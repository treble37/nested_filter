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
        struct_error!(struct)
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

  @doc """
  Recursively keeps map entries for which `predicate` returns a truthy value.

  A matched entry is kept whole: its value is not recursed into, so the
  entire subtree survives. A container entry (map or list) that is not
  matched itself is kept only if it has surviving descendants; branches and
  list elements with no surviving content are pruned entirely. Any other
  input is returned unchanged.

  Structure is always preserved — matches stay at the path where they were
  found, and sibling branches are never merged.

  ## Options

  Accepts the same `:structs` option as `reject/3`. With the default
  `:leaf`, a struct is an opaque value: kept whole when its entry is
  matched, pruned otherwise.

  ## Examples

      iex> NestedFilter.filter(
      ...>   %{a: %{x: 1}, b: %{y: 2}, c: [%{x: 3, y: 4}, %{y: 5}]},
      ...>   fn k, _v -> k in [:x] end
      ...> )
      %{a: %{x: 1}, c: [%{x: 3}]}

      iex> NestedFilter.filter(%{user: %{name: "ada"}, meta: %{z: 1}}, fn k, _v -> k == :user end)
      %{user: %{name: "ada"}}

  """
  @spec filter(map | list | any, predicate, keyword) :: map | list | any
  def filter(data, predicate, opts \\ [])

  def filter(%_{} = struct, predicate, opts) do
    case Keyword.get(opts, :structs, :leaf) do
      :leaf -> struct
      :convert -> struct |> Map.from_struct() |> filter(predicate, opts)
      :error -> struct_error!(struct)
    end
  end

  def filter(map, predicate, opts) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, val}, acc ->
      filter_entry(acc, key, val, predicate, opts)
    end)
  end

  def filter(list, predicate, opts) when is_list(list) do
    Enum.flat_map(list, fn elem ->
      case filter_value(elem, predicate, opts) do
        {:keep, kept} -> [kept]
        :prune -> []
      end
    end)
  end

  def filter(elem, _predicate, _opts), do: elem

  # A matched entry is kept whole; an unmatched one survives only if
  # filtering its value leaves surviving content.
  defp filter_entry(acc, key, val, predicate, opts) do
    if predicate.(key, val) do
      Map.put(acc, key, val)
    else
      case filter_value(val, predicate, opts) do
        {:keep, kept} -> Map.put(acc, key, kept)
        :prune -> acc
      end
    end
  end

  # Filters an unmatched value: containers survive only with surviving
  # content; everything else is pruned.
  defp filter_value(%_{} = struct, predicate, opts) do
    case Keyword.get(opts, :structs, :leaf) do
      :leaf -> :prune
      :convert -> struct |> Map.from_struct() |> filter_value(predicate, opts)
      :error -> struct_error!(struct)
    end
  end

  defp filter_value(map, predicate, opts) when is_map(map) do
    case filter(map, predicate, opts) do
      filtered when map_size(filtered) == 0 -> :prune
      filtered -> {:keep, filtered}
    end
  end

  defp filter_value(list, predicate, opts) when is_list(list) do
    case filter(list, predicate, opts) do
      [] -> :prune
      filtered -> {:keep, filtered}
    end
  end

  defp filter_value(_elem, _predicate, _opts), do: :prune

  defp struct_error!(struct) do
    raise ArgumentError,
          "encountered struct #{inspect(struct.__struct__)} with structs: :error"
  end

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
