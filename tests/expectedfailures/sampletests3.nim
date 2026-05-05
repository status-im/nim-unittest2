import ../../unittest2

suite "Sample tests":
  test "Failing test":
    let x = 123
    check x == 456

  test "Passing test":
    let x = 123
    check x == 123

  test "Skipped test":
    skip()
