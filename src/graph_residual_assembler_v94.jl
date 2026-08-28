const GRAPH_RESIDUAL_ASSEMBLER_V94_CLAIM_BOUNDARY =
    "A graph is solver-eligible only when every declared region, equation, interface, boundary, additional operator, and solve-required field is closed. Partial subgraphs never receive whole-graph credit."

struct ResidualFragmentV94
    requirement_key::String
    owned_rows::Vector{String}
    entries::Vector{Tuple{String,String,Float64}}
    rhs_entries::Vector{Tuple{String,Float64}}
    fragment_hash::String
end

struct GraphAssemblyV94
    status::String
    solver_allowed::Bool
    row_keys::Vector{String}
    variable_keys::Vector{String}
    matrix::Union{Nothing,Matrix{Float64}}
    rhs::Union{Nothing,Vector{Float64}}
    routes::Vector{Dict{String,Any}}
    blockers::Vector{String}
    field_plan::FieldClosurePlanV94
    assembly_hash::String
end

function residual_fragment_v94(requirement_key, owned_rows, entries, rhs_entries)
    normalized_entries = Tuple{String,String,Float64}[
        (String(row), String(column), Float64(value)) for (row, column, value) in entries]
    normalized_rhs = Tuple{String,Float64}[(String(row), Float64(value))
        for (row, value) in rhs_entries]
    all(item -> isfinite(item[3]), normalized_entries) ||
        throw(ArgumentError("non-finite residual fragment coefficient"))
    all(item -> isfinite(item[2]), normalized_rhs) ||
        throw(ArgumentError("non-finite residual fragment rhs"))
    body = Dict{String,Any}(
        "requirement_key" => String(requirement_key),
        "owned_rows" => sort!(String.(owned_rows)),
        "entries" => sort!([[row, column, value] for (row, column, value) in normalized_entries];
            by = canonical_hash),
        "rhs_entries" => sort!([[row, value] for (row, value) in normalized_rhs];
            by = canonical_hash))
    ResidualFragmentV94(String(requirement_key), String.(owned_rows), normalized_entries,
        normalized_rhs, canonical_hash(body))
end

function _declared_linear_fragment_v94(requirement::CapabilityRequirementV94)
    payload = requirement.payload
    terms = Tuple{String,String,Float64}[]
    for raw in get(payload, "terms", Any[])
        term = Dict{String,Any}(_v93_plain(raw))
        push!(terms, (String(term["row_key"]), String(term["variable_key"]),
            Float64(term["coefficient"])))
    end
    rhs = Tuple{String,Float64}[]
    for raw in get(payload, "rhs_entries", Any[])
        item = Dict{String,Any}(_v93_plain(raw))
        push!(rhs, (String(item["row_key"]), Float64(item["value"])))
    end
    residual_fragment_v94(requirement.requirement_key,
        String.(get(payload, "owned_rows", Any[])), terms, rhs)
end

function _v94_term_capabilities(terms, variables)
    state_by_key = Dict(String(item["variable_key"]) => String(item["physical_state"])
        for item in variables)
    space_by_key = Dict(String(item["variable_key"]) => String(item["function_space"])
        for item in variables)
    keys_used = unique(String(get(item, "variable_key", "")) for item in terms)
    states = sort!(unique(state_by_key[key] for key in keys_used if haskey(state_by_key, key)))
    spaces = sort!(unique(space_by_key[key] for key in keys_used if haskey(space_by_key, key)))
    states, spaces
end

function _v94_requirement(kind, key, operator, interface, terms, variables,
        dimension, coordinate, owned_rows, rhs_entries)
    states, spaces = _v94_term_capabilities(terms, variables)
    payload = Dict{String,Any}(
        "terms" => terms, "owned_rows" => owned_rows, "rhs_entries" => rhs_entries)
    CapabilityRequirementV94(String(key), String(kind), states,
        operator === nothing ? nothing : String(operator),
        interface === nothing ? nothing : String(interface),
        spaces, Int(dimension), String(coordinate), "residual_jacobian_fragment", payload)
end

function _v94_equation_requirements(graph, variables, regions_by_key)
    requirements = CapabilityRequirementV94[]
    for raw in get(graph, "equations", Any[])
        equation = Dict{String,Any}(_v93_plain(raw))
        region = regions_by_key[String(equation["region_key"])]
        terms = get(equation, "terms", Any[])
        rhs_entries = [Dict("row_key" => String(equation["row_key"]),
            "value" => Float64(get(equation, "rhs", 0.0)))]
        push!(requirements, _v94_requirement("operator",
            "equation:" * String(equation["equation_key"]), equation["operator"], nothing,
            terms, variables, region["dimension"], region["coordinate"],
            [String(equation["row_key"])], rhs_entries))
        for (index, raw_additional) in enumerate(get(equation, "additional_operators", Any[]))
            additional = raw_additional isa AbstractString ?
                Dict{String,Any}("operator" => String(raw_additional), "terms" => Any[], "rhs" => 0.0) :
                Dict{String,Any}(_v93_plain(raw_additional))
            additional_terms = get(additional, "terms", Any[])
            additional_rhs = [Dict("row_key" => String(equation["row_key"]),
                "value" => Float64(get(additional, "rhs", 0.0)))]
            push!(requirements, _v94_requirement("additional_operator",
                "additional:" * String(equation["equation_key"]) * ":" * string(index),
                additional["operator"], nothing, additional_terms, variables,
                region["dimension"], region["coordinate"], String[], additional_rhs))
        end
    end
    requirements
end

function _v94_interface_requirements(graph, variables, regions_by_key)
    requirements = CapabilityRequirementV94[]
    for raw in get(graph, "interfaces", Any[])
        interface = Dict{String,Any}(_v93_plain(raw))
        left = regions_by_key[String(interface["minus_region_key"])]
        right = regions_by_key[String(interface["plus_region_key"])]
        Int(left["dimension"]) == Int(right["dimension"]) ||
            throw(ArgumentError("mixed-dimensional interface requires an explicit transfer provider"))
        String(left["coordinate"]) == String(right["coordinate"]) ||
            throw(ArgumentError("coordinate-changing interface requires an explicit transfer provider"))
        for raw_condition in get(interface, "conditions", Any[])
            condition = Dict{String,Any}(_v93_plain(raw_condition))
            rhs_entries = [Dict("row_key" => String(condition["row_key"]),
                "value" => Float64(get(condition, "rhs", 0.0)))]
            push!(requirements, _v94_requirement("interface",
                "interface:" * String(interface["interface_key"]) * ":" * String(condition["condition"]),
                nothing, condition["condition"], get(condition, "terms", Any[]), variables,
                left["dimension"], left["coordinate"], [String(condition["row_key"])], rhs_entries))
        end
    end
    requirements
end

function _v94_boundary_requirements(graph, variables, regions_by_key)
    requirements = CapabilityRequirementV94[]
    for raw in get(graph, "boundaries", Any[])
        boundary = Dict{String,Any}(_v93_plain(raw))
        region = regions_by_key[String(boundary["region_key"])]
        rhs_entries = [Dict("row_key" => String(boundary["row_key"]),
            "value" => Float64(get(boundary, "rhs", 0.0)))]
        push!(requirements, _v94_requirement("boundary",
            "boundary:" * String(boundary["boundary_key"]), nothing, boundary["condition"],
            get(boundary, "terms", Any[]), variables, region["dimension"], region["coordinate"],
            [String(boundary["row_key"])], rhs_entries))
    end
    requirements
end

function _v94_structural_blockers(graph, variables, regions, equations, interfaces, boundaries)
    blockers = String[]
    region_keys = String[String(item["region_key"]) for item in regions]
    variable_keys = String[String(item["variable_key"]) for item in variables]
    equation_keys = String[String(item["equation_key"]) for item in equations]
    length(unique(region_keys)) == length(region_keys) || push!(blockers, "duplicate_region_key")
    length(unique(variable_keys)) == length(variable_keys) || push!(blockers, "duplicate_variable_key")
    length(unique(equation_keys)) == length(equation_keys) || push!(blockers, "duplicate_equation_key")
    region_set = Set(region_keys); variable_set = Set(variable_keys)
    for region in regions
        key = String(region["region_key"])
        declared_variables = Set(String.(get(region, "variable_keys", Any[])))
        actual_variables = Set(String(item["variable_key"]) for item in variables
            if String(get(item, "region_key", "")) == key)
        declared_variables == actual_variables || push!(blockers, "region_variable_closure:" * key)
        declared_equations = Set(String.(get(region, "equation_keys", Any[])))
        actual_equations = Set(String(item["equation_key"]) for item in equations
            if String(get(item, "region_key", "")) == key)
        declared_equations == actual_equations || push!(blockers, "region_equation_closure:" * key)
        isempty(actual_variables) && push!(blockers, "empty_region_variables:" * key)
        isempty(actual_equations) && push!(blockers, "empty_region_equations:" * key)
    end
    for variable in variables
        String(get(variable, "region_key", "")) in region_set ||
            push!(blockers, "variable_region_unresolved")
    end
    all_terms = Any[]
    for equation in equations
        String(get(equation, "region_key", "")) in region_set ||
            push!(blockers, "equation_region_unresolved")
        append!(all_terms, get(equation, "terms", Any[]))
        for additional in get(equation, "additional_operators", Any[])
            additional isa AbstractString || append!(all_terms, get(additional, "terms", Any[]))
        end
    end
    for interface in interfaces
        minus = String(get(interface, "minus_region_key", ""))
        plus = String(get(interface, "plus_region_key", ""))
        minus in region_set && plus in region_set && minus != plus ||
            push!(blockers, "interface_endpoint_unresolved")
        isempty(get(interface, "conditions", Any[])) && push!(blockers, "empty_interface_conditions")
        for condition in get(interface, "conditions", Any[])
            append!(all_terms, get(condition, "terms", Any[]))
        end
    end
    for boundary in boundaries
        String(get(boundary, "region_key", "")) in region_set ||
            push!(blockers, "boundary_region_unresolved")
        append!(all_terms, get(boundary, "terms", Any[]))
    end
    for term in all_terms
        String(get(term, "variable_key", "")) in variable_set ||
            push!(blockers, "term_variable_unresolved")
    end
    unique(blockers)
end

function assemble_graph_residual_jacobian_v94(graph_raw,
        registry::OperatorProviderRegistryV94)
    graph = Dict{String,Any}(_v93_plain(graph_raw))
    regions = Dict{String,Any}.(get(graph, "regions", Any[]))
    variables = Dict{String,Any}.(get(graph, "variables", Any[]))
    equations = Dict{String,Any}.(get(graph, "equations", Any[]))
    interfaces = Dict{String,Any}.(get(graph, "interfaces", Any[]))
    boundaries = Dict{String,Any}.(get(graph, "boundaries", Any[]))
    isempty(regions) && throw(ArgumentError("graph requires explicit regions"))
    regions_by_key = Dict(String(item["region_key"]) => item for item in regions)
    field_plan = plan_field_dependency_closure_v94(get(graph, "fields", Any[]); registry = registry)
    blockers = _v94_structural_blockers(graph, variables, regions, equations, interfaces, boundaries)
    required_fields = Set{String}()
    for collection in (equations, interfaces, boundaries)
        for item in collection
            union!(required_fields, String.(get(item, "required_fields", Any[])))
            if haskey(item, "conditions")
                for condition in get(item, "conditions", Any[])
                    union!(required_fields, String.(get(condition, "required_fields", Any[])))
                end
            end
        end
    end
    availability = Dict(String(item["field_key"]) => Bool(item["available"])
        for item in field_plan.records)
    for key in sort!(collect(required_fields))
        get(availability, key, false) || push!(blockers, "solve_field_unavailable:" * key)
    end
    requirements = vcat(
        _v94_equation_requirements(graph, variables, regions_by_key),
        _v94_interface_requirements(graph, variables, regions_by_key),
        _v94_boundary_requirements(graph, variables, regions_by_key))
    routes = Dict{String,Any}[]
    for requirement in requirements
        route = route_provider_v94(registry, requirement)
        push!(routes, route)
        route["status"] == "closed" || push!(blockers,
            "provider_unavailable:" * requirement.requirement_key)
    end
    row_keys = vcat(
        String[String(item["row_key"]) for item in equations],
        String[String(condition["row_key"]) for item in interfaces
            for condition in get(item, "conditions", Any[])],
        String[String(item["row_key"]) for item in boundaries])
    variable_keys = String[String(item["variable_key"]) for item in variables]
    length(unique(row_keys)) == length(row_keys) || push!(blockers, "duplicate_residual_row")
    length(row_keys) == length(variable_keys) || push!(blockers, "non_square_declared_graph")
    if !isempty(blockers)
        body = Dict{String,Any}("status" => "unsupported", "row_keys" => sort!(row_keys),
            "variable_keys" => sort!(variable_keys), "routes" => routes,
            "blockers" => sort!(unique(blockers)), "field_plan_hash" => field_plan.plan_hash,
            "partial_subgraph_credit" => false)
        return GraphAssemblyV94("unsupported", false, row_keys, variable_keys, nothing, nothing,
            routes, sort!(unique(blockers)), field_plan, canonical_hash(body))
    end
    row_index = Dict(key => index for (index, key) in enumerate(row_keys))
    variable_index = Dict(key => index for (index, key) in enumerate(variable_keys))
    matrix = zeros(Float64, length(row_keys), length(variable_keys))
    rhs = zeros(Float64, length(row_keys)); owned = Dict(key => 0 for key in row_keys)
    fragments = ResidualFragmentV94[]
    for (requirement, route) in zip(requirements, routes)
        provider_key = String(route["selected_provider"])
        fragment = registry.implementations[provider_key](requirement)
        fragment isa ResidualFragmentV94 || throw(ArgumentError("provider returned invalid fragment"))
        fragment.requirement_key == requirement.requirement_key ||
            throw(ArgumentError("provider fragment requirement mismatch"))
        push!(fragments, fragment)
        for row in fragment.owned_rows
            haskey(owned, row) || throw(ArgumentError("provider owns undeclared row"))
            owned[row] += 1
        end
        for (row, variable, value) in fragment.entries
            haskey(row_index, row) && haskey(variable_index, variable) ||
                throw(ArgumentError("provider fragment references undeclared graph key"))
            matrix[row_index[row], variable_index[variable]] += value
        end
        for (row, value) in fragment.rhs_entries
            haskey(row_index, row) || throw(ArgumentError("provider rhs references undeclared row"))
            rhs[row_index[row]] += value
        end
    end
    ownership_failures = sort!([key for (key, count) in owned if count != 1])
    if !isempty(ownership_failures)
        push!(blockers, "residual_row_ownership_incomplete")
        body = Dict("status" => "unsupported", "ownership_failures" => ownership_failures,
            "partial_subgraph_credit" => false)
        return GraphAssemblyV94("unsupported", false, row_keys, variable_keys, nothing, nothing,
            routes, sort!(unique(blockers)), field_plan, canonical_hash(body))
    end
    all(isfinite, matrix) && all(isfinite, rhs) || throw(ArgumentError("non-finite graph assembly"))
    body = Dict{String,Any}(
        "status" => "closed", "row_keys" => row_keys, "variable_keys" => variable_keys,
        "matrix" => vec(matrix), "rhs" => rhs, "routes" => routes,
        "fragment_hashes" => [item.fragment_hash for item in fragments],
        "field_plan_hash" => field_plan.plan_hash, "partial_subgraph_credit" => false)
    GraphAssemblyV94("closed", true, row_keys, variable_keys, matrix, rhs, routes,
        String[], field_plan, canonical_hash(body))
end

graph_residual_v94(assembly::GraphAssemblyV94, state) =
    assembly.solver_allowed ? assembly.matrix * state - assembly.rhs :
    throw(ArgumentError("whole graph is not solver-eligible"))

graph_jacobian_v94(assembly::GraphAssemblyV94, state = nothing) =
    assembly.solver_allowed ? copy(assembly.matrix) :
    throw(ArgumentError("whole graph is not solver-eligible"))

function graph_assembly_to_dict_v94(assembly::GraphAssemblyV94)
    Dict{String,Any}(
        "status" => assembly.status, "solver_allowed" => assembly.solver_allowed,
        "row_keys" => assembly.row_keys, "variable_keys" => assembly.variable_keys,
        "routes" => assembly.routes, "blockers" => assembly.blockers,
        "field_plan" => field_closure_plan_to_dict_v94(assembly.field_plan),
        "matrix_shape" => assembly.matrix === nothing ? nothing : collect(size(assembly.matrix)),
        "assembly_hash" => assembly.assembly_hash,
        "partial_subgraph_credit" => false,
        "claim_boundary" => GRAPH_RESIDUAL_ASSEMBLER_V94_CLAIM_BOUNDARY)
end
