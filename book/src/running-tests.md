# Running and Filtering Tests

When your test suite grows, running every single test every time can become slow and noisy. `unittest2` allows you to pick exactly which tests you want to execute. You can run a single test case, all tests in a specific suite, or a group of tests that match a certain naming pattern.

To filter tests, you pass **filter arguments** to the compiled test binary. These arguments come after any regular options (like `--xml` or `--verbose`).

A filter can target:

- An exact test name.
- A specific test inside a specific suite using the `suite::test` syntax.
- An entire suite using the `suite::` syntax.
- Multiple tests or suites using a `*` wildcard.

If you provide multiple filter arguments, `unittest2` will run any test that matches **at least one** of them.

## Run Individual Tests

Using the tests from the [Quickstart](./quickstart.md) example:

```sh
# Runs only the "2 + 2 == 4" test
nim c -r test.nim "2 + 2 == 4"

# Runs both specified tests
nim c -r test.nim "2 + 2 == 4" "out of bounds raises"
```

If a test name is unique across your entire project, you can simply use its name as the filter.

## Run a Single Suite

To run all tests within the `math` suite, use the suite name followed by two colons (`::`):

```sh
nim c -r test.nim "math::"
```

## Run a Specific Test in One Specific Suite

If multiple suites have tests with the same name, or if you want to be explicit, use the `suite::test` syntax:

```sh
nim c -r test.nim "math::2 + 2 == 4"
```

## Wildcard Pattern Matching

Filters support a wildcard `*` to match partial names.

```admonish important
You can use **exactly one** asterisk per filter. Patterns like `*bug*` are not supported and will look for a literal `*` at the end.
```

The asterisk can be placed at the beginning, end, or in the middle of a filter:

```sh
# Run all suites that start with "ma"
nim c -r test.nim "ma*::"

# Run tests in the "math" suite that start with "out"
nim c -r test.nim "math::out*"

# Run all tests that end with "raises"
nim c -r test.nim "*raises"

# Match "2 + 2 == 4" using a wildcard
nim c -r test.nim "2 * 4"
```

## Notes on Matching

- `testOnly` matches any test named exactly `testOnly`, regardless of which suite it belongs to.
- If a test name itself contains `::`, `unittest2` will still correctly match it as an exact test-name filter.

Example with `::` inside the test name:

```sh
nim c -r test.nim "HTTP :: returns 200"
```
