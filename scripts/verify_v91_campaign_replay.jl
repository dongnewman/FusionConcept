#!/usr/bin/env julia

using FusionConceptAI
using JSON3

const ROOT_V91_REPLAY = normpath(joinpath(@__DIR__, ".."))

function option_v91_replay(name, default)
    prefix = "--$(name)="
    for argument in ARGS
        startswith(argument, prefix) && return argument[length(prefix)+1:end]
    end
    default
end

campaign_root = abspath(option_v91_replay("campaign", joinpath(ROOT_V91_REPLAY,
    "runs", "multitopology_v91_formal_1000000_20260827")))
output = abspath(option_v91_replay("output", joinpath(ROOT_V91_REPLAY, "runs",
    "multitopology_v91_formal_hash_replay_20260827.json")))
campaign = FusionConceptAI._v91_load_campaign(campaign_root)
merged = JSON3.read(read(joinpath(campaign_root, "campaign_v91_merged.json"), String),
    Dict{String,Any})

sample_targets = Set(Int(item["request_index"])
    for item in merged["deterministic_replay_checks"])
sampled_rows = Dict{Int,Dict{String,Any}}()
record_count = 0; stream_checks = Dict{String,Any}[]
for shard in campaign["shards"]
    path = joinpath(campaign_root, String(shard["result_stream"]))
    rows = FusionConceptAI._v91_read_rows(path)
    for row in rows
        index = Int(row["request_index"])
        index in sample_targets && (sampled_rows[index] = row)
    end
    global record_count += length(rows)
    expected_sha = only(item for item in merged["shard_ranges"]
        if Int(item["shard_id"]) == Int(shard["shard_id"]))["result_stream_sha256"]
    actual_sha = FusionConceptAI._s70_file_sha256(path)
    push!(stream_checks, Dict("shard_id" => shard["shard_id"],
        "record_hashes_replayed" => length(rows),
        "stream_sha256_match" => actual_sha == expected_sha,
        "stream_sha256" => actual_sha))
end

deterministic_checks = Dict{String,Any}[]
for item in merged["deterministic_replay_checks"]
    index = Int(item["request_index"])
    regenerated = compile_v91_campaign_record(index)
    push!(deterministic_checks, Dict("request_index" => index,
        "record_hash_match" => regenerated["record_hash"] ==
            sampled_rows[index]["record_hash"]))
end

dossier_path = joinpath(campaign_root, "survivor_dossiers_v91.jsonl")
dossier_count = 0; dossier_hash_replay = true
open(dossier_path, "r") do io
    while !eof(io)
        line = readline(io); isempty(strip(line)) && continue
        dossier = JSON3.read(line, Dict{String,Any})
        expected = canonical_hash(Dict{String,Any}(String(key) => value for
            (key, value) in dossier if String(key) != "dossier_hash"))
        global dossier_hash_replay &= String(dossier["dossier_hash"]) == expected
        global dossier_count += 1
    end
end

status = record_count == Int(campaign["total_requests"]) &&
    all(item -> item["stream_sha256_match"] === true, stream_checks) &&
    all(item -> item["record_hash_match"] === true, deterministic_checks) &&
    dossier_hash_replay && dossier_count == Int(merged["hard_gate_survivor_count"])
body = Dict{String,Any}(
    "schema_version" => "1.0.0", "status" => status ? "pass" : "fail",
    "campaign_hash" => campaign["campaign_hash"], "merge_hash" => merged["merge_hash"],
    "record_hashes_replayed" => record_count,
    "stream_checks" => stream_checks,
    "deterministic_reexecution_checks" => deterministic_checks,
    "dossier_hashes_replayed" => dossier_count,
    "dossier_hash_replay_status" => dossier_hash_replay ? "pass" : "fail",
    "claim_boundary" => "Full serialization/hash replay plus sampled deterministic re-execution; physics evidence remains at each record's declared ceiling.")
body["replay_hash"] = canonical_hash(body)
FusionConceptAI._v91_atomic_json(output, body)
println(JSON3.write(Dict("status" => body["status"],
    "record_hashes_replayed" => record_count,
    "dossier_hashes_replayed" => dossier_count,
    "replay_hash" => body["replay_hash"], "output" => output)))
