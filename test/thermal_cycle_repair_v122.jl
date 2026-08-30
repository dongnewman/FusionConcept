using Test
using FusionConceptAI

@testset "v122 thermal-cycle repair declaration" begin
    @test V122_COOLANT_DELTA_T_K == [130.0, 140.0, 150.0]
    @test all(diff(V122_COOLANT_DELTA_T_K) .> 0)
end
