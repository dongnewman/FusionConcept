const _V66_ICF_CLAIM_BOUNDARY =
    "V66 separates pulse active time, shot repetition and plant availability, and adds " *
    "candidate-bound ICF target layers, radial initial profiles, drive history and numerical " *
    "convergence requests. EOS and opacity are never synthesized: only acquired, hash-pinned " *
    "microphysics artifacts may fill those slots. Missing artifacts remain unknown and block " *
    "external Stage-8 execution. Routing uses declared capabilities, never family labels."

function _v66_parameter(items, id::String)
    found = Any[]
    for item in items
        parameters = get(item, "parameters", Dict{String,Any}())
        haskey(parameters, id) && push!(found, parameters[id])
    end
    length(found) == 1 || return nothing
    value = only(found)
    value isa AbstractDict && get(value, "value", nothing) isa Real || return nothing
    return Float64(value["value"])
end

_v66_is_icf(raw) = _prhm_v1_contains(get(raw, "stability_mechanisms", Any[]),
    "icf_radiation_hydrodynamics") ||
    _prhm_v1_contains(get(raw, "compression_systems", Any[]), "laser_")

function _v66_time_semantics!(raw, seed::String)
    mode = lowercase(String(raw["mission"]["operating_mode"]))
    (occursin("pulse", mode) || occursin("transient", mode)) || return nothing
    systems = get(raw, "compression_systems", Any[])
    legacy = get(raw, "time_integration_contract_v1", Dict{String,Any}())
    is_icf = _v66_is_icf(raw)
    system_rate = _v66_parameter(systems, "repetition_rate")
    repetition = system_rate isa Real ? system_rate :
        get(legacy, "repetition_rate_hz", nothing)
    repetition isa Real && isfinite(Float64(repetition)) && repetition > 0.0 ||
        throw(ArgumentError("v66 pulsed Genome lacks an explicit positive repetition rate"))
    duration = if is_icf
        0.5e-9 * 40.0^_v61_unit(seed * ":driver_pulse_width", 1)
    else
        get(legacy, "pulse_duration_s", nothing)
    end
    duration isa Real && isfinite(Float64(duration)) && duration > 0.0 ||
        throw(ArgumentError("v66 pulsed Genome lacks an explicit positive active duration"))
    availability = _v66_parameter(systems, "availability")
    availability = availability isa Real ? availability :
        0.10 + 0.85 * _v61_unit(seed * ":plant_availability", 2)
    0.0 < availability <= 1.0 || throw(ArgumentError(
        "v66 plant availability must be within (0,1]"))
    active = Float64(duration) * Float64(repetition)
    if active > 1.0
        conflict = Dict{String,Any}(
            "schema_version" => "1.0.0",
            "status" => "unsupported",
            "conflict_code" => "active_phase_exceeds_declared_cycle",
            "declared_active_phase_duration_s" => Float64(duration),
            "declared_shot_repetition_rate_hz" => Float64(repetition),
            "declared_cycle_period_s" => 1.0 / Float64(repetition),
            "implied_pulse_active_fraction" => active,
            "source_bindings" => Dict(
                "active_duration" => is_icf ? "v66 explicit driver-pulse search gene" :
                    "time_integration_contract_v1.pulse_duration_s",
                "shot_repetition" => system_rate isa Real ?
                    "compression_systems.repetition_rate" :
                    "time_integration_contract_v1.repetition_rate_hz"),
            "family_label_used" => false)
        conflict["conflict_hash"] = canonical_hash(conflict)
        raw["time_semantics_conflict_v1"] = conflict
        delete!(raw, "time_integration_contract_v2")
        return conflict
    end
    contract = Dict{String,Any}(
        "schema_version" => "2.0.0", "mode" => "pulsed",
        "active_phase_kind" => is_icf ? "laser_drive_pulse" : "declared_pulse_active_phase",
        "active_phase_duration_s" => Float64(duration),
        "shot_repetition_rate_hz" => Float64(repetition),
        "cycle_period_s" => 1.0 / Float64(repetition),
        "pulse_active_fraction" => active,
        "plant_availability_factor" => Float64(availability),
        "average_power_basis" => "scheduled_operating_cycle",
        "energy_to_average_power_rule" =>
            "energy_per_shot_j_times_shot_repetition_rate_hz",
        "event_times_s" => [0.0, Float64(duration)],
        "source_bindings" => Dict(
            "active_duration" => is_icf ? "v66 explicit driver-pulse search gene" :
                "time_integration_contract_v1.pulse_duration_s",
            "shot_repetition" => system_rate isa Real ?
                "compression_systems.repetition_rate" :
                "time_integration_contract_v1.repetition_rate_hz",
            "plant_availability" => availability isa Real &&
                _v66_parameter(systems, "availability") isa Real ?
                "compression_systems.availability" : "v66 explicit availability search gene"),
        "family_label_used" => false)
    contract["contract_hash"] = canonical_hash(contract)
    raw["time_integration_contract_v2"] = contract
    # Compatibility view for legacy solvers. Its duty factor is the physical pulse-active
    # fraction, never plant availability and never a second independently sampled rate.
    compatibility = Dict{String,Any}(
        "schema_version" => "1.1.0", "mode" => "pulsed",
        "pulse_duration_s" => Float64(duration),
        "repetition_rate_hz" => Float64(repetition), "duty_factor" => active,
        "event_times_s" => [0.0, Float64(duration)],
        "semantic_source" => "time_integration_contract_v2",
        "generation_basis" => "v66 compatibility projection; not an independent gene")
    compatibility["contract_hash"] = canonical_hash(compatibility)
    raw["time_integration_contract_v1"] = compatibility
    targets = raw["mission"]["targets"]
    targets["active_phase_duration"] = _v61_q(duration, "s",
        "time_integration_contract_v2.active_phase_duration_s")
    targets["shot_repetition_rate"] = _v61_q(repetition, "Hz",
        "time_integration_contract_v2.shot_repetition_rate_hz")
    targets["plant_availability_factor"] = _v61_q(availability, "1",
        "time_integration_contract_v2.plant_availability_factor")
    return contract
end

function _v66_constant_profile(inner, outer, value, unit, basis)
    return Dict{String,Any}("basis" => "radial_piecewise_linear_v1",
        "coordinate" => "radius_m", "unit" => unit,
        "knots" => [Dict("radius_m" => inner, "value" => value),
            Dict("radius_m" => outer, "value" => value)],
        "generation_basis" => basis)
end

function _v66_normalized_drive_history(energy, duration, seed)
    fractions = [0.0, 0.18, 0.72, 1.0]
    shape = [0.0, 0.12 + 0.18 * _v61_unit(seed * ":foot", 1), 1.0, 0.0]
    raw_integral = sum(0.5 * (shape[index] + shape[index + 1]) *
        (fractions[index + 1] - fractions[index]) * duration
        for index in 1:length(shape)-1)
    scale = energy / raw_integral
    return Dict{String,Any}[
        Dict("time_s" => fractions[index] * duration,
            "power_w" => shape[index] * scale) for index in eachindex(shape)]
end

function _v66_replace_regional_icf_geometry!(raw, geometry)
    regional = get(raw, "regional_solver_contract_v1", nothing)
    regional isa AbstractDict || return
    by_id = Dict(String(item["region_id"]) => item for item in
        get(regional, "region_records", Any[]))
    required = ("fuel_capsule", "ignition_hotspot", "pulsed_chamber_region")
    all(haskey(by_id, id) for id in required) || return
    volumes = Dict("fuel_capsule" => geometry["fuel_shell_volume_m3"],
        "ignition_hotspot" => geometry["hotspot_volume_m3"],
        "pulsed_chamber_region" => geometry["chamber_free_volume_m3"])
    mean_dt_mass = 2.5 * _CPSR_V1_AMU
    profiles = Dict{String,Any}(
        "fuel_capsule" => (geometry["fuel_density_kg_m3"] / mean_dt_mass,
            geometry["fuel_temperature_k"] * _CPSR_V1_KB / _CSR_V1_E_CHARGE,
            "explicit v66 DT-ice initial state"),
        "ignition_hotspot" => (geometry["hotspot_density_kg_m3"] / mean_dt_mass,
            geometry["hotspot_temperature_ev"], "explicit v66 DT-gas initial state"),
        "pulsed_chamber_region" => (geometry["chamber_particle_density_m3"],
            geometry["chamber_temperature_k"] * _CPSR_V1_KB / _CSR_V1_E_CHARGE,
            "explicit v66 residual-DT chamber state"))
    total = sum(values(volumes))
    for id in required
        item = by_id[id]
        volume = Float64(volumes[id]); density, temperature, basis = profiles[id]
        profile = Dict{String,Any}("schema_version" => "1.0.0",
            "coordinate" => "normalized_volume", "basis" => "edge_plus_axis_power_v1",
            "particle_density" => Dict("axis_value_m3" => density,
                "edge_value_m3" => density, "exponent" => 1.0, "unit" => "m^-3"),
            "temperature" => Dict("axis_value_ev" => temperature,
                "edge_value_ev" => temperature, "exponent" => 1.0, "unit" => "eV"),
            "integration_measure" => "dV=region_volume*d(normalized_volume)",
            "generation_basis" => basis)
        item["volume_m3"] = volume; item["partition_weight"] = volume / total
        item["state_profile"] = profile
        item["analytic_integrals"] = _v61_profile_integrals(profile, volume)
        item["mesh"]["region_volume_m3"] = volume
        item["mesh"]["volume_basis"] = id == "pulsed_chamber_region" ?
            "finite_cylindrical_chamber_minus_capsule_v66" :
            "explicit_nonoverlapping_spherical_target_layer_v66"
    end
    areas = Dict(
        "v61_interface_0001_fuel_capsule_to_ignition_hotspot" =>
            4.0 * pi * geometry["hotspot_radius_m"]^2,
        "v61_interface_0002_ignition_hotspot_to_pulsed_chamber_region" =>
            4.0 * pi * geometry["capsule_outer_radius_m"]^2)
    for item in get(regional, "interface_records", Any[])
        id = String(item["interface_id"]); haskey(areas, id) || continue
        old = Float64(item["area_m2"]); new = Float64(areas[id])
        ratio = new / max(old, eps(Float64))
        item["area_m2"] = new
        item["particle_transfer_volume_m3_s"] *= ratio
        item["energy_transfer_volume_m3_s"] *= ratio
        from_volume = volumes[String(item["from_region_id"])]
        to_volume = volumes[String(item["to_region_id"])]
        item["operator_contract"]["validity"]["minimum_volume_m3"] =
            min(from_volume, to_volume)
        item["operator_contract"]["generation_basis"] =
            "explicit v66 target/chamber interface geometry; no family routing"
    end
    regional["generator_id"] = "regional_genome_grammar_v61_plus_icf_geometry_v66"
    regional["contract_hash"] = canonical_hash(Dict{String,Any}(String(key) => value
        for (key, value) in regional if String(key) != "contract_hash"))
end

function _v66_icf_manifest!(raw, seed::String, time_contract)
    _v66_is_icf(raw) || return nothing
    systems = raw["compression_systems"]
    fuel_mass = _v66_parameter(systems, "dt_fuel_mass")
    energy = _v66_parameter(systems, "on_target_energy")
    fuel_mass isa Real && fuel_mass > 0.0 || throw(ArgumentError(
        "v66 ICF grammar requires explicit positive D-T fuel mass"))
    energy isa Real && energy > 0.0 || throw(ArgumentError(
        "v66 ICF grammar requires explicit positive on-target energy"))
    fuel_density = 180.0 + 120.0 * _v61_unit(seed * ":fuel_density", 10)
    hotspot_mass_fraction = 1.0e-4 * 100.0^_v61_unit(seed * ":hotspot_mass", 11)
    hotspot_radius_fraction = 0.08 + 0.22 * _v61_unit(seed * ":hotspot_radius", 12)
    hotspot_density = fuel_density * (0.001 + 0.019 * _v61_unit(seed * ":hotspot_density", 13))
    hotspot_mass = fuel_mass * hotspot_mass_fraction
    hotspot_volume = hotspot_mass / hotspot_density
    hotspot_radius = (3.0 * hotspot_volume / (4.0 * pi))^(1.0 / 3.0)
    fuel_shell_mass = fuel_mass - hotspot_mass
    fuel_shell_volume = fuel_shell_mass / fuel_density
    fuel_outer_radius = (hotspot_radius^3 + 3.0 * fuel_shell_volume /
        (4.0 * pi))^(1.0 / 3.0)
    ablator_thickness = fuel_outer_radius *
        (0.04 + 0.16 * _v61_unit(seed * ":ablator_thickness", 14))
    capsule_outer_radius = fuel_outer_radius + ablator_thickness
    fuel_temperature = 12.0 + 10.0 * _v61_unit(seed * ":fuel_temperature", 15)
    hotspot_temperature = 100.0 + 900.0 * _v61_unit(seed * ":hotspot_temperature", 16)
    ablator_density = 900.0 + 300.0 * _v61_unit(seed * ":ablator_density", 17)
    wavelength = _v61_unit(seed * ":wavelength", 18) < 0.5 ? 248.0e-9 : 351.0e-9
    duration = Float64(time_contract["active_phase_duration_s"])
    knots = _v66_normalized_drive_history(energy, duration, seed)
    spatial = Dict("profile" => "super_gaussian_axisymmetric_v1",
        "order" => 4.0 + 4.0 * _v61_unit(seed * ":beam_order", 19),
        "target_radius_m" => capsule_outer_radius,
        "illumination_basis" => "candidate-bound beam-array target projection")
    deposition = Dict("operator_id" => "candidate_laser_ray_deposition_contract_v1",
        "requires" => ["wavelength", "spatial_profile", "material_opacity"],
        "provides" => ["layer_resolved_absorbed_power"],
        "jacobian_provider" => "external_backend_or_automatic_differentiation")
    layers = Dict{String,Any}[
        Dict("layer_id" => "dt_hotspot_gas", "inner_radius_m" => 0.0,
            "outer_radius_m" => hotspot_radius, "material_id" => "dt_mixture",
            "material_version" => "candidate_composition_v66",
            "isotope_fractions" => Dict("D" => 0.5, "T" => 0.5),
            "initial_density_profile" => _v66_constant_profile(0.0, hotspot_radius,
                hotspot_density, "kg/m^3", "v66 explicit hotspot search gene"),
            "initial_temperature_profile" => _v66_constant_profile(0.0, hotspot_radius,
                hotspot_temperature, "eV", "v66 explicit hotspot search gene"),
            "mesh_region_id" => "ignition_hotspot"),
        Dict("layer_id" => "dt_ice", "inner_radius_m" => hotspot_radius,
            "outer_radius_m" => fuel_outer_radius, "material_id" => "dt_mixture",
            "material_version" => "candidate_composition_v66",
            "isotope_fractions" => Dict("D" => 0.5, "T" => 0.5),
            "initial_density_profile" => _v66_constant_profile(hotspot_radius,
                fuel_outer_radius, fuel_density, "kg/m^3",
                "mass-conserving v66 DT-ice search gene"),
            "initial_temperature_profile" => _v66_constant_profile(hotspot_radius,
                fuel_outer_radius, fuel_temperature, "K",
                "v66 explicit cryogenic target search gene"),
            "mesh_region_id" => "fuel_capsule"),
        Dict("layer_id" => "ch_ablator", "inner_radius_m" => fuel_outer_radius,
            "outer_radius_m" => capsule_outer_radius, "material_id" => "ch_ablator",
            "material_version" => "candidate_composition_v66",
            "isotope_fractions" => Dict("C12" => 1.0 / 3.0, "H1" => 2.0 / 3.0),
            "initial_density_profile" => _v66_constant_profile(fuel_outer_radius,
                capsule_outer_radius, ablator_density, "kg/m^3",
                "v66 explicit ablator-density search gene"),
            "initial_temperature_profile" => _v66_constant_profile(fuel_outer_radius,
                capsule_outer_radius, 300.0, "K",
                "v66 explicit target assembly condition"),
            "mesh_region_id" => "fuel_capsule")]
    required_outputs = ["shock_radius_history", "shock_timing", "convergence_ratio",
        "areal_density", "hotspot_temperature", "absorbed_drive_energy",
        "radiation_loss", "burn_yield", "alpha_deposition", "conservation_ledger"]
    manifest = Dict{String,Any}(
        "schema_version" => "1.0.0", "target_layers" => layers,
        # Deliberately empty until real acquired table/model artifacts are pinned.
        "material_microphysics" => Dict{String,Any}(),
        "drive_history" => Dict("wavelength_m" => wavelength,
            "temporal_power_knots" => knots, "integrated_on_target_energy_j" => energy,
            "spatial_profile" => spatial, "spatial_profile_hash" => canonical_hash(spatial),
            "deposition_operator" => deposition,
            "deposition_operator_hash" => canonical_hash(deposition)),
        "numerical_convergence_plan" => Dict("radial_cell_levels" => [64, 128],
            "radiation_group_levels" => [16, 32], "cfl_target" => 0.5,
            "relative_tolerance" => 0.02,
            "convergence_observables" => ["shock_timing", "areal_density",
                "burn_yield", "conservation_ledger"]),
        "required_outputs" => required_outputs,
        "generation_basis" => "explicit deterministic candidate genes before common screen",
        "microphysics_policy" => "real acquired version and artifact hashes only",
        "family_label_used" => false)
    raw["pulsed_rhd_manifest_v1"] = manifest
    chamber_radius = Float64(raw["mission"]["targets"]["screen_chamber_radius"]["value"])
    chamber_half = Float64(raw["mission"]["targets"]["screen_chamber_half_height"]["value"])
    chamber_volume = 2.0 * pi * chamber_radius^2 * chamber_half
    chamber_temperature = 280.0 + 80.0 * _v61_unit(seed * ":chamber_temperature", 20)
    chamber_pressure = 1.0e-4 * 1.0e4^_v61_unit(seed * ":chamber_pressure", 21)
    geometry = Dict{String,Any}(
        "hotspot_radius_m" => hotspot_radius,
        "capsule_outer_radius_m" => capsule_outer_radius,
        "hotspot_volume_m3" => hotspot_volume,
        "fuel_shell_volume_m3" => fuel_shell_volume,
        "chamber_free_volume_m3" => chamber_volume -
            4.0 * pi * capsule_outer_radius^3 / 3.0,
        "fuel_density_kg_m3" => fuel_density,
        "hotspot_density_kg_m3" => hotspot_density,
        "fuel_temperature_k" => fuel_temperature,
        "hotspot_temperature_ev" => hotspot_temperature,
        "chamber_temperature_k" => chamber_temperature,
        "chamber_particle_density_m3" => chamber_pressure /
            (_CPSR_V1_KB * chamber_temperature))
    _v66_replace_regional_icf_geometry!(raw, geometry)
    for region in raw["plasma_regions"]
        id = String(region["id"])
        if id == "fuel_capsule"
            region["parameters"]["generated_outer_radius"] = _v61_q(
                capsule_outer_radius, "m", "v66 explicit layered-target geometry")
            region["parameters"]["generated_shell_half_width"] = _v61_q(
                0.5 * (capsule_outer_radius - hotspot_radius), "m",
                "v66 explicit layered-target geometry")
        elseif id == "ignition_hotspot"
            region["parameters"]["hotspot_radius"] = _v61_q(hotspot_radius, "m",
                "v66 explicit layered-target geometry")
        end
    end
    return manifest
end

function generate_icf_input_ready_genome_v66(base::Genome, module_ids,
        sample_ordinal::Integer)
    raw = deepcopy(base.normalized)
    seed = canonical_hash(Dict("base_physics_hash" => base.physics_hash,
        "module_ids" => String.(module_ids), "sample_ordinal" => Int(sample_ordinal),
        "generator" => "icf_input_ready_genome_grammar_v66"))
    is_icf = _v66_is_icf(raw)
    time_contract = _v66_time_semantics!(raw, seed)
    if is_icf && time_contract !== nothing &&
            String(get(time_contract, "status", "complete")) != "unsupported"
        _v66_icf_manifest!(raw, seed, time_contract)
    end
    _v18_push_unique!(raw["provenance"]["notes"], [
        "icf_input_ready_genome_grammar_v66",
        "time semantics separate active pulse, shot repetition and plant availability",
        "ICF microphysics remains unknown until real artifact hashes are acquired"])
    raw["design_id"] = "pending_icf_input_ready_v66"
    provisional = parse_genome(raw)
    raw["design_id"] = "v66_$(canonical_hash(module_ids)[1:12])_s$(lpad(Int(sample_ordinal), 6, '0'))_" *
        provisional.physics_hash[1:12]
    result = parse_genome(raw)
    if time_contract !== nothing
        result.physics_hash != base.physics_hash ||
            error("v66 ICF declarations did not enter physics hash")
    else
        result.physics_hash == base.physics_hash ||
            error("v66 changed the physics hash of a non-ICF candidate")
    end
    return result
end

function evaluate_icf_input_ready_candidate_v66(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        halton_skip::Integer = 4096)
    base = evaluate_plant_ready_candidate_v64(context, candidate_index;
        halton_skip = halton_skip)
    old = base.prescreen.compiled
    genome = generate_icf_input_ready_genome_v66(old.genome, old.module_ids,
        base.sample_ordinal)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("generated v66 genome invalid: " *
        join(report.errors, "; ")))
    compiled = CompiledAttributeGenomeV18(old.assembly_id, old.graph_hash, old.family,
        old.mission_contract_id, copy(old.module_ids), genome, old.evaluator_id,
        old.projection_id, sort!(unique(vcat(old.projection_limitations,
            ["v66 target and drive values are search hypotheses; microphysics is fail-closed"]))),
        copy(old.declared_requirements), sort!(unique(vcat(old.validation_warnings,
            report.warnings))))
    prescreen = _v18_prescreen(compiled, context.evaluators, context.evaluator_registry)
    return CrossTopologyCandidateV20(Int(candidate_index), base.assembly_index,
        base.sample_ordinal, prescreen)
end

function icf_input_ready_contract_audit_v66(genome::Genome)
    time = get(genome.normalized, "time_integration_contract_v2", nothing)
    conflict = get(genome.normalized, "time_semantics_conflict_v1", nothing)
    valid_time = time isa AbstractDict &&
        get(time, "contract_hash", "") == canonical_hash(Dict{String,Any}(
            String(key) => value for (key, value) in time if String(key) != "contract_hash"))
    valid_conflict = conflict isa AbstractDict &&
        String(get(conflict, "status", "")) == "unsupported" &&
        get(conflict, "conflict_hash", "") == canonical_hash(Dict{String,Any}(
            String(key) => value for (key, value) in conflict if
                String(key) != "conflict_hash"))
    time_status = valid_time ? "pass" : valid_conflict ? "unsupported" : "missing"
    rhd = compile_pulsed_rhd_manifest_v1(genome, genome.design_id)
    return Dict{String,Any}("time_semantics_status" => time_status,
        "time_semantics_conflict" => conflict,
        "pulsed_rhd_status" => rhd["status"],
        "pulsed_rhd_manifest_hash" => rhd["manifest_hash"],
        "blocking_missing_inputs" => rhd["blocking_missing_inputs"],
        "declaration_conflicts" => rhd["declaration_conflicts"],
        "family_label_used" => false)
end
