import unittest2

type FakeDb = object
  connected: bool
  writes: int

var db: FakeDb

suite "database repository":
  setup:
    db.connected = true
    db.writes = 0

  teardown:
    db.connected = false

  test "write increments counter":
    check db.connected
    db.writes.inc
    check db.writes == 1

  test "state is reset":
    # db.writes will be 0 here because setup ran again
    check db.writes == 0
