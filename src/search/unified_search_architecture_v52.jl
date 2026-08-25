const _V52_PROFILE_TASKS = Dict{String,Vector{String}}(
    "universal_topology_ledger_v1" => [
        "recheck_topology_graph_and_interface_compatibility",
        "close_particle_energy_current_and_flux_ledgers",
    ],
    "steady_net_electric_ledger_v1" => [
        "recompute_candidate_bound_net_electric_ledger",
        "audit_recirculating_power_and_exhaust_paths",
    ],
    "pulsed_energy_ledger_v1" => [
        "recompute_single_pulse_and_repetition_rate_ledgers",
        "audit_driver_coupling_chamber_recovery_and_lifetime",
    ],
    "open_field_end_loss_v1" => [
        "solve_candidate_bound_parallel_and_ambipolar_end_loss",
        "audit_target_heat_and_particle_exhaust",
    ],
    "anisotropic_kinetic_stability_v1" => [
        "solve_anisotropic_finite_beta_equilibrium",
        "test_interchange_and_global_m1",
        "test_DCLC_and_AIC",
    ],
    "closed_field_global_modes_v1" => [
        "solve_candidate_bound_equilibrium",
        "test_global_ideal_resistive_and_kinetic_modes",
    ],
    "implosion_mix_lpi_v1" => [
        "solve_radiation_hydrodynamics_and_mix",
        "test_driver_plasma_coupling_and_laser_plasma_instabilities",
    ],
    "finite_coil_structure_v1" => [
        "solve_finite_coil_peak_field_force_and_stress",
        "audit_critical_surface_support_quench_and_maintenance",
    ],
)

function _v52_record(value)
    plain = _plain_json(value)
    plain isa AbstractDict || throw(ArgumentError("v52 search record must be an object"))
    return Dict{String,Any}(String(key) => _plain_json(item) for (key, item) in plain)
end

function _v52_module_tokens(record::AbstractDict)
    return lowercase.(String.(get(record, "module_ids", Any[])))
end

function _v52_has_token(tokens, needles)
    return any(token -> any(needle -> occursin(needle, token), needles), tokens)
end

"Infer validation obligations from declared modules and mission, never from a family label."
function unified_validation_profiles_v52(value)
    record = _v52_record(value)
    tokens = _v52_module_tokens(record)
    mission = lowercase(String(get(record, "mission_contract_id", "unspecified")))
    profiles = String["universal_topology_ledger_v1"]
    occursin("net_electric", mission) && push!(profiles, "steady_net_electric_ledger_v1")
    _v52_has_token(tokens, ("icf", "mtf", "liner", "pulse", "implosion")) &&
        push!(profiles, "pulsed_energy_ledger_v1")
    _v52_has_token(tokens, ("mirror", "zpinch", "open_field", "linear_end")) &&
        push!(profiles, "open_field_end_loss_v1")
    _v52_has_token(tokens, ("mirror", "kinetic", "fast_ion", "nbi", "anisotropic")) &&
        push!(profiles, "anisotropic_kinetic_stability_v1")
    _v52_has_token(tokens, ("tokamak", "stellarator", "spheromak", "rfp", "frc", "dipole")) &&
        push!(profiles, "closed_field_global_modes_v1")
    _v52_has_token(tokens, ("icf", "mtf", "liner", "implosion", "laser")) &&
        push!(profiles, "implosion_mix_lpi_v1")
    !_v52_has_token(tokens, ("icf", "laser_direct", "laser_indirect", "laser_fast")) &&
        push!(profiles, "finite_coil_structure_v1")
    return sort!(unique(profiles))
end

"Keep true lineage, physical references, model references, and validation routing separate."
function unified_search_relationships_v52(value)
    record = _v52_record(value)
    lineage = sort!(unique(String.(get(record, "lineage_parent_revision_ids", Any[]))))
    references = sort!(unique(String.(get(record, "physics_reference_ids", Any[]))))
    model_references = sort!(unique(filter(!isempty, String[
        String(get(record, "evaluator_id", "")),
        String(get(record, "projection_id", "")),
    ])))
    return Dict{String,Any}(
        "lineage_parent_revision_ids" => lineage,
        "physics_reference_ids" => references,
        "model_reference_ids" => model_references,
        "validation_profile_ids" => unified_validation_profiles_v52(record),
        "parent_synthesized_for_validation" => false,
        "relationship_policy" => "lineage_is_generation_history_not_a_validation_template",
    )
end

const _V52_GATE_ALIASES = Dict{String,Tuple{Vararg{String}}}(
    "variable_topology_representation_and_compatibility" => (
        "variable_topology_representation_and_compatibility",
        "variable_topology_representation"),
    "same_outer_envelope_contract" => (
        "same_outer_envelope_contract", "same_pulsed_outer_envelope_contract"),
    "unified_low_fidelity_physics" => (
        "unified_low_fidelity_physics",
        "first_principles_pulse_and_evidence_separation",
        "timescale_and_flux_ordering"),
    "minimal_engineering_closure" => (
        "minimal_engineering_closure", "shot_energy_and_average_power_closure"),
    "cheap_robustness_screen" => ("cheap_robustness_screen",),
)

function _v52_gate_status(gates, key::String; applicable = true)
    applicable || return "not_applicable"
    aliases = get(_V52_GATE_ALIASES, key, (key,))
    matches = String[alias for alias in aliases if haskey(gates, alias)]
    length(matches) == 1 || return "unknown"
    value = gates[only(matches)]
    value === true && return "pass"
    value === false && return "fail"
    return "unknown"
end

function _v52_robustness_status(record, gates)
    state = String(get(record, "robustness_evaluation_state", "legacy_flattened"))
    state == "pass" && return "pass"
    state == "evaluated_fail" && return "fail"
    state in ("not_evaluated_nominal_failure", "unknown", "legacy_flattened") ||
        return "unknown"
    _v52_gate_status(gates, "cheap_robustness_screen") == "pass" && return "pass"
    return "unknown"
end

function _v52_screen(id::String, status::String, layer::String, reason::String)
    return Dict{String,Any}(
        "screen_id" => id,
        "status" => status,
        "layer" => layer,
        "reason" => reason,
        "candidate_specific_override_allowed" => false,
    )
end

"Apply the same cheap gates to every record; applicability may yield not_applicable, never a free pass."
function unified_screen_candidate_v52(value)
    record = _v52_record(value)
    gates = Dict{String,Any}(String(key) => _plain_json(item) for (key, item) in
        get(record, "gates", Dict{String,Any}()))
    mission = lowercase(String(get(record, "mission_contract_id", "unspecified")))
    net_electric_applicable = occursin("net_electric", mission)
    topology_status = isempty(get(record, "topology_graph_errors", Any[])) ? "pass" : "fail"
    applicability_status = get(record, "proxy_applicable", false) === true ? "pass" : "fail"
    screens = Dict{String,Any}[
        _v52_screen("topology_graph_integrity", topology_status, "universal_hard_gate",
            "declared graph must be internally valid"),
        _v52_screen("evaluator_applicability", applicability_status, "universal_hard_gate",
            "the selected evaluator must declare applicability"),
        _v52_screen("topology_representation_compatibility",
            _v52_gate_status(gates, "variable_topology_representation_and_compatibility"),
            "universal_hard_gate", "candidate topology must be representable without graph contradiction"),
        _v52_screen("shared_outer_envelope",
            _v52_gate_status(gates, "same_outer_envelope_contract"),
            "universal_physics_gate", "comparison must stay inside the declared common envelope"),
        _v52_screen("low_fidelity_physics",
            _v52_gate_status(gates, "unified_low_fidelity_physics"),
            "universal_physics_gate", "common low-fidelity physics cannot be compensated by novelty"),
        _v52_screen("mission_power_ledger",
            net_electric_applicable ? (get(record, "positive_net_power_closure", false) === true ? "pass" : "fail") : "not_applicable",
            "universal_physics_gate", "net-electric missions require a positive closed proxy ledger"),
        _v52_screen("minimal_engineering_closure",
            _v52_gate_status(gates, "minimal_engineering_closure"),
            "validation_readiness_gate", "minimal engineering obligations must be explicit"),
        _v52_screen("cheap_robustness",
            _v52_robustness_status(record, gates),
            "validation_readiness_gate", "a skipped robustness suite remains unknown rather than fail"),
        _v52_screen("evaluator_requirement_coverage",
            get(record, "proxy_coverage_complete", false) === true ? "pass" : "unknown",
            "validation_readiness_gate", "missing evaluator requirements remain explicit unknowns"),
    ]
    hard_layers = Set(["universal_hard_gate", "universal_physics_gate"])
    blocking = [screen for screen in screens if screen["layer"] in hard_layers &&
        screen["status"] in ("fail", "unknown")]
    decision = isempty(blocking) ? "common_screen_pass" : "hard_reject_candidate_instance"
    relationships = unified_search_relationships_v52(record)
    modules = String.(get(record, "module_ids", Any[]))
    routing_basis = Dict{String,Any}(
        "module_ids" => modules,
        "mission_contract_id" => String(get(record, "mission_contract_id", "unspecified")),
        "evaluator_id" => String(get(record, "evaluator_id", "unknown")),
        "family_field_used_for_routing" => false,
    )
    cluster_basis = Dict{String,Any}(
        "field_module" => length(modules) >= 2 ? modules[2] : "missing",
        "stability_module" => length(modules) >= 3 ? modules[3] : "missing",
        "mission_contract_id" => routing_basis["mission_contract_id"],
        "evaluator_id" => routing_basis["evaluator_id"],
        "validation_profile_ids" => relationships["validation_profile_ids"],
    )
    family_label = String(get(record, "family", "unclassified"))
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "candidate_id" => String(get(record, "design_id", "unknown")),
        "candidate_index" => Int(get(record, "candidate_index", 0)),
        "assembly_index" => Int(get(record, "assembly_index", 0)),
        "sample_ordinal" => Int(get(record, "sample_ordinal", 0)),
        "physics_hash" => String(get(record, "physics_hash", "")),
        "proxy_result_hash" => String(get(record, "proxy_result_hash", "")),
        "graph_hash" => String(get(record, "graph_hash", "")),
        "relationships" => relationships,
        "routing_basis" => routing_basis,
        "non_routing_classifications" => Any[Dict(
            "label" => family_label, "source_field" => "legacy_family", "non_routing" => true)],
        "mechanism_cluster_id" => "mechanism_$(canonical_hash(cluster_basis)[1:20])",
        "cluster_basis" => cluster_basis,
        "screens" => screens,
        "failed_common_screen_ids" => String[screen["screen_id"] for screen in blocking],
        "decision" => decision,
        "gate_pass_count" => Int(get(record, "gate_pass_count", 0)),
        "positive_net_power_closure" => get(record, "positive_net_power_closure", false) === true,
        "robustness_pass_fraction" => Float64(get(record, "robustness_pass_fraction", 0.0)),
        "missing_proxy_requirements" => sort!(String.(get(record, "missing_proxy_requirements", Any[]))),
        "claim_level" => "C0_uniform_screen_only",
        "promotion_authorized" => false,
    )
end

function _v52_representative_key(record)
    return (
        record["decision"] == "common_screen_pass" ? 0 : 1,
        length(record["failed_common_screen_ids"]),
        -Int(record["gate_pass_count"]),
        record["positive_net_power_closure"] === true ? 0 : 1,
        length(record["missing_proxy_requirements"]),
        -Float64(record["robustness_pass_fraction"]),
        String(record["physics_hash"]),
    )
end

"Create a concrete plan only after a candidate is selected as a cluster representative."
function candidate_specific_validation_plan_v52(value)
    record = _v52_record(value)
    relationships = get(record, "relationships", unified_search_relationships_v52(record))
    profiles = String.(get(relationships, "validation_profile_ids", Any[]))
    tasks = String[]
    for screen in get(record, "screens", Any[])
        String(get(screen, "status", "unknown")) in ("fail", "unknown") &&
            push!(tasks, "resolve_screen:$(get(screen, "screen_id", "unknown"))")
    end
    for profile in profiles
        append!(tasks, get(_V52_PROFILE_TASKS, profile, String[]))
    end
    return Dict{String,Any}(
        "candidate_id" => String(get(record, "candidate_id", get(record, "design_id", "unknown"))),
        "plan_scope" => "selected_cluster_representative_only",
        "validation_profile_ids" => profiles,
        "ordered_tasks" => unique(tasks),
        "lineage_parent_created" => false,
        "promotion_authorized" => false,
        "stop_conditions" => Any["first_candidate_specific_hard_failure", "budget_exhausted", "all_tasks_resolved"],
    )
end

"Screen every candidate, cluster by mechanism/profile, and validate at most one representative per cluster."
function build_unified_search_archive_v52(values)
    screened = unified_screen_candidate_v52.(collect(values))
    clusters = Dict{String,Vector{Dict{String,Any}}}()
    for record in screened
        push!(get!(clusters, String(record["mechanism_cluster_id"]), Dict{String,Any}[]), record)
    end
    cluster_records = Dict{String,Any}[]
    representatives = Dict{String,Any}[]
    for cluster_id in sort!(collect(keys(clusters)))
        members = clusters[cluster_id]
        representative = sort!(copy(members); by = _v52_representative_key)[1]
        plan = candidate_specific_validation_plan_v52(representative)
        selected = deepcopy(representative)
        selected["candidate_specific_validation_plan"] = plan
        push!(representatives, selected)
        push!(cluster_records, Dict{String,Any}(
            "mechanism_cluster_id" => cluster_id,
            "cluster_basis" => representative["cluster_basis"],
            "candidate_count" => length(members),
            "common_screen_pass_count" => count(item -> item["decision"] == "common_screen_pass", members),
            "representative_candidate_id" => representative["candidate_id"],
            "representative_physics_hash" => representative["physics_hash"],
            "representative_validation_plan" => plan,
        ))
    end
    sort!(screened; by = item -> Int(item["candidate_index"]))
    sort!(representatives; by = item -> String(item["mechanism_cluster_id"]))
    return Dict{String,Any}(
        "screened_records" => screened,
        "cluster_records" => cluster_records,
        "representative_records" => representatives,
        "summary" => Dict{String,Any}(
            "input_candidate_count" => length(screened),
            "common_screen_pass_count" => count(item -> item["decision"] == "common_screen_pass", screened),
            "hard_reject_candidate_instance_count" => count(item -> item["decision"] == "hard_reject_candidate_instance", screened),
            "mechanism_cluster_count" => length(cluster_records),
            "candidate_specific_plan_count" => length(representatives),
            "parent_synthesis_count" => count(item -> item["relationships"]["parent_synthesized_for_validation"] === true, screened),
            "family_routed_count" => count(item -> item["routing_basis"]["family_field_used_for_routing"] === true, screened),
            "promotion_authorized_count" => count(item -> item["promotion_authorized"] === true, screened),
        ),
        "architecture_policy" => Dict{String,Any}(
            "search_mode" => "broad_uniform_screen_then_cluster_representative_validation",
            "lineage_policy" => "preserve_true_generation_history_only",
            "reference_policy" => "references_do_not_create_lineage",
            "routing_policy" => "module_mission_and_applicability_profiles_not_family_labels",
            "validation_policy" => "candidate_specific_plans_only_for_selected_cluster_representatives",
        ),
    )
end
