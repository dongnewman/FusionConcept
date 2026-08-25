struct StellaratorDESCRectangularInternalFieldV1 <: AbstractEvaluator
    ultra_input_path::String
    ultra_raw_path::String
    initial_audit_path::String
    convergence_verification_path::String
    plasma_completion_audit_path::String
    ultra_verification_path::String
    runner_path::String
    ultra_runner_path::String
    audit_script_paths::Vector{String}

    function StellaratorDESCRectangularInternalFieldV1(
            ultra_input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_rectangular_internal_field_pool16_ultra_input.json")),
            ultra_raw_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_rectangular_internal_field_pool16_ultra_raw.json")),
            initial_audit_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_rectangular_internal_field_pool16_resolution_audit.json")),
            convergence_verification_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_rectangular_internal_field_pool16_convergence_verification.json")),
            plasma_completion_audit_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_rectangular_internal_field_pool16_plasma_completion_audit.json")),
            ultra_verification_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_rectangular_internal_field_pool16_ultra_verification.json")),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_stellarator_rectangular_internal_field_runner.py")),
            ultra_runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_stellarator_rectangular_internal_field_ultra_runner.py")))
        paths = abspath.(String.((ultra_input_path, ultra_raw_path,
            initial_audit_path, convergence_verification_path,
            plasma_completion_audit_path, ultra_verification_path,
            runner_path, ultra_runner_path)))
        labels = ("ultra input", "ultra raw", "initial failed audit",
            "failed convergence verification", "failed plasma completion audit",
            "ultra verification", "runner", "ultra runner")
        for (path, label) in zip(paths, labels)
            isfile(path) || throw(ArgumentError(
                "DESC rectangular internal-field $label not found at $path"))
        end
        audit_scripts = abspath.(String[
            normpath(joinpath(@__DIR__, "..", "..", "scripts",
                "desc_stellarator_rectangular_internal_field_resolution_audit.py")),
            normpath(joinpath(@__DIR__, "..", "..", "scripts",
                "desc_stellarator_rectangular_internal_field_convergence_verification.py")),
            normpath(joinpath(@__DIR__, "..", "..", "scripts",
                "desc_stellarator_rectangular_internal_field_plasma_completion_audit.py")),
            normpath(joinpath(@__DIR__, "..", "..", "scripts",
                "desc_stellarator_rectangular_internal_field_ultra_verification.py")),
        ])
        all(isfile, audit_scripts) || throw(ArgumentError(
            "DESC rectangular internal-field audit script is missing"))
        return new(paths..., audit_scripts)
    end
end

const _DESC_RECTANGULAR_INTERNAL_FIELD_PHYSICS_HASH =
    "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"
const _DESC_RECTANGULAR_INTERNAL_FIELD_STATE_HASH =
    "732b0e2e106b743803868e79608ab9541a0a495766ec97b26b91c8f21ab95260"
const _DESC_RECTANGULAR_INTERNAL_FIELD_RUNNER_VERSION =
    "desc_stellarator_rectangular_internal_field_runner_v1"
const _DESC_RECTANGULAR_INTERNAL_FIELD_WRAPPER_VERSION =
    "desc_stellarator_rectangular_internal_field_ultra_wrapper_v1"
const _DESC_RECTANGULAR_INTERNAL_FIELD_INPUT_HASH =
    "39cd24154c22c817d969678ec6fa6c80b0e57451c457b1daaa4811694a914d1c"
const _DESC_RECTANGULAR_INTERNAL_FIELD_RESULT_HASH =
    "8a32b00f2ea97eb4bcf846d00e5d0b49dcf634463069cc14ede04f4645be91e6"
const _DESC_RECTANGULAR_INTERNAL_FIELD_INITIAL_AUDIT_HASH =
    "40ed4e39e3feb536f0c24957c971c00cb17acf98790d0ed5db969e569e1e49a6"
const _DESC_RECTANGULAR_INTERNAL_FIELD_CONVERGENCE_HASH =
    "af21635bcefcc92ffe4bbe756a3f344aebc11b7f53acdfb371727f079a8f2c0b"
const _DESC_RECTANGULAR_INTERNAL_FIELD_COMPLETION_HASH =
    "4e3076e9a657e34461573f01046de61e2ce49cf7c7e7e62e03faa9827311c63b"
const _DESC_RECTANGULAR_INTERNAL_FIELD_VERIFICATION_HASH =
    "617b1938233bd9bbf61e14e5712289e5647e2d521567652b030fd36a28a6e03d"
const _DESC_RECTANGULAR_INTERNAL_FIELD_CLAIM_BOUNDARY =
    "Sampled rectangular-conductor internal self field from the high-coil-aspect-ratio reduced model, combined with separated-centreline fields from the other 47 coils and an exterior virtual-casing plasma-current field, for one fixed 48-coil 60 mm square-pack state; not a resolved winding, tape or turn model, current redistribution, superconductor critical-surface margin, temperature or strain margin, quench, insulation, joints, structural stress, finite-element validation, engineering feasibility, global optimality, or superiority."

function evaluator_spec(::StellaratorDESCRectangularInternalFieldV1)
    return EvaluatorSpec(
        "stellarator_rectangular_internal_field_desc_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "finite_build_coils" => :proxy,
            "rectangular_conductor_internal_field" => :proxy,
            "peak_conductor_magnetic_field" => :proxy,
            "plasma_current_field_at_conductor" => :proxy,
        ),
        "physics_concept",
    )
end

function evaluator_applicability(
        evaluator::StellaratorDESCRectangularInternalFieldV1, genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    genome.physics_hash == _DESC_RECTANGULAR_INTERNAL_FIELD_PHYSICS_HASH || return false,
        "version 1 is bound to the audited pool-16 NFP=2 stellarator candidate"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact pool-16 generated Fourier stellarator with source-bound rectangular internal-field evidence" :
        "stellarator_rectangular_internal_field_desc_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_rectangular_internal_field_metric(id, value; unit = "1",
        status = :pass, constraints = String[], input_hash, run_hash,
        warnings = String[], residuals = Dict{String,Float64}())
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 fixed 48-coil state with a 60 mm square uniform-current conductor; equations (16)-(21), 40 longitudinal by 13x13 cross-section samples, 160-point other-coil sources, and a passed 48x36 exterior virtual-casing source-grid verification.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_rectangular_internal_field_desc_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3", "singh_finite_build_coils_2020",
            "landreman_rectangular_coil_self_force_2025", "coilforces_jl_45a21454"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = 0.0)
end

_read_desc_rectangular_internal_json(path::AbstractString) =
    _plain_json(JSON3.read(read(path, String), Dict{String,Any}))

function _validate_embedded_source_files(record::Dict{String,Any}, label::AbstractString)
    sources = record["source_files"]
    for key in sort!(collect(keys(sources)))
        endswith(key, "_sha256") || continue
        path_key = first(key, length(key) - length("_sha256"))
        haskey(sources, path_key) || error("$label lacks path for $key")
        path = String(sources[path_key])
        isfile(path) || error("$label source file is missing: $path")
        sources[key] == bytes2hex(sha256(read(path))) || error(
            "$label source file hash mismatch: $path")
    end
end

_failed_gate_ids(record::Dict{String,Any}) =
    sort!(String[key for (key, value) in record["gates"] if value !== true])

function _desc_rectangular_internal_field_bundle_from_files(
        adapter::StellaratorDESCRectangularInternalFieldV1, genome::Genome)
    input = _read_desc_rectangular_internal_json(adapter.ultra_input_path)
    raw = _read_desc_rectangular_internal_json(adapter.ultra_raw_path)
    initial = _read_desc_rectangular_internal_json(adapter.initial_audit_path)
    convergence = _read_desc_rectangular_internal_json(
        adapter.convergence_verification_path)
    completion = _read_desc_rectangular_internal_json(
        adapter.plasma_completion_audit_path)
    verification = _read_desc_rectangular_internal_json(
        adapter.ultra_verification_path)

    input["selected_coil_state_hash"] == _DESC_RECTANGULAR_INTERNAL_FIELD_STATE_HASH ||
        error("rectangular internal-field input state mismatch")
    raw["status"] == "pass" || error("rectangular internal-field result did not pass")
    raw["runner_version"] == _DESC_RECTANGULAR_INTERNAL_FIELD_RUNNER_VERSION ||
        error("rectangular internal-field runner version mismatch")
    raw["ultra_wrapper_version"] == _DESC_RECTANGULAR_INTERNAL_FIELD_WRAPPER_VERSION ||
        error("rectangular internal-field wrapper version mismatch")
    raw["claim_boundary"] == _DESC_RECTANGULAR_INTERNAL_FIELD_CLAIM_BOUNDARY ||
        error("rectangular internal-field claim boundary mismatch")
    raw["physics_hash"] == genome.physics_hash ||
        error("rectangular internal-field result is detached from genome")
    raw["selected_coil_state_hash"] == _DESC_RECTANGULAR_INTERNAL_FIELD_STATE_HASH ||
        error("rectangular internal-field result state mismatch")
    raw["input_hash"] == _DESC_RECTANGULAR_INTERNAL_FIELD_INPUT_HASH ||
        error("rectangular internal-field input hash mismatch")
    raw["result_hash"] == _DESC_RECTANGULAR_INTERNAL_FIELD_RESULT_HASH ||
        error("rectangular internal-field result hash mismatch")
    raw["all_comparison_gates_passed"] === true ||
        error("rectangular internal-field analytic gates failed")
    raw["interpretation"]["sampled_internal_self_field_computed"] === true ||
        error("rectangular internal self field is missing")
    raw["interpretation"]["sampled_peak_total_field_including_plasma_computed"] === true ||
        error("rectangular total field is missing")
    for key in ("winding_turns_or_tapes_resolved",
            "nonuniform_current_distribution_computed",
            "superconductor_critical_surface_margin_computed",
            "structural_stress_or_strain_computed",
            "thermal_or_quench_margin_computed", "engineering_feasibility_established")
        raw["interpretation"][key] === false || error(
            "rectangular internal-field result crossed boundary $key")
    end

    initial["audit_hash"] == _DESC_RECTANGULAR_INTERNAL_FIELD_INITIAL_AUDIT_HASH ||
        error("initial internal-field audit hash mismatch")
    convergence["verification_hash"] == _DESC_RECTANGULAR_INTERNAL_FIELD_CONVERGENCE_HASH ||
        error("internal-field convergence hash mismatch")
    completion["audit_hash"] == _DESC_RECTANGULAR_INTERNAL_FIELD_COMPLETION_HASH ||
        error("internal-field completion hash mismatch")
    verification["verification_hash"] == _DESC_RECTANGULAR_INTERNAL_FIELD_VERIFICATION_HASH ||
        error("internal-field ultra verification hash mismatch")
    for (record, label) in ((initial, "initial audit"),
            (convergence, "convergence verification"),
            (completion, "plasma completion audit"),
            (verification, "ultra verification"))
        _validate_embedded_source_files(record, label)
    end
    initial["all_passed"] === false || error("initial failure was not preserved")
    convergence["all_passed"] === false || error("convergence failure was not preserved")
    completion["all_passed"] === false || error("completion failure was not preserved")
    verification["all_passed"] === true || error("ultra verification did not pass")
    _failed_gate_ids(convergence) ==
        ["maximum_plasma_current_field_resolution_accepted"] || error(
            "convergence failure no longer isolates plasma field")
    _failed_gate_ids(completion) ==
        ["maximum_plasma_current_field_resolution_accepted"] || error(
            "completion failure no longer isolates plasma field")
    all(value === true for value in values(verification["gates"])) ||
        error("ultra verification contains a failed gate")
    verification["interpretation"]["engineering_feasibility_established"] === false ||
        error("ultra verification crossed engineering boundary")

    peak = raw["sampled_internal_field"]["global_maximum"]
    comparison = verification["comparisons"]
    warnings_out = String[
        "Three coarser convergence levels failed their predeclared plasma-source gate and remain rejected; only the final 48x36 source-grid result is accepted.",
        "The maximum is sampled on a finite 40x13x13 grid over 12 unique coil representatives and is not a certified continuous-domain upper bound.",
        "The internal self-field model assumes a smooth constant rectangular cross-section and uniform current density; turns, tapes, insulation, voids, coolant, and redistribution are unresolved.",
        "No conductor material, critical surface, temperature/strain margin, quench protection, support stress, or integrated engineering was evaluated.",
    ]
    append!(warnings_out, String.(verification["warnings"]))
    unique!(warnings_out)
    residuals = Dict{String,Float64}(
        "ultra_plasma_field_relative_resolution_change" => Float64(
            comparison["maximum_plasma_current_field_relative_change"]),
        "ultra_total_field_relative_resolution_change" => Float64(
            comparison["maximum_total_internal_field_relative_change"]),
        "straight_conductor_ampere_relative_error" => Float64(
            raw["straight_conductor_ampere_regression"]["relative_error"]),
        "circle_center_field_relative_error" => Float64(
            raw["circle_center_field_regression"]["relative_vector_error"]),
        "cross_section_average_force_relative_error" => Float64(
            raw["force_average_regression"]["relative_vector_error"]),
        "rejected_initial_plasma_field_relative_change" => Float64(
            initial["comparisons"]["maximum_plasma_current_field_relative_change"]),
        "rejected_high_plasma_field_relative_change" => Float64(
            convergence["comparisons"]["maximum_plasma_current_field_relative_change"]),
        "rejected_completion_plasma_field_relative_change" => Float64(
            completion["comparisons"]["maximum_plasma_current_field_relative_change"]),
    )
    file_hashes = Dict{String,Any}(
        "ultra_input" => bytes2hex(sha256(read(adapter.ultra_input_path))),
        "ultra_raw" => bytes2hex(sha256(read(adapter.ultra_raw_path))),
        "initial_audit" => bytes2hex(sha256(read(adapter.initial_audit_path))),
        "convergence_verification" => bytes2hex(sha256(read(
            adapter.convergence_verification_path))),
        "plasma_completion_audit" => bytes2hex(sha256(read(
            adapter.plasma_completion_audit_path))),
        "ultra_verification" => bytes2hex(sha256(read(adapter.ultra_verification_path))),
        "runner" => bytes2hex(sha256(read(adapter.runner_path))),
        "ultra_runner" => bytes2hex(sha256(read(adapter.ultra_runner_path))),
        "audit_scripts" => [bytes2hex(sha256(read(path))) for path in
            adapter.audit_script_paths],
        "adapter" => bytes2hex(sha256(read(@__FILE__))),
    )
    run_hash = canonical_hash(Dict(
        "physics_hash" => genome.physics_hash,
        "coil_state_hash" => _DESC_RECTANGULAR_INTERNAL_FIELD_STATE_HASH,
        "result_hash" => raw["result_hash"],
        "verification_hash" => verification["verification_hash"],
        "preceding_failure_hashes" => verification["preceding_failure_hashes"],
        "file_hashes" => file_hashes,
        "evaluator" => "stellarator_rectangular_internal_field_desc_v1",
        "version" => "1.0.0",
    ))
    constraints = sort!(collect(keys(verification["gates"])))
    metrics = MetricResult[
        _desc_rectangular_internal_field_metric(
            "rectangular_internal_field_resolution_verified", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_rectangular_internal_field_metric(
            "peak_internal_conductor_field_computed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_rectangular_internal_field_metric(
            "plasma_current_field_at_conductor_computed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_rectangular_internal_field_metric("maximum_internal_self_field",
            peak["maximum_internal_self_field_T"]; unit = "T",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_rectangular_internal_field_metric("maximum_other_coil_field",
            peak["maximum_other_coil_field_T"]; unit = "T",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_rectangular_internal_field_metric("maximum_plasma_current_field",
            peak["maximum_plasma_current_field_T"]; unit = "T",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_rectangular_internal_field_metric("maximum_coil_only_internal_field",
            peak["maximum_coil_only_internal_field_T"]; unit = "T",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_rectangular_internal_field_metric(
            "maximum_total_internal_field_including_plasma",
            peak["maximum_total_internal_field_T"]; unit = "T",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
    ]
    for (id, message) in (
            ("winding_turns_or_tapes_resolved",
                "the 60 mm square pack was not allocated into turns, tapes, insulation, void, or coolant"),
            ("nonuniform_current_distribution_computed",
                "uniform current density was assumed and no redistribution model was solved"),
            ("superconductor_critical_surface_margin_feasible",
                "no conductor material, critical surface, temperature, or strain state was supplied"),
            ("structural_stress_or_strain_feasible",
                "magnetic field was not propagated through a support stress/strain model"),
            ("thermal_or_quench_margin_feasible",
                "no thermal transient, protection, hotspot, or quench calculation was performed"),
            ("engineering_feasible",
                "a sampled field input does not close integrated magnet engineering"))
        push!(metrics, _desc_rectangular_internal_field_metric(id, nothing;
            status = :unknown, input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), residuals = residuals))
    end
    return EvaluationBundle("stellarator_rectangular_internal_field_desc_v1",
        genome.design_id, genome.family, 1, :pass, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCRectangularInternalFieldV1,
        genome::Genome; kwargs...)
    return _desc_rectangular_internal_field_bundle_from_files(adapter, genome)
end
