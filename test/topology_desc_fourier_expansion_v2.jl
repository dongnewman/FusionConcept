@testset "family-independent DESC Fourier problem compiler v2" begin
    root = normpath(joinpath(@__DIR__, ".."))
    parent = only(filter(item -> item.design_id == "w7x_mechanism_seed",
        load_genomes(joinpath(root, "examples", "seed_devices.json"))))
    genome = build_stellarator_fourier_genome(parent)
    contract = compile_topology_desc_fourier_problem_v2(genome)
    @test contract["status"] == "ready"
    @test contract["family_label_used"] === false
    @test length(contract["solver_problem_hash"]) == 64
    @test contract["solver_problem_hash"] == canonical_hash(
        contract["solver_input"])
    @test contract["solver_input"]["boundary"]["field_periods"] == 3

    raw = deepcopy(genome.normalized)
    raw["family"] = "diagnostic_scrambled_family_label"
    scrambled = parse_genome(raw)
    scrambled_contract = compile_topology_desc_fourier_problem_v2(scrambled)
    @test scrambled.physics_hash != genome.physics_hash
    @test scrambled_contract["status"] == "ready"
    @test scrambled_contract["solver_problem_hash"] ==
        contract["solver_problem_hash"]
    @test scrambled_contract["solver_input"] == contract["solver_input"]
    @test !evaluator_applicability(StellaratorDESCFourierV1(), scrambled)[1]

    wrong = deepcopy(genome.normalized)
    wrong["topology"]["field_line_class"] = "open_linear"
    rejected = compile_topology_desc_fourier_problem_v2(parse_genome(wrong))
    @test rejected["status"] == "not_applicable"
    @test rejected["solver_problem_hash"] === nothing
    @test "field-line class" in rejected["mismatches"]
end

@testset "family-independent DESC sampled stability acquisition v2" begin
    root = normpath(joinpath(@__DIR__, ".."))
    parent = only(filter(item -> item.design_id == "w7x_mechanism_seed",
        load_genomes(joinpath(root, "examples", "seed_devices.json"))))
    genome = build_stellarator_fourier_genome(parent)
    contract = compile_topology_desc_stability_problem_v2(genome)
    @test contract["status"] == "ready"
    @test contract["family_label_used"] === false
    @test length(contract["solver_problem_hash"]) == 64
    @test contract["solver_input"]["physics_hash"] ==
        contract["solver_problem_hash"]
    raw_genome = deepcopy(genome.normalized)
    raw_genome["family"] = "diagnostic_scrambled_family_label"
    scrambled = compile_topology_desc_stability_problem_v2(
        parse_genome(raw_genome))
    @test scrambled["status"] == "ready"
    @test scrambled["solver_problem_hash"] ==
        contract["solver_problem_hash"]
    @test scrambled["solver_input"] == contract["solver_input"]

    path = joinpath(root, "runs",
        "topology_desc_stability_acquisition_v2_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    search = raw["search"]
    gates = raw["gates"]
    @test search["equilibrium_pass_pool_count"] == 14
    @test search["selected_count"] == 4
    @test search["completed_count"] == 4
    @test search["sampled_favorable_count"] == 1
    @test search["sampled_stability_narrow_c2_count"] == 1
    @test search["family_scramble_invariant_count"] == 4
    @test search["unique_stability_problem_hash_count"] == 4
    @test search["complete_c2_evidence_authorized_count"] == 0
    @test gates["all_selected_executed"]
    @test gates["all_stability_problems_unique"]
    @test gates["all_family_scramble_invariant"]
    @test gates["medium_stability_evidence_acquired"]
    @test gates["medium_to_fine_audit_complete"]
    @test !gates["all_mode_stability_established"]
    @test !gates["complete_c2_evidence_authorized"]
    @test !gates["promotion_authorized"]

    archive_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(archive_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(archive_path)]
    @test sort(Int[item["pool_index"] for item in records]) == [1, 54, 56, 61]
    @test all(item["status"] == "pass" for item in records)
    @test all(item["family_scramble_invariant"] === true for item in records)
    favorable = only(filter(item ->
        item["sampled_local_ideal_mhd_favorable"] === true, records))
    @test favorable["pool_index"] == 56
    @test favorable["medium_to_fine_audit_status"] == "passed"
    @test favorable["sampled_stability_narrow_c2_evidence_authorized"]
    unfavorable = filter(item ->
        item["sampled_local_ideal_mhd_favorable"] === false, records)
    @test length(unfavorable) == 3
    @test all(item["result"]["minimum_mercier_D_normalized"] < 0.0
        for item in unfavorable)
    @test all(item["result"]["maximum_infinite_n_ballooning_lambda"] < 0.0
        for item in records)

    audit = JSON3.read(read(joinpath(root, "runs",
        "topology_desc_stability_pool56_medium_fine_audit_v2_20260816.json"),
        String), Dict{String,Any})
    @test audit["all_passed"]
    @test audit["target"]["physics_hash"] ==
        favorable["stability_solver_problem_hash"]
    @test audit["comparisons"]["mercier_minimum_fine_normalized"] > 0.0
    @test audit["comparisons"]["ballooning_maximum_fine"] < 0.0
    @test !audit["interpretation"]["all_mode_plasma_stability_established"]
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end

@testset "topology DESC Fourier pool64 expansion artifact v2" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs",
        "topology_desc_fourier_expansion_pool64_v2_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    search = raw["search"]
    gates = raw["gates"]
    @test search["proposal_count"] == 64
    @test search["selected_count"] == 16
    @test search["unique_candidate_physics_hash_count"] == 16
    @test search["unique_solver_problem_hash_count"] == 16
    @test search["accepted_equilibrium_count"] == 14
    @test search["route_c1_evidence_authorized_count"] == 14
    @test search["family_scramble_invariant_count"] == 16
    @test search["complete_c2_evidence_authorized_count"] == 0
    @test search["promotion_authorized_count"] == 0
    @test gates["all_selected_candidates_executed"]
    @test gates["all_solver_problems_unique"]
    @test gates["all_family_scramble_invariant"]
    @test gates["at_least_one_route_c1"]
    @test !gates["complete_c2_evidence_authorized"]
    @test !gates["performance_search_authorized"]
    @test !gates["promotion_authorized"]
    @test raw["ranges"]["force_residual_normalized_magnetic"]["max"] <= 0.01

    record_path = joinpath(root,
        split(raw["candidate_archive"]["jsonl"], '/')...)
    @test bytes2hex(sha256(read(record_path))) ==
        raw["candidate_archive"]["sha256"]
    records = [JSON3.read(line, Dict{String,Any})
        for line in eachline(record_path)]
    @test length(records) == 16
    @test length(unique(String(item["physical_result_hash"])
        for item in records)) == 16
    @test all(item["family_label_used"] === false for item in records)
    @test all(item["family_scramble_invariant"] === true for item in records)
    accepted = filter(item -> item["status"] == "pass", records)
    failed = filter(item -> item["status"] == "fail", records)
    @test length(accepted) == 14
    @test length(failed) == 2
    @test all(item["result"]["equation_residual_accepted"] === true
        for item in accepted)
    @test all(item["result"]["force_residual_normalized_magnetic"] <= 0.01
        for item in accepted)
    @test all(item["result"]["equation_residual_accepted"] === false
        for item in failed)
    @test all(item["result"]["fixed_constraints_accepted"] === true &&
        item["result"]["jacobian_accepted"] === true for item in failed)
    @test all(item["result"]["force_residual_normalized_magnetic"] > 0.01
        for item in failed)
    @test sort(Int[item["pool_index"] for item in failed]) == [39, 63]

    shard_counts = Int[]
    shard_accepted = Int[]
    for index in 1:4
        shard = JSON3.read(read(joinpath(root, "runs",
            "topology_desc_fourier_expansion_pool64_shard$(index)_raw_v2.json"),
            String), Dict{String,Any})
        push!(shard_counts, Int(shard["candidate_count"]))
        push!(shard_accepted, Int(shard["accepted_equilibrium_count"]))
    end
    @test shard_counts == [4, 4, 4, 4]
    @test shard_accepted == [4, 4, 3, 3]
    @test all(bytes2hex(sha256(read(joinpath(root,
        split(item["artifact_id"], '/')...)))) == item["artifact_hash"]
        for item in raw["source_artifacts"])
    core = Dict{String,Any}(key => value for (key, value) in raw if
        key != "deterministic_hash")
    @test raw["deterministic_hash"] == canonical_hash(core)
end
