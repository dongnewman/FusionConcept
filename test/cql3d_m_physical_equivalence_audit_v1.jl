@testset "CQL3D public versus CQL3D-m physical equivalence audit v1" begin
    path = joinpath(@__DIR__, "..", "knowledge",
        "cql3d_m_physical_equivalence_audit_v1.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    @test raw["public_commit"] == "3565fee6974deff69371321d8a053593eae1562d"
    @test raw["public_source_evidence"]["mirror_multiradius_disabled"]
    @test raw["public_source_evidence"]["mirror_multiradius_execution_stop"]
    @test raw["public_source_evidence"]["cql3d_m_transfer_declared"]
    @test raw["public_source_evidence"]["declared_transfer_scope_is_mostly_freya"]
    @test !raw["paper"]["version_identity_disclosed"]
    @test !raw["paper"]["wham_input_and_expected_output_disclosed"]
    @test "mirror_multiradius_24_flux_surfaces" in
        raw["missing_required_capability_ids"]
    @test "iterated_quasineutral_ambipolar_potential" in
        raw["missing_required_capability_ids"]
    @test !raw["equivalence_result"]["physically_equivalent_in_wham_operating_domain"]
    @test !raw["equivalence_result"]["exact_source_equivalence_verifiable"]
    @test raw["equivalence_result"]["result_status"] == "fail"
    @test !raw["gates"]["public_mainline_may_substitute_for_wham_cql3d_m"]
    @test !raw["gates"]["candidate_input_compilation_against_public_mainline_authorized"]
    @test !raw["gates"]["c2_kinetic_state_authorized"]
    @test raw["deterministic_hash"] == canonical_hash(Dict{String,Any}(
        key => value for (key, value) in raw if key != "deterministic_hash"))
end
