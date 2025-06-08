proc fromHex(a: string): seq[byte] =
  var buf = newSeq[byte](len(a) shr 1)

type
  FixedBytes[N: static int] = array[N, byte]

func copyFrom(v: openArray[byte], start = 0): FixedBytes[32] =
  if v.len > start:
    let n = min(32, v.len - start)

import
  ./secp256k1

proc makeProof(
      ): Result[(seq[seq[byte]],bool), int] =
  result = ok((@[@[248'u8, 177, 160, 129, 136, 149, 159, 31, 252, 215, 147, 250, 28, 74, 127, 243, 250, 52, 43, 117, 253, 206, 185, 136, 179, 23, 70, 75, 37, 169, 40, 81, 139, 29, 85, 128, 160, 166, 92, 64, 107, 103, 166, 196, 94, 147, 183, 129, 212, 225, 123, 145, 5, 105, 226, 248, 243, 193, 9, 179, 25, 169, 168, 252, 112, 223, 115, 37, 41, 128, 160, 212, 49, 8, 53, 235, 82, 204, 21, 4, 254, 38, 152, 121, 245, 19, 127, 137, 243, 84, 79, 146, 233, 16, 10, 222, 19, 147, 71, 196, 38, 5, 6, 128, 128, 128, 128, 128, 160, 194, 171, 71, 247, 21, 130, 2, 59, 51, 27, 110, 162, 104, 73, 163, 174, 229, 43, 72, 28, 43, 246, 103, 5, 27, 137, 130, 21, 106, 1, 201, 49, 128, 128, 128, 128, 160, 198, 39, 225, 154, 149, 227, 112, 175, 149, 233, 24, 177, 216, 49, 194, 32, 227, 116, 223, 82, 202, 202, 87, 37, 129, 92, 198, 14, 198, 134, 161, 216, 128], @[248, 105, 160, 50, 122, 115, 116, 151, 33, 15, 124, 194, 244, 100, 227, 191, 255, 173, 239, 169, 128, 97, 147, 204, 223, 135, 50, 3, 205, 145, 200, 211, 234, 181, 24, 184, 70, 248, 68, 128, 128, 160, 86, 232, 31, 23, 27, 204, 85, 166, 255, 131, 69, 230, 146, 192, 248, 110, 91, 72, 224, 27, 153, 108, 173, 192, 1, 98, 47]], true))

proc proof(
      ): Result[(seq[seq[byte]],bool), int] =
  let rc = makeProof().valueOr:
    return err(0)

  ok(rc)

proc getAccountProof(): seq[seq[byte]] =
  let accProof = proof().valueOr:
    raiseAssert "Failed to get account proof: " & $error

  accProof[0]

type
  Hash32 = distinct FixedBytes[32]

func fromHex(_: type Hash32, s: openArray[char]): Hash32 {.raises: [ValueError].} = discard

type
  PrivateKey = distinct SkSecretKey

func fromHex(T: type PrivateKey, data: string) = discard
import ./utils, std/tables

type
  DbTransaction = ref object
    parentTransaction: DbTransaction

proc put(db: var Table[seq[byte], int], key: openArray[byte]) =
  db.withValue(@key, _) do:
    discard
  do:
    discard

proc get(t: var DbTransaction, key: openArray[byte]) =
  let key = @key

  while t != nil:
    discard getOrDefault(default(Table[seq[byte], int]), key)
    t = t.parentTransaction

type
  GenesisAlloc = Table[string, GenesisAccount]
  GenesisAccount = object

import std/macros

macro fillArrayOfBlockNumberBasedForkOptionals(conf, tmp: typed): untyped =
  result = newStmtList()
  for _, _ in ["homesteadBlock"]: discard

template toSeq(s: not iterator): untyped =
  #doAssert false  # hm, weird, it doesn't trigger
  type OutType = typeof(items(s))
  evalOnceAs(s2, s, compiles((let _ = s)))
  var i = 0
  var result = newSeq[OutType](s2.len)
  for it in s2:
    result[i] = it
    i += 1
  result

macro evalOnceAs(expAlias, exp: untyped,
                 letAssigneable: static[bool]): untyped =
  expectKind(expAlias, nnkIdent)
  var val = exp

  result = newStmtList()
  if exp.kind != nnkSym and letAssigneable:
    val = genSym()
    result.add(newLetStmt(val, exp))

  result.add(
    newProc(name = genSym(nskTemplate, $expAlias), params = [getType(untyped)],
      body = val, procType = nnkTemplateDef))

type
  NibblesBuf = object
    limbs: array[4, uint64]
    iend: uint8

func fromBytes(T: type NibblesBuf, bytes: openArray[byte]): T =
  result.iend = 64

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
      nextNodeHash: Hash32
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

proc getNextNode(nodeRlp: Rlp, key: NibblesBuf): Result[NextNodeResult, string] =
  var currNode = nodeRlp
  var restKey = key

  template handleNextRef(nextRef: Rlp, keyLen: int) =
    if nextRef.isList:
      let rawBytes = ?nextRef.getRawRlpBytes()
      if len(rawBytes) > 32:
        return err("Embedded node longer than 32 bytes")
      else:
        currNode = nextRef
    else:
      let nodeBytes = ?nextRef.blobBytes()
      if len(nodeBytes) == 32:
        return ok(
          NextNodeResult(
            kind: HashNode, nextNodeHash: Hash32(copyFrom(nodeBytes, 0))
          )
        )
      elif len(nodeBytes) == 0:
        return ok(NextNodeResult(kind: EmptyValue))
      else:
        return err("reference rlp blob should have 0 or 32 bytes")
  while true:
    block:
      if len(restKey) == 0:
        let value = ?currNode.getListElem(16)
        let bytes = ?value.blobBytes()
        return ok(NextNodeResult(kind: ValueNode, value: bytes))
      else:
        let nextRef = ?currNode.getListElem(0)

        handleNextRef(nextRef, 1)

proc verifyProof(key: openArray[byte], foo0: seq[byte]) =
  var currentKey = NibblesBuf.fromBytes(key)

  while true:
    var t = new DbTransaction
    t.get([])
    let node = foo0
    let next = getNextNode(rlpFromBytes(node), currentKey).vResultPrivate
    case next.kind
    of EmptyValue:
      return
    of ValueNode:
      return
    of HashNode:
      currentKey = next.restOfTheKey

proc verifyMptProof(
    branch: seq[seq[byte]], key: openArray[byte]) =
  for _ in branch:
    discard

  verifyProof(key, branch[0])

proc getGenesisAlloc(): GenesisAlloc =
  {"a": GenesisAccount()}.toTable()

let
  _ = getGenesisAlloc()
  _ = Hash32.fromHex("9e6f9f140138677c62d4261312b15b1d26a6d60cb3fa966dd186cb4f04339d77")

verifyMptProof(getAccountProof(), FixedBytes[32](static(Hash32.fromHex("227a737497210f7cc2f464e3bfffadefa9806193ccdf873203cd91c8d3eab518"))))

import
  ./unittest2

proc sign(tx: seq[byte], eip155: bool) = discard

type
  Assembler = object
    data    : seq[byte]

proc createSignedTx(payload: seq[byte]): seq[byte] =
  PrivateKey.fromHex("7a28b5ba57c53603b0b07b56bba752f7784bf506fa95edc395f5cf6c7514fe9d")
  sign(default(seq[byte]), false)

proc runVM(boa: Assembler): bool =
  discard createSignedTx(boa.data)
  true

proc vmProxy_855651302(): bool =
  let boa = Assembler()
  runVM(boa)

discard vmProxy_855651302()
