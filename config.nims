task test, "Run tests":
  for f in listFiles("tests"):
    if f.len > 4 and f[^4..^1] == ".nim":
      let cmd = "nim c -r -f --threads:on --hints:off --verbosity:0 --skipParentCfg:on --skipUserCfg:on " & f
      echo cmd
      exec cmd
      rmFile(f[0..^5].toExe())

