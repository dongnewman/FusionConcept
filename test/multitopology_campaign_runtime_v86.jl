using Test
using FusionConceptAI
using JSON3
using LinearAlgebra

@testset "v86 immutable requests, capability routing, and adaptive bases" begin
    campaign = compile_multitopology_campaign_v86(
        structure_seeds = [2, 72], physical_variants = [1, 2],
        operating_variants = [1], control_variants = [1],
        routes = ["closed/mixed", "open/mixed"], basis_levels = [0])
    @test campaign["specification"]["seed_streams_independent"] === true
    @test campaign["specification"]["isomorphism_dedup_before_variants"] === true
    @test campaign["specification"]["fairness_policy"] ==
        "budget_stratum_then_capability_cell_round_robin_v2"
    @test campaign["specification"]["budget_stratum_count"] == 2
    @test length(unique(campaign["specification"][
        "fair_schedule_request_indices"])) == length(campaign["requests"])
    coverage = compile_v86_capability_coverage_manifest_v1(campaign)
    @test coverage["device_family_routing_used"] === false
    @test coverage["request_count"] == length(campaign["requests"])
    @test coverage["minimality_eligible_request_count"] > 0
    @test coverage["minimality_excluded_request_count"] > 0
    @test coverage["budget_stratum_count"] == 2
    @test coverage["comparison_scope_count"] == 2
    @test any(cell["executor_coverage"]["open_field_end_loss"] ==
        "available_candidate_bound" for cell in coverage["cells"])
    @test any(cell["executor_coverage"][
        "open_field_finite_pressure_capability"] ==
        "available_candidate_bound_paraxial_screen" for cell in coverage["cells"])
    poincare_subset = compile_v86_capability_subset_catalog_v1(campaign;
        required_gate = "poincare_128")
    @test !isempty(poincare_subset["requests"])
    @test all("poincare_128" in raw["capability_signature"][
        "required_hard_gate_chain"] for raw in poincare_subset["requests"])
    @test poincare_subset["specification"]["filter"][
        "device_family_filter_used"] === false

    closed_rows = [item for item in campaign["requests"] if
        item["structure_seed"] == 72 && item["physical_variant"] == 1]
    @test length(closed_rows) == 2
    restored = FusionConceptAI._v86_restore_request.(closed_rows)
    compiled = [compile_joint_physical_realization_v85(item.topology,
        item.compilation, item.request.initial_design;
        basis_override = item.request.basis_override,
        base_coil_count = item.request.base_coil_count) for item in restored]
    hashes = v85_solver_input_hashes_v1.(compiled)
    @test hashes[1]["field_solver_input_hash"] ==
        hashes[2]["field_solver_input_hash"]
    @test hashes[1]["equilibrium_solver_input_hash"] ==
        hashes[2]["equilibrium_solver_input_hash"]
    @test restored[1].request.initial_design.design_hash !=
        restored[2].request.initial_design.design_hash
    @test restored[1].request.capability_signature.minimality_eligible === true
    @test length(restored[1].request.capability_signature.budget_stratum_hash) == 64
    @test length(restored[1].request.capability_signature.comparison_scope_hash) == 64

    open_row = only([item for item in campaign["requests"] if
        item["structure_seed"] == 2 && item["physical_variant"] == 1 &&
        item["route"] == "open/mixed"])
    open_restored = FusionConceptAI._v86_restore_request(open_row)
    signature = open_restored.request.capability_signature
    @test signature.geometry_class == "linear_volume_v1"
    @test signature.minimality_eligible === false
    @test "open_field_end_loss" in signature.required_hard_gate_chain
    @test "open_field_paraxial_finite_pressure_screen_not_complete_equilibrium" in
        signature.exclusion_reasons

    base_request = restored[1].request
    promoted = compile_candidate_solve_request_v86(999, 72,
        restored[1].topology, restored[1].compilation, restored[1].grammar,
        1, 1, 1, base_request.route; basis_level = 1)
    @test promoted.basis_override["coil_fourier_coefficients"][1:5] ==
        promoted.initial_design.coil_fourier_coefficients
    @test length(promoted.basis_override["coil_fourier_coefficients"]) == 7
    @test length(promoted.basis_override["coil_bspline_control_points"]) == 8
    @test promoted.base_coil_count == 20
    promoted2 = compile_candidate_solve_request_v86(1000, 72,
        restored[1].topology, restored[1].compilation, restored[1].grammar,
        1, 1, 1, base_request.route; basis_level = 2)
    @test promoted2.basis_override["coil_fourier_coefficients"][1:7] ==
        promoted.basis_override["coil_fourier_coefficients"]
    @test promoted2.basis_override["coil_bspline_control_points"][1:8] ==
        promoted.basis_override["coil_bspline_control_points"]
    @test promoted2.basis_override["current_potential_coefficients"][1:7] ==
        promoted.basis_override["current_potential_coefficients"]
    promoted_compiled = compile_joint_physical_realization_v85(restored[1].topology,
        restored[1].compilation, promoted.initial_design;
        basis_override = promoted.basis_override,
        base_coil_count = promoted.base_coil_count)
    @test v85_solver_input_hashes_v1(promoted_compiled)[
        "field_solver_input_hash"] != hashes[1]["field_solver_input_hash"]
    changed_low = compile_candidate_joint_design_v1(restored[1].grammar;
        route = promoted.initial_design.route,
        coil_fourier_coefficients = promoted.initial_design.
            coil_fourier_coefficients .+ [0.01, 0, 0, 0, 0],
        coil_bspline_control_points = promoted.initial_design.
            coil_bspline_control_points,
        current_potential_coefficients = promoted.initial_design.
            current_potential_coefficients,
        plasma_boundary_coefficients = promoted.initial_design.
            plasma_boundary_coefficients,
        actuator_timing_coefficients = promoted.initial_design.
            actuator_timing_coefficients,
        controller_modal_coefficients = promoted.initial_design.
            controller_modal_coefficients,
        field_current_a = promoted.initial_design.field_current_a,
        density_scale = promoted.initial_design.density_scale,
        temperature_scale = promoted.initial_design.temperature_scale)
    changed_low_compiled = compile_joint_physical_realization_v85(
        restored[1].topology, restored[1].compilation, changed_low;
        basis_override = promoted.basis_override,
        base_coil_count = promoted.base_coil_count)
    @test changed_low_compiled.binding["v85_low_order_bases"][
        "coil_fourier_coefficients"][1] ==
        changed_low.coil_fourier_coefficients[1]
    @test v85_solver_input_hashes_v1(changed_low_compiled)[
        "field_solver_input_hash"] != v85_solver_input_hashes_v1(
            promoted_compiled)["field_solver_input_hash"]

    winding_surface = compile_candidate_solve_request_v86(1001, 72,
        restored[1].topology, restored[1].compilation, restored[1].grammar,
        1, 1, 1, base_request.route; basis_level = 3)
    @test winding_surface.basis_override["winding_model"] ==
        "winding_surface_current_potential_level_set_filaments_v7"
    @test winding_surface.basis_override["contour_current_scale"] == 0.35
    @test winding_surface.basis_override["contour_count"] == 28
    winding_compiled = compile_joint_physical_realization_v85(
        restored[1].topology, restored[1].compilation,
        winding_surface.initial_design;
        basis_override = winding_surface.basis_override,
        base_coil_count = winding_surface.base_coil_count)
    winding_component = first(filter(component -> component[
        "component_kind"] == "finite_filament_coil_array_v1",
        winding_compiled.realization.components))
    @test winding_component["winding_basis"] ==
        "winding_surface_current_potential_level_set_filaments_v7"
    @test winding_component["contour_current_scale"] == 0.35
    @test winding_component["current_potential_domain_dimension"] == 2
    @test winding_component["contour_count"] == 28
    @test winding_component["dominant_mode_m"] == 1
    @test winding_component["dominant_mode_n"] == 1
    @test all(loop["contour_poloidal_winding_number"] == 1 &&
        loop["contour_toroidal_winding_number"] == 0 for loop in
        winding_component["loops"])
    @test winding_component["field_periods"] == 2
    @test winding_component["supply_group_count"] == 2
    @test winding_component["maximum_contour_residual"] <= 1.0e-9
    @test winding_component["maximum_contour_closure_error_m"] <= 1.0e-8
    @test winding_component["minimum_same_theta_contour_spacing_m"] > 0.0
    @test all(norm(Float64.(first(loop["centerline_m"])) -
        Float64.(last(loop["centerline_m"]))) <= 1.0e-12 for loop in
        winding_component["loops"])
    legacy_override = deepcopy(winding_surface.basis_override)
    legacy_override["winding_model"] =
        "winding_surface_current_potential_level_set_filaments_v6"
    legacy_override["grammar_transition"] =
        "coherent_helical_centerlines_to_2d_winding_surface_current_potential_contours_v2"
    legacy_compiled = compile_joint_physical_realization_v85(
        restored[1].topology, restored[1].compilation,
        winding_surface.initial_design; basis_override = legacy_override,
        base_coil_count = winding_surface.base_coil_count)
    legacy_component = first(filter(component -> component[
        "component_kind"] == "finite_filament_coil_array_v1",
        legacy_compiled.realization.components))
    @test legacy_component["winding_basis"] ==
        "winding_surface_current_potential_level_set_filaments_v6"
    @test all(loop["contour_poloidal_winding_number"] == 2 &&
        loop["contour_toroidal_winding_number"] == 1 for loop in
        legacy_component["loops"])
    @test v85_solver_input_hashes_v1(legacy_compiled)[
        "field_solver_input_hash"] != v85_solver_input_hashes_v1(
            winding_compiled)["field_solver_input_hash"]
    winding_hash = v85_solver_input_hashes_v1(winding_compiled)[
        "field_solver_input_hash"]
    for coefficient_index in 1:5
        potential = copy(winding_surface.initial_design.
            current_potential_coefficients)
        potential[coefficient_index] += 0.01
        changed_potential = compile_candidate_joint_design_v1(
            restored[1].grammar; route = winding_surface.initial_design.route,
            coil_fourier_coefficients = winding_surface.initial_design.
                coil_fourier_coefficients,
            coil_bspline_control_points = winding_surface.initial_design.
                coil_bspline_control_points,
            current_potential_coefficients = potential,
            plasma_boundary_coefficients = winding_surface.initial_design.
                plasma_boundary_coefficients,
            actuator_timing_coefficients = winding_surface.initial_design.
                actuator_timing_coefficients,
            controller_modal_coefficients = winding_surface.initial_design.
                controller_modal_coefficients,
            field_current_a = winding_surface.initial_design.field_current_a,
            density_scale = winding_surface.initial_design.density_scale,
            temperature_scale = winding_surface.initial_design.temperature_scale)
        changed = compile_joint_physical_realization_v85(restored[1].topology,
            restored[1].compilation, changed_potential;
            basis_override = winding_surface.basis_override,
            base_coil_count = winding_surface.base_coil_count)
        @test v85_solver_input_hashes_v1(changed)[
            "field_solver_input_hash"] != winding_hash
    end
end

@testset "v86 structural transition grammars are explicit and restorable" begin
    cases = [
        ("prescribed_electrostatic_end_barrier_pair_v1", 4,
            "prescribed_electrostatic_end_barrier_pair", "open/mixed"),
        ("declared_internal_current_ring_flux_core_v1", 72,
            "declared_internal_current_ring_flux_core", "closed/mixed")]
    for (transition, seed, component, route) in cases
        campaign = compile_structural_transition_campaign_v86(
            structure_seeds = [seed], physical_variants = [1],
            operating_variants = [1], control_variants = [1],
            transition_id = transition)
        @test campaign["specification"]["campaign_kind"] ==
            "structural_transition_campaign_v1"
        @test length(campaign["requests"]) == 1
        raw = only(campaign["requests"])
        @test raw["route"] == route
        @test raw["basis_override"]["grammar_transition"] == transition
        restored = FusionConceptAI._v86_restore_request(raw)
        @test restored.request.basis_override["grammar_transition"] ==
            transition
        @test restored.grammar.base_grammar.allowed_routes == [route]
        @test any(rule.component_kind == component && rule.required &&
            rule.minimum_count == 1 for rule in
            restored.grammar.base_grammar.component_rules)
    end
end

@testset "v86 read-only high-fidelity mode consumes sealed cache only" begin
    mktempdir() do cache
        stage = "finite_pressure_equilibrium"
        input_hash = repeat("a", 64)
        payload = Dict{String,Any}(
            "gate_id" => stage, "status" => "fail",
            "classification_code" => "synthetic_cached_rejection",
            "solver_input_hash" => input_hash,
            "evidence" => Dict{String,Any}(),
            "missing_requirements" => String[])
        written = FusionConceptAI._v86_cached_execution(cache, stage,
            input_hash, () -> payload)
        @test written.cache_hit === false
        cached = FusionConceptAI._v86_cached_execution_if_present(cache,
            stage, input_hash)
        @test cached !== nothing
        @test cached.cache_hit === true
        @test cached.payload["classification_code"] ==
            "synthetic_cached_rejection"
        @test cached.cache_object_hash == written.cache_object_hash
        @test FusionConceptAI._v86_cached_execution_if_present(cache, stage,
            repeat("b", 64)) === nothing
    end
end

@testset "v86 open-field executor is physical and fail-closed" begin
    campaign = compile_multitopology_campaign_v86(
        structure_seeds = [2], physical_variants = [1],
        operating_variants = [1], control_variants = [1],
        routes = ["open/mixed"], basis_levels = [0])
    restored = FusionConceptAI._v86_restore_request(only(campaign["requests"]))
    compiled = compile_joint_physical_realization_v85(restored.topology,
        restored.compilation, restored.request.initial_design;
        basis_override = restored.request.basis_override,
        base_coil_count = restored.request.base_coil_count)
    biot = evaluate_v85_biot_savart_gate_v1(compiled)
    gate = evaluate_open_field_end_loss_gate_v86(compiled, biot)
    @test gate["status"] in ("pass", "fail", "unknown")
    @test gate["evidence"]["model_id"] ==
        "bidirectional_finite_filament_open_end_loss_v1"
    @test length(gate["evidence"]["traces"]) == 6
    @test gate["evidence"]["finite_pressure_credit"] == 0.0
    @test gate["evidence"]["ambipolar_credit"] == 0.0
    admitted_end_loss = FusionConceptAI._v85_gate_record(
        "open_field_end_loss", "pass", "unit_admission_control";
        evidence = gate["evidence"])
    input = compile_open_field_paraxial_finite_pressure_input_v1(compiled, biot;
        axial_sample_count = 7)
    @test input["model_id"] ==
        "candidate_bound_paraxial_scalar_pressure_flux_tube_v1"
    @test input["field_solver_input_hash"] == v85_solver_input_hashes_v1(compiled)[
        "field_solver_input_hash"]
    finite_pressure = evaluate_open_field_paraxial_finite_pressure_gate_v1(
        compiled, biot, admitted_end_loss; axial_sample_count = 7)
    @test finite_pressure["status"] in ("pass", "fail", "unknown")
    @test finite_pressure["status"] != "unsupported"
    @test finite_pressure["solver_input_hash"] == input["solver_input_hash"]
    @test finite_pressure["evidence"]["candidate_bound"] === true
    @test finite_pressure["evidence"]["full_open_field_equilibrium_credit"] == 0.0
    @test finite_pressure["evidence"]["kinetic_credit"] == 0.0
    @test finite_pressure["evidence"]["stability_credit"] == 0.0
end

@testset "v86 resumable shards, global cache, strict merge, and firewall" begin
    campaign = compile_multitopology_campaign_v86(
        structure_seeds = [72], physical_variants = [1],
        operating_variants = [1], control_variants = [1],
        routes = ["closed/mixed", "open/mixed"], basis_levels = [0])
    @test length(campaign["requests"]) == 2
    mktempdir() do resumed_dir
        interrupted = run_v86_campaign_shard_v1(campaign, 1, 1, 2;
            output_directory = resumed_dir, checkpoint_interval = 1,
            stop_after_candidates = 1, maximum_sweeps = 0,
            maximum_evaluations = 1, poincare_steps_per_turn = 60,
            execute_desc = false)
        @test interrupted["status"] == "interrupted"
        open(interrupted["partial_path"], "a") do io
            write(io, "{truncated")
        end
        resumed = run_v86_campaign_shard_v1(campaign, 1, 1, 2;
            output_directory = resumed_dir, checkpoint_interval = 1,
            maximum_sweeps = 0, maximum_evaluations = 1,
            poincare_steps_per_turn = 60, execute_desc = false)
        @test resumed["status"] == "complete"
        @test resumed["uncaught_exception_count"] == 0

        mktempdir() do uninterrupted_dir
            uninterrupted = run_v86_campaign_shard_v1(campaign, 1, 1, 2;
                output_directory = uninterrupted_dir, checkpoint_interval = 1,
                maximum_sweeps = 0, maximum_evaluations = 1,
                poincare_steps_per_turn = 60, execute_desc = false)
            @test resumed["stream_sha256"] == uninterrupted["stream_sha256"]
            @test resumed["shard_result_hash"] ==
                uninterrupted["shard_result_hash"]
        end

        merged = merge_v86_campaign_shards_v1(campaign;
            output_directory = resumed_dir, expected_shard_ids = [1])
        @test merged["candidate_count"] == 2
        @test merged["unique_solver_input_counts"]["finite_filament_field"] == 1
        @test merged["actual_execution_counts"]["finite_filament_field"] == 1
        @test merged["cache_hit_counts"]["finite_filament_field"] == 1
        @test merged["unique_solver_input_counts"]["poincare_32"] == 1
        @test merged["actual_execution_counts"]["poincare_32"] == 1
        @test isempty(merged["duplicate_solver_execution_keys"])
        @test merged["evidence_firewall_passed"] === true
        @test merged["retroactive_feasibility_credit"] === false
        @test merged["cross_capability_disposition"][
            "dominance_claimed_across_cells"] === false
        @test length(merged["budget_stratum_hashes"]) == 1
        @test haskey(merged, "comparison_scope_pareto_archives")
        @test merged["all_hard_gates_pass_count"] == 0
        @test !isempty(merged["basis_promotion_requests"])
        followup = compile_v86_promoted_campaign_v1(campaign, merged)
        @test followup["specification"]["campaign_kind"] ==
            "adaptive_basis_promotion_followup_v1"
        @test followup["specification"]["request_count"] == 1
        @test only(followup["requests"])["basis_level"] == 1
        @test only(followup["requests"])["retroactive_feasibility_credit"] === false
        @test haskey(only(followup["requests"]), "parent_request_hash")

        rows = FusionConceptAI._v84_read_valid_json_lines(joinpath(resumed_dir,
            "v86_campaign_merged.jsonl"))
        @test all(row["gate_chain"]["poincare_32"]["status"] == "fail"
            for row in rows)
        @test all(row["gate_chain"]["poincare_64"]["status"] ==
            "not_admitted" for row in rows)
        @test all(row["complexity_manifest"] === nothing for row in rows)
        @test all(row["basis_feedback"]["applies_to_next_request_only"] === true
            for row in rows)
    end
end

@testset "v86 budgeted stage frontiers are merge-driven and deterministic" begin
    catalog = compile_multitopology_campaign_v86(
        structure_seeds = [1], physical_variants = [1],
        operating_variants = [1], control_variants = [1],
        routes = ["closed/mixed", "open/mixed"], basis_levels = [0])
    policy = compile_v86_capability_budget_policy_v1()
    field_campaign = compile_v86_initial_stage_campaign_v1(catalog;
        budget_policy = policy)
    @test field_campaign["specification"]["scheduled_gate"] ==
        "finite_filament_field"
    @test field_campaign["specification"]["design_execution_policy"] ==
        "joint_optimize_and_reaudit_v1"
    @test all(raw["scheduled_gate"] == "finite_filament_field" for raw in
        field_campaign["requests"])
    frozen_field = compile_v86_initial_stage_campaign_v1(catalog;
        budget_policy = policy,
        design_execution_policy = "frozen_declared_design_reaudit_v1")
    @test frozen_field["specification"]["design_execution_policy"] ==
        "frozen_declared_design_reaudit_v1"
    @test all(raw["design_execution_policy"] ==
        "frozen_declared_design_reaudit_v1" for raw in frozen_field["requests"])
    @test field_campaign["specification"]["budget_policy"][
        "cache_hits_consume_solver_budget"] === false

    mktempdir() do output
        cache = joinpath(output, "cache")
        field_summary = run_v86_campaign_shard_v1(field_campaign, 1, 1,
            length(field_campaign["requests"]); output_directory = output,
            cache_directory = cache, maximum_sweeps = 0,
            maximum_evaluations = 1, poincare_steps_per_turn = 60,
            execute_desc = false)
        @test field_summary["status"] == "complete"
        field_merge = merge_v86_campaign_shards_v1(field_campaign;
            output_directory = output, expected_shard_ids = [1])
        @test all(record["scheduled_gate"] == "finite_filament_field" for
            record in field_merge["stage_frontier_records"])
        @test all(record["promotion_eligible"] === true for record in
            field_merge["stage_frontier_records"])
        field_rows = FusionConceptAI._v84_read_valid_json_lines(joinpath(output,
            "v86_campaign_merged.jsonl"))
        @test all(row["gate_chain"]["poincare_32"]["status"] ==
            "not_scheduled" for row in field_rows)

        frontiers = compile_v86_next_stage_frontiers_v1(field_campaign,
            field_merge)
        @test collect(keys(frontiers)) == ["poincare_32"]
        p32_campaign = frontiers["poincare_32"]
        @test length(p32_campaign["requests"]) == 1
        @test p32_campaign["specification"]["frontier_metadata"][
            "deduplicated_completed_solver_input_count"] == 1
        @test only(p32_campaign["requests"])["scheduled_gate"] == "poincare_32"
        @test p32_campaign["specification"]["design_execution_policy"] ==
            "frozen_promoted_design_reaudit_v1"
        @test only(p32_campaign["requests"])["design_execution_policy"] ==
            "frozen_promoted_design_reaudit_v1"

        p32_output = joinpath(output, "p32")
        p32_summary = run_v86_campaign_shard_v1(p32_campaign, 1, 1, 1;
            output_directory = p32_output, cache_directory = cache,
            maximum_sweeps = 0, maximum_evaluations = 1,
            poincare_steps_per_turn = 60, execute_desc = false)
        @test p32_summary["status"] == "complete"
        p32_merge = merge_v86_campaign_shards_v1(p32_campaign;
            output_directory = p32_output, expected_shard_ids = [1])
        @test p32_merge["cache_hit_counts"]["finite_filament_field"] == 1
        @test p32_merge["actual_execution_counts"]["poincare_32"] == 1
        p32_rows = FusionConceptAI._v84_read_valid_json_lines(joinpath(
            p32_output, "v86_campaign_merged.jsonl"))
        @test only(p32_rows)["optimization"][
            "acquisition_toroidal_turns"] == 8
        @test only(p32_rows)["optimization"][
            "acquisition_steps_per_turn"] == 60
        @test only(p32_rows)["design_execution_policy"] ==
            "frozen_promoted_design_reaudit_v1"
        @test only(p32_rows)["optimized_design"]["design_hash"] ==
            only(p32_campaign["requests"])["initial_design"]["design_hash"]
        @test compile_v86_next_stage_frontier_v1(p32_campaign,
            p32_merge) === nothing
        stop_manifest = compile_v86_search_stop_manifest_v1(
            [[field_merge, p32_merge]];
            minimum_unique_biot_pass_inputs = 1,
            required_consecutive_zero_survival_batches = 1,
            minimum_unique_inputs_per_basis_basin = 1)
        @test stop_manifest["stop_topology_expansion"] === true
        @test stop_manifest["unique_biot_pass_field_input_count"] == 1
        @test !isempty(stop_manifest["retired_basis_basin_keys"])
        @test_throws ArgumentError compile_v86_initial_stage_campaign_v1(
            catalog; stop_manifest = stop_manifest)
        followup = compile_v86_promoted_campaign_v1(p32_campaign, p32_merge)
        adaptive_after_stop = compile_v86_initial_stage_campaign_v1(followup;
            stop_manifest = stop_manifest)
        @test adaptive_after_stop["specification"]["request_count"] == 1
    end

    base = compile_v86_capability_budget_policy_v1()
    per_cell = copy(base["maximum_stage_requests_per_cell"])
    per_stratum = copy(base["maximum_stage_requests_per_stratum"])
    per_cell["finite_filament_field"] = 2
    per_stratum["finite_filament_field"] = 2
    tight = compile_v86_capability_budget_policy_v1(
        maximum_stage_requests_per_cell = per_cell,
        maximum_stage_requests_per_stratum = per_stratum)
    larger_catalog = compile_multitopology_campaign_v86(
        structure_seeds = [1], physical_variants = 1:4,
        operating_variants = [1], control_variants = [1],
        routes = ["closed/mixed"], basis_levels = [0])
    limited = compile_v86_initial_stage_campaign_v1(larger_catalog;
        budget_policy = tight)
    @test length(limited["requests"]) == 2
    @test only(limited["specification"]["budget_decisions"])[
        "rejected_by_budget_count"] == 2
end

@testset "v86 mixed capability frontiers split by applicable physical gate" begin
    catalog = compile_multitopology_campaign_v86(
        structure_seeds = [1, 2], physical_variants = [1],
        operating_variants = [1], control_variants = [1],
        routes = ["closed/mixed"], basis_levels = [0])
    field_campaign = compile_v86_initial_stage_campaign_v1(catalog)
    mktempdir() do output
        run_v86_campaign_shard_v1(field_campaign, 1, 1,
            length(field_campaign["requests"]); output_directory = output,
            maximum_sweeps = 0, maximum_evaluations = 1,
            poincare_steps_per_turn = 60, execute_desc = false)
        merged = merge_v86_campaign_shards_v1(field_campaign;
            output_directory = output, expected_shard_ids = [1])
        frontiers = compile_v86_next_stage_frontiers_v1(field_campaign, merged)
        @test Set(keys(frontiers)) == Set(["poincare_32", "open_field_end_loss"])
        @test only(frontiers["poincare_32"]["requests"])[
            "capability_signature"]["geometry_class"] == "toroidal_volume_v1"
        @test only(frontiers["open_field_end_loss"]["requests"])[
            "capability_signature"]["geometry_class"] == "linear_volume_v1"
        stop_manifest = compile_v86_search_stop_manifest_v1([[merged]];
            minimum_unique_biot_pass_inputs = 2,
            required_consecutive_zero_survival_batches = 1,
            minimum_unique_inputs_per_basis_basin = 1)
        @test stop_manifest["all_capability_unique_biot_pass_field_input_count"] == 2
        @test stop_manifest[
            "poincare_applicable_unique_biot_pass_field_input_count"] == 1
        @test stop_manifest["stop_topology_expansion"] === false
    end
end
