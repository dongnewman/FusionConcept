"Append-only audit for deriving an executable candidate by adding actuators."
struct GenomeActuatorDerivationV1
    compiler_version::String
    base_design_id::String
    base_content_hash::String
    base_physics_hash::String
    derived_design_id::String
    derived_content_hash::String
    derived_physics_hash::String
    base_actuator_count::Int
    derived_actuator_count::Int
    added_actuator_ids::Vector{String}
    base_unchanged::Bool
    physics_hash_changed::Bool
    validation_valid::Bool
    validation_errors::Vector{String}
    validation_warnings::Vector{String}
    derivation_hash::String
end

function _genome_actuator_derivation_core_v1(; base::Genome, derived::Genome,
        added_actuator_ids::Vector{String}, base_unchanged::Bool,
        report::ValidationReport)
    return Dict{String,Any}(
        "compiler_version" => "genome_actuator_derivation_compiler_v1.0.0",
        "base_design_id" => base.design_id,
        "base_content_hash" => base.content_hash,
        "base_physics_hash" => base.physics_hash,
        "derived_design_id" => derived.design_id,
        "derived_content_hash" => derived.content_hash,
        "derived_physics_hash" => derived.physics_hash,
        "base_actuator_count" => length(base.actuators),
        "derived_actuator_count" => length(derived.actuators),
        "added_actuator_ids" => added_actuator_ids,
        "base_unchanged" => base_unchanged,
        "physics_hash_changed" => derived.physics_hash != base.physics_hash,
        "validation_valid" => report.valid,
        "validation_errors" => report.errors,
        "validation_warnings" => report.warnings)
end

"""
Derive a new immutable Genome by appending explicit actuator declarations.

This compiler changes the candidate physics hash because actuators are part of
the physics projection. It establishes structural candidate binding only; it
does not authorize any actuator deposition, source rate, or performance claim.
"""
function derive_genome_with_actuators_v1(base::Genome;
        design_id::AbstractString, label::Union{Nothing,AbstractString} = nothing,
        actuator_declarations::AbstractVector,
        source_ids::AbstractVector{<:AbstractString} = String[],
        notes::AbstractVector{<:AbstractString} = String[],
        claim_level::AbstractString = "structural_example")
    isempty(String(design_id)) && throw(ArgumentError(
        "derived design_id must not be empty"))
    String(design_id) == base.design_id && throw(ArgumentError(
        "derived design_id must differ from the base design_id"))
    isempty(actuator_declarations) && throw(ArgumentError(
        "at least one actuator declaration is required"))

    base_content_hash_before = base.content_hash
    base_physics_hash_before = base.physics_hash
    raw = deepcopy(base.normalized)
    existing = Any[deepcopy(item) for item in get(raw, "actuators", Any[])]
    additions = Any[_plain_json(deepcopy(item)) for item in actuator_declarations]
    added_ids = String[]
    for (index, item) in enumerate(additions)
        item isa AbstractDict || throw(ArgumentError(
            "actuator declaration $index must be an object"))
        haskey(item, "id") || throw(ArgumentError(
            "actuator declaration $index is missing id"))
        haskey(item, "kind") || throw(ArgumentError(
            "actuator declaration $index is missing kind"))
        haskey(item, "parameters") || throw(ArgumentError(
            "actuator declaration $index is missing parameters"))
        push!(added_ids, String(item["id"]))
    end
    all_ids = vcat(String[String(item["id"]) for item in existing], added_ids)
    length(unique(all_ids)) == length(all_ids) || throw(ArgumentError(
        "derived Genome actuator IDs must be unique"))

    raw["design_id"] = String(design_id)
    raw["label"] = isnothing(label) ? nothing : String(label)
    raw["actuators"] = vcat(existing, additions)
    provenance = raw["provenance"]
    provenance["origin"] = "generated"
    provenance["source_ids"] = sort!(unique(vcat(
        String.(get(provenance, "source_ids", Any[])), String.(source_ids))))
    provenance["parent_design_ids"] = sort!(unique(vcat(
        String.(get(provenance, "parent_design_ids", Any[])), [base.design_id])))
    provenance["claim_level"] = String(claim_level)
    provenance["notes"] = vcat(String.(get(provenance, "notes", Any[])),
        String.(notes), [
            "Actuator declarations alter the executable candidate physics hash but do not establish source deposition or performance."])

    derived = parse_genome(raw)
    report = validate_genome(derived)
    report.valid || throw(ArgumentError(
        "derived Genome failed validation: $(join(report.errors, "; "))"))
    base_unchanged = base.content_hash == base_content_hash_before &&
        base.physics_hash == base_physics_hash_before
    base_unchanged || error("base Genome changed during actuator derivation")
    derived.physics_hash != base.physics_hash || error(
        "actuator derivation did not change the physics hash")
    ids = sort!(unique(added_ids))
    core = _genome_actuator_derivation_core_v1(; base = base,
        derived = derived, added_actuator_ids = ids,
        base_unchanged = base_unchanged, report = report)
    audit = GenomeActuatorDerivationV1(
        "genome_actuator_derivation_compiler_v1.0.0",
        base.design_id, base.content_hash, base.physics_hash,
        derived.design_id, derived.content_hash, derived.physics_hash,
        length(base.actuators), length(derived.actuators), ids,
        base_unchanged, derived.physics_hash != base.physics_hash,
        report.valid, report.errors, report.warnings, canonical_hash(core))
    return derived, audit
end

function genome_actuator_derivation_to_dict_v1(audit::GenomeActuatorDerivationV1)
    return Dict{String,Any}(String(name) => getfield(audit, name)
        for name in fieldnames(typeof(audit)))
end
