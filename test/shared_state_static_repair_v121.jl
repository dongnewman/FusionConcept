using Test
using FusionConceptAI

@testset "v121 static repair coordinates" begin
    multipliers = static_repair_field_multipliers_v121(30.0)
    @test multipliers == [0.45, 0.5, 0.55]
    @test maximum(static_repair_field_multipliers_v121(10.0)) == 0.95
    @test_throws ArgumentError static_repair_field_multipliers_v121(0.0)
end
