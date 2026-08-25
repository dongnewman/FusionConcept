"A fail-closed mapping from one exact solver output contract to a generic metric."
struct SolverEvidenceBridgeContractV1
    evaluator_id::String
    capability_id::String
    target_metric_id::String
    required_source_metric_ids::Vector{String}
    applicability::String
    claim_ceiling::String
    promotion_authority::Bool

    function SolverEvidenceBridgeContractV1(evaluator_id::AbstractString,
            capability_id::AbstractString, target_metric_id::AbstractString,
            required_source_metric_ids, applicability::AbstractString,
            claim_ceiling::AbstractString; promotion_authority::Bool = false)
        promotion_authority && throw(ArgumentError(
            "solver evidence bridge contracts cannot grant promotion authority"))
        isempty(required_source_metric_ids) && throw(ArgumentError(
            "solver evidence bridge requires at least one source metric"))
        return new(String(evaluator_id), String(capability_id),
            String(target_metric_id), sort!(unique(String.(collect(required_source_metric_ids)))),
            String(applicability), String(claim_ceiling), false)
    end
end

struct SolverEvidenceBridgeResultV1
    design_id::String
    source_evaluator_id::String
    authorized_contract_ids::Vector{String}
    rejected_contract_ids::Vector{String}
    normalized_bundle::EvaluationBundle
    unmapped_stage_metric_ids::Vector{String}
    bridge_hash::String
end

function default_solver_evidence_bridge_contracts_v1()
    return SolverEvidenceBridgeContractV1[
        SolverEvidenceBridgeContractV1(
            "tokamak_free_boundary_freegs_v1", "maxwell_magnetostatic_field_v1",
            "field_solution_converged", ["free_boundary_equilibrium_converged"],
            "Axisymmetric magnetostatic/equilibrium field on the exact explicit-filament FreeGS domain.",
            "C1_partial_candidate_specific_solver_evidence"),
        SolverEvidenceBridgeContractV1(
            "tokamak_free_boundary_freegs_v1", "axisymmetric_current_equilibrium_v1",
            "equilibrium_converged", ["free_boundary_equilibrium_converged",
                "axisymmetric_force_balance_feasible"],
            "Axisymmetric scalar-pressure Grad-Shafranov balance on the declared FreeGS domain.",
            "C1_partial_candidate_specific_solver_evidence"),
        SolverEvidenceBridgeContractV1(
            "stellarator_fixed_boundary_desc_w7x_v1", "three_dimensional_mhd_equilibrium_v1",
            "equilibrium_converged", ["fixed_boundary_equilibrium_converged",
                "three_dimensional_force_balance_feasible"],
            "DESC packaged W7-X fixed-boundary scalar-pressure equilibrium only.",
            "C1_partial_known_device_control"),
        SolverEvidenceBridgeContractV1(
            "stellarator_fixed_boundary_desc_fourier_v1", "three_dimensional_mhd_equilibrium_v1",
            "equilibrium_converged", ["fixed_boundary_equilibrium_converged",
                "three_dimensional_force_balance_feasible"],
            "DESC explicit Fourier fixed-boundary scalar-pressure equilibrium only.",
            "C1_partial_candidate_specific_solver_evidence"),
        SolverEvidenceBridgeContractV1(
            "mirror_isotropic_pleiades_wham_v1", "maxwell_magnetostatic_field_v1",
            "field_solution_converged", ["axisymmetric_vacuum_field_feasible"],
            "Pinned public Pleiades WHAM axisymmetric vacuum field only.",
            "C1_partial_known_device_control"),
        SolverEvidenceBridgeContractV1(
            "mirror_isotropic_pleiades_wham_v1", "open_field_finite_beta_equilibrium_v1",
            "equilibrium_converged", ["isotropic_equilibrium_converged",
                "finite_beta_equilibrium_feasible"],
            "Public Pleiades scalar-pressure isotropic mirror equilibrium; anisotropy and kinetic stability remain unknown.",
            "C1_partial_known_device_control"),
    ]
end

function _declared_available_bridges_v1(program::CompiledExecutablePhysicsProgramV1,
        executable::ExecutableGenomeV1)
    result = Set{Tuple{String,String}}()
    active = Set(program.active_operator_ids)
    compiled_status = Dict(item.module_id => item.status for item in program.modules)
    for physics_module in executable.modules, backend in physics_module.backend_requirements
        get(compiled_status, physics_module.id, :invalid) == :ready_for_execution || continue
        backend.status == :available || continue
        backend.capability_id in active || continue
        push!(result, (backend.implementation_id, backend.capability_id))
    end
    return result
end

function _source_metric_map_v1(bundle::EvaluationBundle)
    result = Dict{String,Vector{MetricResult}}()
    for metric in bundle.metrics
        push!(get!(result, metric.metric_id, MetricResult[]), metric)
    end
    return result
end

function _bridge_status_v1(required_ids::Vector{String},
        source_metrics::Dict{String,Vector{MetricResult}})
    missing = String[id for id in required_ids if !haskey(source_metrics, id)]
    isempty(missing) || return :unknown, missing, MetricResult[]
    selected = MetricResult[]
    for id in required_ids
        records = source_metrics[id]
        best = sort!(copy(records); by = item -> (-item.fidelity, item.run_hash))[1]
        push!(selected, best)
    end
    any(item -> item.status in (:unknown, :not_applicable, :error), selected) &&
        return :unknown, String[], selected
    any(item -> item.status == :fail || item.value === false, selected) &&
        return :fail, String[], selected
    all(item -> item.status == :pass && item.value !== nothing, selected) ||
        return :unknown, String[], selected
    return :pass, String[], selected
end

function _bridged_metric_v1(contract::SolverEvidenceBridgeContractV1,
        bundle::EvaluationBundle, source_metrics::Dict{String,Vector{MetricResult}})
    status, missing, selected = _bridge_status_v1(
        contract.required_source_metric_ids, source_metrics)
    fidelity = isempty(selected) ? 0 : minimum(getfield.(selected, :fidelity))
    source_runs = sort!(unique(getfield.(selected, :run_hash)))
    run_hash = canonical_hash(Dict{String,Any}(
        "bridge_version" => "1.0.0", "source_evaluator" => bundle.evaluator_id,
        "source_bundle_run_hash" => bundle.run_hash,
        "capability_id" => contract.capability_id,
        "target_metric_id" => contract.target_metric_id,
        "required_source_metric_ids" => contract.required_source_metric_ids,
        "source_run_hashes" => source_runs, "status" => String(status)))
    warnings = String[]
    isempty(missing) || push!(warnings,
        "missing source metrics: $(join(sort!(missing), ", "))")
    status == :unknown && isempty(missing) && push!(warnings,
        "source evidence is unknown, not applicable, or errored")
    return MetricResult(contract.target_metric_id,
        status in (:pass, :fail) ? status == :pass : nothing;
        fidelity = fidelity, applicability = contract.applicability,
        status = status, constraints_checked = copy(contract.required_source_metric_ids),
        solver_name = "solver_evidence_bridge_v1",
        solver_version = "1.0.0", input_hash = bundle.input_hash,
        run_hash = run_hash, source_basis = [bundle.evaluator_id],
        warnings = warnings)
end

const _GENERIC_STAGE_METRICS_V1 = sort!(unique(vcat(
    [pair.second for pair in _EVIDENCE_STAGE_METRICS_V1]...)))

"Normalize solver evidence only when an executable module declared that exact backend/capability pair."
function bridge_solver_evidence_v1(executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1, bundle::EvaluationBundle;
        contracts::Vector{SolverEvidenceBridgeContractV1} =
            default_solver_evidence_bridge_contracts_v1())
    bundle.design_id == executable.base_genome.design_id ||
        throw(ArgumentError("solver bundle design does not match executable Genome"))
    bundle.input_hash == executable.base_genome.physics_hash ||
        throw(ArgumentError("solver bundle is not bound to the executable Genome physics hash"))
    all(metric -> metric.input_hash == executable.base_genome.physics_hash,
        bundle.metrics) || throw(ArgumentError(
        "solver metrics are not bound to the executable Genome physics hash"))
    declared = _declared_available_bridges_v1(program, executable)
    matching = filter(contract -> contract.evaluator_id == bundle.evaluator_id, contracts)
    authorized = SolverEvidenceBridgeContractV1[]
    rejected = SolverEvidenceBridgeContractV1[]
    for contract in matching
        pair = (contract.evaluator_id, contract.capability_id)
        pair in declared ? push!(authorized, contract) : push!(rejected, contract)
    end
    source_metrics = _source_metric_map_v1(bundle)
    metrics = MetricResult[_bridged_metric_v1(contract, bundle, source_metrics)
        for contract in authorized]
    status = any(metric -> metric.status == :fail, metrics) ? :fail :
        any(metric -> metric.status in (:unknown, :error), metrics) ? :unknown :
        isempty(metrics) ? :unknown : :pass
    run_hash = canonical_hash(Dict{String,Any}(
        "bridge_version" => "1.0.0", "program_hash" => program.program_hash,
        "source_bundle_run_hash" => bundle.run_hash,
        "metric_run_hashes" => getfield.(metrics, :run_hash)))
    normalized = EvaluationBundle("solver_evidence_bridge_v1", bundle.design_id,
        bundle.family, isempty(metrics) ? 0 : maximum(getfield.(metrics, :fidelity)),
        status, metrics,
        ["Generic normalization does not add field-line, convergence, stability, transport, engineering, or promotion evidence absent from the source solver."],
        bundle.input_hash, run_hash, "C1_partial_solver_evidence_only")
    mapped = Set(getfield.(metrics, :metric_id))
    unmapped = sort!(String[id for id in _GENERIC_STAGE_METRICS_V1 if !(id in mapped)])
    contract_id(item) = "$(item.evaluator_id)::$(item.capability_id)::$(item.target_metric_id)"
    payload = Dict{String,Any}(
        "design_id" => bundle.design_id, "program_hash" => program.program_hash,
        "source_bundle_run_hash" => bundle.run_hash,
        "authorized_contract_ids" => contract_id.(authorized),
        "rejected_contract_ids" => contract_id.(rejected),
        "normalized_run_hash" => normalized.run_hash,
        "unmapped_stage_metric_ids" => unmapped)
    return SolverEvidenceBridgeResultV1(bundle.design_id, bundle.evaluator_id,
        sort!(contract_id.(authorized)), sort!(contract_id.(rejected)), normalized,
        unmapped, canonical_hash(payload))
end

function solver_evidence_bridge_to_dict_v1(item::SolverEvidenceBridgeResultV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "source_evaluator_id" => item.source_evaluator_id,
        "authorized_contract_ids" => item.authorized_contract_ids,
        "rejected_contract_ids" => item.rejected_contract_ids,
        "normalized_bundle" => evaluation_to_dict(item.normalized_bundle),
        "unmapped_stage_metric_ids" => item.unmapped_stage_metric_ids,
        "bridge_hash" => item.bridge_hash,
        "promotion_authorized" => false)
end
