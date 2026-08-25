using Test
using JSON3
using FusionConceptAI

const CPC2_ROOT = normpath(joinpath(@__DIR__, ".."))

function cpc2_executable(genome_name, executable_name; family = nothing)
    genome_path = joinpath(CPC2_ROOT, "examples", genome_name)
    executable_path = joinpath(CPC2_ROOT, "examples", executable_name)
    family === nothing && return load_executable_genome_v1(genome_path,
        executable_path)
    genome_raw = JSON3.read(read(genome_path, String), Dict{String,Any})
    genome_raw["family"] = family
    genome = parse_genome(genome_raw)
    executable_raw = JSON3.read(read(executable_path, String), Dict{String,Any})
    executable_raw["base_genome_physics_hash"] = genome.physics_hash
    delete!(executable_raw, "document_hash")
    return parse_executable_genome_v1(genome, executable_raw)
end

function cpc2_problem(kind; family = nothing)
    kind == :freegs && return compile_conservation_problem_v2(cpc2_executable(
        "freegs_pointcoil_wall_control_genome_v1.json",
        "freegs_pointcoil_wall_control_executable_physics_v1.json";
        family = family))
    kind == :desc && return compile_conservation_problem_v2(cpc2_executable(
        "desc_w7x_regression_genome.json", "desc_w7x_executable_physics_v1.json";
        family = family))
    kind == :pleiades && return compile_conservation_problem_v2(cpc2_executable(
        "pleiades_wham_isotropic_regression_genome.json",
        "pleiades_wham_executable_physics_v1.json"; family = family))
    error("unknown fixture")
end

function cpc2_evidence(problem; kind = :candidate_solver, fidelity = 2,
        resolution = true, change_id = nothing, change_value = 0.0)
    result = ConservationTermEvidenceV2[]
    for balance in problem.balances, slot in balance.required_slot_ids
        id = join((balance.key.conserved_quantity, balance.key.species,
            balance.key.domain_id, slot), "|")
        value = id == change_id ? change_value : 0.0
        push!(result, compile_conservation_term_evidence_v2(problem,
            balance.key, slot; value = value, source_kind = kind,
            source_artifact_id = "candidate_conservation.json",
            source_artifact_hash = repeat("a", 64),
            source_result_hash = repeat("b", 64),
            candidate_binding_verified = kind != :manufactured,
            resolution_verified = resolution, fidelity = fidelity))
    end
    return result
end

@testset "Executable IR conservation problem compiler v2" begin
    freegs = cpc2_problem(:freegs)
    desc = cpc2_problem(:desc)
    pleiades = cpc2_problem(:pleiades)
    @test length(freegs.balances) == 36
    @test length(desc.balances) == 36
    @test length(pleiades.balances) == 36
    @test sum(length(item.required_slot_ids) for item in freegs.balances) == 150
    @test sum(length(item.required_slot_ids) for item in desc.balances) == 158
    @test sum(length(item.required_slot_ids) for item in pleiades.balances) == 158
    @test "mass" in freegs.required_quantities
    @test ConservationBalanceKeyV1("mass", "ion", "core", "kg s^-1").unit ==
        "kg s^-1"
    @test any(contains("invalid_conserved_quantity:particles"),
        pleiades.compiler_issues)
    @test all(item.status != :pass for item in pleiades.ir_term_audit)
    @test any(item -> "species_resolved_terms_missing" in item.structural_gap_ids,
        freegs.balances)
    @test freegs.claim_ceiling ==
        "C0_conservation_problem_compiled_no_numeric_credit"

    renamed = cpc2_problem(:freegs; family = "declassified_control_label")
    @test renamed.genome_physics_hash != freegs.genome_physics_hash
    @test [item.key for item in renamed.balances] ==
        [item.key for item in freegs.balances]
    @test [item.required_slot_ids for item in renamed.balances] ==
        [item.required_slot_ids for item in freegs.balances]
end

@testset "Candidate conservation slots fail closed v2" begin
    problem = cpc2_problem(:freegs)
    empty = compile_candidate_conservation_v2(problem,
        ConservationTermEvidenceV2[])
    @test empty.status == :unknown
    @test empty.authoritative_slot_count == 0
    @test empty.required_slot_count == 150
    @test !empty.c2_support_authorized

    manufactured = compile_candidate_conservation_v2(problem,
        cpc2_evidence(problem; kind = :manufactured))
    @test manufactured.status == :unknown
    @test manufactured.authoritative_slot_count == 0
    @test !manufactured.c2_support_authorized

    low = cpc2_evidence(problem)
    first_balance = first(problem.balances)
    first_slot = first(first_balance.required_slot_ids)
    low[1] = compile_conservation_term_evidence_v2(problem,
        first_balance.key, first_slot; value = 0.0,
        source_kind = :candidate_solver,
        source_artifact_id = "candidate_conservation.json",
        source_artifact_hash = repeat("a", 64),
        source_result_hash = repeat("b", 64),
        candidate_binding_verified = true, resolution_verified = true, fidelity = 1)
    low_result = compile_candidate_conservation_v2(problem, low)
    @test low_result.status == :unknown
    @test low_result.authoritative_slot_count == 149
    @test !low_result.c2_support_authorized

    desc = cpc2_problem(:desc)
    desc_balance = first(desc.balances)
    foreign = compile_conservation_term_evidence_v2(desc, desc_balance.key,
        first(desc_balance.required_slot_ids); value = 0.0,
        source_kind = :candidate_solver, source_artifact_id = "desc.json",
        source_artifact_hash = repeat("c", 64),
        source_result_hash = repeat("d", 64),
        candidate_binding_verified = true, resolution_verified = true, fidelity = 2)
    @test_throws ArgumentError compile_candidate_conservation_v2(problem, [foreign])
end

@testset "Complete numerical conservation contract v2" begin
    problem = cpc2_problem(:freegs)
    complete = compile_candidate_conservation_v2(problem, cpc2_evidence(problem))
    @test complete.status == :pass
    @test complete.authoritative_slot_count == complete.required_slot_count == 150
    @test complete.c2_support_authorized
    @test all(values(complete.ledger.checks))
    @test conservation_ledger_evidence_bundle_v1(complete.ledger).status == :pass

    source_balance = only(filter(item -> item.key.conserved_quantity == "particle" &&
        item.key.species == "electron" &&
        item.key.domain_id == "freegs_wall_control_core", problem.balances))
    source_id = join((source_balance.key.conserved_quantity,
        source_balance.key.species, source_balance.key.domain_id,
        "volumetric_source"), "|")
    failed = compile_candidate_conservation_v2(problem,
        cpc2_evidence(problem; change_id = source_id, change_value = 1.0e20))
    @test failed.status == :fail
    @test !failed.c2_support_authorized
    @test any(item -> item.key == source_balance.key && item.status == :fail,
        failed.ledger.balances)
end
