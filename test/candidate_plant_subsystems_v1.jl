function _test_cps_v1_record(body)
    record = Dict{String,Any}(String(key) => value for (key, value) in body)
    record["source_refs"] = ["test:plant_subsystem_dataset"]
    record["relative_uncertainty"] = 0.05
    record["data_hash"] = canonical_hash(record)
    return record
end

function _test_cps_v1_manifest!(raw)
    region_id = String(raw["plasma_regions"][1]["id"])
    applicable(provider, basis) = Dict("status" => "applicable",
        "provider" => provider, "basis" => basis,
        "time_behavior" => "already_cycle_average", "relative_uncertainty" => 0.05)
    not_applicable(provider, basis) = Dict("status" => "not_applicable",
        "provider" => provider, "basis" => basis,
        "time_behavior" => "not_applicable", "relative_uncertainty" => 0.0)
    raw["plant_subsystem_manifest_v1"] = Dict{String,Any}(
        "role_applicability" => Dict(
            "heating_and_current_drive_wall_plug" => applicable("regional_actuator", "declared energy actuator"),
            "particle_injection_fuel_processing" => applicable("v64_exhaust_fuel", "fuel species and source rate apply"),
            "magnet_power_and_pulse_storage" => applicable("v63_engineering", "finite winding applies"),
            "cryogenic_system" => applicable("v63_engineering", "cryogenic winding applies"),
            "vacuum_exhaust_pumping" => applicable("v64_exhaust_fuel", "particle exhaust applies"),
            "coolant_circulation_heat_rejection" => applicable("v64_thermal_cycle", "coolant networks apply"),
            "thermal_conversion_auxiliaries" => applicable("v64_thermal_cycle", "heat cycle applies"),
            "shielding_cooling" => not_applicable("none", "test slice declares no shielding component"),
            "controls_diagnostics_auxiliaries" => applicable("v64_auxiliary_load", "control equipment applies"),
            "direct_energy_recovery" => not_applicable("none", "no direct recovery module declared"),
            "gross_electric_generation" => applicable("v64_thermal_cycle", "loss heat cycle applies")),
        "exhaust_networks" => [_test_cps_v1_record(Dict(
            "network_id" => "test_exhaust", "target_region_ids" => [region_id],
            "species_ids" => ["deuterium", "tritium"], "throughput_fraction" => 1.0,
            "inlet_temperature_k" => 300.0, "inlet_pressure_pa" => 1.0,
            "outlet_pressure_pa" => 1.0e5, "duct_length_m" => 1.0,
            "duct_diameter_m" => 10.0, "pump_speed_capacity_m3_s" => 1.0e9,
            "isothermal_efficiency" => 0.7, "operating_duty_factor" => 1.0))],
        "fuel_cycle_systems" => [_test_cps_v1_record(Dict(
            "system_id" => "test_fuel", "species_ids" => ["deuterium", "tritium"],
            "throughput_fraction" => 1.0, "processing_capacity_per_s" => 1.0e40,
            "processing_energy_j_per_particle" => 1.0e-12,
            "processing_efficiency" => 0.8, "capacity_basis" => "cycle_average_rate",
            "residence_time_s" => 100.0, "inventory_limit_kg" => 1.0e9,
            "retention_fraction" => 0.01))],
        "thermal_cycles" => [_test_cps_v1_record(Dict(
            "cycle_id" => "test_cycle", "source_heat_role" => "loss_power",
            "source_fraction" => 1.0, "heat_exchanger_effectiveness" => 0.9,
            "coolant_mass_flow_kg_s" => 1.0e9,
            "coolant_specific_heat_j_kg_k" => 5000.0,
            "coolant_density_kg_m3" => 1000.0,
            "coolant_inlet_temperature_k" => 500.0, "sink_temperature_k" => 300.0,
            "second_law_efficiency" => 0.6, "coolant_pressure_drop_pa" => 1.0e5,
            "circulation_pump_efficiency" => 0.8, "circulation_duty_factor" => 1.0,
            "generator_auxiliary_fraction" => 0.02))],
        "shielding_cooling_systems" => Dict{String,Any}[],
        "auxiliary_loads" => [_test_cps_v1_record(Dict(
            "load_id" => "test_controls", "rated_power_w" => 1.0e6,
            "duty_factor" => 0.5, "supply_efficiency" => 0.9))],
        "direct_recovery_systems" => Dict{String,Any}[],
        "uncertainty_contract" => Dict("coverage_sigma" => 2.0,
            "net_sign_required" => true))
    return raw
end

@testset "Plant subsystem manifest v1" begin
    missing = compile_plant_subsystem_manifest_v1(parse_genome(_test_cem_v1_seed_raw()))
    @test missing.status == :unknown
    @test isempty(missing.exhaust_networks)
    raw = _test_cps_v1_manifest!(_test_cem_v1_complete_raw())
    genome = parse_genome(raw)
    first = compile_plant_subsystem_manifest_v1(genome)
    second = compile_plant_subsystem_manifest_v1(genome)
    @test first.status == :pass
    @test first.manifest_hash == second.manifest_hash
    @test length(first.role_applicability) == 11
    @test plant_subsystem_manifest_to_dict_v1(first)["generated_nominal"] == false
    malformed = deepcopy(raw)
    delete!(malformed["plant_subsystem_manifest_v1"]["exhaust_networks"][1], "inlet_pressure_pa")
    rejected = compile_plant_subsystem_manifest_v1(parse_genome(malformed))
    @test rejected.status == :unsupported
    @test any(contains("inlet_pressure_pa"), rejected.unresolved_reasons)
end

@testset "Plant subsystem numerical runtime v1" begin
    seeds = load_genomes(joinpath(@__DIR__, "..", "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    base = compile_candidate_solver_judgment_input_v63(context, 1;
        discretization_levels = [32, 64])
    raw = deepcopy(base["candidate"].prescreen.compiled.genome.normalized)
    _test_cps_v1_manifest!(raw)
    genome = parse_genome(raw)
    module_ids = base["candidate"].prescreen.compiled.module_ids
    manifest = compile_candidate_solve_manifest_v3(genome, module_ids;
        discretization_levels = [32, 64])
    specs = compile_region_state_specs_v2(genome, manifest)
    interfaces = compile_interface_flux_contracts_v2(genome, manifest, specs)
    regional = solve_region_partition_v2(manifest, specs, interfaces, genome)
    transport = solve_regional_reaction_transport_v1(manifest, specs, regional, genome)
    load_context = engineering_load_context_v1(manifest, regional, transport)
    engineering = solve_magnet_structural_thermal_quench_v1(genome,
        compile_candidate_engineering_manifests_v1(genome); load_context = load_context)
    plant_manifest = compile_plant_subsystem_manifest_v1(genome)
    first = solve_plant_subsystems_v1(genome, plant_manifest, regional, transport,
        engineering; load_context = load_context)
    second = solve_plant_subsystems_v1(genome, plant_manifest, regional, transport,
        engineering; load_context = load_context)
    @test first.status in (:pass, :fail)
    @test first.result_hash == second.result_hash
    @test length(first.exhaust_results) == 1
    @test length(first.fuel_cycle_results) == 1
    @test length(first.thermal_cycle_results) == 1
    @test Set(item["role_id"] for item in first.plant_roles) == Set([
        "particle_injection_fuel_processing", "vacuum_exhaust_pumping",
        "coolant_circulation_heat_rejection", "thermal_conversion_auxiliaries",
        "shielding_cooling", "controls_diagnostics_auxiliaries",
        "direct_energy_recovery", "gross_electric_generation"])
    @test all(item -> item["status"] in ("complete", "not_applicable"), first.plant_roles)
    @test all(item -> item["uncertainty_interval"] isa AbstractDict, first.plant_roles)
    @test first.time_basis["status"] == "complete"
    @test plant_subsystem_result_to_dict_v1(first)["result_hash"] == first.result_hash
    ledger = solve_complete_plant_power_ledger_v1(manifest, regional, transport,
        engineering, plant_manifest, first)
    replay = solve_complete_plant_power_ledger_v1(manifest, regional, transport,
        engineering, plant_manifest, first)
    ledger_dict = plant_power_ledger_to_dict_v1(ledger)
    @test ledger.result_hash == replay.result_hash
    @test length(ledger.plant_roles) == 11
    @test all(item -> item["status"] in ("complete", "not_applicable"), ledger.plant_roles)
    @test ledger.closure["complete"] == true
    @test isempty(ledger.closure["unresolved_roles"])
    @test ledger.reported_net_power_w ≈ ledger.gross_electric_power_w +
        ledger.direct_recovery_power_w - ledger.recirculating_power_w
    @test ledger.status in (:pass, :fail, :unknown)
    @test ledger_dict["result_hash"] == ledger.result_hash
    @test ledger_dict["strict_role_completeness_required"] == true
end
