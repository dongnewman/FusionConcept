using Test
using JSON3
using FusionConceptAI

@testset "candidate solver convergence and engineering roles v58" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)

    steady = compile_candidate_solver_judgment_input_v58(context, 1;
        discretization_levels = [16], compile_problem_artifacts = false)
    steady_result = steady["solver_result"]
    steady_input = steady["judgment_input"]
    steady_judgment = evaluate_uniform_judgment_v55(steady_input)
    operators = Set(String(item["operator_id"])
        for item in steady["manifest"].module_bindings)
    @test steady["manifest"].applicability_scope["transport_control_volume_scope"] ==
        "closed"
    @test "state_derived_bohm_transport_l1_v1" in operators
    @test !("state_derived_parallel_streaming_l1_v1" in operators)
    @test steady_result.status == :pass
    @test steady_result.convergence_status ==
        "converged_with_required_closure_demands"
    @test steady_result.error_estimates["maximum_normalized_conservation_residual"] == 0.0
    closure = only(item for item in steady_result.module_results if
        String(get(item, "operator_id", "")) == "required_steady_source_sink_roles_v2")
    @test closure["status"] == "computed_requirement_not_engineering_realization"
    @test closure["required_source_by_state"]["particle_inventory"] > 0.0
    @test closure["required_source_by_state"]["thermal_energy"] > 0.0

    engineering = steady["engineering_result"]
    engineering_dict = engineering_result_envelope_to_dict_v1(engineering)
    @test engineering.status == :unknown
    @test length(engineering.result_hash) == 64
    @test engineering_dict["result_hash"] == engineering.result_hash
    @test engineering.recirculating_power["value_w"] > 0.0
    @test engineering.recirculating_power["role_completeness"] == "lower_bound"
    role_ids = Set(String(item["role_id"]) for item in engineering.output_roles)
    @test "magnetic_pressure_load" in role_ids
    @test "required_particle_replenishment" in role_ids
    @test "required_auxiliary_thermal_power" in role_ids
    @test "recirculating_power_lower_bound" in role_ids
    @test Set(String(item["check_id"]) for item in engineering.checks) ==
        Set(("field_strength", "force", "stress", "heat_flux", "material_temperature",
            "irradiation", "quench", "repetition_rate", "maintenance_space",
            "fuel_cycle", "component_lifetime"))
    ledger = steady_input["net_energy"]
    @test ledger["status"] == "unknown_incomplete_solver_output_role"
    @test ledger["strict_role_completeness_required"] === true
    recirculating_term = only(item for item in ledger["terms"] if
        item["role"] == "recirculating")
    @test recirculating_term["source_output_hash"] == engineering.result_hash
    @test recirculating_term["role_completeness"] == "lower_bound"
    @test steady_judgment["stages"][3]["status"] == "pass"
    @test steady_judgment["stages"][5]["status"] == "pass"
    @test steady_judgment["stages"][6]["status"] == "unknown"
    @test steady_judgment["stages"][7]["status"] == "unknown"
    @test steady_judgment["decision"] == "unknown"

    pulsed = compile_candidate_solver_judgment_input_v58(context, 5;
        discretization_levels = [16], compile_problem_artifacts = false)
    pulsed_judgment = evaluate_uniform_judgment_v55(pulsed["judgment_input"])
    @test pulsed["solver_result"].status == :pass
    @test pulsed["solver_result"].convergence_status == "complete_pulsed_trajectory"
    @test pulsed["solver_result"].error_estimates[
        "maximum_normalized_conservation_residual"] <=
        pulsed["manifest"].numerical_tolerances["normalized_residual"]
    @test pulsed_judgment["stages"][3]["status"] == "pass"
    @test pulsed_judgment["decision"] == "unknown"

    unsupported = compile_candidate_solver_judgment_input_v58(context, 2;
        discretization_levels = [16], compile_problem_artifacts = false)
    @test unsupported["solver_result"].status == :unsupported
    @test unsupported["solver_result"].convergence_status ==
        "not_run_missing_inputs_or_operator"
    @test evaluate_uniform_judgment_v55(unsupported["judgment_input"])["decision"] ==
        "unknown"

    source = read(joinpath(root, "src", "candidate_solver_runtime_v2.jl"), String) *
        read(joinpath(root, "src", "search", "candidate_solver_runtime_search_v58.jl"),
            String)
    @test !occursin("genome.family", source)
    schema = JSON3.read(read(joinpath(root, "schemas",
        "engineering_result_envelope_v1.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
end
