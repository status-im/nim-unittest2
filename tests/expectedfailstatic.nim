import ../unittest2

when defined(expectedFailureHarness):
  suite "xfail-suite":
    test "unexpected-pass":
      let x = 123
      check x == 123

    test "known-failure":
      let x = 123
      check x == 456

    test "ordinary-pass":
      let x = 123
      check x == 123

    test "skipped-case":
      skip()
else:
  test "helper-builds":
    check true
