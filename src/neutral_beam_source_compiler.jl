const _NBI_ELEMENTARY_CHARGE_V1 = 1.602176634e-19

"A device-label-independent neutral-beam particle-source contract."
struct NeutralBeamSourceProblemV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    actuator_id::String
    injected_species_id::String
    charge_state::Int
    declared_beam_power_w::Float64
    primary_particle_energy_j::Float64
    declared_equivalent_current_a::Union{Nothing,Float64}
    injection_pitch_angle_rad::Float64
    absorption_fraction::Union{Nothing,Float64}
    ionization_branch_fraction::Union{Nothing,Float64}
    actuator_candidate_binding_verified::Bool
    spectrum_interpretation_verified::Bool
    deposition_model_applicability_verified::Bool
    source_kind::Symbol
    source_ids::Vector{String}
    problem_hash::String
end

"Incident ceiling and, only when deposition inputs exist, absorbed/fuel source rates."
struct NeutralBeamSourceObservationV1
    compiler_version::String
    problem_hash::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    actuator_id::String
    injected_species_id::String
    power_limited_incident_particle_rate_s::Float64
    current_limited_incident_particle_rate_s::Union{Nothing,Float64}
    incident_rate_relative_mismatch::Union{Nothing,Float64}
    incident_particle_rate_ceiling_s::Float64
    absorbed_particle_rate_s::Union{Nothing,Float64}
    fueled_particle_source_rate_s::Union{Nothing,Float64}
    charge_exchange_or_nonfuel_rate_s::Union{Nothing,Float64}
    absorbed_beam_power_w::Union{Nothing,Float64}
    fueled_beam_power_w::Union{Nothing,Float64}
    status::Symbol
    physical_source_rate_authorized::Bool
    c2_source_term_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

function compile_neutral_beam_source_problem_v1(; design_id::AbstractString,
        genome_physics_hash::AbstractString, domain_id::AbstractString,
        actuator_id::AbstractString, injected_species_id::AbstractString,
        charge_state::Integer = 1, declared_beam_power_w::Real,
        primary_particle_energy_j::Real,
        declared_equivalent_current_a::Union{Nothing,Real} = nothing,
        injection_pitch_angle_rad::Real,
        absorption_fraction::Union{Nothing,Real} = nothing,
        ionization_branch_fraction::Union{Nothing,Real} = nothing,
        actuator_candidate_binding_verified::Bool = false,
        spectrum_interpretation_verified::Bool = false,
        deposition_model_applicability_verified::Bool = false,
        source_kind::Symbol = :design_assumption,
        source_ids::AbstractVector{<:AbstractString} = String[])
    power = Float64(declared_beam_power_w)
    energy = Float64(primary_particle_energy_j)
    pitch = Float64(injection_pitch_angle_rad)
    current = isnothing(declared_equivalent_current_a) ? nothing :
        Float64(declared_equivalent_current_a)
    absorption = isnothing(absorption_fraction) ? nothing :
        Float64(absorption_fraction)
    ionization = isnothing(ionization_branch_fraction) ? nothing :
        Float64(ionization_branch_fraction)
    all(isfinite, [power, energy, pitch]) || throw(ArgumentError(
        "neutral-beam power, energy, and pitch must be finite"))
    power > 0.0 && energy > 0.0 || throw(ArgumentError(
        "neutral-beam power and primary energy must be positive"))
    charge_state >= 1 || throw(ArgumentError("charge state must be positive"))
    0.0 <= pitch <= pi / 2.0 || throw(ArgumentError(
        "injection pitch must lie between zero and pi/2"))
    !isnothing(current) && (!isfinite(current) || current <= 0.0) &&
        throw(ArgumentError("equivalent beam current must be positive"))
    for (name, value) in (("absorption", absorption), ("ionization", ionization))
        !isnothing(value) && (!isfinite(value) || value < 0.0 || value > 1.0) &&
            throw(ArgumentError("$name fraction must lie in [0,1]"))
    end
    source_kind in (:published_design, :measured, :simulation,
        :design_assumption, :manufactured) || throw(ArgumentError(
        "unsupported neutral-beam source kind"))
    sources = sort!(unique(String.(source_ids)))
    core = Dict{String,Any}(
        "compiler_version" => "neutral_beam_source_compiler_v1.0.0",
        "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id), "actuator_id" => String(actuator_id),
        "injected_species_id" => String(injected_species_id),
        "charge_state" => Int(charge_state),
        "declared_beam_power_w" => power,
        "primary_particle_energy_j" => energy,
        "declared_equivalent_current_a" => current,
        "injection_pitch_angle_rad" => pitch,
        "absorption_fraction" => absorption,
        "ionization_branch_fraction" => ionization,
        "actuator_candidate_binding_verified" =>
            actuator_candidate_binding_verified,
        "spectrum_interpretation_verified" => spectrum_interpretation_verified,
        "deposition_model_applicability_verified" =>
            deposition_model_applicability_verified,
        "source_kind" => String(source_kind), "source_ids" => sources)
    return NeutralBeamSourceProblemV1(
        "neutral_beam_source_compiler_v1.0.0", String(design_id),
        String(genome_physics_hash), String(domain_id), String(actuator_id),
        String(injected_species_id), Int(charge_state), power, energy, current,
        pitch, absorption, ionization, actuator_candidate_binding_verified,
        spectrum_interpretation_verified, deposition_model_applicability_verified,
        source_kind, sources, canonical_hash(core))
end

function evaluate_neutral_beam_source_v1(problem::NeutralBeamSourceProblemV1;
        incident_consistency_limit::Real = 0.05)
    limit = Float64(incident_consistency_limit)
    isfinite(limit) && limit >= 0.0 || throw(ArgumentError(
        "incident consistency limit must be finite and non-negative"))
    power_rate = problem.declared_beam_power_w /
        problem.primary_particle_energy_j
    current_rate = isnothing(problem.declared_equivalent_current_a) ? nothing :
        problem.declared_equivalent_current_a /
            (problem.charge_state * _NBI_ELEMENTARY_CHARGE_V1)
    mismatch = isnothing(current_rate) ? nothing : abs(power_rate - current_rate) /
        max(power_rate, current_rate, 1.0e-30)
    incident_ceiling = isnothing(current_rate) ? power_rate :
        min(power_rate, current_rate)
    absorbed = isnothing(problem.absorption_fraction) ? nothing :
        incident_ceiling * problem.absorption_fraction
    fueled = isnothing(absorbed) || isnothing(problem.ionization_branch_fraction) ?
        nothing : absorbed * problem.ionization_branch_fraction
    nonfuel = isnothing(absorbed) || isnothing(fueled) ? nothing : absorbed - fueled
    absorbed_power = isnothing(problem.absorption_fraction) ? nothing :
        problem.declared_beam_power_w * problem.absorption_fraction
    fueled_power = isnothing(absorbed_power) ||
        isnothing(problem.ionization_branch_fraction) ? nothing :
        absorbed_power * problem.ionization_branch_fraction
    consistency_pass = isnothing(mismatch) || mismatch <= limit
    inputs_complete = !isnothing(absorbed) && !isnothing(fueled)
    source_authority = inputs_complete && consistency_pass &&
        problem.actuator_candidate_binding_verified &&
        problem.spectrum_interpretation_verified &&
        problem.deposition_model_applicability_verified &&
        problem.source_kind in (:published_design, :measured, :simulation) &&
        !isempty(problem.source_ids)
    status = source_authority ? :pass : consistency_pass ? :unknown : :fail
    tasks = String[]
    isnothing(problem.declared_equivalent_current_a) && push!(tasks,
        "supply_equivalent_beam_current")
    !consistency_pass && push!(tasks, "resolve_beam_power_current_inconsistency")
    isnothing(problem.absorption_fraction) && push!(tasks,
        "solve_candidate_beam_absorption")
    isnothing(problem.ionization_branch_fraction) && push!(tasks,
        "solve_ionization_charge_exchange_branching")
    problem.actuator_candidate_binding_verified || push!(tasks,
        "bind_neutral_beam_actuator_to_candidate_genome")
    problem.spectrum_interpretation_verified || push!(tasks,
        "resolve_primary_half_third_energy_component_basis")
    problem.deposition_model_applicability_verified || push!(tasks,
        "validate_deposition_model_at_candidate_state")
    warnings = String[
        "Power divided by primary particle energy and current divided by charge are incident particle-rate ceilings, not absorbed fuel sources.",
        "A physical source requires candidate-specific absorption, ionization versus charge-exchange branching, and a velocity-space deposition spectrum.",
        "This source compiler does not establish a steady plasma state, kinetic confinement, heating balance, fusion gain, or feasibility."]
    core = Dict{String,Any}(
        "compiler_version" => "neutral_beam_source_compiler_v1.0.0",
        "problem_hash" => problem.problem_hash,
        "power_limited_incident_particle_rate_s" => power_rate,
        "current_limited_incident_particle_rate_s" => current_rate,
        "incident_rate_relative_mismatch" => mismatch,
        "incident_particle_rate_ceiling_s" => incident_ceiling,
        "absorbed_particle_rate_s" => absorbed,
        "fueled_particle_source_rate_s" => fueled,
        "charge_exchange_or_nonfuel_rate_s" => nonfuel,
        "absorbed_beam_power_w" => absorbed_power,
        "fueled_beam_power_w" => fueled_power,
        "status" => String(status),
        "physical_source_rate_authorized" => source_authority,
        "c2_source_term_authorized" => source_authority,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return NeutralBeamSourceObservationV1(
        "neutral_beam_source_compiler_v1.0.0", problem.problem_hash,
        problem.design_id, problem.genome_physics_hash, problem.domain_id,
        problem.actuator_id, problem.injected_species_id, power_rate,
        current_rate, mismatch, incident_ceiling, absorbed, fueled, nonfuel,
        absorbed_power, fueled_power, status, source_authority, source_authority,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

"Map ionization-created ion/electron sources to exact coupled-balance terms."
function neutral_beam_source_coupled_evidence_v1(
        balance::CoupledPlasmaBalanceProblemV1,
        problem::NeutralBeamSourceProblemV1,
        observation::NeutralBeamSourceObservationV1;
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString)
    problem.design_id == balance.design_id || throw(ArgumentError(
        "neutral-beam source design mismatch"))
    problem.genome_physics_hash == balance.genome_physics_hash ||
        throw(ArgumentError("neutral-beam source Genome hash mismatch"))
    observation.problem_hash == problem.problem_hash || throw(ArgumentError(
        "neutral-beam source observation problem mismatch"))
    observation.fueled_particle_source_rate_s === nothing &&
        return CoupledPlasmaBalanceTermEvidenceV1[]
    source_kind = observation.c2_source_term_authorized ? :candidate_solver : :proxy
    fidelity = observation.c2_source_term_authorized ? 2 : 1
    status = observation.status == :fail ? :fail : :pass
    result = CoupledPlasmaBalanceTermEvidenceV1[]
    for species in (problem.injected_species_id, "electron")
        matches = filter(item -> item.domain_id == problem.domain_id &&
            item.species_id == species &&
            item.mechanism_class == :external_particle_source, balance.terms)
        isempty(matches) && continue
        term = only(matches)
        push!(result, compile_coupled_plasma_balance_term_evidence_v1(balance;
            term_id = term.term_id,
            value = something(observation.fueled_particle_source_rate_s),
            unit = term.unit, source_kind = source_kind,
            source_artifact_id = source_artifact_id,
            source_artifact_hash = source_artifact_hash,
            source_result_hash = observation.observation_hash,
            candidate_binding_verified =
                problem.actuator_candidate_binding_verified,
            resolution_verified =
                problem.deposition_model_applicability_verified,
            applicability_verified =
                problem.deposition_model_applicability_verified,
            fidelity = fidelity, source_result_status = status))
    end
    return result
end

function neutral_beam_source_problem_to_dict_v1(problem)
    result = Dict{String,Any}(String(name) => getfield(problem, name)
        for name in fieldnames(typeof(problem)))
    result["source_kind"] = String(problem.source_kind)
    return result
end

function neutral_beam_source_observation_to_dict_v1(observation)
    result = Dict{String,Any}(String(name) => getfield(observation, name)
        for name in fieldnames(typeof(observation)))
    result["status"] = String(observation.status)
    return result
end
