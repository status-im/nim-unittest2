--verbosity:0
switch("passC", "-flto -O3")
switch("passL", "-flto -O3")
switch("passC", "-finline-limit=1000")
switch("passL", "-finline-limit=1000")
put("secp256k1.always", "-fno-lto")
#--define:useMalloc
