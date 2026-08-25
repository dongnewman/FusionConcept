using Test
using FusionConceptAI

function longitudinal_parameters_v1(; fueling_capacity_s = 1.0,
        ion_heating_capacity_w = 1.0, electron_heating_capacity_w = 1.0,
        exhaust_capacity_s = 1.0, radiation_control_capacity_w = 1.0)
    return Dict{String,Float64}(
        "charge_a" => 1.0, "charge_b" => 1.0,
        "particle_scale" => 1.0, "energy_scale" => 1.0,
        "particle_rate_scale" => 1.0, "power_scale" => 1.0,
        "particle_transport_a_s" => 0.1, "particle_transport_b_s" => 0.1,
        "ion_energy_loss_s" => 0.1, "electron_energy_loss_s" => 0.1,
        "reaction_coefficient_per_particle_s" => 0.01, "reaction_energy_j" => 2.0,
        "alpha_ion_fraction" => 0.5, "alpha_electron_fraction" => 0.5,
        "radiation_coefficient_per_particle_s" => 0.01,
        "ion_electron_exchange_rate_s" => 0.02,
        "fuel_fraction_a" => 0.5, "fuel_fraction_b" => 0.5,
        "exhaust_fraction_a" => 0.5, "exhaust_fraction_b" => 0.5,
        "fueling_capacity_s" => fueling_capacity_s,
        "ion_heating_capacity_w" => ion_heating_capacity_w,
        "electron_heating_capacity_w" => electron_heating_capacity_w,
        "exhaust_capacity_s" => exhaust_capacity_s,
        "radiation_control_capacity_w" => radiation_control_capacity_w,
        "fueling_baseline_s" => 0.32, "ion_heating_baseline_w" => 0.1125,
        "electron_heating_baseline_w" => 0.1625, "exhaust_baseline_s" => 0.1,
        "radiation_control_baseline_w" => 0.02,
        "target_particle_inventory" => 2.0, "target_ion_energy_j" => 1.0,
        "target_electron_energy_j" => 1.0, "fueling_controller_gain_s" => 0.5,
        "ion_heating_controller_gain_s" => 0.5,
        "electron_heating_controller_gain_s" => 0.5,
        "exhaust_controller_gain_s" => 0.5, "radiation_controller_gain_s" => 0.5,
        "ion_heating_deposition_efficiency" => 0.8,
        "electron_heating_deposition_efficiency" => 0.8,
        "fueling_wall_energy_j_per_particle" => 0.1,
        "exhaust_wall_energy_j_per_particle" => 0.1,
        "ion_heating_wall_plug_efficiency" => 0.5,
        "electron_heating_wall_plug_efficiency" => 0.5,
        "radiation_control_wall_plug_efficiency" => 0.5,
        "electric_conversion_efficiency" => 0.4)
end

@testset "candidate D-T reaction and bremsstrahlung are additive v68 terms" begin
    volume = 1.0
    na = 1.0e20; nb = 1.0e20; ne = 2.0e20
    kev_j = 1.0e3 * 1.602176634e-19
    wi = 1.5 * (na + nb) * 10.0 * kev_j
    we = 1.5 * ne * 10.0 * kev_j
    reactivity = bosch_hale_maxwellian_reactivity_v1(
        "dt_to_alpha_neutron", 10.0)
    burn = na * nb / volume * reactivity
    alpha_power = burn * 3.52e6 * 1.602176634e-19
    brems = 1.69e-38 * ne * (na + nb) / volume * sqrt(1.0e4)

    parameters = longitudinal_parameters_v1()
    for id in ("reaction_coefficient_per_particle_s", "reaction_energy_j",
            "radiation_coefficient_per_particle_s", "particle_transport_a_s",
            "particle_transport_b_s", "ion_energy_loss_s",
            "electron_energy_loss_s")
        delete!(parameters, id)
    end
    merge!(parameters, Dict(
        "particle_scale" => na + nb, "energy_scale" => wi + we,
        "particle_rate_scale" => burn, "power_scale" => alpha_power,
        "ion_electron_exchange_rate_s" => 0.0,
        "fueling_capacity_s" => 4.0 * burn, "fueling_baseline_s" => 2.0 * burn,
        "ion_heating_capacity_w" => alpha_power,
        "electron_heating_capacity_w" => alpha_power,
        "exhaust_capacity_s" => burn, "radiation_control_capacity_w" => alpha_power,
        "ion_heating_baseline_w" => 0.0, "electron_heating_baseline_w" => 0.0,
        "exhaust_baseline_s" => 0.0, "radiation_control_baseline_w" => 0.0,
        "target_particle_inventory" => na + nb, "target_ion_energy_j" => wi,
        "target_electron_energy_j" => we, "fueling_controller_gain_s" => 0.0,
        "ion_heating_controller_gain_s" => 0.0,
        "electron_heating_controller_gain_s" => 0.0,
        "exhaust_controller_gain_s" => 0.0, "radiation_controller_gain_s" => 0.0))
    evidence = Dict(key => "complete" for key in keys(parameters))
    core = CandidateLongitudinalBalanceModuleV1(
        module_id = "candidate_dt_core", region_id = "candidate_control_volume",
        transport_operator_id = "declared_transport_fixture",
        parameters = parameters, parameter_evidence = evidence,
        external_term_ids = [:fusion_reaction, :fuel_ion_bremsstrahlung,
            :transport_response])
    reaction = CandidateReactionBremsstrahlungModuleV1(
        module_id = "candidate_dt_reaction", region_id = "candidate_control_volume",
        candidate_binding_hash = repeat("f", 64), plasma_volume_m3 = volume,
        alpha_ion_fraction = 0.5, alpha_electron_fraction = 0.5,
        evidence_status = Dict(id => "complete" for id in
            ("alpha_partition", "candidate_binding", "fully_ionized_fuel",
                "isotropic_maxwellian_ions", "optically_thin_bremsstrahlung",
                "plasma_volume")), source_result_hash = repeat("a", 64))
    reference_state = [na, nb, ne, wi, we]
    transport_jacobian = zeros(4, 5)
    transport_jacobian[3, 4] = 0.5 * alpha_power / wi
    transport_jacobian[4, 5] = (0.5 * alpha_power - brems) / we
    transport = CandidateTransportResponseModuleV1(
        module_id = "candidate_dt_transport", region_id = "candidate_control_volume",
        candidate_binding_hash = repeat("f", 64),
        transport_operator_id = "candidate_bound_transport_fixture",
        flux_semantics = :radial_boundary, reference_state = reference_state,
        reference_flux = [0.0, 0.0, 0.5 * alpha_power,
            0.5 * alpha_power - brems], response_jacobian = transport_jacobian,
        validity_relative_radius = 0.2,
        evidence_status = Dict(id => "complete" for id in
            ("candidate_binding", "flux_values", "response_jacobian",
                "resolution_convergence", "validity_radius")),
        source_result_hash = repeat("b", 64))
    initials = Dict{String,Float64}(
        "fuel_a_inventory" => na, "fuel_b_inventory" => nb,
        "electron_inventory" => ne, "ion_thermal_energy" => wi,
        "electron_thermal_energy" => we, "fueling_output" => 2.0 * burn,
        "ion_heating_output" => 0.0, "electron_heating_output" => 0.0,
        "exhaust_output" => 0.0, "radiation_control_output" => 0.0)
    manifest = compile_longitudinal_candidate_manifest_v1(core;
        candidate_id = "candidate_dt_additive_fixture", physics_hash = repeat("f", 64),
        initial_conditions = initials)
    modules = AbstractResidualPhysicsModuleV1[core, reaction, transport]
    plan = compile_coupled_solve_plan_v1(manifest, modules)
    @test plan.status == :pass
    @test plan.compiler_audits["residual_producers"] == "pass"
    result = solve_coupled_plan_v1(manifest, modules, plan)
    @test result.status == :pass
    @test all(item -> item["status"] == "pass",
        result.audits["jacobian_directional_audits"])
    physics = result.observables["candidate_dt_reaction"]
    @test result.observables["candidate_dt_core"][
        "complete_power_ledger_authorized"] === false
    ledger = result.observables["candidate_power_ledger"]
    @test ledger["status"] == "unknown"
    @test "complete_radiation_model" in ledger["unresolved_roles"]
    @test isempty(ledger["competing_roles"])
    @test isapprox(ledger["terms"]["total_fusion_power_w"],
        physics["total_fusion_power_w"]; rtol = 1.0e-12)
    @test isapprox(ledger["terms"]["radiation_power_w"], brems; rtol = 2.0e-7)
    @test result.audits["candidate_power_ledger"]["status"] == "unknown"
    c2_state = compile_c2_candidate_state_package_from_v68_v1(manifest, result)
    c2_gate = c2_gate_from_v68_result_v1(c2_state, result)
    @test c2_state.candidate_binding_hash == manifest.physics_hash
    @test c2_state.boundary_classes == ["radial_boundary"]
    @test Set(getfield.(c2_state.species_states, :species_id)) ==
        Set(["fuel_a", "fuel_b", "electron"])
    @test c2_gate.completeness == :incomplete
    @test c2_gate.conclusion == :unknown
    @test "complete_candidate_bound_v68_field:conservation" in c2_gate.evidence_tasks
    stage4 = Dict{String,Any}(
        "candidate_binding_hash" => c2_state.candidate_binding_hash,
        "required_operator_ids" => ["three_dimensional_equilibrium_v2"],
        "passed_operator_ids" => ["three_dimensional_equilibrium_v2"],
        "failed_operator_ids" => String[], "unknown_operator_ids" => String[],
        "missing_evidence_operator_ids" => String[],
        "unsupported_operator_ids" => String[], "stage_complete" => true,
        "evidence" => [Dict{String,Any}(
            "operator_id" => "three_dimensional_equilibrium_v2",
            "status" => "pass", "state_result_hash" => c2_state.state_result_hash)],
        "evidence_tasks" => String[], "compilation_hash" => repeat("d", 64))
    engineering = compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = c2_state.candidate_binding_hash,
        state_result_hash = c2_state.state_result_hash, gate_id = "engineering",
        status = :pass, obligation_ids = ["engineering_constraints"],
        evidence_hashes = [repeat("e", 64)],
        claim_boundary = "Manufactured exact-state engineering bridge test only.")
    uncertainty = compile_c2_uncertainty_interval_evidence_v1(
        candidate_binding_hash = c2_state.candidate_binding_hash,
        state_result_hash = c2_state.state_result_hash,
        quantity_id = "power_balance_residual_w", lower = -1.0e-8,
        upper = 1.0e-8, unit = "W", coverage_probability = 0.95,
        method = "manufactured_interval_fixture",
        source_result_hash = repeat("f", 64))
    independent = compile_c2_independent_evidence_from_v68_v1(c2_state,
        result, uncertainty)
    @test independent.status == :pass
    @test c2_uncertainty_interval_evidence_to_dict_v1(uncertainty)["lower"] ==
        -1.0e-8
    final_c2 = compile_candidate_c2_decision_from_v68_v1(c2_state, result,
        stage4, engineering, independent)
    @test final_c2.completeness == :incomplete
    @test final_c2.candidate_conclusion == :unknown
    @test final_c2.incomplete_gate_ids == ["stage_3_residual"]
    mismatched_engineering = compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = c2_state.candidate_binding_hash,
        state_result_hash = repeat("1", 64), gate_id = "engineering",
        status = :pass, obligation_ids = ["engineering_constraints"],
        evidence_hashes = [repeat("2", 64)],
        claim_boundary = "Intentional state mismatch fixture.")
    @test_throws ArgumentError compile_candidate_c2_decision_from_v68_v1(
        c2_state, result, stage4, mismatched_engineering, independent)
    mismatched_interval = compile_c2_uncertainty_interval_evidence_v1(
        candidate_binding_hash = c2_state.candidate_binding_hash,
        state_result_hash = repeat("3", 64), quantity_id = "power_balance_residual_w",
        lower = -1.0, upper = 1.0, unit = "W", coverage_probability = 0.95,
        method = "intentional_mismatch", source_result_hash = repeat("4", 64))
    @test_throws ArgumentError compile_c2_independent_evidence_from_v68_v1(
        c2_state, result, mismatched_interval)
    @test isapprox(physics["burn_rate_per_s"], burn; rtol = 2.0e-7)
    @test isapprox(physics["fuel_ion_bremsstrahlung_power_w"], brems;
        rtol = 2.0e-7)
    @test physics["complete_radiation_authorized"] === false
    transport_observable = result.observables["candidate_dt_transport"]
    @test transport_observable["flux_semantics"] == "radial_boundary"
    @test transport_observable["maximum_reference_state_relative_delta"] <= 1.0e-8

    missing_provider_plan = compile_coupled_solve_plan_v1(manifest,
        AbstractResidualPhysicsModuleV1[core])
    @test missing_provider_plan.status == :unknown
    @test missing_provider_plan.compiler_audits["coupled_term_producers"] == "unknown"
    @test all(term_id -> any(reason -> reason ==
            "coupled_term_missing_provider:$term_id", missing_provider_plan.reasons),
        ("fusion_reaction", "fuel_ion_bremsstrahlung", "transport_response"))

    reaction_duplicate = CandidateReactionBremsstrahlungModuleV1(
        module_id = "candidate_dt_reaction_duplicate",
        region_id = "candidate_control_volume",
        candidate_binding_hash = repeat("f", 64), plasma_volume_m3 = volume,
        alpha_ion_fraction = 0.5, alpha_electron_fraction = 0.5,
        evidence_status = Dict(id => "complete" for id in
            ("alpha_partition", "candidate_binding", "fully_ionized_fuel",
                "isotropic_maxwellian_ions", "optically_thin_bremsstrahlung",
                "plasma_volume")), source_result_hash = repeat("d", 64))
    competing_plan = compile_coupled_solve_plan_v1(manifest,
        AbstractResidualPhysicsModuleV1[core, reaction, reaction_duplicate, transport])
    @test competing_plan.status == :unsupported
    @test any(reason -> reason ==
        "coupled_term_competing_providers:fusion_reaction", competing_plan.reasons)
end

function longitudinal_initial_v1(; fueling = 0.2, ion_heating = 0.1,
        electron_heating = 0.1, exhaust = 0.05, radiation = 0.01)
    return Dict{String,Float64}("fuel_a_inventory" => 0.8,
        "fuel_b_inventory" => 0.7, "electron_inventory" => 1.5,
        "ion_thermal_energy" => 0.8, "electron_thermal_energy" => 0.9,
        "fueling_output" => fueling, "ion_heating_output" => ion_heating,
        "electron_heating_output" => electron_heating, "exhaust_output" => exhaust,
        "radiation_control_output" => radiation)
end

@testset "candidate longitudinal strong-coupling residual module v1" begin
    parameters = longitudinal_parameters_v1()
    evidence = Dict(key => "complete" for key in keys(parameters))
    module_instance = CandidateLongitudinalBalanceModuleV1(
        module_id = "candidate_longitudinal_balance_fixture",
        region_id = "candidate_control_volume",
        transport_operator_id = "declared_parallel_or_radial_transport_fixture",
        parameters = parameters, parameter_evidence = evidence)
    manifest = compile_longitudinal_candidate_manifest_v1(module_instance;
        candidate_id = "candidate_bound_longitudinal_fixture",
        physics_hash = repeat("c", 64), initial_conditions = longitudinal_initial_v1())
    layout = only(state_layout(module_instance, manifest))
    @test layout.units == ["particle", "particle", "particle", "J", "J",
        "particle/s", "W", "W", "particle/s", "W"]
    @test layout.residual_units == ["particle/s", "particle/s", "particle", "W",
        "W", "particle/s", "W", "W", "particle/s", "W"]
    modules = AbstractResidualPhysicsModuleV1[module_instance]
    plan = compile_coupled_solve_plan_v1(manifest, modules)
    @test plan.status == :pass
    @test count(plan.differential_mask) == 4
    result = solve_coupled_plan_v1(manifest, modules, plan)
    @test result.status == :pass
    @test all(item -> item["status"] == "pass",
        result.audits["jacobian_directional_audits"])
    values = result.observables[module_instance.module_id]
    @test values["transport_operator_id"] ==
        "declared_parallel_or_radial_transport_fixture"
    @test haskey(values, "complete_power_ledger")
    @test haskey(values["complete_power_ledger"], "net_electric_lower_bound_w")
    @test values["complete_power_ledger_authorized"] === false
    @test values["power_ledger_evidence_tier"] == "L1_declared_parameter_only"
    @test result.observables["candidate_power_ledger"]["status"] == "unknown"
    @test "full_reaction_transport_radiation_capabilities" in
        result.observables["candidate_power_ledger"]["unresolved_roles"]
    c2_state = compile_c2_candidate_state_package_from_v68_v1(manifest, result)
    c2_gate = c2_gate_from_v68_result_v1(c2_state, result)
    @test c2_gate.completeness == :incomplete
    @test c2_gate.conclusion == :unknown
    @test isempty(c2_gate.narrow_failures)
    @test values["capacity_shortfall"] === false
    @test isapprox(result.final_state["fuel_a_inventory"], 1.0; atol = 2.0e-7)
    @test isapprox(result.final_state["fuel_b_inventory"], 1.0; atol = 2.0e-7)
    @test isapprox(result.final_state["ion_thermal_energy"], 1.0; atol = 2.0e-7)
    @test isapprox(result.final_state["electron_thermal_energy"], 1.0; atol = 2.0e-7)

    incomplete_evidence = deepcopy(evidence)
    incomplete_evidence["electron_heating_wall_plug_efficiency"] = "unknown"
    incomplete_module = CandidateLongitudinalBalanceModuleV1(
        module_id = "candidate_longitudinal_incomplete_fixture",
        region_id = "candidate_control_volume",
        transport_operator_id = "declared_transport_fixture",
        parameters = parameters, parameter_evidence = incomplete_evidence)
    incomplete_manifest = compile_longitudinal_candidate_manifest_v1(incomplete_module;
        candidate_id = "candidate_incomplete_fixture", physics_hash = repeat("d", 64),
        initial_conditions = longitudinal_initial_v1())
    incomplete_plan = compile_coupled_solve_plan_v1(incomplete_manifest,
        AbstractResidualPhysicsModuleV1[incomplete_module])
    @test incomplete_plan.status == :unknown
    @test any(reason -> occursin("parameter_evidence_incomplete", reason),
        incomplete_plan.reasons)

    saturated_parameters = longitudinal_parameters_v1(fueling_capacity_s = 0.1,
        ion_heating_capacity_w = 0.05, electron_heating_capacity_w = 0.05,
        exhaust_capacity_s = 0.05, radiation_control_capacity_w = 0.01)
    saturated_evidence = Dict(key => "complete" for key in keys(saturated_parameters))
    saturated_module = CandidateLongitudinalBalanceModuleV1(
        module_id = "candidate_longitudinal_saturated_fixture",
        region_id = "candidate_control_volume",
        transport_operator_id = "declared_transport_fixture",
        parameters = saturated_parameters, parameter_evidence = saturated_evidence)
    saturated_manifest = compile_longitudinal_candidate_manifest_v1(saturated_module;
        candidate_id = "candidate_saturated_fixture", physics_hash = repeat("e", 64),
        initial_conditions = longitudinal_initial_v1(fueling = 0.05, ion_heating = 0.02,
            electron_heating = 0.02, exhaust = 0.02, radiation = 0.005))
    saturated_modules = AbstractResidualPhysicsModuleV1[saturated_module]
    saturated_plan = compile_coupled_solve_plan_v1(saturated_manifest, saturated_modules)
    saturated_result = solve_coupled_plan_v1(saturated_manifest, saturated_modules,
        saturated_plan)
    @test saturated_result.status == :fail
    @test saturated_result.classification_code == "fail_actuator_capacity_shortfall"
    saturated_state = compile_c2_candidate_state_package_from_v68_v1(
        saturated_manifest, saturated_result)
    saturated_gate = c2_gate_from_v68_result_v1(saturated_state, saturated_result)
    @test saturated_gate.completeness == :incomplete
    @test saturated_gate.conclusion == :fail
    @test only(saturated_gate.narrow_failures).failure_code ==
        "fail_actuator_capacity_shortfall"
    @test only(saturated_gate.narrow_failures).terminates_candidate === false
end
