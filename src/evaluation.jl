const _EVAL_STATUSES = Set((:pass, :fail, :unknown, :not_applicable, :error))

struct MetricResult
    metric_id::String
    value::Any
    unit::String
    uncertainty::Union{Nothing,Float64}
    fidelity::Int
    applicability::String
    status::Symbol
    constraints_checked::Vector{String}
    solver_name::String
    solver_version::String
    input_hash::String
    run_hash::String
    source_basis::Vector{String}
    warnings::Vector{String}
    residuals::Dict{String,Float64}
    wall_time_s::Float64

    function MetricResult(metric_id::AbstractString, value;
            unit::AbstractString = "1",
            uncertainty::Union{Nothing,Real} = nothing,
            fidelity::Integer,
            applicability::AbstractString,
            status::Symbol,
            constraints_checked::Vector{String} = String[],
            solver_name::AbstractString,
            solver_version::AbstractString,
            input_hash::AbstractString,
            run_hash::AbstractString,
            source_basis::Vector{String} = String[],
            warnings::Vector{String} = String[],
            residuals::Dict{String,Float64} = Dict{String,Float64}(),
            wall_time_s::Real = 0.0)
        status in _EVAL_STATUSES || throw(ArgumentError("invalid evaluation status: $status"))
        if status in (:unknown, :not_applicable, :error)
            value === nothing || throw(ArgumentError("status $status must use value=nothing"))
        elseif value === nothing
            throw(ArgumentError("status $status requires a value"))
        end
        uncertainty === nothing || isfinite(uncertainty) ||
            throw(ArgumentError("uncertainty must be finite or nothing"))
        wall_time_s >= 0 || throw(ArgumentError("wall_time_s must be non-negative"))
        return new(
            String(metric_id), value, String(unit),
            uncertainty === nothing ? nothing : Float64(uncertainty),
            Int(fidelity), String(applicability), status, constraints_checked,
            String(solver_name), String(solver_version), String(input_hash),
            String(run_hash), source_basis, warnings, residuals, Float64(wall_time_s),
        )
    end
end

struct EvaluationBundle
    evaluator_id::String
    design_id::String
    family::String
    fidelity::Int
    status::Symbol
    metrics::Vector{MetricResult}
    warnings::Vector{String}
    input_hash::String
    run_hash::String
    claim_ceiling::String

    function EvaluationBundle(evaluator_id::AbstractString, design_id::AbstractString,
            family::AbstractString, fidelity::Integer, status::Symbol,
            metrics::Vector{MetricResult}, warnings::Vector{String},
            input_hash::AbstractString, run_hash::AbstractString,
            claim_ceiling::AbstractString)
        status in _EVAL_STATUSES || throw(ArgumentError("invalid bundle status: $status"))
        return new(String(evaluator_id), String(design_id), String(family), Int(fidelity),
            status, metrics, warnings, String(input_hash), String(run_hash),
            String(claim_ceiling))
    end
end

function _metric_to_dict(metric::MetricResult)
    return Dict{String,Any}(
        "metric_id" => metric.metric_id,
        "value" => metric.value,
        "unit" => metric.unit,
        "uncertainty" => metric.uncertainty,
        "fidelity" => metric.fidelity,
        "applicability" => metric.applicability,
        "status" => String(metric.status),
        "constraints_checked" => metric.constraints_checked,
        "solver_name" => metric.solver_name,
        "solver_version" => metric.solver_version,
        "input_hash" => metric.input_hash,
        "run_hash" => metric.run_hash,
        "source_basis" => metric.source_basis,
        "warnings" => metric.warnings,
        "residuals" => metric.residuals,
        "wall_time_s" => metric.wall_time_s,
    )
end

function evaluation_to_dict(bundle::EvaluationBundle)
    return Dict{String,Any}(
        "evaluator_id" => bundle.evaluator_id,
        "design_id" => bundle.design_id,
        "family" => bundle.family,
        "fidelity" => bundle.fidelity,
        "status" => String(bundle.status),
        "metrics" => [_metric_to_dict(metric) for metric in bundle.metrics],
        "warnings" => bundle.warnings,
        "input_hash" => bundle.input_hash,
        "run_hash" => bundle.run_hash,
        "claim_ceiling" => bundle.claim_ceiling,
    )
end

function write_evaluation(path::AbstractString, bundle::EvaluationBundle)
    open(path, "w") do io
        JSON3.pretty(io, evaluation_to_dict(bundle))
        write(io, '\n')
    end
    return path
end
