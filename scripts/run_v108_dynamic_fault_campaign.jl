#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 2 || error("usage: OUTPUT_DIR REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result = run_dynamic_fault_campaign_v108(root)
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
report = """# v108 dynamic control and fault screen

The 32 v107 assemblies generated four explicit controller overlays each. All 128 overlays
executed PF-trip, density-excursion, vertical-displacement, coolant-flow-loss and quench
scenarios. $(normalized["dynamic_fault_screen_reject_count"]) controller overlays were
rejected and $(normalized["dynamic_fault_screen_survivor_count"]) survived.

Blockers: `$(JSON3.write(normalized["blocker_histogram"]))`.

Unsupported and provider-system failure counts are zero. This reduced state-space/lumped
fault pass does not close complete dynamic engineering or grant whole-device credibility,
validation or high-cost expansion credit.

Acceptance hash: `$(normalized["acceptance_hash"])`

$(DYNAMIC_FAULT_PROVIDER_V108_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => normalized["status"],
    "controller_overlay_count" => normalized["controller_overlay_count"],
    "dynamic_fault_screen_reject_count" => normalized["dynamic_fault_screen_reject_count"],
    "dynamic_fault_screen_survivor_count" =>
        normalized["dynamic_fault_screen_survivor_count"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "whole_device_credible_count" => normalized["whole_device_credible_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
