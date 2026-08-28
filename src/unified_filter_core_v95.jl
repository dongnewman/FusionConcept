const V95_PROTOCOL_ID = "fusionconceptai-v95-unified-reference-candidate-filter-20260828"

const UNIFIED_FILTER_CORE_V95_CLAIM_BOUNDARY =
    "One declaration-only graph compiler, provider registry, whole-graph solver, numerical VVUQ, and validation VVUQ path is used for every subject. Missing closure is unsupported, numerical failure is not physical failure, and numerical verification is not experimental validation or device feasibility."

const V95_SCREEN_STATUSES = Set([
    "pass", "physical_fail", "numerical_fail", "unsupported", "unknown",
])

"Compile a normalized declaration without receiving identity, provenance role, or labels."
function compile_unified_declared_graph_v95(declaration_raw)
    declaration = Dict{String,Any}(_v93_plain(declaration_raw))
    source_regions = Dict{String,Any}.(get(declaration, "regions", Any[]))
    isempty(source_regions) && throw(ArgumentError("normalized declaration has no regions"))

    regions = Dict{String,Any}[]
    variables = Dict{String,Any}[]
    equations = Dict{String,Any}[]
    region_variables = Dict{String,Vector{String}}()
    region_equations = Dict{String,Vector{String}}()
    for region in source_regions
        key = String(region["region_key"])
        region_variables[key] = String[]
        region_equations[key] = String[]
    end

    for raw in get(declaration, "states", Any[])
        state = Dict{String,Any}(_v93_plain(raw))
        region_key = String(state["region_key"])
        haskey(region_variables, region_key) || throw(ArgumentError(
            "state references an undeclared region"))
        variable_key = String(state["state_key"])
        equation_key = "balance::" * variable_key
        row_key = "row::" * variable_key
        push!(region_variables[region_key], variable_key)
        push!(region_equations[region_key], equation_key)
        push!(variables, Dict{String,Any}(
            "variable_key" => variable_key,
            "region_key" => region_key,
            "physical_state" => String(state["physical_state"]),
            "function_space" => String(state["function_space"])))
        push!(equations, Dict{String,Any}(
            "equation_key" => equation_key,
            "row_key" => row_key,
            "region_key" => region_key,
            "operator" => String(state["operator"]),
            "additional_operators" => String.(get(state, "additional_operators", Any[])),
            "terms" => [Dict("row_key" => row_key, "variable_key" => variable_key,
                "coefficient" => 1.0)],
            "rhs" => 0.0,
            "required_fields" => String.(get(state, "required_fields", Any[]))))
    end

    interfaces = Dict{String,Any}[]
    for raw in get(declaration, "interfaces", Any[])
        interface = Dict{String,Any}(_v93_plain(raw))
        minus = String(interface["minus_region_key"])
        plus = String(interface["plus_region_key"])
        conditions = Dict{String,Any}[]
        for (index, raw_condition) in enumerate(get(interface, "conditions", Any[]))
            condition = Dict{String,Any}(_v93_plain(raw_condition))
            multiplier = "interface_multiplier::" * String(interface["interface_key"]) *
                "::" * string(index)
            row = "interface_row::" * String(interface["interface_key"]) * "::" * string(index)
            push!(region_variables[minus], multiplier)
            push!(variables, Dict{String,Any}(
                "variable_key" => multiplier, "region_key" => minus,
                "physical_state" => "interface_multiplier",
                "function_space" => String(get(condition, "function_space",
                    "unresolved_interface_space"))))
            push!(conditions, Dict{String,Any}(
                "condition" => String(condition["condition"]), "row_key" => row,
                "terms" => [Dict("row_key" => row, "variable_key" => multiplier,
                    "coefficient" => 1.0)], "rhs" => 0.0,
                "required_fields" => String.(get(condition, "required_fields", Any[]))))
        end
        push!(interfaces, Dict{String,Any}(
            "interface_key" => String(interface["interface_key"]),
            "minus_region_key" => minus, "plus_region_key" => plus,
            "conditions" => conditions))
    end

    boundaries = Dict{String,Any}[]
    for raw in get(declaration, "boundaries", Any[])
        boundary = Dict{String,Any}(_v93_plain(raw))
        region_key = String(boundary["region_key"])
        key = String(boundary["boundary_key"])
        multiplier = "boundary_multiplier::" * key
        row = "boundary_row::" * key
        push!(region_variables[region_key], multiplier)
        push!(variables, Dict{String,Any}(
            "variable_key" => multiplier, "region_key" => region_key,
            "physical_state" => "boundary_multiplier",
            "function_space" => String(get(boundary, "function_space",
                "unresolved_boundary_space"))))
        push!(boundaries, Dict{String,Any}(
            "boundary_key" => key, "region_key" => region_key,
            "condition" => String(boundary["condition"]), "row_key" => row,
            "terms" => [Dict("row_key" => row, "variable_key" => multiplier,
                "coefficient" => 1.0)], "rhs" => 0.0,
            "required_fields" => String.(get(boundary, "required_fields", Any[]))))
    end

    for source in source_regions
        key = String(source["region_key"])
        push!(regions, Dict{String,Any}(
            "region_key" => key, "dimension" => Int(source["dimension"]),
            "coordinate" => String(source["coordinate"]),
            "variable_keys" => region_variables[key],
            "equation_keys" => region_equations[key]))
    end
    Dict{String,Any}(
        "regions" => regions, "variables" => variables, "equations" => equations,
        "interfaces" => interfaces, "boundaries" => boundaries,
        "fields" => Dict{String,Any}.(get(declaration, "fields", Any[])),
        "compiler" => "unified_declaration_graph_compiler_v95",
        "physical_conclusion_expanded" => false)
end

function graph_numerical_vvuq_v95(assembly::GraphAssemblyV94, solve)
    get(solve, "status", "") == "pass" || return Dict{String,Any}(
        "status" => "not_executed", "reason" => "solve_not_passed",
        "experimental_validation_credit" => false)
    replay = solve_graph_system_v94(assembly)
    state = Float64.(solve["state"])
    replay_state = Float64.(get(replay, "state", Float64[]))
    difference = length(state) == length(replay_state) ? norm(state - replay_state) : Inf
    passed = replay["status"] == "pass" && difference <= 1e-12 &&
        Float64(solve["normalized_residual"]) <= 1e-10 &&
        Float64(solve["jacobian_relative_error"]) <= 1e-7
    Dict{String,Any}(
        "status" => passed ? "pass" : "fail", "deterministic_replay" => replay["status"],
        "maximum_state_difference" => difference,
        "normalized_residual" => solve["normalized_residual"],
        "jacobian_relative_error" => solve["jacobian_relative_error"],
        "verification_type" => "residual_jacobian_and_deterministic_replay",
        "experimental_validation_credit" => false)
end

"Accept a metric only when it is explicitly derived from a successful whole-graph solve."
function solved_metric_record_v95(metric_id, value, solve;
        origin::AbstractString = "whole_graph_solve_derived")
    allowed = origin == "whole_graph_solve_derived" &&
        get(solve, "status", "") == "pass" &&
        get(solve, "whole_graph_closed", false) === true &&
        haskey(solve, "solve_hash") && value !== nothing && value isa Real && isfinite(value)
    Dict{String,Any}(
        "metric_id" => String(metric_id), "status" => allowed ? "available" : "unsupported",
        "value" => allowed ? Float64(value) : nothing,
        "origin" => allowed ? String(origin) : nothing,
        "solve_hash" => allowed ? solve["solve_hash"] : nothing,
        "basis_direct_proxy_credit" => false,
        "reason" => allowed ? nothing : "metric_not_derived_from_successful_whole_graph_solve")
end

function execute_compiled_graph_v95(graph, registry::OperatorProviderRegistryV94;
        validation_evidence = nothing, validation_applicable::Bool = true)
    stage_order = String["graph_compile", "graph_assembly"]
    assembly = try
        assemble_graph_residual_jacobian_v94(graph, registry)
    catch error
        return Dict{String,Any}(
            "status" => "unsupported", "stage_order" => stage_order,
            "assembly" => Dict("status" => "unsupported",
                "blockers" => ["assembly_contract_error:" * sprint(showerror, error)]),
            "solve" => Dict("status" => "not_executed", "solver_executed" => false),
            "numerical_vvuq" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "partial_subgraph_credit" => false, "physical_conclusion_expanded" => false)
    end
    if !assembly.solver_allowed
        return Dict{String,Any}(
            "status" => "unsupported", "stage_order" => stage_order,
            "assembly" => graph_assembly_to_dict_v94(assembly),
            "solve" => solve_graph_system_v94(assembly),
            "numerical_vvuq" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "partial_subgraph_credit" => false, "physical_conclusion_expanded" => false)
    end
    push!(stage_order, "solve")
    solve = solve_graph_system_v94(assembly)
    if solve["status"] != "pass"
        return Dict{String,Any}(
            "status" => "numerical_fail", "stage_order" => stage_order,
            "assembly" => graph_assembly_to_dict_v94(assembly), "solve" => solve,
            "numerical_vvuq" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "partial_subgraph_credit" => false, "physical_conclusion_expanded" => false)
    end
    push!(stage_order, "numerical_vvuq")
    numerical = graph_numerical_vvuq_v95(assembly, solve)
    if numerical["status"] != "pass"
        return Dict{String,Any}(
            "status" => "numerical_fail", "stage_order" => stage_order,
            "assembly" => graph_assembly_to_dict_v94(assembly), "solve" => solve,
            "numerical_vvuq" => numerical,
            "validation_vvuq" => Dict("status" => "not_executed"),
            "partial_subgraph_credit" => false, "physical_conclusion_expanded" => false)
    end
    push!(stage_order, "validation_vvuq")
    validation = validation_applicable ? audit_validation_vvuq_v94(validation_evidence) :
        Dict{String,Any}("status" => "not_applicable", "experimental_validation" =>
            "not_applicable", "reason" => "gate_declared_not_applicable")
    status = validation["status"] == "pass" || validation["status"] == "not_applicable" ?
        "pass" : "unknown"
    Dict{String,Any}(
        "status" => status, "stage_order" => stage_order,
        "assembly" => graph_assembly_to_dict_v94(assembly), "solve" => solve,
        "numerical_vvuq" => numerical, "validation_vvuq" => validation,
        "partial_subgraph_credit" => false, "physical_conclusion_expanded" => false)
end

function execute_unified_declaration_v95(declaration_raw;
        registry = default_operator_provider_registry_v94(), validation_evidence = nothing,
        validation_applicable::Bool = true)
    graph = compile_unified_declared_graph_v95(declaration_raw)
    result = execute_compiled_graph_v95(graph, registry;
        validation_evidence, validation_applicable)
    result["graph_hash"] = canonical_hash(graph)
    result["protocol_id"] = V95_PROTOCOL_ID
    result["claim_boundary"] = UNIFIED_FILTER_CORE_V95_CLAIM_BOUNDARY
    result["result_hash"] = canonical_hash(result)
    result
end
