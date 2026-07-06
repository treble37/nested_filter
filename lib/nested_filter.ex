defmodule NestedFilter do
  @moduledoc """
  Documentation for NestedFilter.
  """
  @type key :: any
  @type val :: any
  @type keys_to_select :: list
  @type predicate :: (key, val -> boolean)

  @doc """
  Recursively removes map entries for which `predicate` returns a truthy value.

  Values are cleaned depth-first: the predicate receives each key and its
  already-cleaned value. Empty maps produced by rejection are preserved.
  Lists are traversed, but their non-container elements are untouched — the
  predicate only applies to map entries, which have keys. Any other input is
  returned unchanged.

  ## Options

    * `:structs` — how to handle structs encountered at any depth:
      * `:leaf` (default) — the struct passes through as an opaque value,
        never recursed into and never altered
      * `:convert` — the struct is converted with `Map.from_struct/1` and
        recursed into; the result is a plain map
      * `:error` — raises `ArgumentError` on any struct

  ## Examples

      iex> NestedFilter.reject(%{a: 1, b: %{c: nil}}, fn _k, v -> is_nil(v) end)
      %{a: 1, b: %{}}

      iex> NestedFilter.reject(%{a: [1, nil, %{b: nil}]}, fn _k, v -> is_nil(v) end)
      %{a: [1, nil, %{}]}

  """
  @spec reject(map | list | any, predicate, keyword) :: map | list | any
  def reject(data, predicate, opts \\ [])

  def reject(%_{} = struct, predicate, opts) do
    case Keyword.get(opts, :structs, :leaf) do
      :leaf ->
        struct

      :convert ->
        struct |> Map.from_struct() |> reject(predicate, opts)

      :error ->
        raise ArgumentError,
              "encountered struct #{inspect(struct.__struct__)} with structs: :error"
    end
  end

  def reject(map, predicate, opts) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, val}, acc ->
      cleaned_val = reject(val, predicate, opts)

      if predicate.(key, cleaned_val) do
        acc
      else
        Map.put(acc, key, cleaned_val)
      end
    end)
  end

  def reject(list, predicate, opts) when is_list(list) do
    Enum.map(list, &reject(&1, predicate, opts))
  end

  def reject(elem, _predicate, _opts), do: elem

  @spec drop_by(struct, predicate) :: struct
  def drop_by(%_{} = struct, _), do: struct

  @spec drop_by(map, predicate) :: map
  def drop_by(map, predicate) when is_map(map) do
    map
    |> Enum.reduce(
      %{},
      fn {key, val}, acc ->
        cleaned_val = drop_by(val, predicate)

        if predicate.(key, cleaned_val) do
          acc
        else
          Map.put(acc, key, cleaned_val)
        end
      end
    )
  end

  @spec drop_by(list, predicate) :: list
  def drop_by(list, predicate) when is_list(list) do
    Enum.map(list, &drop_by(&1, predicate))
  end

  def drop_by(elem, _) do
    elem
  end

  @doc """
  Recursively removes map entries whose value is in `values_to_reject`.

  Sugar for `reject(map, fn _key, val -> val in values_to_reject end, opts)` —
  see `reject/3` for the traversal semantics and options.

  ## Examples

      iex> NestedFilter.drop_by_value(%{a: 1, b: %{m: nil, n: 2}}, [nil])
      %{a: 1, b: %{n: 2}}

  """
  @spec drop_by_value(map, [val], keyword) :: map
  def drop_by_value(map, values_to_reject, opts \\ []) when is_map(map) do
    reject(map, fn _key, val -> val in values_to_reject end, opts)
  end

  @doc """
  Recursively removes map entries whose key is in `keys_to_reject`.

  Sugar for `reject(map, fn key, _val -> key in keys_to_reject end, opts)` —
  see `reject/3` for the traversal semantics and options.

  ## Examples

      iex> NestedFilter.drop_by_key(%{a: 1, b: %{a: 2, c: 3}}, [:a])
      %{b: %{c: 3}}

  """
  @spec drop_by_key(map, [key], keyword) :: map
  def drop_by_key(map, keys_to_reject, opts \\ []) when is_map(map) do
    reject(map, fn key, _val -> key in keys_to_reject end, opts)
  end

  @spec take_by(map, keys_to_select) :: map
  def take_by(map, keys_to_select) when is_map(map) do
    map
    |> Enum.reduce(
      %{},
      fn {_key, val}, acc ->
        Map.merge(acc, take_by(val, keys_to_select))
      end
    )
    |> Map.merge(Map.take(map, keys_to_select))
  end

  def take_by(_elem, _) do
    %{}
  end

  @doc """
  Take a (nested) map and keep any values with specified keys in the
  keys_to_select list.
  """
  @spec take_by_key(%{any => any}, [any]) :: %{any => any}
  def take_by_key(map, keys_to_select) when is_map(map) do
    Map.merge(
      take_by(map, keys_to_select),
      Map.take(map, keys_to_select)
    )
  end
end
