using Test
using FusionConceptAI

@testset "v84 fixed-topology realization grammar and seed independence" begin
    grammar = default_candidate_realization_grammar_v2(repeat("a", 64))
    @test grammar.schema_version == "2.0.0"
    @test Set(grammar.allowed_routes) == Set(["closed/mixed", "open/mixed"])
    @test all(rule -> !rule.required || rule.minimum_count >= 1,
        grammar.component_rules)
    @test length(grammar.grammar_hash) == 64

    base = compile_realization_variant_tuple_v1(grammar;
        physical_variant = 2, operating_variant = 3, control_variant = 4)
    operating_changed = compile_realization_variant_tuple_v1(grammar;
        physical_variant = 2, operating_variant = 9, control_variant = 4)
    physical_changed = compile_realization_variant_tuple_v1(grammar;
        physical_variant = 8, operating_variant = 3, control_variant = 4)
    control_changed = compile_realization_variant_tuple_v1(grammar;
        physical_variant = 2, operating_variant = 3, control_variant = 7)
    base_binding = generate_decoupled_realization_binding_v1(grammar, base)
    operating_binding = generate_decoupled_realization_binding_v1(
        grammar, operating_changed)
    physical_binding = generate_decoupled_realization_binding_v1(grammar, physical_changed)
    control_binding = generate_decoupled_realization_binding_v1(grammar, control_changed)
    @test base_binding["physical"] == operating_binding["physical"]
    @test base_binding["control"] == operating_binding["control"]
    @test base_binding["operating"] != operating_binding["operating"]
    @test base_binding["operating"] == physical_binding["operating"]
    @test base_binding["control"] == physical_binding["control"]
    @test base_binding["physical"] != physical_binding["physical"]
    @test base_binding["physical"] == control_binding["physical"]
    @test base_binding["operating"] == control_binding["operating"]
    @test base_binding["control"] != control_binding["control"]

    library = default_realization_basis_library_v1(base_binding)
    @test Set(keys(library)) == REALIZATION_BASIS_FAMILIES_V1
    @test all(spec -> isfinite(evaluate_realization_basis_v1(spec, 0.4, 0.7)),
        values(library))
end

@testset "v84 closed and open mixed slices share the v68 residual graph" begin
    grammar = default_candidate_realization_grammar_v2(repeat("b", 64))
    variants = compile_realization_variant_tuple_v1(grammar;
        physical_variant = 1, operating_variant = 1, control_variant = 1)
    for route in ("closed/mixed", "open/mixed")
        evaluation = evaluate_realization_vertical_slice_v84(grammar, variants, route)
        @test evaluation["plan"].status == :pass
        @test evaluation["result"].status == :pass
        @test evaluation["hard_gate_passed"]
        @test all(values(evaluation["hard_gates"]))
        @test all(audit -> audit["status"] == "pass",
            evaluation["result"].audits["jacobian_directional_audits"])
        observed = evaluation["result"].observables[
            "v84_$(replace(route, '/' => '_'))_stage4_stage5"]
        @test observed["stage_residual_rows"]["stage_3"] ==
            FusionConceptAI.LONGITUDINAL_STATE_IDS_V1
        @test Set(observed["joint_optimization_variables"]) == Set([
            "coil_basis", "operating_point", "actuator_timing", "controller_modes"])
        @test observed["evidence_ceiling"] == "L1_joint_residual_only"
    end
end

@testset "v84 feasibility-first complexity Pareto and fidelity firewall" begin
    grammar = default_candidate_realization_grammar_v2(repeat("c", 64))
    scope = compile_minimality_scope_v1(grammar)
    archive = RealizationParetoArchiveV1(scope)
    v1 = compile_realization_variant_tuple_v1(grammar;
        physical_variant = 1, operating_variant = 1, control_variant = 1)
    v2 = compile_realization_variant_tuple_v1(grammar;
        physical_variant = 2, operating_variant = 1, control_variant = 1)
    b1 = generate_decoupled_realization_binding_v1(grammar, v1)
    b2 = generate_decoupled_realization_binding_v1(grammar, v2)
    c1 = compile_device_complexity_manifest_v1(grammar, b1)
    c2 = compile_device_complexity_manifest_v1(grammar, b2)
    passed = Dict(id => true for id in scope.hard_gate_ids)
    failed = copy(passed); failed["stage5_low_order_margin"] = false
    @test insert_realization_pareto_v1!(archive; candidate_id = "failed",
        complexity = c1, hard_gates = failed)["status"] == "rejected_before_pareto"
    @test insert_realization_pareto_v1!(archive; candidate_id = "candidate_1",
        complexity = c1, hard_gates = passed)["status"] == "inserted"
    @test insert_realization_pareto_v1!(archive; candidate_id = "candidate_2",
        complexity = c2, hard_gates = passed)["status"] in ("inserted", "dominated")
    @test length(archive.rejected) == 1
    @test all(entry -> entry["complexity"].evidence_level == scope.evidence_level,
        archive.entries)
    serialized = realization_pareto_archive_to_dict_v1(archive)
    @test serialized["selection_rule"] ==
        "hard_gates_then_six_coordinate_nondominance_no_scalar_score"

    feedback = compile_one_way_fidelity_feedback_v1(
        candidate_binding_hash = b1["candidate_binding_hash"],
        completed_level = "fast_biot_savart", completed_status = "pass",
        next_sample_count = 64, next_basis_order = 3,
        evidence_hash = repeat("d", 64))
    @test feedback["next_level"] == "poincare"
    @test feedback["may_update_sampling"]
    @test feedback["may_update_basis_order"]
    @test !feedback["may_rewrite_lower_fidelity_feasibility"]
    progression = compile_realization_fidelity_progression_v1(
        candidate_binding_hash = b1["candidate_binding_hash"], records = [
            Dict("level" => "analytic_lower_bound", "status" => "pass",
                "evidence_hash" => repeat("e", 64)),
            Dict("level" => "fast_biot_savart", "status" => "pass",
                "evidence_hash" => repeat("f", 64))])
    @test progression["next_level"] == "poincare"
    @test progression["may_advance"]
    @test !progression["higher_fidelity_may_rewrite_lower_feasibility"]
    @test_throws ArgumentError compile_realization_fidelity_progression_v1(
        candidate_binding_hash = b1["candidate_binding_hash"], records = [
            Dict("level" => "poincare", "status" => "pass",
                "evidence_hash" => repeat("1", 64))])
end
