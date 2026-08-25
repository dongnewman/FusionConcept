using Test
using JSON3
using FusionConceptAI

@testset "public judgment state repair v53" begin
    aliased = Dict{String,Any}(
        "candidate_index" => 1,
        "assembly_index" => 1,
        "sample_ordinal" => 1,
        "design_id" => "aliased_pulse",
        "physics_hash" => repeat("a", 64),
        "proxy_result_hash" => repeat("b", 64),
        "graph_hash" => repeat("c", 64),
        "family" => "display_only",
        "mission_contract_id" => "net_electric_pulsed_v1",
        "module_ids" => Any["laser_icf", "icf_direct_drive", "icf_shock_timing"],
        "evaluator_id" => "laser_icf_screen_v1",
        "projection_id" => "pulse",
        "proxy_applicable" => true,
        "topology_graph_errors" => Any[],
        "gates" => Dict(
            "variable_topology_representation" => true,
            "same_pulsed_outer_envelope_contract" => true,
            "first_principles_pulse_and_evidence_separation" => false,
            "shot_energy_and_average_power_closure" => false,
            "cheap_robustness_screen" => false),
        "positive_net_power_closure" => false,
        "proxy_coverage_complete" => false,
        "gate_pass_count" => 2,
        "robustness_pass_fraction" => 0.0,
        "missing_proxy_requirements" => Any["radiation_hydrodynamics"])
    screened = unified_screen_candidate_v52(aliased)
    statuses = Dict(item["screen_id"] => item["status"] for item in screened["screens"])
    @test statuses["topology_representation_compatibility"] == "pass"
    @test statuses["shared_outer_envelope"] == "pass"
    @test statuses["low_fidelity_physics"] == "fail"
    @test statuses["minimal_engineering_closure"] == "fail"
    @test statuses["cheap_robustness"] == "unknown"
end

@testset "candidate-bound representative validation v53" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    common = repaired_common_judgment_v53(context, 6035)
    @test common["raw_result_reconstruction_match"]
    @test common["semantic_gates"]["topology"]
    @test !common["semantic_gates"]["physics"]
    @test common["robustness_evaluation_state"] ==
        "not_evaluated_nominal_failure"
    @test first(common["limiting_margins"])["margin_id"] ==
        "fuel_inventory_energy_conservation"

    diagnostic = diagnostic_robustness_v53(context, 6035)
    @test diagnostic["sample_count"] == 48
    @test diagnostic["status"] == "diagnostic_robust_fail"
    @test diagnostic["common_gate_pass_count"] == 0

    high = higher_fidelity_representative_validation_v53(context, 6035)
    @test high["parent_synthesized"] == false
    @test high["promotion_authorized"] == false
    @test high["executed_backend_count"] >= 1
    @test high["status"] == "higher_fidelity_unknown_or_unsupported"
    @test any(item -> item["route_id"] ==
        "pulsed_radiation_hydrodynamics_input_v1", high["attempts"])

    schema = JSON3.read(read(joinpath(root, "schemas",
        "representative_high_fidelity_v53.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
end
