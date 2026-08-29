#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 9 || error(
    "usage: OUTPUT_DIR CANDIDATES FREEGS_RESULTS DESC_RESULTS STATIC_RESULTS GENERATION_ACCEPTANCE FREEGS_ACCEPTANCE DESC_ACCEPTANCE STATIC_ACCEPTANCE")

root = normpath(joinpath(@__DIR__, ".."))
output_directory = abspath(ARGS[1])
bundle = Dict{String,Any}(
    "candidate_path" => abspath(ARGS[2]),
    "freegs_results_directory" => abspath(ARGS[3]),
    "desc_results_directory" => abspath(ARGS[4]),
    "static_results_directory" => abspath(ARGS[5]),
    "generation_acceptance_path" => abspath(ARGS[6]),
    "freegs_acceptance_path" => abspath(ARGS[7]),
    "desc_acceptance_path" => abspath(ARGS[8]),
    "static_acceptance_path" => abspath(ARGS[9]),
)
body, artifacts = run_repaired_full_device_chain_v118(root, bundle)
mkpath(output_directory)

function write_json(path, value)
    open(path * ".partial", "w") do io
        JSON3.pretty(io, value); write(io, '\n')
    end
    mv(path * ".partial", path; force = true)
end

function write_stream(path, rows)
    open(path * ".partial", "w") do io
        for row in rows
            write(io, JSON3.write(row)); write(io, '\n')
        end
    end
    mv(path * ".partial", path; force = true)
    Dict("row_count" => length(rows), "sha256" => bytes2hex(sha256(read(path))))
end

stream_inventory = Dict{String,Any}()
for name in ("assemblies", "screens", "dags", "dynamics", "materials")
    path = joinpath(output_directory, "v115_$(name).jsonl")
    stream_inventory["v115_$(name)"] = write_stream(path,
        artifacts["v115_streams"][name])
end
stream_inventory["v116_provider_results"] = write_stream(joinpath(output_directory,
    "v116_provider_results.jsonl"), artifacts["v116_rows"])
stream_inventory["v117_channel_results"] = write_stream(joinpath(output_directory,
    "v117_channel_results.jsonl"), artifacts["v117_rows"])

write_json(joinpath(output_directory, "v115_acceptance.json"), artifacts["v115"])
write_json(joinpath(output_directory, "v116_acceptance.json"), artifacts["v116"])
write_json(joinpath(output_directory, "v117_acceptance.json"), artifacts["v117"])
body["stream_inventory"] = stream_inventory
pop!(body, "acceptance_hash", nothing); body["acceptance_hash"] = canonical_hash(body)
write_json(joinpath(output_directory, "acceptance.json"), body)

report = """# v118 repaired full-device chain acceptance

ITER/C-2W reference regression: $(body["reference_regression_pass_count"])/2, bypass=$(body["reference_bypass_count"]).

Fresh v114 source candidates: $(body["source_candidate_count"]). Material survivor rows: $(body["material_survivor_count"]). Conservation-provider survivors: $(body["conservation_provider_survivor_count"]). Sampled whole-graph numerical-VVUQ rows surviving channel thermal-hydraulics: $(body["sampled_whole_graph_numerical_vvuq_pass_count"]).

Unsupported=$(body["unsupported_candidate_count"]), provider-system-failure=$(body["provider_system_failure_count"]), validation=$(body["validation_vvuq_status"]), validation pass=$(body["validation_pass_count"]), credible whole device=$(body["whole_device_credible_count"]).

Acceptance hash: `$(body["acceptance_hash"])`

$(REPAIRED_FULL_DEVICE_CHAIN_V118_CLAIM_BOUNDARY)
"""
write(joinpath(output_directory, "acceptance_report.md"), report)
println(JSON3.write(Dict(key => body[key] for key in (
    "status", "source_candidate_count", "material_survivor_count",
    "conservation_provider_survivor_count",
    "sampled_whole_graph_numerical_vvuq_pass_count",
    "unsupported_candidate_count", "provider_system_failure_count",
    "validation_vvuq_status", "whole_device_credible_count", "acceptance_hash"))))
