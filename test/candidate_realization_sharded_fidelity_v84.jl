using Test
using FusionConceptAI

@testset "v84 analytic shard interruption recovery and strict merge" begin
    topology = generate_graph_native_topology_v69(72)
    grammar = default_candidate_realization_grammar_v2(
        graph_isomorphism_hash_v69(topology))
    grid = compile_v84_candidate_grid_v1(grammar;
        physical_variants = 1:1, operating_variants = 1:1,
        control_variants = 1:1, routes = ["closed/mixed", "open/mixed"])
    @test grid["grid_spec"]["candidate_count"] == 2
    @test getindex.(grid["entries"], "candidate_index") == [1, 2]
    mktempdir() do directory
        interrupted = run_v84_analytic_shard_v1(grammar, grid, 1, 1, 2;
            output_directory = directory, checkpoint_interval = 1,
            resume = false, stop_after_candidates = 1)
        @test interrupted["status"] == "interrupted"
        @test interrupted["processed_count"] == 1
        open(interrupted["partial_path"], "a") do io
            write(io, "{truncated_checkpoint")
        end
        completed = run_v84_analytic_shard_v1(grammar, grid, 1, 1, 2;
            output_directory = directory, checkpoint_interval = 1, resume = true)
        @test completed["status"] == "complete"
        @test completed["candidate_count"] == 2
        @test completed["hard_gate_pass_count"] == 2
        @test_throws ArgumentError run_v84_analytic_shard_v1(grammar, grid,
            1, 1, 1; output_directory = directory, checkpoint_interval = 1,
            resume = true)
        merged = merge_v84_analytic_shards_v1(grammar, grid;
            output_directory = directory, expected_shard_ids = [1])
        @test merged["status"] == "complete"
        @test merged["candidate_count"] == 2
        @test merged["pareto_queue_count"] == 2
        queue_path = joinpath(directory, "v84_fast_biot_savart_queue.jsonl")
        @test isfile(queue_path)
        queue = FusionConceptAI._v84_read_valid_json_lines(queue_path)
        @test getindex.(queue, "queue_index") == [1, 2]
        @test all(row -> row["queue_stage"] == "fast_biot_savart", queue)
        @test all(row -> row["candidate_binding_hash"] ==
            row["binding"]["candidate_binding_hash"], queue)
    end
end

@testset "v84 separately bounded Biot-Savart and Poincare queues" begin
    topology = generate_graph_native_topology_v69(72)
    grammar = default_candidate_realization_grammar_v2(
        graph_isomorphism_hash_v69(topology))
    grid = compile_v84_candidate_grid_v1(grammar;
        physical_variants = 1:1, operating_variants = 1:2,
        control_variants = 1:1, routes = ["closed/mixed", "open/mixed"])
    mktempdir() do directory
        run_v84_analytic_shard_v1(grammar, grid, 1, 1, 4;
            output_directory = directory, checkpoint_interval = 1, resume = false)
        analytic = merge_v84_analytic_shards_v1(grammar, grid;
            output_directory = directory, expected_shard_ids = [1],
            max_biot_savart_candidates = 3)
        @test analytic["pareto_archive_count"] >= analytic["pareto_queue_count"]
        @test analytic["pareto_queue_count"] <= 3
        biot_queue_path = joinpath(directory, "v84_fast_biot_savart_queue.jsonl")
        biot_queue = FusionConceptAI._v84_read_valid_json_lines(biot_queue_path)
        run_v84_biot_savart_shard_v1(grammar, biot_queue_path, 1, 1,
            length(biot_queue); output_directory = directory,
            checkpoint_interval = 1, resume = false)
        biot = merge_v84_biot_savart_shards_v1(grammar, biot_queue_path;
            output_directory = directory, expected_shard_ids = [1],
            max_poincare_candidates = 1)
        @test biot["candidate_count"] <= 3
        @test biot["poincare_queue_count"] == 1
        @test biot["poincare_queue_limit"] == 1
        poincare_queue_path = joinpath(directory, "v84_poincare_queue.jsonl")
        poincare_queue = FusionConceptAI._v84_read_valid_json_lines(
            poincare_queue_path)
        @test poincare_queue[1]["queue_stage"] == "poincare"
        @test haskey(poincare_queue[1], "biot_savart_record_hash")
        @test haskey(poincare_queue[1], "expected_screen_evidence_hash")
        run_v84_poincare_shard_v1(grammar, poincare_queue_path, 1, 1, 1;
            output_directory = directory, checkpoint_interval = 1,
            resume = false, poincare_turns = 4,
            poincare_steps_per_turn = 30, poincare_bin_count = 4)
        poincare = merge_v84_poincare_shards_v1(grammar, poincare_queue_path;
            output_directory = directory, expected_shard_ids = [1])
        @test poincare["candidate_count"] == 1
        @test poincare["uncaught_exception_count"] == 0
        @test !poincare["evidence_firewall"]["retroactive_analytic_credit"]
        @test !poincare["evidence_firewall"]["retroactive_biot_savart_credit"]
    end
end

@testset "v84 candidate-bound Biot-Savart to Poincare physical funnel" begin
    topology = generate_graph_native_topology_v69(72)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    grammar = default_candidate_realization_grammar_v2(
        graph_isomorphism_hash_v69(topology))
    grid = compile_v84_candidate_grid_v1(grammar;
        physical_variants = 1:1, operating_variants = 1:1,
        control_variants = 1:1, routes = ["closed/mixed", "open/mixed"])
    mktempdir() do directory
        run_v84_analytic_shard_v1(grammar, grid, 1, 1, 2;
            output_directory = directory, checkpoint_interval = 1, resume = false)
        merge_v84_analytic_shards_v1(grammar, grid;
            output_directory = directory, expected_shard_ids = [1])
        queue_path = joinpath(directory, "v84_fast_biot_savart_queue.jsonl")
        queue = FusionConceptAI._v84_read_valid_json_lines(queue_path)
        evaluated = evaluate_v84_physical_fidelity_v1(topology, compilation,
            grammar, queue[1]; poincare_turns = 4,
            poincare_steps_per_turn = 30, poincare_bin_count = 4)
        @test evaluated["candidate_binding_hash"] ==
            queue[1]["candidate_binding_hash"]
        @test evaluated["physical_execution_binding"][
            "v84_candidate_binding_hash"] == queue[1]["candidate_binding_hash"]
        @test evaluated["physical_execution_binding_hash"] !=
            evaluated["candidate_binding_hash"]
        @test evaluated["realization"]["candidate_binding_hash"] ==
            evaluated["physical_execution_binding_hash"]
        @test evaluated["screen"]["field_evidence"]["model_id"] ==
            "finite_filament_biot_savart_v1"
        @test evaluated["fast_biot_savart_gate_status"] == "pass"
        @test evaluated["poincare_admitted"]
        @test evaluated["poincare"] !== nothing
    @test evaluated["poincare"]["poincare_evidence"]["model_id"] ==
        "candidate_biot_savart_poincare_periodic_axis_fourier_surface_v2"
        @test !evaluated["fidelity_progression"][
            "higher_fidelity_may_rewrite_lower_feasibility"]

        interrupted = run_v84_physical_fidelity_shard_v1(grammar, queue_path,
            1, 1, 2; output_directory = directory, checkpoint_interval = 1,
            resume = false, stop_after_candidates = 1, poincare_turns = 4,
            poincare_steps_per_turn = 30, poincare_bin_count = 4)
        @test interrupted["status"] == "interrupted"
        open(interrupted["partial_path"], "a") do io
            write(io, "{truncated_physical_checkpoint")
        end
        completed = run_v84_physical_fidelity_shard_v1(grammar, queue_path,
            1, 1, 2; output_directory = directory, checkpoint_interval = 1,
            resume = true, poincare_turns = 4,
            poincare_steps_per_turn = 30, poincare_bin_count = 4)
        @test completed["status"] == "complete"
        @test completed["candidate_count"] == 2
        @test completed["uncaught_exception_count"] == 0
        @test completed["fast_biot_savart_pass_count"] == 2
        @test_throws ArgumentError run_v84_physical_fidelity_shard_v1(grammar,
            queue_path, 1, 1, 2; output_directory = directory,
            checkpoint_interval = 1, resume = true, poincare_turns = 5,
            poincare_steps_per_turn = 30, poincare_bin_count = 4)
        merged = merge_v84_physical_fidelity_shards_v1(grammar, queue_path;
            output_directory = directory, expected_shard_ids = [1])
        @test merged["status"] == "complete"
        @test merged["candidate_count"] == 2
        @test merged["fast_biot_savart_pass_count"] == 2
        @test merged["poincare_admitted_count"] == 2
        @test merged["uncaught_exception_count"] == 0
        @test !merged["evidence_firewall"]["retroactive_analytic_credit"]
    end
end
