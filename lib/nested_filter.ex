defmodule NestedFilter do
  @moduledoc """
  Structure-preserving filtering for nested maps and lists.

  Two engine functions traverse arbitrarily nested maps and lists with
  a predicate:

    * `reject/3` — recursively remove matching entries
    * `filter/3` — recursively keep matching entries, pruning branches
      without a match

  Four convenience functions cover the common cases: `compact/2`,
  `drop_by_value/3`, `drop_by_key/3`, and `take_by_key/3`.

  No operation ever merges sibling branches or invents values — what
  survives is always at the path where it appeared in the input. Structs
  are treated as opaque leaf values by default; see the `:structs` option
  on `reject/3`.

  ## Recipes

  ### Clean params before insert

  Drop `nil` and blank values at any depth before handing user input to a
  changeset or query:

      iex> params = %{"name" => "Ada", "bio" => nil, "address" => %{"city" => "London", "zip" => ""}}
      iex> NestedFilter.drop_by_value(params, [nil, ""])
      %{"name" => "Ada", "address" => %{"city" => "London"}}

  ### Strip nils before JSON encoding

  Remove every `nil` entry so encoded payloads carry no `null` noise:

      iex> payload = %{id: 7, tags: ["a", "b"], meta: %{source: nil, ip: "1.2.3.4"}}
      iex> NestedFilter.reject(payload, fn _k, v -> is_nil(v) end)
      %{id: 7, tags: ["a", "b"], meta: %{ip: "1.2.3.4"}}

  ### Drop sensitive keys everywhere

  Remove known-bad keys wherever they appear, however deeply nested:

      iex> event = %{user: %{email: "ada@example.com", password: "s3cret"}, session: %{token: "abc", ttl: 60}}
      iex> NestedFilter.drop_by_key(event, [:password, :token])
      %{user: %{email: "ada@example.com"}, session: %{ttl: 60}}

  ### Take fields, structure preserved

  Keep only the fields you care about without flattening or losing
  duplicates across branches:

      iex> order = %{buyer: %{id: 1, name: "Ada"}, items: [%{id: 10, sku: "X"}, %{id: 11, sku: "Y"}]}
      iex> NestedFilter.take_by_key(order, [:id])
      %{buyer: %{id: 1}, items: [%{id: 10}, %{id: 11}]}

  ### Sanitize logs

  Redact by pattern when the exact key names aren't known up front:

      iex> log = %{"msg" => "login ok", "user_password" => "hunter2", "ctx" => %{"api_token" => "xyz"}}
      iex> NestedFilter.reject(log, fn k, _v -> is_binary(k) and (k =~ "password" or k =~ "token") end)
      %{"msg" => "login ok", "ctx" => %{}}
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
  Recursively removes `nil` map values, then prunes containers left empty by
  that removal.

  `compact/2` uses the same traversal semantics and `:structs` option as
  `reject/3`: non-container list elements are untouched by default, and
  structs are treated as opaque leaves unless `structs: :convert` or
  `structs: :error` is supplied.

  ## Options

    * `:prune_empty` - when `true` (default), removes map entries and list
      elements whose cleaned value is an empty map or list
    * `:strip_list_nils` - when `true`, also removes `nil` elements from lists;
      defaults to `false`
    * `:structs` - same meaning as in `reject/3`

  ## Examples

      iex> NestedFilter.compact(%{a: 1, b: nil, c: %{d: nil}, e: %{f: 1, g: nil}})
      %{a: 1, e: %{f: 1}}

      iex> NestedFilter.compact(%{a: [1, nil, 2]}, strip_list_nils: true)
      %{a: [1, 2]}

  """
  @spec compact(map | list | any, keyword) :: map | list | any
  def compact(data, opts \\ []) do
    compacted = reject(data, fn _key, val -> is_nil(val) end, opts)

    compacted =
      if Keyword.get(opts, :strip_list_nils, false) do
        strip_list_nils(compacted)
      else
        compacted
      end

    if Keyword.get(opts, :prune_empty, true) do
      prune_empty_containers(compacted)
    else
      compacted
    end
  end

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

  defp strip_list_nils(%_{} = struct), do: struct

  defp strip_list_nils(map) when is_map(map) do
    Map.new(map, fn {key, val} -> {key, strip_list_nils(val)} end)
  end

  defp strip_list_nils(list) when is_list(list) do
    list
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&strip_list_nils/1)
  end

  defp strip_list_nils(elem), do: elem

  defp prune_empty_containers(%_{} = struct), do: struct

  defp prune_empty_containers(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, val}, acc ->
      pruned = prune_empty_containers(val)

      if empty_container?(pruned) do
        acc
      else
        Map.put(acc, key, pruned)
      end
    end)
  end

  defp prune_empty_containers(list) when is_list(list) do
    list
    |> Enum.map(&prune_empty_containers/1)
    |> Enum.reject(&empty_container?/1)
  end

  defp prune_empty_containers(elem), do: elem

  defp empty_container?(%_{}), do: false
  defp empty_container?(map) when is_map(map), do: map_size(map) == 0
  defp empty_container?(list) when is_list(list), do: list == []
  defp empty_container?(_elem), do: false

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

  @doc """
  Recursively keeps map entries whose key is in `keys_to_select`,
  preserving the structure they were found in.

  Sugar for `filter(map, fn key, _val -> key in keys_to_select end, opts)` —
  see `filter/3` for the traversal semantics and options. Matches stay at
  the path where they were found; sibling branches are never merged, and
  branches without a match are pruned.

  > #### Changed in 2.0 {: .warning}
  >
  > In 1.x this function flattened all matches into a single-level map,
  > silently losing data when the same key appeared in more than one
  > branch. It is now structure-preserving.

  ## Examples

      iex> NestedFilter.take_by_key(%{a: %{x: 1}, b: %{x: 2}}, [:x])
      %{a: %{x: 1}, b: %{x: 2}}

  """
  @spec take_by_key(map, keys_to_select, keyword) :: map
  def take_by_key(map, keys_to_select, opts \\ []) when is_map(map) do
    filter(map, fn key, _val -> key in keys_to_select end, opts)
  end
end
