using Dates
using JSON3
using FusionConceptAI

const ROOT = normpath(joinpath(@__DIR__, ".."))
const PANEL = joinpath(ROOT, "fixtures", "candidate_v68_real_panel_v1.json")
const CONFIG = joinpath(ROOT, "fixtures", "candidate_stage4_real_panel_v2.json")
const STAMP = Dates.format(today(), "yyyymmdd")
const OUTPUT = length(ARGS) >= 1 ? abspath(ARGS[1]) :
    joinpath(ROOT, "runs", "candidate_stage4_real_panel_v2_$(STAMP).json")
const REPORT = length(ARGS) >= 2 ? abspath(ARGS[2]) :
    joinpath(ROOT, "reports", "candidate_stage4_real_panel_v2_$(STAMP).md")

result = audit_candidate_stage4_real_panel_v2(PANEL, CONFIG; root = ROOT)
mkpath(dirname(OUTPUT))
open(OUTPUT, "w") do io
    JSON3.pretty(io, result)
    write(io, '\n')
end

function joined_or_dash(values)
    isempty(values) ? "-" : join(values, ", ")
end

mkpath(dirname(REPORT))
open(REPORT, "w") do io
    deterministic_hash = result["deterministic_hash"]
    println(io, "# Candidate Stage-4 real-panel audit v2")
    println(io)
    println(io, "Deterministic hash: `$deterministic_hash`")
    println(io)
    println(io, result["claim_boundary"])
    println(io)
    println(io, "| Panel entry | Route | Role | Status | Passed | Unsupported | Missing evidence | Unknown evidence | Required hard failure | Auxiliary narrow failure |")
    println(io, "|---|---|---|---:|---|---|---|---|---:|---|")
    for row in result["rows"]
        compilation = row["compilation"]
        cells = [row["panel_entry_id"], row["route"], row["control_role"],
            compilation["stage_status"], joined_or_dash(compilation["passed_operator_ids"]),
            joined_or_dash(compilation["unsupported_operator_ids"]),
            joined_or_dash(compilation["missing_evidence_operator_ids"]),
            joined_or_dash(compilation["unknown_operator_ids"]),
            compilation["authoritative_hard_failure"],
            joined_or_dash(compilation["auxiliary_failed_operator_ids"])]
        println(io, "| $(join(cells, " | ")) |")
    end
    println(io)
    println(io, "## Acceptance")
    println(io)
    acceptance = result["acceptance"]
    println(io, "- Closed route complete Stage 4: $(acceptance["closed_route_complete_stage4"])")
    println(io, "- Open route complete Stage 4: $(acceptance["open_route_complete_stage4"])")
    println(io, "- Pulse route deferred without RHD/EOS/opacity: $(acceptance["pulse_route_deferred_without_rhd_eos_opacity"])")
    println(io)
    println(io, "The closed-route fixed-current 32-filament vacuum-Bn control is a required-operator hard failure. The open-route local minimum-B control and both repaired finite-winding candidates' unassisted two-coil vacuum minimum-B paths are auxiliary narrow failures: they remain recorded but do not set the required Stage-4 conclusion. None is a complete Stage-4 or C2 result. FLR, conducting-boundary, ambipolar, flow-shear, DCLC/AIC and alternative minimum-B stabilization remain unfalsified. Pool-24/56 favorable sampled modes remain partial and non-compensating.")
end

println("wrote $OUTPUT")
println("wrote $REPORT")
println("deterministic_hash=", result["deterministic_hash"])
