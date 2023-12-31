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

# this returns a quoted struct definition and the operations for the struct
# example obj:
#=
    "[]f64": {
      "ctype": "struct futhark_f64_1d *",
      "elemtype": "f64",
      "kind": "array",
      "ops": {
        "free": "futhark_free_f64_1d",
        "new": "futhark_new_f64_1d",
        "shape": "futhark_shape_f64_1d",
        "values": "futhark_values_f64_1d"
      },
      "rank": 1
    },
=#



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

    manifest["version"] == "0.24.3" || error("Only version 0.24.3 has been tested")

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

    abstract type AbstractFutharkArray end
    function generate_array_definitions(lib, props)
        JULIA_PRIMITIVES = Dict(
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
            "bool" => Bool
        )
        type_name = split(props["ctype"], ' ')[2] |> uppercasefirst |> Symbol
        # use julia primitives from above
        elem_type = props["elemtype"] |> x -> JULIA_PRIMITIVES[x] |> Symbol
        rank = props["rank"]
        quote
            # generate the struct definition
            struct $type_name <: AbstractFutharkArray
                ctx::FutharkContext
                data::Ptr{Cvoid}
            end
            # generate the constructor, this has side effects (creates the futhark array)
            function to_futhark(ctx::FutharkContext, data::Array{$elem_type,$rank})
                # create the futhark array
                futhark_array = @ccall $lib.$(props["ops"]["new"])(
                    ctx.data::Ptr{Cvoid},
                    data::Ptr{Cvoid},
                    length(data)::Int32)::Ptr{Cvoid}
                # create the julia struct
                $type_name(ctx, futhark_array)
            end

            # generate the values function
        end
    end

    futhark_types = Dict{DataType,String}()
    for (key, value) in $FUTHARK_PRMITIVES
        futhark_types[key] = value
    end

    types = $(manifest["types"])
    for (name, props) in types
        props["kind"] == "array" || error("Only arrays are supported, got $(props["kind"])")
        println("Generating type $name")
        rank = props["rank"]
        rank == 1 || error("Only rank 1 arrays are supported, got $rank")
        # generate structs
        eval(generate_array_definitions($lib, props))
    end

    end
end

end
