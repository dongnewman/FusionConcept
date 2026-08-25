using Test
using JSON3
using FusionConceptAI

@testset "region-first candidate solver gate v60" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    bundle = compile_candidate_solver_judgment_input_v60(context, 1;
        discretization_levels = [32, 64])
    specs = bundle["region_state_specs"]
    interfaces = bundle["interface_flux_contracts"]
    result = bundle["region_solve_result"]

    @test length(specs) == length(bundle["manifest"].regions)
    @test length(interfaces) == length(bundle["manifest"].boundaries)
    @test all(spec -> length(spec.spec_hash) == 64, specs)
    @test all(item -> length(item.contract_hash) == 64, interfaces)
    @test length(result.result_hash) == 64
    @test result.status in (:unknown, :unsupported)
    @test result.gate_statuses["regional_conservation"]["status"] != "pass"
    @test result.gate_statuses["actuator_realization"]["status"] == "not_evaluated"
    @test result.gate_statuses["resolution_convergence"]["status"] == "not_evaluated"
    @test !region_full_search_gate_passes_v1(result)
    @test bundle["artifact_summary"]["full_search_authorized"] === false
    @test bundle["judgment_input"]["state_evolution"]["solver_derived"] === false
    @test bundle["judgment_input"]["transport_burn"]["solver_derived"] === false
    @test isempty(bundle["judgment_input"]["net_energy"]["terms"])
    @test evaluate_uniform_judgment_v55(bundle["judgment_input"])["decision"] == "unknown"

    source = read(joinpath(root, "src", "candidate_solver_runtime_v4.jl"), String) *
        read(joinpath(root, "src", "search", "candidate_solver_runtime_search_v60.jl"), String)
    @test !occursin("genome.family", source)
    @test !occursin("family ==", source)
    @test occursin("equal_region_split", source)
    for schema_name in ("region_state_spec_v1.schema.json",
            "interface_flux_contract_v1.schema.json",
            "region_solve_result_envelope_v1.schema.json")
        schema = JSON3.read(read(joinpath(root, "schemas", schema_name), String))
        @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    end
end
