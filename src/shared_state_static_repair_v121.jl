const V121_PROTOCOL_ID = "fusionconceptai-v121-shared-state-static-repair-20260830"

const SHARED_STATE_STATIC_REPAIR_V121_CLAIM_BOUNDARY =
    "v121 derives a lower-field target only from the measured nine-case peak-field " *
    "overrun, preserves leading beta by scaling density with field squared, and uniformly " *
    "scales all declared device/radial-build dimensions. Reduced physics and engineering " *
    "are recomputed; every retained proposal must rerun FreeGS, DESC, static robustness " *
    "and the downstream whole-device graph. No prior pass or profile-coordinate credit."

const V121_FIELD_TARGET_FRACTIONS = [0.90, 1.00, 1.10]
const V121_SIZE_MULTIPLIERS = [1.25, 1.50, 1.75]

function static_repair_field_multipliers_v121(actual_peak_field_t::Real;
        target_peak_field_t::Real = 15.0)
    actual_peak_field_t > 0 || throw(ArgumentError("actual peak field must be positive"))
    base = min(0.95, Float64(target_peak_field_t) / Float64(actual_peak_field_t))
    unique(sort!(min.(0.95, base .* V121_FIELD_TARGET_FRACTIONS)))
end

function generate_shared_state_static_repairs_v121(parent_raw, static_raw)
    parent = Dict{String,Any}(_v93_plain(parent_raw))
    static = Dict{String,Any}(_v93_plain(static_raw))
    parent["protocol_id"] == V120_PROTOCOL_ID || throw(ArgumentError(
        "v121 requires a v120 profile candidate"))
    static["candidate_result_hash"] == parent["result_hash"] || throw(ArgumentError(
        "v121 static artifact is detached from parent"))
    static["candidate_state"] == "static_robustness_fail" || throw(ArgumentError(
        "v121 requires an actual static robustness failure"))
    records = Dict{String,Any}.(static["records"])
    actual_peak = maximum(Float64(record["response"]["additive_peak_field_proxy_t"])
        for record in records)
    actual_stress = maximum(Float64(record["response"][
        "membrane_support_stress_proxy_pa"]) for record in records)
    field_multipliers = static_repair_field_multipliers_v121(actual_peak)
    proposals = Dict{String,Any}[]; variant = 0
    for field_multiplier in field_multipliers,
            size_multiplier in V121_SIZE_MULTIPLIERS
        variant += 1
        point = deepcopy(parent["operating_point"])
        layout = deepcopy(parent["magnet_layout"])
        point["magnetic_field_t"] = Float64(point["magnetic_field_t"]) * field_multiplier
        point["density_m3"] = Float64(point["density_m3"]) * field_multiplier^2
        for key in ("major_radius_m", "minor_radius_m", "wall_minor_radius_m",
                "coil_minor_radius_m", "open_branch_length_m")
            point[key] = Float64(point[key]) * size_multiplier
        end
        for key in ("shield_thickness_m", "maintenance_gap_m",
                "winding_pack_thickness_m", "support_thickness_m")
            layout[key] = Float64(layout[key]) * size_multiplier
        end
        point["input_origin"] = "candidate_bound_shared_state_static_repair_v121"
        point["design_sequence"] = "actual_overrun_driven_field_and_uniform_size_scan"
        physics = solve_candidate_physics_v98(point, parent["capability_profile"])
        engineering = engineering_prefilter_v100(point, physics, layout)
        declaration = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V121_PROTOCOL_ID,
            "repair_variant_index" => variant,
            "source_actual_static_peak_field_t" => actual_peak,
            "source_actual_static_support_stress_pa" => actual_stress,
            "target_peak_field_t" => 15.0,
            "field_multiplier" => field_multiplier,
            "density_multiplier" => field_multiplier^2,
            "uniform_size_multiplier" => size_multiplier,
            "leading_beta_scaling_ratio" => 1.0,
            "prior_pass_credit" => false,
            "identity_fields_used_for_generation" => false)
        body = deepcopy(parent)
        body["protocol_id"] = V121_PROTOCOL_ID
        body["parent_protocol_id"] = parent["protocol_id"]
        body["parent_request_index"] = parent["request_index"]
        body["parent_candidate_result_hash"] = parent["result_hash"]
        body["operating_point"] = point; body["magnet_layout"] = layout
        body["physics_solve"] = physics; body["engineering_prefilter"] = engineering
        body["repair_declaration"] = declaration
        body["candidate_state"] = physics["status"] == "pass" &&
            engineering["status"] == "pass" ? "computational_candidate" :
            "repair_prefilter_reject"
        body["request_index"] = parse(Int, parent["result_hash"][1:13]; base = 16) *
            100 + variant
        body["solver_input_hash"] = canonical_hash(Dict(
            "capability_hash" => body["capability_profile"]["capability_hash"],
            "operating_point" => point, "magnet_layout" => layout,
            "equilibrium_profile_parameters" => body["equilibrium_profile_parameters"]))
        body["physical_pass_credit"] = false; body["validation_credit"] = false
        body["whole_device_credible"] = false
        body["identity_fields_used_for_routing"] = false
        body["basis_direct_metric_credit"] = false
        body["unsupported_candidate_classification_used"] = false
        body["claim_boundary"] = SHARED_STATE_STATIC_REPAIR_V121_CLAIM_BOUNDARY
        pop!(body, "result_hash", nothing); body["result_hash"] = canonical_hash(body)
        push!(proposals, body)
    end
    proposals
end
