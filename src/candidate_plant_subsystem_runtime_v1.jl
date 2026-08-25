const _CPSR_V1_KB = 1.380649e-23
const _CPSR_V1_AMU = 1.66053906660e-27

"Hash-sealed exhaust, fuel-cycle, thermal-cycle and auxiliary plant result."
struct PlantSubsystemResultEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    status::Symbol
    time_basis::Dict{String,Any}
    exhaust_results::Vector{Dict{String,Any}}
    fuel_cycle_results::Vector{Dict{String,Any}}
    thermal_cycle_results::Vector{Dict{String,Any}}
    plant_roles::Vector{Dict{String,Any}}
    checks::Vector{Dict{String,Any}}
    unresolved_reasons::Vector{String}
    evidence_ceiling::String
    result_hash::String
end

function _cpsr_v1_role_applicable(manifest, id)
    return String(get(_cem_v1_dict(get(manifest.role_applicability, id, nothing)),
        "status", "")) == "applicable"
end

function _cpsr_v1_time_basis(genome::Genome)
    semantic = get(genome.normalized, "time_integration_contract_v2", nothing)
    if semantic isa AbstractDict && String(get(semantic, "mode", "")) == "pulsed"
        duration = get(semantic, "active_phase_duration_s", nothing)
        repetition = get(semantic, "shot_repetition_rate_hz", nothing)
        active = get(semantic, "pulse_active_fraction", nothing)
        availability = get(semantic, "plant_availability_factor", nothing)
        valid = _cem_v1_positive(duration) && _cem_v1_positive(repetition) &&
            _cem_v1_finite(active) && 0.0 < Float64(active) <= 1.0 &&
            _cem_v1_finite(availability) && 0.0 < Float64(availability) <= 1.0 &&
            abs(Float64(duration) * Float64(repetition) - Float64(active)) <=
                max(1.0e-14, 1.0e-8 * Float64(active))
        return Dict{String,Any}("mode" => "cycle_average",
            "time_semantics_version" => "2.0.0",
            "pulse_duration_s" => duration,
            "active_phase_duration_s" => duration,
            "repetition_rate_hz" => repetition,
            "shot_repetition_rate_hz" => repetition,
            "duty_factor" => active, "pulse_active_fraction" => active,
            "plant_availability_factor" => availability,
            "average_factor" => valid ? Float64(active) : nothing,
            "calendar_average_factor" => valid ?
                Float64(active) * Float64(availability) : nothing,
            "status" => valid ? "complete" :
                "unsupported_inconsistent_pulse_time_basis",
            "conversion" => "J_per_shot_times_shot_repetition_rate",
            "average_power_basis" => String(get(semantic,
                "average_power_basis", "scheduled_operating_cycle")))
    end
    contract = get(genome.normalized, "time_integration_contract_v1", nothing)
    mode = lowercase(genome.mission.operating_mode)
    if contract isa AbstractDict && String(get(contract, "mode", "")) == "pulsed"
        duration = get(contract, "pulse_duration_s", nothing)
        repetition = get(contract, "repetition_rate_hz", nothing)
        duty = get(contract, "duty_factor", nothing)
        valid = _cem_v1_positive(duration) && _cem_v1_positive(repetition) &&
            _cem_v1_finite(duty) && 0.0 < Float64(duty) <= 1.0 &&
            abs(Float64(duration) * Float64(repetition) - Float64(duty)) <=
                max(1.0e-10, 1.0e-8 * Float64(duty))
        return Dict{String,Any}("mode" => "cycle_average",
            "pulse_duration_s" => duration, "repetition_rate_hz" => repetition,
            "duty_factor" => duty, "average_factor" => valid ? Float64(duty) : nothing,
            "status" => valid ? "complete" : "unsupported_inconsistent_pulse_time_basis",
            "conversion" => "J_per_pulse_times_repetition_rate")
    elseif occursin("steady", mode)
        return Dict{String,Any}("mode" => "steady_power", "average_factor" => 1.0,
            "status" => "complete")
    end
    return Dict{String,Any}("mode" => mode, "average_factor" => nothing,
        "status" => "unsupported_missing_explicit_transient_cycle_basis")
end

function _cpsr_v1_interval(value, relative_uncertainty, coverage)
    value isa Real || return Dict{String,Any}("lower_w" => nothing, "upper_w" => nothing)
    radius = abs(Float64(value)) * Float64(relative_uncertainty) * Float64(coverage)
    return Dict{String,Any}("lower_w" => max(0.0, Float64(value) - radius),
        "upper_w" => Float64(value) + radius, "coverage_sigma" => Float64(coverage),
        "relative_one_sigma" => Float64(relative_uncertainty))
end

function _cpsr_v1_role(id, value, status, basis, source_hashes, uncertainty)
    body = Dict{String,Any}("role_id" => id, "value_w" => value,
        "status" => status, "basis" => basis,
        "source_output_hashes" => sort!(unique(filter(!isempty, String.(source_hashes)))),
        "uncertainty_interval" => uncertainty)
    body["component_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _cpsr_v1_check(id, status, required, capacity, unit, location, source_hash)
    margin = required isa Real && capacity isa Real ?
        (Float64(capacity) - Float64(required)) / max(abs(Float64(required)), 1.0) : nothing
    body = Dict{String,Any}("check_id" => id, "status" => status,
        "required" => required, "capacity" => capacity, "unit" => unit,
        "normalized_margin" => margin, "location" => location,
        "source_output_hash" => source_hash)
    body["check_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _cpsr_v1_species(genome, reasons)
    contract = get(genome.normalized, "species_state_contract_v1", nothing)
    records = contract isa AbstractDict ? get(contract, "species_records", Any[]) : Any[]
    ions = [item for item in records if get(item, "mass_amu", nothing) isa Real &&
        Int(get(item, "charge_state", 0)) > 0]
    if isempty(ions)
        push!(reasons, "plant solve requires explicit positive-ion species records")
        return (mean_mass_kg = nothing, tritium_fraction = nothing, ids = String[])
    end
    weights = Float64[max(Float64(get(item, "number_fraction_of_total_ion_density", 0.0)), 0.0)
        for item in ions]
    total = sum(weights)
    total > 0.0 || begin
        push!(reasons, "plant species fractions do not define a positive ion mixture")
        return (mean_mass_kg = nothing, tritium_fraction = nothing, ids = String[])
    end
    mean_amu = sum(weights[index] * Float64(ions[index]["mass_amu"])
        for index in eachindex(ions)) / total
    tritium = sum(weights[index] for index in eachindex(ions) if
        lowercase(String(ions[index]["species_id"])) == "tritium"; init = 0.0) / total
    return (mean_mass_kg = mean_amu * _CPSR_V1_AMU,
        tritium_fraction = tritium,
        ids = sort!(String[String(item["species_id"]) for item in ions]))
end

function _cpsr_v1_upstream_rates(regional)
    outputs = get(get(regional.gate_statuses, "actuator_realization", Dict{String,Any}()),
        "outputs", Any[])
    source = sum(Float64(get(item, "actual_output", 0.0)) for item in outputs if
        String(get(item, "capability", "")) == "particle_source"; init = 0.0)
    exhaust = sum(Float64(get(item, "actual_output", 0.0)) for item in outputs if
        String(get(item, "capability", "")) == "particle_exhaust"; init = 0.0)
    return (source = source, exhaust = exhaust,
        source_hashes = String[String(get(item, "output_hash", "")) for item in outputs if
            String(get(item, "capability", "")) in ("particle_source", "particle_exhaust")])
end

function _cpsr_v1_heat_sources(transport, load_context)
    fusion = get(transport, "fusion_power_w", nothing)
    loss = get(transport, "loss_power_w", nothing)
    if !(loss isa Real) && load_context isa AbstractDict
        loss = get(load_context, "mapped_heat_power_w", nothing)
    end
    return Dict{String,Any}("fusion_power" => fusion, "loss_power" => loss)
end

function _cpsr_v1_empty(genome, manifest, status, reasons)
    time_basis = _cpsr_v1_time_basis(genome)
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "manifest_hash" => manifest.manifest_hash, "status" => String(status),
        "time_basis" => time_basis, "exhaust_results" => Any[],
        "fuel_cycle_results" => Any[], "thermal_cycle_results" => Any[],
        "plant_roles" => Any[], "checks" => Any[],
        "unresolved_reasons" => sort!(unique(reasons)),
        "evidence_ceiling" => "no plant numerical result; declaration or upstream gate incomplete")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return PlantSubsystemResultEnvelopeV1("1.0.0", genome.design_id, genome.physics_hash,
        manifest.manifest_hash, status, time_basis, Dict{String,Any}[],
        Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
        Dict{String,Any}[], body["unresolved_reasons"], body["evidence_ceiling"], hash)
end

"Solve molecular-flow exhaust, fuel processing and heat-to-electric plant balances."
function solve_plant_subsystems_v1(genome::Genome, manifest::PlantSubsystemManifestV1,
        regional::RegionSolveResultEnvelopeV1, transport,
        engineering::EngineeringMultiphysicsResultEnvelopeV1; load_context = nothing)
    manifest.status == :pass || return _cpsr_v1_empty(genome, manifest,
        manifest.status == :unsupported ? :unsupported : :unknown,
        manifest.unresolved_reasons)
    time_basis = _cpsr_v1_time_basis(genome)
    String(time_basis["status"]) == "complete" ||
        return _cpsr_v1_empty(genome, manifest, :unsupported,
            [String(time_basis["status"])])
    regional.status == :pass || return _cpsr_v1_empty(genome, manifest, :unsupported,
        ["regional state and actuator realization did not pass"])
    reasons = String[]
    species = _cpsr_v1_species(genome, reasons)
    isempty(reasons) || return _cpsr_v1_empty(genome, manifest, :unsupported, reasons)
    rates = _cpsr_v1_upstream_rates(regional)
    heat_sources = _cpsr_v1_heat_sources(transport, load_context)
    average_factor = Float64(time_basis["average_factor"])
    coverage = Float64(manifest.uncertainty_contract["coverage_sigma"])
    exhaust_results = Dict{String,Any}[]
    fuel_results = Dict{String,Any}[]
    thermal_results = Dict{String,Any}[]
    checks = Dict{String,Any}[]
    roles = Dict{String,Any}[]
    vacuum_power = 0.0; vacuum_u2 = 0.0
    fuel_power = 0.0; fuel_u2 = 0.0
    thermal_aux = 0.0; thermal_u2 = 0.0
    gross_power = 0.0; gross_u2 = 0.0
    shielding_power = 0.0; shielding_u2 = 0.0
    controls_power = 0.0; controls_u2 = 0.0
    direct_power = 0.0; direct_u2 = 0.0
    thermal_pump_power = 0.0
    capacity_failed = false
    thermal_source_incomplete = false
    shielding_source_incomplete = false
    direct_source_incomplete = false
    for item in manifest.exhaust_networks
        fraction = Float64(item["throughput_fraction"])
        required_rate = rates.exhaust * fraction
        temperature = Float64(item["inlet_temperature_k"])
        inlet_pressure = Float64(item["inlet_pressure_pa"])
        outlet_pressure = Float64(item["outlet_pressure_pa"])
        diameter = Float64(item["duct_diameter_m"])
        length_m = Float64(item["duct_length_m"])
        area = pi * diameter^2 / 4.0
        mean_speed = sqrt(8.0 * _CPSR_V1_KB * temperature /
            (pi * Float64(species.mean_mass_kg)))
        transmission = min(1.0, 4.0 * diameter / (3.0 * length_m))
        conductance = 0.25 * area * mean_speed * transmission
        pump_speed = Float64(item["pump_speed_capacity_m3_s"])
        effective_speed = 1.0 / (1.0 / conductance + 1.0 / pump_speed)
        capacity_rate = effective_speed * inlet_pressure / (_CPSR_V1_KB * temperature)
        actual_rate = min(required_rate, capacity_rate)
        efficiency = Float64(item["isothermal_efficiency"])
        peak_power = actual_rate * _CPSR_V1_KB * temperature *
            log(outlet_pressure / inlet_pressure) / efficiency
        wall_power = peak_power * Float64(item["operating_duty_factor"])
        status = capacity_rate + max(required_rate, 1.0) * 1.0e-12 >= required_rate ? "pass" : "fail"
        status == "fail" && (capacity_failed = true)
        result = Dict{String,Any}("network_id" => item["network_id"],
            "required_particle_rate_per_s" => required_rate,
            "actual_particle_rate_per_s" => actual_rate,
            "mean_species_mass_kg" => species.mean_mass_kg,
            "molecular_mean_speed_m_s" => mean_speed,
            "duct_conductance_m3_s" => conductance,
            "effective_pumping_speed_m3_s" => effective_speed,
            "throughput_capacity_per_s" => capacity_rate,
            "compression_ratio" => outlet_pressure / inlet_pressure,
            "peak_pump_power_w" => peak_power, "cycle_average_pump_power_w" => wall_power,
            "status" => status, "source_output_hashes" => rates.source_hashes)
        result["result_hash"] = canonical_hash(_csr_v1_json_safe(result))
        push!(exhaust_results, result)
        push!(checks, _cpsr_v1_check("exhaust_capacity_$(item["network_id"])", status,
            required_rate, capacity_rate, "1/s", String(item["network_id"]), result["result_hash"]))
        uncertainty = Float64(item["relative_uncertainty"])
        vacuum_power += wall_power; vacuum_u2 += (wall_power * uncertainty)^2
    end
    for item in manifest.fuel_cycle_systems
        fraction = Float64(item["throughput_fraction"])
        peak_rate = max(rates.source, rates.exhaust) * fraction
        average_rate = peak_rate * average_factor
        basis_rate = String(item["capacity_basis"]) == "peak_rate" ? peak_rate : average_rate
        capacity = Float64(item["processing_capacity_per_s"])
        actual_rate = min(basis_rate, capacity)
        processing_power = average_rate * Float64(item["processing_energy_j_per_particle"]) /
            Float64(item["processing_efficiency"])
        inventory = average_rate * Float64(item["residence_time_s"]) *
            Float64(species.mean_mass_kg)
        retained = inventory * Float64(item["retention_fraction"])
        inventory_limit = Float64(item["inventory_limit_kg"])
        capacity_status = capacity + max(basis_rate, 1.0) * 1.0e-12 >= basis_rate ? "pass" : "fail"
        inventory_status = inventory <= inventory_limit ? "pass" : "fail"
        (capacity_status == "fail" || inventory_status == "fail") && (capacity_failed = true)
        result = Dict{String,Any}("system_id" => item["system_id"],
            "peak_particle_rate_per_s" => peak_rate,
            "cycle_average_particle_rate_per_s" => average_rate,
            "capacity_basis_rate_per_s" => basis_rate,
            "processing_capacity_per_s" => capacity,
            "actual_processed_rate_per_s" => actual_rate,
            "processing_power_w" => processing_power,
            "total_inventory_kg" => inventory, "retained_inventory_kg" => retained,
            "tritium_inventory_kg" => inventory * Float64(species.tritium_fraction),
            "inventory_limit_kg" => inventory_limit,
            "status" => capacity_status == "pass" && inventory_status == "pass" ? "pass" : "fail",
            "source_output_hashes" => rates.source_hashes)
        result["result_hash"] = canonical_hash(_csr_v1_json_safe(result))
        push!(fuel_results, result)
        push!(checks, _cpsr_v1_check("fuel_processing_capacity_$(item["system_id"])",
            capacity_status, basis_rate, capacity, "1/s", String(item["system_id"]), result["result_hash"]))
        push!(checks, _cpsr_v1_check("fuel_inventory_$(item["system_id"])",
            inventory_status, inventory, inventory_limit, "kg", String(item["system_id"]), result["result_hash"]))
        uncertainty = Float64(item["relative_uncertainty"])
        fuel_power += processing_power; fuel_u2 += (processing_power * uncertainty)^2
    end
    for item in manifest.thermal_cycles
        source_role = String(item["source_heat_role"])
        source_peak = get(heat_sources, source_role, nothing)
        if !(source_peak isa Real && isfinite(Float64(source_peak)) && source_peak >= 0.0)
            push!(reasons, "thermal cycle $(item["cycle_id"]) lacks solved $source_role")
            thermal_source_incomplete = true
            continue
        end
        source_average = Float64(source_peak) * average_factor
        captured = source_average * Float64(item["source_fraction"]) *
            Float64(item["heat_exchanger_effectiveness"])
        mass_flow = Float64(item["coolant_mass_flow_kg_s"])
        cp = Float64(item["coolant_specific_heat_j_kg_k"])
        inlet = Float64(item["coolant_inlet_temperature_k"])
        hot = inlet + captured / (mass_flow * cp)
        sink = Float64(item["sink_temperature_k"])
        cycle_efficiency = hot > sink ? Float64(item["second_law_efficiency"]) *
            (1.0 - sink / hot) : 0.0
        gross = captured * cycle_efficiency
        volumetric_flow = mass_flow / Float64(item["coolant_density_kg_m3"])
        pump = Float64(item["coolant_pressure_drop_pa"]) * volumetric_flow /
            Float64(item["circulation_pump_efficiency"]) *
            Float64(item["circulation_duty_factor"])
        generator_aux = gross * Float64(item["generator_auxiliary_fraction"])
        auxiliary = pump + generator_aux
        result = Dict{String,Any}("cycle_id" => item["cycle_id"],
            "source_heat_role" => source_role, "source_peak_power_w" => source_peak,
            "energy_per_pulse_j" => time_basis["mode"] == "cycle_average" ?
                Float64(source_peak) * Float64(time_basis["pulse_duration_s"]) : nothing,
            "cycle_average_source_power_w" => source_average,
            "captured_heat_power_w" => captured, "coolant_outlet_temperature_k" => hot,
            "sink_temperature_k" => sink, "cycle_efficiency" => cycle_efficiency,
            "gross_electric_power_w" => gross, "circulation_pump_power_w" => pump,
            "generator_auxiliary_power_w" => generator_aux,
            "thermal_conversion_auxiliary_power_w" => auxiliary,
            "rejected_heat_power_w" => captured - gross,
            "status" => hot > sink ? "pass" : "fail_temperature_lift")
        result["result_hash"] = canonical_hash(_csr_v1_json_safe(result))
        push!(thermal_results, result)
        hot <= sink && (capacity_failed = true)
        uncertainty = Float64(item["relative_uncertainty"])
        gross_power += gross; gross_u2 += (gross * uncertainty)^2
        thermal_aux += auxiliary; thermal_u2 += (auxiliary * uncertainty)^2
        thermal_pump_power += pump
    end
    for item in manifest.shielding_cooling_systems
        source = get(heat_sources, String(item["source_heat_role"]), nothing)
        if !(source isa Real && source >= 0.0)
            push!(reasons, "shielding cooling $(item["system_id"]) lacks solved heat source")
            shielding_source_incomplete = true
            continue
        end
        heat = Float64(source) * average_factor * Float64(item["source_fraction"])
        cold = Float64(item["cold_temperature_k"])
        ambient = Float64(item["ambient_temperature_k"])
        wall = heat * max(ambient / cold - 1.0, 0.0) /
            Float64(item["second_law_efficiency"])
        shielding_power += wall
        shielding_u2 += (wall * Float64(item["relative_uncertainty"]))^2
    end
    for item in manifest.auxiliary_loads
        value = Float64(item["rated_power_w"]) * Float64(item["duty_factor"]) /
            Float64(item["supply_efficiency"])
        controls_power += value
        controls_u2 += (value * Float64(item["relative_uncertainty"]))^2
    end
    for item in manifest.direct_recovery_systems
        source = get(heat_sources, String(item["source_heat_role"]), nothing)
        if !(source isa Real && source >= 0.0)
            push!(reasons, "direct recovery $(item["system_id"]) lacks solved source")
            direct_source_incomplete = true
            continue
        end
        available = Float64(source) * average_factor * Float64(item["source_fraction"])
        recovered = min(available * Float64(item["conversion_efficiency"]),
            Float64(item["capacity_w"]))
        direct_power += recovered
        direct_u2 += (recovered * Float64(item["relative_uncertainty"]))^2
    end
    source_hashes = vcat(rates.source_hashes,
        [String(get(transport, "solver_output_hash", "")), engineering.result_hash])
    function add_role!(id, value, u2, basis; incomplete = false)
        applicability = _cem_v1_dict(manifest.role_applicability[id])
        if String(applicability["status"]) == "not_applicable"
            push!(roles, _cpsr_v1_role(id, nothing, "not_applicable",
                String(applicability["basis"]), source_hashes,
                Dict("lower_w" => nothing, "upper_w" => nothing)))
        elseif incomplete
            push!(roles, _cpsr_v1_role(id, nothing, "unknown",
                "applicable role lacks a solved upstream source", source_hashes,
                Dict("lower_w" => nothing, "upper_w" => nothing)))
        else
            uncertainty = value > 0.0 ? sqrt(max(u2, 0.0)) / value : 0.0
            push!(roles, _cpsr_v1_role(id, value, "complete", basis, source_hashes,
                _cpsr_v1_interval(value, uncertainty, coverage)))
        end
    end
    add_role!("particle_injection_fuel_processing", fuel_power, fuel_u2,
        "solved species throughput, processing energy and inventory")
    add_role!("vacuum_exhaust_pumping", vacuum_power, vacuum_u2,
        "molecular duct conductance, pump speed and isothermal compression")
    existing_coolant = sum(Float64(get(item, "value_w", 0.0)) for item in
        engineering.plant_power_roles if item["role_id"] ==
        "coolant_circulation_heat_rejection" && item["status"] == "complete"; init = 0.0)
    add_role!("coolant_circulation_heat_rejection", existing_coolant + thermal_pump_power,
        thermal_u2, "v63 magnet cooling plus solved v64 heat-cycle circulation";
        incomplete = thermal_source_incomplete)
    add_role!("thermal_conversion_auxiliaries", thermal_aux, thermal_u2,
        "solved circulation work and generator auxiliary load";
        incomplete = thermal_source_incomplete)
    add_role!("shielding_cooling", shielding_power, shielding_u2,
        "solved shield heat fraction and temperature-level refrigeration";
        incomplete = shielding_source_incomplete)
    add_role!("controls_diagnostics_auxiliaries", controls_power, controls_u2,
        "declared equipment loads, duty and supply efficiency")
    add_role!("direct_energy_recovery", direct_power, direct_u2,
        "solved source availability, conversion efficiency and capacity";
        incomplete = direct_source_incomplete)
    add_role!("gross_electric_generation", gross_power, gross_u2,
        "captured boundary heat, coolant temperature and second-law cycle efficiency";
        incomplete = thermal_source_incomplete)
    numeric_complete = isempty(reasons) && all(role -> String(role["status"]) in
        ("complete", "not_applicable"), roles)
    status = !numeric_complete ? :unknown : capacity_failed ? :fail : :pass
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "manifest_hash" => manifest.manifest_hash, "status" => String(status),
        "time_basis" => time_basis, "exhaust_results" => exhaust_results,
        "fuel_cycle_results" => fuel_results, "thermal_cycle_results" => thermal_results,
        "plant_roles" => roles, "checks" => checks,
        "unresolved_reasons" => sort!(unique(reasons)),
        "evidence_ceiling" => "candidate-bound L1 molecular-flow, inventory and heat-cycle plant solution")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return PlantSubsystemResultEnvelopeV1("1.0.0", genome.design_id,
        genome.physics_hash, manifest.manifest_hash, status, time_basis,
        exhaust_results, fuel_results, thermal_results, roles, checks,
        body["unresolved_reasons"], body["evidence_ceiling"], hash)
end

function plant_subsystem_result_to_dict_v1(value::PlantSubsystemResultEnvelopeV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "manifest_hash" => value.manifest_hash, "status" => String(value.status),
        "time_basis" => value.time_basis, "exhaust_results" => value.exhaust_results,
        "fuel_cycle_results" => value.fuel_cycle_results,
        "thermal_cycle_results" => value.thermal_cycle_results,
        "plant_roles" => value.plant_roles, "checks" => value.checks,
        "unresolved_reasons" => value.unresolved_reasons,
        "evidence_ceiling" => value.evidence_ceiling, "result_hash" => value.result_hash)
end
