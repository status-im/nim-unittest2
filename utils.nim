type
  Rlp* = object
    bytes*: seq[byte]
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

func rlpItem(input: openArray[byte], start = 0): RlpItem =
  let prefix = input[start]
  if prefix <= 0x7f:
    raiseAssert "FOO1"
  elif prefix <= 0xb7:
    let strLen = int(prefix - 0x80)
    (1 .. start + strLen, rlpBlob)
  else:
    (2 .. 178, rlpList)

func item(self: Rlp): RlpItem =
  rlpItem(self.bytes, self.position)

func rlpFromBytes*(data: openArray[byte]): Rlp =
  Rlp(bytes: @data, position: 0)

func isList*(self: Rlp): bool =
  self.bytes[self.position] >= byte(0xc0)

func toBytes*(self: Rlp): seq[byte] =
  @(self.bytes.view(item(self).payload))

func listElem*(self: Rlp, i: int): Rlp =
  let item = self.item()
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
  self.bytes.toOpenArray(self.position, 1)
