import
  ./secp256k1

proc getAccountProof(): seq[seq[byte]] =
  let accProof = (@[@[248'u8, 177, 160, 129, 136, 149, 159, 31, 252, 215, 147, 250, 28, 74, 127, 243, 250, 52, 43, 117, 253, 206, 185, 136, 179, 23, 70, 75, 37, 169, 40, 81, 139, 29, 85, 128, 160, 166, 92, 64, 107, 103, 166, 196, 94, 147, 183, 129, 212, 225, 123, 145, 5, 105, 226, 248, 243, 193, 9, 179, 25, 169, 168, 252, 112, 223, 115, 37, 41, 128, 160, 212, 49, 8, 53, 235, 82, 204, 21, 4, 254, 38, 152, 121, 245, 19, 127, 137, 243, 84, 79, 146, 233, 16, 10, 222, 19, 147, 71, 196, 38, 5, 6, 128, 128, 128, 128, 128, 160, 194, 171, 71, 247, 21, 130, 2, 59, 51, 27, 110, 162, 104, 73, 163, 174, 229, 43, 72, 28, 43, 246, 103, 5, 27, 137, 130, 21, 106, 1, 201, 49, 128, 128, 128, 128, 160, 198, 39, 225, 154, 149, 227, 112, 175, 149, 233, 24, 177, 216, 49, 194, 32, 227, 116, 223, 82, 202, 202, 87, 37, 129, 92, 198, 14, 198, 134, 161, 216, 128], @[248, 105, 160, 50, 122, 115, 116, 151, 33, 15, 124, 194, 244, 100, 227, 191, 255, 173, 239, 169, 128, 97, 147, 204, 223, 135, 50, 3, 205, 145, 200, 211, 234, 181, 24, 184, 70, 248, 68, 128, 128, 160, 86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47]], true)
  accProof[0]

import ./utils

type
  DbTransaction = ref object
    parentTransaction: DbTransaction

import std/tables

proc get(t: var DbTransaction, key: openArray[byte]) =
  let key = @key

  while t != nil:
    discard getOrDefault(default(Table[seq[byte], int]), key)
    t = t.parentTransaction

import std/macros

macro fillArrayOfBlockNumberBasedForkOptionals(conf, tmp: typed): untyped =
  result = newStmtList()
  for _, _ in ["homesteadBlock"]: discard

template toSeq(s: not iterator): untyped =
  type OutType = typeof(items(s))
  var i = 0
  var result = newSeq[OutType](s.len)
  for it in s:
    result[i] = it
    i += 1
  result

type
  NibblesBuf = object
    iend: uint8

func len(r: NibblesBuf): int =
  int(r.iend)

type
  NextNodeKind = enum
    EmptyValue
    HashNode
    ValueNode

  NextNodeResult = object
    case kind: NextNodeKind
    of EmptyValue:
      discard
    of HashNode:
      nextNodeHash: array[32, byte]
      restOfTheKey: NibblesBuf
    of ValueNode:
      value: seq[byte]

proc getListElem(rlp: Rlp, idx: int): Result[Rlp, string] =
  ok(rlp.listElem(idx))

proc blobBytes(rlp: Rlp): Result[seq[byte], string] =
  try:
    ok(rlp.toBytes)
  except RlpError as e:
    err(e.msg)

proc getRawRlpBytes(rlp: Rlp): Result[seq[byte], string] =
  ok(toSeq(rlp.rawData))

func copyFrom(): array[32, byte] = discard

proc getNextNode(nodeRlp: Rlp, key: NibblesBuf): Result[NextNodeResult, string] =
  var currNode = nodeRlp
  var restKey = key

  template handleNextRef(nextRef: Rlp, keyLen: int) =
    if nextRef.isList:
      let rawBytes = ?nextRef.getRawRlpBytes()
      if len(rawBytes) > 32:
        return err("")
      else:
        currNode = nextRef
    else:
      let nodeBytes = ?nextRef.blobBytes()
      if len(nodeBytes) == 32:
        return ok(
          NextNodeResult(kind: HashNode, nextNodeHash: copyFrom())
        )
      elif len(nodeBytes) == 0:
        return ok(NextNodeResult(kind: EmptyValue))
      else:
        return err("")
  while true:
    if len(restKey) == 0:
      let value = ?currNode.getListElem(16)
      let _ = ?value.blobBytes()
      return ok(NextNodeResult(kind: ValueNode))
    else:
      let nextRef = ?currNode.getListElem(0)

      handleNextRef(nextRef, 1)

proc verifyProof(foo0: seq[byte]) =
  var currentKey = NibblesBuf(iend: 64)

  while true:
    var t = new DbTransaction
    t.get([])
    let node = foo0
    let next = getNextNode(rlpFromBytes(node), currentKey).vResultPrivate
    case next.kind
    of EmptyValue, ValueNode:
      return
    of HashNode:
      currentKey = next.restOfTheKey

let _ = {"a": 0}.toTable()
verifyProof(getAccountProof()[0])
import ./unittest2
