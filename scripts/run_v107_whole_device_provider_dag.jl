#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 2 || error("usage: OUTPUT_DIR REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result = run_whole_device_provider_dag_v107(root)
normalized = Dict{String,Any}(FusionConceptAI._v93_plain(
    JSON3.read(JSON3.write(result), Dict{String,Any})))
pop!(normalized, "acceptance_hash", nothing)
normalized["acceptance_hash"] = canonical_hash(normalized)
mkpath(output_dir)
path = joinpath(output_dir, "acceptance.json")
open(path * ".partial", "w") do io
    JSON3.pretty(io, normalized); write(io, '\n')
end
mv(path * ".partial", path; force = true)
report = """# v107 whole-device available-provider DAG

All $(normalized["input_survivor_count"]) v106 survivors executed every currently available
candidate-bound provider in the declared order. Exact source bindings were verified for FreeGS,
DESC and the nine-case static response. Available-provider DAG pass count is
$(normalized["available_provider_dag_pass_count"]); unsupported and provider-system failures are 0.

All 32 remain `high_fidelity_pending`, because complete whole-device preflight is 0/32.
Validation was not executed and high-cost expansion remains unauthorized. Passing reduced,
sampled or subgraph providers grants no whole-device or credibility credit.

Acceptance hash: `$(normalized["acceptance_hash"])`

$(WHOLE_DEVICE_PROVIDER_DAG_V107_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => normalized["status"],
    "input_survivor_count" => normalized["input_survivor_count"],
    "available_provider_dag_pass_count" => normalized["available_provider_dag_pass_count"],
    "complete_whole_device_preflight_count" =>
        normalized["complete_whole_device_preflight_count"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "whole_device_credible_count" => normalized["whole_device_credible_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
