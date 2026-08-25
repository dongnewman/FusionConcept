const _V26_KA_GRID = (0.05, 0.10, 0.20, 0.40, 0.80, 1.20, 2.00,
    3.00, 5.00, 7.50, 10.00)

const _V26_ZPINCH_CLAIM_BOUNDARY =
    "V26 computes candidate-specific non-ideal scale coverage for every sealed v24 pulsed Z-pinch child and separates solid-graphite from flowing-liquid-metal boundary admission inputs. The computed Lundquist, magnetic-Reynolds, Hall, finite-orbit-width, Mach, shear, pulse, and wavelength scales are dimensional-analysis inputs only: no complex growth-rate spectrum is solved. Every ideal, resistive-viscous, Hall/FOW, and kinetic branch therefore remains unresolved. Boundary ledgers preserve optimistic inventory rejection but grant no sheath, redeposition, thermal-fatigue, free-surface, corrosion, pumping, feedthrough, C1, medium-fidelity, superiority, lifetime, or reactor credit."

struct CandidateSpecificZPinchContextV26
    v24_context::MissionConsistentZPinchContextV24
    input_candidate_sha256::String
    frontier_hash::String
end

function build_candidate_specific_zpinch_context_v26(
        v20_context::RecoverableCrossTopologyContextV20,
        records::Vector{<:AbstractDict}; input_candidate_sha256::AbstractString)
    v24 = build_mission_consistent_zpinch_context_v24(v20_context, records;
        input_candidate_sha256 = input_candidate_sha256)
    return CandidateSpecificZPinchContextV26(v24,
        String(input_candidate_sha256), v24.frontier_hash)
end

function _v26_candidate_scale_coverage(nominal::AbstractDict)
    mu0 = 4.0e-7 * pi
    elementary_charge = 1.602176634e-19
    ion_mass = 2.5 * 1.66053906660e-27
    radius = Float64(nominal["plasma_minor_radius_m"])
    half_length = Float64(nominal["plasma_half_height_or_half_length_m"])
    density = Float64(nominal["density_m3"])
    temperature_keV = Float64(nominal["temperature_keV"])
    temperature_eV = 1000.0 * temperature_keV
    alfven_speed = Float64(nominal["alfven_speed_m_s"])
    flow_speed = Float64(nominal["axial_flow_speed_m_s"])
    normalized_shear = Float64(nominal["normalized_flow_shear"])
    current = Float64(nominal["plasma_current_A"])
    pulse_duration = Float64(nominal["pulse_duration_s"])
    repetition_rate = Float64(nominal["repetition_rate_Hz"])
    field_T = mu0 * current / max(2.0 * pi * radius, 1.0e-30)
    fundamental_k = pi / max(2.0 * half_length, 1.0e-30)
    shear_rate = normalized_shear * fundamental_k * alfven_speed
    ion_thermal_speed = sqrt(2.0 * temperature_keV * 1.602176634e-16 /
        ion_mass)
    ion_gyro_radius = ion_mass * ion_thermal_speed /
        max(elementary_charge * field_T, 1.0e-30)
    ion_skin_depth = sqrt(ion_mass /
        max(mu0 * density * elementary_charge^2, 1.0e-60))
    spitzer_resistivity = 1.03e-4 * 15.0 /
        max(temperature_eV^1.5, 1.0e-30)
    magnetic_diffusivity = spitzer_resistivity / mu0
    alfven_time = radius / max(alfven_speed, 1.0e-30)
    resistive_time = radius^2 / max(magnetic_diffusivity, 1.0e-30)
    lundquist = resistive_time / max(alfven_time, 1.0e-30)
    magnetic_reynolds = abs(flow_speed) * radius /
        max(magnetic_diffusivity, 1.0e-30)
    mach = flow_speed / max(alfven_speed, 1.0e-30)
    pic_ratio = shear_rate /
        max(0.75 * alfven_speed / radius, 1.0e-30)
    scan = Dict{String,Any}[]
    for ka in _V26_KA_GRID
        push!(scan, Dict{String,Any}(
            "ka" => ka,
            "k_m1" => ka / radius,
            "wavelength_over_radius" => 2.0 * pi / ka,
            "k_rho_i" => ka * ion_gyro_radius / radius,
            "k_d_i" => ka * ion_skin_depth / radius,
        ))
    end
    branches = Dict{String,Any}(
        "ideal_mhd_dispersion_map" => Dict{String,Any}(
            "computed_inputs" => ["ka_scan", "alfven_mach", "shear_rate"],
            "missing_inputs" => ["candidate_radial_equilibrium_profiles",
                "candidate_velocity_profile", "electrode_and_wall_boundary_conditions",
                "complex_frequency_dispersion_solver"],
            "status" => "coverage_only_unresolved"),
        "resistive_viscous_extended_mhd" => Dict{String,Any}(
            "computed_inputs" => ["spitzer_reference_resistivity",
                "lundquist_number", "magnetic_reynolds_number"],
            "missing_inputs" => ["candidate_viscosity_and_transport_closure",
                "radial_temperature_and_density_profiles",
                "three_dimensional_nonideal_eigenvalue_solver"],
            "status" => "coverage_only_unresolved"),
        "Hall_and_finite_orbit_width" => Dict{String,Any}(
            "computed_inputs" => ["ion_skin_depth_over_radius",
                "ion_gyro_radius_over_radius", "k_d_i_scan", "k_rho_i_scan"],
            "missing_inputs" => ["two_fluid_equilibrium_profiles",
                "pressure_tensor_and_heat_flux_closure",
                "Hall_FOW_complex_growth_rate_solver"],
            "status" => "coverage_only_unresolved"),
        "kinetic_short_wavelength_check" => Dict{String,Any}(
            "computed_inputs" => ["k_rho_i_scan", "alfven_mach"],
            "missing_inputs" => ["candidate_distribution_functions",
                "collision_operator", "kinetic_electrode_boundary_model",
                "candidate_specific_kinetic_growth_rate_scan"],
            "status" => "coverage_only_unresolved"),
    )
    missing = sort!(unique!(reduce(vcat,
        [String.(branch["missing_inputs"]) for branch in values(branches)])))
    return Dict{String,Any}(
        "candidate_specific_scale_matrix_available" => true,
        "candidate_specific_nonideal_spectrum_available" => false,
        "resolved_model_branch_count" => 0,
        "required_model_branch_count" => length(branches),
        "all_mode_stability_admission_passed" => false,
        "geometry_and_state" => Dict{String,Any}(
            "plasma_radius_m" => radius,
            "plasma_half_length_m" => half_length,
            "density_m3" => density,
            "temperature_keV" => temperature_keV,
            "azimuthal_field_T" => field_T,
            "plasma_current_A" => current,
            "pulse_duration_s" => pulse_duration,
            "repetition_rate_Hz" => repetition_rate),
        "derived_scales" => Dict{String,Any}(
            "fundamental_axial_wave_number_m1" => fundamental_k,
            "fundamental_ka" => fundamental_k * radius,
            "normalized_shear_gene" => normalized_shear,
            "derived_shear_rate_s1" => shear_rate,
            "flow_mach_alfven" => mach,
            "ion_thermal_speed_m_s" => ion_thermal_speed,
            "ion_gyro_radius_m" => ion_gyro_radius,
            "ion_gyro_radius_over_radius" => ion_gyro_radius / radius,
            "ion_skin_depth_m" => ion_skin_depth,
            "ion_skin_depth_over_radius" => ion_skin_depth / radius,
            "spitzer_reference_resistivity_ohm_m" => spitzer_resistivity,
            "spitzer_reference_coulomb_log" => 15.0,
            "magnetic_diffusivity_m2_s" => magnetic_diffusivity,
            "alfven_transit_time_s" => alfven_time,
            "resistive_diffusion_time_s" => resistive_time,
            "lundquist_number" => lundquist,
            "magnetic_reynolds_number" => magnetic_reynolds,
            "pulse_over_alfven_time" => pulse_duration / max(alfven_time, 1.0e-30)),
        "reference_domain_checks" => Dict{String,Any}(
            "old_m1_0p1_kVA_reference_passed" => normalized_shear >= 0.10,
            "pic_m0_0p75_VA_over_r_reference_ratio" => pic_ratio,
            "pic_m0_reference_domain_overlap" => 0.8 <= pic_ratio <= 1.25,
            "pic_m0_flow_mach_no_greater_than_one" => mach <= 1.0,
            "m0_pressure_profile_proxy_passed" =>
                Float64(nominal["m0_profile_margin_gene"]) >= 0.50,
            "credit" => "reference_domain_overlap_only"),
        "dimensionless_scan" => scan,
        "model_branch_ledger" => branches,
        "blocking_missing_inputs" => missing,
        "admission_status" => "blocked_until_candidate_specific_complex_growth_rates_are_solved",
    )
end

function _v26_solid_boundary_bridge(nominal::AbstractDict, genome::Genome)
    inventory = _v23_electrode_lifetime(nominal, genome)
    missing = ["candidate_electrode_grade_and_temperature_dependent_properties",
        "plasma_sheath_heat_and_particle_partition",
        "gross_erosion_redeposition_and_net_loss_map",
        "electrode_internal_temperature_history",
        "thermal_stress_and_crack_growth_law",
        "contact_resistance_and_feedthrough_temperature",
        "replacement_availability_and_remote_maintenance_model"]
    inventory_pass = inventory["optimistic_full_inventory_one_year_gate"]
    return Dict{String,Any}(
        "boundary" => "replaceable_solid_graphite",
        "candidate_specific_input_ledger_available" => true,
        "candidate_specific_boundary_admission_passed" => false,
        "computed_inputs" => Dict{String,Any}(
            "plasma_current_A" => nominal["plasma_current_A"],
            "engineering_current_density_A_mm2" =>
                nominal["engineering_current_density_A_mm2"],
            "pulse_duration_s" => nominal["pulse_duration_s"],
            "repetition_rate_Hz" => nominal["repetition_rate_Hz"],
            "duty_cycle" => nominal["duty_cycle"],
            "electrode_pulse_surface_loading_J_m2" =>
                nominal["electrode_pulse_surface_loading_J_m2"],
            "charge_per_pulse_C" => inventory["charge_per_pulse_C"],
            "one_year_charge_C" => inventory["one_year_charge_C"],
            "two_electrode_full_solid_inventory_upper_bound_kg" =>
                inventory["two_electrode_full_solid_inventory_upper_bound_kg"],
            "full_inventory_lifetime_bracket_years" =>
                inventory["full_inventory_lifetime_bracket_years"]),
        "optimistic_inventory_bound" => inventory,
        "missing_inputs" => missing,
        "hard_rejection_credit" => inventory_pass === false,
        "admission_status" => inventory_pass === false ?
            "rejected_even_by_optimistic_full_inventory_bound" :
            "blocked_by_sheath_thermal_fatigue_feedthrough_and_maintenance_unknowns",
    )
end

function _v26_liquid_boundary_bridge(nominal::AbstractDict)
    missing = ["liquid_metal_composition", "temperature_dependent_conductivity",
        "temperature_dependent_density_and_viscosity", "surface_tension",
        "film_thickness_and_velocity_profile", "wetted_electrode_geometry",
        "free_surface_mhd_stability_model", "plasma_sheath_heat_partition",
        "corrosion_and_mass_transfer_pairing", "pressure_drop_and_pump_curve",
        "feedthrough_lifetime", "drain_catch_and_off_normal_inventory_control"]
    return Dict{String,Any}(
        "boundary" => "flowing_liquid_metal",
        "candidate_specific_input_ledger_available" => true,
        "candidate_specific_boundary_admission_passed" => false,
        "computed_inputs" => Dict{String,Any}(
            "plasma_current_A" => nominal["plasma_current_A"],
            "engineering_current_density_A_mm2" =>
                nominal["engineering_current_density_A_mm2"],
            "pulse_duration_s" => nominal["pulse_duration_s"],
            "repetition_rate_Hz" => nominal["repetition_rate_Hz"],
            "duty_cycle" => nominal["duty_cycle"],
            "electrode_pulse_surface_loading_J_m2" =>
                nominal["electrode_pulse_surface_loading_J_m2"],
            "declared_actuator_power_W" => nominal["declared_actuator_power_W"]),
        "reference_component_control" => Dict{String,Any}(
            "name" => "Century_nonreacting_hydrogen_approximately_0p1_Hz_100_kW_class",
            "candidate_repetition_over_0p1_Hz" =>
                Float64(nominal["repetition_rate_Hz"]) / 0.1,
            "like_for_like_power_comparison_available" => false,
            "credit" => "integration_control_point_only_not_boundary_admission"),
        "missing_inputs" => missing,
        "hard_rejection_credit" => false,
        "admission_status" =>
            "blocked_by_material_free_surface_corrosion_pumping_and_feedthrough_unknowns",
    )
end

function _v26_mach_bin(value::Real)
    value < 0.5 && return "M_lt_0p5"
    value <= 1.0 && return "M_0p5_to_1"
    value <= 2.0 && return "M_1_to_2"
    return "M_gt_2"
end

function _v26_order_bin(value::Real, prefix::AbstractString)
    exponent = floor(Int, log10(max(abs(Float64(value)), 1.0e-300)))
    return "$(prefix)_1e$(exponent)"
end

function evaluate_candidate_specific_zpinch_v26(
        context::CandidateSpecificZPinchContextV26, global_index::Integer)
    v24_record = evaluate_mission_consistent_zpinch_candidate_v24(
        context.v24_context, global_index)
    v23 = context.v24_context.v23_context
    parent_position, boundary, values = _v24_zpinch_gene_spec(
        Int(global_index), length(v23.frontier_records))
    genome = build_mission_consistent_zpinch_genome_v24(
        v23.parent_genomes[parent_position], boundary, values)
    evaluator = v23.v20_context.evaluators["mechanism_expansion_screen_v1"]
    result = _mechanism_expansion_result(evaluator, genome)
    nominal = result["nominal"]
    genome.physics_hash == v24_record["child_physics_hash"] ||
        error("v26 reconstruction drifted from sealed v24 child")
    spectrum = _v26_candidate_scale_coverage(nominal)
    boundary_bridge = boundary == "replaceable_solid_graphite" ?
        _v26_solid_boundary_bridge(nominal, genome) :
        _v26_liquid_boundary_bridge(nominal)
    scales = spectrum["derived_scales"]
    descriptor = join((boundary,
        _v26_mach_bin(scales["flow_mach_alfven"]),
        _v26_order_bin(scales["lundquist_number"], "S"),
        _v26_order_bin(scales["ion_skin_depth_over_radius"], "di_over_a"),
        _v26_order_bin(scales["ion_gyro_radius_over_radius"], "rhoi_over_a")), "|")
    blockers = String.(spectrum["blocking_missing_inputs"])
    append!(blockers, String.(boundary_bridge["missing_inputs"]))
    sort!(unique!(blockers))
    return Dict{String,Any}(
        "global_index" => Int(global_index),
        "parent_position" => parent_position,
        "boundary" => boundary,
        "descriptor" => descriptor,
        "child_design_id" => genome.design_id,
        "child_physics_hash" => genome.physics_hash,
        "mission_contract_id" => v24_record["mission_contract_id"],
        "parent_module_ids" => v24_record["parent_module_ids"],
        "horizontal_gates" => v24_record["horizontal_gates"],
        "horizontal_five_gate_passed" =>
            v24_record["horizontal_five_gate_passed"],
        "positive_net_power_closure" =>
            v24_record["positive_net_power_closure"],
        "robustness_pass_fraction" => v24_record["robustness_pass_fraction"],
        "candidate_specific_spectrum_coverage" => spectrum,
        "boundary_admission_bridge" => boundary_bridge,
        "inherited_v24_hard_rejection_reasons" =>
            v24_record["hard_rejection_reasons"],
        "hard_rejection_count" => v24_record["hard_rejection_count"],
        "blocking_unknowns" => blockers,
        "admission_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => false,
        "claim_boundary" => _V26_ZPINCH_CLAIM_BOUNDARY,
    )
end

function recoverable_candidate_specific_zpinch_spec_v26(
        context::CandidateSpecificZPinchContextV26;
        run_id::AbstractString = "zpinch_candidate_specific_coverage_v26",
        shard_size::Integer = 12, source_sha256::AbstractString)
    total = length(context.v24_context.v23_context.frontier_records) *
        length(_V24_ZPINCH_BOUNDARIES)
    return RecoverableRunSpecV19(String(run_id),
        "zpinch_candidate_specific_scale_and_boundary_coverage", "26.0.0",
        total, Int(shard_size); max_retries = 2,
        max_retained_per_shard = Int(shard_size),
        kernel_config = Dict{String,Any}(
            "input_candidate_sha256" => context.input_candidate_sha256,
            "frontier_hash" => context.frontier_hash,
            "parent_count" => length(
                context.v24_context.v23_context.frontier_records),
            "boundaries" => collect(_V24_ZPINCH_BOUNDARIES),
            "ka_grid" => collect(_V26_KA_GRID),
            "v26_source_sha256" => String(source_sha256),
            "retain_all" => true,
            "credit" => "candidate_specific_scale_coverage_and_rejection_only"))
end

function recoverable_candidate_specific_zpinch_kernel_v26(
        context::CandidateSpecificZPinchContextV26)
    return function(global_index, config)
        record = evaluate_candidate_specific_zpinch_v26(context, global_index)
        return RecoverableKernelOutcomeV19(record, true)
    end
end

function _v26_rank(record::AbstractDict)
    coverage = record["candidate_specific_spectrum_coverage"]
    checks = coverage["reference_domain_checks"]
    bridge = record["boundary_admission_bridge"]
    return (Int(record["hard_rejection_count"]),
        checks["pic_m0_reference_domain_overlap"] === true ? 0 : 1,
        checks["pic_m0_flow_mach_no_greater_than_one"] === true ? 0 : 1,
        bridge["hard_rejection_credit"] === true ? 1 : 0,
        -Float64(record["robustness_pass_fraction"]),
        Int(record["global_index"]))
end

function candidate_specific_zpinch_qd_archive_v26(
        records::Vector{<:AbstractDict})
    cells = Dict{String,Dict{String,Any}}()
    for record in records
        key = String(record["descriptor"])
        item = Dict{String,Any}(record)
        if !haskey(cells, key) || _v26_rank(item) < _v26_rank(cells[key])
            cells[key] = item
        end
    end
    return sort!(collect(values(cells));
        by = record -> String(record["descriptor"]))
end
