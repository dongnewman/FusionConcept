using Test
using FusionConceptAI
using JSON3

@testset "v110 material-closed candidate frontier" begin
    root = normpath(joinpath(@__DIR__, ".."))
    path = joinpath(root, "runs", "v100_candidate_bound_design_refinement_expanded_20260829",
        "computational_candidates.jsonl")
    candidates = [FusionConceptAI._v93_plain(JSON3.read(line)) for line in readlines(path)
        if !isempty(strip(line))]
    prior = FusionConceptAI._v93_plain(JSON3.read(read(joinpath(root, "runs",
        "v100_full_device_qualification_20260829", "acceptance.json"), String)))
    prior_hashes = Set(String(row["candidate_result_hash"]) for row in prior["rows"])
    result, selected = select_material_closed_frontier_v110(candidates;
        prior_result_hashes = prior_hashes, retain_count = 40)
    @test result["input_candidate_count"] == 319
    @test result["material_gate_eligible_count"] == 52
    @test result["previously_executed_eligible_count"] == 12
    @test result["retained_count"] == 40
    @test length(selected) == 40
    @test all(material_frontier_eligible_v110, selected)
    @test isempty(intersect(prior_hashes,
        Set(String(item["result_hash"]) for item in selected)))
    @test result["identity_fields_used_for_selection_metrics"] === false
    @test result["unsupported_candidate_count"] == 0

    item = first(selected)
    relabeled = deepcopy(item)
    relabeled["request_index"] = -999
    relabeled["parent_request_index"] = -888
    relabeled["candidate_state"] = "erased"
    @test material_frontier_inputs_v110(relabeled) ==
        material_frontier_inputs_v110(item)
    @test material_frontier_eligible_v110(relabeled) ==
        material_frontier_eligible_v110(item)
end
