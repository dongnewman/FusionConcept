struct TokamakAxisymmetricProxyV1 <: AbstractEvaluator
    model_root::String
    runner_path::String
    project_root::String

    function TokamakAxisymmetricProxyV1(model_root::AbstractString = normpath(joinpath(
            @__DIR__, "..", "..", "..", "iter_tokamak_julia_model")))
        root = abspath(String(model_root))
        runner = normpath(joinpath(@__DIR__, "..", "..", "scripts",
            "legacy_tokamak_proxy_runner.jl"))
        project = normpath(joinpath(@__DIR__, "..", ".."))
        isfile(joinpath(root, "interactive_demo_server.jl")) ||
            throw(ArgumentError("legacy tokamak model not found at $root"))
        isfile(runner) || throw(ArgumentError("legacy adapter runner not found at $runner"))
        return new(root, runner, project)
    end
end

function evaluator_spec(::TokamakAxisymmetricProxyV1)
    return EvaluatorSpec(
        "tokamak_axisymmetric_proxy_v1",
        "1.0.0",
        ["tokamak_axisymmetric"],
        0,
        Dict(
            "guiding_center_orbits" => :proxy,
            "error_field_sensitivity" => :proxy,
            "finite_build_coils" => :proxy,
            "quench" => :proxy,
        ),
        "screening_only",
    )
end

_approx(value, target; rtol = 1.0e-9, atol = 1.0e-9) =
    value !== nothing && isapprox(value, target; rtol = rtol, atol = atol)

function _legacy_binding_mismatches(genome::Genome)
    mismatches = String[]
    genome.family == "tokamak_axisymmetric" || push!(mismatches, "family")
    genome.topology.field_line_class == "closed_toroidal_separatrix" ||
        push!(mismatches, "field_line_class")
    genome.symmetry.class == "axisymmetric" || push!(mismatches, "symmetry")

    major = quantity(genome, :plasma_regions, "tokamak_core", "major_radius")
    minor = quantity(genome, :plasma_regions, "tokamak_core", "minor_radius")
    elongation = quantity(genome, :plasma_regions, "tokamak_core", "elongation")
    triangularity = quantity(genome, :plasma_regions, "tokamak_core", "triangularity")
    tf_count = quantity(genome, :field_sources, "tokamak_tf_system", "coil_count")
    pf_count = quantity(genome, :field_sources, "tokamak_pf_system", "coil_count")
    cs_count = quantity(genome, :field_sources, "tokamak_cs_system", "module_count")
    plasma_current = quantity(genome, :field_sources, "tokamak_plasma_current", "total_current")

    _approx(major === nothing ? nothing : major.value, 6.2) || push!(mismatches, "major_radius=6.2 m")
    _approx(minor === nothing ? nothing : minor.value, 2.0) || push!(mismatches, "minor_radius=2.0 m")
    _approx(elongation === nothing ? nothing : elongation.value, 1.85) || push!(mismatches, "elongation=1.85")
    _approx(triangularity === nothing ? nothing : triangularity.value, 0.49) || push!(mismatches, "triangularity=0.49")
    _approx(tf_count === nothing ? nothing : tf_count.value, 24.0) || push!(mismatches, "TF count=24")
    _approx(pf_count === nothing ? nothing : pf_count.value, 6.0) || push!(mismatches, "PF count=6")
    _approx(cs_count === nothing ? nothing : cs_count.value, 4.0) || push!(mismatches, "CS count=4")
    _approx(plasma_current === nothing ? nothing : plasma_current.value, 15.0e6) ||
        push!(mismatches, "plasma current=15 MA")
    on_axis = get(genome.mission.targets, "on_axis_field", nothing)
    _approx(on_axis === nothing ? nothing : on_axis.value, 5.3) ||
        push!(mismatches, "on-axis field=5.3 T")
    return mismatches
end

function evaluator_applicability(adapter::TokamakAxisymmetricProxyV1, genome::Genome)
    spec = evaluator_spec(adapter)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    mismatches = _legacy_binding_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact fixed ITER-scale legacy binding" :
        "fixed legacy model binding mismatch: $(join(mismatches, ", "))"
end

function _proxy_metric(id, value, unit, status, spec, genome, run_hash,
        applicability, sources, warnings, wall_time; constraints = String[])
    return MetricResult(id, value;
        unit = unit,
        fidelity = spec.fidelity,
        applicability = applicability,
        status = status,
        constraints_checked = constraints,
        solver_name = spec.id,
        solver_version = spec.version,
        input_hash = genome.physics_hash,
        run_hash = run_hash,
        source_basis = sources,
        warnings = warnings,
        wall_time_s = wall_time)
end

function run_evaluator(adapter::TokamakAxisymmetricProxyV1, genome::Genome; kwargs...)
    spec = evaluator_spec(adapter)
    mismatches = _legacy_binding_mismatches(genome)
    isempty(mismatches) || return _non_applicable_bundle(spec, genome,
        "fixed legacy model binding mismatch: $(join(mismatches, ", "))")

    elapsed = @elapsed raw = mktemp() do output_path, io
        close(io)
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(adapter.project_root) $(adapter.runner_path) --model-root $(adapter.model_root) --output $(output_path)`
        run(command)
        return _plain_json(JSON3.read(read(output_path, String), Dict{String,Any}))
    end

    settings = Dict{String,Any}("mode" => "deterministic_boundary_and_engineering")
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => spec.id,
        "version" => spec.version,
        "legacy_source_hash" => raw["legacy_source_hash"],
        "settings" => settings,
        "metrics" => raw["metrics"],
    ))
    applicability = "Only the fixed ITER-scale analytic tokamak proxy and its current optimized coil configuration."
    sources = String[
        "interactive_demo_server.jl",
        "optimized_coil_config.jl",
        "concept_engineering.jl",
        "concept_verification.jl",
    ]
    warnings = String[
        "Analytic plasma field; not a self-consistent free-boundary equilibrium.",
        "Boundary and engineering values are screening proxies, not reactor validation.",
        "No particle, burning-plasma, exhaust, neutronics, TBR, RAMI, or net-electric evaluation was run.",
    ]
    append!(warnings, String.(get(raw, "engineering_unknowns", Any[])))
    values = raw["metrics"]
    feasible = Bool(values["engineering_feasible"])
    utilization_status(value) = Float64(value) <= 1.0 ? :pass : :fail

    metrics = MetricResult[
        _proxy_metric("boundary_bn_rms_proxy", Float64(values["boundary_bn_rms_T"]), "T", :pass,
            spec, genome, run_hash, applicability, sources, warnings, elapsed),
        _proxy_metric("boundary_bn_max_proxy", Float64(values["boundary_bn_max_T"]), "T", :pass,
            spec, genome, run_hash, applicability, sources, warnings, elapsed),
        _proxy_metric("q95_proxy", Float64(values["q95"]), "1", :pass,
            spec, genome, run_hash, applicability, sources, warnings, elapsed),
        _proxy_metric("q_spread_proxy", Float64(values["q_spread"]), "1", :pass,
            spec, genome, run_hash, applicability, sources, warnings, elapsed),
        _proxy_metric("toroidal_field_ripple_proxy", Float64(values["tf_ripple"]), "1", :pass,
            spec, genome, run_hash, applicability, sources, warnings, elapsed),
        _proxy_metric("engineering_feasible_proxy", feasible, "1", feasible ? :pass : :fail,
            spec, genome, run_hash, applicability, sources, warnings, elapsed;
            constraints = ["all reduced engineering screens"]),
        _proxy_metric("engineering_score_proxy", Float64(values["engineering_score"]), "1", :pass,
            spec, genome, run_hash, applicability, sources, warnings, elapsed),
        _proxy_metric("current_utilization_proxy", Float64(values["current_utilization"]), "1",
            utilization_status(values["current_utilization"]), spec, genome, run_hash,
            applicability, sources, warnings, elapsed; constraints = ["current-field envelope"]),
        _proxy_metric("stress_utilization_proxy", Float64(values["stress_utilization"]), "1",
            utilization_status(values["stress_utilization"]), spec, genome, run_hash,
            applicability, sources, warnings, elapsed; constraints = ["reduced structural stress screen"]),
        _proxy_metric("clearance_utilization_proxy", Float64(values["clearance_utilization"]), "1",
            utilization_status(values["clearance_utilization"]), spec, genome, run_hash,
            applicability, sources, warnings, elapsed; constraints = ["plasma and coil clearance screen"]),
        _proxy_metric("quench_utilization_proxy", Float64(values["quench_utilization"]), "1",
            utilization_status(values["quench_utilization"]), spec, genome, run_hash,
            applicability, sources, warnings, elapsed; constraints = ["reduced quench and dump screen"]),
        _proxy_metric("thermal_hydraulic_utilization_proxy", Float64(values["thermal_hydraulic_utilization"]), "1",
            utilization_status(values["thermal_hydraulic_utilization"]), spec, genome, run_hash,
            applicability, sources, warnings, elapsed; constraints = ["reduced forced-flow helium screen"]),
        _proxy_metric("fatigue_utilization_proxy", Float64(values["fatigue_utilization"]), "1",
            utilization_status(values["fatigue_utilization"]), spec, genome, run_hash,
            applicability, sources, warnings, elapsed; constraints = ["reduced fatigue screen"]),
        _proxy_metric("flux_utilization_proxy", Float64(values["flux_utilization"]), "1",
            utilization_status(values["flux_utilization"]), spec, genome, run_hash,
            applicability, sources, warnings, elapsed; constraints = ["reduced flux response screen"]),
    ]
    bundle_status = feasible && all(metric -> metric.status != :fail, metrics) ? :pass : :fail
    return EvaluationBundle(spec.id, genome.design_id, genome.family, spec.fidelity,
        bundle_status, metrics, warnings, genome.physics_hash, run_hash,
        spec.claim_ceiling)
end
