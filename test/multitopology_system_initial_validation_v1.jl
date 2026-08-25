@testset "multi-topology system initial validation v1" begin
    path = joinpath(@__DIR__, "..", "runs",
        "multitopology_system_initial_validation_v1_20260816.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    chain = raw["upstream_kinetic_chain"]
    search = raw["search_execution"]
    outcome = raw["scientific_outcome"]
    @test chain["public_cql3d_numerical_regression_passed"]
    @test !chain["public_cql3d_physically_equivalent_to_wham_cql3d_m"]
    @test chain["candidate_geometry_source_618_bin_binding_passed"]
    @test chain["reduced_two_species_distribution_ambipolar_end_loss_passed"]
    @test !chain["kinetic_c2_authorized"]
    @test chain["numeric_proxy_balance_closed"]
    @test !chain["coupled_balance_c2_authorized"]
    @test search["infrastructure_validation_passed"]
    @test search["candidate_count"] == 10_000
    @test search["unique_physics_hash_count"] == 10_000
    @test search["topology_count"] == 1_000
    @test search["topology_graph_error_count"] == 0
    @test outcome["fidelity0_positive_net_proxy_count"] == 42
    @test outcome["complete_five_gate_count"] == 0
    @test outcome["coverage_complete_count"] == 0
    @test outcome["medium_fidelity_candidate_count"] == 0
    @test outcome["c2_authorized_new_candidate_count"] == 0
    @test outcome["credible_new_device_count"] == 0
    @test !outcome["positive_proxy_is_feasibility_evidence"]
    @test raw["failure_directed_queue"]["highest_gate_candidate_count"] == 698
    @test raw["gates"]["large_multitopology_infrastructure_initial_validation_complete"]
    @test !raw["gates"]["large_multitopology_scientific_validation_complete"]
    root = normpath(joinpath(@__DIR__, ".."))
    @test all(bytes2hex(sha256(read(joinpath(root,
        replace(item["artifact_id"], '/' => Base.Filesystem.path_separator))))) ==
        item["artifact_hash"] for item in raw["source_artifacts"])
    @test raw["deterministic_hash"] == canonical_hash(Dict{String,Any}(
        key => value for (key, value) in raw if key != "deterministic_hash"))
end
