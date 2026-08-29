const V106_PROTOCOL_ID = "fusionconceptai-v106-whole-device-assembly-screen-20260829"

const WHOLE_DEVICE_ASSEMBLY_SCREEN_V106_CLAIM_BOUNDARY =
    "v106 is a candidate-bound reduced assembly rejection screen. Failed gates reject the " *
    "specific assembly proposal; a screen survivor receives no complete stability, transport, " *
    "engineering, numerical-VVUQ, validation, credibility, or device-pass credit. Grid " *
    "coordinates only supplied physical inputs and never supplied metrics."

const V106_SCREEN_LIMITS = Dict{String,Float64}(
    "minimum_first_wall_thickness_m" => 0.02,
    "minimum_blanket_thickness_m" => 0.65,
    "minimum_shield_thickness_m" => 0.30,
    "maximum_divertor_heat_flux_w_m2" => 10.0e6,
    "minimum_net_electric_power_w" => 100.0e6,
    "maximum_peak_field_t" => 16.0,
    "maximum_engineering_current_density_a_m2" => 50.0e6,
    "maximum_support_stress_pa" => 650.0e6,
    "minimum_tbr_design_target" => 1.10,
    "minimum_fuel_processing_margin" => 2.0,
)

function _v106_gate(id, value, threshold, passed, unit)
    Dict{String,Any}(
        "gate_id" => String(id), "status" => passed ? "pass" : "fail",
        "value" => value, "threshold" => threshold, "unit" => String(unit))
end

function screen_whole_device_assembly_v106(assembly_raw, source_candidate_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    candidate = Dict{String,Any}(_v93_plain(source_candidate_raw))
    closure = audit_whole_device_assembly_inputs_v105(assembly)
    closure["status"] == "closed" || throw(ArgumentError(
        "v106 requires a structurally closed v105 assembly"))
    design = Dict{String,Any}(assembly["physical_design"])
    physics = Dict{String,Any}(candidate["physics_solve"])
    metrics = Dict{String,Any}(physics["metrics"])
    engineering = Dict{String,Any}(candidate["engineering_prefilter"])
    engineering_metrics = Dict{String,Any}(engineering["metrics"])
    layers = Dict(String(item["role"]) => Dict{String,Any}(item)
        for item in Dict{String,Any}.(design["material_stack"]["layers"]))
    first_wall = Float64(layers["first_wall"]["thickness_m"])
    blanket = Float64(layers["breeding_blanket"]["thickness_m"])
    shield = Float64(layers["neutron_shield"]["thickness_m"])
    target_area = Float64(design["edge_exhaust"]["target_wetted_area_m2"])
    exhaust_heat_flux = Float64(metrics["transport_loss_power_w"]) / target_area
    thermal = Dict{String,Any}(design["thermal_cycle"])
    auxiliaries = Dict{String,Any}(design["plant_auxiliaries"])
    cryogenic = Dict{String,Any}(design["cryogenic_system"])
    gross_electric = Float64(thermal["recoverable_heat_input_w"]) *
        Float64(thermal["gross_thermal_efficiency"])
    pump_power = Float64(thermal["mass_flow_kg_s"]) *
        Float64(thermal["primary_pressure_drop_pa"]) /
        (Float64(thermal["coolant_density_kg_m3"]) *
            Float64(thermal["pump_efficiency"]))
    cold = Float64(cryogenic["cold_temperature_k"])
    ambient = Float64(cryogenic["ambient_temperature_k"])
    cryogenic_power = Float64(cryogenic["cold_heat_load_w"]) *
        (ambient / cold - 1) / Float64(cryogenic["second_law_efficiency"])
    heating_wall_power = Float64(metrics["required_auxiliary_power_w"]) /
        Float64(auxiliaries["heating_wall_plug_efficiency"])
    fixed_auxiliary = sum(Float64(auxiliaries[key]) for key in
        ("controls_power_w", "diagnostics_power_w", "vacuum_power_w",
            "fuel_cycle_power_w"))
    recirculating = pump_power + cryogenic_power + heating_wall_power + fixed_auxiliary
    net_electric = gross_electric - recirculating
    fusion_energy_j = 17.6e6 * 1.602176634e-19
    reaction_rate = Float64(metrics["fusion_power_w"]) / fusion_energy_j
    fuel = Dict{String,Any}(design["fuel_cycle"])
    processing_margin = Float64(fuel["processing_capacity_particles_s"]) /
        max(2reaction_rate, eps())
    tbr_target = Float64(fuel["tritium_breeding_ratio_minimum"])
    peak_field = Float64(engineering_metrics["additive_peak_field_t"])
    current_density = Float64(engineering_metrics["pf_current_density_a_m2"])
    support_stress = Float64(engineering_metrics["membrane_support_stress_pa"])
    gates = Dict{String,Any}[
        _v106_gate("first_wall_thickness", first_wall,
            V106_SCREEN_LIMITS["minimum_first_wall_thickness_m"],
            first_wall >= V106_SCREEN_LIMITS["minimum_first_wall_thickness_m"], "m"),
        _v106_gate("blanket_thickness", blanket,
            V106_SCREEN_LIMITS["minimum_blanket_thickness_m"],
            blanket >= V106_SCREEN_LIMITS["minimum_blanket_thickness_m"], "m"),
        _v106_gate("shield_thickness", shield,
            V106_SCREEN_LIMITS["minimum_shield_thickness_m"],
            shield >= V106_SCREEN_LIMITS["minimum_shield_thickness_m"], "m"),
        _v106_gate("divertor_heat_flux", exhaust_heat_flux,
            V106_SCREEN_LIMITS["maximum_divertor_heat_flux_w_m2"],
            exhaust_heat_flux <= V106_SCREEN_LIMITS["maximum_divertor_heat_flux_w_m2"],
            "W/m^2"),
        _v106_gate("net_electric_power", net_electric,
            V106_SCREEN_LIMITS["minimum_net_electric_power_w"],
            net_electric >= V106_SCREEN_LIMITS["minimum_net_electric_power_w"], "W"),
        _v106_gate("peak_field", peak_field,
            V106_SCREEN_LIMITS["maximum_peak_field_t"],
            peak_field <= V106_SCREEN_LIMITS["maximum_peak_field_t"], "T"),
        _v106_gate("engineering_current_density", current_density,
            V106_SCREEN_LIMITS["maximum_engineering_current_density_a_m2"],
            current_density <=
                V106_SCREEN_LIMITS["maximum_engineering_current_density_a_m2"], "A/m^2"),
        _v106_gate("support_stress", support_stress,
            V106_SCREEN_LIMITS["maximum_support_stress_pa"],
            support_stress <= V106_SCREEN_LIMITS["maximum_support_stress_pa"], "Pa"),
        _v106_gate("tbr_design_target", tbr_target,
            V106_SCREEN_LIMITS["minimum_tbr_design_target"],
            tbr_target >= V106_SCREEN_LIMITS["minimum_tbr_design_target"], "1"),
        _v106_gate("fuel_processing_margin", processing_margin,
            V106_SCREEN_LIMITS["minimum_fuel_processing_margin"],
            processing_margin >= V106_SCREEN_LIMITS["minimum_fuel_processing_margin"], "1"),
    ]
    passed = all(gate -> gate["status"] == "pass", gates)
    outputs = Dict{String,Any}(
        "exhaust_heat_flux_w_m2" => exhaust_heat_flux,
        "gross_electric_power_w" => gross_electric,
        "primary_pump_power_w" => pump_power,
        "cryogenic_wall_power_w" => cryogenic_power,
        "heating_wall_power_w" => heating_wall_power,
        "fixed_auxiliary_power_w" => fixed_auxiliary,
        "recirculating_power_w" => recirculating,
        "net_electric_power_w" => net_electric,
        "fusion_reaction_rate_s" => reaction_rate,
        "fuel_processing_margin" => processing_margin,
        "peak_field_t" => peak_field,
        "engineering_current_density_a_m2" => current_density,
        "support_stress_pa" => support_stress)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V106_PROTOCOL_ID,
        "physical_design_hash" => assembly["physical_design_hash"],
        "status" => passed ? "pass" : "fail",
        "candidate_state" => passed ? "whole_device_screen_survivor" :
            "whole_device_assembly_reject",
        "outputs" => outputs, "gates" => gates,
        "failed_gates" => String[gate["gate_id"] for gate in gates if
            gate["status"] == "fail"],
        "whole_device_pass_credit" => false,
        "validation_credit" => false,
        "basis_direct_metric_credit" => false,
        "identity_fields_used_for_routing" => false,
        "unsupported_candidate_classification_used" => false,
        "evidence_ceiling" => "candidate_bound_reduced_whole_device_assembly_screen",
        "claim_boundary" => WHOLE_DEVICE_ASSEMBLY_SCREEN_V106_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body)
    body
end

function run_whole_device_assembly_screen_v106(project_root::AbstractString)
    root = abspath(project_root)
    generation, assemblies = run_whole_device_assembly_generation_v105(root)
    generation["status"] == "assembly_inputs_closed" || throw(ArgumentError(
        "v106 requires closed v105 assembly inputs"))
    candidates = _v104_load_v100_candidates(root)
    candidate_by_hash = Dict(String(item["result_hash"]) => item for item in values(candidates))
    rows = [screen_whole_device_assembly_v106(item,
        candidate_by_hash[String(item["source_candidate_result_hash"])]) for item in assemblies]
    histogram = Dict{String,Int}()
    blockers = Dict{String,Int}()
    for row in rows
        state = String(row["candidate_state"])
        histogram[state] = get(histogram, state, 0) + 1
        for gate in String.(row["failed_gates"])
            blockers[gate] = get(blockers, gate, 0) + 1
        end
    end
    survivors = [row for row in rows if row["status"] == "pass"]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V106_PROTOCOL_ID,
        "status" => "complete",
        "source_v105_acceptance_hash" => generation["acceptance_hash"],
        "assembly_count" => length(rows),
        "candidate_state_histogram" => Dict(sort!(collect(histogram))),
        "blocker_histogram" => Dict(sort!(collect(blockers))),
        "screen_survivor_count" => length(survivors),
        "assembly_reject_count" => count(row -> row["status"] == "fail", rows),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "whole_device_pass_count" => 0, "whole_device_credible_count" => 0,
        "validation_pass_count" => 0,
        "whole_device_high_fidelity_search_authorized" => false,
        "identity_fields_used_for_routing" => false,
        "basis_direct_metric_credit" => false,
        "rows" => rows,
        "claim_boundary" => WHOLE_DEVICE_ASSEMBLY_SCREEN_V106_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body, survivors
end
