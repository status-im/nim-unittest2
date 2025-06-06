type
  Result*[T, E] = object
    when T is void:
      when E is void:
        oResultPrivate: bool
      else:
        case oResultPrivate: bool
        of false:
          eResultPrivate: E
        of true:
          discard
    else:
      when E is void:
        case oResultPrivate: bool
        of false:
          discard
        of true:
          vResultPrivate*: T
      else:
        case oResultPrivate: bool
        of false:
          eResultPrivate: E
        of true:
          vResultPrivate*: T

template ok*[T: not void, E](R: type Result[T, E], x: untyped): R =
  R(oResultPrivate: true, vResultPrivate: x)

template ok*[T: not void, E](self: var Result[T, E], x: untyped) =
  self = ok(type self, x)

template err[T; E: not void](R: type Result[T, E], x: untyped): R =
  R(oResultPrivate: false, eResultPrivate: x)

template err[T](R: type Result[T, cstring], x: string): R =
  const s = x # avoid dangling cstring pointers
  R(oResultPrivate: false, eResultPrivate: cstring(s))

template err[T; E: not void](self: var Result[T, E], x: untyped) =
  self = err(type self, x)

template err[T](self: var Result[T, cstring], x: string) =
  const s = x # Make sure we don't return a dangling pointer
  self = err(type self, cstring(s))

template ok*(v: auto): auto =
  ok(typeof(result), v)

template ok*(): auto =
  ok(typeof(result))

template err*(v: auto): auto =
  err(typeof(result), v)

template err*(): auto =
  err(typeof(result))

func mapConvert*[T0: not void, E](
    self: Result[T0, E], T1: type
): Result[T1, E] {.inline.} =
  case self.oResultPrivate
  of true:
    when T1 is void:
      result.ok()
    else:
      result.ok(T1(self.vResultPrivate))
  of false:
    when E is void:
      result.err()
    else:
      result.err(self.eResultPrivate)

const pushGenericsOpenSym = defined(nimHasGenericsOpenSym2)

template valueOr*[T: not void, E](self: Result[T, E], def: untyped): T =
  let s = (self) # TODO avoid copy
  case s.oResultPrivate
  of true:
    s.vResultPrivate
  of false:
    when E isnot void:
      when pushGenericsOpenSym:
        {.push experimental: "genericsOpenSym".}
      template error(): E {.used.} =
        s.eResultPrivate

    def

template `?`*[T, E](self: Result[T, E]): auto =
  let v = (self)
  case v.oResultPrivate
  of false:
    when typeof(result) is typeof(v):
      result = v
      return
    else:
      when E is void:
        result = err(typeof(result))
        return
      else:
        result = err(typeof(result), v.eResultPrivate)
        return
  of true:
    when not (T is void):
      v.vResultPrivate

type
  SkSecretKey* {.requiresInit.} = object

  SkResult[T] = Result[T, cstring]

func fromHex(T: type seq[byte], s: string): SkResult[T] =
  ok(default(seq[byte]))

func fromRaw(T: type SkSecretKey, data: openArray[byte]): SkResult[T] =
  ok(T())

func fromHex*(T: type SkSecretKey, data: string): SkResult[T] =
  T.fromRaw(? seq[byte].fromHex(data))
