const _V31_SEMANTIC_GATE_IDS = (
    "topology",
    "physics",
    "engineering",
    "outer_envelope",
    "robustness",
)

const _V31_GATE_ALIASES = Dict{String,Tuple{Vararg{String}}}(
    "topology" => (
        "variable_topology_representation_and_compatibility",
        "variable_topology_representation",
    ),
    "physics" => (
        "unified_low_fidelity_physics",
        "first_principles_pulse_and_evidence_separation",
        "timescale_and_flux_ordering",
    ),
    "engineering" => (
        "minimal_engineering_closure",
        "shot_energy_and_average_power_closure",
    ),
    "outer_envelope" => (
        "same_outer_envelope_contract",
        "same_pulsed_outer_envelope_contract",
    ),
    "robustness" => ("cheap_robustness_screen",),
)

const _V31_CLAIM_BOUNDARY =
    "V31 audits semantic gate observability and acquisition-transfer readiness across 100 deterministic fidelity-0 candidates from each of the 11 v17/v20 families. Computed proxy pass/fail labels are kept separate from incomplete declared evidence, and skipped robustness is kept separate from evaluated failure. Exact mapping and reconstruction may authorize a diagnostic failure-frontier search, but failed five-gate readiness forbids an algorithm-performance or promotion claim. The audit cannot improve a gate, create C1 or medium-fidelity credit, validate a fusion concept, or establish physical infeasibility from missing evidence."

function _v31_semantic_gates(raw_gates::AbstractDict)
    result = Dict{String,Bool}()
    aliases = Dict{String,String}()
    raw_keys = Set(String.(collect(keys(raw_gates))))
    for gate in _V31_SEMANTIC_GATE_IDS
        matches = String[alias for alias in _V31_GATE_ALIASES[gate]
            if alias in raw_keys]
        length(matches) == 1 || throw(ArgumentError(
            "v31 expected exactly one alias for $gate, found $(matches)"))
        alias = only(matches)
        value = raw_gates[alias]
        value isa Bool || throw(ArgumentError(
            "v31 gate $alias is not Boolean"))
        result[gate] = value
        aliases[gate] = alias
    end
    return result, aliases
end

function _v31_robustness_state(robustness::AbstractDict)
    skipped = get(robustness, "skipped_due_nominal_gate_failure", false) === true ||
        get(robustness, "skipped_due_conditional_nominal_failure", false) === true
    skipped && return "not_evaluated_nominal_failure"
    get(robustness, "gate_passed", false) === true && return "pass"
    return "evaluated_fail"
end

function _v31_float_or_nothing(value)
    value isa Real || return nothing
    converted = Float64(value)
    isfinite(converted) || return nothing
    return converted
end

function audit_cross_topology_candidate_v31(
        context::RecoverableCrossTopologyContextV20,
        candidate_index::Integer; halton_skip::Integer = 4096)
    candidate = evaluate_cross_topology_candidate_v20(context,
        Int(candidate_index); halton_skip = Int(halton_skip))
    prescreen = candidate.prescreen
    compiled = prescreen.compiled
    evaluator = context.evaluators[compiled.evaluator_id]
    raw_result = _v18_route_result(evaluator, compiled.genome)
    semantic_gates, aliases = _v31_semantic_gates(raw_result["gates"])
    nominal = get(raw_result, "nominal", Dict{String,Any}())
    robustness = get(raw_result, "robustness", Dict{String,Any}())
    robustness_state = _v31_robustness_state(robustness)
    evidence_state = isempty(prescreen.missing_proxy_requirements) ?
        "complete" : "incomplete_unknown_requirements"
    positive = get(raw_result, "positive_net_power_closure_passed",
        get(raw_result, "positive_average_net_power_closure_passed",
            false)) === true
    nominal_physics = get(nominal, "physics_gate_passed", false) === true
    nominal_engineering = get(nominal,
        "engineering_gate_passed", false) === true
    semantic_gate_count = count(values(semantic_gates))
    prescreen.proxy_five_gate_passed == all(values(semantic_gates)) ||
        error("v31 semantic five-gate mapping drifted")
    return Dict{String,Any}(
        "candidate_index" => Int(candidate_index),
        "assembly_index" => candidate.assembly_index,
        "sample_ordinal" => candidate.sample_ordinal,
        "assembly_id" => compiled.assembly_id,
        "graph_hash" => compiled.graph_hash,
        "family" => compiled.family,
        "module_ids" => copy(compiled.module_ids),
        "physics_hash" => compiled.genome.physics_hash,
        "evaluator_id" => compiled.evaluator_id,
        "projection_id" => compiled.projection_id,
        "semantic_gates" => semantic_gates,
        "semantic_gate_aliases" => aliases,
        "semantic_gate_pass_count" => semantic_gate_count,
        "all_five_semantic_gates_passed" => all(values(semantic_gates)),
        "nominal_physics_gate_passed" => nominal_physics,
        "nominal_engineering_gate_passed" => nominal_engineering,
        "positive_net_power_closure" => positive,
        "minimum_normalized_margin" => _v31_float_or_nothing(get(nominal,
            "minimum_normalized_margin", nothing)),
        "robustness_state" => robustness_state,
        "robustness_sample_count" => Int(get(robustness,
            "sample_count", 0)),
        "robustness_pass_count" => Int(get(robustness,
            "pass_count", 0)),
        "robustness_pass_fraction" => Float64(get(robustness,
            "pass_fraction", 0.0)),
        "computed_gate_state_policy" =>
            "pass_or_fail_from_executed_fidelity0_proxy",
        "evidence_coverage_state" => evidence_state,
        "missing_proxy_requirements" =>
            copy(prescreen.missing_proxy_requirements),
        "missing_proxy_requirement_count" =>
            length(prescreen.missing_proxy_requirements),
        "projection_limitations" => copy(compiled.projection_limitations),
        "topology_graph_errors" => copy(prescreen.topology_graph_errors),
        "medium_fidelity_candidate_eligible" =>
            prescreen.medium_fidelity_candidate_eligible,
        "proxy_result_hash" => prescreen.proxy_result_hash,
        "raw_result_hash" => String(raw_result["result_hash"]),
        "raw_result_reconstruction_match" =>
            prescreen.proxy_result_hash == String(raw_result["result_hash"]),
        "claim_level" => "C0_gate_observability_audit_only")
end

function balanced_gate_observability_plan_v31(
        context::RecoverableCrossTopologyContextV20;
        candidates_per_family::Integer = 100,
        target_assemblies_per_family::Integer = 10)
    candidates_per_family > 0 || throw(ArgumentError(
        "v31 candidates_per_family must be positive"))
    target_assemblies_per_family > 0 || throw(ArgumentError(
        "v31 target_assemblies_per_family must be positive"))
    groups = Dict{String,Vector{Tuple{String,Int}}}()
    for (assembly_index, assembly) in enumerate(context.assemblies)
        push!(get!(groups, assembly.family, Tuple{String,Int}[]),
            (assembly.graph_hash, assembly_index))
    end
    topology_count = length(context.assemblies)
    plan = Dict{String,Any}[]
    for family in sort!(collect(keys(groups)))
        ordered = sort!(groups[family]; by = first)
        target_count = min(length(ordered), Int(target_assemblies_per_family))
        positions = target_count == 1 ? [1] : unique(Int[
            round(Int, 1 + (slot - 1) * (length(ordered) - 1) /
                (target_count - 1)) for slot in 1:target_count])
        length(positions) == target_count || error(
            "v31 assembly stratification collapsed for $family")
        representatives = ordered[positions]
        for local_index in 1:Int(candidates_per_family)
            representative = representatives[mod1(local_index,
                length(representatives))]
            sample_ordinal = cld(local_index, length(representatives))
            assembly_index = representative[2]
            candidate_index = assembly_index +
                (sample_ordinal - 1) * topology_count
            push!(plan, Dict{String,Any}(
                "family" => family,
                "family_local_index" => local_index,
                "assembly_index" => assembly_index,
                "graph_hash" => representative[1],
                "sample_ordinal" => sample_ordinal,
                "candidate_index" => candidate_index))
        end
    end
    length(unique(Int(item["candidate_index"]) for item in plan)) ==
        length(plan) || error("v31 balanced plan contains duplicate candidates")
    return plan
end

function _v31_gate_count(rows, gate::String)
    return count(row -> row["semantic_gates"][gate] === true, rows)
end

function _v31_quantiles(values::Vector{Float64})
    isempty(values) && return Dict{String,Any}(
        "minimum" => nothing, "q10" => nothing, "median" => nothing,
        "q90" => nothing, "maximum" => nothing)
    return Dict{String,Any}(
        "minimum" => minimum(values),
        "q10" => _v28_quantile(values, 0.10),
        "median" => _v28_quantile(values, 0.50),
        "q90" => _v28_quantile(values, 0.90),
        "maximum" => maximum(values))
end

function aggregate_cross_family_gate_observability_v31(
        records::Vector{<:AbstractDict}; expected_per_family::Integer = 100)
    isempty(records) && throw(ArgumentError("v31 requires audit records"))
    groups = Dict{String,Vector{AbstractDict}}()
    for record in records
        push!(get!(groups, String(record["family"]), AbstractDict[]), record)
    end
    family_ids = sort!(collect(keys(groups)))
    length(family_ids) == 11 || throw(ArgumentError(
        "v31 requires all 11 v20 families"))
    all(length(groups[family]) == expected_per_family for family in
        family_ids) || throw(ArgumentError("v31 family sample budget drifted"))
    family_summaries = Dict{String,Any}()
    for family in family_ids
        rows = groups[family]
        semantic_counts = Dict(gate => _v31_gate_count(rows, gate)
            for gate in _V31_SEMANTIC_GATE_IDS)
        positive_count = count(row ->
            row["positive_net_power_closure"] === true, rows)
        primary_counts = Dict{String,Int}(
            "physics" => semantic_counts["physics"],
            "engineering" => semantic_counts["engineering"],
            "robustness" => semantic_counts["robustness"],
            "positive_net" => positive_count)
        variable_primary = sort!(String[label for (label, count_value) in
            primary_counts if 0 < count_value < length(rows)])
        margins = Float64[Float64(row["minimum_normalized_margin"])
            for row in rows if row["minimum_normalized_margin"] !== nothing]
        robustness_states = Dict(state => count(row ->
            row["robustness_state"] == state, rows) for state in
            ("pass", "evaluated_fail", "not_evaluated_nominal_failure"))
        missing = sort!(unique(vcat((String.(row[
            "missing_proxy_requirements"]) for row in rows)...)))
        family_summaries[family] = Dict{String,Any}(
            "record_count" => length(rows),
            "semantic_gate_pass_counts" => semantic_counts,
            "nominal_physics_pass_count" => count(row ->
                row["nominal_physics_gate_passed"] === true, rows),
            "nominal_engineering_pass_count" => count(row ->
                row["nominal_engineering_gate_passed"] === true, rows),
            "positive_net_count" => positive_count,
            "evidence_complete_count" => count(row ->
                row["evidence_coverage_state"] == "complete", rows),
            "robustness_state_counts" => robustness_states,
            "variable_primary_label_ids" => variable_primary,
            "minimum_normalized_margin_quantiles" =>
                _v31_quantiles(margins),
            "unique_missing_requirement_count" => length(missing),
            "missing_requirements" => missing)
    end

    mapping_complete = all(record -> length(record[
        "semantic_gates"]) == length(_V31_SEMANTIC_GATE_IDS), records)
    reconstruction_complete = all(record -> record[
        "raw_result_reconstruction_match"] === true, records)
    families_with_physics_variation = count(family -> "physics" in
        family_summaries[family]["variable_primary_label_ids"], family_ids)
    families_with_evaluated_robustness = count(family ->
        family_summaries[family]["robustness_state_counts"][
            "not_evaluated_nominal_failure"] < expected_per_family,
        family_ids)
    families_with_complete_evidence = count(family ->
        family_summaries[family]["evidence_complete_count"] > 0, family_ids)
    family_ready = Dict(family => Dict{String,Any}(
        "physics_label_has_pass_fail_variation" => "physics" in
            family_summaries[family]["variable_primary_label_ids"],
        "robustness_was_evaluated" => family_summaries[family][
            "robustness_state_counts"][
                "not_evaluated_nominal_failure"] < expected_per_family,
        "has_evidence_complete_candidate" => family_summaries[family][
            "evidence_complete_count"] > 0) for family in family_ids)
    all_families_ready = all(family -> all(values(family_ready[family])),
        family_ids)
    readiness_conditions = Dict{String,Any}(
        "semantic_mapping_complete" => mapping_complete,
        "raw_result_reconstruction_complete" => reconstruction_complete,
        "all_11_families_have_physics_label_variation" =>
            families_with_physics_variation == 11,
        "all_11_families_have_evaluated_robustness" =>
            families_with_evaluated_robustness == 11,
        "all_11_families_have_evidence_complete_candidate" =>
            families_with_complete_evidence == 11)
    five_gate_transfer_authorized = all(values(readiness_conditions)) &&
        all_families_ready
    diagnostic_search_authorized = mapping_complete && reconstruction_complete
    global_gate_counts = Dict(gate => _v31_gate_count(records, gate)
        for gate in _V31_SEMANTIC_GATE_IDS)
    return Dict{String,Any}(
        "record_count" => length(records),
        "family_count" => length(family_ids),
        "records_per_family" => Int(expected_per_family),
        "semantic_gate_ids" => collect(_V31_SEMANTIC_GATE_IDS),
        "global_semantic_gate_pass_counts" => global_gate_counts,
        "global_positive_net_count" => count(record ->
            record["positive_net_power_closure"] === true, records),
        "evidence_complete_record_count" => count(record ->
            record["evidence_coverage_state"] == "complete", records),
        "robustness_not_evaluated_record_count" => count(record ->
            record["robustness_state"] ==
                "not_evaluated_nominal_failure", records),
        "families_with_physics_label_variation" =>
            families_with_physics_variation,
        "families_with_evaluated_robustness" =>
            families_with_evaluated_robustness,
        "families_with_complete_evidence" =>
            families_with_complete_evidence,
        "family_transfer_readiness" => family_ready,
        "readiness_conditions" => readiness_conditions,
        "diagnostic_failure_frontier_search_authorized" =>
            diagnostic_search_authorized,
        "five_gate_acquisition_transfer_authorized" =>
            five_gate_transfer_authorized,
        "cross_family_acquisition_transfer_authorized" =>
            five_gate_transfer_authorized,
        "family_summaries" => family_summaries,
        "claim_boundary" => _V31_CLAIM_BOUNDARY)
end
