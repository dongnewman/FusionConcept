using FusionConceptAI
using JSON3

function option(name::String; default = nothing)
    index = findfirst(==(name), ARGS)
    index === nothing && return default
    index < length(ARGS) || error("missing value for $name")
    return ARGS[index + 1]
end

output_directory = abspath(option("--output-directory"))
expected_raw_count = parse(Int, option("--expected-raw-count"; default = "100000"))
artifact = merge_stage3_streaming_shards_v70(output_directory;
    expected_raw_count = expected_raw_count)
println(JSON3.write(Dict("status" => artifact["status"],
    "raw_candidate_count" => artifact["raw_candidate_count"],
    "unique_structure_count" => artifact["unique_structure_count"],
    "unique_evidence_count" => artifact["unique_evidence_count"],
    "winner_structure_hash" => artifact["winner_selection"]["winner"]["structure_hash"],
    "result_hash" => artifact["result_hash"])))
