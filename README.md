## Introduction

**`unittest2`** is a library for writing unit tests for your [Nim](https://nim-lang.org/) programs in the spirit of [xUnit](https://en.wikipedia.org/wiki/XUnit).

Features of `unittest2` include:

* [Parallel test execution](https://status-im.github.io/nim-unittest2/unittest2.html#running-tests-in-parallel)
* Test separation with each test running in its own procedure
* Strict exception handling with support for [exception tracking](https://nim-lang.org/docs/manual.html#effect-system-exception-tracking)

`unittest2` started as a [pull request](https://github.com/nim-lang/Nim/pull/9724) to evolve the [unittest](https://nim-lang.org/docs/unittest.html) module in Nim and has since grown into a separate library.

## Installing

```text
nimble install unittest2
```

or add a dependency in your `.nimble` file:

```text
requires "unittest2"
```

## Usage

See [unittest2.html](https://status-im.github.io/nim-unittest2/unittest2.html) documentation generated by `nim doc unittest2.nim`.

Create a file that contains your unit tests:

```nim
import unittest2

suite "Suites can be used to group tests":
  test "A test":
    check: 1 + 1 == 2
```

Compile and run the unit tests:
```bash
nim c -r test.nim
```

See the [tests](./tests) for more examples!

## Porting code from `unittest`

* Replace `import unittest` with `import unittest2`
* `unittest2` places each test in a separate `proc` which changes the way templates inside tests are interpreted - some code changes may be necessary

## Testing `unittest2`

```text
nimble test
```

## License

MIT

## Credits

- original author: Zahary Karadjov

- fork author: Ștefan Talpalaru \<stefantalpalaru@yahoo.com\>

- homepage: https://github.com/status-im/nim-unittest2
