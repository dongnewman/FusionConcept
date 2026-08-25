function evaluate_open_world_vertical_slice_v1(candidates;
        rules = default_open_world_physics_rules_v1(),
        coverage = default_open_world_rule_coverage_v1(rules))
    verification = verify_generic_ode_dae_event_adapter_v1()
    negative_control = run_generic_ode_negative_control_v1()
    records = Dict{String,Any}[]
    for (name, candidate) in sort!(collect(candidates); by = first)
        compilation = compile_open_world_genome_v2(candidate; rules = rules, coverage = coverage,
            mission_id = "method_vertical_slice_v1")
        erased = compile_open_world_genome_v2(erase_open_world_labels_v2(candidate); rules = rules,
            coverage = coverage, mission_id = "method_vertical_slice_v1")
        plans = plan_candidate_evidence_minimal_v1(compilation)
        erased_plans = plan_candidate_evidence_minimal_v1(erased)
        discrimination = evaluate_candidate_discrimination_v1(compilation.genome)
        preflight = engineering_lower_bound_preflight_v1(compilation.genome)
        operator_forms = String[String(get(get(item, "operator_spec", Dict{String,Any}()), "form", "unknown"))
            for item in get(compilation.genome.data, "interactions", Any[])]
        has_partial = "partial_operator" in operator_forms
        boundary_kind = isempty(get(compilation.genome.data, "boundaries", Any[])) ? "fixed" :
            String(get(compilation.genome.data["boundaries"][1], "kind", "fixed"))
        event_time = boundary_kind in ("moving", "topology_event") ? 1.0 : nothing
        solver_result = has_partial ? nothing : solve_generic_ode_dae_event_v1(
            initial_energy = 1.0, input_power = 0.2, decay_rate = 1.0,
            event_time = event_time, post_event_decay = 0.5, dt = 0.025)
        c0_status = String(compilation.assessments["C0"]["status"])
        c1_status = if c0_status != "pass"
            "unknown"
        elseif has_partial
            "unknown"
        elseif verification["pass"] && solver_result["max_abs_error"] < 1.0e-6
            "pass"
        else
            "fail"
        end
        c1_failure_scope = c1_status == "fail" ? "numerical_method" : nothing
        assessment = Dict{String,Any}(
            "C0" => compilation.assessments["C0"],
            "C1" => Dict("status" => c1_status, "assessment_scope" => "reduced_key_mechanism_only",
                "ruleset_hash" => compilation.ruleset_hash,
                "evidence_refs" => solver_result === nothing ? Any[] : Any["generic_ode_event_trajectory", "analytic_reference"],
                "promotion_scope_ref" => "method_c1_scope", "failure_scope" => c1_failure_scope,
                "validity_domain" => "0d_linear_balance_fixture", "claim_ceiling" => "C1"),
            "C2" => Dict("status" => "unsupported", "reason" => "integrated engineering closure not attempted"),
            "C3" => Dict("status" => "unsupported", "reason" => "mission-specific integrated evidence not attempted"),
        )
        push!(records, Dict{String,Any}(
            "candidate_id" => String(name), "identity_hash" => compilation.genome.identity_hash,
            "structural_hash" => compilation.genome.structural_hash, "ruleset_hash" => compilation.ruleset_hash,
            "coverage_hash" => compilation.coverage_hash,
            "mission_hash" => canonical_hash(compilation.genome.data["mission_contracts"]),
            "evidence_plan_hash" => canonical_hash(plans), "evaluation_hash" => compilation.evaluation_hash,
            "assessments" => assessment, "errors" => compilation.errors, "warnings" => compilation.warnings,
            "unknowns" => compilation.unknowns, "evidence_obligation_graph" => compilation.obligation_graph,
            "evidence_plans" => plans, "model_discrimination" => discrimination,
            "engineering_preflight" => preflight, "solver_evidence" => solver_result,
            "label_erase_invariance" => Dict(
                "structural_hash_equal" => compilation.genome.structural_hash == erased.genome.structural_hash,
                "obligation_graph_equal" => canonical_hash(compilation.obligation_graph) == canonical_hash(erased.obligation_graph),
                "evidence_plan_equal" => canonical_hash(plans) == canonical_hash(erased_plans)),
        ))
    end
    return Dict{String,Any}(
        "report_id" => "open_world_vertical_slice_v1", "date" => "2026-08-21",
        "ruleset_hash" => open_world_ruleset_hash_v1(rules), "coverage_hash" => canonical_hash(coverage),
        "candidate_records" => records, "numerical_verification" => verification,
        "negative_control" => negative_control,
        "exit_gate" => Dict(
            "three_candidates_C0_complete" => length(records) == 3 && all(r -> r["assessments"]["C0"]["status"] == "pass", records),
            "at_least_one_real_C1_resolution" => any(r -> r["assessments"]["C1"]["status"] in ("pass", "fail"), records),
            "negative_control_correctly_falsified" => negative_control["status"] == "correctly_falsified",
            "no_numerical_to_topology_escalation" => negative_control["failure_scope"] != "topology_skeleton",
            "label_erase_invariant" => all(r -> all(values(r["label_erase_invariance"])), records),
            "all_unknowns_have_next_actions" => all(r -> all(o -> get(o, "status", "unknown") != "unknown" ||
                !isempty(get(o, "next_action_refs", Any[])), r["evidence_obligation_graph"]["obligations"]), records),
        ),
        "claim_limits" => Any[
            "method fixtures do not claim original fusion concepts",
            "C1 applies only to the reduced key mechanism and stated parameter domain",
            "engineering preflight carries zero promotion credit",
            "no net-energy, buildability, C2, or C3 conclusion is supported",
        ],
    )
end

