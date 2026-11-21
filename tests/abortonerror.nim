import ../unittest2

suite "abort":
  test "passing":
    check(1 + 1 == 2)

  test "failing require":
    require(1 + 1 == 3)

  test "never reached":
    check(true)
