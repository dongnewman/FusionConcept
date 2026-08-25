struct StellaratorDESCSurfaceCurrentV1 <: AbstractEvaluator
    python_path::String
    runner_path::String

    function StellaratorDESCSurfaceCurrentV1(
            python_path::AbstractString = get(ENV, "FUSION_CONCEPT_DESC_PYTHON",
                normpath(joinpath(@__DIR__, "..", "..", ".venv-desc", "Scripts",
                    "python.exe"))),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_stellarator_surface_current_runner.py")))
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        isfile(python) || throw(ArgumentError(
            "DESC Python not found at $python; run scripts/setup_desc_windows_fixed_boundary.ps1"))
        isfile(runner) || throw(ArgumentError(
            "DESC surface-current runner not found at $runner"))
        return new(python, runner)
    end
end

const _DESC_SURFACE_CURRENT_RUNNER_VERSION =
    "desc_stellarator_surface_current_regcoil_runner_v1"
const _DESC_SURFACE_CURRENT_CLAIM_BOUNDARY =
    "Finite-beta continuous modular surface-current inverse-design proxy on one declared constant-offset winding surface; not discrete coils, coil topology optimization, structural or superconducting feasibility, blanket or port access, maintainability, full engineering feasibility, or device superiority."

function evaluator_spec(::StellaratorDESCSurfaceCurrentV1)
    return EvaluatorSpec(
        "stellarator_surface_current_regcoil_desc_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "explicit_fourier_boundary" => :full,
            "finite_beta_equilibrium" => :full,
            "constant_offset_winding_surface" => :full,
            "continuous_surface_current_inverse_design" => :full,
            "finite_build_coils" => :proxy,
        ),
        "physics_concept",
    )
end

function _desc_surface_current_settings()
    return Dict{String,Any}(
        "winding_surface" => Dict{String,Any}(
            "offset_m" => 0.25,
            "fit_m" => 4,
            "fit_n" => 4,
            "fit_grid_m" => 12,
            "fit_grid_n" => 12,
            "audit_grid_m" => 16,
            "audit_grid_n" => 16,
            "distance_grid_m" => 24,
            "distance_grid_n" => 24,
        ),
        "surface_current" => Dict{String,Any}(
            "current_helicity" => [1, 0],
            "symmetry" => "sin",
            "regularization_type" => "regcoil",
            "phi_m" => 6,
            "phi_n" => 6,
            "eval_grid_m" => 10,
            "eval_grid_n" => 10,
            "source_grid_m" => 12,
            "source_grid_n" => 12,
            "virtual_casing_grid_m" => 8,
            "virtual_casing_grid_n" => 8,
            "chunk_size" => 20,
            "lambda_regularization" => [0.0, 1.0e-20, 1.0e-19,
                1.0e-18, 1.0e-17, 1.0e-16, 1.0e-15, 1.0e-14,
                1.0e-13, 1.0e-12, 1.0e-11, 1.0e-10],
        ),
        "audit" => Dict{String,Any}(
            "maximum_surface_fit_error_m" => 1.0e-3,
            "maximum_offset_root_residual_m" => 1.0e-5,
            "minimum_surface_area_element_m2" => 1.0e-4,
            "minimum_sampled_surface_separation_m" => 0.15,
            "maximum_integral_relative_closure" => 1.0e-10,
            "monotonic_relative_tolerance" => 1.0e-6,
            "reference_normalized_bn_rms" => 0.01,
        ),
    )
end

function _desc_surface_current_input(genome::Genome)
    settings = _desc_surface_current_settings()
    return Dict{String,Any}(
        "runner_version" => _DESC_SURFACE_CURRENT_RUNNER_VERSION,
        "source_binding" => "DESC-0.17.3",
        "claim_boundary" => _DESC_SURFACE_CURRENT_CLAIM_BOUNDARY,
        "physics_hash" => genome.physics_hash,
        "equilibrium_solver_input" => _desc_stability_equilibrium_input(genome),
        "winding_surface" => settings["winding_surface"],
        "surface_current" => settings["surface_current"],
        "audit" => settings["audit"],
    )
end

function evaluator_applicability(evaluator::StellaratorDESCSurfaceCurrentV1,
        genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "explicit bounded stellarator-symmetric Fourier boundary with finite-beta surface-current inverse design" :
        "stellarator_surface_current_regcoil_desc_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_surface_current_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}(), wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 finite-beta REGCOIL-like continuous modular surface current on a declared 0.25 m constant-offset winding surface.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_surface_current_regcoil_desc_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3", "landreman_regcoil_2017",
            "desc_regcoil_tutorial_0_17_3"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time)
end

function _desc_surface_current_bundle_from_raw(
        adapter::StellaratorDESCSurfaceCurrentV1, genome::Genome,
        input::Dict{String,Any}, raw::Dict{String,Any}; wall_time_s::Real = 0.0)
    get(raw, "status", "error") == "pass" || error(
        "DESC surface-current runner failed: $(get(raw, "message", "unknown error"))")
    raw["runner_version"] == _DESC_SURFACE_CURRENT_RUNNER_VERSION || error(
        "DESC surface-current runner version mismatch")
    raw["claim_boundary"] == _DESC_SURFACE_CURRENT_CLAIM_BOUNDARY || error(
        "DESC surface-current claim boundary mismatch")
    raw["physics_hash"] == genome.physics_hash || error(
        "DESC surface-current result is detached from its genome")
    raw["equilibrium"]["accepted"] === true || error(
        "DESC surface-current equilibrium did not pass its declared gates")
    proxy = raw["proxy_status"]
    proxy["continuous_surface_current_computation_completed"] === true || error(
        "continuous surface-current calculation did not complete")
    proxy["discrete_coils_created"] === false || error(
        "surface-current runner crossed its discrete-coil claim boundary")
    proxy["engineering_feasibility_established"] === false || error(
        "surface-current runner crossed its engineering claim boundary")
    raw["surface_current"]["vacuum_approximation_used"] === false || error(
        "finite-beta surface-current runner unexpectedly used a vacuum approximation")
    length(raw["surface_current"]["scan"]) ==
        length(input["surface_current"]["lambda_regularization"]) || error(
        "surface-current regularization scan length mismatch")

    runner_source_hash = bytes2hex(sha256(read(adapter.runner_path)))
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "surface_current_input" => input,
        "runner_result_hash" => raw["result_hash"],
        "runner_source_hash" => runner_source_hash,
        "evaluator" => "stellarator_surface_current_regcoil_desc_v1",
        "version" => "1.0.0",
    ))
    winding = raw["winding_surface"]
    surface_current = raw["surface_current"]
    scan = surface_current["scan"]
    compromise_index = Int(
        surface_current["normalized_log_objective_utopia_compromise_index"]) + 1
    compromise = scan[compromise_index]
    reference_index_raw = surface_current["minimum_current_index_meeting_reference"]
    reference_point = reference_index_raw === nothing ? nothing :
        scan[Int(reference_index_raw) + 1]
    minimum_bn = minimum(Float64(
        item["bn_rms_normalized_by_area_mean_B"]) for item in scan)
    residuals = Dict{String,Float64}(
        "force_normalized_to_magnetic_gradient" => Float64(
            raw["equilibrium"]["after"]["force_normalized_to_magnetic_gradient"]),
        "maximum_surface_fit_error_m" => Float64(
            winding["maximum_surface_fit_error_m"]),
        "maximum_offset_root_residual_m" => Float64(
            winding["maximum_offset_root_residual_m"]),
        "maximum_integral_relative_closure" => Float64(
            surface_current["maximum_integral_relative_closure"]),
    )
    warnings_out = String[
        "This is a continuous sheet-current inverse-design proxy, not a discrete coil set.",
        "The one-percent normalized Bn value is a comparison reference, not an engineering acceptance gate.",
        "The normalized-log utopia point is a deterministic reporting compromise, not a physics optimum or device ranking.",
        "No coil curvature, length, coil-coil distance, stress, superconducting margin, access, blanket, maintenance, or tolerance model was run.",
        "Surface-current spectral complexity is not full device complexity.",
    ]
    append!(warnings_out, String.(raw["warnings"]))
    unique!(warnings_out)
    constraints = ["finite-beta equilibrium gates",
        "constant-offset winding-surface gates", "REGCOIL integral closure",
        "regularization tradeoff monotonicity"]
    metrics = MetricResult[
        _desc_surface_current_metric(
            "continuous_surface_current_computation_completed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out,
            residuals = residuals, wall_time = wall_time_s),
        _desc_surface_current_metric(
            "constant_offset_winding_surface_gates_passed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["surface fit", "offset root residual",
                "positive area element", "sampled plasma-winding separation"],
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric(
            "minimum_sampled_plasma_winding_surface_separation",
            winding["minimum_sampled_surface_separation_m"];
            unit = "m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric(
            "minimum_continuous_surface_current_bn_rms_normalized", minimum_bn;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric(
            "surface_current_reference_normalized_bn_rms_met",
            surface_current["reference_normalized_bn_rms_met"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["RMS Bn / area-mean |B| <= documented reference"],
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric(
            "minimum_surface_current_k_rms_meeting_bn_reference",
            reference_point === nothing ? nothing : reference_point["k_rms_A_per_m"];
            unit = "A/m", status = reference_point === nothing ? :unknown : :pass,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric(
            "surface_current_compromise_bn_rms_normalized",
            compromise["bn_rms_normalized_by_area_mean_B"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric(
            "surface_current_compromise_k_rms", compromise["k_rms_A_per_m"];
            unit = "A/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric(
            "surface_current_compromise_k_max", compromise["k_max_A_per_m"];
            unit = "A/m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric(
            "surface_current_compromise_phi_spectral_complexity",
            compromise["phi_spectral_complexity"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_surface_current_metric("surface_current_regularization_scan_count",
            length(scan); input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
    ]
    for (id, message) in (
            ("surface_current_resolution_converged",
                "a separate base-to-refined audit is required"),
            ("finite_build_coils_feasible",
                "continuous sheet current was not cut into discrete coils"),
            ("discrete_coil_geometry_feasible",
                "coil curvature, length, separation, topology, and tolerances were not evaluated"),
            ("device_complexity_index",
                "surface-current spectral complexity is not full device complexity"),
            ("engineering_feasible",
                "structural, superconducting, blanket, port, maintenance, and systems engineering were not evaluated"))
        push!(metrics, _desc_surface_current_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), residuals = residuals,
            wall_time = wall_time_s))
    end
    return EvaluationBundle("stellarator_surface_current_regcoil_desc_v1",
        genome.design_id, genome.family, 1, :pass, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCSurfaceCurrentV1,
        genome::Genome; kwargs...)
    input = _desc_surface_current_input(genome)
    raw = Dict{String,Any}()
    elapsed = @elapsed raw = mktemp() do input_path, input_io
        JSON3.pretty(input_io, input)
        write(input_io, '\n')
        close(input_io)
        return mktemp() do output_path, output_io
            close(output_io)
            command = `$(adapter.python_path) $(adapter.runner_path) --input $(input_path) --output $(output_path)`
            run(command)
            return _plain_json(JSON3.read(read(output_path, String),
                Dict{String,Any}))
        end
    end
    return _desc_surface_current_bundle_from_raw(adapter, genome, input, raw;
        wall_time_s = elapsed)
end
