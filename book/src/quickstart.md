# Quickstart

`unittest2` is a Nim module for writing automated tests.

It is mostly compatible with Nim's built-in [unittest](https://nim-lang.org/docs/unittest.html), while adding better output, flexible reporting, and advanced execution features like test discovery.

- [API Index →](apidocs/theindex.html)
- [Repository →](https://github.com/status-im/nim-unittest2)
- [Issues →](https://github.com/status-im/nim-unittest2/issues)

## Installation

```shell
$ nimble install -y unittest2
```

Add `unittest2` to your `.nimble` file:

```nim
requires "unittest2"
```

## First Test File

`unittest2` follows this test structure:

- **Module**. A .nim file that has an `import unittest2` in it, usually sits in `tests` directory of your project, and is named starting with a `t` by convention, e.g. `tmath.nim`. A module holds the tests that cover a particular topic or a module in your project.
- **Suite**. Defined with [`suite`](apidocs/unittest2.html#suite.t,string,untyped) block, it's a group of related tests. In he `tmath.nim` example, you could have a suite like "Overflow checks" and "Basic arithmetic."
- **Test case**. A single atomic check under a [`test`](apidocs/unittest2.html#test.t,string,untyped) block. In `tmath.nim` suite "Basic arithmetic," you could have tests like "Addition"and "Subtraction."

Aside from `test`, you can use `setup` and `teardown` blocks inside `suite`.

`setup` block defines the code that runs before each test.

`teardown` block defines the code that runs after each test.

Create `test.nim`:

```nim
{{#shiftinclude auto:../../examples/quickstart.nim}}
```

Compile and run:

```sh
nim c -r test.nim
```

This exits with `0` on success and `1` when any test fails.

See command options:

```sh
# Running the compiled binary directly
./test --help
```

## Compilation Flags

`unittest2` behavior can be customized using compilation flags (`-d:flag`).

A detailed list of all available flags, including execution modes and advanced features, can be found on the **[Compilation Flags](./compilation-flags.md)** page.

### Compile-Time Testing

One of `unittest2` standout features is the ability to run tests during compilation. Use [`staticTest`](apidocs/unittest2.html#staticTest.t,string,untyped), [`runtimeTest`](apidocs/unittest2.html#runtimeTest.t,string,untyped), or [`dualTest`](apidocs/unittest2.html#dualTest.t,string,untyped) for explicit control over when your tests execute.

You can also opt into compile-time execution globally for all `test` blocks:

```sh
nim c -d:unittest2Static=true test.nim
```

## Contributing and Testing This Repository

- [Open an issue](https://github.com/status-im/nim-unittest2/issues/new)
- [Existing issues](https://github.com/status-im/nim-unittest2/issues)
- [Pull requests](https://github.com/status-im/nim-unittest2/pulls)

Run tests locally:

```text
# this calls a task in "config.nims"
nim test
```

Build the documentation locally:

```sh
# Build both the book and apidocs
nim docs

# Build only the book
nim book

# Build only the apidocs
nim apidocs
```

Navigate the generated docs:

- [API docs index](apidocs/theindex.html)

Tip: start from the API index, then jump to symbols in `unittest2.nim` for implementation details.
