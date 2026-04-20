# Porting from std/unittest

Most test code can be ported from `std/unittest` with minimal changes, but there are important semantic differences when using certain execution modes.

## Quick Porting Checklist

1.  Replace `import unittest` with `import unittest2`.
2.  Keep your existing [`suite`](apidocs/unittest2.html#suite.t,string,untyped), [`test`](apidocs/unittest2.html#test.t,string,untyped), [`check`](apidocs/unittest2.html#check.m,untyped), and [`expect`](apidocs/unittest2.html#expect.m,varargs[typed],untyped) blocks.
3.  Reduce dependencies on global initialization order.

## Execution Order and Discovery

The most significant difference occurs when using **Collect-and-Run Mode** (`-d:unittest2Compat=false`). Unlike `std/unittest`, which executes tests as they are encountered, `unittest2` first "discovers" all tests before running any of them.

Code placed directly inside a `suite` block (but outside of `test` or `setup`) will execute during this discovery phase.

```nim
{{#shiftinclude auto:../../examples/execution_order.nim}}
```

To maintain consistent behavior between modes, always place initialization logic inside `setup` and cleanup logic inside `teardown`.

## Strategy for Large Codebases

- **Migrate incrementally:** Port one package or module at a time.
- **Use Compatibility Mode initially:** Keep `-d:unittest2Compat=true` (the default) to match the single-pass execution of `std/unittest`.
- **Switch to Collect-and-Run Mode:** Once your tests are independent and free of side effects in the `suite` body, disable compatibility mode to benefit from better reporting and advanced filtering.
