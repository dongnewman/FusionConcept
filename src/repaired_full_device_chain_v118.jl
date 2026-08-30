const V118_PROTOCOL_ID = "fusionconceptai-v118-repaired-full-device-chain-20260830"

const REPAIRED_FULL_DEVICE_CHAIN_V118_CLAIM_BOUNDARY =
    "v118 binds a freshly executed topology candidate stream to freshly executed FreeGS, " *
    "DESC and static artifacts, then executes assembly, dynamic-fault, source-pinned " *
    "materials, multi-region conservation and channel thermal-hydraulics in order. " *
    "Sampled provider survivors remain validation-pending and receive no complete " *
    "stability, complete transport, whole-device credibility or experimental-validation credit."

function _v118_read_rows(path)
    [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in readlines(path)
        if !isempty(strip(line))]
end

function _v118_source_hashes(bundle)
    Dict{String,Any}(stage => _v115_read_json(bundle[key])["acceptance_hash"]
        for (stage, key) in (("generation", "generation_acceptance_path"),
            ("freegs", "freegs_acceptance_path"),
            ("desc", "desc_acceptance_path"),
            ("static", "static_acceptance_path")))
end

function _v118_select_conservation_assemblies(streams)
    # Normalize at the serialized artifact boundary before Pareto tie-breaking.  Generated
    # in-memory dictionaries can otherwise retain container types whose canonical encoding
    # differs from the JSONL handoff, changing only equal-score tie breaks.
    normalize(row) = Dict{String,Any}(_v93_plain(JSON3.read(JSON3.write(row))))
    assemblies = normalize.(streams["assemblies"])
    screens = normalize.(streams["screens"])
    materials = normalize.(streams["materials"])
    passing = Set(String(row["physical_design_hash"]) for row in materials if
        row["status"] == "pass")
    screen_by_hash = Dict(String(row["physical_design_hash"]) => row for row in screens)
    groups = Dict{String,Vector{Dict{String,Any}}}()
    for assembly in assemblies
        String(assembly["physical_design_hash"]) in passing || continue
        push!(get!(groups, String(assembly["source_candidate_result_hash"]),
            Dict{String,Any}[]), assembly)
    end
    selected = Dict{String,Any}[]
    for source_hash in sort!(collect(keys(groups)))
        ranked = sort!(groups[source_hash]; by = assembly -> begin
            screen = screen_by_hash[String(assembly["physical_design_hash"])]
            (-Float64(screen["outputs"]["net_electric_power_w"]),
                canonical_hash(assembly["physical_design"]))
        end)
        push!(selected, first(ranked))
    end
    selected
end

function _v118_run_conservation(frontier, v115_streams, reference)
    candidates = Dict(String(item["candidate"]["result_hash"]) => item["candidate"]
        for item in frontier)
    assemblies = _v118_select_conservation_assemblies(v115_streams)
    rows = Dict{String,Any}[]
    for assembly in assemblies
        candidate = candidates[String(assembly["source_candidate_result_hash"])]
        transport = execute_core_edge_transport_provider_v116(candidate)
        exhaust = transport["status"] == "pass" ?
            execute_sol_exhaust_provider_v116(assembly, candidate) :
            Dict{String,Any}("status" => "not_executed_upstream_reject")
        row = Dict{String,Any}(
            "source_candidate_result_hash" => candidate["result_hash"],
            "physical_design_hash" => assembly["physical_design_hash"],
            "transport" => transport, "exhaust" => exhaust,
            "candidate_state" => transport["status"] == "pass" &&
                exhaust["status"] == "pass" ? "conservation_provider_survivor" :
                "conservation_provider_reject",
            "whole_device_pass_credit" => false, "validation_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "claim_boundary" => MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
        row["result_hash"] = canonical_hash(row); push!(rows, row)
    end
    provider_failures = count(row -> row["transport"]["status"] == "provider_failure" ||
        row["exhaust"]["status"] == "provider_failure", rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V116_PROTOCOL_ID,
        "status" => provider_failures == 0 ? "complete" : "provider_system_failure",
        "reference_regression_pass_count" => 2, "reference_bypass_count" => 0,
        "source_reference_acceptance_hash" => reference["acceptance_hash"],
        "selected_source_candidate_count" => length(rows),
        "transport_pass_count" => count(row -> row["transport"]["status"] == "pass", rows),
        "exhaust_pass_count" => count(row -> row["exhaust"]["status"] == "pass", rows),
        "conservation_provider_survivor_count" => count(row ->
            row["candidate_state"] == "conservation_provider_survivor", rows),
        "conservation_provider_reject_count" => count(row ->
            row["candidate_state"] == "conservation_provider_reject", rows),
        "unsupported_candidate_count" => 0,
        "provider_system_failure_count" => provider_failures,
        "complete_transport_obligation_credit" => false,
        "complete_exhaust_obligation_credit" => false,
        "partial_subgraph_promotion_allowed" => false,
        "whole_device_credible_count" => 0, "validation_pass_count" => 0,
        "claim_boundary" => MULTIREGION_CONSERVATION_PROVIDERS_V116_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, rows
end

function _v118_select_channel_assemblies(frontier, v115_streams, v116_rows)
    normalize(row) = Dict{String,Any}(_v93_plain(JSON3.read(JSON3.write(row))))
    transport_sources = Set(String(row["source_candidate_result_hash"])
        for row in v116_rows if row["transport"]["status"] == "pass")
    material_hashes = Set(String(row["physical_design_hash"])
        for row in normalize.(v115_streams["materials"]) if row["status"] == "pass")
    eligible = [assembly for assembly in normalize.(v115_streams["assemblies"]) if
        String(assembly["physical_design_hash"]) in material_hashes &&
        String(assembly["source_candidate_result_hash"]) in transport_sources]
    screen_by_hash = Dict(String(row["physical_design_hash"]) => row
        for row in normalize.(v115_streams["screens"]))
    groups = Dict{Tuple{String,Float64,Float64},Vector{Dict{String,Any}}}()
    for assembly in eligible
        design = assembly["physical_design"]
        key = (String(assembly["source_candidate_result_hash"]),
            Float64(design["thermal_cycle"]["declared_coolant_delta_t_k"]),
            Float64(design["edge_exhaust"]["target_wetted_area_m2"]))
        push!(get!(groups, key, Dict{String,Any}[]), assembly)
    end
    representatives = Dict{String,Any}[]
    for key in sort!(collect(keys(groups)); by = canonical_hash)
        ranked = sort!(groups[key]; by = assembly -> begin
            screen = screen_by_hash[String(assembly["physical_design_hash"])]
            (-Float64(screen["outputs"]["net_electric_power_w"]),
                canonical_hash(assembly["physical_design"]))
        end)
        push!(representatives, first(ranked))
    end
    candidates = Dict(String(item["candidate"]["result_hash"]) => item["candidate"]
        for item in frontier)
    exhaust_cache = Dict{Tuple{String,Float64},Bool}()
    [assembly for assembly in representatives if get!(exhaust_cache,
        (String(assembly["source_candidate_result_hash"]), Float64(assembly[
            "physical_design"]["edge_exhaust"]["target_wetted_area_m2"]))) do
                candidate = candidates[String(assembly["source_candidate_result_hash"])]
                execute_sol_exhaust_provider_v116(assembly, candidate)["status"] == "pass"
            end]
end

function _v118_run_channel(frontier, v115_streams, v116_rows, catalog, reference)
    assemblies = _v118_select_channel_assemblies(frontier, v115_streams, v116_rows)
    screen_by_hash = Dict(String(row["physical_design_hash"]) => row
        for row in v115_streams["screens"])
    rows = Dict{String,Any}[]
    level_cache = Dict{String,Tuple{Any,Any}}()
    for assembly in assemblies, overlay in generate_channel_overlays_v117(assembly)
        thermal = assembly["physical_design"]["thermal_cycle"]
        cache_key = canonical_hash(Dict(
            "inlet_temperature_k" => thermal["inlet_temperature_k"],
            "mass_flow_kg_s" => thermal["mass_flow_kg_s"],
            "specific_heat_j_kg_k" => thermal["specific_heat_j_kg_k"],
            "recoverable_heat_input_w" => thermal["recoverable_heat_input_w"]))
        nominal_levels, fault_levels = get!(level_cache, cache_key) do
            ([_v117_channel_level(assembly, overlay, points, 1.0)
                for points in V117_MESH_LEVELS],
             [_v117_channel_level(assembly, overlay, points, 0.5)
                for points in V117_MESH_LEVELS])
        end
        push!(rows, execute_channel_thermal_hydraulics_v117(assembly, overlay,
            screen_by_hash[String(assembly["physical_design_hash"])], catalog;
            nominal_levels_raw = nominal_levels, fault_levels_raw = fault_levels))
    end
    survivors = [row for row in rows if row["status"] == "pass"]
    blockers = Dict{String,Int}()
    for row in rows, gate in String.(row["failed_gates"])
        blockers[gate] = get(blockers, gate, 0) + 1
    end
    provider_failures = count(row -> any(level -> level["status"] ==
        "provider_failure", vcat(row["nominal_mesh_levels"], row["fault_mesh_levels"])), rows)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V117_PROTOCOL_ID,
        "status" => provider_failures == 0 ? "complete" : "provider_system_failure",
        "reference_regression_pass_count" => 2, "reference_bypass_count" => 0,
        "source_reference_acceptance_hash" => reference["acceptance_hash"],
        "source_assembly_count" => length(assemblies),
        "channel_overlay_count" => length(rows),
        "channel_thermal_hydraulics_survivor_count" => length(survivors),
        "unique_survivor_assembly_count" => length(unique(String(row[
            "physical_design_hash"]) for row in survivors)),
        "unique_survivor_source_candidate_count" => length(unique(String(row[
            "source_candidate_result_hash"]) for row in survivors)),
        "channel_thermal_hydraulics_reject_count" => length(rows) - length(survivors),
        "blocker_histogram" => Dict(sort!(collect(blockers))),
        "unsupported_candidate_count" => 0,
        "provider_system_failure_count" => provider_failures,
        "complete_thermal_hydraulics_credit" => false,
        "partial_subgraph_promotion_allowed" => false,
        "whole_device_credible_count" => 0, "validation_pass_count" => 0,
        "claim_boundary" => CHANNEL_THERMAL_HYDRAULICS_V117_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, rows
end

function run_repaired_full_device_chain_v118(project_root::AbstractString, bundle_raw;
        assembly_generator = generate_corrected_whole_device_assemblies_v115)
    root = abspath(project_root); bundle = Dict{String,Any}(_v93_plain(bundle_raw))
    reference = run_mission_aware_reference_acceptance_v103(root)
    reference["status"] == "pass" && reference["reference_regression_pass_count"] == 2 &&
        reference["new_reference_bypass_count"] == 0 || throw(ArgumentError(
            "v118 requires ITER/C-2W 2/2 with no bypass"))
    frontier = load_v114_provider_frontier_v115(bundle["candidate_path"],
        bundle["freegs_results_directory"], bundle["desc_results_directory"],
        bundle["static_results_directory"])
    source_hashes = _v118_source_hashes(bundle)
    v115, v115_streams = run_corrected_whole_device_rescreen_v115(root;
        frontier_raw = frontier, source_acceptance_hashes_raw = source_hashes,
        assembly_generator = assembly_generator)
    v116, v116_rows = _v118_run_conservation(frontier, v115_streams, reference)
    catalog = load_material_property_catalog_v109(root)
    v117, v117_rows = _v118_run_channel(frontier, v115_streams, v116_rows,
        catalog, reference)
    complete = v115["status"] == "complete" && v116["status"] == "complete" &&
        v117["status"] == "complete"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V118_PROTOCOL_ID,
        "status" => complete ? "complete" : "provider_system_failure",
        "stage_order" => ["ITER_C2W_reference_regression", "whole_device_assembly",
            "available_provider_DAG", "dynamic_fault", "materials", "multiregion_transport",
            "SOL_exhaust", "channel_thermal_hydraulics", "sampled_numerical_VVUQ",
            "validation_VVUQ"],
        "reference_regression_pass_count" => 2, "reference_bypass_count" => 0,
        "source_reference_acceptance_hash" => reference["acceptance_hash"],
        "source_provider_acceptance_hashes" => source_hashes,
        "v115_acceptance_hash" => v115["acceptance_hash"],
        "v116_acceptance_hash" => v116["acceptance_hash"],
        "v117_acceptance_hash" => v117["acceptance_hash"],
        "source_candidate_count" => length(frontier),
        "material_survivor_count" => v115["material_screen_survivor_count"],
        "conservation_provider_survivor_count" => v116[
            "conservation_provider_survivor_count"],
        "sampled_whole_graph_numerical_vvuq_pass_count" => v117[
            "channel_thermal_hydraulics_survivor_count"],
        "validation_vvuq_status" => "external_evidence_required",
        "validation_pass_count" => 0, "whole_device_credible_count" => 0,
        "unsupported_candidate_count" => 0,
        "provider_system_failure_count" => v115["provider_system_failure_count"] +
            v116["provider_system_failure_count"] + v117["provider_system_failure_count"],
        "partial_subgraph_promotion_allowed" => false,
        "identity_fields_used_for_routing" => false,
        "basis_direct_metric_credit" => false,
        "claim_boundary" => REPAIRED_FULL_DEVICE_CHAIN_V118_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, Dict{String,Any}("v115" => v115, "v115_streams" => v115_streams,
        "v116" => v116, "v116_rows" => v116_rows,
        "v117" => v117, "v117_rows" => v117_rows)
end
