defmodule NestedFilterTest do
  use ExUnit.Case
  doctest NestedFilter

  test "can filter out a nested map's keys with nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
    assert NestedFilter.drop_by_value(nested_map, [nil]) == %{a: 1, b: %{n: 2}, c: %{p: %{}, s: %{t: 2, u: 3}} }
  end

  test "can filter out a nested map's keys with non-nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
    assert NestedFilter.drop_by_value(nested_map, [2]) == %{a: 1, b: %{m: nil}, c: %{p: %{q: nil, r: nil}, s: %{u: 3}} }
  end

  test "can filter out a nested map's keys with nil and non-nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
    assert NestedFilter.drop_by_value(nested_map, [nil, 1, 2]) == %{b: %{}, c: %{p: %{}, s: %{u: 3}} }
  end

  test "can filter out a nested map's keys with nil and empty map values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
    assert NestedFilter.drop_by_value(nested_map, [nil, %{}]) == %{a: 1, b: %{n: 2}, c: %{s: %{t: 2, u: 3}} }
  end

  test "can filter out a nested map's values by key" do
    nested_map = %{a: 1, b: %{a: 2, b: 3}, c: %{a: %{a: 1, b: 2}, b: 2, c: %{d: 1, e: 2}}}
    assert NestedFilter.drop_by_key(nested_map, [:a]) == %{b: %{b: 3},c: %{b: 2, c: %{d: 1, e: 2}}}
  end

  test "can filter out a nested map's values by multiple keys" do
    nested_map = %{a: 1, b: %{a: 2, b: 3}, c: %{a: %{a: 1, b: 2}, b: 2, c: %{d: 1, e: 2}}}
    assert NestedFilter.drop_by_key(nested_map, [:a, :b]) == %{c: %{c: %{d: 1, e: 2}}}
  end

  test "can filter out values from a nested map with datetime structs as values" do
    datetime = %DateTime{calendar: Calendar.ISO, day: 23, hour: 23, microsecond: {0, 0},
      minute: 50, month: 1, second: 7, std_offset: 0, time_zone: "Etc/UTC",
      utc_offset: 0, year: 2015, zone_abbr: "UTC"}
    nested_map = %{a: 1, b: %{a: 2, b: 3}, date: datetime, foo: nil}
    assert NestedFilter.drop_by_value(nested_map, [nil, datetime]) == %{a: 1, b: %{a: 2, b: 3}}
  end

  test "can filter out values from a nested map with tuples as values" do
    tuple = {:ok, %{"k" => 2, "j" => 3}, 2}
    nested_map = %{a: 1, b: %{a: 2, b: 3}, tuple: tuple, foo: nil}
    assert NestedFilter.drop_by_value(nested_map, [nil]) == %{a: 1, b: %{a: 2, b: 3}, tuple: tuple}
  end

  test "can filter out lists of maps" do
    list = [%{a: 1, b: 2}, %{a: 1, b: 2}]
    nested_map = %{list: list}
    assert NestedFilter.drop_by_key(nested_map, [:b]) == %{list: [%{a: 1}, %{a: 1}]}
  end

  test "take a nested map's values by key (distinct nested keys)" do
    nested_map = %{a: %{b: 2}, c: %{d: 3, e: %{f: 4, g: %{h: %{1 => 2}}}}}
    assert NestedFilter.take_by_key(nested_map, [:b, :f, :h]) ==
      %{b: 2, f: 4, h: %{1 => 2}}
  end

  test "take a nested map's values by key and merges map values of duplicate keys" do
    nested_map = %{a: 1, b: %{a: 2, b: 3}, c: %{a: %{a: 1, b: 2}, b: 2, c: %{d: 1, e: 2}}}
    assert NestedFilter.take_by_key(nested_map, [:b, :c]) == %{b: %{b: 3, a: 2}, c: %{b: 2, c: %{d: 1, e: 2}, a: %{a: 1, b: 2}}}
  end

  test "take a nested map's values by key (duplicate keys) and overwrite non-map duplicate values" do
    nested_map = %{a: %{b: 2}, c: 3, e: %{f: 4}, b: 1}
    assert NestedFilter.take_by_key(nested_map, [:b, :f]) ==
      %{b: 1, f: 4 }
  end

  test "take a nested map in a list" do
    list = [%{a: %{b: 2}, c: 3, e: %{f: 4}, b: 1}, %{c: %{d: %{b: 3}}, e: %{f: 5}}]
    nested_map = %{list: list}
    assert NestedFilter.take_by_key(nested_map, [:b, :f]) ==
      %{list: [%{b: 1, f: 4}, %{b: 3, f: 5}]}
  end
end
