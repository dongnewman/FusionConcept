const _THERMO_PROFILE_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured,
    :published_prior, :design_assumption, :proxy, :manufactured))

"Candidate-bound scalar-pressure values and cell-volume quadrature at one resolution."
struct ScalarPressureSpatialGridV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    resolution_label::String
    resolution_rank::Int
    cell_volumes_m3::Vector{Float64}
    scalar_pressure_pa::Vector{Float64}
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    resolution_verified::Bool
    applicability_verified::Bool
    fidelity::Int
    source_solver_status::Symbol
    grid_hash::String
end

"One independent thermodynamic input: either temperatures or densities."
struct IndependentThermodynamicProfileV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    resolution_label::String
    closure_mode::Symbol
    species_density_m3::Dict{String,Vector{Float64}}
    temperature_parallel_j::Dict{String,Vector{Float64}}
    temperature_perpendicular_j::Dict{String,Vector{Float64}}
    ion_number_fractions::Dict{String,Float64}
    distribution_kinds::Dict{String,Symbol}
    bulk_velocity_m_s::Dict{String,Vector{Float64}}
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    resolution_verified::Bool
    applicability_verified::Bool
    fidelity::Int
    source_solver_status::Symbol
    profile_hash::String
end

"Closed spatial state, with evidence authority kept separate from algebraic closure."
struct SpatialThermodynamicClosureV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    resolution_label::String
    resolution_rank::Int
    closure_mode::Symbol
    pressure_grid_hash::String
    independent_profile_hash::String
    cell_volumes_m3::Vector{Float64}
    species_density_m3::Dict{String,Vector{Float64}}
    temperature_parallel_j::Dict{String,Vector{Float64}}
    temperature_perpendicular_j::Dict{String,Vector{Float64}}
    distribution_kinds::Dict{String,Symbol}
    bulk_velocity_m_s::Dict{String,Vector{Float64}}
    maximum_pressure_relative_residual::Float64
    maximum_quasi_neutrality_relative_residual::Float64
    status::Symbol
    c2_state_closure_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    closure_hash::String
end

function _thermo_profile_dict_v1(raw, label::String; positive::Bool)
    result = Dict{String,Vector{Float64}}()
    for (species, values) in raw
        profile = Float64.(values)
        !isempty(profile) || throw(ArgumentError("$label profile cannot be empty"))
        all(isfinite, profile) || throw(ArgumentError(
            "$label profile must be finite for $species"))
        predicate = positive ? (value -> value > 0.0) : (value -> value >= 0.0)
        all(predicate, profile) || throw(ArgumentError(
            "$label profile has invalid sign for $species"))
        result[String(species)] = profile
    end
    return result
end

function _thermo_sha_ready_v1(value::String)
    return occursin(r"^[0-9a-f]{64}$", value)
end

function compile_scalar_pressure_spatial_grid_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, resolution_label::AbstractString,
        resolution_rank::Integer, cell_volumes_m3, scalar_pressure_pa,
        source_kind::Symbol, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        candidate_binding_verified::Bool, resolution_verified::Bool,
        applicability_verified::Bool, fidelity::Integer,
        source_solver_status::Symbol)
    rank = Int(resolution_rank)
    rank > 0 || throw(ArgumentError("pressure-grid resolution rank must be positive"))
    volumes = Float64.(cell_volumes_m3)
    pressure = Float64.(scalar_pressure_pa)
    !isempty(volumes) || throw(ArgumentError("pressure grid cannot be empty"))
    length(pressure) == length(volumes) || throw(ArgumentError(
        "pressure and cell-volume profile lengths differ"))
    all(value -> isfinite(value) && value > 0.0, volumes) ||
        throw(ArgumentError("pressure-grid cell volumes must be finite and positive"))
    all(value -> isfinite(value) && value >= 0.0, pressure) ||
        throw(ArgumentError("scalar pressure must be finite and non-negative"))
    source_kind in _THERMO_PROFILE_SOURCE_KINDS_V1 || throw(ArgumentError(
        "invalid pressure-grid source kind"))
    source_solver_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid pressure-grid source status"))
    fidelity >= 0 || throw(ArgumentError("pressure-grid fidelity must be non-negative"))
    core = Dict{String,Any}("design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id),
        "resolution_label" => String(resolution_label), "resolution_rank" => rank,
        "cell_volumes_m3" => volumes, "scalar_pressure_pa" => pressure,
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified,
        "applicability_verified" => applicability_verified,
        "fidelity" => Int(fidelity),
        "source_solver_status" => String(source_solver_status))
    return ScalarPressureSpatialGridV1(String(design_id),
        String(genome_physics_hash), String(domain_id), String(resolution_label),
        rank, volumes, pressure, source_kind, String(source_artifact_id),
        String(source_artifact_hash), String(source_result_hash),
        candidate_binding_verified, resolution_verified, applicability_verified,
        Int(fidelity), source_solver_status, canonical_hash(core))
end

function compile_independent_thermodynamic_profile_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, resolution_label::AbstractString,
        closure_mode::Symbol,
        species_density_m3::AbstractDict = Dict{String,Vector{Float64}}(),
        temperature_parallel_j::AbstractDict = Dict{String,Vector{Float64}}(),
        temperature_perpendicular_j::AbstractDict = Dict{String,Vector{Float64}}(),
        ion_number_fractions::AbstractDict = Dict{String,Float64}(),
        distribution_kinds::AbstractDict,
        bulk_velocity_m_s::AbstractDict = Dict{String,Vector{Float64}}(),
        source_kind::Symbol, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        candidate_binding_verified::Bool, resolution_verified::Bool,
        applicability_verified::Bool, fidelity::Integer,
        source_solver_status::Symbol)
    closure_mode in (:temperature_to_density, :density_to_temperature) ||
        throw(ArgumentError("unsupported thermodynamic closure mode"))
    densities = _thermo_profile_dict_v1(species_density_m3,
        "species density"; positive = false)
    tpar = _thermo_profile_dict_v1(temperature_parallel_j,
        "parallel temperature"; positive = true)
    tperp = _thermo_profile_dict_v1(temperature_perpendicular_j,
        "perpendicular temperature"; positive = true)
    closure_mode == :temperature_to_density && !isempty(densities) &&
        throw(ArgumentError("temperature-to-density input cannot prescribe density"))
    closure_mode == :density_to_temperature &&
        (isempty(tpar) || isempty(tperp)) && throw(ArgumentError(
            "density-to-temperature input requires positive temperature ratios"))
    fractions = Dict{String,Float64}(String(k) => Float64(v)
        for (k, v) in ion_number_fractions)
    all(value -> isfinite(value) && value >= 0.0, values(fractions)) ||
        throw(ArgumentError("ion number fractions must be finite and non-negative"))
    distributions = Dict{String,Symbol}(String(k) => Symbol(v)
        for (k, v) in distribution_kinds)
    all(value -> value in _SPECIES_DISTRIBUTIONS_V1, values(distributions)) ||
        throw(ArgumentError("invalid distribution kind in thermodynamic profile"))
    velocities = Dict{String,Vector{Float64}}()
    for (species, raw) in bulk_velocity_m_s
        value = Float64.(raw)
        length(value) == 3 && all(isfinite, value) || throw(ArgumentError(
            "bulk velocity must have three finite components for $species"))
        velocities[String(species)] = value
    end
    source_kind in _THERMO_PROFILE_SOURCE_KINDS_V1 || throw(ArgumentError(
        "invalid independent-profile source kind"))
    source_solver_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid independent-profile source status"))
    fidelity >= 0 || throw(ArgumentError("profile fidelity must be non-negative"))
    core = Dict{String,Any}("design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id),
        "resolution_label" => String(resolution_label),
        "closure_mode" => String(closure_mode),
        "species_density_m3" => densities,
        "temperature_parallel_j" => tpar,
        "temperature_perpendicular_j" => tperp,
        "ion_number_fractions" => fractions,
        "distribution_kinds" => Dict(k => String(v) for (k, v) in distributions),
        "bulk_velocity_m_s" => velocities, "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified,
        "applicability_verified" => applicability_verified,
        "fidelity" => Int(fidelity),
        "source_solver_status" => String(source_solver_status))
    return IndependentThermodynamicProfileV1(String(design_id),
        String(genome_physics_hash), String(domain_id), String(resolution_label),
        closure_mode, densities, tpar, tperp, fractions, distributions,
        velocities, source_kind, String(source_artifact_id),
        String(source_artifact_hash), String(source_result_hash),
        candidate_binding_verified, resolution_verified, applicability_verified,
        Int(fidelity), source_solver_status, canonical_hash(core))
end

function _spatial_pressure_authoritative_v1(item::ScalarPressureSpatialGridV1)
    return item.source_kind in (:candidate_solver, :measured) &&
        !isempty(item.source_artifact_id) &&
        _thermo_sha_ready_v1(item.source_artifact_hash) &&
        _thermo_sha_ready_v1(item.source_result_hash) &&
        item.candidate_binding_verified && item.resolution_verified &&
        item.applicability_verified && item.fidelity >= 2 &&
        item.source_solver_status == :pass
end

function _independent_profile_authoritative_v1(
        item::IndependentThermodynamicProfileV1)
    return item.source_kind in (:candidate_solver, :measured) &&
        !isempty(item.source_artifact_id) &&
        _thermo_sha_ready_v1(item.source_artifact_hash) &&
        _thermo_sha_ready_v1(item.source_result_hash) &&
        item.candidate_binding_verified && item.resolution_verified &&
        item.applicability_verified && item.fidelity >= 2 &&
        item.source_solver_status == :pass
end

_scalar_temperature_v1(tpar, tperp, index) =
    (tpar[index] + 2.0 * tperp[index]) / 3.0

function _require_profile_length_v1(values::AbstractDict, species::String,
        count::Int, label::String)
    haskey(values, species) || throw(ArgumentError(
        "missing $label profile for $species"))
    length(values[species]) == count || throw(ArgumentError(
        "$label profile length mismatch for $species"))
end

function compile_spatial_thermodynamic_closure_v1(
        problem::RuntimeSpeciesStateProblemV1,
        pressure::ScalarPressureSpatialGridV1,
        input::IndependentThermodynamicProfileV1;
        pressure_relative_limit::Real = 1.0e-10,
        quasi_neutrality_limit::Real = 1.0e-10)
    for item in (pressure, input)
        item.design_id == problem.design_id || throw(ArgumentError(
            "thermodynamic closure design mismatch"))
        item.genome_physics_hash == problem.genome_physics_hash ||
            throw(ArgumentError("thermodynamic closure Genome hash mismatch"))
        item.domain_id in problem.population_domain_ids || throw(ArgumentError(
            "thermodynamic closure domain is not a populated plasma domain"))
    end
    pressure.domain_id == input.domain_id || throw(ArgumentError(
        "pressure and independent-profile domains differ"))
    pressure.resolution_label == input.resolution_label || throw(ArgumentError(
        "pressure and independent-profile resolutions differ"))
    plimit = Float64(pressure_relative_limit)
    qlimit = Float64(quasi_neutrality_limit)
    0.0 <= plimit < 1.0 || throw(ArgumentError("invalid pressure residual limit"))
    0.0 <= qlimit < 1.0 || throw(ArgumentError("invalid charge residual limit"))
    count = length(pressure.cell_volumes_m3)
    catalog = Dict(item.species_id => item for item in problem.species_catalog)
    required = [item.species for item in problem.requirements if
        item.domain_id == pressure.domain_id]
    species_ids = getfield.(required, :species_id)
    electron = "electron"
    electron in species_ids || throw(ArgumentError(
        "thermodynamic closure requires an electron population"))
    ions = [item for item in required if item.charge_number > 0]
    !isempty(ions) || throw(ArgumentError(
        "thermodynamic closure requires at least one positive ion"))
    all(haskey(input.distribution_kinds, id) for id in species_ids) ||
        throw(ArgumentError("missing distribution kind for a required species"))
    densities = Dict{String,Vector{Float64}}()
    tpar = Dict{String,Vector{Float64}}()
    tperp = Dict{String,Vector{Float64}}()
    if input.closure_mode == :temperature_to_density
        for id in species_ids
            _require_profile_length_v1(input.temperature_parallel_j, id,
                count, "parallel temperature")
            _require_profile_length_v1(input.temperature_perpendicular_j, id,
                count, "perpendicular temperature")
            tpar[id] = copy(input.temperature_parallel_j[id])
            tperp[id] = copy(input.temperature_perpendicular_j[id])
        end
        fraction_ids = Set(keys(input.ion_number_fractions))
        ion_ids = Set(getfield.(ions, :species_id))
        fraction_ids == ion_ids || throw(ArgumentError(
            "ion fractions must exactly cover required positive ions"))
        isapprox(sum(values(input.ion_number_fractions)), 1.0;
            rtol = 1.0e-12, atol = 1.0e-12) || throw(ArgumentError(
            "ion number fractions must sum to one"))
        for id in species_ids
            densities[id] = zeros(count)
        end
        for index in 1:count
            te = _scalar_temperature_v1(tpar[electron], tperp[electron], index)
            zbar = sum(input.ion_number_fractions[item.species_id] *
                item.charge_number for item in ions)
            denominator = zbar * te + sum(
                input.ion_number_fractions[item.species_id] *
                _scalar_temperature_v1(tpar[item.species_id],
                    tperp[item.species_id], index) for item in ions)
            denominator > 0.0 || throw(ArgumentError(
                "temperature closure has a non-positive pressure denominator"))
            total_ion_density = pressure.scalar_pressure_pa[index] / denominator
            densities[electron][index] = zbar * total_ion_density
            for item in ions
                densities[item.species_id][index] =
                    input.ion_number_fractions[item.species_id] * total_ion_density
            end
        end
    else
        for id in species_ids
            _require_profile_length_v1(input.species_density_m3, id,
                count, "species density")
            _require_profile_length_v1(input.temperature_parallel_j, id,
                count, "parallel temperature ratio")
            _require_profile_length_v1(input.temperature_perpendicular_j, id,
                count, "perpendicular temperature ratio")
            densities[id] = copy(input.species_density_m3[id])
            tpar[id] = zeros(count)
            tperp[id] = zeros(count)
        end
        for index in 1:count
            denominator = sum(densities[id][index] *
                _scalar_temperature_v1(input.temperature_parallel_j[id],
                    input.temperature_perpendicular_j[id], index)
                for id in species_ids)
            if pressure.scalar_pressure_pa[index] == 0.0 && denominator == 0.0
                for id in species_ids
                    tpar[id][index] = input.temperature_parallel_j[id][index]
                    tperp[id][index] = input.temperature_perpendicular_j[id][index]
                end
            else
                denominator > 0.0 || throw(ArgumentError(
                    "density closure has a non-positive temperature denominator"))
                scale = pressure.scalar_pressure_pa[index] / denominator
                scale > 0.0 || throw(ArgumentError(
                    "positive density support requires positive pressure"))
                for id in species_ids
                    tpar[id][index] = scale * input.temperature_parallel_j[id][index]
                    tperp[id][index] = scale * input.temperature_perpendicular_j[id][index]
                end
            end
        end
    end
    reconstructed = zeros(count)
    qresiduals = zeros(count)
    for index in 1:count
        reconstructed[index] = sum(densities[id][index] *
            _scalar_temperature_v1(tpar[id], tperp[id], index)
            for id in species_ids)
        electron_charge = densities[electron][index]
        positive_charge = sum(item.charge_number *
            densities[item.species_id][index] for item in ions)
        qresiduals[index] = abs(positive_charge - electron_charge) /
            max(abs(positive_charge), abs(electron_charge), 1.0)
    end
    pres = maximum(abs(reconstructed[index] - pressure.scalar_pressure_pa[index]) /
        max(abs(pressure.scalar_pressure_pa[index]), 1.0) for index in 1:count)
    qres = maximum(qresiduals)
    failed = String[]
    pres <= plimit || push!(failed, "scalar_pressure_reconstruction")
    qres <= qlimit || push!(failed, "cellwise_quasi_neutrality")
    source_failure = pressure.source_solver_status in (:fail, :error) ||
        input.source_solver_status in (:fail, :error)
    status = source_failure || !isempty(failed) ? :fail : :pass
    authoritative = status == :pass && _spatial_pressure_authoritative_v1(pressure) &&
        _independent_profile_authoritative_v1(input)
    tasks = String[]
    _spatial_pressure_authoritative_v1(pressure) || push!(tasks,
        "raise_spatial_pressure_grid_to_candidate_bound_c2")
    _independent_profile_authoritative_v1(input) || push!(tasks,
        "replace_thermodynamic_assumption_with_candidate_solver_or_measurement")
    append!(tasks, ["resolve:$id" for id in failed])
    warnings = String[
        "Algebraic pressure closure is a spatial state construction, not a transport, heating, particle-source, or burn-equilibrium solution.",
        "A design assumption or published prior can support low-fidelity falsification only and receives no C2 authority."]
    velocities = Dict(id => get(input.bulk_velocity_m_s, id,
        [0.0, 0.0, 0.0]) for id in species_ids)
    distributions = Dict(id => input.distribution_kinds[id] for id in species_ids)
    core = Dict{String,Any}("design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "domain_id" => pressure.domain_id,
        "resolution_label" => pressure.resolution_label,
        "resolution_rank" => pressure.resolution_rank,
        "closure_mode" => String(input.closure_mode),
        "pressure_grid_hash" => pressure.grid_hash,
        "independent_profile_hash" => input.profile_hash,
        "cell_volumes_m3" => pressure.cell_volumes_m3,
        "species_density_m3" => densities,
        "temperature_parallel_j" => tpar,
        "temperature_perpendicular_j" => tperp,
        "distribution_kinds" => Dict(k => String(v) for (k, v) in distributions),
        "bulk_velocity_m_s" => velocities,
        "maximum_pressure_relative_residual" => pres,
        "maximum_quasi_neutrality_relative_residual" => qres,
        "status" => String(status),
        "c2_state_closure_authorized" => authoritative,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return SpatialThermodynamicClosureV1(problem.design_id,
        problem.genome_physics_hash, pressure.domain_id,
        pressure.resolution_label, pressure.resolution_rank, input.closure_mode,
        pressure.grid_hash, input.profile_hash, pressure.cell_volumes_m3,
        densities, tpar, tperp, distributions, velocities, pres, qres, status,
        authoritative, sort!(unique(tasks)), warnings, canonical_hash(core))
end

function spatial_thermodynamic_closure_runtime_state_evidence_v1(
        item::SpatialThermodynamicClosureV1;
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString)
    volume = sum(item.cell_volumes_m3)
    evidence = RuntimeSpeciesStateEvidenceV1[]
    source_kind = item.c2_state_closure_authorized ? :candidate_solver : :proxy
    for species in sort!(collect(keys(item.species_density_m3)))
        density_profile = item.species_density_m3[species]
        particles = sum(density_profile .* item.cell_volumes_m3)
        density = particles / volume
        if particles > 0.0
            tpar = sum(density_profile .* item.temperature_parallel_j[species] .*
                item.cell_volumes_m3) / particles
            tperp = sum(density_profile .* item.temperature_perpendicular_j[species] .*
                item.cell_volumes_m3) / particles
        else
            tpar = sum(item.temperature_parallel_j[species] .*
                item.cell_volumes_m3) / volume
            tperp = sum(item.temperature_perpendicular_j[species] .*
                item.cell_volumes_m3) / volume
        end
        push!(evidence, compile_runtime_species_state_evidence_v1(
            design_id = item.design_id,
            genome_physics_hash = item.genome_physics_hash,
            domain_id = item.domain_id, species_id = species,
            density_m3 = density, temperature_parallel_j = tpar,
            temperature_perpendicular_j = tperp,
            bulk_velocity_m_s = item.bulk_velocity_m_s[species],
            distribution_kind = item.distribution_kinds[species],
            plasma_volume_m3 = volume, source_kind = source_kind,
            source_artifact_id = String(source_artifact_id),
            source_artifact_hash = String(source_artifact_hash),
            source_result_hash = item.closure_hash,
            candidate_binding_verified = item.c2_state_closure_authorized,
            resolution_verified = item.c2_state_closure_authorized,
            applicability_verified = item.c2_state_closure_authorized,
            fidelity = item.c2_state_closure_authorized ? 2 : 1,
            source_solver_status = item.status))
    end
    return evidence
end

function spatial_thermodynamic_closure_collocated_grid_v1(
        item::SpatialThermodynamicClosureV1,
        assessment::RuntimeSpeciesStateAssessmentV1;
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString,
        inventory_relative_limit::Real = 1.0e-10)
    assessment.design_id == item.design_id || throw(ArgumentError(
        "closure/runtime-state assessment design mismatch"))
    assessment.genome_physics_hash == item.genome_physics_hash ||
        throw(ArgumentError("closure/runtime-state assessment Genome hash mismatch"))
    limit = Float64(inventory_relative_limit)
    0.0 <= limit < 1.0 || throw(ArgumentError("invalid inventory consistency limit"))
    volume = sum(item.cell_volumes_m3)
    consistent = true
    for species in keys(item.species_density_m3)
        particle_key = "$(item.domain_id):$species:particle_inventory"
        thermal_key = "$(item.domain_id):$species:thermal_energy"
        if !haskey(assessment.particle_inventories, particle_key) ||
                !haskey(assessment.thermal_energy_inventories_j, thermal_key)
            consistent = false
            break
        end
        particle = sum(item.species_density_m3[species] .* item.cell_volumes_m3)
        thermal = sum(item.species_density_m3[species] .*
            (item.temperature_parallel_j[species] .+
                2.0 .* item.temperature_perpendicular_j[species]) .*
            item.cell_volumes_m3) / 2.0
        particle_error = abs(particle - assessment.particle_inventories[particle_key]) /
            max(abs(particle), abs(assessment.particle_inventories[particle_key]), 1.0)
        thermal_error = abs(thermal - assessment.thermal_energy_inventories_j[thermal_key]) /
            max(abs(thermal), abs(assessment.thermal_energy_inventories_j[thermal_key]), 1.0)
        if particle_error > limit || thermal_error > limit
            consistent = false
            break
        end
    end
    quasi_neutral = item.maximum_quasi_neutrality_relative_residual <= limit
    c2 = item.c2_state_closure_authorized &&
        assessment.c2_state_component_authorized
    source_kind = c2 ? :candidate_solver : :proxy
    return compile_collocated_plasma_state_grid_v1(
        design_id = item.design_id,
        genome_physics_hash = item.genome_physics_hash,
        domain_id = item.domain_id, resolution_label = item.resolution_label,
        resolution_rank = item.resolution_rank,
        cell_volumes_m3 = item.cell_volumes_m3,
        species_density_m3 = item.species_density_m3,
        temperature_parallel_j = item.temperature_parallel_j,
        temperature_perpendicular_j = item.temperature_perpendicular_j,
        distribution_kinds = item.distribution_kinds,
        runtime_state_assessment_hash = assessment.assessment_hash,
        runtime_state_c2_authorized = c2,
        cellwise_quasi_neutrality_verified = quasi_neutral,
        runtime_inventory_consistency_verified = consistent,
        fully_ionized_fuel_verified = false,
        optically_thin_bremsstrahlung_verified = false,
        source_kind = source_kind,
        source_artifact_id = String(source_artifact_id),
        source_artifact_hash = String(source_artifact_hash),
        source_result_hash = item.closure_hash,
        candidate_binding_verified = c2, resolution_verified = c2,
        applicability_verified = c2, fidelity = c2 ? 2 : 1,
        source_solver_status = item.status)
end

function scalar_pressure_spatial_grid_to_dict_v1(item::ScalarPressureSpatialGridV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "resolution_label" => item.resolution_label,
        "resolution_rank" => item.resolution_rank,
        "cell_volumes_m3" => item.cell_volumes_m3,
        "scalar_pressure_pa" => item.scalar_pressure_pa,
        "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_verified" => item.resolution_verified,
        "applicability_verified" => item.applicability_verified,
        "fidelity" => item.fidelity,
        "source_solver_status" => String(item.source_solver_status),
        "grid_hash" => item.grid_hash)
end

function independent_thermodynamic_profile_to_dict_v1(
        item::IndependentThermodynamicProfileV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "resolution_label" => item.resolution_label,
        "closure_mode" => String(item.closure_mode),
        "species_density_m3" => item.species_density_m3,
        "temperature_parallel_j" => item.temperature_parallel_j,
        "temperature_perpendicular_j" => item.temperature_perpendicular_j,
        "ion_number_fractions" => item.ion_number_fractions,
        "distribution_kinds" => Dict(k => String(v) for (k, v) in
            item.distribution_kinds),
        "bulk_velocity_m_s" => item.bulk_velocity_m_s,
        "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_verified" => item.resolution_verified,
        "applicability_verified" => item.applicability_verified,
        "fidelity" => item.fidelity,
        "source_solver_status" => String(item.source_solver_status),
        "profile_hash" => item.profile_hash)
end

function spatial_thermodynamic_closure_to_dict_v1(
        item::SpatialThermodynamicClosureV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "resolution_label" => item.resolution_label,
        "resolution_rank" => item.resolution_rank,
        "closure_mode" => String(item.closure_mode),
        "pressure_grid_hash" => item.pressure_grid_hash,
        "independent_profile_hash" => item.independent_profile_hash,
        "cell_volumes_m3" => item.cell_volumes_m3,
        "species_density_m3" => item.species_density_m3,
        "temperature_parallel_j" => item.temperature_parallel_j,
        "temperature_perpendicular_j" => item.temperature_perpendicular_j,
        "distribution_kinds" => Dict(k => String(v) for (k, v) in
            item.distribution_kinds),
        "bulk_velocity_m_s" => item.bulk_velocity_m_s,
        "maximum_pressure_relative_residual" =>
            item.maximum_pressure_relative_residual,
        "maximum_quasi_neutrality_relative_residual" =>
            item.maximum_quasi_neutrality_relative_residual,
        "status" => String(item.status),
        "c2_state_closure_authorized" => item.c2_state_closure_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "closure_hash" => item.closure_hash)
end
