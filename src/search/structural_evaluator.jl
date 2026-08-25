struct StructuralIREvaluatorV1 <: AbstractEvaluator end

function evaluator_spec(::StructuralIREvaluatorV1)
    return EvaluatorSpec(
        "structural_ir_v1",
        "1.0.0",
        collect(keys(default_family_registry().specs)),
        -1,
        Dict{String,Symbol}(),
        "structural_only",
    )
end

function run_evaluator(::StructuralIREvaluatorV1, genome::Genome; kwargs...)
    spec = evaluator_spec(StructuralIREvaluatorV1())
    semantic = validate_genome(genome)
    semantic.valid || error(join(semantic.errors, "; "))
    unique_geometry_models = length(unique(vcat(
        getfield.(genome.plasma_regions, :geometry_model),
        getfield.(genome.field_sources, :geometry_model),
    )))
    component_count = length(genome.plasma_regions) + length(genome.field_sources) +
        length(genome.actuators)
    ir_complexity = length(genome.field_sources) + 1.25 * length(genome.actuators) +
        0.50 * length(genome.plasma_regions) + 0.25 * length(genome.flux_connections) +
        0.50 * unique_geometry_models + 0.25 * length(genome.stability_mechanisms)
    source_count = length(unique(vcat(genome.provenance.source_ids,
        reduce(vcat, getfield.(genome.stability_mechanisms, :source_ids); init = String[]))))
    raw_metrics = Dict{String,Any}(
        "ir_component_count" => component_count,
        "ir_field_source_count" => length(genome.field_sources),
        "ir_actuator_count" => length(genome.actuators),
        "ir_unique_geometry_model_count" => unique_geometry_models,
        "ir_stability_mechanism_count" => length(genome.stability_mechanisms),
        "ir_source_basis_count" => source_count,
        "ir_complexity_proxy" => ir_complexity,
    )
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => spec.id,
        "version" => spec.version,
        "metrics" => raw_metrics,
    ))
    applicability = "Structural IR only; no equilibrium, stability, transport, power, or engineering performance."
    warnings = [
        "IR complexity is a bookkeeping proxy and must not be called device simplicity or cost.",
        "Declared mechanisms and sources are not evidence that those mechanisms work together.",
    ]
    metrics = MetricResult[]
    for id in sort!(collect(keys(raw_metrics)))
        push!(metrics, MetricResult(id, raw_metrics[id];
            fidelity = spec.fidelity,
            applicability = applicability,
            status = :pass,
            constraints_checked = ["Genome semantic graph validity"],
            solver_name = spec.id,
            solver_version = spec.version,
            input_hash = genome.physics_hash,
            run_hash = run_hash,
            source_basis = genome.provenance.source_ids,
            warnings = warnings))
    end
    return EvaluationBundle(spec.id, genome.design_id, genome.family, spec.fidelity,
        :pass, metrics, warnings, genome.physics_hash, run_hash, spec.claim_ceiling)
end
