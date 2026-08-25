const _COUPLED_BALANCE_SOURCE_KINDS_V1 = Set((:candidate_solver, :measured,
    :proxy, :manufactured, :structural))
const _COUPLED_BALANCE_EVIDENCE_STATUSES_V1 = Set((:pass, :fail, :unknown,
    :error))
const _COUPLED_BALANCE_SIDES_V1 = Set((:storage, :source, :loss,
    :signed_exchange))

"One required rate in a compiler-generated particle or thermal-energy balance."
struct CoupledPlasmaBalanceTermV1
    term_id::String
    equation_id::String
    domain_id::String
    species_id::String
    conserved_quantity::Symbol
    side::Symbol
    unit::String
    mechanism_class::Symbol
    description::String
    upstream_component_ids::Vector{String}
end

"One domain/species balance assembled from physical topology rather than a family label."
struct CoupledPlasmaBalanceEquationV1
    equation_id::String
    domain_id::String
    species_id::String
    conserved_quantity::Symbol
    unit::String
    term_ids::Vector{String}
end

"Candidate-specific state/power balance problem that joins state, reaction, and transport obligations."
struct CoupledPlasmaBalanceProblemV1
    compiler_version::String
    design_id::String
    genome_physics_hash::String
    fuel_declaration::String
    operating_mode::String
    population_domain_ids::Vector{String}
    required_initial_species_ids::Vector{String}
    has_open_field_regions::Bool
    has_closed_field_regions::Bool
    equations::Vector{CoupledPlasmaBalanceEquationV1}
    terms::Vector{CoupledPlasmaBalanceTermV1}
    source_ids::Vector{String}
    evidence_tasks::Vector{String}
    claim_ceiling::String
    problem_hash::String
end

"Numeric candidate-bound value for one exact compiler-generated rate term."
struct CoupledPlasmaBalanceTermEvidenceV1
    design_id::String
    genome_physics_hash::String
    problem_hash::String
    term_id::String
    value::Union{Nothing,Float64}
    unit::String
    source_kind::Symbol
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    resolution_verified::Bool
    applicability_verified::Bool
    fidelity::Int
    source_result_status::Symbol
    c2_term_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    evidence_hash::String
end

"Residual and evidence-completeness result for the coupled candidate balance."
struct CoupledPlasmaBalanceAssessmentV1
    design_id::String
    genome_physics_hash::String
    problem_hash::String
    required_term_count::Int
    observed_term_count::Int
    c2_authorized_term_count::Int
    equation_statuses::Dict{String,Symbol}
    equation_residuals::Dict{String,Union{Nothing,Float64}}
    equation_relative_residuals::Dict{String,Union{Nothing,Float64}}
    passed_equation_ids::Vector{String}
    failed_equation_ids::Vector{String}
    unknown_equation_ids::Vector{String}
    status::Symbol
    complete_c2_balance_authorized::Bool
    promotion_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    assessment_hash::String
end

function _coupled_balance_term_v1(equation_id, domain_id, species_id,
        quantity, side, mechanism, description, upstream)
    side in _COUPLED_BALANCE_SIDES_V1 || throw(ArgumentError(
        "invalid coupled-balance term side"))
    unit = quantity == :particle ? "s^-1" : "W"
    term_id = "$(equation_id)::$(mechanism)"
    return CoupledPlasmaBalanceTermV1(term_id, String(equation_id),
        String(domain_id), String(species_id), quantity, side, unit, mechanism,
        String(description), sort!(unique(String.(upstream))))
end

function _coupled_particle_terms_v1(domain_id::String,
        species::SpeciesPopulationSpecV1, has_open::Bool, has_reactions::Bool)
    equation_id = "particle|$domain_id|$(species.species_id)"
    terms = CoupledPlasmaBalanceTermV1[
        _coupled_balance_term_v1(equation_id, domain_id, species.species_id,
            :particle, :storage, :particle_storage_rate,
            "Time derivative of the candidate-bound species inventory.",
            ["runtime_species_state"]),
        _coupled_balance_term_v1(equation_id, domain_id, species.species_id,
            :particle, :source, :external_particle_source,
            "Fueling, ionization, recycling, or other declared volumetric particle source.",
            ["runtime_species_state", "source_loss_terms"]),
        _coupled_balance_term_v1(equation_id, domain_id, species.species_id,
            :particle, :loss, :cross_field_particle_boundary_flux,
            "Integrated cross-field particle flux through the declared control-volume boundary.",
            ["cross_field_particle_flux"]),
        _coupled_balance_term_v1(equation_id, domain_id, species.species_id,
            :particle, :loss, :orbit_wall_particle_loss,
            "Integrated finite-orbit particle interception by declared material domains.",
            ["orbit_wall_loss_fraction", "particle_inventory"])]
    if species.charge_number > 0
        push!(terms, _coupled_balance_term_v1(equation_id, domain_id,
            species.species_id, :particle, :loss,
            :charge_exchange_particle_loss,
            "Charge-exchange removal rate using candidate neutral and ion state.",
            ["charge_exchange_particle_loss_rate"]))
    end
    if species.role == :fuel_ion && has_reactions
        push!(terms, _coupled_balance_term_v1(equation_id, domain_id,
            species.species_id, :particle, :loss,
            :fusion_reaction_particle_sink,
            "Reactant consumption integrated from the candidate reaction-rate field.",
            ["fusion_reaction_rates"]))
    end
    if has_open
        push!(terms, _coupled_balance_term_v1(equation_id, domain_id,
            species.species_id, :particle, :loss,
            :parallel_particle_boundary_flux,
            "Species-resolved parallel flux through every open material or plasma boundary.",
            ["parallel_particle_boundary_flux", "open_field_connection_length"]))
    end
    return equation_id, terms
end

function _coupled_energy_terms_v1(domain_id::String, has_open::Bool,
        has_reactions::Bool)
    equation_id = "thermal_energy|$domain_id|all_plasma"
    terms = CoupledPlasmaBalanceTermV1[
        _coupled_balance_term_v1(equation_id, domain_id, "all_plasma",
            :thermal_energy, :storage, :thermal_energy_storage_rate,
            "Time derivative of species thermal plus resolved bulk kinetic energy.",
            ["runtime_species_state", "thermal_energy_inventory"]),
        _coupled_balance_term_v1(equation_id, domain_id, "all_plasma",
            :thermal_energy, :source, :external_heating_deposition,
            "Power actually deposited in the plasma by declared RF, beam, electrode, or other actuators.",
            ["actuator_deposition", "source_loss_terms"]),
        _coupled_balance_term_v1(equation_id, domain_id, "all_plasma",
            :thermal_energy, :signed_exchange,
            :electromagnetic_and_compressional_work,
            "Signed electromagnetic, inductive, viscous, and compressional work on the plasma.",
            ["momentum_balance", "current_balance", "source_loss_terms"]),
        _coupled_balance_term_v1(equation_id, domain_id, "all_plasma",
            :thermal_energy, :loss, :total_radiation_power_loss,
            "Complete applicable bremsstrahlung, line, recombination, cyclotron, synchrotron, and neutral radiation.",
            ["radiation_power_loss", "complete_radiation"]),
        _coupled_balance_term_v1(equation_id, domain_id, "all_plasma",
            :thermal_energy, :loss, :cross_field_energy_boundary_flux,
            "Integrated cross-field conductive and convective energy flux through the control-volume boundary.",
            ["cross_field_energy_flux"]),
        _coupled_balance_term_v1(equation_id, domain_id, "all_plasma",
            :thermal_energy, :loss, :orbit_wall_energy_loss,
            "Kinetic energy carried by finite-orbit particles intercepted by material domains.",
            ["orbit_wall_loss_fraction", "thermal_energy_inventory"]),
        _coupled_balance_term_v1(equation_id, domain_id, "all_plasma",
            :thermal_energy, :loss, :charge_exchange_energy_loss,
            "Energy carried out by charge-exchange neutrals and related atomic channels.",
            ["charge_exchange_particle_loss_rate", "runtime_species_state"])]
    if has_reactions
        push!(terms, _coupled_balance_term_v1(equation_id, domain_id,
            "all_plasma", :thermal_energy, :source,
            :charged_fusion_product_deposition,
            "Charged fusion-product power actually deposited before product escape; neutron power is excluded.",
            ["charged_fusion_power", "charged_product_orbit_deposition"]))
    end
    if has_open
        push!(terms, _coupled_balance_term_v1(equation_id, domain_id,
            "all_plasma", :thermal_energy, :loss,
            :parallel_energy_boundary_flux,
            "Integrated species-resolved parallel energy flux through every open boundary.",
            ["parallel_energy_boundary_flux", "open_field_connection_length"]))
    end
    return equation_id, terms
end

"Compile particle and total thermal-energy residuals from topology-selected mechanisms."
function compile_coupled_plasma_balance_problem_v1(genome::Genome)
    state_problem = compile_runtime_species_state_problem_v1(genome)
    reaction_problem = compile_fusion_reaction_radiation_problem_v1(genome)
    transport_problem = compile_transport_loss_problem_v1(genome)
    initial_species = sort!([item for item in state_problem.species_catalog if
        item.required_initial_population]; by = item -> item.species_id)
    equations = CoupledPlasmaBalanceEquationV1[]
    terms = CoupledPlasmaBalanceTermV1[]
    has_reactions = !isempty(reaction_problem.channels)
    for domain_id in state_problem.population_domain_ids
        for species in initial_species
            equation_id, local_terms = _coupled_particle_terms_v1(domain_id,
                species, transport_problem.has_open_field_regions, has_reactions)
            append!(terms, local_terms)
            push!(equations, CoupledPlasmaBalanceEquationV1(equation_id,
                domain_id, species.species_id, :particle, "s^-1",
                getfield.(local_terms, :term_id)))
        end
        equation_id, local_terms = _coupled_energy_terms_v1(domain_id,
            transport_problem.has_open_field_regions, has_reactions)
        append!(terms, local_terms)
        push!(equations, CoupledPlasmaBalanceEquationV1(equation_id,
            domain_id, "all_plasma", :thermal_energy, "W",
            getfield.(local_terms, :term_id)))
    end
    tasks = sort!(String["solve_coupled_balance_term:$(item.term_id)"
        for item in terms])
    core = Dict{String,Any}(
        "compiler_version" => "coupled_plasma_balance_compiler_v1.0.0",
        "design_id" => genome.design_id,
        "genome_physics_hash" => genome.physics_hash,
        "fuel_declaration" => genome.mission.fuel,
        "operating_mode" => genome.mission.operating_mode,
        "population_domain_ids" => state_problem.population_domain_ids,
        "required_initial_species_ids" => getfield.(initial_species, :species_id),
        "has_open_field_regions" => transport_problem.has_open_field_regions,
        "has_closed_field_regions" => transport_problem.has_closed_field_regions,
        "equations" => coupled_plasma_balance_equation_to_dict_v1.(equations),
        "terms" => coupled_plasma_balance_term_to_dict_v1.(terms),
        "source_ids" => ["process_physics_2015", "bosch_hale_reactivity_1992"],
        "evidence_tasks" => tasks,
        "claim_ceiling" => "C2_coupled_particle_and_plasma_energy_balance_component_only")
    return CoupledPlasmaBalanceProblemV1(
        "coupled_plasma_balance_compiler_v1.0.0", genome.design_id,
        genome.physics_hash, genome.mission.fuel, genome.mission.operating_mode,
        state_problem.population_domain_ids, getfield.(initial_species, :species_id),
        transport_problem.has_open_field_regions,
        transport_problem.has_closed_field_regions, equations, terms,
        ["process_physics_2015", "bosch_hale_reactivity_1992"], tasks,
        "C2_coupled_particle_and_plasma_energy_balance_component_only",
        canonical_hash(core))
end

function _coupled_term_lookup_v1(problem::CoupledPlasmaBalanceProblemV1,
        term_id::AbstractString)
    index = findfirst(item -> item.term_id == term_id, problem.terms)
    index === nothing && throw(ArgumentError(
        "term is not required by the coupled balance problem: $term_id"))
    return problem.terms[index]
end

function _coupled_authoritative_provenance_v1(source_kind, source_status,
        candidate_binding, resolution, applicability, fidelity,
        source_artifact_id, source_artifact_hash, source_result_hash)
    provenance = !isempty(source_artifact_id) &&
        length(source_artifact_hash) == 64 && length(source_result_hash) == 64
    return provenance && source_kind in (:candidate_solver, :measured) &&
        source_status in (:pass, :fail) && candidate_binding && resolution &&
        applicability && fidelity >= 2
end

"Compile one exact rate without allowing a proxy or manufactured value to receive C2."
function compile_coupled_plasma_balance_term_evidence_v1(
        problem::CoupledPlasmaBalanceProblemV1; term_id::AbstractString,
        value = nothing, unit::AbstractString,
        source_kind::Symbol, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        candidate_binding_verified::Bool, resolution_verified::Bool,
        applicability_verified::Bool, fidelity::Integer,
        source_result_status::Symbol)
    requirement = _coupled_term_lookup_v1(problem, term_id)
    String(unit) == requirement.unit || throw(ArgumentError(
        "coupled balance evidence unit mismatch"))
    source_kind in _COUPLED_BALANCE_SOURCE_KINDS_V1 || throw(ArgumentError(
        "invalid coupled balance evidence source kind"))
    source_result_status in _COUPLED_BALANCE_EVIDENCE_STATUSES_V1 ||
        throw(ArgumentError("invalid coupled balance evidence status"))
    fidelity >= 0 || throw(ArgumentError("fidelity must be non-negative"))
    numeric = value === nothing ? nothing : Float64(value)
    numeric === nothing || isfinite(numeric) || throw(ArgumentError(
        "coupled balance evidence value must be finite"))
    if numeric !== nothing && requirement.side in (:source, :loss) && numeric < 0.0
        throw(ArgumentError("source and loss rates must be non-negative"))
    end
    tasks = String[]
    warnings = String[]
    isempty(source_artifact_id) && push!(tasks,
        "provide_source_artifact_id:$(requirement.term_id)")
    length(source_artifact_hash) == 64 || push!(tasks,
        "provide_source_artifact_hash:$(requirement.term_id)")
    length(source_result_hash) == 64 || push!(tasks,
        "provide_source_result_hash:$(requirement.term_id)")
    provenance = _coupled_authoritative_provenance_v1(source_kind,
        source_result_status, candidate_binding_verified, resolution_verified,
        applicability_verified, Int(fidelity), String(source_artifact_id),
        String(source_artifact_hash), String(source_result_hash))
    numeric === nothing && push!(tasks, "compute_numeric_term:$(requirement.term_id)")
    candidate_binding_verified || push!(tasks, "verify_candidate_binding:$(requirement.term_id)")
    resolution_verified || push!(tasks, "verify_resolution:$(requirement.term_id)")
    applicability_verified || push!(tasks, "verify_applicability:$(requirement.term_id)")
    fidelity >= 2 || push!(tasks, "raise_fidelity:$(requirement.term_id)")
    source_kind in (:proxy, :manufactured, :structural) && push!(warnings,
        "Proxy, manufactured, and structural values receive zero C2 balance authority.")
    authorized = provenance && source_result_status == :pass && numeric !== nothing
    core = Dict{String,Any}(
        "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash,
        "term_id" => requirement.term_id, "value" => numeric,
        "unit" => requirement.unit, "source_kind" => String(source_kind),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "resolution_verified" => resolution_verified,
        "applicability_verified" => applicability_verified,
        "fidelity" => Int(fidelity),
        "source_result_status" => String(source_result_status),
        "c2_term_authorized" => authorized,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return CoupledPlasmaBalanceTermEvidenceV1(problem.design_id,
        problem.genome_physics_hash, problem.problem_hash, requirement.term_id,
        numeric, requirement.unit, source_kind, String(source_artifact_id),
        String(source_artifact_hash), String(source_result_hash),
        candidate_binding_verified, resolution_verified, applicability_verified,
        Int(fidelity), source_result_status, authorized, sort!(unique(tasks)),
        warnings, canonical_hash(core))
end

function _coupled_signed_value_v1(term::CoupledPlasmaBalanceTermV1,
        value::Float64)
    term.side == :storage && return value
    term.side == :source && return -value
    term.side == :loss && return value
    term.side == :signed_exchange && return -value
    error("unreachable coupled balance side")
end

"Assess all equations independently; missing or non-authoritative terms remain unknown."
function assess_coupled_plasma_balance_v1(problem::CoupledPlasmaBalanceProblemV1,
        evidence::AbstractVector{CoupledPlasmaBalanceTermEvidenceV1};
        relative_residual_limit::Real = 1.0e-6,
        absolute_residual_floor::Real = 1.0e-12)
    limit = Float64(relative_residual_limit)
    floor = Float64(absolute_residual_floor)
    isfinite(limit) && limit >= 0.0 || throw(ArgumentError(
        "relative residual limit must be finite and non-negative"))
    isfinite(floor) && floor > 0.0 || throw(ArgumentError(
        "absolute residual floor must be finite and positive"))
    by_id = Dict{String,CoupledPlasmaBalanceTermEvidenceV1}()
    for item in evidence
        item.design_id == problem.design_id || throw(ArgumentError(
            "coupled balance evidence design mismatch"))
        item.genome_physics_hash == problem.genome_physics_hash ||
            throw(ArgumentError("coupled balance evidence Genome hash mismatch"))
        item.problem_hash == problem.problem_hash || throw(ArgumentError(
            "coupled balance evidence problem hash mismatch"))
        _coupled_term_lookup_v1(problem, item.term_id)
        haskey(by_id, item.term_id) && throw(ArgumentError(
            "duplicate coupled balance evidence for $(item.term_id)"))
        by_id[item.term_id] = item
    end
    term_by_id = Dict(item.term_id => item for item in problem.terms)
    statuses = Dict{String,Symbol}()
    residuals = Dict{String,Union{Nothing,Float64}}()
    relative_residuals = Dict{String,Union{Nothing,Float64}}()
    tasks = String[]
    passed = String[]
    failed = String[]
    unknown = String[]
    for equation in problem.equations
        items = [by_id[id] for id in equation.term_ids if haskey(by_id, id)]
        authoritative_failure = any(item ->
            _coupled_authoritative_provenance_v1(item.source_kind,
                item.source_result_status, item.candidate_binding_verified,
                item.resolution_verified, item.applicability_verified,
                item.fidelity, item.source_artifact_id,
                item.source_artifact_hash, item.source_result_hash) &&
                item.source_result_status == :fail, items)
        complete = length(items) == length(equation.term_ids) &&
            all(item -> item.c2_term_authorized, items)
        if authoritative_failure
            statuses[equation.equation_id] = :fail
            residuals[equation.equation_id] = nothing
            relative_residuals[equation.equation_id] = nothing
            push!(failed, equation.equation_id)
            push!(tasks, "resolve_failed_coupled_balance:$(equation.equation_id)")
        elseif complete
            values = Float64[something(by_id[id].value) for id in equation.term_ids]
            residual = sum(_coupled_signed_value_v1(term_by_id[id], value)
                for (id, value) in zip(equation.term_ids, values))
            scale = max(sum(abs, values), floor)
            relative = abs(residual) / scale
            residuals[equation.equation_id] = residual
            relative_residuals[equation.equation_id] = relative
            if relative <= limit
                statuses[equation.equation_id] = :pass
                push!(passed, equation.equation_id)
            else
                statuses[equation.equation_id] = :fail
                push!(failed, equation.equation_id)
                push!(tasks, "close_numeric_residual:$(equation.equation_id)")
            end
        else
            statuses[equation.equation_id] = :unknown
            residuals[equation.equation_id] = nothing
            relative_residuals[equation.equation_id] = nothing
            push!(unknown, equation.equation_id)
            for id in equation.term_ids
                if !haskey(by_id, id)
                    push!(tasks, "supply_coupled_balance_term:$id")
                elseif !by_id[id].c2_term_authorized
                    append!(tasks, by_id[id].evidence_tasks)
                    push!(tasks, "authorize_coupled_balance_term:$id")
                end
            end
        end
    end
    status = !isempty(failed) ? :fail : isempty(unknown) ? :pass : :unknown
    complete_c2 = status == :pass && length(passed) == length(problem.equations)
    warnings = String[
        "Passing this balance does not establish stability, complete transport-model validity, engineering feasibility, or net electric power.",
        "No empirical confinement-time expression may replace missing boundary flux or radiation evidence."]
    core = Dict{String,Any}(
        "design_id" => problem.design_id,
        "genome_physics_hash" => problem.genome_physics_hash,
        "problem_hash" => problem.problem_hash,
        "required_term_count" => length(problem.terms),
        "observed_term_count" => length(by_id),
        "c2_authorized_term_count" => count(item -> item.c2_term_authorized,
            values(by_id)),
        "equation_statuses" => Dict(k => String(v) for (k, v) in statuses),
        "equation_residuals" => residuals,
        "equation_relative_residuals" => relative_residuals,
        "passed_equation_ids" => sort!(passed),
        "failed_equation_ids" => sort!(failed),
        "unknown_equation_ids" => sort!(unknown),
        "status" => String(status),
        "complete_c2_balance_authorized" => complete_c2,
        "promotion_authorized" => false,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return CoupledPlasmaBalanceAssessmentV1(problem.design_id,
        problem.genome_physics_hash, problem.problem_hash, length(problem.terms),
        length(by_id), count(item -> item.c2_term_authorized, values(by_id)),
        statuses, residuals, relative_residuals, sort!(passed), sort!(failed),
        sort!(unknown), status, complete_c2, false, sort!(unique(tasks)),
        warnings, canonical_hash(core))
end

coupled_plasma_balance_term_to_dict_v1(item::CoupledPlasmaBalanceTermV1) =
    Dict{String,Any}("term_id" => item.term_id,
        "equation_id" => item.equation_id, "domain_id" => item.domain_id,
        "species_id" => item.species_id,
        "conserved_quantity" => String(item.conserved_quantity),
        "side" => String(item.side), "unit" => item.unit,
        "mechanism_class" => String(item.mechanism_class),
        "description" => item.description,
        "upstream_component_ids" => item.upstream_component_ids)

coupled_plasma_balance_equation_to_dict_v1(item::CoupledPlasmaBalanceEquationV1) =
    Dict{String,Any}("equation_id" => item.equation_id,
        "domain_id" => item.domain_id, "species_id" => item.species_id,
        "conserved_quantity" => String(item.conserved_quantity),
        "unit" => item.unit, "term_ids" => item.term_ids)

function coupled_plasma_balance_problem_to_dict_v1(
        item::CoupledPlasmaBalanceProblemV1)
    return Dict{String,Any}("compiler_version" => item.compiler_version,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "fuel_declaration" => item.fuel_declaration,
        "operating_mode" => item.operating_mode,
        "population_domain_ids" => item.population_domain_ids,
        "required_initial_species_ids" => item.required_initial_species_ids,
        "has_open_field_regions" => item.has_open_field_regions,
        "has_closed_field_regions" => item.has_closed_field_regions,
        "equations" => coupled_plasma_balance_equation_to_dict_v1.(item.equations),
        "terms" => coupled_plasma_balance_term_to_dict_v1.(item.terms),
        "source_ids" => item.source_ids, "evidence_tasks" => item.evidence_tasks,
        "claim_ceiling" => item.claim_ceiling, "problem_hash" => item.problem_hash)
end

function coupled_plasma_balance_term_evidence_to_dict_v1(
        item::CoupledPlasmaBalanceTermEvidenceV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "problem_hash" => item.problem_hash, "term_id" => item.term_id,
        "value" => item.value, "unit" => item.unit,
        "source_kind" => String(item.source_kind),
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_verified" => item.resolution_verified,
        "applicability_verified" => item.applicability_verified,
        "fidelity" => item.fidelity,
        "source_result_status" => String(item.source_result_status),
        "c2_term_authorized" => item.c2_term_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "evidence_hash" => item.evidence_hash)
end

function coupled_plasma_balance_assessment_to_dict_v1(
        item::CoupledPlasmaBalanceAssessmentV1)
    return Dict{String,Any}("design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "problem_hash" => item.problem_hash,
        "required_term_count" => item.required_term_count,
        "observed_term_count" => item.observed_term_count,
        "c2_authorized_term_count" => item.c2_authorized_term_count,
        "equation_statuses" => Dict(k => String(v) for (k, v) in
            item.equation_statuses),
        "equation_residuals" => item.equation_residuals,
        "equation_relative_residuals" => item.equation_relative_residuals,
        "passed_equation_ids" => item.passed_equation_ids,
        "failed_equation_ids" => item.failed_equation_ids,
        "unknown_equation_ids" => item.unknown_equation_ids,
        "status" => String(item.status),
        "complete_c2_balance_authorized" =>
            item.complete_c2_balance_authorized,
        "promotion_authorized" => item.promotion_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "assessment_hash" => item.assessment_hash)
end
