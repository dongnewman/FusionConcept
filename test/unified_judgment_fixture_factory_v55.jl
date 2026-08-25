function _v55_fixture_hash(character::Char)
    return repeat(string(character), 64)
end

function representative_judgment_fixture_v55(kind::Symbol)
    kind in (:iter, :c2w) || throw(ArgumentError("fixture kind must be :iter or :c2w"))
    is_iter = kind == :iter
    candidate_id = is_iter ? "iter_reference_contract_v55" : "c2w_reference_contract_v55"
    state_hash = is_iter ? _v55_fixture_hash('a') : _v55_fixture_hash('b')
    transport_hash = is_iter ? _v55_fixture_hash('c') : _v55_fixture_hash('d')
    stability_hash = is_iter ? _v55_fixture_hash('e') : _v55_fixture_hash('f')
    evidence_hashes = is_iter ?
        [_v55_fixture_hash('1'), _v55_fixture_hash('2'), _v55_fixture_hash('3')] :
        [_v55_fixture_hash('4'), _v55_fixture_hash('5'), _v55_fixture_hash('6')]
    fusion_power = is_iter ? 100.0 : 0.0
    self_heating = is_iter ? 20.0 : 0.0
    drive = is_iter ? -40.0 : -20.0
    loss = is_iter ? -50.0 : -15.0
    recirculating = is_iter ? -20.0 : -5.0
    reported_net = fusion_power + drive + loss + recirculating
    mode = is_iter ? "pulsed" : "transient"
    perturbation_operators = is_iter ?
        ["state_spectrum", "edge_boundary", "heating_source", "shape_controller", "coil_tolerance"] :
        ["state_spectrum", "end_boundary", "neutral_beam_source", "translation_controller", "coil_tolerance"]
    perturbation_classes = ["state", "boundary", "source", "controller", "manufacturing"]

    engineering_checks = Any[
        Dict("check_id" => id, "status" => "pass", "normalized_margin" => 0.10,
            "evidence_refs" => Any["engineering_anchor"])
        for id in ["field_strength", "force", "stress", "heat_flux", "material_temperature",
            "irradiation", "quench", "repetition_rate", "maintenance_space", "fuel_cycle",
            "component_lifetime"]
    ]
    uncertainty_checks = Any[
        Dict("check_id" => id, "status" => "pass",
            "evidence_refs" => Any[id == "experimental_anchor" ? "experimental_anchor" : "vvuq_anchor"])
        for id in ["perturbation_uncertainty", "manufacturing_tolerance", "model_error",
            "resolution_convergence", "cross_code_replication", "experimental_anchor"]
    ]

    return Dict{String,Any}(
        "candidate_id" => candidate_id,
        "display_label" => is_iter ? "ITER representative contract" : "C-2W representative contract",
        "family" => is_iter ? "tokamak" : "frc",
        "parent_family" => is_iter ? "magnetic_confinement" : "compact_toroid",
        "benchmark_scope" => "contract_regression_not_device_validation",
        "mission" => Dict(
            "mission_id" => is_iter ? "reference_DT_science_pulse" : "reference_sustained_plasma_operation",
            "fusion_burn_required" => is_iter,
            "positive_net_energy_required" => false),
        "physical_description" => Dict(
            "regions" => Any[Dict("id" => "core"), Dict("id" => "exhaust")],
            "species" => Any[Dict("id" => "ions"), Dict("id" => "electrons")],
            "fields" => Any[Dict("id" => "electromagnetic_field")],
            "materials" => Any[Dict("id" => "first_wall_material")],
            "boundaries" => Any[Dict("id" => "plasma_boundary")],
            "sources" => Any[Dict("id" => "fuel_and_heating", "target_ref" => "core")],
            "sinks" => Any[Dict("id" => "particle_and_energy_exhaust", "source_ref" => "exhaust")],
            "controllers" => Any[Dict("id" => "plasma_controller", "target_ref" => "core")],
            "control_policy" => Dict("mode" => "active_closed_loop",
                "actuator_refs" => Any["fuel_and_heating"],
                "applicability_basis" => "reference fixture declares a closed-loop controller"),
            "observables" => Any[Dict("id" => "state_observables", "source_ref" => "core")]),
        "topology_causality" => Dict(
            "nodes" => Any[
                Dict("node_id" => "driver"), Dict("node_id" => "core"),
                Dict("node_id" => "exhaust"), Dict("node_id" => "controller")],
            "edges" => Any[
                Dict("from" => "driver", "to" => "core", "direction" => "directed",
                    "accounts" => Any["particles", "energy"]),
                Dict("from" => "core", "to" => "exhaust", "direction" => "directed",
                    "accounts" => Any["particles", "energy"]),
                Dict("from" => "controller", "to" => "core", "direction" => "directed",
                    "accounts" => Any["control_action"])]),
        "state_evolution" => Dict(
            "mode" => mode,
            "solver_derived" => true,
            "generated_nominal" => false,
            "solver_output_hash" => state_hash,
            "time_samples_s" => is_iter ? Any[0.0, 100.0, 300.0, 500.0] : Any[0.0, 0.001, 0.005, 0.010],
            "complete_time_trajectory" => true,
            "normalized_residual_tolerance" => 1.0e-6,
            "steady_time_term_tolerance" => 1.0e-6,
            "required_accounts" => Any["energy", "particles"],
            "residuals" => Any[
                Dict("account" => "energy", "dU_dt" => 2.0, "divergence_F" => 8.0,
                    "source_S" => 10.0, "normalization" => 10.0),
                Dict("account" => "particles", "dU_dt" => 1.0, "divergence_F" => 4.0,
                    "source_S" => 5.0, "normalization" => 5.0)]),
        "perturbation_stability" => Dict(
            "tests" => Any[
                Dict("perturbation_class" => perturbation_classes[index],
                    "operator_id" => perturbation_operators[index],
                    "solver_output_hash" => stability_hash,
                    "outcome" => index == 1 ? "saturation" : "bounded",
                    "within_acceptance" => true,
                    "evidence_refs" => Any["vvuq_anchor"])
                for index in eachindex(perturbation_classes)]),
        "transport_burn" => Dict(
            "solver_derived" => true,
            "generated_nominal" => false,
            "state_solution_hash" => state_hash,
            "solver_output_hash" => transport_hash,
            "confinement_time_source" => "candidate_bound_state_trajectory",
            "particle_paths" => Any[
                Dict("role" => "production", "path" => "fuel_source_to_core"),
                Dict("role" => "loss", "path" => "core_to_exhaust"),
                Dict("role" => "burn", "path" => "reaction_sink")],
            "energy_paths" => Any[
                Dict("role" => "deposition", "path" => "driver_to_core"),
                Dict("role" => "transport", "path" => "core_to_edge"),
                Dict("role" => "escape", "path" => "edge_to_exhaust")],
            "fusion_reaction_rate_per_s" => is_iter ? 1.0e19 : 0.0,
            "fusion_power_w" => fusion_power,
            "self_heating_power_w" => self_heating),
        "net_energy" => Dict(
            "generated_nominal" => false,
            "artificially_closed" => false,
            "terms" => Any[
                Dict("role" => "fusion", "value_w" => fusion_power, "solver_derived" => true,
                    "source_output_hash" => transport_hash),
                Dict("role" => "drive", "value_w" => drive, "solver_derived" => true,
                    "source_output_hash" => state_hash),
                Dict("role" => "loss", "value_w" => loss, "solver_derived" => true,
                    "source_output_hash" => transport_hash),
                Dict("role" => "recirculating", "value_w" => recirculating, "solver_derived" => true,
                    "source_output_hash" => state_hash)],
            "reported_net_power_w" => reported_net,
            "closure_tolerance_w" => 1.0e-9),
        "engineering" => Dict("checks" => engineering_checks),
        "uncertainty_evidence" => Dict("checks" => uncertainty_checks),
        "evidence" => Any[
            Dict("evidence_id" => "engineering_anchor", "artifact_hash" => evidence_hashes[1],
                "evidence_class" => "reference_contract_fixture"),
            Dict("evidence_id" => "vvuq_anchor", "artifact_hash" => evidence_hashes[2],
                "evidence_class" => "reference_contract_fixture"),
            Dict("evidence_id" => "experimental_anchor", "artifact_hash" => evidence_hashes[3],
                "evidence_class" => "published_reference_binding")])
end
