function _test_cem_v1_seed_raw()
    root = JSON3.read(read(joinpath(@__DIR__, "..", "examples", "seed_devices.json"), String),
        Dict{String,Any})
    return deepcopy(root["designs"][1])
end

function _test_cem_v1_property(id, unit, source_hash, reference_value)
    return Dict{String,Any}(
        "property_id" => id, "unit" => unit,
        "independent_variables" => ["temperature", "magnetic_field", "strain", "dpa"],
        "representation" => "piecewise_linear_table",
        "curve_data" => Dict("temperature_k" => [4.0, 20.0],
            "values" => [reference_value, reference_value],
            "reference_value" => reference_value),
        "validity_ranges" => Dict(
            "temperature" => Dict("minimum" => 4.0, "maximum" => 20.0, "unit" => "K"),
            "magnetic_field" => Dict("minimum" => 0.0, "maximum" => 20.0, "unit" => "T"),
            "strain" => Dict("minimum" => -0.01, "maximum" => 0.01, "unit" => "1"),
            "dpa" => Dict("minimum" => 0.0, "maximum" => 10.0, "unit" => "1")),
        "uncertainty" => Dict("kind" => "relative_1sigma", "value" => 0.05, "unit" => "1"),
        "source_refs" => ["test_material_dataset"], "data_hash" => source_hash)
end

function _test_cem_v1_complete_raw()
    raw = _test_cem_v1_seed_raw()
    region_id = String(raw["plasma_regions"][1]["id"])
    raw["engineering_geometry_manifest_v1"] = Dict{String,Any}(
        "applicable_component_roles" => ["winding_pack"],
        "components" => [Dict{String,Any}(
            "component_id" => "coil_1", "component_role" => "winding_pack",
            "material_id" => "conductor_v1",
            "finite_geometry" => Dict("representation" => "finite_volume_mesh",
                "geometry_hash" => repeat("a", 64), "mesh_hash" => repeat("b", 64),
                "mesh_dimension" => 3, "measure" => Dict("value" => 2.0, "unit" => "m^3")),
            "features" => [
                Dict("feature_id" => "conductor", "kind" => "conductor_paths",
                    "current_a" => 1.0e5, "total_length_m" => 100.0,
                    "conductor_area_m2" => 0.01, "conductor_volume_m3" => 1.0,
                    "field_volume_m3" => 1.0,
                    "operating_temperature_k" => 4.0, "excitation_frequency_hz" => 1.0,
                    "ac_loss_coefficient_w_per_a2_hz_m" => 1.0e-15),
                Dict("feature_id" => "support", "kind" => "support_domain",
                    "load_bearing_area_m2" => 0.5, "load_path_length_m" => 0.1),
                Dict("feature_id" => "coolant", "kind" => "coolant_channel",
                    "hydraulic_diameter_m" => 0.02, "total_length_m" => 50.0,
                    "flow_area_m2" => 0.01, "wetted_area_m2" => 5.0,
                    "critical_heat_flux_w_m2" => 1.0e6, "mass_flow_kg_s" => 10.0,
                    "density_kg_m3" => 125.0, "specific_heat_j_kg_k" => 5000.0,
                    "inlet_temperature_k" => 4.0, "darcy_friction_factor" => 0.02,
                    "pump_efficiency" => 0.70, "mapped_heat_fraction" => 0.01),
                Dict("feature_id" => "cryo", "kind" => "cryogenic_stage",
                    "ambient_temperature_k" => 300.0, "second_law_efficiency" => 0.25),
                Dict("feature_id" => "protection", "kind" => "quench_protection",
                    "dump_resistance_ohm" => 0.005, "detection_time_s" => 0.01,
                    "conductor_deposited_energy_fraction" => 0.001)])],
        "load_mappings" => [Dict{String,Any}(
            "mapping_id" => "plasma_field_to_coil", "source_region_id" => region_id,
            "source_load_slot" => "magnetic_field", "target_component_id" => "coil_1",
            "mapping_operator_id" => "conservative_field_projection_v1",
            "jacobian_operator_id" => "conservative_field_projection_jacobian_v1",
            "sign_convention" => "positive_into_component", "unit" => "T")],
        "contacts" => Dict{String,Any}[],
        "insulation_boundaries" => [Dict{String,Any}(
            "boundary_id" => "coil_ground_insulation", "component_id" => "coil_1",
            "insulation_material_id" => "insulation_v1", "thickness_m" => 0.01,
            "breakdown_field_v_per_m" => 1.0e7,
            "boundary_operator_id" => "dielectric_insulation_v1")],
        "boundary_conditions" => [Dict{String,Any}(
            "boundary_id" => "coil_coolant_boundary", "component_id" => "coil_1",
            "physics" => "thermal", "condition_type" => "robin",
            "boundary_operator_id" => "coolant_film_boundary_v1",
            "jacobian_operator_id" => "coolant_film_boundary_jacobian_v1")])
    source_hash = repeat("c", 64)
    conductor_properties = [
        _test_cem_v1_property("electrical_resistivity", "ohm*m", repeat("d", 64), 1.0e-12),
        _test_cem_v1_property("thermal_conductivity", "W/m/K", repeat("1", 64), 500.0),
        _test_cem_v1_property("specific_heat", "J/kg/K", repeat("2", 64), 400.0),
        _test_cem_v1_property("density", "kg/m^3", repeat("3", 64), 8000.0),
        _test_cem_v1_property("yield_strength", "Pa", repeat("4", 64), 5.0e8),
        _test_cem_v1_property("fatigue_strength", "Pa", repeat("5", 64), 3.0e8),
        _test_cem_v1_property("critical_current_density", "A/m^2", repeat("6", 64), 1.0e8),
        _test_cem_v1_property("critical_temperature", "K", repeat("7", 64), 20.0),
        _test_cem_v1_property("critical_field", "T", repeat("8", 64), 12.0)]
    insulation_property = _test_cem_v1_property("dielectric_strength", "V/m", repeat("e", 64), 1.0e7)
    raw["material_property_manifest_v1"] = Dict("materials" => [
        Dict("material_id" => "conductor_v1", "grade" => "test-conductor",
            "version" => "2026.1", "data_source_refs" => ["test_material_dataset"],
            "data_hash" => source_hash,
            "applicable_property_ids" => String[item["property_id"] for item in conductor_properties],
            "properties" => conductor_properties),
        Dict("material_id" => "insulation_v1", "grade" => "test-insulation",
            "version" => "2026.1", "data_source_refs" => ["test_material_dataset"],
            "data_hash" => source_hash, "applicable_property_ids" => ["dielectric_strength"],
            "properties" => [insulation_property])])
    raw["fault_scenario_manifest_v1"] = Dict{String,Any}(
        "applicable_fault_classes" => ["quench"],
        "scenarios" => [Dict{String,Any}(
            "scenario_id" => "coil_1_quench", "fault_class" => "quench",
            "applicability_basis" => "declared superconducting winding and dump protection",
            "initial_operating_point_hash" => repeat("f", 64),
            "target_component_ids" => ["coil_1"],
            "trigger" => Dict("event_type" => "normal_zone_seed", "time_s" => 0.0,
                "event_operator_id" => "normal_zone_seed_v1"),
            "protection_actions" => [Dict("action_id" => "dump", "start_time_s" => 0.01,
                "action_operator_id" => "dump_resistor_switch_v1",
                "capacity_limit" => Dict("value" => 1.0e9, "unit" => "J"))],
            "timeline" => [0.0, 0.01, 0.1, 1.0],
            "required_solver_capabilities" => ["finite_conductor_electromagnetics",
                "thermal_transient", "quench_propagation", "circuit_protection"],
            "acceptance_metrics" => [Dict("metric_id" => "peak_voltage",
                "observable_id" => "terminal_voltage", "statistic" => "peak",
                "comparison" => "<=", "threshold" => 1000.0, "unit" => "V",
                "location" => "coil_1 terminals")])])
    return raw
end

@testset "Candidate engineering manifests v1" begin
    missing = compile_candidate_engineering_manifests_v1(parse_genome(_test_cem_v1_seed_raw()))
    @test missing["status"] == :unknown
    @test missing["geometry"].status == :unknown
    @test missing["materials"].status == :unknown
    @test missing["faults"].status == :unknown
    @test isempty(missing["geometry"].components)
    @test engineering_geometry_manifest_to_dict_v1(missing["geometry"])["generated_nominal"] == false

    raw = _test_cem_v1_complete_raw()
    genome = parse_genome(raw)
    first = compile_candidate_engineering_manifests_v1(genome)
    second = compile_candidate_engineering_manifests_v1(genome)
    @test first["status"] == :pass
    @test first["geometry"].status == :pass
    @test first["materials"].status == :pass
    @test first["faults"].status == :pass
    @test first["bundle_hash"] == second["bundle_hash"]
    @test first["geometry"].physics_hash == genome.physics_hash
    @test first["materials"].materials[1]["version"] == "2026.1"
    @test first["faults"].scenarios[1]["acceptance_metrics"][1]["statistic"] == "peak"

    mutated = deepcopy(raw)
    mutated["engineering_geometry_manifest_v1"]["components"][1]["finite_geometry"]["measure"]["value"] = 2.1
    changed = compile_candidate_engineering_manifests_v1(parse_genome(mutated))
    @test changed["bundle_hash"] != first["bundle_hash"]
    @test changed["geometry"].manifest_hash != first["geometry"].manifest_hash

    malformed = _test_cem_v1_seed_raw()
    malformed["engineering_geometry_manifest_v1"] = Dict("applicable_component_roles" => ["winding_pack"])
    malformed["material_property_manifest_v1"] = Dict("materials" => Any[])
    malformed["fault_scenario_manifest_v1"] = Dict("applicable_fault_classes" => ["quench"],
        "scenarios" => Any[])
    rejected = compile_candidate_engineering_manifests_v1(parse_genome(malformed))
    @test rejected["status"] == :unsupported
    @test !isempty(rejected["unresolved_reasons"])
end

@testset "Candidate engineering finite-component vertical slice v1" begin
    loads = Dict{String,Any}("state_result_hash" => repeat("8", 64),
        "field_solution_hash" => repeat("9", 64),
        "transport_result_hash" => repeat("a", 64), "peak_field_t" => 5.0,
        "mapped_heat_power_w" => 1.0e4)
    missing_genome = parse_genome(_test_cem_v1_seed_raw())
    missing = solve_magnet_structural_thermal_quench_v1(missing_genome)
    @test missing.status == :unknown
    @test missing.convergence_status == "not_executed_manifest_gate"
    @test isempty(missing.component_outputs)

    raw = _test_cem_v1_complete_raw()
    genome = parse_genome(raw)
    no_load = solve_magnet_structural_thermal_quench_v1(genome)
    @test no_load.status == :unsupported
    @test any(contains("upstream"), no_load.unresolved_reasons)
    first = solve_magnet_structural_thermal_quench_v1(genome; load_context = loads)
    second = solve_magnet_structural_thermal_quench_v1(genome; load_context = loads)
    @test first.status == :pass
    @test first.state_result_hash == loads["state_result_hash"]
    @test first.field_solution_hash == loads["field_solution_hash"]
    @test first.transport_result_hash == loads["transport_result_hash"]
    @test first.convergence_status == "converged_exact_lumped_balances"
    @test first.result_hash == second.result_hash
    @test length(first.component_outputs) == 1
    @test length(first.engineering_checks) == 8
    @test all(item -> item["status"] == "pass", first.engineering_checks)
    @test Set(item["role_id"] for item in first.plant_power_roles) == Set([
        "magnet_power_and_pulse_storage", "cryogenic_system",
        "coolant_circulation_heat_rejection"])
    @test all(item -> item["status"] == "complete", first.plant_power_roles)
    @test maximum(abs(Float64(item[key])) for item in first.residuals for key in
        ("electromagnetic_energy_residual_j", "thermal_balance_residual_w",
         "hydraulic_power_residual_w")) < 1.0e-8
    @test engineering_multiphysics_result_to_dict_v1(first)["result_hash"] == first.result_hash

    overloaded = deepcopy(raw)
    overloads = deepcopy(loads); overloads["peak_field_t"] = 20.0
    failed = solve_magnet_structural_thermal_quench_v1(parse_genome(overloaded);
        load_context = overloads)
    @test failed.status == :fail
    @test any(item -> item["check_id"] == "peak_internal_conductor_field" &&
        item["status"] == "fail", failed.engineering_checks)

    incomplete = deepcopy(raw)
    pop!(incomplete["engineering_geometry_manifest_v1"]["components"][1]["features"])
    unsupported = solve_magnet_structural_thermal_quench_v1(parse_genome(incomplete);
        load_context = loads)
    @test unsupported.status == :unsupported
    @test any(contains("quench_protection"), unsupported.unresolved_reasons)
end
