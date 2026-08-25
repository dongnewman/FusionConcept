using Test
using JSON3
using FusionConceptAI

const CPB_ROOT = normpath(joinpath(@__DIR__, ".."))
const CPB_FREEGS = joinpath(CPB_ROOT, "examples",
    "freegs_pointcoil_wall_control_genome_v1.json")
const CPB_PLEIADES = joinpath(CPB_ROOT, "examples",
    "pleiades_wham_isotropic_regression_genome.json")
const CPB_DESC = joinpath(CPB_ROOT, "examples", "desc_w7x_regression_genome.json")
const CPB_HASH = repeat("a", 64)

function cpb_evidence(problem, term; value = 0.0,
        source_kind = :candidate_solver, source_status = :pass,
        binding = true, resolution = true, applicability = true, fidelity = 2)
    return compile_coupled_plasma_balance_term_evidence_v1(problem;
        term_id = term.term_id, value = value, unit = term.unit,
        source_kind = source_kind, source_artifact_id = "runs/candidate.json",
        source_artifact_hash = CPB_HASH, source_result_hash = CPB_HASH,
        candidate_binding_verified = binding, resolution_verified = resolution,
        applicability_verified = applicability, fidelity = fidelity,
        source_result_status = source_status)
end

@testset "Topology compiles particle and power residuals without family routing v1" begin
    freegs = compile_coupled_plasma_balance_problem_v1(load_genome(CPB_FREEGS))
    pleiades = compile_coupled_plasma_balance_problem_v1(load_genome(CPB_PLEIADES))
    desc = compile_coupled_plasma_balance_problem_v1(load_genome(CPB_DESC))
    @test (length(freegs.equations), length(freegs.terms)) == (3, 19)
    @test (length(pleiades.equations), length(pleiades.terms)) == (3, 21)
    @test (length(desc.equations), length(desc.terms)) == (3, 18)
    @test freegs.has_open_field_regions && pleiades.has_open_field_regions
    @test !desc.has_open_field_regions && desc.has_closed_field_regions
    @test any(item -> item.mechanism_class == :parallel_energy_boundary_flux,
        pleiades.terms)
    @test !any(item -> item.mechanism_class == :parallel_energy_boundary_flux,
        desc.terms)
    @test any(item -> item.mechanism_class == :charged_fusion_product_deposition,
        pleiades.terms)
    @test !any(item -> item.mechanism_class == :charged_fusion_product_deposition,
        freegs.terms)
    @test all(item -> !occursin("confinement_time", item.term_id),
        vcat(freegs.terms, pleiades.terms, desc.terms))

    raw = JSON3.read(read(CPB_PLEIADES, String), Dict{String,Any})
    raw["family"] = "arbitrary_unseen_family_label"
    relabeled = compile_coupled_plasma_balance_problem_v1(parse_genome(raw))
    @test coupled_plasma_balance_equation_to_dict_v1.(relabeled.equations) ==
        coupled_plasma_balance_equation_to_dict_v1.(pleiades.equations)
    @test coupled_plasma_balance_term_to_dict_v1.(relabeled.terms) ==
        coupled_plasma_balance_term_to_dict_v1.(pleiades.terms)
    @test relabeled.has_open_field_regions == pleiades.has_open_field_regions
end

@testset "Evidence authority and exact rate contracts fail closed v1" begin
    problem = compile_coupled_plasma_balance_problem_v1(load_genome(CPB_PLEIADES))
    term = first(problem.terms)
    valid = cpb_evidence(problem, term)
    @test valid.c2_term_authorized
    @test !cpb_evidence(problem, term; source_kind = :proxy).c2_term_authorized
    @test !cpb_evidence(problem, term; binding = false).c2_term_authorized
    @test !cpb_evidence(problem, term; resolution = false).c2_term_authorized
    @test !cpb_evidence(problem, term; applicability = false).c2_term_authorized
    @test !cpb_evidence(problem, term; fidelity = 1).c2_term_authorized
    @test !cpb_evidence(problem, term; value = nothing).c2_term_authorized
    missing_provenance = compile_coupled_plasma_balance_term_evidence_v1(problem;
        term_id = term.term_id, value = 0.0, unit = term.unit,
        source_kind = :candidate_solver, source_artifact_id = "",
        source_artifact_hash = "", source_result_hash = "",
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 2,
        source_result_status = :pass)
    @test !missing_provenance.c2_term_authorized
    @test length(missing_provenance.evidence_tasks) == 3
    @test_throws ArgumentError compile_coupled_plasma_balance_term_evidence_v1(
        problem; term_id = term.term_id, value = 0.0, unit = "W",
        source_kind = :candidate_solver, source_artifact_id = "x",
        source_artifact_hash = CPB_HASH, source_result_hash = CPB_HASH,
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 2,
        source_result_status = :pass)
    loss = first(filter(item -> item.side == :loss, problem.terms))
    @test_throws ArgumentError cpb_evidence(problem, loss; value = -1.0)
    @test_throws ArgumentError compile_coupled_plasma_balance_term_evidence_v1(
        problem; term_id = "not_compiled", value = 0.0, unit = "W",
        source_kind = :candidate_solver, source_artifact_id = "x",
        source_artifact_hash = CPB_HASH, source_result_hash = CPB_HASH,
        candidate_binding_verified = true, resolution_verified = true,
        applicability_verified = true, fidelity = 2,
        source_result_status = :pass)
end

@testset "Complete residuals pass, incomplete stays unknown, imbalance fails v1" begin
    problem = compile_coupled_plasma_balance_problem_v1(load_genome(CPB_PLEIADES))
    complete = [cpb_evidence(problem, term) for term in problem.terms]
    passing = assess_coupled_plasma_balance_v1(problem, complete)
    @test passing.status == :pass
    @test passing.complete_c2_balance_authorized
    @test !passing.promotion_authorized
    @test length(passing.passed_equation_ids) == length(problem.equations)
    @test all(value -> value == 0.0, values(passing.equation_residuals))

    partial = assess_coupled_plasma_balance_v1(problem, complete[1:end-1])
    @test partial.status == :unknown
    @test !partial.complete_c2_balance_authorized
    @test length(partial.unknown_equation_ids) == 1

    manufactured = assess_coupled_plasma_balance_v1(problem,
        [cpb_evidence(problem, term; source_kind = :manufactured)
            for term in problem.terms])
    @test manufactured.status == :unknown
    @test manufactured.c2_authorized_term_count == 0

    heating_index = findfirst(item ->
        item.mechanism_class == :external_heating_deposition, problem.terms)
    imbalanced = copy(complete)
    imbalanced[heating_index] = cpb_evidence(problem,
        problem.terms[heating_index]; value = 10.0)
    failed = assess_coupled_plasma_balance_v1(problem, imbalanced)
    @test failed.status == :fail
    @test only(failed.failed_equation_ids) ==
        problem.terms[heating_index].equation_id
    @test failed.equation_relative_residuals[
        problem.terms[heating_index].equation_id] == 1.0

    failure = cpb_evidence(problem, first(problem.terms); value = nothing,
        source_status = :fail)
    explicit_failure = assess_coupled_plasma_balance_v1(problem, [failure])
    @test explicit_failure.status == :fail
    @test !isempty(explicit_failure.failed_equation_ids)
    @test_throws ArgumentError assess_coupled_plasma_balance_v1(problem,
        [complete[1], complete[1]])
end
