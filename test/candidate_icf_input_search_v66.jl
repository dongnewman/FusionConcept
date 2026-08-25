@testset "Candidate ICF input-ready grammar and search v66" begin
    seeds = load_genomes(joinpath(@__DIR__, "..", "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    candidate = evaluate_icf_input_ready_candidate_v66(context, 180)
    genome = candidate.prescreen.compiled.genome
    audit = icf_input_ready_contract_audit_v66(genome)
    @test audit["time_semantics_status"] == "pass"
    @test audit["pulsed_rhd_status"] == "unknown"
    @test isempty(audit["declaration_conflicts"])
    @test Set(audit["blocking_missing_inputs"]) ==
        Set(["equation_of_state", "multigroup_opacity"])
    time = genome.normalized["time_integration_contract_v2"]
    @test time["shot_repetition_rate_hz"] == genome.normalized[
        "compression_systems"][1]["parameters"]["repetition_rate"]["value"]
    @test time["pulse_active_fraction"] ≈
        time["active_phase_duration_s"] * time["shot_repetition_rate_hz"]
    @test time["plant_availability_factor"] != time["pulse_active_fraction"]
    regional = genome.normalized["regional_solver_contract_v1"]["region_records"]
    volumes = Dict(item["region_id"] => item["volume_m3"] for item in regional)
    @test volumes["pulsed_chamber_region"] > 1000.0
    @test volumes["fuel_capsule"] < 1.0e-6
    bundle = compile_candidate_solver_judgment_input_v66(context, 180;
        discretization_levels = [32, 64])
    judgment = evaluate_uniform_judgment_v66(bundle["judgment_input"])
    gates = FusionConceptAI._v66_producer_gate(bundle, judgment)
    @test all(==("pass"), values(gates))
    @test bundle["region_solve_result"].status == :pass
    @test bundle["time_trajectory"]["complete"] === true
    @test bundle["pulsed_rhd_manifest"]["status"] == "unknown"
    @test bundle["stage8_external_execution_eligible"] === false
    @test isempty(select_stage8_ready_queue_v66(Dict(
        "bundles" => [bundle], "judgments" => [judgment])))
    @test judgment["chain_id"] == "uniform_fusion_judgment_chain_v66"
    @test judgment["promotion_authorized"] === false

    non_icf_base = evaluate_plant_ready_candidate_v64(context, 3842)
    non_icf = evaluate_icf_input_ready_candidate_v66(context, 3842)
    @test non_icf.prescreen.compiled.genome.physics_hash ==
        non_icf_base.prescreen.compiled.genome.physics_hash
    @test icf_input_ready_contract_audit_v66(
        non_icf.prescreen.compiled.genome)["pulsed_rhd_status"] == "not_applicable"

    conflicting_base = evaluate_plant_ready_candidate_v64(context, 4049)
    conflicting = evaluate_icf_input_ready_candidate_v66(context, 4049)
    conflicting_genome = conflicting.prescreen.compiled.genome
    conflict = conflicting_genome.normalized["time_semantics_conflict_v1"]
    @test conflict["conflict_code"] == "active_phase_exceeds_declared_cycle"
    @test conflict["implied_pulse_active_fraction"] > 1.0
    @test !haskey(conflicting_genome.normalized, "time_integration_contract_v2")
    @test !haskey(conflicting_genome.normalized, "pulsed_rhd_manifest_v1")
    @test conflicting_genome.physics_hash !=
        conflicting_base.prescreen.compiled.genome.physics_hash
end
