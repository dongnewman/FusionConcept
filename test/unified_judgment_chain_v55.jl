using Test
using JSON3
using FusionConceptAI

include("unified_judgment_fixture_factory_v55.jl")

function _v55_stage_by_id(result, id)
    return only(stage for stage in result["stages"] if stage["stage_id"] == id)
end

@testset "uniform eight-stage judgment chain v55" begin
    iter = representative_judgment_fixture_v55(:iter)
    c2w = representative_judgment_fixture_v55(:c2w)
    iter_result = evaluate_uniform_judgment_v55(iter)
    c2w_result = evaluate_uniform_judgment_v55(c2w)

    for result in (iter_result, c2w_result)
        @test result["decision"] == "pass"
        @test result["stage_order"] == collect(UNIFIED_JUDGMENT_STAGE_IDS_V55)
        @test length(result["stages"]) == 8
        @test all(stage -> stage["status"] == "pass", result["stages"])
        @test result["all_eight_stages_executed"]
        @test !result["family_or_parent_used_for_routing"]
        @test result["eligible_for_promotion_review"]
        @test !result["promotion_authorized"]
    end

    @test _v55_stage_by_id(iter_result, "perturbation_and_stability")["stage_id"] ==
        _v55_stage_by_id(c2w_result, "perturbation_and_stability")["stage_id"]

    relabeled = deepcopy(iter)
    relabeled["family"] = "mirror"
    relabeled["parent_family"] = "inertial_confinement"
    relabeled["display_label"] = "deliberately wrong label"
    relabeled_result = evaluate_uniform_judgment_v55(relabeled)
    @test relabeled_result["decision"] == iter_result["decision"]
    @test relabeled_result["routing_input_hash"] == iter_result["routing_input_hash"]
    @test relabeled_result["stages"] == iter_result["stages"]
    @test evaluate_uniform_judgment_v55(erase_judgment_labels_v55(iter))["routing_input_hash"] ==
        iter_result["routing_input_hash"]

    parent_default = deepcopy(iter)
    parent_default["physical_description"]["fields"][1]["value_origin"] = "parent_template"
    parent_result = evaluate_uniform_judgment_v55(parent_default)
    @test parent_result["decision"] == "fail"
    @test "physical_description_completeness" in parent_result["failed_stage_ids"]

    nominal_ledger = deepcopy(iter)
    nominal_ledger["net_energy"]["generated_nominal"] = true
    nominal_result = evaluate_uniform_judgment_v55(nominal_ledger)
    @test nominal_result["decision"] == "fail"
    @test "net_energy_closure" in nominal_result["failed_stage_ids"]

    unclosed = deepcopy(iter)
    unclosed["state_evolution"]["residuals"][1]["source_S"] = 9.0
    unclosed_result = evaluate_uniform_judgment_v55(unclosed)
    @test unclosed_result["decision"] == "fail"
    @test "conservation_and_state_evolution" in unclosed_result["failed_stage_ids"]

    incomplete = deepcopy(c2w)
    empty!(incomplete["physical_description"]["controllers"])
    incomplete_result = evaluate_uniform_judgment_v55(incomplete)
    @test incomplete_result["decision"] == "fail"
    @test "physical_description_completeness" in incomplete_result["failed_stage_ids"]

    explicit_no_controller = deepcopy(c2w)
    empty!(explicit_no_controller["physical_description"]["controllers"])
    explicit_no_controller["physical_description"]["control_policy"] = Dict(
        "mode" => "explicit_no_controller", "actuator_refs" => Any[],
        "applicability_basis" => "reference scope excludes active control")
    no_controller_result = evaluate_uniform_judgment_v55(explicit_no_controller)
    @test no_controller_result["decision"] == "pass"

    passive = deepcopy(c2w)
    empty!(passive["physical_description"]["controllers"])
    passive["physical_description"]["control_policy"] = Dict(
        "mode" => "passive_stability", "actuator_refs" => Any[],
        "applicability_basis" => "declared passive stabilizing response")
    @test evaluate_uniform_judgment_v55(passive)["decision"] == "pass"

    open_loop = deepcopy(c2w)
    empty!(open_loop["physical_description"]["controllers"])
    open_loop["physical_description"]["control_policy"] = Dict(
        "mode" => "open_loop_actuation", "actuator_refs" => Any["fuel_and_heating"],
        "applicability_basis" => "programmed actuator with no feedback target")
    @test evaluate_uniform_judgment_v55(open_loop)["decision"] == "pass"

    net_mission = deepcopy(c2w)
    net_mission["mission"]["positive_net_energy_required"] = true
    net_result = evaluate_uniform_judgment_v55(net_mission)
    @test net_result["decision"] == "fail"
    @test "net_energy_closure" in net_result["failed_stage_ids"]

    unresolved = deepcopy(iter)
    filter!(item -> item["check_id"] != "experimental_anchor",
        unresolved["uncertainty_evidence"]["checks"])
    unresolved_result = evaluate_uniform_judgment_v55(unresolved)
    @test unresolved_result["decision"] == "unknown"
    @test isempty(unresolved_result["failed_stage_ids"])
    @test unresolved_result["unknown_stage_ids"] == ["uncertainty_and_evidence"]
    @test !unresolved_result["eligible_for_promotion_review"]

    archive = evaluate_all_search_results_v55([iter, c2w, nominal_ledger, incomplete])
    @test archive["input_candidate_count"] == 4
    @test archive["evaluated_candidate_count"] == 4
    @test archive["dropped_candidate_count"] == 0
    @test archive["summary"]["pass_count"] == 2
    @test archive["summary"]["fail_count"] == 2
    @test archive["summary"]["family_or_parent_routed_count"] == 0
    @test archive["summary"]["promotion_authorized_count"] == 0

    root = normpath(joinpath(@__DIR__, ".."))
    for schema_name in ("uniform_fusion_judgment_candidate_v55.schema.json",
            "uniform_fusion_judgment_report_v55.schema.json")
        schema = JSON3.read(read(joinpath(root, "schemas", schema_name), String))
        @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    end
end
