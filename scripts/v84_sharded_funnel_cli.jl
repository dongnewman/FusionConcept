using JSON3
using FusionConceptAI

length(ARGS) >= 2 || error("usage: v84_sharded_funnel_cli.jl MODE OUTPUT_DIRECTORY ...")
mode = ARGS[1]
output_directory = abspath(ARGS[2])
topology = generate_graph_native_topology_v69(72)
grammar = default_candidate_realization_grammar_v2(graph_isomorphism_hash_v69(topology))

function v84_grid_from_args(offset)
    physical_count = parse(Int, ARGS[offset])
    operating_count = parse(Int, ARGS[offset + 1])
    control_count = parse(Int, ARGS[offset + 2])
    return compile_v84_candidate_grid_v1(grammar;
        physical_variants = 1:physical_count,
        operating_variants = 1:operating_count,
        control_variants = 1:control_count,
        routes = ["closed/mixed", "open/mixed"])
end

result = if mode == "analytic-shard"
    length(ARGS) == 9 || error("analytic-shard args: OUT SHARD FIRST LAST P O C RESUME")
    grid = v84_grid_from_args(6)
    run_v84_analytic_shard_v1(grammar, grid, parse(Int, ARGS[3]),
        parse(Int, ARGS[4]), parse(Int, ARGS[5]);
        output_directory = output_directory, checkpoint_interval = 25,
        resume = parse(Bool, ARGS[9]))
elseif mode == "merge-analytic"
    length(ARGS) == 7 || error("merge-analytic args: OUT SHARD_COUNT P O C MAX_BIOT")
    shard_count = parse(Int, ARGS[3]); grid = v84_grid_from_args(4)
    merge_v84_analytic_shards_v1(grammar, grid;
        output_directory = output_directory,
        expected_shard_ids = collect(1:shard_count),
        max_biot_savart_candidates = parse(Int, ARGS[7]))
elseif mode == "biot-shard"
    length(ARGS) == 6 || error("biot-shard args: OUT SHARD FIRST LAST RESUME")
    queue_path = joinpath(output_directory, "v84_fast_biot_savart_queue.jsonl")
    run_v84_biot_savart_shard_v1(grammar, queue_path,
        parse(Int, ARGS[3]), parse(Int, ARGS[4]), parse(Int, ARGS[5]);
        output_directory = output_directory, checkpoint_interval = 5,
        resume = parse(Bool, ARGS[6]))
elseif mode == "merge-biot"
    length(ARGS) == 4 || error("merge-biot args: OUT SHARD_COUNT MAX_POINCARE")
    queue_path = joinpath(output_directory, "v84_fast_biot_savart_queue.jsonl")
    merge_v84_biot_savart_shards_v1(grammar, queue_path;
        output_directory = output_directory,
        expected_shard_ids = collect(1:parse(Int, ARGS[3])),
        max_poincare_candidates = parse(Int, ARGS[4]))
elseif mode == "poincare-shard"
    length(ARGS) == 9 || error("poincare-shard args: OUT SHARD FIRST LAST RESUME TURNS STEPS BINS")
    queue_path = joinpath(output_directory, "v84_poincare_queue.jsonl")
    run_v84_poincare_shard_v1(grammar, queue_path,
        parse(Int, ARGS[3]), parse(Int, ARGS[4]), parse(Int, ARGS[5]);
        output_directory = output_directory, checkpoint_interval = 5,
        resume = parse(Bool, ARGS[6]), poincare_turns = parse(Int, ARGS[7]),
        poincare_steps_per_turn = parse(Int, ARGS[8]),
        poincare_bin_count = parse(Int, ARGS[9]))
elseif mode == "merge-poincare"
    length(ARGS) == 3 || error("merge-poincare args: OUT SHARD_COUNT")
    queue_path = joinpath(output_directory, "v84_poincare_queue.jsonl")
    merge_v84_poincare_shards_v1(grammar, queue_path;
        output_directory = output_directory,
        expected_shard_ids = collect(1:parse(Int, ARGS[3])))
else
    error("unknown v84 funnel mode $mode")
end

println(canonical_json(result))
