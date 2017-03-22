defmodule NestedFilter do
  @moduledoc """
  Documentation for NestedFilter.
  """

  @doc """
  Take a (nested) map and filter out any keys with specified values in the
  filter_values list
  """
  @spec reject_keys_by_value(map :: map(), filter_values :: list()) :: map()
  def reject_keys_by_value(map, filter_values) do
    cond do
      is_nested_map?(map) ->
        filtered_map = Map.drop(map, filterable_keys(map, filter_values))
        |> Enum.reduce(%{}, fn({key, val}, acc) -> Map.put(acc, key, reject_keys_by_value(val, filter_values)) end)
      is_map(map) ->
        Map.drop(map, filterable_keys(map, filter_values))
      true ->
        map
    end
  end

  defp filterable_keys(map, filter_values) do
    keys = map
           |> Map.keys
           |> Enum.filter(fn(key) -> Enum.member?(filter_values, map[key]) end)
  end

  defp is_nested_map?(map) do
    cond do
      is_map(map) ->
        map
        |> Enum.any?(fn{key, value} -> is_map(map[key]) end)
      true ->
        false
    end
  end
end
