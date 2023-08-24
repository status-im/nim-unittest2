let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]

from os import quoteShell

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0 --hints:off") &
  " --skipParentCfg --skipUserCfg --outdir:build -f " &
  quoteShell("--nimcache:build/nimcache/$projectName")

proc build(args, path: string, cmdArgs = "") =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path & " " & cmdArgs

proc run(args, path: string, cmdArgs = "") =
  build args & " -r", path, cmdArgs

proc testOptions() =
  let
    xmlFile = "build/test_results.xml"
  rmFile xmlFile

  # This should generate an XML results file.
  run("", "tests/tunittest", "--xml:" & xmlFile)
  doAssert fileExists xmlFile
  rmFile xmlFile

  # This should not, since we disable param processing.
  run("-d:unittest2DisableParamFiltering", "tests/tunittest", "--xml:" & xmlFile)
  doAssert not fileExists xmlFile

task test, "Run tests":
  if not dirExists "build":
    mkDir "build"

  for f in listFiles("tests"):
    if not (f.len > 4 and f[^4..^1] == ".nim"): continue

    for compat in ["-d:unittest2Compat=false", "-d:unittest2Compat=true"]:
      for color in ["-d:nimUnittestColor=on", "-d:nimUnittestColor=off"]:
        for level in ["VERBOSE", "COMPACT", "FAILURES", "NONE"]:
          run "--threads:on " & " " & compat & " " & color, f, "--output-level=" & level

  testOptions()

task buildDocs, "Build docs":
  exec "nim doc --skipParentCfg:on --skipUserCfg:on --outdir:docs --git.url:https://github.com/status-im/nim-unittest2 --git.commit:master --git.devel:master unittest2.nim"
