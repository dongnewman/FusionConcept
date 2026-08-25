function _open_world_base_candidate_v2(design_id::String)
    return Dict{String,Any}(
        "schema_version" => "2.0.0",
        "identity" => Dict(
            "design_id" => design_id, "revision_id" => "$(design_id)_r1",
            "parent_revision_ids" => Any[], "topology_skeleton_id" => "$(design_id)_topology",
            "model_choice_id" => "$(design_id)_model", "parameter_instance_id" => "$(design_id)_parameters",
            "human_label" => replace(design_id, "_" => " "),
        ),
        "provenance" => Dict("origin" => "manual_method_fixture", "claim_level" => "C0_C1_method_only",
            "physical_novelty_claimed" => false, "buildability_claimed" => false),
        "mission_contracts" => Any[Dict(
            "mission_id" => "method_vertical_slice_v1", "claim_ceiling" => "C1",
            "mandatory_ruleset_refs" => Any["open_world_minimal_rules_v1"],
            "required_promotion_scope" => "method_c1_scope", "required_independent_confirmation" => false,
            "allowed_evidence_classes" => Any["analytic", "numerical"],
            "minimum_tuning_budget_policy" => Dict("minimum_trials" => 3),
            "engineering_preflight_policy" => "mandatory_non_promoting",
            "prohibited_claims" => Any["net_energy", "buildability", "reactor_readiness"]),
        ],
        "governance_policy_ref" => "open_world_governance_v2",
        "required_ruleset_refs" => Any["open_world_minimal_rules_v1"],
        "rule_coverage_requirement" => "explicit_gaps",
        "spacetime_support" => Dict("space_dimensions" => 1, "time_dimensions" => 1,
            "coordinate_charts" => Any["normalized_axial_coordinate"],
            "event_and_rollback_semantics" => "deterministic_event_replay"),
        "domains" => Any[
            Dict("domain_id" => "plasma_domain", "kind" => "plasma", "geometry" => "open_closed_0d_compartments"),
        ],
        "populations" => Any[Dict("population_id" => "bulk_ions", "domain_ref" => "plasma_domain")],
        "state_variables" => Any[
            Dict("state_id" => "stored_energy", "domain_ref" => "plasma_domain", "kind" => "scalar",
                "unit" => "J", "epistemic_state" => "derived"),
        ],
        "interactions" => Any[
            Dict("interaction_id" => "exchange_operator", "role_annotations" => Any["energy_exchange"],
                "inputs" => Any["stored_energy"], "outputs" => Any["stored_energy"],
                "affected_domains" => Any["plasma_domain"],
                "operator_spec" => Dict("form" => "known_operator_ref", "ref" => "linear_reservoir_exchange_v1"),
                "parameter_specs" => Any[], "assumptions" => Any["lumped_0d"], "validity_claims" => Any[],
                "conservation_effects" => Any[Dict("account" => "energy", "source_reservoir" => "driver_reservoir",
                    "sink_reservoir" => "plasma_reservoir")],
                "symmetry_claims" => Any[], "timescale_claims" => Any[], "observable_links" => Any["stored_energy_observable"],
                "epistemic_state" => "declared_known", "unknown_refs" => Any[],
                "promotion_scope_ref" => "method_c1_scope", "failure_scope_options" => Any["parameter_instance", "numerical_method"],
                "provenance" => Dict("source" => "analytic_fixture")),
        ],
        "boundaries" => Any[
            Dict("boundary_id" => "switching_boundary", "kind" => "topology_event",
                "domain_refs" => Any["plasma_domain"], "event" => "open_to_closed_then_open"),
        ],
        "reservoirs" => Any[
            Dict("reservoir_id" => "driver_reservoir", "kind" => "energy", "unit" => "J"),
        ],
        "invariants" => Any[Dict("invariant_id" => "total_energy_account", "kind" => "energy_ledger")],
        "actuators" => Any[], "sensors" => Any[], "controls" => Any[],
        "observables" => Any[
            Dict("observable_id" => "stored_energy_observable", "state_ref" => "stored_energy", "unit" => "J",
                "noise_floor" => 0.01),
        ],
        "predictions" => Any[Dict("prediction_id" => "heldout_decay_rate", "observable_ref" => "stored_energy_observable")],
        "engineering_objects" => Any[], "hazards" => Any[], "applicability_claims" => Any[],
        "unknowns" => Any[
            Dict("unknown_id" => "solver_calibration_unknown", "subject_refs" => Any["exchange_operator"],
                "kind" => "missing_parameter", "impact_scope" => "C1 numerical evidence", "risk_class" => "evidence_gap",
                "obligation_refs" => Any["solver_calibration_obligation"]),
        ],
        "evidence_obligation_graph" => Dict(
            "obligations" => Any[
                Dict("obligation_id" => "solver_calibration_obligation", "unknown_refs" => Any["solver_calibration_unknown"],
                    "level" => "C1", "activation_predicate" => "C0_pass", "assessment_scope" => "exchange_operator",
                    "mandatory_for_missions" => Any["method_vertical_slice_v1"], "required_data_products" => Any["trajectory"],
                    "acceptable_evidence_classes" => Any["analytic", "numerical"], "discrimination_requirement" => "negative_control",
                    "calibration_requirements" => Any[], "uncertainty_requirement" => "bounded_error",
                    "promotion_scope_required" => "C1", "failure_scope_options" => Any["parameter_instance", "numerical_method"],
                    "applicability_proof_ref" => nothing, "dependencies" => Any[], "resolution_value" => 1.0,
                    "status" => "unknown", "evidence_refs" => Any[], "next_action_refs" => Any["run_analytic_decay_check"],
                    "termination_conditions" => Any["pass", "fail", "unsupported"]),
            ],
            "dependencies" => Any[], "shared_evidence_correlations" => Any[]),
        "promotion_scopes" => Any[
            Dict("scope_id" => "method_c1_scope", "max_gate" => "C1",
                "valid_missions" => Any["method_vertical_slice_v1"], "valid_domains" => Any["plasma_domain"],
                "valid_parameter_ranges" => Dict("normalized_decay_rate" => Any[0.1, 2.0]),
                "valid_observables" => Any["stored_energy_observable"], "calibration_refs" => Any[],
                "required_ruleset_hash" => "pending", "independent_confirmation_required" => false,
                "expiry_or_version" => "fixture_v1"),
        ],
        "classifications" => Any[Dict("label" => "method_fixture", "non_routing" => true)],
        "equivalence_claims" => Any[], "extensions" => Dict{String,Any}(),
    )
end

function _partial_operator_fixture_v2()
    return Dict{String,Any}(
        "form" => "partial_operator", "inputs" => Any["stored_energy"], "outputs" => Any["stored_energy"],
        "domain_and_time_scope" => Dict("domains" => Any["plasma_domain"], "time" => "transient"),
        "dimension_signature" => Dict("input" => "J", "output_rate" => "W"), "causal_direction" => "input_to_output",
        "allowed_conservation_effects" => Any["energy_transfer"], "forbidden_conservation_effects" => Any["energy_creation"],
        "parameter_bounds" => Dict("gain" => Any[0.0, 1.0]), "scale_bounds" => Dict("time_s" => Any[0.1, 10.0]),
        "symmetry_or_limit_constraints" => Any["zero_gain_recovers_null"], "null_models" => Any["zero_gain"],
        "alternative_models" => Any["linear_saturation"],
        "identifiability_conditions" => Any["two_input_amplitudes_and_decay_observable"],
        "minimum_effect_size" => Dict("value" => 0.05, "unit" => "1"),
        "noise_and_numerical_floor" => Dict("value" => 0.01, "unit" => "1"),
        "complexity_budget" => Dict("max_free_parameters" => 3, "max_free_functions" => 1,
            "max_memory_length" => 1, "max_suboperators" => 2),
        "out_of_sample_prediction_refs" => Any["heldout_decay_rate"],
        "failure_scope_options" => Any["closure_model", "interaction_hypothesis"], "safety_limits" => Any["bounded_gain"],
        "completion_routes" => Any["analytic_bound", "data_driven_identification"], "promotion_scope_ref" => "method_c1_scope",
    )
end

function public_positive_fixtures_v1()
    temporal = _open_world_base_candidate_v2("manual_temporal_open_closed_v1")
    moving = _open_world_base_candidate_v2("manual_moving_boundary_pulse_v1")
    moving["boundaries"][1]["kind"] = "moving"
    moving["boundaries"][1]["event"] = "prescribed_compression_pulse"
    moving["interactions"][1]["operator_spec"] = Dict("form" => "equation_set", "equations" => Any["dE_dt = P_in - E/tau"])

    organized = _open_world_base_candidate_v2("manual_self_organized_control_v1")
    organized["interactions"][1]["operator_spec"] = _partial_operator_fixture_v2()
    organized["interactions"][1]["epistemic_state"] = "hypothesized"

    relay = _open_world_base_candidate_v2("manual_electrostatic_inertial_relay_v1")
    relay["interactions"][1]["operator_spec"] = Dict("form" => "program", "program_ref" => "bounded_relay_map_v1")
    relay["boundaries"][1]["kind"] = "fixed"

    channels = _open_world_base_candidate_v2("manual_selective_particle_channels_v1")
    channels["reservoirs"] = Any[
        Dict("reservoir_id" => "driver_reservoir", "kind" => "energy", "unit" => "J"),
        Dict("reservoir_id" => "particle_reservoir", "kind" => "particles", "unit" => "1"),
    ]
    channels["interactions"][1]["operator_spec"] = Dict("form" => "known_operator_ref", "ref" => "selective_channel_balance_v1")
    return Dict(
        "manual_temporal_open_closed_v1" => temporal,
        "manual_moving_boundary_pulse_v1" => moving,
        "manual_self_organized_control_v1" => organized,
        "manual_electrostatic_inertial_relay_v1" => relay,
        "manual_selective_particle_channels_v1" => channels,
    )
end

function public_negative_fixtures_v1()
    missing_discrimination = deepcopy(public_positive_fixtures_v1()["manual_self_organized_control_v1"])
    missing_discrimination["identity"]["design_id"] = "negative_missing_identifiability_v1"
    delete!(missing_discrimination["interactions"][1]["operator_spec"], "identifiability_conditions")

    below_floor = deepcopy(public_positive_fixtures_v1()["manual_self_organized_control_v1"])
    below_floor["identity"]["design_id"] = "negative_effect_below_floor_v1"
    below_floor["interactions"][1]["operator_spec"]["minimum_effect_size"]["value"] = 0.001

    prior_overreach = deepcopy(public_positive_fixtures_v1()["manual_temporal_open_closed_v1"])
    prior_overreach["identity"]["design_id"] = "negative_empirical_prior_overreach_v1"
    prior_overreach["interactions"][1]["epistemic_state"] = "empirical_prior"
    return Dict(
        "negative_missing_identifiability_v1" => missing_discrimination,
        "negative_effect_below_floor_v1" => below_floor,
        "negative_empirical_prior_overreach_v1" => prior_overreach,
    )
end

