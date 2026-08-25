"A family-independent, single-species sourced loss-cone Fokker--Planck problem."
struct SourcedLossConeFokkerPlanckProblemV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    species_id::String
    mirror_ratio::Float64
    normalized_confining_potential::Float64
    source_temperature_ratio::Float64
    low_speed_regularization::Float64
    perpendicular_diffusion_coefficient::Float64
    maximum_normalized_speed::Float64
    speed_cell_count::Int
    pitch_cell_count::Int
    geometry_candidate_binding_verified::Bool
    source_model_candidate_binding_verified::Bool
    equation_source_ids::Vector{String}
    model_scope::String
    problem_hash::String
end

"A conservative finite-volume solution of the dimensionless sourced equation."
struct SourcedLossConeFokkerPlanckObservationV1
    solver_version::String
    problem_hash::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    species_id::String
    speed_cell_count::Int
    pitch_cell_count::Int
    trapped_cell_count::Int
    loss_cell_count::Int
    normalized_inventory::Float64
    normalized_source_rate::Float64
    normalized_absorbing_loss_rate::Float64
    source_loss_relative_residual::Float64
    linear_system_relative_residual::Float64
    normalized_confinement_time::Float64
    mean_lost_energy_over_temperature::Float64
    perpendicular_to_parallel_pressure_ratio::Float64
    minimum_distribution_value::Float64
    maximum_distribution_value::Float64
    speed_grid::Vector{Float64}
    pitch_grid::Vector{Float64}
    normalized_speed_projection::Vector{Float64}
    normalized_pitch_projection::Vector{Float64}
    status::Symbol
    c2_physical_rate_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

"Grid convergence of the reduced kinetic solution; never authorizes a physical rate."
struct SourcedLossConeFokkerPlanckConvergenceV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    species_id::String
    observation_hashes::Vector{String}
    normalized_confinement_times::Vector{Float64}
    mean_lost_energies_over_temperature::Vector{Float64}
    pressure_anisotropy_ratios::Vector{Float64}
    maximum_adjacent_relative_change::Float64
    convergence_limit::Float64
    status::Symbol
    c2_physical_rate_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    convergence_hash::String
end

function compile_sourced_loss_cone_fokker_planck_problem_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, species_id::AbstractString,
        mirror_ratio::Real, normalized_confining_potential::Real = 0.0,
        source_temperature_ratio::Real = 1.0,
        low_speed_regularization::Real = 0.01,
        perpendicular_diffusion_coefficient::Real = 0.5,
        maximum_normalized_speed::Real = 5.0,
        speed_cell_count::Integer = 48, pitch_cell_count::Integer = 40,
        geometry_candidate_binding_verified::Bool = false,
        source_model_candidate_binding_verified::Bool = false,
        equation_source_ids::AbstractVector{<:AbstractString} = String[])
    values = Float64[mirror_ratio, normalized_confining_potential,
        source_temperature_ratio, low_speed_regularization,
        perpendicular_diffusion_coefficient, maximum_normalized_speed]
    all(isfinite, values) || throw(ArgumentError(
        "loss-cone Fokker--Planck inputs must be finite"))
    mirror_ratio > 1.0 || throw(ArgumentError("mirror ratio must exceed one"))
    normalized_confining_potential >= 0.0 || throw(ArgumentError(
        "normalized confining potential must be non-negative"))
    source_temperature_ratio > 0.0 && low_speed_regularization > 0.0 &&
        perpendicular_diffusion_coefficient > 0.0 &&
        maximum_normalized_speed > 1.0 || throw(ArgumentError(
        "source, diffusion, regularization, and speed extent must be positive"))
    speed_cell_count >= 12 && pitch_cell_count >= 12 || throw(ArgumentError(
        "at least 12 cells are required in each velocity coordinate"))
    sources = sort!(unique(String.(equation_source_ids)))
    scope = "Single singly-charged species; steady dimensionless high-velocity collision model of Ochs, Munirov and Fisch; fixed confining potential; isotropic Maxwellian source; reflecting outer boundaries and absorbing generalized loss boundary."
    core = Dict{String,Any}(
        "compiler_version" => "sourced_loss_cone_fokker_planck_compiler_v1.0.0",
        "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id), "species_id" => String(species_id),
        "mirror_ratio" => Float64(mirror_ratio),
        "normalized_confining_potential" => Float64(normalized_confining_potential),
        "source_temperature_ratio" => Float64(source_temperature_ratio),
        "low_speed_regularization" => Float64(low_speed_regularization),
        "perpendicular_diffusion_coefficient" =>
            Float64(perpendicular_diffusion_coefficient),
        "maximum_normalized_speed" => Float64(maximum_normalized_speed),
        "speed_cell_count" => Int(speed_cell_count),
        "pitch_cell_count" => Int(pitch_cell_count),
        "geometry_candidate_binding_verified" =>
            geometry_candidate_binding_verified,
        "source_model_candidate_binding_verified" =>
            source_model_candidate_binding_verified,
        "equation_source_ids" => sources, "model_scope" => scope)
    return SourcedLossConeFokkerPlanckProblemV1(
        "sourced_loss_cone_fokker_planck_compiler_v1.0.0",
        String(design_id), String(genome_physics_hash), String(domain_id),
        String(species_id), Float64(mirror_ratio),
        Float64(normalized_confining_potential),
        Float64(source_temperature_ratio), Float64(low_speed_regularization),
        Float64(perpendicular_diffusion_coefficient),
        Float64(maximum_normalized_speed), Int(speed_cell_count),
        Int(pitch_cell_count), geometry_candidate_binding_verified,
        source_model_candidate_binding_verified, sources, scope,
        canonical_hash(core))
end

_slcfp_metric_v1(z, theta) = 4.0 * pi * z^2 * sin(theta)

function _slcfp_trapped_v1(problem, z, theta)
    rhs = 1.0 - problem.normalized_confining_potential / z^2
    return rhs <= 0.0 || problem.mirror_ratio * sin(theta)^2 >= rhs
end

function _slcfp_add!(rows, columns, values, row, column, value)
    push!(rows, row); push!(columns, column); push!(values, value)
end

_slcfp_relative_change_v1(a, b) =
    abs(a - b) / max(abs(a), abs(b), 1.0e-30)

"Solve equation (3.29) of Ochs et al. 2024 with a conservative cell-centred grid."
function solve_sourced_loss_cone_fokker_planck_v1(
        problem::SourcedLossConeFokkerPlanckProblemV1;
        conservation_tolerance::Real = 1.0e-8,
        positivity_tolerance::Real = 1.0e-10)
    nz, nt = problem.speed_cell_count, problem.pitch_cell_count
    dz = problem.maximum_normalized_speed / nz
    dt = (pi / 2.0) / nt
    zgrid = [(i - 0.5) * dz for i in 1:nz]
    tgrid = [(j - 0.5) * dt for j in 1:nt]
    trapped = [_slcfp_trapped_v1(problem, zgrid[i], tgrid[j])
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
    gcell = [_slcfp_metric_v1(zgrid[i], tgrid[j]) for i in 1:nz, j in 1:nt]
    source = [pi^(-1.5) * exp(-zgrid[i]^2 /
        problem.source_temperature_ratio) for i in 1:nz, j in 1:nt]
    for j in 1:nt, i in 1:nz
        trapped[i, j] || continue
        rhs[indices[i, j]] = -gcell[i, j] * source[i, j]
    end
    # Internal speed faces; external speed faces are reflecting.
    for j in 1:nt, i in 1:(nz - 1)
        left, right = trapped[i, j], trapped[i + 1, j]
        (left || right) || continue
        zf = i * dz
        gf = _slcfp_metric_v1(zf, tgrid[j])
        denom = zf^3 + problem.low_speed_regularization^3
        af, df = zf / denom, 0.5 / denom
        c_left = gf * (0.5 * af - df / dz)
        c_right = gf * (0.5 * af + df / dz)
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
            _slcfp_add!(rows, columns, coefficients, row, row,
                -c_right / dz)
        end
    end
    # Internal pitch-angle faces; theta=0 and pi/2 are reflecting if trapped.
    for j in 1:(nt - 1), i in 1:nz
        lower, upper = trapped[i, j], trapped[i, j + 1]
        (lower || upper) || continue
        tf = j * dt
        gf = _slcfp_metric_v1(zgrid[i], tf)
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
    source_rate = sum(gcell[trapped] .* source[trapped]) * dz * dt
    inventory = sum(gcell[trapped] .* distribution[trapped]) * dz * dt
    boundary_loss = 0.0
    boundary_energy = 0.0
    for j in 1:nt, i in 1:(nz - 1)
        trapped[i, j] == trapped[i + 1, j] && continue
        zf = i * dz
        gf = _slcfp_metric_v1(zf, tgrid[j])
        denom = zf^3 + problem.low_speed_regularization^3
        af, df = zf / denom, 0.5 / denom
        fl, fr = distribution[i, j], distribution[i + 1, j]
        flux = gf * (af * 0.5 * (fl + fr) + df * (fr - fl) / dz)
        outward = trapped[i, j] ? -flux : flux
        boundary_loss += outward * dt
        boundary_energy += outward * zf^2 * dt
    end
    for j in 1:(nt - 1), i in 1:nz
        trapped[i, j] == trapped[i, j + 1] && continue
        tf = j * dt
        gf = _slcfp_metric_v1(zgrid[i], tf)
        df = problem.perpendicular_diffusion_coefficient /
            (zgrid[i]^3 + problem.low_speed_regularization^3)
        flux = gf * df * (distribution[i, j + 1] -
            distribution[i, j]) / dt
        outward = trapped[i, j] ? -flux : flux
        boundary_loss += outward * dz
        boundary_energy += outward * zgrid[i]^2 * dz
    end
    conservation = abs(source_rate - boundary_loss) /
        max(abs(source_rate), abs(boundary_loss), 1.0e-30)
    linear_residual = maximum(abs.(matrix * solution - rhs)) /
        max(maximum(abs.(rhs)), 1.0e-30)
    parallel_moment = 0.0; perpendicular_moment = 0.0
    speed_projection = zeros(Float64, nz)
    pitch_projection = zeros(Float64, nt)
    for j in 1:nt, i in 1:nz
        weight = gcell[i, j] * distribution[i, j] * dz * dt
        parallel_moment += weight * zgrid[i]^2 * cos(tgrid[j])^2
        perpendicular_moment += weight * zgrid[i]^2 * sin(tgrid[j])^2
        speed_projection[i] += weight
        pitch_projection[j] += weight
    end
    if inventory > 0.0
        speed_projection ./= inventory
        pitch_projection ./= inventory
    end
    anisotropy = 0.5 * perpendicular_moment /
        max(parallel_moment, 1.0e-30)
    mean_lost_energy = boundary_energy / max(boundary_loss, 1.0e-30)
    minf, maxf = minimum(solution), maximum(solution)
    positive = minf >= -Float64(positivity_tolerance) * max(maxf, 1.0)
    conserved = conservation <= Float64(conservation_tolerance) &&
        linear_residual <= Float64(conservation_tolerance)
    status = positive && conserved ? :pass : :fail
    tasks = String[
        "solve_multispecies_nonlinear_coulomb_fokker_planck",
        "solve_ambipolar_potential_from_quasineutrality_and_equal_end_current",
        "bind_physical_collision_frequency_and_particle_source_rate",
        "include_nbi_deposition_charge_exchange_and_radial_transport"]
    problem.geometry_candidate_binding_verified || push!(tasks,
        "bind_loss_boundary_geometry_to_candidate")
    problem.source_model_candidate_binding_verified || push!(tasks,
        "bind_source_distribution_to_candidate_actuator")
    warnings = String[
        "This solves a published reduced dimensionless single-species equation, not the nonlinear multispecies CQL3D-m operator.",
        "The confining potential is prescribed rather than solved ambipolarly, so no physical end-loss rate or C2 balance evidence is authorized.",
        "A converged velocity-space depletion shape cannot establish kinetic stability, radial transport, charge-exchange loss, heating balance, or feasibility."]
    core = Dict{String,Any}(
        "solver_version" => "sourced_loss_cone_fokker_planck_solver_v1.0.0",
        "problem_hash" => problem.problem_hash,
        "normalized_inventory" => inventory,
        "normalized_source_rate" => source_rate,
        "normalized_absorbing_loss_rate" => boundary_loss,
        "source_loss_relative_residual" => conservation,
        "linear_system_relative_residual" => linear_residual,
        "normalized_confinement_time" => inventory / source_rate,
        "mean_lost_energy_over_temperature" => mean_lost_energy,
        "perpendicular_to_parallel_pressure_ratio" => anisotropy,
        "minimum_distribution_value" => minf,
        "maximum_distribution_value" => maxf,
        "speed_grid" => zgrid, "pitch_grid" => tgrid,
        "normalized_speed_projection" => speed_projection,
        "normalized_pitch_projection" => pitch_projection,
        "status" => String(status), "c2_physical_rate_authorized" => false,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return SourcedLossConeFokkerPlanckObservationV1(
        "sourced_loss_cone_fokker_planck_solver_v1.0.0",
        problem.problem_hash, problem.design_id, problem.genome_physics_hash,
        problem.domain_id, problem.species_id, nz, nt, active,
        nz * nt - active, inventory, source_rate, boundary_loss,
        conservation, linear_residual, inventory / source_rate,
        mean_lost_energy, anisotropy, minf, maxf, zgrid, tgrid,
        speed_projection, pitch_projection, status, false,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

function compile_sourced_loss_cone_fokker_planck_convergence_v1(
        observations::AbstractVector{SourcedLossConeFokkerPlanckObservationV1};
        convergence_limit::Real = 0.08)
    length(observations) >= 2 || throw(ArgumentError(
        "at least two kinetic observations are required"))
    limit = Float64(convergence_limit)
    isfinite(limit) && limit >= 0.0 || throw(ArgumentError(
        "convergence limit must be finite and non-negative"))
    ordered = sort!(collect(observations); by = item ->
        item.speed_cell_count * item.pitch_cell_count)
    first_item = first(ordered)
    all(item -> item.design_id == first_item.design_id &&
        item.genome_physics_hash == first_item.genome_physics_hash &&
        item.domain_id == first_item.domain_id &&
        item.species_id == first_item.species_id, ordered) || throw(ArgumentError(
        "kinetic observations must share candidate, domain, and species"))
    taus = getfield.(ordered, :normalized_confinement_time)
    energies = getfield.(ordered, :mean_lost_energy_over_temperature)
    anisotropies = getfield.(ordered, :perpendicular_to_parallel_pressure_ratio)
    changes = Float64[]
    for values in (taus, energies, anisotropies), index in 2:length(values)
        push!(changes, _slcfp_relative_change_v1(values[index - 1], values[index]))
    end
    maxchange = maximum(changes)
    status = all(item -> item.status == :pass, ordered) && maxchange <= limit ?
        :pass : :fail
    tasks = sort!(unique([task for item in ordered for task in item.evidence_tasks]))
    status == :fail && push!(tasks, "refine_loss_cone_velocity_grid")
    warnings = String[
        "Grid convergence validates only the reduced fixed-potential equation; physical-rate C2 remains unauthorized."]
    core = Dict{String,Any}(
        "design_id" => first_item.design_id,
        "genome_physics_hash" => first_item.genome_physics_hash,
        "domain_id" => first_item.domain_id,
        "species_id" => first_item.species_id,
        "observation_hashes" => getfield.(ordered, :observation_hash),
        "normalized_confinement_times" => taus,
        "mean_lost_energies_over_temperature" => energies,
        "pressure_anisotropy_ratios" => anisotropies,
        "maximum_adjacent_relative_change" => maxchange,
        "convergence_limit" => limit, "status" => String(status),
        "c2_physical_rate_authorized" => false,
        "evidence_tasks" => tasks, "warnings" => warnings)
    return SourcedLossConeFokkerPlanckConvergenceV1(
        first_item.design_id, first_item.genome_physics_hash,
        first_item.domain_id, first_item.species_id,
        getfield.(ordered, :observation_hash), taus, energies, anisotropies,
        maxchange, limit, status, false, tasks, warnings, canonical_hash(core))
end

function sourced_loss_cone_fokker_planck_problem_to_dict_v1(problem)
    Dict{String,Any}(String(name) => getfield(problem, name)
        for name in fieldnames(typeof(problem)))
end

function sourced_loss_cone_fokker_planck_observation_to_dict_v1(observation)
    result = Dict{String,Any}(String(name) => getfield(observation, name)
        for name in fieldnames(typeof(observation)))
    result["status"] = String(observation.status)
    return result
end

function sourced_loss_cone_fokker_planck_convergence_to_dict_v1(convergence)
    result = Dict{String,Any}(String(name) => getfield(convergence, name)
        for name in fieldnames(typeof(convergence)))
    result["status"] = String(convergence.status)
    return result
end
