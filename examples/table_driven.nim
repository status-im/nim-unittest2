import unittest2, std/strutils

proc parsePort(s: string): int =
  let p = parseInt(s)
  if p < 1 or p > 65535:
    raise newException(ValueError, "port out of range")
  p

suite "parsePort":
  test "valid values":
    # Use a loop inside test to check multiple inputs
    for c in ["1", "80", "443", "65535"]:
      check parsePort(c) > 0

  test "invalid values raise":
    for c in ["0", "70000", "-1", "abc"]:
      expect ValueError:
        discard parsePort(c)
