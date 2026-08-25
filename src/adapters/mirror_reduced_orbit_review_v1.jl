"""
Reduced fidelity-1 admission audit for a magnetic-mirror candidate that already
passed the common five-gate screen.

The model follows the single-particle magnetic-moment Hamiltonian in an
explicit smooth axial B(z) profile.  It is intentionally conservative: declared
electrostatic plugs are not credited, and no collision operator is invented.
"""
struct MirrorReducedOrbitReviewV1 <: AbstractEvaluator
    coarse_particles::Int
    refined_particles::Int

    function MirrorReducedOrbitReviewV1(; coarse_particles::Integer = 2048,
            refined_particles::Integer = 8192)
        coarse_particles >= 256 || throw(ArgumentError(
            "coarse particle count must be at least 256"))
        refined_particles >= 2 * coarse_particles || throw(ArgumentError(
            "refined particle count must be at least twice the coarse count"))
        return new(Int(coarse_particles), Int(refined_particles))
    end
end

const _MIRROR_REDUCED_ORBIT_SOURCE_BASIS = String[
    "mirror_wham_physics_basis_2023",
    "mirror_beam_2024",
    "mirror_ryutov_mhd_2011",
]

const _MIRROR_REDUCED_ORBIT_CLAIM_BOUNDARY =
    "Fidelity-1 reduced single-particle admission audit in a declared smooth axial mirror field. It resolves the magnetic loss cone, a bounce-time sample, ensemble convergence, and guiding-center scale separation only. It does not solve anisotropic finite-beta equilibrium, electrostatic plug formation, Fokker-Planck end loss, micro/MHD stability, radial transport, finite-build coils, support stress, exhaust recovery, or reactor power balance. A passing bundle means only that this bounded numerical task completed without rejection; the candidate remains provisional."

function evaluator_spec(::MirrorReducedOrbitReviewV1)
    return EvaluatorSpec(
        "mirror_reduced_orbit_review_v1",
        "1.0.0",
        ["magnetic_mirror"],
        1,
        Dict(
            "field_line_and_particle_following" => :proxy,
            "magnetic_loss_cone" => :full,
            "fast_ion_adiabaticity" => :proxy,
        ),
        "physics_proxy",
    )
end

function _mirror_reduced_core(genome::Genome)
    matches = filter(region -> region.kind == "mirror_central_cell",
        genome.plasma_regions)
    length(matches) == 1 || return nothing
    return only(matches)
end

function _mirror_reduced_parameter(item, name::String, unit::String)
    quantity = get(item.parameters, name, nothing)
    quantity === nothing && throw(ArgumentError("$(item.id) is missing $name"))
    quantity.unit == unit || throw(ArgumentError(
        "$(item.id).$name must use $unit, got $(quantity.unit)"))
    return quantity.value
end

function evaluator_applicability(evaluator::MirrorReducedOrbitReviewV1,
        genome::Genome)
    genome.family == "magnetic_mirror" || return false,
        "mirror_reduced_orbit_review_v1 applies only to magnetic_mirror"
    genome.topology.field_line_class == "open_mirror" || return false,
        "reduced orbit review requires open_mirror field lines"
    core = _mirror_reduced_core(genome)
    core === nothing && return false,
        "reduced orbit review requires one explicit mirror_central_cell"
    try
        _mirror_reduced_parameter(core, "central_field", "T") > 0 || return false,
            "central field must be positive"
        _mirror_reduced_parameter(core, "cell_length", "m") > 0 || return false,
            "cell length must be positive"
        _mirror_reduced_parameter(core, "mirror_ratio_gene", "1") >= 2 || return false,
            "mirror ratio must be at least two"
    catch error
        return false, sprint(showerror, error)
    end
    horizontal = _unified_screen_result(UnifiedCrossFamilyScreenV1(), genome)
    horizontal["all_five_gates_passed"] === true || return false,
        "horizontal five-gate screen must pass before fidelity-1 admission"
    return true,
        "five-gate magnetic-mirror survivor with explicit synchronized axial parameters"
end

function _loss_cone_scan(mirror_ratio::Float64, particle_count::Int)
    lost = 0
    for index in 1:particle_count
        # |cos(pitch)| is uniform on [0,1] for an isotropic velocity sphere.
        parallel_fraction = (index - 0.5) / particle_count
        perpendicular_energy_fraction = 1.0 - parallel_fraction^2
        reaches_end = 1.0 - perpendicular_energy_fraction * mirror_ratio > 0.0
        lost += reaches_end
    end
    numerical_loss = lost / particle_count
    analytic_loss = 1.0 - sqrt(1.0 - 1.0 / mirror_ratio)
    return Dict{String,Any}(
        "particle_count" => particle_count,
        "lost_count" => lost,
        "prompt_loss_fraction" => numerical_loss,
        "analytic_isotropic_loss_cone_fraction" => analytic_loss,
        "analytic_absolute_error" => abs(numerical_loss - analytic_loss),
    )
end

function _smooth_mirror_field_T(z_m::Float64, central_field_T::Float64,
        mirror_ratio::Float64, cell_length_m::Float64)
    return central_field_T * (1.0 + (mirror_ratio - 1.0) *
        sinpi(z_m / cell_length_m)^2)
end

function _mirror_max_log_gradient(central_field_T::Float64,
        mirror_ratio::Float64, cell_length_m::Float64; points::Int = 4097)
    maximum_gradient = 0.0
    for index in 0:(points - 1)
        z = 0.5 * cell_length_m * index / (points - 1)
        phase = 2.0 * pi * z / cell_length_m
        field = _smooth_mirror_field_T(z, central_field_T, mirror_ratio,
            cell_length_m)
        derivative = central_field_T * (mirror_ratio - 1.0) * pi /
            cell_length_m * sin(phase)
        maximum_gradient = max(maximum_gradient, abs(derivative / field))
    end
    return maximum_gradient
end

function _representative_bounce_time_s(mirror_ratio::Float64,
        cell_length_m::Float64, speed_m_s::Float64; quadrature_points::Int = 4096)
    trapped_boundary = sqrt(1.0 - 1.0 / mirror_ratio)
    parallel_fraction = 0.5 * trapped_boundary
    perpendicular_fraction = 1.0 - parallel_fraction^2
    turning_ratio = 1.0 / perpendicular_fraction
    argument = clamp((turning_ratio - 1.0) / (mirror_ratio - 1.0), 0.0, 1.0)
    turning_z = cell_length_m / pi * asin(sqrt(argument))
    dz = turning_z / quadrature_points
    quarter_bounce = 0.0
    for index in 1:quadrature_points
        z = (index - 0.5) * dz
        normalized_field = 1.0 + (mirror_ratio - 1.0) *
            sinpi(z / cell_length_m)^2
        parallel_speed = speed_m_s * sqrt(max(1.0 -
            perpendicular_fraction * normalized_field, eps(Float64)))
        quarter_bounce += dz / parallel_speed
    end
    return 4.0 * quarter_bounce
end

function _mirror_reduced_metric(id::String, value; unit::String = "1",
        status::Symbol = :pass, input_hash::String, run_hash::String,
        warnings::Vector{String}, constraints::Vector{String} = String[],
        residuals::Dict{String,Float64} = Dict{String,Float64}(),
        uncertainty::Union{Nothing,Float64} = nothing,
        wall_time_s::Float64 = 0.0)
    return MetricResult(id, value;
        unit = unit,
        uncertainty = uncertainty,
        fidelity = 1,
        applicability = "Reduced magnetic-moment orbit audit in a smooth axial B(z) profile for a five-gate mirror survivor.",
        status = status,
        constraints_checked = constraints,
        solver_name = "mirror_reduced_orbit_review_v1",
        solver_version = "1.0.0",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = _MIRROR_REDUCED_ORBIT_SOURCE_BASIS,
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time_s)
end

function run_evaluator(evaluator::MirrorReducedOrbitReviewV1, genome::Genome; kwargs...)
    started_ns = time_ns()
    core = only(filter(region -> region.kind == "mirror_central_cell",
        genome.plasma_regions))
    central_field_T = _mirror_reduced_parameter(core, "central_field", "T")
    mirror_ratio = _mirror_reduced_parameter(core, "mirror_ratio_gene", "1")
    cell_length_m = _mirror_reduced_parameter(core, "cell_length", "m")
    temperature_J = _screen_target(genome, "screen_temperature",
        15.0 * 1.602176634e-16, "J")

    coarse = _loss_cone_scan(mirror_ratio, evaluator.coarse_particles)
    refined = _loss_cone_scan(mirror_ratio, evaluator.refined_particles)
    ensemble_change = abs(refined["prompt_loss_fraction"] -
        coarse["prompt_loss_fraction"])
    analytic_error = refined["analytic_absolute_error"]

    mean_dt_ion_mass_kg = 2.5 * 1.66053906660e-27
    elementary_charge_C = 1.602176634e-19
    thermal_speed_m_s = sqrt(2.0 * temperature_J / mean_dt_ion_mass_kg)
    rms_perpendicular_speed_m_s = thermal_speed_m_s * sqrt(2.0 / 3.0)
    thermal_gyroradius_m = mean_dt_ion_mass_kg * rms_perpendicular_speed_m_s /
        (elementary_charge_C * central_field_T)
    maximum_log_gradient_m_inv = _mirror_max_log_gradient(central_field_T,
        mirror_ratio, cell_length_m)
    guiding_center_ratio = thermal_gyroradius_m * maximum_log_gradient_m_inv
    bounce_time_s = _representative_bounce_time_s(mirror_ratio, cell_length_m,
        thermal_speed_m_s)

    convergence_ok = ensemble_change <= 5.0e-4 && analytic_error <= 5.0e-4
    prompt_loss_ok = refined["prompt_loss_fraction"] <= 0.25
    adiabaticity_ok = guiding_center_ratio <= 0.10
    numerical_admission_ok = convergence_ok && prompt_loss_ok && adiabaticity_ok
    disposition = numerical_admission_ok ?
        "provisional_advance_with_blocking_unknowns" :
        "rejected_by_reduced_mid_fidelity"
    summary = Dict{String,Any}(
        "model" => "smooth_axial_mirror_magnetic_moment_hamiltonian_v1",
        "central_field_T" => central_field_T,
        "mirror_ratio" => mirror_ratio,
        "cell_length_m" => cell_length_m,
        "temperature_J" => temperature_J,
        "coarse" => coarse,
        "refined" => refined,
        "ensemble_change" => ensemble_change,
        "thermal_gyroradius_m" => thermal_gyroradius_m,
        "maximum_log_field_gradient_m_inv" => maximum_log_gradient_m_inv,
        "guiding_center_ratio" => guiding_center_ratio,
        "representative_bounce_time_s" => bounce_time_s,
        "numerical_admission_ok" => numerical_admission_ok,
        "disposition" => disposition,
    )
    run_hash = canonical_hash(Dict(
        "evaluator" => "mirror_reduced_orbit_review_v1",
        "version" => "1.0.0",
        "input_hash" => genome.physics_hash,
        "coarse_particles" => evaluator.coarse_particles,
        "refined_particles" => evaluator.refined_particles,
        "summary" => summary,
    ))
    elapsed = (time_ns() - started_ns) / 1.0e9
    warnings = String[
        _MIRROR_REDUCED_ORBIT_CLAIM_BOUNDARY,
        "The magnetic-only loss cone is evaluated without credit for the candidate's declared tandem electrostatic plugs.",
        "The smooth B(z) profile is a parameterized realization, not a field reconstructed from finite-build coils.",
    ]
    residuals = Dict{String,Float64}(
        "ensemble_prompt_loss_change" => ensemble_change,
        "analytic_loss_cone_absolute_error" => analytic_error,
    )
    pass_or_fail(value) = value ? :pass : :fail
    metrics = MetricResult[
        _mirror_reduced_metric("magnetic_only_prompt_loss_fraction",
            refined["prompt_loss_fraction"]; status = pass_or_fail(prompt_loss_ok),
            input_hash = genome.physics_hash, run_hash = run_hash, warnings = warnings,
            constraints = ["isotropic magnetic-only prompt loss fraction <= 0.25"],
            residuals = residuals,
            uncertainty = max(ensemble_change, analytic_error),
            wall_time_s = elapsed),
        _mirror_reduced_metric("analytic_loss_cone_fraction",
            refined["analytic_isotropic_loss_cone_fraction"];
            input_hash = genome.physics_hash, run_hash = run_hash, warnings = warnings,
            residuals = residuals, wall_time_s = elapsed),
        _mirror_reduced_metric("orbit_ensemble_resolution_audit_passed",
            convergence_ok; status = pass_or_fail(convergence_ok),
            input_hash = genome.physics_hash, run_hash = run_hash, warnings = warnings,
            constraints = ["coarse/refined change <= 5e-4",
                "refined/analytic error <= 5e-4"], residuals = residuals,
            wall_time_s = elapsed),
        _mirror_reduced_metric("thermal_gyroradius", thermal_gyroradius_m;
            unit = "m", input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, wall_time_s = elapsed),
        _mirror_reduced_metric("guiding_center_scale_ratio", guiding_center_ratio;
            status = pass_or_fail(adiabaticity_ok), input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings,
            constraints = ["rho_i * max(abs(grad(log B))) <= 0.10"],
            wall_time_s = elapsed),
        _mirror_reduced_metric("representative_collisionless_bounce_time",
            bounce_time_s; unit = "s", input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings, wall_time_s = elapsed),
        _mirror_reduced_metric("reduced_mid_fidelity_disposition", disposition;
            status = pass_or_fail(numerical_admission_ok),
            input_hash = genome.physics_hash, run_hash = run_hash, warnings = warnings,
            wall_time_s = elapsed),
    ]
    for (id, message) in (
            ("anisotropic_finite_beta_equilibrium_feasible",
                "anisotropic finite-beta equilibrium was not solved"),
            ("electrostatic_plug_potential_self_consistent",
                "plug potential was not solved and contributed no confinement credit"),
            ("fokker_planck_end_loss_feasible",
                "collisional refill of the loss cone was not calculated"),
            ("minimum_b_transverse_well_feasible",
                "the genome lacks finite-build transverse minimum-B geometry"),
            ("interchange_and_microstability_feasible",
                "interchange, DCLC, AIC, and microstability were not solved"),
            ("reduced_support_stress_feasible",
                "finite-build coil forces and support stress were not solved"),
            ("exhaust_recovery_power_balance_feasible",
                "end-loss recovery and recirculating power were not solved"),
            ("robust_geometry_error_feasible",
                "finite-build geometry and alignment perturbations were not available"))
        push!(metrics, _mirror_reduced_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings, [message]), wall_time_s = elapsed))
    end
    bundle_status = numerical_admission_ok ? :pass : :fail
    return EvaluationBundle("mirror_reduced_orbit_review_v1", genome.design_id,
        genome.family, 1, bundle_status, metrics, warnings, genome.physics_hash,
        run_hash, "physics_proxy")
end
