const _V24_ZPINCH_BOUNDARIES = (
    "replaceable_solid_graphite",
    "flowing_liquid_metal",
)

const _V24_ZPINCH_CLAIM_BOUNDARY =
    "V24 repairs the v23 mission mismatch by constructing pulsed net-electric Z-pinch children with explicit nonzero repetition, candidate-scaled shear, accelerator authority, and solid-graphite versus flowing-liquid-metal boundary branches. Existing v10 horizontal gates remain binding. The m=0 PIC scale is a reference-domain precondition, never an all-mode stability pass. A solid-inventory pass or liquid-metal hypothesis is not electrode, sheath, corrosion, free-surface, feedthrough, thermal-fatigue, availability, C1, medium-fidelity, superiority, or reactor credit."

struct MissionConsistentZPinchContextV24
    v23_context::ZPinchAdmissionContextV23
    input_candidate_sha256::String
    frontier_hash::String
end

function build_mission_consistent_zpinch_context_v24(
        v20_context::RecoverableCrossTopologyContextV20,
        records::Vector{<:AbstractDict}; input_candidate_sha256::AbstractString)
    v23 = build_zpinch_admission_context_v23(v20_context, records;
        input_candidate_sha256 = input_candidate_sha256)
    return MissionConsistentZPinchContextV24(v23,
        String(input_candidate_sha256), v23.frontier_hash)
end

function _v24_zpinch_gene_spec(global_index::Int, frontier_count::Int)
    total = frontier_count * length(_V24_ZPINCH_BOUNDARIES)
    1 <= global_index <= total || throw(BoundsError(1:total, global_index))
    parent_position = mod1(global_index, frontier_count)
    boundary_position = cld(global_index, frontier_count)
    boundary = String(_V24_ZPINCH_BOUNDARIES[boundary_position])
    values = _v20_unit_vector(global_index, 5; skip = 12288)
    return parent_position, boundary, values
end

function _v24_set_target!(raw::Dict{String,Any}, name::String, value::Real,
        unit::String)
    raw["mission"]["targets"][name] = _gtv2_q(Float64(value), unit;
        basis = "mission-consistent Z-pinch v24 search gene")
    return raw
end

function build_mission_consistent_zpinch_genome_v24(parent::Genome,
        boundary::AbstractString, values::Vector{Float64})
    parent.family == "sheared_flow_z_pinch" || throw(ArgumentError(
        "v24 Z-pinch builder requires sheared_flow_z_pinch"))
    String(boundary) in _V24_ZPINCH_BOUNDARIES || throw(ArgumentError(
        "unsupported v24 Z-pinch boundary"))
    length(values) == 5 || throw(ArgumentError("v24 requires five genes"))
    raw = deepcopy(parent.normalized)
    raw["mission"]["kind"] = "net_electric_pilot"
    raw["mission"]["operating_mode"] = "pulsed"
    pulse_duration = Float64(raw["mission"]["targets"][
        "screen_z_pulse_duration"]["value"])
    requested_repetition = 0.1 * 1000.0^values[1]
    repetition_rate = min(requested_repetition,
        0.15 / max(pulse_duration, 1.0e-12))
    core = only(filter(region -> region["kind"] == "linear_pinch_core",
        raw["plasma_regions"]))
    radius = Float64(core["parameters"]["plasma_radius"]["value"])
    half_length = Float64(core["parameters"]["half_length"]["value"])
    required_pic_shear = 0.75 * 2.0 * half_length /
        max(pi * radius, 1.0e-12)
    normalized_shear = max(0.10,
        required_pic_shear * (0.75 + 0.75 * values[2]))
    m0_profile = 0.50 + 0.50 * values[3]
    accelerator_efficiency = 0.30 + 0.55 * values[4]
    declared_power = 50.0e6 * 20.0^values[5]
    _v24_set_target!(raw, "screen_z_repetition_rate", repetition_rate, "Hz")
    _v24_set_target!(raw, "screen_z_normalized_shear", normalized_shear, "1")
    _v24_set_target!(raw, "screen_z_m0_profile_margin", m0_profile, "1")
    _v24_set_target!(raw, "screen_z_accelerator_efficiency",
        accelerator_efficiency, "1")
    _v24_set_target!(raw, "screen_declared_actuator_power", declared_power, "W")
    accelerator = only(filter(actuator ->
        actuator["id"] == "v10_coaxial_plasma_accelerator", raw["actuators"]))
    accelerator["parameters"]["power"] = _gtv2_q(declared_power, "W";
        basis = "v24 pulsed accelerator nameplate")
    conductors = filter(source -> source["kind"] == "passive_conductor",
        raw["field_sources"])
    isempty(conductors) && error("v24 Z-pinch parent lacks a conductor boundary")
    for conductor in conductors
        conductor["geometry_model"] = boundary == "replaceable_solid_graphite" ?
            "replaceable_graphite_electrode_and_wall_v24" :
            "flowing_liquid_metal_electrode_wall_v24"
        conductor["material"] = boundary == "replaceable_solid_graphite" ?
            "POCO_graphite_hypothesis" : "flowing_liquid_metal_hypothesis"
    end
    raw["engineering"]["maintenance"]["architecture"] =
        boundary == "replaceable_solid_graphite" ?
            "pulsed replaceable graphite electrode cartridges" :
            "pulsed flowing liquid metal wall and electrode loop"
    requirements = raw["engineering"]["required_evaluators"]
    _push_unique!(requirements, boundary == "replaceable_solid_graphite" ?
        ["charge_normalized_graphite_net_erosion",
            "electrode_thermal_cycle_fatigue", "feedthrough_lifetime"] :
        ["liquid_metal_free_surface_mhd", "liquid_metal_corrosion",
            "liquid_metal_pumping_power", "feedthrough_lifetime"])
    provenance = raw["provenance"]
    _push_unique!(provenance["source_ids"], boundary ==
        "replaceable_solid_graphite" ?
        ["zpinch_graphite_net_erosion_khairi_shumlak_2025"] :
        ["zpinch_repetitive_liquid_metal_century_2026"])
    notes = get!(provenance, "notes", Any[])
    push!(notes, "v24 mission repair: steady_state to pulsed net-electric contract")
    push!(notes, "v24 boundary branch: $boundary")
    return _gtv2_finish(raw, parent,
        "mission_consistent_zpinch_$(boundary)_v24",
        String.(provenance["source_ids"]))
end

function _v24_liquid_boundary_audit(nominal::AbstractDict)
    return Dict{String,Any}(
        "boundary" => "flowing_liquid_metal",
        "repetition_rate_Hz" => nominal["repetition_rate_Hz"],
        "pulse_duration_s" => nominal["pulse_duration_s"],
        "duty_cycle" => nominal["duty_cycle"],
        "reference_component_control" =>
            "Century_nonreacting_hydrogen_approximately_0p1_Hz_100_kW_class",
        "free_surface_mhd_available" => false,
        "corrosion_and_compatibility_available" => false,
        "pumping_power_available" => false,
        "feedthrough_lifetime_available" => false,
        "candidate_specific_boundary_admission_passed" => false,
        "hard_rejection_credit" => false,
        "admission_status" => "blocking_unknown_liquid_metal_boundary",
    )
end

function evaluate_mission_consistent_zpinch_candidate_v24(
        context::MissionConsistentZPinchContextV24, global_index::Integer)
    v23 = context.v23_context
    parent_position, boundary, values = _v24_zpinch_gene_spec(
        Int(global_index), length(v23.frontier_records))
    parent_record = v23.frontier_records[parent_position]
    parent = v23.parent_genomes[parent_position]
    genome = build_mission_consistent_zpinch_genome_v24(parent, boundary, values)
    contract_id = mission_contract_for(default_mission_contract_registry(),
        genome).id
    evaluator = v23.v20_context.evaluators["mechanism_expansion_screen_v1"]
    result = _mechanism_expansion_result(evaluator, genome)
    nominal = result["nominal"]
    spectrum = _v23_reference_spectrum(nominal,
        v23.v20_context.compiler_context.outer.plasma_field_T)
    boundary_audit = boundary == "replaceable_solid_graphite" ?
        _v23_electrode_lifetime(nominal, genome) :
        _v24_liquid_boundary_audit(nominal)
    horizontal_gates = Dict{String,Bool}(String(key) => Bool(value)
        for (key, value) in result["gates"])
    hard_reasons = sort!([key for (key, passed) in horizontal_gates if !passed])
    contract_id == "net_electric_pulsed_v1" ||
        push!(hard_reasons, "pulsed_net_electric_mission_contract")
    Float64(nominal["repetition_rate_Hz"]) > 0.0 ||
        push!(hard_reasons, "nonzero_repetition")
    spectrum["pic_m0_reference_domain_overlap"] === true ||
        push!(hard_reasons, "bounded_pic_m0_reference_domain")
    if boundary == "replaceable_solid_graphite"
        boundary_audit["optimistic_full_inventory_one_year_gate"] === true ||
            push!(hard_reasons, "optimistic_graphite_inventory_lifetime")
    end
    sort!(unique!(hard_reasons))
    blocking_unknowns = boundary == "replaceable_solid_graphite" ? String[
        "candidate_specific_nonideal_m0_m1_spectrum",
        "electrode_sheath_and_redeposition",
        "electrode_thermal_cycle_fatigue", "feedthrough_lifetime"] : String[
        "candidate_specific_nonideal_m0_m1_spectrum",
        "liquid_metal_free_surface_mhd", "liquid_metal_corrosion",
        "liquid_metal_pumping_power", "feedthrough_lifetime"]
    modules = String.(parent_record["module_ids"])
    return Dict{String,Any}(
        "global_index" => Int(global_index),
        "parent_position" => parent_position,
        "parent_candidate_index" => Int(parent_record["candidate_index"]),
        "parent_graph_hash" => String(parent_record["graph_hash"]),
        "parent_physics_hash" => String(parent_record["physics_hash"]),
        "parent_module_ids" => modules,
        "boundary" => boundary,
        "descriptor" => join((boundary, modules[3], modules[4], modules[5]), "|"),
        "genes" => Dict{String,Any}(
            "halton_coordinates" => values,
            "repetition_rate_Hz" => nominal["repetition_rate_Hz"],
            "pulse_duration_s" => nominal["pulse_duration_s"],
            "duty_cycle" => nominal["duty_cycle"],
            "normalized_shear" => nominal["normalized_flow_shear"],
            "m0_profile_margin" => nominal["m0_profile_margin_gene"],
            "accelerator_efficiency" => _mev10_value(genome, nothing,
                "screen_z_accelerator_efficiency", 0.0, "1"),
            "declared_accelerator_power_W" => _mev10_value(genome, nothing,
                "screen_declared_actuator_power", 0.0, "W"),
        ),
        "child_design_id" => genome.design_id,
        "child_physics_hash" => genome.physics_hash,
        "mission_contract_id" => contract_id,
        "horizontal_gates" => horizontal_gates,
        "horizontal_five_gate_passed" => result["all_five_gates_passed"],
        "positive_net_power_closure" =>
            result["positive_net_power_closure_passed"],
        "robustness_pass_fraction" => result["robustness"]["pass_fraction"],
        "reference_spectrum_audit" => spectrum,
        "boundary_audit" => boundary_audit,
        "hard_rejection_reasons" => hard_reasons,
        "hard_rejection_count" => length(hard_reasons),
        "blocking_unknowns" => blocking_unknowns,
        "admission_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => false,
        "claim_boundary" => _V24_ZPINCH_CLAIM_BOUNDARY,
    )
end

function recoverable_mission_consistent_zpinch_spec_v24(
        context::MissionConsistentZPinchContextV24;
        run_id::AbstractString = "mission_consistent_zpinch_search_v24",
        shard_size::Integer = 12, source_sha256::AbstractString)
    total = length(context.v23_context.frontier_records) *
        length(_V24_ZPINCH_BOUNDARIES)
    return RecoverableRunSpecV19(String(run_id),
        "mission_consistent_zpinch_fidelity0_audit", "24.0.0", total,
        Int(shard_size); max_retries = 2,
        max_retained_per_shard = Int(shard_size),
        kernel_config = Dict{String,Any}(
            "input_candidate_sha256" => context.input_candidate_sha256,
            "frontier_hash" => context.frontier_hash,
            "frontier_count" => length(context.v23_context.frontier_records),
            "boundaries" => collect(_V24_ZPINCH_BOUNDARIES),
            "halton_sequence" => "paired_5d_skip_12288",
            "v24_source_sha256" => String(source_sha256),
            "retain_all" => true,
            "credit" => "rejection_or_blocking_unknown_only",
        ))
end

function recoverable_mission_consistent_zpinch_kernel_v24(
        context::MissionConsistentZPinchContextV24)
    return function(global_index, config)
        record = evaluate_mission_consistent_zpinch_candidate_v24(context,
            global_index)
        return RecoverableKernelOutcomeV19(record, true)
    end
end

function _v24_zpinch_rank(record::AbstractDict)
    spectrum = record["reference_spectrum_audit"]
    return (Int(record["hard_rejection_count"]),
        record["horizontal_five_gate_passed"] === true ? 0 : 1,
        record["positive_net_power_closure"] === true ? 0 : 1,
        spectrum["pic_m0_reference_domain_overlap"] === true ? 0 : 1,
        -Float64(record["robustness_pass_fraction"]),
        Int(record["global_index"]))
end

function mission_consistent_zpinch_qd_archive_v24(
        records::Vector{<:AbstractDict})
    cells = Dict{String,Dict{String,Any}}()
    for record in records
        key = String(record["descriptor"])
        item = Dict{String,Any}(record)
        if !haskey(cells, key) ||
                _v24_zpinch_rank(item) < _v24_zpinch_rank(cells[key])
            cells[key] = item
        end
    end
    return sort!(collect(values(cells));
        by = record -> String(record["descriptor"]))
end
