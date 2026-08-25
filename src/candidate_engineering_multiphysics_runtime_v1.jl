const _CEMR_V1_MU0 = 4.0e-7 * pi

"Bind the engineering slice to the solved regional state, L1 field inventory and transport heat."
function engineering_load_context_v1(manifest::CandidateSolveManifestV1,
        regional::RegionSolveResultEnvelopeV1, transport)
    peak_field = get(manifest.parameters, "peak_declared_field_t", nothing)
    peak_field isa Real || (peak_field = get(manifest.parameters, "magnetic_field_t", nothing))
    transport_hash = String(get(transport, "solver_output_hash", ""))
    heat = get(transport, "loss_power_w", nothing)
    heat_basis = "stage5_transport_loss_power"
    if !(heat isa Real && isfinite(Float64(heat)) && Float64(heat) >= 0.0)
        outputs = get(get(regional.gate_statuses, "actuator_realization", Dict{String,Any}()),
            "outputs", Any[])
        realized_sinks = Float64[Float64(item["actual_output"]) for item in outputs if
            String(get(item, "capability", "")) == "radiation_control" &&
            get(item, "actual_output", nothing) isa Real]
        if !isempty(realized_sinks)
            heat = sum(realized_sinks)
            heat_basis = "stage3_realized_regional_energy_sink"
        end
    end
    reasons = String[]
    regional.status == :pass || push!(reasons, "regional state solution did not pass")
    _cem_v1_positive(peak_field) || push!(reasons, "manifest lacks a positive candidate-bound magnetic field")
    _cem_v1_hash(transport_hash) || push!(reasons, "transport result hash is missing")
    _cem_v1_finite(heat) && Float64(heat) >= 0.0 ||
        push!(reasons, "transport result lacks a finite nonnegative loss power")
    field_body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "state_result_hash" => regional.result_hash,
        "operator_id" => "fixed_candidate_field_inventory_l1_v1",
        "peak_field_t" => peak_field isa Real ? Float64(peak_field) : nothing,
        "status" => isempty(reasons) ? "complete" : "unsupported",
        "evidence_ceiling" => "candidate-declared field bound to converged regional state; no local 3-D conductor field")
    field_hash = canonical_hash(_csr_v1_json_safe(field_body))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "state_result_hash" => regional.result_hash,
        "field_solution_hash" => field_hash, "transport_result_hash" => transport_hash,
        "peak_field_t" => peak_field isa Real ? Float64(peak_field) : nothing,
        "mapped_heat_power_w" => heat isa Real ? Float64(heat) : nothing,
        "mapped_heat_basis" => heat_basis,
        "status" => isempty(reasons) ? "complete" : "unsupported",
        "unresolved_reasons" => sort!(unique(reasons)),
        "field_solution" => field_body,
        "evidence_ceiling" => "L1 state-bound magnetic inventory and Stage 5 loss heat")
    body["result_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

"Hash-sealed finite-component electromagnetic, structural, thermal and quench result."
struct EngineeringMultiphysicsResultEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    state_result_hash::Union{Nothing,String}
    field_solution_hash::Union{Nothing,String}
    transport_result_hash::Union{Nothing,String}
    engineering_manifest_hash::String
    material_manifest_hash::String
    fault_manifest_hash::String
    status::Symbol
    convergence_status::String
    component_outputs::Vector{Dict{String,Any}}
    engineering_checks::Vector{Dict{String,Any}}
    plant_power_roles::Vector{Dict{String,Any}}
    residuals::Vector{Dict{String,Any}}
    unresolved_reasons::Vector{String}
    evidence_ceiling::String
    result_hash::String
end

function _cemr_v1_features(component)
    result = Dict{String,Dict{String,Any}}()
    for raw in get(component, "features", Any[])
        raw isa AbstractDict || continue
        feature = _cem_v1_dict(raw)
        kind = String(get(feature, "kind", ""))
        isempty(kind) || (result[kind] = feature)
    end
    return result
end

function _cemr_v1_property(material, property_id, reasons, context)
    matches = [item for item in get(material, "properties", Any[]) if
        String(get(item, "property_id", "")) == property_id]
    if length(matches) != 1
        push!(reasons, "$context requires exactly one $property_id property curve")
        return nothing
    end
    property = matches[1]
    curve = get(property, "curve_data", Dict{String,Any}())
    value = get(curve, "reference_value", nothing)
    if !_cem_v1_finite(value)
        push!(reasons, "$context $property_id lacks a finite curve_data.reference_value")
        return nothing
    end
    uncertainty = get(property, "uncertainty", Dict{String,Any}())
    uvalue = get(uncertainty, "value", nothing)
    _cem_v1_finite(uvalue) || begin
        push!(reasons, "$context $property_id lacks finite uncertainty")
        return nothing
    end
    return Dict{String,Any}("value" => Float64(value),
        "unit" => String(get(property, "unit", "")),
        "uncertainty_kind" => String(get(uncertainty, "kind", "unknown")),
        "uncertainty_value" => Float64(uvalue),
        "property_data_hash" => String(get(property, "data_hash", "")),
        "material_version" => String(get(material, "version", "")))
end

function _cemr_v1_number(feature, key, reasons, context; positive = true, nonnegative = false)
    value = get(feature, key, nothing)
    valid = _cem_v1_finite(value) && (!positive || Float64(value) > 0.0) &&
        (!nonnegative || Float64(value) >= 0.0)
    if !valid
        qualifier = positive ? "positive" : nonnegative ? "nonnegative" : "finite"
        push!(reasons, "$context requires $qualifier $key")
        return nothing
    end
    return Float64(value)
end

function _cemr_v1_check(id, value, allowable, unit, sense, component_id, material_version,
        fault_case, source_hashes)
    margin = if value isa Real && allowable isa Real
        sense == "upper" ? (Float64(allowable) - Float64(value)) /
            max(abs(Float64(allowable)), eps()) :
            (Float64(value) - Float64(allowable)) / max(abs(Float64(allowable)), eps())
    else
        nothing
    end
    status = margin isa Real ? (margin >= 0.0 ? "pass" : "fail") : "unknown"
    body = Dict{String,Any}("check_id" => id, "status" => status,
        "computed_extremum" => value, "allowable" => allowable,
        "unit" => unit, "sense" => sense, "normalized_margin" => margin,
        "location" => component_id, "material_version" => material_version,
        "fault_case" => fault_case, "source_output_hashes" => source_hashes)
    body["check_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _cemr_v1_role(id, value, status, basis, source_hashes; uncertainty = nothing)
    body = Dict{String,Any}("role_id" => id, "value_w" => value,
        "status" => status, "basis" => basis,
        "source_output_hashes" => source_hashes, "uncertainty" => uncertainty,
        "time_basis" => "instantaneous_or_declared_cycle_average")
    body["component_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _cemr_v1_empty_result(genome, bundle, status, reasons)
    geometry = bundle["geometry"]
    materials = bundle["materials"]
    faults = bundle["faults"]
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "state_result_hash" => nothing, "field_solution_hash" => nothing,
        "transport_result_hash" => nothing,
        "engineering_manifest_hash" => geometry.manifest_hash,
        "material_manifest_hash" => materials.manifest_hash,
        "fault_manifest_hash" => faults.manifest_hash, "status" => String(status),
        "convergence_status" => "not_executed_manifest_gate",
        "component_outputs" => Any[], "engineering_checks" => Any[],
        "plant_power_roles" => Any[], "residuals" => Any[],
        "unresolved_reasons" => sort!(unique(String.(reasons))),
        "evidence_ceiling" => "no numerical engineering result; explicit declarations incomplete")
    hash = canonical_hash(body)
    return EngineeringMultiphysicsResultEnvelopeV1("1.0.0", genome.design_id,
        genome.physics_hash, nothing, nothing, nothing,
        geometry.manifest_hash, materials.manifest_hash,
        faults.manifest_hash, status, body["convergence_status"],
        Dict{String,Any}[], Dict{String,Any}[], Dict{String,Any}[],
        Dict{String,Any}[], body["unresolved_reasons"], body["evidence_ceiling"], hash)
end

function _cemr_v1_not_applicable_result(genome, bundle;
        basis_override = nothing)
    geometry = bundle["geometry"]
    materials = bundle["materials"]
    faults = bundle["faults"]
    basis = basis_override === nothing ? geometry.applicability_basis : String(basis_override)
    roles = Dict{String,Any}[
        _cemr_v1_role("magnet_power_and_pulse_storage", nothing, "not_applicable", basis, String[]),
        _cemr_v1_role("cryogenic_system", nothing, "not_applicable", basis, String[]),
        _cemr_v1_role("coolant_circulation_heat_rejection", nothing, "not_applicable", basis, String[])]
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "state_result_hash" => nothing, "field_solution_hash" => nothing,
        "transport_result_hash" => nothing,
        "engineering_manifest_hash" => geometry.manifest_hash,
        "material_manifest_hash" => materials.manifest_hash,
        "fault_manifest_hash" => faults.manifest_hash, "status" => "pass",
        "convergence_status" => "not_applicable_no_finite_conductor_capability",
        "component_outputs" => Any[], "engineering_checks" => Any[],
        "plant_power_roles" => roles, "residuals" => Any[], "unresolved_reasons" => Any[],
        "evidence_ceiling" => "finite-conductor slice explicitly not applicable: $basis")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return EngineeringMultiphysicsResultEnvelopeV1("1.0.0", genome.design_id,
        genome.physics_hash, nothing, nothing, nothing,
        geometry.manifest_hash, materials.manifest_hash,
        faults.manifest_hash, :pass, body["convergence_status"], Dict{String,Any}[],
        Dict{String,Any}[], roles, Dict{String,Any}[], String[], body["evidence_ceiling"], hash)
end

"""
Solve the first finite-component v63 vertical slice.

Every number is taken from a candidate declaration or a versioned material curve. The runtime
does not infer a conductor size, coolant path, protection circuit, allowable or plant efficiency.
The current implementation is a conservative L1 lumped finite-component/network solve; it is not
a substitute for a 3-D finite-element qualification calculation.
"""
function solve_magnet_structural_thermal_quench_v1(genome::Genome,
        bundle = compile_candidate_engineering_manifests_v1(genome); load_context = nothing)
    bundle_status = bundle["status"]
    bundle_status == :pass || return _cemr_v1_empty_result(genome, bundle,
        bundle_status == :unsupported ? :unsupported : :unknown,
        bundle["unresolved_reasons"])
    geometry = bundle["geometry"]
    materials = bundle["materials"]
    faults = bundle["faults"]
    isempty(geometry.applicable_component_roles) && !isempty(geometry.applicability_basis) &&
        return _cemr_v1_not_applicable_result(genome, bundle)
    any(component -> String(get(component, "component_role", "")) == "winding_pack",
        geometry.components) || return _cemr_v1_not_applicable_result(genome, bundle;
            basis_override = "candidate declares no winding_pack; nonmagnetic plant components are solved by their capability modules")
    if !(load_context isa AbstractDict)
        return _cemr_v1_empty_result(genome, bundle, :unsupported,
            ["missing upstream candidate-bound magnetic and thermal load context"])
    end
    loads = _cem_v1_dict(load_context)
    required_loads = ("state_result_hash", "field_solution_hash",
        "transport_result_hash", "peak_field_t", "mapped_heat_power_w")
    load_reasons = String[]
    for id in required_loads
        haskey(loads, id) || push!(load_reasons, "upstream load context missing $id")
    end
    _cem_v1_hash(get(loads, "state_result_hash", nothing)) ||
        push!(load_reasons, "upstream state_result_hash must be a sha256 hash")
    _cem_v1_hash(get(loads, "field_solution_hash", nothing)) ||
        push!(load_reasons, "upstream field_solution_hash must be a sha256 hash")
    _cem_v1_hash(get(loads, "transport_result_hash", nothing)) ||
        push!(load_reasons, "upstream transport_result_hash must be a sha256 hash")
    _cem_v1_positive(get(loads, "peak_field_t", nothing)) ||
        push!(load_reasons, "upstream peak_field_t must be positive")
    _cem_v1_finite(get(loads, "mapped_heat_power_w", nothing)) &&
        Float64(loads["mapped_heat_power_w"]) >= 0.0 ||
        push!(load_reasons, "upstream mapped_heat_power_w must be finite and nonnegative")
    isempty(load_reasons) || return _cemr_v1_empty_result(genome, bundle, :unsupported,
        load_reasons)
    material_index = Dict(String(item["material_id"]) => item for item in materials.materials)
    scenarios_by_component = Dict{String,Vector{Dict{String,Any}}}()
    for scenario in faults.scenarios, target in scenario["target_component_ids"]
        push!(get!(scenarios_by_component, String(target), Dict{String,Any}[]), scenario)
    end
    reasons = String[]
    outputs = Dict{String,Any}[]
    checks = Dict{String,Any}[]
    residuals = Dict{String,Any}[]
    total_magnet_power = 0.0
    total_cryo_power = 0.0
    total_pump_power = 0.0
    total_stored_energy = 0.0
    for component in geometry.components
        String(component["component_role"]) == "winding_pack" || continue
        component_id = String(component["component_id"])
        context = "component $component_id"
        local_reasons = String[]
        features = _cemr_v1_features(component)
        required_features = ("conductor_paths", "support_domain", "coolant_channel",
            "cryogenic_stage", "quench_protection")
        for id in required_features
            haskey(features, id) || push!(local_reasons, "$context missing $id feature")
        end
        material = material_index[String(component["material_id"])]
        property_ids = ("electrical_resistivity", "thermal_conductivity", "specific_heat",
            "density", "yield_strength", "fatigue_strength", "critical_current_density",
            "critical_temperature", "critical_field")
        properties = Dict{String,Any}()
        for id in property_ids
            value = _cemr_v1_property(material, id, local_reasons, context)
            value === nothing || (properties[id] = value)
        end
        if !isempty(local_reasons)
            append!(reasons, local_reasons)
            continue
        end
        conductor = features["conductor_paths"]
        support = features["support_domain"]
        coolant = features["coolant_channel"]
        cryo = features["cryogenic_stage"]
        protection = features["quench_protection"]
        current = _cemr_v1_number(conductor, "current_a", local_reasons, context)
        length_m = _cemr_v1_number(conductor, "total_length_m", local_reasons, context)
        area = _cemr_v1_number(conductor, "conductor_area_m2", local_reasons, context)
        volume = _cemr_v1_number(conductor, "conductor_volume_m3", local_reasons, context)
        field_volume = _cemr_v1_number(conductor, "field_volume_m3", local_reasons, context)
        peak_field = Float64(loads["peak_field_t"])
        operating_temperature = _cemr_v1_number(conductor, "operating_temperature_k", local_reasons, context)
        frequency = _cemr_v1_number(conductor, "excitation_frequency_hz", local_reasons,
            context; positive = false, nonnegative = true)
        ac_coefficient = _cemr_v1_number(conductor, "ac_loss_coefficient_w_per_a2_hz_m",
            local_reasons, context; positive = false, nonnegative = true)
        support_area = _cemr_v1_number(support, "load_bearing_area_m2", local_reasons, context)
        support_length = _cemr_v1_number(support, "load_path_length_m", local_reasons, context)
        diameter = _cemr_v1_number(coolant, "hydraulic_diameter_m", local_reasons, context)
        channel_length = _cemr_v1_number(coolant, "total_length_m", local_reasons, context)
        flow_area = _cemr_v1_number(coolant, "flow_area_m2", local_reasons, context)
        wetted_area = _cemr_v1_number(coolant, "wetted_area_m2", local_reasons, context)
        critical_heat_flux = _cemr_v1_number(coolant, "critical_heat_flux_w_m2", local_reasons, context)
        mass_flow = _cemr_v1_number(coolant, "mass_flow_kg_s", local_reasons, context)
        coolant_density = _cemr_v1_number(coolant, "density_kg_m3", local_reasons, context)
        coolant_cp = _cemr_v1_number(coolant, "specific_heat_j_kg_k", local_reasons, context)
        inlet_temperature = _cemr_v1_number(coolant, "inlet_temperature_k", local_reasons, context)
        friction = _cemr_v1_number(coolant, "darcy_friction_factor", local_reasons, context)
        pump_efficiency = _cemr_v1_number(coolant, "pump_efficiency", local_reasons, context)
        heat_fraction = _cemr_v1_number(coolant, "mapped_heat_fraction", local_reasons,
            context; positive = false, nonnegative = true)
        ambient_temperature = _cemr_v1_number(cryo, "ambient_temperature_k", local_reasons, context)
        cryo_efficiency = _cemr_v1_number(cryo, "second_law_efficiency", local_reasons, context)
        dump_resistance = _cemr_v1_number(protection, "dump_resistance_ohm", local_reasons, context)
        detection_time = _cemr_v1_number(protection, "detection_time_s", local_reasons,
            context; positive = false, nonnegative = true)
        deposited_fraction = _cemr_v1_number(protection, "conductor_deposited_energy_fraction",
            local_reasons, context; positive = false, nonnegative = true)
        if !isempty(local_reasons)
            append!(reasons, local_reasons)
            continue
        end
        0.0 < pump_efficiency <= 1.0 || push!(reasons, "$context pump_efficiency is outside (0,1]")
        0.0 < cryo_efficiency <= 1.0 || push!(reasons, "$context second_law_efficiency is outside (0,1]")
        0.0 <= deposited_fraction <= 1.0 || push!(reasons,
            "$context conductor_deposited_energy_fraction is outside [0,1]")
        0.0 <= heat_fraction <= 1.0 || push!(reasons,
            "$context mapped_heat_fraction is outside [0,1]")
        isempty(reasons) || continue
        resistivity = Float64(properties["electrical_resistivity"]["value"])
        thermal_conductivity = Float64(properties["thermal_conductivity"]["value"])
        specific_heat = Float64(properties["specific_heat"]["value"])
        density = Float64(properties["density"]["value"])
        yield_strength = Float64(properties["yield_strength"]["value"])
        fatigue_strength = Float64(properties["fatigue_strength"]["value"])
        critical_j = Float64(properties["critical_current_density"]["value"])
        critical_temperature = Float64(properties["critical_temperature"]["value"])
        critical_field = Float64(properties["critical_field"]["value"])
        resistance = resistivity * length_m / area
        resistive_loss = current^2 * resistance
        ac_loss = ac_coefficient * current^2 * frequency * length_m
        magnet_loss = resistive_loss + ac_loss
        current_density = current / area
        stored_energy = peak_field^2 * field_volume / (2.0 * _CEMR_V1_MU0)
        lorentz_force = current * length_m * peak_field
        structural_stress = lorentz_force * max(support_length / max(length_m, eps()), 1.0) /
            support_area
        force_amplification = max(support_length / max(length_m, eps()), 1.0)
        allowable_force = min(yield_strength, fatigue_strength) * support_area / force_amplification
        mapped_heat = Float64(loads["mapped_heat_power_w"]) * heat_fraction
        cold_heat = magnet_loss + mapped_heat
        local_heat_flux = cold_heat / wetted_area
        velocity = mass_flow / (coolant_density * flow_area)
        pressure_drop = friction * channel_length / diameter * 0.5 * coolant_density * velocity^2
        volumetric_flow = mass_flow / coolant_density
        pump_power = pressure_drop * volumetric_flow / pump_efficiency
        outlet_temperature = inlet_temperature + cold_heat / (mass_flow * coolant_cp)
        conduction_delta = cold_heat * support_length / (thermal_conductivity * support_area)
        peak_temperature = outlet_temperature + conduction_delta
        carnot_work = cold_heat * max(ambient_temperature / operating_temperature - 1.0, 0.0)
        cryogenic_power = carnot_work / cryo_efficiency
        inductance = 2.0 * stored_energy / current^2
        time_constant = inductance / dump_resistance
        peak_voltage = current * dump_resistance
        conductor_mass = density * volume
        quench_energy = deposited_fraction * stored_energy + resistive_loss * detection_time
        hotspot_temperature = operating_temperature + quench_energy / (conductor_mass * specific_heat)
        material_version = String(material["version"])
        source_hashes = [geometry.manifest_hash, materials.manifest_hash, faults.manifest_hash,
            String(loads["field_solution_hash"]), String(loads["transport_result_hash"])]
        local_checks = Dict{String,Any}[
            _cemr_v1_check("engineering_current_density", current_density, critical_j,
                "A/m^2", "upper", component_id, material_version, "nominal", source_hashes),
            _cemr_v1_check("peak_internal_conductor_field", peak_field, critical_field,
                "T", "upper", component_id, material_version, "nominal", source_hashes),
            _cemr_v1_check("maximum_lorentz_force", lorentz_force, allowable_force,
                "N", "upper", component_id, material_version, "nominal_and_fault", source_hashes),
            _cemr_v1_check("maximum_structural_stress", structural_stress,
                min(yield_strength, fatigue_strength), "Pa", "upper", component_id,
                material_version, "nominal_and_cyclic", source_hashes),
            _cemr_v1_check("maximum_material_temperature", peak_temperature,
                critical_temperature, "K", "upper", component_id, material_version,
                "nominal", source_hashes),
            _cemr_v1_check("maximum_local_heat_flux", local_heat_flux,
                critical_heat_flux, "W/m^2", "upper", component_id, material_version,
                "nominal", source_hashes),
            _cemr_v1_check("quench_hotspot_temperature", hotspot_temperature,
                critical_temperature, "K", "upper", component_id, material_version,
                "quench", source_hashes)]
        scenarios = get(scenarios_by_component, component_id, Dict{String,Any}[])
        voltage_metrics = Dict{String,Any}[]
        for scenario in scenarios, metric in scenario["acceptance_metrics"]
            String(metric["observable_id"]) == "terminal_voltage" &&
                push!(voltage_metrics, metric)
        end
        if isempty(voltage_metrics)
            push!(reasons, "$context has no terminal_voltage fault acceptance metric")
        else
            metric = first(voltage_metrics)
            push!(local_checks, _cemr_v1_check("maximum_quench_voltage", peak_voltage,
                Float64(metric["threshold"]), String(metric["unit"]), "upper", component_id,
                material_version, "quench", source_hashes))
        end
        append!(checks, local_checks)
        electromagnetic_residual = abs(stored_energy - 0.5 * inductance * current^2)
        thermal_residual = abs(cold_heat - mass_flow * coolant_cp *
            (outlet_temperature - inlet_temperature))
        hydraulic_residual = abs(pump_power * pump_efficiency - pressure_drop * volumetric_flow)
        push!(residuals, Dict("component_id" => component_id,
            "electromagnetic_energy_residual_j" => electromagnetic_residual,
            "thermal_balance_residual_w" => thermal_residual,
            "hydraulic_power_residual_w" => hydraulic_residual))
        output = Dict{String,Any}(
            "component_id" => component_id, "material_id" => material["material_id"],
            "material_version" => material_version,
            "local_current_density_a_m2" => current_density,
            "peak_internal_field_t" => peak_field, "stored_magnetic_energy_j" => stored_energy,
            "equivalent_inductance_h" => inductance, "electrical_resistance_ohm" => resistance,
            "resistive_loss_w" => resistive_loss, "ac_loss_w" => ac_loss,
            "maximum_lorentz_force_n" => lorentz_force,
            "maximum_structural_stress_pa" => structural_stress,
            "cold_mass_heat_load_w" => cold_heat, "peak_temperature_k" => peak_temperature,
            "mapped_upstream_heat_w" => mapped_heat,
            "maximum_local_heat_flux_w_m2" => local_heat_flux,
            "critical_heat_flux_w_m2" => critical_heat_flux,
            "coolant_mass_flow_kg_s" => mass_flow, "coolant_pressure_drop_pa" => pressure_drop,
            "coolant_pump_power_w" => pump_power, "coolant_outlet_temperature_k" => outlet_temperature,
            "cryogenic_input_power_w" => cryogenic_power,
            "quench_time_constant_s" => time_constant, "quench_peak_voltage_v" => peak_voltage,
            "quench_conductor_energy_j" => quench_energy,
            "quench_hotspot_temperature_k" => hotspot_temperature,
            "source_manifest_hashes" => source_hashes)
        output["component_output_hash"] = canonical_hash(_csr_v1_json_safe(output))
        push!(outputs, output)
        total_magnet_power += magnet_loss
        total_cryo_power += cryogenic_power
        total_pump_power += pump_power
        total_stored_energy += stored_energy
    end
    isempty(outputs) && isempty(reasons) && push!(reasons,
        "no declared winding_pack component selected the v63 finite conductor solver")
    any_failed = any(item -> item["status"] == "fail", checks)
    max_residual = maximum((maximum(abs.([Float64(item[key]) for key in
        ("electromagnetic_energy_residual_j", "thermal_balance_residual_w",
         "hydraulic_power_residual_w")]); init = 0.0) for item in residuals); init = 0.0)
    numerical_complete = isempty(reasons) && !isempty(outputs) && isfinite(max_residual)
    status = !numerical_complete ? :unsupported : any_failed ? :fail : :pass
    source_hashes = [String(item["component_output_hash"]) for item in outputs]
    role_status = numerical_complete ? "complete" : "unsupported"
    roles = Dict{String,Any}[
        _cemr_v1_role("magnet_power_and_pulse_storage", numerical_complete ? total_magnet_power : nothing,
            role_status, "finite conductor resistive and declared AC loss solve", source_hashes;
            uncertainty = Dict("stored_energy_j" => total_stored_energy)),
        _cemr_v1_role("cryogenic_system", numerical_complete ? total_cryo_power : nothing,
            role_status, "cold heat load and declared second-law efficiency", source_hashes),
        _cemr_v1_role("coolant_circulation_heat_rejection", numerical_complete ? total_pump_power : nothing,
            role_status, "Darcy-Weisbach channel pressure drop and declared pump efficiency", source_hashes)]
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => genome.design_id, "physics_hash" => genome.physics_hash,
        "state_result_hash" => String(loads["state_result_hash"]),
        "engineering_manifest_hash" => geometry.manifest_hash,
        "material_manifest_hash" => materials.manifest_hash,
        "fault_manifest_hash" => faults.manifest_hash, "status" => String(status),
        "field_solution_hash" => String(loads["field_solution_hash"]),
        "transport_result_hash" => String(loads["transport_result_hash"]),
        "convergence_status" => numerical_complete ? "converged_exact_lumped_balances" :
            "unsupported_incomplete_numeric_operator_inputs",
        "component_outputs" => outputs, "engineering_checks" => checks,
        "plant_power_roles" => roles, "residuals" => residuals,
        "unresolved_reasons" => sort!(unique(reasons)),
        "evidence_ceiling" => "candidate-bound L1 finite-component/network solution; 3-D independent qualification remains required")
    hash = canonical_hash(_csr_v1_json_safe(body))
    return EngineeringMultiphysicsResultEnvelopeV1("1.0.0", genome.design_id,
        genome.physics_hash, body["state_result_hash"], body["field_solution_hash"],
        body["transport_result_hash"], geometry.manifest_hash, materials.manifest_hash,
        faults.manifest_hash, status, body["convergence_status"], outputs, checks, roles,
        residuals, body["unresolved_reasons"], body["evidence_ceiling"], hash)
end

function engineering_multiphysics_result_to_dict_v1(value::EngineeringMultiphysicsResultEnvelopeV1)
    return Dict{String,Any}("schema_version" => value.schema_version,
        "candidate_id" => value.candidate_id, "physics_hash" => value.physics_hash,
        "state_result_hash" => value.state_result_hash,
        "field_solution_hash" => value.field_solution_hash,
        "transport_result_hash" => value.transport_result_hash,
        "engineering_manifest_hash" => value.engineering_manifest_hash,
        "material_manifest_hash" => value.material_manifest_hash,
        "fault_manifest_hash" => value.fault_manifest_hash, "status" => String(value.status),
        "convergence_status" => value.convergence_status,
        "component_outputs" => value.component_outputs,
        "engineering_checks" => value.engineering_checks,
        "plant_power_roles" => value.plant_power_roles, "residuals" => value.residuals,
        "unresolved_reasons" => value.unresolved_reasons,
        "evidence_ceiling" => value.evidence_ceiling, "result_hash" => value.result_hash)
end
