const _V53_CLAIM_BOUNDARY =
    "V53 repairs semantic gate aliases and distinguishes evaluated failure from skipped " *
    "robustness. It executes all-coordinate local diagnostic perturbations and available " *
    "candidate-bound C1 backends for selected mechanism-cluster representatives. A route " *
    "pass is partial evidence only; missing explicit geometry or a missing solver remains " *
    "unknown/unsupported and no result authorizes device promotion."

function _v53_numeric_margins(raw_result::AbstractDict)
    nominal = get(raw_result, "nominal", Dict{String,Any}())
    margins = get(nominal, "margins", Dict{String,Any}())
    records = Dict{String,Any}[]
    for (key, value) in margins
        value isa Real || continue
        converted = Float64(value)
        isfinite(converted) || continue
        push!(records, Dict{String,Any}(
            "margin_id" => String(key), "normalized_margin" => converted,
            "status" => converted >= 0.0 ? "pass" : "fail"))
    end
    sort!(records; by = item -> (Float64(item["normalized_margin"]),
        String(item["margin_id"])))
    return records
end

"Reconstruct the raw evaluator result and preserve executed/skipped/unknown states."
function repaired_common_judgment_v53(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer)
    candidate = evaluate_cross_topology_candidate_v20(context, Int(candidate_index))
    prescreen = candidate.prescreen
    compiled = prescreen.compiled
    raw_result = _plain_json(_v18_route_result(
        context.evaluators[compiled.evaluator_id], compiled.genome))
    semantic_gates, aliases = _v31_semantic_gates(raw_result["gates"])
    robustness = get(raw_result, "robustness", Dict{String,Any}())
    robustness_state = _v31_robustness_state(robustness)
    margins = _v53_numeric_margins(raw_result)
    required_common = ("topology", "physics", "outer_envelope")
    common_status = all(semantic_gates[id] for id in required_common) ?
        "pass" : "fail"
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "candidate_index" => Int(candidate_index),
        "candidate_id" => compiled.genome.design_id,
        "physics_hash" => compiled.genome.physics_hash,
        "graph_hash" => compiled.graph_hash,
        "module_ids" => copy(compiled.module_ids),
        "evaluator_id" => compiled.evaluator_id,
        "semantic_gates" => semantic_gates,
        "semantic_gate_aliases" => aliases,
        "common_physics_status" => common_status,
        "robustness_evaluation_state" => robustness_state,
        "robustness_sample_count" => Int(get(robustness, "sample_count", 0)),
        "robustness_pass_count" => Int(get(robustness, "pass_count", 0)),
        "robustness_pass_fraction" => Float64(get(robustness, "pass_fraction", 0.0)),
        "limiting_margins" => first(margins, min(8, length(margins))),
        "negative_margin_count" => count(item -> item["status"] == "fail", margins),
        "positive_net_power_closure" => get(raw_result,
            "positive_net_power_closure_passed", get(raw_result,
                "positive_average_net_power_closure_passed", false)) === true,
        "missing_proxy_requirements" => copy(prescreen.missing_proxy_requirements),
        "evidence_coverage_state" => isempty(prescreen.missing_proxy_requirements) ?
            "complete" : "incomplete_unknown_requirements",
        "raw_result_hash" => String(raw_result["result_hash"]),
        "raw_result_reconstruction_match" =>
            String(raw_result["result_hash"]) == prescreen.proxy_result_hash,
        "promotion_authorized" => false,
        "claim_boundary" => _V53_CLAIM_BOUNDARY,
    )
end

"Run all 24 paired-coordinate plus/minus perturbations even when nominal physics failed."
function diagnostic_robustness_v53(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        unit_delta::Real = 0.02)
    delta = Float64(unit_delta)
    0.0 < delta <= 0.10 || throw(ArgumentError("v53 delta must be in (0,0.10]"))
    index = Int(candidate_index)
    base = evaluate_cross_topology_candidate_v20(context, index)
    values = _v20_unit_vector(base.sample_ordinal,
        length(_V20_HALTON_PRIMES); skip = 4096)
    records = Dict{String,Any}[]
    for dimension in eachindex(values), direction in (-1, 1)
        perturbed = copy(values)
        perturbed[dimension] = clamp(values[dimension] + direction * delta,
            0.02, 0.98)
        candidate = _v34_candidate_from_values(context, index, perturbed)
        compiled = candidate.prescreen.compiled
        raw = _plain_json(_v18_route_result(
            context.evaluators[compiled.evaluator_id], compiled.genome))
        gates, _ = _v31_semantic_gates(raw["gates"])
        margins = _v53_numeric_margins(raw)
        push!(records, Dict{String,Any}(
            "dimension" => dimension,
            "direction" => direction,
            "coordinate_value" => perturbed[dimension],
            "physics_gate_passed" => gates["physics"],
            "common_gate_passed" => all(gates[id] for id in
                ("topology", "physics", "outer_envelope")),
            "minimum_normalized_margin" => isempty(margins) ? nothing :
                first(margins)["normalized_margin"],
            "primary_limiting_margin_id" => isempty(margins) ? nothing :
                first(margins)["margin_id"],
            "result_hash" => String(raw["result_hash"]),
        ))
    end
    physics_pass_count = count(item -> item["physics_gate_passed"] === true, records)
    common_pass_count = count(item -> item["common_gate_passed"] === true, records)
    status = common_pass_count == length(records) ? "diagnostic_pass" :
        common_pass_count == 0 ? "diagnostic_robust_fail" : "diagnostic_mixed"
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "candidate_index" => index,
        "candidate_id" => base.prescreen.compiled.genome.design_id,
        "physics_hash" => base.prescreen.compiled.genome.physics_hash,
        "coordinate_count" => length(values),
        "sample_count" => length(records),
        "unit_delta" => delta,
        "physics_pass_count" => physics_pass_count,
        "physics_pass_fraction" => physics_pass_count / length(records),
        "common_gate_pass_count" => common_pass_count,
        "common_gate_pass_fraction" => common_pass_count / length(records),
        "status" => status,
        "records" => records,
        "gate_credit" => "diagnostic_only_not_the_preregistered_robustness_gate",
        "promotion_authorized" => false,
        "claim_boundary" => _V53_CLAIM_BOUNDARY,
    )
end

function _v53_attempt(id::String, status::String; executed = false,
        applicable = false, reason = nothing, result_hash = nothing,
        c1_authorized = false, details = Dict{String,Any}())
    return Dict{String,Any}(
        "route_id" => id, "status" => status,
        "executed" => executed, "applicable" => applicable,
        "reason" => reason, "result_hash" => result_hash,
        "candidate_c1_evidence_authorized" => c1_authorized,
        "details" => details,
    )
end

function _v53_native_summary(result)
    magnetic = get(result, "magnetic", Dict{String,Any}())
    pulse = get(result, "pulse", Dict{String,Any}())
    executed = get(magnetic, "backend_executed", false) === true ||
        get(pulse, "backend_executed", false) === true
    details = Dict{String,Any}(
        "c1_route" => get(result, "c1_route", "unsupported"),
        "execution_refinement" => get(result, "execution_refinement", Dict{String,Any}()),
        "magnetic_backend_executed" => get(magnetic, "backend_executed", false),
        "pulse_backend_executed" => get(pulse, "backend_executed", false),
        "magnetic_reason" => get(magnetic, "reason", nothing),
        "pulse_link_errors" => get(pulse, "link_errors", Any[]),
        "pulse_source_binding_errors" => get(pulse, "source_binding_errors", Any[]),
        "drive_geometry_evidence_authorized" =>
            get(pulse, "drive_geometry_evidence_authorized", false),
        "field_solution_evidence_authorized" =>
            get(magnetic, "field_solution_evidence_authorized", false),
    )
    return _v53_attempt("native_candidate_c1_backend_v1",
        String(result["status"]); executed = executed, applicable = true,
        reason = executed ? nothing : get(magnetic, "reason", "no supported native route"),
        result_hash = String(result["physical_result_hash"]),
        c1_authorized = result["candidate_c1_evidence_authorized"] === true,
        details = details)
end

"Attempt only solvers applicable to the declared candidate; never synthesize a parent."
function higher_fidelity_representative_validation_v53(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer)
    candidate = evaluate_cross_topology_candidate_v20(context, Int(candidate_index))
    compiled = candidate.prescreen.compiled
    genome = compiled.genome
    tokens = lowercase.(compiled.module_ids)
    profiles = unified_validation_profiles_v52(Dict{String,Any}(
        "module_ids" => compiled.module_ids,
        "mission_contract_id" => compiled.mission_contract_id,
        "evaluator_id" => compiled.evaluator_id))
    attempts = Dict{String,Any}[]

    native = execute_native_candidate_c1_backend_v1(genome)
    push!(attempts, _v53_native_summary(native))

    if "closed_field_global_modes_v1" in profiles
        desc = compile_topology_desc_stability_problem_v2(genome)
        push!(attempts, _v53_attempt("topology_desc_stability_problem_v2",
            String(desc["status"]); executed = false,
            applicable = desc["status"] == "ready",
            reason = desc["status"] == "ready" ?
                "solver problem compiled but external DESC execution is not authorized by this candidate record" :
                join(String.(get(desc, "mismatches", Any[])), "; "),
            result_hash = get(desc, "solver_problem_hash", nothing),
            details = Dict("family_label_used" => get(desc, "family_label_used", false))))
    end

    if any(token -> occursin("tokamak", token), tokens)
        try
            freegs = TokamakFreeBoundaryFreeGSV1()
            applicable, reason = evaluator_applicability(freegs, genome)
            if applicable
                result = evaluation_to_dict(run_evaluator(freegs, genome))
                push!(attempts, _v53_attempt("tokamak_free_boundary_freegs_v1",
                    "executed"; executed = true, applicable = true,
                    reason = reason, result_hash = canonical_hash(result),
                    details = Dict("metric_count" => length(result["metrics"]))))
            else
                push!(attempts, _v53_attempt("tokamak_free_boundary_freegs_v1",
                    "not_applicable"; reason = reason))
            end
        catch exception
            push!(attempts, _v53_attempt("tokamak_free_boundary_freegs_v1",
                "unsupported"; reason = sprint(showerror, exception)))
        end
    end

    if any(token -> occursin("mirror", token), tokens)
        result = execute_axisymmetric_mirror_filament_c1_v1(genome)
        push!(attempts, _v53_attempt("axisymmetric_mirror_filament_c1_v1",
            String(result["status"]); executed = get(result, "backend_executed", false),
            applicable = get(result, "backend_executed", false),
            reason = get(result, "reason", nothing),
            result_hash = get(result, "physical_result_hash", nothing),
            c1_authorized = get(result, "candidate_c1_evidence_authorized", false)))
    end

    if any(token -> occursin("dipole", token), tokens)
        result = evaluate_levitated_dipole_ring_screen_v1(genome)
        push!(attempts, _v53_attempt("levitated_dipole_ring_screen_v1",
            String(result["status"]); executed = get(result, "backend_executed", false),
            applicable = get(result, "backend_executed", false),
            reason = get(result, "reason", nothing),
            result_hash = get(result, "physical_result_hash", nothing),
            c1_authorized = get(result, "candidate_c1_evidence_authorized", false)))
    end

    if "pulsed_energy_ledger_v1" in profiles
        contract = compile_pulsed_rhd_input_contract_v1(native)
        push!(attempts, _v53_attempt("pulsed_radiation_hydrodynamics_input_v1",
            String(contract["status"]); executed = false,
            applicable = contract["status"] == "ready_for_external_backend",
            reason = isempty(contract["blocking_missing_inputs"]) ? nothing :
                join(String.(contract["blocking_missing_inputs"]), "; "),
            result_hash = String(contract["physical_contract_hash"]),
            details = Dict("blocking_missing_inputs" =>
                contract["blocking_missing_inputs"])))
    end

    executed_count = count(item -> item["executed"] === true, attempts)
    c1_count = count(item -> item["candidate_c1_evidence_authorized"] === true, attempts)
    hard_fail_count = count(item -> item["status"] == "fail", attempts)
    status = hard_fail_count > 0 ? "candidate_bound_route_fail" :
        c1_count > 0 ? "partial_c1_route_pass_deeper_physics_unknown" :
        "higher_fidelity_unknown_or_unsupported"
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "candidate_index" => Int(candidate_index),
        "candidate_id" => genome.design_id,
        "physics_hash" => genome.physics_hash,
        "module_ids" => copy(compiled.module_ids),
        "validation_profile_ids" => profiles,
        "attempts" => attempts,
        "attempt_count" => length(attempts),
        "executed_backend_count" => executed_count,
        "candidate_c1_authorized_route_count" => c1_count,
        "hard_fail_route_count" => hard_fail_count,
        "status" => status,
        "parent_synthesized" => false,
        "promotion_authorized" => false,
        "claim_boundary" => _V53_CLAIM_BOUNDARY,
    )
end
