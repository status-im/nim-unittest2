# Examples

This page showcases common patterns and strategies for effective testing with `unittest2`.

## Service Layer with Dependency Injection

Using mocks or fakes allows you to test business logic without relying on external services like databases or APIs.

```nim
{{#shiftinclude auto:../../examples/dependency_injection.nim}}
```

## Table-Driven Tests

Table-driven tests are excellent for covering many edge cases with minimal code duplication.

```nim
{{#shiftinclude auto:../../examples/table_driven.nim}}
```

## Using Checkpoints for Debugging

The [`checkpoint`](apidocs/unittest2.html#checkpoint.t,string) macro is invaluable for identifying exactly which iteration of a loop failed.

```nim
{{#shiftinclude auto:../../examples/checkpoints.nim}}
```

If the above fails, the output will include `Attempt number 1`, `Attempt number 2`, etc., helping you trace the execution.

## Compile-Time Testing

One of `unittest2`'s most powerful features is the ability to run tests during compilation using [`staticTest`](apidocs/unittest2.html#staticTest.t,string,untyped).

```nim
{{#shiftinclude auto:../../examples/compile_time.nim}}
```

```admonish tip
Combine this with `-d:unittest2Static=true` to run regular `test` blocks at compile-time as well.
```

## Per-Suite Resource Lifecycle

Use `setup` and `teardown` to manage resources that should be fresh for every test.

```nim
{{#shiftinclude auto:../../examples/suite_fixture.nim}}
```
