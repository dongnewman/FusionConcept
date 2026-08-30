#!/usr/bin/env julia
using FusionConceptAI
using JSON3
using SHA

const PROTOCOL_ID = "fusionconceptai-v132-boundary-shape-repair-generation-20260830"
const ELONGATIONS = [1.60, 1.80, 2.01878182223872, 2.20, 2.40]
const TRIANGULARITIES = [-0.30, -0.2326910687798353, -0.15, 0.00, 0.15, 0.30, 0.45]

length(ARGS) == 2 || error("usage: PARENT_CANDIDATE OUTPUT_DIR")
source = abspath(ARGS[1]); output = abspath(ARGS[2])
parent = Dict{String,Any}(FusionConceptAI._v93_plain(JSON3.read(read(source, String))))
parent["candidate_state"] == "computational_candidate" || error(
    "v132 requires a computational parent")

let
mkpath(joinpath(output, "inputs"))
proposals = Dict{String,Any}[]
retained = 0
variant = 0
for elongation in ELONGATIONS, triangularity in TRIANGULARITIES
    variant += 1
    body = deepcopy(parent)
    point = deepcopy(body["operating_point"])
    point["elongation"] = elongation
    point["triangularity"] = triangularity
    point["input_origin"] = "candidate_bound_boundary_shape_repair_v132"
    point["design_sequence"] = "glasser_margin_driven_boundary_shape_scan"
    physics = solve_candidate_physics_v98(point, body["capability_profile"])
    engineering = engineering_prefilter_v100(
        point, physics, body["magnet_layout"])
    body["protocol_id"] = PROTOCOL_ID
    body["parent_protocol_id"] = parent["protocol_id"]
    body["parent_request_index"] = parent["request_index"]
    body["parent_candidate_result_hash"] = parent["result_hash"]
    body["operating_point"] = point
    body["physics_solve"] = physics
    body["engineering_prefilter"] = engineering
    body["candidate_state"] = physics["status"] == "pass" &&
        engineering["status"] == "pass" ? "computational_candidate" :
        "repair_prefilter_reject"
    body["request_index"] = parse(Int, parent["result_hash"][1:12]; base = 16) *
        100 + variant
    body["shape_repair_declaration"] = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => PROTOCOL_ID,
        "repair_variant_index" => variant,
        "elongation" => elongation,
        "triangularity" => triangularity,
        "is_parent_shape_control" =>
            elongation == Float64(parent["operating_point"]["elongation"]) &&
            triangularity == Float64(parent["operating_point"]["triangularity"]),
        "recomputed_reduced_physics" => true,
        "recomputed_engineering_prefilter" => true,
        "prior_stability_pass_credit" => false,
        "identity_fields_used_for_generation" => false)
    body["solver_input_hash"] = canonical_hash(Dict(
        "capability_hash" => body["capability_profile"]["capability_hash"],
        "operating_point" => point,
        "magnet_layout" => body["magnet_layout"],
        "equilibrium_profile_parameters" =>
            body["equilibrium_profile_parameters"]))
    body["physical_pass_credit"] = false
    body["validation_credit"] = false
    body["whole_device_credible"] = false
    body["identity_fields_used_for_routing"] = false
    body["basis_direct_metric_credit"] = false
    body["unsupported_candidate_classification_used"] = false
    body["claim_boundary"] = "v132 varies only declared boundary elongation and " *
        "triangularity around the best v130 current profile, recomputes reduced " *
        "physics and engineering, and grants no prior equilibrium, stability, " *
        "validation, or whole-device pass credit."
    pop!(body, "result_hash", nothing)
    body["result_hash"] = canonical_hash(body)
    input_path = joinpath(output, "inputs", "candidate_$(body["request_index"]).json")
    open(input_path, "w") do io
        JSON3.pretty(io, body); write(io, '\n')
    end
    is_retained = body["candidate_state"] == "computational_candidate"
    retained += is_retained
    push!(proposals, Dict{String,Any}(
        "request_index" => body["request_index"],
        "candidate_result_hash" => body["result_hash"],
        "elongation" => elongation,
        "triangularity" => triangularity,
        "is_parent_shape_control" =>
            body["shape_repair_declaration"]["is_parent_shape_control"],
        "retained" => is_retained,
        "candidate_state" => body["candidate_state"],
        "failed_physics_gates" => body["physics_solve"]["failed_gates"],
        "failed_engineering_gates" =>
            body["engineering_prefilter"]["failed_gates"],
        "input_sha256" => bytes2hex(sha256(read(input_path)))))
end

body = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => PROTOCOL_ID,
    "campaign_kind" => "boundary_shape", "status" => "complete",
    "source_candidate_sha256" => bytes2hex(sha256(read(source))),
    "parent_candidate_result_hash" => parent["result_hash"],
    "proposal_count" => length(proposals), "retained_count" => retained,
    "prefilter_reject_count" => length(proposals) - retained,
    "prior_pass_credit" => false,
    "identity_fields_used_for_generation" => false,
    "proposals" => proposals,
    "claim_boundary" => "v132 proposals receive no pass credit until every " *
        "candidate-bound equilibrium and stability stage is rerun.")
body["acceptance_hash"] = canonical_hash(body)
open(joinpath(output, "generation_acceptance.json"), "w") do io
    JSON3.pretty(io, body); write(io, '\n')
end
println(JSON3.write(Dict(
    "status" => body["status"], "proposal_count" => length(proposals),
    "retained_count" => retained, "acceptance_hash" => body["acceptance_hash"])))
end
