using JSON

const ExitStatus = Int32

futhark_types = Dict(
    "i8" => Int8,
    "i16" => Int16,
    "i32" => Int32,
    "i64" => Int64,
    "u8" => UInt8,
    "u16" => UInt16,
    "u32" => UInt32,
    "u64" => UInt64,
    "f32" => Float32,
    "f64" => Float64,
    "bool" => Bool,
)

lib_path = "lib"
so_path = joinpath(lib_path, "testlib.so")
manifest_path = joinpath(lib_path, "testlib.json")
manifest = JSON.parsefile(manifest_path)
if manifest["backend"] != "c"
    @warn "Only the C backend has been tested, other backends may work but have not been tested"
end

# read json
types = manifest["types"]
struct ArrayType
    ctype::String
    elemtype::DataType
    rank::Int
end
# arrays have the four following ops:
#  - new : this should be a constructor for the array
#  - free : this might not be necessary
#  - shape : this is the same as the size function
#  - values : this is the same as the getindex function
array_types = Vector{ArrayType}()
for (name, props) in types
    if props["kind"] != "array"
        error("Non-array types not implemented")
    end
    elem_type = futhark_types[props["elemtype"]]
    rank = props["rank"]
    ctype = split(props["ctype"], ' ')[2]
    futhark_types[name] = Array{elem_type,rank}
    push!(array_types, ArrayType(ctype, elem_type, rank))
end

# FutharkArray is only legal if there exists a rank and type in manifest
# FutharkArray{Int16, 1} is legal if there exists a type with elemtype "i16" and rank 1
abstract type AbstractFutharkArray end
# generate each futhark type from the list of array types
function generate_futhark_types(array_types)
    for array_type in array_types
        ctype = array_type.ctype |> uppercasefirst |> Symbol
        elemtype = array_type.elemtype |> Symbol
        rank = array_type.rank |> Symbol
        struct_type = :($ctype{$elemtype,$rank})
        @eval struct $struct_type <: AbstractFutharkArray
            _data::Ptr{Cvoid}
        end
        # function for new futhark array
        # futhark_array = @ccall lib.futhark_new_f64_1d(
        # futhark_context::Ptr{Cvoid},
        # test_in::Ptr{Float64},
        # length(test_in)::Int32)::Ptr{Cvoid}
        new_name = split(string(ctype), "Futhark_")[2]
        @eval $struct_type(futhark_context::Ptr{Cvoid}, data::Array{$elemtype,$rank}) = $struct_type(@ccall lib.futhark_new_$new_name(
            futhark_context::Ptr{Cvoid},
            data::Ptr{$elemtype},
            length(data)::Int32)::Ptr{Cvoid})

    end
end



function generate_futhark_library(library_path)
    isdir(library_path) || error("library_path must be a directory")
    # there should be one json and one so file
    so_files = filter(x -> endswith(x, ".so"), readdir(library_path))
    length(so_files) == 1 || error("library_path must contain exactly library file (*.so)")
    so_file = joinpath(library_path, so_files[1])
    manifest_files = filter(x -> endswith(x, ".json"), readdir(library_path))
    length(manifest_files) == 1 || error("library_path must contain exactly one manifest file (*.json)")
    manifest_file = joinpath(library_path, manifest_files[1])
    split(so_file, ".so")[1] == split(manifest_file, ".json")[1] || error("library_path must contain a manifest and library file with the same name")

    # remove the lib/ part of the library path
    lib_name = basename(so_file) |> x -> split(x, ".so")[1] |> uppercasefirst |> Symbol

    manifest = JSON.parsefile(manifest_file)
    manifest["backend"] == "c" || error("Only the C backend has been implemented")

    @eval module $lib_name
    struct FutharkContext
        _data::Ptr{Cvoid}
    end
    end


end
