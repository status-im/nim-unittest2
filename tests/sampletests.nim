import ../unittest2

suite "Sample Tests":
  test "Sample Test":
    check(1 == 1)

test "Global test":
  check(1 == 1)

suite "Sample Suite":
  test "Sample Test":
    check(1 == 1)

  test "Sample Test 2":
    check(1 == 1)

  test "Sample Test 3":
    check(1 == 1)

test "another global test":
  check(1 == 1)

for i in 0..<10:
 test "test" & $i:
    echo "hello"