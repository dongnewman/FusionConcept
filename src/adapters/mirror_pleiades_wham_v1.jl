struct MirrorPleiadesWHAMIsotropicV1 <: AbstractEvaluator
    python_path::String
    runner_path::String

    function MirrorPleiadesWHAMIsotropicV1(
            python_path::AbstractString = get(ENV, "FUSION_CONCEPT_PLEIADES_PYTHON",
                normpath(joinpath(@__DIR__, "..", "..", ".conda-pleiades-public", "python.exe"))),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..", "scripts", "pleiades_wham_runner.py")))
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        isfile(python) || throw(ArgumentError(
            "Pleiades Python not found at $python; run scripts/setup_pleiades_public.ps1"))
        isfile(runner) || throw(ArgumentError("public Pleiades WHAM runner not found at $runner"))
        return new(python, runner)
    end
end

function evaluator_spec(::MirrorPleiadesWHAMIsotropicV1)
    return EvaluatorSpec(
        "mirror_isotropic_pleiades_wham_v1",
        "1.0.0",
        ["magnetic_mirror"],
        1,
        Dict(
            "axisymmetric_green_function_fields" => :full,
            "isotropic_mirror_equilibrium" => :full,
            "finite_beta_equilibrium" => :full,
        ),
        "physics_concept",
    )
end

function _pleiades_one_by_geometry(items, geometry::String, label::String)
    matches = filter(item -> item.geometry_model == geometry, items)
    length(matches) == 1 || throw(ArgumentError("expected one $label using $geometry"))
    return only(matches)
end

function _pleiades_parameter(item, name::String, unit::String)
    parameter = get(item.parameters, name, nothing)
    parameter === nothing && throw(ArgumentError("$(item.id) is missing $name"))
    parameter.unit == unit || throw(ArgumentError("$(item.id).$name must use $unit"))
    return parameter.value
end

function _pleiades_integer_parameter(item, name::String)
    value = _pleiades_parameter(item, name, "1")
    isinteger(value) || throw(ArgumentError("$(item.id).$name must be an integer"))
    return Int(value)
end

function _pleiades_source(genome::Genome, id::String)
    matches = filter(item -> item.id == id, genome.field_sources)
    length(matches) == 1 || throw(ArgumentError("expected field source $id"))
    return only(matches)
end

function _pleiades_inputs(genome::Genome)
    core = _pleiades_one_by_geometry(genome.plasma_regions,
        "pleiades_public_wham_isotropic_0161abb3", "public WHAM isotropic core")
    hts = _pleiades_source(genome, "pleiades_wham_hts_pair")
    central = _pleiades_source(genome, "pleiades_wham_central_pair")
    return Dict{String,Any}(
        "runner_version" => "pleiades_public_wham_isotropic_runner_v1",
        "model_id" => "WHAM-public-isotropic",
        "source_commit" => "0161abb3e9a1d85143c650f068ec524d672fc9ab",
        "grid" => Dict(
            "rmin_m" => _pleiades_parameter(core, "rmin", "m"),
            "rmax_m" => _pleiades_parameter(core, "rmax", "m"),
            "zmin_m" => _pleiades_parameter(core, "zmin", "m"),
            "zmax_m" => _pleiades_parameter(core, "zmax", "m"),
            "nr" => _pleiades_integer_parameter(core, "nr"),
            "nz" => _pleiades_integer_parameter(core, "nz"),
        ),
        "coils" => Dict(
            "hts_current_a" => _pleiades_parameter(hts, "current", "A"),
            "central_current_a" => _pleiades_parameter(central, "current", "A"),
        ),
        "pressure" => Dict(
            "radius_m" => _pleiades_parameter(core, "pressure_radius", "m"),
            "exponent" => _pleiades_parameter(core, "pressure_exponent", "1"),
            "beta_axis_target" => _pleiades_parameter(core, "vacuum_axis_beta_target", "1"),
        ),
        "solver" => Dict(
            "tolerance" => _pleiades_parameter(core, "solver_tolerance", "1"),
            "max_iterations" => _pleiades_integer_parameter(core, "solver_max_iterations"),
        ),
    )
end

function _pleiades_expect_parameter!(mismatches::Vector{String}, item,
        name::String, unit::String, expected::Real)
    actual = _pleiades_parameter(item, name, unit)
    actual == expected || push!(mismatches, "$(item.id).$name must equal $expected $unit")
end

function _pleiades_wham_mismatches(genome::Genome)
    mismatches = String[]
    genome.family == "magnetic_mirror" || push!(mismatches, "family")
    genome.topology.field_line_class == "open_mirror" || push!(mismatches, "field-line class")
    genome.topology.rotation_transform_sources == ["not_applicable"] ||
        push!(mismatches, "rotation transform")
    genome.symmetry.class == "axisymmetric" || push!(mismatches, "symmetry class")
    genome.symmetry.field_periods == 1 || push!(mismatches, "field periods")
    "pleiades_public_0_2_dev_2021" in genome.provenance.source_ids ||
        push!(mismatches, "public Pleiades source binding")
    "mirror_realtwin_corrigendum_2026" in genome.provenance.source_ids ||
        push!(mismatches, "RealTwin corrigendum source binding")
    try
        core = _pleiades_one_by_geometry(genome.plasma_regions,
            "pleiades_public_wham_isotropic_0161abb3", "public WHAM isotropic core")
        hts = _pleiades_source(genome, "pleiades_wham_hts_pair")
        central = _pleiades_source(genome, "pleiades_wham_central_pair")
        hts.geometry_model == "pleiades_rectangular_filament_bundle" ||
            push!(mismatches, "HTS geometry model")
        central.geometry_model == "pleiades_rectangular_filament_bundle" ||
            push!(mismatches, "central-coil geometry model")
        for (name, unit, expected) in (
                ("rmin", "m", 0.0), ("rmax", "m", 0.75),
                ("zmin", "m", -1.0), ("zmax", "m", 1.0),
                ("nr", "1", 31), ("nz", "1", 81),
                ("pressure_radius", "m", 0.5),
                ("pressure_exponent", "1", 2.0),
                ("vacuum_axis_beta_target", "1", 0.1),
                ("solver_tolerance", "1", 1.0e-10),
                ("solver_max_iterations", "1", 100))
            _pleiades_expect_parameter!(mismatches, core, name, unit, expected)
        end
        for (source, values) in (
                (hts, (("coil_count", "1", 2), ("current", "A", 160000.0),
                    ("centroid_radius", "m", 0.25), ("centroid_abs_z", "m", 0.942),
                    ("radial_half_width", "m", 0.0475), ("axial_half_width", "m", 0.0275),
                    ("radial_filaments", "1", 8), ("axial_filaments", "1", 4))),
                (central, (("coil_count", "1", 2), ("current", "A", 60000.0),
                    ("centroid_radius", "m", 1.005), ("centroid_abs_z", "m", 0.205),
                    ("radial_half_width", "m", 0.025), ("axial_half_width", "m", 0.024),
                    ("radial_filaments", "1", 2), ("axial_filaments", "1", 5))))
            for (name, unit, expected) in values
                _pleiades_expect_parameter!(mismatches, source, name, unit, expected)
            end
        end
        1.0e-12 <= _pleiades_parameter(core, "max_fixed_point_residual", "1") <= 1.0e-6 ||
            push!(mismatches, "fixed-point threshold")
        1.0e-12 <= _pleiades_parameter(core, "max_current_consistency_residual", "1") <= 1.0e-5 ||
            push!(mismatches, "current-consistency threshold")
        1.0e-4 <= _pleiades_parameter(core, "max_finite_difference_force_residual", "1") <= 0.05 ||
            push!(mismatches, "force-balance threshold")
        length(filter(item -> item.kind == "open_field_line", genome.flux_connections)) == 2 ||
            push!(mismatches, "exactly two open field-line connections")
    catch error
        push!(mismatches, sprint(showerror, error))
    end
    return sort!(unique(mismatches))
end

function evaluator_applicability(evaluator::MirrorPleiadesWHAMIsotropicV1,
        genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    mismatches = _pleiades_wham_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact public Pleiades 0161abb3 WHAM scalar-pressure regression binding" :
        "mirror_isotropic_pleiades_wham_v1 mismatch: $(join(mismatches, "; "))"
end

function _pleiades_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}(), wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "Public Pleiades 0161abb3 WHAM scalar-pressure axisymmetric equilibrium only.",
        status = status,
        constraints_checked = constraints,
        solver_name = "mirror_isotropic_pleiades_wham_v1",
        solver_version = "1.0.0+Pleiades-0.2.0-dev+0161abb3",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["pleiades_public_0_2_dev_2021", "mirror_wham_physics_basis_2023"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time)
end

function run_evaluator(adapter::MirrorPleiadesWHAMIsotropicV1,
        genome::Genome; kwargs...)
    input = _pleiades_inputs(genome)
    elapsed = @elapsed raw = mktemp() do input_path, input_io
        JSON3.pretty(input_io, input)
        write(input_io, '\n')
        close(input_io)
        return mktemp() do output_path, output_io
            close(output_io)
            command = `$(adapter.python_path) $(adapter.runner_path) --input $(input_path) --output $(output_path)`
            run(pipeline(command, stdout = devnull, stderr = devnull))
            return _plain_json(JSON3.read(read(output_path, String), Dict{String,Any}))
        end
    end
    get(raw, "status", "error") == "pass" ||
        error("public Pleiades WHAM runner failed: $(get(raw, "message", "unknown error"))")
    runner_source_hash = bytes2hex(sha256(read(adapter.runner_path)))
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "solver_input" => input,
        "runner_result_hash" => raw["result_hash"],
        "runner_source_hash" => runner_source_hash,
        "evaluator" => "mirror_isotropic_pleiades_wham_v1",
        "version" => "1.0.0",
    ))

    core = _pleiades_one_by_geometry(genome.plasma_regions,
        "pleiades_public_wham_isotropic_0161abb3", "public WHAM isotropic core")
    solver = raw["solver"]
    metrics_raw = raw["metrics"]
    model = raw["model"]
    upstream = raw["upstream"]
    source_ok = upstream["commit"] == "0161abb3e9a1d85143c650f068ec524d672fc9ab" &&
        upstream["package_source_hash"] == "57c81216f0b58e8eeda53cddc6427bfc6f14b025f50b166d0bf30bd1d3f6e547"
    state_ok = model["state_hash"] ==
        "0dda88f1daed9bdc50069a183ab9f61d57d0477f921ef1aade6d2c75ec6e3e6e"
    grid_ok = model["grid"]["nr"] == 31 && model["grid"]["nz"] == 81 &&
        model["grid"]["points"] == 2511
    solver_ok = solver["converged"] === true &&
        solver["final_iteration_error"] <= solver["requested_tolerance"]
    fixed_limit = _pleiades_parameter(core, "max_fixed_point_residual", "1")
    current_limit = _pleiades_parameter(core, "max_current_consistency_residual", "1")
    force_limit = _pleiades_parameter(core, "max_finite_difference_force_residual", "1")
    fixed_ok = metrics_raw["fixed_point_flux_residual_l2"] <= fixed_limit
    current_ok = metrics_raw["plasma_current_consistency_l2"] <= current_limit
    force_ok = metrics_raw["finite_difference_force_balance_relative_l2"] <= force_limit
    equilibrium_ok = source_ok && state_ok && grid_ok && solver_ok && fixed_ok && current_ok && force_ok

    warnings_out = String[
        "This adapter runs the last public 2021 Pleiades develop commit, not the custom anisotropic Pleiades fork used by RealTwin.",
        "The pressure is an isotropic scalar P(psi) reconstructed from a prescribed midplane radial profile; p_parallel and p_perpendicular are not evolved.",
        "The 31x81 regression grid is below the public notebook's 76x201 grid; a separate 31x81/46x121/61x161 audit bounds reported grid sensitivity.",
        "The sampled mirror ratio is grid-location sensitive because a uniform grid may not land on the coil centroid; it is a diagnostic, not a stability proof.",
        "Static convergence and finite-difference force balance do not establish interchange, ballooning, DCLC, AIC, transport, end-loss, fusion-gain, or engineering feasibility.",
        "This numerical fixture is not an experimental WHAM reconstruction.",
        "The 2026 RealTwin corrigendum requires explicit equation-residual gates for future POPCON performance optimization; optimizer success alone is insufficient.",
    ]
    append!(warnings_out, String.(raw["warnings"]))
    unique!(warnings_out)
    residuals = Dict{String,Float64}(
        "solver_final_iteration_error" => solver["final_iteration_error"],
        "fixed_point_flux_residual_l2" => metrics_raw["fixed_point_flux_residual_l2"],
        "plasma_current_consistency_l2" => metrics_raw["plasma_current_consistency_l2"],
        "finite_difference_force_balance_relative_l2" =>
            metrics_raw["finite_difference_force_balance_relative_l2"],
    )
    metrics = MetricResult[
        _pleiades_metric("axisymmetric_vacuum_field_feasible", source_ok && state_ok && grid_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["pinned public source tree", "exact WHAM coil and grid state"],
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _pleiades_metric("isotropic_equilibrium_converged", solver_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["fixed-point iteration error <= requested tolerance"],
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _pleiades_metric("finite_beta_equilibrium_feasible", equilibrium_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["source and state fingerprints", "solver convergence",
                "fixed-point flux residual", "current consistency", "finite-difference force balance"],
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _pleiades_metric("equilibrium_iteration_count", solver["iterations"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _pleiades_metric("fixed_point_flux_residual_l2", metrics_raw["fixed_point_flux_residual_l2"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _pleiades_metric("finite_difference_force_balance_relative_l2",
            metrics_raw["finite_difference_force_balance_relative_l2"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals, wall_time = elapsed),
        _pleiades_metric("vacuum_center_field", metrics_raw["vacuum_center_field_t"]; unit = "T",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _pleiades_metric("vacuum_sampled_mirror_ratio", metrics_raw["vacuum_sampled_mirror_ratio"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _pleiades_metric("prescribed_axis_pressure", metrics_raw["pressure_axis_pa"]; unit = "Pa",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _pleiades_metric("relative_flux_change_l2", metrics_raw["relative_flux_change_l2"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _pleiades_metric("plasma_diamagnetic_current_total", metrics_raw["plasma_current_total_a"]; unit = "A",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _pleiades_metric("plasma_current_density_peak_abs",
            metrics_raw["plasma_current_density_peak_abs_a_m2"]; unit = "A/m^2",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
    ]
    for (id, unit, message) in (
            ("anisotropic_equilibrium_feasible", "1", "the public solver has no self-consistent anisotropic pressure tensor"),
            ("plasma_stability_feasible", "1", "all-mode mirror stability was not evaluated"),
            ("minimum_stability_margin", "1", "no common stability margin was evaluated"),
            ("interchange_stability_feasible", "1", "m=1 or interchange stability was not evaluated"),
            ("ballooning_stability_feasible", "1", "ballooning stability was not evaluated"),
            ("dclc_stability_feasible", "1", "DCLC stability was not evaluated"),
            ("aic_stability_feasible", "1", "AIC stability was not evaluated"),
            ("particle_confinement_time", "s", "axial and radial transport were not evaluated"),
            ("end_loss_power", "W", "open-end particle and heat losses were not evaluated"),
            ("fusion_gain", "1", "fusion reactions and integrated power balance were not evaluated"),
            ("fusion_power", "W", "fusion reactions were not evaluated"),
            ("device_complexity_index", "1", "physics-based device complexity was not evaluated"),
            ("engineering_feasible", "1", "finite-build magnets, stress, quench, shielding, and maintenance were not evaluated"),
            ("net_electric_power", "W", "net electric power was not evaluated"))
        push!(metrics, _pleiades_metric(id, nothing; unit = unit, status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), wall_time = elapsed))
    end
    return EvaluationBundle("mirror_isotropic_pleiades_wham_v1",
        genome.design_id, genome.family, 1, equilibrium_ok ? :pass : :fail,
        metrics, warnings_out, genome.physics_hash, run_hash, "physics_concept")
end
