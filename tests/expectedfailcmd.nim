import ../unittest2

when defined(expectedFailureHarness):
  suite "xfail-suite":
    test "known-failure":
      let x = 123
      check x == 456

    test "unexpected-pass":
      let x = 123
      check x == 123

    test "ordinary-pass":
      let x = 123
      check x == 123

    test "ordinary-failure":
      let x = 123
      check x == 456

    test "skipped-case":
      skip()
else:
  test "helper-builds":
    check true
