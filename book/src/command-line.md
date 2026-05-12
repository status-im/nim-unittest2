# Command-Line Options

`unittest2` supports runtime options via command-line arguments and environment variables. Command-line options take precedence.

## Core Flags

- `--help`: Print usage and exit.
- `--xml:<file>` or `--xml=<file>`: Write a JUnit-compatible XML report using [`JUnitOutputFormatter`](apidocs/unittest2.html#JUnitOutputFormatter).
- `--console`: Force console output formatter ([`ConsoleOutputFormatter`](apidocs/unittest2.html#ConsoleOutputFormatter)).
- `--output-level:<level>` or `--output-level=<level>`: Set the [`OutputLevel`](apidocs/unittest2.html#OutputLevel). One of `VERBOSE`, `COMPACT`, `FAILURES`, `NONE`.
- `--verbose` or `-v`: Shortcut for `--output-level=VERBOSE`.

## Environment Variables

You can configure `unittest2` using environment variables. To maintain compatibility with the built-in `unittest` module, both `UNITTEST2_` and `NIMTEST_` prefixes are supported.

| Variable | Values | Description |
| :--- | :--- | :--- |
| `UNITTEST2_OUTPUT_LVL` | `VERBOSE`, `COMPACT`, `FAILURES`, `NONE` | Sets the default output verbosity. |
| `UNITTEST2_ABORT_ON_ERROR` | (any) | If defined, stops the test run immediately after the first failure. |
| `NIMTEST_COLOR` | `always`, `never` | Explicitly enables or disables colored output. |
| `NIMTEST_NO_COLOR` | (any) | If defined, disables colored output (unless `NIMTEST_COLOR` is set to `always`). |

### Compatibility Fallbacks

For seamless integration with existing tools and CI pipelines, `unittest2` also recognizes these standard Nim testing variables:

- `NIMTEST_OUTPUT_LVL`: Fallback for `UNITTEST2_OUTPUT_LVL`. Recognizes `PRINT_ALL` (VERBOSE), `PRINT_FAILURES` (FAILURES), and `PRINT_NONE` (NONE).
- `NIMTEST_ABORT_ON_ERROR`: Fallback for `UNITTEST2_ABORT_ON_ERROR`.

## Parameter Parsing Behavior

By default, `unittest2` parses the current process arguments automatically.

To disable this behavior (e.g., if your application needs to handle its own arguments):

```sh
nim c -d:unittest2DisableParamFiltering=true -r test.nim -- --your-app-args
```

Then you can call [`parseParameters`](apidocs/unittest2.html#parseParameters,openArray[string]) manually in your test harness if you still want `unittest2` to process some of the arguments.
