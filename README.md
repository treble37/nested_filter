# NestedFilter

![Build](https://github.com/treble37/nested_filter/actions/workflows/nested_filter_ci.yml/badge.svg?branch=master)
[![GitHub stars](https://img.shields.io/github/stars/treble37/nested_filter.svg)](https://github.com/treble37/nested_filter/stargazers)
[![Module Version](https://img.shields.io/hexpm/v/nested_filter.svg)](https://hex.pm/packages/nested_filter)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/nested_filter/)
[![Total Download](https://img.shields.io/hexpm/dt/nested_filter.svg)](https://hex.pm/packages/nested_filter)
[![License](https://img.shields.io/hexpm/l/nested_filter.svg)](https://github.com/treble37/nested_filter/blob/master/LICENSE.md)
[![Last Updated](https://img.shields.io/github/last-commit/treble37/nested_filter.svg)](https://github.com/treble37/nested_filter/commits/master)

## The Problems

1.  You have a nested map (or a struct that you converted to a nested map) and you want to remove ALL the keys with specific values such as nil.
2.  You want to do a Map#take on a nested map

##### Example: Remove all the map keys with nil values

```elixir
nested_map = %{a: 1, b: %{c: nil, d: nil}, c: nil}

Map.drop(nested_map, [:c, :d])
# => %{a: 1, b: %{c: nil, d: nil}}

# But you actually wanted:
# => %{a: 1}
```

## The Solution: NestedFilter

NestedFilter drills down into a nested map and can do any of the following:

1.  filters out keys according to user specified values.
2.  filters out values according to user specified keys.

## Installation

The package can be installed by adding `:nested_filter` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nested_filter, "~> 1.2.2"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/nested_filter>.

## Usage

By default, when removing user specified values, empty values will be preserved
(see Case 1 below). You can add empty values to the user specified values list
if you wish those "empty values" (e.g., empty maps) to be removed.

### NestedFilter.drop_by_value

```elixir
# Case 1: Remove the nil values from a nested map, preserving empty map values

nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
NestedFilter.drop_by_value(nested_map, [nil])

# => %{a: 1, b: %{n: 2}, c: %{p: %{}, s: %{t: 2, u: 3}} }

# Case 2: Remove the nil values from a nested map, removing empty map values

nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
NestedFilter.drop_by_value(nested_map, [nil, %{}])
# => %{a: 1, b: %{n: 2}, c: %{s: %{t: 2, u: 3}} }
```

### NestedFilter.drop_by_key

```elixir
# Case 1: Remove values from a nested map by key

nested_map = %{a: 1, b: %{a: 2, b: 3}, c: %{a: %{a: 1, b: 2}, b: 2, c: %{d: 1, e: 2}}}
assert NestedFilter.drop_by_key(nested_map, [:a]) == %{b: %{b: 3},c: %{b: 2, c: %{d: 1, e: 2}}}
```

### NestedFilter.take_by_key

```elixir
# Case 1: Take values from a nested map by key

nested_map = %{a: %{b: 1}, c: 3, e: %{f: 4}}
assert NestedFilter.take_by_key(nested_map, [:b, :f]) == %{b: 1, f: 4 }
```

You can browse the tests for more usage examples.


## Copyright and License

Copyright (c) 2017 Bruce Park

This work is free. You can redistribute it and/or modify it under the
terms of the MIT License. See the [LICENSE.md](./LICENSE.md) file for more details.
