import ../../unittest2

suite "Sample tests":
  test "Passing test":
    let x = 123
    check x == 123

  test "Failing test":
    let x = 123
    check x == 456

  test "Skipped test":
    skip()
