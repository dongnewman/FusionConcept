const _RUNTIME_SCALE_STATUSES_V1 = Set((:pass, :fail, :unknown))
const _RUNTIME_MODULE_STATUSES_V1 = Set((:ready_for_execution,
    :blocked_unknown_scale, :blocked_ood_scale, :blocked_unknown_inputs,
    :blocked_backend, :migrated_unknown, :invalid))

"Candidate-bound resolution of one applicability scale declared by an executable module."
struct ApplicabilityScaleEvidenceV1
    design_id::String
    genome_physics_hash::String
    module_id::String
    parameter_id::String
    value::Union{Nothing,Float64}
    unit::String
    lower_bound::Union{Nothing,Float64}
    upper_bound::Union{Nothing,Float64}
    derivation::String
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    fidelity::Int
    status::Symbol
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    evidence_hash::String
end

"Candidate-bound availability evidence for one input declared by an executable module."
struct RuntimeInputEvidenceV1
    design_id::String
    genome_physics_hash::String
    module_id::String
    input_id::String
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    candidate_binding_verified::Bool
    fidelity::Int
    status::Symbol
    evidence_tasks::Vector{String}
    evidence_hash::String
end

"A sidecar view of module readiness after exact runtime scale evidence is applied."
struct RuntimeModuleResolutionV1
    design_id::String
    genome_physics_hash::String
    program_hash::String
    module_id::String
    base_status::Symbol
    runtime_status::Symbol
    resolved_scale_ids::Vector{String}
    out_of_domain_scale_ids::Vector{String}
    unknown_scale_ids::Vector{String}
    resolved_input_ids::Vector{String}
    unknown_input_ids::Vector{String}
    evidence_tasks::Vector{String}
    resolution_hash::String
end

"Candidate-bound equilibrium result with a separate C2 support authorization bit."
struct EquilibriumConvergenceEvidenceV1
    design_id::String
    genome_physics_hash::String
    module_id::String
    capability_id::String
    implementation_id::String
    runtime_resolution_hash::String
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    source_solver_status::Symbol
    solver_converged::Bool
    force_balance_passed::Bool
    independent_residual_verified::Bool
    resolution_verified::Bool
    candidate_binding_verified::Bool
    fidelity::Int
    minimum_c2_fidelity::Int
    residuals::Dict{String,Float64}
    constraints_checked::Vector{String}
    status::Symbol
    c2_support_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    evidence_hash::String
end

function _executable_module_v1(executable::ExecutableGenomeV1,
        module_id::AbstractString)
    matches = filter(item -> item.id == module_id, executable.modules)
    length(matches) == 1 || throw(ArgumentError(
        "expected exactly one executable module named $module_id"))
    return only(matches)
end

function _compiled_module_v1(program::CompiledExecutablePhysicsProgramV1,
        module_id::AbstractString)
    matches = filter(item -> item.module_id == module_id, program.modules)
    length(matches) == 1 || throw(ArgumentError(
        "expected exactly one compiled module named $module_id"))
    return only(matches)
end

function _scale_spec_v1(physics_module::ExecutablePhysicsModuleV1,
        parameter_id::AbstractString)
    matches = filter(item -> item.parameter_id == parameter_id,
        physics_module.applicability_scales)
    length(matches) == 1 || throw(ArgumentError(
        "expected exactly one scale named $parameter_id in module $(physics_module.id)"))
    return only(matches)
end

"Resolve one exact module scale without mutating the sealed executable Genome."
function resolve_applicability_scale_v1(executable::ExecutableGenomeV1,
        module_id::AbstractString, parameter_id::AbstractString;
        value::Union{Nothing,Real} = nothing, unit::AbstractString,
        derivation::AbstractString, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        candidate_binding_verified::Bool, fidelity::Integer)
    fidelity >= 0 || throw(ArgumentError("scale fidelity must be non-negative"))
    physics_module = _executable_module_v1(executable, module_id)
    scale = _scale_spec_v1(physics_module, parameter_id)
    numeric_value = value === nothing ? nothing : Float64(value)
    numeric_value === nothing || isfinite(numeric_value) ||
        throw(ArgumentError("scale value must be finite or nothing"))

    tasks = String[]
    warnings = String[]
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    isempty(source_artifact_hash) && push!(tasks, "provide_source_artifact_hash")
    isempty(source_result_hash) && push!(tasks, "provide_source_result_hash")
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    numeric_value === nothing && push!(tasks, "derive_scale_value:$(scale.parameter_id)")
    String(unit) == scale.unit || push!(tasks, "convert_scale_unit:$(scale.unit)")

    out_of_domain = numeric_value !== nothing && String(unit) == scale.unit &&
        ((scale.lower_bound !== nothing && numeric_value < scale.lower_bound) ||
         (scale.upper_bound !== nothing && numeric_value > scale.upper_bound))
    out_of_domain && push!(warnings,
        "candidate scale lies outside the module's declared numeric applicability bounds")
    provenance_complete = !isempty(source_artifact_id) &&
        !isempty(source_artifact_hash) && !isempty(source_result_hash)
    status = out_of_domain ? :fail :
        (candidate_binding_verified && provenance_complete && numeric_value !== nothing &&
         String(unit) == scale.unit ? :pass : :unknown)

    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => executable.base_genome.design_id,
        "genome_physics_hash" => executable.base_genome.physics_hash,
        "module_id" => String(module_id), "parameter_id" => String(parameter_id),
        "value" => numeric_value, "unit" => String(unit),
        "lower_bound" => scale.lower_bound, "upper_bound" => scale.upper_bound,
        "derivation" => String(derivation),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "fidelity" => Int(fidelity), "status" => String(status),
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return ApplicabilityScaleEvidenceV1(executable.base_genome.design_id,
        executable.base_genome.physics_hash, String(module_id), String(parameter_id),
        numeric_value, String(unit), scale.lower_bound, scale.upper_bound,
        String(derivation), String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified, Int(fidelity), status,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

function applicability_scale_evidence_to_dict_v1(item::ApplicabilityScaleEvidenceV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "module_id" => item.module_id, "parameter_id" => item.parameter_id,
        "value" => item.value, "unit" => item.unit,
        "lower_bound" => item.lower_bound, "upper_bound" => item.upper_bound,
        "derivation" => item.derivation,
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "fidelity" => item.fidelity, "status" => String(item.status),
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "evidence_hash" => item.evidence_hash)
end

"Resolve one module input from an exact candidate-bound source artifact."
function resolve_runtime_input_v1(executable::ExecutableGenomeV1,
        module_id::AbstractString, input_id::AbstractString;
        source_artifact_id::AbstractString, source_artifact_hash::AbstractString,
        source_result_hash::AbstractString, candidate_binding_verified::Bool,
        fidelity::Integer, available::Bool = true)
    fidelity >= 0 || throw(ArgumentError("input evidence fidelity must be non-negative"))
    physics_module = _executable_module_v1(executable, module_id)
    String(input_id) in physics_module.input_ids || throw(ArgumentError(
        "input $input_id is not declared by module $module_id"))
    tasks = String[]
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    isempty(source_artifact_hash) && push!(tasks, "provide_source_artifact_hash")
    isempty(source_result_hash) && push!(tasks, "provide_source_result_hash")
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    available || push!(tasks, "provide_runtime_input:$(String(input_id))")
    provenance_complete = !isempty(source_artifact_id) &&
        !isempty(source_artifact_hash) && !isempty(source_result_hash)
    status = available && candidate_binding_verified && provenance_complete ?
        :pass : :unknown
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => executable.base_genome.design_id,
        "genome_physics_hash" => executable.base_genome.physics_hash,
        "module_id" => String(module_id), "input_id" => String(input_id),
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "candidate_binding_verified" => candidate_binding_verified,
        "fidelity" => Int(fidelity), "status" => String(status),
        "evidence_tasks" => sort!(unique(tasks)))
    return RuntimeInputEvidenceV1(executable.base_genome.design_id,
        executable.base_genome.physics_hash, String(module_id), String(input_id),
        String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), candidate_binding_verified, Int(fidelity), status,
        sort!(unique(tasks)), canonical_hash(core))
end

function runtime_input_evidence_to_dict_v1(item::RuntimeInputEvidenceV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "module_id" => item.module_id, "input_id" => item.input_id,
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "fidelity" => item.fidelity, "status" => String(item.status),
        "evidence_tasks" => item.evidence_tasks,
        "evidence_hash" => item.evidence_hash)
end

"Apply exact scale evidence to one module as a versioned runtime sidecar."
function resolve_runtime_module_v1(executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1, module_id::AbstractString,
        scale_evidence::Vector{ApplicabilityScaleEvidenceV1};
        input_evidence::Vector{RuntimeInputEvidenceV1} = RuntimeInputEvidenceV1[])
    program.design_id == executable.base_genome.design_id ||
        throw(ArgumentError("compiled program design does not match executable Genome"))
    physics_module = _executable_module_v1(executable, module_id)
    compiled = _compiled_module_v1(program, module_id)
    expected = sort!(String[item.parameter_id for item in
        physics_module.applicability_scales if item.status == :unknown])
    by_id = Dict{String,ApplicabilityScaleEvidenceV1}()
    for item in scale_evidence
        item.design_id == executable.base_genome.design_id ||
            throw(ArgumentError("scale evidence design mismatch"))
        item.genome_physics_hash == executable.base_genome.physics_hash ||
            throw(ArgumentError("scale evidence Genome hash mismatch"))
        item.module_id == module_id || throw(ArgumentError("scale evidence module mismatch"))
        haskey(by_id, item.parameter_id) && throw(ArgumentError(
            "duplicate scale evidence for $(item.parameter_id)"))
        by_id[item.parameter_id] = item
    end
    extras = sort!(String[id for id in keys(by_id) if !(id in expected)])
    isempty(extras) || throw(ArgumentError(
        "runtime evidence supplied for scales not declared unknown: $(join(extras, ", "))"))
    resolved = sort!(String[id for id in expected if
        haskey(by_id, id) && by_id[id].status == :pass])
    ood = sort!(String[id for id in expected if
        haskey(by_id, id) && by_id[id].status == :fail])
    unknown = sort!(String[id for id in expected if
        !haskey(by_id, id) || by_id[id].status == :unknown])
    input_by_id = Dict{String,RuntimeInputEvidenceV1}()
    for item in input_evidence
        item.design_id == executable.base_genome.design_id ||
            throw(ArgumentError("runtime input evidence design mismatch"))
        item.genome_physics_hash == executable.base_genome.physics_hash ||
            throw(ArgumentError("runtime input evidence Genome hash mismatch"))
        item.module_id == module_id || throw(ArgumentError(
            "runtime input evidence module mismatch"))
        item.input_id in compiled.missing_input_ids || throw(ArgumentError(
            "runtime input evidence supplied for an input not missing at compile time"))
        haskey(input_by_id, item.input_id) && throw(ArgumentError(
            "duplicate runtime input evidence for $(item.input_id)"))
        input_by_id[item.input_id] = item
    end
    resolved_inputs = sort!(String[id for id in compiled.missing_input_ids if
        haskey(input_by_id, id) && input_by_id[id].status == :pass])
    unknown_inputs = sort!(String[id for id in compiled.missing_input_ids if
        !haskey(input_by_id, id) || input_by_id[id].status != :pass])
    tasks = String[]
    append!(tasks, ["resolve_scale:$id" for id in unknown])
    append!(tasks, ["repair_out_of_domain_scale:$id" for id in ood])
    append!(tasks, ["resolve_runtime_input:$id" for id in unknown_inputs])

    runtime_status = compiled.status == :migrated_unknown ? :migrated_unknown :
        !isempty(unknown_inputs) ? :blocked_unknown_inputs :
        !isempty(compiled.unavailable_capability_ids) ? :blocked_backend :
        !isempty(ood) ? :blocked_ood_scale :
        !isempty(unknown) ? :blocked_unknown_scale : :ready_for_execution
    runtime_status in _RUNTIME_MODULE_STATUSES_V1 || error("invalid runtime status")
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => executable.base_genome.design_id,
        "genome_physics_hash" => executable.base_genome.physics_hash,
        "program_hash" => program.program_hash, "module_id" => String(module_id),
        "base_status" => String(compiled.status),
        "runtime_status" => String(runtime_status),
        "resolved_scale_ids" => resolved, "out_of_domain_scale_ids" => ood,
        "unknown_scale_ids" => unknown,
        "scale_evidence_hashes" => sort!(String[item.evidence_hash for item in values(by_id)]),
        "resolved_input_ids" => resolved_inputs,
        "unknown_input_ids" => unknown_inputs,
        "input_evidence_hashes" => sort!(String[item.evidence_hash for item in values(input_by_id)]),
        "evidence_tasks" => sort!(unique(tasks)))
    return RuntimeModuleResolutionV1(executable.base_genome.design_id,
        executable.base_genome.physics_hash, program.program_hash, String(module_id),
        compiled.status, runtime_status, resolved, ood, unknown,
        resolved_inputs, unknown_inputs,
        sort!(unique(tasks)), canonical_hash(core))
end

function runtime_module_resolution_to_dict_v1(item::RuntimeModuleResolutionV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "program_hash" => item.program_hash, "module_id" => item.module_id,
        "base_status" => String(item.base_status),
        "runtime_status" => String(item.runtime_status),
        "resolved_scale_ids" => item.resolved_scale_ids,
        "out_of_domain_scale_ids" => item.out_of_domain_scale_ids,
        "unknown_scale_ids" => item.unknown_scale_ids,
        "resolved_input_ids" => item.resolved_input_ids,
        "unknown_input_ids" => item.unknown_input_ids,
        "evidence_tasks" => item.evidence_tasks,
        "resolution_hash" => item.resolution_hash)
end

"Compile one equilibrium solver record into fail-closed C2 equilibrium support."
function compile_equilibrium_convergence_evidence_v1(
        executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1,
        runtime::RuntimeModuleResolutionV1;
        implementation_id::AbstractString, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        source_solver_status::Symbol, solver_converged::Bool,
        force_balance_passed::Bool, independent_residual_verified::Bool,
        resolution_verified::Bool, candidate_binding_verified::Bool,
        fidelity::Integer, residuals::Dict{String,Float64},
        constraints_checked::Vector{String}, warnings::Vector{String} = String[])
    fidelity >= 0 || throw(ArgumentError("equilibrium fidelity must be non-negative"))
    source_solver_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid source solver status"))
    all(isfinite, values(residuals)) || throw(ArgumentError(
        "equilibrium residuals must be finite"))
    physics_module = _executable_module_v1(executable, runtime.module_id)
    physics_module.role == :equilibrium || throw(ArgumentError(
        "equilibrium evidence requires an equilibrium-role module"))
    runtime.design_id == executable.base_genome.design_id ||
        throw(ArgumentError("runtime resolution design mismatch"))
    runtime.genome_physics_hash == executable.base_genome.physics_hash ||
        throw(ArgumentError("runtime resolution Genome hash mismatch"))
    runtime.program_hash == program.program_hash ||
        throw(ArgumentError("runtime resolution program hash mismatch"))
    backends = filter(item -> item.implementation_id == implementation_id,
        physics_module.backend_requirements)
    length(backends) == 1 || throw(ArgumentError(
        "expected exactly one equilibrium backend named $implementation_id"))
    backend = only(backends)
    backend.status == :available || throw(ArgumentError(
        "equilibrium backend is not declared available"))
    backend.capability_id in program.active_operator_ids || throw(ArgumentError(
        "equilibrium capability is not active for the physical topology"))
    minimum_c2_fidelity = max(2, backend.minimum_fidelity)

    tasks = String[]
    runtime.runtime_status == :ready_for_execution || push!(tasks,
        "resolve_runtime_module:$(runtime.module_id)")
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    isempty(source_artifact_hash) && push!(tasks, "provide_source_artifact_hash")
    isempty(source_result_hash) && push!(tasks, "provide_source_result_hash")
    independent_residual_verified || push!(tasks, "verify_independent_force_balance_residual")
    resolution_verified || push!(tasks, "run_equilibrium_resolution_convergence")
    fidelity < minimum_c2_fidelity && push!(tasks,
        "raise_equilibrium_fidelity_to:$minimum_c2_fidelity")
    isempty(residuals) && push!(tasks, "provide_force_balance_residuals")
    isempty(constraints_checked) && push!(tasks, "declare_convergence_constraints")
    source_solver_status in (:unknown, :error) && push!(tasks, "repair_source_solver_record")

    numerical_failure = source_solver_status == :fail || !solver_converged ||
        !force_balance_passed
    evidence_complete = runtime.runtime_status == :ready_for_execution &&
        candidate_binding_verified && !isempty(source_artifact_id) &&
        !isempty(source_artifact_hash) && !isempty(source_result_hash) &&
        source_solver_status == :pass && independent_residual_verified &&
        resolution_verified && fidelity >= minimum_c2_fidelity &&
        !isempty(residuals) && !isempty(constraints_checked)
    status = numerical_failure ? :fail : evidence_complete ? :pass : :unknown
    authorized = status == :pass
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => executable.base_genome.design_id,
        "genome_physics_hash" => executable.base_genome.physics_hash,
        "module_id" => runtime.module_id,
        "capability_id" => backend.capability_id,
        "implementation_id" => String(implementation_id),
        "runtime_resolution_hash" => runtime.resolution_hash,
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "source_solver_status" => String(source_solver_status),
        "solver_converged" => solver_converged,
        "force_balance_passed" => force_balance_passed,
        "independent_residual_verified" => independent_residual_verified,
        "resolution_verified" => resolution_verified,
        "candidate_binding_verified" => candidate_binding_verified,
        "fidelity" => Int(fidelity), "minimum_c2_fidelity" => minimum_c2_fidelity,
        "residuals" => residuals,
        "constraints_checked" => sort!(unique(copy(constraints_checked))),
        "status" => String(status), "c2_support_authorized" => authorized,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return EquilibriumConvergenceEvidenceV1(executable.base_genome.design_id,
        executable.base_genome.physics_hash, runtime.module_id,
        backend.capability_id, String(implementation_id), runtime.resolution_hash,
        String(source_artifact_id), String(source_artifact_hash),
        String(source_result_hash), source_solver_status, solver_converged,
        force_balance_passed, independent_residual_verified, resolution_verified,
        candidate_binding_verified, Int(fidelity), minimum_c2_fidelity,
        copy(residuals), sort!(unique(copy(constraints_checked))), status, authorized,
        sort!(unique(tasks)), copy(warnings), canonical_hash(core))
end

function equilibrium_convergence_evidence_to_dict_v1(
        item::EquilibriumConvergenceEvidenceV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "module_id" => item.module_id, "capability_id" => item.capability_id,
        "implementation_id" => item.implementation_id,
        "runtime_resolution_hash" => item.runtime_resolution_hash,
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "source_solver_status" => String(item.source_solver_status),
        "solver_converged" => item.solver_converged,
        "force_balance_passed" => item.force_balance_passed,
        "independent_residual_verified" => item.independent_residual_verified,
        "resolution_verified" => item.resolution_verified,
        "candidate_binding_verified" => item.candidate_binding_verified,
        "fidelity" => item.fidelity,
        "minimum_c2_fidelity" => item.minimum_c2_fidelity,
        "residuals" => item.residuals,
        "constraints_checked" => item.constraints_checked,
        "status" => String(item.status),
        "c2_support_authorized" => item.c2_support_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "evidence_hash" => item.evidence_hash)
end

function equilibrium_convergence_evidence_bundle_v1(
        executable::ExecutableGenomeV1, item::EquilibriumConvergenceEvidenceV1)
    item.design_id == executable.base_genome.design_id ||
        throw(ArgumentError("equilibrium evidence design mismatch"))
    item.genome_physics_hash == executable.base_genome.physics_hash ||
        throw(ArgumentError("equilibrium evidence Genome hash mismatch"))
    metric_value = item.status == :pass ? true : item.status == :fail ? false : nothing
    metric = MetricResult("equilibrium_converged", metric_value;
        fidelity = item.fidelity,
        applicability = "Candidate-bound equilibrium on the exact executable module and runtime-resolved scales only.",
        status = item.status, constraints_checked = item.constraints_checked,
        solver_name = "runtime_equilibrium_evidence_compiler_v1",
        solver_version = "1.0.0", input_hash = item.genome_physics_hash,
        run_hash = item.evidence_hash,
        source_basis = [item.source_artifact_id, item.implementation_id],
        warnings = vcat(item.warnings, item.evidence_tasks), residuals = item.residuals)
    claim = item.c2_support_authorized ?
        "C2_support_equilibrium_convergence_only" :
        "C2_equilibrium_support_unknown_or_failed"
    return EvaluationBundle("runtime_equilibrium_evidence_compiler_v1",
        item.design_id, executable.base_genome.family, item.fidelity, item.status,
        [metric], copy(metric.warnings), item.genome_physics_hash,
        item.evidence_hash, claim)
end
