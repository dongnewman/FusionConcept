#!/usr/bin/env julia

using FusionConceptAI
using JSON3

const ROOT_V90 = normpath(joinpath(@__DIR__, ".."))
function option_v90(name, default)
    prefix = "--$(name)="
    for argument in ARGS
        startswith(argument, prefix) && return argument[length(prefix)+1:end]
    end
    default
end
campaign = option_v90("campaign", joinpath(ROOT_V90, "runs",
    "multitopology_campaign_v90_100000_20260827"))
summary = merge_multitopology_campaign_v90(campaign)
println(JSON3.write(Dict(
    "status" => summary["status"], "merge_hash" => summary["merge_hash"],
    "result_count" => summary["result_count"],
    "unique_solver_inputs" => summary["unique_solver_inputs"],
    "hard_gate_survivor_count" => summary["hard_gate_survivor_count"])))
