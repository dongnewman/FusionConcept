@testset "Phase-locked reciprocal mirror ring stage closure v1" begin
    parent = load_genomes(joinpath(@__DIR__, "..", "examples", "seed_devices.json"))[1]
    spec = default_phase_locked_mirror_ring_spec_v1()
    genome = build_phase_locked_mirror_ring_genome_v1(parent, spec)
    @test validate_genome(genome).valid
    @test genome.family == "phase_locked_reciprocal_mirror_ring"
    @test genome.topology.field_line_class == "mixed"
    @test length(genome.plasma_regions) == spec.cell_count + 1
    @test count(connection -> connection.kind == "phase_gated_open_field_handoff",
        genome.flux_connections) == spec.cell_count

    extension_registry = FamilyExtensionRegistry()
    register_extension!(extension_registry,
        phase_locked_mirror_ring_family_extension_v1())
    @test validate_family(extension_registry, genome).valid

    compiled = compile_physics_problem_v2(genome)
    @test compiled.topology.closure_class == :mixed
    geometry = compile_mechanism_native_geometry_v1(genome)
    @test geometry.geometry_input_complete
    @test geometry.family_scramble_invariant
    @test !geometry.c1_evidence_authorized

    evaluation = evaluate_phase_locked_mirror_ring_stage_v1(genome, spec)
    @test evaluation["interface_contract_id"] ==
        "fusion_stage_control_interface_v1"
    @test evaluation["model"]["empirical_family_scaling_used"] == false
    @test evaluation["claim_ceiling"] == "computational_stage_closure_only"
    @test evaluation["energy_ledger_MW"]["net_electric_proxy"] < 0
    mismatched = PhaseLockedMirrorRingSpecV1(12, 5.0, 0.45, 4.5, 3.5,
        12.0, 0.025, 0.999990, 0.70, 0.35, 36_000.0)
    @test_throws ArgumentError evaluate_phase_locked_mirror_ring_stage_v1(
        genome, mismatched)

    search = search_phase_locked_mirror_ring_stage_v1(parent)
    @test search["candidate_count"] == 18
    @test search["conditional_pass_count"] > 0
    @test search["selected"]["evaluation"]["stage_status"] == "conditional_pass"

    iter_control = evaluate_iter_stage_control_v1(parent)
    @test iter_control["stage_status"] == "control_pass"
    @test iter_control["energy_ledger_MW"]["net_electric"] === nothing

    c2w = build_compact_toroid_genome(parent,
        CompactToroidBuildSpec("field_reversed_configuration",
            "beam_driven_fast_ion"))
    c2w_control = evaluate_c2w_stage_control_v1(c2w)
    @test c2w_control["stage_status"] == "control_pass"
    @test !c2w_control["published_anchor"]["duration_is_energy_confinement_time"]
    @test c2w_control["energy_ledger_MW"]["net_electric"] === nothing
end
