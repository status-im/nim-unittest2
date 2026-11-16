import unittest2

# Demonstrates the compact success dot compression (ANSI mode only) -
# run with: nim c -r examples/compact_dots.nim -d:unittest2CompactDots=true --output-level=COMPACT
#
# The number of consecutive successful tests is rendered in base 10 with
# the progression `.:-=+*#%@` (units are dots, tens colons, hundreds
# dashes, ...), so a long run of passing tests stays on one short line:
#
#   many  -                                   100 passing tests
#   few   ...F..                              dots and the failure
#                                             marker stay in place,
#                                             the counter restarts

suite "many":
  for i in 1 .. 100:
    test "t" & $i:
      check true

suite "few":
  test "a":
    check true
  test "b":
    check true
  test "c":
    check true
  test "boom":
    check false
  test "d":
    check true
  test "e":
    check true
