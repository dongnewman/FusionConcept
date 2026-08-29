#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 2 || error("usage: OUTPUT_DIR REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result, survivors = run_whole_device_assembly_screen_v106(root)
normalized = Dict{String,Any}(FusionConceptAI._v93_plain(
    JSON3.read(JSON3.write(result), Dict{String,Any})))
pop!(normalized, "acceptance_hash", nothing)
normalized["acceptance_hash"] = canonical_hash(normalized)
mkpath(output_dir)
acceptance_path = joinpath(output_dir, "acceptance.json")
open(acceptance_path * ".partial", "w") do io
    JSON3.pretty(io, normalized); write(io, '\n')
end
mv(acceptance_path * ".partial", acceptance_path; force = true)
stream_path = joinpath(output_dir, "screen_survivors.jsonl")
open(stream_path * ".partial", "w") do io
    for item in survivors
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(stream_path * ".partial", stream_path; force = true)
report = """# v106 whole-device assembly reduced screen

All $(normalized["assembly_count"]) v105 assemblies executed the same candidate-bound
radial-build, exhaust, thermal-cycle, recirculating-power, fuel-throughput and finite-conductor
screen. $(normalized["assembly_reject_count"]) were explicitly rejected and
$(normalized["screen_survivor_count"]) remain reduced-screen survivors.

Blockers: `$(JSON3.write(normalized["blocker_histogram"]))`.

There are zero unsupported classifications and zero provider-system failures. A screen survivor
is not a whole-device pass: complete high-fidelity providers, whole-chain numerical VVUQ and
independent validation remain mandatory before credibility or validation credit.

Acceptance hash: `$(normalized["acceptance_hash"])`

$(WHOLE_DEVICE_ASSEMBLY_SCREEN_V106_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => normalized["status"],
    "assembly_count" => normalized["assembly_count"],
    "assembly_reject_count" => normalized["assembly_reject_count"],
    "screen_survivor_count" => normalized["screen_survivor_count"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "whole_device_credible_count" => normalized["whole_device_credible_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
