const _COORDINATE_ALIASES_V1 = Dict(
    "r-z" => "cylindrical_r_z", "rz" => "cylindrical_r_z", "cylindrical_rz" => "cylindrical_r_z",
    "cartesian" => "cartesian_xyz", "xyz" => "cartesian_xyz",
)

function _semantic_minimal_walk_v1(value)
    plain = _plain_json(value)
    if plain isa AbstractDict
        normalized = Dict{String,Any}()
        for key in sort!(String.(collect(keys(plain))))
            key in _OWV2_NONSTRUCTURAL_KEYS && continue
            item = plain[key]
            if key in ("coordinates", "coordinate_chart", "basis") && item isa AbstractString
                normalized[key] = get(_COORDINATE_ALIASES_V1, lowercase(String(item)), String(item))
            else
                normalized[key] = _semantic_minimal_walk_v1(item)
            end
        end
        return normalized
    elseif plain isa AbstractVector
        return sort!(Any[_semantic_minimal_walk_v1(item) for item in plain]; by = canonical_json)
    end
    return plain
end

function semantic_normal_form_minimal_v1(value)
    genome = value isa OpenWorldGenomeV2 ? value : parse_open_world_genome_v2(value)
    normalized_units = normalize_units(genome.data)
    form = _semantic_minimal_walk_v1(normalized_units)
    return Dict("normal_form" => form, "semantic_normal_form_hash" => canonical_hash(form),
        "proof_scope" => Any["supported_unit_conversions", "coordinate_aliases", "order_independent_arrays"],
        "unresolved_equivalence" => Any["gauge", "general_graph_isomorphism", "operator_theorem_proving"])
end

