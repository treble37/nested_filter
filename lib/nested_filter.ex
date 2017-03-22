defmodule NestedFilter do
  @moduledoc """
  Documentation for NestedFilter.
  """

  @doc """
  Take a (nested) map and filter out any keys with specified values in the
  filter_values list
  """
  @spec reject_keys_by_value(map :: map(), filter_values :: list(), options :: list()) :: map()
  def reject_keys_by_value(map, filter_values, options \\ nil) do
    cond do
      is_nested_map?(map) ->
        new_map = Map.drop(map, filterable_keys(map, filter_values))
        |> Enum.reduce(%{}, fn({key, val}, acc) -> Map.put(acc, key, reject_keys_by_value(val, filter_values, options)) end)
        Map.drop(new_map, filterable_keys(new_map, options[:remove_empty]))
      is_map(map) ->
        new_map = Map.drop(map, filterable_keys(map, filter_values))
        Map.drop(new_map, filterable_keys(new_map, options[:remove_empty]))
      true ->
        map
    end
  end

  defp filterable_keys(map, filter_values) when is_list(filter_values) do
    map
    |> Map.keys
    |> Enum.filter(fn(key) -> Enum.member?(filter_values, map[key]) end)
  end

  defp filterable_keys(map, filter_values), do: map

  defp is_nested_map?(map) do
    cond do
      is_map(map) ->
        map
        |> Enum.any?(fn{key, _} -> is_map(map[key]) end)
      true ->
        false
    end
  end
end
