import unittest2, std/strutils

proc parsePort(s: string): int =
  let p = parseInt(s)
  if p < 1 or p > 65535:
    raise newException(ValueError, "port out of range")
  p

suite "parsePort":
  test "valid values":
    # A collection of inputs and expected outputs
    let cases = [("1", 1), ("80", 80), ("443", 443), ("65535", 65535)]
    for (input, expected) in cases:
      check parsePort(input) == expected

  test "invalid values raise":
    # A collection of inputs that should cause a ValueError
    let inputs = ["0", "70000", "-1", "abc"]
    for input in inputs:
      expect ValueError:
        discard parsePort(input)
