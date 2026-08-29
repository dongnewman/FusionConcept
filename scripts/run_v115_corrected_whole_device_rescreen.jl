#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 2 || error("usage: OUTPUT_DIRECTORY REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result, streams = run_corrected_whole_device_rescreen_v115(root)
mkpath(output_dir)
stream_hashes = Dict{String,Any}()
for name in ("assemblies", "screens", "dags", "dynamics", "materials")
    path = joinpath(output_dir, name * ".jsonl")
    open(path * ".partial", "w") do io
        for row in streams[name]
            write(io, JSON3.write(row)); write(io, '\n')
        end
    end
    mv(path * ".partial", path; force = true)
    stream_hashes[name * "_sha256"] = bytes2hex(sha256(read(path)))
end
body = Dict{String,Any}(result)
body["stream_hashes"] = stream_hashes
body["stream_row_counts"] = Dict(name => length(streams[name]) for name in keys(streams))
pop!(body, "acceptance_hash", nothing); body["acceptance_hash"] = canonical_hash(body)
path = joinpath(output_dir, "acceptance.json")
open(path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(path * ".partial", path; force = true)
report = """# v115 corrected whole-device rescreen

ITER/C-2W was rerun before candidate screening: $(body["reference_regression_pass_count"])/2 passed with $(body["reference_bypass_count"]) bypasses.

The campaign bound $(body["source_v114_candidate_count"]) v114 candidates to their FreeGS, DESC and nine-case static artifacts. It generated $(body["assembly_count"]) assemblies with declared 90/110/120 K coolant rises and four independently isolated equal-energy dump segments. Actual-static assembly survivors: $(body["actual_static_screen_survivor_count"]); available-provider DAG passes: $(body["available_provider_dag_pass_count"]); reduced dynamic survivors: $(body["dynamic_fault_screen_survivor_count"]); source-pinned material survivor rows: $(body["material_screen_survivor_count"]), representing $(body["unique_material_survivor_assembly_count"]) unique assemblies from $(body["unique_material_survivor_candidate_count"]) source candidates.

Screen blockers: `$(JSON3.write(body["actual_static_screen_blocker_histogram"]))`. Dynamic blockers: `$(JSON3.write(body["dynamic_fault_blocker_histogram"]))`. Material blockers: `$(JSON3.write(body["material_blocker_histogram"]))`.

Unsupported=$(body["unsupported_candidate_count"]), provider-system-failure=$(body["provider_system_failure_count"]), complete provider preflight=$(body["complete_provider_preflight_count"]), whole-device credible=$(body["whole_device_credible_count"]), validation pass=$(body["validation_pass_count"]). Surviving reduced subgraphs remain high-fidelity pending and are not promoted to whole-device status.

Acceptance hash: `$(body["acceptance_hash"])`

$(CORRECTED_WHOLE_DEVICE_RESCREEN_V115_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => body["status"],
    "reference_regression_pass_count" => body["reference_regression_pass_count"],
    "source_v114_candidate_count" => body["source_v114_candidate_count"],
    "assembly_count" => body["assembly_count"],
    "material_screen_survivor_count" => body["material_screen_survivor_count"],
    "unique_material_survivor_assembly_count" =>
        body["unique_material_survivor_assembly_count"],
    "unique_material_survivor_candidate_count" =>
        body["unique_material_survivor_candidate_count"],
    "whole_device_credible_count" => body["whole_device_credible_count"],
    "acceptance_hash" => body["acceptance_hash"])))
