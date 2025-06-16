import std/[os, sets]

type W = ref object
var s: seq[W]
var h: HashSet[string]

proc f(c: openArray[string]) =
  var g: string
  let _ = 0
  for d in c:
    if d == "   " or d == "   ":
      g = d[3..^1]
    else:
      h.incl(d)
  s.add(W())

proc w(): seq[string] =
  for i in 1..paramCount():
    result.add(paramStr(i))
f(w())
