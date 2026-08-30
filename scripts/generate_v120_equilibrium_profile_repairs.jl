#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 3 || error("usage: CANDIDATE_STREAM FREEGS_RESULTS_DIR OUTPUT_DIR")
candidate_stream = abspath(ARGS[1]); freegs_results = abspath(ARGS[2])
output_dir = abspath(ARGS[3]); mkpath(output_dir)
parents = select_equilibrium_profile_parents_v120(candidate_stream, freegs_results)
candidates = generate_equilibrium_profile_repairs_v120(parents)
stream = joinpath(output_dir, "candidates.jsonl")
open(stream * ".partial", "w") do io
    for item in candidates
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(stream * ".partial", stream; force = true)
body = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V120_PROTOCOL_ID,
    "status" => "complete", "source_candidate_stream_sha256" =>
        bytes2hex(sha256(read(candidate_stream))),
    "selected_parent_count" => length(parents),
    "profile_variant_count" => length(V120_PROFILE_VARIANTS),
    "proposal_count" => length(candidates),
    "candidate_stream_sha256" => bytes2hex(sha256(read(stream))),
    "parent_candidate_result_hashes" => sort!(String.(getindex.(parents, "result_hash"))),
    "identity_fields_used_for_generation" => false,
    "identity_fields_used_for_routing" => false,
    "basis_direct_metric_credit" => false,
    "physical_pass_credit" => false, "validation_credit" => false,
    "unsupported_candidate_count" => 0,
    "claim_boundary" => EQUILIBRIUM_PROFILE_REPAIR_V120_CLAIM_BOUNDARY)
body["acceptance_hash"] = canonical_hash(body)
path = joinpath(output_dir, "generation_acceptance.json")
open(path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(path * ".partial", path; force = true)
println(JSON3.write(Dict("status" => body["status"],
    "selected_parent_count" => body["selected_parent_count"],
    "proposal_count" => body["proposal_count"],
    "acceptance_hash" => body["acceptance_hash"])))
