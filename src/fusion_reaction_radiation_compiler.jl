const _REACTION_ELECTRON_VOLT_J_V1 = 1.602176634e-19
const _REACTION_KEV_J_V1 = 1.0e3 * _REACTION_ELECTRON_VOLT_J_V1
const _REACTION_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured, :proxy,
    :manufactured, :structural))

"Bosch-Hale Maxwellian-reactivity constants from equation 12/table VII."
struct BoschHaleCoefficientsV1
    channel_id::String
    bg_sqrt_kev::Float64
    mrc2_kev::Float64
    coefficients::Vector{Float64}
    minimum_temperature_kev::Float64
    maximum_temperature_kev::Float64
end

"One nuclear reaction channel, independent of the confinement topology."
struct FusionReactionChannelV1
    channel_id::String
    reactant_a::String
    reactant_b::String
    products::Vector{String}
    product_energy_j::Dict{String,Float64}
    identical_reactant_factor::Float64
    reactivity_model::Symbol
    source_ids::Vector{String}
end

"Reaction and radiation questions compiled from fuel chemistry and physical state needs."
struct FusionReactionRadiationProblemV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    fuel_declaration::String
    population_domain_ids::Vector{String}
    channels::Vector{FusionReactionChannelV1}
    radiation_component_ids::Vector{String}
    required_input_ids::Vector{String}
    evidence_tasks::Vector{String}
    problem_hash::String
end

"Collocated spatial state at one numerical resolution. Temperatures are energy moments in J."
struct CollocatedPlasmaStateGridV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    resolution_label::String
    resolution_rank::Int
    cell_volumes_m3::Vector{Float64}
    species_density_m3::Dict{String,Vector{Float64}}
    temperature_parallel_j::Dict{String,Vector{Float64}}
    temperature_perpendicular_j::Dict{String,Vector{Float64}}
    distribution_kinds::Dict{String,Symbol}
    runtime_state_assessment_hash::String
    runtime_state_c2_authorized::Bool
    cellwise_quasi_neutrality_verified::Bool
    runtime_inventory_consistency_verified::Bool
    fully_ionized_fuel_verified::Bool
    optically_thin_bremsstrahlung_verified::Bool
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

"Fusion and minimum fuel-ion bremsstrahlung components at one spatial resolution."
struct FusionReactionRadiationObservationV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    resolution_label::String
    resolution_rank::Int
    grid_hash::String
    channel_reaction_rates_s::Dict{String,Float64}
    channel_fusion_powers_w::Dict{String,Float64}
    total_fusion_power_w::Union{Nothing,Float64}
    charged_fusion_power_w::Union{Nothing,Float64}
    neutral_fusion_power_w::Union{Nothing,Float64}
    fuel_ion_bremsstrahlung_power_w::Union{Nothing,Float64}
    fusion_status::Symbol
    fuel_ion_bremsstrahlung_status::Symbol
    fusion_observation_c2_authorized::Bool
    fuel_ion_bremsstrahlung_observation_c2_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

"Two-or-more-resolution evidence gate. Total radiation and net power remain separate hard gates."
struct FusionReactionRadiationConvergenceV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    observation_hashes::Vector{String}
    total_fusion_power_w::Vector{Union{Nothing,Float64}}
    fuel_ion_bremsstrahlung_power_w::Vector{Union{Nothing,Float64}}
    fusion_adjacent_relative_changes::Vector{Float64}
    bremsstrahlung_adjacent_relative_changes::Vector{Float64}
    convergence_limit::Float64
    fusion_status::Symbol
    fuel_ion_bremsstrahlung_status::Symbol
    c2_fusion_power_authorized::Bool
    c2_fuel_ion_bremsstrahlung_authorized::Bool
    complete_radiation_authorized::Bool
    complete_power_balance_authorized::Bool
    status::Symbol
    evidence_tasks::Vector{String}
    convergence_hash::String
end

function default_bosch_hale_coefficients_v1()
    coeff(id, bg, mrc2, values) = BoschHaleCoefficientsV1(id, bg, mrc2,
        Float64.(values), 0.2, 100.0)
    return Dict{String,BoschHaleCoefficientsV1}(
        "dt_to_alpha_neutron" => coeff("dt_to_alpha_neutron", 34.3827,
            1.124656e6, [1.17302e-9, 1.51361e-2, 7.51886e-2,
                4.60643e-3, 1.35000e-2, -1.06750e-4, 1.36600e-5]),
        "dd_to_tritium_proton" => coeff("dd_to_tritium_proton", 31.3970,
            9.37814e5, [5.65718e-12, 3.41267e-3, 1.99167e-3,
                0.0, 1.05060e-5, 0.0, 0.0]),
        "dd_to_helium3_neutron" => coeff("dd_to_helium3_neutron", 31.3970,
            9.37814e5, [5.43360e-12, 5.85778e-3, 7.68222e-3,
                0.0, -2.96400e-6, 0.0, 0.0]))
end

"Maxwellian reactivity in m^3/s. Out-of-fit temperatures return NaN, never extrapolation."
function bosch_hale_maxwellian_reactivity_v1(channel_id::AbstractString,
        temperature_kev::Real;
        registry = default_bosch_hale_coefficients_v1())
    id = String(channel_id)
    haskey(registry, id) || throw(ArgumentError("unknown Bosch-Hale channel $id"))
    item = registry[id]
    temperature = Float64(temperature_kev)
    isfinite(temperature) || return NaN
    item.minimum_temperature_kev <= temperature <=
        item.maximum_temperature_kev || return NaN
    c1, c2, c3, c4, c5, c6, c7 = item.coefficients
    denominator = 1.0 - temperature *
        (c2 + temperature * (c4 + temperature * c6)) /
        (1.0 + temperature * (c3 + temperature * (c5 + temperature * c7)))
    denominator > 0.0 || return NaN
    theta = temperature / denominator
    xi = (item.bg_sqrt_kev^2 / (4.0 * theta))^(1.0 / 3.0)
    value_cm3_s = c1 * theta * sqrt(xi /
        (item.mrc2_kev * temperature^3)) * exp(-3.0 * xi)
    return value_cm3_s * 1.0e-6
end

function _reaction_energy_j_v1(mev::Real)
    return Float64(mev) * 1.0e6 * _REACTION_ELECTRON_VOLT_J_V1
end

function fusion_reaction_channels_v1(fuel::AbstractString)
    normalized = uppercase(replace(String(fuel), " " => ""))
    source = ["bosch_hale_reactivity_1992"]
    if normalized in ("D-T", "DT")
        return FusionReactionChannelV1[
            FusionReactionChannelV1("dt_to_alpha_neutron", "deuterium",
                "tritium", ["alpha", "neutron"],
                Dict("alpha" => _reaction_energy_j_v1(3.52),
                    "neutron" => _reaction_energy_j_v1(14.06)),
                1.0, :bosch_hale_maxwellian, copy(source))]
    elseif normalized in ("D-D", "DD")
        return FusionReactionChannelV1[
            FusionReactionChannelV1("dd_to_tritium_proton", "deuterium",
                "deuterium", ["tritium", "proton"],
                Dict("tritium" => _reaction_energy_j_v1(1.01),
                    "proton" => _reaction_energy_j_v1(3.02)),
                0.5, :bosch_hale_maxwellian, copy(source)),
            FusionReactionChannelV1("dd_to_helium3_neutron", "deuterium",
                "deuterium", ["helium3", "neutron"],
                Dict("helium3" => _reaction_energy_j_v1(0.82),
                    "neutron" => _reaction_energy_j_v1(2.45)),
                0.5, :bosch_hale_maxwellian, copy(source))]
    end
    return FusionReactionChannelV1[]
end

function fusion_reaction_channel_to_dict_v1(item::FusionReactionChannelV1)
    return Dict{String,Any}("channel_id" => item.channel_id,
        "reactant_a" => item.reactant_a, "reactant_b" => item.reactant_b,
        "products" => item.products, "product_energy_j" => item.product_energy_j,
        "identical_reactant_factor" => item.identical_reactant_factor,
        "reactivity_model" => String(item.reactivity_model),
        "source_ids" => item.source_ids)
end

function compile_fusion_reaction_radiation_problem_v1(genome::Genome)
    state_problem = compile_runtime_species_state_problem_v1(genome)
    channels = fusion_reaction_channels_v1(genome.mission.fuel)
    radiation = ["fuel_ion_bremsstrahlung", "cyclotron_synchrotron",
        "line_recombination", "neutral_atomic_radiation"]
    inputs = ["collocated_species_density_profiles",
        "collocated_species_temperature_profiles", "cell_volume_quadrature",
        "velocity_distribution_applicability", "runtime_species_state_c2"]
    tasks = String[]
    isempty(channels) && push!(tasks,
        "declare_supported_fusion_reaction_network:$(genome.mission.fuel)")
    for domain in state_problem.population_domain_ids
        for channel in channels
            push!(tasks, "compute_reaction_channel:$domain:$(channel.channel_id)")
        end
        append!(tasks, ["compute_radiation_component:$domain:$id" for id in radiation])
    end
    append!(tasks, ["provide:$id" for id in inputs])
    core = Dict{String,Any}(
        "compiler_version" => "fusion_reaction_radiation_compiler_v1.0.0",
        "design_id" => genome.design_id,
        "genome_physics_hash" => genome.physics_hash,
        "fuel_declaration" => genome.mission.fuel,
        "population_domain_ids" => state_problem.population_domain_ids,
        "channels" => fusion_reaction_channel_to_dict_v1.(channels),
        "radiation_component_ids" => radiation,
        "required_input_ids" => inputs,
        "evidence_tasks" => sort!(unique(tasks)))
    return FusionReactionRadiationProblemV1(
        "fusion_reaction_radiation_compiler_v1.0.0", genome.design_id,
        genome.physics_hash, genome.mission.fuel,
        state_problem.population_domain_ids, channels, radiation, inputs,
        sort!(unique(tasks)), canonical_hash(core))
end

function fusion_reaction_radiation_problem_to_dict_v1(
        item::FusionReactionRadiationProblemV1)
    return Dict{String,Any}("compiler_version" => item.compiler_version,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "fuel_declaration" => item.fuel_declaration,
        "population_domain_ids" => item.population_domain_ids,
        "channels" => fusion_reaction_channel_to_dict_v1.(item.channels),
        "radiation_component_ids" => item.radiation_component_ids,
        "required_input_ids" => item.required_input_ids,
        "evidence_tasks" => item.evidence_tasks, "problem_hash" => item.problem_hash)
end

function _profile_dictionary_v1(raw, name::String, count::Int)
    result = Dict{String,Vector{Float64}}()
    for (species, values) in raw
        profile = Float64.(values)
        length(profile) == count || throw(ArgumentError(
            "$name profile length mismatch for $species"))
        all(isfinite, profile) || throw(ArgumentError(
            "$name profile must be finite for $species"))
        result[String(species)] = profile
    end
    return result
end

function compile_collocated_plasma_state_grid_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, resolution_label::AbstractString,
        resolution_rank::Integer, cell_volumes_m3,
        species_density_m3::AbstractDict,
        temperature_parallel_j::AbstractDict,
        temperature_perpendicular_j::AbstractDict,
        distribution_kinds::AbstractDict,
        runtime_state_assessment_hash::AbstractString,
        runtime_state_c2_authorized::Bool,
        cellwise_quasi_neutrality_verified::Bool,
        runtime_inventory_consistency_verified::Bool,
        fully_ionized_fuel_verified::Bool,
        optically_thin_bremsstrahlung_verified::Bool,
        source_kind::Symbol, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        candidate_binding_verified::Bool, resolution_verified::Bool,
        applicability_verified::Bool, fidelity::Integer,
        source_solver_status::Symbol)
    rank = Int(resolution_rank)
    rank > 0 || throw(ArgumentError("resolution rank must be positive"))
    volumes = Float64.(cell_volumes_m3)
    !isempty(volumes) || throw(ArgumentError("state grid cannot be empty"))
    all(value -> isfinite(value) && value > 0.0, volumes) ||
        throw(ArgumentError("cell volumes must be finite and positive"))
    count = length(volumes)
    densities = _profile_dictionary_v1(species_density_m3,
        "species density", count)
    tpar = _profile_dictionary_v1(temperature_parallel_j,
        "parallel temperature", count)
    tperp = _profile_dictionary_v1(temperature_perpendicular_j,
        "perpendicular temperature", count)
    all(profile -> all(value -> value >= 0.0, profile), values(densities)) ||
        throw(ArgumentError("species densities must be non-negative"))
    all(profile -> all(value -> value > 0.0, profile), values(tpar)) ||
        throw(ArgumentError("parallel temperatures must be positive"))
    all(profile -> all(value -> value > 0.0, profile), values(tperp)) ||
        throw(ArgumentError("perpendicular temperatures must be positive"))
    distributions = Dict{String,Symbol}(String(species) => Symbol(kind)
        for (species, kind) in distribution_kinds)
    all(kind -> kind in _SPECIES_DISTRIBUTIONS_V1, values(distributions)) ||
        throw(ArgumentError("invalid distribution kind in collocated state grid"))
    source_kind in _REACTION_SOURCE_KINDS_V1 ||
        throw(ArgumentError("invalid reaction-grid source kind"))
    source_solver_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid reaction-grid source status"))
    fidelity >= 0 || throw(ArgumentError("reaction-grid fidelity must be non-negative"))
    core = Dict{String,Any}("design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id),
        "resolution_label" => String(resolution_label), "resolution_rank" => rank,
        "cell_volumes_m3" => volumes, "species_density_m3" => densities,
        "temperature_parallel_j" => tpar,
        "temperature_perpendicular_j" => tperp,
        "distribution_kinds" => Dict(k => String(v) for (k, v) in distributions),
        "runtime_state_assessment_hash" => String(runtime_state_assessment_hash),
        "runtime_state_c2_authorized" => runtime_state_c2_authorized,
        "cellwise_quasi_neutrality_verified" =>
            cellwise_quasi_neutrality_verified,
        "runtime_inventory_consistency_verified" =>
            runtime_inventory_consistency_verified,
        "fully_ionized_fuel_verified" => fully_ionized_fuel_verified,
        "optically_thin_bremsstrahlung_verified" =>
            optically_thin_bremsstrahlung_verified,
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified,
        "applicability_verified" => applicability_verified,
        "fidelity" => Int(fidelity),
        "source_solver_status" => String(source_solver_status))
    return CollocatedPlasmaStateGridV1(String(design_id),
        String(genome_physics_hash), String(domain_id), String(resolution_label),
        rank, volumes, densities, tpar, tperp, distributions,
        String(runtime_state_assessment_hash), runtime_state_c2_authorized,
        cellwise_quasi_neutrality_verified,
        runtime_inventory_consistency_verified,
        fully_ionized_fuel_verified, optically_thin_bremsstrahlung_verified,
        source_kind, String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified,
        resolution_verified, applicability_verified, Int(fidelity),
        source_solver_status, canonical_hash(core))
end

function _collocated_grid_authoritative_v1(item::CollocatedPlasmaStateGridV1)
    provenance = !isempty(item.source_artifact_id) &&
        occursin(r"^[0-9a-f]{64}$", item.source_artifact_hash) &&
        occursin(r"^[0-9a-f]{64}$", item.source_result_hash) &&
        occursin(r"^[0-9a-f]{64}$", item.runtime_state_assessment_hash)
    return provenance && item.runtime_state_c2_authorized &&
        item.cellwise_quasi_neutrality_verified &&
        item.runtime_inventory_consistency_verified &&
        item.source_kind in (:candidate_solver, :measured) &&
        item.candidate_binding_verified && item.resolution_verified &&
        item.applicability_verified && item.fidelity >= 2 &&
        item.source_solver_status == :pass
end

function _grid_species_ready_v1(grid::CollocatedPlasmaStateGridV1,
        species::String)
    return haskey(grid.species_density_m3, species) &&
        haskey(grid.temperature_parallel_j, species) &&
        haskey(grid.temperature_perpendicular_j, species) &&
        haskey(grid.distribution_kinds, species)
end

function _isotropic_temperature_profile_v1(grid::CollocatedPlasmaStateGridV1,
        species::String; tolerance::Float64 = 1.0e-8)
    _grid_species_ready_v1(grid, species) || return false
    grid.distribution_kinds[species] == :maxwellian || return false
    return all(isapprox(a, b; rtol = tolerance, atol = 0.0) for (a, b) in
        zip(grid.temperature_parallel_j[species],
            grid.temperature_perpendicular_j[species]))
end

function _relative_temperature_kev_v1(channel::FusionReactionChannelV1,
        grid::CollocatedPlasmaStateGridV1, catalog::Dict{String,SpeciesPopulationSpecV1},
        index::Int)
    a, b = channel.reactant_a, channel.reactant_b
    mass_a, mass_b = catalog[a].mass_kg, catalog[b].mass_kg
    reduced_mass = mass_a * mass_b / (mass_a + mass_b)
    ta = grid.temperature_parallel_j[a][index]
    tb = grid.temperature_parallel_j[b][index]
    return reduced_mass * (ta / mass_a + tb / mass_b) / _REACTION_KEV_J_V1
end

function _fuel_bremsstrahlung_power_v1(
        problem::FusionReactionRadiationProblemV1,
        grid::CollocatedPlasmaStateGridV1,
        catalog::Dict{String,SpeciesPopulationSpecV1})
    electron = "electron"
    _isotropic_temperature_profile_v1(grid, electron) || return nothing
    ions = [item for item in values(catalog) if
        item.required_initial_population && item.charge_number > 0]
    all(item -> haskey(grid.species_density_m3, item.species_id), ions) ||
        return nothing
    total = 0.0
    for index in eachindex(grid.cell_volumes_m3)
        ne = grid.species_density_m3[electron][index]
        te_ev = grid.temperature_parallel_j[electron][index] /
            _REACTION_ELECTRON_VOLT_J_V1
        charge_density = sum(item.charge_number^2 *
            grid.species_density_m3[item.species_id][index] for item in ions)
        ne >= 0.0 && te_ev > 0.0 && charge_density >= 0.0 || return nothing
        # NRL hydrogenic optically-thin expression converted from W/cm^3 to W/m^3.
        density_w_m3 = 1.69e-38 * ne * sqrt(te_ev) * charge_density
        total += density_w_m3 * grid.cell_volumes_m3[index]
    end
    return total
end

function compile_fusion_reaction_radiation_observation_v1(
        problem::FusionReactionRadiationProblemV1,
        state_problem::RuntimeSpeciesStateProblemV1,
        grid::CollocatedPlasmaStateGridV1)
    (problem.design_id == state_problem.design_id &&
        state_problem.design_id == grid.design_id) ||
        throw(ArgumentError("reaction/state/grid design mismatch"))
    (problem.genome_physics_hash == state_problem.genome_physics_hash &&
        state_problem.genome_physics_hash == grid.genome_physics_hash) ||
        throw(ArgumentError(
            "reaction/state/grid Genome hash mismatch"))
    grid.domain_id in problem.population_domain_ids || throw(ArgumentError(
        "reaction grid domain is not a populated plasma domain"))
    tasks = String[]
    warnings = String[
        "Fuel-ion bremsstrahlung excludes impurity line/recombination radiation, neutral atomic radiation, and cyclotron/synchrotron transport or reabsorption.",
        "Fusion power is a source component, not net plasma gain or net electric power."]
    catalog = Dict(item.species_id => item for item in state_problem.species_catalog)
    rates = Dict{String,Float64}()
    powers = Dict{String,Float64}()
    charged_power = 0.0
    neutral_power = 0.0
    fusion_ready = !isempty(problem.channels)
    isempty(problem.channels) && push!(tasks, "declare_supported_fusion_reaction_network")
    for channel in problem.channels
        reactants = unique([channel.reactant_a, channel.reactant_b])
        if !all(species -> _grid_species_ready_v1(grid, species), reactants)
            fusion_ready = false
            push!(tasks, "provide_collocated_reactant_profiles:$(channel.channel_id)")
            continue
        end
        if !all(species -> _isotropic_temperature_profile_v1(grid, species), reactants)
            fusion_ready = false
            push!(tasks, "run_velocity_space_reactivity_integral:$(channel.channel_id)")
            continue
        end
        rate = 0.0
        applicable = true
        for index in eachindex(grid.cell_volumes_m3)
            na = grid.species_density_m3[channel.reactant_a][index]
            nb = grid.species_density_m3[channel.reactant_b][index]
            na >= 0.0 && nb >= 0.0 || (applicable = false; break)
            temperature = _relative_temperature_kev_v1(channel, grid,
                catalog, index)
            reactivity = bosch_hale_maxwellian_reactivity_v1(
                channel.channel_id, temperature)
            if !isfinite(reactivity)
                applicable = false
                break
            end
            rate += channel.identical_reactant_factor * na * nb * reactivity *
                grid.cell_volumes_m3[index]
        end
        if !applicable
            fusion_ready = false
            push!(tasks, "resolve_reactivity_applicability:$(channel.channel_id)")
            continue
        end
        rates[channel.channel_id] = rate
        energy = sum(values(channel.product_energy_j))
        powers[channel.channel_id] = rate * energy
        for (product, product_energy) in channel.product_energy_j
            product == "neutron" ?
                (neutral_power += rate * product_energy) :
                (charged_power += rate * product_energy)
        end
    end
    total_fusion = fusion_ready && length(rates) == length(problem.channels) ?
        sum(values(powers); init = 0.0) : nothing
    fuel_brems = _fuel_bremsstrahlung_power_v1(problem, grid, catalog)
    brems_ready = fuel_brems !== nothing
    grid.fully_ionized_fuel_verified || push!(tasks,
        "verify_fully_ionized_fuel_for_bremsstrahlung")
    grid.optically_thin_bremsstrahlung_verified || push!(tasks,
        "verify_optically_thin_bremsstrahlung_applicability")
    brems_ready || push!(tasks, "provide_electron_and_fuel_ion_bremsstrahlung_state")
    grid_authoritative = _collocated_grid_authoritative_v1(grid)
    grid.cellwise_quasi_neutrality_verified || push!(tasks,
        "verify_cellwise_quasi_neutrality")
    grid.runtime_inventory_consistency_verified || push!(tasks,
        "verify_spatial_profiles_against_runtime_state_inventories")
    grid_authoritative || push!(tasks,
        "raise_collocated_species_grid_to_candidate_bound_c2")
    fusion_authorized = fusion_ready && grid_authoritative
    brems_authorized = brems_ready && grid_authoritative &&
        grid.fully_ionized_fuel_verified &&
        grid.optically_thin_bremsstrahlung_verified
    source_failure = grid.source_solver_status in (:fail, :error) &&
        grid.source_kind in (:candidate_solver, :measured) &&
        grid.candidate_binding_verified && grid.fidelity >= 2
    fusion_status = source_failure ? :fail : fusion_ready ? :pass : :unknown
    brems_status = source_failure ? :fail : brems_ready ? :pass : :unknown
    append!(tasks, ["compute_radiation_component:$(grid.domain_id):$id" for id in
        ("cyclotron_synchrotron", "line_recombination", "neutral_atomic_radiation")])
    core = Dict{String,Any}("design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash, "domain_id" => grid.domain_id,
        "resolution_label" => grid.resolution_label,
        "resolution_rank" => grid.resolution_rank, "grid_hash" => grid.grid_hash,
        "channel_reaction_rates_s" => rates,
        "channel_fusion_powers_w" => powers,
        "total_fusion_power_w" => total_fusion,
        "charged_fusion_power_w" => fusion_ready ? charged_power : nothing,
        "neutral_fusion_power_w" => fusion_ready ? neutral_power : nothing,
        "fuel_ion_bremsstrahlung_power_w" => fuel_brems,
        "fusion_status" => String(fusion_status),
        "fuel_ion_bremsstrahlung_status" => String(brems_status),
        "fusion_observation_c2_authorized" => fusion_authorized,
        "fuel_ion_bremsstrahlung_observation_c2_authorized" => brems_authorized,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return FusionReactionRadiationObservationV1(problem.design_id,
        problem.genome_physics_hash, grid.domain_id, grid.resolution_label,
        grid.resolution_rank, grid.grid_hash, rates, powers, total_fusion,
        fusion_ready ? charged_power : nothing,
        fusion_ready ? neutral_power : nothing, fuel_brems, fusion_status,
        brems_status, fusion_authorized, brems_authorized,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

function _component_convergence_v1(values, observations, authorized_field::Symbol,
        status_field::Symbol, limit::Float64)
    any(getfield(item, status_field) == :fail for item in observations) &&
        return (:fail, false, Float64[])
    all_numeric = all(value -> value !== nothing, values)
    changes = all_numeric ? [abs(something(values[index]) -
        something(values[index - 1])) / max(abs(something(values[index])), 1.0e-30)
        for index in 2:length(values)] : Float64[]
    all_authorized = all(getfield(item, authorized_field) for item in observations)
    status = !all_numeric || !all_authorized ? :unknown :
        last(changes) <= limit ? :pass : :fail
    return status, status == :pass, changes
end

function compile_fusion_reaction_radiation_convergence_v1(
        observations::AbstractVector{FusionReactionRadiationObservationV1};
        convergence_limit::Real = 0.02)
    length(observations) >= 2 || throw(ArgumentError(
        "at least two reaction/radiation resolutions are required"))
    limit = Float64(convergence_limit)
    0.0 < limit < 1.0 || throw(ArgumentError("invalid convergence limit"))
    ordered = sort!(collect(observations); by = item -> item.resolution_rank)
    ranks = getfield.(ordered, :resolution_rank)
    length(unique(ranks)) == length(ranks) || throw(ArgumentError(
        "reaction/radiation resolution ranks must be unique"))
    for field in (:design_id, :genome_physics_hash, :domain_id)
        length(unique(getfield.(ordered, field))) == 1 || throw(ArgumentError(
            "reaction/radiation observations must share $field"))
    end
    fusion_values = getfield.(ordered, :total_fusion_power_w)
    brems_values = getfield.(ordered, :fuel_ion_bremsstrahlung_power_w)
    fusion_status, fusion_auth, fusion_changes = _component_convergence_v1(
        fusion_values, ordered, :fusion_observation_c2_authorized,
        :fusion_status, limit)
    brems_status, brems_auth, brems_changes = _component_convergence_v1(
        brems_values, ordered,
        :fuel_ion_bremsstrahlung_observation_c2_authorized,
        :fuel_ion_bremsstrahlung_status, limit)
    complete_radiation = false
    complete_power = false
    status = fusion_status == :fail || brems_status == :fail ? :fail : :unknown
    tasks = String[]
    for item in ordered
        append!(tasks, item.evidence_tasks)
    end
    fusion_status == :pass || push!(tasks,
        "resolve_spatial_fusion_power_convergence")
    brems_status == :pass || push!(tasks,
        "resolve_spatial_fuel_bremsstrahlung_convergence")
    append!(tasks, ["compute_complete_radiation_power",
        "compute_transport_and_exhaust_power", "compute_auxiliary_power",
        "compute_recirculating_and_net_electric_power"])
    core = Dict{String,Any}("design_id" => first(ordered).design_id,
        "genome_physics_hash" => first(ordered).genome_physics_hash,
        "domain_id" => first(ordered).domain_id,
        "observation_hashes" => getfield.(ordered, :observation_hash),
        "total_fusion_power_w" => fusion_values,
        "fuel_ion_bremsstrahlung_power_w" => brems_values,
        "fusion_adjacent_relative_changes" => fusion_changes,
        "bremsstrahlung_adjacent_relative_changes" => brems_changes,
        "convergence_limit" => limit,
        "fusion_status" => String(fusion_status),
        "fuel_ion_bremsstrahlung_status" => String(brems_status),
        "c2_fusion_power_authorized" => fusion_auth,
        "c2_fuel_ion_bremsstrahlung_authorized" => brems_auth,
        "complete_radiation_authorized" => complete_radiation,
        "complete_power_balance_authorized" => complete_power,
        "status" => String(status), "evidence_tasks" => sort!(unique(tasks)))
    return FusionReactionRadiationConvergenceV1(first(ordered).design_id,
        first(ordered).genome_physics_hash, first(ordered).domain_id,
        getfield.(ordered, :observation_hash), fusion_values, brems_values,
        fusion_changes, brems_changes, limit, fusion_status, brems_status,
        fusion_auth, brems_auth, complete_radiation, complete_power, status,
        sort!(unique(tasks)), canonical_hash(core))
end

function collocated_plasma_state_grid_to_dict_v1(item::CollocatedPlasmaStateGridV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "resolution_label" => item.resolution_label,
        "resolution_rank" => item.resolution_rank,
        "cell_volumes_m3" => item.cell_volumes_m3,
        "species_density_m3" => item.species_density_m3,
        "temperature_parallel_j" => item.temperature_parallel_j,
        "temperature_perpendicular_j" => item.temperature_perpendicular_j,
        "distribution_kinds" => Dict(k => String(v) for (k, v) in item.distribution_kinds),
        "runtime_state_assessment_hash" => item.runtime_state_assessment_hash,
        "runtime_state_c2_authorized" => item.runtime_state_c2_authorized,
        "cellwise_quasi_neutrality_verified" =>
            item.cellwise_quasi_neutrality_verified,
        "runtime_inventory_consistency_verified" =>
            item.runtime_inventory_consistency_verified,
        "fully_ionized_fuel_verified" => item.fully_ionized_fuel_verified,
        "optically_thin_bremsstrahlung_verified" =>
            item.optically_thin_bremsstrahlung_verified,
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

function fusion_reaction_radiation_observation_to_dict_v1(
        item::FusionReactionRadiationObservationV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "resolution_label" => item.resolution_label,
        "resolution_rank" => item.resolution_rank, "grid_hash" => item.grid_hash,
        "channel_reaction_rates_s" => item.channel_reaction_rates_s,
        "channel_fusion_powers_w" => item.channel_fusion_powers_w,
        "total_fusion_power_w" => item.total_fusion_power_w,
        "charged_fusion_power_w" => item.charged_fusion_power_w,
        "neutral_fusion_power_w" => item.neutral_fusion_power_w,
        "fuel_ion_bremsstrahlung_power_w" => item.fuel_ion_bremsstrahlung_power_w,
        "fusion_status" => String(item.fusion_status),
        "fuel_ion_bremsstrahlung_status" => String(item.fuel_ion_bremsstrahlung_status),
        "fusion_observation_c2_authorized" =>
            item.fusion_observation_c2_authorized,
        "fuel_ion_bremsstrahlung_observation_c2_authorized" =>
            item.fuel_ion_bremsstrahlung_observation_c2_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "observation_hash" => item.observation_hash)
end

function fusion_reaction_radiation_convergence_to_dict_v1(
        item::FusionReactionRadiationConvergenceV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "observation_hashes" => item.observation_hashes,
        "total_fusion_power_w" => item.total_fusion_power_w,
        "fuel_ion_bremsstrahlung_power_w" => item.fuel_ion_bremsstrahlung_power_w,
        "fusion_adjacent_relative_changes" => item.fusion_adjacent_relative_changes,
        "bremsstrahlung_adjacent_relative_changes" =>
            item.bremsstrahlung_adjacent_relative_changes,
        "convergence_limit" => item.convergence_limit,
        "fusion_status" => String(item.fusion_status),
        "fuel_ion_bremsstrahlung_status" => String(item.fuel_ion_bremsstrahlung_status),
        "c2_fusion_power_authorized" => item.c2_fusion_power_authorized,
        "c2_fuel_ion_bremsstrahlung_authorized" =>
            item.c2_fuel_ion_bremsstrahlung_authorized,
        "complete_radiation_authorized" => item.complete_radiation_authorized,
        "complete_power_balance_authorized" => item.complete_power_balance_authorized,
        "status" => String(item.status), "evidence_tasks" => item.evidence_tasks,
        "convergence_hash" => item.convergence_hash)
end
