using Test
using FusionConceptAI
using JSON3

@testset "v86 current-potential inverse initializes requests without credit" begin
    base_catalog = compile_multitopology_campaign_v86(
        structure_seeds = [72], physical_variants = [1],
        operating_variants = [1], control_variants = [1],
        routes = ["closed/mixed"], basis_levels = [0])
    base = FusionConceptAI._v86_restore_request(only(base_catalog["requests"]))
    source = compile_candidate_solve_request_v86(1, 72, base.topology,
        base.compilation, base.grammar, 1, 1, 1, "closed/mixed";
        basis_level = 3)
    source_raw = candidate_solve_request_to_dict_v86(source)
    specification = deepcopy(base_catalog["specification"])
    specification["campaign_kind"] = "adaptive_basis_promotion_followup_v1"
    specification["request_count"] = 1
    specification["request_hashes"] = [source.request_hash]
    parent = Dict{String,Any}(
        "schema_version" => "1.0.0", "specification" => specification,
        "requests" => [source_raw],
        "campaign_hash" => FusionConceptAI.canonical_hash(specification),
        "claim_boundary" => base_catalog["claim_boundary"])
    restored = FusionConceptAI._v86_restore_request(source_raw)
    inverse_request = compile_current_potential_inverse_request_v1(source,
        source.initial_design, source.basis_override;
        active_coefficient_indices = [1], theta_count = 2, phi_count = 2,
        acquisition_toroidal_turns = 1, acquisition_steps_per_turn = 20,
        axis_locator_refinement_levels = 1,
        maximum_iterations = 1, finite_difference_step = 0.01,
        trust_radius = 0.03, tikhonov_regularization = 0.05)
    @test length(inverse_request.request_hash) == 64
    @test inverse_request.schema_version == "1.0.0"
    @test inverse_request.winding_model ==
        "winding_surface_current_potential_level_set_filaments_v7"
    request_dict = current_potential_inverse_request_to_dict_v1(
        inverse_request)
    @test request_dict["acquisition_model_id"] ==
        "candidate_biot_savart_periodic_axis_fieldline_acquisition_v2"

    result = run_current_potential_inverse_v1(inverse_request,
        restored.topology, restored.compilation, restored.grammar,
        source.initial_design, source.basis_override;
        base_coil_count = source.base_coil_count)
    @test result["candidate_feasibility_credit"] === false
    @test result["retroactive_feasibility_credit"] === false
    @test result["next_request_sampling_only"] === true
    @test result["final_acquisition"]["model_id"] ==
        "candidate_biot_savart_periodic_axis_fieldline_acquisition_v2"
    @test result["final_acquisition"]["axis_relative_start_points"] === true
    @test result["final_acquisition"]["candidate_boundary_frame_used"] === true
    @test length(result["result_hash"]) == 64
    result_body = deepcopy(result); delete!(result_body, "result_hash")
    @test FusionConceptAI._v86_inverse_serialized_hash(result_body) ==
        result["result_hash"]
    serialized_result = FusionConceptAI._stage3_plain_v1(JSON3.read(
        JSON3.write(result), Dict{String,Any}))
    serialized_body = deepcopy(serialized_result)
    delete!(serialized_body, "result_hash")
    @test FusionConceptAI.canonical_hash(serialized_body) ==
        result["result_hash"]
    @test Tuple(Float64.(result["final_rank"])) <=
        Tuple(Float64.(result["initial_rank"]))

    followup = compile_v86_inverse_initialized_campaign_v1(parent, [result])
    result_body_after_followup = deepcopy(result)
    delete!(result_body_after_followup, "result_hash")
    @test FusionConceptAI._v86_inverse_serialized_hash(
        result_body_after_followup) ==
        result["result_hash"]
    @test followup["specification"]["campaign_kind"] ==
        "current_potential_inverse_followup_v1"
    @test followup["specification"]["request_count"] == 1
    followup_request = only(followup["requests"])
    @test followup_request["parent_request_hash"] == source.request_hash
    @test followup_request["inverse_request_hash"] ==
        inverse_request.request_hash
    @test followup_request["inverse_result_hash"] == result["result_hash"]
    @test followup_request["retroactive_feasibility_credit"] === false

    stop_manifest = Dict{String,Any}("stop_topology_expansion" => true,
        "retired_basis_basin_keys" => String[])
    field_campaign = compile_v86_initial_stage_campaign_v1(followup;
        stop_manifest = stop_manifest)
    @test field_campaign["specification"]["scheduled_gate"] ==
        "finite_filament_field"
    @test field_campaign["specification"]["request_count"] == 1
end
