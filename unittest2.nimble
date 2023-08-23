mode = ScriptMode.Verbose

version       = "0.0.9"
author        = "Status Research & Development GmbH"
description   = "unittest fork with support for parallel test execution"
license       = "MIT"
requires "nim >= 1.6.0"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0 --hints:off") &
  " --skipParentCfg --skipUserCfg --outdir:build '--nimcache:build/nimcache/$projectName' -f"

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
      for level in ["VERBOSE", "COMPACT", "FAILURES", "NONE"]:
        run "--threads:on " & " " & compat, f, "--output-level=" & level

  testOptions()

task buildDocs, "Build docs":
  exec "nim doc --skipParentCfg:on --skipUserCfg:on --outdir:docs --git.url:https://github.com/status-im/nim-unittest2 --git.commit:master --git.devel:master unittest2.nim"
