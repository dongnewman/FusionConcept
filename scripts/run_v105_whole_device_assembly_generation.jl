#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 2 || error("usage: OUTPUT_DIR REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result, assemblies = run_whole_device_assembly_generation_v105(root)
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
stream_path = joinpath(output_dir, "assembly_proposals.jsonl")
open(stream_path * ".partial", "w") do io
    for item in assemblies
        write(io, JSON3.write(item)); write(io, '\n')
    end
end
mv(stream_path * ".partial", stream_path; force = true)
report = """# v105 whole-device assembly generation

The sole v100 plasma/equilibrium survivor produced $(normalized["assembly_proposal_count"])
explicit whole-device assembly proposals. All $(normalized["assembly_input_closed_count"])
close the declared structural input sections: profile, edge/divertor, radial material stack,
finite conductor, coolant/thermal cycle, fuel cycle, quench/fault, controls/diagnostics,
numerical VVUQ and validation-observable contracts.

This is generation closure only. Provider preflight remains not ready, so no provider was
executed and no assembly received physical rejection, pass, credibility or validation credit.
The proposal grid only selects physical inputs and cannot directly affect metrics.

Acceptance hash: `$(normalized["acceptance_hash"])`

$(WHOLE_DEVICE_ASSEMBLY_V105_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => normalized["status"],
    "assembly_proposal_count" => normalized["assembly_proposal_count"],
    "assembly_input_closed_count" => normalized["assembly_input_closed_count"],
    "whole_device_search_authorized" => normalized["whole_device_search_authorized"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
