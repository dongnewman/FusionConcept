const _V59_CLAIM_BOUNDARY =
    "V59 adds a family-neutral declared-region network, module requires/provides " *
    "compatibility graph, explicit actuator demand/capacity/efficiency realization, and a " *
    "strict PlantPowerLedgerV1. A converged global L1 control volume does not become a " *
    "geometry-resolved multi-region transport solution: missing regional inventories or " *
    "interface operators remain unknown. Missing actuator modules are unsupported, numeric " *
    "capacity shortfalls are candidate-instance failures, and missing efficiencies or evidence " *
    "remain unknown. Plant roles and local engineering roles are never filled by family defaults."

function _v59_transport_result(result, manifest, coupled)
    transport = transport_burn_for_v55_v1(result, manifest)
    transport["regional_coupled_result_hash"] = coupled.result_hash
    transport["actuator_realization_status"] = String(coupled.status)
    transport["actuator_convergence_status"] = coupled.convergence_status
    transport["region_interface_fluxes"] = deepcopy(coupled.interface_fluxes)
    transport["actuator_demands"] = deepcopy(coupled.actuator_demands)
    transport["actuator_outputs"] = deepcopy(coupled.actuator_outputs)
    body = Dict{String,Any}(String(key) => value for (key, value) in transport if
        String(key) != "solver_output_hash")
    transport["solver_output_hash"] = result.status == :unsupported ? "" :
        canonical_hash(_csr_v1_json_safe(body))
    transport["evidence_ceiling"] = "L1_state_derived_transport_with_explicit_actuator_realization_status"
    return transport
end

"Compile and execute the v59 regional transport-actuator-power vertical slice."
function compile_candidate_solver_judgment_input_v59(
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
    manifest = compile_candidate_solve_manifest_v3(genome, compiled.module_ids;
        discretization_levels = discretization_levels)
    result = solve_candidate_manifest_v2(manifest)
    coupled = solve_region_actuator_coupling_v1(manifest, result)
    state = solver_state_for_v55_v1(result, manifest)
    transport = _v59_transport_result(result, manifest, coupled)
    engineering_result = solve_engineering_roles_v2(manifest, result, transport, coupled)
    plant_ledger = solve_plant_power_ledger_v1(manifest, result, transport, coupled,
        engineering_result)
    ledger = plant_power_ledger_to_dict_v1(plant_ledger)
    manifest_dict = candidate_solve_manifest_to_dict_v1(manifest)
    result_dict = solver_result_envelope_to_dict_v1(result)
    coupled_dict = regional_coupled_solve_to_dict_v1(coupled)
    engineering_dict = engineering_result_envelope_to_dict_v1(engineering_result)
    engineering_dict["solver_derived"] = result.status != :unsupported
    engineering_dict["solver_output_hash"] = engineering_result.result_hash
    artifacts = [
        _v57_runtime_artifact("candidate_solve_manifest_v1", manifest_dict, "compiled"),
        _v57_runtime_artifact("solver_result_envelope_v2", result_dict, String(result.status)),
        _v57_runtime_artifact("regional_coupled_solve_envelope_v1", coupled_dict,
            String(coupled.status)),
        _v57_runtime_artifact("stage5_transport_burn_result_v3", transport,
            result.status == :unsupported ? "unsupported" : "computed"),
        _v57_runtime_artifact("plant_power_ledger_v1", ledger, String(ledger["status"])),
        _v57_runtime_artifact("stage7_engineering_result_v2", engineering_dict,
            String(engineering_result.status)),
    ]
    append!(input["stage_artifacts"], artifacts)
    isempty(input["physical_description"]["species"]) &&
        (input["physical_description"]["species"] = _v57_explicit_fuel_species(genome))
    primary = _v56_primary_region(genome)
    for artifact in artifacts
        artifact_id = String(artifact["artifact_id"])
        push!(input["physical_description"]["observables"], Dict(
            "id" => "observe_$artifact_id", "source_ref" => primary,
            "artifact_hash" => artifact["artifact_hash"]))
        push!(input["evidence"], Dict("evidence_id" => String(artifact["artifact_id"]),
            "artifact_hash" => String(artifact["artifact_hash"]),
            "evidence_class" => "candidate_bound_v59_runtime_product"))
    end
    input["state_evolution"] = state
    input["state_evolution"]["candidate_solve_manifest_hash"] = manifest.manifest_hash
    input["state_evolution"]["solver_result_envelope_ref"] = "solver_result_envelope_v2"
    input["transport_burn"] = transport
    input["transport_burn"]["solver_result_envelope_ref"] = "solver_result_envelope_v2"
    input["engineering"] = engineering_dict
    input["engineering"]["solver_result_envelope_ref"] = "solver_result_envelope_v2"
    input["engineering"]["regional_coupled_result_ref"] =
        "regional_coupled_solve_envelope_v1"
    input["net_energy"] = ledger
    input["net_energy"]["strict_aggregation"] = true
    input["solver_runtime"] = Dict{String,Any}(
        "manifest" => manifest_dict, "result" => result_dict,
        "regional_coupled_result" => coupled_dict,
        "engineering_result" => engineering_dict,
        "plant_power_ledger" => ledger,
        "routing_basis" => "declared requires/provides, regions, operators, state layout, units and time semantics only",
        "operator_ids" => String[item["operator_id"] for item in manifest.module_bindings],
        "unsupported_reasons" => result.unsupported_reasons,
        "coupling_unresolved_reasons" => coupled.unresolved_reasons,
        "evidence_ceiling" => engineering_result.evidence_ceiling)
    input["benchmark_scope"] = "v59_regional_transport_actuator_plant_power_search"
    input["claim_boundary"] = _V59_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    summary = deepcopy(base["artifact_summary"])
    summary["input_hash"] = input_hash
    summary["artifact_count"] = Int(summary["artifact_count"]) + length(artifacts)
    for artifact in artifacts
        summary["artifact_statuses"][String(artifact["artifact_id"])] =
            String(artifact["status"])
    end
    summary["candidate_solver_status"] = String(result.status)
    summary["candidate_solver_convergence_status"] = result.convergence_status
    summary["candidate_solver_manifest_hash"] = manifest.manifest_hash
    summary["candidate_solver_result_hash"] = result.result_hash
    summary["regional_coupled_result_hash"] = coupled.result_hash
    summary["regional_coupled_status"] = String(coupled.status)
    summary["regional_coupled_convergence_status"] = coupled.convergence_status
    summary["engineering_result_hash"] = engineering_result.result_hash
    summary["engineering_status"] = String(engineering_result.status)
    summary["plant_power_ledger_hash"] = plant_ledger.result_hash
    summary["strict_power_ledger_status"] = String(ledger["status"])
    summary["recirculating_power_role_completeness"] = String(get(
        engineering_result.recirculating_power, "role_completeness", "unknown"))
    summary["declared_capability_count"] = length(manifest.capability_declarations)
    summary["selected_operator_count"] = length(manifest.module_bindings)
    cluster_record = unified_screen_candidate_v52(
        solver_ready_candidate_to_dict_v54(candidate))
    summary["mechanism_cluster_id"] = String(cluster_record["mechanism_cluster_id"])
    summary["mechanism_cluster_basis"] = deepcopy(cluster_record["cluster_basis"])
    return Dict{String,Any}("judgment_input" => input,
        "artifact_summary" => summary, "input_hash" => input_hash,
        "manifest" => manifest, "solver_result" => result,
        "regional_coupled_result" => coupled,
        "engineering_result" => engineering_result, "plant_power_ledger" => plant_ledger,
        "cluster_record" => cluster_record, "claim_boundary" => _V59_CLAIM_BOUNDARY)
end

function evaluate_candidate_solver_search_batch_v59(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32])
    bundles = [compile_candidate_solver_judgment_input_v59(context, index;
        discretization_levels = discretization_levels) for index in candidate_indices]
    archive = evaluate_all_search_results_v55(getindex.(bundles, "judgment_input"))
    length(archive["results"]) == length(bundles) || error("v59 dropped a candidate")
    return Dict{String,Any}("bundles" => bundles, "judgment_archive" => archive,
        "claim_boundary" => _V59_CLAIM_BOUNDARY)
end
