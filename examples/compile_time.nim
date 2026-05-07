import unittest2

func fastFib(n: int): int =
  if n <= 1:
    n
  else:
    fastFib(n - 1) + fastFib(n - 2)

# This test runs while the compiler is building your project!
staticTest "fibonacci constant folding":
  check fastFib(10) == 55
