defmodule NestedFilter do
  @moduledoc """
  Documentation for NestedFilter.
  """

  @doc """
  Take a (nested) map and filter out any keys with specified values in the
  values_to_reject list.
  """
  @spec drop_by_value(map :: map(), values_to_reject :: list()) :: map()
  def drop_by_value(map, values_to_reject) when is_map(map) do
    map
    |> Enum.reduce(%{}, fn
      ({key, val}, acc) ->
        cleaned_val = drop_by_value(val, values_to_reject)
        if cleaned_val in values_to_reject do
          acc
        else
          Map.put(acc, key, cleaned_val)
        end
    end)
  end

  def drop_by_value(not_map, _) do
    not_map
  end

  @doc """
  Take a (nested) map and filter out any values with specified keys in the
  keys_to_reject list.
  """
  @spec drop_by_key(map :: map(), keys_to_reject :: list()) :: map()
  def drop_by_key(map, keys_to_reject) when is_map(map) do
    map
    |> Enum.reduce(%{},
    fn
      ({key, val}, acc)  ->
        if key in keys_to_reject do
          acc
        else
          Map.put(acc, key, drop_by_key(val, keys_to_reject))
        end
    end)
  end

  def drop_by_key(not_map, _) do
    not_map
  end
end
