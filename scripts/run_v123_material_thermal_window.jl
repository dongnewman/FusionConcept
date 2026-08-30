#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

length(ARGS) == 9 || error("usage: OUTPUT_DIR CANDIDATES FREEGS_RESULTS DESC_RESULTS STATIC_RESULTS GENERATION_ACCEPTANCE FREEGS_ACCEPTANCE DESC_ACCEPTANCE STATIC_ACCEPTANCE")
output = abspath(ARGS[1]); mkpath(output)
bundle = Dict{String,Any}(
    "candidate_path" => abspath(ARGS[2]),
    "freegs_results_directory" => abspath(ARGS[3]),
    "desc_results_directory" => abspath(ARGS[4]),
    "static_results_directory" => abspath(ARGS[5]),
    "generation_acceptance_path" => abspath(ARGS[6]),
    "freegs_acceptance_path" => abspath(ARGS[7]),
    "desc_acceptance_path" => abspath(ARGS[8]),
    "static_acceptance_path" => abspath(ARGS[9]))
root = normpath(joinpath(@__DIR__, ".."))
body, artifacts = run_material_thermal_window_full_chain_v123(root, bundle)
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
inventory = Dict{String,Any}()
for name in ("assemblies", "screens", "dags", "dynamics", "materials")
    inventory["v123_$(name)"] = write_stream(joinpath(output, "v123_$(name).jsonl"),
        artifacts["v115_streams"][name])
end
inventory["v123_conservation"] = write_stream(joinpath(output,
    "v123_conservation.jsonl"), artifacts["v116_rows"])
inventory["v123_channels"] = write_stream(joinpath(output,
    "v123_channels.jsonl"), artifacts["v117_rows"])
write_json(joinpath(output, "assembly_acceptance.json"), artifacts["v115"])
write_json(joinpath(output, "conservation_acceptance.json"), artifacts["v116"])
write_json(joinpath(output, "channel_acceptance.json"), artifacts["v117"])
body["stream_inventory"] = inventory
pop!(body, "acceptance_hash", nothing); body["acceptance_hash"] = canonical_hash(body)
write_json(joinpath(output, "acceptance.json"), body)
report = """# v123 material/thermal-window full-chain acceptance

ITER/C-2W scoped regression: $(body["reference_regression_pass_count"])/2, bypass=$(body["reference_bypass_count"]).

Source candidates: $(body["source_candidate_count"]). Material survivors: $(body["material_survivor_count"]). Conservation survivors: $(body["conservation_provider_survivor_count"]). Channel numerical-VVUQ survivors: $(body["sampled_whole_graph_numerical_vvuq_pass_count"]).

Unsupported=$(body["unsupported_candidate_count"]), provider-system-failure=$(body["provider_system_failure_count"]), validation=$(body["validation_vvuq_status"]), credible=$(body["whole_device_credible_count"]).

Acceptance hash: `$(body["acceptance_hash"])`

$(MATERIAL_THERMAL_WINDOW_REPAIR_V123_CLAIM_BOUNDARY)
"""
write(joinpath(output, "acceptance_report.md"), report)
println(JSON3.write(Dict(key => body[key] for key in ("status",
    "source_candidate_count", "material_survivor_count",
    "conservation_provider_survivor_count",
    "sampled_whole_graph_numerical_vvuq_pass_count", "unsupported_candidate_count",
    "provider_system_failure_count", "validation_vvuq_status",
    "whole_device_credible_count", "acceptance_hash"))))
