import unittest2

proc eventuallySucceeds(maxAttempts: int): bool =
  # Logic that might fail a few times
  false

suite "retry logic":
  test "fails with descriptive checkpoint":
    for i in 1 .. 3:
      checkpoint "Attempt number " & $i
      check eventuallySucceeds(i)
