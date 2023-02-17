#
#
#            Nim's Runtime Library
#        (c) Copyright 2015 Nim Contributors
#        (c) Copyright 2019-2021 Ștefan Talpalaru
#        (c) Copyright 2021-Onwards Status Research and Development
#

when (NimMajor, NimMinor) < (1, 4):
  {.push raises: [Defect].}
else:
  {.push raises: [].}

## :Authors: Zahary Karadjov, Ștefan Talpalaru
##
## This module implements boilerplate to make unit testing easy.
##
## The test status and name is printed after any output or traceback.
##
## Tests can be nested, however failure of a nested test will not mark the
## parent test as failed. Setup and teardown are inherited. Setup can be
## overridden locally.
##
## Compiled test files return the number of failed test as exit code, while
##
## .. code::
##   nim c -r testfile.nim
##
## exits with 0 or 1.
##
## Running individual tests
## ========================
##
## Specify the test names as command line arguments.
##
## .. code::
##
##   nim c -r test "my test name" "another test"
##
## Multiple arguments can be used.
##
## Running a single test suite
## ===========================
##
## Specify the suite name delimited by ``"::"``.
##
## .. code::
##
##   nim c -r test "my suite name::"
##
## Selecting tests by pattern
## ==========================
##
## A single ``"*"`` can be used for globbing.
##
## Delimit the end of a suite name with ``"::"``.
##
## Tests matching **any** of the arguments are executed.
##
## .. code::
##
##   nim c -r test fast_suite::mytest1 fast_suite::mytest2
##   nim c -r test "fast_suite::mytest*"
##   nim c -r test "auth*::" "crypto::hashing*"
##   # Run suites starting with 'bug #' and standalone tests starting with '#'
##   nim c -r test 'bug #*::' '::#*'
##
## Command line arguments
## ======================
##
## --help      Print short help and quit
## --xml:file  Write JUnit-compatible XML report to `file`
## --console   Write report to the console (default, when no other output is
##             selected)
##
## Command line parsing can be disabled with `-d:unittest2DisableParamFiltering`.
##
## Running tests in parallel
## =========================
##
## To enable the threadpool-based test parallelisation, "--threads:on" needs to
## be passed to the compiler, along with "-d:nimtestParallel" or the
## NIMTEST_PARALLEL environment variable:
##
## .. code::
##
##   nim c -r --threads:on -d:nimtestParallel testfile.nim
##   # or
##   NIMTEST_PARALLEL=1 nim c -r --threads:on testfile.nim
##
## There are some implicit barriers where we wait for all the spawned jobs to
## complete: before and after each test suite and at the main thread's exit.
##
## The suite-related barriers are there to avoid mixing test output, but they
## also affect which groups of tests can be run in parallel, so keep them in
## mind when deciding how many tests to place in different suites (or between
## suites).
##
## You may sometimes need to disable test parallelisation for a specific test,
## even though it was enabled in some configuration file in a parent dir. Do
## this with "-d:nimtestParallelDisabled" which overrides everything else.
##
## Example
## -------
##
## .. code:: nim
##
##   suite "description for this stuff":
##     echo "suite setup: run once before the tests"
##
##     setup:
##       echo "run before each test"
##
##     teardown:
##       echo "run after each test"
##
##     test "essential truths":
##       # give up and stop if this fails
##       require(true)
##
##     test "slightly less obvious stuff":
##       # print a nasty message and move on, skipping
##       # the remainder of this block
##       check(1 != 1)
##       check("asd"[2] == 'd')
##
##     test "out of bounds error is thrown on bad access":
##       let v = @[1, 2, 3]  # you can do initialization here
##       expect(IndexError):
##         discard v[4]
##
##     suiteTeardown:
##       echo "suite teardown: run once after the tests"

import std/[locks, macros, sets, strutils, streams, times, monotimes]

{.warning[LockLevel]:off.}

when declared(stdout):
  import std/os

const useTerminal = not defined(js)

# compile with `-d:unittest2DisableParamFiltering` to skip parsing test filters,
# `--help` and other command line options - you can manually call
# `parseParameters` instead then.
const autoParseArgs = not defined(unittest2DisableParamFiltering)

when useTerminal:
  import std/terminal

when declared(stdout):
  const paralleliseTests* = (existsEnv("NIMTEST_PARALLEL") or defined(nimtestParallel) and not defined(nimtestParallelDisabled))
    ## Whether parallel test running was enabled (set at compile time).
    ## This constant might be useful in custom output formatters.
else:
  const paralleliseTests* = false

when (NimMajor, NimMinor) > (1, 2):
  from std/exitprocs import nil
  template addExitProc(p: proc) =
    when defined(nimHasWarnBareExcept):
      {.warning[BareExcept]:off.}

    try:
      exitprocs.addExitProc(p)
    except Exception as e:
      echo "Can't add exit proc", e.msg
      quit(1)

    when defined(nimHasWarnBareExcept):
      {.warning[BareExcept]:on.}
else:
  template addExitProc(p: proc) =
    addQuitProc(p)

when paralleliseTests:
  import threadpool

  # repeatedly calling sync() without waiting for results - on procs that don't
  # return any - doesn't work properly (probably due to gSomeReady getting its
  # counter increased back to the pre-call value) so we're stuck with these
  # dummy flowvars
  # (`flowVars` will be initialized in each child thread, when using nested tests, by the compiler)
  # TODO: try getting rid of them when nim-0.20.0 is released
  var flowVars {.threadvar.}: seq[FlowVarBase]
  proc repeatableSync*() =
    sync()
    for flowVar in flowVars:
      when (NimMajor, NimMinor, NimPatch) >= (1, 4, 0):
        blockUntil(flowVar[])
      else:
        blockUntil(flowVar)
    flowVars = @[]

  # make sure all the spawned tests are done before exiting
  # (this will be the last sync, so no need for repeatability)
  let mainThreadID = getThreadId()
  proc quitProc() {.noconv.} =
    # "require" can exit from a worker thread and syncing in there would block
    if getThreadId() == mainThreadID:
      sync()
  addExitProc(quitProc)

  var outputLock: Lock # used by testEnded() to avoid mixed test outputs
  initLock(outputLock)

type
  TestStatus* = enum ## The status of a test when it is done.
    OK,
    FAILED,
    SKIPPED

  OutputLevel* = enum  ## The output verbosity of the tests.
    PRINT_ALL,         ## Print as much as possible.
    PRINT_FAILURES,    ## Print only the failed tests.
    PRINT_NONE         ## Print nothing.

  TestResult* = object
    suiteName*: string
      ## Name of the test suite that contains this test case.
      ## Can be ``nil`` if the test case is not in a suite.
    testName*: string
      ## Name of the test case
    status*: TestStatus
    duration*: Duration # How long the test took, in seconds

  OutputFormatter* = ref object of RootObj

  ConsoleOutputFormatter* = ref object of OutputFormatter
    colorOutput: bool
      ## Have test results printed in color.
      ## Default is `auto` depending on `isatty(stdout)`, or override it with
      ## `-d:nimUnittestColor:auto|on|off`.
      ##
      ## Deprecated: Setting the environment variable `NIMTEST_COLOR` to `always`
      ## or `never` changes the default for the non-js target to true or false respectively.
      ## Deprecated: the environment variable `NIMTEST_NO_COLOR`, when set, changes the
      ## default to true, if `NIMTEST_COLOR` is undefined.
    outputLevel: OutputLevel
      ## Set the verbosity of test results.
      ## Default is `PRINT_ALL`, or override with:
      ## `-d:nimUnittestOutputLevel:PRINT_ALL|PRINT_FAILURES|PRINT_NONE`.
      ##
      ## Deprecated: the `NIMTEST_OUTPUT_LVL` environment variable is set for the non-js target.
    isInSuite: bool
    isInTest: bool

  JUnitTest = object
    name: string
    result: TestResult
    error: (seq[string], string)
    failures: seq[seq[string]]

  JUnitSuite = object
    name: string
    tests: seq[JUnitTest]

  JUnitOutputFormatter* = ref object of OutputFormatter
    stream: Stream
    defaultSuite: JUnitSuite
    suites: seq[JUnitSuite]
    currentSuite: int

var
  abortOnError* {.threadvar.}: bool ## Set to true in order to quit
                                    ## immediately on fail. Default is false,
                                    ## or override with `-d:nimUnittestAbortOnError:on|off`.
                                    ##
                                    ## Deprecated: can also override depending on whether
                                    ## `NIMTEST_ABORT_ON_ERROR` environment variable is set.

  checkpoints {.threadvar.}: seq[string]
  formattersLock: Lock
  formatters {.guard: formattersLock.}: seq[OutputFormatter]
  testFiltersLock: Lock
  testsFilters {.guard: testFiltersLock.}: HashSet[string]

const
  outputLevelDefault = PRINT_ALL
  nimUnittestOutputLevel {.strdefine.} = $outputLevelDefault
  nimUnittestColor {.strdefine.} = "auto" ## auto|on|off
  nimUnittestAbortOnError {.booldefine.} = false

initLock(formattersLock)
initLock(testFiltersLock)

template deprecateEnvVarHere() =
  # xxx issue a runtime warning to deprecate this envvar.
  discard

abortOnError = nimUnittestAbortOnError
when declared(stdout):
  if existsEnv("NIMTEST_ABORT_ON_ERROR"):
    deprecateEnvVarHere()
    abortOnError = true

method suiteStarted*(formatter: OutputFormatter, suiteName: string) {.base, gcsafe.} =
  discard
method testStarted*(formatter: OutputFormatter, testName: string) {.base, gcsafe.} =
  discard
method failureOccurred*(formatter: OutputFormatter, checkpoints: seq[string],
    stackTrace: string) {.base, gcsafe.} =
  ## ``stackTrace`` is provided only if the failure occurred due to an exception.
  ## ``checkpoints`` is never ``nil``.
  discard
method testEnded*(formatter: OutputFormatter, testResult: TestResult) {.base, gcsafe.} =
  discard
method suiteEnded*(formatter: OutputFormatter) {.base, gcsafe.} =
  discard
method testRunEnded*(formatter: OutputFormatter) {.base, gcsafe.} =
  # Runs when the test executable is about to end, which is implemented using
  # addQuitProc, a best-effort kind of place to do cleanups

  discard

proc addOutputFormatter*(formatter: OutputFormatter) =
  withLock formattersLock:
    {.gcsafe.}:
      formatters.add(formatter)

proc resetOutputFormatters*() =
  withLock formattersLock:
    {.gcsafe.}:
      formatters = @[]

proc newConsoleOutputFormatter*(outputLevel: OutputLevel = outputLevelDefault,
                                colorOutput = true): ConsoleOutputFormatter =
  ConsoleOutputFormatter(
    outputLevel: outputLevel,
    colorOutput: colorOutput
  )

proc colorOutput(): bool =
  let color = nimUnittestColor
  case color
  of "auto":
    when declared(stdout): result = isatty(stdout)
    else: result = false
  of "on": result = true
  of "off": result = false
  else: doAssert false, $color

  when declared(stdout):
    if existsEnv("NIMTEST_COLOR"):
      let colorEnv = getEnv("NIMTEST_COLOR")
      if colorEnv == "never":
        result = false
      elif colorEnv == "always":
        result = true
    elif existsEnv("NIMTEST_NO_COLOR"):
      result = false

proc defaultConsoleFormatter*(): ConsoleOutputFormatter =
  var colorOutput = colorOutput()
  var outputLevel = static: nimUnittestOutputLevel.parseEnum[:OutputLevel]
  when declared(stdout):
    const a = "NIMTEST_OUTPUT_LVL"
    if existsEnv(a):
      try:
        outputLevel = getEnv(a).parseEnum[:OutputLevel]
      except ValueError as exc:
        echo "Cannot parse NIMTEST_OUTPUT_LVL: ", exc.msg
        quit 1

  result = newConsoleOutputFormatter(outputLevel, colorOutput)

method suiteStarted*(formatter: ConsoleOutputFormatter, suiteName: string) =
  template rawPrint() = echo("\n[Suite] ", suiteName)
  when useTerminal:
    if formatter.colorOutput:
      when (NimMajor, NimMinor) < (1, 4) and defined(windows):
        try:
          styledEcho styleBright, fgBlue, "\n[Suite] ", resetStyle, suiteName
        except Exception: rawPrint() # Work around exceptions in `terminal.nim`
      else:
        try:
          styledEcho styleBright, fgBlue, "\n[Suite] ", resetStyle, suiteName
        except CatchableError: rawPrint() # Work around exceptions in `terminal.nim`
    else: rawPrint()
  else: rawPrint()
  formatter.isInSuite = true

method testStarted*(formatter: ConsoleOutputFormatter, testName: string) =
  formatter.isInTest = true

method failureOccurred*(formatter: ConsoleOutputFormatter,
                        checkpoints: seq[string], stackTrace: string) =
  if stackTrace.len > 0:
    echo stackTrace
  let prefix = if formatter.isInSuite: "    " else: ""
  for msg in items(checkpoints):
    echo prefix, msg

let consoleShowTiming =
  defined(unittestPrintTime) or
  getEnv("NIMTEST_TIMING").toLowerAscii().startsWith("t")

method testEnded*(formatter: ConsoleOutputFormatter, testResult: TestResult) =
  formatter.isInTest = false

  if formatter.outputLevel != OutputLevel.PRINT_NONE and
      (formatter.outputLevel == OutputLevel.PRINT_ALL or testResult.status == TestStatus.FAILED):
    let
      prefix = if testResult.suiteName.len > 0: "  " else: ""
      testHeader =
        if consoleShowTiming:
          let
            seconds = testResult.duration.inMilliseconds.float / 1000.0
            precision = max(3 - ($seconds.int).len, 1)
            formattedSeconds = formatFloat(seconds, ffDecimal, precision)
          prefix & "[" & $testResult.status & " - " & formattedSeconds & "s] "
        else:
          prefix & "[" & $testResult.status & "] "
    template rawPrint() = echo(testHeader, testResult.testName)
    when useTerminal:
      if formatter.colorOutput:
        var color = case testResult.status
          of TestStatus.OK: fgGreen
          of TestStatus.FAILED: fgRed
          of TestStatus.SKIPPED: fgYellow
        when (NimMajor, NimMinor) < (1, 4) and defined(windows):
          try:
            styledEcho styleBright, color, testHeader,
                resetStyle, testResult.testName
          except Exception: rawPrint() # Work around exceptions in `terminal.nim`
        else:
          try:
            styledEcho styleBright, color, testHeader,
                resetStyle, testResult.testName
          except CatchableError: rawPrint() # Work around exceptions in `terminal.nim`
      else:
        rawPrint()
    else:
      rawPrint()

method suiteEnded*(formatter: ConsoleOutputFormatter) =
  formatter.isInSuite = false

proc xmlEscape(s: string): string =
  result = newStringOfCap(s.len)
  for c in items(s):
    case c:
    of '<': result.add("&lt;")
    of '>': result.add("&gt;")
    of '&': result.add("&amp;")
    of '"': result.add("&quot;")
    of '\'': result.add("&apos;")
    else:
      if ord(c) < 32:
        result.add("&#" & $ord(c) & ';')
      else:
        result.add(c)

proc newJUnitOutputFormatter*(stream: Stream): JUnitOutputFormatter =
  ## Creates a formatter that writes report to the specified stream in
  ## JUnit format.
  ## The ``stream`` is NOT closed automatically when the test are finished,
  ## because the formatter has no way to know when all tests are finished.
  ## You should invoke formatter.close() to finalize the report.
  result = JUnitOutputFormatter(
    stream: stream,
    defaultSuite: JUnitSuite(name: "default"),
    currentSuite: -1,
  )
  try:
    stream.writeLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
  except CatchableError as exc:
    echo "Cannot write JUnit: ", exc.msg
    quit 1

template suite(formatter: JUnitOutputFormatter): untyped =
  if formatter.currentSuite == -1:
    addr formatter.defaultSuite
  else:
    addr formatter.suites[formatter.currentSuite]

method suiteStarted*(formatter: JUnitOutputFormatter, suiteName: string) =
  formatter.currentSuite = formatter.suites.len()
  formatter.suites.add(JUnitSuite(name: suiteName))

method testStarted*(formatter: JUnitOutputFormatter, testName: string) =
  formatter.suite().tests.add(JUnitTest(name: testName))

method failureOccurred*(formatter: JUnitOutputFormatter,
                        checkpoints: seq[string], stackTrace: string) =
  ## ``stackTrace`` is provided only if the failure occurred due to an exception.
  ## ``checkpoints`` is never ``nil``.
  if stackTrace.len > 0:
    formatter.suite().tests[^1].error = (checkpoints, stackTrace)
  else:
    formatter.suite().tests[^1].failures.add(checkpoints)

method testEnded*(formatter: JUnitOutputFormatter, testResult: TestResult) =
  formatter.suite().tests[^1].result = testResult

method suiteEnded*(formatter: JUnitOutputFormatter) =
  formatter.currentSuite = -1

func toFloatSeconds(duration: Duration): float64 =
  duration.inNanoseconds().float64 / 1_000_000_000.0

proc writeTest(s: Stream, test: JUnitTest) {.raises: [Exception].} =
  let
    time = test.result.duration.toFloatSeconds()
    timeStr = time.formatFloat(ffDecimal, precision = 6)

  s.writeLine("\t\t<testcase name=\"$#\" time=\"$#\">" % [
      xmlEscape(test.name), timeStr])
  case test.result.status
  of TestStatus.OK:
    discard
  of TestStatus.SKIPPED:
    s.writeLine("\t\t\t<skipped />")
  of TestStatus.FAILED:
    if test.error[0].len > 0:
      s.writeLine("\t\t\t<error message=\"$#\">$#</error>" % [
          xmlEscape(join(test.error[0], "\n")), xmlEscape(test.error[1])])

    for failure in test.failures:
      s.writeLine("\t\t\t<failure message=\"$#\">$#</failure>" %
          [xmlEscape(failure[^1]), xmlEscape(join(failure[0..^2], "\n"))])

  s.writeLine("\t\t</testcase>")

proc countTests(counts: var (int, int, int, int, float), suite: JUnitSuite) =
  counts[0] += suite.tests.len()
  for test in suite.tests:
    counts[4] += test.result.duration.toFloatSeconds()
    case test.result.status
    of TestStatus.OK:
      discard
    of TestStatus.SKIPPED:
      counts[3] += 1
    of TestStatus.FAILED:
      if test.error[0].len > 0:
        counts[2] += 1
      else:
        counts[1] += 1

proc writeSuite(s: Stream, suite: JUnitSuite) {.raises: [Exception].} =
  var counts: (int, int, int, int, float)
  countTests(counts, suite)

  let timeStr = counts[4].formatFloat(ffDecimal, precision = 6)

  s.writeLine("\t" & """<testsuite name="$1" tests="$2" failures="$3" errors="$4" skipped="$5" time="$6">""" % [
    xmlEscape(suite.name), $counts[0], $counts[1], $counts[2], $counts[3], timeStr])

  for test in suite.tests.items():
    s.writeTest(test)

  s.writeLine("\t</testsuite>")

method testRunEnded*(formatter: JUnitOutputFormatter) =
  ## Completes the report and closes the underlying stream.
  let s = formatter.stream

  when defined(nimHasWarnBareExcept):
    {.warning[BareExcept]:off.}
  try:
    s.writeLine("<testsuites>")

    for suite in formatter.suites.mitems():
      s.writeSuite(suite)

    if formatter.defaultSuite.tests.len() > 0:
      s.writeSuite(formatter.defaultSuite)

    s.writeLine("</testsuites>")
    s.close()
  except Exception as exc: # Work around Exception raised in stream
    echo "Cannot write JUnit: ", exc.msg
    quit 1

  when defined(nimHasWarnBareExcept):
    {.warning[BareExcept]:on.}

proc glob(matcher, filter: string): bool =
  ## Globbing using a single `*`. Empty `filter` matches everything.
  if filter.len == 0:
    return true

  if not filter.contains('*'):
    return matcher == filter

  let beforeAndAfter = filter.split('*', maxsplit=1)
  if beforeAndAfter.len == 1:
    # "foo*"
    return matcher.startsWith(beforeAndAfter[0])

  if matcher.len < filter.len - 1:
    return false  # "12345" should not match "123*345"

  return matcher.startsWith(beforeAndAfter[0]) and matcher.endsWith(
      beforeAndAfter[1])

proc matchFilter(suiteName, testName, filter: string): bool =
  if filter == "":
    return true
  if testName == filter:
    # corner case for tests containing "::" in their name
    return true
  let suiteAndTestFilters = filter.split("::", maxsplit=1)

  if suiteAndTestFilters.len == 1:
    # no suite specified
    let testFilter = suiteAndTestFilters[0]
    return glob(testName, testFilter)

  return glob(suiteName, suiteAndTestFilters[0]) and
         glob(testName, suiteAndTestFilters[1])

when defined(testing): export matchFilter

proc shouldRun(currentSuiteName, testName: string): bool =
  ## Check if a test should be run by matching suiteName and testName against
  ## test filters.
  withLock testFiltersLock:
    {.gcsafe.}:
      if testsFilters.len == 0:
        return true

      for f in testsFilters:
        if matchFilter(currentSuiteName, testName, f):
          return true

  return false

proc cleanupFormatters() {.noconv.} =
  withLock(formattersLock):
    for f in formatters.mitems():
      testRunEnded(f)

proc parseParameters*(args: openArray[string]) =
  withLock testFiltersLock:
    withLock formattersLock:
      # Read tests to run from the command line.
      for str in args:
        if str.startsWith("--help"):
          echo "Usage: [--xml=file.xml] [--console] [test-name-glob]"
          quit 0
        elif str.startsWith("--xml"):
          let fn = str[("--xml".len + 1)..^1] # skip separator char as well
          try:
            formatters.add(newJUnitOutputFormatter(
              newFileStream(fn, fmWrite)))
          except CatchableError as exc:
            echo "Cannot open ", fn, " for writing: ", exc.msg
            quit 1
        elif str.startsWith("--console"):
          formatters.add(defaultConsoleFormatter())
        else:
          testsFilters.incl(str)

proc ensureInitialized() =
  if autoParseArgs and declared(paramCount):
    parseParameters(commandLineParams())

  withLock formattersLock:
    if formatters.len == 0:
      formatters = @[OutputFormatter(defaultConsoleFormatter())]

  # Best-effort attempt to close formatters after the last test has run
  addExitProc(cleanupFormatters)

ensureInitialized() # Run once!

proc suiteStarted(name: string) =
  when paralleliseTests:
    repeatableSync() # wait for any independent tests from the threadpool before starting the suite
  withLock formattersLock:
    {.gcsafe.}:
      for formatter in formatters:
        formatter.suiteStarted(name)

proc suiteEnded() =
  when paralleliseTests:
    repeatableSync() # wait for a suite's tests from the threadpool before moving on to the next suite
  withLock formattersLock:
    {.gcsafe.}:
      for formatter in formatters:
        formatter.suiteEnded()

proc testStarted(name: string) =
  withLock formattersLock:
    {.gcsafe.}:
      for formatter in formatters:
        if not formatter.isNil:
          # Useless check that somehow prevents a method dispatch failure on macOS
          formatter.testStarted(name)

proc testEnded(testResult: TestResult) =
  withLock formattersLock:
    {.gcsafe.}:
      for formatter in formatters:
        when paralleliseTests:
          withLock outputLock:
            formatter.testEnded(testResult)
        else:
          formatter.testEnded(testResult)

template suite*(name, body) {.dirty.} =
  ## Declare a test suite identified by `name` with optional ``setup``
  ## and/or ``teardown`` section.
  ##
  ## A test suite is a series of one or more related tests sharing a
  ## common fixture (``setup``, ``teardown``). The fixture is executed
  ## for EACH test.
  ##
  ## .. code-block:: nim
  ##  suite "test suite for addition":
  ##    setup:
  ##      let result = 4
  ##
  ##    test "2 + 2 = 4":
  ##      check(2+2 == result)
  ##
  ##    test "(2 + -2) != 4":
  ##      check(2 + -2 != result)
  ##
  ##    # No teardown needed
  ##
  ## The suite will run the individual test cases in the order in which
  ## they were listed. With default global settings the above code prints:
  ##
  ## .. code-block::
  ##
  ##  [Suite] test suite for addition
  ##    [OK] 2 + 2 = 4
  ##    [OK] (2 + -2) != 4
  bind suiteStarted, suiteEnded

  block:
    template setup(setupBody: untyped) {.dirty, used.} =
      var testSetupIMPLFlag {.used.} = true
      template testSetupIMPL: untyped {.dirty.} = setupBody

    template teardown(teardownBody: untyped) {.dirty, used.} =
      var testTeardownIMPLFlag {.used.} = true
      template testTeardownIMPL: untyped {.dirty.} = teardownBody

    template suiteTeardown(suiteTeardownBody: untyped) {.dirty, used.} =
      var testSuiteTeardownIMPLFlag {.used.} = true
      template testSuiteTeardownIMPL: untyped {.dirty.} = suiteTeardownBody

    let testSuiteName {.used.} = name

    try:
      suiteStarted(name)
      body
      when declared(testSuiteTeardownIMPLFlag):
        when paralleliseTests:
          repeatableSync()
        testSuiteTeardownIMPL()
    finally:
      suiteEnded()

template exceptionTypeName(e: typed): string = $e.name

template checkpoint*(msg: string) =
  ## Set a checkpoint identified by `msg`. Upon test failure all
  ## checkpoints encountered so far are printed out. Example:
  ##
  ## .. code-block:: nim
  ##
  ##  checkpoint("Checkpoint A")
  ##  check((42, "the Answer to life and everything") == (1, "a"))
  ##  checkpoint("Checkpoint B")
  ##
  ## outputs "Checkpoint A" once it fails.
  checkpoints.add(msg)
  # TODO: add support for something like SCOPED_TRACE from Google Test

template fail* =
  ## Print out the checkpoints encountered so far and quit if ``abortOnError``
  ## is true. Otherwise, erase the checkpoints and indicate the test has
  ## failed (change exit code and test status). This template is useful
  ## for debugging, but is otherwise mostly used internally. Example:
  ##
  ## .. code-block:: nim
  ##
  ##  checkpoint("Checkpoint A")
  ##  complicatedProcInThread()
  ##  fail()
  ##
  ## outputs "Checkpoint A" before quitting.
  when declared(testStatusIMPL):
    testStatusIMPL = TestStatus.FAILED
  else:
    programResult = 1

  withLock formattersLock:
    {.gcsafe.}:
      for formatter in formatters:
        when declared(stackTrace):
          formatter.failureOccurred(checkpoints, stackTrace)
        else:
          formatter.failureOccurred(checkpoints, "")

  if abortOnError: quit(1)

  checkpoints = newSeq[string]()

template skip* =
  ## Mark the test as skipped. Should be used directly
  ## in case when it is not possible to perform test
  ## for reasons depending on outer environment,
  ## or certain application logic conditions or configurations.
  ## The test code is still executed.
  ##
  ## .. code-block:: nim
  ##
  ##  if not isGLContextCreated():
  ##    skip()
  bind checkpoints

  testStatusIMPL = TestStatus.SKIPPED
  checkpoints = @[]

template test*(name: string, body: untyped) =
  ## Define a single test case identified by `name`.
  ##
  ## .. code-block:: nim
  ##
  ##  test "roses are red":
  ##    let roses = "red"
  ##    check(roses == "red")
  ##
  ## The above code outputs:
  ##
  ## .. code-block::
  ##
  ##  [OK] roses are red
  bind shouldRun, checkpoints, testStarted, testEnded, exceptionTypeName

  # `gensym` can't be in here because it's not a first-class pragma
  when paralleliseTests:
    # We use "fastcall" to get proper error messages about variable access that
    # would make runTest() a closure - which we can't have in a spawned proc.
    # "nimcall" doesn't work here, because of https://github.com/nim-lang/Nim/issues/8473
    {.pragma: testrunner, gcsafe, fastcall.}
  else:
    {.pragma: testrunner.}

  proc runTest(testSuiteName: string, testName: string): int {.gensym, testrunner.} =
    checkpoints = @[]
    var testStatusIMPL {.inject.} = TestStatus.OK
    let testName {.inject.} = testName

    testStarted(testName)
    let startTime = getMonoTime()

    try:
      when declared(testSetupIMPLFlag): testSetupIMPL()
      when declared(testTeardownIMPLFlag):
        defer: testTeardownIMPL()
      block:
        body

    except CatchableError as e:
      let eTypeDesc = "[" & exceptionTypeName(e) & "]"
      checkpoint("Unhandled exception: " & e.msg & " " & eTypeDesc)
      if e == nil: # foreign
        fail()
      else:
        var stackTrace {.inject.} = e.getStackTrace()
        fail()

    except Defect as e: # This may or may not work dependings on --panics
      let eTypeDesc = "[" & exceptionTypeName(e) & "]"
      checkpoint("Unhandled defect: " & e.msg & " " & eTypeDesc)
      if e == nil: # foreign
        fail()
      else:
        var stackTrace {.inject.} = e.getStackTrace()
        fail()

    finally:
      if testStatusIMPL == TestStatus.FAILED:
        programResult = 1
      let testResult = TestResult(
        suiteName: testSuiteName,
        testName: testName,
        status: testStatusIMPL,
        duration: getMonoTime() - startTime
      )
      testEnded(testResult)
      checkpoints = @[]

  let optionalTestSuiteName = when declared(testSuiteName): testSuiteName else: ""
  let tname = name
  if shouldRun(optionalTestSuiteName, tname):
    when paralleliseTests:
      flowVars.add(spawn runTest(optionalTestSuiteName, tname))
    else:
      discard runTest(optionalTestSuiteName, tname)

{.pop.} # raises: [Defect]

macro check*(conditions: untyped): untyped =
  ## Verify if a statement or a list of statements is true.
  ## A helpful error message and set checkpoints are printed out on
  ## failure (if ``outputLevel`` is not ``PRINT_NONE``).
  runnableExamples:
    import std/strutils

    check("AKB48".toLowerAscii() == "akb48")

    let teams = {'A', 'K', 'B', '4', '8'}

    check:
      "AKB48".toLowerAscii() == "akb48"
      'C' notin teams

  {.warning[Deprecated]:off.}
  let checked = callsite()[1]
  {.warning[Deprecated]:on.}

  template asgn(a: untyped, value: typed) =
    var a = value # XXX: we need "var: var" here in order to
                  # preserve the semantics of var params

  template print(name: untyped, value: typed) =
    when compiles(string($value)):
      checkpoint(name & " was " & $value)

  proc inspectArgs(exp: NimNode): tuple[assigns, check, printOuts: NimNode] =
    result.check = copyNimTree(exp)
    result.assigns = newNimNode(nnkStmtList)
    result.printOuts = newNimNode(nnkStmtList)

    var counter = 0

    if exp[0].kind in {nnkIdent, nnkOpenSymChoice, nnkClosedSymChoice, nnkSym} and
        $exp[0] in ["not", "in", "notin", "==", "<=",
                    ">=", "<", ">", "!=", "is", "isnot"]:

      for i in 1 ..< exp.len:
        if exp[i].kind notin nnkLiterals:
          inc counter
          let argStr = exp[i].toStrLit
          let paramAst = exp[i]
          if exp[i].kind == nnkIdent:
            result.printOuts.add getAst(print(argStr, paramAst))
          if exp[i].kind in nnkCallKinds + {nnkDotExpr, nnkBracketExpr, nnkPar} and
                  (exp[i].typeKind notin {ntyTypeDesc} or $exp[0] notin ["is", "isnot"]):
            let callVar = newIdentNode(":c" & $counter)
            result.assigns.add getAst(asgn(callVar, paramAst))
            result.check[i] = callVar
            result.printOuts.add getAst(print(argStr, callVar))
          if exp[i].kind == nnkExprEqExpr:
            # ExprEqExpr
            #   Ident "v"
            #   IntLit 2
            result.check[i] = exp[i][1]
          if exp[i].typeKind notin {ntyTypeDesc}:
            let arg = newIdentNode(":p" & $counter)
            result.assigns.add getAst(asgn(arg, paramAst))
            result.printOuts.add getAst(print(argStr, arg))
            if exp[i].kind != nnkExprEqExpr:
              result.check[i] = arg
            else:
              result.check[i][1] = arg

  case checked.kind
  of nnkCallKinds:

    let (assigns, check, printOuts) = inspectArgs(checked)
    let lineinfo = newStrLitNode(checked.lineInfo)
    let callLit = checked.toStrLit
    result = quote do:
      block:
        `assigns`
        if not `check`:
          checkpoint(`lineinfo` & ": Check failed: " & `callLit`)
          `printOuts`
          fail()

  of nnkStmtList:
    result = newNimNode(nnkStmtList)
    for node in checked:
      if node.kind != nnkCommentStmt:
        result.add(newCall(newIdentNode("check"), node))

  else:
    let lineinfo = newStrLitNode(checked.lineInfo)
    let callLit = checked.toStrLit

    result = quote do:
      if not `checked`:
        checkpoint(`lineinfo` & ": Check failed: " & `callLit`)
        fail()

template require*(conditions: untyped) =
  ## Same as `check` except any failed test causes the program to quit
  ## immediately. Any teardown statements are not executed and the failed
  ## test output is not generated.
  let savedAbortOnError = abortOnError
  block:
    abortOnError = true
    check conditions
  abortOnError = savedAbortOnError

macro expect*(exceptions: varargs[typed], body: untyped): untyped =
  ## Test if `body` raises an exception found in the passed `exceptions`.
  ## The test passes if the raised exception is part of the acceptable
  ## exceptions. Otherwise, it fails.
  runnableExamples:
    import std/[math, random, strutils]
    proc defectiveRobot() =
      randomize()
      case rand(1..4)
      of 1: raise newException(OSError, "CANNOT COMPUTE!")
      of 2: discard parseInt("Hello World!")
      of 3: raise newException(IOError, "I can't do that Dave.")
      else: assert 2 + 2 == 5

    when (NimMajor, NimMinor, NimPatch) < (1, 4, 0):
      type AssertionDefect = AssertionError

    expect IOError, OSError, ValueError, AssertionDefect:
      defectiveRobot()

  template expectBody(errorTypes, lineInfoLit, body): NimNode {.dirty.} =
    try:
      try:
        body
        checkpoint(lineInfoLit & ": Expect Failed, no exception was thrown.")
        fail()
      except errorTypes:
        discard
    except CatchableError as e:
      checkpoint(lineInfoLit & ": Expect Failed, unexpected " & $e.name &
      " (" & e.msg & ") was thrown.\n" & e.getStackTrace())
      fail()
    except Defect as e:
      checkpoint(lineInfoLit & ": Expect Failed, unexpected " & $e.name &
      " (" & e.msg & ") was thrown.\n" & e.getStackTrace())
      fail()

  var errorTypes = newNimNode(nnkBracket)
  for exp in exceptions:
    errorTypes.add(exp)

  result = getAst(expectBody(errorTypes, errorTypes.lineInfo, body))

proc disableParamFiltering* {.deprecated:
    "Compile with -d:unittest2DisableParamFiltering instead".} =
  discard
