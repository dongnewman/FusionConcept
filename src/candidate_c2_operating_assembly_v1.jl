const _C2_DECLARATION_PROVENANCE_V1 = Set((
    "candidate_design_declaration", "module_derived", "compiler_derived",
    "solver_initial_guess"))
const _C2_ROUTING_KEYS_V1 = Set(("family", "device_name", "candidate_name", "route"))

"A label-free, candidate-bound operating point. Declarations are inputs, not feasibility evidence."
struct CandidateOperatingPointV1
    schema_version::String
    base_candidate_binding_hash::String
    state_declarations::Vector{Dict{String,Any}}
    actuator_declarations::Vector{Dict{String,Any}}
    model_declarations::Vector{Dict{String,Any}}
    operating_point_hash::String
end

"A composite hash binding plasma, field source, boundary, actuators and engineering inputs."
struct CandidateAssemblyBindingV1
    schema_version::String
    base_candidate_binding_hash::String
    plasma_configuration_hash::String
    operating_point_hash::String
    field_source_component_hashes::Vector{String}
    boundary_hash::String
    actuator_manifest_hash::String
    engineering_manifest_hash::String
    assembly_hash::String
end

function _c2_plain_dict_v1(value)
    value isa AbstractDict || throw(ArgumentError("C2 declaration must be an object"))
    return Dict{String,Any}(String(key) => item for (key, item) in pairs(value))
end

function _c2_assert_label_free_v1(value, path::String = "declaration")
    if value isa AbstractDict
        for (key_any, child) in pairs(value)
            key = lowercase(String(key_any))
            key in _C2_ROUTING_KEYS_V1 && throw(ArgumentError(
                "$path contains forbidden routing key: $key"))
            _c2_assert_label_free_v1(child, "$path.$key")
        end
    elseif value isa AbstractVector
        for (index, child) in enumerate(value)
            _c2_assert_label_free_v1(child, "$path[$index]")
        end
    end
    return nothing
end

function _c2_validate_declarations_v1(values, kind::String)
    records = Dict{String,Any}[_c2_plain_dict_v1(value) for value in values]
    ids = String[]
    for record in records
        _c2_assert_label_free_v1(record, kind)
        id = String(get(record, "declaration_id", ""))
        isempty(id) && throw(ArgumentError("$kind declaration_id is required"))
        push!(ids, id)
        provenance = String(get(record, "provenance_kind", ""))
        provenance in _C2_DECLARATION_PROVENANCE_V1 || throw(ArgumentError(
            "$kind declaration has unsupported provenance_kind"))
        source_hash = String(get(record, "source_hash", ""))
        _c2_check_hash_v1(source_hash, "$kind declaration source hash")
        if haskey(record, "value")
            value = record["value"]
            value isa Real && !isfinite(Float64(value)) && throw(ArgumentError(
                "$kind declaration value must be finite"))
        end
        if haskey(record, "lower") && haskey(record, "upper")
            lower, upper = Float64(record["lower"]), Float64(record["upper"])
            isfinite(lower) && isfinite(upper) && lower <= upper || throw(ArgumentError(
                "$kind declaration bounds must be finite and ordered"))
            haskey(record, "value") && record["value"] isa Real &&
                !(lower <= Float64(record["value"]) <= upper) && throw(ArgumentError(
                    "$kind declaration value is outside its declared bounds"))
        end
    end
    length(unique(ids)) == length(ids) || throw(ArgumentError(
        "$kind declaration ids must be unique"))
    return sort!(records; by = item -> String(item["declaration_id"]))
end

function compile_candidate_operating_point_v1(; base_candidate_binding_hash,
        state_declarations, actuator_declarations, model_declarations)
    binding = _c2_check_hash_v1(String(base_candidate_binding_hash),
        "operating-point base candidate binding hash")
    states = _c2_validate_declarations_v1(state_declarations, "state")
    actuators = _c2_validate_declarations_v1(actuator_declarations, "actuator")
    models = _c2_validate_declarations_v1(model_declarations, "model")
    isempty(states) && throw(ArgumentError("operating point requires state declarations"))
    roles = Set(String(get(item, "role", "")) for item in actuators)
    required_roles = Set(("fueling", "heating", "exhaust", "radiation_control"))
    isempty(setdiff(required_roles, roles)) || throw(ArgumentError(
        "operating point must declare fueling, heating, exhaust and radiation-control actuators"))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "base_candidate_binding_hash" => binding,
        "state_declarations" => states, "actuator_declarations" => actuators,
        "model_declarations" => models)
    return CandidateOperatingPointV1("1.0.0", binding, states, actuators, models,
        canonical_hash(body))
end

function candidate_operating_point_to_dict_v1(item::CandidateOperatingPointV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "base_candidate_binding_hash" => item.base_candidate_binding_hash,
        "state_declarations" => item.state_declarations,
        "actuator_declarations" => item.actuator_declarations,
        "model_declarations" => item.model_declarations,
        "operating_point_hash" => item.operating_point_hash)
end

function compile_candidate_assembly_binding_v1(operating::CandidateOperatingPointV1;
        plasma_configuration_hash, field_source_component_hashes,
        boundary_hash, actuator_manifest_hash, engineering_manifest_hash)
    hashes = sort!(unique(String.(field_source_component_hashes)))
    isempty(hashes) && throw(ArgumentError(
        "assembly requires at least one explicitly selected field-source component"))
    plasma = _c2_check_hash_v1(String(plasma_configuration_hash),
        "plasma configuration hash")
    foreach(hash -> _c2_check_hash_v1(hash, "field-source component hash"), hashes)
    boundary = _c2_check_hash_v1(String(boundary_hash), "boundary hash")
    actuators = _c2_check_hash_v1(String(actuator_manifest_hash),
        "actuator manifest hash")
    engineering = _c2_check_hash_v1(String(engineering_manifest_hash),
        "engineering manifest hash")
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "base_candidate_binding_hash" => operating.base_candidate_binding_hash,
        "plasma_configuration_hash" => plasma,
        "operating_point_hash" => operating.operating_point_hash,
        "field_source_component_hashes" => hashes, "boundary_hash" => boundary,
        "actuator_manifest_hash" => actuators,
        "engineering_manifest_hash" => engineering)
    return CandidateAssemblyBindingV1("1.0.0", operating.base_candidate_binding_hash,
        plasma, operating.operating_point_hash, hashes, boundary, actuators,
        engineering, canonical_hash(body))
end

function candidate_assembly_binding_to_dict_v1(item::CandidateAssemblyBindingV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "base_candidate_binding_hash" => item.base_candidate_binding_hash,
        "plasma_configuration_hash" => item.plasma_configuration_hash,
        "operating_point_hash" => item.operating_point_hash,
        "field_source_component_hashes" => item.field_source_component_hashes,
        "boundary_hash" => item.boundary_hash,
        "actuator_manifest_hash" => item.actuator_manifest_hash,
        "engineering_manifest_hash" => item.engineering_manifest_hash,
        "assembly_hash" => item.assembly_hash)
end
