# NestedFilter

NestedFilter drills down into a nested map and filters out keys according to
user specified values.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `nested_filter` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:nested_filter, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/nested_filter](https://hexdocs.pm/nested_filter).


## Usage

```elixir
# here we remove the nils from a nested map

nested_map = %{a: 1, b: %{m: nil, n: 2}, c: %{p: %{q: nil, r: nil}, s: %{t: 2, u: 3}} }
NestedFilter.reject_keys_by_value(nested_map, [nil])

# => %{a: 1, b: %{n: 2}, c: %{p: %{}, s: %{t: 2, u: 3}} }
```
