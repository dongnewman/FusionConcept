const V114_PROTOCOL_ID = "fusionconceptai-v114-similarity-scaled-field-repair-20260830"

const SIMILARITY_SCALED_FIELD_REPAIR_V114_CLAIM_BOUNDARY =
    "v114 couples a declared lower-field, beta-preserving density scan with uniform scaling " *
    "of all principal device and radial-build dimensions. The scale coordinates are proposal " *
    "inputs only; power, equilibrium, stability and engineering metrics are recomputed. Every " *
    "retained proposal must rerun FreeGS, DESC and nine static perturbations, with no identity, " *
    "basis or prior-pass credit."

const V114_FIELD_MULTIPLIERS = [0.90, 0.92, 0.94]
const V114_SIZE_MULTIPLIERS = [1.15, 1.25, 1.35]

function generate_similarity_scaled_field_repairs_v114(parent_raw, static_raw)
    parent = Dict{String,Any}(_v93_plain(parent_raw))
    static = Dict{String,Any}(_v93_plain(static_raw))
    parent["protocol_id"] == V112_PROTOCOL_ID || throw(ArgumentError(
        "v114 requires the v112 stable lower-pack bracket parent"))
    static["candidate_state"] == "static_robustness_fail" || throw(ArgumentError(
        "v114 requires its v112 static field failure"))
    static["candidate_result_hash"] == parent["result_hash"] || throw(ArgumentError(
        "v114 parent/static binding mismatch"))
    base_point = Dict{String,Any}(parent["operating_point"])
    base_layout = Dict{String,Any}(parent["magnet_layout"])
    actual_field = maximum(Float64(record["response"][
        "additive_peak_field_proxy_t"]) for record in Dict{String,Any}.(static["records"]))
    proposals = Dict{String,Any}[]; variant = 0
    for field_multiplier in V114_FIELD_MULTIPLIERS,
            size_multiplier in V114_SIZE_MULTIPLIERS
        variant += 1
        point = deepcopy(base_point); layout = deepcopy(base_layout)
        point["magnetic_field_t"] = Float64(base_point["magnetic_field_t"]) *
            field_multiplier
        point["density_m3"] = Float64(base_point["density_m3"]) * field_multiplier^2
        for key in ("major_radius_m", "minor_radius_m", "wall_minor_radius_m",
                "coil_minor_radius_m", "open_branch_length_m")
            point[key] = Float64(base_point[key]) * size_multiplier
        end
        for key in ("shield_thickness_m", "maintenance_gap_m",
                "winding_pack_thickness_m", "support_thickness_m")
            layout[key] = Float64(base_layout[key]) * size_multiplier
        end
        point["input_origin"] = "candidate_bound_similarity_scaled_field_repair_v114"
        point["design_sequence"] = "declared_field_density_size_scan_no_metric_credit"
        physics = solve_candidate_physics_v98(point, parent["capability_profile"])
        engineering = engineering_prefilter_v100(point, physics, layout)
        declaration = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V114_PROTOCOL_ID,
            "repair_variant_index" => variant,
            "field_multiplier" => field_multiplier,
            "density_multiplier" => field_multiplier^2,
            "uniform_size_multiplier" => size_multiplier,
            "source_actual_static_peak_field_t" => actual_field,
            "leading_beta_scaling_ratio" => 1.0,
            "uniform_dimension_keys" => ["major_radius_m", "minor_radius_m",
                "wall_minor_radius_m", "coil_minor_radius_m", "open_branch_length_m",
                "shield_thickness_m", "maintenance_gap_m",
                "winding_pack_thickness_m", "support_thickness_m"],
            "basis_direct_metric_credit" => false,
            "identity_fields_used_for_generation" => false)
        request_index = Int(parent["request_index"]) * 100 + variant
        body = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V114_PROTOCOL_ID,
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
            "claim_boundary" => SIMILARITY_SCALED_FIELD_REPAIR_V114_CLAIM_BOUNDARY)
        body["solver_input_hash"] = canonical_hash(Dict(
            "capability_hash" => body["capability_profile"]["capability_hash"],
            "operating_point" => point, "magnet_layout" => layout))
        body["result_hash"] = canonical_hash(body)
        push!(proposals, body)
    end
    proposals
end

function run_similarity_scaled_field_repair_generation_v114(project_root::AbstractString)
    root = abspath(project_root)
    directory = joinpath(root, "runs", "v112_fine_static_margin_bracket_20260829")
    candidates = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "candidates.jsonl")) if !isempty(strip(line))]
    desc = _v110_read_json(joinpath(directory, "desc", "acceptance.json"))
    indices = [Int(row["request_index"]) for row in desc["rows"] if
        row["candidate_state"] == "sampled_ideal_mhd_candidate"]
    length(indices) == 1 || throw(ArgumentError(
        "v114 requires exactly one v112 DESC survivor"))
    index = only(indices)
    parent = only(item for item in candidates if Int(item["request_index"]) == index)
    static = _v110_read_json(joinpath(directory, "static", "results",
        "static_$(index).json"))
    proposals = generate_similarity_scaled_field_repairs_v114(parent, static)
    retained = [item for item in proposals if item["candidate_state"] ==
        "computational_candidate"]
    rejected = [item for item in proposals if item["candidate_state"] ==
        "repair_prefilter_reject"]
    blockers = Dict{String,Int}()
    for item in rejected
        for gate in String.(item["physics_solve"]["failed_gates"])
            key = "physics:" * gate; blockers[key] = get(blockers, key, 0) + 1
        end
        for gate in String.(item["engineering_prefilter"]["failed_gates"])
            key = "engineering:" * gate; blockers[key] = get(blockers, key, 0) + 1
        end
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V114_PROTOCOL_ID,
        "status" => "complete", "source_desc_acceptance_hash" =>
            desc["acceptance_hash"], "source_static_result_hash" => static["result_hash"],
        "repair_proposal_count" => length(proposals),
        "repair_prefilter_survivor_count" => length(retained),
        "repair_prefilter_reject_count" => length(rejected),
        "repair_prefilter_blocker_histogram" => Dict(sort!(collect(blockers))),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "physical_pass_credit" => false, "validation_credit" => false,
        "identity_fields_used_for_generation" => false,
        "basis_direct_metric_credit" => false,
        "claim_boundary" => SIMILARITY_SCALED_FIELD_REPAIR_V114_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, retained
end
