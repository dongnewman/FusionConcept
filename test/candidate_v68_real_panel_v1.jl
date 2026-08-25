using Test
using JSON3
using FusionConceptAI

@testset "candidate v68 real fixed panel v1" begin
    root = normpath(joinpath(@__DIR__, ".."))
    panel_path = joinpath(root, "fixtures", "candidate_v68_real_panel_v1.json")
    panel = load_candidate_v68_real_panel_v1(panel_path)
    @test length(panel["entries"]) == 10
    @test length(panel["required_obligations"]) == 16
    for route in ("closed_flux", "open_flux")
        records = filter(item -> item.route == route, panel["entries"])
        @test length(records) == 5
        @test count(item -> item.control_role == "positive_control", records) == 2
        @test count(item -> item.control_role == "candidate", records) == 2
        @test count(item -> item.control_role == "negative_control", records) == 1
    end

    first_audit = audit_candidate_v68_real_panel_v1(root, panel_path)
    second_audit = audit_candidate_v68_real_panel_v1(root, panel_path)
    @test first_audit["deterministic_hash"] == second_audit["deterministic_hash"]
    @test first_audit["complete_c2_acceptance"]["passed"] === false
    @test first_audit["complete_c2_acceptance"]["closed_flux_observed"] == 0
    @test first_audit["complete_c2_acceptance"]["open_flux_observed"] == 0
    for (route, narrow_count) in (("closed_flux", 1), ("open_flux", 3))
        summary = first_audit["route_summaries"][route]
        @test summary["entry_count"] == 5
        @test summary["source_integrity_pass_count"] == 5
        @test summary["component_fail_count"] == 0
        @test summary["narrow_failure_count"] == narrow_count
        @test summary["unknown_count"] == 5
        @test summary["unsupported_count"] == 0
        @test summary["v68_execution_authorized_count"] == 0
    end
    @test all(entry -> all(source -> source["status"] == "pass",
        entry["source_audits"]), first_audit["entries"])

    by_id = Dict(String(item["panel_entry_id"]) => item for item in first_audit["entries"])
    @test "ion_energy_state" in by_id["closed_positive_iter"]["incomplete_obligations"]
    @test "electron_energy_state" in by_id["open_positive_c2w"]["incomplete_obligations"]
    @test "actuator_efficiency" in by_id["open_positive_wham"]["incomplete_obligations"]
    for id in ("closed_negative_discrete_coil", "open_negative_local_saddle",
            "open_candidate_mirror_low_force", "open_candidate_mirror_high_ratio")
        @test by_id[id]["status"] == "unknown"
        @test by_id[id]["classification_code"] ==
            "unknown_incomplete_inputs_with_narrow_failure"
        @test by_id[id]["complete_c2_result"] === false
    end

    original = panel["entries"][1]
    relabeled = RealCandidatePanelEntryV1(original.panel_entry_id * "_renamed",
        "erased_candidate_label", original.candidate_binding_hash, original.binding_hash_kind,
        original.route, original.control_role, deepcopy(original.sources),
        deepcopy(original.evidence), deepcopy(original.hard_failures), original.evidence_ceiling)
    original_result = compile_real_candidate_panel_entry_v1(original, root,
        panel["required_obligations"])
    relabeled_result = compile_real_candidate_panel_entry_v1(relabeled, root,
        panel["required_obligations"])
    @test original_result.routing_projection_hash == relabeled_result.routing_projection_hash
    @test original_result.classification_code == relabeled_result.classification_code

    bad_sources = deepcopy(original.sources)
    bad_sources[1]["sha256"] = repeat("0", 64)
    bad = RealCandidatePanelEntryV1(original.panel_entry_id, original.candidate_id,
        original.candidate_binding_hash, original.binding_hash_kind, original.route,
        original.control_role, bad_sources, deepcopy(original.evidence),
        deepcopy(original.hard_failures), original.evidence_ceiling)
    bad_result = compile_real_candidate_panel_entry_v1(bad, root,
        panel["required_obligations"])
    @test bad_result.status == :unsupported
    @test bad_result.classification_code == "unsupported_source_or_operator"

    source = read(joinpath(root, "src", "candidate_v68_real_panel_v1.jl"), String)
    @test !occursin("genome.family", source)
    @test !occursin("family ==", source)
    schema = JSON3.read(read(joinpath(root, "schemas",
        "candidate_v68_real_panel_result_v1.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
end
