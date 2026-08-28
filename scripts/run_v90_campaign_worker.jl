#!/usr/bin/env julia

using FusionConceptAI
using JSON3

const ROOT_V90 = normpath(joinpath(@__DIR__, ".."))

function option_v90(name, default = nothing)
    prefix = "--$(name)="
    for argument in ARGS
        startswith(argument, prefix) && return argument[length(prefix)+1:end]
    end
    default
end

campaign = option_v90("campaign", joinpath(ROOT_V90, "runs",
    "multitopology_campaign_v90_100000_20260827"))
batch_value = option_v90("batch")
batch_value === nothing && error("--batch=<positive integer> is required")
stop_value = option_v90("stop-after")
summary = run_multitopology_campaign_worker_v90(campaign, parse(Int, batch_value);
    resume = lowercase(option_v90("resume", "true")) == "true",
    stop_after_candidates = stop_value === nothing ? nothing : parse(Int, stop_value),
    checkpoint_interval = parse(Int, option_v90("checkpoint-interval", "25")))
println(JSON3.write(summary))
