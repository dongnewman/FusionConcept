const QUALIFICATION_VVUQ_V92_CLAIM_BOUNDARY =
    "V92 qualification preserves fail, unknown, unsupported, and not_scheduled states. No downstream gate can pass when its candidate-bound upstream state is unavailable, and verification or published intervals cannot substitute for validation."

struct ModeCoverageManifestV92
    payload::Dict{String,Any}
    manifest_hash::String
end

function compile_mode_coverage_manifest_v92(realization_raw)
    realization = _v92_plain(realization_raw)
    obligations = realization["applicability_obligations"]
    operators = Set(String.(obligations["declared_operators"]))
    semantics = Set(String.(obligations["field_semantics"]))
    modes = Dict{String,Any}[
        Dict("mode_id" => "ideal_mhd", "applicable" => true,
            "reason" => "magnetized finite-pressure plasma state declared"),
        Dict("mode_id" => "resistive_mhd", "applicable" => true,
            "reason" => "finite current and wall/interface obligations declared"),
        Dict("mode_id" => "kinetic_fast_particle", "applicable" => true,
            "reason" => "multi-species profile and fusion mission obligations declared"),
        Dict("mode_id" => "microinstability", "applicable" => true,
            "reason" => "density and temperature gradients declared"),
        Dict("mode_id" => "finite_n_global", "applicable" =>
            any(item -> item in semantics, ("three_dimensional_closed",
                "hybrid_field")), "reason" =>
            "three-dimensional or hybrid field semantics determine applicability"),
        Dict("mode_id" => "nonlinear_initial_value", "applicable" => true,
            "reason" => "required only after all linear hard gates pass"),
        Dict("mode_id" => "controller_actuator_fault_coupled", "applicable" =>
            any(item -> item in operators, ("actuator_feedback",
                "fault_transition")), "reason" =>
            "declared actuator_feedback or fault_transition operator")]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "candidate_id" => realization["candidate_id"],
        "candidate_hash" => realization["candidate_hash"],
        "realization_hash" => realization["realization_hash"],
        "routing_axes" => Dict(axis => obligations[axis] for axis in
            V92_ROUTING_AXES), "modes" => modes,
        "family_or_device_label_used" => false,
        "applicable_mode_count" => count(mode -> mode["applicable"], modes),
        "claim_boundary" => QUALIFICATION_VVUQ_V92_CLAIM_BOUNDARY)
    hash = canonical_hash(body); body["manifest_hash"] = hash
    return ModeCoverageManifestV92(body, hash)
end

function compile_blocked_orbit_result_v92(realization_raw,
        equilibrium::EquilibriumResultV92)
    realization = _v92_plain(realization_raw)
    equilibrium.payload["status"] == "pass" && throw(ArgumentError(
        "blocked orbit result is only valid when equilibrium did not pass"))
    inherited = equilibrium.payload["status"] == "unsupported" ?
        "unsupported" : "unknown"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "stage_id" => "field_line_orbit", "candidate_id" =>
            realization["candidate_id"], "candidate_hash" =>
            realization["candidate_hash"], "realization_hash" =>
            realization["realization_hash"], "equilibrium_result_hash" =>
            equilibrium.result_hash, "status" => inherited,
        "request_created" => false, "solver_executed" => false,
        "reason" => "upstream_applicable_equilibrium_not_pass",
        "field_line" => nothing, "guiding_center" => nothing,
        "full_gyro" => nothing, "convergence" => nothing,
        "independent_comparison" => nothing, "invariant_audit" => nothing,
        "wall_interaction" => nothing, "loss_distribution" => nothing,
        "feasibility_credit" => false)
    hash = canonical_hash(body); body["result_hash"] = hash
    return OrbitResultV92(body, hash)
end

function compile_blocked_stability_result_v92(realization_raw,
        equilibrium::EquilibriumResultV92)
    realization = _v92_plain(realization_raw)
    equilibrium.payload["status"] == "pass" && throw(ArgumentError(
        "blocked stability result is only valid when equilibrium did not pass"))
    coverage = compile_mode_coverage_manifest_v92(realization)
    inherited = equilibrium.payload["status"] == "unsupported" ?
        "unsupported" : "unknown"
    mode_rows = [Dict("mode_id" => mode["mode_id"], "applicable" =>
        mode["applicable"], "status" => mode["applicable"] ? inherited :
        "not_applicable", "reason" => mode["applicable"] ?
        "upstream_applicable_equilibrium_not_pass" : mode["reason"])
        for mode in coverage.payload["modes"]]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "stage_id" => "stability", "candidate_id" =>
            realization["candidate_id"], "candidate_hash" =>
            realization["candidate_hash"], "realization_hash" =>
            realization["realization_hash"], "equilibrium_result_hash" =>
            equilibrium.result_hash, "status" => inherited,
        "request_created" => false, "solver_executed" => false,
        "mode_coverage_manifest_hash" => coverage.manifest_hash,
        "mode_coverage" => mode_rows, "linear_results" => nothing,
        "nonlinear_results" => nothing, "eigenvalue_convergence" => nothing,
        "eigenfunction_convergence" => nothing,
        "independent_comparison" => nothing, "conservation_audit" => nothing,
        "restart_replay" => nothing, "feasibility_credit" => false)
    hash = canonical_hash(body); body["result_hash"] = hash
    return StabilityResultV92(body, hash)
end

function compile_cross_code_comparison_v92(equilibrium::EquilibriumResultV92,
        orbit::OrbitResultV92, stability::StabilityResultV92)
    available = equilibrium.payload["primary_backend_available"] &&
        equilibrium.payload["independent_backend_available"] &&
        equilibrium.payload["solver_executed"]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "candidate_id" => equilibrium.payload["candidate_id"],
        "equilibrium_result_hash" => equilibrium.result_hash,
        "orbit_result_hash" => orbit.result_hash,
        "stability_result_hash" => stability.result_hash,
        "observables" => ["topology", "force_balance", "boundary_flux",
            "field_line_classification", "loss_classification", "loss_fraction",
            "growth_rate_sign", "growth_rate", "eigenfunction_subspace",
            "hard_gate_decision"],
        "status" => available ? "unknown_comparison_not_completed" :
            "unknown_independent_model_missing",
        "unresolved_solver_disagreement" => true,
        "comparison_credit" => false)
    body["comparison_hash"] = canonical_hash(body)
    return body
end

function compile_validation_vvuq_v92(realization_raw, equilibrium,
        orbit, stability)
    realization = _v92_plain(realization_raw)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "candidate_id" => realization["candidate_id"],
        "realization_hash" => realization["realization_hash"],
        "code_verification" => Dict("status" => "partial_controls_pass",
            "validation_credit" => false),
        "numerical_vvuq" => Dict("status" => "unsupported",
            "reason" => "no_candidate_bound_high_fidelity_solution_family"),
        "parameter_uq" => Dict("status" => "unsupported",
            "reason" => "no_candidate_bound_high_fidelity_solution_family"),
        "model_validation" => Dict("status" => "unknown",
            "reason" => "holdout_shot_run_measurements_not_attested"),
        "candidate_applicability" => Dict("status" => "unknown",
            "reason" => "candidate_outside_attested_validation_domain_or_domain_missing"),
        "candidate_bound_validation_vvuq" => "unknown",
        "published_interval_substitution_used" => false,
        "iter_design_point_validation_credit" => false,
        "experimental_uncertainty" => nothing,
        "numerical_uncertainty" => nothing,
        "parameter_uncertainty" => nothing,
        "model_discrepancy" => nothing,
        "claim_boundary" => QUALIFICATION_VVUQ_V92_CLAIM_BOUNDARY)
    body["vvuq_hash"] = canonical_hash(body)
    return body
end

function compile_promotion_decision_v92(realization_raw,
        equilibrium::EquilibriumResultV92, orbit::OrbitResultV92,
        stability::StabilityResultV92, comparison, vvuq)
    realization = _v92_plain(realization_raw)
    gate_rows = Dict{String,Any}[
        Dict("gate" => "physical_realization", "status" =>
            realization["qualification"]["status"]),
        Dict("gate" => "applicable_equilibrium", "status" =>
            equilibrium.payload["status"]),
        Dict("gate" => "field_line_orbit_confinement", "status" =>
            orbit.payload["status"]),
        Dict("gate" => "all_applicable_stability", "status" =>
            stability.payload["status"]),
        Dict("gate" => "independent_solver_comparison", "status" =>
            comparison["status"]),
        Dict("gate" => "numerical_vvuq", "status" =>
            vvuq["numerical_vvuq"]["status"]),
        Dict("gate" => "parameter_uq", "status" =>
            vvuq["parameter_uq"]["status"]),
        Dict("gate" => "candidate_bound_validation_vvuq", "status" =>
            vvuq["candidate_bound_validation_vvuq"]),
        Dict("gate" => "engineering_obligations", "status" => "unsupported")]
    all_pass = all(row -> row["status"] == "pass", gate_rows) &&
        !comparison["unresolved_solver_disagreement"]
    first_blocker = findfirst(row -> row["status"] != "pass", gate_rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
        "candidate_id" => realization["candidate_id"],
        "candidate_hash" => realization["candidate_hash"],
        "gates" => gate_rows,
        "first_blocker" => first_blocker === nothing ? nothing :
            gate_rows[first_blocker]["gate"],
        "unresolved_solver_disagreement" =>
            comparison["unresolved_solver_disagreement"],
        "computationally_credible_fusion_device_concept" => all_pass,
        "experimentally_validated_new_fusion_device" => false,
        "manufactured_sentinel_or_published_interval_credit" => false)
    body["decision_hash"] = canonical_hash(body)
    return body
end
