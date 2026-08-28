#!/usr/bin/env julia

using Dates
using FusionConceptAI
using JSON3
using SHA

repo = normpath(joinpath(@__DIR__, ".."))
run_rel = joinpath("runs", "v86_medium_structural_campaign_20260826")
run_root = joinpath(repo, run_rel)
report_json = joinpath(repo, "reports",
    "v86_medium_structural_campaign_seal_20260826.json")
report_md = joinpath(repo, "reports",
    "v86_medium_structural_campaign_seal_20260826.md")

plain(path) = FusionConceptAI._stage3_plain_v1(JSON3.read(read(path, String),
    Dict{String,Any}))
sha256_file(path) = bytes2hex(sha256(read(path)))

stages = [
    ("open_field", "finite_filament_field"),
    ("closed_field", "finite_filament_field"),
    ("open_end_loss", "open_field_end_loss"),
    ("closed_p32", "poincare_32"),
    ("open_finite_pressure", "open_field_finite_pressure_capability"),
    ("closed_p64", "poincare_64"),
    ("closed_p128", "poincare_128"),
    ("closed_finite_pressure", "finite_pressure_equilibrium")]

stage_records = Dict{String,Any}[]
authoritative_files = String[
    joinpath(run_rel, "open_catalog.json"),
    joinpath(run_rel, "closed_catalog.json"),
    joinpath(run_rel, "open_field_campaign.json"),
    joinpath(run_rel, "closed_field_campaign.json"),
    joinpath(run_rel, "open_end_loss_campaign.json"),
    joinpath(run_rel, "closed_p32_campaign.json"),
    joinpath(run_rel, "open_finite_pressure_campaign.json"),
    joinpath(run_rel, "closed_p64_campaign.json"),
    joinpath(run_rel, "closed_p128_campaign.json"),
    joinpath(run_rel, "closed_finite_pressure_campaign.json")]

for (directory, gate) in stages
    summary_rel = joinpath(run_rel, directory,
        "v86_campaign_merged.summary.json")
    stream_rel = joinpath(run_rel, directory, "v86_campaign_merged.jsonl")
    summary = plain(joinpath(repo, summary_rel))
    histogram = summary["stage_status_histograms"][gate]
    push!(stage_records, Dict{String,Any}(
        "stage_directory" => directory,
        "gate" => gate,
        "candidate_count" => summary["candidate_count"],
        "status_histogram" => histogram,
        "unique_solver_input_count" => get(summary[
            "unique_solver_input_counts"], gate, 0),
        "actual_execution_count" => get(summary[
            "actual_execution_counts"], gate, 0),
        "cache_hit_count" => get(summary["cache_hit_counts"], gate, 0),
        "duplicate_solver_execution_key_count" => length(summary[
            "duplicate_solver_execution_keys"]),
        "evidence_firewall_passed" => summary["evidence_firewall_passed"],
        "result_hash" => summary["result_hash"]))
    push!(authoritative_files, summary_rel, stream_rel)
end

field_hashes = Set{String}()
for directory in ("open_field", "closed_field")
    stream = joinpath(run_root, directory, "v86_campaign_merged.jsonl")
    for row in FusionConceptAI._v84_read_valid_json_lines(stream)
        push!(field_hashes, String(row["solver_input_hashes"][
            "finite_filament_field"]))
    end
end
length(field_hashes) == 549 || error(
    "medium campaign no longer has exactly 549 unique field inputs")
all(record["evidence_firewall_passed"] === true for record in stage_records) ||
    error("cannot seal campaign with a failed evidence firewall")
all(record["duplicate_solver_execution_key_count"] == 0 for record in
    stage_records) || error("cannot seal campaign with duplicate executions")

code_files = String[
    joinpath("src", "multitopology_campaign_runtime_v86.jl"),
    joinpath("src", "candidate_joint_physical_optimization_v85.jl"),
    joinpath("src", "FusionConceptAI.jl"),
    joinpath("scripts", "v86_campaign_cli.jl"),
    joinpath("test", "multitopology_campaign_runtime_v86.jl")]

function file_record(relative_path)
    path = joinpath(repo, relative_path)
    isfile(path) || error("missing seal artifact $relative_path")
    return Dict{String,Any}(
        "path" => replace(relative_path, '\\' => '/'),
        "bytes" => filesize(path),
        "sha256" => sha256_file(path))
end

body = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "seal_kind" => "v86_medium_structural_campaign_authoritative_seal_v1",
    "sealed_at_utc" => Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
    "mutation_policy" => "append_only_new_campaign_required",
    "source_run_directory" => replace(run_rel, '\\' => '/'),
    "authoritative_stage_directories" => first.(stages),
    "explicitly_non_authoritative_directories" => [
        "closed_finite_pressure_audit",
        "closed_finite_pressure_cache_audit",
        "closed_finite_pressure_probe"],
    "unique_candidate_bound_field_solver_input_count" => length(field_hashes),
    "stage_records" => stage_records,
    "artifact_files" => file_record.(sort!(authoritative_files)),
    "code_provenance" => file_record.(sort!(code_files)),
    "evidence_boundary" => Dict{String,Any}(
        "open_field" => "prescribed electrostatic barrier plus paraxial scalar-pressure screen; no self-consistent ambipolar, kinetic, or stability credit",
        "closed_field" => "Poincare survival is low-order; all 19 promoted candidate-bound DESC finite-pressure executions failed the declared gate",
        "stability" => "not_scheduled because no closed finite-pressure pass exists",
        "minimality" => "no complete physical or engineering minimality claim"),
    "retroactive_feasibility_credit" => false)

seal = copy(body)
seal["seal_hash"] = FusionConceptAI.canonical_hash(body)
mkpath(dirname(report_json))
open(report_json * ".partial", "w") do io
    JSON3.pretty(io, seal); write(io, '\n')
end
mv(report_json * ".partial", report_json; force = true)

stage_by_name = Dict(record["stage_directory"] => record for record in
    stage_records)
seal_hash = String(seal["seal_hash"])
open(report_md * ".partial", "w") do io
    println(io, "# v86 medium structural campaign seal")
    println(io)
    println(io, "- Seal hash: `$(seal_hash)`")
    println(io, "- Unique candidate-bound field inputs: 549")
    println(io, "- Duplicate execution keys: 0 at every authoritative merge")
    println(io, "- Evidence firewall: passed at every authoritative merge")
    println(io)
    println(io, "| Stage | Candidates | Status histogram | Result hash |")
    println(io, "|---|---:|---|---|")
    for (directory, _) in stages
        record = stage_by_name[directory]
        status_histogram = record["status_histogram"]
        histogram = join(["$(key)=$(status_histogram[key])" for key in
            sort!(collect(keys(status_histogram)))], ", ")
        candidate_count = record["candidate_count"]
        result_hash = record["result_hash"]
        println(io, "| $(directory) | $(candidate_count) | $(histogram) | `$(result_hash)` |")
    end
    println(io)
    println(io, "Open-field passes remain bounded screens. Closed-field Poincare survival did not produce a finite-pressure pass: all 19 formally promoted DESC executions failed. Stability is therefore not scheduled. This seal makes no complete-physics, engineering, originality, net-power, or build-ready claim.")
end
mv(report_md * ".partial", report_md; force = true)

println(JSON3.write(Dict("status" => "sealed", "seal_hash" =>
    seal["seal_hash"], "json" => report_json, "markdown" => report_md)))
