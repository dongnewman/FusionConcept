const _DIRECTED_DEPOSITION_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured,
    :proxy, :manufactured))
const _DIRECTED_DEPOSITION_STATUSES_V1 = Set((:pass, :fail, :unknown, :error))

"One physically normalized spatial/velocity source bin in the candidate magnetic frame."
struct DirectedParticleDepositionBinV1
    energy_group_index::Int
    radial_index::Int
    axial_index::Int
    toroidal_index::Int
    position_m::NTuple{3,Float64}
    magnetic_field_t::NTuple{3,Float64}
    magnetic_field_magnitude_t::Float64
    velocity_m_s::NTuple{3,Float64}
    speed_m_s::Float64
    parallel_speed_m_s::Float64
    perpendicular_speed_m_s::Float64
    signed_pitch_cosine::Float64
    pitch_angle_rad::Float64
    kinetic_energy_j::Float64
    cell_volume_m3::Float64
    ionization_fast_ion_birth_rate_s::Float64
    charge_exchange_fast_ion_birth_rate_s::Float64
    total_fast_ion_birth_rate_s::Float64
    electron_birth_rate_s::Float64
    net_same_species_ion_birth_rate_s::Float64
    thermal_same_species_ion_removal_rate_s::Float64
end

"Candidate-bound source tensor; this is a source operator input, not a solved distribution."
struct DirectedParticleDepositionSourceObservationV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    executable_candidate_physics_hash::String
    domain_id::String
    actuator_id::String
    injected_species_id::String
    bin_count::Int
    bins::Vector{DirectedParticleDepositionBinV1}
    ionization_rate_s::Float64
    charge_exchange_conversion_rate_s::Float64
    fast_ion_birth_rate_s::Float64
    electron_birth_rate_s::Float64
    net_same_species_ion_birth_rate_s::Float64
    thermal_same_species_ion_removal_rate_s::Float64
    represented_fast_ion_birth_kinetic_power_w::Float64
    maximum_rate_identity_relative_residual::Float64
    maximum_energy_identity_relative_residual::Float64
    maximum_external_aggregate_relative_residual::Union{Nothing,Float64}
    external_aggregate_audit_verified::Bool
    candidate_phase_space_binding_verified::Bool
    physical_source_rate_available::Bool
    c2_phase_space_source_authorized::Bool
    c2_kinetic_state_authorized::Bool
    source_kind::Symbol
    source_result_status::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    field_artifact_id::String
    field_artifact_hash::String
    field_result_hash::String
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

function _directed_deposition_vector3_v1(value, name::String)
    vector = Float64.(collect(value))
    length(vector) == 3 && all(isfinite, vector) || throw(ArgumentError(
        "$name must contain three finite values"))
    return (vector[1], vector[2], vector[3])
end

function _directed_deposition_hash_v1(value, name::String)
    text = String(value)
    length(text) == 64 && all(isxdigit, text) || throw(ArgumentError(
        "$name must contain 64 hexadecimal characters"))
    return lowercase(text)
end

function directed_particle_deposition_bin_to_dict_v1(bin)
    return Dict{String,Any}(
        "energy_group_index" => bin.energy_group_index,
        "radial_index" => bin.radial_index,
        "axial_index" => bin.axial_index,
        "toroidal_index" => bin.toroidal_index,
        "position_m" => collect(bin.position_m),
        "magnetic_field_t" => collect(bin.magnetic_field_t),
        "magnetic_field_magnitude_t" => bin.magnetic_field_magnitude_t,
        "velocity_m_s" => collect(bin.velocity_m_s),
        "speed_m_s" => bin.speed_m_s,
        "parallel_speed_m_s" => bin.parallel_speed_m_s,
        "perpendicular_speed_m_s" => bin.perpendicular_speed_m_s,
        "signed_pitch_cosine" => bin.signed_pitch_cosine,
        "pitch_angle_rad" => bin.pitch_angle_rad,
        "kinetic_energy_j" => bin.kinetic_energy_j,
        "cell_volume_m3" => bin.cell_volume_m3,
        "ionization_fast_ion_birth_rate_s" =>
            bin.ionization_fast_ion_birth_rate_s,
        "charge_exchange_fast_ion_birth_rate_s" =>
            bin.charge_exchange_fast_ion_birth_rate_s,
        "total_fast_ion_birth_rate_s" => bin.total_fast_ion_birth_rate_s,
        "electron_birth_rate_s" => bin.electron_birth_rate_s,
        "net_same_species_ion_birth_rate_s" =>
            bin.net_same_species_ion_birth_rate_s,
        "thermal_same_species_ion_removal_rate_s" =>
            bin.thermal_same_species_ion_removal_rate_s)
end

"Compile a cylindrical spatial/energy deposition table into signed pitch-angle source bins."
function compile_directed_particle_deposition_source_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        executable_candidate_physics_hash::AbstractString,
        domain_id::AbstractString, actuator_id::AbstractString,
        injected_species_id::AbstractString, injected_species_mass_kg::Real,
        radial_centers_m, axial_centers_m, toroidal_angles_rad,
        cell_volumes_m3_by_radius, energy_groups, rate_records,
        field_at,
        candidate_binding_verified::Bool = false,
        field_candidate_binding_verified::Bool = false,
        source_candidate_binding_verified::Bool = false,
        coordinate_frame_binding_verified::Bool = false,
        resolution_verified::Bool = false,
        plasma_profile_applicability_verified::Bool = false,
        atomic_model_applicability_verified::Bool = false,
        source_kind::Symbol = :proxy,
        source_result_status::Symbol = :unknown,
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString,
        source_result_hash::AbstractString,
        field_artifact_id::AbstractString,
        field_artifact_hash::AbstractString,
        field_result_hash::AbstractString,
        expected_ionization_rate_s::Union{Nothing,Real} = nothing,
        expected_charge_exchange_conversion_rate_s::Union{Nothing,Real} = nothing,
        expected_fast_ion_birth_rate_s::Union{Nothing,Real} = nothing,
        expected_electron_birth_rate_s::Union{Nothing,Real} = nothing,
        expected_net_same_species_ion_birth_rate_s::Union{Nothing,Real} = nothing,
        expected_represented_fast_ion_birth_kinetic_power_w::Union{Nothing,Real} = nothing,
        index_base::Integer = 0,
        identity_rtol::Real = 1.0e-10,
        energy_rtol::Real = 1.0e-8)
    genome_hash = _directed_deposition_hash_v1(genome_physics_hash,
        "Genome physics hash")
    executable_hash = _directed_deposition_hash_v1(executable_candidate_physics_hash,
        "executable candidate physics hash")
    source_hash = _directed_deposition_hash_v1(source_artifact_hash,
        "source artifact hash")
    source_result = _directed_deposition_hash_v1(source_result_hash,
        "source result hash")
    field_hash = _directed_deposition_hash_v1(field_artifact_hash,
        "field artifact hash")
    field_result = _directed_deposition_hash_v1(field_result_hash,
        "field result hash")
    source_kind in _DIRECTED_DEPOSITION_SOURCE_KINDS_V1 || throw(ArgumentError(
        "unsupported directed-deposition source kind"))
    source_result_status in _DIRECTED_DEPOSITION_STATUSES_V1 || throw(ArgumentError(
        "unsupported directed-deposition result status"))
    index_base in (0, 1) || throw(ArgumentError("index_base must be zero or one"))
    mass = Float64(injected_species_mass_kg)
    isfinite(mass) && mass > 0.0 || throw(ArgumentError(
        "injected species mass must be positive and finite"))
    r = Float64.(collect(radial_centers_m))
    z = Float64.(collect(axial_centers_m))
    phi = Float64.(collect(toroidal_angles_rad))
    volumes = Float64.(collect(cell_volumes_m3_by_radius))
    !isempty(r) && !isempty(z) && !isempty(phi) || throw(ArgumentError(
        "deposition coordinate arrays cannot be empty"))
    length(volumes) == length(r) || throw(ArgumentError(
        "one cell volume is required per radial center"))
    all(isfinite, r) && all(isfinite, z) && all(isfinite, phi) &&
        all(value -> isfinite(value) && value > 0.0, volumes) ||
        throw(ArgumentError("deposition grid values must be finite and volumes positive"))
    all(diff(r) .> 0.0) && all(diff(z) .> 0.0) || throw(ArgumentError(
        "radial and axial centers must be strictly increasing"))
    r[1] >= 0.0 || throw(ArgumentError("radial centers cannot be negative"))
    identity_tol = Float64(identity_rtol)
    energy_tol = Float64(energy_rtol)
    all(value -> isfinite(value) && value >= 0.0, (identity_tol, energy_tol)) ||
        throw(ArgumentError("identity tolerances must be finite and non-negative"))

    groups = Dict{Int,Tuple{Float64,NTuple{3,Float64}}}()
    for raw in energy_groups
        length(raw) == 3 || throw(ArgumentError(
            "each energy group must contain index, kinetic energy J, and velocity vector"))
        group_index = Int(raw[1])
        haskey(groups, group_index) && throw(ArgumentError(
            "duplicate deposition energy-group index"))
        energy = Float64(raw[2])
        isfinite(energy) && energy > 0.0 || throw(ArgumentError(
            "energy-group kinetic energy must be positive and finite"))
        velocity = _directed_deposition_vector3_v1(raw[3], "energy-group velocity")
        speed2 = sum(component^2 for component in velocity)
        speed2 > 0.0 || throw(ArgumentError("energy-group velocity cannot be zero"))
        velocity_energy = 0.5 * mass * speed2
        abs(velocity_energy - energy) <= energy_tol * max(energy, velocity_energy) ||
            throw(ArgumentError("energy-group velocity is inconsistent with mass and energy"))
        groups[group_index] = (energy, velocity)
    end
    isempty(groups) && throw(ArgumentError("at least one energy group is required"))

    bins = DirectedParticleDepositionBinV1[]
    seen = Set{NTuple{4,Int}}()
    max_rate_residual = 0.0
    max_energy_residual = 0.0
    for raw in rate_records
        length(raw) == 6 || throw(ArgumentError(
            "each rate record must contain four indices and two rate densities"))
        indices = ntuple(i -> Int(raw[i]) - index_base + 1, 4)
        group_raw = indices[1] + index_base - 1
        haskey(groups, group_raw) || throw(ArgumentError(
            "rate record refers to an unknown energy group"))
        ir, iz, iphi = indices[2], indices[3], indices[4]
        1 <= ir <= length(r) && 1 <= iz <= length(z) &&
            1 <= iphi <= length(phi) || throw(ArgumentError(
            "rate record spatial index is out of bounds"))
        key = (group_raw, ir, iz, iphi)
        key in seen && throw(ArgumentError("duplicate deposition rate record"))
        push!(seen, key)
        ion_density = Float64(raw[5])
        cx_density = Float64(raw[6])
        all(value -> isfinite(value) && value >= 0.0, (ion_density, cx_density)) ||
            throw(ArgumentError("rate densities must be finite and non-negative"))
        ion_density + cx_density > 0.0 || throw(ArgumentError(
            "zero-only records must be omitted from the sparse deposition table"))

        radius, angle = r[ir], phi[iphi]
        position = (radius * cos(angle), radius * sin(angle), z[iz])
        magnetic = _directed_deposition_vector3_v1(field_at(position),
            "candidate magnetic field")
        magnetic_magnitude = sqrt(sum(component^2 for component in magnetic))
        magnetic_magnitude > 0.0 || throw(ArgumentError(
            "candidate magnetic field contains a null at a deposition bin"))
        energy, velocity = groups[group_raw]
        speed = sqrt(sum(component^2 for component in velocity))
        parallel = sum(velocity[i] * magnetic[i] for i in 1:3) /
            magnetic_magnitude
        perpendicular = sqrt(max(0.0, speed^2 - parallel^2))
        pitch_cosine = clamp(parallel / speed, -1.0, 1.0)
        pitch_angle = acos(pitch_cosine)
        volume = volumes[ir]
        ionization = ion_density * volume
        cx = cx_density * volume
        birth = ionization + cx
        rate_residual = abs(birth - ionization - cx) / max(birth, 1.0e-300)
        velocity_energy = 0.5 * mass * speed^2
        energy_residual = abs(velocity_energy - energy) /
            max(velocity_energy, energy, 1.0e-300)
        max_rate_residual = max(max_rate_residual, rate_residual)
        max_energy_residual = max(max_energy_residual, energy_residual)
        push!(bins, DirectedParticleDepositionBinV1(group_raw,
            ir - 1 + index_base, iz - 1 + index_base, iphi - 1 + index_base,
            position, magnetic, magnetic_magnitude, velocity, speed, parallel,
            perpendicular, pitch_cosine, pitch_angle, energy, volume,
            ionization, cx, birth, ionization, ionization, cx))
    end
    isempty(bins) && throw(ArgumentError(
        "at least one nonzero deposition record is required"))
    sort!(bins; by = bin -> (bin.energy_group_index, bin.radial_index,
        bin.axial_index, bin.toroidal_index))
    max_rate_residual <= identity_tol || throw(ArgumentError(
        "integrated deposition records violate the particle-rate identity"))
    max_energy_residual <= energy_tol || throw(ArgumentError(
        "deposition energy groups violate the kinetic-energy identity"))

    ionization = sum(bin.ionization_fast_ion_birth_rate_s for bin in bins)
    cx = sum(bin.charge_exchange_fast_ion_birth_rate_s for bin in bins)
    birth = sum(bin.total_fast_ion_birth_rate_s for bin in bins)
    represented_power = sum(bin.total_fast_ion_birth_rate_s *
        bin.kinetic_energy_j for bin in bins)
    expected_raw = (expected_ionization_rate_s,
        expected_charge_exchange_conversion_rate_s,
        expected_fast_ion_birth_rate_s, expected_electron_birth_rate_s,
        expected_net_same_species_ion_birth_rate_s,
        expected_represented_fast_ion_birth_kinetic_power_w)
    supplied_expected = map(!isnothing, expected_raw)
    all(supplied_expected) || !any(supplied_expected) || throw(ArgumentError(
        "all external aggregate expectations must be supplied together"))
    aggregate_residual = nothing
    aggregate_verified = false
    if all(supplied_expected)
        expected = Float64[something(value) for value in expected_raw]
        all(value -> isfinite(value) && value >= 0.0, expected) ||
            throw(ArgumentError("external aggregate expectations must be finite and non-negative"))
        actual = Float64[ionization, cx, birth, ionization, ionization,
            represented_power]
        residuals = abs.(actual .- expected) ./ max.(actual, expected, 1.0e-300)
        aggregate_residual = maximum(residuals)
        aggregate_verified = aggregate_residual <= identity_tol
        aggregate_verified || throw(ArgumentError(
            "integrated deposition bins do not reproduce the external aggregates"))
    end
    phase_binding = candidate_binding_verified && field_candidate_binding_verified &&
        source_candidate_binding_verified && coordinate_frame_binding_verified
    provenance = !isempty(source_artifact_id) && !isempty(field_artifact_id)
    physical_rate = source_result_status == :pass &&
        source_kind in (:candidate_solver, :measured) && phase_binding &&
        resolution_verified && aggregate_verified && provenance
    c2_source = physical_rate && plasma_profile_applicability_verified &&
        atomic_model_applicability_verified
    tasks = String[]
    candidate_binding_verified || push!(tasks, "bind_deposition_to_candidate")
    field_candidate_binding_verified || push!(tasks, "bind_field_to_candidate")
    source_candidate_binding_verified || push!(tasks, "bind_directed_source_to_candidate")
    coordinate_frame_binding_verified || push!(tasks,
        "verify_source_field_coordinate_frame_transform")
    resolution_verified || push!(tasks, "verify_spatial_velocity_deposition_resolution")
    aggregate_verified || push!(tasks, "reproduce_external_deposition_aggregates")
    plasma_profile_applicability_verified || push!(tasks,
        "replace_or_validate_candidate_plasma_profile")
    atomic_model_applicability_verified || push!(tasks,
        "validate_atomic_rate_model_applicability")
    push!(tasks, "map_charge_exchange_thermal_ion_sink_in_velocity_space")
    push!(tasks, "solve_multispecies_nonlinear_bounce_averaged_fokker_planck")
    push!(tasks, "solve_candidate_ambipolar_potential_and_loss_boundary")
    warnings = String[
        "Signed pitch angle is retained on [0, pi]; a half-pitch reduced solver cannot consume these bins without an explicit direction-preserving transform.",
        "Same-species charge exchange creates a fast ion and removes a thermal ion, so only ionization is a net ion and electron source.",
        "Represented birth kinetic power is not thermal heating before orbit evolution, slowing down and loss channels are solved.",
        "A phase-space source tensor is not a distribution function, steady state, stability result, gain estimate or feasibility claim."]
    core = Dict{String,Any}(
        "compiler_version" => "directed_particle_deposition_source_compiler_v1.0.0",
        "design_id" => String(design_id), "genome_physics_hash" => genome_hash,
        "executable_candidate_physics_hash" => executable_hash,
        "domain_id" => String(domain_id), "actuator_id" => String(actuator_id),
        "injected_species_id" => String(injected_species_id),
        "bins" => directed_particle_deposition_bin_to_dict_v1.(bins),
        "ionization_rate_s" => ionization,
        "charge_exchange_conversion_rate_s" => cx,
        "fast_ion_birth_rate_s" => birth,
        "electron_birth_rate_s" => ionization,
        "net_same_species_ion_birth_rate_s" => ionization,
        "thermal_same_species_ion_removal_rate_s" => cx,
        "represented_fast_ion_birth_kinetic_power_w" => represented_power,
        "maximum_rate_identity_relative_residual" => max_rate_residual,
        "maximum_energy_identity_relative_residual" => max_energy_residual,
        "maximum_external_aggregate_relative_residual" => aggregate_residual,
        "external_aggregate_audit_verified" => aggregate_verified,
        "candidate_phase_space_binding_verified" => phase_binding,
        "physical_source_rate_available" => physical_rate,
        "c2_phase_space_source_authorized" => c2_source,
        "c2_kinetic_state_authorized" => false,
        "source_kind" => String(source_kind),
        "source_result_status" => String(source_result_status),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => source_hash,
        "source_result_hash" => source_result,
        "field_artifact_id" => String(field_artifact_id),
        "field_artifact_hash" => field_hash,
        "field_result_hash" => field_result,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return DirectedParticleDepositionSourceObservationV1(
        "directed_particle_deposition_source_compiler_v1.0.0",
        String(design_id), genome_hash, executable_hash, String(domain_id),
        String(actuator_id), String(injected_species_id), length(bins), bins,
        ionization, cx, birth, ionization, ionization, cx, represented_power,
        max_rate_residual, max_energy_residual, aggregate_residual,
        aggregate_verified, phase_binding, physical_rate,
        c2_source, false, source_kind, source_result_status,
        String(source_artifact_id), source_hash, source_result,
        String(field_artifact_id), field_hash, field_result,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

function directed_particle_deposition_source_to_dict_v1(observation)
    result = Dict{String,Any}(String(name) => getfield(observation, name)
        for name in fieldnames(typeof(observation)) if name != :bins)
    result["bins"] = directed_particle_deposition_bin_to_dict_v1.(observation.bins)
    result["source_kind"] = String(observation.source_kind)
    result["source_result_status"] = String(observation.source_result_status)
    return result
end

"Map only net ion/electron births; CX thermal removal and birth power stay unmapped."
function directed_particle_deposition_coupled_evidence_v1(
        balance::CoupledPlasmaBalanceProblemV1,
        observation::DirectedParticleDepositionSourceObservationV1)
    observation.design_id == balance.design_id || throw(ArgumentError(
        "directed-deposition design mismatch"))
    observation.genome_physics_hash == balance.genome_physics_hash ||
        throw(ArgumentError("directed-deposition Genome hash mismatch"))
    evidence = CoupledPlasmaBalanceTermEvidenceV1[]
    kind = observation.c2_phase_space_source_authorized ? :candidate_solver : :proxy
    applicable = observation.c2_phase_space_source_authorized
    status = observation.source_result_status == :fail ? :fail : :pass
    for (species, value) in ((observation.injected_species_id,
            observation.net_same_species_ion_birth_rate_s),
            ("electron", observation.electron_birth_rate_s))
        matches = filter(item -> item.domain_id == observation.domain_id &&
            item.species_id == species &&
            item.mechanism_class == :external_particle_source, balance.terms)
        isempty(matches) && continue
        term = only(matches)
        push!(evidence, compile_coupled_plasma_balance_term_evidence_v1(balance;
            term_id = term.term_id, value = value, unit = term.unit,
            source_kind = kind,
            source_artifact_id = observation.source_artifact_id,
            source_artifact_hash = observation.source_artifact_hash,
            source_result_hash = observation.observation_hash,
            candidate_binding_verified =
                observation.candidate_phase_space_binding_verified,
            resolution_verified = observation.external_aggregate_audit_verified,
            applicability_verified = applicable, fidelity = 2,
            source_result_status = status))
    end
    return evidence
end
