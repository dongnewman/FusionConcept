@testset "Pleiades directed two-species ambipolar closure v1" begin
    path = joinpath(@__DIR__, "..", "knowledge",
        "pleiades_directed_two_species_ambipolar_v1.json")
    raw = JSON3.read(read(path, String), Dict{String,Any})
    @test raw["gates"]["candidate_source_distribution_bound"]
    @test raw["gates"]["signed_pitch_preserved_in_ion_solve"]
    @test raw["gates"]["two_species_numeric_distributions_solved"]
    @test raw["gates"]["ambipolar_equal_current_root_solved"]
    @test raw["gates"]["quasineutral_density_solved"]
    @test raw["gates"]["species_end_losses_solved"]
    @test raw["gates"]["screening_resolution_converged"]
    @test !raw["gates"]["nonlinear_multispecies_Rosenbluth_verified"]
    @test !raw["gates"]["c2_kinetic_state_authorized"]
    @test raw["ambipolar_solution"]["equal_total_end_current_verified"]
    @test raw["ambipolar_solution"]["quasineutrality_relative_residual"] < 2.0e-3
    @test raw["summary"]["ion_source_loss_relative_residual"] < 2.0e-8
    @test raw["summary"]["electron_source_loss_relative_residual"] < 2.0e-8
    @test raw["summary"]["quasineutral_density_m3"] > 0.0
    @test raw["summary"]["total_parallel_boundary_kinetic_power_w"] > 0.0
    @test raw["deterministic_hash"] == canonical_hash(Dict{String,Any}(
        key => value for (key, value) in raw if key != "deterministic_hash"))
end
