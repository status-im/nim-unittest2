set -eu
rm *.o -f

# Non-LTO
gcc -c -Wall -g -pedantic -fmax-errors=3 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @mo.nim.c.o @mo.nim.c

# LTO
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @psystem@sexceptions.nim.c.o @psystem@sexceptions.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @pstd@sprivate@sdigitsutils.nim.c.o @pstd@sprivate@sdigitsutils.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @pstd@sassertions.nim.c.o @pstd@sassertions.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @psystem@siterators.nim.c.o @psystem@siterators.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @psystem@sdollars.nim.c.o @psystem@sdollars.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @psystem.nim.c.o @psystem.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @phashes.nim.c.o @phashes.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @pmath.nim.c.o @pmath.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @ptables.nim.c.o @ptables.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @mt.nim.c.o @mt.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @ptimes.nim.c.o @ptimes.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @pstd@senvvars.nim.c.o @pstd@senvvars.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @pstd@scmdline.nim.c.o @pstd@scmdline.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @psets.nim.c.o @psets.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @me.nim.c.o @me.nim.c
gcc -c -Wall -g -pedantic -fmax-errors=3 -flto -finline-limit=1000 -O2 -fno-strict-aliasing -fno-ident -fno-math-errno -o @mw.nim.c.o @mw.nim.c
gcc   -o w  @psystem@sexceptions.nim.c.o @pstd@sprivate@sdigitsutils.nim.c.o @pstd@sassertions.nim.c.o @psystem@siterators.nim.c.o @psystem@sdollars.nim.c.o @psystem.nim.c.o @phashes.nim.c.o @pmath.nim.c.o @ptables.nim.c.o @mo.nim.c.o @mt.nim.c.o @ptimes.nim.c.o @pstd@senvvars.nim.c.o @pstd@scmdline.nim.c.o @psets.nim.c.o @me.nim.c.o @mw.nim.c.o  -lm -lm -lrt  -flto -finline-limit=1000
rm *.o
