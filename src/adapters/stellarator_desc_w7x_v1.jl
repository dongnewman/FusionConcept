struct StellaratorDESCW7XRegressionV1 <: AbstractEvaluator
    python_path::String
    runner_path::String

    function StellaratorDESCW7XRegressionV1(
            python_path::AbstractString = get(ENV, "FUSION_CONCEPT_DESC_PYTHON",
                normpath(joinpath(@__DIR__, "..", "..", ".venv-desc", "Scripts", "python.exe"))),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..", "scripts", "desc_w7x_runner.py")))
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        isfile(python) || throw(ArgumentError(
            "DESC Python not found at $python; run scripts/setup_desc_windows_fixed_boundary.ps1"))
        isfile(runner) || throw(ArgumentError("DESC W7-X runner not found at $runner"))
        return new(python, runner)
    end
end

function evaluator_spec(::StellaratorDESCW7XRegressionV1)
    return EvaluatorSpec(
        "stellarator_fixed_boundary_desc_w7x_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "vmec_or_desc" => :full,
            "finite_beta_equilibrium" => :full,
            "three_dimensional_force_balance" => :full,
        ),
        "physics_concept",
    )
end

function _desc_one_by_geometry(items, geometry::String, label::String)
    matches = filter(item -> item.geometry_model == geometry, items)
    length(matches) == 1 || throw(ArgumentError("expected one $label using $geometry"))
    return only(matches)
end

function _desc_parameter(item, name::String, unit::String)
    parameter = get(item.parameters, name, nothing)
    parameter === nothing && throw(ArgumentError("$(item.id) is missing $name"))
    parameter.unit == unit || throw(ArgumentError("$(item.id).$name must use $unit"))
    return parameter.value
end

function _desc_integer_parameter(item, name::String)
    value = _desc_parameter(item, name, "1")
    isinteger(value) || throw(ArgumentError("$(item.id).$name must be an integer"))
    return Int(value)
end

function _desc_inputs(genome::Genome)
    core = _desc_one_by_geometry(genome.plasma_regions,
        "desc_builtin_w7x_0_17_3", "packaged W7-X plasma region")
    return Dict{String,Any}(
        "runner_version" => "desc_packaged_w7x_refinement_runner_v1",
        "example_id" => "W7-X",
        "example_binding" => "DESC-0.17.3-packaged-data",
        "solver" => Dict(
            "optimizer" => "lsq-exact",
            "max_iterations" => _desc_integer_parameter(core, "solver_max_iterations"),
            "ftol" => _desc_parameter(core, "solver_ftol", "1"),
            "xtol" => _desc_parameter(core, "solver_xtol", "1"),
            "gtol" => _desc_parameter(core, "solver_gtol", "1"),
        ),
    )
end

function _desc_w7x_mismatches(genome::Genome)
    mismatches = String[]
    genome.family == "stellarator" || push!(mismatches, "family")
    genome.topology.field_line_class == "closed_toroidal_nested" ||
        push!(mismatches, "field-line class")
    genome.topology.expected_flux_surfaces === true ||
        push!(mismatches, "nested surfaces")
    genome.topology.expected_separatrix === false || push!(mismatches, "separatrix")
    genome.symmetry.class == "quasi_isodynamic" || push!(mismatches, "symmetry class")
    genome.symmetry.field_periods == 5 || push!(mismatches, "field periods")
    "desc_software_0_17_3" in genome.provenance.source_ids ||
        push!(mismatches, "DESC source binding")
    try
        core = _desc_one_by_geometry(genome.plasma_regions,
            "desc_builtin_w7x_0_17_3", "packaged W7-X plasma region")
        for (name, expected) in (("spectral_l", 12), ("spectral_m", 12),
                ("spectral_n", 12), ("grid_l", 16), ("grid_m", 16),
                ("grid_n", 16), ("boundary_r_coefficient_count", 313),
                ("boundary_z_coefficient_count", 312))
            _desc_integer_parameter(core, name) == expected ||
                push!(mismatches, "$name must equal $expected")
        end
        input = _desc_inputs(genome)
        solver = input["solver"]
        1 <= solver["max_iterations"] <= 20 || push!(mismatches, "max iterations")
        for name in ("ftol", "xtol", "gtol")
            1.0e-12 <= solver[name] <= 1.0e-3 || push!(mismatches, name)
        end
        1.0e-5 <= _desc_parameter(core, "max_normalized_force_error", "1") <= 0.05 ||
            push!(mismatches, "normalized force threshold")
    catch error
        push!(mismatches, sprint(showerror, error))
    end
    return sort!(unique(mismatches))
end

function evaluator_applicability(evaluator::StellaratorDESCW7XRegressionV1,
        genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    mismatches = _desc_w7x_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact DESC 0.17.3 packaged W7-X fixed-boundary regression binding" :
        "stellarator_fixed_boundary_desc_w7x_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}(), wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 packaged W7-X fixed-boundary finite-beta equilibrium only.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_fixed_boundary_desc_w7x_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time)
end

function run_evaluator(adapter::StellaratorDESCW7XRegressionV1,
        genome::Genome; kwargs...)
    input = _desc_inputs(genome)
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
    get(raw, "status", "error") == "pass" ||
        error("DESC W7-X runner failed: $(get(raw, "message", "unknown error"))")
    runner_source_hash = bytes2hex(sha256(read(adapter.runner_path)))
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "solver_input" => input,
        "runner_result_hash" => raw["result_hash"],
        "runner_source_hash" => runner_source_hash,
        "evaluator" => "stellarator_fixed_boundary_desc_w7x_v1",
        "version" => "1.0.0",
    ))
    core = _desc_one_by_geometry(genome.plasma_regions,
        "desc_builtin_w7x_0_17_3", "packaged W7-X plasma region")
    solver = raw["solver"]
    after = raw["after"]
    fixed = raw["fixed_constraint_residuals"]
    example = raw["packaged_example"]
    expected_state_hash = "9aa949dc8845ff7adcfd6fade64ca9faf369d3fb0c49d8318b972fac2881c722"
    state_ok = example["initial_state_hash"] == expected_state_hash
    solver_ok = solver["success"] === true &&
        solver["optimality"] <= solver["requested_gtol"]
    force_limit = _desc_parameter(core, "max_normalized_force_error", "1")
    force_ok = after["force_normalized_to_magnetic_gradient"] <= force_limit
    fixed_max = maximum(Float64[
        fixed["boundary_r_max_abs_m"], fixed["boundary_z_max_abs_m"],
        fixed["pressure_coeff_max_abs_pa"], fixed["iota_coeff_max_abs"],
        fixed["toroidal_flux_abs_wb"],
    ])
    fixed_ok = fixed_max <= 1.0e-12
    equilibrium_ok = state_ok && solver_ok && force_ok && fixed_ok
    warnings_out = String[
        "This is a refinement of DESC 0.17.3 packaged W7-X numerical data, not an experimental reconstruction.",
        "The solve is fixed-boundary and does not evaluate external coils, free-boundary consistency, island divertor physics, or engineering build.",
        "Native Windows lacks jax-finufft; NUFFT-backed neoclassical and fast-ion objectives are unavailable and remain missing.",
        "Three-dimensional force balance does not establish Mercier, ballooning, resistive-MHD, disruption, transport, fusion-gain, or engineering feasibility.",
    ]
    append!(warnings_out, String.(raw["warnings"]))
    unique!(warnings_out)
    residuals = Dict{String,Float64}(
        "force_normalized_to_magnetic_gradient" => after["force_normalized_to_magnetic_gradient"],
        "force_normalized_to_pressure_gradient" => after["force_normalized_to_pressure_gradient"],
        "solver_cost" => solver["cost"],
        "solver_optimality" => solver["optimality"],
        "fixed_constraint_max_abs" => fixed_max,
    )
    metrics = MetricResult[
        _desc_metric("fixed_boundary_equilibrium_converged", solver_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["lsq-exact success", "optimality <= requested gtol"],
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _desc_metric("three_dimensional_force_balance_feasible", equilibrium_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["packaged-state fingerprint", "solver convergence",
                "normalized force residual", "fixed boundary and profiles"],
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _desc_metric("force_balance_residual_volume_average",
            after["force_volume_average_n_m3"]; unit = "N/m^3",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _desc_metric("force_balance_residual_normalized_magnetic",
            after["force_normalized_to_magnetic_gradient"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _desc_metric("equilibrium_iteration_count", solver["iterations"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _desc_metric("plasma_volume", after["plasma_volume_m3"]; unit = "m^3",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _desc_metric("volume_average_beta", after["volume_average_beta"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _desc_metric("major_radius", after["major_radius_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _desc_metric("minor_radius", after["minor_radius_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _desc_metric("aspect_ratio", after["aspect_ratio"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _desc_metric("rotational_transform_axis", after["iota_axis"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _desc_metric("rotational_transform_095", after["iota_095"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
    ]
    for (id, unit, message) in (
            ("plasma_stability_feasible", "1", "all-mode plasma stability was not evaluated"),
            ("minimum_stability_margin", "1", "no common all-mode stability margin was evaluated"),
            ("mercier_stability_feasible", "1", "Mercier stability was not evaluated by this adapter"),
            ("ballooning_stability_feasible", "1", "ballooning stability was not evaluated"),
            ("neoclassical_transport_feasible", "1", "NUFFT-backed neoclassical transport was not evaluated"),
            ("fast_ion_confinement_feasible", "1", "alpha or fast-ion orbits were not evaluated"),
            ("fusion_gain", "1", "burning-plasma power balance was not evaluated"),
            ("fusion_power", "W", "fusion reactions and thermal power were not evaluated"),
            ("device_complexity_index", "1", "physics-based device complexity was not evaluated"),
            ("engineering_feasible", "1", "integrated engineering was not evaluated"),
            ("net_electric_power", "W", "net electric power was not evaluated"))
        push!(metrics, _desc_metric(id, nothing; unit = unit, status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), wall_time = elapsed))
    end
    return EvaluationBundle("stellarator_fixed_boundary_desc_w7x_v1",
        genome.design_id, genome.family, 1, equilibrium_ok ? :pass : :fail,
        metrics, warnings_out, genome.physics_hash, run_hash, "physics_concept")
end
