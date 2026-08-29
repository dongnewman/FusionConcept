#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 4 || error(
    "usage: INPUT.jsonl PRIOR_ACCEPTANCE.json OUTPUT_DIR RETAIN_COUNT")
input_path = abspath(ARGS[1]); prior_path = abspath(ARGS[2])
output_dir = abspath(ARGS[3]); retain_count = parse(Int, ARGS[4])
candidates = [FusionConceptAI._v93_plain(JSON3.read(line)) for line in
    readlines(input_path) if !isempty(strip(line))]
prior = FusionConceptAI._v93_plain(JSON3.read(read(prior_path, String)))
prior_hashes = Set(String(row["candidate_result_hash"]) for row in prior["rows"])
selection, retained = select_material_closed_frontier_v110(candidates;
    prior_result_hashes = prior_hashes, retain_count = retain_count)
mkpath(output_dir)
stream_path = joinpath(output_dir, "candidates.jsonl")
open(stream_path * ".partial", "w") do io
    for item in retained
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(stream_path * ".partial", stream_path; force = true)
body = Dict{String,Any}(selection)
body["status"] = "complete"
body["source_candidate_stream_sha256"] = bytes2hex(sha256(read(input_path)))
body["prior_acceptance_sha256"] = bytes2hex(sha256(read(prior_path)))
body["output_candidate_stream_sha256"] = bytes2hex(sha256(read(stream_path)))
body["rows"] = [Dict(
    "selection_rank" => index,
    "candidate_result_hash" => item["result_hash"],
    "material_frontier_inputs" => material_frontier_inputs_v110(item),
    "physical_pass_credit" => false, "validation_credit" => false,
    "identity_fields_used_for_selection_metrics" => false)
    for (index, item) in enumerate(retained)]
pop!(body, "selection_hash", nothing)
body["acceptance_hash"] = canonical_hash(body)
path = joinpath(output_dir, "selection_acceptance.json")
open(path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(path * ".partial", path; force = true)
println(JSON3.write(Dict(
    "status" => body["status"],
    "input_candidate_count" => body["input_candidate_count"],
    "material_gate_eligible_count" => body["material_gate_eligible_count"],
    "previously_executed_eligible_count" => body["previously_executed_eligible_count"],
    "retained_count" => body["retained_count"],
    "acceptance_hash" => body["acceptance_hash"])))
