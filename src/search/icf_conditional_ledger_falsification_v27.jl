const _V27_ICF_CLAIM_BOUNDARY =
    "V27 is a candidate-specific falsification audit of the 42 sealed v20 laser-ICF records whose searched-hypothesis ledger has positive average net electricity. It exactly decomposes the v15 ledger and solves the algebraic target gain required for zero net power under the same declared chamber contract. The result is not radiation hydrodynamics, LPI, mix, target fabrication, repeat-rate laser, chamber recovery, wall/optic lifetime, tritium, C1, medium-fidelity, or reactor evidence. The measured NIF indirect-drive target-gain anchor is never transferred to a different capsule, hohlraum, pulse, driver, repetition rate, chamber, direct-drive, or fast-ignition candidate."

struct ICFConditionalLedgerContextV27
    v20_context::RecoverableCrossTopologyContextV20
    frontier_records::Vector{Dict{String,Any}}
    candidates::Vector{CrossTopologyCandidateV20}
    input_candidate_sha256::String
    frontier_hash::String
end

function build_icf_conditional_ledger_context_v27(
        v20_context::RecoverableCrossTopologyContextV20,
        records::Vector{<:AbstractDict}; input_candidate_sha256::AbstractString)
    frontier = Dict{String,Any}[Dict{String,Any}(record) for record in records
        if String(record["family"]) == "inertial_confinement_fusion" &&
            record["positive_net_power_closure"] === true]
    sort!(frontier; by = record -> Int(record["candidate_index"]))
    length(frontier) == 42 || throw(ArgumentError(
        "v27 expects the sealed 42-record v20 positive-net ICF frontier"))
    candidates = CrossTopologyCandidateV20[]
    for record in frontier
        candidate = evaluate_cross_topology_candidate_v20(v20_context,
            Int(record["candidate_index"]))
        compiled = candidate.prescreen.compiled
        compiled.graph_hash == record["graph_hash"] || throw(ArgumentError(
            "v27 ICF parent graph reconstruction drifted"))
        compiled.genome.physics_hash == record["physics_hash"] ||
            throw(ArgumentError(
                "v27 ICF parent physics reconstruction drifted"))
        push!(candidates, candidate)
    end
    frontier_hash = canonical_hash([Dict{String,Any}(
        "candidate_index" => Int(record["candidate_index"]),
        "graph_hash" => String(record["graph_hash"]),
        "physics_hash" => String(record["physics_hash"]),
        "module_ids" => String.(record["module_ids"])) for record in frontier])
    return ICFConditionalLedgerContextV27(v20_context, frontier, candidates,
        String(input_candidate_sha256), frontier_hash)
end

function _v27_required_gain(nominal::AbstractDict, contract::AbstractDict)
    e_target = Float64(nominal["on_target_energy_J"])
    rate = Float64(nominal["effective_shot_rate_Hz"])
    driver = Float64(nominal["driver_grid_energy_per_shot_J"])
    factory = Float64(nominal["target_factory_grid_energy_per_shot_J"])
    assumptions = contract["declared_screening_assumptions_not_material_truth"]
    conversion = Float64(assumptions["thermal_conversion_efficiency"])
    fixed_load = Float64(assumptions["fixed_balance_of_plant_load_W"])
    return (driver + factory + fixed_load / max(rate, 1.0e-30)) /
        max(conversion * e_target, 1.0e-30)
end

function _v27_power_balance_audit(result::AbstractDict)
    nominal = result["nominal"]
    contract = result["contract"]
    assumptions = contract["declared_screening_assumptions_not_material_truth"]
    required_gain = _v27_required_gain(nominal, contract)
    assumed_gain = Float64(nominal["target_gain_assumption"])
    rate = Float64(nominal["effective_shot_rate_Hz"])
    fixed_load = Float64(assumptions["fixed_balance_of_plant_load_W"])
    gross = Float64(nominal["gross_electric_energy_per_shot_J"])
    driver = Float64(nominal["driver_grid_energy_per_shot_J"])
    factory = Float64(nominal["target_factory_grid_energy_per_shot_J"])
    reconstructed_net = rate * (gross - driver - factory) - fixed_load
    reported_net = Float64(nominal["average_net_electric_power_W"])
    return Dict{String,Any}(
        "ledger_exactly_reproduced" => isapprox(reconstructed_net,
            reported_net; rtol = 1.0e-12, atol = 1.0e-6),
        "on_target_energy_J" => nominal["on_target_energy_J"],
        "searched_target_gain_assumption" => assumed_gain,
        "required_target_gain_for_zero_average_net_power" => required_gain,
        "searched_gain_over_zero_net_requirement" =>
            assumed_gain / max(required_gain, 1.0e-30),
        "fusion_yield_assumption_J" => nominal["fusion_yield_assumption_J"],
        "driver_grid_energy_per_shot_J" => driver,
        "target_factory_grid_energy_per_shot_J" => factory,
        "gross_electric_energy_per_shot_J" => gross,
        "fixed_balance_of_plant_load_W" => fixed_load,
        "repetition_rate_Hz" => nominal["repetition_rate_Hz"],
        "availability" => nominal["availability"],
        "effective_shot_rate_Hz" => rate,
        "reported_average_net_electric_power_W" => reported_net,
        "reconstructed_average_net_electric_power_W" => reconstructed_net,
        "searched_gain_is_validated" => false,
        "admission_status" =>
            "conditional_positive_ledger_blocked_by_unvalidated_target_gain_and_integrated_subsystems")
end

function _v27_timing_lifetime_audit(result::AbstractDict)
    nominal = result["nominal"]
    features = result["features"]
    period = Float64(nominal["shot_period_s"])
    annual = Float64(nominal["annual_full_power_shot_count"])
    return Dict{String,Any}(
        "target_injection_time_s" => nominal["target_injection_time_s"],
        "chamber_clearing_time_s" => nominal["chamber_clearing_time_s"],
        "shot_period_s" => period,
        "target_injection_time_over_period" =>
            Float64(nominal["target_injection_time_s"]) / period,
        "chamber_clearing_time_over_period" =>
            Float64(nominal["chamber_clearing_time_s"]) / period,
        "annual_full_power_shot_count" => annual,
        "searched_driver_lifetime_shots" =>
            features["driver_lifetime_shots_assumption"],
        "searched_first_wall_lifetime_shots" =>
            features["first_wall_lifetime_shots_assumption"],
        "searched_driver_lifetime_over_annual_requirement" =>
            Float64(features["driver_lifetime_shots_assumption"]) /
                max(annual, 1.0),
        "searched_first_wall_lifetime_over_annual_requirement" =>
            Float64(features["first_wall_lifetime_shots_assumption"]) /
                max(annual, 1.0),
        "neutron_wall_load_W_m2" => nominal["neutron_wall_load_W_m2"],
        "average_chamber_heat_flux_W_m2" =>
            nominal["average_chamber_heat_flux_W_m2"],
        "candidate_specific_chamber_recovery_model_available" => false,
        "candidate_specific_lifetime_model_available" => false,
        "timing_and_lifetime_values_are_searched_hypotheses" => true)
end

function _v27_evidence_ledger(path::AbstractString)
    path_specific = path == "laser_indirect_drive" ?
        "candidate_specific_indirect_drive_radiation_hydrodynamics" :
        path == "laser_direct_drive" ?
            "candidate_specific_direct_drive_radiation_hydrodynamics_and_LPI" :
            "candidate_specific_fast_ignition_transport_and_radiation_hydrodynamics"
    return Dict{String,Any}(
        "nif_2022_indirect_drive_anchor" => Dict{String,Any}(
            "laser_energy_J" => 2.05e6,
            "fusion_yield_J" => 3.1e6,
            "reported_target_gain" => 1.5,
            "source_id" => "nif_target_gain_above_unity_prl_2024",
            "transferable_to_candidate" => false,
            "reason" => "bounded single-shot indirect-drive target evidence only"),
        "required_candidate_specific_evidence" => [path_specific,
            "mix_and_asymmetry_uncertainty",
            "repeat_rate_driver_wall_plug_efficiency_and_shot_life",
            "target_factory_yield_throughput_injection_and_tracking",
            "candidate_chamber_hydrodynamic_recovery",
            "first_wall_blanket_and_final_optics_lifetime",
            "tritium_breeding_recovery_and_inventory",
            "integrated_availability_and_maintenance"],
        "resolved_required_evidence_count" => 0,
        "candidate_specific_target_gain_validated" => false,
        "integrated_engineering_validated" => false,
        "evidence_admission_passed" => false)
end

function _v27_bin(value::Real, cuts, labels)
    for (cut, label) in zip(cuts, labels)
        Float64(value) <= cut && return String(label)
    end
    return String(last(labels))
end

function evaluate_icf_conditional_ledger_v27(
        context::ICFConditionalLedgerContextV27, local_index::Integer)
    1 <= local_index <= length(context.frontier_records) ||
        throw(BoundsError(context.frontier_records, local_index))
    parent = context.frontier_records[Int(local_index)]
    candidate = context.candidates[Int(local_index)]
    genome = candidate.prescreen.compiled.genome
    evaluator = context.v20_context.evaluators["laser_icf_screen_v1"]
    result = _laser_icf_result(evaluator, genome)
    result["positive_average_net_power_closure_passed"] === true ||
        error("v27 frontier reconstruction lost positive conditional net power")
    nominal = result["nominal"]
    power = _v27_power_balance_audit(result)
    timing = _v27_timing_lifetime_audit(result)
    path = String(nominal["drive_path"])
    evidence = _v27_evidence_ledger(path)
    protection = String(nominal["chamber_protection"])
    required_gain = Float64(power[
        "required_target_gain_for_zero_average_net_power"])
    leverage = Float64(power["searched_gain_over_zero_net_requirement"])
    descriptor = join((path, protection,
        _v27_bin(required_gain, (25.0, 50.0, 100.0, 200.0, Inf),
            ("Qreq_le25", "Qreq_25_50", "Qreq_50_100", "Qreq_100_200",
                "Qreq_gt200")),
        _v27_bin(leverage, (1.10, 1.25, 1.50, 2.0, Inf),
            ("headroom_le1p1", "headroom_1p1_1p25", "headroom_1p25_1p5",
                "headroom_1p5_2", "headroom_gt2"))), "|")
    failed_conditional_margins = sort!(String[id for (id, margin) in
        nominal["margins"] if Float64(margin) < 0.0 && !(id in (
            "target_gain_experimental_validation",
            "driver_wall_plug_and_repeat_rate_validation",
            "target_factory_throughput_and_yield_validation",
            "first_wall_and_final_optics_lifetime_validation"))])
    blockers = String.(evidence["required_candidate_specific_evidence"])
    return Dict{String,Any}(
        "local_index" => Int(local_index),
        "candidate_index" => Int(parent["candidate_index"]),
        "graph_hash" => String(parent["graph_hash"]),
        "physics_hash" => String(parent["physics_hash"]),
        "module_ids" => String.(parent["module_ids"]),
        "drive_path" => path,
        "chamber_protection" => protection,
        "descriptor" => descriptor,
        "mission_contract_id" => parent["mission_contract_id"],
        "power_balance_audit" => power,
        "timing_and_lifetime_audit" => timing,
        "evidence_ledger" => evidence,
        "conditional_nominal_physics_passed" =>
            nominal["conditional_physics_gate_passed"],
        "conditional_nominal_engineering_passed" =>
            nominal["conditional_engineering_gate_passed"],
        "conditional_robustness" => result["robustness"],
        "failed_conditional_margin_ids" => failed_conditional_margins,
        "v20_gates" => Dict{String,Bool}(String(key) => Bool(value)
            for (key, value) in parent["gates"]),
        "blocking_unknowns" => blockers,
        "conditional_positive_net_ledger" => true,
        "fidelity0_admission_authorized" => false,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => false,
        "claim_boundary" => _V27_ICF_CLAIM_BOUNDARY)
end

function recoverable_icf_conditional_ledger_spec_v27(
        context::ICFConditionalLedgerContextV27;
        run_id::AbstractString = "icf_conditional_ledger_falsification_v27",
        shard_size::Integer = 7, source_sha256::AbstractString)
    return RecoverableRunSpecV19(String(run_id),
        "icf_positive_conditional_ledger_falsification", "27.0.0",
        length(context.frontier_records), Int(shard_size); max_retries = 2,
        max_retained_per_shard = Int(shard_size),
        kernel_config = Dict{String,Any}(
            "input_candidate_sha256" => context.input_candidate_sha256,
            "frontier_hash" => context.frontier_hash,
            "frontier_count" => length(context.frontier_records),
            "v27_source_sha256" => String(source_sha256),
            "retain_all" => true,
            "credit" => "algebraic_falsification_and_blocking_unknown_only"))
end

function recoverable_icf_conditional_ledger_kernel_v27(
        context::ICFConditionalLedgerContextV27)
    return function(local_index, config)
        record = evaluate_icf_conditional_ledger_v27(context, local_index)
        return RecoverableKernelOutcomeV19(record, true)
    end
end

function _v27_rank(record::AbstractDict)
    power = record["power_balance_audit"]
    robustness = record["conditional_robustness"]
    return (record["conditional_nominal_physics_passed"] === true ? 0 : 1,
        record["conditional_nominal_engineering_passed"] === true ? 0 : 1,
        robustness["gate_passed"] === true ? 0 : 1,
        Float64(power["required_target_gain_for_zero_average_net_power"]),
        -Float64(power["searched_gain_over_zero_net_requirement"]),
        Int(record["candidate_index"]))
end

function icf_conditional_ledger_qd_archive_v27(
        records::Vector{<:AbstractDict})
    cells = Dict{String,Dict{String,Any}}()
    for record in records
        key = String(record["descriptor"])
        item = Dict{String,Any}(record)
        if !haskey(cells, key) || _v27_rank(item) < _v27_rank(cells[key])
            cells[key] = item
        end
    end
    return sort!(collect(values(cells));
        by = record -> String(record["descriptor"]))
end
