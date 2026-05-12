# Compilation Flags

`unittest2` behavior can be customized using compilation flags (`-d:flag`). These flags allow you to select the execution model, enable advanced features, and configure compatibility with the standard library.

## Execution Modes

- `-d:unittest2Compat=true|false`: Select execution mode (default is `true`).
  - `true`: **Compatibility Mode**. Single-pass execution, identical to `std/unittest`.
  - `false`: **Collect-and-Run Mode**. Two-phase execution (discovery then run). See [Operation Modes](./operation-modes.md) for details.
  - Set with `-d:unittest2Compat=false` to disable compatibility mode.

## Advanced Features

- `-d:unittest2Static=true`: Enable **Compile-Time Execution**.
  - Runs your tests in the Nim VM during compilation.
  - Verifies that your code works correctly at compile-time.
  - Use [`staticTest`](apidocs/unittest2.html#staticTest.t,string,untyped), [`runtimeTest`](apidocs/unittest2.html#runtimeTest.t,string,untyped), or [`dualTest`](apidocs/unittest2.html#dualTest.t,string,untyped) for explicit control.
  - Set with `-d:unittest2Static=true`.
- `-d:unittest2ListTests=true`: **List Tests** without running them.
  - Useful for integration with external test runners or IDEs.
  - Requires **Collect-and-Run Mode** (`-d:unittest2Compat=false`).
  - Set with `-d:unittest2ListTests=true`.
- `-d:unittest2DisableParamFiltering=true`: Disable automatic argument parsing.
  - Use this if your test binary needs to handle its own CLI arguments. Call [`parseParameters`](apidocs/unittest2.html#parseParameters,openArray[string]) manually if needed.
  - Set with `-d:unittest2DisableParamFiltering=true`.
- `-d:unittest2NoCollect=true`: Disable test collection mode.
  - This is an experimental feature that affects the order in which tests and suites are evaluated.
  - Set with `-d:unittest2NoCollect=true`.
- `-d:unittest2PreviewIsolate=true`: Enable preview isolation mode.
  - Each test is run in a separate process to ensure complete isolation. This may be removed in the future.
  - Set with `-d:unittest2PreviewIsolate=true`.

## Standard Library Compatibility

These flags provide compatibility with the original `unittest` module:

- `-d:nimUnittestOutputLevel=VERBOSE|COMPACT|FAILURES|NONE`: Set the default output level at compile time.
- `-d:nimUnittestColor=auto|on|off`: Set the color output mode at compile time.
- `-d:nimUnittestAbortOnError=true`: Set whether to abort on the first error at compile time.
