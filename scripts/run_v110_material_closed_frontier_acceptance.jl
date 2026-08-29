#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 2 || error("usage: ACCEPTANCE.json REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
path = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result = run_material_closed_frontier_acceptance_v110(root)
normalized = Dict{String,Any}(FusionConceptAI._v93_plain(
    JSON3.read(JSON3.write(result), Dict{String,Any})))
pop!(normalized, "acceptance_hash", nothing)
normalized["acceptance_hash"] = canonical_hash(normalized)
mkpath(dirname(path))
open(path * ".partial", "w") do io
    JSON3.pretty(io, normalized); write(io, '\n')
end
mv(path * ".partial", path; force = true)
report = """# v110 material-closed high-fidelity frontier

ITER/C-2W reference regression reran first and passed $(normalized["reference_regression_pass_count"])/2 with $(normalized["reference_bypass_count"]) bypasses.

The material-closed frontier retained $(normalized["candidate_count"]) previously unexecuted candidates. FreeGS passed $(normalized["freegs_pass_count"]); DESC cross-code equilibrium plus sampled ideal-MHD retained $(normalized["sampled_ideal_mhd_candidate_count"]); the nine-case static engineering provider retained $(normalized["static_robustness_pass_count"]). Final high-fidelity frontier survivors: $(normalized["high_fidelity_frontier_survivor_count"]).

Blockers: `$(JSON3.write(normalized["blocker_histogram"]))`.

The temporary six-worker DESC OOM was rerun at three workers and is absent from the final artifact: provider system failure=$(normalized["provider_system_failure_count"]), unsupported=$(normalized["unsupported_candidate_count"]). No partial result receives whole-device, validation or credibility credit.

Acceptance hash: `$(normalized["acceptance_hash"])`

$(MATERIAL_CLOSED_FRONTIER_V110_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => normalized["status"], "candidate_count" => normalized["candidate_count"],
    "freegs_pass_count" => normalized["freegs_pass_count"],
    "sampled_ideal_mhd_candidate_count" => normalized["sampled_ideal_mhd_candidate_count"],
    "static_robustness_pass_count" => normalized["static_robustness_pass_count"],
    "high_fidelity_frontier_survivor_count" =>
        normalized["high_fidelity_frontier_survivor_count"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "provider_system_failure_count" => normalized["provider_system_failure_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
