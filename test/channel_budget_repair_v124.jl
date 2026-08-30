using Test
using FusionConceptAI

@testset "v124 channel pressure budget" begin
    @test V124_COOLANT_DELTA_T_K == [55.0, 60.0, 65.0]
    @test V124_PRIMARY_PRESSURE_DROP_BUDGET_PA == 80_000.0
    @test maximum(573.0 .+ 2 .* V124_COOLANT_DELTA_T_K) < 823.15
end
