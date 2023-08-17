using Test
const lib = "lib/testlib.so"
futhark_context_config = @ccall lib.futhark_context_config_new()::Ptr{Cvoid}
futhark_context = @ccall lib.futhark_context_new(futhark_context_config::Ptr{Cvoid})::Ptr{Cvoid}


@testset "Testing triangular numbers function (i32 -> i32)" begin
    test_in = 8
    test_out = Ref{Int32}(0)
    function triangular(n)::Int32
        return n * (n + 1) / 2
    end
    expected = triangular(test_in)

    @ccall lib.futhark_entry_triangle(
        futhark_context::Ptr{Cvoid},
        test_out::Ptr{Int32},
        test_in::Int32)::Int32
    @test test_out[] == expected


end


@testset "Testing 1 to n function (i32 -> []i32)" begin
    test_in = 8

    # test_out can be a vector instead of Ptr{C_int} since vectors are a reference type
    test_out = zeros(Int32, test_in)

    function one_to_n(n)::Array{Int32,1}
        return collect(1:n)
    end
    expected = one_to_n(test_in)
    futhark_array = Ref{Ptr{Cvoid}}(0)
    @ccall lib.futhark_entry_one_to_n(
        futhark_context::Ptr{Cvoid},
        futhark_array::Ptr{Ptr{Cvoid}},
        test_in::Int32)::Int32
    @ccall lib.futhark_values_i32_1d(
        futhark_context::Ptr{Cvoid},
        futhark_array[]::Ptr{Cvoid},
        test_out::Ptr{Int32})::Int32

    @test test_out == expected
end


@testset "Testing average function (f64[] -> f64)" begin
    test_in = [1.0, 2.0, 3.0, 4.0, 5.0]
    test_out = Ref{Float64}(0)
    function average(x::Array{Float64,1})::Float64
        return sum(x) / length(x)
    end
    expected = average(test_in)
    futhark_array = @ccall lib.futhark_new_f64_1d(
        futhark_context::Ptr{Cvoid},
        test_in::Ptr{Float64},
        length(test_in)::Int32)::Ptr{Cvoid}

    @ccall lib.futhark_entry_average(
        futhark_context::Ptr{Cvoid},
        test_out::Ptr{Float64},
        futhark_array::Ptr{Cvoid})::Int32


    @test test_out[] == expected
end
