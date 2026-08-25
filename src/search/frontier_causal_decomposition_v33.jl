const _V33_CLAIM_BOUNDARY =
    "V33 reconstructs the 55 sealed v32 diagnostic frontier records and decomposes their executed fidelity-0 named margins and missing evaluator requirements. Domain and action routes are deterministic bookkeeping aids, not learned causal effects. It changes no gate, evaluates no robustness sample, and grants no physics, feasibility, novelty, C1, medium-fidelity, family-ranking, or promotion credit."

function _v33_margin_domain(margin_id::AbstractString)
    id = lowercase(String(margin_id))
    (occursin("validation", id) || occursin("hypothesis", id) ||
        occursin("experimental", id)) && return "evidence_validation"
    any(token -> occursin(token, id), (
        "net_electric", "fusion_gain", "auxiliary_power",
        "compression_work", "energy_recovery", "accelerator_peak_power",
        "wall_plug", "scientific_gain")) && return "power_cycle"
    any(token -> occursin(token, id), (
        "heat_flux", "neutron_wall", "target_injection", "chamber_clearing",
        "port_area", "electrode_pulse", "first_wall")) &&
        return "exhaust_and_boundary"
    any(token -> occursin(token, id), (
        "coil", "conductor_field", "current_density", "support_stress",
        "inboard_build", "outer_axial", "outer_radial", "internal_coil",
        "curvature", "insulation_field")) && return "geometry_and_magnets"
    any(token -> occursin(token, id), (
        "stability", "particle_loss", "transport", "magnetic_reynolds",
        "pressure_profile", "current_profile", "mode_specific", "flow_mach", "pulse_advection",
        "temperature_domain", "hybrid_field", "transform_share",
        "neutral_fraction", "rotation_mach")) && return "plasma_physics"
    any(token -> occursin(token, id), (
        "repetition", "lifetime", "throughput", "convergence",
        "liner_mass", "fuel_inventory", "target_factory")) &&
        return "pulsed_engineering"
    return "other_executed_constraint"
end

function _v33_action_route(domain::AbstractString)
    routes = Dict(
        "evidence_validation" => "build_known-device_validation_bridge",
        "power_cycle" => "repair_mission_consistent_power_cycle_or_generation_grammar",
        "exhaust_and_boundary" => "repair_boundary_geometry_and_heat_removal_model",
        "geometry_and_magnets" => "repair_candidate_specific_geometry_and_field_model",
        "plasma_physics" => "repair_profile_grammar_and_candidate_specific_physics_solver",
        "pulsed_engineering" => "repair_repetition_lifetime_and_throughput_model",
        "other_executed_constraint" => "inspect_unclassified_executed_constraint")
    return routes[String(domain)]
end

function _v33_count_strings(values)
    counts = Dict{String,Int}()
    for value in values
        key = String(value)
        counts[key] = get(counts, key, 0) + 1
    end
    return counts
end

function _v33_ranked_counts(counts::AbstractDict)
    rows = [Dict{String,Any}("id" => String(id), "count" => Int(count))
        for (id, count) in counts]
    sort!(rows; by = row -> (-Int(row["count"]), String(row["id"])))
    return rows
end

function causal_decompose_frontier_record_v33(
        context::RecoverableCrossTopologyContextV20, frontier_raw)
    frontier = _plain_json(frontier_raw)
    frontier["diagnostic_search_authorized"] === true || throw(ArgumentError(
        "v33 requires a v32-authorized diagnostic record"))
    frontier["five_gate_comparison_authorized"] === false ||
        throw(ArgumentError("v33 requires the v32 five-gate claim block"))
    frontier["promoted"] === false || throw(ArgumentError(
        "v33 cannot ingest a promoted record"))
    candidate = evaluate_cross_topology_candidate_v20(context,
        Int(frontier["candidate_index"]))
    compiled = candidate.prescreen.compiled
    raw_result = _plain_json(_v18_route_result(
        context.evaluators[compiled.evaluator_id], compiled.genome))
    String(raw_result["result_hash"]) == String(frontier["raw_result_hash"]) ||
        error("v33 raw-result reconstruction drifted")
    compiled.graph_hash == frontier["graph_hash"] || error(
        "v33 graph binding drifted")
    compiled.genome.physics_hash == frontier["physics_hash"] || error(
        "v33 physics binding drifted")
    nominal = get(raw_result, "nominal", Dict{String,Any}())
    raw_margins = get(nominal, "margins", nothing)
    raw_margins isa AbstractDict || error(
        "v33 record has no named nominal margin dictionary")
    margins = Dict{String,Float64}()
    for (name, raw_value) in raw_margins
        raw_value isa Real || error("v33 margin $name is not numeric")
        value = Float64(raw_value)
        isfinite(value) || error("v33 margin $name is not finite")
        margins[String(name)] = value
    end
    isempty(margins) && error("v33 record has no named margins")
    ordered = sort!(collect(margins); by = pair ->
        (Float64(last(pair)), String(first(pair))))
    named_rows = [Dict{String,Any}(
        "margin_id" => String(name),
        "value" => Float64(value),
        "domain" => _v33_margin_domain(String(name)),
        "failed" => Float64(value) < 0.0) for (name, value) in ordered]
    failed_rows = [deepcopy(row) for row in named_rows if row["failed"]]
    primary = first(named_rows)
    Float64(primary["value"]) == Float64(
        frontier["minimum_normalized_margin"]) || error(
        "v33 named minimum does not match v32")
    domain = String(primary["domain"])
    missing = sort!(String.(copy(frontier["missing_proxy_requirements"])))
    return Dict{String,Any}(
        "candidate_index" => Int(frontier["candidate_index"]),
        "assembly_index" => Int(frontier["assembly_index"]),
        "sample_ordinal" => Int(frontier["sample_ordinal"]),
        "family" => String(frontier["family"]),
        "graph_hash" => String(frontier["graph_hash"]),
        "physics_hash" => String(frontier["physics_hash"]),
        "module_ids" => String.(copy(frontier["module_ids"])),
        "semantic_gate_pass_count" => Int(
            frontier["semantic_gate_pass_count"]),
        "failed_semantic_gates" => String.(copy(
            frontier["failed_semantic_gates"])),
        "primary_limiting_margin" => deepcopy(primary),
        "limiting_named_margins" => first(named_rows,
            min(5, length(named_rows))),
        "failed_named_margins" => failed_rows,
        "failed_named_margin_count" => length(failed_rows),
        "near_zero_failed_margin_count" => count(row ->
            -0.25 <= Float64(row["value"]) < 0.0, failed_rows),
        "named_margin_count" => length(named_rows),
        "missing_proxy_requirements" => missing,
        "missing_proxy_requirement_count" => length(missing),
        "primary_failure_domain" => domain,
        "recommended_repair_route" => _v33_action_route(domain),
        "raw_result_hash" => String(raw_result["result_hash"]),
        "raw_result_reconstruction_match" => true,
        "diagnostic_decomposition_authorized" => true,
        "five_gate_comparison_authorized" => false,
        "robustness_evaluation_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promoted" => false,
        "claim_level" => "C0_failure_causal_bookkeeping_only")
end

function _v33_summary(rows)
    primary_ids = String[row["primary_limiting_margin"]["margin_id"]
        for row in rows]
    primary_domains = String[row["primary_failure_domain"] for row in rows]
    failed_ids = String[item["margin_id"] for row in rows
        for item in row["failed_named_margins"]]
    missing_ids = String[item for row in rows
        for item in row["missing_proxy_requirements"]]
    routes = String[row["recommended_repair_route"] for row in rows]
    return Dict{String,Any}(
        "record_count" => length(rows),
        "primary_margin_counts" => _v33_count_strings(primary_ids),
        "primary_domain_counts" => _v33_count_strings(primary_domains),
        "failed_margin_counts" => _v33_count_strings(failed_ids),
        "missing_requirement_counts" => _v33_count_strings(missing_ids),
        "repair_route_counts" => _v33_count_strings(routes),
        "top_primary_margins" => _v33_ranked_counts(
            _v33_count_strings(primary_ids)),
        "top_failed_margins" => _v33_ranked_counts(
            _v33_count_strings(failed_ids)),
        "top_missing_requirements" => _v33_ranked_counts(
            _v33_count_strings(missing_ids)),
        "raw_reconstruction_count" => count(row ->
            row["raw_result_reconstruction_match"] === true, rows),
        "promotion_count" => count(row -> row["promoted"] === true, rows),
        "medium_fidelity_authorized_count" => count(row ->
            row["medium_fidelity_authorized"] === true, rows))
end

function aggregate_frontier_causal_decomposition_v33(records::AbstractVector;
        expected_families::Integer = 11, expected_per_family::Integer = 5)
    rows = [Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in record) for record in records]
    length(rows) == Int(expected_families) * Int(expected_per_family) ||
        throw(ArgumentError("v33 frontier size changed"))
    families = sort!(unique(String(row["family"]) for row in rows))
    length(families) == Int(expected_families) || throw(ArgumentError(
        "v33 family count changed"))
    family_summaries = Dict{String,Any}()
    for family in families
        family_rows = [row for row in rows if row["family"] == family]
        length(family_rows) == Int(expected_per_family) || throw(ArgumentError(
            "v33 per-family frontier count changed for $family"))
        family_summaries[family] = _v33_summary(family_rows)
    end
    global_summary = _v33_summary(rows)
    primary_families = Dict{String,Set{String}}()
    for row in rows
        id = String(row["primary_limiting_margin"]["margin_id"])
        push!(get!(primary_families, id, Set{String}()), String(row["family"]))
    end
    systemic = [Dict{String,Any}(
        "margin_id" => id,
        "family_count" => length(family_set),
        "families" => sort!(collect(family_set)),
        "record_count" => Int(global_summary["primary_margin_counts"][id]))
        for (id, family_set) in primary_families if length(family_set) >= 2]
    sort!(systemic; by = row -> (-Int(row["family_count"]),
        -Int(row["record_count"]), String(row["margin_id"])))
    return Dict{String,Any}(
        "record_count" => length(rows),
        "family_count" => length(families),
        "records_per_family" => Int(expected_per_family),
        "global_summary" => global_summary,
        "family_summaries" => family_summaries,
        "systemic_primary_margins" => systemic,
        "all_raw_results_reconstructed" => global_summary[
            "raw_reconstruction_count"] == length(rows),
        "diagnostic_decomposition_authorized" => true,
        "five_gate_comparison_authorized" => false,
        "robustness_evaluation_authorized" => false,
        "promotion_count" => 0,
        "medium_fidelity_authorized_count" => 0,
        "claim_boundary" => _V33_CLAIM_BOUNDARY)
end
