using LinearAlgebra
using JSON3
using FusionConceptAI

BLAS.set_num_threads(1)
root = normpath(joinpath(@__DIR__, ".."))
output_dir = joinpath(root, "runs", V97_FORMAL_CAMPAIGN_ID)
length(ARGS) >= 2 || error("usage: run_v97_shard_group.jl closure|high-cost shard_id...")
mode = lowercase(ARGS[1])
shard_ids = parse.(Int, ARGS[2:end])

if mode == "closure"
    manifest = JSON3.read(read(joinpath(output_dir, "campaign_manifest.json"), String),
        Dict{String,Any})
    for shard_id in shard_ids
        result = run_v97_closure_shard(root, shard_id; output_dir, manifest)
        println("closure shard ", shard_id, ": ", result["status"], " ",
            JSON3.write(result["funnel"]["status_histogram"]))
        flush(stdout)
    end
elseif mode == "high-cost"
    manifest = JSON3.read(read(joinpath(output_dir, "high_cost_manifest.json"), String),
        Dict{String,Any})
    for shard_id in shard_ids
        result = run_v97_high_cost_shard(root, shard_id; output_dir, manifest)
        println("high-cost shard ", shard_id, ": ", result["status"], " ",
            JSON3.write(result["unique_status_histogram"]))
        flush(stdout)
    end
else
    error("unknown group mode: $(mode)")
end
