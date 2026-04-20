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

`unittest2` follows the same core structure as `unittest`:

- Import `unittest2`.
- Define test cases in [`test`](apidocs/unittest2.html#test.t,string,untyped) blocks.
- Group related tests with [`suite`](apidocs/unittest2.html#suite.t,string,untyped).
- Use `setup` and `teardown` to define code that runs before and after each test.

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
