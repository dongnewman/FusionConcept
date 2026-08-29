const V112_PROTOCOL_ID = "fusionconceptai-v112-fine-static-margin-bracket-20260829"

const FINE_STATIC_MARGIN_BRACKET_V112_CLAIM_BOUNDARY =
    "v112 explores a declared fine winding-pack bracket between the v111 static-field " *
    "failure and the neighboring sampled-Mercier failure. Every coordinate is an explicit " *
    "geometry proposal and receives no metric credit; reduced physics, FreeGS, DESC and all " *
    "nine static perturbations must be recomputed before any candidate disposition."

const V112_PACK_MULTIPLIERS = [1.02, 1.04, 1.06, 1.08, 1.10, 1.12, 1.14]

function generate_fine_static_margin_bracket_v112(parent_raw, static_raw)
    parent = Dict{String,Any}(_v93_plain(parent_raw))
    static = Dict{String,Any}(_v93_plain(static_raw))
    parent["protocol_id"] == V111_PROTOCOL_ID || throw(ArgumentError(
        "v112 requires a v111 repair parent"))
    parent["repair_declaration"]["repair_variant_index"] == 1 ||
        throw(ArgumentError("v112 requires the v111 lower-bracket variant"))
    static["candidate_state"] == "static_robustness_fail" || throw(ArgumentError(
        "v112 requires a v111 static failure"))
    static["candidate_result_hash"] == parent["result_hash"] || throw(ArgumentError(
        "v112 parent/static binding mismatch"))
    old_point = Dict{String,Any}(parent["operating_point"])
    old_layout = Dict{String,Any}(parent["magnet_layout"])
    old_pack = Float64(old_layout["winding_pack_thickness_m"])
    old_major = Float64(old_point["major_radius_m"])
    actual_field = maximum(Float64(record["response"][
        "additive_peak_field_proxy_t"]) for record in Dict{String,Any}.(static["records"]))
    actual_current = maximum(Float64(record["response"][
        "maximum_pf_current_a_turn"]) for record in Dict{String,Any}.(static["records"]))
    proposals = Dict{String,Any}[]
    for (variant, multiplier) in enumerate(V112_PACK_MULTIPLIERS)
        point = deepcopy(old_point); layout = deepcopy(old_layout)
        pack = old_pack * multiplier
        major = old_major + 0.5(pack - old_pack)
        point["major_radius_m"] = major
        point["coil_minor_radius_m"] = Float64(point["wall_minor_radius_m"]) +
            Float64(layout["maintenance_gap_m"]) + pack
        point["open_branch_length_m"] = Float64(point["open_branch_length_m"]) *
            major / old_major
        point["input_origin"] = "candidate_bound_fine_static_margin_bracket_v112"
        point["design_sequence"] = "declared_winding_pack_bracket_no_metric_credit"
        layout["winding_pack_thickness_m"] = pack
        physics = solve_candidate_physics_v98(point, parent["capability_profile"])
        engineering = engineering_prefilter_v100(point, physics, layout)
        bracket = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V112_PROTOCOL_ID,
            "bracket_variant_index" => variant,
            "pack_multiplier_from_v111_lower_bracket" => multiplier,
            "source_actual_static_peak_field_t" => actual_field,
            "source_actual_maximum_pf_current_a_turn" => actual_current,
            "prior_winding_pack_thickness_m" => old_pack,
            "proposed_winding_pack_thickness_m" => pack,
            "prior_major_radius_m" => old_major, "proposed_major_radius_m" => major,
            "basis_direct_metric_credit" => false,
            "identity_fields_used_for_generation" => false)
        request_index = Int(parent["request_index"]) * 10 + variant
        body = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V112_PROTOCOL_ID,
            "request_index" => request_index,
            "parent_request_index" => parent["request_index"],
            "parent_candidate_result_hash" => parent["result_hash"],
            "graph_hash" => parent["graph_hash"],
            "capability_profile" => deepcopy(parent["capability_profile"]),
            "operating_point" => point, "magnet_layout" => layout,
            "physics_solve" => physics, "engineering_prefilter" => engineering,
            "bracket_declaration" => bracket,
            "candidate_state" => physics["status"] == "pass" &&
                engineering["status"] == "pass" ? "computational_candidate" :
                "bracket_prefilter_reject",
            "physical_pass_credit" => false, "validation_credit" => false,
            "identity_fields_used_for_routing" => false,
            "basis_direct_metric_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "claim_boundary" => FINE_STATIC_MARGIN_BRACKET_V112_CLAIM_BOUNDARY)
        body["solver_input_hash"] = canonical_hash(Dict(
            "capability_hash" => body["capability_profile"]["capability_hash"],
            "operating_point" => point, "magnet_layout" => layout))
        body["result_hash"] = canonical_hash(body)
        push!(proposals, body)
    end
    proposals
end

function run_fine_static_margin_bracket_generation_v112(project_root::AbstractString)
    root = abspath(project_root)
    directory = joinpath(root, "runs", "v111_static_margin_repair_20260829")
    candidates = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "candidates.jsonl")) if !isempty(strip(line))]
    desc = _v110_read_json(joinpath(directory, "desc", "acceptance.json"))
    indices = [Int(row["request_index"]) for row in desc["rows"] if
        row["candidate_state"] == "sampled_ideal_mhd_candidate"]
    length(indices) == 1 || throw(ArgumentError(
        "v112 requires exactly one v111 DESC survivor"))
    index = only(indices)
    parent = only(item for item in candidates if Int(item["request_index"]) == index)
    static = _v110_read_json(joinpath(directory, "static", "results",
        "static_$(index).json"))
    proposals = generate_fine_static_margin_bracket_v112(parent, static)
    retained = [item for item in proposals if item["candidate_state"] ==
        "computational_candidate"]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V112_PROTOCOL_ID,
        "status" => length(retained) == length(proposals) ? "complete" :
            "bracket_prefilter_reject",
        "source_desc_acceptance_hash" => desc["acceptance_hash"],
        "source_static_result_hash" => static["result_hash"],
        "bracket_proposal_count" => length(proposals),
        "bracket_prefilter_survivor_count" => length(retained),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "physical_pass_credit" => false, "validation_credit" => false,
        "identity_fields_used_for_generation" => false,
        "basis_direct_metric_credit" => false,
        "claim_boundary" => FINE_STATIC_MARGIN_BRACKET_V112_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, retained
end
