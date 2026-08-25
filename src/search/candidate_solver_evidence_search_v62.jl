const _V62_RUNTIME_CLAIM_BOUNDARY = _V62_CLAIM_BOUNDARY * " " *
    "The v62 gate authorizes exhaustive execution when every producer is structurally " *
    "present and the regional numerical gates converge. It does not require or imply an " *
    "eight-stage pass. Independent model, code and experimental evidence remain unknown."

function _v62_state_for_judgment(result::RegionSolveResultEnvelopeV1,
        manifest::CandidateSolveManifestV1, trajectory)
    return Dict{String,Any}("mode" => manifest.time_mode,
        "solver_derived" => result.status != :unsupported, "generated_nominal" => false,
        "solver_output_hash" => trajectory["complete"] === true ? trajectory["result_hash"] :
            result.status != :unsupported ? result.result_hash : "",
        "time_samples_s" => trajectory["time_samples_s"],
        "complete_time_trajectory" => trajectory["complete"],
        "normalized_residual_tolerance" => manifest.numerical_tolerances["normalized_residual"],
        "steady_time_term_tolerance" => manifest.numerical_tolerances["steady_time_term"],
        "required_accounts" => Any["particles", "energy"],
        "residuals" => Any[Dict("account" => item["account"] == "particle" ? "particles" : item["account"],
            "dU_dt" => item["dU_dt"], "divergence_F" => item["divergence_F"],
            "source_S" => item["source_S"], "normalization" => item["normalization"])
            for item in result.global_residuals],
        "regional_residuals" => deepcopy(result.regional_residuals),
        "interface_fluxes" => deepcopy(result.paired_interface_fluxes),
        "evidence_ceiling" => result.evidence_ceiling)
end

function compile_candidate_solver_judgment_input_v62(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32, 64], execute_native_routes::Bool = false,
        compile_problem_artifacts::Bool = false)
    candidate = evaluate_evidence_ready_candidate_v62(context, candidate_index)
    compiled = candidate.prescreen.compiled
    genome = compiled.genome
    base = compile_candidate_bound_judgment_input_v56(context, candidate_index;
        candidate_record = candidate, execute_native_routes = execute_native_routes,
        compile_problem_artifacts = compile_problem_artifacts)
    input = deepcopy(base["judgment_input"])
    manifest = compile_candidate_solve_manifest_v3(genome, compiled.module_ids;
        discretization_levels = discretization_levels)
    specs = compile_region_state_specs_v2(genome, manifest)
    interfaces = compile_interface_flux_contracts_v2(genome, manifest, specs)
    regional = solve_region_partition_v2(manifest, specs, interfaces, genome)
    trajectory = solve_regional_time_trajectory_v1(manifest, specs, interfaces, regional, genome)
    stability = solve_l1_perturbation_suite_v1(manifest, specs, interfaces, regional, genome)
    transport = solve_regional_reaction_transport_v1(manifest, specs, regional, genome)
    if trajectory["complete"] === true
        transport["regional_steady_state_hash"] = transport["state_solution_hash"]
        transport["state_solution_hash"] = trajectory["result_hash"]
        transport["solver_output_hash"] = canonical_hash(Dict{String,Any}(String(key) => value
            for (key, value) in transport if String(key) != "solver_output_hash"))
    end
    engineering = solve_regional_engineering_roles_v1(manifest, specs, interfaces,
        regional, transport)
    ledger = solve_regional_plant_power_ledger_v1(regional, transport, engineering)
    vvuq = orchestrate_l1_vvuq_v1(manifest, regional, stability, transport)

    input["physical_description"]["species"] = Any[Dict(
        "id" => item["species_id"], "mass_amu" => item["mass_amu"],
        "charge_state" => item["charge_state"], "role" => item["role"],
        "region_refs" => item["region_ids"], "binding_basis" => item["declaration_basis"])
        for item in genome.normalized["species_state_contract_v1"]["species_records"]]
    input["state_evolution"] = _v62_state_for_judgment(regional, manifest, trajectory)
    input["perturbation_stability"] = Dict("tests" => deepcopy(stability["tests"]),
        "suite_result_hash" => stability["result_hash"],
        "evidence_ceiling" => stability["evidence_ceiling"])
    input["transport_burn"] = transport
    input["engineering"] = engineering
    input["net_energy"] = ledger
    input["uncertainty_evidence"] = Dict("checks" => deepcopy(vvuq["checks"]),
        "result_hash" => vvuq["result_hash"], "evidence_ceiling" => vvuq["evidence_ceiling"])

    artifact_specs = Any[
        ("species_state_contract_v1", genome.normalized["species_state_contract_v1"], "declared"),
        ("stage3_regional_time_trajectory_v1", trajectory, trajectory["status"]),
        ("stage4_l1_perturbation_suite_v1", stability, stability["status"]),
        ("stage5_regional_reaction_transport_v1", transport,
            transport["reaction_feedback_closure_status"]),
        ("stage6_plant_power_ledger_v1", ledger, ledger["status"]),
        ("stage7_regional_engineering_roles_v1", engineering, "unknown"),
        ("stage8_l1_vvuq_v1", vvuq, vvuq["status"])]
    artifacts = Dict{String,Any}[]
    for (id, details, status) in artifact_specs
        artifact = _v57_runtime_artifact(id, details, status)
        push!(artifacts, artifact)
        push!(input["evidence"], Dict("evidence_id" => id,
            "artifact_hash" => artifact["artifact_hash"],
            "evidence_class" => id in ("stage4_l1_perturbation_suite_v1",
                "stage5_regional_reaction_transport_v1") ?
                "candidate_bound_l1_numerical_result" :
                "candidate_bound_contract_or_bounded_evidence"))
    end
    append!(input["stage_artifacts"], artifacts)
    primary = _v56_primary_region(genome)
    for artifact in artifacts
        push!(input["physical_description"]["observables"], Dict(
            "id" => "observe_$(artifact["artifact_id"])", "source_ref" => primary,
            "artifact_hash" => artifact["artifact_hash"]))
    end
    input["solver_runtime"] = Dict{String,Any}(
        "manifest" => candidate_solve_manifest_to_dict_v1(manifest),
        "region_state_specs" => region_state_spec_to_dict_v1.(specs),
        "interface_flux_contracts" => interface_flux_contract_to_dict_v1.(interfaces),
        "region_solve_result" => region_solve_result_to_dict_v1(regional),
        "time_trajectory" => trajectory,
        "stability_result" => stability, "transport_result" => transport,
        "engineering_result" => engineering, "plant_power_ledger" => ledger,
        "vvuq_result" => vvuq,
        "execution_order" => ["regional_state", "stability", "reaction_transport",
            "engineering_loads", "plant_power_ledger", "vvuq"],
        "routing_basis" => "declared capabilities, regions, species, operators and validity only",
        "family_or_parent_used_for_routing" => false)
    input["benchmark_scope"] = "v62_candidate_bound_evidence_producer_search"
    input["claim_boundary"] = _V62_RUNTIME_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    summary = deepcopy(base["artifact_summary"])
    summary["input_hash"] = input_hash
    summary["artifact_count"] = Int(summary["artifact_count"]) + length(artifacts)
    summary["region_solve_status"] = String(regional.status)
    summary["reaction_feedback_closure_status"] = transport["reaction_feedback_closure_status"]
    summary["stability_status"] = stability["status"]
    summary["plant_power_status"] = ledger["status"]
    summary["vvuq_status"] = vvuq["status"]
    summary["external_evidence_complete"] = false
    return Dict{String,Any}("judgment_input" => input, "artifact_summary" => summary,
        "input_hash" => input_hash, "manifest" => manifest, "region_state_specs" => specs,
        "interface_flux_contracts" => interfaces, "region_solve_result" => regional,
        "time_trajectory" => trajectory,
        "stability_result" => stability, "transport_result" => transport,
        "engineering_result" => engineering, "plant_power_ledger" => ledger,
        "vvuq_result" => vvuq, "candidate" => candidate,
        "claim_boundary" => _V62_RUNTIME_CLAIM_BOUNDARY)
end

function evaluate_uniform_judgment_v62(value)
    record = _v55_record(value)
    result = evaluate_uniform_judgment_v55(record)
    stage = only(item for item in result["stages"] if
        item["stage_id"] == "particle_energy_transport_and_burn")
    closure = String(get(get(record, "transport_burn", Dict{String,Any}()),
        "reaction_feedback_closure_status", "unknown"))
    closure_status = closure == "converged_state_reaction_actuator_balance" ? "pass" :
        startswith(closure, "fail_") ? "fail" : "unknown"
    push!(stage["checks"], _v55_check("state_reaction_actuator_feedback_closure",
        closure_status, "reaction, radiation and self-heating must be returned through realized actuator capacity";
        details = Dict("closure_status" => closure)))
    stage["check_count"] = length(stage["checks"])
    states = String[String(check["status"]) for check in stage["checks"]]
    stage["status"] = any(==("fail"), states) ? "fail" :
        any(state -> state in ("unknown", "unsupported"), states) ? "unknown" : "pass"
    all_states = String[String(item["status"]) for item in result["stages"]]
    result["decision"] = any(==("fail"), all_states) ? "fail" :
        all(==("pass"), all_states) ? "pass" : "unknown"
    result["passed_stage_count"] = count(==("pass"), all_states)
    result["failed_stage_ids"] = String[item["stage_id"] for item in result["stages"] if item["status"] == "fail"]
    result["unknown_stage_ids"] = String[item["stage_id"] for item in result["stages"] if item["status"] == "unknown"]
    result["eligible_for_promotion_review"] = result["decision"] == "pass"
    result["promotion_authorized"] = false
    result["chain_id"] = "uniform_fusion_judgment_chain_v62"
    result["claim_boundary"] = _V62_RUNTIME_CLAIM_BOUNDARY
    return result
end

function _v62_producer_gate(bundle, judgment)
    stage1 = only(item for item in judgment["stages"] if
        item["stage_id"] == "physical_description_completeness")
    roles = Set(String(item["role"]) for item in bundle["plant_power_ledger"]["terms"])
    engineering_ids = Set(String(item["check_id"]) for item in bundle["engineering_result"]["checks"])
    vvuq_ids = Set(String(item["check_id"]) for item in bundle["vvuq_result"]["checks"])
    statuses = Dict{String,String}(
        "physical_description" => stage1["status"] == "pass" ? "pass" : "fail",
        "regional_numerics" => region_full_search_gate_passes_v1(bundle["region_solve_result"]) ? "pass" : "fail",
        "stage4_producer" => length(bundle["stability_result"]["tests"]) == 5 ? "pass" : "fail",
        "stage5_producer" => length(String(bundle["transport_result"]["solver_output_hash"])) == 64 ? "pass" : "fail",
        "stage6_role_coverage" => all(id -> id in roles, ("fusion", "drive", "loss", "recirculating")) ? "pass" : "fail",
        "stage7_role_coverage" => length(engineering_ids) == 11 ? "pass" : "fail",
        "stage8_obligation_coverage" => length(vvuq_ids) == 6 ? "pass" : "fail")
    return statuses
end

function evaluate_candidate_solver_representative_gate_v62(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32, 64])
    indices = Int.(collect(candidate_indices))
    bundles = [compile_candidate_solver_judgment_input_v62(context, index;
        discretization_levels = discretization_levels) for index in indices]
    judgments = [evaluate_uniform_judgment_v62(bundle["judgment_input"]) for bundle in bundles]
    gates = [_v62_producer_gate(bundle, judgment) for (bundle, judgment) in zip(bundles, judgments)]
    ids = sort!(collect(keys(first(gates))))
    histograms = Dict(id => Dict(status => count(item -> item[id] == status, gates)
        for status in ("pass", "fail") if any(item -> item[id] == status, gates)) for id in ids)
    authorized = !isempty(gates) && all(item -> all(==("pass"), values(item)), gates)
    return Dict{String,Any}("candidate_indices" => indices, "bundles" => bundles,
        "judgments" => judgments, "producer_gates" => gates,
        "gate_histograms" => histograms, "full_search_authorized" => authorized,
        "external_evidence_complete" => false, "claim_boundary" => _V62_RUNTIME_CLAIM_BOUNDARY)
end
