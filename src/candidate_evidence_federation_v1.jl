const _CANDIDATE_EVIDENCE_LEVEL_V1 = Dict(
    "C0" => 0, "C1" => 1, "C2" => 2, "C3" => 3, "C4" => 4)

"""
Federate component evidence only when every observation is bound to the same
candidate physics hash. Family labels are intentionally not accepted as input.
Passing narrow C2 components cannot authorize complete C2 unless every required
component independently passes at C2 or above.
"""
function federate_candidate_evidence_v1(candidate_physics_hash::AbstractString,
        observations::AbstractVector)
    isempty(candidate_physics_hash) &&
        throw(ArgumentError("candidate_physics_hash must be non-empty"))
    isempty(observations) &&
        throw(ArgumentError("at least one observation is required"))
    components = Dict{String,Any}[]
    ids = String[]
    for raw in observations
        item = Dict{String,Any}(String(key) => value for (key, value) in raw)
        required_keys = ("component_id", "required_for_complete_c2", "status",
            "evidence_level", "hard_gate", "source_physics_hash")
        missing = String[id for id in required_keys if !haskey(item, id)]
        isempty(missing) || throw(ArgumentError(
            "component observation is missing: " * join(missing, ", ")))
        id = String(item["component_id"])
        isempty(id) && throw(ArgumentError("component_id must be non-empty"))
        status = String(item["status"])
        status in ("pass", "fail", "unknown") ||
            throw(ArgumentError("invalid component status: $status"))
        level = String(item["evidence_level"])
        haskey(_CANDIDATE_EVIDENCE_LEVEL_V1, level) ||
            throw(ArgumentError("invalid evidence level: $level"))
        String(item["source_physics_hash"]) == candidate_physics_hash ||
            throw(ArgumentError("component $id is bound to another physics hash"))
        push!(ids, id)
        push!(components, item)
    end
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("component_id values must be unique"))
    sort!(components; by = item -> String(item["component_id"]))

    required = filter(item -> item["required_for_complete_c2"] === true,
        components)
    isempty(required) && throw(ArgumentError(
        "at least one complete-C2 component must be required"))
    component_c2_pass_count = count(item -> item["status"] == "pass" &&
        _CANDIDATE_EVIDENCE_LEVEL_V1[String(item["evidence_level"])] >= 2,
        components)
    missing_complete_c2 = sort!(String[String(item["component_id"])
        for item in required if item["status"] != "pass" ||
        _CANDIDATE_EVIDENCE_LEVEL_V1[String(item["evidence_level"])] < 2])
    hard_falsified = any(item -> item["hard_gate"] === true &&
        item["status"] == "fail", components)
    complete_c2 = !hard_falsified && isempty(missing_complete_c2)
    status = hard_falsified ? "fail" : complete_c2 ? "pass" : "unknown"

    physical_summary = Dict{String,Any}(
        "candidate_physics_hash" => String(candidate_physics_hash),
        "components" => [Dict{String,Any}(
            "component_id" => String(item["component_id"]),
            "required_for_complete_c2" => item["required_for_complete_c2"],
            "status" => String(item["status"]),
            "evidence_level" => String(item["evidence_level"]),
            "hard_gate" => item["hard_gate"],
            "evidence_values" => get(item, "evidence_values", nothing))
            for item in components])
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "federator_version" => "candidate_evidence_federation_v1",
        "candidate_physics_hash" => String(candidate_physics_hash),
        "family_label_used" => false,
        "component_count" => length(components),
        "required_complete_c2_component_count" => length(required),
        "component_c2_pass_count" => component_c2_pass_count,
        "complete_c2_missing_components" => missing_complete_c2,
        "hard_falsified" => hard_falsified,
        "complete_c2_evidence_authorized" => complete_c2,
        "promotion_authorized" => false,
        "status" => status,
        "components" => components,
        "physical_evidence_hash" => canonical_hash(physical_summary),
        "claim_boundary" => "Component evidence is federated by exact candidate physics hash. Narrow component passes do not establish complete C2, all-mode stability, transport, engineering, fusion gain, net power or promotion.")
end
