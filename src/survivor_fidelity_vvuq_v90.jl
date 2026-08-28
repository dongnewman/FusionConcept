const SURVIVOR_FIDELITY_VVUQ_V90_CLAIM_BOUNDARY =
    "Survivor-only layered reduced fidelity and numerical VVUQ. Missing kinetic, engineering, material, maintenance, or candidate-bound experimental evidence remains unknown or unsupported and cannot be compensated by numerical convergence or Pareto rank."

function _v90_stage_record(stage_id, status, solver_input, payload;
        applicability_proof, evidence_ceiling, reason = nothing,
        independence_group = nothing)
    status in ("pass", "fail", "unknown", "unsupported", "not_applicable") ||
        throw(ArgumentError("invalid v90 stage status $status"))
    input_hash = solver_input isa AbstractString ? String(solver_input) :
        canonical_hash(solver_input)
    body = Dict{String,Any}(
        "stage_id" => String(stage_id), "status" => String(status),
        "applicability_proof" => _v89_plain(applicability_proof),
        "solver_input_hash" => input_hash, "result_payload" => _v89_plain(payload),
        "evidence_ceiling" => String(evidence_ceiling))
    reason === nothing || (body["reason"] = String(reason))
    independence_group === nothing ||
        (body["independence_group"] = String(independence_group))
    body["result_hash"] = canonical_hash(body)
    body
end
function _v90_finite_field_orbit_stage(contract, nonlinear)
    core = String(contract.model_parameters["core_region_id"])
    flux = _v90_final_normalized(nonlinear, "$core::magnetic_flux")
    current = _v90_final_normalized(nonlinear, "$core::plasma_current")
    radii = collect(range(0.0, 1.0; length = 64))
    field = [max(1.0e-8, flux * (1.0 - 0.35radius^2) +
        0.08current * radius) for radius in radii]
    minimum_field = minimum(field); maximum_field = maximum(field)
    orbit_excursion = maximum_field > 0 ? 0.04 * maximum_field / minimum_field : Inf
    favorable = isfinite(orbit_excursion) && orbit_excursion <= 0.20
    _v90_stage_record("finite_field_line_or_orbit", favorable ? "pass" : "fail",
        Dict("contract_hash" => contract.contract_hash, "radial_samples" => 64),
        Dict("minimum_field_normalized" => minimum_field,
            "maximum_field_normalized" => maximum_field,
            "reduced_orbit_excursion" => isfinite(orbit_excursion) ? orbit_excursion : nothing,
            "field_samples" => field);
        applicability_proof = Dict("candidate_bound_field_source" => true,
            "bounded_radial_domain" => true, "model" => "reduced_axis_field_orbit_v90"),
        evidence_ceiling = "reduced_finite_field_and_orbit_screen",
        independence_group = "native_reduced_field_orbit_v90")
end

function _v90_reaction_radiation_stage(contract, nonlinear)
    core = String(contract.model_parameters["core_region_id"]); p = contract.model_parameters
    n = _v90_final_normalized(nonlinear, "$core::particle_inventory")
    e = _v90_final_normalized(nonlinear, "$core::thermal_energy")
    reaction = Float64(p["reaction_coefficient"]) * n^2 * sqrt(e)
    radiation = Float64(p["radiation_coefficient"]) * n^2 * sqrt(e)
    self_heating = Float64(p["self_heating_fraction"]) * reaction
    _v90_stage_record("reaction_radiation_self_heating", "pass",
        Dict("contract_hash" => contract.contract_hash,
            "nonlinear_result_hash" => nonlinear["result_hash"]),
        Dict("reaction_rate_normalized" => reaction,
            "radiation_loss_normalized" => radiation,
            "self_heating_normalized" => self_heating,
            "fed_back_into_same_residual" => true);
        applicability_proof = Dict("declared_reaction_model" => true,
            "declared_radiation_model" => true, "same_iteration_feedback" => true),
        evidence_ceiling = "reduced_coupled_reaction_radiation_self_heating",
        independence_group = "native_multiregion_dae_v90")
end

function _v90_control_fault_stage(contract, nonlinear)
    core = String(contract.model_parameters["core_region_id"]); p = contract.model_parameters
    n = _v90_final_normalized(nonlinear, "$core::particle_inventory")
    e = _v90_final_normalized(nonlinear, "$core::thermal_energy")
    particle_slope = Float64(p["particle_controller_gain"]) *
        _v90_sigmoid(Float64(p["particle_controller_bias"]) +
            Float64(p["particle_controller_gain"]) * (1.0 - n)) *
        (1.0 - _v90_sigmoid(Float64(p["particle_controller_bias"]) +
            Float64(p["particle_controller_gain"]) * (1.0 - n)))
    energy_slope = Float64(p["energy_controller_gain"]) *
        _v90_sigmoid(Float64(p["energy_controller_bias"]) +
            Float64(p["energy_controller_gain"]) * (1.0 - e)) *
        (1.0 - _v90_sigmoid(Float64(p["energy_controller_bias"]) +
            Float64(p["energy_controller_gain"]) * (1.0 - e)))
    stable = particle_slope < 1.0 && energy_slope < 1.0 &&
        Float64(p["actuator_capacity_ratio"]) >= 1.0
    _v90_stage_record("actuator_control_fault", stable ? "pass" : "fail",
        Dict("contract_hash" => contract.contract_hash,
            "nonlinear_result_hash" => nonlinear["result_hash"]),
        Dict("particle_loop_slope" => particle_slope,
            "energy_loop_slope" => energy_slope,
            "actuator_capacity_ratio" => p["actuator_capacity_ratio"],
            "safe_fault_action" => "zero_command",
            "fault_action_in_contract" => true);
        applicability_proof = Dict("bounded_controller" => true,
            "algebraic_actuator_in_same_iteration" => true,
            "fault_action_declared" => true),
        evidence_ceiling = "reduced_linearized_control_and_declared_fault_screen",
        independence_group = "native_control_fault_v90")
end

function _v90_engineering_stages(contract, nonlinear)
    p = contract.model_parameters; core = String(p["core_region_id"])
    current = _v90_final_normalized(nonlinear, "$core::plasma_current")
    field = Float64(p["magnetic_field_t"])
    force_proxy = current * field
    electromagnetic = _v90_stage_record("electromagnetic_force", "pass",
        Dict("contract_hash" => contract.contract_hash, "operator" => "j_cross_b_proxy"),
        Dict("normalized_force_proxy" => force_proxy);
        applicability_proof = Dict("current_and_field_candidate_bound" => true),
        evidence_ceiling = "reduced_electromagnetic_force_proxy",
        independence_group = "native_engineering_proxy_v90")
    missing = Dict{String,Any}[]
    for (stage, reason) in (("structure", "missing_candidate_bound_structural_mesh"),
            ("thermal_material", "missing_material_constitutive_and_lifetime_data"),
            ("shielding", "missing_candidate_bound_neutronics_transport"),
            ("cryogenic", "missing_candidate_bound_cryogenic_architecture"),
            ("maintenance", "missing_candidate_bound_maintenance_and_remote_handling_model"))
        push!(missing, _v90_stage_record(stage, "unsupported",
            Dict("contract_hash" => contract.contract_hash, "stage" => stage),
            Dict("metric" => nothing, "unavailable_reason" => reason);
            applicability_proof = Dict("obligation_applicable" => true,
                "provider_available" => false), evidence_ceiling = "none",
            reason = reason))
    end
    vcat([electromagnetic], missing)
end

function compile_numerical_vvuq_v90(slice, hard_result;
        resolution_levels = [16, 32, 64], uq_multipliers =
            [0.94, 0.96, 0.98, 0.99, 1.01, 1.02, 1.04, 1.06])
    hard_result["status"] == "pass" || return _v90_stage_record(
        "numerical_vvuq", "fail", Dict("candidate_hash" =>
            slice.candidate.candidate_hash), Dict("resolution_runs" => Any[],
            "parameter_uq_runs" => Any[]);
        applicability_proof = Dict("hard_gate_survivor_required" => true,
            "hard_gate_status" => hard_result["status"]),
        evidence_ceiling = "none", reason = "hard_gate_failure_not_admitted")
    contract = hard_result["contract"]; nonlinear = hard_result["nonlinear"]
    open = !isempty(contract.model_parameters["open_region_ids"])
    levels = sort!(unique(Int.(resolution_levels)))
    length(levels) >= 3 || throw(ArgumentError("v90 VVUQ requires three resolutions"))
    resolution_runs = Dict{String,Any}[]; observables = Float64[]
    for level in levels
        result = open ? solve_open_parallel_transport_v90(contract, nonlinear;
            resolution = level) : solve_axisymmetric_finite_pressure_v90(contract,
            nonlinear; resolution = level)
        observable = open ? get(result, "parallel_energy_flux", nothing) :
            (get(result, "flux_profile", nothing) === nothing ? nothing :
                maximum(Float64.(result["flux_profile"])))
        push!(resolution_runs, Dict("resolution" => level,
            "solver_input_hash" => result["solver_input_hash"],
            "result_hash" => result["result_hash"], "status" => result["status"],
            "observable" => observable, "mesh_hash" => result["mesh_hash"]))
        observable isa Real && push!(observables, Float64(observable))
    end
    relative_changes = length(observables) == length(levels) ?
        [abs(observables[index] - observables[index - 1]) /
            max(abs(observables[index]), 1.0e-12) for index in 2:length(observables)] :
        Float64[]
    resolution_pass = all(row -> row["status"] == "pass", resolution_runs) &&
        length(relative_changes) == length(levels) - 1 &&
        last(relative_changes) <= 0.05

    uq_runs = Dict{String,Any}[]
    for (index, multiplier) in enumerate(Float64.(uq_multipliers))
        overrides = Dict{String,Any}(
            "energy_transport_coefficient" =>
                Float64(contract.model_parameters["energy_transport_coefficient"]) * multiplier,
            "reaction_coefficient" =>
                Float64(contract.model_parameters["reaction_coefficient"]) /
                    sqrt(multiplier),
            "radiation_coefficient" =>
                Float64(contract.model_parameters["radiation_coefficient"]) *
                    (2.0 - multiplier))
        sample_route = hard_result["route"]
        sample_contract = compile_multiregion_nonlinear_dae_v90(slice.candidate,
            slice.topology, slice.realization, sample_route;
            coefficient_overrides = overrides)
        sample_result = solve_multiregion_nonlinear_dae_v90(sample_contract)
        sample_hash = canonical_hash(Dict("base_candidate_physics_hash" =>
            slice.realization.candidate_physics_hash, "uq_parameters" => overrides,
            "sample_index" => index))
        push!(uq_runs, Dict("sample_index" => index,
            "parameter_sample_hash" => sample_hash,
            "actual_solver_input_hash" => sample_contract.solver_input_hash,
            "result_hash" => sample_result["result_hash"],
            "status" => sample_result["status"], "weight" =>
                1.0 / length(uq_multipliers)))
    end
    uq_pass = length(uq_runs) >= 8 &&
        length(unique(String(row["actual_solver_input_hash"]) for row in uq_runs)) ==
            length(uq_runs) && all(row -> row["status"] == "pass", uq_runs)
    status = resolution_pass && uq_pass ? "pass" : "unknown"
    _v90_stage_record("numerical_vvuq", status,
        Dict("candidate_hash" => slice.candidate.candidate_hash,
            "contract_hash" => contract.contract_hash,
            "resolution_levels" => levels,
            "uq_sample_hashes" => [row["parameter_sample_hash"] for row in uq_runs]),
        Dict("resolution_runs" => resolution_runs,
            "convergence_relative_changes" => relative_changes,
            "convergence_trend_status" => resolution_pass ? "pass" : "unknown",
            "parameter_uq_runs" => uq_runs,
            "parameter_uq_status" => uq_pass ? "pass" : "unknown",
            "independent_balance_audit_hash" => nonlinear["audits"][
                "independent_balance"]["audit_hash"],
            "independence_groups" => ["native_axis_or_open_fd_v90",
                "independent_account_ledger_v90"]);
        applicability_proof = Dict("hard_gate_survivor" => true,
            "three_or_more_resolutions" => length(levels) >= 3,
            "parameter_uq_sample_count" => length(uq_runs),
            "explicit_independence_groups" => true),
        evidence_ceiling = "reduced_numerical_vvuq_not_validation",
        reason = status == "pass" ? nothing : "incomplete_numerical_convergence_or_uq",
        independence_group = "numerical_vvuq_orchestrator_v90")
end

function evaluate_survivor_fidelity_vvuq_v90(slice, hard_result)
    hard_result["status"] == "pass" || return Dict{String,Any}(
        "status" => "not_admitted", "reason" => "hard_gate_survivor_required",
        "candidate_hash" => slice.candidate.candidate_hash)
    contract = hard_result["contract"]; nonlinear = hard_result["nonlinear"]
    field = _v90_finite_field_orbit_stage(contract, nonlinear)
    deep_payload = hard_result["equilibrium_or_transport"]
    finite_pressure_or_open = _v90_stage_record(
        isempty(contract.model_parameters["open_region_ids"]) ?
            "finite_pressure_equilibrium" : "open_parallel_transport",
        String(deep_payload["status"]), deep_payload["solver_input_hash"], deep_payload;
        applicability_proof = deep_payload["applicability_proof"],
        evidence_ceiling = deep_payload["evidence_ceiling"],
        independence_group = isempty(contract.model_parameters["open_region_ids"]) ?
            "native_axisymmetric_fd_v90" : "native_open_parallel_fd_v90")
    stability_payload = hard_result["stability"]
    stability = _v90_stage_record("applicable_stability",
        String(stability_payload["status"]), stability_payload["solver_input_hash"],
        stability_payload; applicability_proof = stability_payload["applicability_proof"],
        evidence_ceiling = stability_payload["evidence_ceiling"],
        independence_group = "native_finite_mode_stability_v90")
    transport_kinetic = _v90_stage_record("transport_or_kinetic", "unknown",
        Dict("contract_hash" => contract.contract_hash,
            "required" => "kinetic_or_validated_transport"),
        Dict("reduced_transport_coupled" => true,
            "kinetic_distribution_solved" => false,
            "missing_obligations" => ["candidate_bound_kinetic_distribution",
                "collision_operator_validation"]);
        applicability_proof = Dict("transport_applicable" => true,
            "kinetic_provider_available" => false),
        evidence_ceiling = "reduced_transport_only",
        reason = "missing_candidate_bound_kinetic_solver")
    reaction = _v90_reaction_radiation_stage(contract, nonlinear)
    control = _v90_control_fault_stage(contract, nonlinear)
    engineering = _v90_engineering_stages(contract, nonlinear)
    numerical = compile_numerical_vvuq_v90(slice, hard_result)
    validation = _v90_stage_record("validation_vvuq", "unknown",
        Dict("candidate_physics_hash" => slice.realization.candidate_physics_hash,
            "required_anchor" => "candidate_bound_experiment"),
        Dict("experimental_anchor" => nothing,
            "candidate_bound_operating_history" => nothing);
        applicability_proof = Dict("validation_required" => true,
            "candidate_bound_anchor_available" => false),
        evidence_ceiling = "none", reason = "missing_candidate_bound_experimental_anchor")
    stages = vcat([field, finite_pressure_or_open, stability, transport_kinetic,
        reaction, control], engineering, [numerical, validation])
    hard_fail = any(stage -> stage["status"] == "fail", stages)
    complete = all(stage -> stage["status"] in ("pass", "not_applicable"), stages)
    overall = hard_fail ? "fail" : complete ? "pass" : "unknown"
    engineering_pass = all(stage -> stage["status"] == "pass", engineering) &&
        validation["status"] == "pass"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_hash" =>
            slice.candidate.candidate_hash,
        "candidate_physics_hash" => slice.realization.candidate_physics_hash,
        "hard_gate_result_hash" => hard_result["result_hash"],
        "status" => overall, "stages" => stages,
        "numerical_vvuq_status" => numerical["status"],
        "validation_vvuq_status" => validation["status"],
        "engineering_acceptance_status" => engineering_pass ? "pass" : "unknown",
        "high_fidelity_failure_compensated" => false,
        "pareto_score_can_compensate_failure" => false,
        "evidence_ceiling" => "reduced_numerical_vvuq_with_missing_kinetic_engineering_validation",
        "claim_boundary" => SURVIVOR_FIDELITY_VVUQ_V90_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body); body
end
