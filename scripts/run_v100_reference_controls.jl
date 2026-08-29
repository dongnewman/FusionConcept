#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 1 || error("usage: OUTPUT.json")
project_root = normpath(joinpath(@__DIR__, ".."))
v98 = run_v98_reference_acceptance(project_root)
v99 = run_v99_reference_controls(project_root)
body = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "protocol_id" => "fusionconceptai-v100-reference-controls-20260829",
    "status" => v98["status"] == "pass" && v99["status"] == "pass" ? "pass" : "fail",
    "v98_numerical_reference_acceptance" => v98,
    "v99_capability_route_acceptance" => v99,
    "reference_control_count" => 2,
    "validation_pass_count" => 0,
    "whole_device_candidate_credit" => false,
    "identity_fields_used_for_routing" => false,
    "claim_boundary" => "ITER and C-2W are rerun first as non-routing reference controls. " *
        "They test capability routing and bounded numerical regression only; they provide " *
        "no candidate, whole-device, or independent validation credit.",
)
body = Dict{String,Any}(FusionConceptAI._v93_plain(JSON3.read(JSON3.write(body))))
body["acceptance_hash"] = canonical_hash(body)
path = abspath(ARGS[1])
mkpath(dirname(path))
open(path * ".partial", "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
mv(path * ".partial", path; force = true)
println(JSON3.write(Dict("status" => body["status"],
    "reference_control_count" => 2, "validation_pass_count" => 0,
    "acceptance_hash" => body["acceptance_hash"])))
