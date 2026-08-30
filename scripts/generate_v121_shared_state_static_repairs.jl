#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 3 || error("usage: V120_SURVIVORS STATIC_RESULTS_DIR OUTPUT_DIR")
source = abspath(ARGS[1]); static_dir = abspath(ARGS[2]); output = abspath(ARGS[3])
parents = [Dict{String,Any}(FusionConceptAI._v93_plain(JSON3.read(line))) for line in
    readlines(source) if !isempty(strip(line))]
proposals = Dict{String,Any}[]
for parent in parents
    static = Dict{String,Any}(FusionConceptAI._v93_plain(JSON3.read(read(joinpath(
        static_dir, "static_$(parent["request_index"]).json"), String))))
    append!(proposals, generate_shared_state_static_repairs_v121(parent, static))
end
retained = [item for item in proposals if item["candidate_state"] ==
    "computational_candidate"]
mkpath(output); stream = joinpath(output, "candidates.jsonl")
open(stream * ".partial", "w") do io
    for item in retained
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(stream * ".partial", stream; force = true)
blockers = Dict{String,Int}()
for item in proposals
    item["candidate_state"] == "repair_prefilter_reject" || continue
    for gate in String.(item["physics_solve"]["failed_gates"])
        key = "physics:" * gate; blockers[key] = get(blockers, key, 0) + 1
    end
    for gate in String.(item["engineering_prefilter"]["failed_gates"])
        key = "engineering:" * gate; blockers[key] = get(blockers, key, 0) + 1
    end
end
body = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V121_PROTOCOL_ID,
    "status" => "complete", "source_candidate_stream_sha256" =>
        bytes2hex(sha256(read(source))), "source_parent_count" => length(parents),
    "proposal_count" => length(proposals), "retained_count" => length(retained),
    "prefilter_reject_count" => length(proposals) - length(retained),
    "prefilter_blocker_histogram" => Dict(sort!(collect(blockers))),
    "candidate_stream_sha256" => bytes2hex(sha256(read(stream))),
    "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
    "identity_fields_used_for_generation" => false,
    "physical_pass_credit" => false, "validation_credit" => false,
    "claim_boundary" => SHARED_STATE_STATIC_REPAIR_V121_CLAIM_BOUNDARY)
body["acceptance_hash"] = canonical_hash(body)
path = joinpath(output, "generation_acceptance.json")
open(path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(path * ".partial", path; force = true)
println(JSON3.write(Dict(key => body[key] for key in ("status", "proposal_count",
    "retained_count", "prefilter_reject_count", "acceptance_hash"))))
