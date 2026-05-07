# unittest2

**`unittest2`** is a Nim library for writing automated tests. It provides a familiar syntax similar to the built-in `unittest` module but includes enhanced reporting, advanced execution modes, and first-class support for compile-time testing.

## Key Features

* **Clean Output**: Optimized for both human readability and CI pipelines.
* **Isolated Execution**: Each test runs in its own procedure.
* **Strict Exceptions**: Fully compatible with Nim's [exception tracking system](https://nim-lang.org/docs/manual.html#effect-system-exception-tracking).
* **Tooling Integration**: Generates [JUnit](https://junit.org/)-compatible XML reports for CI/CD workflows.
* **Compile-Time Tests**: Run your tests in the Nim VM during compilation to verify code logic early.
* **Advanced Execution**: Supports a two-phase "Collect-and-Run" model for better progress tracking and test listing.

## Compatibility

`unittest2` is designed to be mostly compatible with the standard library's `unittest` module. In many cases, you can simply replace `import unittest` with `import unittest2` to get started.

## Installing

```sh
nimble install unittest2
```

Or add it to your `.nimble` file:

```nim
requires "unittest2"
```

## Usage

For detailed instructions and advanced patterns, see the official documentation:

- **[User Guide and Quickstart](https://status-im.github.io/nim-unittest2/)**
- **[Examples](https://status-im.github.io/nim-unittest2/examples.html)**
- **[API Documentation](https://status-im.github.io/nim-unittest2/apidocs/unittest2.html)**

You can also explore the [tests](./tests) and [examples](./examples) directories in this repository for more inspiration.

## License

MIT

## Credits

- Original author: Zahary Karadjov
- Initial fork author: Ștefan Talpalaru
- Current maintainer: [Status R&D](https://status.im)
- Homepage: [https://github.com/status-im/nim-unittest2](https://github.com/status-im/nim-unittest2)
