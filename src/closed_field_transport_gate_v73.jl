const CLOSED_FIELD_TRANSPORT_V73_CLAIM_BOUNDARY =
    "The v73 closed-field gate traces candidate-bound Biot-Savart field lines and applies an optimistic toroidal curvature-drift loss bound. It can falsify a candidate, but field-line closure or rotational transform alone cannot establish kinetic transport, MHD stability, or required energy confinement."

struct ClosedFieldTransportGateV73
    schema_version::String
    topology_hash::String
    realization_hash::String
    screen_evidence_hash::String
    completeness::Symbol
    conclusion::Symbol
    classification_code::String
    field_line_evidence::Dict{String,Any}
    drift_evidence::Dict{String,Any}
    missing_requirements::Vector{String}
    claim_boundary::String
    evidence_hash::String
end

function _v73_result(realization, screen, completeness, conclusion, code,
        field_lines, drift, missing)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "topology_hash" => realization.topology_hash,
        "realization_hash" => realization.realization_hash,
        "screen_evidence_hash" => screen.evidence_hash,
        "completeness" => String(completeness), "conclusion" => String(conclusion),
        "classification_code" => String(code), "field_line_evidence" => field_lines,
        "drift_evidence" => drift, "missing_requirements" => sort!(unique(missing)),
        "claim_boundary" => CLOSED_FIELD_TRANSPORT_V73_CLAIM_BOUNDARY)
    return ClosedFieldTransportGateV73("1.0.0", realization.topology_hash,
        realization.realization_hash, screen.evidence_hash, completeness, conclusion,
        String(code), Dict{String,Any}(field_lines), Dict{String,Any}(drift),
        sort!(unique(String.(missing))), CLOSED_FIELD_TRANSPORT_V73_CLAIM_BOUNDARY,
        canonical_hash(body))
end

_v73_angle_delta(next, previous) = mod(next - previous + pi, 2pi) - pi

function _v73_unit_field(cache, position, direction_sign)
    field = finite_filament_field_v71(cache, position)
    magnitude = norm(field)
    magnitude > 1.0e-10 && isfinite(magnitude) || return nothing
    return direction_sign .* field ./ magnitude
end

function _v73_rk4_field_step(cache, position, step_length, direction_sign)
    k1 = _v73_unit_field(cache, position, direction_sign); k1 === nothing && return nothing
    k2 = _v73_unit_field(cache, position .+ 0.5step_length .* k1, direction_sign)
    k2 === nothing && return nothing
    k3 = _v73_unit_field(cache, position .+ 0.5step_length .* k2, direction_sign)
    k3 === nothing && return nothing
    k4 = _v73_unit_field(cache, position .+ step_length .* k3, direction_sign)
    k4 === nothing && return nothing
    return position .+ step_length / 6 .* (k1 .+ 2k2 .+ 2k3 .+ k4)
end

function trace_closed_field_line_v73(realization::PhysicalDeviceRealizationV71,
        cache::FiniteFilamentFieldCacheV71, start_m;
        target_toroidal_turns::Real = 2.0, steps_per_turn::Integer = 360)
    region = _v71_primary_region(realization)
    region["geometry_class"] == "toroidal_volume_v1" || throw(ArgumentError(
        "closed-field trace requires toroidal geometry"))
    major = Float64(region["major_radius_m"]); minor = Float64(region["minor_radius_m"])
    position = Float64.(start_m)
    length(position) == 3 || throw(ArgumentError("field-line start must be 3D"))
    first_field = finite_filament_field_v71(cache, position)
    first_phi = atan(position[2], position[1])
    toroidal_unit = [-sin(first_phi), cos(first_phi), 0.0]
    direction_sign = dot(first_field, toroidal_unit) >= 0 ? 1.0 : -1.0
    radial = hypot(position[1], position[2])
    initial_rho = hypot(radial - major, position[3])
    previous_phi = first_phi
    previous_theta = atan(position[3], radial - major)
    accumulated_phi = 0.0; accumulated_theta = 0.0
    maximum_rho_excursion = 0.0; minimum_field = Inf; maximum_field = 0.0
    step_length = 2pi * major / steps_per_turn
    maximum_steps = ceil(Int, 4 * target_toroidal_turns * steps_per_turn)
    escaped = false; singular = false; completed_steps = 0
    trace = Vector{Vector{Float64}}([copy(position)])
    for step_index in 1:maximum_steps
        field_magnitude = norm(finite_filament_field_v71(cache, position))
        minimum_field = min(minimum_field, field_magnitude)
        maximum_field = max(maximum_field, field_magnitude)
        next_position = _v73_rk4_field_step(cache, position, step_length, direction_sign)
        if next_position === nothing
            singular = true; break
        end
        next_radial = hypot(next_position[1], next_position[2])
        rho = hypot(next_radial - major, next_position[3])
        maximum_rho_excursion = max(maximum_rho_excursion, abs(rho - initial_rho))
        if rho > minor
            escaped = true; position = next_position; completed_steps = step_index; break
        end
        next_phi = atan(next_position[2], next_position[1])
        next_theta = atan(next_position[3], next_radial - major)
        accumulated_phi += _v73_angle_delta(next_phi, previous_phi)
        accumulated_theta += _v73_angle_delta(next_theta, previous_theta)
        position = next_position; previous_phi = next_phi; previous_theta = next_theta
        completed_steps = step_index
        step_index % max(1, div(steps_per_turn, 24)) == 0 && push!(trace, copy(position))
        accumulated_phi >= 2pi * target_toroidal_turns && break
    end
    toroidal_turns = accumulated_phi / (2pi)
    poloidal_turns = accumulated_theta / (2pi)
    transform = abs(toroidal_turns) > 1.0e-9 ? poloidal_turns / toroidal_turns : 0.0
    completed = !escaped && !singular && toroidal_turns >= target_toroidal_turns
    return Dict{String,Any}(
        "start_m" => Float64.(start_m), "final_m" => position,
        "completed" => completed, "escaped" => escaped, "field_singular" => singular,
        "completed_steps" => completed_steps, "toroidal_turns" => toroidal_turns,
        "poloidal_turns" => poloidal_turns, "rotational_transform" => transform,
        "initial_minor_radius_m" => initial_rho,
        "maximum_minor_radius_excursion_m" => maximum_rho_excursion,
        "normalized_minor_radius_excursion" => maximum_rho_excursion / minor,
        "minimum_field_t" => minimum_field, "maximum_field_t" => maximum_field,
        "trace_m" => trace)
end

function evaluate_closed_field_transport_gate_v73(
        realization::PhysicalDeviceRealizationV71,
        screen::PhysicalDeviceScreenV71, parameter_binding;
        target_toroidal_turns::Real = 2.0, steps_per_turn::Integer = 360)
    binding = _v71_plain(parameter_binding)
    canonical_hash(binding) == realization.candidate_binding_hash ||
        throw(ArgumentError("v73 binding differs from physical realization"))
    screen.realization_hash == realization.realization_hash ||
        throw(ArgumentError("v73 screen differs from physical realization"))
    region = _v71_primary_region(realization)
    if region["geometry_class"] != "toroidal_volume_v1"
        return _v73_result(realization, screen, :incomplete, :unsupported,
            "not_applicable_non_toroidal_geometry",
            Dict("status" => "not_applicable"), Dict{String,Any}(),
            ["use_open_field_transport_gate_v72"])
    end
    cache = compile_finite_filament_field_cache_v71(realization)
    major = Float64(region["major_radius_m"]); minor = Float64(region["minor_radius_m"])
    starts = [[major + fraction * minor, 0.0, 0.0] for fraction in (0.15, 0.35, 0.55)]
    traces = [trace_closed_field_line_v73(realization, cache, start;
        target_toroidal_turns = target_toroidal_turns,
        steps_per_turn = steps_per_turn) for start in starts]
    all_completed = all(Bool(trace["completed"]) for trace in traces)
    any_escaped = any(Bool(trace["escaped"]) for trace in traces)
    maximum_excursion = maximum(Float64(trace["normalized_minor_radius_excursion"])
        for trace in traces)
    transforms = Float64[trace["rotational_transform"] for trace in traces]
    minimum_transform = minimum(abs.(transforms))
    field_line_status = any_escaped ? "fail" :
        (all_completed && maximum_excursion <= 0.15 && minimum_transform >= 0.02 ?
            "pass" : "fail")
    field_lines = Dict{String,Any}(
        "status" => field_line_status,
        "model_id" => "candidate_biot_savart_rk4_field_line_trace_v1",
        "target_toroidal_turns" => Float64(target_toroidal_turns),
        "steps_per_turn" => Int(steps_per_turn), "trace_count" => length(traces),
        "all_traces_completed" => all_completed, "any_trace_escaped" => any_escaped,
        "maximum_normalized_minor_radius_excursion" => maximum_excursion,
        "rotational_transform_values" => transforms,
        "minimum_absolute_rotational_transform" => minimum_transform,
        "minimum_required_absolute_rotational_transform" => 0.02,
        "traces" => traces, "field_cache_hash" => cache.cache_hash)
    elementary_charge = 1.602176634e-19
    thermal_energy_j = _v71_binding_number(binding, "target_ion_temperature_kev") *
        1.0e3 * elementary_charge
    optimistic_field = max(Float64(screen.field_evidence["maximum_field_t"]), 1.0e-6)
    optimistic_drift_speed = 2thermal_energy_j /
        (elementary_charge * optimistic_field * major)
    optimistic_exit_time = minor / optimistic_drift_speed
    required_tau = Float64(screen.plasma_evidence["required_energy_confinement_s"])
    drift = Dict{String,Any}(
        "status" => optimistic_exit_time < required_tau ? "fail" : "unknown",
        "model_id" => "optimistic_toroidal_curvature_grad_b_drift_bound_v1",
        "optimistic_field_t" => optimistic_field,
        "curvature_radius_m" => major, "available_minor_radius_m" => minor,
        "optimistic_vertical_drift_speed_m_s" => optimistic_drift_speed,
        "optimistic_uncompensated_drift_exit_time_s" => optimistic_exit_time,
        "required_energy_confinement_s" => required_tau,
        "exit_to_required_ratio" => optimistic_exit_time / required_tau,
        "rotational_transform_credit" => field_line_status == "pass" ?
            minimum_transform : 0.0)
    if field_line_status == "fail" && optimistic_exit_time < required_tau
        classification = any_escaped ? "candidate_field_lines_escape_toroidal_volume" :
            minimum_transform < 0.02 ?
                "insufficient_rotational_transform_for_curvature_drift_cancellation" :
                "excessive_flux_surface_radial_excursion"
        return _v73_result(realization, screen, :complete, :fail,
            classification,
            field_lines, drift, String[])
    end
    return _v73_result(realization, screen, :incomplete, :unknown,
        "closed_field_geometry_requires_kinetic_transport_and_stability",
        field_lines, drift,
        ["candidate_bound_closed_field_kinetic_transport",
            "finite_pressure_equilibrium", "mhd_and_microstability_evidence"])
end

function closed_field_transport_gate_to_dict_v73(item::ClosedFieldTransportGateV73)
    return Dict{String,Any}(
        "schema_version" => item.schema_version, "topology_hash" => item.topology_hash,
        "realization_hash" => item.realization_hash,
        "screen_evidence_hash" => item.screen_evidence_hash,
        "completeness" => String(item.completeness),
        "conclusion" => String(item.conclusion),
        "classification_code" => item.classification_code,
        "field_line_evidence" => item.field_line_evidence,
        "drift_evidence" => item.drift_evidence,
        "missing_requirements" => item.missing_requirements,
        "claim_boundary" => item.claim_boundary, "evidence_hash" => item.evidence_hash)
end
