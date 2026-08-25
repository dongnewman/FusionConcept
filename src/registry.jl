abstract type AbstractEvaluator end

struct EvaluatorSpec
    id::String
    version::String
    families::Set{String}
    fidelity::Int
    requirement_support::Dict{String,Symbol}
    claim_ceiling::String

    function EvaluatorSpec(id::AbstractString, version::AbstractString,
            families, fidelity::Integer, requirement_support,
            claim_ceiling::AbstractString)
        support = Dict{String,Symbol}(String(key) => Symbol(value)
            for (key, value) in requirement_support)
        all(level -> level in (:proxy, :full), values(support)) ||
            throw(ArgumentError("requirement support must be :proxy or :full"))
        return new(String(id), String(version), Set(String.(collect(families))),
            Int(fidelity), support, String(claim_ceiling))
    end
end

evaluator_spec(::AbstractEvaluator) =
    throw(MethodError(evaluator_spec, (AbstractEvaluator,)))

function evaluator_applicability(evaluator::AbstractEvaluator, genome::Genome)
    spec = evaluator_spec(evaluator)
    return genome.family in spec.families,
        genome.family in spec.families ? "applicable family" :
        "evaluator $(spec.id) does not apply to family $(genome.family)"
end

run_evaluator(::AbstractEvaluator, ::Genome; kwargs...) =
    throw(MethodError(run_evaluator, (AbstractEvaluator, Genome)))

mutable struct EvaluatorRegistry
    evaluators::Dict{String,AbstractEvaluator}
end

EvaluatorRegistry() = EvaluatorRegistry(Dict{String,AbstractEvaluator}())

function register!(registry::EvaluatorRegistry, evaluator::AbstractEvaluator)
    spec = evaluator_spec(evaluator)
    haskey(registry.evaluators, spec.id) &&
        throw(ArgumentError("evaluator already registered: $(spec.id)"))
    registry.evaluators[spec.id] = evaluator
    return registry
end

struct CoverageItem
    requirement::String
    support::Symbol
    evaluator_ids::Vector{String}
end

function _requirements(genome::Genome)
    requirements = String[]
    for mechanism in genome.stability_mechanisms
        append!(requirements, mechanism.required_evaluators)
    end
    append!(requirements, genome.exhaust.evaluation_requirements)
    append!(requirements, genome.engineering.required_evaluators)
    return sort!(unique(requirements))
end

function coverage_report(registry::EvaluatorRegistry, genome::Genome)
    result = CoverageItem[]
    for requirement in _requirements(genome)
        proxy_ids = String[]
        full_ids = String[]
        for evaluator in values(registry.evaluators)
            spec = evaluator_spec(evaluator)
            applicable, _ = evaluator_applicability(evaluator, genome)
            applicable || continue
            support = get(spec.requirement_support, requirement, :missing)
            support == :proxy && push!(proxy_ids, spec.id)
            support == :full && push!(full_ids, spec.id)
        end
        if !isempty(full_ids)
            push!(result, CoverageItem(requirement, :full, sort!(full_ids)))
        elseif !isempty(proxy_ids)
            push!(result, CoverageItem(requirement, :proxy, sort!(proxy_ids)))
        else
            push!(result, CoverageItem(requirement, :missing, String[]))
        end
    end
    return result
end

coverage_complete(items::Vector{CoverageItem}) = all(item -> item.support == :full, items)

struct FamilySpec
    id::String
    field_line_classes::Set{String}
    symmetry_classes::Set{String}
    coordinate_chart::String
    fidelity1_solvers::Vector{String}
    claim_ceiling_without_fidelity1::String
end

mutable struct FamilyRegistry
    specs::Dict{String,FamilySpec}
end

function FamilyRegistry(specs::Vector{FamilySpec})
    ids = getfield.(specs, :id)
    length(unique(ids)) == length(ids) || throw(ArgumentError("duplicate family ID"))
    return FamilyRegistry(Dict(spec.id => spec for spec in specs))
end

function default_family_registry()
    specs = FamilySpec[
        FamilySpec("tokamak_axisymmetric", Set(["closed_toroidal_nested", "closed_toroidal_separatrix"]),
            Set(["axisymmetric"]), "axisymmetric Fourier or spline boundary",
            ["free_boundary_grad_shafranov"], "screening_only"),
        FamilySpec("tokamak_3d_hybrid", Set(["closed_toroidal_nested", "closed_toroidal_separatrix", "mixed"]),
            Set(["quasi_axisymmetric", "mixed", "none"]), "3D toroidal Fourier-Boozer boundary",
            ["vmec_or_desc", "free_boundary_grad_shafranov"], "screening_only"),
        FamilySpec("closed_open_hybrid", Set(["mixed"]),
            Set(["axisymmetric", "quasi_axisymmetric", "stellarator_symmetric",
                "minimum_b", "mixed", "none"]),
            "attributed closed-core/open-end graph with toroidal and axial charts",
            ["coupled_closed_open_equilibrium", "field_line_and_particle_following"],
            "screening_only"),
        FamilySpec("stellarator", Set(["closed_toroidal_nested", "closed_toroidal_separatrix"]),
            Set(["stellarator_symmetric", "quasi_axisymmetric", "quasi_helical", "quasi_isodynamic", "none"]),
            "near-axis or 3D Fourier-Boozer boundary", ["vmec_or_desc", "spec_if_islands"],
            "screening_only"),
        FamilySpec("magnetic_mirror", Set(["open_mirror"]),
            Set(["axisymmetric", "minimum_b", "mixed"]), "axial B(z) plus finite-build coils",
            ["anisotropic_mirror_equilibrium"], "screening_only"),
        FamilySpec("sheared_flow_z_pinch", Set(["open_linear"]),
            Set(["axisymmetric"]),
            "finite-radius linear current channel plus axial-flow and end-loss charts",
            ["resistive_mhd_with_axial_flow", "coaxial_accelerator_and_electrode_model"],
            "structural_only"),
        FamilySpec("field_reversed_configuration", Set(["compact_toroid"]),
            Set(["axisymmetric", "none"]), "separatrix and flux-conserver coordinates",
            ["two_fluid_or_hybrid_frc"], "structural_only"),
        FamilySpec("reversed_field_pinch", Set(["closed_toroidal_nested", "closed_toroidal_separatrix"]),
            Set(["axisymmetric", "none"]), "axisymmetric boundary plus helical spectrum",
            ["resistive_mhd_rfp"], "structural_only"),
        FamilySpec("spheromak", Set(["compact_toroid"]), Set(["axisymmetric", "none"]),
            "closed-flux compact-toroid coordinates", ["resistive_mhd_spheromak"],
            "structural_only"),
        FamilySpec("magnetized_target_fusion", Set(["compact_toroid", "mixed"]),
            Set(["axisymmetric", "none", "mixed"]),
            "explicit target, compression driver, liner, and pulsed chamber graph",
            ["liner_target_radiation_mhd", "repeat_rate_chamber_model"],
            "structural_only"),
        FamilySpec("levitated_dipole", Set(["closed_toroidal_nested"]),
            Set(["axisymmetric"]), "dipole flux coordinates", ["finite_beta_dipole_equilibrium"],
            "structural_only"),
        FamilySpec("other", Set(["closed_toroidal_nested", "closed_toroidal_separatrix", "open_mirror", "compact_toroid", "mixed"]),
            Set(["axisymmetric", "stellarator_symmetric", "quasi_axisymmetric", "quasi_helical", "quasi_isodynamic", "minimum_b", "none", "mixed"]),
            "must be declared by the candidate", String[], "structural_only"),
    ]
    return FamilyRegistry(specs)
end

family_spec(registry::FamilyRegistry, id::AbstractString) = get(registry.specs, String(id), nothing)

function validate_family(registry::FamilyRegistry, genome::Genome)
    spec = family_spec(registry, genome.family)
    spec === nothing && return ValidationReport(false,
        ["unregistered confinement family $(genome.family)"], String[])
    errors = String[]
    genome.topology.field_line_class in spec.field_line_classes ||
        push!(errors, "field-line class $(genome.topology.field_line_class) is invalid for $(spec.id)")
    genome.symmetry.class in spec.symmetry_classes ||
        push!(errors, "symmetry $(genome.symmetry.class) is invalid for $(spec.id)")
    warnings = isempty(spec.fidelity1_solvers) ?
        ["family has no registered fidelity-1 solver"] : String[]
    return ValidationReport(isempty(errors), errors, warnings)
end

function _non_applicable_bundle(spec::EvaluatorSpec, genome::Genome, reason::String)
    run_hash = canonical_hash(Dict(
        "evaluator" => spec.id,
        "version" => spec.version,
        "input_hash" => genome.physics_hash,
        "status" => "not_applicable",
        "reason" => reason,
    ))
    metric = MetricResult("evaluator_applicability", nothing;
        fidelity = spec.fidelity,
        applicability = reason,
        status = :not_applicable,
        solver_name = spec.id,
        solver_version = spec.version,
        input_hash = genome.physics_hash,
        run_hash = run_hash,
        warnings = [reason])
    return EvaluationBundle(spec.id, genome.design_id, genome.family, spec.fidelity,
        :not_applicable, [metric], [reason], genome.physics_hash, run_hash,
        spec.claim_ceiling)
end

function _error_bundle(spec::EvaluatorSpec, genome::Genome, message::String)
    run_hash = canonical_hash(Dict(
        "evaluator" => spec.id,
        "version" => spec.version,
        "input_hash" => genome.physics_hash,
        "status" => "error",
        "message" => message,
    ))
    metric = MetricResult("evaluator_error", nothing;
        fidelity = spec.fidelity,
        applicability = "evaluator failed before a valid metric was produced",
        status = :error,
        solver_name = spec.id,
        solver_version = spec.version,
        input_hash = genome.physics_hash,
        run_hash = run_hash,
        warnings = [message])
    return EvaluationBundle(spec.id, genome.design_id, genome.family, spec.fidelity,
        :error, [metric], [message], genome.physics_hash, run_hash,
        spec.claim_ceiling)
end

function evaluate_design(registry::EvaluatorRegistry, evaluator_id::AbstractString,
        genome::Genome; kwargs...)
    id = String(evaluator_id)
    haskey(registry.evaluators, id) || throw(KeyError("unregistered evaluator: $id"))
    evaluator = registry.evaluators[id]
    spec = evaluator_spec(evaluator)
    report = validate_genome(genome)
    report.valid || return _error_bundle(spec, genome,
        "invalid genome: $(join(report.errors, "; "))")
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(spec, genome, reason)
    try
        return run_evaluator(evaluator, genome; kwargs...)
    catch error
        return _error_bundle(spec, genome, sprint(showerror, error))
    end
end
