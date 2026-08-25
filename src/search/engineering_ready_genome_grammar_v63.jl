const _V63_CLAIM_BOUNDARY =
    "V63 adds finite component, versioned screening-material and fault/protection search genes " *
    "before the common screen. The genes are capability-routed design hypotheses and enter the " *
    "physics hash. Material ranges remain L1 screening curves, not qualification data; the " *
    "finite-component runtime does not grant independent-code, experimental or promotion credit."

function _v63_property(id, unit, value, seed, ordinal; uncertainty = 0.25)
    ranges = Dict{String,Any}(
        "temperature" => Dict("minimum" => 3.0, "maximum" => 350.0, "unit" => "K"),
        "magnetic_field" => Dict("minimum" => 0.0, "maximum" => 45.0, "unit" => "T"),
        "strain" => Dict("minimum" => -0.02, "maximum" => 0.02, "unit" => "1"),
        "dpa" => Dict("minimum" => 0.0, "maximum" => 10.0, "unit" => "1"))
    body = Dict{String,Any}(
        "property_id" => id, "unit" => unit,
        "independent_variables" => ["temperature", "magnetic_field", "strain", "dpa"],
        "representation" => "constitutive_operator",
        "curve_data" => Dict("reference_value" => Float64(value),
            "operator_id" => "v63_screening_reference_value_with_validity_guard_v1",
            "search_gene_scale" => 0.9 + 0.2 * _v61_unit(seed * ":property:$id", ordinal)),
        "validity_ranges" => ranges,
        "uncertainty" => Dict("kind" => "relative_1sigma", "value" => uncertainty, "unit" => "1"),
        "source_refs" => ["knowledge:v63_screening_material_library_v1",
            "https://www.iter.org/machine/magnets",
            "https://nucleus.iaea.org/sites/fusionportal/Shared%20Documents/DEMO/2018/3/Prestemon.pdf"],
        "evidence_class" => "screening_model_hypothesis_not_material_qualification")
    body["data_hash"] = canonical_hash(body)
    return body
end

function _v63_material(material_id, seed, ordinal)
    values = if material_id == "v63_nbti_cicc_screening"
        Dict("electrical_resistivity" => (1.0e-12, "ohm*m"),
            "thermal_conductivity" => (350.0, "W/m/K"),
            "specific_heat" => (350.0, "J/kg/K"), "density" => (8000.0, "kg/m^3"),
            "yield_strength" => (5.0e8, "Pa"), "fatigue_strength" => (2.5e8, "Pa"),
            "critical_current_density" => (3.0e8, "A/m^2"),
            "critical_temperature" => (9.2, "K"), "critical_field" => (10.0, "T"))
    elseif material_id == "v63_nb3sn_cicc_screening"
        Dict("electrical_resistivity" => (8.0e-13, "ohm*m"),
            "thermal_conductivity" => (300.0, "W/m/K"),
            "specific_heat" => (320.0, "J/kg/K"), "density" => (8200.0, "kg/m^3"),
            "yield_strength" => (6.0e8, "Pa"), "fatigue_strength" => (3.0e8, "Pa"),
            "critical_current_density" => (5.0e8, "A/m^2"),
            "critical_temperature" => (18.0, "K"), "critical_field" => (25.0, "T"))
    else
        Dict("electrical_resistivity" => (5.0e-13, "ohm*m"),
            "thermal_conductivity" => (250.0, "W/m/K"),
            "specific_heat" => (300.0, "J/kg/K"), "density" => (7800.0, "kg/m^3"),
            "yield_strength" => (7.0e8, "Pa"), "fatigue_strength" => (3.5e8, "Pa"),
            "critical_current_density" => (4.0e8, "A/m^2"),
            "critical_temperature" => (90.0, "K"), "critical_field" => (40.0, "T"))
    end
    properties = Dict{String,Any}[]
    for (index, id) in enumerate(sort!(collect(keys(values))))
        value, unit = values[id]
        push!(properties, _v63_property(id, unit, value, seed, 100ordinal + index))
    end
    body = Dict{String,Any}(
        "material_id" => material_id, "grade" => "v63 explicit screening composite",
        "version" => "v63-screening-2026.08",
        "data_source_refs" => ["knowledge:v63_screening_material_library_v1",
            "https://www.iter.org/machine/magnets"],
        "applicable_property_ids" => sort!(collect(keys(values))),
        "properties" => properties,
        "qualification_status" => "model_hypothesis_not_qualified")
    body["data_hash"] = canonical_hash(body)
    return body
end

function _v63_insulation_material(seed)
    property = _v63_property("dielectric_strength", "V/m", 1.0e7, seed, 991;
        uncertainty = 0.35)
    body = Dict{String,Any}(
        "material_id" => "v63_g10_epoxy_screening", "grade" => "cryogenic G10/epoxy screening",
        "version" => "v63-screening-2026.08",
        "data_source_refs" => ["knowledge:v63_screening_material_library_v1",
            "https://conferences.iaea.org/event/151/contributions/5843/"],
        "applicable_property_ids" => ["dielectric_strength"], "properties" => [property],
        "qualification_status" => "model_hypothesis_not_qualified")
    body["data_hash"] = canonical_hash(body)
    return body
end

function _v63_material_selection(source::FieldSource, seed, ordinal)
    text = lowercase(source.material * " " * source.kind)
    if occursin("rebco", text) || occursin("hts", text) || occursin("high-temperature", text)
        return "v63_rebco_composite_screening", "explicit source material declares REBCO/HTS"
    elseif occursin("nb3sn", text) || occursin("niobium-tin", text)
        return "v63_nb3sn_cicc_screening", "explicit source material declares Nb3Sn"
    elseif occursin("nbti", text) || occursin("niobium-titanium", text)
        return "v63_nbti_cicc_screening", "explicit source material declares NbTi"
    elseif occursin("superconduct", text)
        options = ["v63_nbti_cicc_screening", "v63_nb3sn_cicc_screening",
            "v63_rebco_composite_screening"]
        selected = options[clamp(floor(Int, 3.0 * _v61_unit(seed * ":material", ordinal)) + 1, 1, 3)]
        return selected, "explicit v63 material search gene for generic superconducting source"
    end
    return nothing, "source does not declare a supported finite-conductor capability"
end

function _v63_source_field(source::FieldSource, genome::Genome, seed, ordinal)
    values = Float64[Float64(quantity.value) for (id, quantity) in source.parameters if
        quantity.unit == "T" && quantity.value > 0.0 &&
        (occursin("field", lowercase(id)) || occursin("peak", lowercase(id)))]
    if isempty(values)
        for other in genome.field_sources, (id, quantity) in other.parameters
            quantity.unit == "T" && quantity.value > 0.0 &&
                (occursin("field", lowercase(id)) || occursin("peak", lowercase(id))) &&
                push!(values, Float64(quantity.value))
        end
    end
    return isempty(values) ? 1.0 + 14.0 * _v61_unit(seed * ":field", ordinal) : maximum(values)
end

function _v63_coil_count(source::FieldSource)
    values = Int[]
    for (id, quantity) in source.parameters
        occursin("count", lowercase(id)) && quantity.unit == "1" && quantity.value > 0.0 &&
            push!(values, max(1, round(Int, quantity.value)))
    end
    return isempty(values) ? 1 : maximum(values)
end

function _v63_material_reference(material, id)
    property = only(item for item in material["properties"] if item["property_id"] == id)
    return Float64(property["curve_data"]["reference_value"])
end

"Generate explicit component, material and fault genes from declarations and search coordinates."
function generate_engineering_ready_genome_v63(base::Genome, module_ids,
        sample_ordinal::Integer)
    raw = deepcopy(base.normalized)
    seed = canonical_hash(Dict("base_physics_hash" => base.physics_hash,
        "module_ids" => String.(module_ids), "sample_ordinal" => Int(sample_ordinal),
        "generator" => "engineering_ready_genome_grammar_v63"))
    regional = raw["regional_solver_contract_v1"]
    total_volume = sum(Float64(item["volume_m3"]) for item in regional["region_records"])
    region_ids = String[String(item["region_id"]) for item in regional["region_records"]]
    sources = [source for source in base.field_sources if source.kind != "plasma_current" &&
        lowercase(source.material) != "plasma"]
    components = Dict{String,Any}[]
    mappings = Dict{String,Any}[]
    insulation = Dict{String,Any}[]
    boundaries = Dict{String,Any}[]
    scenarios = Dict{String,Any}[]
    materials_by_id = Dict{String,Dict{String,Any}}()
    component_count = max(length(sources), 1)
    pulse = get(raw, "time_integration_contract_v1", Dict{String,Any}())
    frequency = Float64(get(pulse, "repetition_rate_hz", 0.0))
    for (index, source) in enumerate(sources)
        material_id, selection_basis = _v63_material_selection(source, seed, index)
        material_id === nothing && continue
        material = get!(materials_by_id, material_id) do
            _v63_material(material_id, seed, index)
        end
        critical_j = _v63_material_reference(material, "critical_current_density")
        yield_strength = _v63_material_reference(material, "yield_strength")
        peak_field = _v63_source_field(source, base, seed, index)
        coil_count = _v63_coil_count(source)
        scale = cbrt(total_volume)
        path_length = max(2.0pi * scale * coil_count *
            (0.7 + 0.6 * _v61_unit(seed * ":path", index)), 0.1)
        conductor_volume = total_volume / component_count *
            (0.002 + 0.010 * _v61_unit(seed * ":conductor_volume", index))
        conductor_area = conductor_volume / path_length
        design_j = critical_j * (0.15 + 0.25 * _v61_unit(seed * ":current_density", index))
        current = design_j * conductor_area
        predicted_force = current * path_length * peak_field
        support_area = predicted_force /
            (yield_strength * (0.15 + 0.15 * _v61_unit(seed * ":support_margin", index)))
        material_temperature = material_id == "v63_rebco_composite_screening" ? 20.0 : 4.5
        component_id = "v63_winding_$(lpad(index, 3, '0'))_$(source.id)"
        mesh_body = Dict("component_id" => component_id, "kind" => "finite_volume_network",
            "radial_cells" => 8 + 8 * (index % 2), "axial_cells" => 16,
            "source_geometry_model" => source.geometry_model,
            "generation_basis" => "explicit v63 finite-component search gene")
        geometry_body = Dict("component_id" => component_id, "path_length_m" => path_length,
            "conductor_area_m2" => conductor_area, "conductor_volume_m3" => conductor_volume,
            "support_area_m2" => support_area, "coil_count" => coil_count)
        features = Any[
            Dict("feature_id" => "conductor", "kind" => "conductor_paths",
                "current_a" => current, "total_length_m" => path_length,
                "conductor_area_m2" => conductor_area,
                "conductor_volume_m3" => conductor_volume,
                "field_volume_m3" => total_volume / component_count,
                "operating_temperature_k" => material_temperature,
                "excitation_frequency_hz" => frequency,
                "ac_loss_coefficient_w_per_a2_hz_m" => 1.0e-15 *
                    (0.5 + _v61_unit(seed * ":ac_loss", index))),
            Dict("feature_id" => "support", "kind" => "support_domain",
                "load_bearing_area_m2" => support_area,
                "load_path_length_m" => 0.05 + 0.45 * _v61_unit(seed * ":support_path", index)),
            Dict("feature_id" => "coolant", "kind" => "coolant_channel",
                "hydraulic_diameter_m" => 0.01 + 0.04 * _v61_unit(seed * ":diameter", index),
                "total_length_m" => path_length, "flow_area_m2" => max(conductor_area * 0.15, 1.0e-6),
                "wetted_area_m2" => max(pi * (0.01 + 0.04 * _v61_unit(seed * ":diameter", index)) *
                    path_length, 1.0e-6),
                "critical_heat_flux_w_m2" => 1.0e6 + 19.0e6 * _v61_unit(seed * ":chf", index),
                "mass_flow_kg_s" => 1.0 + 30.0 * _v61_unit(seed * ":mass_flow", index),
                "density_kg_m3" => 125.0, "specific_heat_j_kg_k" => 5000.0,
                "inlet_temperature_k" => material_temperature,
                "darcy_friction_factor" => 0.015 + 0.025 * _v61_unit(seed * ":friction", index),
                "pump_efficiency" => 0.55 + 0.30 * _v61_unit(seed * ":pump_efficiency", index),
                "mapped_heat_fraction" => 1.0 / component_count),
            Dict("feature_id" => "cryo", "kind" => "cryogenic_stage",
                "ambient_temperature_k" => 300.0,
                "second_law_efficiency" => 0.15 + 0.20 * _v61_unit(seed * ":cryo", index)),
            Dict("feature_id" => "protection", "kind" => "quench_protection",
                "dump_resistance_ohm" => max(5000.0 / max(current, 1.0), 1.0e-6),
                "detection_time_s" => 0.005 + 0.045 * _v61_unit(seed * ":detection", index),
                "conductor_deposited_energy_fraction" => 1.0e-4 +
                    9.0e-4 * _v61_unit(seed * ":deposition", index))]
        push!(components, Dict("component_id" => component_id,
            "component_role" => "winding_pack", "material_id" => material_id,
            "material_selection_basis" => selection_basis,
            "finite_geometry" => Dict("representation" => "finite_volume_mesh",
                "geometry_hash" => canonical_hash(geometry_body),
                "mesh_hash" => canonical_hash(mesh_body), "mesh_dimension" => 3,
                "measure" => Dict("value" => conductor_volume, "unit" => "m^3")),
            "features" => features))
        for (region_index, region_id) in enumerate(region_ids)
            push!(mappings, Dict("mapping_id" => "v63_field_map_$(index)_$(region_index)",
                "source_region_id" => region_id, "source_load_slot" => "magnetic_field",
                "target_component_id" => component_id,
                "mapping_operator_id" => "conservative_region_field_to_conductor_v1",
                "jacobian_operator_id" => "conservative_region_field_to_conductor_jacobian_v1",
                "sign_convention" => "positive_magnitude", "unit" => "T"))
        end
        push!(insulation, Dict("boundary_id" => "v63_ground_insulation_$index",
            "component_id" => component_id,
            "insulation_material_id" => "v63_g10_epoxy_screening",
            "thickness_m" => 0.005 + 0.015 * _v61_unit(seed * ":insulation", index),
            "breakdown_field_v_per_m" => 1.0e7,
            "boundary_operator_id" => "dielectric_insulation_v1"))
        push!(boundaries, Dict("boundary_id" => "v63_coolant_boundary_$index",
            "component_id" => component_id, "physics" => "thermal_hydraulic",
            "condition_type" => "conjugate_robin_network",
            "boundary_operator_id" => "coolant_film_boundary_v1",
            "jacobian_operator_id" => "coolant_film_boundary_jacobian_v1"))
        push!(scenarios, Dict("scenario_id" => "v63_quench_$index",
            "fault_class" => "quench", "target_component_ids" => [component_id],
            "applicability_basis" => "declared superconducting finite winding and dump circuit",
            "initial_operating_point_hash" => canonical_hash(Dict("component_id" => component_id,
                "current_a" => current, "peak_field_t" => peak_field)),
            "trigger" => Dict("event_type" => "normal_zone_seed", "time_s" => 0.0,
                "event_operator_id" => "normal_zone_seed_v1"),
            "protection_actions" => [Dict("action_id" => "dump_$index", "start_time_s" => 0.01,
                "action_operator_id" => "dump_resistor_switch_v1",
                "capacity_limit" => Dict("value" => 1.0e12, "unit" => "J"))],
            "timeline" => [0.0, 0.01, 0.1, 1.0, 10.0],
            "required_solver_capabilities" => ["finite_conductor_electromagnetics",
                "structural_response", "thermal_hydraulics", "quench_propagation",
                "circuit_protection"],
            "acceptance_metrics" => [Dict("metric_id" => "maximum_terminal_voltage",
                "observable_id" => "terminal_voltage", "statistic" => "peak",
                "comparison" => "<=", "threshold" => 1.0e4, "unit" => "V",
                "location" => "$component_id terminals")]))
    end
    materials = collect(values(materials_by_id)); push!(materials, _v63_insulation_material(seed))
    sort!(materials; by = item -> String(item["material_id"]))
    raw["engineering_geometry_manifest_v1"] = Dict(
        "applicable_component_roles" => isempty(components) ? String[] : ["winding_pack"],
        "not_applicable_basis" => isempty(components) ?
            "candidate declares no finite-conductor magnetic source; laser/driver engineering is outside v63 magnet slice" : "",
        "components" => components, "load_mappings" => mappings,
        "contacts" => Dict{String,Any}[], "insulation_boundaries" => insulation,
        "boundary_conditions" => boundaries, "generator_id" => "engineering_ready_genome_grammar_v63",
        "generation_stage" => "before_common_screen", "family_label_used" => false)
    raw["material_property_manifest_v1"] = Dict("materials" => materials,
        "generator_id" => "engineering_ready_genome_grammar_v63",
        "qualification_status" => "screening_model_hypotheses", "family_label_used" => false)
    raw["fault_scenario_manifest_v1"] = Dict("applicable_fault_classes" =>
        isempty(scenarios) ? String[] : ["quench"], "scenarios" => scenarios,
        "not_applicable_basis" => isempty(scenarios) ?
            "no superconducting winding makes quench protection inapplicable to the v63 magnet slice" : "",
        "generator_id" => "engineering_ready_genome_grammar_v63",
        "generation_stage" => "before_common_screen", "family_label_used" => false)
    provenance = raw["provenance"]
    _v18_push_unique!(provenance["notes"], ["engineering_ready_genome_grammar_v63",
        "finite component/material/fault genes generated before common screening",
        "screening material curves are not qualification or experimental evidence"])
    raw["design_id"] = "pending_engineering_ready_v63"
    provisional = parse_genome(raw)
    raw["design_id"] = "v63_$(canonical_hash(module_ids)[1:12])_s$(lpad(Int(sample_ordinal), 6, '0'))_" *
        provisional.physics_hash[1:12]
    result = parse_genome(raw)
    result.physics_hash != base.physics_hash || error("v63 engineering genes did not enter physics hash")
    return result
end

function evaluate_engineering_ready_candidate_v63(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        halton_skip::Integer = 4096)
    base = evaluate_evidence_ready_candidate_v62(context, candidate_index;
        halton_skip = halton_skip)
    old = base.prescreen.compiled
    genome = generate_engineering_ready_genome_v63(old.genome, old.module_ids,
        base.sample_ordinal)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("generated v63 genome invalid: " *
        join(report.errors, "; ")))
    compiled = CompiledAttributeGenomeV18(old.assembly_id, old.graph_hash, old.family,
        old.mission_contract_id, copy(old.module_ids), genome, old.evaluator_id,
        old.projection_id, sort!(unique(vcat(old.projection_limitations,
            ["v63 engineering material curves are L1 screening hypotheses"]))),
        copy(old.declared_requirements), sort!(unique(vcat(old.validation_warnings,
            report.warnings))))
    prescreen = _v18_prescreen(compiled, context.evaluators, context.evaluator_registry)
    return CrossTopologyCandidateV20(Int(candidate_index), base.assembly_index,
        base.sample_ordinal, prescreen)
end

function engineering_ready_contract_audit_v63(genome::Genome)
    bundle = compile_candidate_engineering_manifests_v1(genome)
    return Dict{String,Any}("status" => String(bundle["status"]),
        "geometry_manifest_hash" => bundle["geometry"].manifest_hash,
        "material_manifest_hash" => bundle["materials"].manifest_hash,
        "fault_manifest_hash" => bundle["faults"].manifest_hash,
        "bundle_hash" => bundle["bundle_hash"],
        "unresolved_reasons" => bundle["unresolved_reasons"],
        "family_label_used" => false)
end
