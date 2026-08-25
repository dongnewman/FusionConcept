struct SearchRecord
    genome::Genome
    descriptor::String
    ir_complexity::Float64
    coverage_full::Int
    coverage_proxy::Int
    coverage_missing::Int
    performance_eligible::Bool
    objective_readiness::Union{Nothing,PreparedCandidate}
    structural_evaluation::EvaluationBundle
end

mutable struct StructuralQDArchive
    cells::Dict{String,SearchRecord}
    seen_hashes::Set{String}
end

StructuralQDArchive() = StructuralQDArchive(Dict{String,SearchRecord}(), Set{String}())

struct StructuralQDResult
    archive::StructuralQDArchive
    discovered::Vector{SearchRecord}
    attempts::Int
    rejected::Int
    duplicate::Int
    random_seed::Int
    iterations::Int
    objective_contract_id::Union{Nothing,String}
end

function structural_descriptor(genome::Genome)
    actuator_bin = length(genome.actuators) == 0 ? "a0" :
        length(genome.actuators) <= 2 ? "a1_2" : "a3plus"
    transform = join(sort(genome.topology.rotation_transform_sources), "+")
    mechanisms = join(sort!(unique(getfield.(genome.stability_mechanisms, :mechanism))), "+")
    field = get(genome.mission.targets, "on_axis_field", nothing)
    field_bin = field === nothing ? "b_unspecified" :
        field.value < 8.0 ? "b_below8" : field.value < 11.0 ? "b8_11" : "b11plus"
    regime = if genome.family == "magnetic_mirror"
        cells = filter(region -> region.kind == "mirror_central_cell", genome.plasma_regions)
        isempty(cells) ? "regime_unspecified" : only(cells).geometry_model
    else
        "regime_na"
    end
    return join((genome.family, genome.topology.field_line_class,
        genome.symmetry.class, "fp$(genome.symmetry.field_periods)",
        transform, genome.exhaust.kind, actuator_bin, field_bin, mechanisms, regime), "|")
end

function _metric_value(bundle::EvaluationBundle, id::String)
    matches = filter(metric -> metric.metric_id == id, bundle.metrics)
    length(matches) == 1 || error("missing structural metric $id")
    return Float64(only(matches).value)
end

function _objective_bundles(registry::EvaluatorRegistry, genome::Genome)
    bundles = EvaluationBundle[]
    for evaluator_id in sort!(collect(keys(registry.evaluators)))
        evaluator_id == "structural_ir_v1" && continue
        evaluator = registry.evaluators[evaluator_id]
        applicable, _ = evaluator_applicability(evaluator, genome)
        applicable || continue
        push!(bundles, evaluate_design(registry, evaluator_id, genome))
    end
    return bundles
end

function _assess(registry::EvaluatorRegistry, genome::Genome,
        objective_contract::Union{Nothing,ObjectiveContract})
    bundle = evaluate_design(registry, "structural_ir_v1", genome)
    bundle.status == :pass || error("structural evaluator failed: $(join(bundle.warnings, "; "))")
    coverage = coverage_report(registry, genome)
    full = count(item -> item.support == :full, coverage)
    proxy = count(item -> item.support == :proxy, coverage)
    missing = count(item -> item.support == :missing, coverage)
    readiness = objective_contract === nothing ? nothing :
        prepare_candidate(genome, _objective_bundles(registry, genome),
            objective_contract)
    return SearchRecord(
        genome,
        structural_descriptor(genome),
        _metric_value(bundle, "ir_complexity_proxy"),
        full,
        proxy,
        missing,
        readiness !== nothing && readiness.eligible,
        readiness,
        bundle,
    )
end

function _selection_key(record::SearchRecord)
    total = record.coverage_full + record.coverage_proxy + record.coverage_missing
    total = max(total, 1)
    return (
        -record.coverage_full / total,
        record.coverage_missing / total,
        record.coverage_proxy / total,
        record.ir_complexity,
        record.genome.physics_hash,
    )
end

function _insert!(archive::StructuralQDArchive, record::SearchRecord)
    record.genome.physics_hash in archive.seen_hashes && return :duplicate
    push!(archive.seen_hashes, record.genome.physics_hash)
    incumbent = get(archive.cells, record.descriptor, nothing)
    if incumbent === nothing || _selection_key(record) < _selection_key(incumbent)
        archive.cells[record.descriptor] = record
        return :inserted
    end
    return :discarded
end

function run_structural_qd(seeds::Vector{Genome}, rules::Vector{GraphRule},
        registry::EvaluatorRegistry; iterations::Int = 250, random_seed::Int = 20260810,
        objective_contract::Union{Nothing,ObjectiveContract} = nothing)
    iterations >= 0 || throw(ArgumentError("iterations must be non-negative"))
    haskey(registry.evaluators, "structural_ir_v1") ||
        throw(ArgumentError("structural_ir_v1 must be registered"))
    rng = MersenneTwister(random_seed)
    archive = StructuralQDArchive()
    discovered = SearchRecord[]
    for seed in sort(seeds; by = genome -> genome.design_id)
        record = _assess(registry, seed, objective_contract)
        _insert!(archive, record)
        push!(discovered, record)
    end

    rejected = 0
    duplicate = 0
    for _ in 1:iterations
        parents = sort!(collect(values(archive.cells)); by = record -> record.genome.design_id)
        isempty(parents) && break
        parent = rand(rng, parents).genome
        available = sort!(filter(rule -> applicable_rule(rule, parent), rules); by = rule -> rule.id)
        if isempty(available)
            rejected += 1
            continue
        end
        rule = rand(rng, available)
        try
            candidate = apply_rule(rule, parent, rng)
            record = _assess(registry, candidate, objective_contract)
            outcome = _insert!(archive, record)
            outcome == :duplicate && (duplicate += 1)
            if outcome != :duplicate &&
                    all(item -> item.genome.physics_hash != candidate.physics_hash, discovered)
                push!(discovered, record)
            end
        catch
            rejected += 1
        end
    end
    sort!(discovered; by = record -> record.genome.physics_hash)
    return StructuralQDResult(archive, discovered, iterations, rejected, duplicate,
        random_seed, iterations,
        objective_contract === nothing ? nothing : objective_contract.id)
end

function _readiness_to_dict(record::SearchRecord)
    readiness = record.objective_readiness
    readiness === nothing && return Dict{String,Any}(
        "audited" => false,
        "eligible" => false,
        "reasons" => ["objective readiness audit not requested"],
    )
    return Dict{String,Any}(
        "audited" => true,
        "contract_id" => readiness.contract_id,
        "eligible" => readiness.eligible,
        "reasons" => readiness.reasons,
        "evidence_signature" => readiness.evidence_signature,
        "available_objectives" => sort!(collect(keys(readiness.objectives))),
        "satisfied_constraints" => sort!(collect(keys(readiness.constraints))),
    )
end

function _search_record_to_dict(record::SearchRecord; include_genome = true)
    result = Dict{String,Any}(
        "design_id" => record.genome.design_id,
        "physics_hash" => record.genome.physics_hash,
        "descriptor" => record.descriptor,
        "ir_complexity_proxy" => record.ir_complexity,
        "coverage" => Dict(
            "full" => record.coverage_full,
            "proxy" => record.coverage_proxy,
            "missing" => record.coverage_missing,
        ),
        "performance_eligible" => record.performance_eligible,
        "objective_readiness" => _readiness_to_dict(record),
        "claim_level" => record.genome.provenance.claim_level,
        "parent_design_ids" => record.genome.provenance.parent_design_ids,
        "grammar_notes" => filter(note -> startswith(note, "grammar_rule:"),
            record.genome.provenance.notes),
    )
    include_genome && (result["genome"] = record.genome.normalized)
    return result
end

function structural_qd_to_dict(result::StructuralQDResult)
    archive_records = sort!(collect(values(result.archive.cells));
        by = record -> record.descriptor)
    rejection_counts = Dict{String,Int}()
    for record in result.discovered
        readiness = record.objective_readiness
        readiness === nothing && continue
        for reason in readiness.reasons
            rejection_counts[reason] = get(rejection_counts, reason, 0) + 1
        end
    end
    return Dict{String,Any}(
        "search_version" => "structural_qd_v1",
        "algorithm" => "MAP-Elites-style graph-grammar mutation",
        "stage" => "structural_only",
        "objective_contract_id" => result.objective_contract_id,
        "objective_readiness_audited" => result.objective_contract_id !== nothing,
        "objective_readiness_rejection_counts" => rejection_counts,
        "claim_boundary" =>
            "Archive selection is research readiness plus IR complexity only; no candidate is ranked for stability, fusion output, net power, cost, or reactor feasibility.",
        "random_seed" => result.random_seed,
        "iterations" => result.iterations,
        "attempts" => result.attempts,
        "rejected" => result.rejected,
        "duplicates" => result.duplicate,
        "archive_cell_count" => length(archive_records),
        "discovered_unique_count" => length(result.discovered),
        "performance_eligible_count" => count(record -> record.performance_eligible,
            result.discovered),
        "archive" => [_search_record_to_dict(record; include_genome = true)
            for record in archive_records],
        "discovered" => [_search_record_to_dict(record; include_genome = false)
            for record in result.discovered],
    )
end
