#!/usr/bin/env julia

using FusionConceptAI
using JSON3

const ROOT_V91 = normpath(joinpath(@__DIR__, ".."))

function option_v91(name, default)
    prefix = "--$(name)="
    for argument in ARGS
        startswith(argument, prefix) && return argument[length(prefix)+1:end]
    end
    default
end

function run_stage_v91(parent, name, tier, count, shard_size)
    root = joinpath(parent, name)
    manifest_path = joinpath(root, "campaign_v91.json")
    if !isfile(manifest_path)
        compile_multitopology_campaign_v91(root;
            campaign_id = name, tier = tier, total_requests = count,
            shard_size = shard_size)
    end
    recovery_path = joinpath(root, "recovery_drill_v91.json")
    if !isfile(recovery_path)
        recovery = perform_v91_recovery_drill(root)
        recovery["status"] == "pass" || error("v91 $tier recovery drill failed")
    end
    execution = run_multitopology_campaign_all_v91(root;
        threaded = true, checkpoint_interval = 1000)
    execution["status"] == "complete" || error("v91 $tier execution incomplete")
    merged = merge_multitopology_campaign_v91(root)
    merged["status"] == "pass" || error("v91 $tier qualification gates failed")
    root, merged
end

parent = abspath(option_v91("output-root", joinpath(ROOT_V91, "runs")))
catalog = abspath(option_v91("novelty-catalog", joinpath(ROOT_V91, "knowledge",
    "v91_external_novelty_catalog_20260827.json")))
mkpath(parent)

pilot_root, pilot = run_stage_v91(parent,
    "multitopology_v91_pilot_10000_20260827", "pilot", 10_000, 1_000)
pilot["status"] == "pass" || error("v91 pilot failed; qualification is forbidden")

qualification_root, qualification = run_stage_v91(parent,
    "multitopology_v91_qualification_100000_20260827", "qualification",
    100_000, 10_000)
qualification["status"] == "pass" || error(
    "v91 qualification failed; formal campaign is forbidden")

# The formal million-request campaign is deliberately in this same executable path.
# Reaching this line is the automatic authorization condition frozen above.
formal_root, formal = run_stage_v91(parent,
    "multitopology_v91_formal_1000000_20260827", "formal", 1_000_000, 50_000)
formal["status"] == "pass" || error("v91 formal campaign failed")

dossiers = audit_campaign_survivors_v91(formal_root, catalog)
dossiers["dossier_count"] == formal["hard_gate_survivor_count"] || error(
    "v91 survivor dossier count mismatch")

body = Dict{String,Any}(
    "status" => "complete", "pilot_root" => pilot_root,
    "qualification_root" => qualification_root, "formal_root" => formal_root,
    "pilot_merge_hash" => pilot["merge_hash"],
    "qualification_merge_hash" => qualification["merge_hash"],
    "formal_merge_hash" => formal["merge_hash"],
    "formal_request_count" => formal["result_count"],
    "formal_unique_nonisomorphic_topologies" =>
        formal["unique_nonisomorphic_topologies"],
    "formal_hard_gate_survivor_count" => formal["hard_gate_survivor_count"],
    "dossier_summary_hash" => dossiers["summary_hash"],
    "million_campaign_actual_execution" => true,
    "extrapolation_used" => false)
body["pipeline_hash"] = canonical_hash(body)
FusionConceptAI._v91_atomic_json(joinpath(parent,
    "v91_campaign_pipeline_20260827.json"), body)
println(JSON3.write(body))
