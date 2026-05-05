import ../../unittest2

suite "Sample tests":
  test "Failing test 1":
    check 1 == 0

  test "Failing test 2":
    check 0 == 1

  test "Passing test":
    check 1 == 1

  test "Skipped test":
    skip()
