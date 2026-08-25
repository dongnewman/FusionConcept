struct StellaratorDESCFourierV1 <: AbstractEvaluator
    python_path::String
    runner_path::String

    function StellaratorDESCFourierV1(
            python_path::AbstractString = get(ENV, "FUSION_CONCEPT_DESC_PYTHON",
                normpath(joinpath(@__DIR__, "..", "..", ".venv-desc", "Scripts", "python.exe"))),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_fourier_runner.py")))
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        isfile(python) || throw(ArgumentError(
            "DESC Python not found at $python; run scripts/setup_desc_windows_fixed_boundary.ps1"))
        isfile(runner) || throw(ArgumentError("DESC Fourier runner not found at $runner"))
        return new(python, runner)
    end
end

function evaluator_spec(::StellaratorDESCFourierV1)
    return EvaluatorSpec(
        "stellarator_fixed_boundary_desc_fourier_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "explicit_fourier_boundary" => :full,
            "vmec_or_desc" => :full,
            "finite_beta_equilibrium" => :full,
            "three_dimensional_force_balance" => :full,
        ),
        "physics_concept",
    )
end

function _desc_fourier_core(genome::Genome)
    return _desc_one_by_geometry(genome.plasma_regions,
        "desc_stellarator_symmetric_fourier_v1", "explicit Fourier plasma region")
end

function _desc_fourier_bool_parameter(item, name::String)
    value = _desc_integer_parameter(item, name)
    value in (0, 1) || throw(ArgumentError("$(item.id).$name must be 0 or 1"))
    return value == 1
end

function _desc_fourier_inputs(genome::Genome)
    core = _desc_fourier_core(genome)
    major = _desc_parameter(core, "major_radius", "m")
    minor_r = _desc_parameter(core, "minor_radius_r", "m")
    minor_z = _desc_parameter(core, "minor_radius_z", "m")
    helical_r = _desc_parameter(core, "helical_axis_r", "m")
    helical_z = _desc_parameter(core, "helical_axis_z", "m")
    pressure_axis = _desc_parameter(core, "pressure_axis", "Pa")
    exponent = _desc_integer_parameter(core, "pressure_profile_exponent")
    exponent == 2 || throw(ArgumentError("Fourier adapter v1 requires pressure exponent 2"))
    iota_axis = _desc_parameter(core, "iota_axis", "1")
    iota_edge = _desc_parameter(core, "iota_edge", "1")
    return Dict{String,Any}(
        "runner_version" => "desc_explicit_fourier_fixed_boundary_runner_v1",
        "model_id" => "stellarator_symmetric_fourier_fixed_boundary_v1",
        "source_binding" => "DESC-0.17.3",
        "boundary" => Dict{String,Any}(
            "field_periods" => genome.symmetry.field_periods,
            "stellarator_symmetric" => true,
            "R_modes" => Any[
                Dict("m" => 0, "n" => 0, "coefficient_m" => major),
                Dict("m" => 1, "n" => 0, "coefficient_m" => minor_r),
                Dict("m" => 0, "n" => 1, "coefficient_m" => helical_r),
            ],
            "Z_modes" => Any[
                Dict("m" => -1, "n" => 0, "coefficient_m" => -minor_z),
                Dict("m" => 0, "n" => -1, "coefficient_m" => -helical_z),
            ],
        ),
        "profiles" => Dict{String,Any}(
            "pressure_power_series_pa" => [pressure_axis, 0.0,
                -2.0 * pressure_axis, 0.0, pressure_axis],
            "iota_power_series" => [iota_axis, 0.0, iota_edge - iota_axis],
            "toroidal_flux_wb" => _desc_parameter(core, "toroidal_flux", "Wb"),
        ),
        "resolution" => Dict{String,Any}(
            "L" => _desc_integer_parameter(core, "spectral_l"),
            "M" => _desc_integer_parameter(core, "spectral_m"),
            "N" => _desc_integer_parameter(core, "spectral_n"),
            "L_grid" => _desc_integer_parameter(core, "grid_l"),
            "M_grid" => _desc_integer_parameter(core, "grid_m"),
            "N_grid" => _desc_integer_parameter(core, "grid_n"),
        ),
        "solver" => Dict{String,Any}(
            "optimizer" => "lsq-exact",
            "max_iterations" => _desc_integer_parameter(core, "solver_max_iterations"),
            "ftol" => _desc_parameter(core, "solver_ftol", "1"),
            "xtol" => _desc_parameter(core, "solver_xtol", "1"),
            "gtol" => _desc_parameter(core, "solver_gtol", "1"),
            "pressure_step" => _desc_parameter(core, "pressure_step", "1"),
            "boundary_step" => _desc_parameter(core, "boundary_step", "1"),
            "shaping_first" => _desc_fourier_bool_parameter(core, "shaping_first"),
        ),
        "audit" => Dict{String,Any}(
            "max_force_normalized_magnetic" =>
                _desc_parameter(core, "max_normalized_force_error", "1"),
            "max_fixed_constraint_error" =>
                _desc_parameter(core, "max_fixed_constraint_error", "1"),
            "min_sqrt_g" => _desc_parameter(core, "min_sqrt_g", "1"),
        ),
    )
end

function _desc_fourier_mismatches(genome::Genome)
    mismatches = String[]
    genome.family == "stellarator" || push!(mismatches, "family")
    genome.topology.field_line_class == "closed_toroidal_nested" ||
        push!(mismatches, "field-line class")
    genome.topology.expected_flux_surfaces === true ||
        push!(mismatches, "nested surfaces")
    genome.topology.expected_separatrix === false || push!(mismatches, "separatrix")
    genome.symmetry.class == "stellarator_symmetric" ||
        push!(mismatches, "symmetry class")
    2 <= genome.symmetry.field_periods <= 8 || push!(mismatches, "field periods")
    "desc_software_0_17_3" in genome.provenance.source_ids ||
        push!(mismatches, "DESC source binding")
    try
        core = _desc_fourier_core(genome)
        spec = StellaratorFourierBuildSpec(
            field_periods = genome.symmetry.field_periods,
            major_radius_m = _desc_parameter(core, "major_radius", "m"),
            minor_radius_r_m = _desc_parameter(core, "minor_radius_r", "m"),
            minor_radius_z_m = _desc_parameter(core, "minor_radius_z", "m"),
            helical_axis_r_m = _desc_parameter(core, "helical_axis_r", "m"),
            helical_axis_z_m = _desc_parameter(core, "helical_axis_z", "m"),
            nominal_field_t = _desc_parameter(core, "nominal_field", "T"),
            pressure_axis_pa = _desc_parameter(core, "pressure_axis", "Pa"),
            iota_axis = _desc_parameter(core, "iota_axis", "1"),
            iota_edge = _desc_parameter(core, "iota_edge", "1"),
            spectral_l = _desc_integer_parameter(core, "spectral_l"),
            spectral_m = _desc_integer_parameter(core, "spectral_m"),
            spectral_n = _desc_integer_parameter(core, "spectral_n"),
            grid_l = _desc_integer_parameter(core, "grid_l"),
            grid_m = _desc_integer_parameter(core, "grid_m"),
            grid_n = _desc_integer_parameter(core, "grid_n"),
            solver_max_iterations = _desc_integer_parameter(core, "solver_max_iterations"),
            solver_ftol = _desc_parameter(core, "solver_ftol", "1"),
            solver_xtol = _desc_parameter(core, "solver_xtol", "1"),
            solver_gtol = _desc_parameter(core, "solver_gtol", "1"),
            pressure_step = _desc_parameter(core, "pressure_step", "1"),
            boundary_step = _desc_parameter(core, "boundary_step", "1"),
            shaping_first = _desc_fourier_bool_parameter(core, "shaping_first"),
            max_normalized_force_error =
                _desc_parameter(core, "max_normalized_force_error", "1"),
            max_fixed_constraint_error =
                _desc_parameter(core, "max_fixed_constraint_error", "1"),
            min_sqrt_g = _desc_parameter(core, "min_sqrt_g", "1"),
        )
        _desc_integer_parameter(core, "pressure_profile_exponent") == 2 ||
            push!(mismatches, "pressure exponent")
        flux = _desc_parameter(core, "toroidal_flux", "Wb")
        expected_flux = spec.nominal_field_t * pi * spec.minor_radius_r_m *
            spec.minor_radius_z_m
        isapprox(flux, expected_flux; rtol = 1.0e-12, atol = 1.0e-12) ||
            push!(mismatches, "toroidal flux is inconsistent with nominal B*pi*a_r*a_z")
        quadratic = _desc_parameter(core, "iota_quadratic", "1")
        isapprox(quadratic, spec.iota_edge - spec.iota_axis;
            rtol = 1.0e-12, atol = 1.0e-12) ||
            push!(mismatches, "iota quadratic coefficient")
        _desc_fourier_inputs(genome)
    catch error
        push!(mismatches, sprint(showerror, error))
    end
    return sort!(unique(mismatches))
end

function evaluator_applicability(evaluator::StellaratorDESCFourierV1,
        genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "explicit bounded stellarator-symmetric Fourier fixed-boundary input" :
        "stellarator_fixed_boundary_desc_fourier_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_fourier_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}(), wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 explicit stellarator-symmetric fixed-boundary finite-beta equilibrium only.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_fixed_boundary_desc_fourier_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time)
end

function _desc_fourier_bundle_from_raw(adapter::StellaratorDESCFourierV1,
        genome::Genome, input::Dict{String,Any}, raw::Dict{String,Any};
        wall_time_s::Real = 0.0)
    get(raw, "status", "error") == "pass" ||
        error("DESC Fourier runner failed: $(get(raw, "message", "unknown error"))")
    runner_source_hash = bytes2hex(sha256(read(adapter.runner_path)))
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "solver_input" => input,
        "runner_result_hash" => raw["result_hash"],
        "runner_source_hash" => runner_source_hash,
        "evaluator" => "stellarator_fixed_boundary_desc_fourier_v1",
        "version" => "1.0.0",
    ))
    solver = raw["solver"]
    after = raw["after"]
    coordinate = raw["coordinate_audit"]
    fixed = raw["fixed_constraint_residuals"]
    field = raw["field_variation"]
    model = raw["model"]
    equilibrium_ok = solver["equilibrium_accepted"] === true
    force_ok = solver["equation_residual_accepted"] === true
    fixed_ok = solver["fixed_constraints_accepted"] === true
    jacobian_ok = solver["jacobian_accepted"] === true
    nested_ok = model["final_nested"] === true
    fixed_max = maximum(Float64[value for value in values(fixed)])
    warnings_out = String[
        "This boundary was generated from a five-mode search chart; it is not W7-X or another experimental reconstruction.",
        "Fixed-boundary force balance does not establish quasi-symmetry, Mercier/ballooning stability, transport, alpha confinement, coil realizability, exhaust, fusion performance, or engineering feasibility.",
        "The nominal magnetic field only sets toroidal flux through B*pi*a_r*a_z; it is not a coil-verified on-axis field.",
        "Native Windows lacks jax-finufft, so NUFFT-backed objectives remain unavailable.",
    ]
    append!(warnings_out, String.(raw["warnings"]))
    unique!(warnings_out)
    residuals = Dict{String,Float64}(
        "force_normalized_to_magnetic_gradient" =>
            after["force_normalized_to_magnetic_gradient"],
        "force_normalized_to_pressure_gradient" =>
            after["force_normalized_to_pressure_gradient"],
        "fixed_constraint_max_abs" => fixed_max,
        "minimum_sampled_sqrt_g" => coordinate["min_sqrt_g"],
    )
    metrics = MetricResult[
        _desc_fourier_metric("fixed_boundary_equilibrium_converged", equilibrium_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["equation residual", "fixed boundary/profiles/flux",
                "nested coordinates", "positive sampled Jacobian"],
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_fourier_metric("three_dimensional_force_balance_feasible", force_ok && fixed_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["normalized force residual <= declared threshold",
                "fixed input drift <= declared threshold"],
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_fourier_metric("nested_flux_surfaces_feasible", nested_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_fourier_metric("positive_coordinate_jacobian_feasible", jacobian_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_fourier_metric("force_balance_residual_volume_average",
            after["force_volume_average_n_m3"]; unit = "N/m^3",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_fourier_metric("force_balance_residual_normalized_magnetic",
            after["force_normalized_to_magnetic_gradient"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_fourier_metric("minimum_sampled_sqrt_g", coordinate["min_sqrt_g"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = wall_time_s),
        _desc_fourier_metric("continuation_state_count", solver["continuation_states"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("boundary_mode_count", model["boundary_mode_count"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("plasma_volume", after["plasma_volume_m3"]; unit = "m^3",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("volume_average_beta", after["volume_average_beta"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("major_radius", after["major_radius_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("minor_radius", after["minor_radius_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("aspect_ratio", after["aspect_ratio"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("rotational_transform_axis", after["iota_axis"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("rotational_transform_095", after["iota_095"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("field_peak_to_peak_over_mean_mid",
            field["field_peak_to_peak_over_mean_mid"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
        _desc_fourier_metric("field_peak_to_peak_over_mean_095",
            field["field_peak_to_peak_over_mean_095"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = wall_time_s),
    ]
    for (id, unit, message) in (
            ("plasma_stability_feasible", "1", "all-mode plasma stability was not evaluated"),
            ("minimum_stability_margin", "1", "no common stability margin was evaluated"),
            ("quasi_symmetry_error", "1", "Boozer-space quasi-symmetry was not evaluated"),
            ("mercier_stability_feasible", "1", "Mercier stability was not evaluated"),
            ("ballooning_stability_feasible", "1", "ballooning stability was not evaluated"),
            ("neoclassical_transport_feasible", "1", "neoclassical transport was not evaluated"),
            ("fast_ion_confinement_feasible", "1", "fast-ion orbits were not evaluated"),
            ("fusion_gain", "1", "burning-plasma power balance was not evaluated"),
            ("fusion_power", "W", "fusion reactions and thermal power were not evaluated"),
            ("device_complexity_index", "1", "coil and system complexity were not evaluated"),
            ("engineering_feasible", "1", "integrated engineering was not evaluated"),
            ("net_electric_power", "W", "net electric power was not evaluated"))
        push!(metrics, _desc_fourier_metric(id, nothing; unit = unit, status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), wall_time = wall_time_s))
    end
    return EvaluationBundle("stellarator_fixed_boundary_desc_fourier_v1",
        genome.design_id, genome.family, 1, equilibrium_ok ? :pass : :fail,
        metrics, warnings_out, genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCFourierV1,
        genome::Genome; kwargs...)
    input = _desc_fourier_inputs(genome)
    raw = Dict{String,Any}()
    elapsed = @elapsed raw = mktemp() do input_path, input_io
        JSON3.pretty(input_io, input)
        write(input_io, '\n')
        close(input_io)
        return mktemp() do output_path, output_io
            close(output_io)
            command = `$(adapter.python_path) $(adapter.runner_path) --input $(input_path) --output $(output_path)`
            run(command)
            return _plain_json(JSON3.read(read(output_path, String), Dict{String,Any}))
        end
    end
    return _desc_fourier_bundle_from_raw(adapter, genome, input, raw;
        wall_time_s = elapsed)
end
