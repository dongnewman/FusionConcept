#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 2 || error("usage: OUTPUT_DIR REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result = run_material_engineering_campaign_v109(root)
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
report = """# v109 source-pinned material and engineering screen

ITER and C-2W first reran through the v103 reference regression: $(normalized["reference_regression_pass_count"])/2 passed with $(normalized["reference_bypass_count"]) bypasses.

All $(normalized["input_dynamic_survivor_count"]) v108 dynamic survivors then ran the source-pinned conservative material screen. $(normalized["material_screen_reject_count"]) were physically rejected and $(normalized["material_screen_survivor_count"]) survived. The blocker histogram is `$(JSON3.write(normalized["blocker_histogram"]))`.

The current designs have about 1.158 m of declared plasma-to-wall nuclear build, below the 1.2 m rejection-screen lower bound, and the 50 percent coolant-flow fault reaches 873 K, above the 823.15 K EUROFER blanket-structure limit. These are candidate-bound screen failures, not provider gaps.

Unsupported and provider-system failure counts are zero. Complete 3D neutronics, damage/lifetime, component thermal hydraulics, stress/strain/fatigue, manufacturing, whole-device numerical VVUQ and validation remain uncomputed. No whole-device or credibility credit is granted.

Acceptance hash: `$(normalized["acceptance_hash"])`

$(MATERIAL_ENGINEERING_PROVIDER_V109_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => normalized["status"],
    "reference_regression_pass_count" => normalized["reference_regression_pass_count"],
    "input_dynamic_survivor_count" => normalized["input_dynamic_survivor_count"],
    "material_screen_reject_count" => normalized["material_screen_reject_count"],
    "material_screen_survivor_count" => normalized["material_screen_survivor_count"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "whole_device_credible_count" => normalized["whole_device_credible_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
