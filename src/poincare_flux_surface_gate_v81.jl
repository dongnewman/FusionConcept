const POINCARE_FLUX_SURFACE_V81_CLAIM_BOUNDARY =
    "v81 traces candidate-bound Biot-Savart field lines to a fixed toroidal Poincare section, removes bounded noncircular surface shape with a fourth-order Fourier fit, and can falsify escape, stochastic radial spread, secular drift, insufficient transform, or loss of nested ordering. Survival remains unknown and grants no finite-pressure equilibrium, kinetic transport, MHD, particle-retention, or device-feasibility credit."

struct PoincareFluxSurfaceGateV81
    schema_version::String
    realization_hash::String
    screen_evidence_hash::String
    completeness::Symbol
    conclusion::Symbol
    classification_code::String
    poincare_evidence::Dict{String,Any}
    missing_requirements::Vector{String}
    claim_boundary::String
    evidence_hash::String
end

function _v81_result(realization, screen, completeness, conclusion, code,
        evidence, missing)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "realization_hash" => realization.realization_hash,
        "screen_evidence_hash" => screen.evidence_hash,
        "completeness" => String(completeness),
        "conclusion" => String(conclusion),
        "classification_code" => String(code),
        "poincare_evidence" => evidence,
        "missing_requirements" => sort!(unique(String.(missing))),
        "claim_boundary" => POINCARE_FLUX_SURFACE_V81_CLAIM_BOUNDARY)
    return PoincareFluxSurfaceGateV81("1.0.0", realization.realization_hash,
        screen.evidence_hash, completeness, conclusion, String(code),
        Dict{String,Any}(evidence), sort!(unique(String.(missing))),
        POINCARE_FLUX_SURFACE_V81_CLAIM_BOUNDARY, canonical_hash(body))
end

function _v81_boundary_frame(region, candidate_boundary, position)
    radial = hypot(position[1], position[2])
    phi = atan(position[2], position[1])
    if candidate_boundary === nothing
        major = Float64(region["major_radius_m"])
        minor = Float64(region["minor_radius_m"])
        axis_r = major; axis_z = 0.0; minor_r = minor; minor_z = minor
        model = "legacy_circular_region_boundary_v1"
    else
        boundary = _v71_plain(candidate_boundary)
        major = Float64(boundary["major_radius_m"])
        minor_r = Float64(boundary["minor_radius_r_m"])
        minor_z = Float64(boundary["minor_radius_z_m"])
        nfp = Int(boundary["field_periods"])
        axis_r = major + Float64(boundary["helical_axis_r_m"]) *
            cos(nfp * phi)
        axis_z = Float64(boundary["helical_axis_z_m"]) * sin(nfp * phi)
        model = String(get(boundary, "boundary_model",
            "candidate_periodic_elliptic_boundary_v1"))
    end
    delta_r = radial - axis_r; delta_z = Float64(position[3]) - axis_z
    normalized_r = delta_r / minor_r; normalized_z = delta_z / minor_z
    return (phi = phi, radial = radial, axis_r = axis_r, axis_z = axis_z,
        delta_r = delta_r, delta_z = delta_z,
        minor_radius_m = hypot(delta_r, delta_z),
        normalized_minor_radius = hypot(normalized_r, normalized_z),
        theta = atan(normalized_z, normalized_r), boundary_model = model)
end

function _v81_boundary_start_point(region, candidate_boundary, fraction)
    if candidate_boundary === nothing
        return [Float64(region["major_radius_m"]) +
            Float64(fraction) * Float64(region["minor_radius_m"]), 0.0, 0.0]
    end
    boundary = _v71_plain(candidate_boundary)
    axis_r = Float64(boundary["major_radius_m"]) +
        Float64(boundary["helical_axis_r_m"])
    return [axis_r + Float64(fraction) *
        Float64(boundary["minor_radius_r_m"]), 0.0, 0.0]
end

function _v81_axis_reference_at(axis_reference, phi)
    phases = Float64.(axis_reference["phase_rad"])
    radii = Float64.(axis_reference["radius_m"])
    heights = Float64.(axis_reference["z_m"])
    length(phases) >= 2 || throw(ArgumentError(
        "v81 magnetic-axis reference requires at least two samples"))
    phase = mod(Float64(phi), 2pi)
    phase == 0.0 && Float64(phi) > 0.0 && (phase = 2pi)
    upper = searchsortedfirst(phases, phase)
    upper <= 1 && return (radius_m = radii[1], z_m = heights[1])
    upper > length(phases) && return (radius_m = radii[end], z_m = heights[end])
    lower = upper - 1
    span = phases[upper] - phases[lower]
    alpha = span > 0 ? (phase - phases[lower]) / span : 0.0
    return (radius_m = (1.0 - alpha) * radii[lower] + alpha * radii[upper],
        z_m = (1.0 - alpha) * heights[lower] + alpha * heights[upper])
end

function _v81_analysis_frame(region, candidate_boundary, position,
        axis_reference)
    boundary_frame = _v81_boundary_frame(region, candidate_boundary, position)
    axis_reference === nothing && return merge(boundary_frame,
        (boundary_normalized_minor_radius =
            boundary_frame.normalized_minor_radius,))
    axis = _v81_axis_reference_at(axis_reference, boundary_frame.phi)
    if candidate_boundary === nothing
        minor_r = Float64(region["minor_radius_m"])
        minor_z = minor_r
    else
        boundary = _v71_plain(candidate_boundary)
        minor_r = Float64(boundary["minor_radius_r_m"])
        minor_z = Float64(boundary["minor_radius_z_m"])
    end
    delta_r = boundary_frame.radial - axis.radius_m
    delta_z = Float64(position[3]) - axis.z_m
    normalized_r = delta_r / minor_r; normalized_z = delta_z / minor_z
    return merge(boundary_frame, (axis_r = axis.radius_m, axis_z = axis.z_m,
        delta_r = delta_r, delta_z = delta_z,
        minor_radius_m = hypot(delta_r, delta_z),
        normalized_minor_radius = hypot(normalized_r, normalized_z),
        theta = atan(normalized_z, normalized_r),
        boundary_normalized_minor_radius =
            boundary_frame.normalized_minor_radius))
end

function _v81_trace_axis_reference(realization, cache, start_m;
        steps_per_turn::Integer = 80, candidate_boundary = nothing)
    region = _v71_primary_region(realization)
    major = Float64(region["major_radius_m"])
    position = Float64.(start_m)
    first_frame = _v81_boundary_frame(region, candidate_boundary, position)
    first_field = finite_filament_field_v71(cache, position)
    toroidal_unit = [-sin(first_frame.phi), cos(first_frame.phi), 0.0]
    direction_sign = dot(first_field, toroidal_unit) >= 0 ? 1.0 : -1.0
    step_length = 2pi * major / Int(steps_per_turn)
    previous_phi = first_frame.phi; accumulated_phi = 0.0
    phases = Float64[0.0]; radii = Float64[first_frame.radial]
    heights = Float64[Float64(position[3])]
    escaped = false; singular = false; completed_steps = 0
    closure_position = nothing
    for step_index in 1:4Int(steps_per_turn)
        next_position = _v73_rk4_field_step(cache, position, step_length,
            direction_sign)
        if next_position === nothing
            singular = true; break
        end
        next_boundary = _v81_boundary_frame(region, candidate_boundary,
            next_position)
        if next_boundary.normalized_minor_radius > 1.0
            escaped = true; completed_steps = step_index; break
        end
        phi_delta = _v73_angle_delta(next_boundary.phi, previous_phi)
        prior_phi = accumulated_phi
        accumulated_phi += phi_delta
        if phi_delta > 1.0e-12 && accumulated_phi >= 2pi
            alpha = clamp((2pi - prior_phi) / phi_delta, 0.0, 1.0)
            crossing = position .+ alpha .* (next_position .- position)
            crossing_frame = _v81_boundary_frame(region, candidate_boundary,
                crossing)
            push!(phases, 2pi); push!(radii, crossing_frame.radial)
            push!(heights, Float64(crossing[3]))
            closure_position = crossing; completed_steps = step_index
            break
        elseif phi_delta > 1.0e-12
            push!(phases, accumulated_phi); push!(radii, next_boundary.radial)
            push!(heights, Float64(next_position[3]))
        end
        position = next_position; previous_phi = next_boundary.phi
        completed_steps = step_index
    end
    complete = closure_position !== nothing && !escaped && !singular
    closure_residual = if complete
        start_frame = _v81_boundary_frame(region, candidate_boundary, start_m)
        end_frame = _v81_boundary_frame(region, candidate_boundary,
            closure_position)
        if candidate_boundary === nothing
            minor_r = Float64(region["minor_radius_m"]); minor_z = minor_r
        else
            boundary = _v71_plain(candidate_boundary)
            minor_r = Float64(boundary["minor_radius_r_m"])
            minor_z = Float64(boundary["minor_radius_z_m"])
        end
        hypot((end_frame.radial - start_frame.radial) / minor_r,
            (Float64(closure_position[3]) - Float64(start_m[3])) / minor_z)
    else
        Inf
    end
    return Dict{String,Any}(
        "status" => complete ? "complete" : "incomplete",
        "start_m" => Float64.(start_m), "phase_rad" => phases,
        "radius_m" => radii, "z_m" => heights,
        "closure_position_m" => closure_position,
        "closure_residual_normalized" => closure_residual,
        "escaped" => escaped, "field_singular" => singular,
        "completed_steps" => completed_steps,
        "steps_per_turn" => Int(steps_per_turn))
end

function _v81_locate_periodic_magnetic_axis(realization, cache,
        candidate_boundary; steps_per_turn::Integer = 80,
        refinement_levels::Integer = 4,
        maximum_closure_residual::Real = 0.04)
    region = _v71_primary_region(realization)
    candidate_boundary === nothing && return Dict{String,Any}(
        "status" => "not_applicable_legacy_boundary",
        "axis_reference" => nothing, "candidate_bound" => false)
    boundary = _v71_plain(candidate_boundary)
    center = _v81_boundary_start_point(region, boundary, 0.0)
    minor_r = Float64(boundary["minor_radius_r_m"])
    minor_z = Float64(boundary["minor_radius_z_m"])
    best_start = copy(center); best_reference = nothing; best_score = Inf
    radial_step = 0.20 * minor_r; vertical_step = 0.20 * minor_z
    evaluation_count = 0; trace_rows = Dict{String,Any}[]
    for level in 1:Int(refinement_levels)
        level_best_start = best_start; level_best_reference = best_reference
        level_best_score = best_score
        for radial_direction in (-1.0, 0.0, 1.0),
                vertical_direction in (-1.0, 0.0, 1.0)
            start = [best_start[1] + radial_direction * radial_step,
                0.0, best_start[3] + vertical_direction * vertical_step]
            boundary_frame = _v81_boundary_frame(region, boundary, start)
            boundary_frame.normalized_minor_radius <= 0.65 || continue
            reference = _v81_trace_axis_reference(realization, cache, start;
                steps_per_turn = steps_per_turn,
                candidate_boundary = boundary)
            evaluation_count += 1
            score = Float64(reference["closure_residual_normalized"])
            push!(trace_rows, Dict{String,Any}(
                "level" => level, "start_m" => start,
                "status" => reference["status"],
                "closure_residual_normalized" =>
                    isfinite(score) ? score : nothing))
            if score < level_best_score
                level_best_score = score; level_best_start = start
                level_best_reference = reference
            end
        end
        best_start = level_best_start; best_reference = level_best_reference
        best_score = level_best_score
        radial_step *= 0.5; vertical_step *= 0.5
    end
    located = best_reference !== nothing && isfinite(best_score) &&
        best_score <= Float64(maximum_closure_residual)
    body = Dict{String,Any}(
        "status" => located ? "located" : "not_located",
        "candidate_bound" => true, "section_phi_rad" => 0.0,
        "axis_start_m" => located ? best_start : nothing,
        "closure_residual_normalized" =>
            isfinite(best_score) ? best_score : nothing,
        "maximum_closure_residual" => Float64(maximum_closure_residual),
        "evaluation_count" => evaluation_count,
        "refinement_levels" => Int(refinement_levels),
        "steps_per_turn" => Int(steps_per_turn),
        "axis_reference" => located ? best_reference : nothing,
        "search_trace" => trace_rows,
        "feasibility_credit" => false)
    body["axis_evidence_hash"] = canonical_hash(body)
    return body
end

function _v81_axis_start_point(region, candidate_boundary, axis_reference,
        fraction)
    axis_reference === nothing && return _v81_boundary_start_point(region,
        candidate_boundary, fraction)
    axis = _v81_axis_reference_at(axis_reference, 0.0)
    outer = _v81_boundary_start_point(region, candidate_boundary, 1.0)
    return [axis.radius_m + Float64(fraction) * (outer[1] - axis.radius_m),
        0.0, axis.z_m + Float64(fraction) * (outer[3] - axis.z_m)]
end

function _v81_trace_to_section(realization::PhysicalDeviceRealizationV71,
        cache::FiniteFilamentFieldCacheV71, start_m;
        target_toroidal_turns::Integer = 128, steps_per_turn::Integer = 180,
        candidate_boundary = nothing, axis_reference = nothing)
    region = _v71_primary_region(realization)
    region["geometry_class"] == "toroidal_volume_v1" || throw(ArgumentError(
        "v81 Poincare trace requires toroidal geometry"))
    major = Float64(region["major_radius_m"])
    position = Float64.(start_m)
    first_frame = _v81_analysis_frame(region, candidate_boundary, position,
        axis_reference)
    first_phi = first_frame.phi
    first_field = finite_filament_field_v71(cache, position)
    toroidal_unit = [-sin(first_phi), cos(first_phi), 0.0]
    direction_sign = dot(first_field, toroidal_unit) >= 0 ? 1.0 : -1.0
    previous_phi = first_phi
    previous_theta = first_frame.theta
    accumulated_phi = 0.0
    accumulated_theta = 0.0
    next_crossing = 2pi
    crossing_index = 1
    step_length = 2pi * major / steps_per_turn
    maximum_steps = 4 * target_toroidal_turns * steps_per_turn
    escaped = false
    singular = false
    minimum_field = Inf
    maximum_field = 0.0
    crossings = Dict{String,Any}[]
    completed_steps = 0
    for step_index in 1:maximum_steps
        field_magnitude = norm(finite_filament_field_v71(cache, position))
        minimum_field = min(minimum_field, field_magnitude)
        maximum_field = max(maximum_field, field_magnitude)
        next_position = _v73_rk4_field_step(cache, position, step_length,
            direction_sign)
        if next_position === nothing
            singular = true
            break
        end
        next_boundary_frame = _v81_boundary_frame(region, candidate_boundary,
            next_position)
        if next_boundary_frame.normalized_minor_radius > 1.0
            escaped = true
            position = next_position
            completed_steps = step_index
            break
        end
        next_frame = _v81_analysis_frame(region, candidate_boundary,
            next_position, axis_reference)
        next_phi = next_frame.phi; next_theta = next_frame.theta
        phi_delta = _v73_angle_delta(next_phi, previous_phi)
        theta_delta = _v73_angle_delta(next_theta, previous_theta)
        prior_accumulated_phi = accumulated_phi
        accumulated_phi += phi_delta
        accumulated_theta += theta_delta
        if phi_delta > 1.0e-12
            while accumulated_phi >= next_crossing &&
                    crossing_index <= target_toroidal_turns
                alpha = clamp((next_crossing - prior_accumulated_phi) /
                    phi_delta, 0.0, 1.0)
                crossing = position .+ alpha .* (next_position .- position)
                frame = _v81_analysis_frame(region, candidate_boundary,
                    crossing, axis_reference)
                push!(crossings, Dict{String,Any}(
                    "turn_index" => crossing_index,
                    "position_m" => crossing,
                    "section_x_m" => frame.delta_r,
                    "section_z_m" => frame.delta_z,
                    "minor_radius_m" => frame.minor_radius_m,
                    "normalized_minor_radius" =>
                        frame.normalized_minor_radius,
                    "boundary_normalized_minor_radius" =>
                        frame.boundary_normalized_minor_radius,
                    "poloidal_angle_rad" => frame.theta))
                crossing_index += 1
                next_crossing = 2pi * crossing_index
            end
        end
        position = next_position
        previous_phi = next_phi
        previous_theta = next_theta
        completed_steps = step_index
        crossing_index > target_toroidal_turns && break
    end
    toroidal_turns = accumulated_phi / (2pi)
    poloidal_turns = accumulated_theta / (2pi)
    transform = abs(toroidal_turns) > 1.0e-9 ?
        poloidal_turns / toroidal_turns : 0.0
    return Dict{String,Any}(
        "start_m" => Float64.(start_m),
        "completed" => !escaped && !singular &&
            length(crossings) == target_toroidal_turns,
        "escaped" => escaped, "field_singular" => singular,
        "completed_steps" => completed_steps,
        "toroidal_turns" => toroidal_turns,
        "poloidal_turns" => poloidal_turns,
        "rotational_transform" => transform,
        "boundary_frame_model" => first_frame.boundary_model,
        "periodic_magnetic_axis_used" => axis_reference !== nothing,
        "minimum_field_t" => minimum_field,
        "maximum_field_t" => maximum_field,
        "crossing_count" => length(crossings),
        "crossings" => crossings)
end

function _v81_surface_fit(crossings; fourier_order::Integer = 4,
        bin_count::Integer = 16)
    theta = Float64[item["poloidal_angle_rad"] for item in crossings]
    radius = Float64[item["normalized_minor_radius"] for item in crossings]
    turns = Float64[item["turn_index"] for item in crossings]
    count = length(radius)
    column_count = 1 + 2fourier_order
    if count < column_count + 2
        return Dict{String,Any}(
            "status" => "insufficient", "crossing_count" => count,
            "required_crossing_count" => column_count + 2)
    end
    design = ones(Float64, count, column_count)
    column = 2
    for harmonic in 1:fourier_order
        design[:, column] .= cos.(harmonic .* theta)
        design[:, column + 1] .= sin.(harmonic .* theta)
        column += 2
    end
    coefficients = design \ radius
    fitted = design * coefficients
    residuals = radius .- fitted
    centered_turns = turns .- sum(turns) / count
    slope_denominator = sum(abs2, centered_turns)
    drift_slope = slope_denominator > 0 ?
        dot(centered_turns, residuals) / slope_denominator : 0.0
    bins = [Float64[] for _ in 1:bin_count]
    for (angle, value) in zip(theta, radius)
        normalized_angle = mod(angle, 2pi) / (2pi)
        bin_index = clamp(floor(Int, normalized_angle * bin_count) + 1,
            1, bin_count)
        push!(bins[bin_index], value)
    end
    repeated_bins = [values for values in bins if length(values) >= 2]
    bin_spreads = [maximum(values) - minimum(values) for values in repeated_bins]
    prediction_angles = collect(range(-pi, pi; length = 65))[1:end-1]
    prediction_design = ones(Float64, length(prediction_angles), column_count)
    column = 2
    for harmonic in 1:fourier_order
        prediction_design[:, column] .= cos.(harmonic .* prediction_angles)
        prediction_design[:, column + 1] .= sin.(harmonic .* prediction_angles)
        column += 2
    end
    return Dict{String,Any}(
        "status" => "complete", "crossing_count" => count,
        "fourier_order" => Int(fourier_order),
        "coefficients" => coefficients,
        "residual_rms" => sqrt(sum(abs2, residuals) / count),
        "maximum_absolute_residual" => maximum(abs.(residuals)),
        "secular_residual_drift_per_toroidal_turn" => drift_slope,
        "repeated_poloidal_bin_count" => length(repeated_bins),
        "maximum_repeated_bin_radial_spread" =>
            isempty(bin_spreads) ? Inf : maximum(bin_spreads),
        "minimum_normalized_minor_radius" => minimum(radius),
        "maximum_normalized_minor_radius" => maximum(radius),
        "mean_normalized_minor_radius" => sum(radius) / count,
        "prediction_angles_rad" => prediction_angles,
        "predicted_normalized_radius" => prediction_design * coefficients)
end

function evaluate_poincare_flux_surface_gate_v81(
        realization::PhysicalDeviceRealizationV71,
        screen::PhysicalDeviceScreenV71, parameter_binding;
        target_toroidal_turns::Integer = 128, steps_per_turn::Integer = 180,
        fourier_order::Integer = 4, bin_count::Integer = 16)
    binding = _v71_plain(parameter_binding)
    canonical_hash(binding) == realization.candidate_binding_hash ||
        throw(ArgumentError("v81 binding differs from realization"))
    screen.realization_hash == realization.realization_hash ||
        throw(ArgumentError("v81 screen differs from realization"))
    region = _v71_primary_region(realization)
    if region["geometry_class"] != "toroidal_volume_v1"
        return _v81_result(realization, screen, :incomplete, :unsupported,
            "not_applicable_non_toroidal_geometry",
            Dict("status" => "not_applicable"),
            ["use_open_field_transport_gate_v72"])
    end
    cache = compile_finite_filament_field_cache_v71(realization)
    candidate_boundary = get(binding, "v85_boundary", nothing)
    axis_evidence = candidate_boundary === nothing ? Dict{String,Any}(
        "status" => "not_applicable_legacy_boundary",
        "axis_reference" => nothing, "candidate_bound" => false) :
        _v81_locate_periodic_magnetic_axis(realization, cache,
            candidate_boundary; steps_per_turn = min(80, steps_per_turn))
    if candidate_boundary !== nothing && axis_evidence["status"] != "located"
        evidence = Dict{String,Any}(
            "status" => "evaluated",
            "model_id" =>
                "candidate_biot_savart_poincare_periodic_axis_v2",
            "target_toroidal_turns" => target_toroidal_turns,
            "steps_per_turn" => steps_per_turn,
            "candidate_boundary_frame_used" => true,
            "periodic_magnetic_axis" => axis_evidence,
            "all_traces_completed" => false,
            "any_trace_escaped" => false,
            "any_field_singular" => false,
            "field_cache_hash" => cache.cache_hash)
        return _v81_result(realization, screen, :complete, :fail,
            "periodic_magnetic_axis_not_located", evidence,
            String[])
    end
    axis_reference = get(axis_evidence, "axis_reference", nothing)
    start_fractions = (0.15, 0.35, 0.55)
    traces = [_v81_trace_to_section(realization, cache,
        _v81_axis_start_point(region, candidate_boundary, axis_reference,
            fraction);
        target_toroidal_turns = target_toroidal_turns,
        steps_per_turn = steps_per_turn,
        candidate_boundary = candidate_boundary,
        axis_reference = axis_reference) for fraction in start_fractions]
    fits = [Bool(trace["completed"]) ? _v81_surface_fit(trace["crossings"];
        fourier_order = fourier_order, bin_count = bin_count) :
        Dict{String,Any}("status" => "not_applicable_incomplete_trace",
            "crossing_count" => trace["crossing_count"]) for trace in traces]
    any_escape = any(Bool(trace["escaped"]) for trace in traces)
    any_singular = any(Bool(trace["field_singular"]) for trace in traces)
    all_completed = all(Bool(trace["completed"]) for trace in traces)
    fits_complete = all(fit["status"] == "complete" for fit in fits)
    transforms = abs.(Float64[trace["rotational_transform"] for trace in traces])
    minimum_transform = minimum(transforms)
    maximum_residual = fits_complete ? maximum(Float64(fit[
        "maximum_absolute_residual"]) for fit in fits) : Inf
    maximum_bin_spread = fits_complete ? maximum(Float64(fit[
        "maximum_repeated_bin_radial_spread"]) for fit in fits) : Inf
    maximum_drift = fits_complete ? maximum(abs(Float64(fit[
        "secular_residual_drift_per_toroidal_turn"])) for fit in fits) : Inf
    maximum_radius = fits_complete ? maximum(Float64(fit[
        "maximum_normalized_minor_radius"]) for fit in fits) : Inf
    minimum_repeated_bins = fits_complete ? minimum(Int(fit[
        "repeated_poloidal_bin_count"]) for fit in fits) : 0
    ordering_fraction = 0.0
    minimum_surface_gap = -Inf
    if fits_complete
        predictions = [Float64.(fit["predicted_normalized_radius"]) for fit in fits]
        ordered = [(predictions[1][index] < predictions[2][index] <
            predictions[3][index]) for index in eachindex(predictions[1])]
        ordering_fraction = count(identity, ordered) / length(ordered)
        minimum_surface_gap = minimum(vcat(predictions[2] .- predictions[1],
            predictions[3] .- predictions[2]))
    end
    thresholds = Dict{String,Any}(
        "minimum_absolute_rotational_transform" => 0.02,
        "maximum_fourier_residual" => 0.08,
        "maximum_repeated_bin_radial_spread" => 0.08,
        "maximum_secular_residual_drift_per_turn" => 2.0e-4,
        "minimum_repeated_poloidal_bins" => 8,
        "maximum_normalized_minor_radius" => 0.95,
        "minimum_surface_ordering_fraction" => 0.95,
        "minimum_fitted_surface_gap" => 0.02)
    evidence = Dict{String,Any}(
        "status" => "evaluated",
        "model_id" =>
            "candidate_biot_savart_poincare_periodic_axis_fourier_surface_v2",
        "target_toroidal_turns" => target_toroidal_turns,
        "steps_per_turn" => steps_per_turn,
        "start_minor_radius_fractions" => collect(start_fractions),
        "candidate_boundary_frame_used" => candidate_boundary !== nothing,
        "periodic_magnetic_axis" => axis_evidence,
        "all_traces_completed" => all_completed,
        "any_trace_escaped" => any_escape,
        "any_field_singular" => any_singular,
        "minimum_absolute_rotational_transform" => minimum_transform,
        "maximum_fourier_residual" =>
            isfinite(maximum_residual) ? maximum_residual : nothing,
        "maximum_repeated_bin_radial_spread" =>
            isfinite(maximum_bin_spread) ? maximum_bin_spread : nothing,
        "maximum_secular_residual_drift_per_turn" =>
            isfinite(maximum_drift) ? maximum_drift : nothing,
        "minimum_repeated_poloidal_bin_count" => minimum_repeated_bins,
        "maximum_normalized_minor_radius" =>
            isfinite(maximum_radius) ? maximum_radius : nothing,
        "surface_ordering_fraction" => ordering_fraction,
        "minimum_fitted_surface_gap" =>
            isfinite(minimum_surface_gap) ? minimum_surface_gap : nothing,
        "thresholds" => thresholds, "traces" => traces, "surface_fits" => fits,
        "field_cache_hash" => cache.cache_hash)
    code = if any_escape
        "poincare_field_line_escape"
    elseif any_singular || !all_completed || !fits_complete
        "incomplete_poincare_trace_or_fit"
    elseif minimum_transform < 0.02
        "insufficient_long_horizon_rotational_transform"
    elseif maximum_radius > 0.95
        "poincare_surface_approaches_boundary"
    elseif minimum_repeated_bins < 8
        "insufficient_poloidal_recurrence_coverage"
    elseif maximum_residual > 0.08 || maximum_bin_spread > 0.08
        "stochastic_or_broken_poincare_surface"
    elseif maximum_drift > 2.0e-4
        "secular_cross_surface_drift"
    elseif ordering_fraction < 0.95 || minimum_surface_gap < 0.02
        "loss_of_nested_poincare_surface_ordering"
    else
        "poincare_surfaces_bounded_requires_downstream_physics"
    end
    if code != "poincare_surfaces_bounded_requires_downstream_physics"
        return _v81_result(realization, screen, :complete, :fail, code,
            evidence, String[])
    end
    return _v81_result(realization, screen, :incomplete, :unknown, code,
        evidence, ["finite_pressure_equilibrium", "candidate_bound_kinetic_transport",
            "mhd_and_microstability_evidence", "accepted_particle_ensemble"])
end

function poincare_flux_surface_gate_to_dict_v81(item::PoincareFluxSurfaceGateV81)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "realization_hash" => item.realization_hash,
        "screen_evidence_hash" => item.screen_evidence_hash,
        "completeness" => String(item.completeness),
        "conclusion" => String(item.conclusion),
        "classification_code" => item.classification_code,
        "poincare_evidence" => item.poincare_evidence,
        "missing_requirements" => item.missing_requirements,
        "claim_boundary" => item.claim_boundary,
        "evidence_hash" => item.evidence_hash)
end

function _v81_frontier_rank(row)
    conclusion = row["conclusion"] == "unknown" ? 0 : 1
    escape = Bool(row["any_trace_escaped"]) ? 1 : 0
    transform = Float64(row["minimum_absolute_rotational_transform"])
    residual = row["maximum_fourier_residual"] === nothing ?
        1.0e9 : Float64(row["maximum_fourier_residual"])
    spread = row["maximum_repeated_bin_radial_spread"] === nothing ?
        1.0e9 : Float64(row["maximum_repeated_bin_radial_spread"])
    drift = row["maximum_secular_residual_drift_per_turn"] === nothing ?
        1.0e9 : Float64(row["maximum_secular_residual_drift_per_turn"])
    ordering = Float64(row["surface_ordering_fraction"])
    minimum_crossings = Int(row["minimum_crossing_count"])
    return (conclusion, escape, transform >= 0.02 ? 0 : 1, -minimum_crossings,
        max(residual, spread), drift, -ordering, -transform, Int(row["modular_seed"]))
end

function run_v80_poincare_frontier_v81(seeds;
        output_path::Union{Nothing,AbstractString} = nothing,
        target_toroidal_turns::Integer = 128, steps_per_turn::Integer = 180)
    topology = generate_graph_native_topology_v69(72)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    rows = Dict{String,Any}[]
    full = Dict{Int,Dict{String,Any}}()
    exception_count = 0
    for seed_value in Int.(collect(seeds))
        try
            binding = generate_modular_multiharmonic_binding_v80(topology, 72,
                seed_value)
            realization = compile_modular_multiharmonic_realization_v80(topology,
                compilation; parameter_binding = binding)
            screen = screen_physical_device_v71(realization, binding;
                particle_count = 1, step_count = 1, required_transit_fraction = 1.0)
            gate = evaluate_poincare_flux_surface_gate_v81(realization, screen,
                binding; target_toroidal_turns = target_toroidal_turns,
                steps_per_turn = steps_per_turn)
            evidence = gate.poincare_evidence
            row = Dict{String,Any}(
                "modular_seed" => seed_value,
                "conclusion" => String(gate.conclusion),
                "classification_code" => gate.classification_code,
                "any_trace_escaped" => evidence["any_trace_escaped"],
                "minimum_crossing_count" => minimum(Int(trace["crossing_count"])
                    for trace in evidence["traces"]),
                "maximum_crossing_count" => maximum(Int(trace["crossing_count"])
                    for trace in evidence["traces"]),
                "minimum_absolute_rotational_transform" =>
                    evidence["minimum_absolute_rotational_transform"],
                "maximum_fourier_residual" => evidence["maximum_fourier_residual"],
                "maximum_repeated_bin_radial_spread" =>
                    evidence["maximum_repeated_bin_radial_spread"],
                "maximum_secular_residual_drift_per_turn" =>
                    evidence["maximum_secular_residual_drift_per_turn"],
                "surface_ordering_fraction" => evidence["surface_ordering_fraction"],
                "minimum_fitted_surface_gap" => evidence["minimum_fitted_surface_gap"])
            row["row_hash"] = canonical_hash(row)
            push!(rows, row)
            full[seed_value] = Dict{String,Any}(
                "row" => row, "parameter_binding" => binding,
                "topology" => _s70_topology_to_dict(topology),
                "realization" => physical_device_realization_to_dict_v71(realization),
                "screen" => physical_device_screen_to_dict_v71(screen),
                "poincare_gate" => poincare_flux_surface_gate_to_dict_v81(gate))
        catch error
            exception_count += 1
            push!(rows, Dict{String,Any}(
                "modular_seed" => seed_value, "status" => "exception",
                "exception_type" => String(nameof(typeof(error))),
                "exception_message" => sprint(showerror, error)))
        end
    end
    valid = [row for row in rows if !haskey(row, "status")]
    sort!(valid; by = _v81_frontier_rank)
    winner = isempty(valid) ? nothing : full[Int(valid[1]["modular_seed"])]
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && winner !== nothing ? "complete" : "incomplete",
        "candidate_count" => length(rows),
        "uncaught_exception_count" => exception_count,
        "poincare_unknown_count" => count(row -> get(row,
            "conclusion", "") == "unknown", rows),
        "target_toroidal_turns" => target_toroidal_turns,
        "steps_per_turn" => steps_per_turn,
        "candidate_rows" => rows, "winner" => winner,
        "device_family_routing_used" => false,
        "claim_boundary" => POINCARE_FLUX_SURFACE_V81_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end
