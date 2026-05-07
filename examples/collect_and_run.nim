import unittest2

# This file demonstrates patterns optimized for Collect-and-Run mode
# (-d:unittest2Compat=false)

suite "collect-and-run optimized suite":
  # 1. Declarations inside the suite are safe, but avoid complex
  # logic or side effects here, as they run during the Discovery phase.
  var counter: int

  setup:
    # 2. Always initialize or reset state in setup.
    # This runs during the Execution phase, just before each test.
    counter = 10

  test "first increment":
    counter.inc
    check counter == 11

  test "independent reset":
    # counter is 10 again because setup ran before this test
    counter.inc
    check counter == 11

  # 3. Code here would run during Discovery.
  # Use teardown for post-test cleanup.
  teardown:
    discard
