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


input = [1.0, 2.0, 3.0, 4.0, 5.0]
function average(xs)::Float64
    return sum(xs) / length(xs)
end
futhark_array = @ccall lib.futhark_new_f64_1d(futhark_context::Ptr{Cvoid},
                                    input::Ptr{Float64},
                                    length(input)::Int32)::Ptr{Cvoid}

# entry average (xs: []f64) = reduce (+) 0 xs / f64.i64 (length xs)
output = Ref{Float64}(0.0)
@ccall lib.futhark_entry_average(futhark_context::Ptr{Cvoid},
                                    output::Ptr{Float64},
                                    futhark_array::Ptr{Cvoid})::Int32
println("Input: $input")
println("Output: $(output[])")
println("Expected output: $(average(input))")
@assert output[] == average(input)
