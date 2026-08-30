using Test
using FusionConceptAI

@testset "v123 joint thermal window" begin
    @test V123_COOLANT_DELTA_T_K == [122.0, 124.0, 125.0]
    @test maximum(573.0 .+ 2 .* V123_COOLANT_DELTA_T_K) <= 823.15
end
