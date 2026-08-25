using Test
using JSON3
using FusionConceptAI

const MEC_ROOT = normpath(joinpath(@__DIR__, ".."))
const MEC_FREEGS = joinpath(MEC_ROOT, "examples",
    "freegs_pointcoil_wall_control_genome_v1.json")

function mec_evidence(problem, metric_id; value = 1.0, unit = nothing,
        source_kind = :candidate_solver, fidelity = 2, binding = true,
        resolution = true, source_status = :pass, limit = nothing,
        limit_verified = false)
    requirement = only(filter(item -> item.metric_id == metric_id,
        problem.requirements))
    limit_unit = limit === nothing ? "" : requirement.unit
    return compile_magnet_engineering_evidence_v1(problem;
        metric_id = metric_id, value = value,
        unit = unit === nothing ? requirement.unit : unit,
        source_kind = source_kind, source_artifact_id = "candidate_result.json",
        source_artifact_hash = repeat("a", 64),
        source_result_hash = repeat("b", 64),
        resolution_artifact_id = "candidate_resolution.json",
        resolution_artifact_hash = repeat("c", 64),
        candidate_binding_verified = binding, resolution_verified = resolution,
        fidelity = fidelity, source_result_status = source_status,
        limit_value = limit, limit_unit = limit_unit,
        limit_source_id = limit === nothing ? "" : "material_limit.json",
        limit_source_hash = limit === nothing ? "" : repeat("d", 64),
        limit_applicability_verified = limit_verified)
end

@testset "Physical-source magnet problem compilation v1" begin
    genome = load_genome(MEC_FREEGS)
    problem = compile_magnet_engineering_problem_v1(genome)
    @test length(problem.requirements) == 14
    @test !("freegs_plasma_current" in problem.magnetic_source_ids)
    @test length(problem.magnetic_source_ids) == 5
    @test length(problem.idealized_source_ids) == 4
    @test "maximum_structural_stress" in
        [item.metric_id for item in problem.requirements]
    @test all(item -> item.required_for_complete_engineering, problem.requirements)

    raw = JSON3.read(read(MEC_FREEGS, String), Dict{String,Any})
    raw["family"] = "declassified_magnetic_control"
    renamed = parse_genome(raw)
    renamed_problem = compile_magnet_engineering_problem_v1(renamed)
    @test renamed_problem.magnetic_source_ids == problem.magnetic_source_ids
    @test renamed_problem.geometry_models == problem.geometry_models
    @test [item.metric_id for item in renamed_problem.requirements] ==
        [item.metric_id for item in problem.requirements]
end

@testset "Magnet component evidence separates observation and limit v1" begin
    problem = compile_magnet_engineering_problem_v1(load_genome(MEC_FREEGS))
    inventory = mec_evidence(problem, "stored_magnetic_energy"; value = 1.8e7)
    @test inventory.observation_status == :pass
    @test inventory.c2_observation_authorized
    @test inventory.feasibility_status == :pass

    low = mec_evidence(problem, "stored_magnetic_energy";
        value = 1.8e7, fidelity = 1)
    @test low.observation_status == :pass
    @test !low.c2_observation_authorized
    @test low.feasibility_status == :unknown
    manufactured = mec_evidence(problem, "stored_magnetic_energy";
        value = 1.8e7, source_kind = :manufactured)
    @test manufactured.observation_status == :pass
    @test !manufactured.c2_observation_authorized

    peak_without_limit = mec_evidence(problem, "peak_internal_conductor_field";
        value = 6.62)
    @test peak_without_limit.observation_status == :pass
    @test peak_without_limit.c2_observation_authorized
    @test peak_without_limit.feasibility_status == :unknown
    @test "provide_applicable_limit:peak_internal_conductor_field" in
        peak_without_limit.evidence_tasks
    peak_pass = mec_evidence(problem, "peak_internal_conductor_field";
        value = 6.62, limit = 12.0, limit_verified = true)
    peak_fail = mec_evidence(problem, "peak_internal_conductor_field";
        value = 13.0, limit = 12.0, limit_verified = true)
    @test peak_pass.feasibility_status == :pass
    @test peak_fail.feasibility_status == :fail

    unbound_failure = mec_evidence(problem, "stored_magnetic_energy";
        value = 1.0, binding = false, source_status = :fail)
    @test unbound_failure.observation_status == :unknown
    @test unbound_failure.feasibility_status == :unknown
    authoritative_failure = mec_evidence(problem, "stored_magnetic_energy";
        value = 1.0, source_status = :fail)
    @test authoritative_failure.observation_status == :fail
    @test authoritative_failure.feasibility_status == :fail
end

@testset "Magnet engineering gates are complete and non-compensating v1" begin
    problem = compile_magnet_engineering_problem_v1(load_genome(MEC_FREEGS))
    partial = assess_magnet_engineering_v1(problem,
        [mec_evidence(problem, "stored_magnetic_energy"; value = 1.8e7)])
    @test partial.status == :unknown
    @test !partial.complete_magnet_engineering_authorized
    @test length(partial.feasibility_unknown_metric_ids) == 13
    partial_bundle = magnet_engineering_evidence_bundle_v1(
        load_genome(MEC_FREEGS), partial)
    @test partial_bundle.status == :unknown
    @test partial_bundle.claim_ceiling ==
        "C2_magnet_engineering_unknown_or_failed"

    failed = assess_magnet_engineering_v1(problem, [
        mec_evidence(problem, "stored_magnetic_energy"; value = 1.8e7),
        mec_evidence(problem, "peak_internal_conductor_field";
            value = 13.0, limit = 12.0, limit_verified = true)])
    @test failed.status == :fail
    @test failed.feasibility_fail_metric_ids == ["peak_internal_conductor_field"]
    @test !failed.complete_c2_authorized

    complete_evidence = MagnetEngineeringEvidenceV1[]
    for requirement in problem.requirements
        if requirement.gate_kind == :boolean_true
            push!(complete_evidence, mec_evidence(problem, requirement.metric_id;
                value = 1.0))
        elseif requirement.gate_kind == :inventory
            push!(complete_evidence, mec_evidence(problem, requirement.metric_id;
                value = 10.0))
        elseif requirement.gate_kind == :upper_limit
            push!(complete_evidence, mec_evidence(problem, requirement.metric_id;
                value = 5.0, limit = 10.0, limit_verified = true))
        else
            push!(complete_evidence, mec_evidence(problem, requirement.metric_id;
                value = 5.0, limit = 1.0, limit_verified = true))
        end
    end
    complete = assess_magnet_engineering_v1(problem, complete_evidence)
    @test complete.status == :pass
    @test complete.complete_magnet_engineering_authorized
    @test complete.complete_c2_authorized
    @test length(complete.c2_authorized_metric_ids) == 14
    @test isempty(complete.feasibility_unknown_metric_ids)
    complete_bundle = magnet_engineering_evidence_bundle_v1(
        load_genome(MEC_FREEGS), complete)
    @test complete_bundle.status == :pass
    @test complete_bundle.claim_ceiling ==
        "C2_support_complete_magnet_engineering"
    @test_throws ArgumentError assess_magnet_engineering_v1(problem,
        [complete_evidence[1], complete_evidence[1]])
end
