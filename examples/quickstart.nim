import unittest2

# A suite groups related tests and can share common setup/teardown code.
suite "math":
  setup:
    # Code inside setup runs before every single test in this suite.
    discard

  test "2 + 2 == 4":
    # 'check' verifies that a condition is true. 
    # If it fails, the test is marked as FAILED and the values are printed.
    check:
      1 + 1 == 2

  test "out of bounds raises":
    let xs = @[1, 2, 3]
    # 'expect' verifies that the code block raises a specific exception.
    # It is useful for testing error conditions.
    expect IndexDefect:
      discard xs[4]
