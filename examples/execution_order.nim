import unittest2

# In Collect-and-Run mode (-d:unittest2Compat=false), 
# execution is split into Discovery and Execution phases.

suite "execution order":
  # This code runs during the Discovery phase.
  echo "1. Discovery phase: suite body runs"

  setup:
    # This runs during the Execution phase, before each test.
    echo "3. Execution phase: setup runs before each test"

  test "example test":
    # This runs during the Execution phase.
    echo "4. Execution phase: test body runs"

  # This also runs during the Discovery phase.
  echo "2. Discovery phase: suite body continues"
