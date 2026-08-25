const _V64_RUNTIME_CLAIM_BOUNDARY = _V64_CLAIM_BOUNDARY * " " *
    "The producer gate requires every applicable plant role, explicit pulse averaging and a " *
    "closed uncertainty interval. Capacity shortfall remains fail; missing declarations or " *
    "upstream outputs remain unknown or unsupported. V64 is L1 candidate screening, not " *
    "vendor qualification, independent-code replication or experimental validation."

function _v64_engineering_for_judgment(result::EngineeringMultiphysicsResultEnvelopeV1,
        manifest::CandidateSolveManifestV1, plant::PlantSubsystemResultEnvelopeV1)
    engineering = _v63_engineering_for_judgment(result, manifest)
    fuel_roles = [item for item in plant.plant_roles if
        String(item["role_id"]) == "particle_injection_fuel_processing"]
    fuel_checks = [item for item in plant.checks if startswith(String(item["check_id"]), "fuel_")]
    status = isempty(fuel_roles) ? "unknown" :
        String(only(fuel_roles)["status"]) == "not_applicable" ? "not_applicable" :
        isempty(fuel_checks) ? "unknown" : any(item -> item["status"] == "fail", fuel_checks) ?
        "fail" : all(item -> item["status"] == "pass", fuel_checks) ? "pass" : "unknown"
    for check in engineering["checks"]
        String(check["check_id"]) == "fuel_cycle" || continue
        check["status"] = status
        check["evidence_refs"] = ["stage7_fuel_inventory_processing_v64"]
        check["source_result_hash"] = plant.result_hash
        check["unknown_basis"] = status == "unknown" ?
            "fuel-cycle numerical result is incomplete" : ""
        check["check_hash"] = canonical_hash(_csr_v1_json_safe(Dict(
            String(key) => value for (key, value) in check if String(key) != "check_hash")))
    end
    for role in plant.plant_roles
        push!(engineering["output_roles"], Dict("role_id" => role["role_id"],
            "status" => role["status"], "output_hash" => role["component_hash"],
            "source_result_hash" => plant.result_hash))
    end
    engineering["plant_subsystem_result_hash"] = plant.result_hash
    engineering["solver_output_hash"] = canonical_hash(_csr_v1_json_safe(engineering))
    return engineering
end

function compile_candidate_solver_judgment_input_v64(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32, 64], execute_native_routes::Bool = false,
        compile_problem_artifacts::Bool = false, candidate_record = nothing)
    candidate = candidate_record === nothing ?
        evaluate_plant_ready_candidate_v64(context, candidate_index) : candidate_record
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
    load_context = engineering_load_context_v1(manifest, regional, transport)
    engineering_manifests = compile_candidate_engineering_manifests_v1(genome)
    multiphysics = solve_magnet_structural_thermal_quench_v1(genome,
        engineering_manifests; load_context = load_context)
    plant_manifest = compile_plant_subsystem_manifest_v1(genome)
    plant = solve_plant_subsystems_v1(genome, plant_manifest, regional, transport,
        multiphysics; load_context = load_context)
    ledger_result = solve_complete_plant_power_ledger_v1(manifest, regional, transport,
        multiphysics, plant_manifest, plant)
    ledger = plant_power_ledger_to_dict_v1(ledger_result)
    engineering = _v64_engineering_for_judgment(multiphysics, manifest, plant)
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
        ("plant_subsystem_manifest_v1", plant_subsystem_manifest_to_dict_v1(plant_manifest),
            String(plant_manifest.status)),
        ("stage7_plant_subsystem_result_v64", plant_subsystem_result_to_dict_v1(plant),
            String(plant.status)),
        ("stage6_complete_plant_power_ledger_v64", ledger, ledger["status"])]
    artifacts = Dict{String,Any}[]
    for (id, details, status) in artifact_specs
        artifact = _v57_runtime_artifact(id, details, status)
        push!(artifacts, artifact)
        push!(input["evidence"], Dict("evidence_id" => id,
            "artifact_hash" => artifact["artifact_hash"],
            "evidence_class" => "candidate_bound_contract_or_l1_plant_numerical_result"))
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
        "time_trajectory" => trajectory, "stability_result" => stability,
        "transport_result" => transport, "engineering_load_context" => load_context,
        "engineering_manifests" => Dict(
            "geometry" => engineering_geometry_manifest_to_dict_v1(engineering_manifests["geometry"]),
            "materials" => material_property_manifest_to_dict_v1(engineering_manifests["materials"]),
            "faults" => fault_scenario_manifest_to_dict_v1(engineering_manifests["faults"])),
        "engineering_multiphysics_result" => engineering_multiphysics_result_to_dict_v1(multiphysics),
        "plant_subsystem_manifest" => plant_subsystem_manifest_to_dict_v1(plant_manifest),
        "plant_subsystem_result" => plant_subsystem_result_to_dict_v1(plant),
        "engineering_result" => engineering, "plant_power_ledger" => ledger,
        "vvuq_result" => vvuq,
        "execution_order" => ["regional_state", "stability", "reaction_transport",
            "finite_em_structure_thermal_quench", "exhaust_fuel_thermal_cycle",
            "complete_plant_power_ledger", "vvuq"],
        "routing_basis" => "declared capabilities, regions, operators and validity ranges",
        "family_or_parent_used_for_routing" => false)
    input["benchmark_scope"] = "v64_candidate_bound_complete_plant_search"
    input["claim_boundary"] = _V64_RUNTIME_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    summary = deepcopy(base["artifact_summary"])
    summary["input_hash"] = input_hash
    summary["artifact_count"] = Int(summary["artifact_count"]) + length(artifacts)
    summary["plant_manifest_status"] = String(plant_manifest.status)
    summary["plant_subsystem_status"] = String(plant.status)
    summary["plant_power_status"] = String(ledger_result.status)
    return Dict{String,Any}("judgment_input" => input, "artifact_summary" => summary,
        "input_hash" => input_hash, "manifest" => manifest,
        "region_state_specs" => specs, "interface_flux_contracts" => interfaces,
        "region_solve_result" => regional, "time_trajectory" => trajectory,
        "stability_result" => stability, "transport_result" => transport,
        "engineering_load_context" => load_context,
        "engineering_manifests" => engineering_manifests,
        "engineering_multiphysics_result" => multiphysics,
        "plant_subsystem_manifest" => plant_manifest, "plant_subsystem_result" => plant,
        "engineering_result" => engineering, "plant_power_ledger" => ledger,
        "plant_power_ledger_result" => ledger_result,
        "vvuq_result" => vvuq, "candidate" => candidate,
        "claim_boundary" => _V64_RUNTIME_CLAIM_BOUNDARY)
end

function evaluate_uniform_judgment_v64(value)
    result = evaluate_uniform_judgment_v62(value)
    result["chain_id"] = "uniform_fusion_judgment_chain_v64"
    result["claim_boundary"] = _V64_RUNTIME_CLAIM_BOUNDARY
    return result
end

function _v64_producer_gate(bundle, judgment)
    base = _v63_producer_gate(bundle, judgment)
    manifest = bundle["plant_subsystem_manifest"]
    plant = bundle["plant_subsystem_result"]
    ledger = bundle["plant_power_ledger_result"]
    role_statuses = Dict(String(item["role_id"]) => String(item["status"])
        for item in ledger.plant_roles)
    all_roles = Set(keys(role_statuses)) == Set(PLANT_SUBSYSTEM_ROLE_IDS_V1) &&
        all(status -> status in ("complete", "not_applicable", "unknown", "unsupported"),
            values(role_statuses))
    pulse_ok = String(plant.time_basis["status"]) == "complete" &&
        (String(plant.time_basis["mode"]) != "cycle_average" ||
         (plant.time_basis["pulse_duration_s"] isa Real &&
          plant.time_basis["repetition_rate_hz"] isa Real))
    interval_ok = all(item -> String(item["status"]) != "complete" ||
        (item["uncertainty_interval"]["lower_w"] isa Real &&
         item["uncertainty_interval"]["upper_w"] isa Real), ledger.plant_roles)
    base["plant_manifest_bundle"] = manifest.status == :pass ? "pass" : "fail"
    base["plant_numerical_execution"] = plant.status in (:pass, :fail) ||
        (plant.status in (:unknown, :unsupported) && !isempty(plant.unresolved_reasons)) ?
        "pass" : "fail"
    base["all_plant_role_coverage"] = all_roles ? "pass" : "fail"
    base["pulse_time_basis"] = pulse_ok ? "pass" : "fail"
    base["power_uncertainty_intervals"] = interval_ok ? "pass" : "fail"
    ledger_classified = Bool(get(ledger.closure, "complete", false)) ||
        (ledger.status == :unknown && !isempty(get(ledger.closure, "unresolved_roles", String[])))
    base["plant_ledger_closure"] = ledger_classified ? "pass" : "fail"
    base["family_free_plant_routing"] = "pass"
    return base
end

function evaluate_candidate_solver_representative_gate_v64(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32, 64])
    indices = Int.(collect(candidate_indices))
    bundles = [compile_candidate_solver_judgment_input_v64(context, index;
        discretization_levels = discretization_levels) for index in indices]
    judgments = [evaluate_uniform_judgment_v64(bundle["judgment_input"]) for bundle in bundles]
    gates = [_v64_producer_gate(bundle, judgment) for
        (bundle, judgment) in zip(bundles, judgments)]
    ids = sort!(collect(keys(first(gates))))
    histograms = Dict(id => Dict(status => count(item -> item[id] == status, gates)
        for status in ("pass", "fail") if any(item -> item[id] == status, gates)) for id in ids)
    authorized = !isempty(gates) && all(item -> all(==("pass"), values(item)), gates)
    return Dict{String,Any}("candidate_indices" => indices, "bundles" => bundles,
        "judgments" => judgments, "producer_gates" => gates,
        "gate_histograms" => histograms, "full_search_authorized" => authorized,
        "claim_boundary" => _V64_RUNTIME_CLAIM_BOUNDARY)
end
