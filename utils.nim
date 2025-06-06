const
  BLOB_START_MARKER = byte(0x80)
  LIST_START_MARKER = byte(0xc0)
  THRESHOLD_LIST_LEN = 56

type
  Rlp* = object
    bytes: seq[byte]
    position*: int

  RlpNodeType = enum
    rlpBlob
    rlpList

  RlpError* = object of CatchableError
  MalformedRlpError* = object of RlpError
  UnsupportedRlpError* = object of RlpError
  RlpTypeMismatch* = object of RlpError

  RlpItem = tuple[payload: Slice[int], typ: RlpNodeType]

template view(input: openArray[byte], position: int): openArray[byte] =
  if position >= input.len:
    raiseOutOfBounds()

  toOpenArray(input, position, input.high())

template view(input: openArray[byte], slice: Slice[int]): openArray[byte] =
  if slice.b >= input.len:
    raiseAssert ""

  toOpenArray(input, slice.a, slice.b)

func decodeInteger(input: openArray[byte]): uint64 =
  if input.len > sizeof(uint64):
    raiseAssert ""

  if input.len == 0:
    0
  else:
    if input[0] == 0:
      raiseAssert ""

    var v: uint64
    for b in input:
      v = (v shl 8) or uint64(b)
    v

func rlpItem(input: openArray[byte], start = 0): RlpItem =
  if start >= len(input):
    raiseAssert ""

  let
    length = len(input) - start # >= 1
    prefix = input[start]

  if prefix <= 0x7f:
    (start .. start, rlpBlob)
  elif prefix <= 0xb7:
    let strLen = int(prefix - 0x80)
    if strLen >= length:
      raiseAssert ""
    if strLen == 1 and input[start + 1] <= 0x7f:
      raiseAssert ""

    (start + 1 .. start + strLen, rlpBlob)
  elif prefix <= 0xbf:

    let
      lenOfStrLen = int(prefix - 0xb7)
      strLen = decodeInteger(input.view(start + 1 .. start + lenOfStrLen))

    if strLen < THRESHOLD_LIST_LEN:
      raiseAssert ""

    if strLen >= uint64(length - lenOfStrLen):
      raiseAssert ""

    (start + 1 + lenOfStrLen .. start + lenOfStrLen + int(strLen), rlpBlob)
  elif prefix <= 0xf7:
    let listLen = int(prefix - 0xc0)
    if listLen >= length:
      raiseAssert ""

    (start + 1 .. start + listLen, rlpList)
  else:
    let
      lenOfListLen = int(prefix - 0xf7)
      listLen = decodeInteger(input.view(start + 1 .. start + lenOfListLen))

    if listLen < THRESHOLD_LIST_LEN:
      raiseAssert ""

    if listLen >= uint64(length - lenOfListLen):
      raiseAssert ""

    (start + 1 + lenOfListLen .. start + lenOfListLen + int(listLen), rlpList)

func item(self: Rlp, position: int): RlpItem =
  rlpItem(self.bytes, position)

func item(self: Rlp): RlpItem =
  self.item(self.position)

func rlpFromBytes*(data: openArray[byte]): Rlp =
  Rlp(bytes: @data, position: 0)

func rlpFromBytes*(data: sink seq[byte]): Rlp =
  Rlp(bytes: move(data), position: 0)

const zeroBytesRlp* = Rlp()

func hasData*(self: Rlp, position: int): bool =
  position < self.bytes.len

func hasData*(self: Rlp): bool =
  self.hasData(self.position)

func isEmpty*(self: Rlp): bool =
  self.hasData() and (
    self.bytes[self.position] == BLOB_START_MARKER or
    self.bytes[self.position] == LIST_START_MARKER
  )

func isList*(self: Rlp, position: int): bool =
  self.hasData(position) and self.bytes[position] >= LIST_START_MARKER

func isList*(self: Rlp): bool =
  self.isList(self.position)

func toInt(self: Rlp, item: RlpItem, IntType: type): IntType =
  mixin maxBytes, to
  if item.typ != rlpBlob:
    raiseAssert ""

  if item.payload.len > maxBytes(IntType):
    raiseAssert ""

  for b in self.bytes.view(item.payload):
    result = (result shl 8) or IntType(b)

func toInt(self: Rlp, IntType: type): IntType =
  self.toInt(self.item(), IntType)

func toBytes*(self: Rlp, item: RlpItem): seq[byte] =
  if item.typ != rlpBlob:
    raiseAssert ""

  @(self.bytes.view(item.payload))

func toBytes*(self: Rlp): seq[byte] =
  self.toBytes(self.item())

func currentElemEnd(self: Rlp, position: int): int =
  let item = self.item(position).payload
  item.b + 1

func currentElemEnd(self: Rlp): int =
  self.currentElemEnd(self.position)

template iterateIt(self: Rlp, position: int, body: untyped) =
  let item = self.item(position)
  doAssert item.typ == rlpList
  var it {.inject.} = item.payload.a
  let last = item.payload.b
  while it <= last:
    let subItem = rlpItem(self.bytes.view(it .. last)).payload
    body
    it += subItem.b + 1

func listElem*(self: Rlp, i: int): Rlp =
  let item = self.item()
  doAssert item.typ == rlpList

  var
    i = i
    start = item.payload.a
    payload = rlpItem(self.bytes.view(start .. item.payload.b)).payload

  while i > 0:
    start += payload.b + 1
    payload = rlpItem(self.bytes.view(start .. item.payload.b)).payload
    dec i

  rlpFromBytes self.bytes.view(start .. start + payload.b)

func listLen*(self: Rlp): int =
  if not self.isList():
    return 0

  self.iterateIt(self.position):
    inc result

template rawData*(self: Rlp): openArray[byte] =
  self.bytes.toOpenArray(self.position, self.currentElemEnd - 1)
