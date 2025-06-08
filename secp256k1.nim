type
  Result*[T, E] = object
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

template err*(v: auto): auto =
  err(typeof(result), v)

template `?`*[T, E](self: Result[T, E]): auto =
  let v = (self)
  case v.oResultPrivate
  of false:
    when typeof(result) is typeof(v):
      return
    else:
      result = err(typeof(result), v.eResultPrivate)
      return
  of true:
    when not (T is void):
      v.vResultPrivate

type
  SkSecretKey* = object
