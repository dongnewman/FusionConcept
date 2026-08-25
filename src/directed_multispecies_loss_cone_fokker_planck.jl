"One species in a full-pitch, candidate-bound, source-driven reduced loss-cone solve."
struct DirectedSpeciesLossConeProblemV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    executable_candidate_physics_hash::String
    domain_id::String
    species_id::String
    charge_number::Int
    mass_kg::Float64
    temperature_j::Float64
    source_rate_s::Float64
    represented_volume_m3::Float64
    collision_time_density_constant_s_m3::Float64
    mirror_ratio::Float64
    normalized_confining_potential::Float64
    low_speed_regularization::Float64
    perpendicular_diffusion_coefficient::Float64
    maximum_normalized_speed::Float64
    speed_cell_count::Int
    pitch_cell_count::Int
    source_cell_weights::Matrix{Float64}
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    collision_normalization_applicability_verified::Bool
    problem_hash::String
end

"Physical normalization and full signed-pitch distribution from the reduced operator."
struct DirectedSpeciesLossConeObservationV1
    solver_version::String
    problem_hash::String
    design_id::String
    genome_physics_hash::String
    executable_candidate_physics_hash::String
    domain_id::String
    species_id::String
    speed_grid::Vector{Float64}
    pitch_grid::Vector{Float64}
    normalized_distribution::Matrix{Float64}
    physical_bin_inventories::Matrix{Float64}
    normalized_inventory::Float64
    normalized_loss_rate::Float64
    normalized_left_loss_rate::Float64
    normalized_right_loss_rate::Float64
    source_loss_relative_residual::Float64
    linear_system_relative_residual::Float64
    particle_density_m3::Float64
    particle_inventory::Float64
    physical_confinement_time_s::Float64
    left_particle_loss_rate_s::Float64
    right_particle_loss_rate_s::Float64
    total_particle_loss_rate_s::Float64
    left_boundary_kinetic_power_w::Float64
    right_boundary_kinetic_power_w::Float64
    total_boundary_kinetic_power_w::Float64
    mean_lost_energy_j::Float64
    perpendicular_to_parallel_pressure_ratio::Float64
    minimum_distribution_value::Float64
    maximum_distribution_value::Float64
    status::Symbol
    c2_kinetic_state_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

function compile_directed_species_loss_cone_problem_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        executable_candidate_physics_hash::AbstractString,
        domain_id::AbstractString, species_id::AbstractString,
        charge_number::Integer, mass_kg::Real, temperature_j::Real,
        source_rate_s::Real, represented_volume_m3::Real,
        collision_time_density_constant_s_m3::Real, mirror_ratio::Real,
        normalized_confining_potential::Real = 0.0,
        low_speed_regularization::Real = 0.01,
        perpendicular_diffusion_coefficient::Real = 0.5,
        maximum_normalized_speed::Real = 5.0,
        speed_cell_count::Integer = 48, pitch_cell_count::Integer = 64,
        source_cell_weights,
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString,
        source_result_hash::AbstractString,
        candidate_binding_verified::Bool = false,
        collision_normalization_applicability_verified::Bool = false)
    charge_number != 0 || throw(ArgumentError("charge number must be nonzero"))
    values = Float64[mass_kg, temperature_j, source_rate_s,
        represented_volume_m3, collision_time_density_constant_s_m3,
        mirror_ratio, normalized_confining_potential, low_speed_regularization,
        perpendicular_diffusion_coefficient, maximum_normalized_speed]
    all(isfinite, values) || throw(ArgumentError("species kinetic inputs must be finite"))
    mass_kg > 0.0 && temperature_j > 0.0 && source_rate_s > 0.0 &&
        represented_volume_m3 > 0.0 && collision_time_density_constant_s_m3 > 0.0 ||
        throw(ArgumentError("mass, temperature, source, volume, and collision normalization must be positive"))
    mirror_ratio > 1.0 || throw(ArgumentError("mirror ratio must exceed one"))
    low_speed_regularization > 0.0 && perpendicular_diffusion_coefficient > 0.0 &&
        maximum_normalized_speed > 1.0 || throw(ArgumentError(
        "regularization, diffusion, and speed extent must be positive"))
    speed_cell_count >= 12 && pitch_cell_count >= 16 || throw(ArgumentError(
        "at least 12 speed and 16 full-pitch cells are required"))
    weights = Matrix{Float64}(source_cell_weights)
    size(weights) == (Int(speed_cell_count), Int(pitch_cell_count)) ||
        throw(ArgumentError("source weights must match the velocity grid"))
    all(isfinite, weights) && all(>=(0.0), weights) && sum(weights) > 0.0 ||
        throw(ArgumentError("source weights must be finite, non-negative, and nonzero"))
    weights ./= sum(weights)
    for (value, name) in ((genome_physics_hash, "genome physics hash"),
            (executable_candidate_physics_hash, "candidate physics hash"),
            (source_artifact_hash, "source artifact hash"),
            (source_result_hash, "source result hash"))
        text = String(value)
        length(text) == 64 && all(isxdigit, text) || throw(ArgumentError(
            "$name must contain 64 hexadecimal characters"))
    end
    core = Dict{String,Any}(
        "compiler_version" => "directed_species_loss_cone_compiler_v1.0.0",
        "design_id" => String(design_id),
        "genome_physics_hash" => lowercase(String(genome_physics_hash)),
        "executable_candidate_physics_hash" =>
            lowercase(String(executable_candidate_physics_hash)),
        "domain_id" => String(domain_id), "species_id" => String(species_id),
        "charge_number" => Int(charge_number), "mass_kg" => Float64(mass_kg),
        "temperature_j" => Float64(temperature_j),
        "source_rate_s" => Float64(source_rate_s),
        "represented_volume_m3" => Float64(represented_volume_m3),
        "collision_time_density_constant_s_m3" =>
            Float64(collision_time_density_constant_s_m3),
        "mirror_ratio" => Float64(mirror_ratio),
        "normalized_confining_potential" => Float64(normalized_confining_potential),
        "low_speed_regularization" => Float64(low_speed_regularization),
        "perpendicular_diffusion_coefficient" =>
            Float64(perpendicular_diffusion_coefficient),
        "maximum_normalized_speed" => Float64(maximum_normalized_speed),
        "speed_cell_count" => Int(speed_cell_count),
        "pitch_cell_count" => Int(pitch_cell_count),
        "source_cell_weights" => [collect(view(weights, row, :))
            for row in axes(weights, 1)],
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => lowercase(String(source_artifact_hash)),
        "source_result_hash" => lowercase(String(source_result_hash)),
        "candidate_binding_verified" => candidate_binding_verified,
        "collision_normalization_applicability_verified" =>
            collision_normalization_applicability_verified)
    return DirectedSpeciesLossConeProblemV1(
        "directed_species_loss_cone_compiler_v1.0.0", String(design_id),
        lowercase(String(genome_physics_hash)),
        lowercase(String(executable_candidate_physics_hash)), String(domain_id),
        String(species_id), Int(charge_number), Float64(mass_kg),
        Float64(temperature_j), Float64(source_rate_s),
        Float64(represented_volume_m3),
        Float64(collision_time_density_constant_s_m3), Float64(mirror_ratio),
        Float64(normalized_confining_potential), Float64(low_speed_regularization),
        Float64(perpendicular_diffusion_coefficient),
        Float64(maximum_normalized_speed), Int(speed_cell_count),
        Int(pitch_cell_count), weights, String(source_artifact_id),
        lowercase(String(source_artifact_hash)), lowercase(String(source_result_hash)),
        candidate_binding_verified, collision_normalization_applicability_verified,
        canonical_hash(core))
end

_directed_fp_metric_v1(z, theta) = 2.0 * pi * z^2 * sin(theta)

function _directed_fp_trapped_v1(problem, z, theta)
    rhs = 1.0 - problem.normalized_confining_potential / z^2
    return rhs <= 0.0 || problem.mirror_ratio * sin(theta)^2 >= rhs
end

"Solve the reduced full-pitch equation and close its physical density through nu=n/C."
function solve_directed_species_loss_cone_v1(
        problem::DirectedSpeciesLossConeProblemV1;
        conservation_tolerance::Real = 1.0e-8,
        positivity_tolerance::Real = 1.0e-10)
    nz, nt = problem.speed_cell_count, problem.pitch_cell_count
    dz, dt = problem.maximum_normalized_speed / nz, pi / nt
    zgrid = [(i - 0.5) * dz for i in 1:nz]
    tgrid = [(j - 0.5) * dt for j in 1:nt]
    metric = [_directed_fp_metric_v1(zgrid[i], tgrid[j])
        for i in 1:nz, j in 1:nt]
    trapped = [_directed_fp_trapped_v1(problem, zgrid[i], tgrid[j])
        for i in 1:nz, j in 1:nt]
    indices = zeros(Int, nz, nt)
    active = 0
    for j in 1:nt, i in 1:nz
        if trapped[i, j]
            active += 1
            indices[i, j] = active
        end
    end
    active > 0 || throw(ArgumentError("loss boundary removes the complete grid"))
    rows = Int[]; columns = Int[]; coefficients = Float64[]
    rhs = zeros(Float64, active)
    for j in 1:nt, i in 1:nz
        trapped[i, j] || continue
        rhs[indices[i, j]] = -problem.source_cell_weights[i, j] / (dz * dt)
    end
    for j in 1:nt, i in 1:(nz - 1)
        left, right = trapped[i, j], trapped[i + 1, j]
        (left || right) || continue
        zf = i * dz
        gf = _directed_fp_metric_v1(zf, tgrid[j])
        denom = zf^3 + problem.low_speed_regularization^3
        af, df = zf / denom, 0.5 / denom
        c_left, c_right = gf * (0.5 * af - df / dz),
            gf * (0.5 * af + df / dz)
        if left
            row = indices[i, j]
            _slcfp_add!(rows, columns, coefficients, row, row, c_left / dz)
            right && _slcfp_add!(rows, columns, coefficients, row,
                indices[i + 1, j], c_right / dz)
        end
        if right
            row = indices[i + 1, j]
            left && _slcfp_add!(rows, columns, coefficients, row,
                indices[i, j], -c_left / dz)
            _slcfp_add!(rows, columns, coefficients, row, row, -c_right / dz)
        end
    end
    for j in 1:(nt - 1), i in 1:nz
        lower, upper = trapped[i, j], trapped[i, j + 1]
        (lower || upper) || continue
        tf = j * dt
        gf = _directed_fp_metric_v1(zgrid[i], tf)
        df = problem.perpendicular_diffusion_coefficient /
            (zgrid[i]^3 + problem.low_speed_regularization^3)
        c_lower, c_upper = -gf * df / dt, gf * df / dt
        if lower
            row = indices[i, j]
            _slcfp_add!(rows, columns, coefficients, row, row, c_lower / dt)
            upper && _slcfp_add!(rows, columns, coefficients, row,
                indices[i, j + 1], c_upper / dt)
        end
        if upper
            row = indices[i, j + 1]
            lower && _slcfp_add!(rows, columns, coefficients, row,
                indices[i, j], -c_lower / dt)
            _slcfp_add!(rows, columns, coefficients, row, row, -c_upper / dt)
        end
    end
    matrix = sparse(rows, columns, coefficients, active, active)
    solution = matrix \ rhs
    distribution = zeros(Float64, nz, nt)
    for j in 1:nt, i in 1:nz
        trapped[i, j] && (distribution[i, j] = solution[indices[i, j]])
    end
    admitted_source = sum(problem.source_cell_weights[trapped])
    inventory = sum(metric[trapped] .* distribution[trapped]) * dz * dt
    left_loss = sum(problem.source_cell_weights[i, j]
        for i in 1:nz, j in 1:nt if !trapped[i, j] && tgrid[j] < pi / 2.0)
    right_loss = sum(problem.source_cell_weights[i, j]
        for i in 1:nz, j in 1:nt if !trapped[i, j] && tgrid[j] >= pi / 2.0)
    left_energy = sum(problem.source_cell_weights[i, j] * zgrid[i]^2
        for i in 1:nz, j in 1:nt if !trapped[i, j] && tgrid[j] < pi / 2.0)
    right_energy = sum(problem.source_cell_weights[i, j] * zgrid[i]^2
        for i in 1:nz, j in 1:nt if !trapped[i, j] && tgrid[j] >= pi / 2.0)
    function add_loss!(outward, energy, theta)
        if theta < pi / 2.0
            left_loss += outward
            left_energy += outward * energy
        else
            right_loss += outward
            right_energy += outward * energy
        end
    end
    for j in 1:nt, i in 1:(nz - 1)
        trapped[i, j] == trapped[i + 1, j] && continue
        zf = i * dz
        gf = _directed_fp_metric_v1(zf, tgrid[j])
        denom = zf^3 + problem.low_speed_regularization^3
        af, df = zf / denom, 0.5 / denom
        fl, fr = distribution[i, j], distribution[i + 1, j]
        flux = gf * (af * 0.5 * (fl + fr) + df * (fr - fl) / dz)
        outward = (trapped[i, j] ? -flux : flux) * dt
        add_loss!(outward, zf^2, tgrid[j])
    end
    for j in 1:(nt - 1), i in 1:nz
        trapped[i, j] == trapped[i, j + 1] && continue
        tf = j * dt
        gf = _directed_fp_metric_v1(zgrid[i], tf)
        df = problem.perpendicular_diffusion_coefficient /
            (zgrid[i]^3 + problem.low_speed_regularization^3)
        flux = gf * df * (distribution[i, j + 1] - distribution[i, j]) / dt
        outward = (trapped[i, j] ? -flux : flux) * dz
        add_loss!(outward, zgrid[i]^2, tf)
    end
    total_loss = left_loss + right_loss
    source_loss_residual = abs(1.0 - total_loss) /
        max(1.0, abs(total_loss), 1.0e-30)
    linear_residual = maximum(abs.(matrix * solution - rhs)) /
        max(maximum(abs.(rhs)), 1.0e-30)
    density = sqrt(problem.source_rate_s * inventory *
        problem.collision_time_density_constant_s_m3 /
        problem.represented_volume_m3)
    particle_inventory = density * problem.represented_volume_m3
    confinement_time = particle_inventory / problem.source_rate_s
    physical_scale = problem.source_rate_s / max(total_loss, 1.0e-30)
    left_rate, right_rate = left_loss * physical_scale, right_loss * physical_scale
    left_power = left_energy * physical_scale * problem.temperature_j
    right_power = right_energy * physical_scale * problem.temperature_j
    physical_bins = metric .* distribution .* (dz * dt) ./ max(inventory, 1.0e-30) .*
        particle_inventory
    parallel_moment = sum(metric .* distribution .* [zgrid[i]^2 * cos(tgrid[j])^2
        for i in 1:nz, j in 1:nt]) * dz * dt
    perpendicular_moment = sum(metric .* distribution .* [zgrid[i]^2 * sin(tgrid[j])^2
        for i in 1:nz, j in 1:nt]) * dz * dt
    anisotropy = 0.5 * perpendicular_moment / max(parallel_moment, 1.0e-30)
    minf, maxf = minimum(solution), maximum(solution)
    positive = minf >= -Float64(positivity_tolerance) * max(maxf, 1.0)
    conserved = source_loss_residual <= Float64(conservation_tolerance) &&
        linear_residual <= Float64(conservation_tolerance)
    status = positive && conserved ? :pass : :fail
    tasks = String[
        "replace_reduced_high_velocity_collision_operator_with_nonlinear_multispecies_Rosenbluth_operator",
        "bounce_average_on_full_candidate_equilibrium_instead_of_scalar_mirror_ratio",
        "include_charge_exchange_redistribution_radial_transport_and_energy_exchange",
        "verify_collision_normalization_against_candidate_kinetic_control",
        "run_two_resolution_distribution_potential_and_end_flux_audit"]
    problem.candidate_binding_verified || push!(tasks,
        "bind_distribution_source_to_candidate")
    problem.collision_normalization_applicability_verified || push!(tasks,
        "verify_collision_time_density_normalization_applicability")
    warnings = String[
        "The full signed-pitch source enters a reduced high-velocity test-particle operator, not a nonlinear multispecies Rosenbluth collision solve.",
        "The physical density closure assumes collision frequency nu=n/C and a steady source-loss balance in the represented volume.",
        "The scalar mirror ratio omits radial and axial bounce-average variation; this output is a C1 kinetic closure for system integration, not C2 authority."]
    core = Dict{String,Any}(
        "solver_version" => "directed_species_loss_cone_solver_v1.0.0",
        "problem_hash" => problem.problem_hash,
        "speed_grid" => zgrid, "pitch_grid" => tgrid,
        "normalized_distribution" => [collect(view(distribution, row, :))
            for row in axes(distribution, 1)],
        "physical_bin_inventories" => [collect(view(physical_bins, row, :))
            for row in axes(physical_bins, 1)],
        "normalized_inventory" => inventory,
        "normalized_loss_rate" => total_loss,
        "normalized_left_loss_rate" => left_loss,
        "normalized_right_loss_rate" => right_loss,
        "source_loss_relative_residual" => source_loss_residual,
        "linear_system_relative_residual" => linear_residual,
        "particle_density_m3" => density, "particle_inventory" => particle_inventory,
        "physical_confinement_time_s" => confinement_time,
        "left_particle_loss_rate_s" => left_rate,
        "right_particle_loss_rate_s" => right_rate,
        "total_particle_loss_rate_s" => left_rate + right_rate,
        "left_boundary_kinetic_power_w" => left_power,
        "right_boundary_kinetic_power_w" => right_power,
        "total_boundary_kinetic_power_w" => left_power + right_power,
        "mean_lost_energy_j" => (left_power + right_power) /
            max(left_rate + right_rate, 1.0e-30),
        "perpendicular_to_parallel_pressure_ratio" => anisotropy,
        "minimum_distribution_value" => minf,
        "maximum_distribution_value" => maxf, "status" => String(status),
        "c2_kinetic_state_authorized" => false,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return DirectedSpeciesLossConeObservationV1(
        "directed_species_loss_cone_solver_v1.0.0", problem.problem_hash,
        problem.design_id, problem.genome_physics_hash,
        problem.executable_candidate_physics_hash, problem.domain_id,
        problem.species_id, zgrid, tgrid, distribution, physical_bins,
        inventory, total_loss, left_loss, right_loss, source_loss_residual,
        linear_residual, density, particle_inventory, confinement_time,
        left_rate, right_rate, left_rate + right_rate, left_power, right_power,
        left_power + right_power, (left_power + right_power) /
            max(left_rate + right_rate, 1.0e-30), anisotropy, minf, maxf,
        status, false, sort!(unique(tasks)), warnings, canonical_hash(core))
end

directed_species_loss_cone_problem_to_dict_v1(problem) =
    Dict{String,Any}(String(name) => (name == :source_cell_weights ?
        [collect(view(problem.source_cell_weights, row, :))
            for row in axes(problem.source_cell_weights, 1)] : getfield(problem, name))
        for name in fieldnames(typeof(problem)))

function directed_species_loss_cone_observation_to_dict_v1(observation)
    result = Dict{String,Any}(String(name) => getfield(observation, name)
        for name in fieldnames(typeof(observation)))
    result["status"] = String(observation.status)
    result["normalized_distribution"] = [collect(view(
        observation.normalized_distribution, row, :))
        for row in axes(observation.normalized_distribution, 1)]
    result["physical_bin_inventories"] = [collect(view(
        observation.physical_bin_inventories, row, :))
        for row in axes(observation.physical_bin_inventories, 1)]
    return result
end
