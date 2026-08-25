const _EXECUTABLE_MODULE_ROLES_V1 = Set((:field, :topology, :equilibrium,
    :transport, :stability, :conservation, :production, :engineering,
    :control, :exhaust, :coupling))
const _STATE_FIELD_TYPES_V1 = Set((:scalar, :vector, :tensor, :distribution,
    :circuit, :geometry))
const _TIME_BEHAVIORS_V1 = Set((:static, :steady_state, :transient, :periodic,
    :event_driven))
const _EQUATION_CLASSES_V1 = Set((:maxwell, :field_line, :force_balance,
    :particle_balance, :energy_balance, :momentum_balance, :current_balance,
    :magnetic_flux_balance, :transport, :stability, :reaction, :radiation,
    :circuit, :mechanics, :heat_transfer, :control, :geometry))
const _EQUATION_FORMS_V1 = Set((:pde, :ode, :algebraic, :integral,
    :eigenproblem, :particle_push, :optimization, :constraint))
const _CLOSURE_LEVELS_V1 = Set((:first_principles, :reduced_physics,
    :calibrated_closure, :empirical_prior, :unknown))
const _BOUNDARY_KINDS_V1 = Set((:dirichlet, :neumann, :robin, :periodic,
    :interface, :open, :absorbing, :conducting, :magnetic_surface,
    :separatrix, :symmetry, :none))
const _TERM_KINDS_V1 = Set((:source, :loss, :exchange, :none))
const _SCALE_STATUSES_V1 = Set((:declared, :derived, :unknown))
const _BACKEND_STATUSES_V1 = Set((:available, :planned, :blocked))
const _MODULE_DECLARATION_STATUSES_V1 = Set((:explicit, :migrated_unknown))
const _COMPILED_MODULE_STATUSES_V1 = Set((:ready_for_execution,
    :blocked_unknown_inputs, :blocked_backend, :blocked_unknown_scale,
    :migrated_unknown, :invalid))

struct PhysicsStateVariableSpecV1
    id::String
    field_type::Symbol
    domain_ids::Vector{String}
    species::Vector{String}
    unit::String
    time_behavior::Symbol
end

struct PhysicsEquationSpecV1
    id::String
    equation_class::Symbol
    form::Symbol
    state_variable_ids::Vector{String}
    input_ids::Vector{String}
    output_ids::Vector{String}
    closure_level::Symbol
    applicability_conditions::Vector{String}
end

struct PhysicsBoundaryConditionSpecV1
    id::String
    domain_ids::Vector{String}
    state_variable_id::String
    kind::Symbol
    data_input_ids::Vector{String}
end

struct PhysicsSourceLossTermSpecV1
    id::String
    kind::Symbol
    conserved_quantities::Vector{String}
    domain_ids::Vector{String}
    input_ids::Vector{String}
    output_ids::Vector{String}
end

struct PhysicsScaleApplicabilitySpecV1
    parameter_id::String
    lower_bound::Union{Nothing,Float64}
    upper_bound::Union{Nothing,Float64}
    unit::String
    derivation::String
    status::Symbol
end

struct PhysicsBackendRequirementV1
    capability_id::String
    implementation_id::String
    minimum_fidelity::Int
    status::Symbol
    required_input_ids::Vector{String}
    convergence_metric_ids::Vector{String}
    uncertainty_output_ids::Vector{String}
end

"A native executable-physics module. Empty physics fields are forbidden for explicit modules."
struct ExecutablePhysicsModuleV1
    id::String
    role::Symbol
    domain_ids::Vector{String}
    input_ids::Vector{String}
    output_ids::Vector{String}
    state_variables::Vector{PhysicsStateVariableSpecV1}
    equations::Vector{PhysicsEquationSpecV1}
    boundary_conditions::Vector{PhysicsBoundaryConditionSpecV1}
    source_loss_terms::Vector{PhysicsSourceLossTermSpecV1}
    applicability_scales::Vector{PhysicsScaleApplicabilitySpecV1}
    backend_requirements::Vector{PhysicsBackendRequirementV1}
    dependency_module_ids::Vector{String}
    declaration_status::Symbol
    source_ids::Vector{String}
end

struct ExecutableGenomeV1
    schema_version::String
    base_genome::Genome
    modules::Vector{ExecutablePhysicsModuleV1}
    document_hash::String
end

struct ExecutablePhysicsValidationV1
    valid::Bool
    errors::Vector{String}
    warnings::Vector{String}
end

struct CompiledExecutableModuleV1
    module_id::String
    status::Symbol
    missing_input_ids::Vector{String}
    unavailable_capability_ids::Vector{String}
    unknown_scale_ids::Vector{String}
end

struct CompiledExecutablePhysicsProgramV1
    compiler_version::String
    design_id::String
    base_problem::CompiledPhysicsProblemV1
    validation::ExecutablePhysicsValidationV1
    schedule::Vector{String}
    modules::Vector{CompiledExecutableModuleV1}
    active_operator_ids::Vector{String}
    declared_operator_ids::Vector{String}
    uncovered_operator_ids::Vector{String}
    misapplied_operator_ids::Vector{String}
    calibration_prior_operator_ids::Vector{String}
    explicit_module_count::Int
    migrated_unknown_module_count::Int
    ready_module_count::Int
    evidence_tasks::Vector{PhysicsEvidenceTaskV1}
    program_hash::String
    claim_ceiling::String
end

function _parse_state_variable_v1(raw, context::String)
    field_type = Symbol(_required(raw, "field_type", context))
    time_behavior = Symbol(_required(raw, "time_behavior", context))
    return PhysicsStateVariableSpecV1(
        String(_required(raw, "id", context)), field_type,
        _strings(_required(raw, "domain_ids", context)),
        _strings(get(raw, "species", Any[])),
        String(_required(raw, "unit", context)), time_behavior)
end

function _parse_equation_v1(raw, context::String)
    return PhysicsEquationSpecV1(
        String(_required(raw, "id", context)),
        Symbol(_required(raw, "equation_class", context)),
        Symbol(_required(raw, "form", context)),
        _strings(_required(raw, "state_variable_ids", context)),
        _strings(get(raw, "input_ids", Any[])),
        _strings(_required(raw, "output_ids", context)),
        Symbol(_required(raw, "closure_level", context)),
        _strings(_required(raw, "applicability_conditions", context)))
end

function _parse_boundary_v1(raw, context::String)
    return PhysicsBoundaryConditionSpecV1(
        String(_required(raw, "id", context)),
        _strings(_required(raw, "domain_ids", context)),
        String(_required(raw, "state_variable_id", context)),
        Symbol(_required(raw, "kind", context)),
        _strings(get(raw, "data_input_ids", Any[])))
end

function _parse_term_v1(raw, context::String)
    return PhysicsSourceLossTermSpecV1(
        String(_required(raw, "id", context)),
        Symbol(_required(raw, "kind", context)),
        _strings(_required(raw, "conserved_quantities", context)),
        _strings(_required(raw, "domain_ids", context)),
        _strings(get(raw, "input_ids", Any[])),
        _strings(get(raw, "output_ids", Any[])))
end

function _optional_float_v1(raw, key::String)
    value = get(raw, key, nothing)
    value === nothing && return nothing
    value isa Real || throw(ArgumentError("$key must be numeric or null"))
    isfinite(value) || throw(ArgumentError("$key must be finite"))
    return Float64(value)
end

function _parse_scale_v1(raw, context::String)
    return PhysicsScaleApplicabilitySpecV1(
        String(_required(raw, "parameter_id", context)),
        _optional_float_v1(raw, "lower_bound"),
        _optional_float_v1(raw, "upper_bound"),
        String(_required(raw, "unit", context)),
        String(_required(raw, "derivation", context)),
        Symbol(_required(raw, "status", context)))
end

function _parse_backend_v1(raw, context::String)
    return PhysicsBackendRequirementV1(
        String(_required(raw, "capability_id", context)),
        String(_required(raw, "implementation_id", context)),
        Int(_required(raw, "minimum_fidelity", context)),
        Symbol(_required(raw, "status", context)),
        _strings(get(raw, "required_input_ids", Any[])),
        _strings(_required(raw, "convergence_metric_ids", context)),
        _strings(_required(raw, "uncertainty_output_ids", context)))
end

function _parse_executable_module_v1(raw, index::Int)
    context = "physics_modules[$index]"
    return ExecutablePhysicsModuleV1(
        String(_required(raw, "id", context)),
        Symbol(_required(raw, "role", context)),
        _strings(_required(raw, "domain_ids", context)),
        _strings(get(raw, "input_ids", Any[])),
        _strings(get(raw, "output_ids", Any[])),
        PhysicsStateVariableSpecV1[_parse_state_variable_v1(item,
            "$context.state_variables[$j]") for (j, item) in
                enumerate(_required(raw, "state_variables", context))],
        PhysicsEquationSpecV1[_parse_equation_v1(item,
            "$context.equations[$j]") for (j, item) in
                enumerate(_required(raw, "equations", context))],
        PhysicsBoundaryConditionSpecV1[_parse_boundary_v1(item,
            "$context.boundary_conditions[$j]") for (j, item) in
                enumerate(_required(raw, "boundary_conditions", context))],
        PhysicsSourceLossTermSpecV1[_parse_term_v1(item,
            "$context.source_loss_terms[$j]") for (j, item) in
                enumerate(_required(raw, "source_loss_terms", context))],
        PhysicsScaleApplicabilitySpecV1[_parse_scale_v1(item,
            "$context.applicability_scales[$j]") for (j, item) in
                enumerate(_required(raw, "applicability_scales", context))],
        PhysicsBackendRequirementV1[_parse_backend_v1(item,
            "$context.backend_requirements[$j]") for (j, item) in
                enumerate(_required(raw, "backend_requirements", context))],
        _strings(get(raw, "dependency_module_ids", Any[])),
        Symbol(_required(raw, "declaration_status", context)),
        _strings(get(raw, "source_ids", Any[])))
end

"Load a Genome-0.2 sidecar and bind it to the exact base Genome physics hash."
function parse_executable_genome_v1(base_genome::Genome, raw)
    data = _plain_json(raw)
    version = String(_required(data, "schema_version", "executable_genome"))
    expected_hash = String(_required(data, "base_genome_physics_hash", "executable_genome"))
    expected_hash == base_genome.physics_hash || throw(ArgumentError(
        "executable Genome base hash does not match the supplied Genome"))
    modules = ExecutablePhysicsModuleV1[
        _parse_executable_module_v1(item, index)
        for (index, item) in enumerate(_required(data, "physics_modules", "executable_genome"))]
    return ExecutableGenomeV1(version, base_genome, modules, canonical_hash(data))
end

function load_executable_genome_v1(base_genome_path::AbstractString,
        executable_path::AbstractString)
    genome = load_genome(base_genome_path)
    raw = JSON3.read(read(executable_path, String), Dict{String,Any})
    return parse_executable_genome_v1(genome, raw)
end

function _duplicates_v1(values)
    return sort!(String[value for value in unique(values) if count(==(value), values) > 1])
end

function _push_duplicates_v1!(errors::Vector{String}, context::String, values)
    duplicates = _duplicates_v1(values)
    isempty(duplicates) || push!(errors,
        "$context contains duplicate IDs: $(join(duplicates, ", "))")
end

function _module_domain_ids_v1(genome::Genome)
    return Set(vcat(getfield.(genome.plasma_regions, :id),
        getfield.(genome.field_sources, :id), getfield.(genome.actuators, :id),
        getfield.(genome.compression_systems, :id)))
end

function _module_schedule_v1(modules::Vector{ExecutablePhysicsModuleV1})
    ids = Set(getfield.(modules, :id))
    indegree = Dict(item.id => 0 for item in modules)
    dependents = Dict(id => String[] for id in ids)
    for item in modules, dependency in item.dependency_module_ids
        dependency in ids || continue
        indegree[item.id] += 1
        push!(dependents[dependency], item.id)
    end
    queue = sort!(String[id for (id, degree) in indegree if degree == 0])
    result = String[]
    while !isempty(queue)
        id = popfirst!(queue)
        push!(result, id)
        for dependent in sort!(dependents[id])
            indegree[dependent] -= 1
            indegree[dependent] == 0 && push!(queue, dependent)
        end
        sort!(queue)
    end
    return result
end

function validate_executable_genome_v1(executable::ExecutableGenomeV1;
        registry::Vector{PhysicsOperatorSpecV1} = default_physics_operator_registry_v1())
    errors = String[]
    warnings = String[]
    executable.schema_version == "0.2.0" ||
        push!(errors, "unsupported executable Genome schema $(executable.schema_version)")
    isempty(executable.modules) && push!(errors, "at least one physics module is required")
    module_ids = getfield.(executable.modules, :id)
    _push_duplicates_v1!(errors, "physics modules", module_ids)
    known_domains = _module_domain_ids_v1(executable.base_genome)
    known_capabilities = Set(spec.id for spec in registry)
    all_outputs = Set(isempty(executable.modules) ? String[] :
        vcat([item.output_ids for item in executable.modules]...))
    module_id_set = Set(module_ids)

    for physics_module in executable.modules
        context = "module $(physics_module.id)"
        physics_module.role in _EXECUTABLE_MODULE_ROLES_V1 ||
            push!(errors, "$context has invalid role $(physics_module.role)")
        physics_module.declaration_status in _MODULE_DECLARATION_STATUSES_V1 ||
            push!(errors, "$context has invalid declaration status $(physics_module.declaration_status)")
        _push_duplicates_v1!(errors, "$context state variables",
            getfield.(physics_module.state_variables, :id))
        _push_duplicates_v1!(errors, "$context equations", getfield.(physics_module.equations, :id))
        _push_duplicates_v1!(errors, "$context boundaries",
            getfield.(physics_module.boundary_conditions, :id))
        _push_duplicates_v1!(errors, "$context source/loss terms",
            getfield.(physics_module.source_loss_terms, :id))
        unknown_domains = sort!(String[id for id in physics_module.domain_ids if !(id in known_domains)])
        isempty(unknown_domains) || push!(errors,
            "$context references unknown domains: $(join(unknown_domains, ", "))")
        missing_dependencies = sort!(String[id for id in physics_module.dependency_module_ids
            if !(id in module_id_set)])
        isempty(missing_dependencies) || push!(errors,
            "$context references missing modules: $(join(missing_dependencies, ", "))")
        physics_module.id in physics_module.dependency_module_ids &&
            push!(errors, "$context depends on itself")

        if physics_module.declaration_status == :explicit
            isempty(physics_module.domain_ids) && push!(errors, "$context has no geometry/material domain")
            isempty(physics_module.state_variables) && push!(errors, "$context has no state variables")
            isempty(physics_module.equations) && push!(errors, "$context has no governing equations")
            isempty(physics_module.boundary_conditions) && push!(errors, "$context has no boundary declaration")
            isempty(physics_module.source_loss_terms) && push!(errors, "$context has no source/loss declaration")
            isempty(physics_module.applicability_scales) && push!(errors, "$context has no scale/applicability declaration")
            isempty(physics_module.backend_requirements) && push!(errors, "$context has no backend requirement")
            isempty(physics_module.source_ids) && push!(errors, "$context has no evidence source IDs")
        else
            push!(warnings, "$context is migrated_unknown and cannot authorize C1")
        end

        state_ids = Set(getfield.(physics_module.state_variables, :id))
        for variable in physics_module.state_variables
            variable.field_type in _STATE_FIELD_TYPES_V1 ||
                push!(errors, "$context variable $(variable.id) has invalid field type")
            variable.time_behavior in _TIME_BEHAVIORS_V1 ||
                push!(errors, "$context variable $(variable.id) has invalid time behavior")
            all(id -> id in physics_module.domain_ids, variable.domain_ids) ||
                push!(errors, "$context variable $(variable.id) escapes module domains")
        end
        for equation in physics_module.equations
            equation.equation_class in _EQUATION_CLASSES_V1 ||
                push!(errors, "$context equation $(equation.id) has invalid class")
            equation.form in _EQUATION_FORMS_V1 ||
                push!(errors, "$context equation $(equation.id) has invalid form")
            equation.closure_level in _CLOSURE_LEVELS_V1 ||
                push!(errors, "$context equation $(equation.id) has invalid closure level")
            all(id -> id in state_ids, equation.state_variable_ids) ||
                push!(errors, "$context equation $(equation.id) references undeclared state")
            all(id -> id in physics_module.input_ids || id in all_outputs,
                equation.input_ids) || push!(errors,
                "$context equation $(equation.id) references undeclared input")
            all(id -> id in physics_module.output_ids, equation.output_ids) ||
                push!(errors, "$context equation $(equation.id) emits undeclared output")
        end
        for boundary in physics_module.boundary_conditions
            boundary.kind in _BOUNDARY_KINDS_V1 ||
                push!(errors, "$context boundary $(boundary.id) has invalid kind")
            boundary.state_variable_id in state_ids ||
                push!(errors, "$context boundary $(boundary.id) references undeclared state")
            all(id -> id in physics_module.domain_ids, boundary.domain_ids) ||
                push!(errors, "$context boundary $(boundary.id) escapes module domains")
            all(id -> id in physics_module.input_ids || id in all_outputs,
                boundary.data_input_ids) || push!(errors,
                "$context boundary $(boundary.id) references undeclared input")
        end
        for term in physics_module.source_loss_terms
            term.kind in _TERM_KINDS_V1 ||
                push!(errors, "$context term $(term.id) has invalid kind")
            all(id -> id in physics_module.domain_ids, term.domain_ids) ||
                push!(errors, "$context term $(term.id) escapes module domains")
            all(id -> id in physics_module.input_ids || id in all_outputs,
                term.input_ids) || push!(errors,
                "$context term $(term.id) references undeclared input")
            all(id -> id in physics_module.output_ids, term.output_ids) ||
                push!(errors, "$context term $(term.id) emits undeclared output")
        end
        for scale in physics_module.applicability_scales
            scale.status in _SCALE_STATUSES_V1 ||
                push!(errors, "$context scale $(scale.parameter_id) has invalid status")
            scale.lower_bound !== nothing && scale.upper_bound !== nothing &&
                scale.lower_bound > scale.upper_bound && push!(errors,
                "$context scale $(scale.parameter_id) has reversed bounds")
        end
        for backend in physics_module.backend_requirements
            backend.status in _BACKEND_STATUSES_V1 ||
                push!(errors, "$context backend $(backend.implementation_id) has invalid status")
            backend.minimum_fidelity >= 0 ||
                push!(errors, "$context backend $(backend.implementation_id) has negative fidelity")
            backend.capability_id in known_capabilities ||
                push!(errors, "$context declares unknown capability $(backend.capability_id)")
            all(id -> id in physics_module.input_ids || id in all_outputs,
                backend.required_input_ids) || push!(errors,
                "$context backend $(backend.implementation_id) references undeclared input")
            all(id -> id in physics_module.output_ids,
                backend.convergence_metric_ids) || push!(errors,
                "$context backend $(backend.implementation_id) convergence metrics are not module outputs")
            isempty(backend.convergence_metric_ids) && push!(errors,
                "$context backend $(backend.implementation_id) lacks convergence metrics")
            isempty(backend.uncertainty_output_ids) && push!(warnings,
                "$context backend $(backend.implementation_id) lacks uncertainty outputs")
        end
    end

    length(_module_schedule_v1(executable.modules)) == length(executable.modules) ||
        push!(errors, "physics module dependency graph contains a cycle")
    return ExecutablePhysicsValidationV1(isempty(errors), sort!(unique(errors)),
        sort!(unique(warnings)))
end

function _state_to_dict_v1(item::PhysicsStateVariableSpecV1)
    return Dict{String,Any}("id" => item.id, "field_type" => String(item.field_type),
        "domain_ids" => item.domain_ids, "species" => item.species,
        "unit" => item.unit, "time_behavior" => String(item.time_behavior))
end

function _equation_to_dict_v1(item::PhysicsEquationSpecV1)
    return Dict{String,Any}("id" => item.id,
        "equation_class" => String(item.equation_class), "form" => String(item.form),
        "state_variable_ids" => item.state_variable_ids, "input_ids" => item.input_ids,
        "output_ids" => item.output_ids, "closure_level" => String(item.closure_level),
        "applicability_conditions" => item.applicability_conditions)
end

function _boundary_to_dict_v1(item::PhysicsBoundaryConditionSpecV1)
    return Dict{String,Any}("id" => item.id, "domain_ids" => item.domain_ids,
        "state_variable_id" => item.state_variable_id, "kind" => String(item.kind),
        "data_input_ids" => item.data_input_ids)
end

function _term_to_dict_v1(item::PhysicsSourceLossTermSpecV1)
    return Dict{String,Any}("id" => item.id, "kind" => String(item.kind),
        "conserved_quantities" => item.conserved_quantities,
        "domain_ids" => item.domain_ids, "input_ids" => item.input_ids,
        "output_ids" => item.output_ids)
end

function _scale_to_dict_v1(item::PhysicsScaleApplicabilitySpecV1)
    return Dict{String,Any}("parameter_id" => item.parameter_id,
        "lower_bound" => item.lower_bound, "upper_bound" => item.upper_bound,
        "unit" => item.unit, "derivation" => item.derivation,
        "status" => String(item.status))
end

function _backend_to_dict_v1(item::PhysicsBackendRequirementV1)
    return Dict{String,Any}("capability_id" => item.capability_id,
        "implementation_id" => item.implementation_id,
        "minimum_fidelity" => item.minimum_fidelity, "status" => String(item.status),
        "required_input_ids" => item.required_input_ids,
        "convergence_metric_ids" => item.convergence_metric_ids,
        "uncertainty_output_ids" => item.uncertainty_output_ids)
end

function executable_module_to_dict_v1(item::ExecutablePhysicsModuleV1)
    return Dict{String,Any}("id" => item.id, "role" => String(item.role),
        "domain_ids" => item.domain_ids, "input_ids" => item.input_ids,
        "output_ids" => item.output_ids,
        "state_variables" => _state_to_dict_v1.(item.state_variables),
        "equations" => _equation_to_dict_v1.(item.equations),
        "boundary_conditions" => _boundary_to_dict_v1.(item.boundary_conditions),
        "source_loss_terms" => _term_to_dict_v1.(item.source_loss_terms),
        "applicability_scales" => _scale_to_dict_v1.(item.applicability_scales),
        "backend_requirements" => _backend_to_dict_v1.(item.backend_requirements),
        "dependency_module_ids" => item.dependency_module_ids,
        "declaration_status" => String(item.declaration_status),
        "source_ids" => item.source_ids)
end

function executable_genome_to_dict_v1(item::ExecutableGenomeV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "base_genome_physics_hash" => item.base_genome.physics_hash,
        "physics_modules" => executable_module_to_dict_v1.(item.modules),
        "document_hash" => item.document_hash)
end

"Legacy migration is deliberately incomplete and cannot silently become executable."
function migrate_legacy_genome_to_executable_v1(genome::Genome)
    domains = sort!(vcat(getfield.(genome.plasma_regions, :id),
        getfield.(genome.field_sources, :id)))
    compatibility_module = ExecutablePhysicsModuleV1("legacy_compatibility_projection",
        :coupling, domains, String[], String[], PhysicsStateVariableSpecV1[],
        PhysicsEquationSpecV1[], PhysicsBoundaryConditionSpecV1[],
        PhysicsSourceLossTermSpecV1[], PhysicsScaleApplicabilitySpecV1[],
        PhysicsBackendRequirementV1[], String[], :migrated_unknown,
        copy(genome.provenance.source_ids))
    payload = Dict{String,Any}("schema_version" => "0.2.0",
        "base_genome_physics_hash" => genome.physics_hash,
        "physics_modules" => [executable_module_to_dict_v1(compatibility_module)])
    return ExecutableGenomeV1("0.2.0", genome, [compatibility_module], canonical_hash(payload))
end

function _compile_modules_v1(executable::ExecutableGenomeV1,
        base_problem::CompiledPhysicsProblemV1)
    schedule = _module_schedule_v1(executable.modules)
    by_id = Dict(item.id => item for item in executable.modules)
    available = copy(base_problem.domain.available_input_ids)
    compiled = CompiledExecutableModuleV1[]
    for id in schedule
        physics_module = by_id[id]
        missing = sort!(String[input for input in physics_module.input_ids if !(input in available)])
        unavailable = sort!(unique(String[backend.capability_id
            for backend in physics_module.backend_requirements if backend.status != :available]))
        unknown_scales = sort!(String[scale.parameter_id
            for scale in physics_module.applicability_scales if scale.status == :unknown])
        status = physics_module.declaration_status == :migrated_unknown ? :migrated_unknown :
            !isempty(missing) ? :blocked_unknown_inputs :
            !isempty(unavailable) ? :blocked_backend :
            !isempty(unknown_scales) ? :blocked_unknown_scale : :ready_for_execution
        push!(compiled, CompiledExecutableModuleV1(physics_module.id, status, missing,
            unavailable, unknown_scales))
        status == :ready_for_execution && union!(available, physics_module.output_ids)
    end
    return schedule, compiled
end

function compile_executable_physics_program_v1(executable::ExecutableGenomeV1;
        registry::Vector{PhysicsOperatorSpecV1} = default_physics_operator_registry_v1())
    validation = validate_executable_genome_v1(executable; registry = registry)
    base = compile_physics_problem_v1(executable.base_genome; registry = registry)
    schedule, compiled_modules = validation.valid ?
        _compile_modules_v1(executable, base) : (String[], CompiledExecutableModuleV1[])
    active_specs = [item.spec for item in base.operators if !item.spec.empirical_prior]
    active_ids = sort!(getfield.(active_specs, :id))
    prior_ids = sort!(String[item.spec.id for item in base.operators if item.spec.empirical_prior])
    declared_ids = sort!(unique(String[backend.capability_id
        for item in executable.modules for backend in item.backend_requirements]))
    uncovered = sort!(String[id for id in active_ids if !(id in declared_ids)])
    misapplied = sort!(String[id for id in declared_ids if !(id in active_ids)])
    tasks = copy(base.evidence_tasks)
    for id in uncovered
        push!(tasks, PhysicsEvidenceTaskV1("declare_operator:$id",
            "Active physics operator has no native executable module declaration.",
            String[], [id]))
    end
    for item in compiled_modules
        item.status == :ready_for_execution && continue
        push!(tasks, PhysicsEvidenceTaskV1("repair_module:$(item.module_id)",
            "Executable module is not ready; missing inputs, backend, scale, or explicit declaration must be repaired.",
            item.missing_input_ids, item.unavailable_capability_ids))
    end
    sort!(tasks; by = item -> item.id)
    explicit_count = count(item -> item.declaration_status == :explicit,
        executable.modules)
    migrated_count = length(executable.modules) - explicit_count
    ready_count = count(item -> item.status == :ready_for_execution, compiled_modules)
    claim = validation.valid && isempty(uncovered) && isempty(misapplied) &&
        migrated_count == 0 && ready_count == length(executable.modules) ?
        "C0_native_executable_program_ready_for_solver_execution" :
        "C0_executable_program_incomplete_unknown"
    payload = Dict{String,Any}(
        "base_physical_signature_hash" => base.physical_signature_hash,
        "modules" => executable_module_to_dict_v1.(executable.modules),
        "schedule" => schedule,
        "active_operator_ids" => active_ids,
        "declared_operator_ids" => declared_ids,
        "uncovered_operator_ids" => uncovered,
        "misapplied_operator_ids" => misapplied,
        "compiled_statuses" => Dict(item.module_id => String(item.status)
            for item in compiled_modules))
    return CompiledExecutablePhysicsProgramV1("1.0.0", executable.base_genome.design_id,
        base, validation, schedule, compiled_modules, active_ids, declared_ids,
        uncovered, misapplied, prior_ids, explicit_count, migrated_count,
        ready_count, tasks, canonical_hash(payload), claim)
end

function compiled_executable_program_to_dict_v1(item::CompiledExecutablePhysicsProgramV1)
    return Dict{String,Any}(
        "compiler_version" => item.compiler_version,
        "design_id" => item.design_id,
        "base_problem" => physics_problem_to_dict_v1(item.base_problem),
        "validation" => Dict{String,Any}("valid" => item.validation.valid,
            "errors" => item.validation.errors, "warnings" => item.validation.warnings),
        "schedule" => item.schedule,
        "modules" => [Dict{String,Any}("module_id" => compiled_module.module_id,
            "status" => String(compiled_module.status),
            "missing_input_ids" => compiled_module.missing_input_ids,
            "unavailable_capability_ids" => compiled_module.unavailable_capability_ids,
            "unknown_scale_ids" => compiled_module.unknown_scale_ids) for compiled_module in item.modules],
        "active_operator_ids" => item.active_operator_ids,
        "declared_operator_ids" => item.declared_operator_ids,
        "uncovered_operator_ids" => item.uncovered_operator_ids,
        "misapplied_operator_ids" => item.misapplied_operator_ids,
        "calibration_prior_operator_ids" => item.calibration_prior_operator_ids,
        "explicit_module_count" => item.explicit_module_count,
        "migrated_unknown_module_count" => item.migrated_unknown_module_count,
        "ready_module_count" => item.ready_module_count,
        "evidence_tasks" => [_task_to_dict_v1(task) for task in item.evidence_tasks],
        "program_hash" => item.program_hash,
        "claim_ceiling" => item.claim_ceiling,
        "promotion_authorized" => false)
end
