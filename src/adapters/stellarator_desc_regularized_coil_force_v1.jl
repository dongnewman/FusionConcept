struct StellaratorDESCRegularizedCoilForceV1 <: AbstractEvaluator
    base_input_path::String
    base_raw_path::String
    refined_input_path::String
    refined_raw_path::String
    resolution_audit_path::String
    runner_path::String

    function StellaratorDESCRegularizedCoilForceV1(
            base_input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_regularized_coil_force_pool16_base_input.json")),
            base_raw_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_regularized_coil_force_pool16_base_raw.json")),
            refined_input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_regularized_coil_force_pool16_refined_input.json")),
            refined_raw_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_regularized_coil_force_pool16_refined_raw.json")),
            resolution_audit_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_regularized_coil_force_pool16_resolution_audit.json")),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_stellarator_regularized_coil_force_runner.py")))
        paths = abspath.(String.((base_input_path, base_raw_path, refined_input_path,
            refined_raw_path, resolution_audit_path, runner_path)))
        labels = ("base input", "base raw", "refined input", "refined raw",
            "resolution audit", "runner")
        for (path, label) in zip(paths, labels)
            isfile(path) || throw(ArgumentError(
                "DESC regularized-coil $label not found at $path"))
        end
        return new(paths...)
    end
end

const _DESC_REGULARIZED_COIL_PHYSICS_HASH =
    "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"
const _DESC_REGULARIZED_COIL_STATE_HASH =
    "732b0e2e106b743803868e79608ab9541a0a495766ec97b26b91c8f21ab95260"
const _DESC_REGULARIZED_COIL_RUNNER_VERSION =
    "desc_stellarator_regularized_coil_force_runner_v1"
const _DESC_REGULARIZED_COIL_BASE_INPUT_HASH =
    "e04733941a94e194b175cd5c459241abd970c52592bb850d7d713e1315ddde90"
const _DESC_REGULARIZED_COIL_BASE_RESULT_HASH =
    "5b6ab597c57a722a7932b48d97664bea327f721cd9b6b98e9368ac30d14ae99b"
const _DESC_REGULARIZED_COIL_REFINED_INPUT_HASH =
    "953bc413f96cddc4d10644f79542ac71ec73e6ee07b246e6117c04577fceda9c"
const _DESC_REGULARIZED_COIL_REFINED_RESULT_HASH =
    "41a520deac7d7ec0fa0a9284412e262119c4534d1718ad874753fd17987382b8"
const _DESC_REGULARIZED_COIL_AUDIT_HASH =
    "5ff298187072ead7d77eacb5ab7df7b451c1c58f6d65a8252caf0ccd219ad823"
const _DESC_REGULARIZED_COIL_CLAIM_BOUNDARY =
    "Rectangular-cross-section high-coil-aspect-ratio reduced model for regularized self-force field, self/mutual inductance, coil-only stored magnetic energy, and self-plus-mutual Lorentz line load on one fixed 48-coil 60 mm square-pack state; not peak internal conductor field, plasma-current field or coupling, stress or strain, supports, conductor material allocation, critical-current or temperature margin, quench, insulation, joints, finite-element validation, engineering feasibility, global optimality, or superiority."

function evaluator_spec(::StellaratorDESCRegularizedCoilForceV1)
    return EvaluatorSpec(
        "stellarator_regularized_coil_force_desc_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "finite_build_coils" => :proxy,
            "regularized_rectangular_coil_self_force" => :proxy,
            "coil_inductance" => :proxy,
            "coil_only_stored_magnetic_energy" => :proxy,
            "total_coil_electromagnetic_load" => :proxy,
        ),
        "physics_concept",
    )
end

function evaluator_applicability(
        evaluator::StellaratorDESCRegularizedCoilForceV1, genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    genome.physics_hash == _DESC_REGULARIZED_COIL_PHYSICS_HASH || return false,
        "version 1 is bound to the audited pool-16 NFP=2 stellarator candidate"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact pool-16 generated Fourier stellarator with source-bound regularized-coil evidence" :
        "stellarator_regularized_coil_force_desc_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_regularized_coil_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}())
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 fixed 48-coil state with a 60 mm square conductor; Landreman-Hurwitz-Antonsen rectangular high-coil-aspect-ratio regularization, audited at 5x5 mutual-field pack quadrature, 72 force points, and 144 inductance points.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_regularized_coil_force_desc_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3",
            "singh_finite_build_coils_2020",
            "landreman_rectangular_coil_self_force_2025"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = 0.0)
end

function _read_desc_regularized_coil_json(path::AbstractString)
    return _plain_json(JSON3.read(read(path, String), Dict{String,Any}))
end

function _validate_desc_regularized_coil_raw(raw::Dict{String,Any}, genome::Genome,
        label::AbstractString, expected_input_hash::AbstractString,
        expected_result_hash::AbstractString)
    raw["status"] == "pass" || error("regularized-coil $label status is not pass")
    raw["runner_version"] == _DESC_REGULARIZED_COIL_RUNNER_VERSION || error(
        "regularized-coil $label runner version mismatch")
    raw["claim_boundary"] == _DESC_REGULARIZED_COIL_CLAIM_BOUNDARY || error(
        "regularized-coil $label claim boundary mismatch")
    raw["physics_hash"] == genome.physics_hash || error(
        "regularized-coil $label is detached from genome")
    raw["selected_coil_state_hash"] == _DESC_REGULARIZED_COIL_STATE_HASH || error(
        "regularized-coil $label coil-state hash mismatch")
    raw["input_hash"] == expected_input_hash || error(
        "regularized-coil $label input hash mismatch")
    raw["result_hash"] == expected_result_hash || error(
        "regularized-coil $label result hash mismatch")
    raw["all_comparison_gates_passed"] === true || error(
        "regularized-coil $label comparison gates failed")
    raw["interpretation"]["regularized_rectangular_self_force_computed"] === true ||
        error("regularized-coil $label lacks self-force evidence")
    raw["interpretation"]["coil_only_self_and_mutual_inductance_computed"] === true ||
        error("regularized-coil $label lacks inductance evidence")
    raw["interpretation"]["peak_internal_conductor_field_computed"] === false ||
        error("regularized-coil $label crossed internal-field boundary")
    raw["interpretation"]["plasma_current_field_or_coupling_computed"] === false ||
        error("regularized-coil $label crossed plasma-coupling boundary")
    raw["interpretation"]["structural_stress_or_strain_computed"] === false ||
        error("regularized-coil $label crossed structural boundary")
    raw["interpretation"]["thermal_or_superconducting_margin_computed"] === false ||
        error("regularized-coil $label crossed superconducting boundary")
    raw["interpretation"]["engineering_feasibility_established"] === false ||
        error("regularized-coil $label crossed engineering boundary")
end

function _desc_regularized_coil_bundle_from_files(
        adapter::StellaratorDESCRegularizedCoilForceV1, genome::Genome)
    base_input = _read_desc_regularized_coil_json(adapter.base_input_path)
    base_raw = _read_desc_regularized_coil_json(adapter.base_raw_path)
    refined_input = _read_desc_regularized_coil_json(adapter.refined_input_path)
    refined_raw = _read_desc_regularized_coil_json(adapter.refined_raw_path)
    audit = _read_desc_regularized_coil_json(adapter.resolution_audit_path)
    _validate_desc_regularized_coil_raw(base_raw, genome, "base",
        _DESC_REGULARIZED_COIL_BASE_INPUT_HASH,
        _DESC_REGULARIZED_COIL_BASE_RESULT_HASH)
    _validate_desc_regularized_coil_raw(refined_raw, genome, "refined",
        _DESC_REGULARIZED_COIL_REFINED_INPUT_HASH,
        _DESC_REGULARIZED_COIL_REFINED_RESULT_HASH)
    base_input["selected_coil_state_hash"] == _DESC_REGULARIZED_COIL_STATE_HASH ||
        error("regularized-coil base input state mismatch")
    refined_input["selected_coil_state_hash"] == _DESC_REGULARIZED_COIL_STATE_HASH ||
        error("regularized-coil refined input state mismatch")
    audit["audit_hash"] == _DESC_REGULARIZED_COIL_AUDIT_HASH || error(
        "regularized-coil audit hash mismatch")
    audit["all_passed"] === true || error("regularized-coil resolution audit failed")
    audit["physics_hash"] == genome.physics_hash || error(
        "regularized-coil audit is detached from genome")
    audit["selected_coil_state_hash"] == _DESC_REGULARIZED_COIL_STATE_HASH || error(
        "regularized-coil audit state mismatch")
    audit["source_files"]["base_input_sha256"] ==
        bytes2hex(sha256(read(adapter.base_input_path))) || error(
        "regularized-coil base input file mismatch")
    audit["source_files"]["base_result_sha256"] ==
        bytes2hex(sha256(read(adapter.base_raw_path))) || error(
        "regularized-coil base result file mismatch")
    audit["source_files"]["refined_input_sha256"] ==
        bytes2hex(sha256(read(adapter.refined_input_path))) || error(
        "regularized-coil refined input file mismatch")
    audit["source_files"]["refined_result_sha256"] ==
        bytes2hex(sha256(read(adapter.refined_raw_path))) || error(
        "regularized-coil refined result file mismatch")
    audit["source_files"]["runner_sha256"] ==
        bytes2hex(sha256(read(adapter.runner_path))) || error(
        "regularized-coil runner source mismatch")
    all(value === true for value in values(audit["gates"])) || error(
        "regularized-coil audit contains a failed gate")
    audit["interpretation"]["engineering_feasibility_established"] === false ||
        error("regularized-coil audit crossed engineering boundary")

    force = refined_raw["force_proxy"]
    geometry = force["geometry_diagnostics"]
    energy = refined_raw["inductance_and_energy"]
    comparison = audit["comparisons"]
    warnings_out = String[
        "The regularized self-force field is not the peak internal conductor field.",
        "The reduced model is asymptotic in conductor dimension divided by local curvature radius; no universal threshold was applied to the reported width-curvature ratio.",
        "Stored energy includes the 48 external coils only and excludes plasma-current and conducting-structure coupling.",
        "Line loads exclude plasma-current field and were not propagated through supports or a stress/strain model.",
        "No conductor allocation, material limits, critical surface, temperature/strain margin, quench, insulation, joints, or integrated engineering were evaluated.",
    ]
    append!(warnings_out, String.(audit["warnings"]))
    unique!(warnings_out)
    residuals = Dict{String,Float64}(
        "maximum_self_line_load_relative_resolution_change" => Float64(
            comparison["maximum_self_line_load_relative_change"]),
        "maximum_mutual_line_load_relative_resolution_change" => Float64(
            comparison["maximum_mutual_line_load_relative_change"]),
        "maximum_total_line_load_relative_resolution_change" => Float64(
            comparison["maximum_total_line_load_relative_change"]),
        "stored_energy_relative_resolution_change" => Float64(
            comparison["stored_energy_relative_change"]),
        "circle_regression_maximum_relative_error" => Float64(
            comparison["refined_circle_maximum_relative_error"]),
        "actual_formula_crosscheck_relative_difference" => Float64(
            comparison["refined_actual_coil_formula_crosscheck_relative_difference"]),
    )
    file_hashes = Dict(
        "base_input" => bytes2hex(sha256(read(adapter.base_input_path))),
        "base_raw" => bytes2hex(sha256(read(adapter.base_raw_path))),
        "refined_input" => bytes2hex(sha256(read(adapter.refined_input_path))),
        "refined_raw" => bytes2hex(sha256(read(adapter.refined_raw_path))),
        "audit" => bytes2hex(sha256(read(adapter.resolution_audit_path))),
        "runner" => bytes2hex(sha256(read(adapter.runner_path))),
        "adapter" => bytes2hex(sha256(read(@__FILE__))),
    )
    run_hash = canonical_hash(Dict(
        "physics_hash" => genome.physics_hash,
        "coil_state_hash" => _DESC_REGULARIZED_COIL_STATE_HASH,
        "base_result_hash" => base_raw["result_hash"],
        "refined_result_hash" => refined_raw["result_hash"],
        "resolution_audit_hash" => audit["audit_hash"],
        "file_hashes" => file_hashes,
        "evaluator" => "stellarator_regularized_coil_force_desc_v1",
        "version" => "1.0.0",
    ))
    constraints = sort!(collect(keys(audit["gates"])))
    metrics = MetricResult[
        _desc_regularized_coil_metric(
            "regularized_rectangular_coil_force_resolution_audit_passed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("regularized_coil_self_force_computed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("maximum_regularized_self_force_field",
            force["maximum_regularized_self_force_field_T"];
            unit = "T", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("maximum_self_lorentz_line_load",
            force["maximum_self_lorentz_line_load_N_per_m"];
            unit = "N/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("rms_self_lorentz_line_load",
            force["rms_self_lorentz_line_load_N_per_m"];
            unit = "N/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("maximum_total_coil_lorentz_line_load",
            force["maximum_total_coil_lorentz_line_load_N_per_m"];
            unit = "N/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("rms_total_coil_lorentz_line_load",
            force["rms_total_coil_lorentz_line_load_N_per_m"];
            unit = "N/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("coil_only_stored_magnetic_energy",
            energy["total_coil_only_stored_magnetic_energy_J"] / 1.0e6;
            unit = "MJ", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("equivalent_common_current_inductance",
            energy["equivalent_common_current_inductance_H"] * 1.0e3;
            unit = "mH", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_regularized_coil_metric("maximum_conductor_width_times_curvature",
            geometry["maximum_width_times_curvature"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
    ]
    for (id, message) in (
            ("peak_internal_conductor_field_computed",
                "Breg yields cross-section-averaged self-force but not peak internal field"),
            ("plasma_current_field_at_conductor_computed",
                "plasma-current field and coil-plasma coupling were excluded"),
            ("structural_stress_or_strain_feasible",
                "line load was not propagated through supports or a stress/strain model"),
            ("thermal_or_superconducting_margin_feasible",
                "no conductor material, critical surface, temperature, strain, or quench model was evaluated"),
            ("engineering_feasible",
                "regularized electromagnetic proxies do not close integrated engineering"))
        push!(metrics, _desc_regularized_coil_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), residuals = residuals))
    end
    return EvaluationBundle("stellarator_regularized_coil_force_desc_v1",
        genome.design_id, genome.family, 1, :pass, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCRegularizedCoilForceV1,
        genome::Genome; kwargs...)
    return _desc_regularized_coil_bundle_from_files(adapter, genome)
end
