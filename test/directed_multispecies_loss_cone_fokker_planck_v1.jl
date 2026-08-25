@testset "Full-pitch directed species loss-cone Fokker-Planck v1" begin
    nz, nt = 20, 32
    weights = zeros(nz, nt)
    weights[6, 7] = 0.8
    weights[6, nt - 6] = 0.2
    problem = compile_directed_species_loss_cone_problem_v1(
        design_id = "control", genome_physics_hash = repeat("a", 64),
        executable_candidate_physics_hash = repeat("b", 64),
        domain_id = "open", species_id = "deuterium", charge_number = 1,
        mass_kg = 3.3435837724e-27, temperature_j = 1.602176634e-15,
        source_rate_s = 1.0e20, represented_volume_m3 = 0.1,
        collision_time_density_constant_s_m3 = 2.0e18,
        mirror_ratio = 10.0, normalized_confining_potential = 0.5,
        maximum_normalized_speed = 4.0, speed_cell_count = nz,
        pitch_cell_count = nt, source_cell_weights = weights,
        source_artifact_id = "manufactured", source_artifact_hash = repeat("c", 64),
        source_result_hash = repeat("d", 64), candidate_binding_verified = true)
    observation = solve_directed_species_loss_cone_v1(problem;
        conservation_tolerance = 1.0e-7)
    @test observation.status == :pass
    @test observation.source_loss_relative_residual < 1.0e-7
    @test observation.linear_system_relative_residual < 1.0e-7
    @test observation.particle_density_m3 > 0.0
    @test observation.particle_inventory > 0.0
    @test observation.total_particle_loss_rate_s ≈ problem.source_rate_s rtol = 1.0e-12
    @test observation.left_particle_loss_rate_s > observation.right_particle_loss_rate_s
    @test sum(observation.physical_bin_inventories) ≈ observation.particle_inventory rtol = 1.0e-12
    @test !observation.c2_kinetic_state_authorized
    serialized = directed_species_loss_cone_observation_to_dict_v1(observation)
    @test serialized["observation_hash"] == observation.observation_hash
    @test_throws ArgumentError compile_directed_species_loss_cone_problem_v1(
        design_id = "bad", genome_physics_hash = repeat("a", 64),
        executable_candidate_physics_hash = repeat("b", 64), domain_id = "open",
        species_id = "d", charge_number = 1, mass_kg = 1.0, temperature_j = 1.0,
        source_rate_s = 1.0, represented_volume_m3 = 1.0,
        collision_time_density_constant_s_m3 = 1.0, mirror_ratio = 2.0,
        speed_cell_count = nz, pitch_cell_count = nt,
        source_cell_weights = zeros(nz, nt), source_artifact_id = "bad",
        source_artifact_hash = repeat("c", 64), source_result_hash = repeat("d", 64))
end
