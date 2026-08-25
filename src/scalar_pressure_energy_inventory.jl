"Candidate-bound scalar-pressure volume integral at one numerical resolution."
struct ScalarPressureEnergyObservationV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    pressure_model::Symbol
    resolution_label::String
    resolution_rank::Int
    point_count::Int
    plasma_volume_m3::Float64
    pressure_volume_integral_j::Float64
    adiabatic_index::Float64
    scalar_mhd_thermal_energy_j::Float64
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    species_resolved::Bool
    distribution_resolved::Bool
    fidelity::Int
    source_solver_status::Symbol
    status::Symbol
    c2_observation_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

"Resolution assessment for a scalar-pressure thermodynamic-energy inventory."
struct ScalarPressureEnergyConvergenceV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    pressure_model::Symbol
    observation_hashes::Vector{String}
    resolution_labels::Vector{String}
    scalar_mhd_thermal_energy_j::Vector{Float64}
    adjacent_relative_changes::Vector{Float64}
    convergence_limit::Float64
    status::Symbol
    resolution_verified::Bool
    c2_scalar_mhd_energy_authorized::Bool
    complete_particle_state_authorized::Bool
    evidence_tasks::Vector{String}
    convergence_hash::String
end

function compile_scalar_pressure_energy_observation_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, pressure_model::Symbol,
        resolution_label::AbstractString, resolution_rank::Integer,
        point_count::Integer, plasma_volume_m3::Real,
        pressure_volume_integral_j::Real, adiabatic_index::Real,
        scalar_mhd_thermal_energy_j::Real,
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString,
        source_result_hash::AbstractString,
        candidate_binding_verified::Bool, species_resolved::Bool,
        distribution_resolved::Bool, fidelity::Integer,
        source_solver_status::Symbol)
    pressure_model in (:scalar_isotropic_mhd, :anisotropic_cgl,
        :kinetic_moment) || throw(ArgumentError("unsupported pressure model"))
    source_solver_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid pressure-energy source status"))
    rank = Int(resolution_rank)
    points = Int(point_count)
    gamma = Float64(adiabatic_index)
    volume = Float64(plasma_volume_m3)
    integral = Float64(pressure_volume_integral_j)
    energy = Float64(scalar_mhd_thermal_energy_j)
    all(isfinite, (gamma, volume, integral, energy)) || throw(ArgumentError(
        "pressure-energy quantities must be finite"))
    rank > 0 || throw(ArgumentError("resolution rank must be positive"))
    points > 0 || throw(ArgumentError("point count must be positive"))
    gamma > 1.0 || throw(ArgumentError("adiabatic index must exceed one"))
    volume > 0.0 || throw(ArgumentError("plasma volume must be positive"))
    integral >= 0.0 || throw(ArgumentError(
        "pressure-volume integral must be non-negative"))
    energy >= 0.0 || throw(ArgumentError(
        "scalar MHD thermal energy must be non-negative"))
    expected = integral / (gamma - 1.0)
    isapprox(energy, expected; rtol = 1.0e-10,
        atol = max(1.0e-12, 1.0e-12 * abs(expected))) ||
        throw(ArgumentError("thermal energy is inconsistent with pressure integral and gamma"))
    fidelity >= 0 || throw(ArgumentError("fidelity must be non-negative"))
    tasks = String[]
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    length(source_artifact_hash) == 64 || push!(tasks,
        "provide_source_artifact_hash")
    length(source_result_hash) == 64 || push!(tasks,
        "provide_source_result_hash")
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    fidelity >= 2 || push!(tasks, "raise_scalar_pressure_inventory_to_c2")
    species_resolved || append!(tasks, ["resolve_species_density_profiles",
        "resolve_species_temperature_profiles"])
    distribution_resolved || push!(tasks, "resolve_velocity_distribution_functions")
    pressure_model == :scalar_isotropic_mhd || push!(tasks,
        "verify_pressure_energy_closure_for_non_scalar_model")
    provenance = !isempty(source_artifact_id) &&
        length(source_artifact_hash) == 64 && length(source_result_hash) == 64
    ready = provenance && candidate_binding_verified
    authoritative = ready && fidelity >= 2
    status = authoritative && source_solver_status in (:fail, :error) ? :fail :
        ready && source_solver_status == :pass ? :pass : :unknown
    authorized = status == :pass && authoritative &&
        pressure_model == :scalar_isotropic_mhd
    warnings = String[
        "Scalar-pressure thermodynamic energy is not a species particle inventory, temperature profile, velocity distribution, fusion rate, radiation loss, transport flux, or confinement time."]
    !species_resolved && push!(warnings,
        "Species-resolved density and temperature are absent; no reaction or collisional operator may consume this value as a complete plasma state.")
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id),
        "pressure_model" => String(pressure_model),
        "resolution_label" => String(resolution_label),
        "resolution_rank" => rank, "point_count" => points,
        "plasma_volume_m3" => volume,
        "pressure_volume_integral_j" => integral,
        "adiabatic_index" => gamma,
        "scalar_mhd_thermal_energy_j" => energy,
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "species_resolved" => species_resolved,
        "distribution_resolved" => distribution_resolved,
        "fidelity" => Int(fidelity),
        "source_solver_status" => String(source_solver_status),
        "status" => String(status),
        "c2_observation_authorized" => authorized,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return ScalarPressureEnergyObservationV1(String(design_id),
        String(genome_physics_hash), String(domain_id), pressure_model,
        String(resolution_label), rank, points, volume, integral, gamma, energy,
        String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified,
        species_resolved, distribution_resolved, Int(fidelity),
        source_solver_status, status, authorized, sort!(unique(tasks)),
        warnings, canonical_hash(core))
end

function scalar_pressure_energy_observation_to_dict_v1(
        item::ScalarPressureEnergyObservationV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id,
        "pressure_model" => String(item.pressure_model),
        "resolution_label" => item.resolution_label,
        "resolution_rank" => item.resolution_rank,
        "point_count" => item.point_count,
        "plasma_volume_m3" => item.plasma_volume_m3,
        "pressure_volume_integral_j" => item.pressure_volume_integral_j,
        "adiabatic_index" => item.adiabatic_index,
        "scalar_mhd_thermal_energy_j" => item.scalar_mhd_thermal_energy_j,
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "species_resolved" => item.species_resolved,
        "distribution_resolved" => item.distribution_resolved,
        "fidelity" => item.fidelity,
        "source_solver_status" => String(item.source_solver_status),
        "status" => String(item.status),
        "c2_observation_authorized" => item.c2_observation_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "observation_hash" => item.observation_hash)
end

function compile_scalar_pressure_energy_convergence_v1(
        observations::AbstractVector{ScalarPressureEnergyObservationV1};
        convergence_limit::Real = 0.02)
    length(observations) >= 2 || throw(ArgumentError(
        "at least two pressure-energy resolutions are required"))
    limit = Float64(convergence_limit)
    0.0 < limit < 1.0 || throw(ArgumentError(
        "convergence limit must lie between zero and one"))
    ordered = sort!(collect(observations), by = item -> item.resolution_rank)
    ranks = [item.resolution_rank for item in ordered]
    length(unique(ranks)) == length(ranks) || throw(ArgumentError(
        "pressure-energy resolution ranks must be unique"))
    design_ids = unique(item.design_id for item in ordered)
    hashes = unique(item.genome_physics_hash for item in ordered)
    domains = unique(item.domain_id for item in ordered)
    models = unique(item.pressure_model for item in ordered)
    gammas = unique(item.adiabatic_index for item in ordered)
    length(design_ids) == length(hashes) == length(domains) ==
        length(models) == length(gammas) == 1 || throw(ArgumentError(
        "pressure-energy observations must share candidate, domain, model, and gamma"))
    energies = [item.scalar_mhd_thermal_energy_j for item in ordered]
    changes = [abs(energies[index] - energies[index - 1]) /
        max(abs(energies[index]), 1.0e-30) for index in 2:length(energies)]
    if any(item.status == :fail for item in ordered)
        status = :fail
    else
        all_ready = all(item.status == :pass && item.c2_observation_authorized
            for item in ordered)
        status = all_ready && last(changes) <= limit ? :pass :
            all_ready ? :fail : :unknown
    end
    resolution_verified = status == :pass
    scalar_authorized = resolution_verified && only(models) ==
        :scalar_isotropic_mhd
    complete_state = scalar_authorized && all(item.species_resolved &&
        item.distribution_resolved for item in ordered)
    tasks = String[]
    for item in ordered
        append!(tasks, item.evidence_tasks)
    end
    last(changes) <= limit || push!(tasks,
        "resolve_scalar_pressure_energy_grid_convergence")
    complete_state || append!(tasks, ["resolve_species_density_profiles",
        "resolve_species_temperature_profiles",
        "resolve_velocity_distribution_functions"])
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => only(design_ids),
        "genome_physics_hash" => only(hashes), "domain_id" => only(domains),
        "pressure_model" => String(only(models)),
        "observation_hashes" => [item.observation_hash for item in ordered],
        "resolution_labels" => [item.resolution_label for item in ordered],
        "scalar_mhd_thermal_energy_j" => energies,
        "adjacent_relative_changes" => changes,
        "convergence_limit" => limit, "status" => String(status),
        "resolution_verified" => resolution_verified,
        "c2_scalar_mhd_energy_authorized" => scalar_authorized,
        "complete_particle_state_authorized" => complete_state,
        "evidence_tasks" => sort!(unique(tasks)))
    return ScalarPressureEnergyConvergenceV1(only(design_ids), only(hashes),
        only(domains), only(models), [item.observation_hash for item in ordered],
        [item.resolution_label for item in ordered], energies, changes, limit,
        status, resolution_verified, scalar_authorized, complete_state,
        sort!(unique(tasks)), canonical_hash(core))
end

function scalar_pressure_energy_convergence_to_dict_v1(
        item::ScalarPressureEnergyConvergenceV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id,
        "pressure_model" => String(item.pressure_model),
        "observation_hashes" => item.observation_hashes,
        "resolution_labels" => item.resolution_labels,
        "scalar_mhd_thermal_energy_j" => item.scalar_mhd_thermal_energy_j,
        "adjacent_relative_changes" => item.adjacent_relative_changes,
        "convergence_limit" => item.convergence_limit,
        "status" => String(item.status),
        "resolution_verified" => item.resolution_verified,
        "c2_scalar_mhd_energy_authorized" =>
            item.c2_scalar_mhd_energy_authorized,
        "complete_particle_state_authorized" =>
            item.complete_particle_state_authorized,
        "evidence_tasks" => item.evidence_tasks,
        "convergence_hash" => item.convergence_hash)
end

function scalar_pressure_energy_evidence_bundle_v1(genome::Genome,
        item::ScalarPressureEnergyConvergenceV1)
    genome.design_id == item.design_id || throw(ArgumentError(
        "pressure-energy design mismatch"))
    genome.physics_hash == item.genome_physics_hash || throw(ArgumentError(
        "pressure-energy Genome hash mismatch"))
    value = item.c2_scalar_mhd_energy_authorized ?
        last(item.scalar_mhd_thermal_energy_j) : nothing
    metric = MetricResult("scalar_mhd_thermal_energy_inventory", value;
        unit = "J", fidelity = 2,
        applicability = "Candidate-bound scalar isotropic MHD pressure volume integral with declared gamma; not a species or kinetic state.",
        status = item.status,
        constraints_checked = ["candidate binding", "pressure model",
            "coordinate Jacobian", "resolution convergence",
            "W_p=integral(p dV)/(gamma-1)"],
        solver_name = "scalar_pressure_energy_inventory_v1",
        solver_version = "1.0.0", input_hash = item.genome_physics_hash,
        run_hash = item.convergence_hash,
        source_basis = item.observation_hashes,
        warnings = item.evidence_tasks)
    claim = item.c2_scalar_mhd_energy_authorized ?
        "C2_support_scalar_mhd_thermal_energy_only" :
        "C2_scalar_mhd_thermal_energy_unknown_or_failed"
    return EvaluationBundle("scalar_pressure_energy_inventory_v1",
        item.design_id, genome.family, 2, item.status, [metric],
        copy(metric.warnings), item.genome_physics_hash,
        item.convergence_hash, claim)
end
