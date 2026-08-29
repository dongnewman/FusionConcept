const V111_PROTOCOL_ID = "fusionconceptai-v111-static-margin-repair-20260829"

const STATIC_MARGIN_REPAIR_V111_CLAIM_BOUNDARY =
    "v111 repairs only the explicit winding-pack and support geometry of v110 DESC " *
    "survivors using their worst nine-case PF current as a sizing load. The repaired major " *
    "radius and all reduced physics are recomputed, and every proposal must rerun FreeGS, " *
    "DESC and static perturbations. The prior failure is never converted into a pass, and " *
    "the repair calculation grants no provider, validation or whole-device credit."

const V111_TARGET_STATIC_PEAK_FIELD_T = 15.0
const V111_PACK_MARGIN_MULTIPLIERS = [1.0, 1.15, 1.30]

function _v111_predicted_static_field(parent, maximum_pf_current, pack)
    point = Dict{String,Any}(parent["operating_point"])
    layout = Dict{String,Any}(parent["magnet_layout"])
    engineering = Dict{String,Any}(parent["engineering_prefilter"])
    metrics = Dict{String,Any}(engineering["metrics"])
    old_pack = Float64(layout["winding_pack_thickness_m"])
    old_major = Float64(point["major_radius_m"])
    inner_center = Float64(metrics["inner_pf_center_major_radius_m"])
    field = Float64(point["magnetic_field_t"])
    repaired_major = old_major + 0.5(pack - old_pack)
    field * repaired_major / inner_center + 4e-7maximum_pf_current / pack
end

function _v111_minimum_pack(parent, maximum_pf_current;
        target = V111_TARGET_STATIC_PEAK_FIELD_T)
    layout = Dict{String,Any}(parent["magnet_layout"])
    low = Float64(layout["winding_pack_thickness_m"])
    high = low
    while _v111_predicted_static_field(parent, maximum_pf_current, high) > target &&
            high < 12.0
        high *= 1.10
    end
    high < 12.0 || throw(ArgumentError(
        "v111 could not find a finite winding-pack repair below 12 m"))
    for _ in 1:80
        middle = 0.5(low + high)
        if _v111_predicted_static_field(parent, maximum_pf_current, middle) > target
            low = middle
        else
            high = middle
        end
    end
    high
end

function generate_static_margin_repairs_v111(parent_raw, static_raw)
    parent = Dict{String,Any}(_v93_plain(parent_raw))
    static = Dict{String,Any}(_v93_plain(static_raw))
    static["candidate_state"] == "static_robustness_fail" || throw(ArgumentError(
        "v111 requires a v110 static-robustness failure"))
    static["candidate_result_hash"] == parent["result_hash"] || throw(ArgumentError(
        "v111 parent/static artifact binding mismatch"))
    maximum_pf_current = maximum(Float64(record["response"][
        "maximum_pf_current_a_turn"]) for record in Dict{String,Any}.(static["records"]))
    base_pack = _v111_minimum_pack(parent, maximum_pf_current)
    proposals = Dict{String,Any}[]
    for (variant, multiplier) in enumerate(V111_PACK_MARGIN_MULTIPLIERS)
        point = deepcopy(Dict{String,Any}(parent["operating_point"]))
        layout = deepcopy(Dict{String,Any}(parent["magnet_layout"]))
        old_major = Float64(point["major_radius_m"])
        old_pack = Float64(layout["winding_pack_thickness_m"])
        pack = base_pack * multiplier
        major = old_major + 0.5(pack - old_pack)
        point["major_radius_m"] = major
        point["coil_minor_radius_m"] = Float64(point["wall_minor_radius_m"]) +
            Float64(layout["maintenance_gap_m"]) + pack
        point["open_branch_length_m"] = Float64(point["open_branch_length_m"]) *
            major / old_major
        point["input_origin"] = "candidate_bound_static_margin_geometry_repair_v111"
        point["design_sequence"] = "explicit_winding_pack_repair_from_static_load"
        layout["winding_pack_thickness_m"] = pack
        layout["support_thickness_m"] = 1.20Float64(layout["support_thickness_m"])
        physics = solve_candidate_physics_v98(point, parent["capability_profile"])
        engineering = engineering_prefilter_v100(point, physics, layout)
        repair = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V111_PROTOCOL_ID,
            "repair_variant_index" => variant,
            "source_static_result_hash" => static["result_hash"],
            "source_worst_pf_current_a_turn" => maximum_pf_current,
            "target_static_peak_field_t" => V111_TARGET_STATIC_PEAK_FIELD_T,
            "pack_margin_multiplier" => multiplier,
            "predicted_static_peak_field_t" => _v111_predicted_static_field(
                parent, maximum_pf_current, pack),
            "prior_winding_pack_thickness_m" => old_pack,
            "repaired_winding_pack_thickness_m" => pack,
            "prior_major_radius_m" => old_major, "repaired_major_radius_m" => major,
            "basis_direct_metric_credit" => false,
            "identity_fields_used_for_generation" => false)
        request_index = Int(parent["request_index"]) * 10 + variant
        body = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V111_PROTOCOL_ID,
            "request_index" => request_index,
            "parent_request_index" => parent["request_index"],
            "parent_candidate_result_hash" => parent["result_hash"],
            "graph_hash" => parent["graph_hash"],
            "capability_profile" => deepcopy(parent["capability_profile"]),
            "operating_point" => point, "magnet_layout" => layout,
            "physics_solve" => physics, "engineering_prefilter" => engineering,
            "repair_declaration" => repair,
            "candidate_state" => physics["status"] == "pass" &&
                engineering["status"] == "pass" ? "computational_candidate" :
                "repair_prefilter_reject",
            "physical_pass_credit" => false, "validation_credit" => false,
            "identity_fields_used_for_routing" => false,
            "basis_direct_metric_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "claim_boundary" => STATIC_MARGIN_REPAIR_V111_CLAIM_BOUNDARY)
        body["solver_input_hash"] = canonical_hash(Dict(
            "capability_hash" => body["capability_profile"]["capability_hash"],
            "operating_point" => point, "magnet_layout" => layout))
        body["result_hash"] = canonical_hash(body)
        push!(proposals, body)
    end
    proposals
end

function run_static_margin_repair_generation_v111(project_root::AbstractString)
    root = abspath(project_root)
    directory = joinpath(root, "runs", "v110_material_closed_frontier_20260829")
    candidates = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(joinpath(directory, "candidates.jsonl")) if !isempty(strip(line))]
    candidate_by_index = Dict(Int(item["request_index"]) => item for item in candidates)
    desc = _v110_read_json(joinpath(directory, "desc", "acceptance.json"))
    survivor_indices = sort!([Int(row["request_index"]) for row in desc["rows"] if
        row["candidate_state"] == "sampled_ideal_mhd_candidate"])
    proposals = Dict{String,Any}[]
    for index in survivor_indices
        static = _v110_read_json(joinpath(directory, "static", "results",
            "static_$(index).json"))
        append!(proposals, generate_static_margin_repairs_v111(
            candidate_by_index[index], static))
    end
    retained = [item for item in proposals if item["candidate_state"] ==
        "computational_candidate"]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V111_PROTOCOL_ID,
        "status" => length(retained) == length(proposals) ? "complete" :
            "repair_prefilter_reject",
        "source_desc_acceptance_hash" => desc["acceptance_hash"],
        "source_static_failure_count" => length(survivor_indices),
        "repair_proposal_count" => length(proposals),
        "repair_prefilter_survivor_count" => length(retained),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "whole_device_pass_count" => 0, "validation_pass_count" => 0,
        "identity_fields_used_for_generation" => false,
        "basis_direct_metric_credit" => false,
        "claim_boundary" => STATIC_MARGIN_REPAIR_V111_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, retained
end
