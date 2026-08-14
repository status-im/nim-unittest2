# unittest2
#
#        (c) Copyright 2015 Nim Contributors
#        (c) Copyright 2019-2021 Ștefan Talpalaru
#        (c) Copyright 2021-Onwards Status Research and Development
#

{.push raises: [].}

## :Authors: Zahary Karadjov, Ștefan Talpalaru, Status Research and Development

import std/[
  macros, sequtils, sets, strutils, streams, tables, times, monotimes]

when defined(nimHasWarnBareExcept):
  # In unit tests, we want to at least attempt to catch Exception no matter its
  # UB
  {.warning[BareExcept]: off.}

{.warning[LockLevel]: off.}

when declared(stdout):
  import std/os

const useTerminal = declared(stdout) and not defined(js)

type
  OutputLevel* = enum  ## The output verbosity of the tests.
    VERBOSE,     ## Print as much as possible.
    COMPACT      ## Print failures and compact success information
    FAILURES,    ## Print only failures
    NONE         ## Print nothing.

const
  outputLevelDefault = COMPACT
  slowThreshold = initDuration(seconds = 5)

  # `unittest` compatibility
  nimUnittestOutputLevel {.strdefine.} = $outputLevelDefault
    ## Set the default output level at compile time.
    ## Set with `-d:nimUnittestOutputLevel=VERBOSE|COMPACT|FAILURES|NONE`.
  nimUnittestColor {.strdefine.} = "auto"
    ## Set the color output mode at compile time.
    ## Set with `-d:nimUnittestColor=auto|on|off`.
  nimUnittestAbortOnError {.booldefine.} = false
    ## Set whether to abort on first error at compile time.
    ## Set with `-d:nimUnittestAbortOnError=true`.

  # `unittest2` compile-time configuration options
  unittest2DisableParamFiltering {.booldefine.} = false
    ## Disables automatic command line argument parsing - parsing is available
    ## via the `parseParameters` function instead.
    ## Set with `-d:unittest2DisableParamFiltering=true`.
  unittest2Compat {.booldefine.} = true # This will be disabled in the future
    ## Compatibility mode for `unittest` for easier porting and improved
    ## backwards compatibility - no stability guarantees.
    ## Set with `-d:unittest2Compat=false` to disable.
  unittest2NoCollect {.booldefine.} = false
    ## Disable test collection mode where tests are enumerated before they are
    ## run - in particular, this affects the order in which tests and suites
    ## have their bodies evaluated and disables several features that require
    ## knowing how many tests will be executed - experimental feature.
    ## Set with `-d:unittest2NoCollect=true`.
  unittest2PreviewIsolate {.booldefine.} = false
    ## Preview isolation mode where each test is run in a separate process - may
    ## be removed in the future.
    ## Set with `-d:unittest2PreviewIsolate=true`.
  unittest2Static* {.booldefine.} = false
    ## Run tests at compile time as well - only a subset of functionality is
    ## enabled at compile-time meaning that tests must be written
    ## conservatively. `suite` features (`setup` etc) in particular are not
    ## supported.
    ## Set with `-d:unittest2Static=true`.
  unittest2ListTests* {.booldefine.} = false
    ## List tests at runtime without actually running them (useful for test runners).
    ## Set with `-d:unittest2ListTests=true`.

when useTerminal:
  import std/terminal

const
  collect = (not unittest2NoCollect and not unittest2Compat) or unittest2PreviewIsolate or unittest2ListTests
  autoParseArgs = not unittest2DisableParamFiltering
  isolate = unittest2PreviewIsolate

when isolate:
  let
    isolated = getEnv("UNITTEST2_ISOLATED") == "1"
      ## Test is running in the isolated environment

from std/exitprocs import nil
template addExitProc(p: proc) =
  ## Register an exit handler and terminate with a diagnostic on failure.
  try:
    exitprocs.addExitProc(p)
  except Exception as e:
    echo "Can't add exit proc", e.msg
    quit(1)

type
  Test = object
    suiteName: string
    testName: string
    impl: proc(suite, name: string): TestStatus
    lineInfo: int
    filename: string

  TestStatus* = enum ## The status of a test when it is done.
    OK,
    FAILED,
    SKIPPED

  TestResult* = object
    ## Represents the result of a single test case execution.
    suiteName*: string
      ## Name of the test suite that contains this test case.
    testName*: string
      ## Name of the test case.
    status*: TestStatus
      ## Final status of the test (OK, FAILED, or SKIPPED).
    duration*: Duration
      ## How long the test took to execute.
    output*: string
      ## Combined stdout/stderr output captured during the test (if supported by the execution mode).
    errors*: string
      ## Failure diagnostics and checkpoints collected during the test.

  OutputFormatter* = ref object of RootObj
    ## Base class for all test output formatters.
    ## Custom formatters should inherit from this type and override its methods.

  ConsoleOutputFormatter* = ref object of OutputFormatter
    ## A formatter that prints test results to the console with optional color
    ## and various verbosity levels.
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
      ## Default is `VERBOSE`, or override with:
      ## `-d:nimUnittestOutputLevel:VERBOSE|FAILURES|NONE`.
      ##
      ## Deprecated: the `NIMTEST_OUTPUT_LVL` environment variable is set for the non-js target.

    when collect:
      tests: Table[string, int]

    curSuiteName: string
    curSuite: int
    curTestName: string
    curTest: int

    statuses: array[TestStatus, int]

    totalDuration: Duration

    results: seq[TestResult]

    failures: seq[TestResult]

    errors: string

  JUnitTest = object
    name: string
    result: TestResult
    error: (seq[string], string)
    failures: seq[seq[string]]

  JUnitSuite = object
    name: string
    tests: seq[JUnitTest]

  JUnitOutputFormatter* = ref object of OutputFormatter
    ## A formatter that writes test results in JUnit-compatible XML format.
    stream: Stream
    defaultSuite: JUnitSuite
    suites: seq[JUnitSuite]
    currentSuite: int

# TODO these globals are threadvar so as to avoid gc-safety-issues - this should
#      probably be resolved in a better way down the line specially since we
#      don't support threads _really_

var
  abortOnError* {.threadvar.}: bool
    ## Set to true in order to quit
    ## immediately on fail. Default is false,
    ## or override with `-d:nimUnittestAbortOnError:on|off`.

  checkpointsVm {.compileTime.}: seq[string]
  checkpoints {.threadvar.}: seq[string]
  formatters {.threadvar.}: seq[OutputFormatter]
  testsFilters {.threadvar.}: HashSet[string]

  currentSuite {.threadvar.}: string
  testStatus {.threadvar.}: TestStatus

when collect:
  var
    tests {.threadvar.}: OrderedTable[string, seq[Test]]

abortOnError = nimUnittestAbortOnError

when declared(stdout):
  if existsEnv("UNITTEST2_ABORT_ON_ERROR") or existsEnv("NIMTEST_ABORT_ON_ERROR"):
    abortOnError = true

when collect:
  method suiteRunStarted*(
      formatter: OutputFormatter, tests: OrderedTable[string, seq[Test]]) {.base, gcsafe.} =
    ## Called when a round of running discovered suites starts. 
    ## This is only relevant in Collect-and-Run mode.
    discard

method suiteStarted*(formatter: OutputFormatter, suiteName: string) {.base, gcsafe.} =
  ## Called before tests from `suiteName` start running.
  discard

method testStarted*(formatter: OutputFormatter, testName: string) {.base, gcsafe.} =
  ## Called before `testName` starts running.
  discard

method failureOccurred*(formatter: OutputFormatter, checkpoints: seq[string],
    stackTrace: string) {.base, gcsafe.} =
  ## Called when a check or expectation fails, or an unhandled exception occurs.
  ## ``stackTrace`` is provided only if the failure occurred due to an exception.
  ## ``checkpoints`` contains the list of checkpoints encountered before the failure.
  discard

method testEnded*(formatter: OutputFormatter, testResult: TestResult) {.base, gcsafe.} =
  ## Called when a test has finished and the final `testResult` is known.
  discard

method suiteEnded*(formatter: OutputFormatter) {.base, gcsafe.} =
  ## Called after all tests in the current suite have finished.
  discard

when collect:
  method suiteRunEnded*(
      formatter: OutputFormatter) {.base, gcsafe.} =
    ## Called when a round of running discovered suites ends.
    ## This is only relevant in Collect-and-Run mode.
    discard

method testRunEnded*(formatter: OutputFormatter) {.base, gcsafe.} =
  ## Called once when the full test run is about to terminate (usually via an exit proc).
  discard


when collect:
  proc suiteRunStarted(tests: OrderedTable[string, seq[Test]]) =
    ## Broadcast suite-run start event to all registered formatters.
    for formatter in formatters:
      formatter.suiteRunStarted(tests)

proc suiteStarted(name: string) =
  ## Broadcast suite start event to all registered formatters.
  for formatter in formatters:
    formatter.suiteStarted(name)

proc testStarted(name: string) =
  ## Broadcast test start event to all registered formatters.
  for formatter in formatters:
    formatter.testStarted(name)

proc testEnded(testResult: TestResult) =
  ## Broadcast test end event to all registered formatters.
  for formatter in formatters:
    formatter.testEnded(testResult)

proc suiteEnded() =
  ## Broadcast suite end event to all registered formatters.
  for formatter in formatters:
    formatter.suiteEnded()

when collect:
  proc suiteRunEnded() =
    ## Broadcast suite-run completion event to all registered formatters.
    for formatter in formatters:
      formatter.suiteRunEnded()

proc testRunEnded() =
  ## Finalize suite lifecycle and notify formatters that the run is complete.
  when not collect:
    if currentSuite.len > 0:
      suiteEnded()
      currentSuite.reset()

  for formatter in formatters:
    testRunEnded(formatter)

proc addOutputFormatter*(formatter: OutputFormatter) =
  ## Add an output formatter used for all subsequent reporting events.
  formatters.add(formatter)

proc resetOutputFormatters*() =
  ## Remove all currently registered output formatters.
  formatters.reset()

proc newConsoleOutputFormatter*(outputLevel: OutputLevel = outputLevelDefault,
                                colorOutput = true): ConsoleOutputFormatter =
  ## Create a console formatter with explicit verbosity and color settings.
  ConsoleOutputFormatter(
    outputLevel: outputLevel,
    colorOutput: colorOutput,
  )

proc defaultColorOutput(): bool =
  ## Resolve default console color behavior from compile-time and environment settings.
  let color = nimUnittestColor
  case color
  of "auto":
    when declared(stdout): result = isatty(stdout)
    else: result = false
  of "on": result = true
  of "off": result = false
  else: raiseAssert "Unrecognised nimUnittestColor setting: " & color

  when declared(stdout):
    # TODO unittest2-equivalent color parsing
    if existsEnv("NIMTEST_COLOR"):
      let colorEnv = getEnv("NIMTEST_COLOR")
      if colorEnv == "never":
        result = false
      elif colorEnv == "always":
        result = true
    elif existsEnv("NIMTEST_NO_COLOR"):
      result = false

proc defaultOutputLevel(): OutputLevel =
  ## Resolve output verbosity from environment and compile-time defaults.
  when declared(stdout):
    const levelEnv = "UNITTEST2_OUTPUT_LVL"
    const nimtestEnv = "NIMTEST_OUTPUT_LVL"
    if existsEnv(levelEnv):
      try:
        parseEnum[OutputLevel](getEnv(levelEnv))
      except ValueError:
        echo "Cannot parse UNITTEST2_OUTPUT_LVL: ", getEnv(levelEnv)
        quit 1
    elif existsEnv(nimtestEnv):
      # std-compatible parsing and translation
      case toUpper(getEnv(nimtestEnv))
      of "PRINT_ALL": OutputLevel.VERBOSE
      of "PRINT_FAILURES": OutputLevel.FAILURES
      of "PRINT_NONE": OutputLevel.NONE
      else:
        echo "Cannot parse NIMTEST_OUTPUT_LVL: ", getEnv(nimtestEnv)
        quit 1
    else:
      const defaultLevel = static: nimUnittestOutputLevel.parseEnum[:OutputLevel]
      defaultLevel

proc defaultConsoleFormatter*(): ConsoleOutputFormatter =
  ## Create the default console formatter honoring current runtime settings.
  newConsoleOutputFormatter(defaultOutputLevel(), defaultColorOutput())

const
  maxStatusLen = 7
  maxDurationLen = 6

func formatStatus(status: string): string =
  ## Render a padded status label enclosed in square brackets.
  "[" & alignLeft(status, maxStatusLen) & "]"

func formatStatus(status: TestStatus): string =
  ## Render a status enum as a padded bracketed label.
  formatStatus($status)

proc formatDuration(dur: Duration, aligned = true): string =
  ## Format a duration for human-readable test output.
  let
    seconds = dur.inMilliseconds.float / 1000.0
    precision = max(3 - ($seconds.int).len, 1)
    str = formatFloat(seconds, ffDecimal, precision)

  if aligned:
    "(" & align(str, maxDurationLen) & "s)"
  else:
    "(" & str & "s)"

when collect:
  proc formatFraction(cur, total: int): string =
    ## Render `cur/total` progress aligned for console output.
    let
      cur = $cur
      total = $total
    "[" & align(cur, max(0, maxStatusLen - total.len - 1)) & "/" & total & "]"

template write(
    formatter: ConsoleOutputFormatter, styled: untyped, unstyled: untyped) =
  ## Write to stdout with optional styling while suppressing terminal I/O exceptions.
  template ignoreExceptions(body: untyped) =
    # We ignore exceptions throughout assuming there's no way to
    try: body except CatchableError: discard

  when useTerminal:
    if formatter.colorOutput:
      ignoreExceptions: styled
    else: ignoreExceptions: unstyled
  else: ignoreExceptions: unstyled

when collect:
  method suiteRunStarted*(
      formatter: ConsoleOutputFormatter, tests: OrderedTable[string, seq[Test]]) =
    ## Initialize suite counters for a collect-mode run.
    for k, v in tests:
      formatter.tests[k] = v.len

when collect:
  method suiteRunEnded*(formatter: ConsoleOutputFormatter) =
    ## Clear collect-mode bookkeeping at the end of a suite run.
    formatter.tests.reset()

method suiteStarted*(formatter: ConsoleOutputFormatter, suiteName: string) =
  formatter.curSuiteName = suiteName
  formatter.curSuite += 1

  formatter.curTest.reset()

  if formatter.outputLevel in {OutputLevel.FAILURES, OutputLevel.NONE}:
    return

  let
    counter =
      when collect: formatFraction(formatter.curSuite, formatter.tests.len) & " "
      else:
        if formatter.outputLevel == VERBOSE: formatStatus("Suite") & " " else: ""
    maxNameLen = when collect: max(toSeq(formatter.tests.keys()).mapIt(it.len)) else: 0
    eol = if formatter.outputLevel == VERBOSE: "\n" else: " "
  formatter.write do:
    stdout.styledWrite(styleBright, fgBlue, counter, alignLeft(suiteName, maxNameLen), eol)
  do:
    stdout.write(counter, alignLeft(suiteName, maxNameLen), eol)
  stdout.flushFile()

proc writeTestName(formatter: ConsoleOutputFormatter, testName: string) =
  ## Write a test name using formatter color settings.
  formatter.write do:
    stdout.styledWrite fgBlue, testName
  do:
    stdout.write(testName)

method testStarted*(formatter: ConsoleOutputFormatter, testName: string) =
  formatter.curTestName = testName
  formatter.curTest += 1

  if formatter.outputLevel != VERBOSE:
    return

  # In verbose mode, print a line when the test starts so that output can be
  # correlated with the test that's currently running rather than misleadingly
  # being printed just below the test that just finished running.
  let
    counter =
      when collect:
        try: formatFraction(formatter.curTest, formatter.tests[formatter.curSuiteName]) & " "
        except CatchableError: ""
      else:
        formatStatus("Test")

  formatter.write do:
    stdout.styledWrite "  ", fgBlue, alignLeft(counter, maxStatusLen + maxDurationLen + 7)
  do:
    stdout.write "  ", alignLeft(counter, maxStatusLen + maxDurationLen + 7)

  writeTestName(formatter, testName)
  echo ""

method failureOccurred*(formatter: ConsoleOutputFormatter,
                        checkpoints: seq[string], stackTrace: string) =
  if stackTrace.len > 0:
    formatter.errors.add(stackTrace)
    formatter.errors.add("\n")
  for msg in items(checkpoints):
    formatter.errors.add("    ")
    formatter.errors.add(msg)
    formatter.errors.add("\n")

proc color(status: TestStatus): ForegroundColor =
  ## Map a `TestStatus` to a console foreground color.
  case status
  of TestStatus.OK: fgGreen
  of TestStatus.FAILED: fgRed
  of TestStatus.SKIPPED: fgYellow
proc marker(status: TestStatus): string =
  ## Map a `TestStatus` to compact progress marker text.
  case status
  of TestStatus.OK: "."
  of TestStatus.FAILED: "F"
  of TestStatus.SKIPPED: "s"

proc getAppFilename2(): string =
  ## Best-effort wrapper for obtaining the executable path.
  # TODO https://github.com/nim-lang/Nim/pull/22544
  try:
    getAppFilename()
  except OSError:
    ""

proc printFailureInfo(formatter: ConsoleOutputFormatter, testResult: TestResult) =
  ## Print rerun hint, test output, and failure diagnostics for one failing test.
  # Show how to re-run this test case
  echo repeat('=', testResult.testName.len)
  echo "  ", getAppFilename2(), " ", quoteShell(testResult.suiteName & "::" & testResult.testName)
  echo repeat('-', testResult.testName.len)

  # Show the output
  if testResult.output.len > 0:
    echo testResult.output
  if testResult.errors.len > 0:
    echo testResult.errors

proc printTestResultStatus(formatter: ConsoleOutputFormatter, testResult: TestResult) =
  ## Print a single test result line including status and duration.
  let
    status = formatStatus(testResult.status)
    duration = formatDuration(testResult.duration)

  formatter.write do:
    stdout.styledWrite(
      "  ", styleBright, testResult.status.color, status, " ")
    if testResult.duration > slowThreshold:
      stdout.styledWrite styleBright, duration
    else:
      stdout.write(duration)
    stdout.write " ", testResult.testName
  do:
    stdout.styledWrite "  ", status, " ", duration, " ", testResult.testName
  echo ""

method testEnded*(formatter: ConsoleOutputFormatter, testResult: TestResult) =
  formatter.statuses[testResult.status] += 1
  formatter.totalDuration += testResult.duration

  if formatter.outputLevel == NONE:
    return

  var testResult = testResult
  testResult.errors = move(formatter.errors)

  formatter.results.add(testResult)

  if formatter.outputLevel == VERBOSE and testResult.status == TestStatus.FAILED:
    # We'll print it again when all tests have completed
    formatter.failures.add testResult

  if formatter.outputLevel in {VERBOSE, FAILURES}:
    if testResult.status == TestStatus.FAILED:
      printFailureInfo(formatter, testResult)
    if formatter.outputLevel == VERBOSE or testResult.status == TestStatus.FAILED:
      printTestResultStatus(formatter, testResult)
  else:
    # In compact mode, we use a small marker to mark progress within the suite -
    # we have to be careful about line breaks and flushing so that the marker
    # really ends up on the screen where it's supposed to
    # TODO if the test writes to stdout, the display with be disrupted
    #      capturing / redirecting stdout with `dup2` or process isolation could
    #      fix this

    let
      marker = testResult.status.marker()
      color = testResult.status.color()
    formatter.write do:
        stdout.styledWrite styleBright, color, marker
    do:
      stdout.write marker
    stdout.flushFile()

method suiteEnded*(formatter: ConsoleOutputFormatter) =
  if formatter.outputLevel == OutputLevel.NONE:
    return

  let
    totalDur = formatter.results.foldl(a + b.duration, DurationZero)
    totalDurStr = formatDuration(totalDur, false)

  if formatter.outputLevel == OutputLevel.COMPACT:
    if formatter.results.len > 0:
      # Complete the line with timing information
      formatter.write do:
        if totalDur > slowThreshold:
          stdout.styledWrite(" ", styleBright, totalDurStr)
        else:
          stdout.write(" ", totalDurStr)
        echo ""
      do:
        echo(" ", totalDurStr)
    else:
      formatter.write do:
        # If no tests were run, remove the suite name
        stdout.eraseLine()
      do:
        stdout.writeLine("")

  var failed = false
  if formatter.outputLevel notin {VERBOSE, FAILURES}:
    for testResult in formatter.results:
      if testResult.status == TestStatus.FAILED:
        failed = true
        formatter.printFailureInfo(testResult)
        formatter.printTestResultStatus(testResult)
        echo ""

  formatter.results.reset()

  if failed or formatter.outputLevel == VERBOSE:
    formatter.write do:
      if totalDur > slowThreshold:
        stdout.styledWrite styleBright, align(totalDurStr, maxStatusLen)
      else:
        stdout.write(align(totalDurStr, maxStatusLen))
    do:
      stdout.write(align(totalDurStr, maxStatusLen))

    echo("   ", formatter.curSuiteName)
    echo("")

method testRunEnded*(formatter: ConsoleOutputFormatter) =
  if formatter.outputLevel notin {VERBOSE, COMPACT} or
      (formatter.outputLevel == FAILURES and
        formatter.statuses[TestStatus.FAILED] > 0):
    return

  let totalDurStr = formatDuration(formatter.totalDuration, false)

  try:
    let total = foldl(formatter.statuses, a + b, 0)
    stdout.write("[Summary] ", $total, " tests run ", totalDurStr, ": ")

    var first = true
    for s, c in formatter.statuses:
      if first:
        first = false
      else:
        stdout.write(", ")
      if c > 0:
        formatter.write do: stdout.styledWrite(s.color, $c, " ", $s)
        do: stdout.write($c, " ", $s)
      else:
        stdout.write($c, " ", $s)
    echo ""
  except CatchableError: discard

  # In verbose mode, it's likely failures got spammed away - print the specifics
  # so that they can more easily be looked up:
  for testResult in formatter.failures:
    formatter.printTestResultStatus(testResult)

proc xmlEscape(s: string): string =
  ## Escape a string for use in XML attributes and text nodes.
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
  ## Return the active JUnit suite, falling back to the default suite.
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
  ## Convert a `Duration` to fractional seconds.
  duration.inNanoseconds().float64 / 1_000_000_000.0

proc writeTest(s: Stream, test: JUnitTest) {.raises: [CatchableError].} =
  ## Serialize a single JUnit testcase element.
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
  ## Aggregate tests, failures, errors, skipped and elapsed time for one suite.
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

proc writeSuite(s: Stream, suite: JUnitSuite) {.raises: [CatchableError].} =
  ## Serialize one JUnit testsuite and all contained testcases.
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
  ## Globbing using exactly one `*`. Empty `filter` matches everything.
  ## Multiple asterisks are not supported and the second `*` will be treated
  ## as a literal character.
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
  ## Match a `suiteName::testName` pair against a single filter expression.
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
  when nimvm:
    true
  else:
    if testsFilters.len == 0:
      return true

    for f in testsFilters:
      if matchFilter(currentSuiteName, testName, f):
        return true

    return false

proc parseParameters*(args: openArray[string]) =
  ## Parse unittest2 CLI options and test filters from `args`.
  ##
  ## Recognized options include `--help`, `--xml`, `--console`,
  ## `--output-level`, and `--verbose`/`-v`.
  var
    hasConsole = false
    hasXml: string
    hasVerbose = false
    hasLevel = defaultOutputLevel()

  # Read tests to run from the command line.
  for str in args:
    if str.startsWith("--help"):
      echo "Usage: [--xml=file.xml] [--console] [--output-level=[VERBOSE,COMPACT,FAILURES,NONE]] [test-name-glob]"
      quit 0
    elif str.startsWith("--xml:") or str.startsWith("--xml="):
      hasXml = str[("--xml".len + 1)..^1] # skip separator char as well
    elif str.startsWith("--console"):
      hasConsole = true
    elif str.startsWith("--output-level:") or str.startsWith("--output-level="):
      hasLevel = try: parseEnum[OutputLevel](str[("--output-level".len + 1)..^1])
        except ValueError:
          echo "Unknown output level ", str[("--output-level".len + 1)..^1]
          quit 1
    elif str.startsWith("--verbose") or str == "-v":
      hasVerbose = true
    else:
      testsFilters.incl(str)
  if hasXml.len > 0:
    try:
      formatters.add(newJUnitOutputFormatter(newFileStream(hasXml, fmWrite)))
    except CatchableError as exc:
      echo "Cannot open ", hasXml, " for writing: ", exc.msg
      quit 1

  if hasConsole or hasXml.len == 0:
    let level =
      if hasVerbose: OutputLevel.VERBOSE
      else: hasLevel
    formatters.add(newConsoleOutputFormatter(level, defaultColorOutput()))

proc ensureInitialized() =
  ## Lazily initialize formatters and optionally parse process parameters.
  if autoParseArgs and declared(paramCount):
    parseParameters(commandLineParams())

  if formatters.len == 0:
    formatters = @[OutputFormatter(defaultConsoleFormatter())]

ensureInitialized() # Run once!

template suite*(nameParam: string, body: untyped) {.dirty.} =
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
  bind collect, currentSuite, suiteStarted, suiteEnded

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

    let suiteName {.inject.} = nameParam
    when nimvm:
      discard
    else:
      when not collect:
        # TODO deal with suite nesting
        if currentSuite.len > 0:
          suiteEnded()
          currentSuite.reset()
        currentSuite = suiteName

        suiteStarted(suiteName)

    # TODO what about exceptions in the suite itself?
    body

    when declared(testSuiteTeardownIMPLFlag):
      testSuiteTeardownIMPL()

    when nimvm:
      discard
    else:
      when not collect:
        suiteEnded()
        currentSuite.reset()

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
  when nimvm:
    {.cast(gcsafe).}:
      checkpointsVm.add msg
  else:
    bind checkpoints

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
  when nimvm:
    echo "Tests failed"
    {.cast(gcsafe).}:
      for msg in items(checkpointsVm):
        echo("    ")
        echo(msg)
        echo("\n")
    quit 1
  else:
    testStatus = TestStatus.FAILED

    exitProcs.setProgramResult(1)

    for formatter in formatters:
      let formatter = formatter # avoid lent iterator
      when declared(stackTrace):
        when stackTrace is string:
          formatter.failureOccurred(checkpoints, stackTrace)
        else:
          formatter.failureOccurred(checkpoints, "")
      else:
        formatter.failureOccurred(checkpoints, "")

    if abortOnError: quit(1)

    checkpoints.reset()

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
  when nimvm:
    {.cast(gcsafe).}:
      reset checkpointsVm
  else:
    bind checkpoints

    testStatus = TestStatus.SKIPPED
    checkpoints = @[]

proc runDirect(test: Test) =
  ## Execute a test instance immediately and report its result.
  when not collect:
    # In collection mode, we implicitly create a suite based on the module name
    # and start it based on the test list but in non-collect mode, we have to
    # emulate this with this hack
    if currentSuite != test.suiteName:
      if currentSuite.len > 0:
        suiteEnded()
      suiteStarted(test.suiteName)
      currentSuite = test.suiteName

  let startTime = getMonoTime()
  testStarted(test.testName)

  # TODO this annotation works around a limitation where we know that we only
  #      call the callback from the main thread but the compiler doesn't -
  #      when / if testing becomes multithreaded, this will need a proper
  #      solution
  {.gcsafe.}:
    let
      status = test.impl(test.suiteName, test.testName)
      duration = getMonoTime() - startTime

  testEnded(TestResult(
    suiteName: test.suiteName,
    testName: test.testName,
    status: status,
    duration: duration
  ))

template runtimeTest*(nameParam: string, body: untyped) =
  ## Define a test case that runs only at runtime.
  ## This is useful for tests that require OS features, I/O, or other 
  ## functionality not available in the Nim VM.
  bind collect, runDirect, shouldRun, checkpoints

  proc runTest(suiteName, testName: string): TestStatus {.raises: [], gensym.} =
    testStatus = TestStatus.OK
    template testStatusIMPL: var TestStatus {.inject, used.} = testStatus
    let suiteName {.inject, used.} = suiteName
    let testName {.inject, used.} = testName

    template fail(prefix: string, eClass: string, e: auto): untyped =
      let eName = "[" & $e.name & "]"
      checkpoint(prefix & "Unhandled " & eClass & ": " & e.msg & " " & eName)
      var stackTrace {.inject.} = e.getStackTrace()
      fail()

    template failingOnExceptions(prefix: string, code: untyped): untyped =
      when NimMajor>=2:
        {.push warning[UnnamedBreak]:off.}
      try:
        block:
          code
      except CatchableError as e:
        prefix.fail("error", e)
      except Defect as e: # This may or may not work dependings on --panics
        prefix.fail("defect", e)
      except Exception as e:
        prefix.fail("exception that may cause undefined behavior", e)
      when NimMajor>=2:
        {.pop.}

    failingOnExceptions("[setup] "):
      when declared(testSetupIMPLFlag): testSetupIMPL()
      defer: failingOnExceptions("[teardown] "):
        when declared(testTeardownIMPLFlag): testTeardownIMPL()
      failingOnExceptions(""):
        when not unittest2ListTests:
          body

    checkpoints = @[]

    testStatus

  let
    localSuiteName =
      when declared(suiteName):
        suiteName
      else:
        if currentSuite.len > 0:
          currentSuite
        else:
          instantiationInfo().filename
    localTestName = nameParam
  if shouldRun(localSuiteName, localTestName):
    let
      instance =
        Test(
          testName: localTestName, 
          suiteName: localSuiteName, 
          impl: runTest,
          lineInfo: instantiationInfo().line,
          filename: instantiationInfo().filename
        )
    when collect:
      tests.mgetOrPut(localSuiteName, default(seq[Test])).add(instance)
    else:
      runDirect(instance)

template staticTest*(nameParam: string, body: untyped) =
  ## Define a test case that runs only at compile-time in the Nim VM.
  ## This is useful for verifying logic, constant folding, and 
  ## type-level transformations during compilation.
  static:
    block:
      echo "[Test   ] ", nameParam
      body
      echo "[", TestStatus.OK, "     ] ", nameParam
    {.cast(gcsafe).}:
      reset checkpointsVm

template dualTest*(nameParam: string, body: untyped) =
  ## Define a test case that runs both at compile-time and runtime.
  ## This ensures that your code behaves consistently in both environments.
  staticTest nameParam:
    when not unittest2ListTests:
      body
  runtimeTest nameParam:
    when not unittest2ListTests:
      body

template test*(nameParam: string, body: untyped) =
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
  when nimvm:
    when unittest2Static:
      staticTest nameParam:
        when not unittest2ListTests:
          body
  runtimeTest nameParam:
    when not unittest2ListTests:
      body

{.pop.} # raises: []

iterator unittest2EvalOnceIter[T](x: T): auto =
  ## Helper iterator used by `check` to avoid evaluating expressions twice.
  yield x
iterator unittest2EvalOnceIter[T](x: var T): var T =
  ## Mutable variant of `unittest2EvalOnceIter`.
  yield x

template unittest2EvalOnce(name: untyped, param: typed, blk: untyped) =
  ## Bind `param` once and execute `blk` with the bound value.
  for name in unittest2EvalOnceIter(param):
    blk

macro check*(conditions: untyped): untyped =
  ## Verify if a statement or a list of statements is true.
  ## A helpful error message and set checkpoints are printed out on
  ## failure (if ``outputLevel`` is not ``NONE``).
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

  template print(name: untyped, value: typed) =
    when compiles($value):
      when typeof($value) is string:
        checkpoint(name & " was " & $value)

  proc inspectArgs(exp: NimNode): tuple[frame, inner, check, printOuts: NimNode] =
    result.check = copyNimTree(exp)
    result.inner = newNimNode(nnkStmtList)
    result.printOuts = newNimNode(nnkStmtList)

    var counter = 0
    let evalOnce = bindSym("unittest2EvalOnce")
    result.frame = result.inner
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
            result.frame = nnkCall.newTree(evalOnce, callVar, paramAst, result.frame)
            result.check[i] = callVar
            result.printOuts.add getAst(print(argStr, callVar))
          if exp[i].kind == nnkExprEqExpr:
            # ExprEqExpr
            #   Ident "v"
            #   IntLit 2
            result.check[i] = exp[i][1]
          if exp[i].typeKind notin {ntyTypeDesc}:
            let arg = newIdentNode(":p" & $counter)
            result.frame = nnkCall.newTree(evalOnce, arg, paramAst, result.frame)
            result.printOuts.add getAst(print(argStr, arg))
            if exp[i].kind != nnkExprEqExpr:
              result.check[i] = arg
            else:
              result.check[i][1] = arg

  proc buildCheck(lineinfo, callLit, check, printOuts: NimNode): NimNode =
    let
      checkpointSym = bindSym("checkpoint")
      failSym = bindSym("fail")
    nnkBlockStmt.newTree(
      newEmptyNode(),
      nnkStmtList.newTree(
        nnkIfStmt.newTree(
          nnkElifBranch.newTree(
            nnkCall.newTree(ident("not"), check),
            nnkStmtList.newTree(
              nnkCall.newTree(
                checkpointSym,
                nnkInfix.newTree(
                  ident("&"),
                  nnkInfix.newTree(
                    ident("&"),
                    lineinfo,
                    newLit(": Check failed: ")
                  ),
                  callLit
                )
              ),
              printOuts,
              nnkCall.newTree(failSym)
            )
          )
        )
      )
    )

  let
    checkSym = bindSym("check")

  case checked.kind
  of nnkCallKinds:
    let
      (frame, inner, check, printOuts) = inspectArgs(checked)
      lineinfo = newStrLitNode(checked.lineInfo)
      callLit = checked.toStrLit

    inner.add buildCheck(lineinfo, callLit, check, printOuts)
    result = frame
  of nnkStmtList:
    result = newNimNode(nnkStmtList)
    for node in checked:
      if node.kind != nnkCommentStmt:
        result.add(newCall(checkSym, node))

  else:
    let
      lineinfo = newStrLitNode(checked.lineInfo)
      callLit = checked.toStrLit

    result = buildCheck(
      lineinfo, callLit, checked, newEmptyNode())

template require*(conditions: untyped) =
  ## Same as `check` except any failed test causes the program to quit
  ## immediately. Any teardown statements are not executed and the failed
  ## test output is not generated.
  when nimvm:
    check conditions
  else:
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
  ## Deprecated runtime switch kept for source compatibility.
  discard

when unittest2PreviewIsolate:
  import std/[osproc, strtabs]
  proc runIsolated(test: Test) =
    ## Run one test in a child process and capture combined output.
    # Run test in an isolated process - this has the advantage that we can
    # trivially capture stdout but has a number of problems:
    # * suite and other global stuff gets executed for each test
    #   * on unix, `fork` could work around this but not on windows
    # * there's no good way to separate errors from stdout
    # * there's process overhead
    #
    # There are advantages too:
    # * reduced cross-test pollution
    # * simple to parallelise
    # * we can abort long-running tests after a timeout

    let startTime = getMonoTime()
    testStarted(test.testName)

    let runner = startProcess(
      getAppFilename2(),
      args = [test.suiteName & "::" & test.testName],
      env = newStringTable(
        "UNITTEST2_ISOLATED", "1",
        StringTableMode.modeCaseSensitive),
      options = {poStdErrToStdOut})

    close(runner.inputStream) # EOF so the test doesn't think it'll get input

    var output: string

    while true:
      let pos = output.len
      output.setLen(pos + 4096)

      let bytes = runner.outputStream.readData(addr output[pos], 4096)
      if bytes >= 0:
        output.setLen(pos + bytes)

      if bytes <= 0:
        break

    let status = runner.waitForExit()

    runner.close()

    testEnded(TestResult(
      suiteName: test.suiteName,
      testName: test.testName,
      status: if status == 0: TestStatus.OK else: TestStatus.FAILED,
      duration: getMonoTime() - startTime,
      output: output
    ))

  type
    IsolatedFormatter* = ref object of OutputFormatter
        ## Formatter suitable for using the process-isolated environment
        ##
        ## This is a work in progress with several open issues
        ## * we could use stderr for "unittest" traffic but it would be
        ##   compromised by application output (typically ok in nim) and makes
        ##   reading messy
        ## * we could print all errors after test providing some sort of
        ##   separator - has escape issues
        ## * we could redirect stdout/stderr to a file and use stdout for errors
        ## * as an addon to the above, we could read back the file then print
        ##   a structured test format to stdout which the parent process can
        ##   capture easily

  if isolated:
    formatters.add(IsolatedFormatter())

  method failureOccurred*(formatter: IsolatedFormatter,
                          checkpoints: seq[string], stackTrace: string) =
    if stackTrace.len > 0:
      echo(stackTrace)
      echo("\n")
    for msg in items(checkpoints):
      echo("    ")
      echo(msg)
      echo("\n")

when collect:
  proc runScheduledTests() {.noconv.} =
    ## Execute discovered tests, optionally listing them instead of running.
    # Tests can be added inside tests - this is weird and only partially
    # supported
    while tests.len > 0:
      var tmp = move(tests)
      when unittest2ListTests:
        for suiteName, suite in tmp:
          if suite.len == 0: continue
          echo "Suite: ", suiteName
          for test in suite:
            echo "\tTest: ", test.testName
            echo "\tFile: ", test.filename, ":", test.lineInfo
      else:
        suiteRunStarted(tmp)
        for suiteName, suite in tmp:
          if suite.len == 0: continue

          suiteStarted(suiteName)
          for test in suite:
            when isolate:
              if not isolated:
                runIsolated(test)
              else:
                runDirect(test)
            else:
              runDirect(test)

          suiteEnded()

        suiteRunEnded()
    when not unittest2ListTests:
      testRunEnded()

  addExitProc(runScheduledTests)

else:
  addExitProc(proc() {.noconv.} = testRunEnded())
