function load_candidate_solver_reference_anchors_v1(path::AbstractString)
    raw = JSON3.read(read(path, String), Dict{String,Any})
    get(raw, "schema_version", nothing) == "1.0.0" || throw(ArgumentError(
        "unsupported candidate solver anchor schema"))
    anchors = get(raw, "anchors", Any[])
    anchors isa AbstractVector && !isempty(anchors) || throw(ArgumentError(
        "candidate solver anchor file has no anchors"))
    return Dict{String,Any}[Dict{String,Any}(String(key) => _plain_json(value)
        for (key, value) in item) for item in anchors]
end

function compile_reference_candidate_solve_manifest_v1(anchor;
        discretization_levels = [64, 128])
    item = _csr_v1_plain_dict(anchor)
    physics_definition = Dict{String,Any}(String(key) => deepcopy(value)
        for (key, value) in item if !(String(key) in
            ("anchor_observables", "source_refs", "claim_boundary", "anchor_kind")))
    physics_hash = canonical_hash(physics_definition)
    initial = Dict{String,Float64}(String(key) => Float64(value)
        for (key, value) in item["initial_conditions"])
    applicability = Dict{String,Any}(
        "status" => "applicable", "unsupported_reasons" => String[],
        "routing_basis" => "declared_module_capabilities_only",
        "nonrouting_fields" => ["family", "parent_family", "display_label"],
        "anchor_kind" => String(item["anchor_kind"]))
    return CandidateSolveManifestV1(candidate_id = String(item["candidate_id"]),
        physics_hash = physics_hash,
        regions = Dict{String,Any}[_csr_v1_plain_dict(value) for value in item["regions"]],
        state_variables = Dict{String,Any}[_csr_v1_plain_dict(value)
            for value in item["state_variables"]],
        capability_declarations = Dict{String,Any}[_csr_v1_plain_dict(value)
            for value in item["capabilities"]],
        module_bindings = Dict{String,Any}[_csr_v1_plain_dict(value)
            for value in item["module_bindings"]],
        time_mode = String(item["time_mode"]), initial_conditions = initial,
        discretization_levels = discretization_levels,
        applicability_scope = applicability,
        parameters = _csr_v1_plain_dict(item["parameters"]))
end

function _csr_anchor_observed_values_v1(result::SolverResultEnvelopeV1)
    values = Dict{String,Any}()
    trajectory = result.state_trajectory
    if get(trajectory, "complete", false) === true
        final = get(trajectory, "final_state", Dict{String,Any}())
        particles = get(final, "particle_inventory", nothing)
        energy = get(final, "thermal_energy", nothing)
        if particles isa Real && energy isa Real && particles > 0
            values["effective_temperature_ev"] = energy /
                (3.0 * particles * _CSR_V1_E_CHARGE)
        end
        times = get(trajectory, "time_samples_s", Any[])
        !isempty(times) && (values["pulse_duration_s"] = Float64(last(times)))
    end
    for observation in result.module_results
        for id in ("fusion_power_w", "self_heating_power_w", "radiation_loss_power_w",
                "state_derived_transport_time_s")
            haskey(observation, id) && (values[id] = observation[id])
        end
    end
    return values
end

function evaluate_reference_vertical_slice_v1(anchor;
        discretization_levels = [64, 128])
    item = _csr_v1_plain_dict(anchor)
    manifest = compile_reference_candidate_solve_manifest_v1(item;
        discretization_levels = discretization_levels)
    result = solve_candidate_manifest_v1(manifest)
    observed = _csr_anchor_observed_values_v1(result)
    comparisons = Dict{String,Any}[]
    for requirement in item["anchor_observables"]
        id = String(requirement["observable_id"])
        value = get(observed, id, nothing)
        lower = Float64(requirement["minimum"])
        upper = Float64(requirement["maximum"])
        within = value isa Real && isfinite(value) && lower <= value <= upper
        push!(comparisons, Dict("observable_id" => id, "observed_value" => value,
            "minimum" => lower, "maximum" => upper, "within_anchor_range" => within,
            "evidence_state" => String(requirement["evidence_state"]),
            "source_ref" => String(requirement["source_ref"])))
    end
    comparison_status = result.status == :unsupported ? "runtime_unsupported" :
        all(item -> item["within_anchor_range"] === true, comparisons) ?
            "within_all_declared_anchor_ranges" : "model_discrepancy"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "anchor_id" => String(item["anchor_id"]),
        "anchor_kind" => String(item["anchor_kind"]),
        "physics_hash" => manifest.physics_hash, "manifest_hash" => manifest.manifest_hash,
        "solver_result_hash" => result.result_hash, "solver_status" => String(result.status),
        "comparison_status" => comparison_status, "observed_values" => observed,
        "comparisons" => comparisons, "source_refs" => item["source_refs"],
        "evidence_ceiling" => result.evidence_ceiling,
        "claim_boundary" => String(item["claim_boundary"]))
    body["validation_hash"] = canonical_hash(body)
    return Dict{String,Any}("manifest" => candidate_solve_manifest_to_dict_v1(manifest),
        "solver_result" => solver_result_envelope_to_dict_v1(result),
        "validation" => body)
end

"Evaluate the same sealed anchor fixture with the v2 convergence runtime."
function evaluate_reference_vertical_slice_v2(anchor;
        discretization_levels = [64, 128])
    item = _csr_v1_plain_dict(anchor)
    manifest = compile_reference_candidate_solve_manifest_v1(item;
        discretization_levels = discretization_levels)
    result = solve_candidate_manifest_v2(manifest)
    observed = _csr_anchor_observed_values_v1(result)
    comparisons = Dict{String,Any}[]
    for requirement in item["anchor_observables"]
        id = String(requirement["observable_id"])
        value = get(observed, id, nothing)
        lower = Float64(requirement["minimum"])
        upper = Float64(requirement["maximum"])
        within = value isa Real && isfinite(value) && lower <= value <= upper
        push!(comparisons, Dict("observable_id" => id, "observed_value" => value,
            "minimum" => lower, "maximum" => upper, "within_anchor_range" => within,
            "evidence_state" => String(requirement["evidence_state"]),
            "source_ref" => String(requirement["source_ref"])))
    end
    comparison_status = result.status == :unsupported ? "runtime_unsupported" :
        all(record -> record["within_anchor_range"] === true, comparisons) ?
            "within_all_declared_anchor_ranges" : "model_discrepancy"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "runtime_version" => "v2",
        "anchor_id" => String(item["anchor_id"]),
        "anchor_kind" => String(item["anchor_kind"]),
        "physics_hash" => manifest.physics_hash, "manifest_hash" => manifest.manifest_hash,
        "solver_result_hash" => result.result_hash, "solver_status" => String(result.status),
        "convergence_status" => result.convergence_status,
        "comparison_status" => comparison_status, "observed_values" => observed,
        "comparisons" => comparisons, "source_refs" => item["source_refs"],
        "evidence_ceiling" => result.evidence_ceiling,
        "claim_boundary" => String(item["claim_boundary"]))
    body["validation_hash"] = canonical_hash(body)
    return Dict{String,Any}("manifest" => candidate_solve_manifest_to_dict_v1(manifest),
        "solver_result" => solver_result_envelope_to_dict_v1(result),
        "validation" => body)
end
