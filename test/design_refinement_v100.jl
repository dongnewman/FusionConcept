using Test
using JSON3
using FusionConceptAI

@testset "v100 candidate-bound operating and radial-build refinement" begin
    root = normpath(joinpath(@__DIR__, ".."))
    parent = open(joinpath(root, "runs",
        "v98_end_to_end_device_campaign_1048576_20260829",
        "computational_candidates.jsonl"), "r") do io
        FusionConceptAI._v93_plain(JSON3.read(readline(io)))
    end
    result = refine_candidate_operating_points_v100(parent;
        variant_count = 32, retain_count = 2)
    @test result["unsupported_candidate_count"] == 0
    @test result["identity_fields_used_for_routing"] === false
    @test result["retained_count"] <= 2
    @test sum(values(result["failure_histogram"])) > 0
    for item in result["retained"]
        @test item["physics_solve"]["status"] == "pass"
        @test item["engineering_prefilter"]["status"] == "pass"
        @test item["basis_direct_metric_credit"] === false
        @test item["unsupported_candidate_classification_used"] === false
    end

    retained = open(joinpath(root, "runs",
        "v100_candidate_bound_design_refinement_20260829",
        "computational_candidates.jsonl"), "r") do io
        FusionConceptAI._v93_plain(JSON3.read(readline(io)))
    end
    point = retained["operating_point"]
    physics = retained["physics_solve"]
    layout = retained["magnet_layout"]
    baseline = engineering_prefilter_v100(point, physics, layout)
    @test baseline["status"] == "pass"

    labeled_point = merge(point, Dict("candidate_id" => "erased-id",
        "candidate_hash" => repeat("f", 64), "device_family" => "permuted-label"))
    labeled_physics = merge(physics, Dict("candidate_id" => "another-id"))
    labeled_layout = merge(layout, Dict("device_family" => "not-a-routing-axis"))
    @test engineering_prefilter_v100(labeled_point, labeled_physics,
        labeled_layout)["result_hash"] == baseline["result_hash"]

    permuted_point = Dict(reverse(collect(point)))
    permuted_physics = Dict(reverse(collect(physics)))
    permuted_layout = Dict(reverse(collect(layout)))
    @test engineering_prefilter_v100(permuted_point, permuted_physics,
        permuted_layout)["result_hash"] == baseline["result_hash"]

    incomplete_layout = deepcopy(layout)
    delete!(incomplete_layout, "winding_pack_thickness_m")
    @test_throws KeyError engineering_prefilter_v100(point, physics, incomplete_layout)
end
