using Test
using FusionConceptAI

@testset "v109 source-pinned material engineering screen" begin
    root = normpath(joinpath(@__DIR__, ".."))
    catalog = load_material_property_catalog_v109(root)
    audit = audit_material_property_catalog_v109(catalog)
    @test audit["status"] == "closed_for_rejection_screen"
    @test audit["record_count"] == 7
    @test audit["complete_engineering_credit"] === false

    registry = OperatorProviderRegistryV94()
    register_provider_v94!(registry, material_screen_provider_capability_v109(),
        (_, _) -> nothing)
    @test route_provider_v94(registry,
        material_screen_requirement_v109())["status"] == "closed"

    result = run_material_engineering_campaign_v109(root)
    @test result["status"] == "complete"
    @test result["reference_regression_status"] == "pass"
    @test result["reference_regression_pass_count"] == 2
    @test result["reference_bypass_count"] == 0
    @test result["input_dynamic_survivor_count"] == 96
    @test result["material_screen_reject_count"] == 96
    @test result["material_screen_survivor_count"] == 0
    @test result["candidate_state_histogram"] == Dict("material_screen_reject" => 96)
    @test result["blocker_histogram"] == Dict(
        "blanket_loss_of_flow_temperature" => 96,
        "full_nuclear_radial_build" => 96)
    @test result["unsupported_candidate_count"] == 0
    @test result["provider_system_failure_count"] == 0
    @test result["whole_device_credible_count"] == 0
    @test result["complete_engineering_obligation_credit"] === false
    @test all(row -> row["unsupported_candidate_classification_used"] === false,
        result["rows"])

    dynamic = run_dynamic_fault_campaign_v108(root)
    screen, _ = run_whole_device_assembly_screen_v106(root)
    _, assemblies = run_whole_device_assembly_generation_v105(root)
    upstream = first([row for row in dynamic["rows"] if row["status"] == "pass"])
    hash = upstream["physical_design_hash"]
    assembly = only(item for item in assemblies if item["physical_design_hash"] == hash)
    screen_row = only(item for item in screen["rows"] if
        item["physical_design_hash"] == hash)
    original = execute_material_engineering_provider_v109(
        assembly, screen_row, upstream, catalog)
    relabeled = deepcopy(assembly)
    relabeled["source_candidate_result_hash"] = repeat("f", 64)
    relabeled["source_candidate_solver_input_hash"] = repeat("e", 64)
    @test execute_material_engineering_provider_v109(
        relabeled, screen_row, upstream, catalog)["result_hash"] ==
        original["result_hash"]
    permuted = deepcopy(catalog)
    reverse!(permuted["records"])
    @test execute_material_engineering_provider_v109(
        assembly, screen_row, upstream, permuted)["result_hash"] ==
        original["result_hash"]
    missing = deepcopy(catalog)
    filter!(item -> item["record_id"] != "eurofer_blanket_structure_temperature",
        missing["records"])
    @test_throws ArgumentError execute_material_engineering_provider_v109(
        assembly, screen_row, upstream, missing)
end
