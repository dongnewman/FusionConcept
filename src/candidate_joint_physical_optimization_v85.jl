const JOINT_PHYSICAL_OPTIMIZATION_V85_CLAIM_BOUNDARY =
    "v85 performs candidate-bound constrained pattern search over coil shape, plasma boundary, field current, operating point, actuator timing, and controller modes. Final minimality is evaluated only after finite-filament Biot-Savart, long-horizon Poincare, candidate-specific finite-pressure DESC equilibrium, and sampled ideal-MHD DESC gates. These gates do not establish kinetic, resistive, finite-n, nonlinear, disruption, full engineering, net-power, VVUQ, originality, or all-mode device feasibility."

const V85_DESIGN_BLOCKS_V1 = (
    :coil_fourier, :coil_bspline, :current_potential, :plasma_boundary,
    :actuator_timing, :controller_modal, :field_current,
    :operating_density, :operating_temperature)

"A complete continuous design point. Every coordinate is consumed by a declared evaluator."
struct CandidateJointDesignV1
    schema_version::String
    structure_hash::String
    grammar_hash::String
    route::String
    coil_fourier_coefficients::Vector{Float64}
    coil_bspline_control_points::Vector{Float64}
    current_potential_coefficients::Vector{Float64}
    plasma_boundary_coefficients::Vector{Float64}
    actuator_timing_coefficients::Vector{Float64}
    controller_modal_coefficients::Vector{Float64}
    field_current_a::Float64
    density_scale::Float64
    temperature_scale::Float64
    design_hash::String
end

"Grammar extension. `nothing` means return the complete Pareto set."
struct JointOptimizationGrammarV1
    schema_version::String
    base_grammar::CandidateRealizationGrammarV2
    representative_policy::Union{Nothing,String}
    hard_gate_ids::Vector{String}
    grammar_hash::String
end

struct ActualDeviceComplexityManifestV2
    schema_version::String
    design_hash::String
    field_solver_input_hash::String
    component_count::Int
    power_supply_count::Int
    conductor_length_m::Float64
    maximum_curvature_m_inv::Float64
    conductor_mass_kg::Float64
    support_mass_kg::Float64
    control_complexity::Int
    bom::Dict{String,Any}
    manifest_hash::String
end

function compile_joint_optimization_grammar_v1(
        grammar::CandidateRealizationGrammarV2;
        representative_policy::Union{Nothing,AbstractString} = nothing)
    policy = representative_policy === nothing ? nothing : String(representative_policy)
    policy in (nothing, "lexicographic_complexity_v1") || throw(ArgumentError(
        "unsupported v85 representative policy $policy"))
    gates = ["finite_filament_biot_savart", "poincare_nested_surfaces",
        "finite_pressure_equilibrium", "sampled_ideal_mhd_stability"]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "base_grammar_hash" => grammar.grammar_hash,
        "structure_hash" => grammar.structure_hash,
        "representative_policy" => policy, "hard_gate_ids" => gates,
        "claim_boundary" => JOINT_PHYSICAL_OPTIMIZATION_V85_CLAIM_BOUNDARY)
    return JointOptimizationGrammarV1("1.0.0", grammar, policy, gates,
        canonical_hash(body))
end

function _v85_design_body(item::CandidateJointDesignV1)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "structure_hash" => item.structure_hash,
        "grammar_hash" => item.grammar_hash, "route" => item.route,
        "coil_fourier_coefficients" => item.coil_fourier_coefficients,
        "coil_bspline_control_points" => item.coil_bspline_control_points,
        "current_potential_coefficients" => item.current_potential_coefficients,
        "plasma_boundary_coefficients" => item.plasma_boundary_coefficients,
        "actuator_timing_coefficients" => item.actuator_timing_coefficients,
        "controller_modal_coefficients" => item.controller_modal_coefficients,
        "field_current_a" => item.field_current_a,
        "density_scale" => item.density_scale,
        "temperature_scale" => item.temperature_scale)
end

function candidate_joint_design_to_dict_v1(item::CandidateJointDesignV1)
    body = _v85_design_body(item); body["design_hash"] = item.design_hash
    return body
end

function compile_candidate_joint_design_v1(
        grammar::JointOptimizationGrammarV1; route,
        coil_fourier_coefficients, coil_bspline_control_points,
        current_potential_coefficients, plasma_boundary_coefficients,
        actuator_timing_coefficients, controller_modal_coefficients,
        field_current_a, density_scale, temperature_scale)
    route_value = String(route)
    route_value in grammar.base_grammar.allowed_routes || throw(ArgumentError(
        "route $route_value is outside the base grammar"))
    vectors = [Float64.(collect(value)) for value in (
        coil_fourier_coefficients, coil_bspline_control_points,
        current_potential_coefficients, plasma_boundary_coefficients,
        actuator_timing_coefficients, controller_modal_coefficients)]
    length.(vectors) == [5, 6, 5, 5, 5, 4] || throw(ArgumentError(
        "v85 basis coefficient lengths must be 5/6/5/5/5/4"))
    all(all(isfinite, value) for value in vectors) || throw(ArgumentError(
        "v85 coefficients must be finite"))
    3.0e4 <= Float64(field_current_a) <= 5.0e5 || throw(ArgumentError(
        "v85 field current is outside the declared design bounds"))
    0.65 <= Float64(density_scale) <= 1.35 || throw(ArgumentError(
        "v85 density scale is outside the declared design bounds"))
    0.65 <= Float64(temperature_scale) <= 1.35 || throw(ArgumentError(
        "v85 temperature scale is outside the declared design bounds"))
    provisional = CandidateJointDesignV1("1.0.0",
        grammar.base_grammar.structure_hash, grammar.grammar_hash, route_value,
        vectors[1], vectors[2], vectors[3], vectors[4], vectors[5], vectors[6],
        Float64(field_current_a), Float64(density_scale),
        Float64(temperature_scale), "")
    return CandidateJointDesignV1(provisional.schema_version,
        provisional.structure_hash, provisional.grammar_hash, provisional.route,
        provisional.coil_fourier_coefficients,
        provisional.coil_bspline_control_points,
        provisional.current_potential_coefficients,
        provisional.plasma_boundary_coefficients,
        provisional.actuator_timing_coefficients,
        provisional.controller_modal_coefficients, provisional.field_current_a,
        provisional.density_scale, provisional.temperature_scale,
        canonical_hash(_v85_design_body(provisional)))
end

function seed_candidate_joint_design_v1(grammar::JointOptimizationGrammarV1;
        physical_variant::Integer, operating_variant::Integer,
        control_variant::Integer, route::AbstractString = "closed/mixed")
    variants = compile_realization_variant_tuple_v1(grammar.base_grammar;
        physical_variant = physical_variant, operating_variant = operating_variant,
        control_variant = control_variant)
    binding = generate_decoupled_realization_binding_v1(grammar.base_grammar, variants)
    physical = binding["physical"]; operating = binding["operating"]
    control = binding["control"]
    current_rng = _v84_stream_rng(grammar.base_grammar.structure_hash,
        "v85_field_current", physical_variant)
    current = 10.0 ^ (log10(6.0e4) + rand(current_rng) *
        (log10(3.0e5) - log10(6.0e4)))
    return compile_candidate_joint_design_v1(grammar; route = route,
        coil_fourier_coefficients = physical["coil_fourier_coefficients"],
        coil_bspline_control_points = physical["coil_bspline_control_points"],
        current_potential_coefficients = physical[
            "current_potential_coefficients"],
        plasma_boundary_coefficients = physical["plasma_boundary_coefficients"],
        actuator_timing_coefficients = control["actuator_timing_coefficients"],
        controller_modal_coefficients = control["controller_modal_coefficients"],
        field_current_a = current, density_scale = operating["density_scale"],
        temperature_scale = operating["temperature_scale"])
end

function _v85_boundary_geometry(design::CandidateJointDesignV1)
    c = design.plasma_boundary_coefficients
    major = 3.0 * (1.0 + 0.08 * c[1])
    minor_r = 0.65 * (1.0 + 0.30 * c[2])
    minor_z = 0.65 * (1.0 + 0.30 * c[3])
    helical_r = 0.18 * c[4]
    helical_z = 0.18 * c[5]
    return Dict{String,Any}(
        "major_radius_m" => major, "minor_radius_r_m" => minor_r,
        "minor_radius_z_m" => minor_z, "helical_axis_r_m" => helical_r,
        "helical_axis_z_m" => helical_z, "field_periods" => 2,
        "boundary_model" => "v85_candidate_bound_five_mode_surface_v1")
end

function _v85_control_schedule(design::CandidateJointDesignV1)
    times = collect(range(0.0, 1.0; length = 33))
    actuator = [1.0 + _v84_fourier(design.actuator_timing_coefficients,
        2pi * t, 2) for t in times]
    controller = [1.0 + _v84_fourier(design.controller_modal_coefficients,
        2pi * t, 2) for t in times]
    command = actuator .* controller
    return Dict{String,Any}(
        "sample_times_normalized" => times, "actuator_multiplier" => actuator,
        "controller_multiplier" => controller, "joint_command" => command,
        "minimum_command" => minimum(command), "maximum_command" => maximum(command),
        "rms_tracking_error" => sqrt(sum((command .- 1.0) .^ 2) / length(command)),
        "capacity_multiplier" => 1.5,
        "status" => minimum(command) >= 0.0 && maximum(command) <= 1.5 ?
            "pass" : "fail")
end

function _v85_physics_design_hash(design::CandidateJointDesignV1)
    body = _v85_design_body(design)
    delete!(body, "route")
    return canonical_hash(body)
end

function v85_physical_variant_parameter_seed_v1(structure_hash::AbstractString,
        physical_variant::Integer)
    physical_variant > 0 || throw(ArgumentError(
        "physical_variant must be positive"))
    digest = canonical_hash(Dict{String,Any}(
        "structure_hash" => String(structure_hash),
        "physical_variant" => Int(physical_variant),
        "seed_stream" => "v85_base_physical_parameter_binding_v1"))
    return Int(parse(UInt64, digest[1:12]; base = 16) % UInt64(typemax(Int)))
end

function _v85_parameter_binding(topology::GraphNativeTopologyV69,
        design::CandidateJointDesignV1; basis_override = nothing,
        base_coil_count::Integer = 16, parameter_binding_seed = nothing)
    graph_isomorphism_hash_v69(topology) == design.structure_hash || throw(
        ArgumentError("v85 design and topology hashes differ"))
    physics_design_hash = _v85_physics_design_hash(design)
    seed = parameter_binding_seed === nothing ?
        Int(parse(UInt64, physics_design_hash[1:12]; base = 16) %
            UInt64(typemax(Int))) : Int(parameter_binding_seed)
    seed >= 0 || throw(ArgumentError("v85 parameter binding seed must be nonnegative"))
    binding = generate_physical_parameter_binding_v71(topology, seed)
    boundary = _v85_boundary_geometry(design)
    control = _v85_control_schedule(design)
    boundary["geometry_class"] = binding["geometry_class"]
    binding["major_radius_m"] = boundary["major_radius_m"]
    binding["minor_radius_m"] = min(boundary["minor_radius_r_m"],
        boundary["minor_radius_z_m"])
    binding["half_length_m"] = 1.5 * (1.0 +
        0.20 * design.plasma_boundary_coefficients[1])
    boundary["half_length_m"] = binding["half_length_m"]
    binding["coil_clearance_m"] = 0.22
    binding["field_coil_count"] = Int(base_coil_count) + 2
    binding["v85_base_coil_count"] = Int(base_coil_count)
    binding["field_current_a"] = design.field_current_a
    binding["field_turns"] = 10
    binding["conductor_radius_m"] = 0.045
    binding["target_total_ion_density_m3"] *= design.density_scale
    binding["target_ion_temperature_kev"] *= design.temperature_scale
    binding["target_electron_temperature_kev"] *= design.temperature_scale
    binding["heating_power_w"] *= max(0.65, sum(control["joint_command"]) /
        length(control["joint_command"]))
    binding["actuator_capacity_w"] = control["capacity_multiplier"] *
        Float64(binding["heating_power_w"])
    binding["v85_design_hash"] = design.design_hash
    binding["v85_physics_design_hash"] = physics_design_hash
    binding["v85_parameter_binding_seed"] = seed
    binding["v85_parameter_binding_seed_scope"] = parameter_binding_seed === nothing ?
        "legacy_full_design_hash_v1" : "fixed_physical_variant_stream_v1"
    binding["v85_route"] = design.route
    binding["v85_boundary"] = boundary
    binding["v85_control_schedule"] = control
    binding["v85_low_order_bases"] = Dict{String,Any}(
        "coil_fourier_coefficients" => design.coil_fourier_coefficients,
        "coil_bspline_control_points" => design.coil_bspline_control_points,
        "current_potential_coefficients" => design.current_potential_coefficients,
        "plasma_boundary_coefficients" => design.plasma_boundary_coefficients,
        "actuator_timing_coefficients" => design.actuator_timing_coefficients,
        "controller_modal_coefficients" => design.controller_modal_coefficients)
    if basis_override !== nothing
        override = _stage3_plain_v1(basis_override)
        low_order_lengths = Dict(
            "coil_fourier_coefficients" =>
                length(design.coil_fourier_coefficients),
            "coil_bspline_control_points" =>
                length(design.coil_bspline_control_points),
            "current_potential_coefficients" =>
                length(design.current_potential_coefficients))
        effective_override = deepcopy(override)
        for key in keys(low_order_lengths)
            haskey(override, key) || continue
            values = Float64.(override[key])
            low_order_length = low_order_lengths[key]
            length(values) >= low_order_length || throw(ArgumentError(
                "v85 basis override $key truncates the declared low-order basis"))
            # Low-order coordinates remain owned by the optimizer.  A promoted
            # basis contributes only the appended tail; otherwise the serialized
            # parent coefficients silently mask every low-order trial point.
            effective = vcat(Float64.(binding["v85_low_order_bases"][key]),
                values[low_order_length + 1:end])
            binding["v85_low_order_bases"][key] = effective
            effective_override[key] = effective
        end
        binding["v85_basis_override"] = effective_override
        binding["v85_winding_model"] = String(get(override, "winding_model",
            "v85_joint_base_helical_low_order_filaments_v1"))
        binding["v85_basis_override_hash"] = canonical_hash(effective_override)
        transition = String(get(override, "grammar_transition", ""))
        if transition == "declared_internal_current_ring_flux_core_v1"
            fraction = Float64(get(override, "internal_ring_current_fraction", 0.08))
            0.02 <= fraction <= 0.14 || throw(ArgumentError(
                "declared internal-ring current fraction is outside [0.02,0.14]"))
            shield_radius = Float64(get(override,
                "internal_ring_excluded_core_radius_m", 0.08))
            shield_radius > Float64(binding["conductor_radius_m"]) || throw(
                ArgumentError("internal-ring excluded core must contain conductor"))
            binding["v85_internal_current_ring"] = Dict{String,Any}(
                "component_model_id" =>
                    "declared_internal_toroidal_current_ring_flux_core_v1",
                "current_fraction" => fraction,
                "excluded_core_radius_m" => shield_radius,
                "candidate_component" => true,
                "benchmark_only" => false)
            boundary["inner_excluded_flux_core_radius_m"] = shield_radius
            boundary["plasma_region_topology"] =
                "annular_region_around_declared_internal_flux_core_v1"
        elseif transition == "prescribed_electrostatic_end_barrier_pair_v1"
            potential_fraction = Float64(get(override,
                "end_barrier_potential_fraction_of_injector", 0.75))
            0.10 <= potential_fraction <= 1.0 || throw(ArgumentError(
                "end-barrier potential fraction is outside [0.10,1.0]"))
            binding["v85_open_end_barrier"] = Dict{String,Any}(
                "component_model_id" =>
                    "prescribed_electrostatic_end_barrier_pair_v1",
                "potential_kev" => potential_fraction * Float64(binding[
                    "injector_energy_kev"]),
                "potential_fraction_of_injector" => potential_fraction,
                "barrier_count" => 2,
                "candidate_component" => true,
                "self_consistent_ambipolar_solution" => false,
                "kinetic_credit" => false)
        end
    else
        binding["v85_winding_model"] =
            "v85_joint_base_helical_low_order_filaments_v1"
    end
    _graph_v69_assert_label_free(binding, "v85_parameter_binding")
    return binding
end

function _v85_winding_surface_field_component_v3(port, region, binding)
    String(region["geometry_class"]) == "toroidal_volume_v1" || throw(
        ArgumentError("v85 winding-surface grammar requires toroidal geometry"))
    major = Float64(region["major_radius_m"])
    minor = Float64(region["minor_radius_m"])
    clearance = Float64(binding["coil_clearance_m"])
    current = Float64(binding["field_current_a"])
    turns = Int(binding["field_turns"])
    bases = binding["v85_low_order_bases"]
    fourier = Float64.(bases["coil_fourier_coefficients"])
    bspline = Float64.(bases["coil_bspline_control_points"])
    potential = Float64.(bases["current_potential_coefficients"])
    boundary = binding["v85_boundary"]
    field_periods = Int(boundary["field_periods"])
    requested_count = Int(get(binding, "v85_base_coil_count", 16))
    coil_count = max(4field_periods,
        field_periods * cld(requested_count, field_periods))
    fourier_order = max(0, div(length(fourier) - 1, 2))
    potential_order = max(0, div(length(potential) - 1, 2))
    winding_minor = minor + clearance
    point_count = 128
    loops = Dict{String,Any}[]
    for coil_index in 1:coil_count
        toroidal_phase = 2pi * (coil_index - 1) / coil_count
        symmetry_phase = field_periods * toroidal_phase
        potential_value = _v84_fourier(potential, symmetry_phase,
            potential_order)
        current_fraction = clamp(1.0 + 0.55 * potential_value, 0.25, 1.75)
        centerline = Vector{Vector{Float64}}()
        for point_index in 0:point_count
            poloidal = 2pi * point_index / point_count
            helical_argument = poloidal - symmetry_phase
            fourier_shape = clamp(_v84_fourier(fourier, helical_argument,
                fourier_order), -0.65, 0.65)
            spline_shape = clamp(_v84_periodic_cubic_bspline(bspline,
                helical_argument + 0.5symmetry_phase), -0.65, 0.65)
            # The previous fixed 0.18-rad tilt forced every candidate above the
            # boundary-normal-field gate.  Here the low-order current-potential
            # and shape modes control a bounded tilt around a conservative base.
            nonplanar_tilt = clamp(0.055 + 0.10 * abs(tanh(potential_value)) +
                0.055 * tanh(fourier_shape) +
                0.020 * sin(2poloidal - symmetry_phase), 0.010, 0.180)
            local_poloidal = poloidal + 0.16 * fourier_shape
            local_minor = winding_minor * (1.0 + 0.10 * spline_shape +
                0.05 * fourier_shape)
            cylindrical_radius = major + local_minor * cos(local_poloidal) +
                Float64(boundary["helical_axis_r_m"]) * cos(symmetry_phase)
            vertical = local_minor * sin(local_poloidal) +
                Float64(boundary["helical_axis_z_m"]) * sin(symmetry_phase)
            phi = toroidal_phase + nonplanar_tilt * sin(poloidal)
            push!(centerline, [cylindrical_radius * cos(phi),
                cylindrical_radius * sin(phi), vertical])
        end
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_v85_winding_surface_$coil_index",
            "winding_role" => "winding_surface_current_potential_contour",
            "centerline_m" => centerline,
            "current_a" => current * current_fraction,
            "turns" => turns,
            "supply_group" => "winding_surface_supply_$coil_index",
            "toroidal_phase_rad" => toroidal_phase,
            "current_potential_sample" => potential_value,
            "basis_binding_hash" => canonical_hash(bases)))
    end
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" =>
            "winding_surface_current_potential_contour_filaments_v3",
        "loops" => loops, "base_coil_count" => coil_count,
        "helical_module_count" => 0, "field_periods" => field_periods,
        "current_potential_spatial_sample_count" => coil_count,
        "conductor" => Dict{String,Any}(
            "material_model" => "candidate_bound_copper_equivalent_v1",
            "density_kg_m3" => 8960.0,
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" =>
            "candidate_bound_winding_surface_finite_filament_biot_savart_v3")
end

function _v85_current_potential_v7(coefficients, theta::Real, phi::Real,
        field_periods::Integer, dominant_m::Integer, dominant_n::Integer)
    # A normalized current potential on the periodic winding-surface domain.
    # The secular phi term creates closed poloidal modular contours.  Bounded
    # double-Fourier terms deform them non-planarly without changing their
    # winding class.  Scaling by n*NFP keeps d(Phi)/d(phi) positive so every
    # declared level has one deterministic branch.
    value = Float64(phi)
    derivative_phi = 1.0
    modes = Dict{String,Any}[]
    for (index, raw_coefficient) in enumerate(Float64.(coefficients))
        pair_index = cld(index, 2)
        poloidal_mode = Int(dominant_m) + div(pair_index - 1, 2)
        toroidal_mode = Int(dominant_n) + mod(pair_index - 1, 2)
        toroidal_wave_number = toroidal_mode * Int(field_periods)
        amplitude = 0.60 * tanh(raw_coefficient) /
            (toroidal_wave_number * sqrt(Float64(pair_index)))
        argument = poloidal_mode * Float64(theta) -
            toroidal_wave_number * Float64(phi)
        if isodd(index)
            value += amplitude * cos(argument)
            derivative_phi += amplitude * toroidal_wave_number * sin(argument)
            parity = "cos"
        else
            value += amplitude * sin(argument)
            derivative_phi -= amplitude * toroidal_wave_number * cos(argument)
            parity = "sin"
        end
        push!(modes, Dict{String,Any}(
            "coefficient_index" => index,
            "poloidal_mode_m" => poloidal_mode,
            "toroidal_mode_n" => toroidal_mode,
            "parity" => parity,
            "normalized_amplitude" => amplitude))
    end
    return (value = value, derivative_phi = derivative_phi, modes = modes)
end

function _v85_current_potential_contour_phi_v7(coefficients, theta::Real,
        contour_level::Real, field_periods::Integer, dominant_m::Integer,
        dominant_n::Integer)
    phi = Float64(contour_level)
    minimum_derivative = Inf
    for _ in 1:16
        sample = _v85_current_potential_v7(coefficients, theta, phi,
            field_periods, dominant_m, dominant_n)
        minimum_derivative = min(minimum_derivative, sample.derivative_phi)
        sample.derivative_phi > 0.20 || throw(ArgumentError(
            "v85 v7 current-potential contour lost monotonic phi branch"))
        residual = sample.value - Float64(contour_level)
        phi -= residual / sample.derivative_phi
        abs(residual) <= 1.0e-12 && break
    end
    final = _v85_current_potential_v7(coefficients, theta, phi,
        field_periods, dominant_m, dominant_n)
    residual = abs(final.value - Float64(contour_level))
    residual <= 1.0e-9 || throw(ArgumentError(
        "v85 v7 current-potential contour solve did not converge"))
    return (phi = phi, residual = residual,
        minimum_derivative = min(minimum_derivative,
            final.derivative_phi))
end

function _v85_winding_surface_point_v6(region, boundary, clearance::Real,
        fourier, bspline, theta::Real, phi::Real)
    major = Float64(region["major_radius_m"])
    field_periods = Int(boundary["field_periods"])
    winding_minor_r = Float64(boundary["minor_radius_r_m"]) +
        Float64(clearance)
    winding_minor_z = Float64(boundary["minor_radius_z_m"]) +
        Float64(clearance)
    fourier_order = max(0, div(length(fourier) - 1, 2))
    fourier_shape = clamp(_v84_fourier(fourier,
        Float64(theta) - field_periods * Float64(phi), fourier_order),
        -0.55, 0.55)
    spline_shape = clamp(_v84_periodic_cubic_bspline(bspline,
        Float64(theta) + 0.5field_periods * Float64(phi)), -0.55, 0.55)
    radial_scale = 1.0 + 0.08fourier_shape + 0.04spline_shape
    vertical_scale = 1.0 + 0.05fourier_shape - 0.06spline_shape
    axis_radius = major + Float64(boundary["helical_axis_r_m"]) *
        cos(field_periods * Float64(phi))
    axis_vertical = Float64(boundary["helical_axis_z_m"]) *
        sin(field_periods * Float64(phi))
    cylindrical_radius = axis_radius + winding_minor_r * radial_scale *
        cos(Float64(theta))
    vertical = axis_vertical + winding_minor_z * vertical_scale *
        sin(Float64(theta))
    return [cylindrical_radius * cos(Float64(phi)),
        cylindrical_radius * sin(Float64(phi)), vertical]
end

function _v85_helical_current_potential_v6(coefficients, theta::Real,
        phi::Real, field_periods::Integer, dominant_n::Integer)
    value = Float64(theta) -
        Int(dominant_n) * Int(field_periods) * Float64(phi)
    derivative_theta = 1.0
    modes = Dict{String,Any}[]
    for (index, raw_coefficient) in enumerate(Float64.(coefficients))
        pair_index = cld(index, 2)
        poloidal_mode = 1 + div(pair_index - 1, 2)
        toroidal_mode = mod(pair_index - 1, 2)
        amplitude = 0.12 * tanh(raw_coefficient) /
            (poloidal_mode * sqrt(Float64(pair_index)))
        argument = poloidal_mode * Float64(theta) -
            toroidal_mode * Int(field_periods) * Float64(phi)
        if isodd(index)
            value += amplitude * cos(argument)
            derivative_theta -= amplitude * poloidal_mode * sin(argument)
            parity = "cos"
        else
            value += amplitude * sin(argument)
            derivative_theta += amplitude * poloidal_mode * cos(argument)
            parity = "sin"
        end
        push!(modes, Dict{String,Any}(
            "coefficient_index" => index,
            "poloidal_mode_m" => poloidal_mode,
            "toroidal_mode_n" => toroidal_mode,
            "parity" => parity,
            "normalized_amplitude" => amplitude))
    end
    return (value = value, derivative_theta = derivative_theta, modes = modes)
end

function _v85_helical_current_potential_contour_theta_v6(coefficients,
        phi::Real, contour_level::Real, field_periods::Integer,
        dominant_n::Integer)
    theta = Float64(contour_level) +
        Int(dominant_n) * Int(field_periods) * Float64(phi)
    minimum_derivative = Inf
    for _ in 1:16
        sample = _v85_helical_current_potential_v6(coefficients, theta, phi,
            field_periods, dominant_n)
        minimum_derivative = min(minimum_derivative, sample.derivative_theta)
        sample.derivative_theta > 0.20 || throw(ArgumentError(
            "v85 v6 current-potential contour lost monotonic theta branch"))
        residual = sample.value - Float64(contour_level)
        theta -= residual / sample.derivative_theta
        abs(residual) <= 1.0e-12 && break
    end
    final = _v85_helical_current_potential_v6(coefficients, theta, phi,
        field_periods, dominant_n)
    residual = abs(final.value - Float64(contour_level))
    residual <= 1.0e-9 || throw(ArgumentError(
        "v85 v6 current-potential contour solve did not converge"))
    return (theta = theta, residual = residual,
        minimum_derivative = min(minimum_derivative,
            final.derivative_theta))
end

function _v85_winding_surface_current_potential_component_v6(port, region,
        binding)
    String(region["geometry_class"]) == "toroidal_volume_v1" || throw(
        ArgumentError("v85 v6 winding-surface grammar requires toroidal geometry"))
    bases = binding["v85_low_order_bases"]
    fourier = Float64.(bases["coil_fourier_coefficients"])
    bspline = Float64.(bases["coil_bspline_control_points"])
    potential = Float64.(bases["current_potential_coefficients"])
    boundary = binding["v85_boundary"]
    field_periods = Int(boundary["field_periods"])
    override = get(binding, "v85_basis_override", Dict{String,Any}())
    dominant_m = Int(get(override, "dominant_poloidal_mode_m", 1))
    dominant_n = Int(get(override, "dominant_toroidal_mode_n", 1))
    dominant_m == 1 || throw(ArgumentError(
        "v85 v6 supports only closed m=1 helical contours"))
    dominant_n > 0 || throw(ArgumentError(
        "v85 v6 dominant toroidal mode must be positive"))
    requested_count = Int(get(override, "contour_count",
        get(binding, "v85_base_coil_count", 16)))
    contour_count = max(4field_periods,
        field_periods * cld(requested_count, field_periods))
    supply_group_count = clamp(Int(get(override, "supply_group_count",
        field_periods)), 1, contour_count)
    contour_current_scale = Float64(get(override,
        "contour_current_scale", 0.35))
    0.02 <= contour_current_scale <= 1.50 || throw(ArgumentError(
        "v85 v6 contour-current scale is outside [0.02,1.50]"))
    current = Float64(binding["field_current_a"]) * contour_current_scale
    turns = Int(binding["field_turns"])
    clearance = Float64(binding["coil_clearance_m"])
    point_count = 192
    loops = Dict{String,Any}[]
    contour_points = Vector{Vector{Vector{Float64}}}()
    maximum_residual = 0.0
    minimum_derivative = Inf
    maximum_closure_error = 0.0
    for contour_index in 1:contour_count
        contour_level = 2pi * (contour_index - 1) / contour_count
        centerline = Vector{Vector{Float64}}()
        for point_index in 0:point_count
            phi = 2pi * point_index / point_count
            solved = _v85_helical_current_potential_contour_theta_v6(
                potential, phi, contour_level, field_periods, dominant_n)
            maximum_residual = max(maximum_residual, solved.residual)
            minimum_derivative = min(minimum_derivative,
                solved.minimum_derivative)
            push!(centerline, _v85_winding_surface_point_v6(region, boundary,
                clearance, fourier, bspline, solved.theta, phi))
        end
        closure_error = norm(last(centerline) - first(centerline))
        maximum_closure_error = max(maximum_closure_error, closure_error)
        closure_error <= 1.0e-8 || throw(ArgumentError(
            "v85 v6 current-potential contour is not geometrically closed"))
        centerline[end] = copy(first(centerline))
        push!(contour_points, centerline)
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_v85_v6_contour_$contour_index",
            "winding_role" => "two_dimensional_current_potential_level_set",
            "centerline_m" => centerline,
            "current_a" => current,
            "turns" => turns,
            "supply_group" => "winding_surface_contour_supply_$((contour_index - 1) % supply_group_count + 1)",
            "contour_level_rad" => contour_level,
            "dominant_mode_m" => dominant_m,
            "dominant_mode_n" => dominant_n,
            "contour_poloidal_winding_number" => dominant_n * field_periods,
            "contour_toroidal_winding_number" => 1,
            "field_periods" => field_periods,
            "basis_binding_hash" => canonical_hash(bases)))
    end
    minimum_spacing = Inf
    for contour_index in 1:contour_count, point_index in 1:point_count
        next_contour = mod1(contour_index + 1, contour_count)
        minimum_spacing = min(minimum_spacing, norm(
            contour_points[contour_index][point_index] -
            contour_points[next_contour][point_index]))
    end
    mode_sample = _v85_helical_current_potential_v6(potential, 0.0, 0.0,
        field_periods, dominant_n)
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" =>
            "winding_surface_current_potential_level_set_filaments_v6",
        "loops" => loops,
        "base_coil_count" => contour_count,
        "helical_module_count" => 0,
        "current_potential_domain_dimension" => 2,
        "current_potential_domain" => "periodic_theta_phi_winding_surface_v1",
        "contour_extractor" => "implicit_newton_continuation_v1",
        "contour_count" => contour_count,
        "contour_point_count" => point_count,
        "dominant_mode_m" => dominant_m,
        "dominant_mode_n" => dominant_n,
        "field_periods" => field_periods,
        "winding_surface_gap_m" => clearance,
        "supply_group_count" => supply_group_count,
        "contour_current_scale" => contour_current_scale,
        "current_potential_modes" => mode_sample.modes,
        "maximum_contour_residual" => maximum_residual,
        "minimum_potential_theta_derivative" => minimum_derivative,
        "maximum_contour_closure_error_m" => maximum_closure_error,
        "minimum_same_phi_contour_spacing_m" => minimum_spacing,
        "current_potential_spatial_sample_count" =>
            contour_count * point_count,
        "conductor" => Dict{String,Any}(
            "material_model" => "candidate_bound_copper_equivalent_v1",
            "density_kg_m3" => 8960.0,
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" =>
            "candidate_bound_2d_current_potential_contour_finite_filament_v6")
end

function _v85_winding_surface_current_potential_component_v7(port, region,
        binding)
    String(region["geometry_class"]) == "toroidal_volume_v1" || throw(
        ArgumentError("v85 v7 winding-surface grammar requires toroidal geometry"))
    bases = binding["v85_low_order_bases"]
    fourier = Float64.(bases["coil_fourier_coefficients"])
    bspline = Float64.(bases["coil_bspline_control_points"])
    potential = Float64.(bases["current_potential_coefficients"])
    boundary = binding["v85_boundary"]
    field_periods = Int(boundary["field_periods"])
    override = get(binding, "v85_basis_override", Dict{String,Any}())
    dominant_m = Int(get(override, "dominant_poloidal_mode_m", 1))
    dominant_n = Int(get(override, "dominant_toroidal_mode_n", 1))
    dominant_m > 0 || throw(ArgumentError(
        "v85 v7 dominant poloidal mode must be positive"))
    dominant_n > 0 || throw(ArgumentError(
        "v85 v7 dominant toroidal mode must be positive"))
    requested_count = Int(get(override, "contour_count",
        get(binding, "v85_base_coil_count", 16)))
    contour_count = max(4field_periods,
        field_periods * cld(requested_count, field_periods))
    supply_group_count = clamp(Int(get(override, "supply_group_count",
        field_periods)), 1, contour_count)
    contour_current_scale = Float64(get(override,
        "contour_current_scale", 0.35))
    0.02 <= contour_current_scale <= 1.50 || throw(ArgumentError(
        "v85 v7 contour-current scale is outside [0.02,1.50]"))
    current = Float64(binding["field_current_a"]) * contour_current_scale
    turns = Int(binding["field_turns"])
    clearance = Float64(binding["coil_clearance_m"])
    point_count = 192
    loops = Dict{String,Any}[]
    contour_points = Vector{Vector{Vector{Float64}}}()
    maximum_residual = 0.0
    minimum_derivative = Inf
    maximum_closure_error = 0.0
    for contour_index in 1:contour_count
        contour_level = 2pi * (contour_index - 1) / contour_count
        centerline = Vector{Vector{Float64}}()
        for point_index in 0:point_count
            theta = 2pi * point_index / point_count
            solved = _v85_current_potential_contour_phi_v7(potential, theta,
                contour_level, field_periods, dominant_m, dominant_n)
            maximum_residual = max(maximum_residual, solved.residual)
            minimum_derivative = min(minimum_derivative,
                solved.minimum_derivative)
            push!(centerline, _v85_winding_surface_point_v6(region, boundary,
                clearance, fourier, bspline, theta, solved.phi))
        end
        closure_error = norm(last(centerline) - first(centerline))
        maximum_closure_error = max(maximum_closure_error, closure_error)
        closure_error <= 1.0e-8 || throw(ArgumentError(
            "v85 v7 current-potential contour is not geometrically closed"))
        centerline[end] = copy(first(centerline))
        push!(contour_points, centerline)
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_v85_v7_contour_$contour_index",
            "winding_role" => "two_dimensional_current_potential_level_set",
            "centerline_m" => centerline,
            "current_a" => current,
            "turns" => turns,
            "supply_group" => "winding_surface_contour_supply_$((contour_index - 1) % supply_group_count + 1)",
            "contour_level_rad" => contour_level,
            "dominant_mode_m" => dominant_m,
            "dominant_mode_n" => dominant_n,
            "contour_poloidal_winding_number" => 1,
            "contour_toroidal_winding_number" => 0,
            "field_periods" => field_periods,
            "basis_binding_hash" => canonical_hash(bases)))
    end
    minimum_spacing = Inf
    for contour_index in 1:contour_count, point_index in 1:point_count
        next_contour = mod1(contour_index + 1, contour_count)
        minimum_spacing = min(minimum_spacing, norm(
            contour_points[contour_index][point_index] -
            contour_points[next_contour][point_index]))
    end
    mode_sample = _v85_current_potential_v7(potential, 0.0, 0.0,
        field_periods, dominant_m, dominant_n)
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" =>
            "winding_surface_current_potential_level_set_filaments_v7",
        "loops" => loops,
        "base_coil_count" => contour_count,
        "helical_module_count" => 0,
        "current_potential_domain_dimension" => 2,
        "current_potential_domain" => "periodic_theta_phi_winding_surface_v1",
        "contour_extractor" => "implicit_newton_continuation_v1",
        "contour_count" => contour_count,
        "contour_point_count" => point_count,
        "dominant_mode_m" => dominant_m,
        "dominant_mode_n" => dominant_n,
        "field_periods" => field_periods,
        "winding_surface_gap_m" => clearance,
        "supply_group_count" => supply_group_count,
        "contour_current_scale" => contour_current_scale,
        "current_potential_modes" => mode_sample.modes,
        "maximum_contour_residual" => maximum_residual,
        "minimum_potential_phi_derivative" => minimum_derivative,
        "maximum_contour_closure_error_m" => maximum_closure_error,
        "minimum_same_theta_contour_spacing_m" => minimum_spacing,
        "current_potential_spatial_sample_count" =>
            contour_count * point_count,
        "conductor" => Dict{String,Any}(
            "material_model" => "candidate_bound_copper_equivalent_v1",
            "density_kg_m3" => 8960.0,
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" =>
            "candidate_bound_2d_current_potential_contour_finite_filament_v7")
end

function _v85_coherent_helical_field_component_v4(port, region, binding)
    String(region["geometry_class"]) == "toroidal_volume_v1" || throw(
        ArgumentError("v85 coherent-helical grammar requires toroidal geometry"))
    major = Float64(region["major_radius_m"])
    minor = Float64(region["minor_radius_m"])
    clearance = Float64(binding["coil_clearance_m"])
    current = Float64(binding["field_current_a"])
    turns = Int(binding["field_turns"])
    bases = binding["v85_low_order_bases"]
    fourier = Float64.(bases["coil_fourier_coefficients"])
    bspline = Float64.(bases["coil_bspline_control_points"])
    potential = Float64.(bases["current_potential_coefficients"])
    boundary = binding["v85_boundary"]
    base_radius = minor + clearance
    base_count = Int(get(binding, "v85_base_coil_count", 16))
    loops = Dict{String,Any}[]
    for coil_index in 1:base_count
        phi = 2pi * (coil_index - 1) / base_count
        radial = [cos(phi), sin(phi), 0.0]
        center = major .* radial
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_v85_v4_base_$coil_index",
            "winding_role" => "toroidal_field_base",
            "centerline_m" => _v71_circular_loop(center, radial,
                [0.0, 0.0, 1.0], base_radius, 64),
            "current_a" => current, "turns" => turns,
            "supply_group" => "base_toroidal_supply"))
    end
    module_count = 12
    point_count = 192
    potential_order = max(0, div(length(potential) - 1, 2))
    fourier_order = max(0, div(length(fourier) - 1, 2))
    override = get(binding, "v85_basis_override", Dict{String,Any}())
    helical_current_scale = Float64(get(override,
        "helical_current_scale", 1.0))
    0.0 < helical_current_scale <= 1.5 || throw(ArgumentError(
        "v85 coherent-helical current scale is outside (0,1.5]"))
    for module_index in 1:module_count
        phase = 2pi * (module_index - 1) / module_count
        potential_sample = _v84_fourier(potential, phase + 0.17,
            potential_order)
        current_fraction = helical_current_scale * clamp(
            0.08 + 0.45 * potential_sample, 0.01, 0.22)
        centerline = Vector{Vector{Float64}}()
        for point_index in 0:point_count
            phi = 2pi * point_index / point_count
            shape = clamp(_v84_fourier(fourier, phi + phase,
                fourier_order), -0.45, 0.45)
            spline = clamp(_v84_periodic_cubic_bspline(bspline,
                phi - phase), -0.45, 0.45)
            theta = 2phi + phase + 0.18 * shape
            deformation = clamp(shape + spline, -0.30, 0.30)
            helical = Float64(boundary["helical_axis_r_m"]) * cos(2phi) +
                Float64(boundary["helical_axis_z_m"]) * sin(2phi)
            local_radius = (base_radius + helical) *
                (1.0 + 0.16 * deformation)
            cylindrical_radius = major + local_radius * cos(theta)
            push!(centerline, [cylindrical_radius * cos(phi),
                cylindrical_radius * sin(phi), local_radius * sin(theta)])
        end
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_v85_v4_helical_$module_index",
            "winding_role" => "coherent_current_potential_helical_contour",
            "centerline_m" => centerline,
            "current_a" => current * current_fraction,
            "turns" => turns,
            "supply_group" => "helical_supply_$module_index",
            "helical_phase_rad" => phase,
            "current_potential_sample" => potential_sample,
            "basis_binding_hash" => canonical_hash(bases)))
    end
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" => String(get(binding, "v85_winding_model",
            "coherent_helical_current_potential_contour_filaments_v4")),
        "loops" => loops, "base_coil_count" => base_count,
        "helical_module_count" => module_count,
        "helical_current_scale" => helical_current_scale,
        "current_potential_spatial_sample_count" => module_count,
        "conductor" => Dict{String,Any}(
            "material_model" => "candidate_bound_copper_equivalent_v1",
            "density_kg_m3" => 8960.0,
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" => helical_current_scale == 1.0 ?
            "candidate_bound_coherent_helical_finite_filament_biot_savart_v4" :
            "candidate_bound_coherent_helical_finite_filament_biot_savart_v5")
end

function _v85_joint_field_component(port, region, binding)
    minor = Float64(region["minor_radius_m"])
    clearance = Float64(binding["coil_clearance_m"])
    current = Float64(binding["field_current_a"])
    turns = Int(binding["field_turns"])
    bases = binding["v85_low_order_bases"]
    fourier = Float64.(bases["coil_fourier_coefficients"])
    bspline = Float64.(bases["coil_bspline_control_points"])
    potential = Float64.(bases["current_potential_coefficients"])
    boundary = binding["v85_boundary"]
    loops = Dict{String,Any}[]
    base_radius = minor + clearance
    if String(get(binding, "v85_winding_model", "")) ==
            "winding_surface_current_potential_contour_filaments_v3" &&
            String(region["geometry_class"]) == "toroidal_volume_v1"
        return _v85_winding_surface_field_component_v3(port, region, binding)
    end
    if String(get(binding, "v85_winding_model", "")) ==
            "winding_surface_current_potential_level_set_filaments_v6" &&
            String(region["geometry_class"]) == "toroidal_volume_v1"
        return _v85_winding_surface_current_potential_component_v6(port,
            region, binding)
    end
    if String(get(binding, "v85_winding_model", "")) ==
            "winding_surface_current_potential_level_set_filaments_v7" &&
            String(region["geometry_class"]) == "toroidal_volume_v1"
        return _v85_winding_surface_current_potential_component_v7(port,
            region, binding)
    end
    if String(get(binding, "v85_winding_model", "")) in (
            "coherent_helical_current_potential_contour_filaments_v4",
            "coherent_helical_current_potential_contour_filaments_v5") &&
            String(region["geometry_class"]) == "toroidal_volume_v1"
        return _v85_coherent_helical_field_component_v4(port, region, binding)
    end
    if String(region["geometry_class"]) != "toroidal_volume_v1"
        half_length = Float64(region["half_length_m"])
        linear_count = max(4, Int(get(binding, "v85_base_coil_count", 16)) ÷ 2)
        fourier_order = max(0, div(length(fourier) - 1, 2))
        potential_order = max(0, div(length(potential) - 1, 2))
        for coil_index in 1:linear_count
            phase = 2pi * (coil_index - 1) / linear_count
            radius = base_radius * (1.0 + 0.20 * clamp(
                _v84_fourier(fourier, phase, fourier_order) +
                _v84_periodic_cubic_bspline(bspline, phase), -0.4, 0.4))
            z = half_length * (-1.15 + 2.30 * (coil_index - 1) /
                max(linear_count - 1, 1)) + 0.12 * minor *
                _v84_fourier(fourier, phase + 0.21, fourier_order)
            current_fraction = clamp(0.70 + _v84_fourier(potential,
                phase + 0.19, potential_order), 0.25, 1.20)
            push!(loops, Dict{String,Any}(
                "loop_id" => "$(port["port_id"])_v85_linear_$coil_index",
                "winding_role" => "open_linear_field_module",
                "centerline_m" => _v71_circular_loop([0.0, 0.0, z],
                    [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], radius, 64),
                "current_a" => current * current_fraction, "turns" => turns,
                "supply_group" => "linear_supply_$coil_index"))
        end
        return Dict{String,Any}(
            "component_kind" => "finite_filament_coil_array_v1",
            "winding_basis" => "v85_joint_open_linear_low_order_filaments_v1",
            "loops" => loops, "base_coil_count" => linear_count,
            "helical_module_count" => 0,
            "conductor" => Dict{String,Any}(
                "material_model" => "candidate_bound_copper_equivalent_v1",
                "density_kg_m3" => 8960.0,
                "radius_m" => Float64(binding["conductor_radius_m"]),
                "current_density_limit_a_m2" => 3.0e8,
                "allowable_magnetic_stress_pa" => 4.0e8),
            "model_fidelity" => "candidate_bound_finite_filament_biot_savart_v85")
    end
    major = Float64(region["major_radius_m"])
    base_count = Int(get(binding, "v85_base_coil_count", 16))
    for coil_index in 1:base_count
        phi = 2pi * (coil_index - 1) / base_count
        radial = [cos(phi), sin(phi), 0.0]
        center = major .* radial
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_v85_base_$coil_index",
            "winding_role" => "toroidal_field_base",
            "centerline_m" => _v71_circular_loop(center, radial, [0.0, 0.0, 1.0],
                base_radius, 64), "current_a" => current, "turns" => turns,
            "supply_group" => "base_toroidal_supply"))
    end
    point_count = 192
    for module_index in 1:2
        phase = pi * (module_index - 1)
        centerline = Vector{Vector{Float64}}()
        # Offset the two module sampling phases so sine current-potential modes
        # do not vanish identically at 0/pi.
        potential_order = max(0, div(length(potential) - 1, 2))
        fourier_order = max(0, div(length(fourier) - 1, 2))
        current_fraction = clamp(0.08 + _v84_fourier(potential,
            phase + 0.37 * module_index, potential_order),
            -0.25, 0.25)
        for point_index in 0:point_count
            phi = 2pi * point_index / point_count
            theta = 2phi + phase + 0.35 * _v84_fourier(fourier, phi + phase,
                fourier_order)
            deformation = clamp(_v84_fourier(fourier, phi + phase,
                fourier_order) +
                _v84_periodic_cubic_bspline(bspline, phi - phase), -0.35, 0.35)
            helical = Float64(boundary["helical_axis_r_m"]) * cos(2phi) +
                Float64(boundary["helical_axis_z_m"]) * sin(2phi)
            local_radius = (base_radius + helical) * (1.0 + 0.25 * deformation)
            cylindrical_radius = major + local_radius * cos(theta)
            push!(centerline, [cylindrical_radius * cos(phi),
                cylindrical_radius * sin(phi), local_radius * sin(theta)])
        end
        push!(loops, Dict{String,Any}(
            "loop_id" => "$(port["port_id"])_v85_helical_$module_index",
            "winding_role" => "joint_low_order_helical_module",
            "centerline_m" => centerline,
            "current_a" => current * current_fraction, "turns" => turns,
            "supply_group" => "helical_supply_$module_index",
            "basis_binding_hash" => canonical_hash(bases)))
    end
    return Dict{String,Any}(
        "component_kind" => "finite_filament_coil_array_v1",
        "winding_basis" => "v85_joint_base_helical_low_order_filaments_v1",
        "loops" => loops, "base_coil_count" => base_count,
        "helical_module_count" => 2,
        "conductor" => Dict{String,Any}(
            "material_model" => "candidate_bound_copper_equivalent_v1",
            "density_kg_m3" => 8960.0,
            "radius_m" => Float64(binding["conductor_radius_m"]),
            "current_density_limit_a_m2" => 3.0e8,
            "allowable_magnetic_stress_pa" => 4.0e8),
        "model_fidelity" => "candidate_bound_finite_filament_biot_savart_v85")
end

function compile_joint_physical_realization_v85(
        topology::GraphNativeTopologyV69,
        compilation::GraphTopologyCompilationV69,
        design::CandidateJointDesignV1; basis_override = nothing,
        base_coil_count::Integer = 16, parameter_binding_seed = nothing)
    binding = _v85_parameter_binding(topology, design;
        basis_override = basis_override, base_coil_count = base_coil_count,
        parameter_binding_seed = parameter_binding_seed)
    base = compile_physical_device_realization_v71(topology, compilation;
        parameter_binding = binding)
    base.completeness == :complete || return (binding = binding, realization = base)
    regions = Dict(String(item["region_id"]) => item for item in
        base.geometry["regions"])
    ports = Dict(String(item["port_id"]) => item for item in topology.ports)
    components = deepcopy(base.components); mappings = deepcopy(base.port_mappings)
    for index in eachindex(components)
        component = components[index]
        String(component["component_kind"]) == "finite_filament_coil_array_v1" ||
            continue
        port = ports[String(component["bound_port_id"])]
        replacement = merge(Dict{String,Any}(
            "component_id" => component["component_id"],
            "realizer_id" => "v85_joint_physical_realizer_v1",
            "region_id" => component["region_id"],
            "bound_port_id" => component["bound_port_id"],
            "bound_resource_ids" => component["bound_resource_ids"]),
            _v85_joint_field_component(port,
                regions[String(component["region_id"])], binding))
        replacement["component_hash"] = canonical_hash(replacement)
        components[index] = replacement
    end
    for mapping in mappings
        port = ports[String(mapping["port_id"])]
        String(port["port_kind"]) == "field_source" || continue
        mapping["realizer_id"] = "v85_joint_physical_realizer_v1"
    end
    if haskey(binding, "v85_internal_current_ring")
        region = _v71_primary_region(base)
        String(region["geometry_class"]) == "toroidal_volume_v1" || throw(
            ArgumentError("internal current-ring grammar requires toroidal geometry"))
        field_index = findfirst(component -> String(component[
            "component_kind"]) == "finite_filament_coil_array_v1", components)
        field_index === nothing && throw(ArgumentError(
            "internal current-ring grammar requires a finite-filament field component"))
        component = components[field_index]
        specification = binding["v85_internal_current_ring"]
        loop = Dict{String,Any}(
            "loop_id" => "declared_internal_current_ring",
            "winding_role" => "declared_internal_flux_core_field_source",
            "centerline_m" => _v71_circular_loop([0.0, 0.0, 0.0],
                [1.0, 0.0, 0.0], [0.0, 1.0, 0.0],
                Float64(region["major_radius_m"]), 256),
            "current_a" => Float64(binding["field_current_a"]) *
                Float64(specification["current_fraction"]),
            "turns" => Int(binding["field_turns"]),
            "supply_group" => "internal_flux_core_supply",
            "excluded_core_radius_m" => specification[
                "excluded_core_radius_m"],
            "candidate_component" => true, "benchmark_only" => false)
        external_loops = [existing for existing in component["loops"] if
            String(get(existing, "winding_role", "")) == "toroidal_field_base"]
        isempty(external_loops) && throw(ArgumentError(
            "internal current-ring grammar requires external toroidal-field loops"))
        component["loops"] = vcat(deepcopy(external_loops), [loop])
        component["winding_basis"] =
            "external_filaments_plus_declared_internal_flux_core_v1"
        component["internal_flux_core"] = deepcopy(specification)
        component["component_hash"] = canonical_hash(component)
        components[field_index] = component
    end
    if haskey(binding, "v85_open_end_barrier")
        region = _v71_primary_region(base)
        String(region["geometry_class"]) == "linear_volume_v1" || throw(
            ArgumentError("end-barrier grammar requires linear open geometry"))
        actuator_index = findfirst(component -> String(component[
            "component_kind"]) == "directed_particle_energy_injector_v1", components)
        actuator_index === nothing && throw(ArgumentError(
            "end-barrier grammar requires a directed energy actuator"))
        component = components[actuator_index]
        specification = binding["v85_open_end_barrier"]
        center = Float64.(region["center_m"])
        half_length = Float64(region["half_length_m"])
        component["electrostatic_end_barrier_pair"] = merge(
            deepcopy(specification), Dict{String,Any}(
                "end_plane_centers_m" => [center .+ [0.0, 0.0, -half_length],
                    center .+ [0.0, 0.0, half_length]],
                "aperture_radius_m" => 0.85 * Float64(region[
                    "minor_radius_m"]),
                "model_fidelity" =>
                    "prescribed_potential_maxwellian_suppression_screen_v1"))
        component["component_hash"] = canonical_hash(component)
        components[actuator_index] = component
    end
    registry_hash = canonical_hash(Dict{String,Any}(
        "base_registry_hash" => base.registry_hash,
        "extension_id" => "v85_joint_physical_realizer_v1",
        "design_hash" => design.design_hash))
    claim = "Exact v85 design coefficients and any declared structural-transition components compile into candidate-bound finite filaments and actuators; operating and control coordinates remain candidate-bound. Internal flux cores and prescribed end barriers are explicit candidate components, not benchmark credit. This is a screening realization, not a build-ready device."
    body = Dict{String,Any}(
        "schema_version" => base.schema_version, "topology_hash" => base.topology_hash,
        "compilation_hash" => base.compilation_hash,
        "candidate_binding_hash" => base.candidate_binding_hash,
        "registry_hash" => registry_hash, "completeness" => String(base.completeness),
        "conclusion" => String(base.conclusion),
        "classification_code" => "v85_joint_realization_requires_hard_gates",
        "geometry" => base.geometry, "components" => components,
        "port_mappings" => mappings,
        "dependency_mappings" => base.dependency_mappings,
        "missing_requirements" => base.missing_requirements,
        "claim_boundary" => claim)
    realization = PhysicalDeviceRealizationV71(base.schema_version,
        base.topology_hash, base.compilation_hash, base.candidate_binding_hash,
        registry_hash, base.completeness, base.conclusion,
        "v85_joint_realization_requires_hard_gates", base.geometry, components,
        mappings, base.dependency_mappings, base.missing_requirements, claim,
        canonical_hash(body))
    return (binding = binding, realization = realization)
end

function v85_solver_input_hashes_v1(compiled; poincare_budget = Dict{String,Any}(
        "turns" => 32, "steps_per_turn" => 180, "fourier_order" => 4,
        "bin_count" => 16,
        "boundary_frame_semantics" =>
            "candidate_bound_periodic_axis_elliptic_v3"))
    realization = compiled.realization; binding = compiled.binding
    field_components = [Dict{String,Any}(
        "loops" => [Dict{String,Any}(
            "centerline_m" => loop["centerline_m"],
            "current_a" => loop["current_a"], "turns" => loop["turns"])
            for loop in component["loops"]],
        "conductor_radius_m" => component["conductor"]["radius_m"])
        for component in realization.components if
            String(component["component_kind"]) == "finite_filament_coil_array_v1"]
    region = _v71_primary_region(realization)
    field_body = Dict{String,Any}(
        "region" => Dict("geometry_class" => region["geometry_class"],
            "major_radius_m" => get(region, "major_radius_m", nothing),
            "minor_radius_m" => region["minor_radius_m"],
            "half_length_m" => get(region, "half_length_m", nothing)),
        "candidate_boundary_surface" => binding["v85_boundary"],
        "field_components" => field_components)
    field_hash = canonical_hash(field_body)
    poincare_hash = canonical_hash(Dict{String,Any}(
        "field_solver_input_hash" => field_hash, "budget" => poincare_budget))
    equilibrium_body = Dict{String,Any}(
        "boundary" => binding["v85_boundary"],
        "density_m3" => binding["target_total_ion_density_m3"],
        "ion_temperature_kev" => binding["target_ion_temperature_kev"],
        "electron_temperature_kev" => binding["target_electron_temperature_kev"],
        "field_current_a" => binding["field_current_a"])
    equilibrium_hash = canonical_hash(equilibrium_body)
    stability_hash = canonical_hash(Dict{String,Any}(
        "equilibrium_solver_input_hash" => equilibrium_hash,
        "settings" => _desc_stability_settings_medium()))
    return Dict{String,Any}(
        "field_solver_input_hash" => field_hash,
        "poincare_solver_input_hash" => poincare_hash,
        "equilibrium_solver_input_hash" => equilibrium_hash,
        "stability_solver_input_hash" => stability_hash)
end

function _v85_boundary_point_and_normal(boundary, theta, phi)
    r0 = Float64(boundary["major_radius_m"])
    ar = Float64(boundary["minor_radius_r_m"])
    az = Float64(boundary["minor_radius_z_m"])
    hr = Float64(boundary["helical_axis_r_m"])
    hz = Float64(boundary["helical_axis_z_m"])
    nfp = Int(boundary["field_periods"])
    radius = r0 + ar * cos(theta) + hr * cos(nfp * phi)
    z = az * sin(theta) + hz * sin(nfp * phi)
    point = [radius * cos(phi), radius * sin(phi), z]
    dtheta = [-ar * sin(theta) * cos(phi),
        -ar * sin(theta) * sin(phi), az * cos(theta)]
    dradius_dphi = -nfp * hr * sin(nfp * phi)
    dphi = [dradius_dphi * cos(phi) - radius * sin(phi),
        dradius_dphi * sin(phi) + radius * cos(phi),
        nfp * hz * cos(nfp * phi)]
    raw_normal = cross(dphi, dtheta)
    normal = raw_normal ./ max(norm(raw_normal), eps())
    return point, normal
end

function _v85_boundary_normal_field(realization, binding; theta_count = 6,
        phi_count = 8)
    cache = compile_finite_filament_field_cache_v71(realization)
    boundary = binding["v85_boundary"]
    relative = Float64[]; absolute = Float64[]; magnitudes = Float64[]
    if boundary["geometry_class"] == "toroidal_volume_v1"
        for theta_index in 0:theta_count-1, phi_index in 0:phi_count-1
            theta = 2pi * theta_index / theta_count
            phi = 2pi * phi_index / phi_count
            point, normal = _v85_boundary_point_and_normal(boundary, theta, phi)
            field = finite_filament_field_v71(cache, point)
            magnitude = norm(field); normal_field = abs(dot(field, normal))
            push!(magnitudes, magnitude); push!(absolute, normal_field)
            push!(relative, normal_field / max(magnitude, 1.0e-12))
        end
    else
        radius = min(Float64(boundary["minor_radius_r_m"]),
            Float64(boundary["minor_radius_z_m"]))
        half_length = Float64(boundary["half_length_m"])
        for zfraction in (-0.8, -0.4, 0.0, 0.4, 0.8),
                phi_index in 0:phi_count-1
            phi = 2pi * phi_index / phi_count
            point = [radius * cos(phi), radius * sin(phi),
                zfraction * half_length]
            normal = [cos(phi), sin(phi), 0.0]
            field = finite_filament_field_v71(cache, point)
            magnitude = norm(field); normal_field = abs(dot(field, normal))
            push!(magnitudes, magnitude); push!(absolute, normal_field)
            push!(relative, normal_field / max(magnitude, 1.0e-12))
        end
    end
    rms_relative = sqrt(sum(relative .^ 2) / length(relative))
    return Dict{String,Any}(
        "model_id" => "candidate_surface_normal_finite_filament_biot_savart_v1",
        "sample_count" => length(relative),
        "rms_relative_normal_field" => rms_relative,
        "maximum_relative_normal_field" => maximum(relative),
        "maximum_absolute_normal_field_t" => maximum(absolute),
        "minimum_boundary_field_t" => minimum(magnitudes),
        "field_cache_hash" => cache.cache_hash)
end

function _v85_fast_field_summary(realization)
    if _v71_primary_region(realization)["geometry_class"] == "toroidal_volume_v1"
        return _v80_fast_field_proxy(realization)
    end
    cache = compile_finite_filament_field_cache_v71(realization)
    evidence = _v71_field_evidence(realization, cache)
    return Dict{String,Any}(
        "model_id" => "candidate_biot_savart_linear_field_summary_v1",
        "median_transform_proxy" => 0.0,
        "minimum_field_t" => evidence["minimum_field_t"],
        "maximum_field_t" => evidence["maximum_field_t"],
        "relative_field_ripple" => evidence["relative_field_spread"],
        "field_cache_hash" => cache.cache_hash)
end

function _v85_short_fieldline_acquisition(realization;
        target_toroidal_turns::Integer = 2,
        steps_per_turn::Integer = 60, candidate_boundary = nothing)
    region = _v71_primary_region(realization)
    String(region["geometry_class"]) == "toroidal_volume_v1" || return
        Dict{String,Any}("status" => "not_applicable",
            "acquisition_only" => true, "feasibility_credit" => false)
    cache = compile_finite_filament_field_cache_v71(realization)
    fractions = (0.15, 0.35, 0.55)
    traces = [_v81_trace_to_section(realization, cache,
        _v81_boundary_start_point(region, candidate_boundary, fraction);
        target_toroidal_turns = target_toroidal_turns,
        steps_per_turn = steps_per_turn,
        candidate_boundary = candidate_boundary) for fraction in fractions]
    expected_steps = max(1, target_toroidal_turns * steps_per_turn)
    completion = minimum(min(1.0, Float64(trace["completed_steps"]) /
        expected_steps) for trace in traces)
    escape_fraction = count(trace -> Bool(trace["escaped"]), traces) /
        length(traces)
    transform = minimum(abs(Float64(trace["rotational_transform"])) for trace in
        traces)
    sampled_radii = Float64[crossing["normalized_minor_radius"] for trace in traces
        for crossing in trace["crossings"]]
    wall_margin = isempty(sampled_radii) ? 0.0 : max(0.0,
        1.0 - maximum(sampled_radii))
    shared_crossings = minimum(length(trace["crossings"]) for trace in traces)
    ordering = if shared_crossings == 0
        0.0
    else
        count(index -> traces[1]["crossings"][index][
            "normalized_minor_radius"] < traces[2]["crossings"][index][
            "normalized_minor_radius"] < traces[3]["crossings"][index][
            "normalized_minor_radius"], 1:shared_crossings) / shared_crossings
    end
    penalty = 1.5 * escape_fraction + 0.6 * (1.0 - completion) +
        0.4 * max(0.0, 0.02 - transform) / 0.02 +
        0.35 * (1.0 - ordering) + 0.30 * max(0.0, 0.05 - wall_margin) / 0.05
    return Dict{String,Any}(
        "status" => "evaluated", "model_id" =>
            "two_turn_candidate_biot_savart_fieldline_acquisition_v1",
        "target_toroidal_turns" => target_toroidal_turns,
        "steps_per_turn" => steps_per_turn,
        "trace_escape_fraction" => escape_fraction,
        "minimum_trace_completion_fraction" => completion,
        "minimum_absolute_rotational_transform" => transform,
        "minimum_sampled_wall_margin_fraction" => wall_margin,
        "surface_ordering_fraction" => ordering,
        "acquisition_penalty" => penalty, "traces" => traces,
        "acquisition_only" => true, "feasibility_credit" => false)
end

function _v85_axis_aware_short_fieldline_acquisition_v2(realization;
        target_toroidal_turns::Integer = 2,
        steps_per_turn::Integer = 60, candidate_boundary = nothing,
        axis_locator_refinement_levels::Integer = 4,
        axis_locator_maximum_closure_residual::Real = 0.04)
    region = _v71_primary_region(realization)
    String(region["geometry_class"]) == "toroidal_volume_v1" || return
        Dict{String,Any}("status" => "not_applicable",
            "model_id" =>
                "candidate_biot_savart_periodic_axis_fieldline_acquisition_v2",
            "acquisition_only" => true, "feasibility_credit" => false)
    candidate_boundary === nothing && throw(ArgumentError(
        "axis-aware acquisition requires a candidate-bound boundary"))
    target_toroidal_turns > 0 && steps_per_turn > 0 || throw(ArgumentError(
        "axis-aware acquisition budget must be positive"))
    axis_locator_refinement_levels > 0 || throw(ArgumentError(
        "axis-aware acquisition refinement count must be positive"))
    axis_locator_maximum_closure_residual > 0 || throw(ArgumentError(
        "axis-aware acquisition closure threshold must be positive"))
    cache = compile_finite_filament_field_cache_v71(realization)
    boundary = _v71_plain(candidate_boundary)
    axis_evidence = _v81_locate_periodic_magnetic_axis(realization, cache,
        boundary; steps_per_turn = min(80, Int(steps_per_turn)),
        refinement_levels = Int(axis_locator_refinement_levels),
        maximum_closure_residual =
            Float64(axis_locator_maximum_closure_residual))
    axis_located = String(axis_evidence["status"]) == "located"
    axis_violation = axis_located ? 0.0 : 1.0
    if !axis_located
        penalty = 2.0 * axis_violation + 0.6 + 0.4 + 0.35 + 0.30
        return Dict{String,Any}(
            "status" => "periodic_magnetic_axis_not_located",
            "model_id" =>
                "candidate_biot_savart_periodic_axis_fieldline_acquisition_v2",
            "target_toroidal_turns" => Int(target_toroidal_turns),
            "steps_per_turn" => Int(steps_per_turn),
            "start_minor_radius_fractions" => [0.15, 0.35, 0.55],
            "candidate_boundary_frame_used" => true,
            "axis_relative_start_points" => true,
            "periodic_magnetic_axis" => axis_evidence,
            "axis_location_violation" => axis_violation,
            "trace_escape_fraction" => 0.0,
            "minimum_trace_completion_fraction" => 0.0,
            "minimum_absolute_rotational_transform" => 0.0,
            "minimum_sampled_wall_margin_fraction" => 0.0,
            "surface_ordering_fraction" => 0.0,
            "acquisition_penalty" => penalty,
            "traces" => Dict{String,Any}[],
            "completion_semantics" =>
                "minimum_toroidal_turn_fraction_v2",
            "escape_semantics" =>
                "candidate_boundary_normalized_minor_radius_v2",
            "acquisition_only" => true, "feasibility_credit" => false)
    end
    axis_reference = axis_evidence["axis_reference"]
    fractions = (0.15, 0.35, 0.55)
    traces = [_v81_trace_to_section(realization, cache,
        _v81_axis_start_point(region, boundary, axis_reference, fraction);
        target_toroidal_turns = target_toroidal_turns,
        steps_per_turn = steps_per_turn,
        candidate_boundary = boundary,
        axis_reference = axis_reference) for fraction in fractions]
    completion = minimum(clamp(abs(Float64(trace["toroidal_turns"])) /
        Int(target_toroidal_turns), 0.0, 1.0) for trace in traces)
    escape_fraction = count(trace -> Bool(trace["escaped"]), traces) /
        length(traces)
    transform = minimum(abs(Float64(trace["rotational_transform"])) for trace in
        traces)
    sampled_radii = Float64[crossing["normalized_minor_radius"] for trace in
        traces for crossing in trace["crossings"]]
    wall_margin = isempty(sampled_radii) ? 0.0 : max(0.0,
        1.0 - maximum(sampled_radii))
    shared_crossings = minimum(length(trace["crossings"]) for trace in traces)
    ordering = if shared_crossings == 0
        0.0
    else
        count(index -> traces[1]["crossings"][index][
            "normalized_minor_radius"] < traces[2]["crossings"][index][
            "normalized_minor_radius"] < traces[3]["crossings"][index][
            "normalized_minor_radius"], 1:shared_crossings) / shared_crossings
    end
    penalty = 2.0 * axis_violation + 1.5 * escape_fraction +
        0.6 * (1.0 - completion) +
        0.4 * max(0.0, 0.02 - transform) / 0.02 +
        0.35 * (1.0 - ordering) +
        0.30 * max(0.0, 0.05 - wall_margin) / 0.05
    return Dict{String,Any}(
        "status" => "evaluated", "model_id" =>
            "candidate_biot_savart_periodic_axis_fieldline_acquisition_v2",
        "target_toroidal_turns" => Int(target_toroidal_turns),
        "steps_per_turn" => Int(steps_per_turn),
        "start_minor_radius_fractions" => collect(fractions),
        "candidate_boundary_frame_used" => true,
        "axis_relative_start_points" => true,
        "periodic_magnetic_axis" => axis_evidence,
        "axis_location_violation" => axis_violation,
        "trace_escape_fraction" => escape_fraction,
        "minimum_trace_completion_fraction" => completion,
        "minimum_absolute_rotational_transform" => transform,
        "minimum_sampled_wall_margin_fraction" => wall_margin,
        "surface_ordering_fraction" => ordering,
        "acquisition_penalty" => penalty, "traces" => traces,
        "completion_semantics" => "minimum_toroidal_turn_fraction_v2",
        "escape_semantics" =>
            "candidate_boundary_normalized_minor_radius_v2",
        "acquisition_only" => true, "feasibility_credit" => false)
end

function _v85_fast_constrained_evaluation(topology, compilation,
        design::CandidateJointDesignV1; basis_override = nothing,
        base_coil_count::Integer = 16,
        parameter_binding_seed = nothing,
        poincare_aware_acquisition::Bool = false,
        capability_acquisition = nothing,
        acquisition_toroidal_turns::Integer = 2,
        acquisition_steps_per_turn::Integer = 60)
    compiled = compile_joint_physical_realization_v85(topology, compilation, design;
        basis_override = basis_override, base_coil_count = base_coil_count,
        parameter_binding_seed = parameter_binding_seed)
    realization = compiled.realization; binding = compiled.binding
    if realization.completeness != :complete
        return Dict{String,Any}("status" => "incomplete", "violation" => Inf,
            "merit" => Inf, "compiled" => compiled,
            "classification_code" => realization.classification_code)
    end
    field = _v85_fast_field_summary(realization)
    normal = _v85_boundary_normal_field(realization, binding)
    control = binding["v85_control_schedule"]
    conductor = first(_v71_field_components(realization))["conductor"]
    current_density = abs(design.field_current_a) /
        (pi * Float64(conductor["radius_m"])^2)
    current_density_ratio = current_density /
        Float64(conductor["current_density_limit_a_m2"])
    transform = Float64(field["median_transform_proxy"])
    ripple = Float64(field["relative_field_ripple"])
    minimum_field = Float64(field["minimum_field_t"])
    rms_normal = Float64(normal["rms_relative_normal_field"])
    pressure_factor = design.density_scale * design.temperature_scale
    toroidal = _v71_primary_region(realization)["geometry_class"] ==
        "toroidal_volume_v1"
    violations = Dict{String,Float64}(
        "minimum_field" => max(0.0, (0.10 - minimum_field) / 0.10),
        "field_ripple" => max(0.0, (ripple - 3.0) / 3.0),
        "boundary_normal_field" => max(0.0, (rms_normal - 0.18) / 0.18),
        "transform_proxy" => toroidal ? max(0.0,
            (0.02 - transform) / 0.02) : 0.0,
        "current_density" => max(0.0, current_density_ratio - 1.0),
        "control_schedule" => control["status"] == "pass" ? 0.0 :
            max(0.0, -Float64(control["minimum_command"])) +
            max(0.0, Float64(control["maximum_command"]) - 1.5),
        "screening_pressure_load" => max(0.0, pressure_factor - 1.55) / 1.55)
    violation = sum(values(violations))
    # This merit guides sampling only. It grants no gate credit.
    fieldline = poincare_aware_acquisition && toroidal ?
        _v85_short_fieldline_acquisition(realization;
            target_toroidal_turns = acquisition_toroidal_turns,
            steps_per_turn = acquisition_steps_per_turn,
            candidate_boundary = binding["v85_boundary"]) : nothing
    fieldline_penalty = fieldline === nothing ? 0.0 : Float64(fieldline[
        "acquisition_penalty"])
    capability_record = capability_acquisition === nothing ? nothing :
        capability_acquisition(compiled)
    capability_penalty = capability_record === nothing ? 0.0 : Float64(
        capability_record["acquisition_penalty"])
    merit = 4.0 * rms_normal + (toroidal ? 0.8 * abs(transform - 0.06) : 0.0) +
        0.15 * min(ripple, 20.0) + 0.03 * Float64(control["rms_tracking_error"]) +
        0.02 * abs(pressure_factor - 1.0) + 0.01 * current_density_ratio +
        fieldline_penalty + capability_penalty
    return Dict{String,Any}(
        "status" => "evaluated", "violation" => violation, "merit" => merit,
        "constraint_violations" => violations, "field_evidence" => field,
        "normal_field_evidence" => normal, "control_evidence" => control,
        "short_fieldline_acquisition" => fieldline,
        "capability_acquisition" => capability_record,
        "current_density_a_m2" => current_density,
        "compiled" => compiled,
        "acquisition_only" => true)
end

function _v85_design_vector(design::CandidateJointDesignV1)
    return vcat(design.coil_fourier_coefficients,
        design.coil_bspline_control_points,
        design.current_potential_coefficients,
        design.plasma_boundary_coefficients,
        design.actuator_timing_coefficients,
        design.controller_modal_coefficients,
        [log10(design.field_current_a), design.density_scale,
            design.temperature_scale])
end

function _v85_coordinate_metadata()
    names = String[]; lower = Float64[]; upper = Float64[]; steps = Float64[]
    for (prefix, count, bound, step) in (("coil_fourier", 5, 0.35, 0.04),
            ("coil_bspline", 6, 0.35, 0.04),
            ("current_potential", 5, 0.25, 0.03),
            ("plasma_boundary", 5, 0.50, 0.04),
            ("actuator_timing", 5, 0.30, 0.03),
            ("controller_modal", 4, 0.30, 0.03))
        for index in 1:count
            push!(names, "$(prefix)_$index"); push!(lower, -bound)
            push!(upper, bound); push!(steps, step)
        end
    end
    append!(names, ["log10_field_current", "operating_density",
        "operating_temperature"])
    append!(lower, [log10(3.0e4), 0.65, 0.65])
    append!(upper, [log10(5.0e5), 1.35, 1.35])
    append!(steps, [0.10, 0.06, 0.06])
    return (names = names, lower = lower, upper = upper, steps = steps)
end

function _v85_design_from_vector(grammar::JointOptimizationGrammarV1,
        route, vector)
    x = Float64.(collect(vector)); length(x) == 33 || throw(ArgumentError(
        "v85 design vector must contain 33 coordinates"))
    cursor = 1
    take(count) = begin value = x[cursor:cursor + count - 1]; cursor += count; value end
    return compile_candidate_joint_design_v1(grammar; route = route,
        coil_fourier_coefficients = take(5),
        coil_bspline_control_points = take(6),
        current_potential_coefficients = take(5),
        plasma_boundary_coefficients = take(5),
        actuator_timing_coefficients = take(5),
        controller_modal_coefficients = take(4),
        field_current_a = 10.0 ^ x[31], density_scale = x[32],
        temperature_scale = x[33])
end

_v85_acquisition_rank(result) = (Float64(result["violation"]),
    Float64(result["merit"]))

const _V85_TRUST_REGION_PRIMES = Int[2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31,
    37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107,
    109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181,
    191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263,
    269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349,
    353, 359, 367, 373, 379, 383, 389, 397, 401]

function _v85_radical_inverse(index::Integer, base::Integer)
    value = 0.0; fraction = 1.0 / Int(base); cursor = Int(index)
    while cursor > 0
        value += fraction * (cursor % Int(base))
        cursor ÷= Int(base); fraction /= Int(base)
    end
    return value
end

function _v85_trust_region_direction(sample_index::Integer, dimension::Integer)
    dimension <= length(_V85_TRUST_REGION_PRIMES) || throw(ArgumentError(
        "v85 trust-region dimension exceeds its declared low-discrepancy basis"))
    return [2.0 * _v85_radical_inverse(Int(sample_index),
        _V85_TRUST_REGION_PRIMES[index]) - 1.0 for index in 1:Int(dimension)]
end

function _v85_augmented_optimizer_state(design::CandidateJointDesignV1,
        basis_override)
    base = _v85_coordinate_metadata()
    vector = _v85_design_vector(design)
    names = copy(base.names); lower = copy(base.lower)
    upper = copy(base.upper); steps = copy(base.steps)
    layout = Dict{String,UnitRange{Int}}()
    basis_override === nothing && return (vector = vector,
        metadata = (names = names, lower = lower, upper = upper, steps = steps),
        layout = layout, override = nothing)
    override = _stage3_plain_v1(basis_override)
    specifications = (
        ("coil_fourier_coefficients", length(design.coil_fourier_coefficients),
            0.35, 0.025, "coil_fourier_high_order"),
        ("coil_bspline_control_points",
            length(design.coil_bspline_control_points), 0.35, 0.025,
            "coil_bspline_high_order"),
        ("current_potential_coefficients",
            length(design.current_potential_coefficients), 0.25, 0.020,
            "current_potential_high_order"))
    for (key, low_length, bound, step, prefix) in specifications
        haskey(override, key) || continue
        values = Float64.(override[key])
        length(values) >= low_length || throw(ArgumentError(
            "v85 augmented optimizer received a truncated $key override"))
        tail = values[low_length + 1:end]
        isempty(tail) && continue
        first_index = length(vector) + 1
        append!(vector, tail)
        append!(names, ["$(prefix)_$index" for index in
            low_length + 1:length(values)])
        append!(lower, fill(-Float64(bound), length(tail)))
        append!(upper, fill(Float64(bound), length(tail)))
        append!(steps, fill(Float64(step), length(tail)))
        layout[key] = first_index:length(vector)
    end
    if haskey(override, "helical_current_scale")
        push!(vector, Float64(override["helical_current_scale"]))
        push!(names, "helical_current_scale")
        push!(lower, 0.15); push!(upper, 1.25); push!(steps, 0.10)
        layout["helical_current_scale"] = length(vector):length(vector)
    end
    if haskey(override, "contour_current_scale")
        push!(vector, Float64(override["contour_current_scale"]))
        push!(names, "contour_current_scale")
        push!(lower, 0.05); push!(upper, 1.25); push!(steps, 0.10)
        layout["contour_current_scale"] = length(vector):length(vector)
    end
    return (vector = vector,
        metadata = (names = names, lower = lower, upper = upper, steps = steps),
        layout = layout, override = override)
end

function _v85_state_to_design_and_override(grammar::JointOptimizationGrammarV1,
        route, state, template_override, layout)
    design = _v85_design_from_vector(grammar, route, state[1:33])
    template_override === nothing && return design, nothing
    override = deepcopy(template_override)
    low_order_lengths = Dict(
        "coil_fourier_coefficients" =>
            length(design.coil_fourier_coefficients),
        "coil_bspline_control_points" =>
            length(design.coil_bspline_control_points),
        "current_potential_coefficients" =>
            length(design.current_potential_coefficients))
    low_order_values = Dict(
        "coil_fourier_coefficients" => design.coil_fourier_coefficients,
        "coil_bspline_control_points" => design.coil_bspline_control_points,
        "current_potential_coefficients" =>
            design.current_potential_coefficients)
    for (key, range) in layout
        if key in ("helical_current_scale", "contour_current_scale")
            override[key] = Float64(only(state[range]))
            continue
        end
        values = Float64.(override[key])
        low_length = low_order_lengths[key]
        override[key] = vcat(Float64.(low_order_values[key]),
            Float64.(state[range]))
        length(override[key]) == length(values) || throw(ArgumentError(
            "v85 augmented optimizer changed the declared $key basis length"))
    end
    return design, override
end

function _v85_coordinate_order(names, sweep::Integer)
    order = sortperm(eachindex(names); by = index -> canonical_hash(
        Dict("coordinate_name" => names[index], "scheduler" =>
            "cross_block_deterministic_v1")))
    isempty(order) && return order
    offset = mod(Int(sweep) - 1, length(order))
    return vcat(order[offset + 1:end], order[1:offset])
end

function optimize_joint_physical_design_v85(topology, compilation,
        grammar::JointOptimizationGrammarV1, initial::CandidateJointDesignV1;
        maximum_sweeps::Integer = 2, maximum_evaluations::Integer = 160,
        step_contraction::Real = 0.5, basis_override = nothing,
        base_coil_count::Integer = 16,
        poincare_aware_acquisition::Bool = false,
        capability_acquisition = nothing,
        trust_region_expansion::Real = 1.15,
        minimum_trust_radius_fraction::Real = 0.05,
        parameter_binding_seed = nothing,
        boundary_resamples_per_sweep::Integer = 2,
        boundary_resampling_violation::Real = 0.50,
        global_resamples_per_sweep::Integer = 2,
        acquisition_toroidal_turns::Integer = 2,
        acquisition_steps_per_turn::Integer = 60)
    maximum_sweeps >= 0 || throw(ArgumentError("maximum_sweeps must be nonnegative"))
    maximum_evaluations >= 1 || throw(ArgumentError(
        "maximum_evaluations must be positive"))
    0.0 < step_contraction < 1.0 || throw(ArgumentError(
        "step_contraction must lie strictly between zero and one"))
    trust_region_expansion >= 1.0 || throw(ArgumentError(
        "trust_region_expansion must be at least one"))
    0.0 < minimum_trust_radius_fraction <= 1.0 || throw(ArgumentError(
        "minimum_trust_radius_fraction must lie in (0,1]"))
    boundary_resamples_per_sweep >= 0 || throw(ArgumentError(
        "boundary_resamples_per_sweep cannot be negative"))
    global_resamples_per_sweep >= 0 || throw(ArgumentError(
        "global_resamples_per_sweep cannot be negative"))
    acquisition_toroidal_turns > 0 || throw(ArgumentError(
        "acquisition_toroidal_turns must be positive"))
    acquisition_steps_per_turn > 0 || throw(ArgumentError(
        "acquisition_steps_per_turn must be positive"))
    boundary_resampling_violation >= 0 || throw(ArgumentError(
        "boundary_resampling_violation cannot be negative"))
    state = _v85_augmented_optimizer_state(initial, basis_override)
    metadata = state.metadata; x = copy(state.vector)
    template_override = state.override; layout = state.layout
    initial_steps = copy(metadata.steps); steps = copy(initial_steps)
    best_design = initial; best_basis_override = template_override
    best = _v85_fast_constrained_evaluation(topology, compilation, best_design;
        basis_override = best_basis_override, base_coil_count = base_coil_count,
        parameter_binding_seed = parameter_binding_seed,
        poincare_aware_acquisition = poincare_aware_acquisition,
        capability_acquisition = capability_acquisition,
        acquisition_toroidal_turns = acquisition_toroidal_turns,
        acquisition_steps_per_turn = acquisition_steps_per_turn)
    trace = Dict{String,Any}[Dict{String,Any}(
        "evaluation" => 1, "event" => "initial", "design_hash" => initial.design_hash,
        "violation" => best["violation"], "merit" => best["merit"])]
    evaluations = 1; evaluated_coordinates = Set{String}()
    boundary_resampling_evaluations = 0; global_resampling_evaluations = 0
    trust_region_contractions = 0
    trust_region_expansions = 0
    for sweep in 1:Int(maximum_sweeps)
        improved = false
        for sample in 1:Int(global_resamples_per_sweep)
            evaluations >= maximum_evaluations && break
            direction = _v85_trust_region_direction(
                (sweep - 1) * max(1, Int(global_resamples_per_sweep)) + sample,
                length(x))
            trial_x = clamp.(x .+ steps .* direction, metadata.lower,
                metadata.upper)
            trial_x == x && continue
            trial_design, trial_override = _v85_state_to_design_and_override(
                grammar, initial.route, trial_x, template_override, layout)
            trial = _v85_fast_constrained_evaluation(topology, compilation,
                trial_design; basis_override = trial_override,
                base_coil_count = base_coil_count,
                parameter_binding_seed = parameter_binding_seed,
                poincare_aware_acquisition = poincare_aware_acquisition,
                capability_acquisition = capability_acquisition,
                acquisition_toroidal_turns = acquisition_toroidal_turns,
                acquisition_steps_per_turn = acquisition_steps_per_turn)
            evaluations += 1; global_resampling_evaluations += 1
            if _v85_acquisition_rank(trial) < _v85_acquisition_rank(best)
                x = trial_x; best = trial; best_design = trial_design
                best_basis_override = trial_override; improved = true
                push!(trace, Dict{String,Any}(
                    "evaluation" => evaluations,
                    "event" => "accepted_global_low_discrepancy_resample",
                    "sweep" => sweep, "sample" => sample,
                    "design_hash" => best_design.design_hash,
                    "violation" => best["violation"], "merit" => best["merit"]))
            end
        end
        for coordinate in _v85_coordinate_order(metadata.names, sweep)
            evaluations >= maximum_evaluations && break
            push!(evaluated_coordinates, metadata.names[coordinate])
            local_x = copy(x); local_best = best; local_design = best_design
            local_override = best_basis_override
            for direction in (-1.0, 1.0)
                evaluations >= maximum_evaluations && break
                trial_x = copy(x)
                trial_x[coordinate] = clamp(x[coordinate] +
                    direction * steps[coordinate], metadata.lower[coordinate],
                    metadata.upper[coordinate])
                trial_x[coordinate] == x[coordinate] && continue
                trial_design, trial_override = _v85_state_to_design_and_override(
                    grammar, initial.route, trial_x, template_override, layout)
                trial = _v85_fast_constrained_evaluation(topology, compilation,
                    trial_design; basis_override = trial_override,
                    base_coil_count = base_coil_count,
                    parameter_binding_seed = parameter_binding_seed,
                    poincare_aware_acquisition = poincare_aware_acquisition,
                    capability_acquisition = capability_acquisition,
                    acquisition_toroidal_turns = acquisition_toroidal_turns,
                    acquisition_steps_per_turn = acquisition_steps_per_turn)
                evaluations += 1
                if _v85_acquisition_rank(trial) < _v85_acquisition_rank(local_best)
                    local_x = trial_x; local_best = trial; local_design = trial_design
                    local_override = trial_override
                end
            end
            if _v85_acquisition_rank(local_best) < _v85_acquisition_rank(best)
                x = local_x; best = local_best; best_design = local_design
                best_basis_override = local_override
                improved = true
                push!(trace, Dict{String,Any}(
                    "evaluation" => evaluations, "event" => "accepted_coordinate",
                    "sweep" => sweep, "coordinate" => metadata.names[coordinate],
                    "design_hash" => best_design.design_hash,
                    "violation" => best["violation"], "merit" => best["merit"]))
            end
        end
        if Float64(best["violation"]) <= Float64(boundary_resampling_violation)
            for sample in 1:Int(boundary_resamples_per_sweep)
                evaluations >= maximum_evaluations && break
                direction = _v85_trust_region_direction(
                    (sweep - 1) * max(1, Int(boundary_resamples_per_sweep)) + sample,
                    length(x))
                trial_x = clamp.(x .+ steps .* direction, metadata.lower,
                    metadata.upper)
                trial_x == x && continue
                trial_design, trial_override = _v85_state_to_design_and_override(
                    grammar, initial.route, trial_x, template_override, layout)
                trial = _v85_fast_constrained_evaluation(topology, compilation,
                    trial_design; basis_override = trial_override,
                    base_coil_count = base_coil_count,
                    parameter_binding_seed = parameter_binding_seed,
                    poincare_aware_acquisition = poincare_aware_acquisition,
                    capability_acquisition = capability_acquisition,
                    acquisition_toroidal_turns = acquisition_toroidal_turns,
                    acquisition_steps_per_turn = acquisition_steps_per_turn)
                evaluations += 1; boundary_resampling_evaluations += 1
                if _v85_acquisition_rank(trial) < _v85_acquisition_rank(best)
                    x = trial_x; best = trial; best_design = trial_design
                    best_basis_override = trial_override
                    improved = true
                    push!(trace, Dict{String,Any}(
                        "evaluation" => evaluations,
                        "event" => "accepted_feasible_boundary_resample",
                        "sweep" => sweep, "sample" => sample,
                        "design_hash" => best_design.design_hash,
                        "violation" => best["violation"],
                        "merit" => best["merit"]))
                end
            end
        end
        if improved
            steps .= min.(initial_steps,
                steps .* Float64(trust_region_expansion))
            trust_region_expansions += 1
            event = "trust_region_retained_or_expanded"
        else
            steps .*= Float64(step_contraction)
            trust_region_contractions += 1
            event = "trust_region_contracted"
        end
        push!(trace, Dict{String,Any}(
            "evaluation" => evaluations, "event" => event, "sweep" => sweep,
            "minimum_radius_fraction" => minimum(steps ./ initial_steps),
            "maximum_radius_fraction" => maximum(steps ./ initial_steps),
            "violation" => best["violation"], "merit" => best["merit"]))
        evaluations >= maximum_evaluations && break
        maximum(steps ./ initial_steps) < Float64(
            minimum_trust_radius_fraction) && break
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "optimizer" =>
            "deterministic_feasibility_first_trust_region_pattern_search_v2",
        "initial_design_hash" => initial.design_hash,
        "optimized_design" => best_design,
        "optimized_design_hash" => best_design.design_hash,
        "optimized_basis_override" => best_basis_override,
        "optimized_basis_override_hash" => best_basis_override === nothing ?
            nothing : canonical_hash(best_basis_override),
        "evaluations" => evaluations,
        "evaluated_coordinate_names" => sort!(collect(evaluated_coordinates)),
        "boundary_resampling_evaluations" => boundary_resampling_evaluations,
        "global_resampling_evaluations" => global_resampling_evaluations,
        "trust_region_contractions" => trust_region_contractions,
        "trust_region_expansions" => trust_region_expansions,
        "trust_region_policy" => Dict{String,Any}(
            "step_contraction" => Float64(step_contraction),
            "step_expansion" => Float64(trust_region_expansion),
            "minimum_radius_fraction" => Float64(minimum_trust_radius_fraction),
            "boundary_resamples_per_sweep" => Int(boundary_resamples_per_sweep),
            "global_resamples_per_sweep" => Int(global_resamples_per_sweep),
            "boundary_resampling_violation" =>
                Float64(boundary_resampling_violation),
            "acquisition_toroidal_turns" =>
                Int(acquisition_toroidal_turns),
            "acquisition_steps_per_turn" => Int(acquisition_steps_per_turn),
            "constraint_violation_precedes_merit" => true),
        "initial_rank" => [trace[1]["violation"], trace[1]["merit"]],
        "final_rank" => [best["violation"], best["merit"]],
        "acquisition_only" => true, "trace" => trace,
        "final_evaluation" => best)
end

function _v85_gate_record(gate_id, status, classification_code;
        solver_input_hash = nothing, evidence = Dict{String,Any}(),
        missing_requirements = String[])
    body = Dict{String,Any}(
        "gate_id" => String(gate_id), "status" => String(status),
        "classification_code" => String(classification_code),
        "solver_input_hash" => solver_input_hash, "evidence" => evidence,
        "missing_requirements" => String.(missing_requirements))
    body["evidence_hash"] = canonical_hash(body)
    return body
end

function evaluate_v85_biot_savart_gate_v1(compiled;
        maximum_rms_relative_normal_field::Real = 0.18)
    realization = compiled.realization; binding = compiled.binding
    realization.completeness == :complete || return _v85_gate_record(
        "finite_filament_biot_savart", "unknown", "incomplete_realization";
        missing_requirements = realization.missing_requirements)
    proxy = _v85_fast_field_summary(realization)
    normal = _v85_boundary_normal_field(realization, binding)
    conductor = first(_v71_field_components(realization))["conductor"]
    current_density = abs(Float64(binding["field_current_a"])) /
        (pi * Float64(conductor["radius_m"])^2)
    current_density_limit = Float64(conductor["current_density_limit_a_m2"])
    requirements = Dict{String,Any}(
        "minimum_field_t" => 0.10, "maximum_relative_field_ripple" => 3.0,
        "maximum_rms_relative_normal_field" =>
            Float64(maximum_rms_relative_normal_field),
        "maximum_current_density_a_m2" => current_density_limit)
    checks = Dict{String,Bool}(
        "finite_field" => all(isfinite, [Float64(proxy["minimum_field_t"]),
            Float64(proxy["maximum_field_t"]),
            Float64(proxy["relative_field_ripple"])]),
        "minimum_field" => Float64(proxy["minimum_field_t"]) >= 0.10,
        "field_ripple" => Float64(proxy["relative_field_ripple"]) <= 3.0,
        "candidate_surface_normal_field" => Float64(normal[
            "rms_relative_normal_field"]) <= maximum_rms_relative_normal_field,
        "current_density" => current_density <= current_density_limit,
        "control_schedule" => binding["v85_control_schedule"]["status"] == "pass")
    evidence = Dict{String,Any}(
        "field" => proxy, "candidate_surface_normal_field" => normal,
        "current_density_a_m2" => current_density,
        "requirements" => requirements, "checks" => checks,
        "realization_hash" => realization.realization_hash,
        "actual_finite_filament_geometry" => true)
    hashes = v85_solver_input_hashes_v1(compiled)
    passed = all(values(checks))
    return _v85_gate_record("finite_filament_biot_savart",
        passed ? "pass" : "fail",
        passed ? "candidate_biot_savart_constraints_pass" :
            "candidate_biot_savart_constraint_failure";
        solver_input_hash = hashes["field_solver_input_hash"], evidence = evidence)
end

function evaluate_v85_poincare_gate_v1(compiled, biot_gate;
        target_toroidal_turns::Integer = 128,
        steps_per_turn::Integer = 180, fourier_order::Integer = 4,
        bin_count::Integer = 16)
    biot_gate["status"] == "pass" || return _v85_gate_record(
        "poincare_nested_surfaces", "not_admitted",
        "biot_savart_hard_gate_not_passed";
        missing_requirements = ["finite_filament_biot_savart_pass"])
    realization = compiled.realization; binding = compiled.binding
    screen = screen_physical_device_v71(realization, binding; particle_count = 1,
        step_count = 1, required_transit_fraction = 1.0)
    gate = evaluate_poincare_flux_surface_gate_v81(realization, screen, binding;
        target_toroidal_turns = target_toroidal_turns,
        steps_per_turn = steps_per_turn, fourier_order = fourier_order,
        bin_count = bin_count)
    evidence = poincare_flux_surface_gate_to_dict_v81(gate)
    passed = gate.classification_code ==
        "poincare_surfaces_bounded_requires_downstream_physics"
    status = passed ? "pass" : (gate.conclusion == :unsupported ? "unsupported" :
        (gate.conclusion == :unknown ? "unknown" : "fail"))
    budget = Dict{String,Any}("turns" => target_toroidal_turns,
        "steps_per_turn" => steps_per_turn, "fourier_order" => fourier_order,
        "bin_count" => bin_count,
        "boundary_frame_semantics" =>
            "candidate_bound_periodic_axis_elliptic_v3")
    hashes = v85_solver_input_hashes_v1(compiled; poincare_budget = budget)
    return _v85_gate_record("poincare_nested_surfaces",
        status, gate.classification_code;
        solver_input_hash = hashes["poincare_solver_input_hash"],
        evidence = evidence,
        missing_requirements = passed ? String[] : gate.missing_requirements)
end

function compile_v85_desc_equilibrium_input_v1(design::CandidateJointDesignV1,
        compiled, poincare_gate)
    _v71_primary_region(compiled.realization)["geometry_class"] ==
        "toroidal_volume_v1" || throw(ArgumentError(
        "DESC finite-pressure capability requires a nested toroidal volume"))
    poincare_gate["status"] == "pass" || throw(ArgumentError(
        "DESC equilibrium input requires a passed Poincare hard gate"))
    boundary = compiled.binding["v85_boundary"]
    poincare = poincare_gate["evidence"]["poincare_evidence"]
    iota_axis = max(0.02, Float64(poincare[
        "minimum_absolute_rotational_transform"]))
    iota_edge = clamp(1.08 * iota_axis, iota_axis + 0.005, 0.8)
    elementary_charge = 1.602176634e-19
    density = Float64(compiled.binding["target_total_ion_density_m3"])
    temperature_sum_kev = Float64(compiled.binding[
        "target_ion_temperature_kev"]) + Float64(compiled.binding[
        "target_electron_temperature_kev"])
    pressure_axis = density * temperature_sum_kev * 1.0e3 * elementary_charge
    first_trace = poincare_gate["evidence"]["poincare_evidence"]["traces"][1]
    mean_field = 0.5 * (Float64(first_trace["minimum_field_t"]) +
        Float64(first_trace["maximum_field_t"]))
    if !isfinite(mean_field) || mean_field <= 0
        mean_field = Float64(evaluate_v85_biot_savart_gate_v1(compiled)[
            "evidence"]["field"]["minimum_field_t"])
    end
    flux = clamp(mean_field * pi * Float64(boundary["minor_radius_r_m"]) *
        Float64(boundary["minor_radius_z_m"]), 1.0e-4, 100.0)
    input = Dict{String,Any}(
        "runner_version" => "desc_explicit_fourier_fixed_boundary_runner_v1",
        "model_id" => "stellarator_symmetric_fourier_fixed_boundary_v1",
        "source_binding" => "DESC-0.17.3",
        "boundary" => Dict{String,Any}(
            "field_periods" => Int(boundary["field_periods"]),
            "stellarator_symmetric" => true,
            "R_modes" => Any[
                Dict("m" => 0, "n" => 0, "coefficient_m" => boundary[
                    "major_radius_m"]),
                Dict("m" => 1, "n" => 0, "coefficient_m" => boundary[
                    "minor_radius_r_m"]),
                Dict("m" => 0, "n" => 1, "coefficient_m" => boundary[
                    "helical_axis_r_m"])],
            "Z_modes" => Any[
                Dict("m" => -1, "n" => 0, "coefficient_m" =>
                    -Float64(boundary["minor_radius_z_m"])),
                Dict("m" => 0, "n" => -1, "coefficient_m" =>
                    -Float64(boundary["helical_axis_z_m"]))]),
        "profiles" => Dict{String,Any}(
            "pressure_power_series_pa" => [pressure_axis, 0.0,
                -2pressure_axis, 0.0, pressure_axis],
            "iota_power_series" => [iota_axis, 0.0, iota_edge - iota_axis],
            "toroidal_flux_wb" => flux),
        # L4 can report an O(1e-2) force residual for otherwise nested low-beta
        # states that converge below the declared 5e-3 gate at L6.  Finite
        # pressure is already a survivor-only stage, so use the verified L6
        # floor instead of granting or denying credit from the acquisition mesh.
        "resolution" => Dict{String,Any}("L" => 6, "M" => 6, "N" => 4,
            "L_grid" => 12, "M_grid" => 12, "N_grid" => 8),
        "solver" => Dict{String,Any}("optimizer" => "lsq-exact",
            "max_iterations" => 100, "ftol" => 1.0e-8, "xtol" => 1.0e-8,
            "gtol" => 1.0e-8, "pressure_step" => 0.25,
            "boundary_step" => 0.25, "shaping_first" => true),
        "audit" => Dict{String,Any}(
            "max_force_normalized_magnetic" => 5.0e-3,
            "max_fixed_constraint_error" => 1.0e-8, "min_sqrt_g" => 1.0e-8))
    return input
end

function _v85_run_json_solver(python_path, runner_path, input)
    raw = Dict{String,Any}(); elapsed = @elapsed raw = mktemp() do input_path, input_io
        JSON3.pretty(input_io, input); write(input_io, '\n'); close(input_io)
        return mktemp() do output_path, output_io
            close(output_io)
            run(`$(python_path) $(runner_path) --input $(input_path) --output $(output_path)`)
            return _stage3_plain_v1(JSON3.read(read(output_path, String),
                Dict{String,Any}))
        end
    end
    return raw, elapsed
end

function evaluate_v85_desc_equilibrium_gate_v1(design, compiled, poincare_gate;
        adapter = StellaratorDESCFourierV1(), execute_solver::Bool = true)
    poincare_gate["status"] == "pass" || return _v85_gate_record(
        "finite_pressure_equilibrium", "not_admitted",
        "poincare_hard_gate_not_passed";
        missing_requirements = ["poincare_nested_surfaces_pass"])
    _v71_primary_region(compiled.realization)["geometry_class"] ==
        "toroidal_volume_v1" || return _v85_gate_record(
        "finite_pressure_equilibrium", "unsupported",
        "finite_pressure_desc_capability_requires_nested_toroidal_volume";
        missing_requirements = ["open_boundary_finite_pressure_solver"])
    input = compile_v85_desc_equilibrium_input_v1(design, compiled, poincare_gate)
    input_hash = canonical_hash(input)
    execute_solver || return _v85_gate_record("finite_pressure_equilibrium",
        "unknown", "solver_execution_disabled"; solver_input_hash = input_hash,
        evidence = Dict("solver_input" => input),
        missing_requirements = ["executed_desc_equilibrium"])
    try
        raw, elapsed = _v85_run_json_solver(adapter.python_path,
            adapter.runner_path, input)
        if get(raw, "status", "error") != "pass"
            return _v85_gate_record("finite_pressure_equilibrium", "unknown",
                "desc_equilibrium_runner_error";
                solver_input_hash = input_hash,
                evidence = Dict("solver_input" => input, "raw_result" => raw,
                    "wall_time_s" => elapsed, "candidate_bound" => true,
                    "family_label_routing" => false),
                missing_requirements = ["successful_desc_equilibrium_execution"])
        end
        solver = get(raw, "solver", Dict{String,Any}())
        accepted = get(solver, "equilibrium_accepted", false) === true &&
            get(solver, "equation_residual_accepted", false) === true &&
            get(solver, "fixed_constraints_accepted", false) === true &&
            get(solver, "jacobian_accepted", false) === true
        evidence = Dict{String,Any}("solver_input" => input,
            "raw_result" => raw, "wall_time_s" => elapsed,
            "candidate_bound" => true, "family_label_routing" => false)
        return _v85_gate_record("finite_pressure_equilibrium",
            accepted ? "pass" : "fail",
            accepted ? "desc_finite_pressure_equilibrium_accepted" :
                "desc_finite_pressure_equilibrium_rejected";
            solver_input_hash = input_hash, evidence = evidence)
    catch error
        return _v85_gate_record("finite_pressure_equilibrium", "unknown",
            "desc_equilibrium_exception"; solver_input_hash = input_hash,
            evidence = Dict("solver_input" => input,
                "exception" => sprint(showerror, error)),
            missing_requirements = ["successful_desc_equilibrium_execution"])
    end
end

function compile_v85_desc_stability_input_v1(design, compiled,
        poincare_gate, equilibrium_gate)
    equilibrium_gate["status"] == "pass" || throw(ArgumentError(
        "stability input requires accepted finite-pressure equilibrium"))
    equilibrium_input = equilibrium_gate["evidence"]["solver_input"]
    medium_input = deepcopy(equilibrium_input)
    medium_input["resolution"] = Dict{String,Any}("L" => 6, "M" => 6,
        "N" => 4, "L_grid" => 12, "M_grid" => 12, "N_grid" => 8)
    medium_input["solver"]["max_iterations"] = max(100,
        Int(medium_input["solver"]["max_iterations"]))
    raw = equilibrium_gate["evidence"]["raw_result"]
    reference = Dict{String,Any}(
        "input_hash" => get(raw, "input_hash", canonical_hash(equilibrium_input)),
        "result_hash" => raw["result_hash"], "after" => raw["after"])
    # The stability runner uses a higher-resolution re-solve. A prior reference
    # is only comparable when its embedded equilibrium input is identical.
    reference = canonical_hash(medium_input) == canonical_hash(equilibrium_input) ?
        reference : nothing
    return Dict{String,Any}(
        "runner_version" => _DESC_STABILITY_RUNNER_VERSION,
        "source_binding" => "DESC-0.17.3",
        "claim_boundary" => _DESC_STABILITY_CLAIM_BOUNDARY,
        "physics_hash" => canonical_hash(Dict(
            "field_solver_input_hash" => v85_solver_input_hashes_v1(compiled)[
                "field_solver_input_hash"],
            "poincare_evidence_hash" => poincare_gate["evidence_hash"],
            "equilibrium_result_hash" => raw["result_hash"])),
        "equilibrium_solver_input" => medium_input,
        "equilibrium_reference" => reference,
        "stability" => _desc_stability_settings_medium())
end

function evaluate_v85_desc_stability_gate_v1(design, compiled,
        poincare_gate, equilibrium_gate;
        adapter = StellaratorDESCStabilityV1(), execute_solver::Bool = true)
    equilibrium_gate["status"] == "pass" || return _v85_gate_record(
        "sampled_ideal_mhd_stability", "not_admitted",
        "finite_pressure_equilibrium_hard_gate_not_passed";
        missing_requirements = ["finite_pressure_equilibrium_pass"])
    input = compile_v85_desc_stability_input_v1(design, compiled,
        poincare_gate, equilibrium_gate)
    input_hash = canonical_hash(input)
    execute_solver || return _v85_gate_record("sampled_ideal_mhd_stability",
        "unknown", "solver_execution_disabled"; solver_input_hash = input_hash,
        evidence = Dict("solver_input" => input),
        missing_requirements = ["executed_desc_stability"])
    try
        raw, elapsed = _v85_run_json_solver(adapter.python_path,
            adapter.runner_path, input)
        if get(raw, "status", "error") != "pass"
            return _v85_gate_record("sampled_ideal_mhd_stability", "unknown",
                "desc_stability_runner_error";
                solver_input_hash = input_hash,
                evidence = Dict("solver_input" => input, "raw_result" => raw,
                    "wall_time_s" => elapsed, "sampled_only" => true,
                    "all_mode_stability_established" => false),
                missing_requirements = ["successful_desc_stability_execution"])
        end
        favorable = get(get(raw, "equilibrium", Dict{String,Any}()),
            "accepted", false) === true &&
            get(get(raw, "local_ideal_mhd", Dict{String,Any}()),
                "sampled_favorable", false) === true
        evidence = Dict{String,Any}("solver_input" => input,
            "raw_result" => raw, "wall_time_s" => elapsed,
            "sampled_only" => true, "all_mode_stability_established" => false)
        return _v85_gate_record("sampled_ideal_mhd_stability",
            favorable ? "pass" : "fail",
            favorable ? "sampled_mercier_and_infinite_n_ballooning_favorable" :
                "sampled_ideal_mhd_stability_unfavorable";
            solver_input_hash = input_hash, evidence = evidence)
    catch error
        return _v85_gate_record("sampled_ideal_mhd_stability", "unknown",
            "desc_stability_exception"; solver_input_hash = input_hash,
            evidence = Dict("solver_input" => input,
                "exception" => sprint(showerror, error)),
            missing_requirements = ["successful_desc_stability_execution"])
    end
end

function _v85_polyline_length_and_curvature(points)
    vectors = [Float64.(point) for point in points]
    length(vectors) >= 3 || return (length_m = 0.0, curvature_m_inv = Inf)
    segment_lengths = [norm(vectors[index + 1] - vectors[index]) for index in
        1:length(vectors)-1]
    maximum_curvature = 0.0
    for index in 2:length(vectors)-1
        a = norm(vectors[index] - vectors[index - 1])
        b = norm(vectors[index + 1] - vectors[index])
        c = norm(vectors[index + 1] - vectors[index - 1])
        curvature = 2norm(cross(vectors[index] - vectors[index - 1],
            vectors[index + 1] - vectors[index - 1])) /
            max(a * b * c, 1.0e-12)
        maximum_curvature = max(maximum_curvature, curvature)
    end
    return (length_m = sum(segment_lengths),
        curvature_m_inv = maximum_curvature)
end

function compile_actual_device_complexity_manifest_v2(design, compiled,
        gate_chain)
    all(get(gate_chain, gate_id, Dict("status" => "missing"))["status"] == "pass"
        for gate_id in ("finite_filament_biot_savart",
            "poincare_nested_surfaces", "finite_pressure_equilibrium",
            "sampled_ideal_mhd_stability")) || throw(ArgumentError(
        "v85 complexity may only be compiled after every hard gate passes"))
    components = _v71_field_components(compiled.realization)
    loop_rows = Dict{String,Any}[]; total_wire_length = 0.0
    maximum_curvature = 0.0; supply_groups = Set{String}()
    conductor_mass = 0.0; total_magnetic_load_n = 0.0
    maximum_field = Float64(gate_chain["finite_filament_biot_savart"][
        "evidence"]["field"]["maximum_field_t"])
    for component in components
        conductor = component["conductor"]
        radius = Float64(conductor["radius_m"])
        density = Float64(conductor["density_kg_m3"])
        for loop in component["loops"]
            metrics = _v85_polyline_length_and_curvature(loop["centerline_m"])
            turns = Int(loop["turns"]); wire_length = metrics.length_m * turns
            mass = pi * radius^2 * wire_length * density
            load = abs(Float64(loop["current_a"]) * turns) *
                metrics.length_m * maximum_field
            total_wire_length += wire_length
            conductor_mass += mass; total_magnetic_load_n += load
            maximum_curvature = max(maximum_curvature, metrics.curvature_m_inv)
            push!(supply_groups, String(loop["supply_group"]))
            push!(loop_rows, Dict{String,Any}(
                "loop_id" => loop["loop_id"], "turns" => turns,
                "centerline_length_m" => metrics.length_m,
                "wire_length_m" => wire_length,
                "maximum_curvature_m_inv" => metrics.curvature_m_inv,
                "conductor_mass_kg" => mass,
                "screening_magnetic_load_n" => load,
                "supply_group" => loop["supply_group"]))
        end
    end
    support_density = 7850.0; allowable_support_stress = 2.5e8
    support_safety_factor = 2.0; support_load_path_m = 0.75
    required_support_volume = support_safety_factor * total_magnetic_load_n /
        allowable_support_stress * support_load_path_m
    support_mass = required_support_volume * support_density
    control = compiled.binding["v85_control_schedule"]
    active_control_coefficients = count(value -> abs(value) > 1.0e-8,
        vcat(design.actuator_timing_coefficients,
            design.controller_modal_coefficients))
    component_count = length(loop_rows) + 2 # actuator bank and controller
    power_supply_count = length(supply_groups) + 1 # heating/actuator bank
    hashes = v85_solver_input_hashes_v1(compiled)
    bom = Dict{String,Any}(
        "source_realization_hash" => compiled.realization.realization_hash,
        "field_solver_input_hash" => hashes["field_solver_input_hash"],
        "finite_filament_loops" => loop_rows,
        "conductor_model" => Dict("cross_section" => "circular",
            "radius_m" => first(components)["conductor"]["radius_m"],
            "density_kg_m3" => first(components)["conductor"]["density_kg_m3"]),
        "support_model" => Dict(
            "model_id" => "candidate_bound_magnetic_load_path_v1",
            "total_screening_magnetic_load_n" => total_magnetic_load_n,
            "maximum_sampled_field_t" => maximum_field,
            "material_density_kg_m3" => support_density,
            "allowable_stress_pa" => allowable_support_stress,
            "safety_factor" => support_safety_factor,
            "load_path_m" => support_load_path_m),
        "power_supply_groups" => sort!(collect(supply_groups)),
        "actuator_power_supply" => Dict("count" => 1,
            "capacity_w" => compiled.binding["actuator_capacity_w"]),
        "control_schedule_hash" => canonical_hash(control),
        "control_complexity_definition" =>
            "nonzero actuator timing plus controller modal coefficients")
    provisional = Dict{String,Any}(
        "schema_version" => "2.0.0", "design_hash" => design.design_hash,
        "field_solver_input_hash" => hashes["field_solver_input_hash"],
        "component_count" => component_count,
        "power_supply_count" => power_supply_count,
        "conductor_length_m" => total_wire_length,
        "maximum_curvature_m_inv" => maximum_curvature,
        "conductor_mass_kg" => conductor_mass,
        "support_mass_kg" => support_mass,
        "control_complexity" => active_control_coefficients, "bom" => bom)
    manifest_hash = canonical_hash(provisional)
    return ActualDeviceComplexityManifestV2("2.0.0", design.design_hash,
        hashes["field_solver_input_hash"], component_count, power_supply_count,
        total_wire_length, maximum_curvature, conductor_mass, support_mass,
        active_control_coefficients, bom, manifest_hash)
end

function actual_device_complexity_manifest_to_dict_v2(item::ActualDeviceComplexityManifestV2)
    return Dict{String,Any}(
        "schema_version" => item.schema_version, "design_hash" => item.design_hash,
        "field_solver_input_hash" => item.field_solver_input_hash,
        "component_count" => item.component_count,
        "power_supply_count" => item.power_supply_count,
        "conductor_length_m" => item.conductor_length_m,
        "maximum_curvature_m_inv" => item.maximum_curvature_m_inv,
        "conductor_mass_kg" => item.conductor_mass_kg,
        "support_mass_kg" => item.support_mass_kg,
        "control_complexity" => item.control_complexity, "bom" => item.bom,
        "manifest_hash" => item.manifest_hash)
end

function _v85_complexity_vector(manifest::ActualDeviceComplexityManifestV2)
    return (Float64(manifest.component_count), Float64(manifest.power_supply_count),
        manifest.conductor_length_m, manifest.maximum_curvature_m_inv,
        manifest.support_mass_kg, Float64(manifest.control_complexity))
end

function _v85_dominates(left::ActualDeviceComplexityManifestV2,
        right::ActualDeviceComplexityManifestV2)
    a = _v85_complexity_vector(left); b = _v85_complexity_vector(right)
    return all(a[index] <= b[index] for index in eachindex(a)) &&
        any(a[index] < b[index] for index in eachindex(a))
end

function build_realization_pareto_archive_v85(rows;
        representative_policy::Union{Nothing,String} = nothing)
    eligible = [row for row in rows if get(row, "all_hard_gates_pass", false) === true]
    sort!(eligible; by = row -> row["design"].design_hash)
    unique_rows = Dict{String,Any}[]; seen = Set{String}()
    for row in eligible
        manifest = row["complexity_manifest"]::ActualDeviceComplexityManifestV2
        key = canonical_hash(collect(_v85_complexity_vector(manifest)))
        key in seen && continue
        push!(seen, key); push!(unique_rows, row)
    end
    pareto = Dict{String,Any}[]
    for (index, row) in enumerate(unique_rows)
        manifest = row["complexity_manifest"]::ActualDeviceComplexityManifestV2
        any(other_index != index && _v85_dominates(
            unique_rows[other_index]["complexity_manifest"], manifest)
            for other_index in eachindex(unique_rows)) && continue
        push!(pareto, row)
    end
    sort!(pareto; by = row -> (_v85_complexity_vector(row["complexity_manifest"]),
        row["design"].design_hash))
    representative = if representative_policy === nothing || isempty(pareto)
        nothing
    elseif representative_policy == "lexicographic_complexity_v1"
        first(pareto)
    else
        throw(ArgumentError("unsupported v85 representative policy"))
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "eligible_count" => length(eligible),
        "unique_complexity_count" => length(unique_rows),
        "pareto_count" => length(pareto),
        "pareto_design_hashes" => [row["design"].design_hash for row in pareto],
        "representative_policy" => representative_policy,
        "representative_design_hash" => representative === nothing ? nothing :
            representative["design"].design_hash,
        "equality_duplicates_retained" => false,
        "minimality_scope" => "declared_v85_grammar_and_four_hard_gates_only")
    body["archive_hash"] = canonical_hash(body)
    return (artifact = body, pareto_rows = pareto, representative = representative)
end

function run_joint_physical_optimization_v85(topology, compilation,
        grammar::JointOptimizationGrammarV1, initial_designs;
        maximum_sweeps::Integer = 2, maximum_evaluations::Integer = 160,
        poincare_turns::Integer = 128, poincare_steps_per_turn::Integer = 180,
        execute_desc::Bool = true)
    rows = Dict{String,Any}[]
    field_gate_cache = Dict{String,Dict{String,Any}}()
    poincare_gate_cache = Dict{String,Dict{String,Any}}()
    equilibrium_gate_cache = Dict{String,Dict{String,Any}}()
    stability_gate_cache = Dict{String,Dict{String,Any}}()
    execution_counts = Dict{String,Int}("biot_savart" => 0, "poincare" => 0,
        "equilibrium" => 0, "stability" => 0)
    for initial in initial_designs
        optimization = optimize_joint_physical_design_v85(topology, compilation,
            grammar, initial; maximum_sweeps = maximum_sweeps,
            maximum_evaluations = maximum_evaluations)
        design = optimization["optimized_design"]
        compiled = optimization["final_evaluation"]["compiled"]
        budget = Dict{String,Any}("turns" => poincare_turns,
            "steps_per_turn" => poincare_steps_per_turn, "fourier_order" => 4,
            "bin_count" => 16)
        hashes = v85_solver_input_hashes_v1(compiled; poincare_budget = budget)
        field_hash = hashes["field_solver_input_hash"]
        biot = get(field_gate_cache, field_hash, nothing)
        if biot === nothing
            biot = evaluate_v85_biot_savart_gate_v1(compiled)
            field_gate_cache[field_hash] = biot; execution_counts["biot_savart"] += 1
        end
        poincare_hash = hashes["poincare_solver_input_hash"]
        poincare = get(poincare_gate_cache, poincare_hash, nothing)
        if poincare === nothing
            poincare = evaluate_v85_poincare_gate_v1(compiled, biot;
                target_toroidal_turns = poincare_turns,
                steps_per_turn = poincare_steps_per_turn)
            poincare_gate_cache[poincare_hash] = poincare
            biot["status"] == "pass" && (execution_counts["poincare"] += 1)
        end
        equilibrium = if poincare["status"] == "pass"
            equilibrium_input = compile_v85_desc_equilibrium_input_v1(design,
                compiled, poincare)
            equilibrium_hash = canonical_hash(equilibrium_input)
            get!(equilibrium_gate_cache, equilibrium_hash) do
                execution_counts["equilibrium"] += execute_desc ? 1 : 0
                evaluate_v85_desc_equilibrium_gate_v1(design, compiled, poincare;
                    execute_solver = execute_desc)
            end
        else
            evaluate_v85_desc_equilibrium_gate_v1(design, compiled, poincare;
                execute_solver = false)
        end
        stability = if equilibrium["status"] == "pass"
            stability_input = compile_v85_desc_stability_input_v1(design, compiled,
                poincare, equilibrium)
            stability_hash = canonical_hash(stability_input)
            get!(stability_gate_cache, stability_hash) do
                execution_counts["stability"] += execute_desc ? 1 : 0
                evaluate_v85_desc_stability_gate_v1(design, compiled, poincare,
                    equilibrium; execute_solver = execute_desc)
            end
        else
            evaluate_v85_desc_stability_gate_v1(design, compiled, poincare,
                equilibrium; execute_solver = false)
        end
        gates = Dict{String,Any}(
            "finite_filament_biot_savart" => biot,
            "poincare_nested_surfaces" => poincare,
            "finite_pressure_equilibrium" => equilibrium,
            "sampled_ideal_mhd_stability" => stability)
        all_pass = all(gates[id]["status"] == "pass" for id in
            grammar.hard_gate_ids)
        manifest = all_pass ? compile_actual_device_complexity_manifest_v2(
            design, compiled, gates) : nothing
        push!(rows, Dict{String,Any}(
            "initial_design_hash" => initial.design_hash, "design" => design,
            "optimization" => optimization, "solver_input_hashes" => hashes,
            "gate_chain" => gates, "all_hard_gates_pass" => all_pass,
            "complexity_manifest" => manifest))
    end
    archive = build_realization_pareto_archive_v85(rows;
        representative_policy = grammar.representative_policy)
    summary = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "structure_hash" => grammar.base_grammar.structure_hash,
        "grammar_hash" => grammar.grammar_hash,
        "candidate_count" => length(rows),
        "all_hard_gates_pass_count" => count(row -> row[
            "all_hard_gates_pass"] === true, rows),
        "unique_solver_input_counts" => Dict(
            "biot_savart" => length(field_gate_cache),
            "poincare" => length(poincare_gate_cache),
            "equilibrium" => length(equilibrium_gate_cache),
            "stability" => length(stability_gate_cache)),
        "actual_solver_execution_counts" => execution_counts,
        "pareto_archive" => archive.artifact,
        "claim_boundary" => JOINT_PHYSICAL_OPTIMIZATION_V85_CLAIM_BOUNDARY)
    summary["result_hash"] = canonical_hash(summary)
    return (summary = summary, rows = rows, pareto_rows = archive.pareto_rows,
        representative = archive.representative)
end

function joint_physical_optimization_result_to_dict_v85(result)
    rows = Dict{String,Any}[]
    for row in result.rows
        optimization = row["optimization"]
        gates = row["gate_chain"]
        push!(rows, Dict{String,Any}(
            "initial_design_hash" => row["initial_design_hash"],
            "design" => candidate_joint_design_to_dict_v1(row["design"]),
            "optimization" => Dict{String,Any}(
                "optimizer" => optimization["optimizer"],
                "evaluations" => optimization["evaluations"],
                "evaluated_coordinate_names" => optimization[
                    "evaluated_coordinate_names"],
                "initial_rank" => optimization["initial_rank"],
                "final_rank" => optimization["final_rank"],
                "acquisition_only" => true, "trace" => optimization["trace"]),
            "solver_input_hashes" => row["solver_input_hashes"],
            "gate_chain" => gates,
            "all_hard_gates_pass" => row["all_hard_gates_pass"],
            "complexity_manifest" => row["complexity_manifest"] === nothing ?
                nothing : actual_device_complexity_manifest_to_dict_v2(
                    row["complexity_manifest"])))
    end
    body = Dict{String,Any}("summary" => result.summary, "rows" => rows,
        "pareto_design_hashes" => [row["design"].design_hash for row in
            result.pareto_rows],
        "representative_design_hash" => result.representative === nothing ?
            nothing : result.representative["design"].design_hash)
    body["artifact_hash"] = canonical_hash(body)
    return body
end
