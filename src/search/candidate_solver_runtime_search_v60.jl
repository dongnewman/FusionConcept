const _V60_CLAIM_BOUNDARY =
    "V60 compiles every candidate through the same RegionStateSpecV1 and " *
    "InterfaceFluxContractV1 chain. Region inventories may only come from explicit " *
    "region profiles and finite geometry integration; equal splitting, nominal volume " *
    "fractions, family templates and parent defaults are prohibited. Actuator realization " *
    "and plant-power accounting are deferred until regional conservation passes. A 10,000 " *
    "candidate run is authorized only after regional conservation, actuator realization and " *
    "two-level resolution convergence all pass on the declared representative gate set."

function _v60_defer_downstream!(input, region_result)
    state = input["state_evolution"]
    state["solver_derived"] = false
    state["solver_output_hash"] = ""
    state["solver_status"] = String(region_result.status)
    state["regional_result_hash"] = region_result.result_hash
    state["residuals"] = Dict{String,Any}[]
    state["complete_time_trajectory"] = false

    transport = input["transport_burn"]
    transport["solver_derived"] = false
    transport["generated_nominal"] = false
    transport["solver_output_hash"] = ""
    transport["state_solution_hash"] = ""
    transport["particle_paths"] = Dict{String,Any}[]
    transport["energy_paths"] = Dict{String,Any}[]
    transport["fusion_reaction_rate_per_s"] = nothing
    transport["fusion_power_w"] = nothing
    transport["self_heating_power_w"] = nothing
    transport["confinement_time_source"] = ""
    transport["deferred_reason"] = "regional_conservation_gate_not_passed"

    ledger = input["net_energy"]
    ledger["terms"] = Dict{String,Any}[]
    ledger["reported_net_power_w"] = nothing
    ledger["status"] = "unknown_deferred_until_regional_and_actuator_gates_pass"
    ledger["generated_nominal"] = false
    ledger["artificially_closed"] = false

    engineering = input["engineering"]
    engineering["solver_derived"] = false
    engineering["solver_output_hash"] = ""
    engineering["status"] = "unknown_deferred_until_regional_and_actuator_gates_pass"
    for check in get(engineering, "checks", Any[])
        check["status"] = "unknown"
        check["applicability_basis"] = "not evaluated before regional conservation"
        pop!(check, "normalized_margin", nothing)
    end
    return input
end

"Compile a candidate into the region-first v60 chain without a separate incomplete path."
function compile_candidate_solver_judgment_input_v60(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32, 64], execute_native_routes::Bool = false,
        compile_problem_artifacts::Bool = false)
    base = compile_candidate_solver_judgment_input_v59(context, candidate_index;
        discretization_levels = discretization_levels,
        execute_native_routes = execute_native_routes,
        compile_problem_artifacts = compile_problem_artifacts)
    genome = base["cluster_record"] === nothing ? error("missing candidate cluster") :
        evaluate_solver_ready_candidate_v54(context, candidate_index).prescreen.compiled.genome
    manifest = base["manifest"]
    specs = compile_region_state_specs_v1(genome, manifest)
    interfaces = compile_interface_flux_contracts_v1(genome, manifest, specs)
    region_result = solve_region_partition_v1(manifest, specs, interfaces)
    input = deepcopy(base["judgment_input"])
    region_full_search_gate_passes_v1(region_result) || _v60_defer_downstream!(input, region_result)

    spec_dicts = region_state_spec_to_dict_v1.(specs)
    interface_dicts = interface_flux_contract_to_dict_v1.(interfaces)
    result_dict = region_solve_result_to_dict_v1(region_result)
    artifacts = Dict{String,Any}[]
    for spec in spec_dicts
        push!(artifacts, _v57_runtime_artifact(
            "region_state_spec_v1__$(spec["region_id"])", spec,
            String(spec["applicability"]["status"])))
    end
    for contract in interface_dicts
        push!(artifacts, _v57_runtime_artifact(
            "interface_flux_contract_v1__$(contract["interface_id"])", contract,
            String(contract["applicability"]["status"])))
    end
    push!(artifacts, _v57_runtime_artifact("region_solve_result_envelope_v1",
        result_dict, String(region_result.status)))
    append!(input["stage_artifacts"], artifacts)
    primary = _v56_primary_region(genome)
    for artifact in artifacts
        push!(input["physical_description"]["observables"], Dict(
            "id" => "observe_$(artifact["artifact_id"])", "source_ref" => primary,
            "artifact_hash" => artifact["artifact_hash"]))
        push!(input["evidence"], Dict("evidence_id" => artifact["artifact_id"],
            "artifact_hash" => artifact["artifact_hash"],
            "evidence_class" => "candidate_bound_v60_region_protocol_product"))
    end
    input["solver_runtime"]["region_state_specs"] = spec_dicts
    input["solver_runtime"]["interface_flux_contracts"] = interface_dicts
    input["solver_runtime"]["region_solve_result"] = result_dict
    input["solver_runtime"]["execution_order"] = [
        "regional_conservation", "actuator_realization", "resolution_convergence",
        "plant_power_ledger"]
    input["solver_runtime"]["full_search_authorized"] =
        region_full_search_gate_passes_v1(region_result)
    input["solver_runtime"]["routing_basis"] =
        "declared region geometry/profile, interface contracts, capabilities, units and signs only"
    input["benchmark_scope"] = "v60_region_first_representative_gate"
    input["claim_boundary"] = _V60_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    summary = deepcopy(base["artifact_summary"])
    summary["input_hash"] = input_hash
    summary["artifact_count"] = Int(summary["artifact_count"]) + length(artifacts)
    summary["region_count"] = length(specs)
    summary["interface_count"] = length(interfaces)
    summary["complete_region_spec_count"] = count(spec ->
        String(spec.applicability["status"]) == "complete", specs)
    summary["complete_interface_contract_count"] = count(item ->
        String(item.applicability["status"]) == "complete", interfaces)
    summary["region_solve_status"] = String(region_result.status)
    summary["region_solve_convergence_status"] = region_result.convergence_status
    summary["region_solve_result_hash"] = region_result.result_hash
    summary["gate_statuses"] = deepcopy(region_result.gate_statuses)
    summary["full_search_authorized"] = region_full_search_gate_passes_v1(region_result)
    for artifact in artifacts
        summary["artifact_statuses"][String(artifact["artifact_id"])] =
            String(artifact["status"])
    end
    return Dict{String,Any}("judgment_input" => input, "artifact_summary" => summary,
        "input_hash" => input_hash, "manifest" => manifest,
        "region_state_specs" => specs, "interface_flux_contracts" => interfaces,
        "region_solve_result" => region_result, "base_v59" => base,
        "cluster_record" => base["cluster_record"], "claim_boundary" => _V60_CLAIM_BOUNDARY)
end

"Evaluate a declared representative set; this function never launches the 10,000 search."
function evaluate_candidate_solver_representative_gate_v60(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32, 64])
    indices = Int.(collect(candidate_indices))
    bundles = [compile_candidate_solver_judgment_input_v60(context, index;
        discretization_levels = discretization_levels) for index in indices]
    judgments = [evaluate_uniform_judgment_v55(bundle["judgment_input"]) for bundle in bundles]
    all_three = [region_full_search_gate_passes_v1(bundle["region_solve_result"])
        for bundle in bundles]
    gate_histograms = Dict{String,Dict{String,Int}}()
    for id in ("regional_conservation", "actuator_realization", "resolution_convergence")
        histogram = Dict{String,Int}()
        for bundle in bundles
            status = String(bundle["region_solve_result"].gate_statuses[id]["status"])
            histogram[status] = get(histogram, status, 0) + 1
        end
        gate_histograms[id] = histogram
    end
    return Dict{String,Any}("candidate_indices" => indices, "bundles" => bundles,
        "judgments" => judgments, "gate_histograms" => gate_histograms,
        "all_candidates_pass_all_three_gates" => !isempty(all_three) && all(all_three),
        "full_search_authorized" => !isempty(all_three) && all(all_three),
        "full_search_executed" => false,
        "full_search_block_reason" => all(all_three) ?
            "caller_must_explicitly_launch_after_review" :
            "representative regional, actuator and resolution gates are not all pass",
        "claim_boundary" => _V60_CLAIM_BOUNDARY)
end
