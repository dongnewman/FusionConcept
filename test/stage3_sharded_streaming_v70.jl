using Test
using JSON3

@testset "stage3 v70 streaming shard resume" begin
    mktempdir() do directory
        interrupted = run_stage3_streaming_shard_v70(1, 1, 12;
            output_directory = directory, numerical_per_shard = 4,
            checkpoint_interval = 2, stop_after_seeds = 5)
        @test interrupted["status"] == "interrupted"
        @test interrupted["processed_count"] == 5
        resumed = run_stage3_streaming_shard_v70(1, 1, 12;
            output_directory = directory, numerical_per_shard = 4,
            checkpoint_interval = 2)
        @test resumed["status"] == "complete"
        @test resumed["raw_seed_count"] == 12
        @test resumed["uncaught_exception_count"] == 0
        rows = readlines(joinpath(directory, "stage3_v70_shard_01.structures.jsonl"))
        @test length(rows) == 12
        @test Int(JSON3.read(rows[1])["seed"]) == 1
        @test Int(JSON3.read(rows[end])["seed"]) == 12
    end
end

@testset "stage3 v70 ten-shard hash merge" begin
    mktempdir() do directory
        for shard_id in 1:10
            first_seed = (shard_id - 1) * 2 + 1
            run_stage3_streaming_shard_v70(shard_id, first_seed, first_seed + 1;
                output_directory = directory, numerical_per_shard = 1)
        end
        artifact = merge_stage3_streaming_shards_v70(directory;
            expected_raw_count = 20, expected_shard_size = 2)
        @test artifact["status"] == "accepted"
        @test artifact["raw_candidate_count"] == 20
        @test artifact["shard_count"] == 10
        @test artifact["unique_structure_count"] + artifact["duplicate_structure_count"] == 20
        @test artifact["unique_evidence_count"] > 0
        @test all(values(artifact["exit_gate"]))
    end
end

@testset "stage3 v70 shard output is bounded and hash sealed" begin
    mktempdir() do directory
        summary = run_stage3_streaming_shard_v70(2, 21, 32;
            output_directory = directory, numerical_per_shard = 3)
        @test summary["numerical_evidence_count"] <= 3
        @test summary["unique_structure_count"] <= 12
        @test length(summary["structures_sha256"]) == 64
        @test length(summary["evidence_sha256"]) == 64
        @test length(summary["shard_result_hash"]) == 64
    end
end
