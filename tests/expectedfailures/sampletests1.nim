import ../../unittest2

suite "Sample tests":
  test "Failing test 1":
    let x = 123
    check x == 456

  test "Failing test 2":
    let x = 789
    check x == 999

  test "Passing test":
    let x = 123
    check x == 123

  test "Skipped test":
    skip()
