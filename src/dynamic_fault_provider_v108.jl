const V108_PROTOCOL_ID = "fusionconceptai-v108-dynamic-control-fault-provider-20260829"

const DYNAMIC_FAULT_PROVIDER_V108_CLAIM_BOUNDARY =
    "v108 executes a candidate-bound reduced time-domain control and protection model for " *
    "all fault classes declared by the v105 assembly. Controller coordinates are explicit " *
    "design inputs and receive no metric credit. A scenario failure rejects that controller " *
    "overlay. A pass is limited to the reduced state-space and lumped protection models; it " *
    "is not complete nonlinear plasma, thermal-hydraulic, quench, engineering, validation, " *
    "or whole-device evidence."

const V108_CONTROLLER_GAINS = [(1.5, 0.5), (3.0, 1.0), (6.0, 2.0), (12.0, 4.0)]

function generate_controller_overlays_v108(assembly_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    design = Dict{String,Any}(assembly["physical_design"])
    fault = Dict{String,Any}(design["control_fault"])
    overlays = Dict{String,Any}[]
    for (index, (kp, ki)) in enumerate(V108_CONTROLLER_GAINS)
        physical = Dict{String,Any}(
            "schema_version" => "1.0.0", "protocol_id" => V108_PROTOCOL_ID,
            "controller_sequence_index" => index,
            "proportional_gain" => kp, "integral_gain_per_s" => ki,
            "actuator_authority_normalized" => 1.0,
            "actuator_output_limit_normalized" => 1.0,
            "controller_time_step_s" => fault["controller_time_step_s"],
            "sensor_latency_s" => fault["maximum_sensor_latency_s"],
            "actuator_time_constant_s" => fault["maximum_actuator_latency_s"],
            "required_fault_scenarios" => sort!(String.(fault["required_fault_scenarios"])),
            "maximum_normalized_excursion" => 0.15,
            "maximum_final_normalized_error" => 0.01,
            "basis_direct_metric_credit" => false,
            "identity_fields_used_for_generation" => false,
            "claim_boundary" => DYNAMIC_FAULT_PROVIDER_V108_CLAIM_BOUNDARY)
        physical["controller_design_hash"] = canonical_hash(physical)
        body = Dict{String,Any}(
            "physical_design_hash" => assembly["physical_design_hash"],
            "controller_design" => physical,
            "controller_design_hash" => physical["controller_design_hash"],
            "candidate_state" => "controller_overlay_proposal",
            "physical_pass_credit" => false, "validation_credit" => false,
            "unsupported_candidate_classification_used" => false)
        body["overlay_hash"] = canonical_hash(body); push!(overlays, body)
    end
    overlays
end

function _v108_control_scenario(name)
    name == "single_pf_coil_trip" && return (growth = 0.5, disturbance = 0.03,
        initial = 0.0)
    name == "density_limit_excursion" && return (growth = 0.0, disturbance = 0.0,
        initial = 0.10)
    name == "vertical_displacement_event" && return (growth = 2.0, disturbance = 0.0,
        initial = 0.02)
    throw(ArgumentError("not a feedback state-space scenario: $name"))
end

function _v108_state_space(controller, scenario; dt, method)
    duration = 2.0; steps = round(Int, duration / dt)
    latency_steps = max(1, round(Int, Float64(controller["sensor_latency_s"]) / dt))
    history = fill(Float64(scenario.initial), latency_steps)
    x = Float64(scenario.initial); integral = 0.0; actuator = 0.0
    kp = Float64(controller["proportional_gain"])
    ki = Float64(controller["integral_gain_per_s"])
    authority = Float64(controller["actuator_authority_normalized"])
    limit = Float64(controller["actuator_output_limit_normalized"])
    tau = Float64(controller["actuator_time_constant_s"])
    peak = abs(x); peak_actuator = 0.0
    for _ in 1:steps
        measured = popfirst!(history); push!(history, x)
        command(z) = clamp(kp * measured + ki * z, -limit, limit)
        dx(state, control) = scenario.growth * state - authority * control +
            scenario.disturbance
        du(control, z) = (command(z) - control) / tau
        if method == "explicit_euler"
            xdot = dx(x, actuator); udot = du(actuator, integral)
            x += dt * xdot; actuator += dt * udot; integral += dt * measured
        elseif method == "midpoint_rk2"
            xdot = dx(x, actuator); udot = du(actuator, integral)
            xmid = x + 0.5dt * xdot
            umid = actuator + 0.5dt * udot
            zmid = integral + 0.5dt * measured
            x += dt * dx(xmid, umid)
            actuator += dt * du(umid, zmid)
            integral += dt * measured
        else
            throw(ArgumentError("unknown v108 integration method"))
        end
        peak = max(peak, abs(x)); peak_actuator = max(peak_actuator, abs(actuator))
    end
    Dict{String,Any}(
        "peak_normalized_excursion" => peak,
        "final_normalized_error" => abs(x),
        "peak_actuator_fraction" => peak_actuator,
        "time_step_s" => dt, "duration_s" => duration,
        "method" => String(method))
end

function _v108_control_result(name, controller)
    scenario = _v108_control_scenario(name)
    dt = Float64(controller["controller_time_step_s"])
    primary = _v108_state_space(controller, scenario; dt = dt,
        method = "explicit_euler")
    verification = _v108_state_space(controller, scenario; dt = 0.5dt,
        method = "midpoint_rk2")
    peak_difference = abs(Float64(primary["peak_normalized_excursion"]) -
        Float64(verification["peak_normalized_excursion"])) /
        max(Float64(verification["peak_normalized_excursion"]), 1e-12)
    final_difference = abs(Float64(primary["final_normalized_error"]) -
        Float64(verification["final_normalized_error"])) /
        max(Float64(verification["final_normalized_error"]), 1e-12)
    physical_pass = Float64(primary["peak_normalized_excursion"]) <=
        Float64(controller["maximum_normalized_excursion"]) &&
        Float64(primary["final_normalized_error"]) <=
            Float64(controller["maximum_final_normalized_error"]) &&
        Float64(primary["peak_actuator_fraction"]) <=
            Float64(controller["actuator_output_limit_normalized"]) * 1.01
    numerical_pass = peak_difference <= 0.02 && final_difference <= 0.02
    Dict{String,Any}(
        "scenario_id" => String(name),
        "status" => physical_pass && numerical_pass ? "pass" : "fail",
        "physical_gate_pass" => physical_pass,
        "numerical_vvuq_pass" => numerical_pass,
        "primary" => primary, "verification" => verification,
        "peak_relative_difference" => peak_difference,
        "final_relative_difference" => final_difference,
        "verification_type" => "step_refinement_and_independent_integrator")
end

function _v108_coolant_result(design)
    thermal = Dict{String,Any}(design["thermal_cycle"])
    fault = Dict{String,Any}(design["control_fault"])
    flow = 0.5Float64(thermal["mass_flow_kg_s"])
    cp = Float64(thermal["specific_heat_j_kg_k"])
    inlet = Float64(thermal["inlet_temperature_k"])
    heat = Float64(thermal["recoverable_heat_input_w"])
    outlet = inlet + heat / (flow * cp)
    response_time = Float64(fault["maximum_sensor_latency_s"]) +
        Float64(fault["maximum_actuator_latency_s"])
    passed = outlet <= 973.0 && response_time <= 0.01
    Dict{String,Any}(
        "scenario_id" => "loss_of_coolant_flow", "status" => passed ? "pass" : "fail",
        "remaining_flow_fraction" => 0.5, "pre_shutdown_outlet_temperature_k" => outlet,
        "maximum_allowed_outlet_temperature_k" => 973.0,
        "shutdown_response_time_s" => response_time,
        "lumped_transient_only" => true)
end

function _v108_quench_result(design, source_candidate)
    point = Dict{String,Any}(design["operating_point"])
    conductor = only(item for item in Dict{String,Any}.(
        design["finite_conductor"]["coil_systems"]) if item["role"] == "poloidal_field")
    engineering = Dict{String,Any}(source_candidate["engineering_prefilter"])
    peak_field = Float64(engineering["metrics"]["additive_peak_field_t"])
    current = Float64(conductor["maximum_current_a_turn"])
    area = Float64(conductor["minimum_conductor_area_m2"])
    volume = 2pi * Float64(point["major_radius_m"]) * area
    magnetic_energy = peak_field^2 / (2 * 4pi * 1e-7) * volume
    inductance = 2magnetic_energy / current^2
    voltage_limit = Float64(design["finite_conductor"]["maximum_terminal_voltage_v"])
    resistance = voltage_limit / current
    time_constant = inductance / resistance
    detection = Float64(design["finite_conductor"]["quench_detection_time_s"])
    final_fraction = exp(-(2.0 - detection) / time_constant)
    deposited = magnetic_energy * (1 - exp(-2detection / time_constant))
    temperature_rise = deposited / (volume * 8000.0 * 400.0)
    passed = voltage_limit <= 20000.0 && final_fraction <= 0.01 &&
        temperature_rise <= 100.0
    Dict{String,Any}(
        "scenario_id" => "quench", "status" => passed ? "pass" : "fail",
        "magnetic_energy_proxy_j" => magnetic_energy,
        "equivalent_inductance_h" => inductance,
        "dump_resistance_ohm" => resistance,
        "current_decay_time_constant_s" => time_constant,
        "final_current_fraction_at_2s" => final_fraction,
        "conductor_temperature_rise_proxy_k" => temperature_rise,
        "terminal_voltage_v" => voltage_limit,
        "lumped_protection_only" => true)
end

function execute_dynamic_fault_provider_v108(assembly_raw, overlay_raw, source_candidate_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    overlay = Dict{String,Any}(_v93_plain(overlay_raw))
    candidate = Dict{String,Any}(_v93_plain(source_candidate_raw))
    assembly["physical_design_hash"] == overlay["physical_design_hash"] ||
        throw(ArgumentError("controller overlay assembly binding mismatch"))
    controller = Dict{String,Any}(overlay["controller_design"])
    design = Dict{String,Any}(assembly["physical_design"])
    required = Set(String.(design["control_fault"]["required_fault_scenarios"]))
    declared = Set(String.(controller["required_fault_scenarios"]))
    required == declared || throw(ArgumentError("controller fault scenario contract mismatch"))
    results = Dict{String,Any}[
        _v108_control_result("single_pf_coil_trip", controller),
        _v108_control_result("density_limit_excursion", controller),
        _v108_control_result("vertical_displacement_event", controller),
        _v108_coolant_result(design),
        _v108_quench_result(design, candidate),
    ]
    Set(String(item["scenario_id"]) for item in results) == required ||
        throw(ArgumentError("v108 did not execute exactly the declared fault scenarios"))
    passed = all(item -> item["status"] == "pass", results)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V108_PROTOCOL_ID,
        "physical_design_hash" => assembly["physical_design_hash"],
        "controller_design_hash" => overlay["controller_design_hash"],
        "status" => passed ? "pass" : "fail",
        "candidate_state" => passed ? "dynamic_fault_screen_survivor" :
            "dynamic_fault_screen_reject",
        "scenario_count" => length(results),
        "scenario_pass_count" => count(item -> item["status"] == "pass", results),
        "failed_scenarios" => String[item["scenario_id"] for item in results if
            item["status"] == "fail"],
        "scenario_results" => results,
        "whole_device_pass_credit" => false, "validation_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "identity_fields_used_for_routing" => false,
        "evidence_ceiling" => "candidate_bound_reduced_time_domain_and_lumped_fault_screen",
        "claim_boundary" => DYNAMIC_FAULT_PROVIDER_V108_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body)
    body
end

function run_dynamic_fault_campaign_v108(project_root::AbstractString)
    root = abspath(project_root)
    v107 = run_whole_device_provider_dag_v107(root)
    generation, assemblies = run_whole_device_assembly_generation_v105(root)
    assembly_by_hash = Dict(String(item["physical_design_hash"]) => item for item in assemblies)
    candidates = _v104_load_v100_candidates(root)
    candidate_by_hash = Dict(String(item["result_hash"]) => item for item in values(candidates))
    rows = Dict{String,Any}[]
    for upstream in v107["rows"]
        upstream["candidate_state"] == "high_fidelity_pending" || continue
        assembly = assembly_by_hash[String(upstream["physical_design_hash"])]
        candidate = candidate_by_hash[String(assembly["source_candidate_result_hash"])]
        for overlay in generate_controller_overlays_v108(assembly)
            push!(rows, execute_dynamic_fault_provider_v108(assembly, overlay, candidate))
        end
    end
    histogram = Dict{String,Int}(); blockers = Dict{String,Int}()
    for row in rows
        state = String(row["candidate_state"])
        histogram[state] = get(histogram, state, 0) + 1
        for scenario in String.(row["failed_scenarios"])
            blockers[scenario] = get(blockers, scenario, 0) + 1
        end
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V108_PROTOCOL_ID,
        "status" => "complete", "source_v107_acceptance_hash" => v107["acceptance_hash"],
        "source_v105_acceptance_hash" => generation["acceptance_hash"],
        "source_assembly_count" => length(v107["rows"]),
        "controller_overlay_count" => length(rows),
        "candidate_state_histogram" => Dict(sort!(collect(histogram))),
        "dynamic_fault_screen_survivor_count" => count(row -> row["status"] == "pass", rows),
        "dynamic_fault_screen_reject_count" => count(row -> row["status"] == "fail", rows),
        "blocker_histogram" => Dict(sort!(collect(blockers))),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "whole_device_pass_count" => 0, "whole_device_credible_count" => 0,
        "validation_pass_count" => 0,
        "complete_dynamic_fault_obligation_credit" => false,
        "high_cost_expansion_authorized" => false,
        "identity_fields_used_for_routing" => false,
        "rows" => rows, "claim_boundary" => DYNAMIC_FAULT_PROVIDER_V108_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end
