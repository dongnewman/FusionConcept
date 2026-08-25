using Test
using JSON3
using FusionConceptAI

function _v59_test_manifest_with_contracts(manifest, contracts; plant_roles = Dict{String,Any}(),
        single_region = true)
    parameters = deepcopy(manifest.parameters)
    parameters["actuator_contracts"] = contracts
    parameters["declared_plant_power_roles_w"] = plant_roles
    regions = single_region ? [deepcopy(first(manifest.regions))] : manifest.regions
    boundaries = single_region ? Dict{String,Any}[] : manifest.boundaries
    if single_region
        region_id = String(first(regions)["region_id"])
        state_ids = String[String(item["state_id"]) for item in manifest.state_variables]
        parameters["declared_region_network_v1"] = Dict{String,Any}(
            "nodes" => [Dict("region_id" => region_id,
                "kind" => String(get(first(regions), "kind", "")),
                "geometry_model" => String(get(first(regions), "geometry_model", "")),
                "state_ids" => state_ids, "state_partition_status" =>
                    "primary_control_volume")],
            "edges" => [Dict("from_region_id" => region_id,
                "to_region_id" => "__external_boundary__",
                "kind" => "transport_loss_boundary",
                "flux_partition_status" => "computed_from_selected_transport_operator")],
            "status" => "complete_single_declared_control_volume",
            "routing_basis" => "explicit unit-test fixture")
    end
    return CandidateSolveManifestV1(candidate_id = manifest.candidate_id,
        physics_hash = manifest.physics_hash, regions = regions, mesh = manifest.mesh,
        state_variables = manifest.state_variables,
        capability_declarations = manifest.capability_declarations,
        module_bindings = manifest.module_bindings, boundaries = boundaries,
        sources_sinks = manifest.sources_sinks, time_mode = manifest.time_mode,
        initial_conditions = manifest.initial_conditions,
        numerical_tolerances = manifest.numerical_tolerances,
        discretization_levels = manifest.discretization_levels,
        required_outputs = manifest.required_outputs,
        applicability_scope = manifest.applicability_scope, parameters = parameters)
end

function _v59_test_contract(id; energy = nothing, particles = nothing, wall = nothing)
    capabilities = String[]
    energy isa Real && push!(capabilities, "deposited_energy_source")
    particles isa Real && push!(capabilities, "particle_source")
    body = Dict{String,Any}("actuator_id" => id, "declared_kind" => "test_fixture",
        "provided_capabilities" => capabilities,
        "plasma_side_power_capacity_w" => energy,
        "particle_rate_capacity_per_s" => particles,
        "deposition_efficiency" => 1.0, "wall_plug_efficiency" => wall,
        "dynamic_response_time_s" => 0.0, "parameters" => Any[],
        "capacity_basis" => "explicit unit-test fixture")
    body["contract_hash"] = canonical_hash(body)
    return body
end

@testset "regional transport actuator and plant ledger v59" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    bundle = compile_candidate_solver_judgment_input_v59(context, 1;
        discretization_levels = [16], compile_problem_artifacts = false)
    manifest = bundle["manifest"]
    @test manifest.parameters["capability_dependency_graph_v1"][
        "compatibility_status"] == "compatible"
    @test manifest.parameters["declared_region_network_v1"]["status"] ==
        "unknown_missing_multi_region_state_partition"
    @test bundle["regional_coupled_result"].status == :unsupported
    @test bundle["regional_coupled_result"].convergence_status ==
        "unsupported_missing_actuator_module"
    @test evaluate_uniform_judgment_v55(bundle["judgment_input"])["decision"] == "unknown"
    @test plant_power_ledger_to_dict_v1(bundle["plant_power_ledger"])["status"] ==
        "unknown_incomplete_solver_output_role"

    explicit = [_v59_test_contract("fuel"; particles = 1.0e40, wall = 0.5),
        _v59_test_contract("heat"; energy = 1.0e30, wall = 0.5)]
    realized_manifest = _v59_test_manifest_with_contracts(manifest, explicit)
    realized_state = solve_candidate_manifest_v2(realized_manifest)
    realized = solve_region_actuator_coupling_v1(realized_manifest, realized_state)
    @test realized.status == :pass
    @test realized.convergence_status ==
        "coupled_state_and_actuator_demands_converged"
    @test last(realized.residual_history)[
        "maximum_normalized_conservation_residual"] <=
        realized_manifest.numerical_tolerances["normalized_residual"]
    @test last(realized.residual_history)[
        "maximum_normalized_demand_realization_mismatch"] <=
        realized_manifest.numerical_tolerances["normalized_residual"]

    insufficient_manifest = _v59_test_manifest_with_contracts(manifest,
        [_v59_test_contract("fuel"; particles = 1.0, wall = 0.5),
            _v59_test_contract("heat"; energy = 1.0, wall = 0.5)])
    insufficient = solve_region_actuator_coupling_v1(insufficient_manifest,
        solve_candidate_manifest_v2(insufficient_manifest))
    @test insufficient.status == :fail
    @test insufficient.convergence_status == "capacity_constrained_infeasible"
    insufficient_state = solve_candidate_manifest_v2(insufficient_manifest)
    insufficient_transport = FusionConceptAI._v59_transport_result(insufficient_state,
        insufficient_manifest, insufficient)
    insufficient_engineering = solve_engineering_roles_v2(insufficient_manifest,
        insufficient_state, insufficient_transport, insufficient)
    actuator_check = only(item for item in insufficient_engineering.checks if
        item["check_id"] == "actuator_capacity")
    @test insufficient_engineering.status == :fail
    @test actuator_check["status"] == "fail"
    @test actuator_check["normalized_margin"] < 0.0

    efficiency_unknown_manifest = _v59_test_manifest_with_contracts(manifest,
        [_v59_test_contract("fuel"; particles = 1.0e40, wall = 0.5),
            _v59_test_contract("heat"; energy = 1.0e30)])
    efficiency_unknown = solve_region_actuator_coupling_v1(efficiency_unknown_manifest,
        solve_candidate_manifest_v2(efficiency_unknown_manifest))
    @test efficiency_unknown.status == :unknown
    @test efficiency_unknown.convergence_status ==
        "numerically_converged_efficiency_evidence_unknown"

    engineering = solve_engineering_roles_v2(realized_manifest, realized_state,
        FusionConceptAI._v59_transport_result(realized_state, realized_manifest, realized),
        realized)
    role_ids = Set(String(item["role_id"]) for item in engineering.output_roles)
    @test all(id -> id in role_ids, ("local_target_heat_flux",
        "conductor_hotspot_temperature", "quench_voltage", "structural_peak_stress",
        "irradiation_damage_rate", "component_lifetime", "fuel_cycle_inventory",
        "maintenance_access_margin"))
    @test engineering.recirculating_power["role_completeness"] == "lower_bound"

    for schema_name in ("regional_coupled_solve_envelope_v1.schema.json",
            "plant_power_ledger_v1.schema.json")
        schema = JSON3.read(read(joinpath(root, "schemas", schema_name), String))
        @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    end
    source = read(joinpath(root, "src", "candidate_solver_runtime_v3.jl"), String) *
        read(joinpath(root, "src", "search", "candidate_solver_runtime_search_v59.jl"), String)
    @test !occursin("genome.family", source)
end
