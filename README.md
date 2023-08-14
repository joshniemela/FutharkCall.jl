# FutharkCall.jl
How to run current example:
* Go to `src` and run `futhark c triangle.fut --library`
* Run `triangle.c -o testlib.so -fPIC -shared`
* Go back to the root of the project
* Run `julia src/FutharkCall.jl`
