struct StellaratorDESCDiscreteCoilCutV1 <: AbstractEvaluator
    python_path::String
    runner_path::String
    input_path::String
    audit_path::String

    function StellaratorDESCDiscreteCoilCutV1(
            python_path::AbstractString = get(ENV, "FUSION_CONCEPT_DESC_PYTHON",
                normpath(joinpath(@__DIR__, "..", "..", ".venv-desc", "Scripts",
                    "python.exe"))),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_stellarator_discrete_coil_cut_runner.py")),
            input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_discrete_coil_cut_pool16_input.json")),
            audit_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_discrete_coil_cut_pool16_resolution_audit.json")))
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        input = abspath(String(input_path))
        audit = abspath(String(audit_path))
        isfile(python) || throw(ArgumentError("DESC Python not found at $python"))
        isfile(runner) || throw(ArgumentError("DESC discrete-coil runner not found at $runner"))
        isfile(input) || throw(ArgumentError("DESC discrete-coil input not found at $input"))
        isfile(audit) || throw(ArgumentError("DESC discrete-coil audit not found at $audit"))
        return new(python, runner, input, audit)
    end
end

const _DESC_DISCRETE_COIL_CUT_RUNNER_VERSION =
    "desc_stellarator_discrete_coil_cut_runner_v1"
const _DESC_DISCRETE_COIL_CUT_CLAIM_BOUNDARY =
    "Finite modular line-current contours cut from one resolution-audited continuous surface-current solution; not coil-shape optimization, finite conductor build, structural or superconducting feasibility, tolerance robustness, access, blanket, maintenance, integrated engineering, or device superiority."
const _DESC_DISCRETE_COIL_CUT_PHYSICS_HASH =
    "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"

function evaluator_spec(::StellaratorDESCDiscreteCoilCutV1)
    return EvaluatorSpec(
        "stellarator_discrete_coil_cut_desc_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "explicit_fourier_boundary" => :full,
            "finite_beta_equilibrium" => :full,
            "continuous_surface_current_inverse_design" => :full,
            "finite_discrete_coil_contours" => :full,
            "finite_build_coils" => :proxy,
        ),
        "physics_concept",
    )
end

function evaluator_applicability(evaluator::StellaratorDESCDiscreteCoilCutV1,
        genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    genome.physics_hash == _DESC_DISCRETE_COIL_CUT_PHYSICS_HASH || return false,
        "version 1 is bound to the resolution-audited pool-16 surface-current source"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact pool-16 generated Fourier stellarator with audited surface-current source" :
        "stellarator_discrete_coil_cut_desc_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_discrete_coil_cut_input(
        adapter::StellaratorDESCDiscreteCoilCutV1, genome::Genome)
    input = _plain_json(JSON3.read(read(adapter.input_path, String), Dict{String,Any}))
    input["runner_version"] == _DESC_DISCRETE_COIL_CUT_RUNNER_VERSION || error(
        "stored discrete-coil input runner version mismatch")
    input["claim_boundary"] == _DESC_DISCRETE_COIL_CUT_CLAIM_BOUNDARY || error(
        "stored discrete-coil input claim boundary mismatch")
    input["physics_hash"] == genome.physics_hash || error(
        "stored discrete-coil input is detached from genome")
    input["source_resolution_audit"]["all_passed"] === true || error(
        "discrete-coil input lacks a passed surface-current audit")
    return input
end

function _desc_discrete_coil_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}(), wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 unoptimized Fourier-smoothed modular line-current contours cut from the audited pool-16 continuous current potential.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_discrete_coil_cut_desc_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3", "landreman_regcoil_2017",
            "desc_regcoil_tutorial_0_17_3"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time)
end

function _desc_discrete_coil_cut_bundle_from_raw(
        adapter::StellaratorDESCDiscreteCoilCutV1, genome::Genome,
        input::Dict{String,Any}, raw::Dict{String,Any}, audit::Dict{String,Any};
        wall_time_s::Real = 0.0)
    raw["status"] == "pass" || error(
        "DESC discrete-coil runner failed: $(get(raw, "message", "unknown error"))")
    raw["runner_version"] == _DESC_DISCRETE_COIL_CUT_RUNNER_VERSION || error(
        "DESC discrete-coil runner version mismatch")
    raw["claim_boundary"] == _DESC_DISCRETE_COIL_CUT_CLAIM_BOUNDARY || error(
        "DESC discrete-coil claim boundary mismatch")
    raw["physics_hash"] == genome.physics_hash || error(
        "DESC discrete-coil result is detached from genome")
    raw["discrete_coils_created"] === true || error(
        "discrete-coil runner did not create contours")
    raw["coil_shape_optimization_performed"] === false || error(
        "cut-only runner unexpectedly claims shape optimization")
    raw["discrete_coil_geometry_feasibility_established"] === false || error(
        "cut-only runner crossed geometry-feasibility boundary")
    raw["engineering_feasibility_established"] === false || error(
        "cut-only runner crossed engineering boundary")
    audit["audit_version"] ==
        "desc_stellarator_discrete_coil_cut_resolution_audit_v1" || error(
        "discrete-coil resolution audit version mismatch")
    audit["target"]["physics_hash"] == genome.physics_hash || error(
        "discrete-coil audit is detached from genome")
    audit["source_artifacts"]["base_result_hash"] == raw["result_hash"] || error(
        "discrete-coil audit is detached from raw result")
    audit["base"]["input_hash"] == raw["input_hash"] || error(
        "discrete-coil audit and raw result disagree on Python input hash")
    audit["source_artifacts"]["base_input_file_sha256"] ==
        bytes2hex(sha256(read(adapter.input_path))) || error(
        "discrete-coil input file is detached from its resolution audit")
    audit["all_passed"] === false || error(
        "version 1 typed artifact expects the recorded failed resolution audit")
    audit["interpretation"]["discrete_coil_geometry_feasibility_established"] ===
        false || error("audit crossed discrete geometry boundary")

    cuts = raw["cuts"]
    length(cuts) == 3 || error("discrete-coil count scan must have three cuts")
    best = cuts[Int(raw["best_bn_cut_index"]) + 1]
    minimum_bn = minimum(Float64(
        cut["bn_total_rms_normalized_by_area_mean_B"]) for cut in cuts)
    continuous_bn = Float64(raw["surface_current_solution"][
        "continuous_bn_rms_normalized_by_area_mean_B"])
    warnings_out = String[
        "Finite line-current contours were created but not shape-optimized.",
        "No scanned coil count met the one-percent normalized-Bn comparison reference.",
        "The base-to-refined cut audit failed its Bn-drift and curvature-drift gates.",
        "Distance values are sampled line-current references, not finite-build clearances.",
        "No conductor, current-density, stress, superconducting margin, tolerance, access, blanket, maintenance, exhaust, neutronics, or plant model was run.",
    ]
    append!(warnings_out, String.(raw["warnings"]))
    unique!(warnings_out)
    residuals = Dict{String,Float64}(
        "maximum_bn_rms_normalized_absolute_resolution_change" => maximum(
            Float64(item["bn_rms_normalized_absolute_change"])
            for item in audit["comparisons"]),
        "maximum_curvature_relative_resolution_change" => maximum(
            Float64(item["maximum_curvature_relative_change"])
            for item in audit["comparisons"]),
        "maximum_fourier_fit_sampled_hausdorff_m" => maximum(
            Float64(cut["maximum_fourier_fit_sampled_hausdorff_m"])
            for cut in cuts),
        "maximum_current_closure_relative_error" => maximum(
            Float64(cut["current_closure_relative_error"]) for cut in cuts),
    )
    runner_source_hash = bytes2hex(sha256(read(adapter.runner_path)))
    audit_source_hash = bytes2hex(sha256(read(adapter.audit_path)))
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "cut_input" => input,
        "runner_result_hash" => raw["result_hash"],
        "resolution_audit_hash" => audit["audit_hash"],
        "runner_source_hash" => runner_source_hash,
        "audit_file_hash" => audit_source_hash,
        "evaluator" => "stellarator_discrete_coil_cut_desc_v1",
        "version" => "1.0.0",
    ))
    constraints = ["surface-current source resolution audit",
        "contour intersection checks", "Fourier fit gate", "current closure gate"]
    metrics = MetricResult[
        _desc_discrete_coil_metric("discrete_coil_contours_created", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out,
            residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric("coil_shape_optimization_performed", false;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric("unoptimized_discrete_coil_count_scan_count",
            length(cuts); input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric(
            "minimum_unoptimized_discrete_coil_bn_rms_normalized", minimum_bn;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric(
            "continuous_to_discrete_bn_degradation_factor", minimum_bn / continuous_bn;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric(
            "unoptimized_discrete_coil_bn_reference_met_by_any_cut", false;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["one-percent normalized Bn comparison reference"],
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric("best_bn_cut_total_physical_coil_count",
            best["total_physical_coil_count"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric("best_bn_cut_minimum_coil_coil_distance",
            best["minimum_coil_coil_distance_m"];
            unit = "m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric("best_bn_cut_minimum_plasma_coil_distance",
            best["minimum_plasma_coil_distance_m"];
            unit = "m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric("best_bn_cut_maximum_sampled_curvature",
            best["maximum_sampled_curvature_per_m"];
            unit = "1/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric("best_bn_cut_total_physical_coil_length",
            best["total_physical_coil_length_m"];
            unit = "m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_discrete_coil_metric("unoptimized_discrete_coil_resolution_audit_passed",
            false; status = :fail, input_hash = genome.physics_hash,
            run_hash = run_hash, constraints = sort!(collect(keys(audit["gates"]))),
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
    ]
    for (id, message) in (
            ("unoptimized_discrete_coil_resolution_converged",
                "the base-to-refined Bn and curvature gates failed"),
            ("minimum_total_physical_coil_count_meeting_bn_reference",
                "none of the three unoptimized cuts met the comparison reference"),
            ("discrete_coil_geometry_feasible",
                "coil-shape optimization and finite-build geometry were not evaluated"),
            ("finite_build_coils_feasible",
                "line currents have no conductor cross-section or tolerance model"),
            ("device_complexity_index",
                "coil count and length do not constitute full device complexity"),
            ("engineering_feasible",
                "integrated engineering was not evaluated"))
        push!(metrics, _desc_discrete_coil_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), residuals = residuals,
            wall_time = wall_time_s))
    end
    return EvaluationBundle("stellarator_discrete_coil_cut_desc_v1",
        genome.design_id, genome.family, 1, :pass, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCDiscreteCoilCutV1,
        genome::Genome; kwargs...)
    input = _desc_discrete_coil_cut_input(adapter, genome)
    raw = Dict{String,Any}()
    elapsed = @elapsed raw = mktemp() do input_path, input_io
        JSON3.pretty(input_io, input)
        write(input_io, '\n')
        close(input_io)
        return mktemp() do output_path, output_io
            close(output_io)
            command = `$(adapter.python_path) -B $(adapter.runner_path) --input $(input_path) --output $(output_path)`
            run(command)
            return _plain_json(JSON3.read(read(output_path, String),
                Dict{String,Any}))
        end
    end
    audit = _plain_json(JSON3.read(read(adapter.audit_path, String),
        Dict{String,Any}))
    return _desc_discrete_coil_cut_bundle_from_raw(
        adapter, genome, input, raw, audit; wall_time_s = elapsed)
end
