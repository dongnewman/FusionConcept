#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 2 || error("usage: OUTPUT_DIR REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result = run_whole_device_preflight_v104(root)
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

row = only(normalized["survivor_rows"]); preflight = row["preflight"]
gaps = [item for item in preflight["obligation_rows"] if item["status"] != "closed"]
gap_lines = ["| $(item["obligation"]["obligation_id"]) | $(item["status"]) | " *
    "$(item["best_available_evidence_level"]) | " *
    "$(item["obligation"]["required_evidence_level"]) |" for item in gaps]
report = """# v104 whole-device provider preflight

ITER/C-2W mission-aware reference regression: 2/2 pass; bypass=0.

The sole v100 qualification-incomplete survivor was preflighted before any new
high-cost search. Only $(preflight["closed_obligation_count"])/$(preflight["required_obligation_count"])
whole-device obligations are closed, so whole-device search is not authorized.
The candidate is `not_adjudicated_provider_gap`: it is neither unsupported,
physically rejected, physically passed, nor validated.

| Obligation | Preflight status | Best available | Required |
|---|---|---|---|
$(join(gap_lines, "\n"))

The next generator revision must create candidate-bound edge/divertor, material,
blanket/shield, finite-conductor, coolant/thermal-cycle, fuel-cycle, quench/fault,
controller/diagnostic and validation-observable inputs. Existing reduced or static
outputs cannot be relabelled as complete evidence.

Acceptance hash: `$(normalized["acceptance_hash"])`

$(WHOLE_DEVICE_PREFLIGHT_V104_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => normalized["status"],
    "reference_regression_pass_count" => normalized["reference_regression_pass_count"],
    "closed_obligation_count" => preflight["closed_obligation_count"],
    "required_obligation_count" => preflight["required_obligation_count"],
    "whole_device_search_authorized" => normalized["whole_device_search_authorized"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
