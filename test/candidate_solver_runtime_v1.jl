using Test
using JSON3
using FusionConceptAI

@testset "capability-assembled candidate solver runtime v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    compiled = evaluate_solver_ready_candidate_v54(context, 1).prescreen.compiled

    manifest = compile_candidate_solve_manifest_v1(compiled.genome,
        compiled.module_ids; discretization_levels = [16, 32])
    manifest_dict = candidate_solve_manifest_to_dict_v1(manifest)
    manifest_body = Dict{String,Any}(String(key) => value for (key, value) in
        manifest_dict if String(key) != "manifest_hash")
    @test manifest.manifest_hash == canonical_hash(manifest_body)
    @test manifest.applicability_scope["status"] == "applicable"
    @test manifest.applicability_scope["routing_basis"] ==
        "declared_module_capabilities_only"
    capabilities = Set(String(item["capability_id"])
        for item in manifest.capability_declarations)
    @test "conserved_particle_inventory" in capabilities
    @test "conserved_thermal_energy" in capabilities
    @test !isempty(manifest.module_bindings)

    binding = first(manifest.module_bindings)
    physics_module = CandidatePhysicsModuleV1(String(binding["module_id"]),
        String(binding["capability_id"]), String(binding["operator_id"]),
        String.(binding["state_ids"]), deepcopy(manifest.parameters))
    @test solver_capability(physics_module) == binding["capability_id"]
    @test applicability(physics_module, manifest)["status"] == "applicable"
    @test !isempty(state_layout(physics_module, manifest))

    first_result = solve_candidate_manifest_v1(manifest)
    second_result = solve_candidate_manifest_v1(manifest)
    @test first_result.result_hash == second_result.result_hash
    @test first_result.status in (:pass, :unknown)
    @test first_result.physics_hash == compiled.genome.physics_hash
    @test first_result.manifest_hash == manifest.manifest_hash
    @test length(first_result.result_hash) == 64
    @test !isempty(first_result.state_trajectory["states"])
    @test !isempty(first_result.conservation_slots)
    @test all(item -> haskey(item, "dU_dt") && haskey(item, "divergence_F") &&
        haskey(item, "source_S"), first_result.conservation_slots)
    @test !occursin("NaN", canonical_json(solver_result_envelope_to_dict_v1(first_result)))

    state = solver_state_for_v55_v1(first_result, manifest)
    transport = transport_burn_for_v55_v1(first_result, manifest)
    ledger = strict_power_ledger_v1(first_result, transport)
    @test state["solver_derived"]
    @test state["solver_output_hash"] == first_result.result_hash
    @test transport["state_solution_hash"] == first_result.result_hash
    @test transport["confinement_time_source"] ==
        "candidate_bound_state_derived_operator"
    @test all(item -> item["solver_derived"] === true, ledger["terms"])
    @test all(item -> item["source_output_hash"] in
        (state["solver_output_hash"], transport["solver_output_hash"]), ledger["terms"])
    @test ledger["status"] == "unknown_missing_solver_output_role"

    unsupported_manifest = compile_candidate_solve_manifest_v1(compiled.genome,
        compiled.module_ids; parameter_overrides = Dict(
            "particle_inventory" => NaN, "thermal_energy_j" => NaN))
    unsupported = solve_candidate_manifest_v1(unsupported_manifest)
    @test unsupported.status == :unsupported
    @test isempty(unsupported.state_trajectory)
    @test !isempty(unsupported.unsupported_reasons)

    relabeled_raw = deepcopy(compiled.genome.normalized)
    relabeled_raw["family"] = "deliberately_wrong_nonrouting_label"
    relabeled = parse_genome(relabeled_raw)
    relabeled_manifest = compile_candidate_solve_manifest_v1(relabeled,
        compiled.module_ids; discretization_levels = [16, 32])
    @test relabeled_manifest.module_bindings == manifest.module_bindings
    @test relabeled_manifest.capability_declarations == manifest.capability_declarations
    @test relabeled_manifest.initial_conditions == manifest.initial_conditions

    runtime_source = read(joinpath(root, "src", "candidate_solver_runtime_v1.jl"), String)
    @test !occursin("genome.family", runtime_source)
    for schema_name in ("candidate_solve_manifest_v1.schema.json",
            "solver_result_envelope_v1.schema.json")
        schema = JSON3.read(read(joinpath(root, "schemas", schema_name), String))
        @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    end
end
