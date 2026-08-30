using Test
using FusionConceptAI

@testset "v136 per-region realization routing" begin
    mixed = Dict{String,Any}(
        "regions" => [
            Dict("region_key" => "a", "field_semantics" => "axisymmetric_closed",
                "dimension" => 2),
            Dict("region_key" => "b", "field_semantics" =>
                "three_dimensional_closed", "dimension" => 3),
            Dict("region_key" => "c", "field_semantics" => "open_guiding_field",
                "boundary" => "open", "dimension" => 1)],
        "interfaces" => [
            Dict("interface_key" => "ab", "dimension" => 2),
            Dict("interface_key" => "bc", "dimension" => 2)])
    plan = compile_region_realization_plan_v136(mixed)
    @test plan["status"] == "closed"
    @test plan["capability_class"] == "mixed_multiregion"
    @test plan["majority_route_used"] == false
    @test Set(route["capability_class"] for route in plan["region_routes"]) ==
        Set(["axisymmetric_closed", "three_dimensional_closed", "open_field"])
    @test length(unique(route["selected_provider"] for route in
        plan["region_routes"])) == 3
    @test all(route["status"] == "closed" for route in plan["interface_routes"])

    relabeled = deepcopy(mixed)
    relabeled["candidate_id"] = "forbidden-candidate-id"
    relabeled["device_family"] = "forbidden-family"
    relabeled["label"] = "renamed"
    @test compile_region_realization_plan_v136(relabeled)["plan_hash"] ==
        plan["plan_hash"]
    permuted = deepcopy(mixed)
    reverse!(permuted["regions"]); reverse!(permuted["interfaces"])
    @test compile_region_realization_plan_v136(permuted)["plan_hash"] ==
        plan["plan_hash"]

    absent = compile_region_realization_plan_v136(mixed;
        registry = OperatorProviderRegistryV94())
    @test absent["status"] == "unsupported"
    @test !isempty(absent["blockers"])

    unresolved = Dict("regions" => [Dict("region_key" => "h",
        "field_semantics" => "hybrid_field", "dimension" => 3)],
        "interfaces" => Any[])
    unresolved_plan = compile_region_realization_plan_v136(unresolved)
    @test unresolved_plan["status"] == "unsupported"
    @test "h:hybrid_region_requires_explicit_subregions" in
        unresolved_plan["blockers"]
end

@testset "v136 proxy separation and quota-only scheduling" begin
    clean = audit_proxy_gate_separation_v136(Dict(
        "physical_gates" => [Dict("gate_id" => "equilibrium_residual",
            "value" => 1e-9)],
        "scheduling_features" => Dict("field_quality" => 0.8)))
    @test clean["status"] == "pass"
    @test clean["proxy_physical_credit"] == false
    contaminated = audit_proxy_gate_separation_v136(Dict(
        "physical_gates" => [Dict("gate_id" => "field_quality_penalty",
            "value" => 0.8)]))
    @test contaminated["status"] == "fail"

    axis_plan = compile_region_realization_plan_v136(Dict("regions" => [Dict(
        "region_key" => "r", "field_semantics" => "axisymmetric_closed",
        "dimension" => 2)], "interfaces" => Any[]))
    open_plan = compile_region_realization_plan_v136(Dict("regions" => [Dict(
        "region_key" => "r", "field_semantics" => "open_guiding_field",
        "boundary" => "open", "dimension" => 1)], "interfaces" => Any[]))
    rows = [Dict("candidate_ref" => "a", "realization_plan" => axis_plan,
            "scheduler_score" => 0.4, "scheduling_features" => Dict(
                "field_quality" => 0.4)),
        Dict("candidate_ref" => "b", "realization_plan" => axis_plan,
            "scheduler_score" => 0.9, "scheduling_features" => Dict(
                "field_quality" => 0.9)),
        Dict("candidate_ref" => "c", "realization_plan" => open_plan,
            "scheduler_score" => 0.2, "scheduling_features" => Dict(
                "field_quality" => 0.2))]
    frontier = capability_quota_frontier_v136(rows, Dict(
        "axisymmetric_closed" => 1, "open_field" => 1,
        "three_dimensional_closed" => 0, "mixed_multiregion" => 0))
    @test only(frontier["selected_by_class"]["axisymmetric_closed"])[
        "candidate_ref"] == "b"
    @test frontier["quota_is_physical_gate"] == false
    @test all(item["physical_credit"] == false for group in
        values(frontier["selected_by_class"]) for item in group)
end

@testset "v136 field-period geometry sensitivity" begin
    declaration = Dict{String,Any}(
        "field_periods" => 2,
        "R_modes" => [Dict("m" => 0, "n" => 0, "coefficient_m" => 5.5),
            Dict("m" => 1, "n" => 0, "coefficient_m" => 0.5),
            Dict("m" => 1, "n" => 1, "coefficient_m" => 0.08)],
        "Z_modes" => [Dict("m" => 1, "n" => 0, "coefficient_m" => 0.5),
            Dict("m" => 1, "n" => 1, "coefficient_m" => 0.08)],
        "coil_templates" => [Dict("major_radius_m" => 6.4,
            "minor_radius_m" => 0.35, "vertical_m" => 0.0,
            "phase_fraction" => 0.1, "current_a" => 1.0e6)])
    nfp2 = materialize_periodic_boundary_coils_v136(declaration)
    declaration["field_periods"] = 5
    nfp5 = materialize_periodic_boundary_coils_v136(declaration)
    @test audit_field_period_sensitivity_v136(nfp2, nfp5)["status"] == "pass"
    fake = deepcopy(nfp2); fake["field_periods"] = 5
    fake["wout_sha256"] = "a"^64
    nfp2["wout_sha256"] = "a"^64
    @test audit_field_period_sensitivity_v136(nfp2, fake)["status"] == "fail"
    one_to_five_unchanged = deepcopy(nfp2)
    one_to_five_unchanged["field_periods"] = 1
    @test audit_field_period_sensitivity_v136(
        one_to_five_unchanged, fake)["status"] == "fail"
end

@testset "v136 complete interface coupling only" begin
    topology = Dict{String,Any}(
        "regions" => [Dict("region_key" => "left",
            "field_semantics" => "axisymmetric_closed", "dimension" => 2),
            Dict("region_key" => "right", "field_semantics" =>
            "open_guiding_field", "boundary" => "open", "dimension" => 1)],
        "interfaces" => [Dict("interface_key" => "join", "dimension" => 2)])
    plan = compile_region_realization_plan_v136(topology)
    routes = Dict(route["region_key"] => route["selected_provider"] for route in
        plan["region_routes"])
    results = Dict(
        "left" => Dict("status" => "pass", "provider_key" => routes["left"],
            "plan_hash" => plan["plan_hash"], "interface_traces" => Dict(
                "join" => Dict("particle_flux" => Dict("value" => 1.2,
                    "response" => 1.0)))),
        "right" => Dict("status" => "pass", "provider_key" => routes["right"],
            "plan_hash" => plan["plan_hash"], "interface_traces" => Dict(
                "join" => Dict("particle_flux" => Dict("value" => 1.0,
                    "response" => 1.0)))))
    interface = [Dict("interface_key" => "join", "minus_region_key" => "left",
        "plus_region_key" => "right", "quantities" => ["particle_flux"],
        "tolerance" => 1e-10)]
    coupled = couple_region_interfaces_v136(plan, results, interface)
    @test coupled["status"] == "pass"
    @test maximum(abs, coupled["final_residual"]) <= 1e-10
    missing = deepcopy(results); delete!(missing, "right")
    blocked = couple_region_interfaces_v136(plan, missing, interface)
    @test blocked["status"] == "not_solved"
    @test blocked["partial_subgraph_credit"] == false
end
