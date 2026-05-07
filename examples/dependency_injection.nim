import unittest2

type
  Mailer = ref object of RootObj
  RealMailer = ref object of Mailer
  FakeMailer = ref object of Mailer
    sentTo: seq[string]

method send(m: Mailer, userId: string) {.base.} =
  discard

method send(m: RealMailer, userId: string) =
  # Real external I/O in production
  discard

method send(m: FakeMailer, userId: string) =
  m.sentTo.add(userId)

proc activateUser(userId: string, mailer: Mailer): bool =
  if userId.len == 0:
    return false
  mailer.send(userId)
  true

suite "activateUser":
  var fake: FakeMailer

  setup:
    fake = FakeMailer(sentTo: @[])

  test "sends welcome mail for valid id":
    check activateUser("u-123", fake)
    check fake.sentTo == @["u-123"]

  test "rejects empty user id":
    check activateUser("", fake) == false
    check fake.sentTo.len == 0
