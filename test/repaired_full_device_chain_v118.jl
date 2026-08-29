using Test
using JSON3

@testset "v118 explicit artifact bundle and normalized handoff" begin
    root = normpath(joinpath(@__DIR__, ".."))
    v114 = joinpath(root, "runs", "v114_similarity_scaled_field_repair_20260830")
    frontier = load_v114_provider_frontier_v115(joinpath(v114, "candidates.jsonl"),
        joinpath(v114, "freegs", "results"), joinpath(v114, "desc", "results"),
        joinpath(v114, "static", "results"))
    @test length(frontier) == 9
    @test all(item -> item["artifacts"]["static"]["candidate_result_hash"] ==
        item["candidate"]["result_hash"], frontier)

    v115 = joinpath(root, "runs", "v115_corrected_whole_device_rescreen_20260830")
    streams = Dict{String,Any}(name => [FusionConceptAI._v93_plain(JSON3.read(line))
        for line in readlines(joinpath(v115, "$(name).jsonl")) if !isempty(strip(line))]
        for name in ("assemblies", "screens", "materials"))
    normalized = FusionConceptAI._v118_select_conservation_assemblies(streams)
    sealed = select_v115_source_assemblies_v116(root)
    @test getindex.(normalized, "physical_design_hash") ==
        getindex.(sealed, "physical_design_hash")

    v116_rows = [FusionConceptAI._v93_plain(JSON3.read(line)) for line in readlines(
        joinpath(root, "runs", "v116_multiregion_conservation_20260830",
            "provider_results.jsonl")) if !isempty(strip(line))]
    normalized_channel = FusionConceptAI._v118_select_channel_assemblies(
        frontier, streams, v116_rows)
    sealed_channel = select_v116_survivor_assemblies_v117(root)
    @test getindex.(normalized_channel, "physical_design_hash") ==
        getindex.(sealed_channel, "physical_design_hash")
end
