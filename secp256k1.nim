type
  Result*[T, E] = object
    when T is void:
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

template err[T; E: not void](self: var Result[T, E], x: untyped) =
  self = err(type self, x)

template ok*(v: auto): auto =
  ok(typeof(result), v)

template ok*(): auto =
  ok(typeof(result))

template err*(v: auto): auto =
  err(typeof(result), v)

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
  SkSecretKey* = object
