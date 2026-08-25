const _SPECIES_DISTRIBUTIONS_V1 = Set((:maxwellian, :bi_maxwellian,
    :tabulated, :particle_ensemble, :unknown))
const _SPECIES_EVIDENCE_STATUSES_V1 = Set((:pass, :fail, :unknown, :error))
const _SPECIES_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured, :proxy,
    :manufactured, :structural))

"A species implied by the fuel declaration, separated into initial populations and reaction products."
struct SpeciesPopulationSpecV1
    species_id::String
    role::Symbol
    charge_number::Int
    mass_kg::Float64
    required_initial_population::Bool
end

"One topology- and domain-derived runtime state requirement."
struct RuntimeSpeciesStateRequirementV1
    domain_id::String
    species::SpeciesPopulationSpecV1
    required_field_ids::Vector{String}
    anisotropy_resolution_required::Bool
end

"Executable per-domain/per-species state problem; family labels are absent from routing."
struct RuntimeSpeciesStateProblemV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    fuel_declaration::String
    population_domain_ids::Vector{String}
    scalar_pressure_reference_required::Bool
    species_catalog::Vector{SpeciesPopulationSpecV1}
    requirements::Vector{RuntimeSpeciesStateRequirementV1}
    evidence_tasks::Vector{String}
    problem_hash::String
end

"Candidate-bound volume-averaged species moments and distribution declaration."
struct RuntimeSpeciesStateEvidenceV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    species_id::String
    density_m3::Union{Nothing,Float64}
    temperature_parallel_j::Union{Nothing,Float64}
    temperature_perpendicular_j::Union{Nothing,Float64}
    bulk_velocity_m_s::Union{Nothing,Vector{Float64}}
    distribution_kind::Symbol
    plasma_volume_m3::Union{Nothing,Float64}
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    resolution_verified::Bool
    applicability_verified::Bool
    fidelity::Int
    source_solver_status::Symbol
    evidence_hash::String
end

"Non-compensating assessment of state completeness and its algebraic physical checks."
struct RuntimeSpeciesStateAssessmentV1
    design_id::String
    genome_physics_hash::String
    status::Symbol
    complete_required_state::Bool
    c2_state_component_authorized::Bool
    conservation_rate_authorized::Bool
    particle_inventories::Dict{String,Float64}
    mass_inventories_kg::Dict{String,Float64}
    momentum_inventories_kg_m_s::Dict{String,Vector{Float64}}
    thermal_energy_inventories_j::Dict{String,Float64}
    bulk_kinetic_energy_inventories_j::Dict{String,Float64}
    quasi_neutrality_residuals::Dict{String,Float64}
    scalar_pressure_energy_relative_errors::Dict{String,Float64}
    failed_check_ids::Vector{String}
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    assessment_hash::String
end

const _MASS_ELECTRON_KG_V1 = 9.1093837139e-31
const _ATOMIC_MASS_KG_V1 = 1.66053906892e-27

function _species_spec_v1(id, role, charge, mass_u, required)
    mass = id == "electron" ? _MASS_ELECTRON_KG_V1 :
        Float64(mass_u) * _ATOMIC_MASS_KG_V1
    return SpeciesPopulationSpecV1(String(id), role, Int(charge), mass,
        Bool(required))
end

"Fuel chemistry only defines reactants/products; it does not choose a confinement model."
function species_population_catalog_v1(fuel::AbstractString)
    normalized = uppercase(replace(String(fuel), " " => ""))
    if normalized in ("D-T", "DT")
        return SpeciesPopulationSpecV1[
            _species_spec_v1("electron", :electron, -1, 0, true),
            _species_spec_v1("deuterium", :fuel_ion, 1, 2.013553, true),
            _species_spec_v1("tritium", :fuel_ion, 1, 3.015501, true),
            _species_spec_v1("alpha", :product_ion, 2, 4.001506, false),
            _species_spec_v1("neutron", :reaction_product, 0, 1.008665, false)]
    elseif normalized in ("D-D", "DD")
        return SpeciesPopulationSpecV1[
            _species_spec_v1("electron", :electron, -1, 0, true),
            _species_spec_v1("deuterium", :fuel_ion, 1, 2.013553, true),
            _species_spec_v1("tritium", :product_ion, 1, 3.015501, false),
            _species_spec_v1("helium3", :product_ion, 2, 3.014932, false),
            _species_spec_v1("proton", :product_ion, 1, 1.007276, false),
            _species_spec_v1("neutron", :reaction_product, 0, 1.008665, false)]
    end
    return SpeciesPopulationSpecV1[
        _species_spec_v1("electron", :electron, -1, 0, true),
        _species_spec_v1("ion_unspecified", :fuel_ion, 1, 1.0, true)]
end

function _population_domain_v1(region::PlasmaRegion)
    description = lowercase("$(region.kind) $(region.geometry_model)")
    excluded = ("wall", "outside", "end_expander", "divertor", "exhaust")
    return !any(token -> occursin(token, description), excluded)
end

function _runtime_species_problem_core_v1(genome::Genome)
    topology = _topology_descriptor_v1(genome)
    domains = sort!(String[region.id for region in genome.plasma_regions
        if _population_domain_v1(region)])
    catalog = species_population_catalog_v1(genome.mission.fuel)
    anisotropy = topology.closure_class in (:open, :mixed)
    requirements = RuntimeSpeciesStateRequirementV1[]
    tasks = String[]
    fields = ["density", "temperature_parallel", "temperature_perpendicular",
        "bulk_velocity", "distribution_kind", "plasma_volume"]
    for domain in domains, species in catalog
        species.required_initial_population || continue
        push!(requirements, RuntimeSpeciesStateRequirementV1(domain, species,
            copy(fields), anisotropy))
        prefix = "$(domain):$(species.species_id)"
        append!(tasks, ["provide:$prefix:$field" for field in fields])
        anisotropy && push!(tasks, "resolve_anisotropy:$prefix")
    end
    isempty(domains) && push!(tasks, "declare_populated_plasma_domain")
    pressure_required = "pressure_profile" in _profile_inputs_v1(genome)
    pressure_required && append!(tasks,
        ["provide_independent_scalar_pressure_energy_reference:$domain"
            for domain in domains])
    return topology, domains, pressure_required, catalog, requirements,
        sort!(unique(tasks))
end

function compile_runtime_species_state_problem_v1(genome::Genome)
    _, domains, pressure_required, catalog, requirements, tasks =
        _runtime_species_problem_core_v1(genome)
    core = Dict{String,Any}(
        "compiler_version" => "runtime_species_state_compiler_v1.0.0",
        "design_id" => genome.design_id,
        "genome_physics_hash" => genome.physics_hash,
        "fuel_declaration" => genome.mission.fuel,
        "population_domain_ids" => domains,
        "scalar_pressure_reference_required" => pressure_required,
        "species_catalog" => [species_population_to_dict_v1(x) for x in catalog],
        "requirements" => [runtime_species_requirement_to_dict_v1(x)
            for x in requirements],
        "evidence_tasks" => tasks)
    return RuntimeSpeciesStateProblemV1(
        "runtime_species_state_compiler_v1.0.0", genome.design_id,
        genome.physics_hash, genome.mission.fuel, domains, pressure_required, catalog,
        requirements, tasks, canonical_hash(core))
end

"Parse a schema-conforming overlay without deriving missing moments from pressure."
function parse_runtime_species_state_overlay_v1(
        problem::RuntimeSpeciesStateProblemV1, raw)
    data = _plain_json(raw)
    String(_required(data, "schema_version", "runtime_species_state_overlay")) ==
        "1.0.0" || throw(ArgumentError("unsupported runtime species overlay version"))
    String(_required(data, "design_id", "runtime_species_state_overlay")) ==
        problem.design_id || throw(ArgumentError("runtime species overlay design mismatch"))
    String(_required(data, "genome_physics_hash", "runtime_species_state_overlay")) ==
        problem.genome_physics_hash || throw(ArgumentError(
            "runtime species overlay Genome hash mismatch"))
    states = RuntimeSpeciesStateEvidenceV1[]
    for (index, item) in enumerate(_required(data, "states",
            "runtime_species_state_overlay"))
        context = "runtime_species_state_overlay.states[$index]"
        push!(states, compile_runtime_species_state_evidence_v1(
            design_id = problem.design_id,
            genome_physics_hash = problem.genome_physics_hash,
            domain_id = String(_required(item, "domain_id", context)),
            species_id = String(_required(item, "species_id", context)),
            density_m3 = get(item, "density_m3", nothing),
            temperature_parallel_j = get(item, "temperature_parallel_j", nothing),
            temperature_perpendicular_j = get(item,
                "temperature_perpendicular_j", nothing),
            bulk_velocity_m_s = get(item, "bulk_velocity_m_s", nothing),
            distribution_kind = Symbol(_required(item, "distribution_kind", context)),
            plasma_volume_m3 = get(item, "plasma_volume_m3", nothing),
            source_kind = Symbol(_required(item, "source_kind", context)),
            source_artifact_id = String(_required(item, "source_artifact_id", context)),
            source_artifact_hash = String(_required(item, "source_artifact_hash", context)),
            source_result_hash = String(_required(item, "source_result_hash", context)),
            candidate_binding_verified = Bool(_required(item,
                "candidate_binding_verified", context)),
            resolution_verified = Bool(_required(item,
                "resolution_verified", context)),
            applicability_verified = Bool(_required(item,
                "applicability_verified", context)),
            fidelity = Int(_required(item, "fidelity", context)),
            source_solver_status = Symbol(_required(item,
                "source_solver_status", context))))
    end
    return states
end

function load_runtime_species_state_overlay_v1(
        problem::RuntimeSpeciesStateProblemV1, path::AbstractString)
    return parse_runtime_species_state_overlay_v1(problem,
        JSON3.read(read(path, String), Dict{String,Any}))
end

function _optional_finite_species_value_v1(value, id)
    value === nothing && return nothing
    result = Float64(value)
    isfinite(result) || throw(ArgumentError("$id must be finite or nothing"))
    return result
end

function compile_runtime_species_state_evidence_v1(;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        domain_id::AbstractString, species_id::AbstractString,
        density_m3 = nothing, temperature_parallel_j = nothing,
        temperature_perpendicular_j = nothing, bulk_velocity_m_s = nothing,
        distribution_kind::Symbol = :unknown, plasma_volume_m3 = nothing,
        source_kind::Symbol = :structural,
        source_artifact_id::AbstractString = "",
        source_artifact_hash::AbstractString = "",
        source_result_hash::AbstractString = "",
        candidate_binding_verified::Bool = false,
        resolution_verified::Bool = false,
        applicability_verified::Bool = false, fidelity::Integer = 0,
        source_solver_status::Symbol = :unknown)
    distribution_kind in _SPECIES_DISTRIBUTIONS_V1 ||
        throw(ArgumentError("unsupported distribution kind"))
    source_solver_status in _SPECIES_EVIDENCE_STATUSES_V1 ||
        throw(ArgumentError("invalid species evidence status"))
    source_kind in _SPECIES_SOURCE_KINDS_V1 ||
        throw(ArgumentError("invalid species evidence source kind"))
    fidelity >= 0 || throw(ArgumentError("fidelity must be non-negative"))
    density = _optional_finite_species_value_v1(density_m3, "density_m3")
    tpar = _optional_finite_species_value_v1(temperature_parallel_j,
        "temperature_parallel_j")
    tperp = _optional_finite_species_value_v1(temperature_perpendicular_j,
        "temperature_perpendicular_j")
    volume = _optional_finite_species_value_v1(plasma_volume_m3,
        "plasma_volume_m3")
    velocity = bulk_velocity_m_s === nothing ? nothing : Float64.(bulk_velocity_m_s)
    velocity === nothing || (length(velocity) == 3 && all(isfinite, velocity)) ||
        throw(ArgumentError("bulk velocity must contain three finite components"))
    core = Dict{String,Any}(
        "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id), "species_id" => String(species_id),
        "density_m3" => density, "temperature_parallel_j" => tpar,
        "temperature_perpendicular_j" => tperp,
        "bulk_velocity_m_s" => velocity,
        "distribution_kind" => String(distribution_kind),
        "plasma_volume_m3" => volume,
        "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified,
        "applicability_verified" => applicability_verified,
        "fidelity" => Int(fidelity),
        "source_solver_status" => String(source_solver_status))
    return RuntimeSpeciesStateEvidenceV1(String(design_id),
        String(genome_physics_hash), String(domain_id), String(species_id),
        density, tpar, tperp, velocity, distribution_kind, volume,
        source_kind, String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified,
        resolution_verified, applicability_verified, Int(fidelity), source_solver_status,
        canonical_hash(core))
end

function _species_evidence_complete_v1(item::RuntimeSpeciesStateEvidenceV1)
    return item.density_m3 !== nothing && item.temperature_parallel_j !== nothing &&
        item.temperature_perpendicular_j !== nothing &&
        item.bulk_velocity_m_s !== nothing && item.distribution_kind != :unknown &&
        item.plasma_volume_m3 !== nothing
end

function _species_evidence_authoritative_v1(item::RuntimeSpeciesStateEvidenceV1)
    provenance = !isempty(item.source_artifact_id) &&
        length(item.source_artifact_hash) == 64 &&
        length(item.source_result_hash) == 64
    return provenance && item.candidate_binding_verified && item.fidelity >= 2 &&
        item.resolution_verified && item.applicability_verified &&
        item.source_kind in (:candidate_solver, :measured) &&
        item.source_solver_status == :pass
end

function assess_runtime_species_state_v1(problem::RuntimeSpeciesStateProblemV1,
        evidence::AbstractVector{RuntimeSpeciesStateEvidenceV1};
        reference_scalar_mhd_energy_j::AbstractDict = Dict{String,Float64}(),
        quasi_neutrality_limit::Real = 1.0e-6,
        pressure_energy_relative_limit::Real = 0.05)
    qlimit = Float64(quasi_neutrality_limit)
    plimit = Float64(pressure_energy_relative_limit)
    0.0 <= qlimit < 1.0 || throw(ArgumentError("invalid quasi-neutrality limit"))
    0.0 <= plimit < 1.0 || throw(ArgumentError("invalid pressure-energy limit"))
    by_key = Dict{Tuple{String,String},RuntimeSpeciesStateEvidenceV1}()
    tasks = String[]
    failures = String[]
    warnings = String[
        "Static particle and thermal-energy inventories are state components, not time derivatives, fluxes, confinement times, balance rates, or powers."]
    for item in evidence
        item.design_id == problem.design_id || throw(ArgumentError(
            "species evidence design mismatch"))
        item.genome_physics_hash == problem.genome_physics_hash ||
            throw(ArgumentError("species evidence Genome hash mismatch"))
        key = (item.domain_id, item.species_id)
        haskey(by_key, key) && throw(ArgumentError("duplicate species evidence for $key"))
        by_key[key] = item
    end
    inventories = Dict{String,Float64}()
    masses = Dict{String,Float64}()
    momenta = Dict{String,Vector{Float64}}()
    energies = Dict{String,Float64}()
    bulk_energies = Dict{String,Float64}()
    qresiduals = Dict{String,Float64}()
    perrors = Dict{String,Float64}()
    all_complete = true
    all_authoritative = true
    required_by_domain = Dict{String,Vector{RuntimeSpeciesStateRequirementV1}}()
    for requirement in problem.requirements
        push!(get!(required_by_domain, requirement.domain_id,
            RuntimeSpeciesStateRequirementV1[]), requirement)
        key = (requirement.domain_id, requirement.species.species_id)
        prefix = "$(key[1]):$(key[2])"
        if !haskey(by_key, key)
            all_complete = false
            all_authoritative = false
            push!(tasks, "provide_required_species_state:$prefix")
            continue
        end
        item = by_key[key]
        complete = _species_evidence_complete_v1(item)
        authoritative = _species_evidence_authoritative_v1(item)
        all_complete &= complete
        all_authoritative &= authoritative
        complete || push!(tasks, "complete_species_state:$prefix")
        authoritative || push!(tasks, "raise_species_state_to_candidate_bound_c2:$prefix")
        if complete
            density = something(item.density_m3)
            tpar = something(item.temperature_parallel_j)
            tperp = something(item.temperature_perpendicular_j)
            volume = something(item.plasma_volume_m3)
            if density <= 0 || tpar <= 0 || tperp <= 0 || volume <= 0
                authoritative ? push!(failures, "positive_state:$prefix") :
                    push!(tasks, "resolve_nonpositive_state:$prefix")
                continue
            end
            requirement.anisotropy_resolution_required &&
                item.distribution_kind == :maxwellian && push!(warnings,
                    "Open/mixed topology $prefix declares isotropy; anisotropic applicability must be demonstrated by the source solver.")
            inventory_key = "$prefix:particle_inventory"
            mass_key = "$prefix:mass_inventory"
            momentum_key = "$prefix:momentum_inventory"
            energy_key = "$prefix:thermal_energy"
            bulk_energy_key = "$prefix:bulk_kinetic_energy"
            particle_inventory = density * volume
            mass_inventory = particle_inventory * requirement.species.mass_kg
            velocity = something(item.bulk_velocity_m_s)
            inventories[inventory_key] = particle_inventory
            masses[mass_key] = mass_inventory
            momenta[momentum_key] = mass_inventory .* velocity
            energies[energy_key] = particle_inventory * (tpar / 2 + tperp)
            bulk_energies[bulk_energy_key] = 0.5 * mass_inventory * dot(velocity, velocity)
        end
    end
    for (domain, requirements) in required_by_domain
        items = RuntimeSpeciesStateEvidenceV1[]
        specs = SpeciesPopulationSpecV1[]
        ready = true
        authoritative = true
        for requirement in requirements
            key = (domain, requirement.species.species_id)
            if !haskey(by_key, key) || !_species_evidence_complete_v1(by_key[key])
                ready = false
                break
            end
            push!(items, by_key[key]); push!(specs, requirement.species)
            authoritative &= _species_evidence_authoritative_v1(by_key[key])
        end
        ready || continue
        charge = sum(spec.charge_number * something(item.density_m3)
            for (spec, item) in zip(specs, items))
        charge_scale = sum(abs(spec.charge_number * something(item.density_m3))
            for (spec, item) in zip(specs, items))
        qres = abs(charge) / max(charge_scale, 1.0e-300)
        qresiduals[domain] = qres
        if qres > qlimit
            authoritative ? push!(failures, "quasi_neutrality:$domain") :
                push!(tasks, "resolve_quasi_neutrality:$domain")
        end
        if haskey(reference_scalar_mhd_energy_j, domain)
            reference = Float64(reference_scalar_mhd_energy_j[domain])
            reference > 0 || throw(ArgumentError("reference energy must be positive"))
            calculated = sum(get(energies,
                "$domain:$(spec.species_id):thermal_energy", 0.0) for spec in specs)
            error = abs(calculated - reference) / reference
            perrors[domain] = error
            if error > plimit
                authoritative ? push!(failures,
                    "scalar_pressure_energy_consistency:$domain") :
                    push!(tasks, "resolve_scalar_pressure_energy_consistency:$domain")
            end
        elseif problem.scalar_pressure_reference_required
            push!(tasks, "provide_independent_scalar_pressure_energy_reference:$domain")
        end
    end
    references_complete = !problem.scalar_pressure_reference_required ||
        length(perrors) == length(required_by_domain)
    status = !isempty(failures) ? :fail :
        all_complete && all_authoritative &&
            length(qresiduals) == length(required_by_domain) &&
            references_complete ? :pass : :unknown
    c2 = status == :pass
    tasks = sort!(unique(tasks))
    failures = sort!(unique(failures))
    core = Dict{String,Any}(
        "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash,
        "evidence_hashes" => sort!(getfield.(collect(evidence), :evidence_hash)),
        "status" => String(status), "complete_required_state" => all_complete,
        "c2_state_component_authorized" => c2,
        "conservation_rate_authorized" => false,
        "particle_inventories" => inventories,
        "mass_inventories_kg" => masses,
        "momentum_inventories_kg_m_s" => momenta,
        "thermal_energy_inventories_j" => energies,
        "bulk_kinetic_energy_inventories_j" => bulk_energies,
        "quasi_neutrality_residuals" => qresiduals,
        "scalar_pressure_energy_relative_errors" => perrors,
        "failed_check_ids" => failures, "evidence_tasks" => tasks,
        "warnings" => warnings)
    return RuntimeSpeciesStateAssessmentV1(problem.design_id,
        problem.genome_physics_hash, status, all_complete, c2, false,
        inventories, masses, momenta, energies, bulk_energies, qresiduals,
        perrors, failures, tasks, warnings,
        canonical_hash(core))
end

species_population_to_dict_v1(item::SpeciesPopulationSpecV1) = Dict{String,Any}(
    "species_id" => item.species_id, "role" => String(item.role),
    "charge_number" => item.charge_number, "mass_kg" => item.mass_kg,
    "required_initial_population" => item.required_initial_population)

runtime_species_requirement_to_dict_v1(item::RuntimeSpeciesStateRequirementV1) =
    Dict{String,Any}("domain_id" => item.domain_id,
        "species" => species_population_to_dict_v1(item.species),
        "required_field_ids" => item.required_field_ids,
        "anisotropy_resolution_required" => item.anisotropy_resolution_required)

function runtime_species_state_problem_to_dict_v1(item::RuntimeSpeciesStateProblemV1)
    return Dict{String,Any}(
        "compiler_version" => item.compiler_version, "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "fuel_declaration" => item.fuel_declaration,
        "population_domain_ids" => item.population_domain_ids,
        "scalar_pressure_reference_required" => item.scalar_pressure_reference_required,
        "species_catalog" => [species_population_to_dict_v1(x) for x in item.species_catalog],
        "requirements" => [runtime_species_requirement_to_dict_v1(x) for x in item.requirements],
        "evidence_tasks" => item.evidence_tasks, "problem_hash" => item.problem_hash)
end

"Bridge only authoritative static inventories into transport; no rate is synthesized."
function runtime_species_state_transport_inventory_evidence_v1(
        problem::TransportLossProblemV1,
        assessment::RuntimeSpeciesStateAssessmentV1;
        source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString)
    problem.design_id == assessment.design_id || throw(ArgumentError(
        "species-state/transport design mismatch"))
    problem.genome_physics_hash == assessment.genome_physics_hash ||
        throw(ArgumentError("species-state/transport Genome hash mismatch"))
    assessment.c2_state_component_authorized || return TransportLossEvidenceV1[]
    particle = sum(values(assessment.particle_inventories); init = 0.0)
    energy = sum(values(assessment.thermal_energy_inventories_j); init = 0.0)
    return TransportLossEvidenceV1[
        compile_transport_loss_evidence_v1(problem; metric_id = "particle_inventory",
            value = particle, unit = "1", source_kind = :candidate_solver,
            source_artifact_id = source_artifact_id,
            source_artifact_hash = source_artifact_hash,
            source_result_hash = assessment.assessment_hash,
            candidate_binding_verified = true, resolution_verified = true,
            applicability_verified = true, fidelity = 2,
            source_result_status = :pass),
        compile_transport_loss_evidence_v1(problem;
            metric_id = "thermal_energy_inventory", value = energy, unit = "J",
            source_kind = :candidate_solver, source_artifact_id = source_artifact_id,
            source_artifact_hash = source_artifact_hash,
            source_result_hash = assessment.assessment_hash,
            candidate_binding_verified = true, resolution_verified = true,
            applicability_verified = true, fidelity = 2,
            source_result_status = :pass)]
end

function runtime_species_state_evidence_to_dict_v1(item::RuntimeSpeciesStateEvidenceV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "species_id" => item.species_id,
        "density_m3" => item.density_m3,
        "temperature_parallel_j" => item.temperature_parallel_j,
        "temperature_perpendicular_j" => item.temperature_perpendicular_j,
        "bulk_velocity_m_s" => item.bulk_velocity_m_s,
        "distribution_kind" => String(item.distribution_kind),
        "plasma_volume_m3" => item.plasma_volume_m3,
        "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_verified" => item.resolution_verified,
        "applicability_verified" => item.applicability_verified,
        "fidelity" => item.fidelity, "source_solver_status" => String(item.source_solver_status),
        "evidence_hash" => item.evidence_hash)
end

function runtime_species_state_assessment_to_dict_v1(item::RuntimeSpeciesStateAssessmentV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "status" => String(item.status), "complete_required_state" => item.complete_required_state,
        "c2_state_component_authorized" => item.c2_state_component_authorized,
        "conservation_rate_authorized" => item.conservation_rate_authorized,
        "particle_inventories" => item.particle_inventories,
        "mass_inventories_kg" => item.mass_inventories_kg,
        "momentum_inventories_kg_m_s" => item.momentum_inventories_kg_m_s,
        "thermal_energy_inventories_j" => item.thermal_energy_inventories_j,
        "bulk_kinetic_energy_inventories_j" =>
            item.bulk_kinetic_energy_inventories_j,
        "quasi_neutrality_residuals" => item.quasi_neutrality_residuals,
        "scalar_pressure_energy_relative_errors" => item.scalar_pressure_energy_relative_errors,
        "failed_check_ids" => item.failed_check_ids, "evidence_tasks" => item.evidence_tasks,
        "warnings" => item.warnings, "assessment_hash" => item.assessment_hash)
end
