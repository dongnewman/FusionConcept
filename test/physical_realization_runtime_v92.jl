using Test
using JSON3
using SHA

if !isdefined(Main, :canonical_hash)
    using FusionConceptAI
end
if !isdefined(Main, :verify_protocol_seal_v92)
    include(joinpath(@__DIR__, "..", "src", "protocol_seal_runtime_v92.jl"))
end
if !isdefined(Main, :PhysicalRealizationV92)
    include(joinpath(@__DIR__, "..", "src", "physical_realization_runtime_v92.jl"))
end

@testset "PhysicalRealizationV92 candidate binding" begin
    root = normpath(joinpath(@__DIR__, ".."))
    assert_protocol_sealed_v92(root)
    dossier_path = joinpath(root, "runs",
        "multitopology_v91_formal_1000000_20260827",
        "survivor_dossiers_v91.jsonl")
    first_dossier = open(dossier_path, "r") do io
        JSON3.read(readline(io))
    end
    realization = compile_physical_realization_v92(first_dossier)
    payload = physical_realization_to_dict_v92(realization)
    @test realization.status == "pass"
    @test payload["candidate_id"] == "v91-candidate-3052"
    @test payload["protocol_id"] == V92_PROTOCOL_ID
    @test length(payload["regions"]) >= 6
    @test Set(region["region_type"] for region in payload["regions"]) ==
        Set(["plasma", "vacuum", "coil", "wall", "open_loss", "terminal"])
    @test length(payload["volume_meshes"]) == 3
    @test [mesh["cell_count"] for mesh in payload["volume_meshes"]] ==
        [262144, 1000000, 4096000]
    @test length(payload["wall_meshes"]) == 3
    @test [mesh["face_count"] for mesh in payload["wall_meshes"]] ==
        [50176, 200704, 802816]
    @test all(mesh["backend_consumable"] for mesh in payload["volume_meshes"])
    @test length(payload["field_sources"]) >= 1
    @test length(payload["profiles"]) == 5
    @test length(payload["interface_conditions"]) == 6
    @test length(payload["structural_gene_consumption"]) == 41
    @test payload["qualification"]["expected_structural_gene_consumption_count"] == 41
    @test length(payload["basis_consumption"]) == 8
    @test payload["realization_hash"] == realization.realization_hash
    @test payload["claim_boundary"] == PHYSICAL_REALIZATION_V92_CLAIM_BOUNDARY

    invalid = deepcopy(FusionConceptAI._v92_plain(first_dossier))
    for node in invalid["genome"]["topology"]["nodes"]
        if node["role"] == "field_evolution" || node["operator"] == "field_balance"
            node["dimension"] = "0d"
        end
    end
    invalid_realization = compile_physical_realization_v92(invalid)
    @test invalid_realization.status == "fail"
    @test invalid_realization.first_blocker ==
        "missing_spatial_field_balance_backbone"
    @test invalid_realization.payload["qualification"]["status"] == "fail"
end
