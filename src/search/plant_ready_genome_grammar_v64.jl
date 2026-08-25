const _V64_CLAIM_BOUNDARY =
    "V64 adds explicit vacuum duct, fuel processing, heat exchanger, conversion-cycle and " *
    "auxiliary-load genes before the common screen. All roles declare provider, time behavior " *
    "and uncertainty. Values are candidate design hypotheses and L1 equipment maps, not vendor " *
    "qualification, independent-code replication, experiment or promotion evidence."

function _v64_evidence_record(body, seed, ordinal; uncertainty_min = 0.05,
        uncertainty_span = 0.10)
    record = Dict{String,Any}(String(key) => value for (key, value) in body)
    record["source_refs"] = ["knowledge:v64_plant_subsystem_screening_library_v1"]
    record["relative_uncertainty"] = uncertainty_min + uncertainty_span *
        _v61_unit(seed * ":uncertainty", ordinal)
    record["evidence_class"] = "candidate_search_equipment_map_not_vendor_qualification"
    record["data_hash"] = canonical_hash(record)
    return record
end

function _v64_role(status, provider, basis, time_behavior, seed, ordinal)
    return Dict{String,Any}("status" => status, "provider" => provider,
        "basis" => basis, "time_behavior" => time_behavior,
        "relative_uncertainty" => status == "not_applicable" ? 0.0 :
            0.05 + 0.10 * _v61_unit(seed * ":role_uncertainty:$provider", ordinal))
end

function _v64_plant_material(seed)
    values = Dict("thermal_conductivity" => (16.0, "W/m/K"),
        "specific_heat" => (500.0, "J/kg/K"), "density" => (8000.0, "kg/m^3"),
        "yield_strength" => (3.0e8, "Pa"), "fatigue_strength" => (1.5e8, "Pa"),
        "fracture_toughness" => (1.0e8, "Pa*sqrt(m)"),
        "radiation_degradation_factor" => (0.8, "1"))
    properties = Dict{String,Any}[]
    for (index, id) in enumerate(sort!(collect(keys(values))))
        value, unit = values[id]
        push!(properties, _v63_property(id, unit, value, seed, 2000 + index;
            uncertainty = 0.20))
    end
    body = Dict{String,Any}("material_id" => "v64_316l_plant_screening",
        "grade" => "316L screening plant structure", "version" => "v64-screening-2026.08",
        "data_source_refs" => ["knowledge:v64_plant_subsystem_screening_library_v1"],
        "applicable_property_ids" => sort!(collect(keys(values))), "properties" => properties,
        "qualification_status" => "model_hypothesis_not_qualified")
    body["data_hash"] = canonical_hash(body)
    return body
end

function _v64_actuator_rate(regional, capability)
    return sum(Float64(get(item, "demand", 0.0)) for item in
        regional["actuator_sizing_records"] if String(get(item, "capability", "")) == capability;
        init = 0.0)
end

function _v64_actuator_wall_power(regional)
    return sum((String(get(item, "capability", "")) == "deposited_energy_source" &&
        get(item, "wall_plug_efficiency", nothing) isa Real ?
        Float64(item["demand"]) / Float64(item["wall_plug_efficiency"]) : 0.0)
        for item in regional["actuator_sizing_records"]; init = 0.0)
end

function _v64_fault_scenario(id, fault_class, component_id, seed, ordinal, metric)
    return Dict{String,Any}("scenario_id" => id, "fault_class" => fault_class,
        "target_component_ids" => [component_id],
        "applicability_basis" => "explicit v64 plant component and fault class",
        "initial_operating_point_hash" => canonical_hash(Dict("component_id" => component_id,
            "fault_class" => fault_class, "seed" => seed)),
        "trigger" => Dict("event_type" => fault_class, "time_s" => 0.0,
            "event_operator_id" => "v64_$(fault_class)_trigger_v1"),
        "protection_actions" => [Dict("action_id" => "isolate_$id", "start_time_s" =>
            0.01 + 0.09 * _v61_unit(seed * ":fault_action", ordinal),
            "action_operator_id" => "v64_isolation_and_safe_shutdown_v1",
            "capacity_limit" => Dict("value" => 1.0, "unit" => "1"))],
        "timeline" => [0.0, 0.01, 0.1, 1.0, 10.0],
        "required_solver_capabilities" => ["plant_transient_network", fault_class],
        "acceptance_metrics" => [metric])
end

function generate_plant_ready_genome_v64(base::Genome, module_ids,
        sample_ordinal::Integer)
    raw = deepcopy(base.normalized)
    seed = canonical_hash(Dict("base_physics_hash" => base.physics_hash,
        "module_ids" => String.(module_ids), "sample_ordinal" => Int(sample_ordinal),
        "generator" => "plant_ready_genome_grammar_v64"))
    regional = raw["regional_solver_contract_v1"]
    source_rate = _v64_actuator_rate(regional, "particle_source")
    exhaust_rate = _v64_actuator_rate(regional, "particle_exhaust")
    has_particles = max(source_rate, exhaust_rate) > 0.0
    geometry = raw["engineering_geometry_manifest_v1"]
    materials = raw["material_property_manifest_v1"]
    faults = raw["fault_scenario_manifest_v1"]
    has_winding = any(item -> String(get(item, "component_role", "")) == "winding_pack",
        geometry["components"])
    species_contract = raw["species_state_contract_v1"]
    has_reaction = String(get(species_contract, "status", "unsupported")) == "complete" &&
        !isempty(fusion_reaction_channels_v1(base.mission.fuel))
    exhaust_regions = unique(String.(raw["exhaust"]["region_ids"]))
    isempty(exhaust_regions) && (exhaust_regions = [String(last(raw["plasma_regions"])["id"])])
    exhaust_networks = Dict{String,Any}[]
    fuel_systems = Dict{String,Any}[]
    thermal_cycles = Dict{String,Any}[]
    shielding_systems = Dict{String,Any}[]
    auxiliary_loads = Dict{String,Any}[]
    recovery_systems = Dict{String,Any}[]
    new_components = Dict{String,Any}[]
    new_mappings = Dict{String,Any}[]
    new_boundaries = Dict{String,Any}[]
    new_faults = Dict{String,Any}[]
    if has_particles
        temperature = 280.0 + 80.0 * _v61_unit(seed * ":exhaust_temperature", 1)
        inlet_pressure = 0.1 + 4.9 * _v61_unit(seed * ":exhaust_pressure", 2)
        mean_mass = 2.5 * _CPSR_V1_AMU
        mean_speed = sqrt(8.0 * _CPSR_V1_KB * temperature / (pi * mean_mass))
        required_speed = exhaust_rate * _CPSR_V1_KB * temperature / inlet_pressure
        conductance_target = max(4.0 * required_speed, 1.0e-6)
        diameter = sqrt(16.0 * conductance_target / (pi * mean_speed))
        duct_id = "v64_vacuum_duct_001"
        exhaust = _v64_evidence_record(Dict(
            "network_id" => "v64_exhaust_network_001", "target_region_ids" => exhaust_regions,
            "species_ids" => String[String(item["species_id"]) for item in
                species_contract["species_records"] if Int(item["charge_state"]) > 0],
            "throughput_fraction" => 1.0, "inlet_temperature_k" => temperature,
            "inlet_pressure_pa" => inlet_pressure, "outlet_pressure_pa" => 1.0e5,
            "duct_length_m" => max(diameter, 0.1), "duct_diameter_m" => diameter,
            "pump_speed_capacity_m3_s" => max(4.0 * required_speed, 1.0e-6),
            "isothermal_efficiency" => 0.55 + 0.30 * _v61_unit(seed * ":pump_eff", 3),
            "operating_duty_factor" => 0.5 + 0.5 * _v61_unit(seed * ":pump_duty", 4)),
            seed, 10)
        push!(exhaust_networks, exhaust)
        residence = 10.0 + 990.0 * _v61_unit(seed * ":residence", 5)
        average_factor = get(get(raw, "time_integration_contract_v1", Dict{String,Any}()),
            "duty_factor", 1.0)
        average_rate = max(source_rate, exhaust_rate) * Float64(average_factor)
        inventory = average_rate * residence * mean_mass
        push!(fuel_systems, _v64_evidence_record(Dict(
            "system_id" => "v64_fuel_cycle_001",
            "species_ids" => exhaust["species_ids"], "throughput_fraction" => 1.0,
            "processing_capacity_per_s" => max(1.2 * average_rate, 1.0),
            "processing_energy_j_per_particle" => 1.0e-13 +
                9.9e-12 * _v61_unit(seed * ":processing_energy", 6),
            "processing_efficiency" => 0.55 + 0.35 * _v61_unit(seed * ":processing_eff", 7),
            "capacity_basis" => "cycle_average_rate", "residence_time_s" => residence,
            "inventory_limit_kg" => max(2.0 * inventory, 1.0e-12),
            "retention_fraction" => 0.001 + 0.049 * _v61_unit(seed * ":retention", 8)),
            seed, 11))
        mesh_body = Dict("component_id" => duct_id, "kind" => "finite_volume_vacuum_network",
            "axial_cells" => 32, "diameter_m" => diameter, "length_m" => max(diameter, 0.1))
        geometry_body = Dict("component_id" => duct_id, "diameter_m" => diameter,
            "length_m" => max(diameter, 0.1))
        volume = pi * diameter^2 / 4.0 * max(diameter, 0.1)
        push!(new_components, Dict("component_id" => duct_id,
            "component_role" => "vacuum_duct", "material_id" => "v64_316l_plant_screening",
            "finite_geometry" => Dict("representation" => "network_mesh",
                "geometry_hash" => canonical_hash(geometry_body),
                "mesh_hash" => canonical_hash(mesh_body), "mesh_dimension" => 1,
                "measure" => Dict("value" => volume, "unit" => "m^3")),
            "features" => [Dict("feature_id" => "molecular_duct", "kind" => "vacuum_duct",
                "diameter_m" => diameter, "length_m" => max(diameter, 0.1))]))
        for (index, region_id) in enumerate(exhaust_regions)
            push!(new_mappings, Dict("mapping_id" => "v64_exhaust_map_$index",
                "source_region_id" => region_id, "source_load_slot" => "particle_exhaust",
                "target_component_id" => duct_id,
                "mapping_operator_id" => "species_exhaust_to_molecular_network_v1",
                "jacobian_operator_id" => "species_exhaust_to_molecular_network_jacobian_v1",
                "sign_convention" => "positive_out_of_plasma", "unit" => "1/s"))
        end
        push!(new_boundaries, Dict("boundary_id" => "v64_vacuum_outlet",
            "component_id" => duct_id, "physics" => "molecular_flow",
            "condition_type" => "specified_pump_speed_and_backpressure",
            "boundary_operator_id" => "molecular_pump_boundary_v1",
            "jacobian_operator_id" => "molecular_pump_boundary_jacobian_v1"))
        push!(new_faults, _v64_fault_scenario("v64_loss_of_vacuum", "loss_of_vacuum",
            duct_id, seed, 20, Dict("metric_id" => "maximum_vacuum_pressure",
                "observable_id" => "duct_pressure", "statistic" => "peak",
                "comparison" => "<=", "threshold" => 1.0e3, "unit" => "Pa",
                "location" => duct_id)))
    end
    if has_reaction
        heat_id = "v64_heat_exchange_surface_001"
        source_fraction = base.engineering.blanket_required ? 0.85 : 0.95
        push!(thermal_cycles, _v64_evidence_record(Dict(
            "cycle_id" => "v64_primary_heat_cycle_001", "source_heat_role" => "fusion_power",
            "source_fraction" => source_fraction,
            "heat_exchanger_effectiveness" => 0.75 + 0.20 * _v61_unit(seed * ":hx_eff", 30),
            "coolant_mass_flow_kg_s" => 1.0e3 + 9.9e4 * _v61_unit(seed * ":hot_flow", 31),
            "coolant_specific_heat_j_kg_k" => 4500.0,
            "coolant_density_kg_m3" => 900.0,
            "coolant_inlet_temperature_k" => 650.0 + 250.0 * _v61_unit(seed * ":hot_inlet", 32),
            "sink_temperature_k" => 290.0 + 40.0 * _v61_unit(seed * ":sink", 33),
            "second_law_efficiency" => 0.45 + 0.35 * _v61_unit(seed * ":cycle_eff", 34),
            "coolant_pressure_drop_pa" => 1.0e5 + 1.9e6 * _v61_unit(seed * ":hot_dp", 35),
            "circulation_pump_efficiency" => 0.65 + 0.25 * _v61_unit(seed * ":hot_pump_eff", 36),
            "circulation_duty_factor" => 0.70 + 0.30 * _v61_unit(seed * ":hot_duty", 37),
            "generator_auxiliary_fraction" => 0.01 + 0.04 * _v61_unit(seed * ":gen_aux", 38)),
            seed, 31))
        if base.engineering.blanket_required
            push!(shielding_systems, _v64_evidence_record(Dict(
                "system_id" => "v64_shield_cooling_001", "source_heat_role" => "fusion_power",
                "source_fraction" => 0.10, "cold_temperature_k" => 80.0,
                "ambient_temperature_k" => 300.0,
                "second_law_efficiency" => 0.20 + 0.20 * _v61_unit(seed * ":shield_eff", 39)),
                seed, 32))
        end
        area = 100.0 + 900.0 * _v61_unit(seed * ":hx_area", 40)
        geometry_body = Dict("component_id" => heat_id, "surface_area_m2" => area,
            "thickness_m" => 0.02, "channel_count" => 64)
        mesh_body = Dict("component_id" => heat_id, "kind" => "surface_and_channel_mesh",
            "surface_cells" => 4096, "channel_cells" => 2048)
        push!(new_components, Dict("component_id" => heat_id,
            "component_role" => "heat_exchange_surface", "material_id" => "v64_316l_plant_screening",
            "finite_geometry" => Dict("representation" => "surface_mesh",
                "geometry_hash" => canonical_hash(geometry_body),
                "mesh_hash" => canonical_hash(mesh_body), "mesh_dimension" => 2,
                "measure" => Dict("value" => area, "unit" => "m^2")),
            "features" => [Dict("feature_id" => "primary_heat_exchanger",
                "kind" => "heat_exchange_surface", "surface_area_m2" => area,
                "channel_count" => 64)]))
        for (index, region) in enumerate(regional["region_records"])
            push!(new_mappings, Dict("mapping_id" => "v64_heat_map_$index",
                "source_region_id" => region["region_id"], "source_load_slot" => "fusion_power",
                "target_component_id" => heat_id,
                "mapping_operator_id" => "regional_heat_to_exchange_surface_v1",
                "jacobian_operator_id" => "regional_heat_to_exchange_surface_jacobian_v1",
                "sign_convention" => "positive_into_plant_cycle", "unit" => "W"))
        end
        push!(new_boundaries, Dict("boundary_id" => "v64_heat_sink_boundary",
            "component_id" => heat_id, "physics" => "thermal_hydraulic",
            "condition_type" => "counterflow_heat_exchanger",
            "boundary_operator_id" => "effectiveness_ntU_heat_exchanger_v1",
            "jacobian_operator_id" => "effectiveness_ntU_heat_exchanger_jacobian_v1"))
        push!(new_faults, _v64_fault_scenario("v64_loss_of_flow", "loss_of_flow",
            heat_id, seed, 41, Dict("metric_id" => "maximum_wall_temperature",
                "observable_id" => "heat_exchanger_wall_temperature", "statistic" => "peak",
                "comparison" => "<=", "threshold" => 1200.0, "unit" => "K",
                "location" => heat_id)))
        push!(new_faults, _v64_fault_scenario("v64_loss_of_coolant", "loss_of_coolant",
            heat_id, seed, 42, Dict("metric_id" => "integrated_unremoved_heat",
                "observable_id" => "unremoved_heat", "statistic" => "integral",
                "comparison" => "<=", "threshold" => 1.0e12, "unit" => "J",
                "location" => heat_id)))
        push!(new_faults, _v64_fault_scenario("v64_loss_of_power", "loss_of_power",
            heat_id, seed, 43, Dict("metric_id" => "passive_cooling_delay",
                "observable_id" => "temperature_limit_duration", "statistic" => "duration",
                "comparison" => ">=", "threshold" => 10.0, "unit" => "s",
                "location" => heat_id)))
    end
    drive_wall = _v64_actuator_wall_power(regional)
    push!(auxiliary_loads, _v64_evidence_record(Dict(
        "load_id" => "v64_controls_diagnostics_001",
        "rated_power_w" => max(1.0e3, drive_wall *
            (0.005 + 0.025 * _v61_unit(seed * ":controls", 50))),
        "duty_factor" => 0.50 + 0.50 * _v61_unit(seed * ":controls_duty", 51),
        "supply_efficiency" => 0.80 + 0.18 * _v61_unit(seed * ":controls_eff", 52)),
        seed, 50))
    if !isempty(new_components)
        append!(geometry["components"], new_components)
        append!(geometry["load_mappings"], new_mappings)
        append!(geometry["boundary_conditions"], new_boundaries)
        geometry["applicable_component_roles"] = sort!(unique(vcat(
            String.(geometry["applicable_component_roles"]),
            String[String(item["component_role"]) for item in new_components])))
        geometry["not_applicable_basis"] = ""
        push!(materials["materials"], _v64_plant_material(seed))
        append!(faults["scenarios"], new_faults)
        faults["applicable_fault_classes"] = sort!(unique(vcat(
            String.(faults["applicable_fault_classes"]),
            String[String(item["fault_class"]) for item in new_faults])))
        faults["not_applicable_basis"] = ""
    end
    pulse = haskey(raw, "time_integration_contract_v1")
    heating_applicable = any(item -> String(get(item, "capability", "")) ==
        "deposited_energy_source", regional["actuator_sizing_records"])
    thermal_applicable = has_reaction
    role_applicability = Dict{String,Any}(
        "heating_and_current_drive_wall_plug" => heating_applicable ?
            _v64_role("applicable", "regional_actuator", "realized deposited-energy actuator",
                pulse ? "pulse_active" : "continuous", seed, 60) :
            _v64_role("not_applicable", "none", "no deposited-energy actuator",
                "not_applicable", seed, 60),
        "particle_injection_fuel_processing" => has_particles ?
            _v64_role("applicable", "v64_exhaust_fuel", "particle source/exhaust applies",
                "already_cycle_average", seed, 61) :
            _v64_role("not_applicable", "none", "no particle source or exhaust demand",
                "not_applicable", seed, 61),
        "magnet_power_and_pulse_storage" => has_winding ?
            _v64_role("applicable", "v63_engineering", "finite winding applies",
                pulse ? "pulse_active" : "continuous", seed, 62) :
            _v64_role("not_applicable", "none", "no finite winding_pack",
                "not_applicable", seed, 62),
        "cryogenic_system" => has_winding ?
            _v64_role("applicable", "v63_engineering", "cryogenic winding applies",
                "continuous", seed, 63) :
            _v64_role("not_applicable", "none", "no cryogenic winding",
                "not_applicable", seed, 63),
        "vacuum_exhaust_pumping" => has_particles ?
            _v64_role("applicable", "v64_exhaust_fuel", "particle exhaust applies",
                "already_cycle_average", seed, 64) :
            _v64_role("not_applicable", "none", "no particle exhaust demand",
                "not_applicable", seed, 64),
        "coolant_circulation_heat_rejection" => (has_winding || thermal_applicable) ?
            _v64_role("applicable", "v64_thermal_cycle", "magnet or plant coolant applies",
                "already_cycle_average", seed, 65) :
            _v64_role("not_applicable", "none", "no coolant-bearing component",
                "not_applicable", seed, 65),
        "thermal_conversion_auxiliaries" => thermal_applicable ?
            _v64_role("applicable", "v64_thermal_cycle", "fusion heat cycle applies",
                "already_cycle_average", seed, 66) :
            _v64_role("not_applicable", "none", "no applicable reaction heat source",
                "not_applicable", seed, 66),
        "shielding_cooling" => thermal_applicable && base.engineering.blanket_required ?
            _v64_role("applicable", "v64_thermal_cycle", "blanket/shield heat fraction applies",
                "already_cycle_average", seed, 67) :
            _v64_role("not_applicable", "none", "no declared blanket/shield cooling role",
                "not_applicable", seed, 67),
        "controls_diagnostics_auxiliaries" =>
            _v64_role("applicable", "v64_auxiliary_load", "control and diagnostic equipment applies",
                "already_cycle_average", seed, 68),
        "direct_energy_recovery" =>
            _v64_role("not_applicable", "none", "no direct recovery capability declared",
                "not_applicable", seed, 69),
        "gross_electric_generation" => thermal_applicable ?
            _v64_role("applicable", "v64_thermal_cycle", "captured fusion heat cycle applies",
                "already_cycle_average", seed, 70) :
            _v64_role("not_applicable", "none", "no applicable reaction heat source",
                "not_applicable", seed, 70))
    raw["plant_subsystem_manifest_v1"] = Dict{String,Any}(
        "role_applicability" => role_applicability,
        "exhaust_networks" => exhaust_networks, "fuel_cycle_systems" => fuel_systems,
        "thermal_cycles" => thermal_cycles,
        "shielding_cooling_systems" => shielding_systems,
        "auxiliary_loads" => auxiliary_loads,
        "direct_recovery_systems" => recovery_systems,
        "uncertainty_contract" => Dict("coverage_sigma" => 2.0,
            "net_sign_required" => true),
        "generator_id" => "plant_ready_genome_grammar_v64",
        "generation_stage" => "before_common_screen", "family_label_used" => false)
    _v18_push_unique!(raw["provenance"]["notes"], ["plant_ready_genome_grammar_v64",
        "explicit exhaust/fuel/thermal/auxiliary roles generated before common screening",
        "pulse power converted through J_per_pulse times repetition rate"])
    raw["design_id"] = "pending_plant_ready_v64"
    provisional = parse_genome(raw)
    raw["design_id"] = "v64_$(canonical_hash(module_ids)[1:12])_s$(lpad(Int(sample_ordinal), 6, '0'))_" *
        provisional.physics_hash[1:12]
    result = parse_genome(raw)
    result.physics_hash != base.physics_hash || error("v64 plant genes did not enter physics hash")
    return result
end

function evaluate_plant_ready_candidate_v64(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        halton_skip::Integer = 4096)
    base = evaluate_engineering_ready_candidate_v63(context, candidate_index;
        halton_skip = halton_skip)
    old = base.prescreen.compiled
    genome = generate_plant_ready_genome_v64(old.genome, old.module_ids,
        base.sample_ordinal)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("generated v64 genome invalid: " * join(report.errors, "; ")))
    compiled = CompiledAttributeGenomeV18(old.assembly_id, old.graph_hash, old.family,
        old.mission_contract_id, copy(old.module_ids), genome, old.evaluator_id,
        old.projection_id, sort!(unique(vcat(old.projection_limitations,
            ["v64 plant maps are L1 screening hypotheses"]))),
        copy(old.declared_requirements), sort!(unique(vcat(old.validation_warnings,
            report.warnings))))
    prescreen = _v18_prescreen(compiled, context.evaluators, context.evaluator_registry)
    return CrossTopologyCandidateV20(Int(candidate_index), base.assembly_index,
        base.sample_ordinal, prescreen)
end

function plant_ready_contract_audit_v64(genome::Genome)
    plant = compile_plant_subsystem_manifest_v1(genome)
    engineering = compile_candidate_engineering_manifests_v1(genome)
    status = plant.status == :pass && engineering["status"] == :pass ? "pass" :
        plant.status == :unsupported || engineering["status"] == :unsupported ? "unsupported" : "unknown"
    return Dict{String,Any}("status" => status, "plant_manifest_hash" => plant.manifest_hash,
        "engineering_bundle_hash" => engineering["bundle_hash"],
        "plant_reasons" => plant.unresolved_reasons,
        "engineering_reasons" => engineering["unresolved_reasons"],
        "family_label_used" => false)
end
