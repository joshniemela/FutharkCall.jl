const lib = "src/testlib.so"
# input is 32 bit integer
input = Int32(9)

futhark_context_config = @ccall lib.futhark_context_config_new()::Ptr{Cvoid}
futhark_context = @ccall lib.futhark_context_new(futhark_context_config::Ptr{Cvoid})::Ptr{Cvoid}



# out is a mutable pointer to i32
output = Ref{Int32}(0)
# int futhark_entry_triangle(struct futhark_context *ctx, int32_t *out0, const int32_t in0);
@ccall lib.futhark_entry_triangle(futhark_context::Ptr{Cvoid}, output::Ptr{Int32}, input::Int32)::Int32


function triangle_number(n)::Int32
    return n * (n + 1) // 2
end
expected_output = triangle_number(input)


println("Input: $input")
println("Output: $(output[])")
println("Expected output: $expected_output")
@assert output[] == expected_output




function one_to_n(n)::Vector{Int32}
    return [i for i in 1:n]
end


futhark_array = Ref{Ptr{Cvoid}}(0)

# int futhark_entry_one_to_n(struct futhark_context *ctx, struct futhark_i32_1d **out0, const int32_t in0);
@ccall lib.futhark_entry_one_to_n(futhark_context::Ptr{Cvoid},
                                    futhark_array::Ptr{Ptr{Cvoid}},
                                    input::Int32)::Int32



# output should be an array of length 4 with type i32
output = zeros(Int32, input)

# int futhark_values_i32_1d(struct futhark_context *ctx, struct futhark_i32_1d *arr, int32_t *data);
@ccall lib.futhark_values_i32_1d(futhark_context::Ptr{Cvoid},
                                    futhark_array[]::Ptr{Cvoid},
                                    output::Ptr{Int32})::Int32

expected_output = one_to_n(input)
println("Input: $input")
println("Output: $output")
println("Expected output: $expected_output")

@assert output == expected_output
