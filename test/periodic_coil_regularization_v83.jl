using Test

@testset "v83 periodic coil regularization" begin
    topology = generate_graph_native_topology_v69(72)
    binding = generate_regularized_periodic_binding_v83(topology, 0.5, 0.5, 0.5)
    @test binding["v82_parent_candidate_binding_hash"] isa String
    @test binding["deformation_scale"] == 0.5
    artifact = run_periodic_coil_regularization_v83(
        deformation_scales = [0.5], current_spread_scales = [0.5],
        radius_spread_scales = [0.5])
    @test artifact["status"] == "complete"
    @test artifact["grid_candidate_count"] == 1
    @test artifact["winner"] !== nothing
    @test artifact["device_family_routing_used"] == false
end
