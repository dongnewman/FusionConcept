#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 6 || error(
    "usage: STAGE CANDIDATES.jsonl DESC_ACCEPTANCE.json STATIC_RESULTS_DIR OUTPUT_DIR EXPECTED_SURVIVORS")

stage = ARGS[1]
candidate_path = abspath(ARGS[2])
desc_acceptance_path = abspath(ARGS[3])
static_results_directory = abspath(ARGS[4])
output_directory = abspath(ARGS[5])
expected_survivors = parse(Int, ARGS[6])

generators = Dict(
    "v111" => generate_static_margin_repairs_v111,
    "v112" => generate_fine_static_margin_bracket_v112,
    "v113" => generate_beta_preserving_field_repairs_v113,
    "v114" => generate_similarity_scaled_field_repairs_v114,
)
haskey(generators, stage) || error("unsupported repair stage: $stage")

candidates = Dict{Int,Dict{String,Any}}()
open(candidate_path, "r") do io
    for line in eachline(io)
        isempty(strip(line)) && continue
        candidate = Dict{String,Any}(FusionConceptAI._v93_plain(JSON3.read(line)))
        index = Int(candidate["request_index"])
        haskey(candidates, index) && error("duplicate candidate request index: $index")
        candidates[index] = candidate
    end
end
desc = Dict{String,Any}(FusionConceptAI._v93_plain(
    JSON3.read(read(desc_acceptance_path, String))))
survivor_indices = sort!([Int(row["request_index"]) for row in desc["rows"] if
    row["candidate_state"] == "sampled_ideal_mhd_candidate"])
length(survivor_indices) == expected_survivors || error(
    "sampled-stability survivor census mismatch: $(length(survivor_indices)) != $expected_survivors")

proposals = Dict{String,Any}[]
source_static_hashes = String[]
for index in survivor_indices
    haskey(candidates, index) || error("missing candidate for survivor $index")
    static_path = joinpath(static_results_directory, "static_$(index).json")
    isfile(static_path) || error("missing bound static result for survivor $index")
    static = Dict{String,Any}(FusionConceptAI._v93_plain(
        JSON3.read(read(static_path, String))))
    static["candidate_result_hash"] == candidates[index]["result_hash"] ||
        error("candidate/static binding mismatch for survivor $index")
    static["candidate_state"] == "static_robustness_fail" ||
        error("repair input must be a static robustness failure for survivor $index")
    push!(source_static_hashes, String(static["result_hash"]))
    append!(proposals, generators[stage](candidates[index], static))
end

retained = [item for item in proposals if
    item["candidate_state"] == "computational_candidate"]
rejected = [item for item in proposals if
    item["candidate_state"] != "computational_candidate"]
mkpath(output_directory)
stream_path = joinpath(output_directory, "candidates.jsonl")
open(stream_path * ".partial", "w") do io
    for item in retained
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(stream_path * ".partial", stream_path; force = true)

body = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "protocol_id" => "fusionconceptai-v118-explicit-bound-repair-stage-20260830",
    "repair_stage" => stage,
    "status" => isempty(rejected) ? "complete" : "repair_prefilter_reject",
    "source_candidate_stream_sha256" => bytes2hex(sha256(read(candidate_path))),
    "source_desc_acceptance_hash" => desc["acceptance_hash"],
    "source_static_result_hashes" => source_static_hashes,
    "source_survivor_count" => length(survivor_indices),
    "repair_proposal_count" => length(proposals),
    "repair_prefilter_survivor_count" => length(retained),
    "repair_prefilter_reject_count" => length(rejected),
    "candidate_stream_sha256" => bytes2hex(sha256(read(stream_path))),
    "unsupported_candidate_count" => 0,
    "provider_system_failure_count" => 0,
    "identity_fields_used_for_generation" => false,
    "basis_direct_metric_credit" => false,
    "physical_pass_credit" => false,
    "validation_credit" => false,
    "claim_boundary" => "This adapter binds repair proposals to explicit candidate, DESC, and static artifacts. It grants no physical, whole-device, or validation credit; every retained proposal must rerun all downstream providers.",
)
body["acceptance_hash"] = canonical_hash(body)
acceptance_path = joinpath(output_directory, "generation_acceptance.json")
open(acceptance_path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(acceptance_path * ".partial", acceptance_path; force = true)
println(JSON3.write(Dict(key => body[key] for key in (
    "status", "repair_stage", "source_survivor_count", "repair_proposal_count",
    "repair_prefilter_survivor_count", "repair_prefilter_reject_count",
    "acceptance_hash"))))
