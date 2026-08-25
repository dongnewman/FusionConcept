struct TokamakPFStaticRobustnessV1 <: AbstractEvaluator
    python_path::String
    runner_path::String
    coil_offset_m::Float64
    plasma_current_fraction::Float64
    axis_pressure_fraction::Float64

    function TokamakPFStaticRobustnessV1(
            python_path::AbstractString = get(ENV, "FUSION_CONCEPT_FREEGS_PYTHON",
                normpath(joinpath(@__DIR__, "..", "..", ".venv-freegs", "Scripts", "python.exe"))),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..", "scripts", "freegs_runner.py"));
            coil_offset_m::Real = 0.005,
            plasma_current_fraction::Real = 0.03,
            axis_pressure_fraction::Real = 0.05)
        python = abspath(String(python_path))
        runner = abspath(String(runner_path))
        isfile(python) || throw(ArgumentError(
            "FreeGS Python not found at $python; run scripts/setup_freegs.ps1"))
        isfile(runner) || throw(ArgumentError("FreeGS runner not found at $runner"))
        0.0 < coil_offset_m <= 0.02 ||
            throw(ArgumentError("coil_offset_m must be in (0, 0.02]"))
        0.0 < plasma_current_fraction <= 0.10 ||
            throw(ArgumentError("plasma_current_fraction must be in (0, 0.10]"))
        0.0 < axis_pressure_fraction <= 0.15 ||
            throw(ArgumentError("axis_pressure_fraction must be in (0, 0.15]"))
        return new(python, runner, Float64(coil_offset_m),
            Float64(plasma_current_fraction), Float64(axis_pressure_fraction))
    end
end

const _TOKAMAK_PF_STATIC_ROBUSTNESS_CLAIM_BOUNDARY =
    "Fidelity-1 deterministic static FreeGS re-solves under declared PF-centerline, " *
    "plasma-current, and pressure perturbations. Passing establishes only that the " *
    "static shape-control solve retained the recorded equilibrium, displacement, PF " *
    "current-authority, paired-current, and reduced engineering-proxy margins. It is " *
    "not a vertical growth-rate calculation, dynamic controller simulation, ideal or " *
    "resistive MHD stability result, disruption analysis, PF mutual-force solution, " *
    "finite winding or superconducting qualification, transport/exhaust calculation, " *
    "reactor power balance, or global optimum."

function evaluator_spec(::TokamakPFStaticRobustnessV1)
    return EvaluatorSpec(
        "tokamak_pf_static_robustness_v1",
        "1.0.0",
        ["tokamak_axisymmetric"],
        1,
        Dict(
            "free_boundary_static_perturbation_resolve" => :full,
            "pf_static_control_authority" => :proxy,
            "vertical_response" => :proxy,
        ),
        "physics_proxy",
    )
end

function evaluator_applicability(evaluator::TokamakPFStaticRobustnessV1,
        genome::Genome)
    freegs = TokamakFreeBoundaryFreeGSV1(evaluator.python_path,
        evaluator.runner_path)
    applicable, reason = evaluator_applicability(freegs, genome)
    applicable || return false, reason
    length(_freegs_inputs(genome)["machine"]["coils"]) >= 8 ||
        return false, "tokamak_pf_static_robustness_v1 requires at least eight PF coils"
    return true,
        "explicit symmetric PF-filament tokamak with static FreeGS shape-control re-solves"
end

function _tpr_target(genome::Genome, name::String)
    value = get(genome.mission.targets, name, nothing)
    value === nothing && throw(ArgumentError("mission target $name is required"))
    return Float64(value.value)
end

function _tpr_scenarios(adapter::TokamakPFStaticRobustnessV1,
        nominal::Dict{String,Any})
    cases = Pair{String,Dict{String,Any}}[]
    push!(cases, "nominal" => deepcopy(nominal))

    for (name, shift) in (("all_pf_z_plus", adapter.coil_offset_m),
            ("all_pf_z_minus", -adapter.coil_offset_m))
        input = deepcopy(nominal)
        for coil in input["machine"]["coils"]
            coil["vertical_position_m"] += shift
        end
        push!(cases, name => input)
    end

    input = deepcopy(nominal)
    for coil in input["machine"]["coils"]
        z = coil["vertical_position_m"]
        coil["vertical_position_m"] += copysign(adapter.coil_offset_m, z)
    end
    push!(cases, "paired_pf_vertical_separation" => input)

    input = deepcopy(nominal)
    for (index, coil) in enumerate(input["machine"]["coils"])
        radial_sign = isodd(index) ? -1.0 : 1.0
        vertical_sign = isodd(cld(index, 2)) ? -1.0 : 1.0
        coil["major_radius_m"] += radial_sign * adapter.coil_offset_m
        coil["vertical_position_m"] += vertical_sign * adapter.coil_offset_m
    end
    push!(cases, "alternating_pf_rz_offsets" => input)

    for (name, fraction) in (
            ("plasma_current_plus", adapter.plasma_current_fraction),
            ("plasma_current_minus", -adapter.plasma_current_fraction))
        input = deepcopy(nominal)
        input["profile"]["plasma_current_a"] *= 1.0 + fraction
        push!(cases, name => input)
    end

    for (name, fraction) in (
            ("axis_pressure_plus", adapter.axis_pressure_fraction),
            ("axis_pressure_minus", -adapter.axis_pressure_fraction))
        input = deepcopy(nominal)
        input["profile"]["axis_pressure_pa"] *= 1.0 + fraction
        push!(cases, name => input)
    end
    return cases
end

function _tpr_perturbation_record(adapter::TokamakPFStaticRobustnessV1,
        name::String)
    if startswith(name, "all_pf_z")
        return Dict("kind" => "uniform_pf_vertical_offset",
            "magnitude_m" => adapter.coil_offset_m,
            "sign" => endswith(name, "plus") ? 1 : -1)
    elseif name == "paired_pf_vertical_separation"
        return Dict("kind" => "mirror_pair_vertical_separation",
            "magnitude_per_coil_m" => adapter.coil_offset_m)
    elseif name == "alternating_pf_rz_offsets"
        return Dict("kind" => "deterministic_alternating_pf_rz_offset",
            "magnitude_per_axis_m" => adapter.coil_offset_m)
    elseif startswith(name, "plasma_current")
        return Dict("kind" => "plasma_current_fraction",
            "magnitude" => adapter.plasma_current_fraction,
            "sign" => endswith(name, "plus") ? 1 : -1)
    elseif startswith(name, "axis_pressure")
        return Dict("kind" => "axis_pressure_fraction",
            "magnitude" => adapter.axis_pressure_fraction,
            "sign" => endswith(name, "plus") ? 1 : -1)
    end
    return Dict("kind" => "nominal")
end

function _tpr_run_input(adapter::TokamakPFStaticRobustnessV1,
        input::Dict{String,Any})
    return mktemp() do input_path, input_io
        JSON3.pretty(input_io, input)
        write(input_io, '\n')
        close(input_io)
        return mktemp() do output_path, output_io
            close(output_io)
            command = `$(adapter.python_path) $(adapter.runner_path) --input $(input_path) --output $(output_path)`
            process = run(ignorestatus(command))
            if !success(process)
                return Dict{String,Any}(
                    "status" => "error",
                    "message" => "FreeGS runner exited with code $(process.exitcode)")
            end
            raw_text = read(output_path, String)
            isempty(strip(raw_text)) && return Dict{String,Any}(
                "status" => "error", "message" => "FreeGS runner produced no output")
            return _plain_json(JSON3.read(raw_text, Dict{String,Any}))
        end
    end
end

function _tpr_solver_gates(raw::AbstractDict, input::AbstractDict)
    get(raw, "status", "error") == "pass" || return Dict{String,Bool}(
        "runner_completed" => false,
        "picard_converged" => false,
        "independent_residual" => false,
        "shape_constraints" => false,
        "plasma_current" => false,
    )
    convergence = raw["convergence"]
    residual = raw["independent_residual"]
    constraints = raw["constraints"]
    equilibrium = raw["equilibrium"]
    xpoint_max = maximum(Float64(item["bp_t"])
        for item in constraints["xpoint_field_residuals"])
    isoflux_max = maximum(Float64(item["relative_to_flux_span"])
        for item in constraints["isoflux_residuals"])
    target_current = Float64(input["profile"]["plasma_current_a"])
    current_error = abs(Float64(equilibrium["plasma_current_a"]) - target_current) /
        abs(target_current)
    return Dict{String,Bool}(
        "runner_completed" => true,
        "picard_converged" => Float64(convergence["final_relative_change"]) <=
            Float64(convergence["requested_rtol"]),
        "independent_residual" => Float64(residual["plasma_l2_relative"]) <= 0.02,
        "shape_constraints" => xpoint_max <= 0.02 && isoflux_max <= 0.03,
        "plasma_current" => current_error <= 1.0e-10,
    )
end

function _tpr_pair_imbalance(currents::AbstractDict, nominal_max::Float64)
    imbalances = Float64[]
    for (id, value) in currents
        endswith(String(id), "_upper") || continue
        lower = replace(String(id), r"_upper$" => "_lower")
        haskey(currents, lower) || continue
        push!(imbalances, abs(Float64(value) - Float64(currents[lower])) /
            max(nominal_max, eps(Float64)))
    end
    return isempty(imbalances) ? Inf : maximum(imbalances)
end

function _tpr_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        wall_time = 0.0)
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "Deterministic static FreeGS PF-perturbation and control-authority screen for the declared candidate.",
        status = status,
        constraints_checked = constraints,
        solver_name = "tokamak_pf_static_robustness_v1",
        solver_version = "1.0.0+FreeGS-0.8.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["freegs_software_0_8_2"],
        warnings = warnings,
        wall_time_s = wall_time)
end

function run_evaluator(adapter::TokamakPFStaticRobustnessV1,
        genome::Genome; kwargs...)
    nominal_input = _freegs_inputs(genome)
    scenarios = _tpr_scenarios(adapter, nominal_input)
    raw_cases = Pair{String,Dict{String,Any}}[]
    elapsed = @elapsed for (name, input) in scenarios
        push!(raw_cases, name => _tpr_run_input(adapter, input))
    end

    nominal_raw = first(raw_cases).second
    get(nominal_raw, "status", "error") == "pass" ||
        error("nominal FreeGS runner failed: $(get(nominal_raw, "message", "unknown error"))")
    nominal_eq = nominal_raw["equilibrium"]
    nominal_minor = Float64(nominal_eq["minor_radius_m"])
    nominal_axis_r = Float64(nominal_eq["magnetic_axis_r_m"])
    nominal_axis_z = Float64(nominal_eq["magnetic_axis_z_m"])
    nominal_q95 = Float64(nominal_eq["q_95"])
    nominal_currents = nominal_raw["coil_currents_a"]
    nominal_max_current = maximum(abs(Float64(value))
        for value in values(nominal_currents))

    pack_m = _tpr_target(genome, "screen_coil_pack_thickness")
    support_m = _tpr_target(genome, "screen_support_thickness")
    major_m = _tpr_target(genome, "screen_major_scale")
    field_T = _tpr_target(genome, "screen_plasma_field")
    contract = default_common_comparison_contract()
    case_records = Dict{String,Any}[]
    for ((name, input), (_, raw)) in zip(scenarios, raw_cases)
        solver_gates = _tpr_solver_gates(raw, input)
        solver_passed = all(values(solver_gates))
        record = Dict{String,Any}(
            "name" => name,
            "perturbation" => _tpr_perturbation_record(adapter, name),
            "solver_gates" => solver_gates,
            "solver_passed" => solver_passed,
            "runner_result_hash" => get(raw, "result_hash", nothing),
            "runner_message" => get(raw, "message", nothing),
        )
        if solver_passed
            equilibrium = raw["equilibrium"]
            currents = raw["coil_currents_a"]
            axis_r_delta = Float64(equilibrium["magnetic_axis_r_m"]) - nominal_axis_r
            axis_z_delta = Float64(equilibrium["magnetic_axis_z_m"]) - nominal_axis_z
            normalized_axis_displacement = hypot(axis_r_delta, axis_z_delta) /
                nominal_minor
            q95_relative_change = abs(Float64(equilibrium["q_95"]) / nominal_q95 - 1.0)
            minor_relative_change = abs(Float64(equilibrium["minor_radius_m"]) /
                nominal_minor - 1.0)
            maximum_current = maximum(abs(Float64(value)) for value in values(currents))
            current_amplification = maximum_current / nominal_max_current
            pair_imbalance = _tpr_pair_imbalance(currents, nominal_max_current)
            minimum_pf_radius = minimum(Float64(coil["major_radius_m"])
                for coil in input["machine"]["coils"])
            current_density = maximum_current / pack_m^2
            toroidal_field = field_T * major_m / minimum_pf_radius
            local_self_field = 4.0 * pi * 1.0e-7 * maximum_current / (pi * pack_m)
            additive_peak_field = toroidal_field + local_self_field
            magnetic_pressure = additive_peak_field^2 / (2.0 * 4.0 * pi * 1.0e-7)
            support_stress = magnetic_pressure * minimum_pf_radius / support_m
            response_gates = Dict{String,Bool}(
                "axis_displacement" => normalized_axis_displacement <= 0.02,
                "q95_response" => q95_relative_change <= 0.10,
                "minor_radius_response" => minor_relative_change <= 0.05,
                "pf_current_amplification" => current_amplification <= 1.25,
                "paired_differential_current" => pair_imbalance <= 0.20,
                "pf_current_density_proxy" => current_density <=
                    contract.engineering_current_density_limit_A_mm2 * 1.0e6,
                "pf_additive_peak_field_proxy" => additive_peak_field <=
                    contract.peak_conductor_field_limit_T,
                "pf_membrane_support_stress_proxy" => support_stress <=
                    contract.support_stress_limit_Pa,
            )
            merge!(record, Dict{String,Any}(
                "equilibrium" => Dict(
                    "magnetic_axis_r_m" => equilibrium["magnetic_axis_r_m"],
                    "magnetic_axis_z_m" => equilibrium["magnetic_axis_z_m"],
                    "minor_radius_m" => equilibrium["minor_radius_m"],
                    "q95" => equilibrium["q_95"],
                ),
                "response" => Dict(
                    "axis_r_delta_m" => axis_r_delta,
                    "axis_z_delta_m" => axis_z_delta,
                    "normalized_axis_displacement" => normalized_axis_displacement,
                    "q95_relative_change" => q95_relative_change,
                    "minor_radius_relative_change" => minor_relative_change,
                    "maximum_pf_current_A_turn" => maximum_current,
                    "pf_current_amplification" => current_amplification,
                    "maximum_paired_current_imbalance_fraction" => pair_imbalance,
                    "maximum_pf_current_density_A_m2" => current_density,
                    "additive_peak_field_proxy_T" => additive_peak_field,
                    "membrane_support_stress_proxy_Pa" => support_stress,
                ),
                "response_gates" => response_gates,
                "case_passed" => all(values(response_gates)),
            ))
        else
            record["response"] = nothing
            record["response_gates"] = Dict{String,Bool}()
            record["case_passed"] = false
        end
        push!(case_records, record)
    end

    perturbation_records = case_records[2:end]
    successful_records = filter(record -> record["solver_passed"], case_records)
    maximum_or_inf(key) = isempty(successful_records) ? Inf :
        maximum(Float64(record["response"][key]) for record in successful_records)
    overall_gates = Dict{String,Bool}(
        "nominal_static_equilibrium" => Bool(first(case_records)["solver_passed"]),
        "all_perturbed_static_equilibria" => all(record["solver_passed"]
            for record in perturbation_records),
        "axis_displacement_response" => all(record["case_passed"] &&
            record["response_gates"]["axis_displacement"] for record in case_records),
        "q95_response" => all(record["case_passed"] &&
            record["response_gates"]["q95_response"] for record in case_records),
        "minor_radius_response" => all(record["case_passed"] &&
            record["response_gates"]["minor_radius_response"] for record in case_records),
        "pf_current_amplification" => all(record["case_passed"] &&
            record["response_gates"]["pf_current_amplification"] for record in case_records),
        "paired_differential_current" => all(record["case_passed"] &&
            record["response_gates"]["paired_differential_current"] for record in case_records),
        "all_case_reduced_engineering_proxies" => all(record["case_passed"] &&
            record["response_gates"]["pf_current_density_proxy"] &&
            record["response_gates"]["pf_additive_peak_field_proxy"] &&
            record["response_gates"]["pf_membrane_support_stress_proxy"]
            for record in case_records),
    )
    all_passed = all(values(overall_gates))
    summary = Dict{String,Any}(
        "model" => "deterministic_static_freegs_pf_perturbation_suite_v1",
        "scenario_count" => length(case_records),
        "perturbation_case_count" => length(perturbation_records),
        "case_pass_count" => count(record -> record["case_passed"], case_records),
        "all_gates_passed" => all_passed,
        "gates" => overall_gates,
        "nominal" => Dict(
            "magnetic_axis_r_m" => nominal_axis_r,
            "magnetic_axis_z_m" => nominal_axis_z,
            "minor_radius_m" => nominal_minor,
            "q95" => nominal_q95,
            "maximum_pf_current_A_turn" => nominal_max_current,
        ),
        "worst_case" => Dict(
            "normalized_axis_displacement" => maximum_or_inf(
                "normalized_axis_displacement"),
            "q95_relative_change" => maximum_or_inf("q95_relative_change"),
            "minor_radius_relative_change" => maximum_or_inf(
                "minor_radius_relative_change"),
            "pf_current_amplification" => maximum_or_inf("pf_current_amplification"),
            "maximum_paired_current_imbalance_fraction" => maximum_or_inf(
                "maximum_paired_current_imbalance_fraction"),
            "maximum_pf_current_density_A_m2" => maximum_or_inf(
                "maximum_pf_current_density_A_m2"),
            "additive_peak_field_proxy_T" => maximum_or_inf(
                "additive_peak_field_proxy_T"),
            "membrane_support_stress_proxy_Pa" => maximum_or_inf(
                "membrane_support_stress_proxy_Pa"),
        ),
        "cases" => case_records,
        "disposition" => all_passed ?
            "eligible_for_dynamic_vertical_and_mhd_review" :
            "repair_pf_layout_or_control_authority_before_dynamic_review",
        "blocking_unknowns" => all_passed ? String[
            "linear vertical growth rate and conducting-structure response",
            "dynamic sensor actuator controller bandwidth and saturation",
            "ideal and resistive MHD spectrum",
            "PF mutual forces finite winding critical surface and quench",
            "transport exhaust disruptions and power balance",
        ] : String["failed deterministic static perturbation gates"],
        "claim_boundary" => _TOKAMAK_PF_STATIC_ROBUSTNESS_CLAIM_BOUNDARY,
    )
    runner_source_hash = bytes2hex(sha256(read(adapter.runner_path)))
    run_hash = canonical_hash(Dict(
        "evaluator" => "tokamak_pf_static_robustness_v1",
        "version" => "1.0.0",
        "input_hash" => genome.physics_hash,
        "runner_source_hash" => runner_source_hash,
        "configuration" => Dict(
            "coil_offset_m" => adapter.coil_offset_m,
            "plasma_current_fraction" => adapter.plasma_current_fraction,
            "axis_pressure_fraction" => adapter.axis_pressure_fraction,
        ),
        "summary" => summary,
    ))
    warnings = String[
        _TOKAMAK_PF_STATIC_ROBUSTNESS_CLAIM_BOUNDARY,
        "The FreeGS controller re-solves PF currents independently in every case; this measures static control authority, not an open-loop instability or feedback transient.",
        "The perturbation suite is deterministic and bounded, not a probability distribution or manufacturing acceptance test.",
        "Paired-current imbalance is reported explicitly because symmetric nominal currents and limited differential control demand are preferred engineering semantics.",
    ]
    pass_or_fail(value) = value ? :pass : :fail
    metrics = MetricResult[
        _tpr_metric("pf_static_robustness_summary", summary;
            status = pass_or_fail(all_passed), input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings, wall_time = elapsed),
        _tpr_metric("static_perturbation_cases_passed",
            summary["case_pass_count"];
            status = pass_or_fail(all_passed), input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings, wall_time = elapsed),
        _tpr_metric("worst_normalized_axis_displacement",
            summary["worst_case"]["normalized_axis_displacement"];
            status = pass_or_fail(overall_gates["axis_displacement_response"]),
            constraints = ["axis displacement <= 0.02 nominal minor radii"],
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, wall_time = elapsed),
        _tpr_metric("worst_pf_current_amplification",
            summary["worst_case"]["pf_current_amplification"];
            status = pass_or_fail(overall_gates["pf_current_amplification"]),
            constraints = ["maximum PF current <= 1.25 times nominal"],
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, wall_time = elapsed),
        _tpr_metric("worst_paired_current_imbalance_fraction",
            summary["worst_case"]["maximum_paired_current_imbalance_fraction"];
            status = pass_or_fail(overall_gates["paired_differential_current"]),
            constraints = ["paired differential current <= 0.20 nominal maximum PF current"],
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, wall_time = elapsed),
        _tpr_metric("pf_static_robustness_disposition", summary["disposition"];
            status = pass_or_fail(all_passed), input_hash = genome.physics_hash,
            run_hash = run_hash, warnings = warnings, wall_time = elapsed),
    ]
    for (id, message) in (
            ("vertical_mhd_stability_feasible",
                "no vertical growth rate or conducting-structure response was calculated"),
            ("dynamic_shape_controller_feasible",
                "no sensor actuator delay bandwidth or saturation transient was calculated"),
            ("ideal_and_resistive_mhd_stability_feasible",
                "no ideal or resistive MHD spectrum was calculated"))
        push!(metrics, _tpr_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings, [message]), wall_time = elapsed))
    end
    return EvaluationBundle("tokamak_pf_static_robustness_v1", genome.design_id,
        genome.family, 1, all_passed ? :pass : :fail, metrics, warnings,
        genome.physics_hash, run_hash, "physics_proxy")
end
