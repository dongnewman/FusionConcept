#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 3 || error("usage: CANDIDATE_STREAM FREEGS_RESULTS_DIR OUTPUT_DIR")
source = abspath(ARGS[1]); freegs = abspath(ARGS[2]); output = abspath(ARGS[3])
parents = select_equilibrium_profile_parents_v120(source, freegs;
    maximum_parents = typemax(Int))
all_proposals = generate_equilibrium_profile_repairs_v120(parents)
candidates = [item for item in all_proposals if
    item["equilibrium_profile_parameters"]["alpha_m"] == 2 &&
    item["equilibrium_profile_parameters"]["alpha_n"] == 1]
mkpath(output); stream = joinpath(output, "candidates.jsonl")
open(stream * ".partial", "w") do io
    for item in candidates
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(stream * ".partial", stream; force = true)
body = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "protocol_id" => "fusionconceptai-v125-profile21-frontier-expansion-20260830",
    "status" => "complete", "selected_parent_count" => length(parents),
    "proposal_count" => length(candidates),
    "selected_profile" => Dict("alpha_m" => 2, "alpha_n" => 1),
    "selection_basis" => "v120_only_profile_shape_with_shared_state_desc_survivors",
    "source_candidate_stream_sha256" => bytes2hex(sha256(read(source))),
    "candidate_stream_sha256" => bytes2hex(sha256(read(stream))),
    "identity_fields_used_for_generation" => false,
    "identity_fields_used_for_routing" => false,
    "prior_pass_credit" => false, "physical_pass_credit" => false,
    "validation_credit" => false, "unsupported_candidate_count" => 0,
    "claim_boundary" => "v125 expands the empirically surviving (2,1) profile operator across every corrected low-beta FreeGS parent; all providers rerun and the profile receives no pass credit.")
body["acceptance_hash"] = canonical_hash(body)
path = joinpath(output, "generation_acceptance.json")
open(path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(path * ".partial", path; force = true)
println(JSON3.write(Dict(key => body[key] for key in ("status",
    "selected_parent_count", "proposal_count", "acceptance_hash"))))
