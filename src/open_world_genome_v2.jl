"An open, family-neutral OTG v2 candidate and its deterministic identities."
struct OpenWorldGenomeV2
    data::Dict{String,Any}
    identity_hash::String
    structural_hash::String
    semantic_normal_form_hash::Union{Nothing,String}
    behavioral_signature_hash::Union{Nothing,String}
    legacy_hashes::Dict{String,String}
end

const _OWV2_NONSTRUCTURAL_KEYS = Set([
    "identity", "provenance", "classifications", "equivalence_claims",
    "search_metadata", "human_label", "label", "family", "parameter_specs",
    "parameter_bounds", "scale_bounds", "valid_parameter_ranges",
])

function _owv2_sorted_projection(value)
    plain = _plain_json(value)
    if plain isa AbstractDict
        result = Dict{String,Any}()
        for key in sort!(String.(collect(keys(plain))))
            key in _OWV2_NONSTRUCTURAL_KEYS && continue
            result[key] = _owv2_sorted_projection(plain[key])
        end
        return result
    elseif plain isa AbstractVector
        projected = Any[_owv2_sorted_projection(item) for item in plain]
        return sort!(projected; by = canonical_json)
    end
    return plain
end

"Minimal structural normal form: erase lineage, display labels, and non-routing classifications."
open_world_structural_projection_v2(value) = _owv2_sorted_projection(value)

function parse_open_world_genome_v2(value)
    data = _plain_json(value)
    data isa AbstractDict || throw(ArgumentError("OpenWorldGenomeV2 must be an object"))
    normalized = Dict{String,Any}(String(key) => _plain_json(item) for (key, item) in data)
    identity = get(normalized, "identity", Dict{String,Any}())
    provenance = get(normalized, "provenance", Dict{String,Any}())
    identity_hash = canonical_hash(Dict(
        "identity" => identity,
        "provenance" => provenance,
    ))
    structural_hash = canonical_hash(open_world_structural_projection_v2(normalized))
    legacy_hashes = Dict{String,String}()
    for key in ("content_hash", "physics_hash")
        haskey(normalized, key) && (legacy_hashes[key] = String(normalized[key]))
    end
    return OpenWorldGenomeV2(normalized, identity_hash, structural_hash,
        nothing, nothing, legacy_hashes)
end

function load_open_world_genome_v2(path::AbstractString)
    return parse_open_world_genome_v2(JSON3.read(read(path, String), Dict{String,Any}))
end

function open_world_genome_to_dict_v2(genome::OpenWorldGenomeV2)
    result = deepcopy(genome.data)
    result["hashes"] = Dict(
        "identity_hash" => genome.identity_hash,
        "structural_hash" => genome.structural_hash,
        "semantic_normal_form_hash" => genome.semantic_normal_form_hash,
        "behavioral_signature_hash" => genome.behavioral_signature_hash,
        "legacy_hashes" => genome.legacy_hashes,
    )
    return result
end

"Erase display classification without changing candidate physics or routing inputs."
function erase_open_world_labels_v2(value)
    data = value isa OpenWorldGenomeV2 ? deepcopy(value.data) : deepcopy(_plain_json(value))
    identity = get(data, "identity", nothing)
    identity isa AbstractDict && (identity["human_label"] = nothing)
    data["classifications"] = Any[]
    pop!(data, "family", nothing)
    return data
end

"Single-direction migration adapter. The sealed v1 object is never modified."
function migrate_genome_v1_to_v2(value)
    raw = value isa Genome ? deepcopy(value.raw) : deepcopy(_plain_json(value))
    raw isa AbstractDict || throw(ArgumentError("legacy genome must be an object"))
    design_id = String(get(raw, "design_id", "legacy_candidate"))
    old_hash = canonical_hash(raw)
    old_physics_hash = canonical_hash(physics_projection(raw))
    family = String(get(raw, "family", "unclassified"))
    mission = get(raw, "mission", Dict{String,Any}())
    topology = get(raw, "topology", Dict{String,Any}())
    regions = get(raw, "plasma_regions", Any[])
    fields = get(raw, "field_sources", Any[])
    state_variables = Any[
        Dict("state_id" => "legacy_state_$(index)", "domain_ref" => String(get(region, "id", "domain_$index")),
            "kind" => "legacy_state_bundle", "epistemic_state" => "declared_known")
        for (index, region) in enumerate(regions)
    ]
    domains = Any[
        Dict("domain_id" => String(get(region, "id", "domain_$index")),
            "kind" => "plasma", "geometry" => get(region, "geometry_model", "legacy_unspecified"))
        for (index, region) in enumerate(regions)
    ]
    isempty(domains) && push!(domains, Dict("domain_id" => "legacy_domain", "kind" => "plasma",
        "geometry" => get(topology, "field_line_class", "legacy_unspecified")))
    result = Dict{String,Any}(
        "schema_version" => "2.0.0",
        "identity" => Dict(
            "design_id" => design_id,
            "revision_id" => "$(design_id)_otg2_migration_v1",
            "parent_revision_ids" => Any[],
            "topology_skeleton_id" => "$(design_id)_topology",
            "model_choice_id" => "$(design_id)_legacy_models",
            "parameter_instance_id" => "$(design_id)_legacy_parameters",
            "human_label" => get(raw, "label", nothing),
        ),
        "provenance" => Dict("origin" => "legacy_migration", "legacy_schema_version" => get(raw, "schema_version", "unknown")),
        "mission_contracts" => Any[Dict("mission_id" => "legacy_mission", "legacy_payload" => mission,
            "claim_ceiling" => "C0")],
        "governance_policy_ref" => "open_world_governance_v2",
        "required_ruleset_refs" => Any["open_world_minimal_rules_v1"],
        "rule_coverage_requirement" => "explicit_gaps",
        "spacetime_support" => Dict("space_dimensions" => 3, "time_dimensions" => 1),
        "domains" => domains,
        "populations" => Any[],
        "state_variables" => state_variables,
        "interactions" => Any[
            Dict("interaction_id" => "legacy_field_source_$(index)", "inputs" => Any[], "outputs" => Any[],
                "affected_domains" => Any[String(get(domains[1], "domain_id", "legacy_domain"))],
                "operator_spec" => Dict("form" => "known_operator_ref", "ref" => String(get(field, "kind", "legacy_field_source"))),
                "conservation_effects" => Any[], "epistemic_state" => "declared_known",
                "promotion_scope_ref" => "legacy_structural_only")
            for (index, field) in enumerate(fields)
        ],
        "boundaries" => Any[], "reservoirs" => Any[], "invariants" => Any[],
        "actuators" => get(raw, "actuators", Any[]), "sensors" => Any[], "controls" => Any[],
        "observables" => Any[], "predictions" => Any[], "engineering_objects" => Any[], "hazards" => Any[],
        "applicability_claims" => Any[], "unknowns" => Any[],
        "evidence_obligation_graph" => Dict("obligations" => Any[], "dependencies" => Any[]),
        "promotion_scopes" => Any[Dict("scope_id" => "legacy_structural_only", "max_gate" => "none",
            "valid_missions" => Any["legacy_mission"], "valid_domains" => Any[], "valid_parameter_ranges" => Dict(),
            "valid_observables" => Any[], "calibration_refs" => Any[], "required_ruleset_hash" => "pending",
            "independent_confirmation_required" => true, "expiry_or_version" => "migration_v1")],
        "classifications" => Any[Dict("label" => family, "non_routing" => true, "source" => "legacy_family")],
        "equivalence_claims" => Any[], "extensions" => Dict("legacy_payload_hash" => old_hash),
        "content_hash" => old_hash, "physics_hash" => old_physics_hash,
    )
    return parse_open_world_genome_v2(result)
end
