struct TokamakFreeBoundaryFreeGSV1 <: AbstractEvaluator
    python_path::String
    runner_path::String

    function TokamakFreeBoundaryFreeGSV1(
            python_path::AbstractString = get(ENV, "FUSION_CONCEPT_FREEGS_PYTHON",
                normpath(joinpath(@__DIR__, "..", "..", ".venv-freegs", "Scripts", "python.exe"))),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..", "scripts", "freegs_runner.py")))
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        isfile(python) || throw(ArgumentError(
            "FreeGS Python not found at $python; run scripts/setup_freegs.ps1"))
        isfile(runner) || throw(ArgumentError("FreeGS runner not found at $runner"))
        return new(python, runner)
    end
end

function evaluator_spec(::TokamakFreeBoundaryFreeGSV1)
    return EvaluatorSpec(
        "tokamak_free_boundary_freegs_v1",
        "1.0.0",
        ["tokamak_axisymmetric"],
        1,
        Dict(
            "free_boundary_grad_shafranov" => :full,
            "axisymmetric_force_balance" => :full,
            "free_boundary_shape_control" => :full,
        ),
        "physics_concept",
    )
end

function _freegs_items_by_kind(items, kind::String)
    return filter(item -> item.kind == kind, items)
end

function _freegs_one_by_geometry(items, geometry::String, label::String)
    matches = filter(item -> item.geometry_model == geometry, items)
    length(matches) == 1 || throw(ArgumentError("expected one $label using $geometry"))
    return only(matches)
end

function _freegs_one_by_kind(items, kind::String, label::String)
    matches = filter(item -> item.kind == kind, items)
    length(matches) == 1 || throw(ArgumentError("expected one $label of kind $kind"))
    return only(matches)
end

function _freegs_parameter(item, name::String, unit::String)
    parameter = get(item.parameters, name, nothing)
    parameter === nothing && throw(ArgumentError("$(item.id) is missing $name"))
    parameter.unit == unit || throw(ArgumentError("$(item.id).$name must use $unit"))
    return parameter.value
end

function _freegs_integer_parameter(item, name::String)
    value = _freegs_parameter(item, name, "1")
    isinteger(value) || throw(ArgumentError("$(item.id).$name must be an integer"))
    return Int(value)
end

function _freegs_inputs(genome::Genome)
    core = _freegs_one_by_geometry(genome.plasma_regions,
        "freegs_explicit_filament_v1", "plasma region")
    current = _freegs_one_by_geometry(genome.field_sources,
        "freegs_constrain_paxis_ip_v1", "plasma-current source")
    toroidal = _freegs_one_by_geometry(genome.field_sources,
        "vacuum_f_reference_v1", "toroidal-field reference")
    feedback = _freegs_one_by_kind(genome.actuators,
        "feedback_coil", "shape-feedback actuator")
    pf_coils = sort!(_freegs_items_by_kind(genome.field_sources,
        "poloidal_field_coil"); by = item -> item.id)
    isempty(pf_coils) && throw(ArgumentError("no poloidal-field coils were declared"))

    coil_inputs = [Dict{String,Any}(
        "id" => coil.id,
        "major_radius_m" => _freegs_parameter(coil, "major_radius", "m"),
        "vertical_position_m" => _freegs_parameter(coil, "vertical_position", "m"),
    ) for coil in pf_coils if coil.geometry_model == "freegs_filament_coil_v1"]
    length(coil_inputs) == length(pf_coils) ||
        throw(ArgumentError("all PF coils must use freegs_filament_coil_v1"))

    on_axis_field = _freegs_parameter(toroidal, "on_axis_field", "T")
    reference_radius = _freegs_parameter(toroidal, "reference_radius", "m")
    return Dict{String,Any}(
        "runner_version" => "freegs_explicit_filament_runner_v2",
        "machine" => Dict("kind" => "explicit_filament_coils", "coils" => coil_inputs),
        "domain" => Dict(
            "r_min_m" => _freegs_parameter(core, "domain_r_min", "m"),
            "r_max_m" => _freegs_parameter(core, "domain_r_max", "m"),
            "z_min_m" => _freegs_parameter(core, "domain_z_min", "m"),
            "z_max_m" => _freegs_parameter(core, "domain_z_max", "m"),
            "nx" => _freegs_integer_parameter(core, "grid_nx"),
            "ny" => _freegs_integer_parameter(core, "grid_ny"),
            "boundary" => "freeBoundaryHagenow",
        ),
        "profile" => Dict(
            "kind" => "ConstrainPaxisIp",
            "axis_pressure_pa" => _freegs_parameter(current, "axis_pressure", "Pa"),
            "plasma_current_a" => _freegs_parameter(current, "total_current", "A"),
            "vacuum_f_tm" => on_axis_field * reference_radius,
            "alpha_m" => _freegs_parameter(current, "alpha_m", "1"),
            "alpha_n" => _freegs_parameter(current, "alpha_n", "1"),
            "profile_axis_radius_m" => _freegs_parameter(current,
                "profile_axis_radius", "m"),
        ),
        "constraints" => Dict(
            "xpoints_m" => [
                [_freegs_parameter(core, "xpoint_lower_r", "m"),
                    _freegs_parameter(core, "xpoint_lower_z", "m")],
                [_freegs_parameter(core, "xpoint_upper_r", "m"),
                    _freegs_parameter(core, "xpoint_upper_z", "m")],
            ],
            "isoflux_m" => [[
                _freegs_parameter(core, "isoflux_reference_r", "m"),
                _freegs_parameter(core, "isoflux_reference_z", "m"),
                _freegs_parameter(core, "isoflux_match_r", "m"),
                _freegs_parameter(core, "isoflux_match_z", "m"),
            ]],
            "gamma" => _freegs_parameter(feedback, "tikhonov_gamma", "1"),
        ),
        "solver" => Dict(
            "rtol" => _freegs_parameter(core, "solver_rtol", "1"),
            "atol" => _freegs_parameter(core, "solver_atol", "1"),
            "max_iterations" => _freegs_integer_parameter(core,
                "solver_max_iterations"),
        ),
    )
end

function _freegs_mismatches(genome::Genome)
    mismatches = String[]
    genome.family == "tokamak_axisymmetric" || push!(mismatches, "family")
    genome.topology.field_line_class == "closed_toroidal_separatrix" ||
        push!(mismatches, "field-line class")
    genome.topology.expected_separatrix === true || push!(mismatches, "expected separatrix")
    genome.symmetry.class == "axisymmetric" || push!(mismatches, "symmetry")
    try
        input = _freegs_inputs(genome)
        coils = input["machine"]["coils"]
        4 <= length(coils) <= 32 || push!(mismatches, "PF coil count must be 4-32")
        domain = input["domain"]
        0.02 <= domain["r_min_m"] < domain["r_max_m"] <= 30.0 ||
            push!(mismatches, "radial domain")
        -30.0 <= domain["z_min_m"] < domain["z_max_m"] <= 30.0 ||
            push!(mismatches, "vertical domain")
        all(n -> 17 <= n <= 257 && isodd(n), (domain["nx"], domain["ny"])) ||
            push!(mismatches, "grid must be odd and 17-257")
        profile = input["profile"]
        0.0 < profile["axis_pressure_pa"] <= 1.0e8 || push!(mismatches, "axis pressure")
        1.0e4 <= abs(profile["plasma_current_a"]) <= 3.0e7 ||
            push!(mismatches, "plasma current")
        0.01 <= profile["vacuum_f_tm"] <= 200.0 || push!(mismatches, "vacuum F")
        0.1 <= profile["alpha_m"] <= 10.0 || push!(mismatches, "alpha_m")
        0.1 <= profile["alpha_n"] <= 10.0 || push!(mismatches, "alpha_n")
        solver = input["solver"]
        1.0e-8 <= solver["rtol"] <= 1.0e-2 || push!(mismatches, "solver rtol")
        10 <= solver["max_iterations"] <= 1000 || push!(mismatches, "max iterations")
        for coil in coils
            domain["r_min_m"] < coil["major_radius_m"] < 2.0 * domain["r_max_m"] ||
                push!(mismatches, "coil $(coil["id"]) radius")
        end
    catch error
        push!(mismatches, sprint(showerror, error))
    end
    return sort!(unique(mismatches))
end

function evaluator_applicability(evaluator::TokamakFreeBoundaryFreeGSV1,
        genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    mismatches = _freegs_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "explicit axisymmetric PF filaments with ConstrainPaxisIp and X-point/isoflux control" :
        "tokamak_free_boundary_freegs_v1 mismatch: $(join(mismatches, "; "))"
end

function _freegs_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}(), wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "Static axisymmetric FreeGS 0.8.2 free-boundary equilibrium for the declared explicit-filament model only.",
        status = status,
        constraints_checked = constraints,
        solver_name = "tokamak_free_boundary_freegs_v1",
        solver_version = "1.0.0+FreeGS-0.8.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["freegs_software_0_8_2"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = wall_time)
end

function run_evaluator(adapter::TokamakFreeBoundaryFreeGSV1, genome::Genome; kwargs...)
    input = _freegs_inputs(genome)
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
        error("FreeGS runner failed: $(get(raw, "message", "unknown error"))")
    runner_source_hash = bytes2hex(sha256(read(adapter.runner_path)))
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "solver_input" => input,
        "runner_result_hash" => raw["result_hash"],
        "runner_source_hash" => runner_source_hash,
        "evaluator" => "tokamak_free_boundary_freegs_v1",
        "version" => "1.0.0",
    ))
    convergence = raw["convergence"]
    residual = raw["independent_residual"]
    constraints_raw = raw["constraints"]
    equilibrium = raw["equilibrium"]
    target_current = input["profile"]["plasma_current_a"]
    current_relative_error = abs(equilibrium["plasma_current_a"] - target_current) /
        abs(target_current)
    xpoint_max = maximum(item["bp_t"] for item in
        constraints_raw["xpoint_field_residuals"])
    isoflux_max = maximum(item["relative_to_flux_span"] for item in
        constraints_raw["isoflux_residuals"])
    convergence_ok = convergence["final_relative_change"] <=
        convergence["requested_rtol"]
    residual_ok = residual["plasma_l2_relative"] <= 0.02
    shape_ok = xpoint_max <= 0.02 && isoflux_max <= 0.03
    current_ok = current_relative_error <= 1.0e-10
    equilibrium_ok = convergence_ok && residual_ok && shape_ok && current_ok
    warnings_out = String[
        "FreeGS 0.8.2 is alpha-stage software; this adapter is a solver-integration result, not experimental validation.",
        "The independent GS residual uses a second-order stencil against FreeGS's fourth-order solve and is a cross-check, not the solver stopping criterion.",
        "Static axisymmetric force balance does not establish ideal/resistive MHD stability, transport, disruption avoidance, exhaust, fusion gain, or engineering feasibility.",
        "No grid-convergence uncertainty is attached to this single-grid evaluation.",
    ]
    append!(warnings_out, String.(raw["warnings"]))
    residual_dict = Dict{String,Float64}(
        "final_picard_relative_change" => convergence["final_relative_change"],
        "independent_plasma_l2_relative" => residual["plasma_l2_relative"],
        "independent_plasma_linf_relative" => residual["plasma_linf_relative"],
        "xpoint_field_max_T" => xpoint_max,
        "isoflux_relative_max" => isoflux_max,
        "plasma_current_relative_error" => current_relative_error,
    )
    metrics = MetricResult[
        _freegs_metric("free_boundary_equilibrium_converged", convergence_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["Picard final relative change <= requested rtol"],
            warnings = warnings_out, residuals = residual_dict, wall_time = elapsed),
        _freegs_metric("axisymmetric_force_balance_feasible", equilibrium_ok;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["convergence", "independent GS residual", "shape control", "plasma current"],
            warnings = warnings_out, residuals = residual_dict, wall_time = elapsed),
        _freegs_metric("grad_shafranov_residual_l2_relative",
            residual["plasma_l2_relative"]; input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings_out, residuals = residual_dict,
            wall_time = elapsed),
        _freegs_metric("picard_final_relative_change",
            convergence["final_relative_change"]; input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings_out, residuals = residual_dict,
            wall_time = elapsed),
        _freegs_metric("equilibrium_iteration_count", convergence["iterations"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("xpoint_field_residual_max", xpoint_max; unit = "T",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residual_dict, wall_time = elapsed),
        _freegs_metric("isoflux_residual_relative", isoflux_max;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residual_dict, wall_time = elapsed),
        _freegs_metric("plasma_current", equilibrium["plasma_current_a"]; unit = "A",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("plasma_current_relative_error", current_relative_error;
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residual_dict, wall_time = elapsed),
        _freegs_metric("magnetic_axis_r", equilibrium["magnetic_axis_r_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("magnetic_axis_z", equilibrium["magnetic_axis_z_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("plasma_volume", equilibrium["plasma_volume_m3"]; unit = "m^3",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("minor_radius", equilibrium["minor_radius_m"]; unit = "m",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("elongation", equilibrium["elongation"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("poloidal_beta", equilibrium["poloidal_beta"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("toroidal_beta", equilibrium["toroidal_beta"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("beta_n", equilibrium["beta_n"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("q_95", equilibrium["q_95"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("internal_inductance", equilibrium["internal_inductance"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
        _freegs_metric("max_abs_pf_coil_current",
            maximum(abs(value) for value in values(raw["coil_currents_a"])); unit = "A",
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, wall_time = elapsed),
    ]
    for (id, unit, message) in (
            ("plasma_stability_feasible", "1", "ideal and resistive MHD stability were not evaluated"),
            ("minimum_stability_margin", "1", "no all-mode stability margin was evaluated"),
            ("fusion_gain", "1", "burning-plasma power balance was not evaluated"),
            ("fusion_power", "W", "fusion reactions and thermal power were not evaluated"),
            ("device_complexity_index", "1", "physics-based device complexity was not evaluated"),
            ("engineering_feasible", "1", "integrated engineering was not evaluated"),
            ("net_electric_power", "W", "net electric power was not evaluated"))
        push!(metrics, _freegs_metric(id, nothing; unit = unit, status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), wall_time = elapsed))
    end
    return EvaluationBundle("tokamak_free_boundary_freegs_v1", genome.design_id,
        genome.family, 1, equilibrium_ok ? :pass : :fail, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end
