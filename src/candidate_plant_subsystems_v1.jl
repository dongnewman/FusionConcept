const PLANT_SUBSYSTEM_ROLE_IDS_V1 = (
    "heating_and_current_drive_wall_plug",
    "particle_injection_fuel_processing",
    "magnet_power_and_pulse_storage",
    "cryogenic_system",
    "vacuum_exhaust_pumping",
    "coolant_circulation_heat_rejection",
    "thermal_conversion_auxiliaries",
    "shielding_cooling",
    "controls_diagnostics_auxiliaries",
    "direct_energy_recovery",
    "gross_electric_generation",
)

"Candidate-bound exhaust, fuel, heat-cycle and auxiliary plant declaration."
struct PlantSubsystemManifestV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    status::Symbol
    role_applicability::Dict{String,Any}
    exhaust_networks::Vector{Dict{String,Any}}
    fuel_cycle_systems::Vector{Dict{String,Any}}
    thermal_cycles::Vector{Dict{String,Any}}
    shielding_cooling_systems::Vector{Dict{String,Any}}
    auxiliary_loads::Vector{Dict{String,Any}}
    direct_recovery_systems::Vector{Dict{String,Any}}
    uncertainty_contract::Dict{String,Any}
    unresolved_reasons::Vector{String}
    manifest_hash::String
end

function _cps_v1_efficiency!(reasons, value, context)
    _cem_v1_finite(value) && 0.0 < Float64(value) <= 1.0 ||
        push!(reasons, "$context must be in (0,1]")
end

function _cps_v1_nonnegative!(reasons, value, context)
    _cem_v1_finite(value) && Float64(value) >= 0.0 ||
        push!(reasons, "$context must be finite and nonnegative")
end

function _cps_v1_positive!(reasons, value, context)
    _cem_v1_positive(value) || push!(reasons, "$context must be positive")
end

function _cps_v1_sources!(reasons, record, context)
    refs = get(record, "source_refs", nothing)
    refs isa AbstractVector && !isempty(refs) || push!(reasons, "$context must cite source_refs")
    _cem_v1_hash(get(record, "data_hash", nothing)) ||
        push!(reasons, "$context data_hash must be a sha256 hash")
    uncertainty = get(record, "relative_uncertainty", nothing)
    _cem_v1_finite(uncertainty) && 0.0 <= Float64(uncertainty) <= 1.0 ||
        push!(reasons, "$context relative_uncertainty must be in [0,1]")
end

function _cps_v1_manifest_body(genome, status, applicability, exhaust, fuel, thermal,
        shielding, auxiliaries, recovery, uncertainty, reasons)
    return Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "status" => String(status), "role_applicability" => applicability,
        "exhaust_networks" => exhaust, "fuel_cycle_systems" => fuel,
        "thermal_cycles" => thermal, "shielding_cooling_systems" => shielding,
        "auxiliary_loads" => auxiliaries, "direct_recovery_systems" => recovery,
        "uncertainty_contract" => uncertainty,
        "unresolved_reasons" => sort!(unique(reasons)),
        "routing_basis" => "explicit plant roles, regions, species, operators and validity only",
        "family_label_used" => false, "generated_nominal" => false)
end

"Compile the complete plant-role declaration without inserting pump, cycle or auxiliary defaults."
function compile_plant_subsystem_manifest_v1(genome::Genome)
    raw = get(genome.normalized, "plant_subsystem_manifest_v1", nothing)
    if !(raw isa AbstractDict)
        reasons = ["missing explicit plant_subsystem_manifest_v1 declaration"]
        body = _cps_v1_manifest_body(genome, :unknown, Dict{String,Any}(),
            Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
            Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
            Dict{String,Any}(), reasons)
        return PlantSubsystemManifestV1("1.0.0", genome.design_id, genome.physics_hash,
            :unknown, Dict{String,Any}(), Dict{String,Any}[], Dict{String,Any}[],
            Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
            Dict{String,Any}[], Dict{String,Any}(), reasons, canonical_hash(body))
    end
    declaration = _cem_v1_dict(raw)
    reasons = String[]
    _cem_v1_missing!(reasons, declaration, ("role_applicability", "exhaust_networks",
        "fuel_cycle_systems", "thermal_cycles", "shielding_cooling_systems",
        "auxiliary_loads", "direct_recovery_systems", "uncertainty_contract"),
        "plant subsystem manifest")
    applicability = _cem_v1_dict(get(declaration, "role_applicability", nothing))
    for id in PLANT_SUBSYSTEM_ROLE_IDS_V1
        role = _cem_v1_dict(get(applicability, id, nothing))
        _cem_v1_missing!(reasons, role,
            ("status", "provider", "basis", "time_behavior", "relative_uncertainty"),
            "plant role $id")
        status = String(get(role, "status", ""))
        status in ("applicable", "not_applicable") ||
            push!(reasons, "plant role $id status must be applicable or not_applicable")
        isempty(strip(String(get(role, "provider", "")))) &&
            push!(reasons, "plant role $id must name its provider")
        isempty(strip(String(get(role, "basis", "")))) &&
            push!(reasons, "plant role $id must state an applicability basis")
        String(get(role, "time_behavior", "")) in
            ("continuous", "pulse_active", "already_cycle_average", "not_applicable") ||
            push!(reasons, "plant role $id has unsupported time_behavior")
        role_u = get(role, "relative_uncertainty", nothing)
        _cem_v1_finite(role_u) && 0.0 <= Float64(role_u) <= 1.0 ||
            push!(reasons, "plant role $id relative_uncertainty must be in [0,1]")
    end
    exhaust = _cem_v1_vector(get(declaration, "exhaust_networks", Any[]))
    fuel = _cem_v1_vector(get(declaration, "fuel_cycle_systems", Any[]))
    thermal = _cem_v1_vector(get(declaration, "thermal_cycles", Any[]))
    shielding = _cem_v1_vector(get(declaration, "shielding_cooling_systems", Any[]))
    auxiliaries = _cem_v1_vector(get(declaration, "auxiliary_loads", Any[]))
    recovery = _cem_v1_vector(get(declaration, "direct_recovery_systems", Any[]))
    for (records, key, context) in ((exhaust, "network_id", "exhaust_networks"),
            (fuel, "system_id", "fuel_cycle_systems"),
            (thermal, "cycle_id", "thermal_cycles"),
            (shielding, "system_id", "shielding_cooling_systems"),
            (auxiliaries, "load_id", "auxiliary_loads"),
            (recovery, "system_id", "direct_recovery_systems"))
        _cem_v1_unique_ids!(reasons, records, key, context)
    end
    applicable(id) = String(get(_cem_v1_dict(get(applicability, id, nothing)),
        "status", "")) == "applicable"
    applicable("vacuum_exhaust_pumping") && isempty(exhaust) &&
        push!(reasons, "applicable vacuum_exhaust_pumping has no exhaust network")
    applicable("particle_injection_fuel_processing") && isempty(fuel) &&
        push!(reasons, "applicable particle_injection_fuel_processing has no fuel-cycle system")
    (applicable("gross_electric_generation") ||
        applicable("thermal_conversion_auxiliaries")) && isempty(thermal) &&
        push!(reasons, "applicable thermal conversion roles have no thermal cycle")
    applicable("shielding_cooling") && isempty(shielding) &&
        push!(reasons, "applicable shielding_cooling has no cooling system")
    applicable("controls_diagnostics_auxiliaries") && isempty(auxiliaries) &&
        push!(reasons, "applicable controls_diagnostics_auxiliaries has no auxiliary loads")
    applicable("direct_energy_recovery") && isempty(recovery) &&
        push!(reasons, "applicable direct_energy_recovery has no recovery system")
    region_ids = Set(item.id for item in genome.plasma_regions)
    for (index, item) in enumerate(exhaust)
        context = "exhaust_networks[$index]"
        _cem_v1_missing!(reasons, item, ("network_id", "target_region_ids", "species_ids",
            "throughput_fraction", "inlet_temperature_k", "inlet_pressure_pa",
            "outlet_pressure_pa", "duct_length_m", "duct_diameter_m",
            "pump_speed_capacity_m3_s", "isothermal_efficiency", "operating_duty_factor", "source_refs",
            "data_hash", "relative_uncertainty"), context)
        targets = get(item, "target_region_ids", Any[])
        targets isa AbstractVector && !isempty(targets) ||
            push!(reasons, "$context must target at least one region")
        for target in targets
            String(target) in region_ids || push!(reasons, "$context references unknown region $target")
        end
        species = get(item, "species_ids", Any[])
        species isa AbstractVector && !isempty(species) ||
            push!(reasons, "$context must declare species_ids")
        _cps_v1_nonnegative!(reasons, get(item, "throughput_fraction", nothing),
            "$context throughput_fraction")
        _cps_v1_positive!(reasons, get(item, "inlet_temperature_k", nothing),
            "$context inlet_temperature_k")
        _cps_v1_positive!(reasons, get(item, "inlet_pressure_pa", nothing),
            "$context inlet_pressure_pa")
        _cps_v1_positive!(reasons, get(item, "outlet_pressure_pa", nothing),
            "$context outlet_pressure_pa")
        get(item, "outlet_pressure_pa", 0.0) > get(item, "inlet_pressure_pa", Inf) ||
            push!(reasons, "$context outlet pressure must exceed inlet pressure")
        _cps_v1_positive!(reasons, get(item, "duct_length_m", nothing), "$context duct_length_m")
        _cps_v1_positive!(reasons, get(item, "duct_diameter_m", nothing), "$context duct_diameter_m")
        _cps_v1_positive!(reasons, get(item, "pump_speed_capacity_m3_s", nothing),
            "$context pump_speed_capacity_m3_s")
        _cps_v1_efficiency!(reasons, get(item, "isothermal_efficiency", nothing),
            "$context isothermal_efficiency")
        _cps_v1_efficiency!(reasons, get(item, "operating_duty_factor", nothing),
            "$context operating_duty_factor")
        _cps_v1_sources!(reasons, item, context)
    end
    !isempty(exhaust) && abs(sum(Float64(get(item, "throughput_fraction", 0.0))
        for item in exhaust) - 1.0) > 1.0e-8 &&
        push!(reasons, "exhaust throughput fractions must sum to one")
    for (index, item) in enumerate(fuel)
        context = "fuel_cycle_systems[$index]"
        _cem_v1_missing!(reasons, item, ("system_id", "species_ids", "throughput_fraction",
            "processing_capacity_per_s", "processing_energy_j_per_particle",
            "processing_efficiency", "capacity_basis", "residence_time_s", "inventory_limit_kg",
            "retention_fraction", "source_refs", "data_hash", "relative_uncertainty"), context)
        _cps_v1_nonnegative!(reasons, get(item, "throughput_fraction", nothing),
            "$context throughput_fraction")
        for key in ("processing_capacity_per_s", "processing_energy_j_per_particle",
                "residence_time_s", "inventory_limit_kg")
            _cps_v1_positive!(reasons, get(item, key, nothing), "$context $key")
        end
        _cps_v1_efficiency!(reasons, get(item, "processing_efficiency", nothing),
            "$context processing_efficiency")
        String(get(item, "capacity_basis", "")) in ("peak_rate", "cycle_average_rate") ||
            push!(reasons, "$context capacity_basis must be peak_rate or cycle_average_rate")
        retention = get(item, "retention_fraction", nothing)
        _cem_v1_finite(retention) && 0.0 <= Float64(retention) <= 1.0 ||
            push!(reasons, "$context retention_fraction must be in [0,1]")
        _cps_v1_sources!(reasons, item, context)
    end
    !isempty(fuel) && abs(sum(Float64(get(item, "throughput_fraction", 0.0))
        for item in fuel) - 1.0) > 1.0e-8 &&
        push!(reasons, "fuel-cycle throughput fractions must sum to one")
    for (index, item) in enumerate(thermal)
        context = "thermal_cycles[$index]"
        _cem_v1_missing!(reasons, item, ("cycle_id", "source_heat_role", "source_fraction",
            "heat_exchanger_effectiveness", "coolant_mass_flow_kg_s",
            "coolant_specific_heat_j_kg_k", "coolant_density_kg_m3",
            "coolant_inlet_temperature_k", "sink_temperature_k", "second_law_efficiency",
            "coolant_pressure_drop_pa", "circulation_pump_efficiency",
            "circulation_duty_factor", "generator_auxiliary_fraction", "source_refs",
            "data_hash", "relative_uncertainty"), context)
        String(get(item, "source_heat_role", "")) in ("fusion_power", "loss_power") ||
            push!(reasons, "$context source_heat_role is unsupported")
        for key in ("source_fraction", "heat_exchanger_effectiveness",
                "second_law_efficiency", "circulation_pump_efficiency",
                "circulation_duty_factor")
            _cps_v1_efficiency!(reasons, get(item, key, nothing), "$context $key")
        end
        auxiliary = get(item, "generator_auxiliary_fraction", nothing)
        _cem_v1_finite(auxiliary) && 0.0 <= Float64(auxiliary) < 1.0 ||
            push!(reasons, "$context generator_auxiliary_fraction must be in [0,1)")
        for key in ("coolant_mass_flow_kg_s", "coolant_specific_heat_j_kg_k",
                "coolant_density_kg_m3", "coolant_inlet_temperature_k",
                "sink_temperature_k", "coolant_pressure_drop_pa")
            _cps_v1_positive!(reasons, get(item, key, nothing), "$context $key")
        end
        _cps_v1_sources!(reasons, item, context)
    end
    for role in ("fusion_power", "loss_power")
        fraction = sum(Float64(get(item, "source_fraction", 0.0)) for item in thermal if
            String(get(item, "source_heat_role", "")) == role; init = 0.0)
        fraction += sum(Float64(get(item, "source_fraction", 0.0)) for item in shielding if
            String(get(item, "source_heat_role", "")) == role; init = 0.0)
        fraction += sum(Float64(get(item, "source_fraction", 0.0)) for item in recovery if
            String(get(item, "source_heat_role", "")) == role; init = 0.0)
        fraction <= 1.0 + 1.0e-8 || push!(reasons,
            "combined thermal, shielding and recovery source fractions for $role exceed one")
    end
    for (index, item) in enumerate(shielding)
        context = "shielding_cooling_systems[$index]"
        _cem_v1_missing!(reasons, item, ("system_id", "source_heat_role", "source_fraction",
            "cold_temperature_k", "ambient_temperature_k", "second_law_efficiency",
            "source_refs", "data_hash", "relative_uncertainty"), context)
        String(get(item, "source_heat_role", "")) in ("fusion_power", "loss_power") ||
            push!(reasons, "$context source_heat_role is unsupported")
        _cps_v1_efficiency!(reasons, get(item, "source_fraction", nothing),
            "$context source_fraction")
        _cps_v1_efficiency!(reasons, get(item, "second_law_efficiency", nothing),
            "$context second_law_efficiency")
        _cps_v1_positive!(reasons, get(item, "cold_temperature_k", nothing),
            "$context cold_temperature_k")
        _cps_v1_positive!(reasons, get(item, "ambient_temperature_k", nothing),
            "$context ambient_temperature_k")
        _cps_v1_sources!(reasons, item, context)
    end
    for (index, item) in enumerate(auxiliaries)
        context = "auxiliary_loads[$index]"
        _cem_v1_missing!(reasons, item, ("load_id", "rated_power_w", "duty_factor",
            "supply_efficiency", "source_refs", "data_hash", "relative_uncertainty"), context)
        _cps_v1_positive!(reasons, get(item, "rated_power_w", nothing), "$context rated_power_w")
        _cps_v1_efficiency!(reasons, get(item, "duty_factor", nothing), "$context duty_factor")
        _cps_v1_efficiency!(reasons, get(item, "supply_efficiency", nothing),
            "$context supply_efficiency")
        _cps_v1_sources!(reasons, item, context)
    end
    for (index, item) in enumerate(recovery)
        context = "direct_recovery_systems[$index]"
        _cem_v1_missing!(reasons, item, ("system_id", "source_heat_role", "source_fraction",
            "conversion_efficiency", "capacity_w", "source_refs", "data_hash",
            "relative_uncertainty"), context)
        String(get(item, "source_heat_role", "")) in ("fusion_power", "loss_power") ||
            push!(reasons, "$context source_heat_role is unsupported")
        _cps_v1_efficiency!(reasons, get(item, "source_fraction", nothing),
            "$context source_fraction")
        _cps_v1_efficiency!(reasons, get(item, "conversion_efficiency", nothing),
            "$context conversion_efficiency")
        _cps_v1_positive!(reasons, get(item, "capacity_w", nothing), "$context capacity_w")
        _cps_v1_sources!(reasons, item, context)
    end
    uncertainty = _cem_v1_dict(get(declaration, "uncertainty_contract", nothing))
    _cem_v1_missing!(reasons, uncertainty, ("coverage_sigma", "net_sign_required"),
        "uncertainty_contract")
    _cps_v1_positive!(reasons, get(uncertainty, "coverage_sigma", nothing),
        "uncertainty_contract coverage_sigma")
    get(uncertainty, "net_sign_required", nothing) isa Bool ||
        push!(reasons, "uncertainty_contract net_sign_required must be boolean")
    status = isempty(reasons) ? :pass : :unsupported
    body = _cps_v1_manifest_body(genome, status, applicability, exhaust, fuel,
        thermal, shielding, auxiliaries, recovery, uncertainty, reasons)
    return PlantSubsystemManifestV1("1.0.0", genome.design_id, genome.physics_hash,
        status, applicability, exhaust, fuel, thermal, shielding, auxiliaries,
        recovery, uncertainty, sort!(unique(reasons)), canonical_hash(body))
end

function plant_subsystem_manifest_to_dict_v1(value::PlantSubsystemManifestV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "status" => String(value.status), "role_applicability" => value.role_applicability,
        "exhaust_networks" => value.exhaust_networks,
        "fuel_cycle_systems" => value.fuel_cycle_systems,
        "thermal_cycles" => value.thermal_cycles,
        "shielding_cooling_systems" => value.shielding_cooling_systems,
        "auxiliary_loads" => value.auxiliary_loads,
        "direct_recovery_systems" => value.direct_recovery_systems,
        "uncertainty_contract" => value.uncertainty_contract,
        "unresolved_reasons" => value.unresolved_reasons,
        "routing_basis" => "explicit plant roles, regions, species, operators and validity only",
        "family_label_used" => false, "generated_nominal" => false,
        "manifest_hash" => value.manifest_hash)
end
