defmodule NestedFilterTest.Profile do
  defstruct [:name, :email]
end

defmodule NestedFilterTest do
  use ExUnit.Case
  doctest NestedFilter

  alias NestedFilterTest.Profile

  test "can filter out a nested map's keys with nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}}}

    assert NestedFilter.drop_by_value(nested_map, [nil]) == %{
             a: 1,
             b: %{n: 2},
             c: %{p: %{}, s: %{t: 2, u: 3}}
           }
  end

  test "can filter out a nested map's keys with non-nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}}}

    assert NestedFilter.drop_by_value(nested_map, [2]) == %{
             a: 1,
             b: %{m: nil},
             c: %{p: %{q: nil, r: nil}, s: %{u: 3}}
           }
  end

  test "can filter out a nested map's keys with nil and non-nil values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}}}

    assert NestedFilter.drop_by_value(nested_map, [nil, 1, 2]) == %{
             b: %{},
             c: %{p: %{}, s: %{u: 3}}
           }
  end

  test "can filter out a nested map's keys with nil and empty map values" do
    nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}}}

    assert NestedFilter.drop_by_value(nested_map, [nil, %{}]) == %{
             a: 1,
             b: %{n: 2},
             c: %{s: %{t: 2, u: 3}}
           }
  end

  test "can filter out a nested map's values by key" do
    nested_map = %{a: 1, b: %{a: 2, b: 3}, c: %{a: %{a: 1, b: 2}, b: 2, c: %{d: 1, e: 2}}}

    assert NestedFilter.drop_by_key(nested_map, [:a]) == %{
             b: %{b: 3},
             c: %{b: 2, c: %{d: 1, e: 2}}
           }
  end

  test "can filter out a nested map's values by multiple keys" do
    nested_map = %{a: 1, b: %{a: 2, b: 3}, c: %{a: %{a: 1, b: 2}, b: 2, c: %{d: 1, e: 2}}}
    assert NestedFilter.drop_by_key(nested_map, [:a, :b]) == %{c: %{c: %{d: 1, e: 2}}}
  end

  test "can filter out values from a nested map with datetime structs as values" do
    datetime = %DateTime{
      calendar: Calendar.ISO,
      day: 23,
      hour: 23,
      microsecond: {0, 0},
      minute: 50,
      month: 1,
      second: 7,
      std_offset: 0,
      time_zone: "Etc/UTC",
      utc_offset: 0,
      year: 2015,
      zone_abbr: "UTC"
    }

    nested_map = %{a: 1, b: %{a: 2, b: 3}, date: datetime, foo: nil}
    assert NestedFilter.drop_by_value(nested_map, [nil, datetime]) == %{a: 1, b: %{a: 2, b: 3}}
  end

  test "can filter out values from a nested map with tuples as values" do
    tuple = {:ok, %{"k" => 2, "j" => 3}, 2}
    nested_map = %{a: 1, b: %{a: 2, b: 3}, tuple: tuple, foo: nil}

    assert NestedFilter.drop_by_value(nested_map, [nil]) == %{
             a: 1,
             b: %{a: 2, b: 3},
             tuple: tuple
           }
  end

  test "can filter out lists of maps" do
    list = [%{a: 1, b: 2}, %{a: 1, b: 2}]
    nested_map = %{list: list}
    assert NestedFilter.drop_by_key(nested_map, [:b]) == %{list: [%{a: 1}, %{a: 1}]}
  end

  describe "reject/3" do
    test "removes entries matching the predicate at any depth, preserving empty maps" do
      nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}}}

      assert NestedFilter.reject(nested_map, fn _k, v -> is_nil(v) end) ==
               %{a: 1, b: %{n: 2}, c: %{p: %{}}}
    end

    test "predicate receives the already-cleaned value" do
      nested_map = %{a: %{b: nil}}

      assert NestedFilter.reject(nested_map, fn _k, v -> is_nil(v) or v == %{} end) == %{}
    end

    test "non-container list elements are untouched" do
      nested_map = %{a: [1, nil, %{b: nil, c: 2}]}

      assert NestedFilter.reject(nested_map, fn _k, v -> is_nil(v) end) ==
               %{a: [1, nil, %{c: 2}]}
    end

    test "structs are leaves by default: never entered, never altered" do
      profile = %Profile{name: "ada", email: nil}
      nested_map = %{user: profile, junk: nil}

      assert NestedFilter.reject(nested_map, fn _k, v -> is_nil(v) end) ==
               %{user: profile}
    end

    test "a bare struct passes through unchanged" do
      profile = %Profile{name: "ada", email: nil}
      assert NestedFilter.reject(profile, fn _k, v -> is_nil(v) end) == profile
    end

    test "structs: :convert recurses into the struct as a plain map" do
      nested_map = %{user: %Profile{name: "ada", email: nil}}

      assert NestedFilter.reject(nested_map, fn _k, v -> is_nil(v) end, structs: :convert) ==
               %{user: %{name: "ada"}}
    end

    test "structs: :error raises ArgumentError naming the struct module" do
      nested_map = %{user: %Profile{name: "ada", email: nil}}

      assert_raise ArgumentError, ~r/NestedFilterTest\.Profile/, fn ->
        NestedFilter.reject(nested_map, fn _k, v -> is_nil(v) end, structs: :error)
      end
    end

    test "non-map, non-list input is returned unchanged" do
      assert NestedFilter.reject(5, fn _k, v -> is_nil(v) end) == 5
      assert NestedFilter.reject("hello", fn _k, v -> is_nil(v) end) == "hello"
      assert NestedFilter.reject(nil, fn _k, v -> is_nil(v) end) == nil
    end

    test "mixed atom and string keys are compared with plain equality" do
      nested_map = %{"a" => 1, :a => 2, "b" => %{"a" => 3}}

      assert NestedFilter.reject(nested_map, fn k, _v -> k == "a" end) ==
               %{:a => 2, "b" => %{}}
    end
  end

  describe "drop sugar with opts" do
    test "drop_by_value/3 forwards the structs option" do
      nested_map = %{user: %Profile{name: "ada", email: nil}}

      assert NestedFilter.drop_by_value(nested_map, [nil], structs: :convert) ==
               %{user: %{name: "ada"}}
    end

    test "drop_by_key/3 forwards the structs option" do
      nested_map = %{user: %Profile{name: "ada", email: "a@b.c"}}

      assert NestedFilter.drop_by_key(nested_map, [:email], structs: :convert) ==
               %{user: %{name: "ada"}}
    end
  end

  describe "compact/2" do
    test "removes nil values and prunes empty containers by default" do
      nested_map = %{a: 1, b: nil, c: %{d: nil}, e: %{f: 1, g: nil}}

      assert NestedFilter.compact(nested_map) == %{a: 1, e: %{f: 1}}
    end

    test "prunes empty containers bottom-up after nil removal" do
      nested_map = %{
        a: [%{b: %{c: nil}}],
        d: [%{e: nil}, %{f: 1}],
        g: %{h: %{i: nil}, j: [nil]}
      }

      assert NestedFilter.compact(nested_map) == %{d: [%{f: 1}], g: %{j: [nil]}}
    end

    test "prune_empty: false keeps empty containers left by nil removal" do
      nested_map = %{a: 1, b: nil, c: %{d: nil}, e: [%{f: nil}]}

      assert NestedFilter.compact(nested_map, prune_empty: false) == %{
               a: 1,
               c: %{},
               e: [%{}]
             }
    end

    test "list nils are untouched by default" do
      assert NestedFilter.compact(%{a: [1, nil, 2]}) == %{a: [1, nil, 2]}
    end

    test "strip_list_nils: true removes nil elements from lists" do
      assert NestedFilter.compact(%{a: [1, nil, 2]}, strip_list_nils: true) == %{a: [1, 2]}
    end

    test "strip_list_nils: true interacts with default empty-container pruning" do
      nested_map = %{a: [nil], b: [nil, %{c: nil}], d: [nil, %{e: 1}]}

      assert NestedFilter.compact(nested_map, strip_list_nils: true) == %{d: [%{e: 1}]}
    end

    test "structs are leaves by default: never entered, never altered" do
      profile = %Profile{name: "ada", email: nil}

      assert NestedFilter.compact(%{user: profile, junk: nil}) == %{user: profile}
    end

    test "structs: :convert recurses into the struct as a plain map" do
      nested_map = %{user: %Profile{name: "ada", email: nil}}

      assert NestedFilter.compact(nested_map, structs: :convert) == %{user: %{name: "ada"}}
    end

    test "structs: :error raises ArgumentError naming the struct module" do
      nested_map = %{user: %Profile{name: "ada", email: nil}}

      assert_raise ArgumentError, ~r/NestedFilterTest\.Profile/, fn ->
        NestedFilter.compact(nested_map, structs: :error)
      end
    end

    test "non-map, non-list input is returned unchanged" do
      assert NestedFilter.compact(5) == 5
      assert NestedFilter.compact("hello") == "hello"
      assert NestedFilter.compact(nil) == nil
    end
  end

  describe "filter/3" do
    test "keeps matched entries and containers with surviving descendants, pruning the rest" do
      nested_map = %{a: %{x: 1}, b: %{y: 2}, c: [%{x: 3, y: 4}, %{y: 5}]}

      assert NestedFilter.filter(nested_map, fn k, _v -> k in [:x] end) ==
               %{a: %{x: 1}, c: [%{x: 3}]}
    end

    test "matched entries are kept whole: no recursion into a matched value" do
      nested_map = %{user: %{name: "ada", password: "secret"}, meta: %{z: 1}}

      assert NestedFilter.filter(nested_map, fn k, _v -> k == :user end) ==
               %{user: %{name: "ada", password: "secret"}}
    end

    test "no cross-branch merging or data loss on key collisions" do
      nested_map = %{a: %{x: 1}, b: %{x: 2}}
      assert NestedFilter.filter(nested_map, fn k, _v -> k in [:x] end) == nested_map
    end

    test "branches with no surviving content are pruned entirely" do
      nested_map = %{a: %{b: %{c: 1}}, d: 2}
      assert NestedFilter.filter(nested_map, fn k, _v -> k == :nope end) == %{}
    end

    test "non-container list elements with no surviving content are pruned" do
      nested_map = %{c: [1, "two", %{x: 3}]}
      assert NestedFilter.filter(nested_map, fn k, _v -> k == :x end) == %{c: [%{x: 3}]}
    end

    test "a top-level list is traversed symmetrically" do
      list = [%{x: 1}, %{y: 2}, 3]
      assert NestedFilter.filter(list, fn k, _v -> k == :x end) == [%{x: 1}]
    end

    test "mixed atom and string keys are compared with plain equality" do
      nested_map = %{"x" => 1, :x => 2, "b" => %{"x" => 3}, "c" => %{y: 4}}

      assert NestedFilter.filter(nested_map, fn k, _v -> k == "x" end) ==
               %{"x" => 1, "b" => %{"x" => 3}}
    end

    test "structs are leaves by default: kept whole when matched, pruned when not" do
      profile = %Profile{name: "ada", email: nil}

      assert NestedFilter.filter(%{user: profile, other: 1}, fn k, _v -> k == :user end) ==
               %{user: profile}

      assert NestedFilter.filter(%{user: profile}, fn k, _v -> k == :nope end) == %{}
    end

    test "a bare struct passes through unchanged" do
      profile = %Profile{name: "ada", email: nil}
      assert NestedFilter.filter(profile, fn k, _v -> k == :name end) == profile
    end

    test "structs: :convert recurses into the struct as a plain map" do
      nested_map = %{user: %Profile{name: "ada", email: nil}}

      assert NestedFilter.filter(nested_map, fn k, _v -> k == :name end, structs: :convert) ==
               %{user: %{name: "ada"}}

      bare_struct = %Profile{name: "ada", email: nil}

      assert NestedFilter.filter(bare_struct, fn k, _v -> k == :name end, structs: :convert) ==
               %{name: "ada"}
    end

    test "structs: :error raises ArgumentError naming the struct module" do
      nested_map = %{user: %Profile{name: "ada", email: nil}}

      assert_raise ArgumentError, ~r/NestedFilterTest\.Profile/, fn ->
        NestedFilter.filter(nested_map, fn k, _v -> k == :name end, structs: :error)
      end

      assert_raise ArgumentError, ~r/NestedFilterTest\.Profile/, fn ->
        NestedFilter.filter(%Profile{name: "ada"}, fn k, _v -> k == :name end, structs: :error)
      end
    end

    test "non-map, non-list input is returned unchanged" do
      assert NestedFilter.filter(5, fn k, _v -> k == :x end) == 5
      assert NestedFilter.filter("hello", fn k, _v -> k == :x end) == "hello"
    end
  end

  describe "take_by_key/3 (structure-preserving)" do
    test "no flattening, no data loss on key collisions across branches" do
      nested_map = %{a: %{x: 1}, b: %{x: 2}}
      assert NestedFilter.take_by_key(nested_map, [:x]) == %{a: %{x: 1}, b: %{x: 2}}
    end

    test "keeps matches at the path where they were found" do
      nested_map = %{a: %{b: 2}, c: %{d: 3, e: %{f: 4, g: %{h: %{1 => 2}}}}}

      assert NestedFilter.take_by_key(nested_map, [:b, :f, :h]) ==
               %{a: %{b: 2}, c: %{e: %{f: 4, g: %{h: %{1 => 2}}}}}
    end

    test "matched entries are kept whole, including nested duplicates" do
      nested_map = %{a: 1, b: %{a: 2, b: 3}, c: %{a: %{a: 1, b: 2}, b: 2, c: %{d: 1, e: 2}}}

      assert NestedFilter.take_by_key(nested_map, [:b, :c]) == %{
               b: %{a: 2, b: 3},
               c: %{a: %{a: 1, b: 2}, b: 2, c: %{d: 1, e: 2}}
             }
    end

    test "keys matched at different depths survive independently" do
      nested_map = %{a: %{b: 2}, c: 3, e: %{f: 4}, b: 1}

      assert NestedFilter.take_by_key(nested_map, [:b, :f]) ==
               %{a: %{b: 2}, b: 1, e: %{f: 4}}
    end

    test "forwards the structs option" do
      nested_map = %{user: %Profile{name: "ada", email: nil}}

      assert NestedFilter.take_by_key(nested_map, [:name], structs: :convert) ==
               %{user: %{name: "ada"}}
    end
  end
end
