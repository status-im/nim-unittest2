import std/[macros, tables], ./o

proc y(): seq[seq[byte]] =
  result = @[@[248'u8, 177, 160, 129, 136, 149, 159, 31, 252, 215, 147, 250, 28, 74, 127, 243, 250, 52, 43, 117, 253, 206, 185, 136, 179, 23, 70, 75, 37, 169, 40, 81, 139, 29, 85, 128, 160, 166, 92, 64, 107, 103, 166, 196, 94, 147, 183, 129, 212, 225, 123, 145, 5, 105, 226, 248, 243, 193, 9, 179, 25, 169, 168, 252, 112, 223, 115, 37, 41, 128, 160, 212, 49, 8, 53, 235, 82, 204, 21, 4, 254, 38, 152, 121, 245, 19, 127, 137, 243, 84, 79, 146, 233, 16, 10, 222, 19, 147, 71, 196, 38, 5, 6, 128, 128, 128, 128, 128, 160, 194, 171, 71, 247, 21, 130, 2, 59, 51, 27, 110, 162, 104, 73, 163, 174, 229, 43, 72, 28, 43, 246, 103, 5, 27, 137, 130, 21, 106, 1, 201, 49, 128, 128, 128, 128, 160, 198, 39, 225, 154, 149, 227, 112, 175, 149, 233, 24, 177, 216, 49, 194, 32, 227, 116, 223, 82, 202, 202, 87, 37, 129, 92, 198, 14, 198, 134, 161, 216, 128], @[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]]
import ./t

type B = ref object
  v: B

proc x(t: var B, g: openArray[byte]) =
  let g = @g
  while t != nil:
    discard getOrDefault(default(Table[seq[byte], int]), g)
    t = t.v

macro a(): untyped =
  result = newStmtList()
  for _, _ in [""]: discard

type K = object
  case kind: range[0 .. 2]
  of 2: discard
  of 1:
    e: array[32, byte]
    r: uint8
  of 0: p: seq[byte]

proc s(f: L): Q[L] = Q[L](g: true, z: h(f))
proc n(d: L): Q[seq[byte]] =
  try:
    Q[seq[byte]](g: true, z: @(d.bytes.p(item(d).payload)))
  except CatchableError:
    Q[seq[byte]](g: false)

template k(s: untyped): untyped =
  var result = newSeq[byte](len(s))
  discard s[0]
  result

template c[T](self: Q[T]): auto =
  let w = self
  case w.g
  of false:
    result = Q[K]()
    return
  of true:
    w.z

proc m(w: L): Q[seq[byte]] = Q[seq[byte]](g: true, z: k(toOpenArray(w.bytes, w.position, 1)))
proc w(): array[32, byte] = discard
proc p(f: L, i: uint8): Q[K] =
  var w = f
  while true:
    if i == 0:
      discard n(c(s(w)))
      return Q[K](g: true, z: K(kind: 0))
    else:
      let h = c(s(w))
      if j(h):
        if len(c(m(h))) > 32:
          return Q[K]()
        else:
          w = h
      else:
        let d = len(c(n(h)))
        if d == 32:
          discard w()
          return Q[K](g: true, z: K(kind: 1))
        elif d == 0:
          return Q[K](g: true, z: K(kind: 2))
        return Q[K](g: false)

proc u(data: openArray[byte]): L = L(bytes: @data, position: 0)
proc v(g: seq[byte]) =
  var e = 64'u8
  while true:
    var t = new B
    x(t, [])
    let node = g
    let next = p(u(node), e).z
    case next.kind
    of 0, 2:
      return
    of 1:
      e = next.r

discard {"": 0}.toTable()
v(y()[0])
import ./e
