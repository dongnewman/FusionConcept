#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) in (5, 6) || error(
    "usage: INPUT.jsonl OUTPUT_DIR VARIANTS_PER_PARENT RETAIN_PER_PARENT EXPECTED_PARENTS [UPSTREAM_ACCEPTANCE.json]")
input_path = abspath(ARGS[1])
output_dir = abspath(ARGS[2])
variant_count = parse(Int, ARGS[3])
retain_count = parse(Int, ARGS[4])
expected_parents = parse(Int, ARGS[5])
upstream_acceptance_path = length(ARGS) == 6 ? abspath(ARGS[6]) : nothing
allowed_parent_indices = if isnothing(upstream_acceptance_path)
    nothing
else
    upstream = FusionConceptAI._v93_plain(JSON3.read(read(upstream_acceptance_path, String)))
    Set(Int(row["request_index"]) for row in upstream["rows"] if row["status"] == "pass")
end
parents = Dict{String,Any}[]
open(input_path, "r") do io
    for line in eachline(io)
        isempty(strip(line)) && continue
        parent = FusionConceptAI._v93_plain(JSON3.read(line))
        if isnothing(allowed_parent_indices) || Int(parent["request_index"]) in allowed_parent_indices
            push!(parents, parent)
        end
    end
end
length(parents) == expected_parents || error(
    "parent census mismatch: $(length(parents)) != $expected_parents")
if !isnothing(allowed_parent_indices)
    Set(Int(parent["request_index"]) for parent in parents) == allowed_parent_indices ||
        error("upstream pass set does not bind one-to-one to the parent stream")
end
mkpath(output_dir)
results = Dict{String,Any}[]
retained = Dict{String,Any}[]
for (number, parent) in enumerate(parents)
    result = refine_candidate_operating_points_v100(parent;
        variant_count = variant_count, retain_count = retain_count)
    push!(results, result)
    append!(retained, result["retained"])
    println("[$number/$(length(parents))] parent=$(parent["request_index"]) " *
        "prefilter=$(result["prefilter_pass_count"]) retained=$(result["retained_count"])")
end
sort!(retained; by = item -> Int(item["request_index"]))
candidate_path = joinpath(output_dir, "computational_candidates.jsonl")
open(candidate_path * ".partial", "w") do io
    for item in retained
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(candidate_path * ".partial", candidate_path; force = true)
failure_histogram = Dict{String,Int}()
for result in results, (key, value) in result["failure_histogram"]
    failure_histogram[key] = get(failure_histogram, key, 0) + Int(value)
end
body = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "protocol_id" => V100_PROTOCOL_ID,
    "status" => "complete",
    "source_candidate_stream" => basename(input_path),
    "source_candidate_stream_sha256" => bytes2hex(sha256(read(input_path))),
    "upstream_acceptance_sha256" => isnothing(upstream_acceptance_path) ? nothing :
        bytes2hex(sha256(read(upstream_acceptance_path))),
    "parent_count" => length(parents),
    "variant_count_per_parent" => variant_count,
    "evaluated_design_count" => length(parents) * variant_count,
    "prefilter_pass_count" => sum(Int(result["prefilter_pass_count"]) for result in results),
    "retained_count" => length(retained),
    "parents_with_retained_count" => count(result -> result["retained_count"] > 0, results),
    "failure_histogram" => Dict(sort(collect(failure_histogram))),
    "unsupported_candidate_count" => 0,
    "provider_system_failure_count" => 0,
    "identity_fields_used_for_routing" => false,
    "candidate_stream_sha256" => bytes2hex(sha256(read(candidate_path))),
    "parent_rows" => [Dict(
        "parent_request_index" => result["parent_request_index"],
        "prefilter_pass_count" => result["prefilter_pass_count"],
        "retained_count" => result["retained_count"],
    ) for result in results],
    "claim_boundary" => DESIGN_REFINEMENT_V100_CLAIM_BOUNDARY,
)
body["acceptance_hash"] = FusionConceptAI.canonical_hash(body)
acceptance_path = joinpath(output_dir, "acceptance.json")
open(acceptance_path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(acceptance_path * ".partial", acceptance_path; force = true)
println(JSON3.write(Dict(key => body[key] for key in (
    "status", "parent_count", "evaluated_design_count", "prefilter_pass_count",
    "retained_count", "parents_with_retained_count", "acceptance_hash"))))
