--verbosity:0
--hints:off
--warnings:off
switch("passC", "-flto")
switch("passL", "-flto")
switch("passC", "-finline-limit=1000")
switch("passL", "-finline-limit=1000")
#--define:useMalloc
