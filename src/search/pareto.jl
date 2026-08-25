const _CLAIM_LEVELS = Dict(
    "structural_only" => 0,
    "screening_only" => 1,
    "physics_proxy" => 2,
    "physics_concept" => 3,
    "engineering_concept" => 4,
    "experiment_proposal" => 5,
)

struct ObjectiveSpec
    metric_id::String
    direction::Symbol
    unit::String
    minimum_fidelity::Int
    require_uncertainty::Bool

    function ObjectiveSpec(metric_id::AbstractString, direction::Symbol,
            unit::AbstractString; minimum_fidelity::Integer = 0,
            require_uncertainty::Bool = true)
        direction in (:min, :max) ||
            throw(ArgumentError("objective direction must be :min or :max"))
        return new(String(metric_id), direction, String(unit),
            Int(minimum_fidelity), require_uncertainty)
    end
end

struct ConstraintSpec
    metric_id::String
    relation::Symbol
    threshold::Any
    unit::String
    minimum_fidelity::Int
    require_uncertainty::Bool

    function ConstraintSpec(metric_id::AbstractString, relation::Symbol,
            threshold = nothing; unit::AbstractString = "1",
            minimum_fidelity::Integer = 0,
            require_uncertainty::Bool = false)
        relation in (:is_true, :is_false, :ge, :le, :eq) ||
            throw(ArgumentError("unsupported constraint relation $relation"))
        relation in (:ge, :le, :eq) && !(threshold isa Real) &&
            throw(ArgumentError("numeric constraint $relation requires a numeric threshold"))
        relation in (:is_true, :is_false) && threshold !== nothing &&
            throw(ArgumentError("boolean constraints do not use a threshold"))
        return new(String(metric_id), relation, threshold, String(unit),
            Int(minimum_fidelity), require_uncertainty)
    end
end

struct ObjectiveContract
    id::String
    mission_kinds::Set{String}
    fuels::Set{String}
    objectives::Vector{ObjectiveSpec}
    hard_constraints::Vector{ConstraintSpec}
    minimum_claim_level::String

    function ObjectiveContract(id::AbstractString, mission_kinds, fuels,
            objectives::Vector{ObjectiveSpec}, hard_constraints::Vector{ConstraintSpec};
            minimum_claim_level::AbstractString = "physics_proxy")
        isempty(objectives) && throw(ArgumentError("objective contract requires objectives"))
        objective_ids = getfield.(objectives, :metric_id)
        length(unique(objective_ids)) == length(objective_ids) ||
            throw(ArgumentError("duplicate objective metric IDs"))
        constraint_ids = getfield.(hard_constraints, :metric_id)
        length(unique(constraint_ids)) == length(constraint_ids) ||
            throw(ArgumentError("duplicate hard-constraint metric IDs"))
        haskey(_CLAIM_LEVELS, String(minimum_claim_level)) ||
            throw(ArgumentError("unknown claim level $minimum_claim_level"))
        return new(String(id), Set(String.(mission_kinds)), Set(String.(fuels)),
            objectives, hard_constraints, String(minimum_claim_level))
    end
end

"""
Cross-family contract for the first science-gain discovery loop.

The metric IDs are intentionally configuration-neutral. Family evaluators may
estimate them at different fidelities, but every candidate must provide all
four objectives plus the stability and engineering hard gates before it can
enter a performance Pareto archive.
"""
function first_principles_discovery_contract()
    return ObjectiveContract(
        "science_gain_first_principles_v1",
        ["science_gain_demo"],
        ["D-T"],
        ObjectiveSpec[
            ObjectiveSpec("device_complexity_index", :min, "1";
                minimum_fidelity = 1, require_uncertainty = true),
            ObjectiveSpec("minimum_stability_margin", :max, "1";
                minimum_fidelity = 1, require_uncertainty = true),
            ObjectiveSpec("fusion_power", :max, "W";
                minimum_fidelity = 0, require_uncertainty = true),
            ObjectiveSpec("fusion_gain", :max, "1";
                minimum_fidelity = 0, require_uncertainty = true),
        ],
        ConstraintSpec[
            ConstraintSpec("plasma_stability_feasible", :is_true;
                minimum_fidelity = 1),
            ConstraintSpec("engineering_feasible", :is_true;
                minimum_fidelity = 1),
        ];
        minimum_claim_level = "physics_proxy",
    )
end

"Family-local contract used only to explore the BEAM 0-D proxy domain."
function mirror_beam_screening_contract()
    proxy_gates = [
        "beta_limit_feasible_proxy",
        "beam_absorption_90pct_feasible_proxy",
        "dclc_size_feasible_proxy",
        "flr_m2_feasible_proxy",
        "fast_ion_adiabaticity_feasible_proxy",
        "peak_field_25T_feasible_proxy",
        "high_mirror_ratio_feasible_proxy",
    ]
    return ObjectiveContract(
        "mirror_beam_proxy_screening_v1",
        ["science_gain_demo"],
        ["D-T"],
        ObjectiveSpec[
            ObjectiveSpec("fusion_gain", :max, "1"),
            ObjectiveSpec("fusion_power", :max, "W"),
            ObjectiveSpec("absorbed_beam_power_proxy", :min, "W"),
            ObjectiveSpec("effective_plasma_volume", :min, "m^3"),
        ],
        ConstraintSpec[
            ConstraintSpec(id, :is_true; minimum_fidelity = 0)
            for id in proxy_gates
        ];
        minimum_claim_level = "physics_proxy",
    )
end

struct PreparedCandidate
    design_id::String
    family::String
    contract_id::String
    eligible::Bool
    reasons::Vector{String}
    objectives::Dict{String,MetricResult}
    constraints::Dict{String,MetricResult}
    evidence_signature::String
end

struct DominanceDecision
    comparable::Bool
    a_dominates::Bool
    b_dominates::Bool
    reasons::Vector{String}
end

function _claim_at_least(actual::String, required::String)
    return get(_CLAIM_LEVELS, actual, -1) >= _CLAIM_LEVELS[required]
end

function _candidate_metrics(genome::Genome, bundles::Vector{EvaluationBundle})
    result = Dict{String,Vector{Tuple{MetricResult,String}}}()
    errors = String[]
    for bundle in bundles
        bundle.design_id == genome.design_id ||
            push!(errors, "bundle $(bundle.evaluator_id) belongs to design $(bundle.design_id)")
        bundle.family == genome.family ||
            push!(errors, "bundle $(bundle.evaluator_id) family $(bundle.family) does not match $(genome.family)")
        bundle.input_hash == genome.physics_hash ||
            push!(errors, "bundle $(bundle.evaluator_id) input hash does not match genome")
        for metric in bundle.metrics
            metric.input_hash == genome.physics_hash ||
                push!(errors, "metric $(metric.metric_id) input hash does not match genome")
            push!(get!(result, metric.metric_id, Tuple{MetricResult,String}[]),
                (metric, bundle.claim_ceiling))
        end
    end
    return result, errors
end

function _select_metric(metric_id::String, candidates, minimum_fidelity::Int,
        unit::String, require_uncertainty::Bool, minimum_claim_level::String)
    reasons = String[]
    isempty(candidates) && return nothing, ["missing required metric $metric_id"], nothing

    deduplicated = Dict{String,Tuple{MetricResult,String}}()
    for (metric, claim) in candidates
        deduplicated[metric.run_hash] = (metric, claim)
    end
    valid = Tuple{MetricResult,String}[]
    for (metric, claim) in values(deduplicated)
        metric.status == :pass || begin
            push!(reasons, "metric $metric_id has status $(metric.status)")
            continue
        end
        metric.value isa Real && !(metric.value isa Bool) || begin
            push!(reasons, "metric $metric_id is not a numeric objective value")
            continue
        end
        isfinite(metric.value) || begin
            push!(reasons, "metric $metric_id is not finite")
            continue
        end
        metric.unit == unit || begin
            push!(reasons, "metric $metric_id unit $(metric.unit) does not match $unit")
            continue
        end
        metric.fidelity >= minimum_fidelity || begin
            push!(reasons, "metric $metric_id fidelity $(metric.fidelity) is below $minimum_fidelity")
            continue
        end
        !require_uncertainty || metric.uncertainty !== nothing || begin
            push!(reasons, "metric $metric_id lacks required uncertainty")
            continue
        end
        _claim_at_least(claim, minimum_claim_level) || begin
            push!(reasons, "metric $metric_id claim ceiling $claim is below $minimum_claim_level")
            continue
        end
        push!(valid, (metric, claim))
    end
    isempty(valid) && return nothing, reasons, nothing
    maximum_fidelity = maximum(item[1].fidelity for item in valid)
    highest = filter(item -> item[1].fidelity == maximum_fidelity, valid)
    length(highest) == 1 || return nothing,
        ["metric $metric_id is ambiguous at fidelity $maximum_fidelity"], nothing
    metric, claim = only(highest)
    evidence = Dict(
        "metric_id" => metric.metric_id,
        "fidelity" => metric.fidelity,
        "claim_level" => _CLAIM_LEVELS[claim],
        "has_uncertainty" => metric.uncertainty !== nothing,
    )
    return metric, String[], evidence
end

function _constraint_satisfied(spec::ConstraintSpec, metric::MetricResult)
    if spec.relation == :is_true
        return metric.value === true
    elseif spec.relation == :is_false
        return metric.value === false
    elseif !(metric.value isa Real) || metric.value isa Bool
        return false
    elseif spec.relation == :ge
        return metric.value >= spec.threshold
    elseif spec.relation == :le
        return metric.value <= spec.threshold
    end
    return metric.value == spec.threshold
end

function _select_constraint(spec::ConstraintSpec, candidates,
        minimum_claim_level::String)
    # Reuse objective selection for numeric constraints. Boolean gates retain
    # the same status/fidelity/unit/claim checks but do not require a number.
    if spec.relation in (:ge, :le, :eq)
        metric, reasons, evidence = _select_metric(spec.metric_id, candidates,
            spec.minimum_fidelity, spec.unit, spec.require_uncertainty,
            minimum_claim_level)
        metric === nothing && return nothing, reasons, evidence
        _constraint_satisfied(spec, metric) ||
            return nothing, ["hard constraint $(spec.metric_id) failed"], evidence
        return metric, String[], evidence
    end

    reasons = String[]
    isempty(candidates) && return nothing,
        ["missing required hard constraint $(spec.metric_id)"], nothing
    deduplicated = Dict(item[1].run_hash => item for item in candidates)
    valid = Tuple{MetricResult,String}[]
    for (metric, claim) in values(deduplicated)
        metric.status == :pass || begin
            push!(reasons, "hard constraint $(spec.metric_id) has status $(metric.status)")
            continue
        end
        metric.value isa Bool || begin
            push!(reasons, "hard constraint $(spec.metric_id) is not boolean")
            continue
        end
        metric.unit == spec.unit || begin
            push!(reasons, "hard constraint $(spec.metric_id) unit mismatch")
            continue
        end
        metric.fidelity >= spec.minimum_fidelity || begin
            push!(reasons, "hard constraint $(spec.metric_id) fidelity is too low")
            continue
        end
        !spec.require_uncertainty || metric.uncertainty !== nothing || begin
            push!(reasons, "hard constraint $(spec.metric_id) lacks uncertainty")
            continue
        end
        _claim_at_least(claim, minimum_claim_level) || begin
            push!(reasons, "hard constraint $(spec.metric_id) claim ceiling is too low")
            continue
        end
        push!(valid, (metric, claim))
    end
    isempty(valid) && return nothing, reasons, nothing
    maximum_fidelity = maximum(item[1].fidelity for item in valid)
    highest = filter(item -> item[1].fidelity == maximum_fidelity, valid)
    length(highest) == 1 || return nothing,
        ["hard constraint $(spec.metric_id) is ambiguous"], nothing
    metric, claim = only(highest)
    _constraint_satisfied(spec, metric) ||
        return nothing, ["hard constraint $(spec.metric_id) failed"], nothing
    evidence = Dict(
        "metric_id" => metric.metric_id,
        "fidelity" => metric.fidelity,
        "claim_level" => _CLAIM_LEVELS[claim],
        "has_uncertainty" => metric.uncertainty !== nothing,
    )
    return metric, String[], evidence
end

"Prepare a candidate for Pareto comparison; every missing item is a rejection reason."
function prepare_candidate(genome::Genome, bundles::Vector{EvaluationBundle},
        contract::ObjectiveContract)
    reasons = String[]
    genome.mission.kind in contract.mission_kinds ||
        push!(reasons, "mission kind $(genome.mission.kind) is outside contract $(contract.id)")
    genome.mission.fuel in contract.fuels ||
        push!(reasons, "fuel $(genome.mission.fuel) is outside contract $(contract.id)")
    candidates, bundle_errors = _candidate_metrics(genome, bundles)
    append!(reasons, bundle_errors)
    objectives = Dict{String,MetricResult}()
    constraints = Dict{String,MetricResult}()
    evidence = Any[]

    for spec in contract.objectives
        metric, metric_reasons, metric_evidence = _select_metric(spec.metric_id,
            get(candidates, spec.metric_id, Tuple{MetricResult,String}[]),
            spec.minimum_fidelity, spec.unit, spec.require_uncertainty,
            contract.minimum_claim_level)
        append!(reasons, metric_reasons)
        if metric !== nothing
            objectives[spec.metric_id] = metric
            push!(evidence, metric_evidence)
        end
    end
    for spec in contract.hard_constraints
        metric, metric_reasons, metric_evidence = _select_constraint(spec,
            get(candidates, spec.metric_id, Tuple{MetricResult,String}[]),
            contract.minimum_claim_level)
        append!(reasons, metric_reasons)
        if metric !== nothing
            constraints[spec.metric_id] = metric
            push!(evidence, metric_evidence)
        end
    end
    evidence_signature = isempty(evidence) ? "unready" : canonical_hash(sort(evidence;
        by = item -> item["metric_id"]))
    return PreparedCandidate(genome.design_id, genome.family, contract.id,
        isempty(reasons), sort!(unique(reasons)), objectives, constraints,
        evidence_signature)
end

function compare_candidates(a::PreparedCandidate, b::PreparedCandidate,
        contract::ObjectiveContract)
    reasons = String[]
    a.contract_id == contract.id && b.contract_id == contract.id ||
        push!(reasons, "candidates were not prepared for contract $(contract.id)")
    a.eligible || push!(reasons, "candidate $(a.design_id) is not objective-ready")
    b.eligible || push!(reasons, "candidate $(b.design_id) is not objective-ready")
    a.evidence_signature == b.evidence_signature ||
        push!(reasons, "candidates belong to different evidence tiers")
    isempty(reasons) || return DominanceDecision(false, false, false, reasons)

    a_no_worse = true
    b_no_worse = true
    a_strict = false
    b_strict = false
    for spec in contract.objectives
        av = Float64(a.objectives[spec.metric_id].value)
        bv = Float64(b.objectives[spec.metric_id].value)
        if spec.direction == :max
            a_no_worse &= av >= bv
            b_no_worse &= bv >= av
            a_strict |= av > bv
            b_strict |= bv > av
        else
            a_no_worse &= av <= bv
            b_no_worse &= bv <= av
            a_strict |= av < bv
            b_strict |= bv < av
        end
    end
    return DominanceDecision(true, a_no_worse && a_strict,
        b_no_worse && b_strict, String[])
end

mutable struct EvidenceParetoArchive
    contract::ObjectiveContract
    tiers::Dict{String,Vector{PreparedCandidate}}
end

EvidenceParetoArchive(contract::ObjectiveContract) =
    EvidenceParetoArchive(contract, Dict{String,Vector{PreparedCandidate}}())

struct ParetoInsertion
    status::Symbol
    removed_design_ids::Vector{String}
    reasons::Vector{String}
end

function insert_candidate!(archive::EvidenceParetoArchive, candidate::PreparedCandidate)
    candidate.eligible || return ParetoInsertion(:rejected, String[], candidate.reasons)
    candidate.contract_id == archive.contract.id || return ParetoInsertion(:rejected,
        String[], ["candidate contract does not match archive"])
    tier = get!(archive.tiers, candidate.evidence_signature, PreparedCandidate[])
    any(item -> item.design_id == candidate.design_id, tier) &&
        return ParetoInsertion(:duplicate, String[], String[])
    dominated = String[]
    for incumbent in tier
        decision = compare_candidates(candidate, incumbent, archive.contract)
        decision.b_dominates && return ParetoInsertion(:dominated, String[], String[])
        decision.a_dominates && push!(dominated, incumbent.design_id)
    end
    filter!(item -> !(item.design_id in dominated), tier)
    push!(tier, candidate)
    sort!(tier; by = item -> item.design_id)
    return ParetoInsertion(:inserted, sort!(dominated), String[])
end
