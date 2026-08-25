using JSON3
using FusionConceptAI

root = normpath(joinpath(@__DIR__, ".."))
result = audit_candidate_v68_real_panel_v1(root)
json_path = joinpath(root, "runs", "candidate_v68_real_panel_v1_20260824.json")
report_path = joinpath(root, "reports", "candidate_v68_real_panel_v1_20260824.md")
open(json_path, "w") do io
    JSON3.pretty(io, result)
    write(io, '\n')
end
closed = result["route_summaries"]["closed_flux"]
open_route = result["route_summaries"]["open_flux"]
lines = [
    "# Candidate v68 real fixed panel v1",
    "",
    "- Panel entries: $(length(result["entries"]))",
    "- Closed route: $(closed["unknown_count"]) unknown, $(closed["component_fail_count"]) component fail, $(closed["complete_c2_result_count"]) complete C2",
    "- Open route: $(open_route["unknown_count"]) unknown, $(open_route["component_fail_count"]) component fail, $(open_route["complete_c2_result_count"]) complete C2",
    "- Source-integrity audits: $(closed["source_integrity_pass_count"] + open_route["source_integrity_pass_count"])/$(length(result["entries"])) pass",
    "- Stage-1 acceptance: $(result["complete_c2_acceptance"]["passed"] ? "pass" : "not yet satisfied")",
    "- Deterministic hash: `$(result["deterministic_hash"])`",
    "",
    "The panel audit does not promote equilibrium, stability, winding, or deposition components into complete C2 residual closure. Candidate-specific missing obligations are recorded in the JSON artifact.",
]
open(report_path, "w") do io
    write(io, join(lines, "\n"))
    write(io, '\n')
end
println(JSON3.write(Dict("json" => json_path, "report" => report_path,
    "deterministic_hash" => result["deterministic_hash"])))
