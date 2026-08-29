const V105_PROTOCOL_ID = "fusionconceptai-v105-whole-device-assembly-generator-20260829"

const WHOLE_DEVICE_ASSEMBLY_V105_CLAIM_BOUNDARY =
    "v105 extends a plasma/equilibrium candidate into explicit whole-device assembly " *
    "proposals. Grid coordinates only propose physical component inputs; they receive no " *
    "metric, provider, physics, engineering, numerical-VVUQ, validation, or promotion " *
    "credit. Structural input closure is not provider closure or device feasibility."

const V105_REQUIRED_ASSEMBLY_SECTIONS = [
    "operating_point", "equilibrium_inputs", "profile_parameterization", "edge_exhaust",
    "material_stack", "finite_conductor", "thermal_cycle", "fuel_cycle", "control_fault",
    "cryogenic_system", "plant_auxiliaries", "numerical_vvuq_contract",
    "validation_observable_contract",
]

function _v105_design_body(candidate, blanket_fraction, wetted_fraction, efficiency,
        sequence_index)
    point = Dict{String,Any}(candidate["operating_point"])
    physics = Dict{String,Any}(candidate["physics_solve"])
    geometry = Dict{String,Any}(physics["geometry"])
    metrics = Dict{String,Any}(physics["metrics"])
    layout = Dict{String,Any}(candidate["magnet_layout"])
    engineering = Dict{String,Any}(candidate["engineering_prefilter"])
    engineering_metrics = Dict{String,Any}(engineering["metrics"])
    plasma_to_wall = Float64(geometry["plasma_to_wall_clearance_m"])
    first_wall = min(0.03, 0.08plasma_to_wall)
    remaining = plasma_to_wall - first_wall
    blanket = blanket_fraction * remaining
    shield = remaining - blanket
    wall_to_coil = Float64(geometry["wall_to_coil_clearance_m"])
    maintenance = Float64(layout["maintenance_gap_m"])
    winding = Float64(layout["winding_pack_thickness_m"])
    support = Float64(layout["support_thickness_m"])
    first_wall_area = Float64(geometry["first_wall_area_m2"])
    divertor_area = wetted_fraction * first_wall_area
    fusion_power = Float64(metrics["fusion_power_w"])
    loss_power = Float64(metrics["transport_loss_power_w"])
    neutron_power = 0.80fusion_power
    recoverable_heat = neutron_power + 0.20fusion_power + loss_power
    coolant_delta_t = 150.0
    coolant_cp = 5200.0
    coolant_mass_flow = recoverable_heat / (coolant_cp * coolant_delta_t)
    pf_current = Float64(engineering_metrics["maximum_pf_current_a_turn"])
    pf_current_density = Float64(engineering_metrics["pf_current_density_a_m2"])
    conductor_area = pf_current / max(pf_current_density, eps())
    design = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V105_PROTOCOL_ID,
        "proposal_sequence_index" => Int(sequence_index),
        "proposal_grid" => Dict(
            "blanket_fraction_of_remaining_plasma_wall_build" => blanket_fraction,
            "divertor_wetted_area_fraction" => wetted_fraction,
            "gross_thermal_efficiency" => efficiency,
            "proposal_only_no_metric_credit" => true),
        "operating_point" => deepcopy(point),
        "equilibrium_inputs" => Dict(
            "free_boundary_required" => true, "independent_fixed_boundary_required" => true,
            "equilibrium_source_binding_required" => true,
            "required_state_fields" => ["magnetic_flux", "pressure", "current_density"],
            "identity_fields_used_for_routing" => false),
        "profile_parameterization" => Dict(
            "species" => ["deuterium", "tritium", "electron", "helium_ash"],
            "radial_coordinate" => "normalized_toroidal_flux",
            "density_profile_exponent" => 1.0,
            "temperature_profile_exponent" => 1.5,
            "impurity_fraction" => 0.01,
            "edge_density_fraction" => 0.15,
            "edge_temperature_kev" => 0.2,
            "profile_parameters_are_solver_inputs" => true),
        "edge_exhaust" => Dict(
            "topology_semantics" => "closed_core_open_exhaust",
            "separatrix_declared" => true, "scrape_off_layer_declared" => true,
            "divertor_target_declared" => true, "vacuum_pump_declared" => true,
            "target_wetted_area_m2" => divertor_area,
            "target_inclination_deg" => 3.0,
            "flux_expansion" => 8.0,
            "connection_length_m" => Float64(point["open_branch_length_m"]),
            "pump_speed_capacity_m3_s" => 250.0,
            "neutral_pressure_operating_pa" => 2.0,
            "detachment_control_observable" => "target_electron_temperature_ev"),
        "material_stack" => Dict(
            "radial_coordinate" => "outward_from_last_closed_flux_surface",
            "total_plasma_to_wall_build_m" => plasma_to_wall,
            "layers" => [
                Dict("role" => "first_wall", "material_system" => "tungsten_armour",
                    "thickness_m" => first_wall,
                    "material_property_dataset_required" => true),
                Dict("role" => "breeding_blanket", "material_system" =>
                    "lithium_lead_structural_blanket", "thickness_m" => blanket,
                    "material_property_dataset_required" => true),
                Dict("role" => "neutron_shield", "material_system" =>
                    "steel_water_shield", "thickness_m" => shield,
                    "material_property_dataset_required" => true)],
            "blanket_neutronics_required" => true,
            "damage_and_lifetime_required" => true,
            "remote_maintenance_required" => true),
        "finite_conductor" => Dict(
            "coordinate" => "component_geometry", "coil_systems" => [
                Dict("role" => "toroidal_field", "conductor_system" => "rebco_cicc",
                    "operating_temperature_k" => 20.0, "winding_pack_thickness_m" => winding,
                    "support_thickness_m" => support, "finite_build_required" => true),
                Dict("role" => "poloidal_field", "conductor_system" => "rebco_cicc",
                    "maximum_current_a_turn" => pf_current,
                    "engineering_current_density_a_m2" => pf_current_density,
                    "minimum_conductor_area_m2" => conductor_area,
                    "operating_temperature_k" => 20.0, "finite_build_required" => true)],
            "maintenance_gap_m" => maintenance,
            "wall_to_winding_pack_outer_radius_m" => maintenance + winding,
            "declared_wall_to_coil_clearance_m" => wall_to_coil,
            "quench_detection_time_s" => 0.05,
            "maximum_terminal_voltage_v" => 20000.0,
            "dump_energy_capacity_required" => true),
        "thermal_cycle" => Dict(
            "primary_coolant" => "helium", "inlet_temperature_k" => 573.0,
            "outlet_temperature_k" => 723.0, "specific_heat_j_kg_k" => coolant_cp,
            "coolant_density_kg_m3" => 5.0,
            "mass_flow_kg_s" => coolant_mass_flow,
            "primary_pressure_drop_pa" => 2.0e5,
            "gross_thermal_efficiency" => efficiency,
            "pump_efficiency" => 0.75,
            "recoverable_heat_input_w" => recoverable_heat,
            "sizing_rule" => "candidate_power_balance_with_declared_delta_t"),
        "fuel_cycle" => Dict(
            "species" => ["deuterium", "tritium", "helium_ash"],
            "tritium_breeding_ratio_minimum" => 1.10,
            "maximum_site_tritium_inventory_kg" => 5.0,
            "processing_capacity_particles_s" => 2.0e23,
            "fuel_cycle_residence_time_s" => 3600.0,
            "retention_fraction_maximum" => 0.01,
            "candidate_bound_burn_rate_required" => true),
        "cryogenic_system" => Dict(
            "cold_temperature_k" => 20.0, "ambient_temperature_k" => 300.0,
            "cold_heat_load_w" => 1.0e5, "second_law_efficiency" => 0.25,
            "heat_load_is_design_input_not_validation" => true),
        "plant_auxiliaries" => Dict(
            "controls_power_w" => 15.0e6, "diagnostics_power_w" => 5.0e6,
            "vacuum_power_w" => 5.0e6, "fuel_cycle_power_w" => 10.0e6,
            "heating_wall_plug_efficiency" => 0.50),
        "control_fault" => Dict(
            "controller_time_step_s" => 1.0e-3,
            "maximum_sensor_latency_s" => 2.0e-3,
            "maximum_actuator_latency_s" => 5.0e-3,
            "controlled_observables" => ["magnetic_axis", "plasma_current", "stored_energy",
                "density", "divertor_target_temperature"],
            "actuator_capabilities" => ["poloidal_field_current", "heating_power",
                "fueling_rate", "impurity_seeding", "fast_shutdown"],
            "required_fault_scenarios" => ["single_pf_coil_trip", "loss_of_coolant_flow",
                "quench", "density_limit_excursion", "vertical_displacement_event"],
            "closed_loop_time_domain_required" => true),
        "numerical_vvuq_contract" => Dict(
            "mesh_levels_required" => 3, "independent_algorithm_required" => true,
            "jacobian_audit_required" => true,
            "parametric_uncertainty_samples_minimum" => 128,
            "uncertain_inputs" => ["density", "temperature", "magnetic_field",
                "material_properties", "transport_coefficients", "component_tolerances"]),
        "validation_observable_contract" => Dict(
            "independent_from_design_solver_required" => true,
            "validation_domain_attestation_required" => true,
            "measurement_uncertainty_required" => true,
            "candidate_bound_external_measurement_available" => false,
            "observables" => ["equilibrium_boundary", "stored_energy", "confinement_time",
                "neutron_rate", "divertor_heat_flux", "coil_current", "structural_strain",
                "coolant_temperature", "net_electric_power"]),
        "identity_fields_used_for_generation" => false,
        "basis_direct_metric_credit" => false,
        "claim_boundary" => WHOLE_DEVICE_ASSEMBLY_V105_CLAIM_BOUNDARY)
    design["physical_design_hash"] = canonical_hash(design)
    design
end

function generate_whole_device_assemblies_v105(candidate_raw; variants::Integer = 64)
    candidate = Dict{String,Any}(_v93_plain(candidate_raw))
    levels = round(Int, cbrt(variants))
    levels^3 == variants || throw(ArgumentError("v105 variants must be a positive cube"))
    levels >= 2 || throw(ArgumentError("v105 requires at least 8 variants"))
    blankets = collect(range(0.55, 0.75; length = levels))
    wetted = collect(range(0.08, 0.20; length = levels))
    efficiencies = collect(range(0.32, 0.46; length = levels))
    results = Dict{String,Any}[]; sequence = 0
    for blanket in blankets, area in wetted, efficiency in efficiencies
        sequence += 1
        design = _v105_design_body(candidate, blanket, area, efficiency, sequence)
        body = Dict{String,Any}(
            "source_candidate_result_hash" => candidate["result_hash"],
            "source_candidate_solver_input_hash" => candidate["solver_input_hash"],
            "physical_design" => design,
            "physical_design_hash" => design["physical_design_hash"],
            "candidate_state" => "whole_device_assembly_proposal",
            "physical_pass_credit" => false, "physical_rejection_credit" => false,
            "validation_credit" => false,
            "unsupported_candidate_classification_used" => false,
            "identity_fields_used_for_generation" => false,
            "claim_boundary" => WHOLE_DEVICE_ASSEMBLY_V105_CLAIM_BOUNDARY)
        body["assembly_result_hash"] = canonical_hash(body)
        push!(results, body)
    end
    results
end

function audit_whole_device_assembly_inputs_v105(assembly_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    design = Dict{String,Any}(assembly["physical_design"])
    blockers = String[]
    for section in V105_REQUIRED_ASSEMBLY_SECTIONS
        haskey(design, section) || push!(blockers, "missing_section:$section")
    end
    if isempty(blockers)
        stack = Dict{String,Any}(design["material_stack"])
        layers = Dict{String,Any}.(stack["layers"])
        declared = Float64(stack["total_plasma_to_wall_build_m"])
        summed = sum(Float64(layer["thickness_m"]) for layer in layers)
        abs(declared - summed) <= 1e-10max(declared, 1.0) ||
            push!(blockers, "radial_material_stack_not_closed")
        all(layer -> Float64(layer["thickness_m"]) > 0, layers) ||
            push!(blockers, "nonpositive_material_layer")
        conductor = Dict{String,Any}(design["finite_conductor"])
        abs(Float64(conductor["wall_to_winding_pack_outer_radius_m"]) -
            Float64(conductor["declared_wall_to_coil_clearance_m"])) <= 1e-10 ||
            push!(blockers, "wall_to_coil_radial_build_not_closed")
        edge = Dict{String,Any}(design["edge_exhaust"])
        Float64(edge["target_wetted_area_m2"]) > 0 ||
            push!(blockers, "nonpositive_divertor_target_area")
        thermal = Dict{String,Any}(design["thermal_cycle"])
        Float64(thermal["mass_flow_kg_s"]) > 0 ||
            push!(blockers, "nonpositive_coolant_mass_flow")
        Float64(thermal["primary_pressure_drop_pa"]) > 0 ||
            push!(blockers, "nonpositive_primary_pressure_drop")
    end
    body = Dict{String,Any}(
        "status" => isempty(blockers) ? "closed" : "invalid",
        "blockers" => sort!(unique(blockers)),
        "required_sections" => V105_REQUIRED_ASSEMBLY_SECTIONS,
        "physical_design_hash" => assembly["physical_design_hash"],
        "structural_closure_only" => true,
        "provider_credit" => false, "physical_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "claim_boundary" => WHOLE_DEVICE_ASSEMBLY_V105_CLAIM_BOUNDARY)
    body["closure_hash"] = canonical_hash(body)
    body
end

function run_whole_device_assembly_generation_v105(project_root::AbstractString;
        variants::Integer = 64)
    root = abspath(project_root)
    preflight = run_whole_device_preflight_v104(root)
    candidates = _v104_load_v100_candidates(root)
    source_hashes = Set(String(row["source_candidate_result_hash"])
        for row in preflight["survivor_rows"])
    source_candidates = [candidate for candidate in values(candidates)
        if candidate["result_hash"] in source_hashes]
    assemblies = Dict{String,Any}[]
    for candidate in source_candidates
        append!(assemblies, generate_whole_device_assemblies_v105(candidate;
            variants = variants))
    end
    closures = [audit_whole_device_assembly_inputs_v105(item) for item in assemblies]
    input_closed = length(closures) == length(assemblies) &&
        all(item -> item["status"] == "closed", closures)
    rows = Dict{String,Any}[]
    for (assembly, closure) in zip(assemblies, closures)
        row = Dict{String,Any}(
            "physical_design_hash" => assembly["physical_design_hash"],
            "assembly_result_hash" => assembly["assembly_result_hash"],
            "input_closure" => closure,
            "candidate_state" => input_closed ? "assembly_input_closed" :
                "assembly_input_invalid",
            "provider_execution_status" => "not_executed_preflight_not_ready",
            "physical_pass_credit" => false, "physical_rejection_credit" => false,
            "validation_credit" => false,
            "unsupported_candidate_classification_used" => false)
        row["row_hash"] = canonical_hash(row); push!(rows, row)
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V105_PROTOCOL_ID,
        "status" => input_closed ? "assembly_inputs_closed" : "assembly_input_failure",
        "source_v104_acceptance_hash" => preflight["acceptance_hash"],
        "source_survivor_count" => length(source_candidates),
        "assembly_proposal_count" => length(assemblies),
        "assembly_input_closed_count" => count(item -> item["status"] == "closed", closures),
        "whole_device_provider_preflight_ready" => preflight["status"] == "ready",
        "whole_device_search_authorized" => preflight["status"] == "ready" && input_closed,
        "unsupported_candidate_count" => 0,
        "physical_reject_count" => 0, "physical_pass_count" => 0,
        "whole_device_credible_count" => 0, "validation_pass_count" => 0,
        "identity_fields_used_for_generation" => false,
        "basis_direct_metric_credit" => false,
        "assembly_rows" => rows,
        "claim_boundary" => WHOLE_DEVICE_ASSEMBLY_V105_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, assemblies
end
