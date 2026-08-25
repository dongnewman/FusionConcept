function _stage4_plain_v2(value)
    value isa AbstractDict && return Dict{String,Any}(String(key) => _stage4_plain_v2(item)
        for (key, item) in pairs(value))
    value isa AbstractVector && return Any[_stage4_plain_v2(item) for item in value]
    return value
end

function _stage4_artifact_v2(root::AbstractString, relative::AbstractString,
        expected_hash::AbstractString)
    path = normpath(joinpath(root,
        replace(String(relative), '/' => Base.Filesystem.path_separator)))
    isfile(path) || throw(ArgumentError("missing Stage-4 source artifact: $relative"))
    observed = bytes2hex(sha256(read(path)))
    observed == lowercase(String(expected_hash)) || throw(ArgumentError(
        "Stage-4 source artifact hash mismatch: $relative"))
    return path, observed
end

function _stage4_contract_v2(operator_id::AbstractString,
        registry::Vector{StabilityCapabilityContractV2})
    matches = filter(item -> item.operator_id == operator_id, registry)
    length(matches) == 1 || throw(ArgumentError("missing or duplicate contract: $operator_id"))
    return only(matches)
end

function _stage4_frontier_record_v2(frontier::Dict{String,Any}, candidate_id::String)
    records = [_stage4_plain_v2(item) for item in frontier["candidates"]]
    matches = filter(item -> String(item["candidate_id"]) == candidate_id, records)
    length(matches) == 1 || throw(ArgumentError(
        "frontier candidate binding is not unique: $candidate_id"))
    return only(matches)
end

function _stage4_jsonl_record_v2(path::AbstractString, field::AbstractString,
        expected::AbstractString)
    matches = Dict{String,Any}[]
    for line in eachline(path)
        isempty(strip(line)) && continue
        row = _stage4_plain_v2(JSON3.read(line, Dict{String,Any}))
        haskey(row, field) && String(row[field]) == expected && push!(matches, row)
    end
    length(matches) == 1 || throw(ArgumentError(
        "Stage-4 JSONL binding is missing or non-unique: $field=$expected"))
    return only(matches)
end

function _finite_winding_axis_curvature_v2(result::Dict{String,Any})
    samples = Dict{String,Any}[Dict{String,Any}(item) for item in result["axis_samples"]]
    length(samples) >= 3 || throw(ArgumentError(
        "finite-winding minimum-B audit requires at least three axis samples"))
    iszero(Float64(samples[1]["z_m"])) || throw(ArgumentError(
        "finite-winding axis samples must start at the symmetry center"))
    h = Float64(samples[2]["z_m"])
    h > 0.0 || throw(ArgumentError("finite-winding axis sample spacing must be positive"))
    b0, b1 = Float64(samples[1]["field_T"]), Float64(samples[2]["field_T"])
    axial = 2.0 * (b1 - b0) / h^2
    radial = -0.5 * axial
    return Dict{String,Any}("axis_sample_spacing_m" => h, "center_field_T" => b0,
        "field_strength_axial_curvature_T_per_m2" => axial,
        "field_strength_radial_curvature_T_per_m2" => radial,
        "curvature_product_T2_per_m4" => axial * radial)
end

"Recompute the local vacuum-field saddle of a repaired finite winding without widening it."
function compile_mirror_finite_winding_minimum_b_failure_v2(
        entry::RealCandidatePanelEntryV1, adapter::Dict{String,Any}; root::AbstractString,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    path, artifact_hash = _stage4_artifact_v2(root, String(adapter["artifact_path"]),
        String(adapter["artifact_sha256"]))
    raw = _stage4_jsonl_record_v2(path, "repair_candidate_id", entry.candidate_id)
    String(raw["physical_result_hash"]) == entry.candidate_binding_hash || throw(ArgumentError(
        "finite-winding minimum-B result candidate binding mismatch"))
    Bool(raw["candidate_specific_finite_winding_vacuum_component_authorized"]) ||
        throw(ArgumentError("finite-winding vacuum component is not authorized"))
    selected = Dict{String,Any}(raw["selected_repair"])
    Bool(selected["candidate_specific_finite_winding_vacuum_component_authorized"]) ||
        throw(ArgumentError("selected finite winding is not authorized"))
    gates = Dict{String,Any}(selected["repair_gates"])
    all(Bool(value) for value in values(gates)) || throw(ArgumentError(
        "selected finite winding no longer passes its declared repair gates"))
    history = Dict{String,Any}[]
    for (resolution, key) in (("coarse", "coarse_numerical_result"),
            ("refined", "refined_numerical_result"))
        row = _finite_winding_axis_curvature_v2(Dict{String,Any}(selected[key]))
        row["resolution"] = resolution
        push!(history, row)
    end
    products = Float64[row["curvature_product_T2_per_m4"] for row in history]
    all(products .< 0.0) || throw(ArgumentError(
        "finite-winding center is no longer a field-strength saddle"))
    relative_change = abs(products[2] - products[1]) / max(abs(products[2]), 1.0e-30)
    relative_change <= 0.01 || throw(ArgumentError(
        "finite-winding saddle curvature did not converge below one percent"))
    history[2]["curvature_product_relative_change"] = relative_change
    contract = _stage4_contract_v2("minimum_b_stabilization_path_v2", registry)
    perturbation = StabilityPerturbationSpecV2(
        "finite_winding_axisymmetric_vacuum_hessian_v2", contract.operator_id;
        equations = ["B_axis''(0)=2*(B_axis(h)-B_axis(0))/h^2",
            "d2|B|/dr2=-B_axis''(0)/2 from axisymmetric div(B)=0 in a current-free vacuum neighborhood"],
        state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = ["symmetric axisymmetric finite winding",
            "local current-free vacuum neighborhood at the device center"],
        time_semantics = :steady, resolution_levels = ["coarse", "refined"],
        normalization = "product of axial and radial field-strength curvature")
    scope = Dict{String,Any}(
        "scope" => "repaired_two_coil_finite_winding_local_vacuum_minimum_b_path",
        "curvature_product_T2_per_m4" => products[2],
        "not_falsified" => ["finite_beta_interchange_response", "conducting_boundary_m1",
            "finite_larmor_radius_stabilization", "ambipolar_response", "flow_shear",
            "DCLC_or_AIC_response", "additional_minimum_b_coil_grammars"])
    evidence = compile_stability_evidence_envelope_v2(entry.candidate_binding_hash,
        String(raw["refined_solver_problem_hash"]), contract, perturbation;
        favorable = false, signed_normalized_margin = products[2],
        convergence_history = history, validity_domain_covered = true,
        resolution_verified = true, covered_input_ids = copy(contract.required_input_ids),
        source_kind = :candidate_solver,
        source_artifact_paths = [String(adapter["artifact_path"])],
        source_artifact_hashes = [artifact_hash],
        source_result_hash = String(raw["physical_result_hash"]),
        candidate_binding_verified = true, minimal_failure_scope = scope,
        claim_boundary = "Candidate-bound local vacuum field-strength saddle of the selected repaired finite winding only. It rejects the unassisted two-coil minimum-B path, not other stabilization mechanisms or complete Stage 4.")
    evidence.status == :fail || throw(ArgumentError(
        "finite-winding minimum-B result did not compile as a narrow failure"))
    return StabilityEvidenceEnvelopeV2[evidence]
end

"Adapt a linked medium/fine DESC audit without upgrading its sampled claim boundary."
function compile_desc_stage4_evidence_v2(entry::RealCandidatePanelEntryV1,
        adapter::Dict{String,Any}; root::AbstractString,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    frontier_path, frontier_hash = _stage4_artifact_v2(root,
        String(adapter["frontier_path"]), String(adapter["frontier_sha256"]))
    audit_path, audit_hash = _stage4_artifact_v2(root,
        String(adapter["audit_path"]), String(adapter["audit_sha256"]))
    frontier = _stage4_plain_v2(JSON3.read(read(frontier_path, String), Dict{String,Any}))
    audit = _stage4_plain_v2(JSON3.read(read(audit_path, String), Dict{String,Any}))
    record = _stage4_frontier_record_v2(frontier, entry.candidate_id)
    parameters = Dict{String,Any}(record["parameters"])
    String(parameters["candidate_physics_hash"]) == entry.candidate_binding_hash ||
        throw(ArgumentError("frontier candidate physics binding mismatch"))
    state_hash = String(parameters["stability_problem_hash"])
    String(audit["target"]["physics_hash"]) == state_hash || throw(ArgumentError(
        "DESC audit is detached from the candidate stability problem"))
    computed = Dict{String,Any}(parameters["computed_evidence"])
    String(computed["stability_audit_hash"]) == String(audit["audit_hash"]) ||
        throw(ArgumentError("frontier-to-DESC result hash mismatch"))
    Bool(audit["all_passed"]) || throw(ArgumentError(
        "DESC medium/fine audit did not pass its declared numerical gates"))
    sources = [String(adapter["frontier_path"]), String(adapter["audit_path"])]
    hashes = [frontier_hash, audit_hash]
    result_hash = String(audit["audit_hash"])
    claim = String(audit["claim_boundary"])
    gates = sort!(String.(collect(keys(audit["gates"]))))

    eq_contract = _stage4_contract_v2("three_dimensional_equilibrium_v2", registry)
    eq_perturbation = StabilityPerturbationSpecV2("desc_fixed_boundary_force_balance_v2",
        eq_contract.operator_id; equations = ["J cross B minus grad(p) equals zero"],
        state_input_ids = copy(eq_contract.required_input_ids),
        boundary_conditions = ["fixed three-dimensional flux boundary"],
        time_semantics = :steady, resolution_levels = ["medium", "fine"],
        normalization = "force residual normalized to magnetic-pressure gradient")
    equilibrium = compile_stability_evidence_envelope_v2(entry.candidate_binding_hash,
        state_hash, eq_contract, eq_perturbation; favorable = true,
        signed_normalized_margin = Float64(audit["comparisons"]["minimum_sampled_sqrt_g_fine"]),
        convergence_history = Dict{String,Any}[
            Dict("resolution" => "medium", "normalized_force_residual" =>
                Float64(audit["comparisons"]["force_residual_medium"])),
            Dict("resolution" => "fine", "normalized_force_residual" =>
                Float64(audit["comparisons"]["force_residual_fine"]))],
        validity_domain_covered = true, resolution_verified = true,
        covered_input_ids = copy(eq_contract.required_input_ids), source_kind = :candidate_solver,
        source_artifact_paths = sources, source_artifact_hashes = hashes,
        source_result_hash = result_hash, candidate_binding_verified = true,
        claim_boundary = claim)

    mercier_contract = _stage4_contract_v2("mercier_interchange_v2", registry)
    mercier_perturbation = StabilityPerturbationSpecV2("desc_sampled_mercier_v2",
        mercier_contract.operator_id; equations = ["Mercier local ideal-MHD criterion"],
        state_input_ids = copy(mercier_contract.required_input_ids),
        boundary_conditions = ["nested fixed-boundary flux surfaces"],
        time_semantics = :eigenvalue, resolution_levels = ["medium", "fine"],
        normalization = "D_Mercier times Psi squared")
    mercier_margin = Float64(audit["comparisons"]["mercier_minimum_fine_normalized"])
    mercier = compile_stability_evidence_envelope_v2(entry.candidate_binding_hash,
        state_hash, mercier_contract, mercier_perturbation;
        favorable = Bool(audit["fine"]["mercier"]["sampled_favorable"]),
        signed_normalized_margin = mercier_margin,
        convergence_history = Dict{String,Any}[
            Dict("resolution" => "medium", "minimum_margin" =>
                Float64(audit["comparisons"]["mercier_minimum_medium_normalized"])),
            Dict("resolution" => "fine", "minimum_margin" => mercier_margin)],
        validity_domain_covered = true, resolution_verified = true,
        covered_input_ids = copy(mercier_contract.required_input_ids),
        source_kind = :candidate_solver, source_artifact_paths = sources,
        source_artifact_hashes = hashes, source_result_hash = result_hash,
        candidate_binding_verified = true, claim_boundary = claim)

    ballooning_contract = _stage4_contract_v2("infinite_n_ballooning_v2", registry)
    ballooning_perturbation = StabilityPerturbationSpecV2(
        "desc_sampled_infinite_n_ballooning_v2", ballooning_contract.operator_id;
        equations = ["infinite-n ideal-ballooning field-line eigenproblem"],
        state_input_ids = copy(ballooning_contract.required_input_ids),
        boundary_conditions = ["finite sampled field-line turns"],
        time_semantics = :eigenvalue, resolution_levels = ["medium", "fine"],
        normalization = "negative of maximum sampled ballooning eigenvalue")
    ballooning_margin = -Float64(audit["comparisons"]["ballooning_maximum_fine"])
    ballooning = compile_stability_evidence_envelope_v2(entry.candidate_binding_hash,
        state_hash, ballooning_contract, ballooning_perturbation;
        favorable = Bool(audit["fine"]["ballooning"]["sampled_favorable"]),
        signed_normalized_margin = ballooning_margin,
        convergence_history = Dict{String,Any}[
            Dict("resolution" => "medium", "signed_margin" =>
                -Float64(audit["comparisons"]["ballooning_maximum_medium"])),
            Dict("resolution" => "fine", "signed_margin" => ballooning_margin)],
        validity_domain_covered = true, resolution_verified = true,
        covered_input_ids = copy(ballooning_contract.required_input_ids),
        source_kind = :candidate_solver, source_artifact_paths = sources,
        source_artifact_hashes = hashes, source_result_hash = result_hash,
        candidate_binding_verified = true, claim_boundary = claim)
    all(item -> item.status == :pass, (equilibrium, mercier, ballooning)) ||
        throw(ArgumentError("linked DESC evidence did not compile as authoritative pass"))
    evidence = StabilityEvidenceEnvelopeV2[equilibrium, mercier, ballooning]
    if haskey(adapter, "fast_ion_artifact_path")
        push!(evidence, compile_desc_fast_ion_stage4_evidence_v2(entry, adapter;
            root = root, registry = registry))
    end
    return evidence
end

"Adapt the short-horizon DESC guiding-center diagnostic without granting confinement credit."
function compile_desc_fast_ion_stage4_evidence_v2(entry::RealCandidatePanelEntryV1,
        adapter::Dict{String,Any}; root::AbstractString,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    result_path, result_sha = _stage4_artifact_v2(root,
        String(adapter["fast_ion_artifact_path"]),
        String(adapter["fast_ion_artifact_sha256"]))
    input_path, input_sha = _stage4_artifact_v2(root,
        String(adapter["fast_ion_input_path"]), String(adapter["fast_ion_input_sha256"]))
    runner_path, runner_sha = _stage4_artifact_v2(root,
        String(adapter["fast_ion_runner_path"]), String(adapter["fast_ion_runner_sha256"]))
    raw = _stage4_plain_v2(JSON3.read(read(result_path, String), Dict{String,Any}))
    input = _stage4_plain_v2(JSON3.read(read(input_path, String), Dict{String,Any}))
    String(raw["runner_version"]) == "desc_fast_ion_guiding_center_runner_v1" ||
        throw(ArgumentError("unexpected fast-ion runner version"))
    String(raw["runner_source_sha256"]) == runner_sha || throw(ArgumentError(
        "fast-ion result runner-source binding mismatch"))
    String(raw["candidate_binding_hash"]) == entry.candidate_binding_hash ||
        throw(ArgumentError("fast-ion result candidate binding mismatch"))
    String(input["candidate_binding_hash"]) == entry.candidate_binding_hash ||
        throw(ArgumentError("fast-ion input candidate binding mismatch"))
    String(raw["stability_problem_hash"]) == String(input["stability_problem_hash"]) ||
        throw(ArgumentError("fast-ion result state binding mismatch"))
    Bool(raw["gates"]["candidate_binding_verified"]) || throw(ArgumentError(
        "fast-ion runner did not verify candidate binding"))
    Bool(raw["gates"]["source_equilibrium_recomputed"]) || throw(ArgumentError(
        "fast-ion runner did not recompute the source equilibrium"))
    contract = _stage4_contract_v2("fast_ion_orbit_v2", registry)
    perturbation = StabilityPerturbationSpecV2("desc_alpha_guiding_center_ensemble_v1",
        contract.operator_id;
        equations = ["collisionless first-order guiding-center equations in a static magnetic field"],
        state_input_ids = ["equilibrium_state"],
        boundary_conditions = ["rho equals one plasma-boundary crossing"],
        time_semantics = :transient,
        resolution_levels = [string(item["step_count"], "_time_steps")
            for item in raw["resolution_history"]],
        normalization = "plasma-boundary crossing fraction and relative invariant error")
    loss = Float64(raw["finest"]["plasma_boundary_crossing_fraction"])
    history = Dict{String,Any}[Dict{String,Any}(
        "step_count" => Int(item["step_count"]),
        "time_step_s" => Float64(item["time_step_s"]),
        "plasma_boundary_crossing_fraction" =>
            Float64(item["plasma_boundary_crossing_fraction"]),
        "maximum_relative_energy_error" =>
            Float64(item["maximum_relative_energy_error"]),
        "interpolation_domain_exit_count" => Int(item["interpolation_domain_exit_count"]))
        for item in raw["resolution_history"]]
    scope = Dict{String,Any}(
        "scope" => "declared_short_horizon_guiding_center_ensemble_only",
        "observed_plasma_boundary_crossing_fraction" => loss,
        "not_falsified" => ["candidate_fast_ion_distribution", "material_wall_confinement",
            "collisional_slowing_down", "electric_field_response", "long_time_confinement"])
    evidence = compile_stability_evidence_envelope_v2(entry.candidate_binding_hash,
        String(raw["stability_problem_hash"]), contract, perturbation;
        favorable = loss == 0.0, signed_normalized_margin = 0.05 - loss,
        convergence_history = history,
        validity_domain_covered = false,
        resolution_verified = Bool(raw["gates"]["time_step_convergence_verified"]),
        covered_input_ids = ["equilibrium_state"], source_kind = :candidate_solver,
        source_artifact_paths = [String(adapter["fast_ion_input_path"]),
            String(adapter["fast_ion_artifact_path"]), String(adapter["fast_ion_runner_path"])],
        source_artifact_hashes = [input_sha, result_sha, runner_sha],
        source_result_hash = String(raw["result_hash"]),
        candidate_binding_verified = true, minimal_failure_scope = scope,
        claim_boundary = String(raw["claim_boundary"]))
end

"Adapt the local minimum-B falsifier while preserving alternative stabilizers as unknown."
function compile_minimum_b_failure_evidence_v2(entry::RealCandidatePanelEntryV1,
        adapter::Dict{String,Any}; root::AbstractString,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    path, artifact_hash = _stage4_artifact_v2(root, String(adapter["artifact_path"]),
        String(adapter["artifact_sha256"]))
    raw = _stage4_plain_v2(JSON3.read(read(path, String), Dict{String,Any}))
    String(raw["input"]["candidate_hash"]) == entry.candidate_binding_hash ||
        throw(ArgumentError("minimum-B diagnostic candidate binding mismatch"))
    Bool(raw["gates"]["center_is_local_field_strength_saddle"]) ||
        throw(ArgumentError("minimum-B negative control no longer contains a saddle"))
    contract = _stage4_contract_v2("minimum_b_stabilization_path_v2", registry)
    perturbation = StabilityPerturbationSpecV2("field_strength_hessian_refinement_v2",
        contract.operator_id; equations = ["finite-difference Hessian of magnetic-field strength"],
        state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = ["candidate-bound vacuum field near center"],
        time_semantics = :steady,
        resolution_levels = [string(item["step_m"], "_m") for item in raw["diagnostic"]["curvature_cases"]],
        normalization = "radial curvature times axial curvature")
    history = Dict{String,Any}[Dict{String,Any}(item) for item in
        raw["diagnostic"]["curvature_cases"]]
    margin = Float64(last(history)["curvature_product_t2_per_m4"])
    evidence = compile_stability_evidence_envelope_v2(entry.candidate_binding_hash,
        String(raw["deterministic_hash"]), contract, perturbation; favorable = false,
        signed_normalized_margin = margin, convergence_history = history,
        validity_domain_covered = true,
        resolution_verified = Bool(raw["gates"]["curvature_refinement_below_1pct"]),
        covered_input_ids = copy(contract.required_input_ids), source_kind = :candidate_solver,
        source_artifact_paths = [String(adapter["artifact_path"])],
        source_artifact_hashes = [artifact_hash],
        source_result_hash = String(raw["deterministic_hash"]),
        candidate_binding_verified = true,
        minimal_failure_scope = Dict{String,Any}(raw["minimal_failure_scope"]),
        claim_boundary = String(raw["claim_boundary"]))
    evidence.status == :fail || throw(ArgumentError(
        "minimum-B negative control did not compile as an authoritative narrow failure"))
    return StabilityEvidenceEnvelopeV2[evidence]
end

"Adapt a resolution-audited vacuum current-error response and its narrow nominal-field failure."
function compile_desc_error_field_stage4_evidence_v2(entry::RealCandidatePanelEntryV1,
        adapter::Dict{String,Any}; root::AbstractString,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    result_path, result_sha = _stage4_artifact_v2(root,
        String(adapter["artifact_path"]), String(adapter["artifact_sha256"]))
    input_path, input_sha = _stage4_artifact_v2(root,
        String(adapter["input_path"]), String(adapter["input_sha256"]))
    runner_path, runner_sha = _stage4_artifact_v2(root,
        String(adapter["runner_path"]), String(adapter["runner_sha256"]))
    raw = _stage4_plain_v2(JSON3.read(read(result_path, String), Dict{String,Any}))
    input = _stage4_plain_v2(JSON3.read(read(input_path, String), Dict{String,Any}))
    String(raw["runner_version"]) == "desc_coil_current_error_response_runner_v1" ||
        throw(ArgumentError("unexpected error-field runner version"))
    String(raw["runner_source_sha256"]) == runner_sha || throw(ArgumentError(
        "error-field result runner-source binding mismatch"))
    String(raw["candidate_binding_hash"]) == entry.candidate_binding_hash ||
        throw(ArgumentError("error-field result candidate binding mismatch"))
    String(input["candidate_binding_hash"]) == entry.candidate_binding_hash ||
        throw(ArgumentError("error-field input candidate binding mismatch"))
    String(raw["stability_problem_hash"]) == String(input["stability_problem_hash"]) ||
        throw(ArgumentError("error-field state binding mismatch"))
    Bool(raw["gates"]["candidate_binding_verified"]) || throw(ArgumentError(
        "error-field runner did not verify candidate binding"))
    Bool(raw["gates"]["physical_symmetry_copies_expanded"]) || throw(ArgumentError(
        "error-field runner did not expand physical coils"))
    contract = _stage4_contract_v2("error_field_response_v2", registry)
    perturbation = StabilityPerturbationSpecV2("desc_physical_coil_current_error_v1",
        contract.operator_id;
        equations = ["linear Biot-Savart map from independent fractional coil-current errors to total boundary-normal field"],
        state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = ["candidate fixed-boundary rho equals one surface"],
        time_semantics = :steady,
        resolution_levels = [string(item["angular_count"], "_angular")
            for item in raw["resolution_history"]],
        normalization = "area-weighted RMS normal field divided by area-mean equilibrium field")
    history = Dict{String,Any}[Dict{String,Any}(
        "angular_count" => Int(item["angular_count"]),
        "surface_point_count" => Int(item["surface_point_count"]),
        "nominal_total_bn_rms_normalized" =>
            Float64(item["nominal_total_bn_rms_normalized"]),
        "maximum_pattern_normalized_delta_bn_rms" =>
            Float64(item["maximum_pattern_normalized_delta_bn_rms"]),
        "maximum_weighted_response_singular_value" =>
            Float64(item["maximum_weighted_response_singular_value"]),
        "response_matrix_hash" => String(item["response_matrix_hash"]))
        for item in raw["resolution_history"]]
    evidence = compile_stability_evidence_envelope_v2(entry.candidate_binding_hash,
        String(raw["stability_problem_hash"]), contract, perturbation;
        favorable = Bool(raw["gates"]["nominal_bn_reference_met"]),
        signed_normalized_margin = Float64(raw["signed_nominal_bn_margin"]),
        convergence_history = history, validity_domain_covered = true,
        resolution_verified = Bool(raw["gates"]["response_resolution_verified"]),
        covered_input_ids = copy(contract.required_input_ids), source_kind = :candidate_solver,
        source_artifact_paths = [String(adapter["input_path"]),
            String(adapter["artifact_path"]), String(adapter["runner_path"])],
        source_artifact_hashes = [input_sha, result_sha, runner_sha],
        source_result_hash = String(raw["result_hash"]),
        candidate_binding_verified = true,
        minimal_failure_scope = Dict{String,Any}(raw["minimal_failure_scope"]),
        claim_boundary = String(raw["claim_boundary"]))
    evidence.status == :fail || throw(ArgumentError(
        "error-field negative control did not compile as an authoritative narrow failure"))
    return StabilityEvidenceEnvelopeV2[evidence]
end

function load_candidate_stage4_panel_config_v2(path::AbstractString)
    raw = _stage4_plain_v2(JSON3.read(read(path, String), Dict{String,Any}))
    String(raw["schema_version"]) == "2.0.0" || throw(ArgumentError(
        "unsupported Stage-4 panel schema"))
    entries = Dict{String,Any}[Dict{String,Any}(item) for item in raw["entries"]]
    ids = String[item["panel_entry_id"] for item in entries]
    length(unique(ids)) == length(ids) || throw(ArgumentError(
        "Stage-4 panel entry IDs must be unique"))
    return Dict{String,Any}("panel_id" => String(raw["panel_id"]),
        "claim_boundary" => String(raw["claim_boundary"]), "entries" => entries,
        "source_hash" => bytes2hex(sha256(read(path))))
end

function audit_candidate_stage4_real_panel_v2(v68_panel_path::AbstractString,
        stage4_config_path::AbstractString; root::AbstractString = dirname(dirname(v68_panel_path)),
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    panel = load_candidate_v68_real_panel_v1(v68_panel_path)
    config = load_candidate_stage4_panel_config_v2(stage4_config_path)
    panel_entries = Dict(item.panel_entry_id => item for item in panel["entries"])
    configs = Dict(String(item["panel_entry_id"]) => item for item in config["entries"])
    Set(keys(panel_entries)) == Set(keys(configs)) || throw(ArgumentError(
        "Stage-4 configuration must cover the fixed v68 panel exactly"))
    rows = Dict{String,Any}[]
    for panel_id in sort!(collect(keys(panel_entries)))
        entry = panel_entries[panel_id]
        item = configs[panel_id]
        required = sort!(unique(String.(item["required_operator_ids"])))
        context = Dict{String,Any}(item["assembly_context"])
        evidence = StabilityEvidenceEnvelopeV2[]
        if haskey(item, "adapter")
            adapter = Dict{String,Any}(item["adapter"])
            kind = String(adapter["kind"])
            if kind == "desc_medium_fine_v2"
                append!(evidence, compile_desc_stage4_evidence_v2(entry, adapter;
                    root = root, registry = registry))
            elseif kind == "minimum_b_failure_v2"
                append!(evidence, compile_minimum_b_failure_evidence_v2(entry, adapter;
                    root = root, registry = registry))
            elseif kind == "desc_error_field_negative_v2"
                append!(evidence, compile_desc_error_field_stage4_evidence_v2(entry,
                    adapter; root = root, registry = registry))
            elseif kind == "mirror_finite_winding_minimum_b_failure_v2"
                append!(evidence, compile_mirror_finite_winding_minimum_b_failure_v2(entry,
                    adapter; root = root, registry = registry))
            else
                throw(ArgumentError("unknown Stage-4 panel adapter: $kind"))
            end
        end
        compilation = compile_stability_stage_v2(entry.candidate_binding_hash,
            required, context, evidence; registry = registry)
        push!(rows, Dict{String,Any}(
            "panel_entry_id" => entry.panel_entry_id, "candidate_id" => entry.candidate_id,
            "route" => entry.route, "control_role" => entry.control_role,
            "assembly_context" => context,
            "compilation" => stability_stage_compilation_to_dict_v2(compilation)))
    end
    summary = Dict{String,Any}()
    for route in ("closed_flux", "open_flux")
        selected = filter(row -> row["route"] == route, rows)
        summary[route] = Dict{String,Any}(
            "entry_count" => length(selected),
            "pass_count" => count(row -> row["compilation"]["stage_status"] == "pass", selected),
            "fail_count" => count(row -> row["compilation"]["stage_status"] == "fail", selected),
            "unknown_count" => count(row -> row["compilation"]["stage_status"] == "unknown", selected),
            "unsupported_count" => count(row -> row["compilation"]["stage_status"] == "unsupported", selected),
            "complete_stage4_count" => count(row -> row["compilation"]["stage_complete"] === true, selected),
            "authoritative_hard_failure_count" => count(row ->
                row["compilation"]["authoritative_hard_failure"] === true, selected),
            "auxiliary_narrow_failure_count" => count(row ->
                !isempty(row["compilation"]["auxiliary_failed_operator_ids"]), selected))
    end
    core = Dict{String,Any}(
        "schema_version" => "2.0.0", "panel_id" => config["panel_id"],
        "v68_panel_source_hash" => panel["source_hash"],
        "stage4_config_source_hash" => config["source_hash"],
        "capability_registry_hash" => stability_capability_registry_hash_v2(registry),
        "claim_boundary" => config["claim_boundary"], "rows" => rows, "summary" => summary,
        "acceptance" => Dict("closed_route_complete_stage4" =>
                summary["closed_flux"]["complete_stage4_count"] >= 1,
            "open_route_complete_stage4" =>
                summary["open_flux"]["complete_stage4_count"] >= 1,
            "pulse_route_deferred_without_rhd_eos_opacity" => true))
    core["deterministic_hash"] = canonical_hash(core)
    return core
end
