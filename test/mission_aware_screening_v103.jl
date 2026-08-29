using Test
using FusionConceptAI

@testset "v103 mission-aware reference and candidate rescreen" begin
    root = normpath(joinpath(@__DIR__, ".."))
    references = run_mission_aware_reference_acceptance_v103(root)
    @test references["status"] == "pass"
    @test references["reference_count"] == 2
    @test references["reference_regression_pass_count"] == 2
    @test references["old_reference_bypass_count"] == 2
    @test references["new_reference_bypass_count"] == 0
    @test references["full_qualification_pass_count"] == 0
    @test references["validation_pass_count"] == 0
    @test references["unsupported_candidate_count"] == 0
    @test references["provider_system_failure_count"] == 0
    @test references["identity_erasure_invariant"]
    @test all(row -> row["generic_whole_graph_closed"] === true,
        references["reference_rows"])
    @test all(row -> row["generic_numerical_vvuq"] == "pass",
        references["reference_rows"])
    @test all(row -> row["reference_regression_status"] == "pass",
        references["reference_rows"])
    @test all(row -> row["full_qualification_status"] ==
        "qualification_incomplete", references["reference_rows"])
    @test all(row -> row["validation_vvuq"]["validation_pass"] === false,
        references["reference_rows"])

    candidates = rescreen_v100_candidates_v103(root, references)
    @test candidates["status"] == "complete"
    @test candidates["candidate_count"] == 79
    @test candidates["physical_reject_count"] == 78
    @test candidates["qualification_incomplete_count"] == 1
    @test candidates["unsupported_candidate_count"] == 0
    @test candidates["provider_system_failure_count"] == 0
    @test candidates["whole_device_credible_count"] == 0
    @test candidates["validation_pass_count"] == 0
    @test all(row -> row["mission_reduced_gate_status"] == "pass",
        candidates["rows"])

    combined = run_v103_mission_aware_campaign(root)
    @test combined["status"] == "complete"
    @test combined["acceptance_hash"] == run_v103_mission_aware_campaign(root)[
        "acceptance_hash"]
end
