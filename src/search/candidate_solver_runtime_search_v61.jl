const _V61_RUNTIME_CLAIM_BOUNDARY = _V61_CLAIM_BOUNDARY * " " *
    "The v61 runtime solves only a linear L1 conservative regional balance with explicit " *
    "two-point interface operators and bounded region-targeted actuators. Higher stages " *
    "remain unknown unless independently supplied."

function _v61_state_for_judgment(result::RegionSolveResultEnvelopeV1,
        manifest::CandidateSolveManifestV1)
    residuals = Dict{String,Any}[]
    for item in result.global_residuals
        push!(residuals, Dict("account" => item["account"],
            "dU_dt" => item["dU_dt"], "divergence_F" => item["divergence_F"],
            "source_S" => item["source_S"], "normalization" => item["normalization"]))
    end
    return Dict{String,Any}(
        "solver_derived" => result.status == :pass,
        "generated_nominal" => false,
        "solver_output_hash" => result.status == :pass ? result.result_hash : "",
        "solver_status" => String(result.status), "mode" => "steady",
        "residuals" => residuals, "required_accounts" => ["particle", "energy"],
        "normalized_residual_tolerance" => manifest.numerical_tolerances["normalized_residual"],
        "steady_time_term_tolerance" => manifest.numerical_tolerances["steady_time_term"],
        "time_samples_s" => [0.0], "complete_time_trajectory" => true,
        "regional_result_hash" => result.result_hash,
        "region_trajectories" => deepcopy(result.region_trajectories),
        "interface_fluxes" => deepcopy(result.paired_interface_fluxes),
        "evidence_ceiling" => result.evidence_ceiling)
end

function _v61_transport_for_judgment(result::RegionSolveResultEnvelopeV1)
    actuator = result.gate_statuses["actuator_realization"]
    outputs = get(actuator, "outputs", Any[])
    particle_paths = Dict{String,Any}[
        Dict("role" => "production", "source" => "region_targeted_particle_source"),
        Dict("role" => "loss", "source" => "region_targeted_particle_exhaust"),
        Dict("role" => "burn", "status" => "unknown_not_solved_at_L1")]
    energy_paths = Dict{String,Any}[
        Dict("role" => "deposition", "source" => "region_targeted_energy_source"),
        Dict("role" => "transport", "source" => "finite_volume_two_point_flux_v1"),
        Dict("role" => "escape", "source" => "region_targeted_radiation_control")]
    body = Dict{String,Any}(
        "solver_derived" => result.status == :pass, "generated_nominal" => false,
        "state_solution_hash" => result.status == :pass ? result.result_hash : "",
        "particle_paths" => particle_paths, "energy_paths" => energy_paths,
        "fusion_reaction_rate_per_s" => nothing, "fusion_power_w" => nothing,
        "self_heating_power_w" => nothing,
        "confinement_time_source" => "regional_finite_volume_operator",
        "actuator_outputs" => deepcopy(outputs),
        "evidence_ceiling" => "L1_regional_transport_without_reaction_burn_closure")
    body["solver_output_hash"] = result.status == :pass ? canonical_hash(body) : ""
    return body
end

"Compile one v61 candidate through the same eight-stage judgment input and region-first gate."
function compile_candidate_solver_judgment_input_v61(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32, 64], execute_native_routes::Bool = false,
        compile_problem_artifacts::Bool = false)
    candidate = evaluate_regional_solver_candidate_v61(context, candidate_index)
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
    region_result = solve_region_partition_v2(manifest, specs, interfaces, genome)
    state = _v61_state_for_judgment(region_result, manifest)
    transport = _v61_transport_for_judgment(region_result)
    input["state_evolution"] = state
    input["transport_burn"] = transport
    input["net_energy"]["terms"] = Dict{String,Any}[]
    input["net_energy"]["reported_net_power_w"] = nothing
    input["net_energy"]["generated_nominal"] = false
    input["net_energy"]["artificially_closed"] = false
    input["net_energy"]["status"] = "unknown_stage6_not_recomputed_from_v61_regional_output"

    spec_dicts = region_state_spec_to_dict_v1.(specs)
    interface_dicts = interface_flux_contract_to_dict_v1.(interfaces)
    result_dict = region_solve_result_to_dict_v1(region_result)
    contract = deepcopy(genome.normalized["regional_solver_contract_v1"])
    artifacts = Dict{String,Any}[]
    for spec in spec_dicts
        push!(artifacts, _v57_runtime_artifact(
            "region_state_spec_v1__$(spec["region_id"])", spec,
            String(spec["applicability"]["status"])))
    end
    for interface in interface_dicts
        push!(artifacts, _v57_runtime_artifact(
            "interface_flux_contract_v1__$(interface["interface_id"])", interface,
            String(interface["applicability"]["status"])))
    end
    push!(artifacts, _v57_runtime_artifact("regional_solver_contract_v1", contract,
        regional_solver_contract_audit_v61(genome)["status"]))
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
            "evidence_class" => "candidate_bound_v61_regional_runtime_product"))
    end
    input["solver_runtime"] = Dict{String,Any}(
        "manifest" => candidate_solve_manifest_to_dict_v1(manifest),
        "region_state_specs" => spec_dicts,
        "interface_flux_contracts" => interface_dicts,
        "region_solve_result" => result_dict,
        "regional_solver_contract" => contract,
        "execution_order" => ["regional_conservation", "actuator_realization",
            "resolution_convergence", "plant_power_ledger"],
        "full_search_authorized" => region_full_search_gate_passes_v1(region_result),
        "routing_basis" => "declared region/interface/actuator capabilities, units and signs only",
        "family_or_parent_used_for_routing" => false)
    input["benchmark_scope"] = "v61_explicit_regional_genome_runtime"
    input["claim_boundary"] = _V61_RUNTIME_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    cluster = unified_screen_candidate_v52(solver_ready_candidate_to_dict_v54(candidate))
    summary = deepcopy(base["artifact_summary"])
    summary["input_hash"] = input_hash
    summary["artifact_count"] = Int(summary["artifact_count"]) + length(artifacts)
    summary["region_count"] = length(specs)
    summary["interface_count"] = length(interfaces)
    summary["complete_region_spec_count"] = count(spec ->
        spec.applicability["status"] == "complete", specs)
    summary["complete_interface_contract_count"] = count(item ->
        item.applicability["status"] == "complete", interfaces)
    summary["region_solve_status"] = String(region_result.status)
    summary["region_solve_result_hash"] = region_result.result_hash
    summary["gate_statuses"] = deepcopy(region_result.gate_statuses)
    summary["full_search_authorized"] = region_full_search_gate_passes_v1(region_result)
    summary["mechanism_cluster_id"] = cluster["mechanism_cluster_id"]
    summary["regional_contract_hash"] = contract["contract_hash"]
    return Dict{String,Any}("judgment_input" => input, "artifact_summary" => summary,
        "input_hash" => input_hash, "manifest" => manifest,
        "region_state_specs" => specs, "interface_flux_contracts" => interfaces,
        "region_solve_result" => region_result, "candidate" => candidate,
        "cluster_record" => cluster, "claim_boundary" => _V61_RUNTIME_CLAIM_BOUNDARY)
end

function evaluate_candidate_solver_representative_gate_v61(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32, 64])
    indices = Int.(collect(candidate_indices))
    bundles = [compile_candidate_solver_judgment_input_v61(context, index;
        discretization_levels = discretization_levels) for index in indices]
    judgments = [evaluate_uniform_judgment_v55(bundle["judgment_input"]) for bundle in bundles]
    all_three = [region_full_search_gate_passes_v1(bundle["region_solve_result"])
        for bundle in bundles]
    histograms = Dict{String,Dict{String,Int}}()
    for id in ("regional_conservation", "actuator_realization", "resolution_convergence")
        histogram = Dict{String,Int}()
        for bundle in bundles
            status = String(bundle["region_solve_result"].gate_statuses[id]["status"])
            histogram[status] = get(histogram, status, 0) + 1
        end
        histograms[id] = histogram
    end
    authorized = !isempty(all_three) && all(all_three)
    return Dict{String,Any}("candidate_indices" => indices, "bundles" => bundles,
        "judgments" => judgments, "gate_histograms" => histograms,
        "all_candidates_pass_all_three_gates" => authorized,
        "full_search_authorized" => authorized,
        "claim_boundary" => _V61_RUNTIME_CLAIM_BOUNDARY)
end
