"Non-promoting engineering preflight for reduced vertical-slice candidates."
function engineering_lower_bound_preflight_v1(value;
        stored_energy_j = 1.0, peak_power_w = 1.0, available_power_w = 10.0,
        minimum_effect = 0.05, diagnostic_floor = 0.01)
    genome = value isa OpenWorldGenomeV2 ? value : parse_open_world_genome_v2(value)
    design_id = String(get(get(genome.data, "identity", Dict{String,Any}()), "design_id", "unknown"))
    checks = Any[
        Dict("bound_id" => "$(design_id)_energy_nonnegative", "version" => "1.0.0",
            "activation_predicate" => "stored_energy_declared", "quantity_and_units" => "stored_energy:J",
            "analytic_or_empirical_bound" => "E >= 0", "valid_domain" => "reduced_lumped_model",
            "assumptions" => Any["SI_energy_account"], "evaluated_parameter_region" => Dict("stored_energy_j" => stored_energy_j),
            "result" => stored_energy_j >= 0 ? "bound_satisfied" : "parameter_instance_excluded",
            "failure_scope_ceiling" => "parameter_instance", "evidence_refs" => Any["analytic_nonnegative_energy"],
            "promotion_scope" => "none"),
        Dict("bound_id" => "$(design_id)_power_availability", "version" => "1.0.0",
            "activation_predicate" => "peak_power_declared", "quantity_and_units" => "power:W",
            "analytic_or_empirical_bound" => "P_required <= P_available", "valid_domain" => "fixture_driver",
            "assumptions" => Any["ideal_transfer_upper_bound"],
            "evaluated_parameter_region" => Dict("peak_power_w" => peak_power_w, "available_power_w" => available_power_w),
            "result" => peak_power_w <= available_power_w ? "bound_satisfied" : "parameter_instance_excluded",
            "failure_scope_ceiling" => "parameter_instance", "evidence_refs" => Any["declared_fixture_power"],
            "promotion_scope" => "none"),
        Dict("bound_id" => "$(design_id)_diagnostic_resolution", "version" => "1.0.0",
            "activation_predicate" => "minimum_effect_declared", "quantity_and_units" => "normalized_signal:1",
            "analytic_or_empirical_bound" => "minimum_effect > diagnostic_floor", "valid_domain" => "fixture_observable",
            "assumptions" => Any["independent_floor_components_already_combined"],
            "evaluated_parameter_region" => Dict("minimum_effect" => minimum_effect, "diagnostic_floor" => diagnostic_floor),
            "result" => minimum_effect > diagnostic_floor ? "bound_satisfied" : "parameter_instance_excluded",
            "failure_scope_ceiling" => "parameter_instance", "evidence_refs" => Any["fixture_noise_contract"],
            "promotion_scope" => "none"),
    ]
    return Dict("candidate_id" => design_id, "checks" => checks,
        "promotion_credit" => 0, "claim" => "preflight_only_not_C2")
end

