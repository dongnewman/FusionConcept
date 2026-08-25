const _V23_ZPINCH_CLAIM_BOUNDARY =
    "V23 is a failure-directed admission audit for the sealed v20 sheared-flow Z-pinch frontier. The 1995 m=1 shear threshold and 2019 bounded m=0 kinetic calculations are treated as reference-domain checks, not an all-mode stability pass. The 2026 ideal-spectrum disagreement makes candidate-specific non-ideal m=0/m=1 calculations mandatory. The ZaP-HD graphite erosion bracket is used only as an optimistic full-inventory rejection bound; it grants no electrode, sheath, feedthrough, thermal-fatigue, duty-cycle, C1, medium-fidelity, superiority, or reactor credit."

const _V23_NET_EROSION_LOW_KG_C = 1.0e-8
const _V23_NET_EROSION_HIGH_KG_C = 1.0e-7
const _V23_GRAPHITE_DENSITY_KG_M3 = 1800.0
const _V23_SERVICE_INTERVAL_S = 365.25 * 24.0 * 3600.0
const _V23_KA_GRID = (0.05, 0.10, 0.20, 0.40, 0.80, 1.20, 2.00)

struct ZPinchAdmissionContextV23
    v20_context::RecoverableCrossTopologyContextV20
    frontier_records::Vector{Dict{String,Any}}
    parent_genomes::Vector{Genome}
    input_candidate_sha256::String
    frontier_hash::String
end

function build_zpinch_admission_context_v23(
        v20_context::RecoverableCrossTopologyContextV20,
        records::Vector{<:AbstractDict}; input_candidate_sha256::AbstractString)
    frontier = Dict{String,Any}[Dict{String,Any}(record) for record in records
        if String(record["family"]) == "sheared_flow_z_pinch" &&
            Int(record["gate_pass_count"]) == 3]
    sort!(frontier; by = record -> Int(record["candidate_index"]))
    length(frontier) == 336 || throw(ArgumentError(
        "v23 expects the sealed 336-record v20 Z-pinch frontier"))
    parents = Genome[]
    for record in frontier
        reconstructed = evaluate_cross_topology_candidate_v20(v20_context,
            Int(record["candidate_index"]))
        reconstructed.prescreen.compiled.graph_hash == record["graph_hash"] ||
            throw(ArgumentError("v23 parent graph reconstruction drifted"))
        reconstructed.prescreen.compiled.genome.physics_hash ==
            record["physics_hash"] || throw(ArgumentError(
                "v23 parent physics reconstruction drifted"))
        push!(parents, reconstructed.prescreen.compiled.genome)
    end
    frontier_hash = canonical_hash([Dict{String,Any}(
        "candidate_index" => Int(record["candidate_index"]),
        "graph_hash" => String(record["graph_hash"]),
        "physics_hash" => String(record["physics_hash"]),
        "module_ids" => String.(record["module_ids"]),
    ) for record in frontier])
    return ZPinchAdmissionContextV23(v20_context, frontier, parents,
        String(input_candidate_sha256), frontier_hash)
end

function _v23_reference_spectrum(nominal::AbstractDict, field_T::Float64)
    mu0 = 4.0e-7 * pi
    elementary_charge = 1.602176634e-19
    ion_mass = 2.5 * 1.66053906660e-27
    radius = Float64(nominal["plasma_minor_radius_m"])
    half_length = Float64(nominal["plasma_half_height_or_half_length_m"])
    temperature_keV = Float64(nominal["temperature_keV"])
    temperature_eV = 1000.0 * temperature_keV
    alfven_speed = Float64(nominal["alfven_speed_m_s"])
    flow_speed = Float64(nominal["axial_flow_speed_m_s"])
    normalized_shear = Float64(nominal["normalized_flow_shear"])
    axial_wave_number = pi / max(2.0 * half_length, 1.0e-12)
    shear_rate = normalized_shear * axial_wave_number * alfven_speed
    ion_thermal_speed = sqrt(2.0 * temperature_keV * 1.602176634e-16 /
        ion_mass)
    ion_gyro_radius = ion_mass * ion_thermal_speed /
        max(elementary_charge * field_T, 1.0e-30)
    spitzer_resistivity = 1.03e-4 * 15.0 /
        max(temperature_eV^1.5, 1.0e-30)
    magnetic_diffusivity = spitzer_resistivity / mu0
    lundquist_number = radius * alfven_speed /
        max(magnetic_diffusivity, 1.0e-30)
    pic_m0_reference_shear_rate = 0.75 * alfven_speed / radius
    old_m1_reference_passed = normalized_shear >= 0.10
    pic_m0_reference_ratio = shear_rate / pic_m0_reference_shear_rate
    krhoi = Float64[value * ion_gyro_radius / radius for value in _V23_KA_GRID]
    return Dict{String,Any}(
        "fundamental_axial_wave_number_m1" => axial_wave_number,
        "normalized_shear_gene" => normalized_shear,
        "derived_shear_rate_s1" => shear_rate,
        "flow_mach_alfven" => flow_speed / max(alfven_speed, 1.0),
        "old_m1_0p1_kVA_reference_passed" => old_m1_reference_passed,
        "pic_m0_0p75_VA_over_r_reference_ratio" => pic_m0_reference_ratio,
        "pic_m0_reference_domain_overlap" =>
            0.8 <= pic_m0_reference_ratio <= 1.25,
        "m0_pressure_profile_proxy_passed" =>
            Float64(nominal["m0_profile_margin_gene"]) >= 0.50,
        "ion_gyro_radius_m" => ion_gyro_radius,
        "ion_gyro_radius_over_radius" => ion_gyro_radius / radius,
        "spitzer_reference_resistivity_ohm_m" => spitzer_resistivity,
        "spitzer_reference_coulomb_log" => 15.0,
        "lundquist_reference" => lundquist_number,
        "ka_scan" => collect(_V23_KA_GRID),
        "k_rho_i_scan" => krhoi,
        "required_modes" => ["m0_sausage_and_entropy",
            "m1_kink_reflection_and_acoustic_kink"],
        "required_model_branches" => ["ideal_mhd_dispersion_map",
            "resistive_viscous_extended_mhd", "Hall_and_finite_orbit_width",
            "kinetic_short_wavelength_check"],
        "candidate_specific_nonideal_spectrum_available" => false,
        "all_mode_stability_admission_passed" => false,
        "admission_status" =>
            "blocked_by_candidate_specific_nonideal_spectrum_and_model_disagreement",
    )
end

function _v23_electrode_lifetime(nominal::AbstractDict, genome::Genome)
    radius = Float64(nominal["plasma_minor_radius_m"])
    current = Float64(nominal["plasma_current_A"])
    pulse_duration = Float64(nominal["pulse_duration_s"])
    repetition_rate = Float64(nominal["repetition_rate_Hz"])
    electrode_build = _mev10_value(genome, nothing,
        "screen_z_electrode_build", 0.25, "m")
    full_inventory = 2.0 * pi * radius^2 * electrode_build *
        _V23_GRAPHITE_DENSITY_KG_M3
    charge_per_pulse = current * pulse_duration
    annual_charge = charge_per_pulse * repetition_rate *
        _V23_SERVICE_INTERVAL_S
    optimistic_annual_loss = _V23_NET_EROSION_LOW_KG_C * annual_charge
    pessimistic_annual_loss = _V23_NET_EROSION_HIGH_KG_C * annual_charge
    repetitive = repetition_rate > 0.0
    optimistic_years = repetitive ? full_inventory /
        max(optimistic_annual_loss, 1.0e-30) : nothing
    pessimistic_years = repetitive ? full_inventory /
        max(pessimistic_annual_loss, 1.0e-30) : nothing
    optimistic_inventory_pass = repetitive ?
        optimistic_annual_loss <= full_inventory : nothing
    hard_rejected = !repetitive || optimistic_inventory_pass === false
    status = !repetitive ? "rejected_no_repetitive_plant_operation" :
        optimistic_inventory_pass === false ?
            "rejected_even_with_low_erosion_and_full_inventory_removal" :
            "unknown_within_optimistic_mass_inventory_bound"
    return Dict{String,Any}(
        "graphite_density_kg_m3" => _V23_GRAPHITE_DENSITY_KG_M3,
        "two_electrode_full_solid_inventory_upper_bound_kg" => full_inventory,
        "plasma_current_A" => current,
        "pulse_duration_s" => pulse_duration,
        "repetition_rate_Hz" => repetition_rate,
        "charge_per_pulse_C" => charge_per_pulse,
        "one_year_charge_C" => annual_charge,
        "measured_net_erosion_bracket_kg_C" => [
            _V23_NET_EROSION_LOW_KG_C, _V23_NET_EROSION_HIGH_KG_C],
        "one_year_loss_bracket_kg" => [optimistic_annual_loss,
            pessimistic_annual_loss],
        "full_inventory_lifetime_bracket_years" => [pessimistic_years,
            optimistic_years],
        "repetitive_operation_declared" => repetitive,
        "optimistic_full_inventory_one_year_gate" =>
            optimistic_inventory_pass,
        "hard_rejection_credit" => hard_rejected,
        "thermal_cycle_evidence_available" => false,
        "electrode_sheath_evidence_available" => false,
        "feedthrough_lifetime_evidence_available" => false,
        "candidate_specific_electrode_admission_passed" => false,
        "admission_status" => status,
        "bound_warning" =>
            "Using the low measured net-erosion coefficient and allowing removal of the entire idealized solid inventory is intentionally optimistic; a pass grants no lifetime credit.",
    )
end

function evaluate_zpinch_admission_candidate_v23(
        context::ZPinchAdmissionContextV23, local_index::Integer)
    1 <= local_index <= length(context.frontier_records) ||
        throw(BoundsError(context.frontier_records, local_index))
    parent_record = context.frontier_records[Int(local_index)]
    genome = context.parent_genomes[Int(local_index)]
    evaluator = context.v20_context.evaluators[
        "mechanism_expansion_screen_v1"]
    result = _mechanism_expansion_result(evaluator, genome)
    nominal = result["nominal"]
    field_T = context.v20_context.compiler_context.outer.plasma_field_T
    spectrum = _v23_reference_spectrum(nominal, field_T)
    electrode = _v23_electrode_lifetime(nominal, genome)
    modules = String.(parent_record["module_ids"])
    blockers = String[
        "candidate_specific_nonideal_m0_m1_spectrum",
        "model_disagreement_resolution",
        "electrode_thermal_cycle_evidence",
        "electrode_sheath_evidence",
        "feedthrough_lifetime_evidence",
    ]
    hard_reasons = String[]
    electrode["repetitive_operation_declared"] === true ||
        push!(hard_reasons, "no_repetitive_plant_operation")
    electrode["optimistic_full_inventory_one_year_gate"] === false &&
        push!(hard_reasons, "optimistic_graphite_inventory_lifetime")
    return Dict{String,Any}(
        "local_index" => Int(local_index),
        "candidate_index" => Int(parent_record["candidate_index"]),
        "graph_hash" => String(parent_record["graph_hash"]),
        "physics_hash" => String(parent_record["physics_hash"]),
        "module_ids" => modules,
        "descriptor" => join((modules[2], modules[3], modules[5]), "|"),
        "v20_gates" => Dict{String,Bool}(String(key) => Bool(value)
            for (key, value) in parent_record["gates"]),
        "reference_spectrum_audit" => spectrum,
        "electrode_lifetime_audit" => electrode,
        "hard_rejection_reasons" => hard_reasons,
        "hard_rejection_count" => length(hard_reasons),
        "blocking_unknowns" => blockers,
        "admission_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => false,
        "claim_boundary" => _V23_ZPINCH_CLAIM_BOUNDARY,
    )
end

function recoverable_zpinch_admission_spec_v23(
        context::ZPinchAdmissionContextV23;
        run_id::AbstractString = "zpinch_nonideal_electrode_audit_v23",
        shard_size::Integer = 10, source_sha256::AbstractString,
        evidence_sha256::AbstractString)
    return RecoverableRunSpecV19(String(run_id),
        "zpinch_nonideal_electrode_admission_audit", "23.0.0",
        length(context.frontier_records), Int(shard_size); max_retries = 2,
        max_retained_per_shard = Int(shard_size),
        kernel_config = Dict{String,Any}(
            "input_candidate_sha256" => context.input_candidate_sha256,
            "frontier_hash" => context.frontier_hash,
            "frontier_count" => length(context.frontier_records),
            "v23_source_sha256" => String(source_sha256),
            "v23_evidence_sha256" => String(evidence_sha256),
            "net_erosion_bracket_kg_C" => [
                _V23_NET_EROSION_LOW_KG_C, _V23_NET_EROSION_HIGH_KG_C],
            "service_interval_s" => _V23_SERVICE_INTERVAL_S,
            "retain_all" => true,
            "credit" => "rejection_or_blocking_unknown_only",
        ))
end

function recoverable_zpinch_admission_kernel_v23(
        context::ZPinchAdmissionContextV23)
    return function(local_index, config)
        record = evaluate_zpinch_admission_candidate_v23(context, local_index)
        return RecoverableKernelOutcomeV19(record, true)
    end
end

function _v23_zpinch_rank(record::AbstractDict)
    spectrum = record["reference_spectrum_audit"]
    electrode = record["electrode_lifetime_audit"]
    lifetime = electrode["full_inventory_lifetime_bracket_years"][2]
    optimistic_years = lifetime === nothing ? 0.0 : Float64(lifetime)
    return (Int(record["hard_rejection_count"]),
        spectrum["old_m1_0p1_kVA_reference_passed"] === true ? 0 : 1,
        abs(log10(max(Float64(
            spectrum["pic_m0_0p75_VA_over_r_reference_ratio"]), 1.0e-99))),
        -min(optimistic_years, 1.0e12), Int(record["candidate_index"]))
end

function zpinch_failure_directed_archive_v23(records::Vector{<:AbstractDict})
    cells = Dict{String,Dict{String,Any}}()
    for record in records
        key = String(record["descriptor"])
        item = Dict{String,Any}(record)
        if !haskey(cells, key) ||
                _v23_zpinch_rank(item) < _v23_zpinch_rank(cells[key])
            cells[key] = item
        end
    end
    return sort!(collect(values(cells));
        by = record -> String(record["descriptor"]))
end
