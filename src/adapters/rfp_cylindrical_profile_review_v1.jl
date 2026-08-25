"""
Fidelity-1 reduced cylindrical current-profile admission audit for an RFP
candidate that already passed the v7 horizontal five-gate screen.

The Python backend integrates the force-free alpha-Theta0 profile equations at
two numerical resolutions.  This evaluator deliberately stops before 3D
helical equilibrium and nonlinear resistive-MHD dynamics.
"""
struct RFPCylindricalProfileReviewV1 <: AbstractEvaluator
    python_path::String
    runner_path::String

    function RFPCylindricalProfileReviewV1(
            python_path::AbstractString = get(ENV,
                "FUSION_CONCEPT_RFP_PROFILE_PYTHON",
                something(Sys.which("python"), "")),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..",
                "..", "scripts", "rfp_cylindrical_profile_runner.py")))
        isempty(python_path) && throw(ArgumentError(
            "Python was not found; set FUSION_CONCEPT_RFP_PROFILE_PYTHON"))
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        isfile(python) || throw(ArgumentError("Python not found at $python"))
        isfile(runner) || throw(ArgumentError(
            "RFP cylindrical profile runner not found at $runner"))
        return new(python, runner)
    end
end

const _RFP_PROFILE_REVIEW_SOURCE_BASIS = String[
    "rfp_sheq_martines_2011",
    "rfp_mpfm_shen_sprott_1991",
    "mrxmhd_spec_hudson_2012",
    "nimrod_sovinec_2004",
    "rfp_ppcd_sarff_1997",
    "rfp_sha_lorenzini_2008",
]

const _RFP_PROFILE_REVIEW_CLAIM_BOUNDARY =
    "Fidelity-1 reduced cylindrical force-free current-profile reconstruction " *
    "for a v7 RFP survivor. It tests numerical convergence, F/Theta boundary " *
    "reconstruction, and analytic on-axis regularity only. It does not run " *
    "SHEq, SPEC, or NIMROD and does not establish a 3D helical equilibrium, " *
    "Ohmic consistency, nonlinear resistive-MHD stability, PPCD sustainment, " *
    "reactor-scale transport, or reactor feasibility."

function evaluator_spec(::RFPCylindricalProfileReviewV1)
    return EvaluatorSpec(
        "rfp_cylindrical_profile_review_v1",
        "1.0.0",
        ["reversed_field_pinch"],
        1,
        Dict(
            "rfp_current_profile_and_sustainment" => :proxy,
            "resistive_mhd_rfp" => :proxy,
            "rfp_mode_spectrum" => :proxy,
        ),
        "physics_proxy",
    )
end

function _rfp_profile_contract(genome::Genome)
    radial = _so_target(genome, "screen_outer_radial_extent", NaN, "m")
    axial = _so_target(genome, "screen_outer_axial_half_extent", NaN, "m")
    field = _so_target(genome, "screen_plasma_field", NaN, "T")
    matches = filter(shared_outer_envelope_contracts_v1()) do contract
        isapprox(radial, contract.outer_radial_extent_m; rtol = 1e-12,
            atol = 1e-12) &&
        isapprox(axial, contract.outer_axial_half_extent_m; rtol = 1e-12,
            atol = 1e-12) &&
        isapprox(field, contract.plasma_field_T; rtol = 1e-12,
            atol = 1e-12)
    end
    return length(matches) == 1 ? only(matches) : nothing
end

function evaluator_applicability(::RFPCylindricalProfileReviewV1,
        genome::Genome)
    genome.family == "reversed_field_pinch" || return false,
        "rfp_cylindrical_profile_review_v1 applies only to reversed_field_pinch"
    haskey(genome.mission.targets, "screen_reversal_parameter") || return false,
        "candidate is missing screen_reversal_parameter"
    haskey(genome.mission.targets, "screen_pinch_parameter") || return false,
        "candidate is missing screen_pinch_parameter"
    contract = _rfp_profile_contract(genome)
    contract === nothing && return false,
        "candidate is not bound to exactly one sealed outer-envelope contract"
    horizontal = _self_organized_result(SelfOrganizedScreenV1(contract), genome)
    horizontal["all_five_gates_passed"] === true || return false,
        "v7 horizontal five-gate screen must pass before profile review"
    return true,
        "five-gate RFP survivor with explicit F, Theta, PPCD, and boundary-control ledgers"
end

function _run_rfp_profile_backend(adapter::RFPCylindricalProfileReviewV1,
        genome::Genome)
    input = Dict{String,Any}(
        "target_F" => _so_target(genome, "screen_reversal_parameter", NaN, "1"),
        "target_Theta" => _so_target(genome, "screen_pinch_parameter", NaN, "1"),
    )
    elapsed = @elapsed raw = mktemp() do input_path, input_io
        JSON3.pretty(input_io, input)
        write(input_io, '\n')
        close(input_io)
        return mktemp() do output_path, output_io
            close(output_io)
            command = `$(adapter.python_path) -B $(adapter.runner_path) --input $(input_path) --output $(output_path)`
            run(pipeline(command, stdout = devnull))
            return _plain_json(JSON3.read(read(output_path, String),
                Dict{String,Any}))
        end
    end
    raw["runner"] == "rfp_cylindrical_profile_runner" || error(
        "unexpected RFP profile runner identity")
    raw["runner_version"] == "1.0.0" || error(
        "unexpected RFP profile runner version")
    return input, raw, elapsed
end

function _rfp_profile_metric(id::String, value; unit::String = "1",
        status::Symbol = :pass, input_hash::String, run_hash::String,
        warnings::Vector{String}, constraints::Vector{String} = String[],
        residuals::Dict{String,Float64} = Dict{String,Float64}(),
        uncertainty::Union{Nothing,Float64} = nothing,
        wall_time_s::Float64 = 0.0)
    return MetricResult(id, value;
        unit = unit,
        uncertainty = uncertainty,
        fidelity = 1,
        applicability = "Reduced alpha-Theta0 cylindrical profile review for a complete v7 RFP five-gate survivor.",
        status = status,
        constraints_checked = constraints,
        solver_name = "rfp_cylindrical_profile_review_v1",
        solver_version = "1.0.0",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = _RFP_PROFILE_REVIEW_SOURCE_BASIS,
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time_s)
end

function run_evaluator(adapter::RFPCylindricalProfileReviewV1,
        genome::Genome; kwargs...)
    input, raw, elapsed = _run_rfp_profile_backend(adapter, genome)
    backend_hash = String(raw["result_hash"])
    run_hash = canonical_hash(Dict(
        "evaluator" => "rfp_cylindrical_profile_review_v1",
        "version" => "1.0.0",
        "input_hash" => genome.physics_hash,
        "backend_result_hash" => backend_hash,
        "runner_sha256" => bytes2hex(sha256(read(adapter.runner_path))),
    ))
    unconstrained = raw["unconstrained"]["fine"]
    regular = raw["axis_regular"]["fine"]
    convergence = raw["convergence"]
    taylor = raw["taylor_constant_alpha"]
    gates = raw["gates"]
    admitted = gates["profile_admission"] === true
    pass_or_fail(value) = value ? :pass : :fail
    residuals = Dict{String,Float64}(
        "unconstrained_F_residual" => Float64(unconstrained["residual_F"]),
        "unconstrained_Theta_residual" =>
            Float64(unconstrained["residual_Theta"]),
        "axis_regular_F_residual" => Float64(regular["residual_F"]),
        "axis_regular_Theta_residual" => Float64(regular["residual_Theta"]),
        "axis_regular_residual_norm" => Float64(regular["residual_norm"]),
    )
    warnings = String[
        _RFP_PROFILE_REVIEW_CLAIM_BOUNDARY,
        "The 1e-3 axis-regular F/Theta residual gate is a declared screening tolerance, not a universal physical threshold.",
        "The unconstrained optimum has alpha < 1, so d(sigma)/dr scales as r^(alpha-1) and is singular at the magnetic axis.",
        "The v7 survivor operates far beyond the current and beta range used to motivate the experimental reconstruction model.",
    ]
    metrics = MetricResult[
        _rfp_profile_metric("rfp_profile_numerical_convergence_passed",
            gates["numerical_convergence"];
            status = pass_or_fail(gates["numerical_convergence"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings,
            constraints = ["coarse/fine fit changes remain within declared tolerances"],
            residuals = residuals, wall_time_s = elapsed),
        _rfp_profile_metric("rfp_unconstrained_profile_theta0",
            unconstrained["theta0"]; input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings, residuals = residuals,
            wall_time_s = elapsed),
        _rfp_profile_metric("rfp_unconstrained_profile_alpha",
            unconstrained["alpha"]; status = :fail,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings,
            constraints = ["alpha > 1 for a vanishing on-axis radial derivative"],
            residuals = residuals, wall_time_s = elapsed),
        _rfp_profile_metric("rfp_unconstrained_boundary_residual_norm",
            unconstrained["residual_norm"];
            status = pass_or_fail(gates[
                "unconstrained_boundary_reconstruction"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, constraints = ["F/Theta residual norm <= 1e-5"],
            residuals = residuals, wall_time_s = elapsed),
        _rfp_profile_metric("rfp_axis_regular_profile_theta0",
            regular["theta0"]; input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings, residuals = residuals,
            wall_time_s = elapsed),
        _rfp_profile_metric("rfp_axis_regular_profile_alpha",
            regular["alpha"]; input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings,
            constraints = ["alpha > 1"], residuals = residuals,
            wall_time_s = elapsed),
        _rfp_profile_metric("rfp_axis_regular_boundary_residual_norm",
            regular["residual_norm"];
            status = pass_or_fail(gates["axis_regular_boundary_reconstruction"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings,
            constraints = ["axis-regular F/Theta residual norm <= 1e-3"],
            residuals = residuals, wall_time_s = elapsed),
        _rfp_profile_metric("rfp_taylor_constant_alpha_predicted_F",
            taylor["predicted_F"]; input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings, residuals = residuals,
            wall_time_s = elapsed),
        _rfp_profile_metric("rfp_taylor_constant_alpha_F_mismatch",
            taylor["absolute_F_mismatch"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, residuals = residuals, wall_time_s = elapsed),
        _rfp_profile_metric("rfp_profile_review_disposition",
            raw["disposition"]; status = pass_or_fail(admitted),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, residuals = residuals, wall_time_s = elapsed),
    ]
    for (id, message) in (
            ("rfp_ohmic_constraint_feasible",
                "Ohm-law and loop-voltage consistency were not solved"),
            ("rfp_helical_equilibrium_feasible",
                "no 3D SHAx/QSH equilibrium solver was run"),
            ("rfp_secondary_tearing_spectrum_feasible",
                "secondary tearing and resistive-wall modes were not evolved"),
            ("rfp_ppcd_repeatable_sustainment_feasible",
                "PPCD repetition, flux consumption, and waveform control were not solved"),
            ("rfp_reactor_scale_transport_feasible",
                "reactor-scale transport remains an unvalidated extrapolation"))
        push!(metrics, _rfp_profile_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings, [message]), residuals = residuals,
            wall_time_s = elapsed))
    end
    return EvaluationBundle("rfp_cylindrical_profile_review_v1",
        genome.design_id, genome.family, 1, admitted ? :pass : :fail, metrics,
        warnings, genome.physics_hash, run_hash, "physics_proxy")
end
