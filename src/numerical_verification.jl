function numerical_verification_report_v1(; measurement_floor = 0.01, minimum_effect = 0.05)
    base = verify_generic_ode_dae_event_adapter_v1()
    combined_floor = Float64(measurement_floor) + Float64(base["finer_error"])
    return Dict{String,Any}(
        "report_id" => "open_world_code_solution_verification_v1",
        "code_verification" => Dict("analytic_solution" => true, "manufactured_solution" => true,
            "adapter_verification" => base),
        "solution_verification" => Dict("time_step_refinement" => true,
            "observed_convergence" => base["observed_convergence"],
            "conservation_error_bound" => base["finer_error"]),
        "uncertainty_components" => Dict("numerical" => base["finer_error"],
            "measurement" => Float64(measurement_floor), "model_form" => "reported_separately",
            "transfer" => "not_assessed_for_fixture"),
        "minimum_effect_size" => Float64(minimum_effect), "combined_detection_floor" => combined_floor,
        "minimum_effect_resolved" => Float64(minimum_effect) > combined_floor,
        "pass" => base["pass"] && base["observed_convergence"] && Float64(minimum_effect) > combined_floor,
        "claim_scope" => "scalar linear balance with deterministic events",
    )
end

