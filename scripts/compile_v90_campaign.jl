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

output = option_v90("output", joinpath(ROOT_V90, "runs",
    "multitopology_campaign_v90_100000_20260827"))
batches = parse(Int, option_v90("batches", "10"))
batch_size = parse(Int, option_v90("batch-size", "10000"))
overwrite = lowercase(option_v90("overwrite", "false")) == "true"
specification = compile_multitopology_campaign_v90(output;
    batch_count = batches, batch_size = batch_size, overwrite)
println(JSON3.write(Dict(
    "status" => "compiled", "output" => abspath(output),
    "campaign_hash" => specification["campaign_hash"],
    "expected_result_count" => specification["expected_result_count"])))
