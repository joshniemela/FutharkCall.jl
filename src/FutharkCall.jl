#=using JSON

const ExitStatus = Int32

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
=#



module FutharkCall
const FUTHARK_PRMITIVES = Dict(
    Int8 => "i8",
    Int16 => "i16",
    Int32 => "i32",
    Int64 => "i64",
    UInt8 => "u8",
    UInt16 => "u16",
    UInt32 => "u32",
    UInt64 => "u64",
    Float32 => "f32",
    Float64 => "f64",
    Bool => "bool"
)
export generate_futhark_library
using JSON
function generate_futhark_library(library_path)
    isdir(library_path) || error("library_path must be a directory")
    # there should be one json and one so file
    so_files = filter(x -> endswith(x, ".so"), readdir(library_path))
    length(so_files) == 1 || error("library_path must contain exactly library file (*.so)")
    lib = joinpath(library_path, so_files[1])
    manifest_files = filter(x -> endswith(x, ".json"), readdir(library_path))
    length(manifest_files) == 1 || error("library_path must contain exactly one manifest file (*.json)")
    manifest_file = joinpath(library_path, manifest_files[1])
    split(lib, ".so")[1] == split(manifest_file, ".json")[1] || error("library_path must contain a manifest and library file with the same name")

    # remove the lib/ part of the library path
    lib_name = basename(lib) |> x -> split(x, ".so")[1] |> uppercasefirst |> Symbol

    manifest = JSON.parsefile(manifest_file)
    manifest["backend"] == "c" || error("Only the C backend has been implemented")

    println("Generating library $lib_name from $lib and $manifest_file")
    println("Backend: $(manifest["backend"])")

    @eval module $lib_name
    export FutharkContextConfig, FutharkContext

    struct FutharkContextConfig
        data::Ptr{Cvoid}
    end
    struct FutharkContext
        data::Ptr{Cvoid}
    end
    function make_context_config()
        config = @ccall $lib.futhark_context_config_new()::Ptr{Cvoid}
        FutharkContextConfig(config)
    end
    FutharkContextConfig() = make_context_config()

    function make_context(config::FutharkContextConfig)
        context = @ccall $lib.futhark_context_new(config.data::Ptr{Cvoid})::Ptr{Cvoid}
        FutharkContext(context)
    end
    FutharkContext(config::FutharkContextConfig) = make_context(config)
    FutharkContext() = FutharkContext(FutharkContextConfig())

    futhark_types = Dict{DataType, String}()
    for (key, value) in $FUTHARK_PRMITIVES
        futhark_types[key] = value
    end

    types = $(manifest["types"])
    for (name, props) in types
        props["kind"] == "array" || error("Only arrays are supported, got $(props["kind"])")
        println("Generating type $name")
        rank = props["rank"]
        rank == 1 || error("Only rank 1 arrays are supported, got $rank")
        elemtype = props["elemtype"]
        struct_name = split(props["ctype"], ' ')[2] |> uppercasefirst |> Symbol
        @eval begin
            struct $(split(props["ctype"], ' ')[2] |> uppercasefirst |> Symbol
                ctx::FutharkContext
                data::Ptr{Cvoid}
            end
        end



        println(props)
    end

end
end

end
