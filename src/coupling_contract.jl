function validate_coupling_contract_v1(value)
    item = _plain_json(value)
    errors = String[]
    required = ["coupling_id", "version", "participants", "exchanged_variables", "interface_geometry",
        "units_basis_coordinates", "temporal_semantics", "interpolation_extrapolation", "synchronization_policy",
        "event_rollback_semantics", "algebraic_loop_strategy", "interface_conservation_accounts",
        "duplicate_flux_prevention", "convergence_test", "local_error_budgets", "global_error_budget",
        "known_instability_conditions", "regression_fixtures"]
    for key in required
        haskey(item, key) || push!(errors, "CouplingContract missing $key")
    end
    length(get(item, "participants", Any[])) >= 2 || push!(errors, "CouplingContract requires at least two participants")
    isempty(get(item, "exchanged_variables", Any[])) && push!(errors, "CouplingContract requires exchanged variables")
    get(item, "duplicate_flux_prevention", false) === true || push!(errors, "duplicate flux prevention is not enabled")
    isempty(get(item, "interface_conservation_accounts", Any[])) && push!(errors, "interface conservation account is missing")
    isempty(get(item, "regression_fixtures", Any[])) && push!(errors, "coupling regression fixture is missing")
    return errors
end

function default_two_reservoir_coupling_contract_v1()
    return Dict{String,Any}(
        "coupling_id" => "two_reservoir_energy_exchange_v1", "version" => "1.0.0",
        "participants" => Any["reservoir_solver_a", "reservoir_solver_b"],
        "exchanged_variables" => Any[Dict("name" => "interface_energy_flux", "unit" => "W", "direction" => "signed_once")],
        "interface_geometry" => "lumped_interface", "units_basis_coordinates" => Dict("units" => "SI", "basis" => "scalar"),
        "temporal_semantics" => "synchronous_fixed_step", "interpolation_extrapolation" => "none",
        "synchronization_policy" => "evaluate_flux_once_then_apply_opposite_signs",
        "event_rollback_semantics" => "transactional_step_rollback", "algebraic_loop_strategy" => "explicit_lag_free_flux",
        "interface_conservation_accounts" => Any[Dict("account" => "energy", "tolerance" => 1.0e-12)],
        "duplicate_flux_prevention" => true, "convergence_test" => Dict("refinement_ratio" => 2, "required" => true),
        "local_error_budgets" => Any[Dict("participant" => "reservoir_solver_a", "absolute" => 1.0e-4),
            Dict("participant" => "reservoir_solver_b", "absolute" => 1.0e-4)],
        "global_error_budget" => Dict("energy_conservation_absolute" => 1.0e-10, "solution_absolute" => 1.0e-3),
        "known_instability_conditions" => Any["dt * exchange_rate > 1"],
        "regression_fixtures" => Any["two_reservoir_equalization", "duplicate_flux_negative_control"],
    )
end

