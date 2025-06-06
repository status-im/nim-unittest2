import std/[
  sets, strutils]

when declared(stdout):
  import std/os

const useTerminal = declared(stdout) and not defined(js)

type
  OutputLevel = enum  ## The output verbosity of the tests.
    VERBOSE,     ## Print as much as possible.
    COMPACT      ## Print failures and compact success information
    FAILURES,    ## Print only failures
    NONE         ## Print nothing.

const
  outputLevelDefault = COMPACT
  nimUnittestOutputLevel {.strdefine.} = $outputLevelDefault
  nimUnittestColor {.strdefine.} = "auto" ## auto|on|off
  nimUnittestAbortOnError {.booldefine.} = false

when useTerminal:
  import std/terminal

const
  autoParseArgs = true

type
  TestStatus = enum ## The status of a test when it is done.
    OK,
    FAILED,
    SKIPPED

  TestResult = object
    suiteName: string
    testName: string
    status: TestStatus
    output: string
    errors: string

  OutputFormatter = ref object of RootObj

  ConsoleOutputFormatter = ref object of OutputFormatter
    colorOutput: bool
    outputLevel: OutputLevel

    curSuiteName: string
    curSuite: int
    curTestName: string
    curTest: int

    statuses: array[TestStatus, int]

    results: seq[TestResult]

    failures: seq[TestResult]

    errors: string

var
  abortOnError {.threadvar.}: bool

  formatters {.threadvar.}: seq[OutputFormatter]
  testsFilters {.threadvar.}: HashSet[string]

abortOnError = nimUnittestAbortOnError

when declared(stdout):
  if existsEnv("UNITTEST2_ABORT_ON_ERROR") or existsEnv("NIMTEST_ABORT_ON_ERROR"):
    abortOnError = true

method suiteStarted(formatter: OutputFormatter, suiteName: string) {.base, gcsafe.} =
  discard
method failureOccurred(formatter: OutputFormatter, checkpoints: seq[string],
    stackTrace: string) {.base, gcsafe.} =
  discard
method testEnded(formatter: OutputFormatter, testResult: TestResult) {.base, gcsafe.} =
  discard
method suiteEnded(formatter: OutputFormatter) {.base, gcsafe.} =
  discard

method testRunEnded(formatter: OutputFormatter) {.base, gcsafe.} =
  discard

proc newConsoleOutputFormatter(outputLevel: OutputLevel = outputLevelDefault,
                                colorOutput = true): ConsoleOutputFormatter =
  ConsoleOutputFormatter(
    outputLevel: outputLevel,
    colorOutput: colorOutput,
  )

proc defaultColorOutput(): bool =
  let color = nimUnittestColor
  case color
  of "auto":
    when declared(stdout): result = isatty(stdout)
    else: result = false
  of "on": result = true
  of "off": result = false
  else: raiseAssert "Unrecognised nimUnittestColor setting: " & color

  when declared(stdout):
    if existsEnv("NIMTEST_COLOR"):
      let colorEnv = getEnv("NIMTEST_COLOR")
      if colorEnv == "never":
        result = false
      elif colorEnv == "always":
        result = true
    elif existsEnv("NIMTEST_NO_COLOR"):
      result = false

proc defaultOutputLevel(): OutputLevel =
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

proc defaultConsoleFormatter(): ConsoleOutputFormatter =
  newConsoleOutputFormatter(defaultOutputLevel(), defaultColorOutput())

func formatStatus(status: string): string = discard
func formatStatus(status: TestStatus): string = discard

template write(
    formatter: ConsoleOutputFormatter, styled: untyped, unstyled: untyped) = discard

method suiteStarted(formatter: ConsoleOutputFormatter, suiteName: string) =
  formatter.curSuiteName = suiteName
  formatter.curSuite += 1

  formatter.curTest.reset()

  if formatter.outputLevel in {OutputLevel.FAILURES, OutputLevel.NONE}:
    return

  let
    counter =
      if formatter.outputLevel == VERBOSE: formatStatus("Suite") & " " else: ""
    maxNameLen = 0
    eol = if formatter.outputLevel == VERBOSE: "\n" else: " "
  formatter.write do:
    stdout.styledWrite(styleBright, fgBlue, counter, alignLeft(suiteName, maxNameLen), eol)
  do:
    stdout.write(counter, alignLeft(suiteName, maxNameLen), eol)
  stdout.flushFile()

method failureOccurred(formatter: ConsoleOutputFormatter,
                        checkpoints: seq[string], stackTrace: string) =
  if stackTrace.len > 0:
    formatter.errors.add(stackTrace)
    formatter.errors.add("\n")
  for msg in items(checkpoints):
    formatter.errors.add("    ")
    formatter.errors.add(msg)
    formatter.errors.add("\n")

proc printTestResultStatus(formatter: ConsoleOutputFormatter, testResult: TestResult) =
  let
    status = formatStatus(testResult.status)

  formatter.write do:
    stdout.styledWrite(
      "  ", styleBright, testResult.status.color, status, " ")
    stdout.write " ", testResult.testName
  do:
    stdout.styledWrite "  ", status, " ", testResult.testName
  echo ""

method testRunEnded(formatter: ConsoleOutputFormatter) =
  if formatter.outputLevel notin {VERBOSE, COMPACT} or
      (formatter.outputLevel == FAILURES and
        formatter.statuses[TestStatus.FAILED] > 0):
    return

  try:
    let total = 0
    stdout.write("[Summary] ", $total, " tests run ")

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

  for testResult in formatter.failures:
    formatter.printTestResultStatus(testResult)

proc parseParameters(args: openArray[string]) =
  var
    hasConsole = false
    hasXml: string
    hasVerbose = false
    hasLevel = defaultOutputLevel()

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

  if hasConsole or hasXml.len == 0:
    let level =
      if hasVerbose: OutputLevel.VERBOSE
      else: hasLevel
    formatters.add(newConsoleOutputFormatter(level, defaultColorOutput()))

proc ensureInitialized() =
  if autoParseArgs and declared(paramCount):
    parseParameters(commandLineParams())

  if formatters.len == 0:
    formatters = @[OutputFormatter(defaultConsoleFormatter())]

ensureInitialized() # Run once!
