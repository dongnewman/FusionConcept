using Test
using JSON3
using FusionConceptAI

@testset "v92 blocked downstream qualification and VVUQ" begin
    root = normpath(joinpath(@__DIR__, ".."))
    realization = open(joinpath(root, "runs",
        "physical_closure_v92_formal_417_20260828",
        "realization_dossiers_v92.jsonl"), "r") do io
        for line in eachline(io)
            row = JSON3.read(line)
            row.qualification.status == "pass" && return row
        end
    end
    audit = audit_solver_installations_v92(root)
    request = compile_equilibrium_request_v92(realization)
    equilibrium = execute_equilibrium_request_v92(request, audit)
    @test equilibrium.payload["status"] == "unsupported"
    modes = compile_mode_coverage_manifest_v92(realization)
    @test length(modes.payload["modes"]) == 7
    @test modes.payload["family_or_device_label_used"] == false
    orbit = compile_blocked_orbit_result_v92(realization, equilibrium)
    stability = compile_blocked_stability_result_v92(realization, equilibrium)
    @test orbit.payload["status"] == "unsupported"
    @test orbit.payload["solver_executed"] == false
    @test stability.payload["status"] == "unsupported"
    @test all(row["status"] in ("unsupported", "not_applicable") for row in
        stability.payload["mode_coverage"])
    comparison = compile_cross_code_comparison_v92(equilibrium, orbit,
        stability)
    @test comparison["status"] == "unknown_independent_model_missing"
    @test comparison["unresolved_solver_disagreement"] == true
    vvuq = compile_validation_vvuq_v92(realization, equilibrium, orbit,
        stability)
    @test vvuq["candidate_bound_validation_vvuq"] == "unknown"
    @test vvuq["published_interval_substitution_used"] == false
    @test vvuq["code_verification"]["validation_credit"] == false
    decision = compile_promotion_decision_v92(realization, equilibrium, orbit,
        stability, comparison, vvuq)
    @test decision["computationally_credible_fusion_device_concept"] == false
    @test decision["experimentally_validated_new_fusion_device"] == false
    @test decision["first_blocker"] == "applicable_equilibrium"
    @test decision["manufactured_sentinel_or_published_interval_credit"] == false
end
