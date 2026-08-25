const _V58_CLAIM_BOUNDARY =
    "V58 separates numerical state convergence, required steady balance demands, and " *
    "engineering realization. Steady control-volume equations may converge by solving the " *
    "fueling, auxiliary-heating, and removal demands needed to hold the candidate-declared " *
    "state; those demands do not prove that hardware can supply them. Pulse trajectories use " *
    "a local independent RK4 residual probe. Stage-7 magnetic pressure, global force, stored " *
    "energy, global heat-load, fueling, and recirculating-power lower-bound roles remain below " *
    "engineering feasibility until geometry, material limits, efficiencies, faults, lifetime, " *
    "maintenance, fuel cycle, and local heat-flux evidence close. Routing uses declared module " *
    "capabilities and time semantics, never family or parent-family labels."

"Compile and execute the capability-matched v58 Stage 3-7 vertical slice."
function compile_candidate_solver_judgment_input_v58(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32], execute_native_routes::Bool = false,
        compile_problem_artifacts::Bool = true)
    candidate = evaluate_solver_ready_candidate_v54(context, candidate_index)
    compiled = candidate.prescreen.compiled
    genome = compiled.genome
    base = compile_candidate_bound_judgment_input_v56(context, candidate_index;
        candidate_record = candidate, execute_native_routes = execute_native_routes,
        compile_problem_artifacts = compile_problem_artifacts)
    input = deepcopy(base["judgment_input"])
    engineering_parameters = candidate_engineering_parameters_v1(genome,
        compiled.module_ids)
    manifest = compile_candidate_solve_manifest_v2(genome, compiled.module_ids;
        discretization_levels = discretization_levels,
        parameter_overrides = engineering_parameters)
    result = solve_candidate_manifest_v2(manifest)
    state = solver_state_for_v55_v1(result, manifest)
    transport = transport_burn_for_v55_v1(result, manifest)
    engineering_result = solve_engineering_roles_v1(manifest, result, transport)
    ledger = strict_power_ledger_v2(result, transport, engineering_result)
    manifest_dict = candidate_solve_manifest_to_dict_v1(manifest)
    result_dict = solver_result_envelope_to_dict_v1(result)
    engineering_dict = engineering_result_envelope_to_dict_v1(engineering_result)
    engineering_dict["solver_derived"] = result.status != :unsupported
    engineering_dict["solver_output_hash"] = engineering_result.result_hash
    manifest_artifact = _v57_runtime_artifact("candidate_solve_manifest_v1",
        manifest_dict, "compiled")
    result_artifact = _v57_runtime_artifact("solver_result_envelope_v2",
        result_dict, String(result.status))
    transport_artifact = _v57_runtime_artifact("stage5_transport_burn_result_v2",
        transport, result.status == :unsupported ? "unsupported" : "computed")
    engineering_artifact = _v57_runtime_artifact("stage7_engineering_result_v1",
        engineering_dict, String(engineering_result.status))
    ledger_artifact = _v57_runtime_artifact("stage6_strict_power_ledger_v2",
        ledger, String(ledger["status"]))
    runtime_artifacts = [manifest_artifact, result_artifact, transport_artifact,
        ledger_artifact, engineering_artifact]
    append!(input["stage_artifacts"], runtime_artifacts)
    isempty(input["physical_description"]["species"]) &&
        (input["physical_description"]["species"] = _v57_explicit_fuel_species(genome))
    primary = _v56_primary_region(genome)
    for artifact in runtime_artifacts
        push!(input["physical_description"]["observables"], Dict(
            "id" => "observe_$(artifact["artifact_id"])", "source_ref" => primary,
            "artifact_hash" => artifact["artifact_hash"]))
        push!(input["evidence"], Dict(
            "evidence_id" => String(artifact["artifact_id"]),
            "artifact_hash" => String(artifact["artifact_hash"]),
            "evidence_class" => "candidate_bound_l1_runtime_product"))
    end
    input["state_evolution"] = state
    input["state_evolution"]["candidate_solve_manifest_hash"] = manifest.manifest_hash
    input["state_evolution"]["solver_result_envelope_ref"] =
        "solver_result_envelope_v2"
    input["transport_burn"] = transport
    input["transport_burn"]["solver_result_envelope_ref"] =
        "solver_result_envelope_v2"
    input["engineering"] = engineering_dict
    input["engineering"]["solver_result_envelope_ref"] =
        "solver_result_envelope_v2"
    input["net_energy"] = ledger
    input["net_energy"]["strict_aggregation"] = true
    input["solver_runtime"] = Dict{String,Any}(
        "manifest" => manifest_dict, "result" => result_dict,
        "engineering_result" => engineering_dict,
        "routing_basis" => "declared_module_capabilities_and_time_semantics_only",
        "operator_ids" => String[item["operator_id"] for item in manifest.module_bindings],
        "unsupported_reasons" => result.unsupported_reasons,
        "evidence_ceiling" => engineering_result.evidence_ceiling)
    input["benchmark_scope"] = "v58_candidate_solver_convergence_engineering_search"
    input["claim_boundary"] = _V58_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    summary = deepcopy(base["artifact_summary"])
    summary["input_hash"] = input_hash
    summary["artifact_count"] = Int(summary["artifact_count"]) + length(runtime_artifacts)
    for artifact in runtime_artifacts
        summary["artifact_statuses"][String(artifact["artifact_id"])] =
            String(artifact["status"])
    end
    summary["candidate_solver_status"] = String(result.status)
    summary["candidate_solver_convergence_status"] = result.convergence_status
    summary["candidate_solver_manifest_hash"] = manifest.manifest_hash
    summary["candidate_solver_result_hash"] = result.result_hash
    summary["engineering_result_hash"] = engineering_result.result_hash
    summary["engineering_status"] = String(engineering_result.status)
    summary["recirculating_power_role_completeness"] = String(get(
        engineering_result.recirculating_power, "role_completeness", "unknown"))
    summary["strict_power_ledger_status"] = String(ledger["status"])
    summary["declared_capability_count"] = length(manifest.capability_declarations)
    summary["selected_operator_count"] = length(manifest.module_bindings)
    cluster_record = unified_screen_candidate_v52(
        solver_ready_candidate_to_dict_v54(candidate))
    summary["mechanism_cluster_id"] = String(cluster_record["mechanism_cluster_id"])
    summary["mechanism_cluster_basis"] = deepcopy(cluster_record["cluster_basis"])
    return Dict{String,Any}("judgment_input" => input,
        "artifact_summary" => summary, "input_hash" => input_hash,
        "manifest" => manifest, "solver_result" => result,
        "engineering_result" => engineering_result, "cluster_record" => cluster_record,
        "claim_boundary" => _V58_CLAIM_BOUNDARY)
end

function evaluate_candidate_solver_search_batch_v58(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32])
    bundles = [compile_candidate_solver_judgment_input_v58(context, index;
        discretization_levels = discretization_levels) for index in candidate_indices]
    archive = evaluate_all_search_results_v55(getindex.(bundles, "judgment_input"))
    length(archive["results"]) == length(bundles) || error("v58 dropped a candidate")
    return Dict{String,Any}("bundles" => bundles, "judgment_archive" => archive,
        "claim_boundary" => _V58_CLAIM_BOUNDARY)
end
