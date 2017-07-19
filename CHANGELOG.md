# Changelog

All notable changes to this project will be documented in this file.

For more information about changelogs, check
[Keep a Changelog](http://keepachangelog.com) and
[Vandamme](http://tech-angels.github.io/vandamme).

## 1.0.0 - 7/18/17 Tues

* [BREAKING CHANGE] - Drop support for Elixir 1.2.0. This is done in order to be
able to easily pattern match on DateTime structs.

## 0.1.5 - 4/13/17 Thurs

* [ENHANCEMENT] Update to use more idiomatic Elixir code. Thank you [scohen](https://github.com/scohen).

## 0.1.4 - 3/24/17 Fri

* [ENHANCEMENT] Update to allow compatibility with Elixir >= 1.2.0
* [ENHANCEMENT] Change method names to drop_by_value and drop_by_key for more clarity

## 0.1.3 - 3/23/17 Thurs

* [ENHANCEMENT] Add a NestedFilter#reject_values_by_key to allow the
user to specify the automatic removal of values with specific keys

## 0.1.2 - 3/23/17 Thurs

* [ENHANCEMENT] Remove a "remove_empty" option to NestedFilter#reject_keys_by_values to allow the
user to specify the automatic removal of keys that end up with empty values

## 0.1.1 - 3/22/17 Weds

* [ENHANCEMENT] Add a "remove_empty" option to NestedFilter#reject_keys_by_values to allow the
user to specify the automatic removal of keys that end up with empty values

## 0.1.0 - 3/21/17 Tues

* Initial release to let a user filter out a nested map's keys via user
specified values
