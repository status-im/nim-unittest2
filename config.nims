--verbosity:0
switch("passC", "-flto")
switch("passL", "-flto")
switch("passC", "-finline-limit=1000")
switch("passL", "-finline-limit=1000")
#--define:useMalloc
