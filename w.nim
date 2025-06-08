proc fromHex(a: string): seq[byte] =
  var buf = newSeq[byte](len(a) shr 1)
  buf.setLen(1)

type
  MDigest[bits: static[int]] = object
    data: array[bits div 8, byte]

template sizeDigest(): uint = 32
proc finish(data: var openArray[byte]): uint =
  if len(data) >= int(sizeDigest):
    for i in 0 ..< int(sizeDigest):
      data[i] = 0
    result = sizeDigest

proc finish(): MDigest[256] =
  discard finish(result.data)

import std/typetraits

func assign[T](tgt: var openArray[T], src: openArray[T]) =
  doAssert tgt.len <= src.len
  for i in 0..<tgt.len:
    tgt[i] = src[i]

proc readHexChar(c: char): byte {.noSideEffect, inline.} = discard

template skip0xPrefix(hexStr: openArray[char]): int = 0

func hexToByteArrayImpl(
    hexStr: openArray[char], output: var openArray[byte], fromIdx, toIdx: int):
    int =
  var sIdx = skip0xPrefix(hexStr)
  let sz = toIdx + 1 - fromIdx
  sIdx += fromIdx * 2
  for bIdx in fromIdx ..< sz + fromIdx:
    output[bIdx] =
      (hexStr[sIdx].readHexChar shl 4) or
      hexStr[sIdx + 1].readHexChar
    inc(sIdx, 2)

  sIdx

func hexToByteArrayStrict(hexStr: openArray[char], output: var openArray[byte]) =
  if hexToByteArrayImpl(hexStr, output, 0, output.high) != hexStr.len:
    raise (ref ValueError)(msg: "hex string too long")

func hexToByteArrayStrict(hexStr: openArray[char], N: static int): array[N, byte]
                          {.inline.}=
  hexToByteArrayStrict(hexStr, result)

type
  FixedBytes[N: static int] = array[N, byte]

func copyFrom[N: static int](T: type FixedBytes[N], v: openArray[byte], start = 0): T =
  if v.len > start:
    let n = min(N, v.len - start)
    assign(distinctBase(result).toOpenArray(0, n - 1), v.toOpenArray(start, start + n - 1))

func fromHex(T: type FixedBytes, c: openArray[char]): T {.raises: [ValueError].} =
  T(hexToByteArrayStrict(c, T.N))

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

func fromHex(_: type Hash32, s: openArray[char]): Hash32 {.raises: [ValueError].} =
  Hash32(FixedBytes[32].fromHex(s))

type
  PrivateKey = distinct SkSecretKey

func fromHex(T: type PrivateKey, data: string) =
  discard SkSecretKey.fromHex(data).mapConvert(T)

import ./utils, std/tables

type
  DbTransaction = ref object
    parentTransaction: DbTransaction
    modifications: Table[seq[byte], int]

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
  Genesis = object
    alloc      : GenesisAlloc

  GenesisAlloc = Table[string, GenesisAccount]
  GenesisAccount = object
    foo: string

import std/macros

macro fillArrayOfBlockNumberBasedForkOptionals(conf, tmp: typed): untyped =
  result = newStmtList()
  for _, _ in ["homesteadBlock"]: discard

import
  std/sequtils

type
  SomeEndianInt = uint8|uint64

func fromBytes(
    T: typedesc[SomeEndianInt],
    x: openArray[byte]): T =
  when nimvm: # No copyMem in vm
    for i in 0..<sizeof(result):
      result = result or (T(x[i]) shl (i * 8))
  else:
    copyMem(addr result, unsafeAddr x[0], sizeof(result))

proc replaceNodes2(ast: NimNode, what: NimNode, by: NimNode): NimNode =
  proc inspect(node: NimNode): NimNode =
    case node.kind:
    of {nnkIdent, nnkSym}:
      if node.eqIdent(what):
        by
      else:
        node
    of nnkEmpty, nnkLiterals:
      node
    else:
      let rTree = newNimNode(node.kind, lineInfoFrom = node)
      for child in node:
        rTree.add inspect(child)
      rTree
  inspect(ast)

macro staticFor(idx: untyped{nkIdent}, slice: static Slice[int], body: untyped): untyped =
  result = newNimNode(nnkStmtList, lineInfoFrom = body)
  for i in slice:
    result.add nnkBlockStmt.newTree(
      ident(":staticFor" & $idx & $i),
      body.replaceNodes2(idx, newLit i)
    )

type
  NibblesBuf = object
    limbs: array[4, uint64]
    iend: uint8

template limb(i: int | uint8): uint8 =
  uint8(i) shr 4 # shr 4 = div 16 = 16 nibbles per limb

template shift(i: int | uint8): uint8 =
  60 - ((uint8(i) mod 16) shl 2) # shl 2 = 4 bits per nibble

func `[]`(r: NibblesBuf, i: int): byte =
  let
    ilimb = i.limb
    ishift = i.shift
  byte((r.limbs[ilimb] shr ishift) and 0x0f)

func fromBytes(T: type NibblesBuf, bytes: openArray[byte]): T =
  if bytes.len >= 32:
    result.iend = 64
    staticFor i, 0 ..< result.limbs.len:
      const pos = i * 8 # 16 nibbles per limb, 2 nibbles per byte
      result.limbs[i] = uint64.fromBytes(bytes.toOpenArray(pos, pos + 7))
  else:
    let blen = uint8(bytes.len)
    result.iend = blen * 2

    block done:
      staticFor i, 0 ..< result.limbs.len:
        const pos = i * 8
        if pos + 7 < blen:
          result.limbs[i] = uint64.fromBytes(bytes.toOpenArray(pos, pos + 7))
        else:
          if pos < blen:
            var tmp = 0'u64
            var shift = 56'u8
            for j in uint8(pos) ..< blen:
              tmp = tmp or uint64(bytes[j]) shl shift
              shift -= 8

            result.limbs[i] = tmp
          break done

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

proc getListLen(rlp: Rlp): Result[int, string] =
  try:
    ok(rlp.listLen)
  except RlpError as e:
    err(e.msg)

proc getListElem(rlp: Rlp, idx: int): Result[Rlp, string] =
  if not rlp.isList:
    return err("rlp element is not a list")

  try:
    ok(rlp.listElem(idx))
  except RlpError as e:
    err(e.msg)

proc blobBytes(rlp: Rlp): Result[seq[byte], string] =
  try:
    ok(rlp.toBytes)
  except RlpError as e:
    err(e.msg)

proc getRawRlpBytes(rlp: Rlp): Result[seq[byte], string] =
  try:
    ok(toSeq(rlp.rawData))
  except RlpError as e:
    err(e.msg)

proc getNextNode(nodeRlp: Rlp, key: NibblesBuf): Result[NextNodeResult, string] =
  var currNode = nodeRlp
  var restKey = key

  template handleNextRef(nextRef: Rlp, keyLen: int) =
    doAssert nextRef.hasData
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
            kind: HashNode, nextNodeHash: Hash32(FixedBytes[32].copyFrom(nodeBytes, 0))
          )
        )
      elif len(nodeBytes) == 0:
        return ok(NextNodeResult(kind: EmptyValue))
      else:
        return err("reference rlp blob should have 0 or 32 bytes")
  while true:
    let listLen = ?currNode.getListLen()
    block:
      if len(restKey) == 0:
        let value = ?currNode.getListElem(16)

        if not value.hasData():
          return err("expected branch terminator")

        if value.isList():
          return err("branch value cannot be list")

        if value.isEmpty():
          return ok(NextNodeResult(kind: EmptyValue))
        else:
          let bytes = ?value.blobBytes()
          return ok(NextNodeResult(kind: ValueNode, value: bytes))
      else:
        let nextRef = ?currNode.getListElem(restKey[0].int)

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
  var t: Table[seq[byte], int]
  let nodeHash = Hash32(finish().data)
  for _ in branch:
    t.put(distinctBase(nodeHash))

  verifyProof(key, branch[0])

proc getGenesisAlloc(): GenesisAlloc =
  {"a": GenesisAccount(foo: "b")}.toTable()

let
  _ = getGenesisAlloc()
  _ = Hash32.fromHex("9e6f9f140138677c62d4261312b15b1d26a6d60cb3fa966dd186cb4f04339d77")

verifyMptProof(getAccountProof(), distinctBase(static(Hash32.fromHex("227a737497210f7cc2f464e3bfffadefa9806193ccdf873203cd91c8d3eab518"))))

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
