const _V54_CLAIM_BOUNDARY =
    "V54 makes solver-input contracts search genes. Contracts are generated before " *
    "screening from module declarations and deterministic sample coordinates, participate " *
    "in the candidate physics hash, and are consumed without creating a validation parent. " *
    "Contract completeness or a source-field calculation is not equilibrium, stability, " *
    "burn, net-energy, engineering, C2/C3, or promotion evidence."

_v54_q(value::Real, unit::String, basis::String = "v54 deterministic search gene") =
    Dict{String,Any}("value" => Float64(value), "unit" => unit, "basis" => basis)

function _v54_contract_hash(value)
    roundtrip = _plain_json(JSON3.read(canonical_json(value), Dict{String,Any}))
    return canonical_hash(roundtrip)
end

function _v54_quantity_values(genome::Genome, unit::String)
    collected = Float64[]
    for target in Base.values(genome.mission.targets)
        target.unit == unit && isfinite(target.value) && push!(collected, abs(target.value))
    end
    for collection in (genome.plasma_regions, genome.field_sources,
            genome.actuators, genome.compression_systems)
        for item in collection, parameter in Base.values(item.parameters)
            parameter.unit == unit && isfinite(parameter.value) &&
                push!(collected, abs(parameter.value))
        end
    end
    return filter(>(0.0), collected)
end

function _v54_scale(genome::Genome, unit::String, fallback::Real;
        lower::Real = 0.0, upper::Real = Inf)
    values = _v54_quantity_values(genome, unit)
    value = isempty(values) ? Float64(fallback) : values[cld(length(values), 2)]
    return clamp(value, Float64(lower), Float64(upper))
end

function _v54_module_match(module_ids, needles)
    tokens = lowercase.(String.(module_ids))
    return any(token -> any(needle -> occursin(needle, token), needles), tokens)
end

function _v54_boundary_contract(genome::Genome, module_ids, u)
    major = _v54_scale(genome, "m", 2.5; lower = 0.15, upper = 12.0)
    minor = clamp(major * (0.12 + 0.22 * u[13]), 0.03, 0.42 * major)
    elongation = 1.0 + 1.1 * u[14]
    triangularity = -0.15 + 0.65 * u[15]
    helical_r = minor * (0.02 + 0.16 * u[16])
    helical_z = minor * (0.02 + 0.16 * u[17])
    periods = max(1, genome.symmetry.field_periods)
    is_three_d = periods > 1 || _v54_module_match(module_ids,
        ("stellarator", "hybrid", "minimum_b"))
    r_modes = Any[
        Dict("m" => 0, "n" => 0, "coefficient_m" => major),
        Dict("m" => 1, "n" => 0, "coefficient_m" => minor),
        Dict("m" => 2, "n" => 0, "coefficient_m" => triangularity * minor * 0.25),
    ]
    z_modes = Any[
        Dict("m" => -1, "n" => 0, "coefficient_m" => -elongation * minor),
        Dict("m" => -2, "n" => 0, "coefficient_m" => triangularity * minor * 0.20),
    ]
    if is_three_d
        push!(r_modes, Dict("m" => 0, "n" => 1, "coefficient_m" => helical_r))
        push!(z_modes, Dict("m" => 0, "n" => -1, "coefficient_m" => -helical_z))
    end
    return Dict{String,Any}(
        "representation" => "cylindrical_fourier_boundary_v1",
        "field_periods" => periods,
        "stellarator_symmetric" => is_three_d,
        "R_modes" => r_modes, "Z_modes" => z_modes,
        "major_radius_m" => major, "minor_radius_m" => minor,
        "elongation" => elongation, "triangularity" => triangularity)
end

function _v54_profile_contract(genome::Genome, boundary, u)
    field = _v54_scale(genome, "T", 3.0; lower = 0.05, upper = 30.0)
    beta = 0.002 + 0.075 * u[18]
    pressure = beta * field^2 / (2.0 * 4.0e-7 * pi)
    major = boundary["major_radius_m"]
    current = (0.15 + 1.85 * u[19]) * 1.0e6 * max(0.2, major / 3.0)
    iota_axis = 0.18 + 0.45 * u[20]
    iota_edge = iota_axis + 0.08 + 0.45 * u[21]
    return Dict{String,Any}(
        "pressure" => Dict("coordinate" => "normalized_toroidal_flux",
            "basis" => "power_series", "coefficients_pa" =>
                [pressure, 0.0, -2.0 * pressure, 0.0, pressure]),
        "current" => Dict("coordinate" => "normalized_toroidal_flux",
            "basis" => "enclosed_current_power_series",
            "total_current_a" => current,
            "coefficients_a" => [0.0, current, 0.0, -0.15 * current]),
        "iota" => Dict("basis" => "quadratic",
            "axis" => iota_axis, "edge" => iota_edge),
        "design_field_t" => field, "design_beta" => beta)
end

function _v54_generic_filaments(boundary, profiles, u)
    major = boundary["major_radius_m"]
    minor = boundary["minor_radius_m"]
    target = profiles["design_field_t"]
    radius = major + 0.35 * minor
    half_z = (0.70 + 0.35 * u[22]) * minor
    current = target * max(radius, 0.05) / (4.0e-7 * pi) * 0.45
    return Any[
        Dict("id" => "upper_circular_filament", "geometry" => "circular_filament",
            "radius_m" => radius, "center_m" => [0.0, 0.0, half_z],
            "normal" => [0.0, 0.0, 1.0], "current_a" => current),
        Dict("id" => "lower_circular_filament", "geometry" => "circular_filament",
            "radius_m" => radius, "center_m" => [0.0, 0.0, -half_z],
            "normal" => [0.0, 0.0, 1.0], "current_a" => current),
    ]
end

function _v54_mirror_contract(genome::Genome, boundary, profiles, u)
    radius = max(0.08, 1.35 * boundary["minor_radius_m"])
    ratio = 1.6 + 4.0 * u[22]
    separation = _mirror_pair_separation_search_v1(radius, ratio)
    half_z = radius * separation["selected_half_separation_over_radius"]
    field = profiles["design_field_t"]
    coefficient = _mirror_pair_axis_coeff_v1(radius, half_z, 0.0)
    current = field / coefficient
    plasma_radius = min(0.72 * radius, boundary["minor_radius_m"])
    return Dict{String,Any}(
        "kind" => "axisymmetric_mirror_filament_pair_v1",
        "loop_radius_m" => radius,
        "pair_half_separation_m" => half_z,
        "pair_center_z_m" => 0.0,
        "current_per_loop_a" => current,
        "target_central_field_t" => field,
        "target_mirror_ratio" => ratio,
        "plasma_center_m" => [0.0, 0.0, 0.0],
        "plasma_radius_m" => plasma_radius,
        "central_cell_length_m" => 2.0 * half_z,
        "filaments" => Any[
            Dict("id" => "mirror_left", "geometry" => "circular_filament",
                "radius_m" => radius, "center_m" => [0.0, 0.0, -half_z],
                "normal" => [0.0, 0.0, 1.0], "current_a" => current),
            Dict("id" => "mirror_right", "geometry" => "circular_filament",
                "radius_m" => radius, "center_m" => [0.0, 0.0, half_z],
                "normal" => [0.0, 0.0, 1.0], "current_a" => current),
        ])
end

function _v54_dipole_contract(boundary, profiles, u)
    plasma_major = boundary["major_radius_m"]
    plasma_minor = min(boundary["minor_radius_m"], 0.38 * plasma_major)
    loop_radius = max(0.02, (0.18 + 0.32 * u[22]) * plasma_minor)
    loop_z = 0.0
    target = profiles["design_field_t"]
    unit_field = _dipole_ring_field_v1(loop_radius, loop_z, 1.0, 512)
    per_amp = _dipole_ring_magnitude_v1(unit_field, (plasma_major, 0.0, 0.0))
    current = target / max(per_amp, 1.0e-30)
    peak = max(1.2 * abs(4.0e-7 * pi * current / (2.0 * loop_radius)),
        1.5 * target)
    return Dict{String,Any}(
        "kind" => "finite_build_floating_superconducting_ring_v1",
        "loop_radius_m" => loop_radius, "loop_center_z_m" => loop_z,
        "equivalent_ampere_turns_a" => current,
        "peak_field_screen_t" => peak,
        "plasma_center_m" => [plasma_major, 0.0, 0.0],
        "plasma_major_radius_m" => plasma_major,
        "plasma_minor_radius_m" => plasma_minor,
        "coil_pack_thickness_m" => 0.04 * plasma_minor,
        "shield_thickness_m" => 0.06 * plasma_minor,
        "maintenance_gap_m" => 0.05 * plasma_minor)
end

function _v54_pulsed_contract(genome::Genome, module_ids, boundary, u)
    is_icf = _v54_module_match(module_ids, ("icf",))
    energy = _v54_scale(genome, "J", is_icf ? 2.0e6 : 5.0e7;
        lower = 1.0e3, upper = 5.0e10)
    duration = is_icf ? (0.5e-9 + 19.5e-9 * u[13]) :
        (0.2e-6 + 19.8e-6 * u[13])
    peak_power = 2.0 * energy / duration
    times = [0.0, 0.25, 0.50, 0.75, 1.0] .* duration
    powers = [0.0, 0.5, 1.0, 0.5, 0.0] .* peak_power
    radius = is_icf ? clamp(0.0004 + 0.004 * u[14], 1.0e-4, 0.01) :
        clamp(boundary["minor_radius_m"], 0.02, 2.0)
    material = is_icf ? "DT_50_50_with_CH_or_HDC_ablator" :
        "DT_target_with_conducting_liner"
    return Dict{String,Any}(
        "geometry" => Dict("model" => is_icf ? "spherical_1d_layered" :
            "axisymmetric_lagrangian_liner", "outer_radius_m" => radius,
            "shell_half_width_m" => 0.12 * radius),
        "materials" => Any[
            Dict("region" => "fuel", "material" => "DT_50_50",
                "mass_fraction" => 1.0,
                "eos_model_id" => "screen_ideal_plasma_gamma_5_3_v1",
                "opacity_model_id" => "screen_gray_kramers_v1"),
            Dict("region" => "driver_shell", "material" => material,
                "mass_fraction" => 1.0,
                "eos_model_id" => "screen_mie_gruneisen_v1",
                "opacity_model_id" => "screen_gray_diffusion_v1"),
        ],
        "initial_profiles" => Dict(
            "radial_coordinate" => "normalized_radius",
            "density_shape" => [1.0, 1.0, 0.4],
            "temperature_shape" => [1.0, 0.7, 0.2]),
        "drive_history" => Dict("time_s" => times, "power_w" => powers,
            "requested_energy_j" => energy, "wavelength_m" =>
                (is_icf ? 351.0e-9 : 1.0e-6), "spatial_profile" => "super_gaussian_m4"),
        "mesh_convergence" => Dict("coarse_cells" => 256,
            "fine_cells" => 512, "coarse_cfl" => 0.5, "fine_cfl" => 0.35,
            "required_energy_residual_fraction" => 0.01,
            "required_qoi_relative_change" => 0.05),
        "outputs" => ["total_energy_history", "fuel_internal_energy",
            "radiation_energy", "kinetic_energy", "burn_fraction", "alpha_deposition"],
        "mix_model" => "bounded_diffusion_coefficient_scan_v1")
end

function _v54_ledgers(genome::Genome, module_ids, boundary, u)
    volume = 2.0 * pi^2 * boundary["major_radius_m"] *
        boundary["minor_radius_m"]^2
    gross = (0.05 + 1.95 * u[1]) * 1.0e9
    recirculating = gross * (0.15 + 0.55 * u[2])
    auxiliaries = gross * (0.03 + 0.22 * u[3])
    net = gross - recirculating - auxiliaries
    particle_source = (0.2 + 4.8 * u[4]) * 1.0e21 * max(volume, 1.0e-4)
    exhaust = particle_source * (0.70 + 0.25 * u[5])
    burn = particle_source - exhaust
    fuel_inventory = (0.01 + 2.0 * u[6]) * max(volume, 1.0e-4)
    fuel_in = (0.2 + 4.8 * u[7]) * 1.0e-5
    fuel_burn = fuel_in * (0.01 + 0.18 * u[8])
    fuel_exhaust = fuel_in - fuel_burn
    open_field = _v54_module_match(module_ids,
        ("mirror", "zpinch", "open_field", "linear_end", "frc"))
    end_power = open_field ? gross * (0.05 + 0.45 * u[9]) : 0.0
    return Dict{String,Any}(
        "power" => Dict("terms_w" => Dict("gross_electric" => gross,
            "recirculating" => -recirculating, "auxiliaries" => -auxiliaries,
            "net_electric" => -net), "closure_residual_w" => 0.0,
            "sign_convention" => "sources_positive_sinks_negative"),
        "particle" => Dict("terms_per_s" => Dict("source" => particle_source,
            "exhaust" => -exhaust, "burn" => -burn),
            "closure_residual_per_s" => 0.0),
        "fuel_inventory" => Dict("inventory_kg" => fuel_inventory,
            "terms_kg_per_s" => Dict("injection" => fuel_in,
                "burn" => -fuel_burn, "exhaust" => -fuel_exhaust),
            "closure_residual_kg_per_s" => 0.0),
        "end_loss" => Dict("applicable" => open_field,
            "parallel_particle_loss_per_s" => open_field ? exhaust : 0.0,
            "parallel_energy_loss_w" => end_power,
            "left_right_split" => [0.5, 0.5],
            "target_area_m2" => max(0.01, 2.0 * pi * boundary["minor_radius_m"]^2)))
end

function solver_ready_contracts_v54(genome::Genome, module_ids,
        values_u::AbstractVector{<:Real})
    length(values_u) == length(_V20_HALTON_PRIMES) ||
        throw(ArgumentError("v54 requires all 24 deterministic sample coordinates"))
    u = Float64.(values_u)
    boundary = _v54_boundary_contract(genome, module_ids, u)
    profiles = _v54_profile_contract(genome, boundary, u)
    is_icf = _v54_module_match(module_ids, ("icf",))
    is_pulsed = _v54_module_match(module_ids,
        ("icf", "mtf", "liner", "pulse", "implosion"))
    magnetic = is_icf ? Dict{String,Any}("applicable" => false) :
        Dict{String,Any}("applicable" => true,
            "boundary" => boundary, "profiles" => profiles,
            "filaments" => _v54_generic_filaments(boundary, profiles, u),
            "source_model" => "explicit_filament_search_gene_v1")
    special = _v54_module_match(module_ids, ("mirror",)) ?
        _v54_mirror_contract(genome, boundary, profiles, u) :
        _v54_module_match(module_ids, ("dipole",)) ?
            _v54_dipole_contract(boundary, profiles, u) :
            Dict{String,Any}("kind" => "not_applicable")
    pulsed = is_pulsed ? _v54_pulsed_contract(genome, module_ids, boundary, u) :
        Dict{String,Any}("applicable" => false)
    payload = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "generation_stage" => "before_common_screen",
        "routing_basis" => Dict("module_ids" => String.(module_ids),
            "family_label_used" => false),
        "magnetic_constraint" => magnetic,
        "mirror_or_dipole" => special,
        "pulsed_device" => pulsed,
        "ledgers" => _v54_ledgers(genome, module_ids, boundary, u),
        "parent_synthesized" => false,
        "promotion_authorized" => false)
    payload["contract_hash"] = _v54_contract_hash(payload)
    return payload
end

function _v54_set_quantity!(parameters, id::String, value::Real, unit::String)
    parameters[id] = _v54_q(value, unit)
    return parameters
end

function _v54_bind_native_geometry!(raw, contracts, module_ids)
    special = contracts["mirror_or_dipole"]
    if _v54_module_match(module_ids, ("mirror",))
        source = first(raw["field_sources"])
        source["geometry_model"] = "axisymmetric_circular_filament_pair_v1"
        parameters = source["parameters"]
        for (id, key, unit) in (("loop_radius", "loop_radius_m", "m"),
                ("pair_half_separation", "pair_half_separation_m", "m"),
                ("pair_center_z", "pair_center_z_m", "m"),
                ("current_per_loop", "current_per_loop_a", "A"),
                ("target_central_field", "target_central_field_t", "T"),
                ("target_mirror_ratio", "target_mirror_ratio", "1"))
            _v54_set_quantity!(parameters, id, special[key], unit)
        end
        core = first(raw["plasma_regions"])
        core["kind"] = "mirror_central_cell"
        core["geometry_model"] = "mirror_0d_solver_ready_v54"
        _v54_set_quantity!(core["parameters"], "plasma_radius",
            special["plasma_radius_m"], "m")
        _v54_set_quantity!(core["parameters"], "cell_length",
            special["central_cell_length_m"], "m")
    elseif _v54_module_match(module_ids, ("dipole",))
        source = first(raw["field_sources"])
        source["geometry_model"] = "finite_build_floating_superconducting_ring"
        _v54_set_quantity!(source["parameters"], "coil_radius",
            special["loop_radius_m"], "m")
        _v54_set_quantity!(source["parameters"], "generated_vertical_position",
            special["loop_center_z_m"], "m")
        _v54_set_quantity!(source["parameters"], "peak_field",
            special["peak_field_screen_t"], "T")
        core = first(raw["plasma_regions"])
        core["kind"] = "closed_toroidal_core"
        _v54_set_quantity!(core["parameters"], "major_radius",
            special["plasma_major_radius_m"], "m")
        _v54_set_quantity!(core["parameters"], "minor_radius",
            special["plasma_minor_radius_m"], "m")
        _v54_set_quantity!(core["parameters"], "generated_vertical_position", 0.0, "m")
        targets = raw["mission"]["targets"]
        radius_fraction = special["loop_radius_m"] / special["plasma_minor_radius_m"]
        field = contracts["magnetic_constraint"]["profiles"]["design_field_t"]
        _v54_set_quantity!(targets, "on_axis_field", field, "T")
        _v54_set_quantity!(targets, "screen_internal_coil_radius_fraction",
            radius_fraction, "1")
        _v54_set_quantity!(targets, "screen_internal_coil_field_ratio",
            special["peak_field_screen_t"] / field, "1")
        _v54_set_quantity!(targets, "screen_coil_pack_thickness",
            special["coil_pack_thickness_m"], "m")
        _v54_set_quantity!(targets, "screen_internal_shield_thickness",
            special["shield_thickness_m"], "m")
        _v54_set_quantity!(targets, "screen_internal_maintenance_gap",
            special["maintenance_gap_m"], "m")
    elseif _v54_module_match(module_ids, ("zpinch",))
        magnetic = contracts["magnetic_constraint"]
        boundary = magnetic["boundary"]
        profiles = magnetic["profiles"]
        current = profiles["current"]["total_current_a"]
        radius = boundary["minor_radius_m"]
        raw["field_sources"] = Any[Dict{String,Any}(
            "id" => "v54_explicit_axial_current",
            "kind" => "plasma_current",
            "geometry_model" => "finite_radius_axial_current_density",
            "parameters" => Dict(
                "total_current" => _v54_q(current, "A"),
                "generated_half_width_r" => _v54_q(radius, "m"),
                "generated_current_channel_radius" => _v54_q(radius, "m")),
            "material" => "candidate_plasma_current")]
        core = first(raw["plasma_regions"])
        _v54_set_quantity!(core["parameters"], "edge_azimuthal_field",
            4.0e-7 * pi * current / (2.0 * pi * radius), "T")
        _v54_set_quantity!(core["parameters"], "generated_half_width_r", radius, "m")
    end
    return raw
end

function generate_solver_ready_genome_v54(genome::Genome, module_ids,
        values_u::AbstractVector{<:Real}, sample_ordinal::Integer)
    contracts = solver_ready_contracts_v54(genome, module_ids, values_u)
    raw = deepcopy(genome.normalized)
    raw["solver_ready_contracts"] = contracts
    _v54_bind_native_geometry!(raw, contracts, module_ids)
    provenance = raw["provenance"]
    _v18_push_unique!(provenance["notes"], [
        "solver_ready_contract_search_v54",
        "solver contracts were generated before screening",
        "no validation parent or family-label routing was used"])
    raw["design_id"] = "pending_solver_ready_v54"
    provisional = parse_genome(raw)
    raw["design_id"] = "v54_$(canonical_hash(module_ids)[1:12])_s$(lpad(Int(sample_ordinal), 6, '0'))_" *
        provisional.physics_hash[1:12]
    result = parse_genome(raw)
    result.physics_hash != genome.physics_hash || error(
        "v54 solver contracts did not enter the physics hash")
    return result
end

function solver_contract_audit_v54(genome::Genome, module_ids)
    contracts = get(genome.normalized, "solver_ready_contracts", nothing)
    errors = String[]
    contracts isa AbstractDict || push!(errors, "solver_ready_contracts missing")
    if isempty(errors)
        get(contracts, "generation_stage", "") == "before_common_screen" ||
            push!(errors, "contract generation stage is not before_common_screen")
        get(contracts, "parent_synthesized", true) === false ||
            push!(errors, "contract record synthesized a parent")
        ledgers = get(contracts, "ledgers", Dict{String,Any}())
        for id in ("power", "particle", "fuel_inventory", "end_loss")
            haskey(ledgers, id) || push!(errors, "missing $id ledger")
        end
        if !_v54_module_match(module_ids, ("icf",))
            magnetic = get(contracts, "magnetic_constraint", Dict{String,Any}())
            get(magnetic, "applicable", false) === true ||
                push!(errors, "magnetic contract missing")
            for id in ("boundary", "profiles", "filaments")
                haskey(magnetic, id) || push!(errors, "magnetic contract missing $id")
            end
        end
        if _v54_module_match(module_ids, ("mirror", "dipole"))
            special = get(contracts, "mirror_or_dipole", Dict{String,Any}())
            get(special, "kind", "not_applicable") != "not_applicable" ||
                push!(errors, "mirror/dipole explicit contract missing")
        end
        if _v54_module_match(module_ids, ("icf", "mtf", "liner", "pulse", "implosion"))
            pulsed = get(contracts, "pulsed_device", Dict{String,Any}())
            for id in ("geometry", "materials", "initial_profiles", "drive_history",
                    "mesh_convergence", "outputs")
                haskey(pulsed, id) || push!(errors, "pulsed contract missing $id")
            end
        end
        expected = get(contracts, "contract_hash", "")
        body = Dict{String,Any}(String(k) => deepcopy(v) for (k, v) in contracts
            if String(k) != "contract_hash")
        expected == _v54_contract_hash(body) || push!(errors, "contract hash mismatch")
    end
    return Dict{String,Any}(
        "status" => isempty(errors) ? "ready" : "invalid",
        "errors" => sort!(unique(errors)),
        "contract_hash" => contracts isa AbstractDict ?
            get(contracts, "contract_hash", nothing) : nothing,
        "parent_synthesized" => contracts isa AbstractDict ?
            get(contracts, "parent_synthesized", nothing) : nothing,
        "promotion_authorized" => false)
end

function _v54_candidate_from_values(context::RecoverableCrossTopologyContextV20,
        candidate_index::Int, values_u::AbstractVector{<:Real})
    topology_count = length(context.assemblies)
    assembly_index = mod1(candidate_index, topology_count)
    sample_ordinal = cld(candidate_index, topology_count)
    assembly = context.assemblies[assembly_index]
    values = Float64.(values_u)
    proxy, evaluator_id, projection_id, limitations = _v20_projection(
        context.compiler_context, assembly, values)
    annotated = _v18_annotate_proxy(proxy, assembly, context.modules)
    solver_ready = generate_solver_ready_genome_v54(annotated,
        assembly.module_ids, values, sample_ordinal)
    report = validate_genome(solver_ready)
    report.valid || throw(ArgumentError("sampled v54 genome invalid: " *
        join(report.errors, "; ")))
    family_report = assembly.family == "inertial_confinement_fusion" ?
        validate_family(laser_icf_family_registry_v15(), solver_ready) :
        validate_family(default_family_registry(), solver_ready)
    family_report.valid || throw(ArgumentError("sampled v54 family invalid: " *
        join(family_report.errors, "; ")))
    mission_contract_for(default_mission_contract_registry(), solver_ready).id ==
        assembly.mission_contract_id || throw(ArgumentError(
            "sampled v54 mission contract drifted"))
    declared = _v20_declared_requirements(context, assembly)
    warnings = sort!(unique(vcat(report.warnings, family_report.warnings)))
    compiled = CompiledAttributeGenomeV18(assembly.assembly_id,
        assembly.graph_hash, assembly.family, assembly.mission_contract_id,
        copy(assembly.module_ids), solver_ready, evaluator_id, projection_id,
        sort!(unique(vcat(limitations,
            ["solver-ready input contracts generated before common screening"]))),
        declared, warnings)
    prescreen = _v18_prescreen(compiled, context.evaluators,
        context.evaluator_registry)
    return CrossTopologyCandidateV20(candidate_index, assembly_index,
        sample_ordinal, prescreen)
end

function evaluate_solver_ready_candidate_v54(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        halton_skip::Integer = 4096)
    index = Int(candidate_index)
    index > 0 || throw(ArgumentError("v54 candidate index must be positive"))
    sample_ordinal = cld(index, length(context.assemblies))
    values = _v20_unit_vector(sample_ordinal, length(_V20_HALTON_PRIMES);
        skip = Int(halton_skip))
    return _v54_candidate_from_values(context, index, values)
end

function solver_ready_candidate_to_dict_v54(candidate::CrossTopologyCandidateV20)
    record = cross_topology_candidate_to_dict_v20(candidate)
    compiled = candidate.prescreen.compiled
    audit = solver_contract_audit_v54(compiled.genome, compiled.module_ids)
    record["solver_contract_status"] = audit["status"]
    record["solver_contract_errors"] = audit["errors"]
    record["solver_contract_hash"] = audit["contract_hash"]
    record["solver_ready_contracts"] = deepcopy(
        compiled.genome.normalized["solver_ready_contracts"])
    record["solver_contract_generated_before_screen"] = true
    record["parent_synthesized_for_contract"] = false
    record["claim_level"] = "C0_plus_solver_ready_search_inputs"
    return record
end

"Screen and cluster candidates only after their generated solver contracts are present."
function build_solver_ready_search_archive_v54(values)
    raw_records = [_v52_record(value) for value in values]
    base = build_unified_search_archive_v52(raw_records)
    raw_by_index = Dict(Int(record["candidate_index"]) => record for record in raw_records)
    for screened in base["screened_records"]
        raw = raw_by_index[Int(screened["candidate_index"])]
        status = String(get(raw, "solver_contract_status", "unknown")) == "ready" ?
            "pass" : "fail"
        push!(screened["screens"], _v52_screen("solver_input_contract_readiness",
            status, "universal_hard_gate",
            "solver inputs must be generated as candidate genes before screening"))
        status == "pass" || push!(screened["failed_common_screen_ids"],
            "solver_input_contract_readiness")
        screened["decision"] = isempty(screened["failed_common_screen_ids"]) ?
            "common_screen_pass" : "hard_reject_candidate_instance"
        screened["solver_contract_hash"] = get(raw, "solver_contract_hash", nothing)
        screened["solver_contract_generated_before_screen"] =
            get(raw, "solver_contract_generated_before_screen", false)
    end
    by_index = Dict(Int(record["candidate_index"]) => record
        for record in base["screened_records"])
    for representative in base["representative_records"]
        updated = by_index[Int(representative["candidate_index"])]
        representative["screens"] = updated["screens"]
        representative["failed_common_screen_ids"] =
            updated["failed_common_screen_ids"]
        representative["decision"] = updated["decision"]
        representative["solver_contract_hash"] = updated["solver_contract_hash"]
        representative["solver_contract_generated_before_screen"] = true
        representative["candidate_specific_validation_plan"] =
            candidate_specific_validation_plan_v52(representative)
    end
    ready_count = count(record -> String(get(record,
        "solver_contract_status", "unknown")) == "ready", raw_records)
    base["summary"]["solver_contract_ready_count"] = ready_count
    base["summary"]["solver_contract_invalid_count"] = length(raw_records) - ready_count
    base["summary"]["common_screen_pass_count"] = count(record ->
        record["decision"] == "common_screen_pass", base["screened_records"])
    base["summary"]["hard_reject_candidate_instance_count"] = count(record ->
        record["decision"] == "hard_reject_candidate_instance",
        base["screened_records"])
    base["architecture_policy"]["solver_contract_policy"] =
        "generated_before_screen_and_never_repaired_by_validation_parent"
    return base
end

function repaired_common_judgment_v54(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer)
    candidate = evaluate_solver_ready_candidate_v54(context, candidate_index)
    compiled = candidate.prescreen.compiled
    raw_result = _plain_json(_v18_route_result(
        context.evaluators[compiled.evaluator_id], compiled.genome))
    semantic_gates, aliases = _v31_semantic_gates(raw_result["gates"])
    robustness = get(raw_result, "robustness", Dict{String,Any}())
    audit = solver_contract_audit_v54(compiled.genome, compiled.module_ids)
    margins = _v53_numeric_margins(raw_result)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_index" => Int(candidate_index),
        "candidate_id" => compiled.genome.design_id,
        "physics_hash" => compiled.genome.physics_hash,
        "module_ids" => copy(compiled.module_ids),
        "semantic_gates" => semantic_gates, "semantic_gate_aliases" => aliases,
        "common_physics_status" => all(semantic_gates[id] for id in
            ("topology", "physics", "outer_envelope")) ? "pass" : "fail",
        "robustness_evaluation_state" => _v31_robustness_state(robustness),
        "solver_contract_audit" => audit,
        "limiting_margins" => first(margins, min(8, length(margins))),
        "raw_result_hash" => String(raw_result["result_hash"]),
        "raw_result_reconstruction_match" =>
            String(raw_result["result_hash"]) == candidate.prescreen.proxy_result_hash,
        "parent_synthesized" => false, "promotion_authorized" => false,
        "claim_boundary" => _V54_CLAIM_BOUNDARY)
end

function _v54_drive_integral(contract)
    drive = contract["drive_history"]
    times = Float64.(drive["time_s"])
    powers = Float64.(drive["power_w"])
    length(times) == length(powers) >= 2 || return NaN
    return sum(0.5 * (powers[i] + powers[i + 1]) *
        (times[i + 1] - times[i]) for i in 1:(length(times) - 1))
end

function higher_fidelity_solver_contract_validation_v54(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer)
    candidate = evaluate_solver_ready_candidate_v54(context, candidate_index)
    compiled = candidate.prescreen.compiled
    genome = compiled.genome
    contracts = genome.normalized["solver_ready_contracts"]
    attempts = Dict{String,Any}[]
    audit = solver_contract_audit_v54(genome, compiled.module_ids)
    push!(attempts, _v53_attempt("solver_contract_audit_v54", audit["status"];
        executed = true, applicable = true,
        reason = isempty(audit["errors"]) ? nothing : join(audit["errors"], "; "),
        result_hash = audit["contract_hash"], details = audit))

    native = execute_native_candidate_c1_backend_v1(genome)
    push!(attempts, _v53_native_summary(native))

    if _v54_module_match(compiled.module_ids, ("mirror",))
        result = execute_axisymmetric_mirror_filament_c1_v1(genome)
        push!(attempts, _v53_attempt("axisymmetric_mirror_filament_c1_v1",
            String(result["status"]); executed = get(result, "backend_executed", false),
            applicable = true, reason = get(result, "reason", nothing),
            result_hash = get(result, "physical_result_hash", nothing),
            c1_authorized = get(result, "candidate_c1_evidence_authorized", false)))
    elseif _v54_module_match(compiled.module_ids, ("dipole",))
        result = evaluate_levitated_dipole_ring_screen_v1(genome)
        push!(attempts, _v53_attempt("levitated_dipole_ring_screen_v1",
            String(result["status"]); executed = get(result, "backend_executed", false),
            applicable = true, reason = get(result, "reason", nothing),
            result_hash = get(result, "physical_result_hash", nothing),
            c1_authorized = get(result, "candidate_c1_evidence_authorized", false)))
    end

    magnetic = contracts["magnetic_constraint"]
    if get(magnetic, "applicable", false) === true
        compiled_fourier = Dict{String,Any}(
            "boundary" => magnetic["boundary"], "profiles" => magnetic["profiles"],
            "filament_count" => length(magnetic["filaments"]),
            "contract_hash" => canonical_hash(magnetic))
        push!(attempts, _v53_attempt("explicit_boundary_profile_filament_compile_v54",
            "ready"; executed = true, applicable = true,
            result_hash = compiled_fourier["contract_hash"], details = compiled_fourier))
    end

    pulsed = contracts["pulsed_device"]
    if haskey(pulsed, "drive_history")
        integrated = _v54_drive_integral(pulsed)
        requested = Float64(pulsed["drive_history"]["requested_energy_j"])
        relative = abs(integrated - requested) / max(requested, 1.0e-30)
        status = isfinite(relative) && relative <= 1.0e-12 ? "pass" : "fail"
        push!(attempts, _v53_attempt("time_resolved_drive_energy_audit_v54",
            status; executed = true, applicable = true,
            reason = status == "pass" ? nothing : "drive history does not integrate to requested energy",
            result_hash = canonical_hash(Dict("integrated_energy_j" => integrated,
                "requested_energy_j" => requested)),
            details = Dict("integrated_energy_j" => integrated,
                "requested_energy_j" => requested,
                "relative_error" => relative,
                "material_count" => length(pulsed["materials"]),
                "mesh_levels" => [pulsed["mesh_convergence"]["coarse_cells"],
                    pulsed["mesh_convergence"]["fine_cells"]])))
    end

    ledgers = contracts["ledgers"]
    ledger_residuals = Dict{String,Float64}(
        "power" => abs(Float64(ledgers["power"]["closure_residual_w"])),
        "particle" => abs(Float64(ledgers["particle"]["closure_residual_per_s"])),
        "fuel_inventory" => abs(Float64(
            ledgers["fuel_inventory"]["closure_residual_kg_per_s"])))
    push!(attempts, _v53_attempt("power_particle_fuel_end_loss_ledger_audit_v54",
        all(iszero, values(ledger_residuals)) ? "pass" : "fail";
        executed = true, applicable = true,
        result_hash = canonical_hash(ledgers),
        details = Dict("closure_residuals" => ledger_residuals,
            "end_loss_applicable" => ledgers["end_loss"]["applicable"])))

    executed = count(item -> item["executed"] === true, attempts)
    c1 = count(item -> item["candidate_c1_evidence_authorized"] === true, attempts)
    hard_fail = count(item -> item["status"] == "fail", attempts)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_index" => Int(candidate_index),
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "module_ids" => copy(compiled.module_ids), "attempts" => attempts,
        "attempt_count" => length(attempts), "executed_backend_count" => executed,
        "candidate_c1_authorized_route_count" => c1,
        "hard_fail_route_count" => hard_fail,
        "status" => hard_fail > 0 ? "candidate_bound_route_fail" :
            c1 > 0 ? "partial_c1_route_pass_deeper_physics_unknown" :
            "solver_inputs_ready_deeper_physics_unknown",
        "contract_generated_during_search" => true,
        "parent_synthesized" => false, "promotion_authorized" => false,
        "claim_boundary" => _V54_CLAIM_BOUNDARY)
end
