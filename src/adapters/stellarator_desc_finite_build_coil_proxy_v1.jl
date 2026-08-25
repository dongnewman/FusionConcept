struct StellaratorDESCFiniteBuildCoilProxyV1 <: AbstractEvaluator
    base_input_path::String
    base_raw_path::String
    refined_input_path::String
    refined_raw_path::String
    resolution_audit_path::String
    runner_path::String

    function StellaratorDESCFiniteBuildCoilProxyV1(
            base_input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_finite_build_coil_pool16_base_input.json")),
            base_raw_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_finite_build_coil_pool16_base_raw.json")),
            refined_input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_finite_build_coil_pool16_refined_input.json")),
            refined_raw_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_finite_build_coil_pool16_refined_raw.json")),
            resolution_audit_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_finite_build_coil_pool16_resolution_audit.json")),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_stellarator_finite_build_coil_runner.py")))
        paths = abspath.(String.((base_input_path, base_raw_path, refined_input_path,
            refined_raw_path, resolution_audit_path, runner_path)))
        labels = ("base input", "base raw", "refined input", "refined raw",
            "resolution audit", "runner")
        for (path, label) in zip(paths, labels)
            isfile(path) || throw(ArgumentError(
                "DESC finite-build coil $label not found at $path"))
        end
        return new(paths...)
    end
end

const _DESC_FINITE_BUILD_COIL_PHYSICS_HASH =
    "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"
const _DESC_FINITE_BUILD_COIL_STATE_HASH =
    "732b0e2e106b743803868e79608ab9541a0a495766ec97b26b91c8f21ab95260"
const _DESC_FINITE_BUILD_COIL_RUNNER_VERSION =
    "desc_stellarator_finite_build_coil_proxy_runner_v1"
const _DESC_FINITE_BUILD_COIL_BASE_INPUT_HASH =
    "6bb7ecde7118909f51daffb38ada7c569d6af8d426ddc9b68fc017be3bd05a1e"
const _DESC_FINITE_BUILD_COIL_BASE_RESULT_HASH =
    "2b168c053f373142e42ee2c3a5fbda500def09c5cda5a2e3edcf3ac787484e09"
const _DESC_FINITE_BUILD_COIL_REFINED_INPUT_HASH =
    "1db98db7b239001b1a130bc0b4f74c601f7bafbadb77d1d70086eee3c28c9202"
const _DESC_FINITE_BUILD_COIL_REFINED_RESULT_HASH =
    "e3d9ae65d414a9ffa7e625cd3b70e7934461bfbc415466db403d21f5a2001b28"
const _DESC_FINITE_BUILD_COIL_AUDIT_HASH =
    "283c0785b6fa166bdbc8b9d5318ddc11c833bcfb5974d9119822d1b7f584ab5a"
const _DESC_FINITE_BUILD_COIL_CLAIM_BOUNDARY =
    "Square winding-pack midpoint multi-filament correction to boundary B.n, circumscribed-pack clearance lower bounds, equivalent engineering current density, and mutual-coil-only field/Lorentz line-load proxy for one fixed 48-coil state; not self field/force, structural stress or strain, thermal or superconducting margin, insulation, joints, stored energy, finite-element validation, engineering feasibility, global optimality, or superiority."

function evaluator_spec(::StellaratorDESCFiniteBuildCoilProxyV1)
    return EvaluatorSpec(
        "stellarator_finite_build_coil_proxy_desc_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "explicit_fourier_boundary" => :full,
            "finite_beta_equilibrium" => :full,
            "optimized_filament_coils" => :full,
            "finite_build_coils" => :proxy,
            "winding_pack_clearance" => :proxy,
            "winding_pack_current_density" => :proxy,
            "mutual_coil_electromagnetic_load" => :proxy,
        ),
        "physics_concept",
    )
end

function evaluator_applicability(
        evaluator::StellaratorDESCFiniteBuildCoilProxyV1, genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    genome.physics_hash == _DESC_FINITE_BUILD_COIL_PHYSICS_HASH || return false,
        "version 1 is bound to the audited pool-16 NFP=2 stellarator candidate"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact pool-16 generated Fourier stellarator with source-bound finite-build coil proxy evidence" :
        "stellarator_finite_build_coil_proxy_desc_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_finite_build_coil_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}())
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 fixed 48-coil state expanded into square midpoint multi-filament winding packs; 60 mm anchor audited from 3x3 to 5x5 cross-section quadrature.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_finite_build_coil_proxy_desc_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3",
            "desc_stage_two_coil_tutorial_0_14_1",
            "singh_finite_build_coils_2020",
            "landreman_rectangular_coil_self_force_2025"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = 0.0)
end

function _read_desc_finite_build_json(path::AbstractString)
    return _plain_json(JSON3.read(read(path, String), Dict{String,Any}))
end

function _validate_desc_finite_build_raw(raw::Dict{String,Any}, genome::Genome,
        label::AbstractString, expected_input_hash::AbstractString,
        expected_result_hash::AbstractString)
    raw["status"] == "pass" || error("finite-build $label status is not pass")
    raw["runner_version"] == _DESC_FINITE_BUILD_COIL_RUNNER_VERSION || error(
        "finite-build $label runner version mismatch")
    raw["claim_boundary"] == _DESC_FINITE_BUILD_COIL_CLAIM_BOUNDARY || error(
        "finite-build $label claim boundary mismatch")
    raw["physics_hash"] == genome.physics_hash || error(
        "finite-build $label is detached from genome")
    raw["selected_coil_state_hash"] == _DESC_FINITE_BUILD_COIL_STATE_HASH || error(
        "finite-build $label coil-state hash mismatch")
    raw["input_hash"] == expected_input_hash || error(
        "finite-build $label input hash mismatch")
    raw["result_hash"] == expected_result_hash || error(
        "finite-build $label result hash mismatch")
    raw["equilibrium_reference"]["matched"] === true || error(
        "finite-build $label equilibrium reference did not match")
    raw["all_comparison_gates_passed"] === true || error(
        "finite-build $label comparison gates failed")
    raw["interpretation"]["self_field_or_self_force_computed"] === false || error(
        "finite-build $label crossed self-force boundary")
    raw["interpretation"]["structural_stress_or_strain_computed"] === false || error(
        "finite-build $label crossed structural boundary")
    raw["interpretation"]["thermal_or_superconducting_margin_computed"] === false ||
        error("finite-build $label crossed superconducting boundary")
    raw["interpretation"]["engineering_feasibility_established"] === false || error(
        "finite-build $label crossed engineering boundary")
end

function _desc_finite_build_coil_bundle_from_files(
        adapter::StellaratorDESCFiniteBuildCoilProxyV1, genome::Genome)
    base_input = _read_desc_finite_build_json(adapter.base_input_path)
    base_raw = _read_desc_finite_build_json(adapter.base_raw_path)
    refined_input = _read_desc_finite_build_json(adapter.refined_input_path)
    refined_raw = _read_desc_finite_build_json(adapter.refined_raw_path)
    audit = _read_desc_finite_build_json(adapter.resolution_audit_path)
    _validate_desc_finite_build_raw(base_raw, genome, "base",
        _DESC_FINITE_BUILD_COIL_BASE_INPUT_HASH,
        _DESC_FINITE_BUILD_COIL_BASE_RESULT_HASH)
    _validate_desc_finite_build_raw(refined_raw, genome, "refined",
        _DESC_FINITE_BUILD_COIL_REFINED_INPUT_HASH,
        _DESC_FINITE_BUILD_COIL_REFINED_RESULT_HASH)
    # Input canonical hashes are produced by the pinned Python runner. Cross-language
    # float rendering is not used as a duplicate check here; exact input files are
    # instead bound below by the audit's SHA-256 records.
    audit["audit_hash"] == _DESC_FINITE_BUILD_COIL_AUDIT_HASH || error(
        "finite-build audit hash mismatch")
    audit["all_passed"] === true || error("finite-build resolution audit failed")
    audit["physics_hash"] == genome.physics_hash || error(
        "finite-build audit is detached from genome")
    audit["selected_coil_state_hash"] == _DESC_FINITE_BUILD_COIL_STATE_HASH || error(
        "finite-build audit coil-state hash mismatch")
    audit["source_files"]["base_input_sha256"] ==
        bytes2hex(sha256(read(adapter.base_input_path))) || error(
        "finite-build audit base input file mismatch")
    audit["source_files"]["base_result_sha256"] ==
        bytes2hex(sha256(read(adapter.base_raw_path))) || error(
        "finite-build audit base result file mismatch")
    audit["source_files"]["refined_input_sha256"] ==
        bytes2hex(sha256(read(adapter.refined_input_path))) || error(
        "finite-build audit refined input file mismatch")
    audit["source_files"]["refined_result_sha256"] ==
        bytes2hex(sha256(read(adapter.refined_raw_path))) || error(
        "finite-build audit refined result file mismatch")
    audit["source_files"]["runner_sha256"] ==
        bytes2hex(sha256(read(adapter.runner_path))) || error(
        "finite-build audit runner source mismatch")
    for value in values(audit["gates"])
        value === true || error("finite-build audit contains a failed gate")
    end
    audit["interpretation"]["all_widths_resolution_audited"] === false || error(
        "finite-build audit crossed all-width resolution boundary")
    audit["interpretation"]["engineering_feasibility_established"] === false || error(
        "finite-build audit crossed engineering boundary")

    anchor = only(refined_raw["scan_records"])
    anchor["width_m"] == 0.06 || error("finite-build refined anchor changed")
    mutual = anchor["mutual_coil_proxy"]
    warnings_out = String[
        "Only the predeclared 60 mm square pack received the 5x5 refined calculation; 20, 40, and 80 mm are base-resolution trend points.",
        "The Bn result is a strict RMS bound formed from the independently audited 48x48 line-current RMS plus the finite-build correction RMS.",
        "The square winding-pack orientation follows a sampled Frenet frame and was not optimized.",
        "Mutual-coil field and line load exclude self field/force and plasma-current field at the conductor.",
        "No material limits, structural stress/strain, insulation, thermal/quench margin, joints, supports, stored energy, or integrated engineering were evaluated.",
    ]
    append!(warnings_out, String.(audit["warnings"]))
    unique!(warnings_out)
    comparison = audit["comparisons"]
    residuals = Dict{String,Float64}(
        "finite_build_correction_absolute_resolution_change" => Float64(
            comparison["anchor_finite_build_correction_absolute_change"]),
        "finite_build_upper_bound_absolute_resolution_change" => Float64(
            comparison["anchor_finite_build_upper_bound_absolute_change"]),
        "maximum_mutual_field_relative_resolution_change" => Float64(
            comparison["anchor_maximum_mutual_field_relative_change"]),
        "maximum_mutual_line_load_relative_resolution_change" => Float64(
            comparison["anchor_maximum_mutual_line_load_relative_change"]),
        "segment_desc_normalized_bn_rms_difference" => Float64(
            comparison["refined_segment_desc_normalized_bn_rms_difference"]),
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
        "coil_state_hash" => _DESC_FINITE_BUILD_COIL_STATE_HASH,
        "base_result_hash" => base_raw["result_hash"],
        "refined_result_hash" => refined_raw["result_hash"],
        "resolution_audit_hash" => audit["audit_hash"],
        "file_hashes" => file_hashes,
        "evaluator" => "stellarator_finite_build_coil_proxy_desc_v1",
        "version" => "1.0.0",
    ))
    constraints = sort!(collect(keys(audit["gates"])))
    metrics = MetricResult[
        _desc_finite_build_coil_metric("finite_build_winding_pack_scan_completed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("finite_build_anchor_resolution_audit_passed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("refined_square_winding_pack_width",
            anchor["width_m"]; unit = "m", input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("refined_finite_build_bn_correction_rms_normalized",
            anchor["finite_build_correction_normalized_bn_rms"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("refined_finite_build_bn_rms_upper_bound",
            anchor["finite_build_normalized_bn_rms_upper_bound"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("refined_finite_build_bn_comparison_reference_met",
            anchor["gates"]["finite_build_bn_comparison_reference_met"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["strict normalized Bn RMS upper bound <= 0.02 comparison reference"],
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("equivalent_winding_pack_engineering_current_density",
            anchor["equivalent_winding_pack_engineering_current_density_MA_per_m2"];
            unit = "MA/m^2", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("circumscribed_pack_coil_coil_clearance_lower_bound",
            anchor["circumscribed_pack_minimum_coil_coil_clearance_lower_bound_m"];
            unit = "m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("circumscribed_pack_plasma_coil_clearance_lower_bound",
            anchor["circumscribed_pack_minimum_plasma_coil_clearance_lower_bound_m"];
            unit = "m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("maximum_mutual_coil_field_at_centerline",
            mutual["maximum_mutual_coil_field_at_centerline_T"];
            unit = "T", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("rms_mutual_coil_field_at_centerline",
            mutual["rms_mutual_coil_field_at_centerline_T"];
            unit = "T", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("maximum_mutual_coil_lorentz_line_load",
            mutual["maximum_mutual_coil_lorentz_line_load_N_per_m"];
            unit = "N/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_finite_build_coil_metric("rms_mutual_coil_lorentz_line_load",
            mutual["rms_mutual_coil_lorentz_line_load_N_per_m"];
            unit = "N/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
    ]
    for (id, message) in (
            ("winding_pack_orientation_optimized",
                "the sampled Frenet frame is fixed rather than optimized"),
            ("coil_self_field_or_self_force_computed",
                "a regularized finite-cross-section self-field/self-force method is required"),
            ("structural_stress_or_strain_feasible",
                "electromagnetic line load was not propagated through a support model"),
            ("thermal_or_superconducting_margin_feasible",
                "no material, temperature, strain, critical-surface, or quench model was evaluated"),
            ("engineering_feasible",
                "finite-build electromagnetic proxies do not close integrated engineering"))
        push!(metrics, _desc_finite_build_coil_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), residuals = residuals))
    end
    return EvaluationBundle("stellarator_finite_build_coil_proxy_desc_v1",
        genome.design_id, genome.family, 1, :pass, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCFiniteBuildCoilProxyV1,
        genome::Genome; kwargs...)
    return _desc_finite_build_coil_bundle_from_files(adapter, genome)
end
