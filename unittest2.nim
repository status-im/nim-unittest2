import std/sets

type
  OutputLevel = enum  ## The output verbosity of the tests.
    COMPACT      ## Print failures and compact success information

  ConsoleOutputFormatter = ref object
    outputLevel: OutputLevel

var
  formatters: seq[ConsoleOutputFormatter]
  testsFilters: HashSet[string]

proc newConsoleOutputFormatter(): ConsoleOutputFormatter =
  ConsoleOutputFormatter()

proc defaultOutputLevel(): OutputLevel = COMPACT

proc parseParameters(args: openArray[string]) =
  var
    hasXml: string
    hasLevel = defaultOutputLevel()

  for str in args:
    if str == "--xml:" or str == "--xml=":
      hasXml = str["--xml".len..^1] # skip separator char as well
    else:
      testsFilters.incl(str)

  formatters.add(newConsoleOutputFormatter())

import std/os

proc ensureInitialized() =
  if declared(paramCount):
    parseParameters(commandLineParams())

ensureInitialized()
