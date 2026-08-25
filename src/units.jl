const _UNIT_TABLE = Dict{String,Tuple{Float64,String}}(
    "1" => (1.0, "1"),
    "%" => (0.01, "1"),
    "m" => (1.0, "m"),
    "cm" => (1.0e-2, "m"),
    "mm" => (1.0e-3, "m"),
    "s" => (1.0, "s"),
    "ms" => (1.0e-3, "s"),
    "us" => (1.0e-6, "s"),
    "Hz" => (1.0, "Hz"),
    "m/s" => (1.0, "m/s"),
    "km/s" => (1.0e3, "m/s"),
    "kg/s" => (1.0, "kg/s"),
    "A" => (1.0, "A"),
    "kA" => (1.0e3, "A"),
    "MA" => (1.0e6, "A"),
    "A-turn" => (1.0, "A-turn"),
    "kA-turn" => (1.0e3, "A-turn"),
    "MA-turn" => (1.0e6, "A-turn"),
    "T" => (1.0, "T"),
    "T/m" => (1.0, "T/m"),
    "Wb" => (1.0, "Wb"),
    "V" => (1.0, "V"),
    "kV" => (1.0e3, "V"),
    "W" => (1.0, "W"),
    "kW" => (1.0e3, "W"),
    "MW" => (1.0e6, "W"),
    "GW" => (1.0e9, "W"),
    "J" => (1.0, "J"),
    "kJ" => (1.0e3, "J"),
    "MJ" => (1.0e6, "J"),
    "GJ" => (1.0e9, "J"),
    "eV" => (1.602176634e-19, "J"),
    "keV" => (1.602176634e-16, "J"),
    "MeV" => (1.602176634e-13, "J"),
    "rad" => (1.0, "rad"),
    "deg" => (pi / 180.0, "rad"),
    "Pa" => (1.0, "Pa"),
    "kPa" => (1.0e3, "Pa"),
    "MPa" => (1.0e6, "Pa"),
    "K" => (1.0, "K"),
    "kg" => (1.0, "kg"),
    "m^2" => (1.0, "m^2"),
    "m^3" => (1.0, "m^3"),
    "m^-3" => (1.0, "m^-3"),
    "W/m^2" => (1.0, "W/m^2"),
    "MW/m^2" => (1.0e6, "W/m^2"),
)

"A scalar quantity normalized to the canonical SI-like unit used by the IR."
struct Quantity
    value::Float64
    unit::String
    basis::Union{Nothing,String}

    function Quantity(value::Real, unit::AbstractString,
            basis::Union{Nothing,AbstractString} = nothing)
        isfinite(value) || throw(ArgumentError("quantity must be finite"))
        haskey(_UNIT_TABLE, String(unit)) ||
            throw(ArgumentError("unsupported unit: $(unit)"))
        scale, canonical_unit = _UNIT_TABLE[String(unit)]
        normalized = Float64(value) * scale
        normalized == -0.0 && (normalized = 0.0)
        return new(normalized, canonical_unit,
            basis === nothing ? nothing : String(basis))
    end
end

function _plain_json(value)
    if value isa AbstractDict
        return Dict{String,Any}(String(key) => _plain_json(item)
            for (key, item) in pairs(value))
    elseif value isa AbstractVector
        return Any[_plain_json(item) for item in value]
    elseif value isa JSON3.Object
        return Dict{String,Any}(String(key) => _plain_json(item)
            for (key, item) in pairs(value))
    elseif value isa JSON3.Array
        return Any[_plain_json(item) for item in value]
    end
    return value
end

_is_quantity_dict(value::AbstractDict) =
    haskey(value, "value") && haskey(value, "unit") &&
    value["value"] isa Real && value["unit"] isa AbstractString

"Recursively normalize every `{value, unit}` object while retaining its basis."
function normalize_units(value)
    plain = _plain_json(value)
    if plain isa AbstractDict
        if _is_quantity_dict(plain)
            q = Quantity(plain["value"], plain["unit"], get(plain, "basis", nothing))
            result = Dict{String,Any}("value" => q.value, "unit" => q.unit)
            q.basis === nothing || (result["basis"] = q.basis)
            for (key, item) in plain
                key in ("value", "unit", "basis") && continue
                result[key] = normalize_units(item)
            end
            return result
        end
        return Dict{String,Any}(String(key) => normalize_units(item)
            for (key, item) in plain)
    elseif plain isa AbstractVector
        return Any[normalize_units(item) for item in plain]
    elseif plain isa AbstractFloat
        isfinite(plain) || throw(ArgumentError("non-finite number in design IR"))
        return plain == -0.0 ? 0.0 : plain
    end
    return plain
end

function _canonical_write(io::IO, value)
    if value === nothing
        print(io, "null")
    elseif value isa Bool
        print(io, value ? "true" : "false")
    elseif value isa Integer
        print(io, value)
    elseif value isa AbstractFloat
        isfinite(value) || throw(ArgumentError("canonical JSON rejects non-finite numbers"))
        print(io, JSON3.write(value == -0.0 ? 0.0 : value))
    elseif value isa AbstractString || value isa Symbol
        print(io, JSON3.write(String(value)))
    elseif value isa AbstractDict
        print(io, "{")
        keys_sorted = sort!(String.(collect(keys(value))))
        for (index, key) in enumerate(keys_sorted)
            index == 1 || print(io, ",")
            print(io, JSON3.write(key), ":")
            _canonical_write(io, value[key])
        end
        print(io, "}")
    elseif value isa AbstractVector || value isa Tuple
        print(io, "[")
        for (index, item) in enumerate(value)
            index == 1 || print(io, ",")
            _canonical_write(io, item)
        end
        print(io, "]")
    else
        throw(ArgumentError("unsupported canonical JSON value: $(typeof(value))"))
    end
end

"Deterministic JSON with recursively sorted object keys."
function canonical_json(value)
    io = IOBuffer()
    _canonical_write(io, _plain_json(value))
    return String(take!(io))
end

canonical_hash(value) = bytes2hex(sha256(codeunits(canonical_json(value))))

"Remove identity and prose-only fields while retaining schema and physical inputs."
function physics_projection(value; _depth = 0)
    plain = _plain_json(value)
    if plain isa AbstractDict
        result = Dict{String,Any}()
        for (key, item) in plain
            _depth == 0 && key in ("design_id", "label", "provenance") && continue
            key == "basis" && _is_quantity_dict(plain) && continue
            result[String(key)] = physics_projection(item; _depth = _depth + 1)
        end
        return result
    elseif plain isa AbstractVector
        return Any[physics_projection(item; _depth = _depth + 1) for item in plain]
    end
    return plain
end
