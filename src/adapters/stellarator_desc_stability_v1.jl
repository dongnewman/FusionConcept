struct StellaratorDESCStabilityV1 <: AbstractEvaluator
    python_path::String
    runner_path::String

    function StellaratorDESCStabilityV1(
            python_path::AbstractString = get(ENV, "FUSION_CONCEPT_DESC_PYTHON",
                normpath(joinpath(@__DIR__, "..", "..", ".venv-desc", "Scripts",
                    "python.exe"))),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_stellarator_stability_runner.py")))
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        isfile(python) || throw(ArgumentError(
            "DESC Python not found at $python; run scripts/setup_desc_windows_fixed_boundary.ps1"))
        isfile(runner) || throw(ArgumentError("DESC stability runner not found at $runner"))
        return new(python, runner)
    end
end

const _DESC_STABILITY_RUNNER_VERSION =
    "desc_stellarator_sampled_ideal_mhd_stability_runner_v1"
const _DESC_STABILITY_CLAIM_BOUNDARY =
    "Sampled Mercier and infinite-n ideal-ballooning criteria on a re-solved fixed-boundary equilibrium only; not finite-n, resistive, kinetic, nonlinear, disruption, transport, engineering, all-mode stability, or device superiority."

function evaluator_spec(::StellaratorDESCStabilityV1)
    return EvaluatorSpec(
        "stellarator_sampled_ideal_mhd_stability_desc_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "explicit_fourier_boundary" => :full,
            "finite_beta_equilibrium" => :full,
            "mercier" => :proxy,
            "ballooning" => :proxy,
            "sampled_mercier_criterion" => :full,
            "sampled_infinite_n_ballooning" => :full,
        ),
        "physics_concept",
    )
end

function _desc_stability_equilibrium_input(genome::Genome)
    input = _desc_fourier_inputs(genome)
    # Stability classification may not use the coarse 4/4/3 pilot grid: the
    # recorded NFP=2 audit demonstrated a Mercier sign change at 6/6/4.
    input["resolution"] = Dict{String,Any}(
        "L" => 6,
        "M" => 6,
        "N" => 4,
        "L_grid" => 12,
        "M_grid" => 12,
        "N_grid" => 8,
    )
    input["solver"]["max_iterations"] = 40
    return input
end

function _desc_stability_settings_medium()
    return Dict{String,Any}(
        "mercier" => Dict{String,Any}(
            "rho" => [0.15, 0.25, 0.40, 0.55, 0.70, 0.85, 0.95],
            "angular_m" => 12,
            "angular_n" => 9,
            "minimum_normalized_positive_margin" => 1.0e-5,
        ),
        "ballooning" => Dict{String,Any}(
            "rho" => [0.25, 0.50, 0.75, 0.90],
            "alpha_count" => 8,
            "nturns" => 3,
            "nzetaperturn" => 128,
            "zeta0_count" => 15,
            "maximum_lambda" => -1.0e-5,
            "extraction_shift" => -1.0,
        ),
    )
end

function _desc_stability_input(genome::Genome)
    return Dict{String,Any}(
        "runner_version" => _DESC_STABILITY_RUNNER_VERSION,
        "source_binding" => "DESC-0.17.3",
        "claim_boundary" => _DESC_STABILITY_CLAIM_BOUNDARY,
        "physics_hash" => genome.physics_hash,
        "equilibrium_solver_input" => _desc_stability_equilibrium_input(genome),
        "equilibrium_reference" => nothing,
        "stability" => _desc_stability_settings_medium(),
    )
end

function evaluator_applicability(evaluator::StellaratorDESCStabilityV1,
        genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "explicit bounded stellarator-symmetric Fourier boundary with a medium-resolution stability re-solve" :
        "stellarator_sampled_ideal_mhd_stability_desc_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_stability_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}(), wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 sampled Mercier and infinite-n ideal-ballooning criteria on a medium-resolution explicit-Fourier fixed-boundary equilibrium.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_sampled_ideal_mhd_stability_desc_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3", "landreman_jorge_mercier_2020",
            "gaur_omnigenous_stability_2024"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time)
end

function _desc_stability_bundle_from_raw(adapter::StellaratorDESCStabilityV1,
        genome::Genome, input::Dict{String,Any}, raw::Dict{String,Any};
        wall_time_s::Real = 0.0)
    get(raw, "status", "error") == "pass" || error(
        "DESC stability runner failed: $(get(raw, "message", "unknown error"))")
    raw["runner_version"] == _DESC_STABILITY_RUNNER_VERSION || error(
        "DESC stability runner version mismatch")
    raw["claim_boundary"] == _DESC_STABILITY_CLAIM_BOUNDARY || error(
        "DESC stability claim boundary mismatch")
    raw["physics_hash"] == genome.physics_hash || error(
        "DESC stability result is detached from its genome")
    raw["equilibrium"]["accepted"] === true || error(
        "DESC stability equilibrium did not pass its declared gates")
    raw["local_ideal_mhd"]["all_mode_plasma_stability_established"] === false ||
        error("DESC stability runner exceeded its allowed claim boundary")
    raw["mercier"]["rho"] == input["stability"]["mercier"]["rho"] || error(
        "Mercier scan grid mismatch")
    raw["ballooning"]["rho"] == input["stability"]["ballooning"]["rho"] || error(
        "ballooning scan grid mismatch")

    runner_source_hash = bytes2hex(sha256(read(adapter.runner_path)))
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "stability_input" => input,
        "runner_result_hash" => raw["result_hash"],
        "runner_source_hash" => runner_source_hash,
        "evaluator" => "stellarator_sampled_ideal_mhd_stability_desc_v1",
        "version" => "1.0.0",
    ))
    equilibrium = raw["equilibrium"]
    mercier = raw["mercier"]
    ballooning = raw["ballooning"]
    local_result = raw["local_ideal_mhd"]
    force_residual = Float64(
        equilibrium["after"]["force_normalized_to_magnetic_gradient"])
    sqrt_g = Float64(equilibrium["minimum_sampled_sqrt_g"])
    mercier_closure = Float64(mercier["term_closure_max_abs_wb_minus2"])
    shift_difference = Float64(
        ballooning["shift_extraction_max_abs_difference"])
    residuals = Dict{String,Float64}(
        "force_normalized_to_magnetic_gradient" => force_residual,
        "minimum_sampled_sqrt_g" => sqrt_g,
        "mercier_term_closure_max_abs_wb_minus2" => mercier_closure,
        "ballooning_shift_extraction_max_abs_difference" => shift_difference,
    )
    warnings_out = String[
        "These are finite rho/alpha/field-line scans, not continuous-domain proofs.",
        "The NFP=2 pilot showed a coarse-to-medium Mercier sign change; every promoted candidate still needs an independent medium-to-fine resolution audit.",
        "Favorable sampled Mercier and infinite-n ballooning values do not establish finite-n, resistive, kinetic, nonlinear, disruption, or all-mode stability.",
        "This evaluator does not establish transport, alpha confinement, coil realizability, exhaust, fusion gain, engineering feasibility, simplicity, or device superiority.",
    ]
    append!(warnings_out, String.(raw["warnings"]))
    unique!(warnings_out)
    metrics = MetricResult[
        _desc_stability_metric("sampled_stability_computation_completed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["medium-resolution equilibrium gates",
                "Mercier term closure", "ballooning double-shift extraction"],
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_stability_metric("sampled_stability_equilibrium_converged", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["normalized force residual <= declared threshold",
                "fixed inputs", "nested coordinates", "positive sampled Jacobian"],
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_stability_metric("minimum_sampled_mercier_D_normalized",
            mercier["minimum_D_Mercier_normalized"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_stability_metric("sampled_mercier_favorable",
            mercier["sampled_favorable"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["D_Mercier*Psi^2 >= declared positive margin at every sampled rho"],
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_stability_metric("sampled_mercier_positive_fraction",
            mercier["positive_fraction"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_stability_metric("maximum_sampled_infinite_n_ballooning_lambda",
            ballooning["maximum_lambda"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_stability_metric("sampled_infinite_n_ballooning_favorable",
            ballooning["sampled_favorable"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["maximum lambda <= declared negative margin on the sampled field lines"],
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_stability_metric("sampled_local_ideal_mhd_favorable",
            local_result["sampled_favorable"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["sampled Mercier favorable",
                "sampled infinite-n ballooning favorable"],
            warnings = warnings_out, residuals = residuals,
            wall_time = wall_time_s),
        _desc_stability_metric("mercier_rho_sample_count",
            length(mercier["rho"]);
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_stability_metric("ballooning_field_line_scan_count",
            ballooning["scan_count"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_stability_metric("ballooning_field_line_point_count",
            ballooning["field_line_point_count"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
    ]
    for (id, message) in (
            ("sampled_stability_resolution_converged",
                "a per-candidate medium-to-fine audit was not supplied to this evaluator"),
            ("mercier_stability_feasible",
                "a finite sampled Mercier scan is not a continuum-domain stability proof"),
            ("ballooning_stability_feasible",
                "a finite infinite-n field-line scan is not an all-ballooning-mode proof"),
            ("plasma_stability_feasible",
                "finite-n, resistive, kinetic, nonlinear, and disruption stability were not evaluated"),
            ("minimum_stability_margin",
                "Mercier D and ballooning lambda do not define one common all-mode margin"))
        push!(metrics, _desc_stability_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), residuals = residuals,
            wall_time = wall_time_s))
    end
    return EvaluationBundle("stellarator_sampled_ideal_mhd_stability_desc_v1",
        genome.design_id, genome.family, 1, :pass, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCStabilityV1,
        genome::Genome; kwargs...)
    input = _desc_stability_input(genome)
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
    return _desc_stability_bundle_from_raw(adapter, genome, input, raw;
        wall_time_s = elapsed)
end
