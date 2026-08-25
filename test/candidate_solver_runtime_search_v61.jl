using Test
using JSON3
using FusionConceptAI

@testset "explicit regional Genome grammar and runtime v61" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    # 844 exercises positive-state feasibility scaling; 8002 exercises the
    # centered flux representation used to avoid common-state cancellation.
    for candidate_index in (1, 844, 3860, 8002)
        base = evaluate_solver_ready_candidate_v54(context, candidate_index)
        bundle = compile_candidate_solver_judgment_input_v61(context, candidate_index)
        genome = bundle["candidate"].prescreen.compiled.genome
        result = bundle["region_solve_result"]
        @test genome.physics_hash != base.prescreen.compiled.genome.physics_hash
        @test regional_solver_contract_audit_v61(genome)["status"] == "ready"
        @test length(bundle["region_state_specs"]) == length(genome.plasma_regions)
        @test length(bundle["interface_flux_contracts"]) == length(genome.flux_connections)
        @test all(spec -> spec.applicability["status"] == "complete",
            bundle["region_state_specs"])
        @test all(item -> item.applicability["status"] == "complete",
            bundle["interface_flux_contracts"])
        @test result.status == :pass
        @test region_full_search_gate_passes_v1(result)
        @test all(id -> result.gate_statuses[id]["status"] == "pass",
            ("regional_conservation", "actuator_realization", "resolution_convergence"))
        @test result.error_estimates["maximum_normalized_regional_residual"] <=
            bundle["manifest"].numerical_tolerances["normalized_residual"]
        @test result.error_estimates["relative_resolution_error"] <=
            bundle["manifest"].numerical_tolerances["relative_resolution"]
        @test all(item -> item["upstream_flux"] == -item["downstream_flux"],
            result.paired_interface_fluxes)
        @test all(item -> all(>(0.0), values(item["final_state"])),
            result.region_trajectories)
        @test all(item -> 0.0 <= item["positive_state_feasibility_scale"] <= 1.0,
            genome.normalized["regional_solver_contract_v1"]["actuator_sizing_records"])
        @test all(item -> haskey(item, "centered_solver_state"),
            result.region_trajectories)
    end
    source = read(joinpath(root, "src", "search", "regional_genome_grammar_v61.jl"), String) *
        read(joinpath(root, "src", "candidate_solver_runtime_v5.jl"), String) *
        read(joinpath(root, "src", "search", "candidate_solver_runtime_search_v61.jl"), String)
    @test !occursin("genome.family", source)
    @test !occursin("family ==", source)
    @test occursin("equal_region_split", source)
    @test occursin("analytic_two_point_flux_jacobian_v1", source)
    overlay = JSON3.read(read(joinpath(root, "schemas",
        "confinement_genome_v61.schema.json"), String), Dict{String,Any})
    @test overlay["properties"]["regional_solver_contract_v1"]["\$ref"] ==
        "#/\$defs/regional_contract"
    interface_schema = overlay["\$defs"]["explicit_interface"]
    jacobian_schema = interface_schema["properties"]["operator_contract"]
    @test jacobian_schema["properties"]["jacobian_provider"]["const"] ==
        "analytic_two_point_flux_jacobian_v1"
end
