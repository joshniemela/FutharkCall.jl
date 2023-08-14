-- Return the n'th triangle number
entry triangle (n: i32) : i32 = reduce (+) 0 (1...n)

entry one_to_n (n: i32) : []i32 = (1...n)


-- Taken from Futhark's main page
entry average (xs: []f64) = reduce (+) 0 xs / f64.i64 (length xs)
