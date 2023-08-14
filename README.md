# FutharkCall.jl
How to run current example:
* Go to `src` and run `futhark c testlib.fut --library`
* Run `testlib.c -o testlib.so -fPIC -shared`
* Go back to the root of the project
* Run `julia src/FutharkCall.jl`
