mode = ScriptMode.Verbose

version       = "0.0.1"
author        = "Ștefan Talpalaru"
description   = "unittest fork with support for parallel test execution"
license       = "MIT"
requires "nim >= 0.19.4"

task test, "Run tests":
  for f in listFiles("tests"):
    if f.len > 4 and f[^4..^1] == ".nim":
      exec "nim c -r -f --hints:off --verbosity:0 " & f
      rmFile(f[0..^5].toExe())

