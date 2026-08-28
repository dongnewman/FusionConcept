using LinearAlgebra
using JSON3
using FusionConceptAI

BLAS.set_num_threads(1)

root = normpath(joinpath(@__DIR__, ".."))
output_dir = joinpath(root, "runs", V97_FORMAL_CAMPAIGN_ID)
mode = isempty(ARGS) ? "all" : lowercase(ARGS[1])

if mode == "manifest"
    manifest = compile_exhaustive_campaign_manifest_v97(root)
    mkpath(output_dir)
    FusionConceptAI._v97_json_write(joinpath(output_dir, "campaign_manifest.json"), manifest)
    println("campaign hash: ", manifest["campaign_hash"])
elseif mode == "closure-shard"
    length(ARGS) >= 2 || error("closure-shard requires a shard id")
    manifest_path = joinpath(output_dir, "campaign_manifest.json")
    isfile(manifest_path) || error("run manifest first")
    manifest = JSON3.read(read(manifest_path, String), Dict{String,Any})
    result = run_v97_closure_shard(root, parse(Int, ARGS[2]); output_dir, manifest)
    println(JSON3.write(result))
elseif mode == "merge-closure"
    result = merge_v97_closure_shards(root; output_dir)
    println(JSON3.write(result))
elseif mode == "high-cost-manifest"
    batch_size = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 4096
    result = compile_v97_high_cost_manifest(root; output_dir, batch_size)
    println(JSON3.write(result))
elseif mode == "high-cost-shard"
    length(ARGS) >= 2 || error("high-cost-shard requires a shard id")
    result = run_v97_high_cost_shard(root, parse(Int, ARGS[2]); output_dir)
    println(JSON3.write(result))
elseif mode == "merge-high-cost"
    result = merge_v97_high_cost_shards(root; output_dir)
    println(JSON3.write(result))
elseif mode == "acceptance"
    result = write_v97_exhaustive_acceptance(root; output_dir)
    println(JSON3.write(result))
elseif mode == "all"
    result = run_exhaustive_physical_campaign_v97(root; output_dir)
    println("v97 acceptance: ", result["status"])
    println("processed: ", result["processed"])
    println("final statuses: ", result["final_expanded_status_histogram"])
    println("acceptance hash: ", result["acceptance_hash"])
else
    error("unknown mode: $(mode)")
end
