const _V44_CLAIM_BOUNDARY =
    "V44 replays the measured direction of the RFP PPCD/boundary-control and LDX " *
    "levitation anchors through existing v7/v8 fidelity-0 equations without adding a " *
    "constant or refitting a coefficient. The PPCD fourfold response is an explicit " *
    "calibration replay, not independent validation. Boundary feedback is qualitative " *
    "direction only. The supported-dipole endpoint is graph-invalid in the current " *
    "levitated-only grammar. No replay grants candidate-module validation, promotion " *
    "credit, robustness, C1, scale-up, reactor closure, or net-electric credibility."

function _v44_candidate_v7(parent::Genome, contract,
        mechanism::String, values::Dict{String,Float64})
    spec = SelfOrganizedTopologySpecV7("reversed_field_pinch", mechanism, 4)
    base = _sov7_structural_base(parent, spec)
    genome = _sov7_instantiate(base, values, contract)
    result = _self_organized_result(SelfOrganizedScreenV1(contract), genome)
    return genome, result
end

function _v44_candidate_v8(parent::Genome, contract,
        mechanism::String, values::Dict{String,Float64})
    spec = ProfileCoupledRFPTopologySpecV8(mechanism, 4)
    base = _pcrfp_structural_base_v8(parent, spec)
    genome = _pcrfp_instantiate_v8(base, values, contract)
    result = _profile_coupled_rfp_result(
        ProfileCoupledRFPScreenV1(contract), genome)
    return genome, result
end

function _v44_candidate_dipole(parent::Genome, contract,
        values::Dict{String,Float64})
    spec = SelfOrganizedTopologySpecV7(
        "levitated_dipole", "levitated_inward_pinch", 4)
    base = _sov7_structural_base(parent, spec)
    genome = _sov7_instantiate(base, values, contract)
    result = _self_organized_result(SelfOrganizedScreenV1(contract), genome)
    return genome, result
end

_v44_value(result, key::String) = Float64(result["nominal"][key])

function _v44_trial_record(trial_id::String, family::String,
        mapped_modules::Vector{String}, low_genome::Genome,
        low_result::Dict{String,Any}, high_genome::Genome,
        high_result::Dict{String,Any}, metrics::Vector{String};
        replay_class::String, expected_direction::Dict{String,String},
        checks::Dict{String,Bool}, circular_calibration::Bool,
        route_blocker::String = "none")
    low = Dict(metric => _v44_value(low_result, metric) for metric in metrics)
    high = Dict(metric => _v44_value(high_result, metric) for metric in metrics)
    deltas = Dict(metric => high[metric] - low[metric] for metric in metrics)
    return Dict{String,Any}(
        "trial_id" => trial_id,
        "family" => family,
        "mapped_v43_module_ids" => sort!(mapped_modules),
        "replay_class" => replay_class,
        "expected_direction" => expected_direction,
        "low_state" => low,
        "high_state" => high,
        "high_minus_low" => deltas,
        "direction_checks" => checks,
        "all_direction_checks_passed" => all(values(checks)),
        "low_physics_hash" => low_genome.physics_hash,
        "high_physics_hash" => high_genome.physics_hash,
        "low_topology_graph_error_count" => length(
            low_result["topology_graph_errors"]),
        "high_topology_graph_error_count" => length(
            high_result["topology_graph_errors"]),
        "both_endpoints_graph_valid" => isempty(
            low_result["topology_graph_errors"]) && isempty(
            high_result["topology_graph_errors"]),
        "circular_calibration_replay" => circular_calibration,
        "independent_known_device_validation" => false,
        "candidate_module_validation" => false,
        "route_blocker" => route_blocker,
        "medium_fidelity_authorized" => false,
        "promotion_credit" => 0,
    )
end

function experiment_anchored_directional_replay_v44(seeds::Vector{Genome})
    isempty(seeds) && throw(ArgumentError("v44 requires a parent seed"))
    contract = only(filter(item -> item.id == "outer_small_B3_v1",
        shared_outer_envelope_contracts_v1()))
    parent = first(seeds)
    u = fill(0.5, 21)
    records = Dict{String,Any}[]

    ppcd_spec = SelfOrganizedTopologySpecV7(
        "reversed_field_pinch", "qsh_pulsed_poloidal_current_drive", 4)
    ppcd_values = _sov7_ranges(ppcd_spec, u)
    ppcd_low = copy(ppcd_values); ppcd_low["screen_current_profile_control"] = 0.0
    ppcd_high = copy(ppcd_values); ppcd_high["screen_current_profile_control"] = 1.0
    low_g, low_r = _v44_candidate_v7(parent, contract,
        ppcd_spec.mechanism, ppcd_low)
    high_g, high_r = _v44_candidate_v7(parent, contract,
        ppcd_spec.mechanism, ppcd_high)
    ratio = _v44_value(high_r, "energy_confinement_time_s") /
        _v44_value(low_r, "energy_confinement_time_s")
    push!(records, _v44_trial_record(
        "rfp_ppcd_v7_calibration_replay", "reversed_field_pinch",
        ["rfp_ppcd"], low_g, low_r, high_g, high_r,
        ["energy_confinement_time_s", "rfp_ppcd_multiplier",
            "particle_loss_fraction_proxy", "declared_ppcd_power_W"];
        replay_class = "candidate_parameter_calibration_replay",
        expected_direction = Dict(
            "energy_confinement_time_s" => "increase_by_4_to_5_fold",
            "rfp_ppcd_multiplier" => "increase",
            "declared_ppcd_power_W" => "unchanged_nonzero_ledger"),
        checks = Dict(
            "confinement_ratio_inside_reported_anchor" => 4.0 <= ratio <= 5.0,
            "ppcd_multiplier_increased" => _v44_value(high_r,
                "rfp_ppcd_multiplier") > _v44_value(low_r,
                "rfp_ppcd_multiplier"),
            "ppcd_power_ledger_unchanged_and_positive" => _v44_value(high_r,
                "declared_ppcd_power_W") == _v44_value(low_r,
                "declared_ppcd_power_W") > 0.0),
        circular_calibration = true))

    ppcd_v8_spec = ProfileCoupledRFPTopologySpecV8(
        "qsh_pulsed_poloidal_current_drive", 4)
    ppcd_v8_values = _pcrfp_ranges_v8(ppcd_v8_spec, u)
    ppcd_v8_low = copy(ppcd_v8_values)
    ppcd_v8_low["screen_current_profile_control"] = 0.0
    ppcd_v8_high = copy(ppcd_v8_values)
    ppcd_v8_high["screen_current_profile_control"] = 1.0
    low_g, low_r = _v44_candidate_v8(parent, contract,
        ppcd_v8_spec.mechanism, ppcd_v8_low)
    high_g, high_r = _v44_candidate_v8(parent, contract,
        ppcd_v8_spec.mechanism, ppcd_v8_high)
    ratio = _v44_value(high_r, "energy_confinement_time_s") /
        _v44_value(low_r, "energy_confinement_time_s")
    push!(records, _v44_trial_record(
        "rfp_ppcd_profile_v8_calibration_replay", "reversed_field_pinch",
        ["rfp_ppcd_profile"], low_g, low_r, high_g, high_r,
        ["energy_confinement_time_s", "rfp_ppcd_multiplier",
            "derived_reversal_parameter", "derived_pinch_parameter"];
        replay_class = "profile_coupled_candidate_parameter_calibration_replay",
        expected_direction = Dict(
            "energy_confinement_time_s" => "increase_by_4_to_5_fold",
            "derived_reversal_parameter" => "unchanged_fixed_profile",
            "derived_pinch_parameter" => "unchanged_fixed_profile"),
        checks = Dict(
            "confinement_ratio_inside_reported_anchor" => 4.0 <= ratio <= 5.0,
            "derived_reversal_parameter_unchanged" => _v44_value(high_r,
                "derived_reversal_parameter") == _v44_value(low_r,
                "derived_reversal_parameter"),
            "derived_pinch_parameter_unchanged" => _v44_value(high_r,
                "derived_pinch_parameter") == _v44_value(low_r,
                "derived_pinch_parameter")),
        circular_calibration = true))

    boundary_spec = SelfOrganizedTopologySpecV7(
        "reversed_field_pinch", "qsh_ppcd_boundary_mode_control", 4)
    boundary_values = _sov7_ranges(boundary_spec, u)
    boundary_values["screen_current_profile_control"] = 1.0
    boundary_low = copy(boundary_values)
    boundary_low["screen_boundary_feedback_strength"] = 0.0
    boundary_high = copy(boundary_values)
    boundary_high["screen_boundary_feedback_strength"] = 1.0
    low_g, low_r = _v44_candidate_v7(parent, contract,
        boundary_spec.mechanism, boundary_low)
    high_g, high_r = _v44_candidate_v7(parent, contract,
        boundary_spec.mechanism, boundary_high)
    push!(records, _v44_trial_record(
        "rfp_boundary_block_v7_qualitative_replay", "reversed_field_pinch",
        ["rfp_boundary_control", "rfp_saddle_control"],
        low_g, low_r, high_g, high_r,
        ["particle_loss_fraction_proxy", "external_peak_field_T",
            "declared_boundary_control_power_W"];
        replay_class = "shared_block_qualitative_direction_replay",
        expected_direction = Dict(
            "particle_loss_fraction_proxy" => "decrease",
            "external_peak_field_T" => "increase_engineering_cost",
            "declared_boundary_control_power_W" => "unchanged_nonzero_ledger"),
        checks = Dict(
            "particle_loss_proxy_decreased" => _v44_value(high_r,
                "particle_loss_fraction_proxy") < _v44_value(low_r,
                "particle_loss_fraction_proxy"),
            "external_peak_field_cost_increased" => _v44_value(high_r,
                "external_peak_field_T") > _v44_value(low_r,
                "external_peak_field_T"),
            "boundary_power_ledger_unchanged_and_positive" => _v44_value(high_r,
                "declared_boundary_control_power_W") == _v44_value(low_r,
                "declared_boundary_control_power_W") > 0.0),
        circular_calibration = false,
        route_blocker = "saddle and boundary module identities share one response block"))

    dipole_spec = SelfOrganizedTopologySpecV7(
        "levitated_dipole", "levitated_inward_pinch", 4)
    dipole_values = _sov7_ranges(dipole_spec, u)
    supported_values = copy(dipole_values)
    supported_values["screen_levitation_quality"] = 0.0
    levitated_values = copy(dipole_values)
    levitated_values["screen_levitation_quality"] = 1.0
    low_g, low_r = _v44_candidate_dipole(parent, contract, supported_values)
    high_g, high_r = _v44_candidate_dipole(parent, contract, levitated_values)
    push!(records, _v44_trial_record(
        "ldx_supported_to_levitated_semantic_probe", "levitated_dipole",
        ["dipole_levitated", "dipole_supported"],
        low_g, low_r, high_g, high_r,
        ["energy_confinement_time_s", "particle_loss_fraction_proxy",
            "minimum_stability_margin_proxy"];
        replay_class = "parameter_direction_visible_but_supported_graph_invalid",
        expected_direction = Dict(
            "energy_confinement_time_s" => "increase",
            "particle_loss_fraction_proxy" => "decrease",
            "minimum_stability_margin_proxy" => "increase"),
        checks = Dict(
            "confinement_proxy_increased" => _v44_value(high_r,
                "energy_confinement_time_s") > _v44_value(low_r,
                "energy_confinement_time_s"),
            "particle_loss_proxy_decreased" => _v44_value(high_r,
                "particle_loss_fraction_proxy") < _v44_value(low_r,
                "particle_loss_fraction_proxy"),
            "levitated_endpoint_graph_valid" => isempty(
                high_r["topology_graph_errors"]),
            "supported_endpoint_graph_rejected" => !isempty(
                low_r["topology_graph_errors"])),
        circular_calibration = false,
        route_blocker = "current grammar contains a levitated coil only; supported endpoint is not a valid candidate graph"))

    mapped_modules = sort!(unique(String[String(module_id) for record in records
        for module_id in record["mapped_v43_module_ids"]]))
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "search_version" => "experiment_anchored_directional_replay_v44",
        "stage" => "sealed_experiment_anchored_directional_replay",
        "replay_contract" => Dict{String,Any}(
            "existing_equations_only" => true,
            "new_empirical_multiplier_allowed" => false,
            "calibration_replay_is_independent_validation" => false,
            "qualitative_direction_is_magnitude_validation" => false,
            "graph_invalid_endpoint_can_validate_module" => false,
            "known_device_anchor_can_promote_candidate" => false,
        ),
        "aggregate" => Dict{String,Any}(
            "trial_count" => length(records),
            "mapped_experimental_anchor_module_count" => length(mapped_modules),
            "mapped_experimental_anchor_module_ids" => mapped_modules,
            "all_direction_checks_passed_count" => count(record -> record[
                "all_direction_checks_passed"] === true, records),
            "both_endpoints_graph_valid_trial_count" => count(record -> record[
                "both_endpoints_graph_valid"] === true, records),
            "circular_calibration_replay_trial_count" => count(record -> record[
                "circular_calibration_replay"] === true, records),
            "formula_direction_replay_module_count" => 4,
            "supported_topology_blocked_module_count" => 2,
            "v43_experimental_anchor_module_count" => 8,
            "remaining_experimental_anchor_module_count" => 2,
            "independent_known_device_validation_count" => 0,
            "candidate_module_validation_count" => 0,
            "candidate_module_validation_fraction_of_v43_routes" => 0.0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0,
            "old_domain_scale_up_authorized" => false,
        ),
        "trial_records" => records,
        "next_actions" => [
            "add an explicit supported-dipole graph and repeat the LDX paired control",
            "separate RFP saddle hardware from boundary-control response ownership",
            "replace PPCD calibration replay with held-out MST discharge regression",
            "build NIF indirect-drive and W7-X island-divertor executable route bridges",
        ],
        "promotion_credit" => Dict{String,Any}(
            "physics_evidence_level_change" => 0,
            "engineering_evidence_level_change" => 0,
            "medium_fidelity_authorized_count" => 0,
            "promotion_count" => 0,
        ),
        "claim_boundary" => _V44_CLAIM_BOUNDARY,
    )
end
