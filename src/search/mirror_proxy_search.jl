struct MirrorBeamSearchSpace
    names::Vector{String}
    lower::Vector{Float64}
    upper::Vector{Float64}

    function MirrorBeamSearchSpace(names, lower, upper)
        length(names) == length(lower) == length(upper) ||
            throw(ArgumentError("search-space arrays must have equal length"))
        all(Float64.(lower) .< Float64.(upper)) ||
            throw(ArgumentError("every search-space lower bound must be below its upper bound"))
        return new(String.(names), Float64.(lower), Float64.(upper))
    end
end

function default_mirror_beam_search_space()
    return MirrorBeamSearchSpace(
        ["central_field_T", "peak_field_T", "plasma_radius_m",
            "cell_length_m", "density_n20", "beam_energy_E100"],
        [2.5, 22.0, 0.40, 12.0, 0.55, 1.00],
        [3.4, 25.0, 0.70, 35.0, 0.95, 1.50],
    )
end

struct MirrorProxyCandidate
    genome::Genome
    parameters::Dict{String,Float64}
    evaluation::EvaluationBundle
    screening_readiness::PreparedCandidate
    performance_readiness::PreparedCandidate
end

struct MirrorProxySearchResult
    screening_archive::EvidenceParetoArchive
    space::MirrorBeamSearchSpace
    base_design_id::String
    base_physics_hash::String
    candidates::Vector{MirrorProxyCandidate}
    attempted::Int
    rejected_or_inapplicable::Int
    duplicate::Int
    random_seed::Int
    population_size::Int
    generations::Int
end

function _raw_item_by_kind(items, kind::String)
    matches = filter(item -> String(item["kind"]) == kind, items)
    length(matches) == 1 || throw(ArgumentError("expected one item of kind $kind"))
    return only(matches)
end

function _set_raw_quantity!(item, key::String, value::Float64)
    parameters = item["parameters"]
    haskey(parameters, key) || throw(ArgumentError("$(item["id"]) lacks $key"))
    parameters[key]["value"] = value
end

function _decode_parameters(space::MirrorBeamSearchSpace, unit_vector::Vector{Float64})
    length(unit_vector) == length(space.names) ||
        throw(ArgumentError("candidate dimension does not match search space"))
    values = space.lower .+ clamp.(unit_vector, 0.0, 1.0) .* (space.upper .- space.lower)
    return Dict(space.names[index] => values[index] for index in eachindex(space.names))
end

function _beam_variant(base::Genome, parameters::Dict{String,Float64},
        design_id::String)
    raw = deepcopy(base.normalized)
    raw["design_id"] = design_id
    raw["label"] = "BEAM 0-D constrained evolutionary screening candidate"
    central = _raw_item_by_kind(raw["plasma_regions"], "mirror_central_cell")
    coil = _raw_item_by_kind(raw["field_sources"], "mirror_coil")
    nbi = _raw_item_by_kind(raw["actuators"], "nbi")

    b0 = parameters["central_field_T"]
    radius = parameters["plasma_radius_m"]
    length = parameters["cell_length_m"]
    n20 = parameters["density_n20"]
    energy_100 = parameters["beam_energy_E100"]
    _set_raw_quantity!(central, "central_field", b0)
    _set_raw_quantity!(central, "plasma_radius", radius)
    _set_raw_quantity!(central, "cell_length", length)
    _set_raw_quantity!(central, "ion_density", n20 * 1.0e20)
    _set_raw_quantity!(central, "effective_plasma_volume", pi * radius^2 * length)
    _set_raw_quantity!(coil, "peak_field", parameters["peak_field_T"])
    _set_raw_quantity!(nbi, "beam_energy", energy_100 * 100.0 * 1.602176634e-16)
    _set_raw_quantity!(nbi, "injection_angle", pi / 2)
    raw["provenance"]["origin"] = "generated"
    raw["provenance"]["parent_design_ids"] = [base.design_id]
    raw["provenance"]["claim_level"] = "numerical_candidate"
    raw["provenance"]["notes"] = [
        "Generated inside the strict mirror_beam_0d_v1 proxy domain.",
        "Screening result only; not a plasma-stability or engineering concept claim.",
    ]
    return parse_genome(raw)
end

function _random_unit_vector(rng, dimension::Int)
    return rand(rng, dimension)
end

function _feasible_anchor(space::MirrorBeamSearchSpace)
    anchor = Dict(
        "central_field_T" => 2.75,
        "peak_field_T" => 25.0,
        "plasma_radius_m" => 0.50,
        "cell_length_m" => 25.0,
        "density_n20" => 0.70,
        "beam_energy_E100" => 1.00,
    )
    return [(anchor[name] - space.lower[index]) /
        (space.upper[index] - space.lower[index])
        for (index, name) in enumerate(space.names)]
end

function _offspring_unit_vector(rng, a::Vector{Float64}, b::Vector{Float64})
    alpha = rand(rng)
    child = alpha .* a .+ (1.0 - alpha) .* b
    child .+= 0.10 .* randn(rng, length(child))
    return clamp.(child, 0.0, 1.0)
end

function _evaluate_mirror_candidate(registry::EvaluatorRegistry, base::Genome,
        space::MirrorBeamSearchSpace, unit_vector::Vector{Float64}, design_id::String,
        screening_contract::ObjectiveContract, performance_contract::ObjectiveContract)
    parameters = _decode_parameters(space, unit_vector)
    genome = _beam_variant(base, parameters, design_id)
    semantic = validate_genome(genome)
    semantic.valid || throw(ArgumentError("generated genome is invalid: $(semantic.errors)"))
    bundle = evaluate_design(registry, "mirror_beam_0d_v1", genome)
    screening = prepare_candidate(genome, [bundle], screening_contract)
    performance = prepare_candidate(genome, [bundle], performance_contract)
    return MirrorProxyCandidate(genome, parameters, bundle, screening, performance)
end

"""
Run a deterministic constrained evolutionary search inside the BEAM 0-D domain.

The returned archive is a physics-proxy screening Pareto set. A second,
configuration-neutral first-principles readiness result is retained for every
candidate and is expected to reject all candidates until higher-fidelity
stability and engineering evaluators exist.
"""
function run_mirror_beam_proxy_search(base::Genome;
        space::MirrorBeamSearchSpace = default_mirror_beam_search_space(),
        population_size::Int = 32, generations::Int = 16,
        random_seed::Int = 20260810)
    population_size >= 4 || throw(ArgumentError("population_size must be at least 4"))
    generations >= 1 || throw(ArgumentError("generations must be positive"))
    applicable, reason = evaluator_applicability(MirrorBeam0DV1(), base)
    applicable || throw(ArgumentError("base design is outside BEAM domain: $reason"))
    rng = MersenneTwister(random_seed)
    registry = EvaluatorRegistry()
    register!(registry, MirrorBeam0DV1())
    screening_contract = mirror_beam_screening_contract()
    performance_contract = first_principles_discovery_contract()
    archive = EvidenceParetoArchive(screening_contract)
    candidates = MirrorProxyCandidate[]
    vectors = Dict{String,Vector{Float64}}()
    states = Dict{String,MirrorProxyCandidate}()
    seen = Set{String}()
    rejected = 0
    duplicate = 0
    attempted = 0

    for generation in 1:generations
        for index in 1:population_size
            unit_vector = if generation == 1 && index == 1
                _feasible_anchor(space)
            elseif generation == 1 || isempty(archive.tiers)
                _random_unit_vector(rng, length(space.names))
            else
                front = sort!(vcat(values(archive.tiers)...); by = item -> item.design_id)
                parent_a = rand(rng, front)
                parent_b = rand(rng, front)
                _offspring_unit_vector(rng, vectors[parent_a.design_id],
                    vectors[parent_b.design_id])
            end
            attempted += 1
            design_id = "beam_proxy_g$(lpad(generation, 3, '0'))_i$(lpad(index, 3, '0'))"
            candidate = _evaluate_mirror_candidate(registry, base, space,
                unit_vector, design_id, screening_contract, performance_contract)
            if candidate.genome.physics_hash in seen
                duplicate += 1
                continue
            end
            push!(seen, candidate.genome.physics_hash)
            push!(candidates, candidate)
            vectors[design_id] = unit_vector
            states[design_id] = candidate
            insertion = insert_candidate!(archive, candidate.screening_readiness)
            insertion.status == :rejected && (rejected += 1)
        end
    end
    sort!(candidates; by = item -> item.genome.physics_hash)
    return MirrorProxySearchResult(archive, space, base.design_id,
        base.physics_hash, candidates, attempted, rejected, duplicate,
        random_seed, population_size, generations)
end

function _metric_summary(prepared::PreparedCandidate)
    return Dict(id => Dict(
            "value" => metric.value,
            "unit" => metric.unit,
            "uncertainty" => metric.uncertainty,
            "fidelity" => metric.fidelity,
        ) for (id, metric) in prepared.objectives)
end

function _mirror_candidate_to_dict(candidate::MirrorProxyCandidate)
    return Dict{String,Any}(
        "design_id" => candidate.genome.design_id,
        "physics_hash" => candidate.genome.physics_hash,
        "parameters" => candidate.parameters,
        "screening_objectives" => _metric_summary(candidate.screening_readiness),
        "screening_evidence_signature" => candidate.screening_readiness.evidence_signature,
        "proxy_evaluation_status" => String(candidate.evaluation.status),
        "proxy_run_hash" => candidate.evaluation.run_hash,
        "first_principles_eligible" => candidate.performance_readiness.eligible,
        "first_principles_rejection_reasons" => candidate.performance_readiness.reasons,
        "genome" => candidate.genome.normalized,
    )
end

function mirror_beam_proxy_search_to_dict(result::MirrorProxySearchResult)
    front = isempty(result.screening_archive.tiers) ? PreparedCandidate[] :
        sort!(vcat(values(result.screening_archive.tiers)...);
            by = item -> item.design_id)
    by_id = Dict(candidate.genome.design_id => candidate for candidate in result.candidates)
    records = [_mirror_candidate_to_dict(by_id[item.design_id]) for item in front]
    feasible_count = count(candidate -> candidate.screening_readiness.eligible,
        result.candidates)
    return Dict{String,Any}(
        "search_version" => "mirror_beam_proxy_evolution_v1",
        "algorithm" => "constrained multi-objective evolutionary search",
        "stage" => "physics_proxy_screening",
        "claim_boundary" => "Pareto membership is valid only for the BEAM 0-D proxy equations and gates; no full stability, transport, engineering, net-power, or reactor claim.",
        "screening_contract_id" => result.screening_archive.contract.id,
        "first_principles_contract_id" => first_principles_discovery_contract().id,
        "base_design_id" => result.base_design_id,
        "base_physics_hash" => result.base_physics_hash,
        "search_space" => Dict(result.space.names[index] => Dict(
                "lower" => result.space.lower[index],
                "upper" => result.space.upper[index],
            ) for index in eachindex(result.space.names)),
        "variation" => Dict(
            "selection" => "uniform from the current nondominated proxy archive",
            "crossover" => "random arithmetic blend",
            "mutation" => "independent Gaussian in normalized coordinates",
            "mutation_sigma" => 0.10,
            "bounds_policy" => "clip to closed search bounds",
            "feasible_anchor" => Dict(
                "central_field_T" => 2.75,
                "peak_field_T" => 25.0,
                "plasma_radius_m" => 0.50,
                "cell_length_m" => 25.0,
                "density_n20" => 0.70,
                "beam_energy_E100" => 1.00,
            ),
        ),
        "random_seed" => result.random_seed,
        "population_size" => result.population_size,
        "generations" => result.generations,
        "attempted" => result.attempted,
        "unique_candidates" => length(result.candidates),
        "screening_feasible_count" => feasible_count,
        "rejected_or_inapplicable_count" => result.rejected_or_inapplicable,
        "duplicate_count" => result.duplicate,
        "pareto_count" => length(records),
        "first_principles_eligible_count" => count(record ->
            record["first_principles_eligible"], records),
        "pareto_archive" => records,
    )
end
