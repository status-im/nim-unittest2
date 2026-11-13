import ../unittest2
from std/strutils import repeat

suite "successDisplay":
  test "0 and 1-9 are plain dots":
    check successDisplay(0) == ""
    for n in 1 .. 9:
      check successDisplay(n) == ".".repeat(n)

  test "9 dots compress to 1 colon at the 10th test":
    check successDisplay(10) == ":"
    check successDisplay(11) == ":."
    check successDisplay(19) == ":" & ".".repeat(9)

  test "colons accumulate, 9 of them compress to a dash":
    check successDisplay(20) == "::"
    check successDisplay(90) == ":".repeat(9)
    check successDisplay(99) == ":".repeat(9) & ".".repeat(9)
    check successDisplay(100) == "-"

  test "the ladder continues, cascading at every 9":
    check successDisplay(105) == "-" & ".".repeat(5)
    check successDisplay(190) == "-" & ":".repeat(9)
    check successDisplay(200) == "--"
    check successDisplay(900) == "-".repeat(9)
    check successDisplay(999) == "-".repeat(9) & ":".repeat(9) & ".".repeat(9)
    check successDisplay(1000) == "="
    check successDisplay(9999) == "=".repeat(9) & "-".repeat(9) & ":".repeat(9) & ".".repeat(9)

  test "mixed digits render most significant first":
    check successDisplay(50) == ":".repeat(5)
    check successDisplay(432) == "-".repeat(4) & ":".repeat(3) & ".".repeat(2)
    check successDisplay(1234) == "=" & "--" & ":".repeat(3) & ".".repeat(4)

when unittest2CompactDots:
  from std/os import removeFile
  from std/strutils import contains

  const
    tempName = "unittest2_dot_compression.tmp"

  suite "compact success dot compression":
    test "the display region is rewritten in place, padded, and the cursor returns to the display":
      let
        formatter = newConsoleOutputFormatter(OutputLevel.COMPACT, true)
        f = open(tempName, fmWrite)
      defer:
        f.close()
        removeFile(tempName)
      # 9 dots on screen (the 9th success); the 10th compresses them to a
      # single colon
      formatter.successCount = 10
      compressSuccessDots(formatter, f)
      let content = readFile(tempName)
      # Move back over the 9 dots, write the colon, pad with 8 spaces,
      # then move back over the padding so the next dot lands after the
      # colon - no line erase
      doAssert contains(content, "\e[9D")
      doAssert contains(content, ":")
      doAssert contains(content, " ".repeat(8))
      doAssert contains(content, "\e[8D")
      doAssert not contains(content, "\e[2K")

    test "a two-character display is padded and the cursor returns to it":
      let
        formatter = newConsoleOutputFormatter(OutputLevel.COMPACT, true)
        f = open(tempName, fmWrite)
      defer:
        f.close()
        removeFile(tempName)
      # 10 characters on screen (a colon and 9 dots, the 19th success);
      # the 20th compresses them to two colons
      formatter.successCount = 20
      compressSuccessDots(formatter, f)
      let content = readFile(tempName)
      doAssert contains(content, "\e[10D")
      doAssert contains(content, "::")
      doAssert contains(content, " ".repeat(8))
      doAssert contains(content, "\e[8D")
      doAssert not contains(content, "\e[2K")
