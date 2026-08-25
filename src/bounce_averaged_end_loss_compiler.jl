"A device-label-independent dimensional open-boundary sink problem."
struct BounceAveragedEndLossProblemV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    species_id::String
    throat_to_throat_length_m::Float64
    throat_to_throat_length_verified::Bool
    bin_particle_inventories::Union{Nothing,Vector{Float64}}
    bin_parallel_speeds_m_s::Union{Nothing,Vector{Float64}}
    bin_boundary_kinetic_energies_j::Union{Nothing,Vector{Float64}}
    loss_boundary_mask::Union{Nothing,Vector{Bool}}
    distribution_physical_normalization_verified::Bool
    candidate_loss_boundary_verified::Bool
    ambipolar_profile_c2_authorized::Bool
    bounce_average_verified::Bool
    boundary_energy_verified::Bool
    source_sink_complete_verified::Bool
    candidate_binding_verified::Bool
    resolution_verified::Bool
    applicability_verified::Bool
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    source_ids::Vector{String}
    problem_hash::String
end

"SI particle and represented kinetic-energy loss from 2*abs(v_parallel)/L."
struct BounceAveragedEndLossObservationV1
    solver_version::String
    problem_hash::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    species_id::String
    loss_bin_count::Int
    represented_particle_inventory::Union{Nothing,Float64}
    parallel_particle_loss_rate_s::Union{Nothing,Float64}
    parallel_boundary_kinetic_power_w::Union{Nothing,Float64}
    inventory_depletion_time_s::Union{Nothing,Float64}
    status::Symbol
    c2_physical_end_loss_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

function _optional_end_loss_vector_v1(value, name)
    value === nothing && return nothing
    result = Float64.(value)
    !isempty(result) && all(isfinite, result) && all(>=(0.0), result) ||
        throw(ArgumentError("$name must contain non-negative finite values"))
    return result
end

function compile_bounce_averaged_end_loss_problem_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, species_id::AbstractString,
        throat_to_throat_length_m::Real,
        throat_to_throat_length_verified::Bool = false,
        bin_particle_inventories = nothing,
        bin_parallel_speeds_m_s = nothing,
        bin_boundary_kinetic_energies_j = nothing,
        loss_boundary_mask = nothing,
        distribution_physical_normalization_verified::Bool = false,
        candidate_loss_boundary_verified::Bool = false,
        ambipolar_profile_c2_authorized::Bool = false,
        bounce_average_verified::Bool = false,
        boundary_energy_verified::Bool = false,
        source_sink_complete_verified::Bool = false,
        candidate_binding_verified::Bool = false,
        resolution_verified::Bool = false,
        applicability_verified::Bool = false,
        source_kind::Symbol = :structural,
        source_artifact_id::AbstractString = "",
        source_artifact_hash::AbstractString = "",
        source_result_hash::AbstractString = "",
        source_ids::AbstractVector{<:AbstractString} = String[])
    length_m = Float64(throat_to_throat_length_m)
    isfinite(length_m) && length_m > 0.0 || throw(ArgumentError(
        "throat-to-throat length must be positive and finite"))
    source_kind in (:candidate_solver, :measured, :proxy, :manufactured,
        :structural) || throw(ArgumentError("unsupported end-loss source kind"))
    inventories = _optional_end_loss_vector_v1(bin_particle_inventories,
        "bin particle inventories")
    speeds = _optional_end_loss_vector_v1(bin_parallel_speeds_m_s,
        "bin parallel speeds")
    energies = _optional_end_loss_vector_v1(bin_boundary_kinetic_energies_j,
        "bin boundary kinetic energies")
    mask = loss_boundary_mask === nothing ? nothing : Bool.(loss_boundary_mask)
    supplied = (inventories !== nothing, speeds !== nothing, energies !== nothing,
        mask !== nothing)
    all(supplied) || !any(supplied) || throw(ArgumentError(
        "inventory, parallel speed, boundary energy, and loss mask must be supplied together"))
    if all(supplied)
        count = length(something(inventories))
        length(something(speeds)) == count && length(something(energies)) == count &&
            length(something(mask)) == count || throw(ArgumentError(
            "all end-loss bin arrays must have identical length"))
        any(something(mask)) || throw(ArgumentError(
            "at least one phase-space bin must lie in the loss boundary"))
    end
    sources = sort!(unique(String.(source_ids)))
    core = Dict{String,Any}(
        "compiler_version" => "bounce_averaged_end_loss_compiler_v1.0.0",
        "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id), "species_id" => String(species_id),
        "throat_to_throat_length_m" => length_m,
        "throat_to_throat_length_verified" => throat_to_throat_length_verified,
        "bin_particle_inventories" => inventories,
        "bin_parallel_speeds_m_s" => speeds,
        "bin_boundary_kinetic_energies_j" => energies,
        "loss_boundary_mask" => mask,
        "distribution_physical_normalization_verified" =>
            distribution_physical_normalization_verified,
        "candidate_loss_boundary_verified" => candidate_loss_boundary_verified,
        "ambipolar_profile_c2_authorized" => ambipolar_profile_c2_authorized,
        "bounce_average_verified" => bounce_average_verified,
        "boundary_energy_verified" => boundary_energy_verified,
        "source_sink_complete_verified" => source_sink_complete_verified,
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified,
        "applicability_verified" => applicability_verified,
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "source_ids" => sources)
    return BounceAveragedEndLossProblemV1(
        "bounce_averaged_end_loss_compiler_v1.0.0", String(design_id),
        String(genome_physics_hash), String(domain_id), String(species_id),
        length_m, throat_to_throat_length_verified, inventories, speeds, energies, mask,
        distribution_physical_normalization_verified,
        candidate_loss_boundary_verified, ambipolar_profile_c2_authorized,
        bounce_average_verified, boundary_energy_verified,
        source_sink_complete_verified, candidate_binding_verified,
        resolution_verified, applicability_verified, source_kind,
        String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), sources, canonical_hash(core))
end

function solve_bounce_averaged_end_loss_v1(
        problem::BounceAveragedEndLossProblemV1)
    tasks = String[]
    warnings = String[
        "The sink uses the published bounce-averaged form 2*abs(v_parallel)/L only on bins already classified as lost by the supplied candidate boundary.",
        "The represented kinetic-energy flux is not an end-plate heat load unless end-region fields, sheaths, radiation and material interception are also solved.",
        "End loss alone does not establish steady state, stability, gain, or feasibility."]
    inventories = problem.bin_particle_inventories
    if inventories === nothing
        append!(tasks, [
            "provide_physically_normalized_bounce_averaged_distribution_bins",
            "provide_candidate_magnetic_and_ambipolar_loss_boundary_mask",
            "provide_boundary_parallel_speed_and_energy_per_bin",
            "verify_candidate_throat_to_throat_length",
            "solve_candidate_ambipolar_potential_profile",
            "bounce_average_end_sink_on_candidate_equilibrium",
            "verify_boundary_energy_mapping",
            "include_candidate_sources_charge_exchange_and_radial_sinks",
            "bind_end_loss_distribution_to_candidate_genome",
            "verify_end_loss_phase_space_resolution",
            "verify_end_loss_operator_applicability"])
        core = Dict{String,Any}(
            "solver_version" => "bounce_averaged_end_loss_solver_v1.0.0",
            "problem_hash" => problem.problem_hash, "loss_bin_count" => 0,
            "represented_particle_inventory" => nothing,
            "parallel_particle_loss_rate_s" => nothing,
            "parallel_boundary_kinetic_power_w" => nothing,
            "inventory_depletion_time_s" => nothing, "status" => "unknown",
            "c2_physical_end_loss_authorized" => false,
            "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
        return BounceAveragedEndLossObservationV1(
            "bounce_averaged_end_loss_solver_v1.0.0", problem.problem_hash,
            problem.design_id, problem.genome_physics_hash, problem.domain_id,
            problem.species_id, 0, nothing, nothing, nothing, nothing,
            :unknown, false, sort!(unique(tasks)), warnings, canonical_hash(core))
    end
    particles = something(inventories)
    speeds = something(problem.bin_parallel_speeds_m_s)
    energies = something(problem.bin_boundary_kinetic_energies_j)
    mask = something(problem.loss_boundary_mask)
    frequencies = 2.0 .* speeds ./ problem.throat_to_throat_length_m
    rates = frequencies .* particles .* mask
    inventory = sum(particles)
    particle_loss = sum(rates)
    power = sum(rates .* energies)
    depletion = particle_loss > 0.0 ? inventory / particle_loss : nothing
    provenance = !isempty(problem.source_artifact_id) &&
        length(problem.source_artifact_hash) == 64 &&
        length(problem.source_result_hash) == 64 && !isempty(problem.source_ids)
    authority = provenance && problem.throat_to_throat_length_verified &&
        problem.distribution_physical_normalization_verified &&
        problem.candidate_loss_boundary_verified &&
        problem.ambipolar_profile_c2_authorized && problem.bounce_average_verified &&
        problem.boundary_energy_verified && problem.source_sink_complete_verified &&
        problem.candidate_binding_verified && problem.resolution_verified &&
        problem.applicability_verified &&
        problem.source_kind in (:candidate_solver, :measured)
    gates = [
        (problem.throat_to_throat_length_verified,
            "verify_candidate_throat_to_throat_length"),
        (problem.distribution_physical_normalization_verified,
            "normalize_distribution_to_candidate_particle_inventory"),
        (problem.candidate_loss_boundary_verified,
            "solve_candidate_magnetic_and_electrostatic_loss_boundary"),
        (problem.ambipolar_profile_c2_authorized,
            "solve_candidate_ambipolar_potential_profile"),
        (problem.bounce_average_verified,
            "bounce_average_end_sink_on_candidate_equilibrium"),
        (problem.boundary_energy_verified,
            "verify_boundary_energy_mapping"),
        (problem.source_sink_complete_verified,
            "include_candidate_sources_charge_exchange_and_radial_sinks"),
        (problem.candidate_binding_verified,
            "bind_end_loss_distribution_to_candidate_genome"),
        (problem.resolution_verified, "verify_end_loss_phase_space_resolution"),
        (problem.applicability_verified, "verify_end_loss_operator_applicability")]
    for (passed, task) in gates
        passed || push!(tasks, task)
    end
    core = Dict{String,Any}(
        "solver_version" => "bounce_averaged_end_loss_solver_v1.0.0",
        "problem_hash" => problem.problem_hash,
        "loss_bin_count" => count(mask),
        "represented_particle_inventory" => inventory,
        "parallel_particle_loss_rate_s" => particle_loss,
        "parallel_boundary_kinetic_power_w" => power,
        "inventory_depletion_time_s" => depletion, "status" => "pass",
        "c2_physical_end_loss_authorized" => authority,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return BounceAveragedEndLossObservationV1(
        "bounce_averaged_end_loss_solver_v1.0.0", problem.problem_hash,
        problem.design_id, problem.genome_physics_hash, problem.domain_id,
        problem.species_id, count(mask), inventory, particle_loss, power,
        depletion, :pass, authority, sort!(unique(tasks)), warnings,
        canonical_hash(core))
end

"Map one or more species sinks to exact particle terms and one total energy term."
function bounce_averaged_end_loss_coupled_evidence_v1(
        balance::CoupledPlasmaBalanceProblemV1,
        pairs::AbstractVector{<:Tuple}; source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString)
    isempty(pairs) && return CoupledPlasmaBalanceTermEvidenceV1[]
    result = CoupledPlasmaBalanceTermEvidenceV1[]
    domains = Set{String}()
    total_power = 0.0
    all_authorized = true
    result_hashes = String[]
    for pair in pairs
        length(pair) == 2 || throw(ArgumentError(
            "each end-loss pair must contain problem and observation"))
        problem, observation = pair
        problem isa BounceAveragedEndLossProblemV1 || throw(ArgumentError(
            "invalid end-loss problem in pair"))
        observation isa BounceAveragedEndLossObservationV1 || throw(ArgumentError(
            "invalid end-loss observation in pair"))
        problem.design_id == balance.design_id &&
            problem.genome_physics_hash == balance.genome_physics_hash ||
            throw(ArgumentError("end-loss candidate mismatch"))
        observation.problem_hash == problem.problem_hash || throw(ArgumentError(
            "end-loss observation mismatch"))
        observation.parallel_particle_loss_rate_s === nothing && continue
        push!(domains, problem.domain_id)
        all_authorized &= observation.c2_physical_end_loss_authorized
        push!(result_hashes, observation.observation_hash)
        total_power += something(observation.parallel_boundary_kinetic_power_w)
        match = only(filter(item -> item.domain_id == problem.domain_id &&
            item.species_id == problem.species_id &&
            item.mechanism_class == :parallel_particle_boundary_flux,
            balance.terms))
        push!(result, compile_coupled_plasma_balance_term_evidence_v1(balance;
            term_id = match.term_id,
            value = something(observation.parallel_particle_loss_rate_s),
            unit = match.unit,
            source_kind = observation.c2_physical_end_loss_authorized ?
                :candidate_solver : :proxy,
            source_artifact_id = source_artifact_id,
            source_artifact_hash = source_artifact_hash,
            source_result_hash = observation.observation_hash,
            candidate_binding_verified = problem.candidate_binding_verified,
            resolution_verified = problem.resolution_verified,
            applicability_verified = problem.applicability_verified,
            fidelity = observation.c2_physical_end_loss_authorized ? 2 : 1,
            source_result_status = :pass))
    end
    length(domains) <= 1 || throw(ArgumentError(
        "one energy mapping call cannot combine multiple domains"))
    isempty(domains) && return result
    domain = only(domains)
    energy = only(filter(item -> item.domain_id == domain &&
        item.mechanism_class == :parallel_energy_boundary_flux, balance.terms))
    aggregate_hash = canonical_hash(sort!(result_hashes))
    push!(result, compile_coupled_plasma_balance_term_evidence_v1(balance;
        term_id = energy.term_id, value = total_power, unit = energy.unit,
        source_kind = all_authorized ? :candidate_solver : :proxy,
        source_artifact_id = source_artifact_id,
        source_artifact_hash = source_artifact_hash,
        source_result_hash = aggregate_hash,
        candidate_binding_verified = all_authorized,
        resolution_verified = all_authorized,
        applicability_verified = all_authorized,
        fidelity = all_authorized ? 2 : 1, source_result_status = :pass))
    return result
end

bounce_averaged_end_loss_problem_to_dict_v1(problem) =
    Dict{String,Any}(String(name) => (name == :source_kind ?
        String(getfield(problem, name)) : getfield(problem, name))
        for name in fieldnames(typeof(problem)))

function bounce_averaged_end_loss_observation_to_dict_v1(observation)
    result = Dict{String,Any}(String(name) => getfield(observation, name)
        for name in fieldnames(typeof(observation)))
    result["status"] = String(observation.status)
    return result
end
