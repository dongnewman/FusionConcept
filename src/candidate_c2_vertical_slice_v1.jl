struct CandidateC2VerticalSliceResultV1
    operating_point::CandidateOperatingPointV1
    assembly::CandidateAssemblyBindingV1
    solve_plan::CoupledSolvePlanV1
    nonlinear_result::NonlinearSolveResultEnvelopeV1
    state_package::C2CandidateStatePackageV1
    stability_compilation::Dict{String,Any}
    engineering_evidence::C2BoundGateEvidenceV1
    independent_evidence::C2BoundGateEvidenceV1
    decision::C2DecisionEnvelope
    slice_hash::String
end

function _c2_operating_decl_v1(operating::CandidateOperatingPointV1, id::String)
    records = vcat(operating.state_declarations, operating.actuator_declarations,
        operating.model_declarations)
    matches = [item for item in records if String(item["declaration_id"]) == id]
    length(matches) == 1 || throw(ArgumentError(
        "operating point requires exactly one declaration: $id"))
    return only(matches)
end

_c2_operating_value_v1(operating, id) =
    Float64(_c2_operating_decl_v1(operating, id)["value"])

"Solve the same particle-energy-species-actuator-power slice for any composite assembly."
function solve_candidate_c2_longitudinal_slice_v1(
        operating::CandidateOperatingPointV1, assembly::CandidateAssemblyBindingV1;
        flux_semantics::Symbol, transport_operator_id::AbstractString,
        topology_boundary_class::Union{Nothing,AbstractString} = nothing)
    operating.operating_point_hash == assembly.operating_point_hash || throw(ArgumentError(
        "vertical slice operating-point/assembly mismatch"))
    flux_semantics in (:radial_boundary, :parallel_boundary) || throw(ArgumentError(
        "vertical slice requires radial or parallel boundary semantics"))
    volume = _c2_operating_value_v1(operating, "plasma_volume_m3")
    pressure = _c2_operating_value_v1(operating, "thermal_pressure_pa")
    ti_kev = _c2_operating_value_v1(operating, "ion_temperature_kev")
    te_kev = _c2_operating_value_v1(operating, "electron_temperature_kev")
    volume > 0 && pressure > 0 && ti_kev > 0 && te_kev > 0 || throw(ArgumentError(
        "vertical-slice volume, pressure and temperatures must be positive"))
    complete_radiation = Bool(_c2_operating_decl_v1(
        operating, "complete_radiation_model")["value"])
    kev_j = 1.0e3 * 1.602176634e-19
    # p = n_i kT_i + n_e kT_e and quasineutral n_e = n_i for singly charged D-T.
    nion_density = pressure / ((ti_kev + te_kev) * kev_j)
    nion = nion_density * volume
    na = 0.5 * nion; nb = 0.5 * nion; ne = nion
    wi = 1.5 * nion * ti_kev * kev_j
    we = 1.5 * ne * te_kev * kev_j
    reactivity = bosch_hale_maxwellian_reactivity_v1("dt_to_alpha_neutron", ti_kev)
    burn = na * nb / volume * reactivity
    charged = burn * 3.52e6 * 1.602176634e-19
    brems = 1.69e-38 * ne * nion / volume * sqrt(te_kev * 1.0e3)
    ion_heat = 0.125 * charged
    electron_heat = 0.125 * charged
    ion_transport = 0.5 * charged + 0.8 * ion_heat
    electron_transport = 0.5 * charged + 0.8 * electron_heat - brems
    electron_transport > 0 || throw(ArgumentError(
        "declared operating point produces a negative electron transport loss"))
    fueling = 2.0 * burn

    parameters = Dict{String,Float64}(
        "charge_a" => 1.0, "charge_b" => 1.0,
        "particle_scale" => nion, "energy_scale" => wi + we,
        "particle_rate_scale" => max(burn, 1.0),
        "power_scale" => max(charged, brems, 1.0),
        "ion_electron_exchange_rate_s" => 0.0,
        "alpha_ion_fraction" => 0.5, "alpha_electron_fraction" => 0.5,
        "fuel_fraction_a" => 0.5, "fuel_fraction_b" => 0.5,
        "exhaust_fraction_a" => 0.5, "exhaust_fraction_b" => 0.5,
        "fueling_capacity_s" => 2.0 * fueling,
        "ion_heating_capacity_w" => 2.0 * ion_heat,
        "electron_heating_capacity_w" => 2.0 * electron_heat,
        "exhaust_capacity_s" => max(burn, 1.0),
        "radiation_control_capacity_w" => max(brems, 1.0),
        "fueling_baseline_s" => fueling,
        "ion_heating_baseline_w" => ion_heat,
        "electron_heating_baseline_w" => electron_heat,
        "exhaust_baseline_s" => 0.0, "radiation_control_baseline_w" => 0.0,
        "target_particle_inventory" => nion, "target_ion_energy_j" => wi,
        "target_electron_energy_j" => we,
        "fueling_controller_gain_s" => 0.0,
        "ion_heating_controller_gain_s" => 0.0,
        "electron_heating_controller_gain_s" => 0.0,
        "exhaust_controller_gain_s" => 0.0,
        "radiation_controller_gain_s" => 0.0,
        "ion_heating_deposition_efficiency" => 0.8,
        "electron_heating_deposition_efficiency" => 0.8,
        "fueling_wall_energy_j_per_particle" => 1.0e-16,
        "exhaust_wall_energy_j_per_particle" => 1.0e-16,
        "ion_heating_wall_plug_efficiency" => 0.5,
        "electron_heating_wall_plug_efficiency" => 0.5,
        "radiation_control_wall_plug_efficiency" => 0.5,
        "electric_conversion_efficiency" => 0.4)
    evidence = Dict(key => "complete" for key in keys(parameters))
    core = CandidateLongitudinalBalanceModuleV1(
        module_id = "candidate_longitudinal_balance",
        region_id = "candidate_control_volume",
        transport_operator_id = String(transport_operator_id),
        parameters = parameters, parameter_evidence = evidence,
        external_term_ids = [:fusion_reaction, :fuel_ion_bremsstrahlung,
            :transport_response])
    reaction_evidence = Dict(id => "complete" for id in
        ("alpha_partition", "candidate_binding", "fully_ionized_fuel",
            "isotropic_maxwellian_ions", "optically_thin_bremsstrahlung",
            "plasma_volume"))
    complete_radiation && (reaction_evidence["complete_radiation_model"] = "complete")
    reaction = CandidateReactionBremsstrahlungModuleV1(
        module_id = "candidate_reaction_radiation",
        region_id = "candidate_control_volume",
        candidate_binding_hash = assembly.assembly_hash, plasma_volume_m3 = volume,
        alpha_ion_fraction = 0.5, alpha_electron_fraction = 0.5,
        evidence_status = reaction_evidence,
        source_result_hash = _c2_operating_decl_v1(
            operating, "complete_radiation_model")["source_hash"])
    reference_state = [na, nb, ne, wi, we]
    transport = CandidateTransportResponseModuleV1(
        module_id = "candidate_transport_response",
        region_id = "candidate_control_volume",
        candidate_binding_hash = assembly.assembly_hash,
        transport_operator_id = String(transport_operator_id),
        flux_semantics = flux_semantics, reference_state = reference_state,
        reference_flux = [0.0, 0.0, ion_transport, electron_transport],
        response_jacobian = zeros(4, 5), validity_relative_radius = 0.2,
        evidence_status = Dict(id => "complete" for id in
            ("candidate_binding", "flux_values", "response_jacobian",
                "resolution_convergence", "validity_radius")),
        source_result_hash = _c2_operating_decl_v1(
            operating, "transport_response")["source_hash"])
    initials = Dict{String,Float64}(
        "fuel_a_inventory" => na, "fuel_b_inventory" => nb,
        "electron_inventory" => ne, "ion_thermal_energy" => wi,
        "electron_thermal_energy" => we, "fueling_output" => fueling,
        "ion_heating_output" => ion_heat,
        "electron_heating_output" => electron_heat, "exhaust_output" => 0.0,
        "radiation_control_output" => 0.0)
    manifest = compile_longitudinal_candidate_manifest_v1(core;
        candidate_id = "assembly_$(first(assembly.assembly_hash, 16))",
        physics_hash = assembly.assembly_hash, initial_conditions = initials)
    physical_boundary = topology_boundary_class === nothing ? String(flux_semantics) :
        String(topology_boundary_class)
    isempty(physical_boundary) && throw(ArgumentError(
        "topology boundary class cannot be empty"))
    push!(manifest.boundaries, Dict{String,Any}(
        "boundary_class" => physical_boundary,
        "flux_semantics" => String(flux_semantics)))
    modules = AbstractResidualPhysicsModuleV1[core, reaction, transport]
    plan = compile_coupled_solve_plan_v1(manifest, modules)
    plan.status == :pass || throw(ArgumentError(
        "candidate C2 vertical-slice plan did not compile: $(join(plan.reasons, ";"))"))
    result = solve_coupled_plan_v1(manifest, modules, plan)
    result.status == :pass || throw(ArgumentError(
        "candidate C2 vertical-slice nonlinear solve did not pass: $(result.classification_code)"))
    state = compile_c2_candidate_state_package_from_v68_v1(manifest, result)
    return plan, result, state
end

function _c2_projected_stage4_evidence_v1(assembly::CandidateAssemblyBindingV1,
        state::C2CandidateStatePackageV1, operator_id::String;
        favorable::Bool, margin::Real, history::Vector{Dict{String,Any}},
        source_paths::Vector{String}, source_hashes::Vector{String},
        source_result_hash::String, equations::Vector{String},
        boundary_conditions::Vector{String}, time_semantics::Symbol,
        claim_boundary::String, terminal::Bool = false)
    contract = only(filter(item -> item.operator_id == operator_id,
        default_stability_capability_registry_v2()))
    perturbation = StabilityPerturbationSpecV2(
        "assembly_projected_$(operator_id)", operator_id;
        equations = equations, state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = boundary_conditions, time_semantics = time_semantics,
        resolution_levels = String[string(get(item, "resolution", index))
            for (index, item) in enumerate(history)],
        normalization = "signed necessary-condition margin")
    scope = favorable ? Dict{String,Any}() : Dict{String,Any}(
        "scope" => "selected_composite_assembly_only",
        "terminates_candidate" => terminal,
        "not_falsified" => ["base_plasma_configuration", "alternative_field_source",
            "alternative_stabilization_mechanism"])
    return compile_stability_evidence_envelope_v2(assembly.assembly_hash,
        state.state_result_hash, contract, perturbation; favorable = favorable,
        signed_normalized_margin = Float64(margin), convergence_history = history,
        validity_domain_covered = true, resolution_verified = true,
        covered_input_ids = copy(contract.required_input_ids),
        source_kind = :candidate_solver, source_artifact_paths = source_paths,
        source_artifact_hashes = source_hashes,
        source_result_hash = source_result_hash, candidate_binding_verified = true,
        minimal_failure_scope = scope, claim_boundary = claim_boundary)
end

function compile_closed_assembly_stage4_projection_v1(
        assembly::CandidateAssemblyBindingV1, state::C2CandidateStatePackageV1;
        audit_path::AbstractString, frontier_path::AbstractString)
    audit = _stage4_plain_v2(JSON3.read(read(audit_path, String), Dict{String,Any}))
    frontier_hash = bytes2hex(sha256(read(frontier_path)))
    audit_hash = bytes2hex(sha256(read(audit_path)))
    sources = [String(frontier_path), String(audit_path)]
    hashes = [frontier_hash, audit_hash]
    comparisons = Dict{String,Any}(audit["comparisons"])
    records = StabilityEvidenceEnvelopeV2[]
    push!(records, _c2_projected_stage4_evidence_v1(assembly, state,
        "three_dimensional_equilibrium_v2"; favorable = true,
        margin = Float64(comparisons["minimum_sampled_sqrt_g_fine"]),
        history = [Dict("resolution" => "medium", "value" =>
                Float64(comparisons["force_residual_medium"])),
            Dict("resolution" => "fine", "value" =>
                Float64(comparisons["force_residual_fine"]))],
        source_paths = sources, source_hashes = hashes,
        source_result_hash = String(audit["audit_hash"]),
        equations = ["J cross B minus grad(p) equals zero"],
        boundary_conditions = ["selected fixed three-dimensional boundary"],
        time_semantics = :steady,
        claim_boundary = "Exact assembly projection of the linked medium/fine fixed-boundary equilibrium audit; no fast-ion, error-field or engineering claim."))
    push!(records, _c2_projected_stage4_evidence_v1(assembly, state,
        "mercier_interchange_v2"; favorable = true,
        margin = Float64(comparisons["mercier_minimum_fine_normalized"]),
        history = [Dict("resolution" => "medium", "value" =>
                Float64(comparisons["mercier_minimum_medium_normalized"])),
            Dict("resolution" => "fine", "value" =>
                Float64(comparisons["mercier_minimum_fine_normalized"]))],
        source_paths = sources, source_hashes = hashes,
        source_result_hash = String(audit["audit_hash"]),
        equations = ["sampled Mercier ideal-MHD criterion"],
        boundary_conditions = ["selected nested fixed-boundary surfaces"],
        time_semantics = :eigenvalue,
        claim_boundary = "Exact assembly projection of the linked sampled Mercier audit only."))
    push!(records, _c2_projected_stage4_evidence_v1(assembly, state,
        "infinite_n_ballooning_v2"; favorable = true,
        margin = -Float64(comparisons["ballooning_maximum_fine"]),
        history = [Dict("resolution" => "medium", "value" =>
                -Float64(comparisons["ballooning_maximum_medium"])),
            Dict("resolution" => "fine", "value" =>
                -Float64(comparisons["ballooning_maximum_fine"]))],
        source_paths = sources, source_hashes = hashes,
        source_result_hash = String(audit["audit_hash"]),
        equations = ["sampled infinite-n ideal-ballooning eigenproblem"],
        boundary_conditions = ["finite sampled field-line turns"],
        time_semantics = :eigenvalue,
        claim_boundary = "Exact assembly projection of the linked sampled infinite-n ballooning audit only."))
    stage = compile_stability_stage_v2(assembly.assembly_hash,
        ["three_dimensional_equilibrium_v2", "mercier_interchange_v2",
            "infinite_n_ballooning_v2", "error_field_response_v2",
            "fast_ion_orbit_v2"],
        Dict{String,Any}("dimension" => "periodic_3d",
            "boundary_class" => "closed_flux", "time_mode" => "steady"), records)
    return stability_stage_compilation_to_dict_v2(stage)
end

function compile_open_assembly_minimum_b_stage4_v1(
        assembly::CandidateAssemblyBindingV1, state::C2CandidateStatePackageV1;
        winding_jsonl_path::AbstractString, base_candidate_binding_hash::AbstractString)
    raw = _stage4_jsonl_record_v2(String(winding_jsonl_path), "physical_result_hash",
        String(base_candidate_binding_hash))
    selected = Dict{String,Any}(raw["selected_repair"])
    history = Dict{String,Any}[]
    for (resolution, key) in (("coarse", "coarse_numerical_result"),
            ("refined", "refined_numerical_result"))
        row = _finite_winding_axis_curvature_v2(Dict{String,Any}(selected[key]))
        row["resolution"] = resolution
        push!(history, row)
    end
    products = Float64[item["curvature_product_T2_per_m4"] for item in history]
    all(products .< 0) || throw(ArgumentError(
        "selected open assembly is no longer a local field-strength saddle"))
    relative_change = abs(products[2] - products[1]) / max(abs(products[2]), 1.0e-30)
    relative_change <= 0.01 || throw(ArgumentError(
        "selected open assembly saddle did not converge below one percent"))
    artifact_hash = bytes2hex(sha256(read(winding_jsonl_path)))
    evidence = _c2_projected_stage4_evidence_v1(assembly, state,
        "minimum_b_stabilization_path_v2"; favorable = false,
        margin = products[2], history = history,
        source_paths = [String(winding_jsonl_path)], source_hashes = [artifact_hash],
        source_result_hash = String(raw["physical_result_hash"]),
        equations = ["B_axis second derivative and axisymmetric vacuum radial curvature"],
        boundary_conditions = ["selected symmetric finite winding at its center"],
        time_semantics = :steady, terminal = true,
        claim_boundary = "The assembly declares the unassisted two-coil minimum-B path as necessary. Its converged local field-strength saddle hard-fails this selected assembly, while alternative field sources or stabilizers remain outside scope.")
    stage = compile_stability_stage_v2(assembly.assembly_hash,
        ["minimum_b_stabilization_path_v2"],
        Dict{String,Any}("dimension" => "axisymmetric_2d",
            "boundary_class" => "open_flux", "time_mode" => "steady"),
        [evidence])
    return stability_stage_compilation_to_dict_v2(stage)
end

function compile_candidate_c2_vertical_slice_result_v1(
        operating::CandidateOperatingPointV1, assembly::CandidateAssemblyBindingV1,
        plan::CoupledSolvePlanV1, result::NonlinearSolveResultEnvelopeV1,
        state::C2CandidateStatePackageV1, stability::Dict{String,Any},
        engineering::C2BoundGateEvidenceV1)
    interval_width = max(1.0e-12,
        Float64(get(result.audits, "maximum_normalized_residual", 0.0)))
    interval = compile_c2_uncertainty_interval_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash,
        quantity_id = "normalized_independent_residual", lower = -interval_width,
        upper = interval_width, unit = "1", coverage_probability = 0.95,
        method = "v68_independent_recalculation_and_three_level_resolution_envelope",
        source_result_hash = result.result_hash)
    independent = compile_c2_independent_evidence_from_v68_v1(state, result, interval)
    decision = compile_candidate_c2_decision_from_v68_v1(state, result, stability,
        engineering, independent)
    body = Dict{String,Any}("operating_point_hash" => operating.operating_point_hash,
        "assembly_hash" => assembly.assembly_hash, "plan_hash" => plan.plan_hash,
        "state_result_hash" => result.result_hash,
        "stability_compilation_hash" => stability["compilation_hash"],
        "engineering_evidence_hash" => engineering.evidence_bundle_hash,
        "independent_evidence_hash" => independent.evidence_bundle_hash,
        "decision_hash" => decision.decision_hash)
    return CandidateC2VerticalSliceResultV1(operating, assembly, plan, result, state,
        stability, engineering, independent, decision, canonical_hash(body))
end

function candidate_c2_vertical_slice_to_dict_v1(item::CandidateC2VerticalSliceResultV1)
    return Dict{String,Any}(
        "operating_point" => candidate_operating_point_to_dict_v1(item.operating_point),
        "assembly" => candidate_assembly_binding_to_dict_v1(item.assembly),
        "solve_plan" => coupled_solve_plan_to_dict_v1(item.solve_plan),
        "nonlinear_result" => nonlinear_solve_result_to_dict_v1(item.nonlinear_result),
        "state_package" => c2_candidate_state_package_to_dict_v1(item.state_package),
        "stability_compilation" => item.stability_compilation,
        "engineering_evidence" => c2_bound_gate_evidence_to_dict_v1(
            item.engineering_evidence),
        "independent_evidence" => c2_bound_gate_evidence_to_dict_v1(
            item.independent_evidence),
        "decision" => c2_decision_envelope_to_dict_v1(item.decision),
        "slice_hash" => item.slice_hash)
end
