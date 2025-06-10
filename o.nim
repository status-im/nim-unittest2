{.localPassC: "-fno-lto".}
type Q*[T] = object
  case g*: bool
  of false:
    discard
  of true:
    z*: T
