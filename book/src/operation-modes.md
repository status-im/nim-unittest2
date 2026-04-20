# Operation Modes

`unittest2` supports two distinct execution models: **Compatibility Mode** and **Collect-and-Run Mode**.

## Compatibility Mode (Single Pass)

This is the default behavior (`-d:unittest2Compat=true`).

In this mode, `unittest2` behaves like the standard `unittest` module: each test is executed immediately when its `test` block is reached. There is no separate discovery phase.

- **Pros:** Full compatibility with existing `unittest` code.
- **Cons:** Limited reporting (cannot know total test count upfront), no support for advanced features like test listing or process isolation.

## Collect-and-Run Mode (Two Phase)

Enable with:

```sh
nim c -d:unittest2Compat=false -r test.nim
```

```admonish note
`-d:unittest2Compat=false` is required to enable this mode.
```

In this mode, `unittest2` execution is split into two phases:

1. **Discovery:** The program runs, but `test` blocks are only registered, not executed.
2. **Execution:** Once discovery is complete, `unittest2` iterates through all registered suites and tests, executing them and reporting results.

### Benefits

- **Accurate Progress:** Since the total number of tests that match your filters is known after discovery, formatters can show accurate `[1/50]` progress indicators.
- **Test Listing:** You can use `-d:unittest2ListTests=true` to see exactly which tests match your filters without executing them.
- **Advanced Filtering:** This mode provides the foundation for advanced features like running filtered tests in separate processes or in parallel.

### Preparing Your Test Suite

To ensure your test suite works correctly in Collect-and-Run mode, follow these guidelines:

1. **Avoid side effects in `suite` blocks:** Any code inside a `suite` block but outside a `test`, `setup`, or `teardown` block will execute during the **Discovery** phase. If this code modifies global state, it might affect tests in unexpected ways.
2. **Use `setup` and `teardown`:** Always put initialization and cleanup logic inside `setup` and `teardown`. These are guaranteed to run before and after each test during the **Execution** phase.
3. **Independence:** Ensure each test is independent. Collect-and-Run mode makes it easier to run tests in isolation, so they shouldn't rely on being run in a specific order.

### Migration Caveats

- **Top-level code:** Code at the top level of your test module executes during Discovery.
- **Global state:** If you initialize global variables at the top level, they are initialized once before any test runs. If tests modify them, ensure they are reset in `setup`.
