const SURVIVOR_EVIDENCE_AUDIT_V91_CLAIM_BOUNDARY =
    "v91 survivor dossiers execute every registered audit slot, but unavailable candidate-bound high-fidelity capabilities remain unknown or unsupported. A reduced solve, manufactured numerical control, published interval regression, or novelty catalog cannot grant higher evidence classes."

function _v91_reduced_nonlinear_solve(input, resolution::Int; source_scale = 1.0)
    resolution >= 8 || throw(ArgumentError("v91 nonlinear resolution is too small"))
    basis = Float64.(input["basis_coefficients"]); n = resolution
    h = 1.0 / (n - 1); diffusion = 0.03 + 0.04basis[7]
    loss = 0.4 + 0.5basis[8]; cubic = 0.08 + 0.12basis[1]
    source = source_scale * (0.7 + 0.6basis[2])
    left_boundary = 0.2 + 0.2basis[3]; right_boundary = 0.1 + 0.1basis[4]
    state = collect(range(left_boundary, right_boundary; length = n)) .+ source / loss
    history = Float64[]; converged = false
    for _ in 1:40
        residual = zeros(Float64, n); diagonal = zeros(Float64, n)
        lower = zeros(Float64, n - 1); upper = zeros(Float64, n - 1)
        residual[1] = state[1] - left_boundary; diagonal[1] = 1.0
        for index in 2:n-1
            residual[index] = -diffusion * (state[index + 1] - 2state[index] +
                state[index - 1]) / h^2 + loss * state[index] +
                cubic * state[index]^3 - source
            lower[index - 1] = -diffusion / h^2
            diagonal[index] = 2diffusion / h^2 + loss + 3cubic * state[index]^2
            upper[index] = -diffusion / h^2
        end
        residual[n] = state[n] - right_boundary; diagonal[n] = 1.0
        norm_value = maximum(abs, residual; init = 0.0); push!(history, norm_value)
        if norm_value <= 1.0e-10
            converged = true; break
        end
        delta = _v91_thomas(diagonal, lower, upper, -residual)
        all(isfinite, delta) || break
        damping = maximum(abs, delta; init = 0.0) > 1.0 ? 0.5 : 1.0
        state .+= damping .* delta
    end
    # Reassemble without reusing the Newton residual array.
    audit = zeros(Float64, n); audit[1] = state[1] - left_boundary
    for index in 2:n-1
        audit[index] = -diffusion * (state[index + 1] - 2state[index] +
            state[index - 1]) / h^2 + loss * state[index] +
            cubic * state[index]^3 - source
    end
    audit[n] = state[n] - right_boundary
    residual_norm = maximum(abs, audit; init = 0.0)
    observable = h * (sum(state) - 0.5state[1] - 0.5state[end])
    body = Dict{String,Any}(
        "status" => converged && residual_norm <= 1.0e-9 ? "pass" : "unknown",
        "resolution" => n, "diffusion" => diffusion, "loss" => loss,
        "cubic_reaction" => cubic, "source" => source,
        "boundary_values" => [left_boundary, right_boundary],
        "state" => state, "observable_integral" => observable,
        "maximum_residual" => residual_norm, "convergence_history" => history,
        "candidate_bound" => true,
        "equation_scope" => "reduced_1d_nonlinear_diffusion_reaction_balance",
        "solver_input_hash" => canonical_hash(Dict(
            "parent_solver_input_hash" => input["solver_input_hash"],
            "resolution" => n, "source_scale" => Float64(source_scale))))
    body["result_hash"] = canonical_hash(body); body
end

function compile_numerical_vvuq_v91(input)
    levels = [_v91_reduced_nonlinear_solve(input, resolution)
        for resolution in (16, 32, 64)]
    observables = Float64[level["observable_integral"] for level in levels]
    differences = [abs(observables[index + 1] - observables[index]) /
        max(abs(observables[index + 1]), 1.0e-12) for index in 1:2]
    monotone = differences[2] <= differences[1] + 1.0e-12
    status = all(level -> level["status"] == "pass", levels) &&
        differences[end] <= 0.02 && monotone ? "pass" : "unknown"
    body = Dict{String,Any}(
        "status" => status, "resolution_count" => 3,
        "resolutions" => [16, 32, 64], "levels" => levels,
        "observable_relative_differences" => differences,
        "convergence_monotone" => monotone,
        "acceptance_threshold" => 0.02,
        "verification_scope" => "reduced_nonlinear_discretization_only",
        "manufactured_control_credit" => false)
    body["result_hash"] = canonical_hash(body); body
end

function _v91_dense_replication(input, reference)
    diagonal = Float64.(input["diagonal"]); lower = Float64.(input["lower"])
    upper = Float64.(input["upper"]); rhs = Float64.(input["right_hand_side"])
    matrix = Tridiagonal(lower, diagonal, upper)
    dense_state = Matrix(matrix) \ rhs
    difference = maximum(abs, dense_state .- Float64.(reference["state"]); init = 0.0)
    Dict{String,Any}(
        "status" => difference <= 1.0e-12 ? "pass" : "fail",
        "maximum_state_difference" => difference,
        "primary_backend" => "custom_thomas_v91",
        "comparison_backend" => "linearalgebra_dense_lu_v91",
        "same_equation_model" => true,
        "independence_group_distinct" => false,
        "scientifically_independent_solver_status" => "unknown",
        "unresolved_solver_disagreement" => false,
        "claim_boundary" => "Numerically separate implementation of the same reduced equations; not an independent physics model or external auditor.")
end

function _v91_parameter_uq(input)
    samples = Dict{String,Any}[]
    for perturbation in (-0.10, -0.075, -0.05, -0.025, 0.0, 0.025, 0.05, 0.075, 0.10)
        solve = _v91_reduced_nonlinear_solve(input, 32;
            source_scale = 1.0 + perturbation)
        push!(samples, Dict("source_relative_perturbation" => perturbation,
            "status" => solve["status"], "observable" => solve["observable_integral"],
            "result_hash" => solve["result_hash"]))
    end
    values = Float64[item["observable"] for item in samples]
    body = Dict{String,Any}(
        "status" => all(item -> item["status"] == "pass", samples) ? "pass" : "unknown",
        "sample_count" => length(samples), "samples" => samples,
        "observable_minimum" => minimum(values), "observable_maximum" => maximum(values),
        "scope" => "deterministic_local_parameter_propagation_not_validation")
    body["result_hash"] = canonical_hash(body); body
end

function _v91_control_fault_response(input)
    basis = Float64.(input["basis_coefficients"])
    state = 0.15 + 0.2basis[3]; target = 0.4 + 0.2basis[4]
    gain = 1.0 + basis[5]; actuator_limit = 0.5 + basis[6]
    peak = state; fault_applied = false
    for step in 1:200
        fault = 70 <= step <= 85 ? 0.35 : 0.0
        fault_applied |= fault > 0
        command = clamp(gain * (target - state), -actuator_limit, actuator_limit)
        state += 0.02 * (command - 0.5state + fault)
        peak = max(peak, abs(state))
    end
    recovered = abs(state - target * gain / (gain + 0.5)) <= 0.08
    body = Dict{String,Any}(
        "status" => fault_applied && recovered && peak <= 1.5 ? "pass" : "fail",
        "fault_window" => [70, 85], "final_state" => state,
        "peak_absolute_state" => peak, "recovered" => recovered,
        "controller_gain" => gain, "actuator_limit" => actuator_limit,
        "scope" => "reduced_bounded_scalar_feedback_fault_response")
    body["result_hash"] = canonical_hash(body); body
end

function _v91_reference_matrix(topology, reference_catalog)
    candidate_count = length(topology["nodes"])
    entries = Dict{String,Any}[]
    for reference in get(reference_catalog, "references", Any[])
        mapped_count = Int(reference["mapped_region_count"])
        push!(entries, Dict{String,Any}(
            "reference_id" => reference["reference_id"],
            "source_url" => reference["source_url"],
            "source_title" => reference["source_title"],
            "mapped_region_count" => mapped_count,
            "candidate_region_count" => candidate_count,
            "isomorphic" => mapped_count == candidate_count ? "unknown_not_fully_mapped" : false,
            "nonisomorphism_proof" => mapped_count == candidate_count ? nothing :
                "vertex_count_mismatch_in_declared_region_abstraction",
            "mapping_scope" => reference["mapping_scope"]))
    end
    entries
end

function audit_hard_gate_survivor_v91(index::Integer, reference_catalog_raw)
    topology = generate_family_neutral_topology_v91(index; relabel_nonce = 41)
    input = compile_candidate_bound_screen_input_v91(topology, index)
    screen = solve_candidate_bound_screen_v91(input)
    screen["hard_gate_survivor"] === true || throw(ArgumentError(
        "v91 deep audit may only consume a preregistered hard-gate survivor"))
    numerical = compile_numerical_vvuq_v91(input)
    dense = _v91_dense_replication(input, screen)
    uq = _v91_parameter_uq(input); control = _v91_control_fault_response(input)
    catalog = _v89_plain(reference_catalog_raw)
    comparison = _v91_reference_matrix(topology, catalog)
    external_nonisomorphic = all(item -> item["isomorphic"] === false, comparison)
    stages = Dict{String,Any}[
        Dict("stage_id" => "candidate_bound_nonlinear_dae_closure",
            "status" => numerical["status"], "evidence" => numerical,
            "evidence_ceiling" => "reduced_1d_nonlinear_balance"),
        Dict("stage_id" => "applicable_equilibrium",
            "status" => "unsupported", "metric" => nothing,
            "unavailable_reason" => "candidate_bound_free_boundary_or_3d_equilibrium_backend_not_available_for_this_generated_topology"),
        Dict("stage_id" => "field_line_orbit_confinement",
            "status" => "unsupported", "metric" => nothing,
            "unavailable_reason" => "candidate_bound_3d_coil_geometry_and_orbit_initial_distribution_not_available"),
        Dict("stage_id" => "ideal_stability",
            "status" => "pass", "metric" => screen["physical_metrics"]["reduced_stability_margin"],
            "evidence_ceiling" => "reduced_screening_mode_only"),
        Dict("stage_id" => "resistive_stability", "status" => "unsupported",
            "metric" => nothing, "unavailable_reason" => "no_candidate_bound_resistive_mhd_backend"),
        Dict("stage_id" => "kinetic_stability", "status" => "unsupported",
            "metric" => nothing, "unavailable_reason" => "no_candidate_bound_distribution_or_kinetic_backend"),
        Dict("stage_id" => "nonlinear_stability", "status" => "unsupported",
            "metric" => nothing, "unavailable_reason" => "no_candidate_bound_nonlinear_mhd_or_kinetic_backend"),
        Dict("stage_id" => "transport_reaction_radiation_self_heating_burn",
            "status" => numerical["status"], "metric" =>
                numerical["levels"][end]["observable_integral"],
            "evidence_ceiling" => "reduced_diffusion_reaction_balance_not_burn_prediction"),
        Dict("stage_id" => "actuator_controller_fault_response",
            "status" => control["status"], "evidence" => control,
            "evidence_ceiling" => "reduced_scalar_feedback"),
        Dict("stage_id" => "electromagnetic_force", "status" => "unknown",
            "metric" => nothing, "unavailable_reason" => "screening_field_amplitude_has_no_candidate_bound_conductor_force_mesh"),
        Dict("stage_id" => "structure", "status" => "unsupported",
            "metric" => nothing, "unavailable_reason" => "no_candidate_bound_structural_mesh_material_and_load_case"),
        Dict("stage_id" => "thermal_material", "status" => "unsupported",
            "metric" => nothing, "unavailable_reason" => "no_candidate_bound_thermal_material_lifetime_model"),
        Dict("stage_id" => "shielding", "status" => "unsupported",
            "metric" => nothing, "unavailable_reason" => "no_candidate_bound_neutronics_shielding_model"),
        Dict("stage_id" => "cryogenic", "status" => "unsupported",
            "metric" => nothing, "unavailable_reason" => "no_candidate_bound_cryogenic_system_model"),
        Dict("stage_id" => "maintenance", "status" => "unsupported",
            "metric" => nothing, "unavailable_reason" => "no_candidate_bound_maintenance_access_and_dose_model"),
        Dict("stage_id" => "numerical_vvuq", "status" => numerical["status"],
            "evidence" => numerical),
        Dict("stage_id" => "parameter_uq", "status" => uq["status"],
            "evidence" => uq),
        Dict("stage_id" => "independent_solver_auditor_comparison",
            "status" => "unknown", "evidence" => dense,
            "unavailable_reason" => "numerical replication is same-model and not an independent physics solver"),
        Dict("stage_id" => "candidate_bound_validation_vvuq",
            "status" => "unknown", "metric" => nothing,
            "manufactured_control_credit" => false,
            "sentinel_containment_credit" => false,
            "published_interval_regression_credit" => false,
            "unavailable_reason" => "no_real_experiment_or_hardware_dataset_bound_to_this_candidate"),
        Dict("stage_id" => "external_novelty",
            "status" => external_nonisomorphic ? "pass_within_declared_catalog" : "unknown",
            "comparison_matrix" => comparison,
            "search_scope" => get(catalog, "search_scope", nothing),
            "search_date" => get(catalog, "search_date", nothing),
            "replay_record" => get(catalog, "replay_record", nothing),
            "patentability_claimed" => false, "fto_claimed" => false)]
    unsupported = count(stage -> stage["status"] == "unsupported", stages)
    unknown = count(stage -> stage["status"] == "unknown", stages)
    novel_topology = external_nonisomorphic
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_id" => "v91-candidate-$index",
        "request_index" => Int(index), "classification" => Dict(
            "novel_topology_candidate" => novel_topology,
            "computationally_credible_fusion_device_concept" => false,
            "engineering_qualified_fusion_device_design" => false,
            "experimentally_validated_new_fusion_device" => false),
        "genome" => Dict("grammar_id" => topology["grammar_id"],
            "structural_gene_digits" => topology["structural_gene_digits"],
            "topology" => topology),
        "basis" => input["basis_coefficients"],
        "realization" => Dict("solver_input_hash" => input["solver_input_hash"],
            "capability_inventory" => input["capability_inventory"],
            "capability_cell" => input["capability_cell"]),
        "solver_input" => input, "screen_result" => screen,
        "stages" => stages, "stage_unsupported_count" => unsupported,
        "stage_unknown_count" => unknown,
        "numerical_vvuq_status" => numerical["status"],
        "validation_vvuq_status" => "unknown",
        "engineering_obligations_status" => "unsupported",
        "unresolved_solver_disagreement_status" => "unknown_independent_model_missing",
        "hard_gate_failure_compensated" => false,
        "evidence_ceiling" => "novel_topology_candidate_at_most",
        "claim_boundary" => SURVIVOR_EVIDENCE_AUDIT_V91_CLAIM_BOUNDARY)
    normalized = _v89_plain(JSON3.read(JSON3.write(body), Dict{String,Any}))
    normalized["dossier_hash"] = canonical_hash(normalized); normalized
end

function audit_campaign_survivors_v91(campaign_directory::AbstractString,
        reference_catalog_path::AbstractString; output_path::Union{Nothing,AbstractString} = nothing)
    root = abspath(campaign_directory)
    merge_path = joinpath(root, "campaign_v91_merged.json")
    isfile(merge_path) || throw(ArgumentError("v91 merged campaign is missing"))
    merged = _v89_plain(JSON3.read(read(merge_path, String), Dict{String,Any}))
    merged["status"] == "pass" || throw(ArgumentError(
        "v91 survivor audit requires a passed campaign"))
    catalog = _v89_plain(JSON3.read(read(reference_catalog_path, String),
        Dict{String,Any}))
    target = output_path === nothing ? joinpath(root, "survivor_dossiers_v91.jsonl") :
        abspath(output_path)
    mkpath(dirname(target)); temporary = target * ".partial"
    counts = Dict("novel_topology_candidate" => 0,
        "computationally_credible_fusion_device_concept" => 0,
        "engineering_qualified_fusion_device_design" => 0,
        "experimentally_validated_new_fusion_device" => 0)
    dossier_hashes = String[]
    open(temporary, "w") do io
        for index_any in merged["hard_gate_survivor_indices"]
            dossier = audit_hard_gate_survivor_v91(Int(index_any), catalog)
            for key in keys(counts)
                counts[key] += dossier["classification"][key] === true
            end
            push!(dossier_hashes, dossier["dossier_hash"]); _v91_json_line(io, dossier)
        end
    end
    mv(temporary, target; force = true)
    summary = Dict{String,Any}(
        "status" => "complete", "campaign_hash" => merged["campaign_hash"],
        "survivor_count" => length(merged["hard_gate_survivor_indices"]),
        "dossier_count" => length(dossier_hashes), "classification_counts" => counts,
        "credible_new_device_count" => counts[
            "computationally_credible_fusion_device_concept"],
        "computationally_credible_new_device_count" => counts[
            "computationally_credible_fusion_device_concept"],
        "engineering_qualified_new_device_count" => counts[
            "engineering_qualified_fusion_device_design"],
        "experimentally_validated_new_fusion_device_count" => counts[
            "experimentally_validated_new_fusion_device"],
        "dominant_blockers" => [
            "candidate_bound_free_boundary_or_3d_equilibrium",
            "field_line_and_orbit_confinement",
            "resistive_kinetic_and_nonlinear_stability",
            "independent_physics_solver_comparison",
            "structural_thermal_material_shielding_cryogenic_maintenance_closure",
            "candidate_bound_real_experimental_validation_vvuq"],
        "dossier_stream" => basename(target),
        "dossier_stream_sha256" => _s70_file_sha256(target),
        "dossier_set_hash" => canonical_hash(dossier_hashes),
        "claim_boundary" => SURVIVOR_EVIDENCE_AUDIT_V91_CLAIM_BOUNDARY)
    summary["summary_hash"] = canonical_hash(summary)
    _v91_atomic_json(joinpath(root, "survivor_dossiers_v91_summary.json"), summary)
    summary
end
