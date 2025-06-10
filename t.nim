type
  L* = object
    bytes*: seq[byte]
    position*: int
  D = tuple[payload: Slice[int], _: int]

template p*(n: openArray[byte], s: Slice[int]): openArray[byte] =
  if s.b >= len(n): raiseAssert ""
  toOpenArray(n, s.a, s.b)

proc k(f: openArray[byte], t = 0): D =
  if f[t] <= 0x7f:
    raiseAssert ""
  elif f[t] <= 0xb7:
    (1 .. int(f[t] - 128), 0)
  else:
    (2 .. 178, 0)

proc item*(e: L): D = k(e.bytes, e.position)
proc j*(v: L): bool = v.bytes[v.position] >= byte(0xc0)
proc h*(x: L): L =
  let m = item(x)
  var p = k(x.bytes.p(m.payload.a .. m.payload.b)).payload
  for _ in 0 ..< 1:
    p = k(x.bytes.p(2 .. 178)).payload
  L(bytes: @(x.bytes.p(2 .. 2 + p.b)), position: 0)
