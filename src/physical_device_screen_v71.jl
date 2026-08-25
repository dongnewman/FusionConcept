const PHYSICAL_DEVICE_SCREEN_V71_CLAIM_BOUNDARY =
    "This is a candidate-bound low-fidelity screen using finite-filament Biot-Savart fields, collisionless Boris particle orbits, Bosch-Hale D-T reactivity, fuel-ion bremsstrahlung, and explicit hardware capacity bounds. A screen_pass is scheduling evidence only, not a feasible fusion-device claim."

struct PhysicalDeviceScreenV71
    schema_version::String
    topology_hash::String
    realization_hash::String
    candidate_binding_hash::String
    completeness::Symbol
    conclusion::Symbol
    classification_code::String
    field_evidence::Dict{String,Any}
    particle_evidence::Dict{String,Any}
    plasma_evidence::Dict{String,Any}
    engineering_evidence::Dict{String,Any}
    gate_statuses::Dict{String,String}
    passed_gate_count::Int
    required_gate_count::Int
    claim_boundary::String
    evidence_hash::String
end

struct FiniteFilamentFieldCacheV71
    midpoint_m::Matrix{Float64}
    differential_m::Matrix{Float64}
    current_turns_a::Vector{Float64}
    regularization_squared_m2::Vector{Float64}
    cache_hash::String
end

function _v71_binding_number(binding, key)
    value = binding[key]
    value isa Real || throw(ArgumentError("physical binding $key must be numeric"))
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("physical binding $key must be finite"))
    return result
end

function _v71_field_components(realization::PhysicalDeviceRealizationV71)
    return [item for item in realization.components if
        String(item["component_kind"]) == "finite_filament_coil_array_v1"]
end

function compile_finite_filament_field_cache_v71(
        realization::PhysicalDeviceRealizationV71)
    midpoints = Vector{Vector{Float64}}()
    differentials = Vector{Vector{Float64}}()
    currents = Float64[]; regularizations = Float64[]
    for component in _v71_field_components(realization)
        regularization = Float64(component["conductor"]["radius_m"])
        for loop in component["loops"]
            points = loop["centerline_m"]
            current_turns = Float64(loop["current_a"]) * Int(loop["turns"])
            for index in 1:length(points)-1
                start = Float64.(points[index]); stop = Float64.(points[index + 1])
                dl = stop - start; midpoint = 0.5 .* (start + stop)
                push!(midpoints, midpoint); push!(differentials, dl)
                push!(currents, current_turns); push!(regularizations, regularization^2)
            end
        end
    end
    midpoint_matrix = isempty(midpoints) ? zeros(3, 0) : hcat(midpoints...)
    differential_matrix = isempty(differentials) ? zeros(3, 0) : hcat(differentials...)
    body = Dict{String,Any}(
        "realization_hash" => realization.realization_hash,
        "segment_count" => length(currents),
        "compiler_id" => "finite_filament_field_cache_v71")
    return FiniteFilamentFieldCacheV71(midpoint_matrix, differential_matrix,
        currents, regularizations, canonical_hash(body))
end

function finite_filament_field_v71(cache::FiniteFilamentFieldCacheV71,
        point_m::AbstractVector)
    length(point_m) == 3 || throw(ArgumentError("field point must be three-dimensional"))
    px, py, pz = Float64(point_m[1]), Float64(point_m[2]), Float64(point_m[3])
    bx = 0.0; by = 0.0; bz = 0.0
    @inbounds for index in eachindex(cache.current_turns_a)
        rx = px - cache.midpoint_m[1, index]
        ry = py - cache.midpoint_m[2, index]
        rz = pz - cache.midpoint_m[3, index]
        dlx = cache.differential_m[1, index]
        dly = cache.differential_m[2, index]
        dlz = cache.differential_m[3, index]
        radius_squared = rx * rx + ry * ry + rz * rz +
            cache.regularization_squared_m2[index]
        factor = 1.0e-7 * cache.current_turns_a[index] / radius_squared^(3 / 2)
        bx += factor * (dly * rz - dlz * ry)
        by += factor * (dlz * rx - dlx * rz)
        bz += factor * (dlx * ry - dly * rx)
    end
    return [bx, by, bz]
end

function finite_filament_field_v71(realization::PhysicalDeviceRealizationV71,
        point_m::AbstractVector)
    cache = compile_finite_filament_field_cache_v71(realization)
    field = finite_filament_field_v71(cache, point_m)
    return field
end

function _v71_primary_region(realization::PhysicalDeviceRealizationV71)
    regions = realization.geometry["regions"]
    isempty(regions) && throw(ArgumentError("physical realization has no regions"))
    return first(regions)
end

function _v71_field_sample_points(region)
    points = Vector{Vector{Float64}}()
    minor = Float64(region["minor_radius_m"])
    if region["geometry_class"] == "toroidal_volume_v1"
        major = Float64(region["major_radius_m"])
        for radial_fraction in (-0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75)
            push!(points, [major + radial_fraction * minor, 0.0, 0.0])
        end
        for vertical_fraction in (-0.6, -0.3, 0.3, 0.6)
            push!(points, [major, 0.0, vertical_fraction * minor])
        end
    else
        center = Float64.(region["center_m"])
        half_length = Float64(region["half_length_m"])
        for axial_fraction in (-0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75)
            point = copy(center); point[3] += axial_fraction * half_length
            push!(points, point)
        end
        for radial_fraction in (-0.6, -0.3, 0.3, 0.6)
            point = copy(center); point[1] += radial_fraction * minor
            push!(points, point)
        end
    end
    return points
end

function _v71_field_evidence(realization, cache)
    points = _v71_field_sample_points(_v71_primary_region(realization))
    vectors = [finite_filament_field_v71(cache, point) for point in points]
    magnitudes = norm.(vectors)
    minimum_field = minimum(magnitudes); maximum_field = maximum(magnitudes)
    mean_field = sum(magnitudes) / length(magnitudes)
    relative_spread = (maximum_field - minimum_field) / max(mean_field, eps())
    finite = all(isfinite, magnitudes)
    pass = finite && minimum_field >= 0.10 && relative_spread <= 3.0
    return Dict{String,Any}(
        "status" => pass ? "pass" : "fail",
        "model_id" => "finite_filament_biot_savart_v1",
        "sample_points_m" => points,
        "field_vectors_t" => vectors,
        "field_magnitudes_t" => magnitudes,
        "minimum_field_t" => minimum_field,
        "maximum_field_t" => maximum_field,
        "mean_field_t" => mean_field,
        "relative_field_spread" => relative_spread,
        "minimum_field_requirement_t" => 0.10,
        "maximum_relative_spread" => 3.0,
        "sample_count" => length(points),
        "finite_values" => finite)
end

function _v71_inside_region(position, region)
    if region["geometry_class"] == "toroidal_volume_v1"
        major = Float64(region["major_radius_m"])
        minor = Float64(region["minor_radius_m"])
        radial = hypot(position[1], position[2])
        return (radial - major)^2 + position[3]^2 <= minor^2
    end
    center = Float64.(region["center_m"])
    radial_squared = (position[1] - center[1])^2 + (position[2] - center[2])^2
    return radial_squared <= Float64(region["minor_radius_m"])^2 &&
        abs(position[3] - center[3]) <= Float64(region["half_length_m"])
end

function _v71_particle_start(rng, region)
    minor = Float64(region["minor_radius_m"])
    radius = 0.20 * minor * sqrt(rand(rng)); angle = 2pi * rand(rng)
    if region["geometry_class"] == "toroidal_volume_v1"
        phi = 2pi * rand(rng); major = Float64(region["major_radius_m"])
        cylindrical_radius = major + radius * cos(angle)
        return [cylindrical_radius * cos(phi), cylindrical_radius * sin(phi),
            radius * sin(angle)]
    end
    center = Float64.(region["center_m"])
    axial = 0.15 * Float64(region["half_length_m"]) * (2rand(rng) - 1)
    return center + [radius * cos(angle), radius * sin(angle), axial]
end

function _v71_isotropic_velocity(rng, speed)
    cosine = 2rand(rng) - 1; sine = sqrt(max(0.0, 1.0 - cosine^2))
    phi = 2pi * rand(rng)
    return speed .* [sine * cos(phi), sine * sin(phi), cosine]
end

function _v71_boris_step(position, velocity, charge_mass_ratio, step_seconds,
        field_cache)
    field = finite_filament_field_v71(field_cache, position)
    t = 0.5 * charge_mass_ratio * step_seconds .* field
    s = 2.0 .* t ./ (1.0 + dot(t, t))
    prime = velocity + cross(velocity, t)
    updated_velocity = velocity + cross(prime, s)
    updated_position = position + step_seconds .* updated_velocity
    return updated_position, updated_velocity
end

function _v71_particle_evidence(realization, binding; particle_count = 24,
        step_count = 400, trace_stride = 4, required_transit_fraction = 0.25,
        field_cache = compile_finite_filament_field_cache_v71(realization))
    particle_count > 0 || throw(ArgumentError("particle_count must be positive"))
    step_count > 0 || throw(ArgumentError("step_count must be positive"))
    required_transit_fraction > 0 || throw(ArgumentError(
        "required_transit_fraction must be positive"))
    region = _v71_primary_region(realization)
    reference_point = if region["geometry_class"] == "toroidal_volume_v1"
        [Float64(region["major_radius_m"]), 0.0, 0.0]
    else
        Float64.(region["center_m"])
    end
    reference_field = norm(finite_filament_field_v71(field_cache, reference_point))
    elementary_charge = 1.602176634e-19
    deuteron_mass = 3.3435837724e-27
    charge_mass_ratio = elementary_charge / deuteron_mass
    gyroperiod = 2pi / (charge_mass_ratio * max(reference_field, 0.01))
    step_seconds = gyroperiod / 40
    temperature_j = _v71_binding_number(binding, "target_ion_temperature_kev") *
        1.0e3 * elementary_charge
    speed = sqrt(2temperature_j / deuteron_mass)
    characteristic_path = region["geometry_class"] == "toroidal_volume_v1" ?
        2pi * Float64(region["major_radius_m"]) :
        2.0 * Float64(region["half_length_m"])
    target_duration = required_transit_fraction * characteristic_path / speed
    required_step_count = max(1, ceil(Int, target_duration / step_seconds))
    completed_step_count = min(step_count, required_step_count)
    completed_duration = completed_step_count * step_seconds
    duration_coverage = min(1.0, completed_duration / target_duration)
    rng = MersenneTwister(Int(binding["seed"]) + 710_071)
    survived = 0; lifetimes = Float64[]; representative_trace = Vector{Vector{Float64}}()
    for particle_index in 1:particle_count
        position = _v71_particle_start(rng, region)
        velocity = _v71_isotropic_velocity(rng, speed)
        lifetime_steps = 0
        for step_index in 1:completed_step_count
            position, velocity = _v71_boris_step(position, velocity,
                charge_mass_ratio, step_seconds, field_cache)
            if particle_index == 1 && (step_index == 1 || step_index % trace_stride == 0)
                push!(representative_trace, copy(position))
            end
            _v71_inside_region(position, region) || break
            lifetime_steps = step_index
        end
        lifetime_steps == completed_step_count && (survived += 1)
        push!(lifetimes, lifetime_steps * step_seconds)
    end
    retained_fraction = survived / particle_count
    confidence_z = 1.959963984540054
    denominator = 1.0 + confidence_z^2 / particle_count
    center = (retained_fraction + confidence_z^2 / (2particle_count)) / denominator
    radius = confidence_z / denominator * sqrt(retained_fraction *
        (1.0 - retained_fraction) / particle_count + confidence_z^2 /
        (4particle_count^2))
    wilson_lower = max(0.0, center - radius)
    confidence_complete = wilson_lower >= 0.80
    status = retained_fraction < 0.80 ? "fail" :
        (duration_coverage < 1.0 - 1.0e-12 || !confidence_complete ? "unknown" : "pass")
    return Dict{String,Any}(
        "status" => status,
        "model_id" => "collisionless_deuteron_boris_orbit_v1",
        "electric_field_model" => "zero",
        "collision_model" => "not_included",
        "collective_plasma_response" => "not_included",
        "particle_count" => particle_count,
        "step_budget" => step_count,
        "required_step_count" => required_step_count,
        "completed_step_count" => completed_step_count,
        "time_step_s" => step_seconds,
        "simulated_duration_s" => completed_duration,
        "target_duration_s" => target_duration,
        "duration_coverage_fraction" => duration_coverage,
        "characteristic_path_length_m" => characteristic_path,
        "required_transit_fraction" => required_transit_fraction,
        "reference_field_t" => reference_field,
        "initial_energy_kev" => _v71_binding_number(binding, "target_ion_temperature_kev"),
        "retained_particle_count" => survived,
        "retained_fraction" => retained_fraction,
        "required_retained_fraction" => 0.80,
        "retained_fraction_wilson_lower_95" => wilson_lower,
        "statistical_confidence_complete" => confidence_complete,
        "lifetimes_s" => lifetimes,
        "representative_trace_m" => representative_trace,
        "trace_stride" => trace_stride)
end

function _v71_plasma_evidence(realization, binding)
    region = _v71_primary_region(realization)
    volume = Float64(region["volume_m3"])
    density = _v71_binding_number(binding, "target_total_ion_density_m3")
    ion_temperature = _v71_binding_number(binding, "target_ion_temperature_kev")
    electron_temperature = _v71_binding_number(binding, "target_electron_temperature_kev")
    effective_charge = _v71_binding_number(binding, "effective_charge")
    reactivity = bosch_hale_maxwellian_reactivity_v1("dt_to_alpha_neutron", ion_temperature)
    elementary_charge = 1.602176634e-19
    reaction_rate = 0.25 * density^2 * reactivity * volume
    fusion_power = reaction_rate * 17.58e6 * elementary_charge
    alpha_power = reaction_rate * 3.52e6 * elementary_charge
    neutron_power = reaction_rate * 14.06e6 * elementary_charge
    bremsstrahlung = 1.69e-38 * density^2 * effective_charge * volume *
        sqrt(electron_temperature * 1.0e3)
    heating = _v71_binding_number(binding, "heating_power_w")
    wall_power = heating / _v71_binding_number(binding, "injector_efficiency")
    plasma_gain = fusion_power / max(heating, eps())
    scientific_balance = alpha_power + heating - bremsstrahlung
    thermal_energy = 1.5 * density * volume *
        (ion_temperature + electron_temperature) * 1.0e3 * elementary_charge
    required_energy_confinement = scientific_balance > 0 ?
        thermal_energy / scientific_balance : Inf
    finite = all(isfinite, (reactivity, reaction_rate, fusion_power,
        bremsstrahlung, plasma_gain, thermal_energy))
    pass = finite && plasma_gain >= 1.0 && scientific_balance > 0
    return Dict{String,Any}(
        "status" => pass ? "pass" : "fail",
        "model_id" => "bosch_hale_dt_zero_d_power_screen_v1",
        "fuel" => "D-T", "plasma_volume_m3" => volume,
        "total_ion_density_m3" => density,
        "ion_temperature_kev" => ion_temperature,
        "electron_temperature_kev" => electron_temperature,
        "effective_charge" => effective_charge,
        "reactivity_m3_s" => reactivity,
        "reaction_rate_per_s" => reaction_rate,
        "fusion_power_w" => fusion_power,
        "alpha_power_w" => alpha_power,
        "neutron_power_w" => neutron_power,
        "bremsstrahlung_power_w" => bremsstrahlung,
        "delivered_heating_power_w" => heating,
        "injector_wall_power_w" => wall_power,
        "plasma_gain_proxy" => plasma_gain,
        "required_plasma_gain_proxy" => 1.0,
        "stored_thermal_energy_j" => thermal_energy,
        "required_energy_confinement_s" => required_energy_confinement,
        "radiation_scope" => "fuel_ion_bremsstrahlung_only",
        "transport_closure" => "not_included")
end

function _v71_engineering_evidence(realization, binding, field, plasma)
    coil_components = _v71_field_components(realization)
    conductor_radius = _v71_binding_number(binding, "conductor_radius_m")
    current = _v71_binding_number(binding, "field_current_a")
    current_density = current / (pi * conductor_radius^2)
    magnetic_pressure = Float64(field["maximum_field_t"])^2 / (2 * 4pi * 1.0e-7)
    stress_factor = 1.0 + _v71_binding_number(binding, "coil_clearance_m") /
        max(conductor_radius, eps())
    estimated_stress = magnetic_pressure * stress_factor
    current_density_limit = isempty(coil_components) ? 0.0 :
        Float64(first(coil_components)["conductor"]["current_density_limit_a_m2"])
    stress_limit = isempty(coil_components) ? 0.0 :
        Float64(first(coil_components)["conductor"]["allowable_magnetic_stress_pa"])
    cooling_capacity = _v71_binding_number(binding, "cooling_capacity_w")
    thermal_load = Float64(plasma["fusion_power_w"]) +
        Float64(plasma["injector_wall_power_w"])
    current_ok = current_density <= current_density_limit
    stress_ok = estimated_stress <= stress_limit
    cooling_ok = cooling_capacity >= thermal_load
    pass = !isempty(coil_components) && current_ok && stress_ok && cooling_ok
    return Dict{String,Any}(
        "status" => pass ? "pass" : "fail",
        "model_id" => "finite_coil_capacity_lower_bound_v1",
        "coil_component_count" => length(coil_components),
        "conductor_current_density_a_m2" => current_density,
        "current_density_limit_a_m2" => current_density_limit,
        "current_density_margin_fraction" => current_density_limit == 0 ? -Inf :
            1.0 - current_density / current_density_limit,
        "estimated_magnetic_stress_pa" => estimated_stress,
        "allowable_magnetic_stress_pa" => stress_limit,
        "stress_margin_fraction" => stress_limit == 0 ? -Inf :
            1.0 - estimated_stress / stress_limit,
        "cooling_capacity_w" => cooling_capacity,
        "screened_thermal_load_w" => thermal_load,
        "cooling_margin_w" => cooling_capacity - thermal_load,
        "current_density_gate" => current_ok ? "pass" : "fail",
        "magnetic_stress_gate" => stress_ok ? "pass" : "fail",
        "heat_rejection_gate" => cooling_ok ? "pass" : "fail",
        "quench_and_fatigue_evidence" => "not_included")
end

function screen_physical_device_v71(realization::PhysicalDeviceRealizationV71,
        parameter_binding; particle_count = 24, step_count = 400,
        required_transit_fraction = 0.25)
    binding = _v71_plain(parameter_binding)
    canonical_hash(binding) == realization.candidate_binding_hash ||
        throw(ArgumentError("physical realization and parameter binding hashes differ"))
    if realization.completeness != :complete
        conclusion = realization.conclusion == :unsupported ? :unsupported : :unknown
        body = Dict{String,Any}(
            "schema_version" => "1.0.0", "topology_hash" => realization.topology_hash,
            "realization_hash" => realization.realization_hash,
            "candidate_binding_hash" => realization.candidate_binding_hash,
            "completeness" => "incomplete", "conclusion" => String(conclusion),
            "classification_code" => "physical_realization_not_executable",
            "field_evidence" => Dict{String,Any}(),
            "particle_evidence" => Dict{String,Any}(),
            "plasma_evidence" => Dict{String,Any}(),
            "engineering_evidence" => Dict{String,Any}(),
            "gate_statuses" => Dict{String,String}(), "passed_gate_count" => 0,
            "required_gate_count" => 6,
            "claim_boundary" => PHYSICAL_DEVICE_SCREEN_V71_CLAIM_BOUNDARY)
        return PhysicalDeviceScreenV71("1.0.0", realization.topology_hash,
            realization.realization_hash, realization.candidate_binding_hash,
            :incomplete, conclusion, "physical_realization_not_executable",
            Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}(),
            Dict{String,Any}(), Dict{String,String}(), 0, 6,
            PHYSICAL_DEVICE_SCREEN_V71_CLAIM_BOUNDARY, canonical_hash(body))
    end
    field_cache = compile_finite_filament_field_cache_v71(realization)
    field = _v71_field_evidence(realization, field_cache)
    particles = _v71_particle_evidence(realization, binding;
        particle_count = particle_count, step_count = step_count,
        required_transit_fraction = required_transit_fraction,
        field_cache = field_cache)
    plasma = _v71_plasma_evidence(realization, binding)
    engineering = _v71_engineering_evidence(realization, binding, field, plasma)
    gates = Dict{String,String}(
        "finite_field" => String(field["status"]),
        "collisionless_particle_retention" => String(particles["status"]),
        "dt_power_balance_proxy" => String(plasma["status"]),
        "conductor_current_density" => String(engineering["current_density_gate"]),
        "magnetic_stress" => String(engineering["magnetic_stress_gate"]),
        "heat_rejection_capacity" => String(engineering["heat_rejection_gate"]))
    passed = count(==("pass"), values(gates)); required = length(gates)
    any_failed = any(==("fail"), values(gates))
    conclusion = passed == required ? :screen_pass :
        (any_failed ? :screen_fail : :screen_unknown)
    classification = conclusion == :screen_pass ?
        "low_fidelity_physical_screen_pass_requires_higher_fidelity" :
        conclusion == :screen_fail ? "low_fidelity_physical_screen_rejection" :
        "low_fidelity_physical_screen_budget_incomplete"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "topology_hash" => realization.topology_hash,
        "realization_hash" => realization.realization_hash,
        "candidate_binding_hash" => realization.candidate_binding_hash,
        "completeness" => "complete", "conclusion" => String(conclusion),
        "classification_code" => classification, "field_evidence" => field,
        "particle_evidence" => particles, "plasma_evidence" => plasma,
        "engineering_evidence" => engineering, "gate_statuses" => gates,
        "passed_gate_count" => passed, "required_gate_count" => required,
        "claim_boundary" => PHYSICAL_DEVICE_SCREEN_V71_CLAIM_BOUNDARY)
    return PhysicalDeviceScreenV71("1.0.0", realization.topology_hash,
        realization.realization_hash, realization.candidate_binding_hash,
        :complete, conclusion, classification, field, particles, plasma,
        engineering, gates, passed, required,
        PHYSICAL_DEVICE_SCREEN_V71_CLAIM_BOUNDARY, canonical_hash(body))
end

function physical_device_screen_to_dict_v71(item::PhysicalDeviceScreenV71)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "topology_hash" => item.topology_hash,
        "realization_hash" => item.realization_hash,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "completeness" => String(item.completeness),
        "conclusion" => String(item.conclusion),
        "classification_code" => item.classification_code,
        "field_evidence" => item.field_evidence,
        "particle_evidence" => item.particle_evidence,
        "plasma_evidence" => item.plasma_evidence,
        "engineering_evidence" => item.engineering_evidence,
        "gate_statuses" => item.gate_statuses,
        "passed_gate_count" => item.passed_gate_count,
        "required_gate_count" => item.required_gate_count,
        "claim_boundary" => item.claim_boundary,
        "evidence_hash" => item.evidence_hash)
end

function _v71_screen_rank(screen::PhysicalDeviceScreenV71)
    particle_fraction = Float64(get(screen.particle_evidence, "retained_fraction", 0.0))
    particle_coverage = Float64(get(screen.particle_evidence,
        "duration_coverage_fraction", 0.0))
    gain = Float64(get(screen.plasma_evidence, "plasma_gain_proxy", 0.0))
    current_margin = Float64(get(screen.engineering_evidence,
        "current_density_margin_fraction", -Inf))
    cooling_margin = Float64(get(screen.engineering_evidence, "cooling_margin_w", -Inf))
    return (-screen.passed_gate_count, -particle_coverage, -particle_fraction, -gain,
        -current_margin, -cooling_margin, screen.evidence_hash)
end

function evaluate_physical_device_candidate_v71(seed::Integer;
        particle_count::Integer = 24, step_count::Integer = 400,
        required_transit_fraction::Real = 0.25)
    seed > 0 || throw(ArgumentError("physical candidate seed must be positive"))
    topology = generate_graph_native_topology_v69(seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    compilation.status == :pass || return Dict{String,Any}(
        "seed" => Int(seed), "status" => "not_admitted",
        "classification_code" => compilation.classification_code,
        "topology_hash" => topology.topology_hash,
        "structure_hash" => compilation.isomorphism_hash)
    binding = generate_physical_parameter_binding_v71(topology, seed)
    realization = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    screen = screen_physical_device_v71(realization, binding;
        particle_count = particle_count, step_count = step_count,
        required_transit_fraction = required_transit_fraction)
    return Dict{String,Any}(
        "seed" => Int(seed), "status" => "evaluated",
        "topology" => _s70_topology_to_dict(topology),
        "compilation" => Dict{String,Any}(
            "status" => String(compilation.status),
            "classification_code" => compilation.classification_code,
            "isomorphism_hash" => compilation.isomorphism_hash,
            "compilation_hash" => compilation.compilation_hash),
        "parameter_binding" => binding,
        "realization" => physical_device_realization_to_dict_v71(realization),
        "screen" => physical_device_screen_to_dict_v71(screen))
end

function refine_physical_device_candidates_v71(seeds;
        output_path::Union{Nothing,AbstractString} = nothing,
        particle_count::Integer = 24, step_count::Integer = 400,
        required_transit_fraction::Real = 0.25)
    normalized_seeds = sort!(unique(Int.(collect(seeds))))
    isempty(normalized_seeds) && throw(ArgumentError("refinement seeds cannot be empty"))
    results = Dict{String,Any}[]; evaluated = Tuple{Any,PhysicalDeviceScreenV71}[]
    exception_count = 0
    for seed in normalized_seeds
        try
            result = evaluate_physical_device_candidate_v71(seed;
                particle_count = particle_count, step_count = step_count,
                required_transit_fraction = required_transit_fraction)
            push!(results, result)
            if result["status"] == "evaluated"
                screen_dict = result["screen"]
                screen = PhysicalDeviceScreenV71(
                    String(screen_dict["schema_version"]), String(screen_dict["topology_hash"]),
                    String(screen_dict["realization_hash"]),
                    String(screen_dict["candidate_binding_hash"]),
                    Symbol(screen_dict["completeness"]), Symbol(screen_dict["conclusion"]),
                    String(screen_dict["classification_code"]),
                    Dict{String,Any}(screen_dict["field_evidence"]),
                    Dict{String,Any}(screen_dict["particle_evidence"]),
                    Dict{String,Any}(screen_dict["plasma_evidence"]),
                    Dict{String,Any}(screen_dict["engineering_evidence"]),
                    Dict{String,String}(String(key) => String(value) for
                        (key, value) in pairs(screen_dict["gate_statuses"])),
                    Int(screen_dict["passed_gate_count"]),
                    Int(screen_dict["required_gate_count"]),
                    String(screen_dict["claim_boundary"]), String(screen_dict["evidence_hash"]))
                push!(evaluated, (result, screen))
            end
        catch error
            exception_count += 1
            push!(results, Dict{String,Any}(
                "seed" => seed, "status" => "exception",
                "exception_type" => String(nameof(typeof(error)))))
        end
    end
    sort!(evaluated; by = item -> _v71_screen_rank(item[2]))
    winner = isempty(evaluated) ? nothing : first(evaluated)[1]
    conclusion_counts = Dict{String,Int}()
    for (_, screen) in evaluated
        key = String(screen.conclusion)
        conclusion_counts[key] = get(conclusion_counts, key, 0) + 1
    end
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && winner !== nothing ? "complete" : "incomplete",
        "refined_seeds" => normalized_seeds,
        "particle_count" => Int(particle_count), "step_count" => Int(step_count),
        "required_transit_fraction" => Float64(required_transit_fraction),
        "evaluated_count" => length(evaluated),
        "uncaught_exception_count" => exception_count,
        "conclusion_counts" => conclusion_counts,
        "winner_selection_method" =>
            "lexicographic_gate_depth_particle_retention_gain_engineering_margins_v1",
        "winner" => winner, "candidate_results" => results,
        "device_family_routing_used" => false,
        "claim_boundary" => PHYSICAL_DEVICE_SCREEN_V71_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    output_path === nothing || _stage3_atomic_json_v1(String(output_path), artifact)
    return artifact
end

"""Search graph structures and physical design genes through one candidate-bound v71 chain."""
function run_physical_device_search_v71(first_seed::Integer, last_seed::Integer;
        output_path::Union{Nothing,AbstractString} = nothing,
        particle_count::Integer = 16, step_count::Integer = 240)
    1 <= first_seed <= last_seed || throw(ArgumentError("invalid physical search seed range"))
    rows = Dict{String,Any}[]; best = nothing; best_rank = nothing
    compilation_counts = Dict{String,Int}(); realization_counts = Dict{String,Int}()
    conclusion_counts = Dict{String,Int}(); exception_count = 0
    for seed in first_seed:last_seed
        try
            topology = generate_graph_native_topology_v69(seed)
            compilation = compile_graph_native_topology_candidate_v69(topology)
            compilation_key = String(compilation.status)
            compilation_counts[compilation_key] = get(compilation_counts, compilation_key, 0) + 1
            compilation.status == :pass || continue
            binding = generate_physical_parameter_binding_v71(topology, seed)
            realization = compile_physical_device_realization_v71(topology, compilation;
                parameter_binding = binding)
            realization_key = String(realization.completeness)
            realization_counts[realization_key] = get(realization_counts, realization_key, 0) + 1
            screen = screen_physical_device_v71(realization, binding;
                particle_count = particle_count, step_count = step_count)
            conclusion_key = String(screen.conclusion)
            conclusion_counts[conclusion_key] = get(conclusion_counts, conclusion_key, 0) + 1
            row = Dict{String,Any}(
                "seed" => Int(seed), "topology_hash" => topology.topology_hash,
                "structure_hash" => compilation.isomorphism_hash,
                "candidate_binding_hash" => realization.candidate_binding_hash,
                "realization_hash" => realization.realization_hash,
                "evidence_hash" => screen.evidence_hash,
                "physical_component_count" => length(realization.components),
                "passed_gate_count" => screen.passed_gate_count,
                "required_gate_count" => screen.required_gate_count,
                "conclusion" => String(screen.conclusion),
                "gate_statuses" => screen.gate_statuses,
                "minimum_field_t" => get(screen.field_evidence, "minimum_field_t", nothing),
                "retained_fraction" => get(screen.particle_evidence, "retained_fraction", nothing),
                "plasma_gain_proxy" => get(screen.plasma_evidence, "plasma_gain_proxy", nothing),
                "current_density_margin_fraction" => get(screen.engineering_evidence,
                    "current_density_margin_fraction", nothing),
                "cooling_margin_w" => get(screen.engineering_evidence,
                    "cooling_margin_w", nothing))
            row["row_hash"] = canonical_hash(row); push!(rows, row)
            rank = _v71_screen_rank(screen)
            if best === nothing || rank < best_rank
                best_rank = rank
                best = Dict{String,Any}(
                    "seed" => Int(seed),
                    "topology" => _s70_topology_to_dict(topology),
                    "compilation" => Dict{String,Any}(
                        "status" => String(compilation.status),
                        "classification_code" => compilation.classification_code,
                        "isomorphism_hash" => compilation.isomorphism_hash,
                        "compilation_hash" => compilation.compilation_hash),
                    "parameter_binding" => binding,
                    "realization" => physical_device_realization_to_dict_v71(realization),
                    "screen" => physical_device_screen_to_dict_v71(screen))
            end
        catch error
            exception_count += 1
            push!(rows, Dict{String,Any}(
                "seed" => Int(seed), "conclusion" => "exception",
                "exception_type" => String(nameof(typeof(error))),
                "row_hash" => canonical_hash(Dict("seed" => Int(seed),
                    "exception_type" => String(nameof(typeof(error)))))))
        end
    end
    sort!(rows; by = row -> Int(row["seed"]))
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "status" => exception_count == 0 && best !== nothing ? "complete" : "incomplete",
        "first_seed" => Int(first_seed), "last_seed" => Int(last_seed),
        "raw_candidate_count" => Int(last_seed - first_seed + 1),
        "evaluated_physical_candidate_count" => count(row ->
            haskey(row, "realization_hash"), rows),
        "compilation_status_counts" => compilation_counts,
        "realization_completeness_counts" => realization_counts,
        "screen_conclusion_counts" => conclusion_counts,
        "uncaught_exception_count" => exception_count,
        "winner_selection_method" =>
            "lexicographic_gate_depth_particle_retention_gain_engineering_margins_v1",
        "winner" => best,
        "candidate_rows" => rows,
        "device_family_routing_used" => false,
        "claim_boundary" => PHYSICAL_DEVICE_SCREEN_V71_CLAIM_BOUNDARY)
    artifact["result_hash"] = canonical_hash(artifact)
    if output_path !== nothing
        _stage3_atomic_json_v1(String(output_path), artifact)
    end
    return artifact
end
