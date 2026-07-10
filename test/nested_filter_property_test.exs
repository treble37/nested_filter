defmodule NestedFilterPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  defmodule Point do
    defstruct [:x, :y]
  end

  property "reject/3 output contains no entry matching the predicate at any depth" do
    check all({term, predicate} <- term_with_predicate(scalar_gen())) do
      term
      |> NestedFilter.reject(predicate)
      |> refute_match_anywhere(predicate)
    end
  end

  property "filter/3 invents nothing: every output leaf exists at the same path in the input" do
    check all({term, predicate} <- term_with_predicate(scalar_gen())) do
      output_leaves = term |> NestedFilter.filter(predicate) |> leaf_paths() |> Enum.frequencies()
      input_leaves = term |> leaf_paths() |> Enum.frequencies()

      Enum.each(output_leaves, fn {leaf_at_path, count} ->
        assert Map.get(input_leaves, leaf_at_path, 0) >= count
      end)
    end
  end

  property "reject/3 and filter/3 are idempotent" do
    check all({term, predicate} <- term_with_predicate(scalar_gen())) do
      rejected = NestedFilter.reject(term, predicate)
      assert NestedFilter.reject(rejected, predicate) == rejected

      filtered = NestedFilter.filter(term, predicate)
      assert NestedFilter.filter(filtered, predicate) == filtered
    end
  end

  property "structs: :leaf round-trips structs unchanged" do
    check all({term, predicate} <- term_with_predicate(one_of([scalar_gen(), struct_gen()]))) do
      input_structs = all_structs(term)

      for engine <- [&NestedFilter.reject/3, &NestedFilter.filter/3] do
        output_structs = all_structs(engine.(term, predicate, structs: :leaf))
        assert output_structs -- input_structs == []
      end

      assert NestedFilter.reject(term, fn _k, _v -> false end) == term
    end
  end

  property "compact/2 output contains no nil map values at any depth" do
    check all(term <- nested_gen(scalar_gen())) do
      term |> NestedFilter.compact() |> refute_nil_map_values()
    end
  end

  property "compact/2 with prune_empty: true contains no empty container values" do
    check all(term <- nested_gen(scalar_gen())) do
      term |> NestedFilter.compact() |> refute_empty_container_values()
    end
  end

  property "redact/3 replaces every value whose key is in the keys list" do
    check all(term <- nested_gen(scalar_gen()), keys <- targets_gen(term, :key)) do
      term |> NestedFilter.redact(keys) |> assert_keys_redacted(keys)
    end
  end

  property "compact/2 and redact/3 are idempotent" do
    check all(term <- nested_gen(scalar_gen()), keys <- targets_gen(term, :key)) do
      compacted = NestedFilter.compact(term)
      assert NestedFilter.compact(compacted) == compacted
      redacted = NestedFilter.redact(term, keys)
      assert NestedFilter.redact(redacted, keys) == redacted
    end
  end

  # --- Generators -----------------------------------------------------------

  defp key_gen do
    one_of([atom(:alphanumeric), string(:alphanumeric, max_length: 8)])
  end

  defp scalar_gen do
    one_of([integer(), boolean(), string(:alphanumeric, max_length: 8), constant(nil)])
  end

  defp struct_gen do
    gen all(x <- integer(), y <- integer()) do
      %Point{x: x, y: y}
    end
  end

  # Bounded-depth JSON-shaped terms: nested maps and lists over the given
  # leaves, with mixed atom and string keys.
  defp nested_gen(leaf_gen) do
    tree(leaf_gen, fn child ->
      one_of([
        map_of(key_gen(), child, max_length: 4),
        list_of(child, max_length: 4)
      ])
    end)
  end

  # A term paired with a key- or value-based predicate whose targets are
  # drawn from the term itself (plus noise), so matches actually happen.
  defp term_with_predicate(leaf_gen) do
    gen all(
          term <- nested_gen(leaf_gen),
          kind <- member_of([:key, :value]),
          targets <- targets_gen(term, kind)
        ) do
      predicate =
        case kind do
          :key -> fn key, _val -> key in targets end
          :value -> fn _key, val -> val in targets end
        end

      {term, predicate}
    end
  end

  defp targets_gen(term, :key) do
    term |> all_keys() |> Enum.uniq() |> sublist_gen(key_gen())
  end

  defp targets_gen(term, :value) do
    term |> all_scalars() |> Enum.uniq() |> sublist_gen(scalar_gen())
  end

  defp sublist_gen([], noise_gen), do: list_of(noise_gen, max_length: 2)

  defp sublist_gen(present, noise_gen) do
    gen all(
          sampled <- list_of(member_of(present), max_length: 3),
          noise <- list_of(noise_gen, max_length: 1)
        ) do
      Enum.uniq(sampled ++ noise)
    end
  end

  # --- Walkers (structs are opaque leaves throughout) -----------------------

  defp refute_match_anywhere(%_{}, _predicate), do: :ok

  defp refute_match_anywhere(map, predicate) when is_map(map) do
    Enum.each(map, fn {key, val} ->
      refute predicate.(key, val)
      refute_match_anywhere(val, predicate)
    end)
  end

  defp refute_match_anywhere(list, predicate) when is_list(list) do
    Enum.each(list, &refute_match_anywhere(&1, predicate))
  end

  defp refute_match_anywhere(_scalar, _predicate), do: :ok

  defp leaf_paths(term), do: leaf_paths(term, [])

  defp leaf_paths(%_{} = struct, path), do: [{Enum.reverse(path), struct}]

  defp leaf_paths(map, path) when is_map(map) do
    Enum.flat_map(map, fn {key, val} -> leaf_paths(val, [{:key, key} | path]) end)
  end

  # List positions are recorded without their index: filter/3 prunes list
  # elements, shifting the indices of the survivors.
  defp leaf_paths(list, path) when is_list(list) do
    Enum.flat_map(list, &leaf_paths(&1, [:list | path]))
  end

  defp leaf_paths(scalar, path), do: [{Enum.reverse(path), scalar}]

  defp all_keys(%_{}), do: []

  defp all_keys(map) when is_map(map) do
    Enum.flat_map(map, fn {key, val} -> [key | all_keys(val)] end)
  end

  defp all_keys(list) when is_list(list), do: Enum.flat_map(list, &all_keys/1)
  defp all_keys(_scalar), do: []

  defp all_scalars(%_{}), do: []

  defp all_scalars(map) when is_map(map) do
    Enum.flat_map(map, fn {_key, val} -> all_scalars(val) end)
  end

  defp all_scalars(list) when is_list(list), do: Enum.flat_map(list, &all_scalars/1)
  defp all_scalars(scalar), do: [scalar]

  defp all_structs(%_{} = struct), do: [struct]

  defp all_structs(map) when is_map(map) do
    Enum.flat_map(map, fn {_key, val} -> all_structs(val) end)
  end

  defp all_structs(list) when is_list(list), do: Enum.flat_map(list, &all_structs/1)
  defp all_structs(_scalar), do: []

  defp refute_nil_map_values(%_{}), do: :ok

  defp refute_nil_map_values(map) when is_map(map) do
    Enum.each(map, fn {_key, value} ->
      refute is_nil(value)
      refute_nil_map_values(value)
    end)
  end

  defp refute_nil_map_values(list) when is_list(list),
    do: Enum.each(list, &refute_nil_map_values/1)

  defp refute_nil_map_values(_scalar), do: :ok

  defp refute_empty_container_values(%_{}), do: :ok

  defp refute_empty_container_values(map) when is_map(map) do
    Enum.each(map, fn {_key, value} ->
      refute value == %{}
      refute value == []
      refute_empty_container_values(value)
    end)
  end

  defp refute_empty_container_values(list) when is_list(list) do
    Enum.each(list, fn value ->
      refute value == %{}
      refute value == []
      refute_empty_container_values(value)
    end)
  end

  defp refute_empty_container_values(_scalar), do: :ok

  defp assert_keys_redacted(%_{} = struct, _keys), do: struct

  defp assert_keys_redacted(map, keys) when is_map(map) do
    Enum.each(map, fn {key, value} ->
      if key in keys, do: assert(value == "[REDACTED]"), else: assert_keys_redacted(value, keys)
    end)
  end

  defp assert_keys_redacted(list, keys) when is_list(list),
    do: Enum.each(list, &assert_keys_redacted(&1, keys))

  defp assert_keys_redacted(scalar, _keys), do: scalar
end
