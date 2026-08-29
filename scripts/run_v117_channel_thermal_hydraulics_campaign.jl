#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 2 || error("usage: ACCEPTANCE.json REPORT.md")
root = normpath(joinpath(@__DIR__, "..")); path = abspath(ARGS[1])
report_path = abspath(ARGS[2]); result = run_channel_thermal_hydraulics_campaign_v117(root)
body = Dict{String,Any}(FusionConceptAI._v93_plain(
    JSON3.read(JSON3.write(result), Dict{String,Any})))
rows = pop!(body, "rows"); mkpath(dirname(path))
stream = joinpath(dirname(path), "channel_results.jsonl")
open(stream * ".partial", "w") do io
    for row in rows
        write(io, JSON3.write(row)); write(io, '\n')
    end
end
mv(stream * ".partial", stream; force = true)
body["channel_result_stream_sha256"] = bytes2hex(sha256(read(stream)))
body["channel_result_stream_row_count"] = length(rows)
body["rows"] = [Dict(
    "source_candidate_result_hash" => row["source_candidate_result_hash"],
    "physical_design_hash" => row["physical_design_hash"],
    "channel_design_hash" => row["channel_design_hash"],
    "status" => row["status"], "candidate_state" => row["candidate_state"],
    "failed_gates" => row["failed_gates"],
    "updated_net_electric_power_w" => row["updated_net_electric_power_w"],
    "loss_of_flow_structure_temperature_k" =>
        row["loss_of_flow_structure_temperature_k"],
    "result_hash" => row["result_hash"]) for row in rows]
pop!(body, "acceptance_hash", nothing); body["acceptance_hash"] = canonical_hash(body)
open(path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(path * ".partial", path; force = true)
report = """# v117 channel thermal-hydraulics campaign

ITER/C-2W reran first: $(body["reference_regression_pass_count"])/2 passed with $(body["reference_bypass_count"]) bypasses.

The Pareto-preserving handoff retained $(body["source_assembly_count"]) assemblies across source candidate, coolant temperature rise and divertor target area. It evaluated $(body["channel_overlay_count"]) explicit helium-channel designs. $(body["channel_thermal_hydraulics_survivor_count"]) rows passed, representing $(body["unique_survivor_assembly_count"]) assemblies and $(body["unique_survivor_source_candidate_count"]) source candidates. $(body["channel_thermal_hydraulics_reject_count"]) rows were physically rejected.

Blockers: `$(JSON3.write(body["blocker_histogram"]))`. Unsupported=$(body["unsupported_candidate_count"]), provider failure=$(body["provider_system_failure_count"]), whole-device credible=$(body["whole_device_credible_count"]).

Acceptance hash: `$(body["acceptance_hash"])`

$(CHANNEL_THERMAL_HYDRAULICS_V117_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict("status" => body["status"],
    "channel_overlay_count" => body["channel_overlay_count"],
    "channel_thermal_hydraulics_survivor_count" =>
        body["channel_thermal_hydraulics_survivor_count"],
    "unique_survivor_assembly_count" => body["unique_survivor_assembly_count"],
    "unique_survivor_source_candidate_count" =>
        body["unique_survivor_source_candidate_count"],
    "unsupported_candidate_count" => body["unsupported_candidate_count"],
    "acceptance_hash" => body["acceptance_hash"])))
