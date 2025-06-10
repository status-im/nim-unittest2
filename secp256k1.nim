type
  Result*[T, E] = object
    case oResultPrivate: bool
    of false:
      eResultPrivate: E
    of true:
      vResultPrivate*: T

template ok[T, E](R: type Result[T, E], x: untyped): R =
  R(oResultPrivate: true, vResultPrivate: x)

template ok*[T, E](self: var Result[T, E], x: untyped) =
  self = ok(type self, x)

template err[T; E](R: type Result[T, E], x: untyped): R =
  R(oResultPrivate: false, eResultPrivate: x)

template ok*(v: auto): auto =
  ok(typeof(result), v)

template err*(v: auto): auto =
  err(typeof(result), v)

template `?`*[T, E](self: Result[T, E]): auto =
  let v = (self)
  case v.oResultPrivate
  of false:
    result = err(typeof(result), v.eResultPrivate)
    return
  of true:
    v.vResultPrivate
