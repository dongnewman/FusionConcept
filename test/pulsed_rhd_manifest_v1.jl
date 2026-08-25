@testset "PulsedRHDManifestV1 fail-closed input readiness" begin
    hash = repeat("a", 64)
    raw = Dict{String,Any}(
        "solver_ready_contracts" => [Dict("capability" => "radiation_hydrodynamics")],
        "compression_systems" => [Dict("kind" => "laser_direct_drive",
            "parameters" => Dict("repetition_rate" => Dict("value" => 5.0,
                "unit" => "Hz", "basis" => "explicit test")))],
        "actuators" => [Dict("id" => "laser", "parameters" => Dict(
            "on_target_energy" => Dict("value" => 1.0e6, "unit" => "J",
                "basis" => "explicit test")))],
        "regional_solver_contract_v1" => Dict("region_records" => [Dict(
            "region_id" => "fuel", "volume_m3" => 1.0e-9,
            "state_profile" => Dict("basis" => "generic"))]),
        "time_integration_contract_v1" => Dict("repetition_rate_hz" => 5.0))
    missing = compile_pulsed_rhd_manifest_v1(raw, "candidate", hash)
    @test missing["status"] == "unknown"
    @test "equation_of_state" in missing["blocking_missing_inputs"]
    @test !missing["regional_state_diagnostics"][1]["usable_as_target_layer_initial_condition"]
    @test !missing["family_label_used_for_routing"]

    conflicting = deepcopy(raw)
    conflicting["time_integration_contract_v1"]["repetition_rate_hz"] = 1.0
    conflict = compile_pulsed_rhd_manifest_v1(conflicting, "candidate", hash)
    @test conflict["status"] == "unsupported"
    @test !isempty(conflict["declaration_conflicts"])

    complete = deepcopy(raw)
    complete["pulsed_rhd_manifest_v1"] = Dict{String,Any}(
        "candidate_physics_hash" => hash,
        "target_layers" => [Dict("layer_id" => "dt_fuel", "inner_radius_m" => 0.0,
            "outer_radius_m" => 1.0e-3, "material_id" => "dt_ice",
            "material_version" => "test-v1", "isotope_fractions" =>
                Dict("D" => 0.5, "T" => 0.5),
            "initial_density_profile" => Dict("basis" => "radial_knots",
                "knots" => [[0.0, 250.0], [1.0e-3, 250.0]]),
            "initial_temperature_profile" => Dict("basis" => "radial_knots",
                "knots" => [[0.0, 18.0], [1.0e-3, 18.0]]),
            "mesh_region_id" => "fuel")],
        "material_microphysics" => Dict(
            "equation_of_state" => Dict("model_or_table_id" => "eos-test",
                "version" => "1", "table_hash" => repeat("b", 64),
                "validity_domain" => Dict("density_kg_m3" => [1.0, 1.0e6]),
                "relative_uncertainty" => 0.1),
            "multigroup_opacity" => Dict("model_or_table_id" => "opacity-test",
                "version" => "1", "table_hash" => repeat("c", 64),
                "validity_domain" => Dict("temperature_k" => [1.0e3, 1.0e9]),
                "relative_uncertainty" => 0.2)),
        "drive_history" => Dict("wavelength_m" => 351.0e-9,
            "temporal_power_knots" => [Dict("time_s" => 0.0, "power_w" => 0.0),
                Dict("time_s" => 1.0e-9, "power_w" => 1.0e15)],
            "spatial_profile_hash" => repeat("d", 64),
            "deposition_operator_hash" => repeat("e", 64)),
        "numerical_convergence_plan" => Dict("radial_cell_levels" => [64, 128],
            "radiation_group_levels" => [16, 32], "cfl_target" => 0.5,
            "relative_tolerance" => 0.02,
            "convergence_observables" => ["burn_yield", "shock_timing"]),
        "required_outputs" => ["shock_radius_history", "shock_timing",
            "convergence_ratio", "areal_density", "hotspot_temperature",
            "absorbed_drive_energy", "radiation_loss", "burn_yield",
            "alpha_deposition", "conservation_ledger"])
    ready = compile_pulsed_rhd_manifest_v1(complete, "candidate", hash)
    @test ready["status"] == "ready_for_external_backend"
    @test isempty(ready["blocking_missing_inputs"])

    unrelated = Dict{String,Any}("solver_ready_contracts" =>
        [Dict("capability" => "axisymmetric_mhd_equilibrium")])
    @test compile_pulsed_rhd_manifest_v1(unrelated, "magnetic", hash)["status"] ==
        "not_applicable"
end
