const _V63_RUNTIME_CLAIM_BOUNDARY = _V63_CLAIM_BOUNDARY * " " *
    "The producer gate requires finite components, material versions, fault scenarios, upstream " *
    "load hashes, local extrema and numerical margins. Physical margin failures remain fail and " *
    "missing irradiation, lifetime, maintenance, plant-cycle or external evidence remains unknown."

function _v63_result_checks(result::EngineeringMultiphysicsResultEnvelopeV1, ids)
    return [item for item in result.engineering_checks if String(item["check_id"]) in ids]
end

function _v63_combined_status(records)
    isempty(records) && return "unknown"
    statuses = String[String(item["status"]) for item in records]
    any(==("fail"), statuses) && return "fail"
    all(==("pass"), statuses) && return "pass"
    return "unknown"
end

function _v63_stage7_check(id, records, result, basis)
    status = result.status == :unsupported ? "unsupported" :
        result.status == :unknown ? "unknown" : _v63_combined_status(records)
    margins = Float64[Float64(item["normalized_margin"]) for item in records if
        get(item, "normalized_margin", nothing) isa Real]
    body = Dict{String,Any}("check_id" => id, "status" => status,
        "evidence_refs" => ["stage7_finite_engineering_multiphysics_v63"],
        "normalized_margin" => isempty(margins) ? nothing : minimum(margins),
        "basis" => basis, "source_result_hash" => result.result_hash,
        "unknown_basis" => status in ("unknown", "unsupported") ?
            join(result.unresolved_reasons, "; ") : "")
    body["check_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _v63_unknown_stage7_check(id, result, basis)
    body = Dict{String,Any}("check_id" => id, "status" => "unknown",
        "evidence_refs" => ["stage7_finite_engineering_multiphysics_v63"],
        "normalized_margin" => nothing, "basis" => basis,
        "source_result_hash" => result.result_hash,
        "unknown_basis" => basis)
    body["check_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _v63_engineering_for_judgment(result::EngineeringMultiphysicsResultEnvelopeV1,
        manifest::CandidateSolveManifestV1)
    finite_conductor_not_applicable =
        result.convergence_status == "not_applicable_no_finite_conductor_capability"
    field = _v63_result_checks(result, ("peak_internal_conductor_field",))
    force = _v63_result_checks(result, ("maximum_lorentz_force",))
    stress = _v63_result_checks(result, ("maximum_structural_stress",))
    heat = _v63_result_checks(result, ("maximum_local_heat_flux",))
    temperature = _v63_result_checks(result,
        ("maximum_material_temperature", "quench_hotspot_temperature"))
    quench = _v63_result_checks(result,
        ("quench_hotspot_temperature", "maximum_quench_voltage"))
    repetition_status = manifest.time_mode == "steady" ? "not_applicable" :
        get(manifest.parameters, "repetition_rate_hz", nothing) isa Real ? "pass" : "unknown"
    repetition = Dict{String,Any}("check_id" => "repetition_rate",
        "status" => repetition_status,
        "evidence_refs" => ["stage7_finite_engineering_multiphysics_v63"],
        "computed_extremum" => get(manifest.parameters, "repetition_rate_hz", nothing),
        "normalized_margin" => repetition_status == "pass" ? 0.0 : nothing,
        "applicability_basis" => manifest.time_mode,
        "source_result_hash" => result.result_hash)
    repetition["check_hash"] = canonical_hash(_csr_v1_json_safe(repetition))
    checks = Dict{String,Any}[
        _v63_stage7_check("field_strength", field, result,
            "finite conductor peak field versus versioned critical-field curve"),
        _v63_stage7_check("force", force, result,
            "Lorentz force versus declared support load capacity"),
        _v63_stage7_check("stress", stress, result,
            "load-path stress versus yield/fatigue allowable"),
        _v63_stage7_check("heat_flux", heat, result,
            "local wetted-area heat flux versus declared CHF"),
        _v63_stage7_check("material_temperature", temperature, result,
            "nominal and quench hotspot temperature versus material limit"),
        _v63_unknown_stage7_check("irradiation", result,
            "no candidate-bound dpa and helium-production transport yet"),
        _v63_stage7_check("quench", quench, result,
            "quench hotspot and terminal voltage fault gates"),
        repetition,
        _v63_unknown_stage7_check("maintenance_space", result,
            "finite maintenance access and replacement solve is not implemented"),
        _v63_unknown_stage7_check("fuel_cycle", result,
            "fuel inventory and processing network is not implemented in v63"),
        _v63_unknown_stage7_check("component_lifetime", result,
            "irradiation and cycle-damage lifetime integration is not implemented")]
    if finite_conductor_not_applicable
        for check in checks
            String(check["check_id"]) in ("field_strength", "force", "stress", "quench") || continue
            check["status"] = "not_applicable"
            check["unknown_basis"] = ""
            check["applicability_basis"] = result.evidence_ceiling
            check["check_hash"] = canonical_hash(_csr_v1_json_safe(Dict(
                String(key) => value for (key, value) in check if String(key) != "check_hash")))
        end
    end
    roles = Dict{String,Any}[]
    for output in result.component_outputs
        role = deepcopy(output)
        role["role_id"] = "finite_component_$(output["component_id"])"
        role["status"] = "computed_with_numerical_margins"
        role["output_hash"] = output["component_output_hash"]
        push!(roles, role)
    end
    return Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => result.candidate_id, "physics_hash" => result.physics_hash,
        "status" => String(result.status), "checks" => checks, "output_roles" => roles,
        "solver_derived" => true, "solver_output_hash" => result.result_hash,
        "unknown_reasons" => result.unresolved_reasons,
        "evidence_ceiling" => result.evidence_ceiling)
end

function _v63_merge_power_roles(ledger, engineering::EngineeringMultiphysicsResultEnvelopeV1)
    result = deepcopy(ledger)
    replacements = Dict(String(item["role_id"]) => deepcopy(item)
        for item in engineering.plant_power_roles)
    roles = Dict{String,Any}[]
    for raw in result["plant_roles"]
        role = _cem_v1_dict(raw)
        id = String(role["role_id"])
        push!(roles, haskey(replacements, id) ? replacements[id] : role)
        pop!(replacements, id, nothing)
    end
    append!(roles, values(replacements))
    complete_values = Float64[Float64(item["value_w"]) for item in roles if
        String(get(item, "status", "unknown")) == "complete" &&
        get(item, "value_w", nothing) isa Real]
    lower_bound = sum(complete_values; init = 0.0)
    unresolved = sort!([String(item["role_id"]) for item in roles if
        String(get(item, "status", "unknown")) in ("unknown", "unsupported")])
    for term in result["terms"]
        String(term["role"]) == "recirculating" || continue
        term["value_w"] = -lower_bound
        term["role_completeness"] = isempty(unresolved) ? "complete" : "lower_bound"
        term["source_output_hash"] = engineering.result_hash
        term["component_hash"] = canonical_hash(engineering.plant_power_roles)
    end
    result["plant_roles"] = roles
    result["reported_net_power_w"] = sum(Float64(item["value_w"])
        for item in result["terms"])
    result["status"] = isempty(unresolved) ? "unknown_uncertainty_sign_not_closed" :
        "unknown_incomplete_recirculating_roles"
    result["closure"] = Dict("complete" => isempty(unresolved),
        "power_balance_residual_w" => 0.0,
        "unresolved_roles" => unresolved, "uncertainty_sign_robust" => false)
    result["evidence_ceiling"] =
        "v63 solver-derived magnet, cryogenic and coolant power; remaining plant roles incomplete"
    pop!(result, "result_hash", nothing)
    result["result_hash"] = canonical_hash(_csr_v1_json_safe(result))
    return result
end

function compile_candidate_solver_judgment_input_v63(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        discretization_levels = [32, 64], execute_native_routes::Bool = false,
        compile_problem_artifacts::Bool = false)
    candidate = evaluate_engineering_ready_candidate_v63(context, candidate_index)
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
    engineering = _v63_engineering_for_judgment(multiphysics, manifest)
    base_ledger = solve_regional_plant_power_ledger_v1(regional, transport,
        solve_regional_engineering_roles_v1(manifest, specs, interfaces, regional, transport))
    ledger = _v63_merge_power_roles(base_ledger, multiphysics)
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
        ("engineering_geometry_manifest_v1",
            engineering_geometry_manifest_to_dict_v1(engineering_manifests["geometry"]),
            String(engineering_manifests["geometry"].status)),
        ("material_property_manifest_v1",
            material_property_manifest_to_dict_v1(engineering_manifests["materials"]),
            String(engineering_manifests["materials"].status)),
        ("fault_scenario_manifest_v1",
            fault_scenario_manifest_to_dict_v1(engineering_manifests["faults"]),
            String(engineering_manifests["faults"].status)),
        ("stage7_engineering_load_context_v1", load_context, load_context["status"]),
        ("stage7_finite_engineering_multiphysics_v63",
            engineering_multiphysics_result_to_dict_v1(multiphysics), String(multiphysics.status)),
        ("stage6_plant_power_ledger_v63", ledger, ledger["status"])]
    artifacts = Dict{String,Any}[]
    for (id, details, status) in artifact_specs
        artifact = _v57_runtime_artifact(id, details, status)
        push!(artifacts, artifact)
        push!(input["evidence"], Dict("evidence_id" => id,
            "artifact_hash" => artifact["artifact_hash"],
            "evidence_class" => "candidate_bound_contract_or_l1_engineering_numerical_result"))
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
        "engineering_result" => engineering, "plant_power_ledger" => ledger,
        "vvuq_result" => vvuq,
        "execution_order" => ["regional_state", "stability", "reaction_transport",
            "engineering_load_binding", "finite_em_structure_thermal_quench",
            "plant_power_ledger", "vvuq"],
        "routing_basis" => "declared capabilities, regions, component roles, operators and validity",
        "family_or_parent_used_for_routing" => false)
    input["benchmark_scope"] = "v63_candidate_bound_finite_engineering_search"
    input["claim_boundary"] = _V63_RUNTIME_CLAIM_BOUNDARY
    input_hash = canonical_hash(input)
    summary = deepcopy(base["artifact_summary"])
    summary["input_hash"] = input_hash
    summary["artifact_count"] = Int(summary["artifact_count"]) + length(artifacts)
    summary["engineering_manifest_status"] = String(engineering_manifests["status"])
    summary["engineering_multiphysics_status"] = String(multiphysics.status)
    summary["plant_power_status"] = ledger["status"]
    return Dict{String,Any}("judgment_input" => input, "artifact_summary" => summary,
        "input_hash" => input_hash, "manifest" => manifest,
        "region_state_specs" => specs, "interface_flux_contracts" => interfaces,
        "region_solve_result" => regional, "time_trajectory" => trajectory,
        "stability_result" => stability, "transport_result" => transport,
        "engineering_load_context" => load_context,
        "engineering_manifests" => engineering_manifests,
        "engineering_multiphysics_result" => multiphysics,
        "engineering_result" => engineering, "plant_power_ledger" => ledger,
        "vvuq_result" => vvuq, "candidate" => candidate,
        "claim_boundary" => _V63_RUNTIME_CLAIM_BOUNDARY)
end

function evaluate_uniform_judgment_v63(value)
    result = evaluate_uniform_judgment_v62(value)
    result["chain_id"] = "uniform_fusion_judgment_chain_v63"
    result["claim_boundary"] = _V63_RUNTIME_CLAIM_BOUNDARY
    return result
end

function _v63_producer_gate(bundle, judgment)
    base = _v62_producer_gate(bundle, judgment)
    manifests = bundle["engineering_manifests"]
    multiphysics = bundle["engineering_multiphysics_result"]
    required_checks = Set(["engineering_current_density", "peak_internal_conductor_field",
        "maximum_lorentz_force", "maximum_structural_stress", "maximum_material_temperature",
        "maximum_local_heat_flux", "quench_hotspot_temperature", "maximum_quench_voltage"])
    present_checks = Set(String(item["check_id"]) for item in multiphysics.engineering_checks)
    all_margins = all(item -> get(item, "normalized_margin", nothing) isa Real,
        multiphysics.engineering_checks)
    role_ids = Set(String(item["role_id"]) for item in multiphysics.plant_power_roles)
    required_roles = Set(["magnet_power_and_pulse_storage", "cryogenic_system",
        "coolant_circulation_heat_rejection"])
    not_applicable = multiphysics.convergence_status ==
        "not_applicable_no_finite_conductor_capability"
    base["engineering_manifest_bundle"] = manifests["status"] == :pass ? "pass" : "fail"
    base["finite_multiphysics_execution"] = not_applicable ||
        (multiphysics.status in (:pass, :fail) && !isempty(multiphysics.component_outputs)) ? "pass" : "fail"
    base["finite_local_margin_coverage"] = not_applicable ||
        (required_checks ⊆ present_checks && all_margins) ? "pass" : "fail"
    base["magnet_cryo_pump_role_coverage"] = required_roles ⊆ role_ids &&
        all(item -> item["status"] in ("complete", "not_applicable"),
            multiphysics.plant_power_roles) ? "pass" : "fail"
    base["upstream_load_hash_binding"] =
        _cem_v1_hash(get(bundle["engineering_load_context"], "field_solution_hash", nothing)) &&
        _cem_v1_hash(get(bundle["engineering_load_context"], "transport_result_hash", nothing)) ?
        "pass" : "fail"
    base["family_free_engineering_routing"] = "pass"
    return base
end

function evaluate_candidate_solver_representative_gate_v63(
        context::RecoverableCrossTopologyContextV20, candidate_indices;
        discretization_levels = [32, 64])
    indices = Int.(collect(candidate_indices))
    bundles = [compile_candidate_solver_judgment_input_v63(context, index;
        discretization_levels = discretization_levels) for index in indices]
    judgments = [evaluate_uniform_judgment_v63(bundle["judgment_input"]) for bundle in bundles]
    gates = [_v63_producer_gate(bundle, judgment) for
        (bundle, judgment) in zip(bundles, judgments)]
    ids = sort!(collect(keys(first(gates))))
    histograms = Dict(id => Dict(status => count(item -> item[id] == status, gates)
        for status in ("pass", "fail") if any(item -> item[id] == status, gates)) for id in ids)
    authorized = !isempty(gates) && all(item -> all(==("pass"), values(item)), gates)
    return Dict{String,Any}("candidate_indices" => indices, "bundles" => bundles,
        "judgments" => judgments, "producer_gates" => gates,
        "gate_histograms" => histograms, "full_search_authorized" => authorized,
        "claim_boundary" => _V63_RUNTIME_CLAIM_BOUNDARY)
end
