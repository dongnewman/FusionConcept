#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 1 || error("usage: OUTPUT_DIR")
root = normpath(joinpath(@__DIR__, "..")); output_dir = abspath(ARGS[1])
result, candidates = run_fine_static_margin_bracket_generation_v112(root)
mkpath(output_dir)
stream = joinpath(output_dir, "candidates.jsonl")
open(stream * ".partial", "w") do io
    for item in candidates
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(stream * ".partial", stream; force = true)
body = Dict{String,Any}(result)
body["candidate_stream_sha256"] = bytes2hex(sha256(read(stream)))
body["rows"] = [Dict(
    "candidate_result_hash" => item["result_hash"],
    "bracket_declaration" => item["bracket_declaration"],
    "physical_pass_credit" => false, "validation_credit" => false)
    for item in candidates]
pop!(body, "acceptance_hash", nothing); body["acceptance_hash"] = canonical_hash(body)
path = joinpath(output_dir, "generation_acceptance.json")
open(path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(path * ".partial", path; force = true)
println(JSON3.write(Dict(
    "status" => body["status"], "bracket_proposal_count" =>
        body["bracket_proposal_count"], "bracket_prefilter_survivor_count" =>
        body["bracket_prefilter_survivor_count"], "acceptance_hash" =>
        body["acceptance_hash"])))
