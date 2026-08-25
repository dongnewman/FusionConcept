struct StellaratorDESCDiscreteCoilOptimizationV1 <: AbstractEvaluator
    input_path::String
    raw_path::String
    repair_screen_path::String
    resolution_audit_path::String
    tolerance_audit_path::String

    function StellaratorDESCDiscreteCoilOptimizationV1(
            input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_discrete_coil_optimization_pool16_v7_input.json")),
            raw_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_discrete_coil_optimization_pool16_v7_raw.json")),
            repair_screen_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_discrete_coil_interpolation_screen_pool16_v3.json")),
            resolution_audit_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_discrete_coil_interpolation_screen_pool16_v3_resolution_audit.json")),
            tolerance_audit_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_discrete_coil_interpolation_screen_pool16_v3_tolerance_audit.json")))
        paths = abspath.(String.((input_path, raw_path, repair_screen_path,
            resolution_audit_path, tolerance_audit_path)))
        labels = ("optimization input", "optimization raw", "repair screen",
            "resolution audit", "tolerance audit")
        for (path, label) in zip(paths, labels)
            isfile(path) || throw(ArgumentError("DESC discrete-coil $label not found at $path"))
        end
        return new(paths...)
    end
end

const _DESC_DISCRETE_COIL_OPTIMIZATION_PHYSICS_HASH =
    "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"
const _DESC_DISCRETE_COIL_OPTIMIZATION_CLAIM_BOUNDARY =
    "One fixed-current 48-filament coil state passed a base-to-refined line-current geometry and Bn audit plus a deterministic four-sample one-millimetre broken-symmetry screen; the three-millimetre screen failed, and no finite conductor, statistical manufacturing qualification, structural, superconducting, access, blanket, maintenance, integrated engineering, or superiority claim is made."

function evaluator_spec(::StellaratorDESCDiscreteCoilOptimizationV1)
    return EvaluatorSpec(
        "stellarator_discrete_coil_optimization_desc_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "explicit_fourier_boundary" => :full,
            "finite_beta_equilibrium" => :full,
            "continuous_surface_current_inverse_design" => :full,
            "finite_discrete_coil_contours" => :full,
            "optimized_filament_coils" => :full,
            "line_current_geometry" => :full,
            "finite_build_coils" => :proxy,
            "assembly_tolerance" => :proxy,
        ),
        "physics_concept",
    )
end

function evaluator_applicability(
        evaluator::StellaratorDESCDiscreteCoilOptimizationV1, genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    genome.physics_hash == _DESC_DISCRETE_COIL_OPTIMIZATION_PHYSICS_HASH || return false,
        "version 1 is bound to the audited pool-16 NFP=2 stellarator candidate"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact pool-16 generated Fourier stellarator with fixed audited coil evidence" :
        "stellarator_discrete_coil_optimization_desc_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_optimized_coil_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}())
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 fixed-current 48-filament coil shape with refined-grid evaluation and deterministic broken-symmetry perturbation screens.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_discrete_coil_optimization_desc_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3", "landreman_regcoil_2017",
            "desc_regcoil_tutorial_0_17_3", "desc_stage_two_coil_tutorial_0_14_1"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = 0.0)
end

function _read_desc_coil_json(path::AbstractString)
    return _plain_json(JSON3.read(read(path, String), Dict{String,Any}))
end

function _desc_discrete_coil_optimization_bundle_from_files(
        adapter::StellaratorDESCDiscreteCoilOptimizationV1, genome::Genome)
    input = _read_desc_coil_json(adapter.input_path)
    raw = _read_desc_coil_json(adapter.raw_path)
    repair = _read_desc_coil_json(adapter.repair_screen_path)
    resolution = _read_desc_coil_json(adapter.resolution_audit_path)
    tolerance = _read_desc_coil_json(adapter.tolerance_audit_path)

    input["physics_hash"] == genome.physics_hash || error(
        "optimization input is detached from genome")
    raw["status"] == "pass" || error("optimization raw status is not pass")
    raw["base_margin_candidate_accepted"] === false || error(
        "version 7 endpoint should fail its micrometre-scale length margin")
    repair["physics_hash"] == genome.physics_hash || error(
        "repair screen is detached from genome")
    repair["source"]["v7_input_file_sha256"] ==
        bytes2hex(sha256(read(adapter.input_path))) || error(
        "repair screen is detached from optimization input")
    repair["source"]["v7_raw_file_sha256"] ==
        bytes2hex(sha256(read(adapter.raw_path))) || error(
        "repair screen is detached from optimization raw")
    repair["source"]["v7_result_hash"] == raw["result_hash"] || error(
        "repair screen and optimization raw result hash disagree")
    repair["base_repair_candidate_accepted"] === true || error(
        "repair screen did not produce an accepted base candidate")
    resolution["source_hashes"]["repair_screen_result_hash"] ==
        repair["result_hash"] || error("resolution audit is detached from repair")
    resolution["source_files"]["repair_screen_sha256"] ==
        bytes2hex(sha256(read(adapter.repair_screen_path))) || error(
        "resolution audit repair file hash mismatch")
    resolution["all_passed"] === true || error(
        "repair candidate failed its refined-grid audit")
    tolerance["source_hashes"]["repair_screen_result_hash"] ==
        repair["result_hash"] || error("tolerance audit is detached from repair")
    tolerance["source_hashes"]["resolution_audit_hash"] ==
        resolution["audit_hash"] || error(
        "tolerance audit is detached from resolution audit")
    tolerance["source_files"]["repair_screen_sha256"] ==
        bytes2hex(sha256(read(adapter.repair_screen_path))) || error(
        "tolerance audit repair file hash mismatch")
    tolerance["source_files"]["resolution_audit_sha256"] ==
        bytes2hex(sha256(read(adapter.resolution_audit_path))) || error(
        "tolerance audit resolution file hash mismatch")
    tolerance["candidate_one_mm_tolerance_screen_accepted"] === true || error(
        "one-millimetre deterministic screen did not pass")
    tolerance["three_mm_stress_screen_accepted"] === false || error(
        "version 1 expects the recorded failed three-millimetre screen")
    tolerance["interpretation"]["statistical_manufacturing_tolerance_established"] ===
        false || error("tolerance audit crossed statistical qualification boundary")
    tolerance["interpretation"]["finite_build_coils_feasibility_established"] ===
        false || error("tolerance audit crossed finite-build boundary")
    tolerance["interpretation"]["engineering_feasibility_established"] === false ||
        error("tolerance audit crossed engineering boundary")

    refined = resolution["refined"]
    comparison = resolution["comparisons"]
    one_mm = tolerance["summaries"]["one_mm"]
    three_mm = tolerance["summaries"]["three_mm"]
    warnings_out = String[
        "The one-millimetre result is a four-sample deterministic screen, not a manufacturing yield or confidence interval.",
        "The same-seed three-millimetre stress screen failed torsion and maximum-length gates.",
        "The refined normalized-Bn RMS remains above the one-percent comparison reference.",
        "All coils are zero-thickness line currents; conductor pack, current density, forces, stress, superconducting margin, supports, access, blanket, maintenance, exhaust, neutronics, and plant balance were not modeled.",
    ]
    append!(warnings_out, String.(resolution["warnings"]))
    append!(warnings_out, String.(tolerance["warnings"]))
    unique!(warnings_out)
    residuals = Dict{String,Float64}(
        "base_to_refined_bn_rms_normalized_absolute_change" => Float64(
            comparison["normalized_bn_absolute_change"]),
        "refined_source_relative_bn_improvement" => Float64(
            comparison["refined_bn_relative_improvement_from_refined_source"]),
        "one_mm_maximum_relative_bn_degradation" => Float64(
            one_mm["maximum_relative_bn_degradation"]),
        "one_mm_maximum_sampled_torsion_per_m" => Float64(
            one_mm["maximum_sampled_abs_torsion_per_m"]),
        "one_mm_maximum_individual_coil_length_m" => Float64(
            one_mm["maximum_individual_coil_length_m"]),
    )
    file_hashes = Dict(
        "input" => bytes2hex(sha256(read(adapter.input_path))),
        "raw" => bytes2hex(sha256(read(adapter.raw_path))),
        "repair" => bytes2hex(sha256(read(adapter.repair_screen_path))),
        "resolution" => bytes2hex(sha256(read(adapter.resolution_audit_path))),
        "tolerance" => bytes2hex(sha256(read(adapter.tolerance_audit_path))),
    )
    run_hash = canonical_hash(Dict(
        "physics_hash" => genome.physics_hash,
        "repair_result_hash" => repair["result_hash"],
        "resolution_audit_hash" => resolution["audit_hash"],
        "tolerance_audit_hash" => tolerance["audit_hash"],
        "file_hashes" => file_hashes,
        "evaluator" => "stellarator_discrete_coil_optimization_desc_v1",
        "version" => "1.0.0",
    ))
    constraints = ["refined-grid Bn and geometry drift gates",
        "line-current distance, curvature, torsion, and length gates",
        "four deterministic one-millimetre broken-symmetry perturbations"]
    metrics = MetricResult[
        _desc_optimized_coil_metric("coil_shape_optimization_performed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric(
            "optimized_discrete_line_current_geometry_feasible", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric(
            "optimized_discrete_coil_resolution_audit_passed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = sort!(collect(keys(resolution["gates"]))),
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric(
            "deterministic_one_mm_tolerance_screen_passed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric(
            "deterministic_three_mm_stress_screen_passed", false;
            status = :fail, input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = String.(three_mm["failed_gate_names"]),
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("optimized_discrete_coil_count", 48;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("refined_normalized_bn_rms_from_discrete_coils",
            refined["bn_total_rms_normalized_by_area_mean_B"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("refined_source_relative_bn_improvement",
            comparison["refined_bn_relative_improvement_from_refined_source"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("refined_minimum_coil_coil_distance",
            refined["minimum_coil_coil_distance_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("refined_minimum_plasma_coil_distance",
            refined["minimum_plasma_coil_distance_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("refined_maximum_sampled_curvature",
            refined["maximum_sampled_abs_curvature_per_m"]; unit = "1/m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("refined_maximum_sampled_torsion",
            refined["maximum_sampled_abs_torsion_per_m"]; unit = "1/m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("refined_maximum_individual_coil_length",
            refined["maximum_unique_coil_length_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("refined_total_physical_coil_length",
            refined["total_physical_coil_length_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_optimized_coil_metric("one_mm_maximum_relative_bn_degradation",
            one_mm["maximum_relative_bn_degradation"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
    ]
    for (id, message) in (
            ("statistical_manufacturing_tolerance_established",
                "four deterministic samples do not establish a manufacturing distribution"),
            ("finite_build_coils_feasible",
                "zero-thickness line currents have no conductor pack or structural model"),
            ("device_complexity_index",
                "coil count and centre-line length do not close device complexity"),
            ("engineering_feasible",
                "integrated engineering was not evaluated"))
        push!(metrics, _desc_optimized_coil_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), residuals = residuals))
    end
    return EvaluationBundle("stellarator_discrete_coil_optimization_desc_v1",
        genome.design_id, genome.family, 1, :pass, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCDiscreteCoilOptimizationV1,
        genome::Genome; kwargs...)
    return _desc_discrete_coil_optimization_bundle_from_files(adapter, genome)
end
