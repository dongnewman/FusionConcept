const V104_PROTOCOL_ID = "fusionconceptai-v104-whole-device-preflight-20260829"

const WHOLE_DEVICE_PREFLIGHT_V104_CLAIM_BOUNDARY =
    "v104 is a fail-closed campaign preflight. It does not promote, reject, or classify a " *
    "candidate when a required whole-device provider or candidate-bound input is absent. " *
    "Such a campaign is not executed; the candidate remains not_adjudicated_provider_gap, " *
    "never unsupported and never a physical pass or failure. Existing reduced or sampled " *
    "evidence cannot satisfy a complete whole-device obligation."

const V104_EVIDENCE_RANK = Dict(
    "none" => 0,
    "reduced_candidate_bound" => 1,
    "sampled_candidate_bound" => 2,
    "complete_candidate_bound" => 3,
    "independent_validation" => 4,
)

const V104_WHOLE_DEVICE_OBLIGATIONS = Dict{String,Any}[
    Dict(
        "obligation_id" => "free_boundary_equilibrium",
        "states" => ["magnetic_flux", "pressure"],
        "operators" => ["grad_shafranov"],
        "interfaces" => ["plasma_vacuum", "vacuum_coil"],
        "function_spaces" => ["axisymmetric_finite_volume"],
        "dimensions" => [2], "coordinates" => ["cylindrical_axisymmetric"],
        "required_output" => "candidate_bound_free_boundary_equilibrium",
        "required_evidence_level" => "complete_candidate_bound"),
    Dict(
        "obligation_id" => "cross_code_equilibrium",
        "states" => ["magnetic_flux", "pressure"],
        "operators" => ["force_balance"],
        "interfaces" => ["fixed_boundary_transform"],
        "function_spaces" => ["spectral_fixed_boundary"],
        "dimensions" => [3], "coordinates" => ["flux_coordinates"],
        "required_output" => "independent_equilibrium_comparison",
        "required_evidence_level" => "independent_validation"),
    Dict(
        "obligation_id" => "complete_stability",
        "states" => ["equilibrium", "perturbation"],
        "operators" => ["ideal_mhd", "resistive_mhd", "kinetic", "nonlinear"],
        "interfaces" => ["plasma_vacuum", "plasma_wall"],
        "function_spaces" => ["finite_n_global_modes", "kinetic_phase_space"],
        "dimensions" => [3], "coordinates" => ["flux_coordinates"],
        "required_output" => "all_applicable_mode_disposition",
        "required_evidence_level" => "complete_candidate_bound"),
    Dict(
        "obligation_id" => "transport_and_confinement",
        "states" => ["species_inventory", "thermal_energy"],
        "operators" => ["neoclassical_transport", "turbulent_transport", "orbit_loss",
            "radiation"],
        "interfaces" => ["core_edge", "edge_exhaust"],
        "function_spaces" => ["spatial_species_resolved"],
        "dimensions" => [3], "coordinates" => ["flux_coordinates"],
        "required_output" => "closed_particle_energy_balance",
        "required_evidence_level" => "complete_candidate_bound"),
    Dict(
        "obligation_id" => "particle_and_heat_exhaust",
        "states" => ["particle_flux", "heat_flux"],
        "operators" => ["scrape_off_layer", "neutral_transport", "plasma_surface_interaction"],
        "interfaces" => ["separatrix", "divertor_target", "vacuum_pump"],
        "function_spaces" => ["open_field_edge_volume"],
        "dimensions" => [3], "coordinates" => ["field_aligned_open"],
        "required_output" => "target_load_and_particle_throughput",
        "required_evidence_level" => "complete_candidate_bound"),
    Dict(
        "obligation_id" => "complete_engineering_and_materials",
        "states" => ["electromagnetic_load", "temperature", "stress", "damage"],
        "operators" => ["finite_conductor", "thermal_hydraulics", "structural_mechanics",
            "neutron_damage", "quench_protection"],
        "interfaces" => ["plasma_wall", "blanket_shield", "coil_support", "coolant"],
        "function_spaces" => ["finite_component_mesh"],
        "dimensions" => [3], "coordinates" => ["component_geometry"],
        "required_output" => "component_margin_inventory",
        "required_evidence_level" => "complete_candidate_bound"),
    Dict(
        "obligation_id" => "dynamic_control_and_fault_response",
        "states" => ["plasma_state", "coil_current", "thermal_state", "protection_state"],
        "operators" => ["closed_loop_control", "fault_transient", "protection_logic"],
        "interfaces" => ["sensor_controller", "controller_actuator", "fault_protection"],
        "function_spaces" => ["time_dependent_state_space"],
        "dimensions" => [0, 1, 2, 3], "coordinates" => ["time_and_component_geometry"],
        "required_output" => "fault_envelope_disposition",
        "required_evidence_level" => "complete_candidate_bound"),
    Dict(
        "obligation_id" => "numerical_vvuq",
        "states" => ["all_whole_device_outputs"],
        "operators" => ["mesh_convergence", "solver_replay", "uncertainty_propagation"],
        "interfaces" => ["all_provider_boundaries"],
        "function_spaces" => ["provider_native"],
        "dimensions" => [0, 1, 2, 3], "coordinates" => ["provider_native"],
        "required_output" => "whole_device_numerical_vvuq",
        "required_evidence_level" => "complete_candidate_bound"),
    Dict(
        "obligation_id" => "validation_vvuq",
        "states" => ["validation_observables"],
        "operators" => ["independent_comparison", "uncertainty_aware_validation"],
        "interfaces" => ["model_to_validation_observable"],
        "function_spaces" => ["declared_validation_domain"],
        "dimensions" => [0, 1, 2, 3], "coordinates" => ["validation_native"],
        "required_output" => "candidate_bound_validation_disposition",
        "required_evidence_level" => "independent_validation"),
]

function default_whole_device_provider_inventory_v104()
    Dict{String,Any}[
        Dict("provider_key" => "freegs_candidate_bound_v100", "obligation_id" =>
            "free_boundary_equilibrium", "evidence_level" => "complete_candidate_bound",
            "status" => "available", "input_contract" =>
            ["operating_point", "magnet_layout", "freegs_mesh_ensemble"]),
        Dict("provider_key" => "desc_cross_code_v100", "obligation_id" =>
            "cross_code_equilibrium", "evidence_level" => "independent_validation",
            "status" => "available", "input_contract" =>
            ["freegs_boundary", "pressure_profile", "iota_profile"]),
        Dict("provider_key" => "desc_sampled_local_ideal_mhd_v100", "obligation_id" =>
            "complete_stability", "evidence_level" => "sampled_candidate_bound",
            "status" => "available", "input_contract" =>
            ["desc_equilibrium", "mercier_grid", "infinite_n_ballooning_grid"]),
        Dict("provider_key" => "ipb98y2_zero_d_v98", "obligation_id" =>
            "transport_and_confinement", "evidence_level" => "reduced_candidate_bound",
            "status" => "available", "input_contract" => ["operating_point"]),
        Dict("provider_key" => "reduced_exhaust_area_v98", "obligation_id" =>
            "particle_and_heat_exhaust", "evidence_level" => "reduced_candidate_bound",
            "status" => "available", "input_contract" => ["transport_loss", "wall_area"]),
        Dict("provider_key" => "static_pf_engineering_v100", "obligation_id" =>
            "complete_engineering_and_materials", "evidence_level" =>
            "sampled_candidate_bound", "status" => "available", "input_contract" =>
            ["magnet_layout", "nine_static_perturbations"]),
        Dict("provider_key" => "static_pf_response_v100", "obligation_id" =>
            "dynamic_control_and_fault_response", "evidence_level" =>
            "sampled_candidate_bound", "status" => "available", "input_contract" =>
            ["nine_static_perturbations"]),
        Dict("provider_key" => "v98_mesh_replay_uq", "obligation_id" =>
            "numerical_vvuq", "evidence_level" => "sampled_candidate_bound",
            "status" => "available", "input_contract" =>
            ["reduced_physics", "freegs_mesh_ensemble"]),
    ]
end

function compile_whole_device_preflight_v104(capability_raw;
        providers = default_whole_device_provider_inventory_v104())
    capability = Dict{String,Any}(_v93_plain(capability_raw))
    routing = Dict{String,Any}(
        "route" => capability["route"],
        "declared_field_semantics" => sort!(String.(capability["declared_field_semantics"])),
        "declared_boundaries" => sort!(String.(capability["declared_boundaries"])),
        "declared_operators" => sort!(String.(capability["declared_operators"])),
        "declared_dimensions" => sort!(Int.(capability["declared_dimensions"])))
    inventory = Dict{String,Any}.(_v93_plain(providers))
    rows = Dict{String,Any}[]
    for obligation_raw in V104_WHOLE_DEVICE_OBLIGATIONS
        obligation = deepcopy(obligation_raw)
        matches = [provider for provider in inventory if
            provider["obligation_id"] == obligation["obligation_id"] &&
            provider["status"] == "available"]
        required = V104_EVIDENCE_RANK[String(obligation["required_evidence_level"])]
        qualified = [provider for provider in matches if
            V104_EVIDENCE_RANK[String(provider["evidence_level"])] >= required]
        status = !isempty(qualified) ? "closed" : isempty(matches) ?
            "missing_provider" : "insufficient_evidence_level"
        push!(rows, Dict{String,Any}(
            "obligation" => obligation, "status" => status,
            "matching_provider_keys" => sort!(String.(getindex.(matches, "provider_key"))),
            "qualified_provider_keys" => sort!(String.(getindex.(qualified, "provider_key"))),
            "best_available_evidence_level" => isempty(matches) ? "none" :
                first(sort!(String.(getindex.(matches, "evidence_level"));
                    by = value -> -V104_EVIDENCE_RANK[value])),
            "candidate_identity_used_for_routing" => false))
    end
    closed = all(row -> row["status"] == "closed", rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V104_PROTOCOL_ID,
        "status" => closed ? "ready" : "not_ready",
        "routing_declaration" => routing, "obligation_rows" => rows,
        "closed_obligation_count" => count(row -> row["status"] == "closed", rows),
        "required_obligation_count" => length(rows),
        "provider_gap_count" => count(row -> row["status"] == "missing_provider", rows),
        "fidelity_gap_count" => count(row -> row["status"] ==
            "insufficient_evidence_level", rows),
        "candidate_identity_used_for_routing" => false,
        "whole_device_search_authorized" => closed,
        "claim_boundary" => WHOLE_DEVICE_PREFLIGHT_V104_CLAIM_BOUNDARY)
    body["preflight_hash"] = canonical_hash(body)
    body
end

function _v104_load_v100_candidates(root)
    candidates = Dict{Int,Dict{String,Any}}()
    for directory in ("v100_candidate_bound_design_refinement_20260829",
            "v100_candidate_bound_design_refinement_expanded_20260829")
        path = joinpath(root, "runs", directory, "computational_candidates.jsonl")
        open(path, "r") do io
            for line in eachline(io)
                isempty(strip(line)) && continue
                item = Dict{String,Any}(_v93_plain(JSON3.read(line)))
                index = Int(item["request_index"])
                haskey(candidates, index) && candidates[index]["result_hash"] !=
                    item["result_hash"] && throw(ArgumentError(
                        "conflicting candidate at request index $index"))
                candidates[index] = item
            end
        end
    end
    candidates
end


function run_whole_device_preflight_v104(project_root::AbstractString)
    root = abspath(project_root)
    reference = run_mission_aware_reference_acceptance_v103(root)
    final = Dict{String,Any}(_v93_plain(JSON3.read(read(joinpath(root, "runs",
        "v100_full_device_qualification_20260829", "acceptance.json"), String))))
    survivors = [Dict{String,Any}(row) for row in Dict{String,Any}.(final["rows"])
        if row["candidate_state"] == "qualification_incomplete"]
    candidates = _v104_load_v100_candidates(root)
    rows = Dict{String,Any}[]
    for survivor in survivors
        index = Int(survivor["request_index"]); candidate = candidates[index]
        preflight = compile_whole_device_preflight_v104(candidate["capability_profile"])
        push!(rows, Dict{String,Any}(
            "report_index" => length(rows) + 1,
            "source_candidate_result_hash" => candidate["result_hash"],
            "source_v100_candidate_state" => survivor["candidate_state"],
            "preflight" => preflight,
            "candidate_state" => preflight["status"] == "ready" ?
                "ready_for_whole_device_execution" : "not_adjudicated_provider_gap",
            "physical_rejection_credit" => false, "physical_pass_credit" => false,
            "validation_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "candidate_identity_used_for_routing" => false))
        rows[end]["row_hash"] = canonical_hash(rows[end])
    end
    ready = reference["status"] == "pass" && !isempty(rows) &&
        all(row -> row["preflight"]["status"] == "ready", rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V104_PROTOCOL_ID,
        "status" => ready ? "ready" : "not_ready",
        "reference_regression_status" => reference["status"],
        "reference_regression_pass_count" => reference["reference_regression_pass_count"],
        "reference_bypass_count" => reference["new_reference_bypass_count"],
        "source_v100_acceptance_hash" => final["acceptance_hash"],
        "survivor_preflight_count" => length(rows), "survivor_rows" => rows,
        "whole_device_search_authorized" => ready,
        "unsupported_candidate_count" => 0,
        "physical_reject_count_added_by_preflight" => 0,
        "physical_pass_count_added_by_preflight" => 0,
        "whole_device_credible_count" => 0, "validation_pass_count" => 0,
        "claim_boundary" => WHOLE_DEVICE_PREFLIGHT_V104_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end
