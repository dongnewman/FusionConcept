const _NEUTRAL_DEPOSITION_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured,
    :proxy, :manufactured))
const _NEUTRAL_DEPOSITION_STATUSES_V1 = Set((:pass, :fail, :unknown, :error))

"Mechanism-resolved neutral attenuation and fast-ion birth evidence."
struct NeutralTransportDepositionObservationV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    domain_id::String
    actuator_id::String
    injected_species_id::String
    ionization_rate_s::Float64
    main_ion_charge_exchange_conversion_rate_s::Float64
    fast_ion_birth_rate_s::Float64
    electron_source_rate_s::Float64
    net_same_species_ion_source_rate_s::Float64
    represented_fast_ion_birth_kinetic_power_w::Float64
    thermalized_heating_power_w::Union{Nothing,Float64}
    same_species_charge_exchange::Bool
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    resolution_verified::Bool
    beamline_geometry_candidate_verified::Bool
    spectrum_basis_candidate_verified::Bool
    plasma_profile_applicability_verified::Bool
    atomic_model_applicability_verified::Bool
    slowing_down_computed::Bool
    source_result_status::Symbol
    particle_source_c2_authorized::Bool
    heating_c2_authorized::Bool
    charge_exchange_particle_loss_mapping_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

function compile_neutral_transport_deposition_observation_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, actuator_id::AbstractString,
        injected_species_id::AbstractString, ionization_rate_s::Real,
        main_ion_charge_exchange_conversion_rate_s::Real,
        fast_ion_birth_rate_s::Real, electron_source_rate_s::Real,
        net_same_species_ion_source_rate_s::Real,
        represented_fast_ion_birth_kinetic_power_w::Real,
        thermalized_heating_power_w::Union{Nothing,Real} = nothing,
        same_species_charge_exchange::Bool = true,
        source_kind::Symbol = :proxy,
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString,
        source_result_hash::AbstractString,
        candidate_binding_verified::Bool = false,
        resolution_verified::Bool = false,
        beamline_geometry_candidate_verified::Bool = false,
        spectrum_basis_candidate_verified::Bool = false,
        plasma_profile_applicability_verified::Bool = false,
        atomic_model_applicability_verified::Bool = false,
        slowing_down_computed::Bool = false,
        source_result_status::Symbol = :unknown,
        identity_rtol::Real = 1.0e-10)
    rates = Float64[ionization_rate_s,
        main_ion_charge_exchange_conversion_rate_s, fast_ion_birth_rate_s,
        electron_source_rate_s, net_same_species_ion_source_rate_s,
        represented_fast_ion_birth_kinetic_power_w]
    all(isfinite, rates) && all(>=(0.0), rates) || throw(ArgumentError(
        "neutral-transport rates and represented power must be finite and non-negative"))
    heating = isnothing(thermalized_heating_power_w) ? nothing :
        Float64(thermalized_heating_power_w)
    !isnothing(heating) && (!isfinite(heating) || heating < 0.0) &&
        throw(ArgumentError("thermalized heating power must be finite and non-negative"))
    source_kind in _NEUTRAL_DEPOSITION_SOURCE_KINDS_V1 || throw(ArgumentError(
        "unsupported neutral-transport source kind"))
    source_result_status in _NEUTRAL_DEPOSITION_STATUSES_V1 || throw(ArgumentError(
        "unsupported neutral-transport result status"))
    length(genome_physics_hash) == 64 || throw(ArgumentError(
        "neutral-transport Genome hash must contain 64 hex characters"))
    length(source_artifact_hash) == 64 || throw(ArgumentError(
        "neutral-transport source artifact hash must contain 64 hex characters"))
    length(source_result_hash) == 64 || throw(ArgumentError(
        "neutral-transport result hash must contain 64 hex characters"))
    rtol = Float64(identity_rtol)
    isfinite(rtol) && rtol >= 0.0 || throw(ArgumentError(
        "neutral-transport identity tolerance must be finite and non-negative"))
    ionization = rates[1]
    cx = rates[2]
    birth = rates[3]
    electron = rates[4]
    net_ion = rates[5]
    identity_scale = max(birth, ionization, cx, 1.0e-30)
    abs(birth - ionization - cx) <= rtol * identity_scale || throw(ArgumentError(
        "fast-ion birth must equal ionization plus main-ion CX conversion"))
    abs(electron - ionization) <= rtol * max(electron, ionization, 1.0e-30) ||
        throw(ArgumentError("electron source must equal the ionization rate"))
    if same_species_charge_exchange
        abs(net_ion - ionization) <= rtol * max(net_ion, ionization, 1.0e-30) ||
            throw(ArgumentError(
                "same-species CX cannot be counted as a net plasma-ion source or loss"))
    end
    applicability = plasma_profile_applicability_verified &&
        atomic_model_applicability_verified &&
        beamline_geometry_candidate_verified &&
        spectrum_basis_candidate_verified
    particle_authority = source_result_status == :pass &&
        source_kind in (:candidate_solver, :measured) &&
        candidate_binding_verified && resolution_verified && applicability
    heating_authority = particle_authority && slowing_down_computed &&
        !isnothing(heating)
    cx_loss_authority = !same_species_charge_exchange && particle_authority
    tasks = String[]
    candidate_binding_verified || push!(tasks, "bind_neutral_transport_to_candidate")
    resolution_verified || push!(tasks, "verify_neutral_transport_resolution")
    beamline_geometry_candidate_verified || push!(tasks,
        "bind_beamline_geometry_to_executable_genome")
    spectrum_basis_candidate_verified || push!(tasks,
        "verify_energy_group_fraction_basis")
    plasma_profile_applicability_verified || push!(tasks,
        "replace_or_validate_plasma_profile")
    atomic_model_applicability_verified || push!(tasks,
        "validate_atomic_rate_model_applicability")
    slowing_down_computed || push!(tasks,
        "solve_fast_ion_slowing_down_and_thermalization")
    isnothing(heating) && push!(tasks, "compute_thermalized_heating_power")
    warnings = String[
        "Main-ion charge exchange converts a fast neutral and thermal ion into a fast ion and thermal neutral; for same-species exchange it is not a net plasma-particle loss.",
        "Represented fast-ion birth kinetic power is not thermalized plasma heating until slowing down, orbit loss, atomic energy, and radiation are closed.",
        "Numeric deposition under an unverified background state receives zero C2 authority."]
    core = Dict{String,Any}(
        "compiler_version" => "neutral_transport_deposition_compiler_v1.0.0",
        "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id), "actuator_id" => String(actuator_id),
        "injected_species_id" => String(injected_species_id),
        "ionization_rate_s" => ionization,
        "main_ion_charge_exchange_conversion_rate_s" => cx,
        "fast_ion_birth_rate_s" => birth,
        "electron_source_rate_s" => electron,
        "net_same_species_ion_source_rate_s" => net_ion,
        "represented_fast_ion_birth_kinetic_power_w" => rates[6],
        "thermalized_heating_power_w" => heating,
        "same_species_charge_exchange" => same_species_charge_exchange,
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified,
        "beamline_geometry_candidate_verified" =>
            beamline_geometry_candidate_verified,
        "spectrum_basis_candidate_verified" =>
            spectrum_basis_candidate_verified,
        "plasma_profile_applicability_verified" =>
            plasma_profile_applicability_verified,
        "atomic_model_applicability_verified" =>
            atomic_model_applicability_verified,
        "slowing_down_computed" => slowing_down_computed,
        "source_result_status" => String(source_result_status),
        "particle_source_c2_authorized" => particle_authority,
        "heating_c2_authorized" => heating_authority,
        "charge_exchange_particle_loss_mapping_authorized" => cx_loss_authority,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return NeutralTransportDepositionObservationV1(
        "neutral_transport_deposition_compiler_v1.0.0", String(design_id),
        String(genome_physics_hash), String(domain_id), String(actuator_id),
        String(injected_species_id), ionization, cx, birth, electron, net_ion,
        rates[6], heating, same_species_charge_exchange, source_kind,
        String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified,
        resolution_verified, beamline_geometry_candidate_verified,
        spectrum_basis_candidate_verified, plasma_profile_applicability_verified,
        atomic_model_applicability_verified, slowing_down_computed,
        source_result_status, particle_authority, heating_authority,
        cx_loss_authority, sort!(unique(tasks)), warnings, canonical_hash(core))
end

"Map only physically correct net sources into exact coupled-balance terms."
function neutral_transport_deposition_coupled_evidence_v1(
        balance::CoupledPlasmaBalanceProblemV1,
        observation::NeutralTransportDepositionObservationV1)
    observation.design_id == balance.design_id || throw(ArgumentError(
        "neutral-transport design mismatch"))
    observation.genome_physics_hash == balance.genome_physics_hash ||
        throw(ArgumentError("neutral-transport Genome hash mismatch"))
    evidence = CoupledPlasmaBalanceTermEvidenceV1[]
    source_kind = observation.particle_source_c2_authorized ?
        :candidate_solver : :proxy
    fidelity = observation.resolution_verified ? 2 : 1
    applicability = observation.plasma_profile_applicability_verified &&
        observation.atomic_model_applicability_verified &&
        observation.beamline_geometry_candidate_verified &&
        observation.spectrum_basis_candidate_verified
    status = observation.source_result_status == :fail ? :fail : :pass
    for (species, value) in ((observation.injected_species_id,
            observation.net_same_species_ion_source_rate_s),
            ("electron", observation.electron_source_rate_s))
        matches = filter(item -> item.domain_id == observation.domain_id &&
            item.species_id == species &&
            item.mechanism_class == :external_particle_source, balance.terms)
        isempty(matches) && continue
        term = only(matches)
        push!(evidence, compile_coupled_plasma_balance_term_evidence_v1(balance;
            term_id = term.term_id, value = value, unit = term.unit,
            source_kind = source_kind,
            source_artifact_id = observation.source_artifact_id,
            source_artifact_hash = observation.source_artifact_hash,
            source_result_hash = observation.observation_hash,
            candidate_binding_verified = observation.candidate_binding_verified,
            resolution_verified = observation.resolution_verified,
            applicability_verified = applicability, fidelity = fidelity,
            source_result_status = status))
    end
    if observation.heating_c2_authorized
        matches = filter(item -> item.domain_id == observation.domain_id &&
            item.mechanism_class == :external_heating_deposition, balance.terms)
        if !isempty(matches)
            term = only(matches)
            push!(evidence, compile_coupled_plasma_balance_term_evidence_v1(balance;
                term_id = term.term_id,
                value = something(observation.thermalized_heating_power_w),
                unit = term.unit, source_kind = :candidate_solver,
                source_artifact_id = observation.source_artifact_id,
                source_artifact_hash = observation.source_artifact_hash,
                source_result_hash = observation.observation_hash,
                candidate_binding_verified = true, resolution_verified = true,
                applicability_verified = true, fidelity = 2,
                source_result_status = :pass))
        end
    end
    return evidence
end

function neutral_transport_deposition_observation_to_dict_v1(observation)
    result = Dict{String,Any}(String(name) => getfield(observation, name)
        for name in fieldnames(typeof(observation)))
    result["source_kind"] = String(observation.source_kind)
    result["source_result_status"] = String(observation.source_result_status)
    return result
end
