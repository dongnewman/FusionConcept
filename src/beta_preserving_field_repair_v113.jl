const V113_PROTOCOL_ID = "fusionconceptai-v113-beta-preserving-field-repair-20260830"

const BETA_PRESERVING_FIELD_REPAIR_V113_CLAIM_BOUNDARY =
    "v113 proposes a declared magnetic-field scan around the sole v112 DESC survivor and " *
    "scales density by the square of the field multiplier to preserve the leading pressure " *
    "to magnetic-pressure ratio. This is a physical operating-point proposal, not a metric " *
    "correction: reduced physics, FreeGS, DESC and nine static perturbations are recomputed, " *
    "and no coordinate receives pass or promotion credit."

const V113_FIELD_MULTIPLIERS = [0.94, 0.96, 0.98, 0.99]

function generate_beta_preserving_field_repairs_v113(parent_raw, static_raw)
    parent = Dict{String,Any}(_v93_plain(parent_raw))
    static = Dict{String,Any}(_v93_plain(static_raw))
    parent["protocol_id"] == V112_PROTOCOL_ID || throw(ArgumentError(
        "v113 requires a v112 bracket parent"))
    static["candidate_state"] == "static_robustness_fail" || throw(ArgumentError(
        "v113 requires a v112 static failure"))
    static["candidate_result_hash"] == parent["result_hash"] || throw(ArgumentError(
        "v113 parent/static binding mismatch"))
    old_point = Dict{String,Any}(parent["operating_point"])
    old_field = Float64(old_point["magnetic_field_t"])
    old_density = Float64(old_point["density_m3"])
    actual_field = maximum(Float64(record["response"][
        "additive_peak_field_proxy_t"]) for record in Dict{String,Any}.(static["records"]))
    proposals = Dict{String,Any}[]
    for (variant, multiplier) in enumerate(V113_FIELD_MULTIPLIERS)
        point = deepcopy(old_point)
        point["magnetic_field_t"] = old_field * multiplier
        point["density_m3"] = old_density * multiplier^2
        point["input_origin"] = "candidate_bound_beta_preserving_field_repair_v113"
        point["design_sequence"] = "declared_field_density_scan_no_metric_credit"
        layout = deepcopy(Dict{String,Any}(parent["magnet_layout"]))
        physics = solve_candidate_physics_v98(point, parent["capability_profile"])
        engineering = engineering_prefilter_v100(point, physics, layout)
        declaration = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V113_PROTOCOL_ID,
            "repair_variant_index" => variant, "field_multiplier" => multiplier,
            "density_multiplier" => multiplier^2,
            "source_actual_static_peak_field_t" => actual_field,
            "prior_magnetic_field_t" => old_field,
            "proposed_magnetic_field_t" => point["magnetic_field_t"],
            "prior_density_m3" => old_density,
            "proposed_density_m3" => point["density_m3"],
            "leading_beta_scaling_ratio" =>
                (Float64(point["density_m3"]) / old_density) /
                (Float64(point["magnetic_field_t"]) / old_field)^2,
            "basis_direct_metric_credit" => false,
            "identity_fields_used_for_generation" => false)
        request_index = Int(parent["request_index"]) * 10 + variant
        body = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V113_PROTOCOL_ID,
            "request_index" => request_index,
            "parent_request_index" => parent["request_index"],
            "parent_candidate_result_hash" => parent["result_hash"],
            "graph_hash" => parent["graph_hash"],
            "capability_profile" => deepcopy(parent["capability_profile"]),
            "operating_point" => point, "magnet_layout" => layout,
            "physics_solve" => physics, "engineering_prefilter" => engineering,
            "repair_declaration" => declaration,
            "candidate_state" => physics["status"] == "pass" &&
                engineering["status"] == "pass" ? "computational_candidate" :
                "repair_prefilter_reject",
            "physical_pass_credit" => false, "validation_credit" => false,
            "identity_fields_used_for_routing" => false,
            "basis_direct_metric_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "claim_boundary" => BETA_PRESERVING_FIELD_REPAIR_V113_CLAIM_BOUNDARY)
        body["solver_input_hash"] = canonical_hash(Dict(
            "capability_hash" => body["capability_profile"]["capability_hash"],
            "operating_point" => point, "magnet_layout" => layout))
        body["result_hash"] = canonical_hash(body)
        push!(proposals, body)
    end
    proposals
end

function run_beta_preserving_field_repair_generation_v113(project_root::AbstractString)
    root = abspath(project_root)
    directory = joinpath(root, "runs", "v112_fine_static_margin_bracket_20260829")
    candidates = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "candidates.jsonl")) if !isempty(strip(line))]
    desc = _v110_read_json(joinpath(directory, "desc", "acceptance.json"))
    indices = [Int(row["request_index"]) for row in desc["rows"] if
        row["candidate_state"] == "sampled_ideal_mhd_candidate"]
    length(indices) == 1 || throw(ArgumentError(
        "v113 requires exactly one v112 DESC survivor"))
    index = only(indices)
    parent = only(item for item in candidates if Int(item["request_index"]) == index)
    static = _v110_read_json(joinpath(directory, "static", "results",
        "static_$(index).json"))
    proposals = generate_beta_preserving_field_repairs_v113(parent, static)
    retained = [item for item in proposals if item["candidate_state"] ==
        "computational_candidate"]
    rejected = [item for item in proposals if item["candidate_state"] ==
        "repair_prefilter_reject"]
    blockers = Dict{String,Int}()
    for item in rejected
        physics = Dict{String,Any}(item["physics_solve"])
        engineering = Dict{String,Any}(item["engineering_prefilter"])
        for gate in String.(get(physics, "failed_gates", Any[]))
            key = "physics:" * gate; blockers[key] = get(blockers, key, 0) + 1
        end
        for gate in String.(get(engineering, "failed_gates", Any[]))
            key = "engineering:" * gate; blockers[key] = get(blockers, key, 0) + 1
        end
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V113_PROTOCOL_ID,
        "status" => "complete",
        "source_desc_acceptance_hash" => desc["acceptance_hash"],
        "source_static_result_hash" => static["result_hash"],
        "repair_proposal_count" => length(proposals),
        "repair_prefilter_survivor_count" => length(retained),
        "repair_prefilter_reject_count" => length(rejected),
        "repair_prefilter_blocker_histogram" => Dict(sort!(collect(blockers))),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "physical_pass_credit" => false, "validation_credit" => false,
        "identity_fields_used_for_generation" => false,
        "basis_direct_metric_credit" => false,
        "claim_boundary" => BETA_PRESERVING_FIELD_REPAIR_V113_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, retained
end
