const _V32_CLAIM_BOUNDARY =
    "V32 executes a recoverable diagnostic failure-frontier QD search over 22 new Halton samples for every graph in the 1,000-topology v17/v20 archive. It uses v31 family q10/q90 margins only for monotone normalization and diversity bins; no gate threshold is changed. Graph and mechanism archives preserve topology and failure diversity, but constant physics labels, skipped robustness, and incomplete evidence remain explicit blockers. No record can create an algorithm-superiority, C1, medium-fidelity, novelty, feasibility, or promotion claim."

struct DiagnosticCrossFamilyContextV32
    cross_topology::RecoverableCrossTopologyContextV20
    margin_anchors::Dict{String,Tuple{Float64,Float64}}
    v31_result_hash::String
end

function build_diagnostic_cross_family_context_v32(
        cross_topology::RecoverableCrossTopologyContextV20,
        v31_artifact_raw)
    v31 = _plain_json(v31_artifact_raw)
    get(v31, "result_hash", "") ==
        "60f69caeb5306c7cb41259e1cb0f9da72286491fac4a734e29ede9246fe721c1" ||
        throw(ArgumentError("v32 requires sealed v31 gate observability evidence"))
    aggregate = v31["aggregate"]
    aggregate["diagnostic_failure_frontier_search_authorized"] === true ||
        throw(ArgumentError("v31 did not authorize v32 diagnostic search"))
    aggregate["five_gate_acquisition_transfer_authorized"] === false ||
        throw(ArgumentError("v32 requires the v31 five-gate claim block"))
    anchors = Dict{String,Tuple{Float64,Float64}}()
    for (family, summary) in aggregate["family_summaries"]
        quantiles = summary["minimum_normalized_margin_quantiles"]
        q10 = Float64(quantiles["q10"])
        q90 = Float64(quantiles["q90"])
        q90 > q10 || throw(ArgumentError(
            "v32 margin anchors collapsed for $family"))
        anchors[String(family)] = (q10, q90)
    end
    Set(keys(anchors)) == Set(assembly.family for assembly in
        cross_topology.assemblies) || throw(ArgumentError(
        "v32 margin anchors do not cover the 11-family archive"))
    return DiagnosticCrossFamilyContextV32(cross_topology, anchors,
        String(v31["result_hash"]))
end

function _v32_normalized_margin(context::DiagnosticCrossFamilyContextV32,
        family::String, raw_margin)
    raw_margin === nothing && return -Inf
    q10, q90 = context.margin_anchors[family]
    return (Float64(raw_margin) - q10) / (q90 - q10)
end

function _v32_margin_bin(value::Float64)
    !isfinite(value) && return "missing"
    value < -1.0 && return "lt_-1"
    value < -0.5 && return "-1_to_-0.5"
    value < 0.0 && return "-0.5_to_0"
    value < 0.5 && return "0_to_0.5"
    value < 1.0 && return "0.5_to_1"
    value < 2.0 && return "1_to_2"
    return "ge_2"
end

function _v32_missing_bucket(count_value::Int)
    count_value == 0 && return "0"
    count_value <= 3 && return "1_to_3"
    count_value <= 6 && return "4_to_6"
    count_value <= 9 && return "7_to_9"
    return "ge_10"
end

function _v32_failure_signature(gates::AbstractDict)
    return join(Int(gates[gate] === true) for gate in
        _V31_SEMANTIC_GATE_IDS)
end

function evaluate_diagnostic_cross_family_candidate_v32(
        context::DiagnosticCrossFamilyContextV32,
        logical_candidate_index::Integer; candidate_offset::Integer = 10_000,
        halton_skip::Integer = 4096)
    logical_candidate_index > 0 || throw(ArgumentError(
        "v32 logical candidate index must be positive"))
    physical_index = Int(candidate_offset) + Int(logical_candidate_index)
    record = audit_cross_topology_candidate_v31(context.cross_topology,
        physical_index; halton_skip = Int(halton_skip))
    family = String(record["family"])
    normalized_margin = _v32_normalized_margin(context, family,
        record["minimum_normalized_margin"])
    missing_count = Int(record["missing_proxy_requirement_count"])
    gates = record["semantic_gates"]
    failed_gates = sort!(String[gate for gate in _V31_SEMANTIC_GATE_IDS
        if gates[gate] !== true])
    item = deepcopy(record)
    item["logical_candidate_index"] = Int(logical_candidate_index)
    item["candidate_offset"] = Int(candidate_offset)
    item["normalized_family_margin"] = normalized_margin
    item["normalized_margin_bin"] = _v32_margin_bin(normalized_margin)
    item["missing_requirement_bucket"] = _v32_missing_bucket(missing_count)
    item["failure_signature"] = _v32_failure_signature(gates)
    item["failed_semantic_gates"] = failed_gates
    item["mechanism_qd_cell"] = join((family,
        String(item["failure_signature"]),
        String(item["normalized_margin_bin"]),
        String(item["missing_requirement_bucket"])), "|")
    item["next_evidence_actions"] = first(sort!(String.(copy(
        item["missing_proxy_requirements"]))), min(5, missing_count))
    item["diagnostic_search_authorized"] = true
    item["five_gate_comparison_authorized"] = false
    item["promoted"] = false
    item["medium_fidelity_authorized"] = false
    item["novelty_claimed"] = false
    item["claim_level"] = "C0_diagnostic_failure_frontier_only"
    return item
end

function recoverable_diagnostic_cross_family_spec_v32(
        context::DiagnosticCrossFamilyContextV32,
        total_candidates::Integer, shard_size::Integer;
        run_id::AbstractString = "diagnostic_cross_family_qd_v32",
        candidate_offset::Integer = 10_000,
        max_retries::Integer = 2, halton_skip::Integer = 4096,
        source_sha256::AbstractString)
    total_candidates > 0 || throw(ArgumentError(
        "v32 total_candidates must be positive"))
    shard_size > 0 || throw(ArgumentError("v32 shard_size must be positive"))
    length(source_sha256) == 64 || throw(ArgumentError(
        "v32 source_sha256 must be a full hash"))
    return RecoverableRunSpecV19(String(run_id),
        "diagnostic_cross_family_failure_frontier_kernel", "32.0.0",
        Int(total_candidates), Int(shard_size);
        max_retries = Int(max_retries),
        max_retained_per_shard = Int(shard_size),
        kernel_config = Dict{String,Any}(
            "topology_archive_size" => length(
                context.cross_topology.assemblies),
            "topology_archive_hash" => context.cross_topology.archive_hash,
            "topology_catalog_hash" => context.cross_topology.catalog_hash,
            "v31_result_hash" => context.v31_result_hash,
            "candidate_offset" => Int(candidate_offset),
            "halton_skip" => Int(halton_skip),
            "v32_source_sha256" => String(source_sha256),
            "retain_policy" => "all_diagnostic_records",
            "claim_boundary" => _V32_CLAIM_BOUNDARY))
end

function recoverable_diagnostic_cross_family_kernel_v32(
        context::DiagnosticCrossFamilyContextV32)
    return function(logical_candidate_index::Int, config::Dict{String,Any})
        String(config["v31_result_hash"]) == context.v31_result_hash ||
            throw(ArgumentError("v32 kernel v31 binding drifted"))
        Int(config["topology_archive_size"]) == length(
            context.cross_topology.assemblies) || throw(ArgumentError(
            "v32 kernel topology count drifted"))
        String(config["topology_archive_hash"]) ==
            context.cross_topology.archive_hash || throw(ArgumentError(
            "v32 kernel topology archive drifted"))
        record = evaluate_diagnostic_cross_family_candidate_v32(context,
            logical_candidate_index;
            candidate_offset = Int(config["candidate_offset"]),
            halton_skip = Int(config["halton_skip"]))
        return RecoverableKernelOutcomeV19(record, true)
    end
end

function _v32_robustness_rank(state::AbstractString)
    state == "pass" && return 0
    state == "evaluated_fail" && return 1
    return 2
end

function _v32_diagnostic_rank(record::AbstractDict)
    normalized = Float64(record["normalized_family_margin"])
    finite_margin = isfinite(normalized) ? normalized : -1.0e12
    return (
        -Int(record["semantic_gate_pass_count"]),
        -finite_margin,
        _v32_robustness_rank(String(record["robustness_state"])),
        Int(record["missing_proxy_requirement_count"]),
        record["positive_net_power_closure"] === true ? 0 : 1,
        String(record["physics_hash"]),
    )
end

function _v32_insert_best!(cells::Dict{String,Dict{String,Any}},
        key::String, record::AbstractDict)
    item = Dict{String,Any}(String(name) => _plain_json(value)
        for (name, value) in record)
    incumbent = get(cells, key, nothing)
    if incumbent === nothing || _v32_diagnostic_rank(item) <
            _v32_diagnostic_rank(incumbent)
        cells[key] = item
    end
    return cells
end

function diagnostic_cross_family_qd_archives_v32(records::AbstractVector;
        frontier_per_family::Integer = 5)
    isempty(records) && throw(ArgumentError("v32 requires diagnostic records"))
    frontier_per_family > 0 || throw(ArgumentError(
        "v32 frontier_per_family must be positive"))
    graph_cells = Dict{String,Dict{String,Any}}()
    mechanism_cells = Dict{String,Dict{String,Any}}()
    families = Dict{String,Vector{Dict{String,Any}}}()
    for raw in records
        record = Dict{String,Any}(String(name) => _plain_json(value)
            for (name, value) in raw)
        _v32_insert_best!(graph_cells, String(record["graph_hash"]), record)
        _v32_insert_best!(mechanism_cells,
            String(record["mechanism_qd_cell"]), record)
        push!(get!(families, String(record["family"]),
            Dict{String,Any}[]), record)
    end
    graph_archive = sort!(collect(values(graph_cells)); by = record ->
        String(record["graph_hash"]))
    mechanism_archive = sort!(collect(values(mechanism_cells)); by = record ->
        String(record["mechanism_qd_cell"]))
    frontier = Dict{String,Any}[]
    for family in sort!(collect(keys(families)))
        ranked = sort!(families[family]; by = _v32_diagnostic_rank)
        seen_graphs = Set{String}()
        for record in ranked
            graph = String(record["graph_hash"])
            graph in seen_graphs && continue
            push!(seen_graphs, graph)
            push!(frontier, record)
            length(seen_graphs) >= frontier_per_family && break
        end
        length(seen_graphs) == frontier_per_family || error(
            "v32 could not fill frontier for $family")
    end
    global_gate_counts = Dict(gate => count(record ->
        record["semantic_gates"][gate] === true, records) for gate in
        _V31_SEMANTIC_GATE_IDS)
    family_summaries = Dict{String,Any}()
    for family in sort!(collect(keys(families)))
        rows = families[family]
        family_summaries[family] = Dict{String,Any}(
            "record_count" => length(rows),
            "graph_count" => length(unique(String(record["graph_hash"])
                for record in rows)),
            "semantic_gate_pass_counts" => Dict(gate => count(record ->
                record["semantic_gates"][gate] === true, rows)
                for gate in _V31_SEMANTIC_GATE_IDS),
            "positive_net_count" => count(record ->
                record["positive_net_power_closure"] === true, rows),
            "evidence_complete_count" => count(record ->
                record["evidence_coverage_state"] == "complete", rows),
            "robustness_evaluated_count" => count(record ->
                record["robustness_state"] !=
                    "not_evaluated_nominal_failure", rows),
            "best_normalized_family_margin" => maximum(Float64(
                record["normalized_family_margin"]) for record in rows),
            "failure_signature_count" => length(unique(String(
                record["failure_signature"]) for record in rows)))
    end
    return Dict{String,Any}(
        "input_record_count" => length(records),
        "unique_physics_hash_count" => length(unique(String(
            record["physics_hash"]) for record in records)),
        "family_count" => length(families),
        "global_semantic_gate_pass_counts" => global_gate_counts,
        "global_positive_net_count" => count(record ->
            record["positive_net_power_closure"] === true, records),
        "evidence_complete_count" => count(record ->
            record["evidence_coverage_state"] == "complete", records),
        "robustness_evaluated_count" => count(record ->
            record["robustness_state"] !=
                "not_evaluated_nominal_failure", records),
        "graph_archive_cell_count" => length(graph_archive),
        "mechanism_archive_cell_count" => length(mechanism_archive),
        "frontier_record_count" => length(frontier),
        "frontier_per_family" => Int(frontier_per_family),
        "family_summaries" => family_summaries,
        "graph_archive" => graph_archive,
        "mechanism_archive" => mechanism_archive,
        "family_frontier" => frontier,
        "promotion_count" => count(record ->
            record["promoted"] === true, records),
        "medium_fidelity_authorized_count" => count(record ->
            record["medium_fidelity_authorized"] === true, records),
        "claim_boundary" => _V32_CLAIM_BOUNDARY)
end
