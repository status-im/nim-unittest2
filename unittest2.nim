import std/[
  sets, strutils]

type
  OutputLevel = enum  ## The output verbosity of the tests.
    COMPACT      ## Print failures and compact success information

const
  nimUnittestOutputLevel = $COMPACT

type
  TestStatus = enum ## The status of a test when it is done.
    OK,
    FAILED

  OutputFormatter = ref object of RootObj

  ConsoleOutputFormatter = ref object of OutputFormatter
    outputLevel: OutputLevel
    statuses: array[TestStatus, int]

var
  formatters {.threadvar.}: seq[OutputFormatter]
  testsFilters {.threadvar.}: HashSet[string]

method testRunEnded(formatter: OutputFormatter) {.base, gcsafe.} =
  discard

proc newConsoleOutputFormatter(outputLevel: OutputLevel = COMPACT,
                                colorOutput = true): ConsoleOutputFormatter =
  ConsoleOutputFormatter(
    outputLevel: outputLevel,
  )

proc defaultColorOutput(): bool = false
proc defaultOutputLevel(): OutputLevel =
  const defaultLevel = static: nimUnittestOutputLevel.parseEnum[:OutputLevel]
  defaultLevel

proc defaultConsoleFormatter(): ConsoleOutputFormatter =
  newConsoleOutputFormatter(defaultOutputLevel(), defaultColorOutput())

proc parseParameters(args: openArray[string]) =
  var
    hasConsole = false
    hasXml: string
    hasVerbose = false
    hasLevel = defaultOutputLevel()

  for str in args:
    if str.startsWith("--xml:") or str.startsWith("--xml="):
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
    let level = hasLevel
    formatters.add(newConsoleOutputFormatter(level, defaultColorOutput()))

import std/os

proc ensureInitialized() =
  if declared(paramCount):
    parseParameters(commandLineParams())

  if formatters.len == 0:
    formatters = @[OutputFormatter(defaultConsoleFormatter())]

ensureInitialized()
