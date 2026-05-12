# Examples

## Resource Lifecycle with setup and teardown

Use `setup` and `teardown` to manage resources that should be fresh for every test. This ensures that tests are independent and don't leak state to each other.

```nim
{{#shiftinclude auto:../../examples/suite_fixture.nim}}
```

## Compile-Time Testing

One of `unittest2` features is the ability to run tests during compilation using [`staticTest`](apidocs/unittest2.html#staticTest.t,string,untyped). This allows you to verify code logic in the Nim VM before the program even runs.

```nim
{{#shiftinclude auto:../../examples/compile_time.nim}}
```

```admonish tip
Combine this with `-d:unittest2Static=true` to run regular `test` blocks at compile-time as well.
```

## Data-Driven Tests

Data-driven tests cover many edge cases by iterating over a collection of inputs and expected outputs. This pattern keeps your test code compact and easy to extend.

```nim
{{#shiftinclude auto:../../examples/data_driven.nim}}
```

## Collect-and-Run Mode Optimization

When using the [Collect-and-Run mode](./operation-modes.md), it is important to separate the **Discovery** phase from the **Execution** phase. This example shows how to structure your suites for maximum compatibility.

```nim
{{#shiftinclude auto:../../examples/collect_and_run.nim}}
```

## Using Checkpoints for Debugging

The [`checkpoint`](apidocs/unittest2.html#checkpoint.t,string) macro is used for identifying which iteration of a loop failed by printing a message only on failure. It is useful for analyzing failures in complex loops or retry logic.

```nim
{{#shiftinclude auto:../../examples/checkpoints.nim}}
```

## Dependency Injection

Using mocks or fakes allows you to test business logic without relying on external services like databases or APIs. This makes your tests faster and more deterministic.

```nim
{{#shiftinclude auto:../../examples/dependency_injection.nim}}
```
