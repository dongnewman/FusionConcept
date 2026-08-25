const _V57_CLAIM_BOUNDARY =
    "V57 assembles stage-3 through stage-6 L1 numerical work only from capabilities " *
    "declared by the selected candidate modules. The shared contracts standardize inputs, " *
    "residual audits, hashes, statuses and evidence ceilings; candidate modules select the " *
    "operators. Unsupported inputs remain unsupported and nonconverged calculations remain " *
    "unknown. A low-fidelity control-volume trajectory, Bohm/parallel-loss calculation, or " *
    "reduced D-T reaction/radiation result is screening evidence, not a validated device, " *
    "engineering closure, net-electric claim, C2/C3 promotion, or experimental confirmation."

function _v57_runtime_artifact(id, details, status)
    record = Dict{String,Any}("artifact_id" => String(id), "status" => String(status),
        "details" => _plain_json(details))
    record["artifact_hash"] = canonical_hash(record)
    return record
end

function _v57_explicit_fuel_species(genome::Genome)
    fuel = lowercase(replace(genome.mission.fuel, " " => ""))
    ids = if occursin("d-t", fuel) || occursin("dt", fuel)
        ["deuterium", "tritium", "electrons"]
    elseif occursin("he3", fuel) || occursin("helium-3", fuel)
        ["deuterium", "helium3", "electrons"]
    elseif occursin("11b", fuel) || occursin("boron", fuel)
        ["protons", "boron11", "electrons"]
    elseif occursin("deuter", fuel) || fuel == "d"
        ["deuterium", "electrons"]
    else
        ["declared_fuel_ion", "electrons"]
    end
    return Any[Dict("id" => id, "binding_basis" => "explicit_mission_fuel") for id in ids]
end

"Compile and execute one candidate-bound L1 vertical slice without family routing."
function compile_candidate_solver_judgment_input_v57(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32], execute_native_routes::Bool = false,
        compile_problem_artifacts::Bool = true)
    candidate = evaluate_solver_ready_candidate_v54(context, candidate_index)
    compiled = candidate.prescreen.compiled
    base = compile_candidate_bound_judgment_input_v56(context, candidate_index;
        candidate_record = candidate, execute_native_routes = execute_native_routes,
        compile_problem_artifacts = compile_problem_artifacts)
    input = deepcopy(base["judgment_input"])
    manifest = compile_candidate_solve_manifest_v1(compiled.genome,
        compiled.module_ids; discretization_levels = discretization_levels)
    result = solve_candidate_manifest_v1(manifest)
    state = solver_state_for_v55_v1(result, manifest)
    transport = transport_burn_for_v55_v1(result, manifest)
    ledger = strict_power_ledger_v1(result, transport)
    manifest_dict = candidate_solve_manifest_to_dict_v1(manifest)
    result_dict = solver_result_envelope_to_dict_v1(result)
    manifest_artifact = _v57_runtime_artifact("candidate_solve_manifest_v1",
        manifest_dict, "compiled")
    result_artifact = _v57_runtime_artifact("solver_result_envelope_v1",
        result_dict, String(result.status))
    transport_artifact = _v57_runtime_artifact("stage5_transport_burn_result_v1",
        transport, result.status == :unsupported ? "unsupported" : "computed")
    ledger_artifact = _v57_runtime_artifact("stage6_strict_power_ledger_v1",
        ledger, String(ledger["status"]))
    runtime_artifacts = [manifest_artifact, result_artifact, transport_artifact,
        ledger_artifact]
    append!(input["stage_artifacts"], runtime_artifacts)
    isempty(input["physical_description"]["species"]) &&
        (input["physical_description"]["species"] = _v57_explicit_fuel_species(compiled.genome))
    for artifact in runtime_artifacts
        push!(input["physical_description"]["observables"], Dict(
            "id" => "observe_$(artifact["artifact_id"])",
            "source_ref" => _v56_primary_region(compiled.genome),
            "artifact_hash" => artifact["artifact_hash"]))
    end
    for artifact in runtime_artifacts
        push!(input["evidence"], Dict(
            "evidence_id" => String(artifact["artifact_id"]),
            "artifact_hash" => String(artifact["artifact_hash"]),
            "evidence_class" => "candidate_bound_l1_runtime_product"))
    end
    input["state_evolution"] = state
    input["state_evolution"]["candidate_solve_manifest_hash"] = manifest.manifest_hash
    input["state_evolution"]["solver_result_envelope_ref"] =
        "solver_result_envelope_v1"
    input["transport_burn"] = transport
    input["transport_burn"]["solver_result_envelope_ref"] =
        "solver_result_envelope_v1"
    input["net_energy"] = ledger
    input["net_energy"]["strict_aggregation"] = true
    input["solver_runtime"] = Dict{String,Any}(
        "manifest" => manifest_dict, "result" => result_dict,
        "routing_basis" => "declared_module_capabilities_only",
        "operator_ids" => String[item["operator_id"] for item in manifest.module_bindings],
        "unsupported_reasons" => result.unsupported_reasons,
        "evidence_ceiling" => result.evidence_ceiling)
    input["benchmark_scope"] = "v57_candidate_solver_runtime_full_search"
    input["claim_boundary"] = _V57_CLAIM_BOUNDARY
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
    summary["declared_capability_count"] = length(manifest.capability_declarations)
    summary["selected_operator_count"] = length(manifest.module_bindings)
    summary["strict_power_ledger_status"] = String(ledger["status"])
    cluster_record = unified_screen_candidate_v52(solver_ready_candidate_to_dict_v54(candidate))
    summary["mechanism_cluster_id"] = String(cluster_record["mechanism_cluster_id"])
    summary["mechanism_cluster_basis"] = deepcopy(cluster_record["cluster_basis"])
    return Dict{String,Any}("judgment_input" => input, "artifact_summary" => summary,
        "input_hash" => input_hash, "manifest" => manifest,
        "solver_result" => result, "cluster_record" => cluster_record,
        "claim_boundary" => _V57_CLAIM_BOUNDARY)
end

function evaluate_candidate_solver_search_batch_v57(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32])
    bundles = [compile_candidate_solver_judgment_input_v57(context, index;
        discretization_levels = discretization_levels) for index in candidate_indices]
    inputs = getindex.(bundles, "judgment_input")
    archive = evaluate_all_search_results_v55(inputs)
    length(archive["results"]) == length(bundles) || error("v57 dropped a candidate")
    return Dict{String,Any}("bundles" => bundles, "judgment_archive" => archive,
        "claim_boundary" => _V57_CLAIM_BOUNDARY)
end
