task test, "Run tests":
  let
    xmlFile = "test_results.xml"
    commandStart = "nim c -r -f --threads:on --hints:off --verbosity:0 --skipParentCfg:on --skipUserCfg:on "

  for f in listFiles("tests"):
    if f.len > 4 and f[^4..^1] == ".nim":
      # This should generate an XML results file.
      var cmd = commandStart & f & " --xml:" & xmlFile & " --console"
      echo cmd
      exec cmd
      doAssert fileExists xmlFile
      rmFile xmlFile

      # This should not, since we disable param processing.
      cmd = commandStart & "-d:unittest2DisableParamFiltering " & f & " --xml:" & xmlFile
      echo cmd
      exec cmd
      doAssert not fileExists xmlFile
      rmFile f[0..^5].toExe

task buildDocs, "Build docs":
  exec "nim doc --skipParentCfg:on --skipUserCfg:on --outdir:docs --git.url:https://github.com/status-im/nim-unittest2 --git.commit:master --git.devel:master unittest2.nim"

