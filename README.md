# NestedFilter

![Build](https://github.com/treble37/nested_filter/actions/workflows/nested_filter_ci.yml/badge.svg?branch=main)
[![Coverage Status](https://coveralls.io/repos/github/treble37/nested_filter/badge.svg?branch=main)](https://coveralls.io/github/treble37/nested_filter?branch=main)
[![Hex.pm](https://img.shields.io/hexpm/v/nested_filter.svg)](https://hex.pm/packages/nested_filter)
[![Hex.pm Downloads](https://img.shields.io/hexpm/dt/nested_filter.svg)](https://hex.pm/packages/nested_filter)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/treble37/nested_filter/main/LICENSE)

Structure-preserving filter/reject for nested maps and lists: drop or take
keys and values at any depth without flattening or losing data. Zero runtime
dependencies.

`Map.take/2` and `Map.drop/2` only see the top level. NestedFilter walks the
whole structure — maps inside maps, maps inside lists — and never merges
sibling branches or invents values: what survives is always at the path where
it appeared in the input.

Every example below is copied verbatim from a doctest, so it runs exactly as
shown.

## Recipes

### Clean params before insert

Drop `nil` and blank values at any depth before handing user input to a
changeset or query:

```elixir
iex> params = %{"name" => "Ada", "bio" => nil, "address" => %{"city" => "London", "zip" => ""}}
iex> NestedFilter.drop_by_value(params, [nil, ""])
%{"name" => "Ada", "address" => %{"city" => "London"}}
```

### Strip nils before JSON encoding

Remove every `nil` entry so encoded payloads carry no `null` noise:

```elixir
iex> payload = %{id: 7, tags: ["a", "b"], meta: %{source: nil, ip: "1.2.3.4"}}
iex> NestedFilter.reject(payload, fn _k, v -> is_nil(v) end)
%{id: 7, tags: ["a", "b"], meta: %{ip: "1.2.3.4"}}
```

### Compact nested payloads

Remove `nil` map values and prune containers left empty by that cleanup:

```elixir
iex> NestedFilter.compact(%{a: 1, b: nil, c: %{d: nil}, e: %{f: 1, g: nil}})
%{a: 1, e: %{f: 1}}
```

### Drop sensitive keys everywhere

Remove known-bad keys wherever they appear, however deeply nested:

```elixir
iex> event = %{user: %{email: "ada@example.com", password: "s3cret"}, session: %{token: "abc", ttl: 60}}
iex> NestedFilter.drop_by_key(event, [:password, :token])
%{user: %{email: "ada@example.com"}, session: %{ttl: 60}}
```

### Take fields, structure preserved

Keep only the fields you care about without flattening or losing duplicates
across branches:

```elixir
iex> order = %{buyer: %{id: 1, name: "Ada"}, items: [%{id: 10, sku: "X"}, %{id: 11, sku: "Y"}]}
iex> NestedFilter.take_by_key(order, [:id])
%{buyer: %{id: 1}, items: [%{id: 10}, %{id: 11}]}
```

### Sanitize logs

Redact by pattern when the exact key names aren't known up front:

```elixir
iex> log = %{"msg" => "login ok", "user_password" => "hunter2", "ctx" => %{"api_token" => "xyz"}}
iex> NestedFilter.reject(log, fn k, _v -> is_binary(k) and (k =~ "password" or k =~ "token") end)
%{"msg" => "login ok", "ctx" => %{}}
```

### Redact sensitive values

Replace sensitive values at any depth without dropping their keys:

```elixir
iex> NestedFilter.redact(%{user: %{name: "Ana", password: "hunter2"}, token: "abc"}, [:password, :token])
%{user: %{name: "Ana", password: "[REDACTED]"}, token: "[REDACTED]"}
```

## Installation

Add `nested_filter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:nested_filter, "~> 2.1"}]
end
```

Requires Elixir 1.15 or later. Full documentation is at
[hexdocs.pm/nested_filter](https://hexdocs.pm/nested_filter).

## API

Two engine functions take a `predicate` receiving each key and value:

- `NestedFilter.reject/3` — recursively remove matching entries
- `NestedFilter.filter/3` — recursively keep matching entries, pruning
  branches without a match; a matched entry is kept whole

Five convenience functions cover the common cases:

- `NestedFilter.compact/2` — remove `nil` map values and optionally prune
  empty containers or strip `nil` list elements
- `NestedFilter.redact/3` — replace values matching keys or a predicate
- `NestedFilter.drop_by_value/3` — remove entries whose value is in a list
- `NestedFilter.drop_by_key/3` — remove entries whose key is in a list
- `NestedFilter.take_by_key/3` — keep entries whose key is in a list,
  structure preserved

## Semantics worth knowing

- **Structure is sacred.** Matches stay at the path where they were found.
  Sibling branches are never merged, so duplicate keys in different branches
  never clobber each other.
- **`reject` preserves empty maps; `filter` prunes empty branches.** Rejecting
  every entry of a nested map leaves `%{}` at its path (add `%{}` to
  `drop_by_value/3`'s list to remove those too), while `filter` drops any
  branch with no surviving content.
- **Lists are traversed, not filtered by value.** `reject` leaves non-map list
  elements untouched; `filter` prunes list elements with no surviving content.
- **Structs are opaque leaves by default.** Pass `structs: :convert` to
  recurse into them as plain maps, or `structs: :error` to raise if one is
  encountered. See the `:structs` option on `reject/3`.

## Upgrading from 1.x

Version 2.0 changed `take_by_key/3` from flattening (which silently lost data
on duplicate keys) to structure-preserving, removed the undocumented
`drop_by/2` and `take_by/2`, and raised the Elixir floor to 1.15. See the
[CHANGELOG](CHANGELOG.md) for the full migration table.

## License

MIT — see [LICENSE](LICENSE).
