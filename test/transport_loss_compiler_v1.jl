using Test
using JSON3
using FusionConceptAI

const TLC_ROOT = normpath(joinpath(@__DIR__, ".."))
const TLC_FREEGS = joinpath(TLC_ROOT, "examples",
    "freegs_pointcoil_wall_control_genome_v1.json")
const TLC_PLEIADES = joinpath(TLC_ROOT, "examples",
    "pleiades_wham_isotropic_regression_genome.json")
const TLC_DESC = joinpath(TLC_ROOT, "runs",
    "stellarator_regularized_coil_force_pool16_20260811.json")

function tlc_desc_genome()
    raw = JSON3.read(read(TLC_DESC, String), Dict{String,Any})
    return parse_genome(raw["genome"])
end

function tlc_evidence(problem, metric_id; value = 1.0, unit = nothing,
        source_kind = :candidate_solver, fidelity = 2, binding = true,
        resolution = true, applicability = true, source_status = :pass)
    requirement = only(filter(item -> item.metric_id == metric_id,
        problem.requirements))
    return compile_transport_loss_evidence_v1(problem;
        metric_id = metric_id, value = value,
        unit = unit === nothing ? requirement.unit : unit,
        source_kind = source_kind,
        source_artifact_id = "candidate_transport_result.json",
        source_artifact_hash = repeat("a", 64),
        source_result_hash = repeat("b", 64),
        candidate_binding_verified = binding,
        resolution_verified = resolution,
        applicability_verified = applicability,
        fidelity = fidelity, source_result_status = source_status)
end

@testset "Topology-routed transport problem compilation v1" begin
    freegs = load_genome(TLC_FREEGS)
    pleiades = load_genome(TLC_PLEIADES)
    desc = tlc_desc_genome()
    mixed = compile_transport_loss_problem_v1(freegs)
    open = compile_transport_loss_problem_v1(pleiades)
    closed = compile_transport_loss_problem_v1(desc)

    @test mixed.has_open_field_regions && mixed.has_closed_field_regions
    @test open.has_open_field_regions && !open.has_closed_field_regions
    @test !closed.has_open_field_regions && closed.has_closed_field_regions
    @test length(mixed.requirement_ids) == 21
    @test length(open.requirement_ids) == 14
    @test length(closed.requirement_ids) == 14
    @test "parallel_particle_boundary_flux" in open.requirement_ids
    @test !("neoclassical_particle_flux" in open.requirement_ids)
    @test "neoclassical_particle_flux" in closed.requirement_ids
    @test !("parallel_particle_boundary_flux" in closed.requirement_ids)
    @test "parallel_particle_boundary_flux" in mixed.requirement_ids
    @test "neoclassical_particle_flux" in mixed.requirement_ids
    @test all(!occursin("confinement_time", id) for id in
        vcat(mixed.requirement_ids, open.requirement_ids,
            closed.requirement_ids))

    raw = JSON3.read(read(TLC_PLEIADES, String), Dict{String,Any})
    raw["family"] = "declassified_open_magnetic_control"
    relabeled = compile_transport_loss_problem_v1(parse_genome(raw))
    @test relabeled.requirement_ids == open.requirement_ids
    @test relabeled.has_open_field_regions == open.has_open_field_regions
    @test relabeled.has_closed_field_regions == open.has_closed_field_regions
    @test relabeled.problem_hash != open.problem_hash
end

@testset "Transport component evidence authority v1" begin
    problem = compile_transport_loss_problem_v1(load_genome(TLC_PLEIADES))
    metric = "adiabatic_prompt_loss_fraction"
    authoritative = tlc_evidence(problem, metric; value = 0.04)
    @test authoritative.status == :pass
    @test authoritative.c2_component_authorized

    low = tlc_evidence(problem, metric; value = 0.04, fidelity = 1)
    @test low.status == :pass
    @test !low.c2_component_authorized
    @test "raise_transport_fidelity_to_c2" in low.evidence_tasks
    proxy = tlc_evidence(problem, metric; value = 0.04,
        source_kind = :proxy)
    @test proxy.status == :pass
    @test !proxy.c2_component_authorized
    unbound_failure = tlc_evidence(problem, metric; value = 0.04,
        binding = false, source_status = :fail)
    @test unbound_failure.status == :unknown
    @test !unbound_failure.c2_component_authorized
    authoritative_failure = tlc_evidence(problem, metric; value = 0.04,
        source_status = :fail)
    @test authoritative_failure.status == :fail
    @test !authoritative_failure.c2_component_authorized
    wrong_unit = tlc_evidence(problem, metric; value = 0.04, unit = "s^-1")
    @test wrong_unit.status == :unknown
    @test "convert_transport_unit:1" in wrong_unit.evidence_tasks
end

@testset "Transport completeness is non-compensating v1" begin
    genome = load_genome(TLC_PLEIADES)
    problem = compile_transport_loss_problem_v1(genome)
    prompt = tlc_evidence(problem, "adiabatic_prompt_loss_fraction";
        value = 0.04)
    partial = assess_transport_loss_v1(problem, [prompt])
    @test partial.status == :unknown
    @test !partial.complete_transport_c2_authorized
    @test partial.c2_authorized_metric_ids ==
        ["adiabatic_prompt_loss_fraction"]
    @test length(partial.unknown_metric_ids) == 13
    bundle = transport_loss_evidence_bundle_v1(genome, partial)
    @test bundle.status == :unknown
    @test bundle.claim_ceiling == "C2_transport_and_loss_unknown_or_failed"

    low = tlc_evidence(problem, "adiabatic_prompt_loss_fraction";
        value = 0.04, fidelity = 1)
    low_assessment = assess_transport_loss_v1(problem, [low])
    @test "adiabatic_prompt_loss_fraction" in
        low_assessment.unknown_metric_ids
    @test "raise_transport_fidelity_to_c2" in low_assessment.evidence_tasks

    failed = assess_transport_loss_v1(problem, [tlc_evidence(problem,
        "adiabatic_prompt_loss_fraction"; value = 0.04,
        source_status = :fail)])
    @test failed.status == :fail
    @test failed.failed_metric_ids == ["adiabatic_prompt_loss_fraction"]

    complete_evidence = TransportLossEvidenceV1[
        tlc_evidence(problem, requirement.metric_id; value = 1.0)
        for requirement in problem.requirements]
    complete = assess_transport_loss_v1(problem, complete_evidence)
    @test complete.status == :pass
    @test complete.complete_transport_c2_authorized
    @test isempty(complete.unknown_metric_ids)
    complete_bundle = transport_loss_evidence_bundle_v1(genome, complete)
    @test complete_bundle.status == :pass
    @test complete_bundle.claim_ceiling ==
        "C2_support_complete_transport_and_loss"
    @test_throws ArgumentError assess_transport_loss_v1(problem,
        [complete_evidence[1], complete_evidence[1]])
end
