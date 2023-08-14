const lib = "src/testlib.so"
# input is 32 bit integer
input = Int32(9)

futhark_context_config = @ccall lib.futhark_context_config_new()::Ptr{Cvoid}
futhark_context = @ccall lib.futhark_context_new(futhark_context_config::Ptr{Cvoid})::Ptr{Cvoid}



# out is a mutable pointer to i32
output = Ref{Int32}(0)
@ccall "./src/testlib.so".futhark_entry_triangle(futhark_context::Ptr{Cvoid}, output::Ptr{Int32}, input::Int32)::Int32


function triangle_number(n)::Int32
    return n * (n + 1) // 2
end
expected_output = triangle_number(input)


println("Input: $input")
println("Output: $(output[])")
println("Expected output: $expected_output")
@assert output[] == expected_output
