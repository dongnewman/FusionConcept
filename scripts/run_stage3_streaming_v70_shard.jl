using FusionConceptAI
using JSON3

function option(name::String; default = nothing)
    index = findfirst(==(name), ARGS)
    index === nothing && return default
    index < length(ARGS) || error("missing value for $name")
    return ARGS[index + 1]
end

shard_id = parse(Int, option("--shard-id"))
first_seed = parse(Int, option("--first-seed"))
last_seed = parse(Int, option("--last-seed"))
output_directory = abspath(option("--output-directory"))
numerical_per_shard = parse(Int, option("--numerical-per-shard"; default = "100"))

summary = run_stage3_streaming_shard_v70(shard_id, first_seed, last_seed;
    output_directory = output_directory,
    numerical_per_shard = numerical_per_shard)
println(JSON3.write(Dict("status" => summary["status"],
    "shard_id" => summary["shard_id"],
    "raw_seed_count" => summary["raw_seed_count"],
    "unique_structure_count" => summary["unique_structure_count"],
    "numerical_evidence_count" => summary["numerical_evidence_count"],
    "shard_result_hash" => summary["shard_result_hash"])))
