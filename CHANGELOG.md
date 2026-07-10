# Changelog

All notable changes to this project will be documented in this file.

For more information about changelogs, check
[Keep a Changelog](http://keepachangelog.com) and
[Vandamme](http://tech-angels.github.io/vandamme).

## 2.1.0 - 7/10/26 Friday

-   [ENHANCEMENT] Add `compact/2` to remove `nil` map values recursively.
    Empty containers are pruned by default with `prune_empty: true`, and
    `strip_list_nils: true` optionally removes `nil` list elements.
-   [ENHANCEMENT] Add `redact/3` to replace values selected by a keys list or
    predicate. `replacement:` customizes the redaction value, and
    `recurse_into_matched: true` searches matched containers for deeper
    matches instead of replacing those containers wholesale.

## 2.0.0 - 7/6/26 Monday

-   [BREAKING CHANGE] `take_by_key/3` is now structure-preserving. In 1.x it
    flattened all matches into a single-level map, silently losing data when
    the same key appeared in more than one branch. Matches now stay at the
    path where they were found.
-   [BREAKING CHANGE] Remove the public-but-undocumented `drop_by/2` and
    `take_by/2`. Use `reject/3` and `filter/3` instead.
-   [BREAKING CHANGE] Require Elixir ~> 1.15.
-   [ENHANCEMENT] New engine functions: `reject/3` recursively removes
    entries matching a predicate; `filter/3` recursively keeps matching
    entries (kept whole) and prunes branches without a match.
    `drop_by_value/3`, `drop_by_key/3`, and `take_by_key/3` are now sugar
    over the engines and each accept an `opts` argument.
-   [ENHANCEMENT] New `structs:` option on every function: `:leaf` (default)
    passes structs through as opaque values, `:convert` recurses into them
    via `Map.from_struct/1`, `:error` raises `ArgumentError` on any struct.
-   [ENHANCEMENT] StreamData property suite; 100% test coverage.

### Upgrading from 1.x

| If you used                            | In 2.0                                                                                                    |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `take_by_key(map, keys)`               | Same call, new semantics: results keep their original nesting instead of being flattened (no more data loss on duplicate keys). Audit call sites that relied on a flat result. |
| `drop_by/2`                            | `reject(map, predicate)` — e.g. `NestedFilter.reject(map, fn _k, v -> is_nil(v) end)`                     |
| `take_by/2`                            | `filter(map, predicate)` — e.g. `NestedFilter.filter(map, fn k, _v -> k in [:id] end)`                    |
| Structs converted by hand before 1.x calls | Pass `structs: :convert` (or keep the default `:leaf` to treat structs as opaque values)               |
| Elixir < 1.15                          | Stay on `nested_filter ~> 1.2` or upgrade Elixir; 2.0 requires `~> 1.15`                                  |

## 1.2.2 - 5/30/19 Saturday

-   [WARNING FIX] Remove warning from unused parameter (thanks
    @rsilvestre)
-   Update credo, excoveralls, ex_doc, inch_ex dependencies

## 1.2.1 - 4/22/18 Sun

-   [ENHANCEMENT] Add a take_by_key function which returns a map based on user
    specified keys. A duplicate key's values are overwritten (or merged if the value
    is a map).

## 1.1.1 - 8/25/17 Fri

-   [ENHANCEMENT] Filter out lists of maps

## 1.0.1 - 7/19/17 Weds

-   [BUGFIX] Filter out values even if DateTime values exist in a nested map

## 1.0.0 - 7/18/17 Tues

-   [BREAKING CHANGE] - Drop support for Elixir 1.2.0. This is done in order to be
    able to easily pattern match on DateTime structs.

## 0.1.5 - 4/13/17 Thurs

-   [ENHANCEMENT] Update to use more idiomatic Elixir code. Thank you [scohen](https://github.com/scohen).

## 0.1.4 - 3/24/17 Fri

-   [ENHANCEMENT] Update to allow compatibility with Elixir >= 1.2.0
-   [ENHANCEMENT] Change method names to drop_by_value and drop_by_key for more clarity

## 0.1.3 - 3/23/17 Thurs

-   [ENHANCEMENT] Add a NestedFilter#reject_values_by_key to allow the
    user to specify the automatic removal of values with specific keys

## 0.1.2 - 3/23/17 Thurs

-   [ENHANCEMENT] Remove a "remove_empty" option to NestedFilter#reject_keys_by_values to allow the
    user to specify the automatic removal of keys that end up with empty values

## 0.1.1 - 3/22/17 Weds

-   [ENHANCEMENT] Add a "remove_empty" option to NestedFilter#reject_keys_by_values to allow the
    user to specify the automatic removal of keys that end up with empty values

## 0.1.0 - 3/21/17 Tues

-   Initial release to let a user filter out a nested map's keys via user
    specified values
