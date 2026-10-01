mode = ScriptMode.Verbose

version       = "0.2.5"
author        = "Status Research & Development GmbH"
description   = "unittest fork with support for parallel test execution"
license       = "MIT"
requires "nim >= 1.6.0"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]
let platform = getEnv("PLATFORM", "")

from std/os import quoteShell

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0") &
  " --skipParentCfg --skipUserCfg --outdir:build -f " &
  quoteShell("--nimcache:build/nimcache/$projectName")

proc build(args, path: string, cmdArgs = "") =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path & " " & cmdArgs

proc run(args, path: string, cmdArgs = "") =
  build args & " -r", path, cmdArgs

proc testOptions(args: string) =
  let
    xmlFile = "build/test_results.xml"
  rmFile xmlFile

  # This should generate an XML results file.
  run(args, "tests/tunittest", "--xml:" & xmlFile)
  doAssert fileExists xmlFile
  rmFile xmlFile

  # This should not, since we disable param processing.
  run(args & " -d:unittest2DisableParamFiltering", "tests/tunittest", "--xml:" & xmlFile)
  doAssert not fileExists xmlFile

task test, "Run all tests":
  for compat in ["-d:unittest2Compat=false", "-d:unittest2Compat=true"]:
    for color in ["-d:nimUnittestColor=on", "-d:nimUnittestColor=off"]:
      let args = "--threads:on " & compat & " " & color
      for level in ["VERBOSE", "COMPACT", "FAILURES", "NONE"]:
        run args & " --mm:refc", "tests/tunittest", "--output-level=" & level
        run args & " --mm:orc", "tests/tunittest", "--output-level=" & level

  testOptions "--mm:refc"
  testOptions "--mm:orc"

task test_asan, "Run all tests with ASAN":
  if platform != "x86":
    try:
      exec "echo '#if __clang_major__ < 20\n#error\n#endif' | clang -E - >/dev/null"
    except OSError:
      return

    # https://clang.llvm.org/docs/AddressSanitizer.html
    putEnv("ASAN_OPTIONS", "detect_leaks=0:detect_stack_use_after_return=1")
    # https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html
    putEnv("UBSAN_OPTIONS", "print_stacktrace=1")
    let asanArgs =
      " --mm:orc -d:useMalloc --cc:clang --debugger:native" &
      " --passC:-fsanitize=address,undefined" &
      " --passL:-fsanitize=address,undefined" &
      " --passC:-fno-sanitize-recover=undefined" &
      " --passC:-fno-sanitize-merge" &
      " --passC:-fno-omit-frame-pointer"
    for compat in ["-d:unittest2Compat=false", "-d:unittest2Compat=true"]:
      for color in ["-d:nimUnittestColor=on", "-d:nimUnittestColor=off"]:
        let args = "--threads:on " & compat & " " & color
        for level in ["VERBOSE", "COMPACT", "FAILURES", "NONE"]:
          run args & asanArgs, "tests/tunittest", "--output-level=" & level

    testOptions asanArgs

task book, "Generate book":
  exec "mdbook build book -d ../docs"

task apidocs, "Generate API docs":
  exec nimc & " doc --outdir:docs/apidocs --project --index:on --git.url:https://github.com/status-im/nim-unittest2 --git.commit:master --git.devel:master unittest2.nim"

task docs, "Generate docs":
  bookTask()
  apidocsTask()
