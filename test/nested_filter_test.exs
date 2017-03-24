defmodule NestedFilterTest do
  use ExUnit.Case
  doctest NestedFilter

  test "can filter out a nested map's nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
    assert NestedFilter.reject_keys_by_value(nested_map, [nil]) == %{a: 1, b: %{n: 2}, c: %{p: %{}, s: %{t: 2, u: 3}} }
  end

  test "can filter out a nested map's and specified non-nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
    assert NestedFilter.reject_keys_by_value(nested_map, [2]) == %{a: 1, b: %{m: nil}, c: %{p: %{q: nil, r: nil}, s: %{u: 3}} }
  end

  test "can filter out a nested map's nil and specified non-nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
    assert NestedFilter.reject_keys_by_value(nested_map, [nil, 1, 2]) == %{b: %{}, c: %{p: %{}, s: %{u: 3}} }
  end

  test "can filter out a nested map's nil values and empty maps" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
    assert NestedFilter.reject_keys_by_value(nested_map, [nil, %{}]) == %{a: 1, b: %{n: 2}, c: %{s: %{t: 2, u: 3}} }
  end
end
