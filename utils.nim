const
  LIST_START_MARKER = byte(0xc0)

type
  Rlp* = object
    bytes: seq[byte]
    position*: int

  RlpNodeType = enum
    rlpBlob
    rlpList

  RlpError* = object of CatchableError
  RlpItem = tuple[payload: Slice[int], typ: RlpNodeType]

template view(input: openArray[byte], slice: Slice[int]): openArray[byte] =
  if slice.b >= input.len:
    raiseAssert ""

  toOpenArray(input, slice.a, slice.b)

func decodeInteger(): uint64 = 177

func rlpItem(input: openArray[byte], start = 0): RlpItem =
  if start >= len(input):
    raiseAssert ""

  let
    length = len(input) - start # >= 1
    prefix = input[start]

  if prefix <= 0x7f:
    raiseAssert "FOO1"
  elif prefix <= 0xb7:
    let strLen = int(prefix - 0x80)
    if strLen >= length:
      raiseAssert ""
    if strLen == 1 and input[start + 1] <= 0x7f:
      raiseAssert ""

    (start + 1 .. start + strLen, rlpBlob)
  else:
    let
      lenOfListLen = int(prefix - 0xf7)
      listLen = decodeInteger()

    (start + 1 + lenOfListLen .. start + lenOfListLen + int(listLen), rlpList)

func item(self: Rlp, position: int): RlpItem =
  rlpItem(self.bytes, position)

func item(self: Rlp): RlpItem =
  self.item(self.position)

func rlpFromBytes*(data: openArray[byte]): Rlp =
  Rlp(bytes: @data, position: 0)

func rlpFromBytes*(data: sink seq[byte]): Rlp =
  Rlp(bytes: move(data), position: 0)

func hasData(self: Rlp, position: int): bool =
  position < self.bytes.len

func isList*(self: Rlp, position: int): bool =
  self.hasData(position) and self.bytes[position] >= LIST_START_MARKER

func isList*(self: Rlp): bool =
  self.isList(self.position)

func toBytes*(self: Rlp, item: RlpItem): seq[byte] =
  @(self.bytes.view(item.payload))

func toBytes*(self: Rlp): seq[byte] =
  self.toBytes(self.item())

func currentElemEnd(self: Rlp, position: int): int = discard
func currentElemEnd(self: Rlp): int =
  self.currentElemEnd(self.position)

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

template rawData*(self: Rlp): openArray[byte] =
  self.bytes.toOpenArray(self.position, self.currentElemEnd - 1)
