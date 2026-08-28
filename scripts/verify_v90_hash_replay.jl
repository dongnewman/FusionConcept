#!/usr/bin/env julia

using FusionConceptAI
using JSON3
using SHA

const ROOT_V90 = normpath(joinpath(@__DIR__, ".."))

function option_v90(name, default)
    prefix = "--$(name)="
    for argument in ARGS
        startswith(argument, prefix) && return argument[length(prefix)+1:end]
    end
    default
end

plain_v90(value) = FusionConceptAI._v89_plain(value)
sha256_file_v90(path) = bytes2hex(sha256(read(path)))

function replay_hash_v90(item, omitted)
    canonical_hash(Dict{String,Any}(String(key) => value for (key, value) in item
        if !(String(key) in omitted)))
end

function verify_jsonl_v90(path, hash_field, omitted)
    count = 0
    open(path, "r") do io
        while !eof(io)
            line = readline(io); isempty(strip(line)) && continue
            item = plain_v90(JSON3.read(line, Dict{String,Any}))
            expected = replay_hash_v90(item, omitted)
            String(item[hash_field]) == expected || error(
                "hash replay mismatch in $(basename(path)) record $(count + 1)")
            count += 1
        end
    end
    count
end

campaign_root = abspath(option_v90("campaign", joinpath(ROOT_V90, "runs",
    "multitopology_campaign_v90_100000_20260827")))
acceptance_path = abspath(option_v90("acceptance", joinpath(ROOT_V90, "runs",
    "universal_multitopology_acceptance_v90_20260827.json")))
output_path = abspath(option_v90("output", joinpath(ROOT_V90, "runs",
    "universal_multitopology_hash_replay_v90_20260827.json")))

campaign_path = joinpath(campaign_root, "campaign_v90.json")
campaign = plain_v90(JSON3.read(read(campaign_path, String), Dict{String,Any}))
String(campaign["campaign_hash"]) == replay_hash_v90(campaign,
    Set(["campaign_hash"])) || error("campaign hash replay mismatch")

request_count = 0; result_count = 0
batch_checks = Dict{String,Any}[]
for batch_id in 1:Int(campaign["batch_count"])
    suffix = lpad(batch_id, 2, '0')
    request_path = joinpath(campaign_root, "requests_batch_$suffix.jsonl")
    result_path = joinpath(campaign_root, "results_batch_$suffix.jsonl")
    summary_path = result_path * ".summary.json"
    local_requests = verify_jsonl_v90(request_path, "request_hash",
        Set(["request_hash"]))
    local_results = verify_jsonl_v90(result_path, "record_hash",
        Set(["record_hash", "elapsed_seconds"]))
    summary = plain_v90(JSON3.read(read(summary_path, String), Dict{String,Any}))
    String(summary["batch_result_hash"]) == replay_hash_v90(summary,
        Set(["batch_result_hash", "elapsed_seconds"])) || error(
        "batch $batch_id summary hash replay mismatch")
    String(summary["request_stream_sha256"]) == sha256_file_v90(request_path) ||
        error("batch $batch_id request stream SHA mismatch")
    String(summary["result_stream_sha256"]) == sha256_file_v90(result_path) ||
        error("batch $batch_id result stream SHA mismatch")
    global request_count += local_requests
    global result_count += local_results
    push!(batch_checks, Dict(
        "batch_id" => batch_id, "request_count" => local_requests,
        "result_count" => local_results,
        "batch_result_hash" => summary["batch_result_hash"]))
end

merged_path = joinpath(campaign_root, "campaign_v90_merged.json")
merged = plain_v90(JSON3.read(read(merged_path, String), Dict{String,Any}))
String(merged["merge_hash"]) == replay_hash_v90(merged, Set(["merge_hash"])) ||
    error("merge hash replay mismatch")
acceptance = plain_v90(JSON3.read(read(acceptance_path, String), Dict{String,Any}))
String(acceptance["artifact_hash"]) == replay_hash_v90(acceptance,
    Set(["artifact_hash"])) || error("acceptance artifact hash replay mismatch")

expected = Int(campaign["expected_result_count"])
request_count == expected && result_count == expected || error(
    "v90 replay request/result count mismatch")
body = Dict{String,Any}(
    "schema_version" => "1.0.0", "status" => "pass",
    "campaign_hash" => campaign["campaign_hash"],
    "merge_hash" => merged["merge_hash"],
    "acceptance_artifact_hash" => acceptance["artifact_hash"],
    "request_record_hashes_replayed" => request_count,
    "result_record_hashes_replayed" => result_count,
    "batch_checks" => batch_checks,
    "cache_replay_audit_hash" => merged["cache_replay_audit"]["audit_hash"],
    "claim_boundary" => "Hash replay proves serialization and recorded execution integrity only; it does not promote physics, engineering, validation, novelty, patent, or FTO evidence.")
body["replay_artifact_hash"] = canonical_hash(body)
temporary = output_path * ".partial"; mkpath(dirname(output_path))
open(temporary, "w") do io; JSON3.pretty(io, body); write(io, '\n'); end
mv(temporary, output_path; force = true)
println(JSON3.write(Dict(
    "status" => body["status"], "request_count" => request_count,
    "result_count" => result_count,
    "replay_artifact_hash" => body["replay_artifact_hash"],
    "output" => output_path)))
