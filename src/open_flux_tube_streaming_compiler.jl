const _OPEN_STREAMING_DISTRIBUTIONS_V1 = Set((:maxwellian, :bi_maxwellian,
    :tabulated, :particle_ensemble, :unknown))

"One volume-averaged species state used by the full-loss-cone streaming ceiling."
struct OpenFluxTubeSpeciesStateV1
    species_id::String
    mass_kg::Float64
    density_m3::Float64
    temperature_j::Float64
    distribution_kind::Symbol
end

"Collisionless full-loss-cone streaming ceiling for one open flux-tube resolution."
struct OpenFluxTubeStreamingObservationV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    resolution_label::String
    resolution_rank::Int
    connection_length_m::Float64
    effective_volume_m3::Float64
    effective_midplane_area_m2::Float64
    mirror_ratio::Float64
    end_count::Int
    flux_weighted_loss_cone_transmission::Float64
    species_states::Vector{OpenFluxTubeSpeciesStateV1}
    species_particle_loss_rates_s::Dict{String,Float64}
    species_energy_loss_powers_w::Dict{String,Float64}
    total_particle_loss_rate_s::Union{Nothing,Float64}
    total_energy_loss_power_w::Union{Nothing,Float64}
    geometry_candidate_binding_verified::Bool
    state_candidate_binding_verified::Bool
    full_loss_cone_boundary_condition_verified::Bool
    status::Symbol
    physical_rate_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

"Resolution audit for a streaming ceiling; convergence never upgrades it to C2."
struct OpenFluxTubeStreamingConvergenceV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    observation_hashes::Vector{String}
    total_particle_loss_rates_s::Vector{Union{Nothing,Float64}}
    total_energy_loss_powers_w::Vector{Union{Nothing,Float64}}
    particle_adjacent_relative_changes::Vector{Float64}
    energy_adjacent_relative_changes::Vector{Float64}
    convergence_limit::Float64
    status::Symbol
    c2_boundary_flux_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    convergence_hash::String
end

function compile_open_flux_tube_species_state_v1(; species_id::AbstractString,
        mass_kg::Real, density_m3::Real, temperature_j::Real,
        distribution_kind::Symbol = :maxwellian)
    mass = Float64(mass_kg)
    density = Float64(density_m3)
    temperature = Float64(temperature_j)
    all(isfinite, (mass, density, temperature)) || throw(ArgumentError(
        "open-flux state values must be finite"))
    mass > 0.0 && density >= 0.0 && temperature > 0.0 || throw(ArgumentError(
        "mass and temperature must be positive and density non-negative"))
    distribution_kind in _OPEN_STREAMING_DISTRIBUTIONS_V1 ||
        throw(ArgumentError("unsupported open-flux distribution declaration"))
    return OpenFluxTubeSpeciesStateV1(String(species_id), mass, density,
        temperature, distribution_kind)
end

function _open_streaming_observation_core_v1(; design_id, genome_physics_hash,
        domain_id, resolution_label, resolution_rank, connection_length_m,
        effective_volume_m3, mirror_ratio, end_count, states,
        geometry_candidate_binding_verified, state_candidate_binding_verified,
        full_loss_cone_boundary_condition_verified, status, rates, powers,
        total_rate, total_power, tasks, warnings)
    return Dict{String,Any}(
        "compiler_version" => "open_flux_tube_streaming_compiler_v1.0.0",
        "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id),
        "resolution_label" => String(resolution_label),
        "resolution_rank" => Int(resolution_rank),
        "connection_length_m" => connection_length_m,
        "effective_volume_m3" => effective_volume_m3,
        "effective_midplane_area_m2" => effective_volume_m3 / connection_length_m,
        "mirror_ratio" => mirror_ratio, "end_count" => Int(end_count),
        "flux_weighted_loss_cone_transmission" => 1.0 / mirror_ratio,
        "species_states" => open_flux_tube_species_state_to_dict_v1.(states),
        "species_particle_loss_rates_s" => rates,
        "species_energy_loss_powers_w" => powers,
        "total_particle_loss_rate_s" => total_rate,
        "total_energy_loss_power_w" => total_power,
        "geometry_candidate_binding_verified" =>
            geometry_candidate_binding_verified,
        "state_candidate_binding_verified" => state_candidate_binding_verified,
        "full_loss_cone_boundary_condition_verified" =>
            full_loss_cone_boundary_condition_verified,
        "status" => String(status), "physical_rate_authorized" => false,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
end

"Compute a two-ended or multi-ended full-loss-cone Maxwellian streaming ceiling."
function compile_open_flux_tube_streaming_observation_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, resolution_label::AbstractString,
        resolution_rank::Integer, connection_length_m::Real,
        effective_volume_m3::Real, mirror_ratio::Real,
        species_states::AbstractVector{OpenFluxTubeSpeciesStateV1},
        end_count::Integer = 2,
        geometry_candidate_binding_verified::Bool = false,
        state_candidate_binding_verified::Bool = false,
        full_loss_cone_boundary_condition_verified::Bool = false)
    length_value = Float64(connection_length_m)
    volume = Float64(effective_volume_m3)
    ratio = Float64(mirror_ratio)
    rank = Int(resolution_rank)
    ends = Int(end_count)
    all(isfinite, (length_value, volume, ratio)) || throw(ArgumentError(
        "open-flux geometry values must be finite"))
    length_value > 0.0 && volume > 0.0 && ratio >= 1.0 && rank >= 1 && ends >= 1 ||
        throw(ArgumentError("invalid open-flux geometry or resolution"))
    isempty(species_states) && throw(ArgumentError(
        "at least one species state is required"))
    ids = getfield.(species_states, :species_id)
    length(unique(ids)) == length(ids) || throw(ArgumentError(
        "duplicate species in open-flux state"))
    tasks = String[]
    warnings = String[
        "This is a full-loss-cone collisionless Maxwellian streaming ceiling, not a collisional or ambipolar steady-state end-loss solution.",
        "The effective midplane area is volume divided by connection length; field-varying flux-tube area and off-axis distributions remain unresolved.",
        "Convergence of this ceiling cannot authorize a physical boundary flux or C2 evidence."]
    unsupported = [item.species_id for item in species_states if
        item.distribution_kind != :maxwellian]
    if !isempty(unsupported)
        append!(tasks, ["solve_velocity_space_open_boundary_flux:$id"
            for id in unsupported])
        core = _open_streaming_observation_core_v1(
            design_id = design_id, genome_physics_hash = genome_physics_hash,
            domain_id = domain_id, resolution_label = resolution_label,
            resolution_rank = rank, connection_length_m = length_value,
            effective_volume_m3 = volume, mirror_ratio = ratio,
            end_count = ends, states = collect(species_states),
            geometry_candidate_binding_verified =
                geometry_candidate_binding_verified,
            state_candidate_binding_verified = state_candidate_binding_verified,
            full_loss_cone_boundary_condition_verified =
                full_loss_cone_boundary_condition_verified,
            status = :unknown, rates = Dict{String,Float64}(),
            powers = Dict{String,Float64}(), total_rate = nothing,
            total_power = nothing, tasks = tasks, warnings = warnings)
        return OpenFluxTubeStreamingObservationV1(
            "open_flux_tube_streaming_compiler_v1.0.0", String(design_id),
            String(genome_physics_hash), String(domain_id),
            String(resolution_label), rank, length_value, volume,
            volume / length_value, ratio, ends, 1.0 / ratio,
            collect(species_states), Dict{String,Float64}(),
            Dict{String,Float64}(), nothing, nothing,
            geometry_candidate_binding_verified,
            state_candidate_binding_verified,
            full_loss_cone_boundary_condition_verified, :unknown, false,
            sort!(unique(tasks)), warnings, canonical_hash(core))
    end
    area = volume / length_value
    transmission = 1.0 / ratio
    rates = Dict{String,Float64}()
    powers = Dict{String,Float64}()
    for state in species_states
        one_way_flux_m2_s = state.density_m3 * sqrt(
            state.temperature_j / (2.0 * pi * state.mass_kg))
        rate = ends * area * one_way_flux_m2_s * transmission
        rates[state.species_id] = rate
        # Effusing Maxwellian particles carry mean kinetic energy 2T.
        powers[state.species_id] = 2.0 * state.temperature_j * rate
    end
    geometry_candidate_binding_verified || push!(tasks,
        "bind_open_flux_geometry_to_candidate")
    state_candidate_binding_verified || push!(tasks,
        "replace_assumed_state_with_candidate_state")
    full_loss_cone_boundary_condition_verified || push!(tasks,
        "solve_loss_cone_refill_ambipolar_and_boundary_condition")
    total_rate = sum(values(rates))
    total_power = sum(values(powers))
    core = _open_streaming_observation_core_v1(
        design_id = design_id, genome_physics_hash = genome_physics_hash,
        domain_id = domain_id, resolution_label = resolution_label,
        resolution_rank = rank, connection_length_m = length_value,
        effective_volume_m3 = volume, mirror_ratio = ratio,
        end_count = ends, states = collect(species_states),
        geometry_candidate_binding_verified = geometry_candidate_binding_verified,
        state_candidate_binding_verified = state_candidate_binding_verified,
        full_loss_cone_boundary_condition_verified =
            full_loss_cone_boundary_condition_verified,
        status = :pass, rates = rates, powers = powers,
        total_rate = total_rate, total_power = total_power,
        tasks = tasks, warnings = warnings)
    return OpenFluxTubeStreamingObservationV1(
        "open_flux_tube_streaming_compiler_v1.0.0", String(design_id),
        String(genome_physics_hash), String(domain_id), String(resolution_label),
        rank, length_value, volume, area, ratio, ends, transmission,
        collect(species_states), rates, powers, total_rate, total_power,
        geometry_candidate_binding_verified, state_candidate_binding_verified,
        full_loss_cone_boundary_condition_verified, :pass, false,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

function _open_streaming_relative_changes_v1(values)
    result = Float64[]
    for index in 2:length(values)
        previous = values[index - 1]
        current = values[index]
        previous === nothing || current === nothing || push!(result,
            abs(current - previous) / max(abs(current), abs(previous), 1.0e-30))
    end
    return result
end

function compile_open_flux_tube_streaming_convergence_v1(
        observations::AbstractVector{OpenFluxTubeStreamingObservationV1};
        convergence_limit::Real = 0.02)
    length(observations) >= 2 || throw(ArgumentError(
        "at least two streaming observations are required"))
    limit = Float64(convergence_limit)
    isfinite(limit) && limit >= 0.0 || throw(ArgumentError(
        "streaming convergence limit must be finite and non-negative"))
    ordered = sort!(collect(observations); by = item -> item.resolution_rank)
    first_item = first(ordered)
    all(item -> item.design_id == first_item.design_id &&
        item.genome_physics_hash == first_item.genome_physics_hash &&
        item.domain_id == first_item.domain_id, ordered) || throw(ArgumentError(
        "streaming observations must share candidate and domain"))
    length(unique(getfield.(ordered, :resolution_rank))) == length(ordered) ||
        throw(ArgumentError("duplicate streaming resolution rank"))
    particle_values = getfield.(ordered, :total_particle_loss_rate_s)
    energy_values = getfield.(ordered, :total_energy_loss_power_w)
    particle_changes = _open_streaming_relative_changes_v1(particle_values)
    energy_changes = _open_streaming_relative_changes_v1(energy_values)
    numeric = all(item -> item.status == :pass, ordered) &&
        length(particle_changes) == length(ordered) - 1 &&
        length(energy_changes) == length(ordered) - 1
    converged = numeric && all(value -> value <= limit,
        vcat(particle_changes, energy_changes))
    status = converged ? :pass : numeric ? :fail : :unknown
    tasks = String[]
    status == :fail && push!(tasks, "refine_open_flux_streaming_resolution")
    status == :unknown && push!(tasks, "supply_numeric_open_flux_streaming_observations")
    append!(tasks, [task for item in ordered for task in item.evidence_tasks])
    warnings = String[
        "Numerical convergence supports only the declared streaming ceiling; physical steady-state flux remains unauthorized."]
    core = Dict{String,Any}(
        "design_id" => first_item.design_id,
        "genome_physics_hash" => first_item.genome_physics_hash,
        "domain_id" => first_item.domain_id,
        "observation_hashes" => getfield.(ordered, :observation_hash),
        "total_particle_loss_rates_s" => particle_values,
        "total_energy_loss_powers_w" => energy_values,
        "particle_adjacent_relative_changes" => particle_changes,
        "energy_adjacent_relative_changes" => energy_changes,
        "convergence_limit" => limit, "status" => String(status),
        "c2_boundary_flux_authorized" => false,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return OpenFluxTubeStreamingConvergenceV1(first_item.design_id,
        first_item.genome_physics_hash, first_item.domain_id,
        getfield.(ordered, :observation_hash), particle_values, energy_values,
        particle_changes, energy_changes, limit, status, false,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

"Map a converged ceiling into exact coupled-balance term IDs with proxy-only authority."
function open_flux_tube_streaming_coupled_evidence_v1(
        problem::CoupledPlasmaBalanceProblemV1,
        observations::AbstractVector{OpenFluxTubeStreamingObservationV1},
        convergence::OpenFluxTubeStreamingConvergenceV1;
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString)
    convergence.design_id == problem.design_id || throw(ArgumentError(
        "streaming convergence design mismatch"))
    convergence.genome_physics_hash == problem.genome_physics_hash ||
        throw(ArgumentError("streaming convergence Genome hash mismatch"))
    convergence.status == :pass || return CoupledPlasmaBalanceTermEvidenceV1[]
    finest = last(sort!(collect(observations); by = item -> item.resolution_rank))
    finest.observation_hash in convergence.observation_hashes || throw(ArgumentError(
        "finest streaming observation is not in convergence audit"))
    result = CoupledPlasmaBalanceTermEvidenceV1[]
    for (species_id, rate) in finest.species_particle_loss_rates_s
        matches = filter(item -> item.domain_id == finest.domain_id &&
            item.species_id == species_id &&
            item.mechanism_class == :parallel_particle_boundary_flux,
            problem.terms)
        isempty(matches) && continue
        term = only(matches)
        push!(result, compile_coupled_plasma_balance_term_evidence_v1(problem;
            term_id = term.term_id, value = rate, unit = term.unit,
            source_kind = :proxy, source_artifact_id = source_artifact_id,
            source_artifact_hash = source_artifact_hash,
            source_result_hash = convergence.convergence_hash,
            candidate_binding_verified = finest.geometry_candidate_binding_verified,
            resolution_verified = true, applicability_verified = false,
            fidelity = 1, source_result_status = :pass))
    end
    energy_matches = filter(item -> item.domain_id == finest.domain_id &&
        item.mechanism_class == :parallel_energy_boundary_flux, problem.terms)
    if !isempty(energy_matches) && finest.total_energy_loss_power_w !== nothing
        term = only(energy_matches)
        push!(result, compile_coupled_plasma_balance_term_evidence_v1(problem;
            term_id = term.term_id,
            value = something(finest.total_energy_loss_power_w), unit = term.unit,
            source_kind = :proxy, source_artifact_id = source_artifact_id,
            source_artifact_hash = source_artifact_hash,
            source_result_hash = convergence.convergence_hash,
            candidate_binding_verified = finest.geometry_candidate_binding_verified,
            resolution_verified = true, applicability_verified = false,
            fidelity = 1, source_result_status = :pass))
    end
    return result
end

open_flux_tube_species_state_to_dict_v1(item::OpenFluxTubeSpeciesStateV1) =
    Dict{String,Any}("species_id" => item.species_id,
        "mass_kg" => item.mass_kg, "density_m3" => item.density_m3,
        "temperature_j" => item.temperature_j,
        "distribution_kind" => String(item.distribution_kind))

function open_flux_tube_streaming_observation_to_dict_v1(
        item::OpenFluxTubeStreamingObservationV1)
    return Dict{String,Any}(
        "compiler_version" => item.compiler_version,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id,
        "resolution_label" => item.resolution_label,
        "resolution_rank" => item.resolution_rank,
        "connection_length_m" => item.connection_length_m,
        "effective_volume_m3" => item.effective_volume_m3,
        "effective_midplane_area_m2" => item.effective_midplane_area_m2,
        "mirror_ratio" => item.mirror_ratio, "end_count" => item.end_count,
        "flux_weighted_loss_cone_transmission" =>
            item.flux_weighted_loss_cone_transmission,
        "species_states" => open_flux_tube_species_state_to_dict_v1.(item.species_states),
        "species_particle_loss_rates_s" => item.species_particle_loss_rates_s,
        "species_energy_loss_powers_w" => item.species_energy_loss_powers_w,
        "total_particle_loss_rate_s" => item.total_particle_loss_rate_s,
        "total_energy_loss_power_w" => item.total_energy_loss_power_w,
        "geometry_candidate_binding_verified" =>
            item.geometry_candidate_binding_verified,
        "state_candidate_binding_verified" => item.state_candidate_binding_verified,
        "full_loss_cone_boundary_condition_verified" =>
            item.full_loss_cone_boundary_condition_verified,
        "status" => String(item.status),
        "physical_rate_authorized" => item.physical_rate_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "observation_hash" => item.observation_hash)
end

function open_flux_tube_streaming_convergence_to_dict_v1(
        item::OpenFluxTubeStreamingConvergenceV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id,
        "observation_hashes" => item.observation_hashes,
        "total_particle_loss_rates_s" => item.total_particle_loss_rates_s,
        "total_energy_loss_powers_w" => item.total_energy_loss_powers_w,
        "particle_adjacent_relative_changes" =>
            item.particle_adjacent_relative_changes,
        "energy_adjacent_relative_changes" => item.energy_adjacent_relative_changes,
        "convergence_limit" => item.convergence_limit,
        "status" => String(item.status),
        "c2_boundary_flux_authorized" => item.c2_boundary_flux_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "convergence_hash" => item.convergence_hash)
end
