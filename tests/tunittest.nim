discard """
  output: '''[Suite] suite with only teardown

[Suite] suite with only setup

[Suite] suite with none

[Suite] suite with both

[Suite] bug #4494

[Suite] bug #5571

[Suite] bug #5784

[Suite] test suite

[Suite] test name filtering

'''
"""

import ../unittest2, sequtils
from std/exitprocs import nil
import std/[osproc, strutils]

#------------------------------------------------------------------------------
# Tests using backdoors
# This kind of tests should be executed first
#------------------------------------------------------------------------------

suite "PR #35":
  setup:
    # ensure teardown is called at the end
    doAssert(true)

  teardown:
    if testStatusIMPL != TestStatus.FAILED:
      testStatusIMPL = TestStatus.FAILED
      exitProcs.setProgramResult(QuitFailure)
      debugEcho "PR #35 test FAILED"
    else:
      testStatusIMPL = TestStatus.OK
      exitProcs.setProgramResult(QuitSuccess)

  test "something":
    # emulate exception
    raise newException(ValueError, "error")

suite "PR #36":
  # ensure variables declared in setup section
  # still accessible from teardown section
  setup:
    var server: ref string

  teardown:
    if server.isNil.not:
      testStatusIMPL = TestStatus.OK

  test "test body":
    server = new(string)
    server[] = "hello"

suite "checks in `proc` should work":
  teardown:
    require testStatusIMPL == TestStatus.Failed
    testStatusIMPL = TestStatus.OK
    exitProcs.setProgramResult(QuitSuccess)

  proc checkFalse() = check false

  test "test":
    checkFalse()

#------------------------------------------------------------------------------
# Regular tests
#------------------------------------------------------------------------------

proc doThings(spuds: var int): int =
  spuds = 24
  return 99
test "#964":
  var spuds = 0
  check doThings(spuds) == 99
  check spuds == 24


from strutils import toUpperAscii, parseInt
test "#1384":
  check(@["hello", "world"].map(toUpperAscii) == @["HELLO", "WORLD"])


import options
test "unittest typedescs":
  check(none(int) == none(int))
  check(none(int) != some(1))

test "unittest multiple requires":
  require(true)
  require(true)

import random
proc defectiveRobot() =
  randomize()
  case rand(1..4)
  of 1: raise newException(OSError, "CANNOT COMPUTE!")
  of 2: discard parseInt("Hello World!")
  of 3: raise newException(IOError, "I can't do that Dave.")
  else: assert 2 + 2 == 5
runtimeTest "unittest expect":
  expect IOError, OSError, ValueError, AssertionDefect:
    defectiveRobot()
  expect CatchableError:
    if true: raise CatchableError.newException("Okay")
  expect CatchableError, ValueError:
    if true: raise CatchableError.newException("Okay")
  expect Defect:
    if true: raise Defect.newException("Okay")
  expect Defect, CatchableError:
    if true: raise Defect.newException("Okay")

var
  a = 1
  b = -1
  c = 1

#unittests are sequential right now
suite "suite with only teardown":
  teardown:
    b = 2

  runtimeTest "unittest with only teardown 1":
    check a == c

  runtimeTest "unittest with only teardown 2":
    check b > a

suite "suite with only setup":
  setup:
    var testVar {.used.} = "from setup"

  runtimeTest "unittest with only setup 1":
    check testVar == "from setup"
    check b > a
    b = -1

  runtimeTest "unittest with only setup 2":
    check b < a

suite "suite with none":
  runtimeTest "unittest with none":
    check b < a

suite "suite with both":
  setup:
    a = -2

  teardown:
    c = 2

  runtimeTest "unittest with both 1":
    check b > a

  runtimeTest "unittest with both 2":
    check c == 2

suite "bug #4494":
    test "Uniqueness check":
      var tags = @[1, 2, 3, 4, 5]
      check:
        allIt(0..3, tags[it] != tags[it + 1])

suite "bug #5571":
  test "can define gcsafe procs within tests":
    proc doTest {.gcsafe.} =
      let line = "a"
      check: line == "a"
    doTest()

suite "bug #5784":
  test "`or` should short circuit":
    type Obj = ref object
      field: int
    var obj: Obj
    check obj.isNil or obj.field == 0

suite "PR #59":
  staticTest "Nested static test":
    staticTest "inner test":
      checkpoint "nested static test CP"
      check 1 == 1

  dualTest "Nested dual test":
    dualTest "inner test":
      checkpoint "nested dual test CP"
      check 1 == 1
 
  staticTest "Nested test":
    template testInStatic(): untyped =
      static:
        test "inner test":
          check 1 == 1
    check(not compiles(testInStatic()))

type
    SomeType = object
        value: int
        children: seq[SomeType]

# bug #5252

proc `==`(a, b: SomeType): bool =
    return a.value == b.value

suite "test suite":
    test "test":
        let a = SomeType(value: 10)
        let b = SomeType(value: 10)

        check(a == b)

    test "openArray":
      let
        a = [1, 2, 3]
        b = [2, 2, 3]
      check: # Ensure check can capture openArray without assigning to local
        a.toOpenArray(1, 2) == b.toOpenArray(1, 2)

when defined(testing):
  suite "test name filtering":
    test "test name":
      check matchFilter("suite1", "foo", "")
      check matchFilter("suite1", "foo", "foo")
      check matchFilter("suite1", "foo", "::")
      check matchFilter("suite1", "foo", "*")
      check matchFilter("suite1", "foo", "::foo")
      check matchFilter("suite1", "::foo", "::foo")

    test "test name - glob":
      check matchFilter("suite1", "foo", "f*")
      check matchFilter("suite1", "foo", "*oo")
      check matchFilter("suite1", "12345", "12*345")
      check matchFilter("suite1", "q*wefoo", "q*wefoo")
      check false == matchFilter("suite1", "foo", "::x")
      check false == matchFilter("suite1", "foo", "::x*")
      check false == matchFilter("suite1", "foo", "::*x")
      #  overlap
      check false == matchFilter("suite1", "12345", "123*345")
      check matchFilter("suite1", "ab*c::d*e::f", "ab*c::d*e::f")

    test "suite name":
      check matchFilter("suite1", "foo", "suite1::")
      check false == matchFilter("suite1", "foo", "suite2::")
      check matchFilter("suite1", "qwe::foo", "qwe::foo")
      check matchFilter("suite1", "qwe::foo", "suite1::qwe::foo")

    test "suite name - glob":
      check matchFilter("suite1", "foo", "::*")
      check matchFilter("suite1", "foo", "*::*")
      check matchFilter("suite1", "foo", "*::foo")
      check false == matchFilter("suite1", "foo", "*ite2::")
      check matchFilter("suite1", "q**we::foo", "q**we::foo")
      check matchFilter("suite1", "a::b*c::d*e", "a::b*c::d*e")

# Also supposed to work outside tests:
check 1 == 1

suite "break should works inside test body":
  var number: int = 0
  test "step one":
    number = 2
  test "step two":
    if number == 2:
      break
    number = 3
  test "step three":
    check number == 2

suite "list tests":
  test "should list tests when `-d:unittest2ListTests` is passed":    

    let (output, exitCode) = execCmdEx("nim c -d:unittest2ListTests -r tests/sampletests.nim")
    
    check exitCode == 0
    check count(output, "Suite:") == 3
    check count(output, "Test:") == 16
    check count(output, "File:") == 16
    check count(output, "Hello") == 0