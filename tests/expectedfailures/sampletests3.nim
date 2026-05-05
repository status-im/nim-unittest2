import ../../unittest2

suite "Sample tests":
  test "Passing test":
    check 1 == 1

  test "Failing test":
    check 1 == 0

  test "Skipped test":
    skip()
