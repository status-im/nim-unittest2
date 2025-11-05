{.define: unittest2Static.}

import ../unittest2

suite "VM test":
  test "Simple test":
    checkpoint "simple test CP"
    check 1 == 1

  test "Nested test":
    test "inner test":
      checkpoint "nested test CP"
      check 1 == 1
