#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 2 || error("usage: ACCEPTANCE.json REPORT.md")
root = normpath(joinpath(@__DIR__, "..")); path = abspath(ARGS[1])
report_path = abspath(ARGS[2]); body = run_multiregion_conservation_campaign_v116(root)
normalized = Dict{String,Any}(FusionConceptAI._v93_plain(
    JSON3.read(JSON3.write(body), Dict{String,Any})))
rows = pop!(normalized, "rows")
stream_path = joinpath(dirname(path), "provider_results.jsonl")
mkpath(dirname(stream_path)); open(stream_path * ".partial", "w") do io
    for row in rows
        write(io, JSON3.write(row)); write(io, '\n')
    end
end
mv(stream_path * ".partial", stream_path; force = true)
normalized["provider_result_stream_sha256"] = bytes2hex(sha256(read(stream_path)))
normalized["provider_result_stream_row_count"] = length(rows)
normalized["rows"] = [Dict(
    "source_candidate_result_hash" => row["source_candidate_result_hash"],
    "physical_design_hash" => row["physical_design_hash"],
    "candidate_state" => row["candidate_state"],
    "transport_result_hash" => get(row["transport"], "result_hash", nothing),
    "transport_failed_gates" => get(row["transport"], "failed_gates", Any[]),
    "exhaust_result_hash" => get(row["exhaust"], "result_hash", nothing),
    "exhaust_failed_gates" => get(row["exhaust"], "failed_gates", Any[]),
    "row_result_hash" => row["result_hash"]) for row in rows]
pop!(normalized, "acceptance_hash", nothing); normalized["acceptance_hash"] =
    canonical_hash(normalized)
mkpath(dirname(path)); open(path * ".partial", "w") do io
    JSON3.pretty(io, normalized); write(io, '\n')
end
mv(path * ".partial", path; force = true)
blockers = Dict{String,Int}()
for row in rows
    for gate in get(row["transport"], "failed_gates", Any[])
        key = "transport:" * String(gate); blockers[key] = get(blockers, key, 0) + 1
    end
    for gate in get(row["exhaust"], "failed_gates", Any[])
        key = "exhaust:" * String(gate); blockers[key] = get(blockers, key, 0) + 1
    end
end
report = """# v116 multi-region conservation providers

ITER/C-2W reran first: $(normalized["reference_regression_pass_count"])/2 passed, bypass=$(normalized["reference_bypass_count"]).

Six distinct v115 source candidates each supplied one assembly chosen by declared net-power output and a canonical-hash tie break. Core/edge particle and energy conservation passed $(normalized["transport_pass_count"])/6. Field-aligned Spitzer-Harm exhaust passed $(normalized["exhaust_pass_count"])/6. The resulting conservation-provider frontier contains $(normalized["conservation_provider_survivor_count"]) candidates; blockers: `$(JSON3.write(blockers))`.

All solves used the v94 provider registry, field dependency closure, complete graph residual/Jacobian assembly, three mesh levels and independent analytic solutions. Missing-interface negative control remains solver-ineligible. Unsupported=$(normalized["unsupported_candidate_count"]), provider failure=$(normalized["provider_system_failure_count"]).

The whole-device preflight deliberately remains `$(normalized["post_v116_preflight_status"])` with $(normalized["post_v116_closed_obligation_count"])/9 complete obligations. This provider pack does not claim 3D turbulent/neoclassical transport, kinetic SOL/neutral physics, experimental validation or whole-device credibility.

Acceptance hash: `$(normalized["acceptance_hash"])`

$(MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict("status" => normalized["status"],
    "transport_pass_count" => normalized["transport_pass_count"],
    "exhaust_pass_count" => normalized["exhaust_pass_count"],
    "conservation_provider_survivor_count" =>
        normalized["conservation_provider_survivor_count"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
