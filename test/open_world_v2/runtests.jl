using Test
using JSON3
using FusionConceptAI

const OPEN_WORLD_V2_TEST_ROOT = normpath(joinpath(@__DIR__, "..", ".."))
include(joinpath(@__DIR__, "fixture_factory.jl"))

@testset "OpenWorld v2 trusted R0/R1 slice" begin
    rules = default_open_world_physics_rules_v1()
    coverage = default_open_world_rule_coverage_v1(rules)
    @test isempty(reduce(vcat, validate_physics_rule_manifest_v1.(rules)))
    @test isempty(validate_rule_coverage_manifest_v1(coverage))
    @test coverage["ruleset_hash"] == open_world_ruleset_hash_v1(rules)

    for (name, candidate) in public_positive_fixtures_v1()
        result = compile_open_world_genome_v2(candidate; rules = rules, coverage = coverage)
        @test isempty(result.errors)
        @test result.assessments["C0"]["status"] == "pass"
        @test !isempty(result.obligation_graph["obligations"])
        erased = compile_open_world_genome_v2(erase_open_world_labels_v2(candidate); rules = rules, coverage = coverage)
        @test result.genome.structural_hash == erased.genome.structural_hash
        @test canonical_hash(result.obligation_graph) == canonical_hash(erased.obligation_graph)
        @test result.ruleset_hash == erased.ruleset_hash
        @test !isempty(name)
    end

    negatives = public_negative_fixtures_v1()
    missing = compile_open_world_genome_v2(negatives["negative_missing_identifiability_v1"])
    below = compile_open_world_genome_v2(negatives["negative_effect_below_floor_v1"])
    prior = compile_open_world_genome_v2(negatives["negative_empirical_prior_overreach_v1"])
    @test missing.assessments["C0"]["status"] == "fail"
    @test any(contains("identifiability_conditions"), missing.errors)
    @test below.assessments["C0"]["status"] == "fail"
    @test any(contains("minimum effect"), below.errors)
    @test prior.assessments["C0"]["status"] == "fail"
    @test any(contains("empirical prior"), prior.errors)

    unsupported = deepcopy(first(values(public_positive_fixtures_v1())))
    unsupported["interactions"][1]["operator_spec"] = Dict("form" => "novel_unknown_operator")
    unsupported_result = compile_open_world_genome_v2(unsupported)
    @test isempty(unsupported_result.errors)
    @test unsupported_result.assessments["C0"]["status"] == "unknown"
    @test any(item -> item["kind"] == "ruleset_coverage_gap", unsupported_result.unknowns)

    topology_failure = Dict(
        "failure_id" => "f1", "failed_obligation_ids" => Any["o1"], "scope_type" => "topology_skeleton",
        "scope_refs" => Any["t1"], "excluded_alternatives" => Any[], "tuning_budget_consumed" => 0,
        "evidence_refs" => Any["e1"], "ruleset_hash" => open_world_ruleset_hash_v1(), "escalation_conditions" => Any[])
    @test length(validate_failure_record_v1(topology_failure)) == 2

    seeds = JSON3.read(read(joinpath(OPEN_WORLD_V2_TEST_ROOT, "examples", "seed_devices.json"), String), Dict{String,Any})
    migrated = migrate_genome_v1_to_v2(first(seeds["designs"]))
    @test migrated.data["schema_version"] == "2.0.0"
    @test !haskey(migrated.data, "family")
    @test haskey(migrated.legacy_hashes, "physics_hash")

    schema_names = ["open_world_genome_v2.schema.json", "partial_operator_v2.schema.json",
        "evidence_obligation_graph_v2.schema.json", "physics_rule_manifest_v1.schema.json",
        "rule_coverage_manifest_v1.schema.json", "promotion_scope_v1.schema.json", "failure_record_v1.schema.json"]
    for name in schema_names
        parsed = JSON3.read(read(joinpath(OPEN_WORLD_V2_TEST_ROOT, "schemas", name), String))
        @test parsed[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    end
end

@testset "OpenWorld v2 R3A/R3B scope and OOD" begin
    numerical = numerical_verification_report_v1()
    @test numerical["pass"]
    @test numerical["minimum_effect_resolved"]

    failure = Dict("failure_id" => "fnum", "failed_obligation_ids" => Any["o1"],
        "scope_type" => "numerical_method", "scope_refs" => Any["solver"],
        "excluded_alternatives" => Any["closure_a"], "tuning_budget_consumed" => 10.0,
        "evidence_refs" => Any["e1"], "ruleset_hash" => open_world_ruleset_hash_v1(),
        "escalation_conditions" => Any["all alternatives exhausted"])
    @test !audit_failure_scope_escalation_v1(failure, "topology_skeleton")["allowed"]

    candidate = public_positive_fixtures_v1()["manual_temporal_open_closed_v1"]
    scope = deepcopy(candidate["promotion_scopes"][1])
    scope["required_ruleset_hash"] = open_world_ruleset_hash_v1()
    prior = deepcopy(scope); prior["scope_id"] = "prior"; prior["max_gate"] = "none"
    intersection = intersect_promotion_scopes_v1(Any[scope, prior]; current_ruleset_hash = open_world_ruleset_hash_v1())
    @test intersection["max_gate"] == "none"
    @test !promotion_scope_authorizes_v1(intersection, "C1"; mission = "method_vertical_slice_v1", domain = "plasma_domain")

    proof = Dict("obligation_id" => "o1", "predicate_id" => "p1", "predicate_version" => "1",
        "evaluated_inputs" => Dict("x" => 1), "evidence_refs" => Any["e1"], "result" => true,
        "validity_domain" => "fixture", "uncertainty" => 0.0, "reproduction_trace" => "x == 1")
    @test audit_not_applicable_v1(Dict("status" => "not_applicable"), proof)["valid"]
    @test !audit_not_applicable_v1(Dict("status" => "not_applicable"))["valid"]

    domain = Dict("dimensionless" => Dict("x" => Any[0.0, 1.0]),
        "operator_class" => Any["equation_set"], "geometry_class" => Any["0d"])
    outside = basic_ood_assessment_v1(Dict("dimensionless" => Dict("x" => 2.0),
        "operator_class" => "partial_operator", "geometry_class" => "3d"), domain)
    @test outside["status"] == "out_of_domain"
    @test outside["promotion_action"] == "downgrade_to_unknown"
    @test !outside["silent_extrapolation"]

    original = semantic_normal_form_minimal_v1(candidate)
    erased = semantic_normal_form_minimal_v1(erase_open_world_labels_v2(candidate))
    @test original["semantic_normal_form_hash"] == erased["semantic_normal_form_hash"]
    @test adapt_imas_record_minimal_v1(Dict("time" => 0.0))["status"] == "unknown"
    @test adapt_openpmd_product_minimal_v1(Dict("iteration" => 0))["status"] == "unknown"
end

@testset "OpenWorld v2 R2 vertical slice" begin
    candidates = public_positive_fixtures_v1()
    selected = Dict(name => candidates[name] for name in
        ["manual_temporal_open_closed_v1", "manual_moving_boundary_pulse_v1", "manual_self_organized_control_v1"])
    report = evaluate_open_world_vertical_slice_v1(selected)
    @test all(values(report["exit_gate"]))
    @test report["numerical_verification"]["pass"]
    @test report["negative_control"]["status"] == "correctly_falsified"
    @test report["negative_control"]["failure_scope"] == "parameter_instance"
    @test count(record -> record["assessments"]["C1"]["status"] == "pass", report["candidate_records"]) == 2
    @test count(record -> record["assessments"]["C1"]["status"] == "unknown", report["candidate_records"]) == 1
    @test all(record -> record["engineering_preflight"]["promotion_credit"] == 0, report["candidate_records"])
    @test all(record -> !isempty(record["evidence_plans"]), report["candidate_records"])
    for schema in ["evidence_request_v1.schema.json", "evidence_acquisition_plan_v1.schema.json", "engineering_bound_check_v1.schema.json"]
        @test JSON3.read(read(joinpath(OPEN_WORLD_V2_TEST_ROOT, "schemas", schema), String))[Symbol("\$schema")] ==
            "https://json-schema.org/draft/2020-12/schema"
    end
end

@testset "OpenWorld v2 R4 controlled search" begin
    seed = public_positive_fixtures_v1()["manual_temporal_open_closed_v1"]
    candidates = generate_open_world_candidates_v2(seed, 64)
    @test length(candidates) == 64
    @test all(candidate -> !haskey(candidate, "family") && isempty(candidate["classifications"]), candidates)
    compiled = [Dict("compilation" => compile_open_world_genome_v2(candidate),
        "semantic_key" => parse_open_world_genome_v2(candidate).structural_hash) for candidate in candidates]
    @test all(item -> item["compilation"].assessments["C0"]["status"] == "pass", compiled)
    archive = build_pareto_behavior_archive_v1(compiled)
    @test length(archive["unique_records"]) == 64
    @test archive["semantic_duplicate_rate"] == 0.0
    @test !archive["physics_winner_claimed"]
    allocation = allocate_evidence_budget_v1(archive["unique_records"]; total_budget = 64.0)
    @test all(item -> item["topology_failure_authorized"], allocation["allocations"])
    stagnation = archive_stagnation_status_v1([2, 1, 0, 0, 0]; window = 3)
    @test stagnation["stagnant"] && stagnation["restart_recommended"]
end

@testset "OpenWorld v2 R5 evidence and coupling" begin
    capabilities = default_evidence_capability_registry_v1()
    request = Dict("request_id" => "r1", "question_kind" => "parameter_bound",
        "admissible_evidence_classes" => Any["analytic", "existing_experimental_data"],
        "budget_limits" => Dict("relative_cost" => 5.0))
    plan = plan_evidence_acquisition_v1(request; capabilities = capabilities)
    @test plan["status"] == "planned"
    @test first(plan["selected_routes"]) == "analytic_interval_bound_v1"
    @test all(route -> haskey(route, "correlation_group"), plan["route_correlations"])
    resolution = resolve_obligation_with_analytic_bound_v1(Dict("obligation_id" => "o1");
        interval = Any[0.1, 0.5], pass_upper_bound = 1.0)
    @test resolution["status"] == "pass" && resolution["evidence_class"] == "analytic"

    contract = default_two_reservoir_coupling_contract_v1()
    @test isempty(validate_coupling_contract_v1(contract))
    coupled = run_coupled_two_reservoir_v1(contract)
    @test coupled["status"] == "pass"
    @test coupled["interface_conservation_pass"] && coupled["global_error_budget_pass"]
    negative = deepcopy(contract); negative["duplicate_flux_prevention"] = false
    @test run_coupled_two_reservoir_v1(negative)["status"] == "coupling_unsupported"
    @test !fmi_adapter_manifest_minimal_v1()["co_simulation_algorithm_provided"]
    for schema in ["evidence_capability_manifest_v1.schema.json", "coupling_contract_v1.schema.json"]
        @test JSON3.read(read(joinpath(OPEN_WORLD_V2_TEST_ROOT, "schemas", schema), String))[Symbol("\$schema")] ==
            "https://json-schema.org/draft/2020-12/schema"
    end
end
