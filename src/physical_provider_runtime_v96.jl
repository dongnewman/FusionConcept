const V96_PROTOCOL_ID = "fusionconceptai-v96-physical-provider-closure-20260828"

const PHYSICAL_PROVIDER_RUNTIME_V96_CLAIM_BOUNDARY =
    "The v96 runtime closes a candidate-bound reduced finite-volume perturbation model through capability-routed region, interface, and boundary providers. Closure and numerical verification do not establish experimental validation, engineering readiness, or device feasibility."

const V96_REGION_OPERATORS = [
    "field_balance", "coil_response", "wall_response", "particle_balance",
    "energy_balance", "cross_field_transport", "parallel_transport",
    "terminal_balance", "reaction_radiation", "actuator_feedback",
    "fault_transition", "coupled_inventory_root", "stability_linearization",
]

const V96_INTERFACE_OPERATORS = [
    "conservative_same_coordinate_flux", "conservative_coordinate_transfer",
    "conservative_mixed_dimension_transfer",
]

const V96_BOUNDARY_OPERATORS = [
    "closed_no_flux", "open_outflow", "absorbing_terminal", "mixed_robin",
]

struct ProviderRequirementV96
    requirement_key::String
    kind::String
    physical_states::Vector{String}
    operator::String
    source_space::String
    target_space::String
    source_dimension::Int
    target_dimension::Int
    source_coordinate::String
    target_coordinate::String
    payload::Dict{String,Any}
end

struct ProviderCapabilityV96
    provider_key::String
    lifecycle_status::String
    kinds::Vector{String}
    physical_states::Vector{String}
    operators::Vector{String}
    source_spaces::Vector{String}
    target_spaces::Vector{String}
    source_dimensions::Vector{Int}
    target_dimensions::Vector{Int}
    source_coordinates::Vector{String}
    target_coordinates::Vector{String}
    implementation_revision::String
    claim_boundary::String
end

struct ResidualFragmentV96
    requirement_key::String
    owned_rows::Vector{String}
    entries::Vector{Tuple{String,String,Float64}}
    rhs_entries::Vector{Tuple{String,Float64}}
    conservative::Bool
    fragment_hash::String
end

mutable struct PhysicalProviderRegistryV96
    manifests::Dict{String,ProviderCapabilityV96}
    implementations::Dict{String,Function}
end

PhysicalProviderRegistryV96() = PhysicalProviderRegistryV96(
    Dict{String,ProviderCapabilityV96}(), Dict{String,Function}())

struct PhysicalGraphAssemblyV96
    status::String
    solver_allowed::Bool
    row_keys::Vector{String}
    variable_keys::Vector{String}
    matrix::Union{Nothing,Matrix{Float64}}
    rhs::Union{Nothing,Vector{Float64}}
    routes::Vector{Dict{String,Any}}
    blockers::Vector{String}
    variable_scales::Dict{String,Float64}
    mesh_hash::String
    assembly_hash::String
end

_v96_matches(value, capabilities) = isempty(capabilities) || value in capabilities

function register_physical_provider_v96!(registry::PhysicalProviderRegistryV96,
        capability::ProviderCapabilityV96, implementation::Function)
    isempty(capability.provider_key) && throw(ArgumentError("empty provider key"))
    capability.lifecycle_status in ("available", "disabled") || throw(ArgumentError(
        "invalid provider lifecycle"))
    haskey(registry.manifests, capability.provider_key) && throw(ArgumentError(
        "duplicate provider key"))
    registry.manifests[capability.provider_key] = capability
    registry.implementations[capability.provider_key] = implementation
    registry
end

function unregister_physical_provider_v96!(registry::PhysicalProviderRegistryV96,
        provider_key::AbstractString)
    key = String(provider_key)
    delete!(registry.manifests, key)
    delete!(registry.implementations, key)
    registry
end

function _v96_provider_matches(capability::ProviderCapabilityV96,
        requirement::ProviderRequirementV96)
    capability.lifecycle_status == "available" || return false
    _v96_matches(requirement.kind, capability.kinds) || return false
    all(state -> _v96_matches(state, capability.physical_states),
        requirement.physical_states) || return false
    _v96_matches(requirement.operator, capability.operators) || return false
    _v96_matches(requirement.source_space, capability.source_spaces) || return false
    _v96_matches(requirement.target_space, capability.target_spaces) || return false
    _v96_matches(requirement.source_dimension, capability.source_dimensions) || return false
    _v96_matches(requirement.target_dimension, capability.target_dimensions) || return false
    _v96_matches(requirement.source_coordinate, capability.source_coordinates) || return false
    _v96_matches(requirement.target_coordinate, capability.target_coordinates) || return false
    true
end

function route_physical_provider_v96(registry::PhysicalProviderRegistryV96,
        requirement::ProviderRequirementV96)
    matches = sort!([key for (key, capability) in registry.manifests
        if _v96_provider_matches(capability, requirement)])
    body = Dict{String,Any}(
        "requirement_key" => requirement.requirement_key,
        "status" => isempty(matches) ? "unsupported" :
            length(matches) == 1 ? "closed" : "ambiguous",
        "selected_provider" => length(matches) == 1 ? first(matches) : nothing,
        "matching_providers" => matches,
        "routing_axes" => ["kind", "physical_states", "operator", "source_space",
            "target_space", "source_dimension", "target_dimension",
            "source_coordinate", "target_coordinate"])
    body["route_hash"] = canonical_hash(body)
    body
end

function residual_fragment_v96(requirement_key, owned_rows, entries, rhs_entries;
        conservative = false)
    normalized_entries = Tuple{String,String,Float64}[
        (String(row), String(variable), Float64(value)) for (row, variable, value) in entries]
    normalized_rhs = Tuple{String,Float64}[(String(row), Float64(value))
        for (row, value) in rhs_entries]
    all(entry -> isfinite(entry[3]), normalized_entries) || throw(ArgumentError(
        "nonfinite fragment coefficient"))
    all(entry -> isfinite(entry[2]), normalized_rhs) || throw(ArgumentError(
        "nonfinite fragment rhs"))
    body = Dict{String,Any}(
        "requirement_key" => String(requirement_key),
        "owned_rows" => sort!(String.(owned_rows)),
        "entries" => sort!([[a, b, c] for (a, b, c) in normalized_entries]; by = canonical_hash),
        "rhs_entries" => sort!([[a, b] for (a, b) in normalized_rhs]; by = canonical_hash),
        "conservative" => Bool(conservative))
    ResidualFragmentV96(String(requirement_key), String.(owned_rows), normalized_entries,
        normalized_rhs, Bool(conservative), canonical_hash(body))
end

function _v96_declared_fragment(requirement::ProviderRequirementV96)
    payload = requirement.payload
    entries = Tuple{String,String,Float64}[]
    for raw in get(payload, "entries", Any[])
        item = Dict{String,Any}(_v93_plain(raw))
        push!(entries, (String(item["row_key"]), String(item["variable_key"]),
            Float64(item["coefficient"])))
    end
    rhs = Tuple{String,Float64}[]
    for raw in get(payload, "rhs_entries", Any[])
        item = Dict{String,Any}(_v93_plain(raw))
        push!(rhs, (String(item["row_key"]), Float64(item["value"])))
    end
    residual_fragment_v96(requirement.requirement_key,
        String.(get(payload, "owned_rows", Any[])), entries, rhs;
        conservative = get(payload, "conservative", false) === true)
end

function default_physical_provider_registry_v96()
    registry = PhysicalProviderRegistryV96()
    state_spaces = ["FV0_volume", "FV0_surface", "FV0_line", "scalar_0d"]
    dimensions = [0, 1, 2, 3]
    coordinates = ["cartesian", "axisymmetric", "curvilinear", "surface",
        "open_field", "scalar"]
    for operator in V96_REGION_OPERATORS
        capability = ProviderCapabilityV96(
            "$(operator)_provider_v96", "available",
            ["primary_operator", "additional_operator"], String[], [operator],
            state_spaces, state_spaces, dimensions, dimensions, coordinates, coordinates,
            "v96.1", PHYSICAL_PROVIDER_RUNTIME_V96_CLAIM_BOUNDARY)
        register_physical_provider_v96!(registry, capability, _v96_declared_fragment)
    end
    for operator in V96_INTERFACE_OPERATORS
        same_dimension = operator == "conservative_mixed_dimension_transfer" ? Int[] : dimensions
        target_dimensions = operator == "conservative_mixed_dimension_transfer" ? Int[] : dimensions
        capability = ProviderCapabilityV96(
            "$(operator)_provider_v96", "available", ["interface"], String[], [operator],
            state_spaces, state_spaces, same_dimension, target_dimensions,
            coordinates, coordinates, "v96.1", PHYSICAL_PROVIDER_RUNTIME_V96_CLAIM_BOUNDARY)
        register_physical_provider_v96!(registry, capability, _v96_declared_fragment)
    end
    for operator in V96_BOUNDARY_OPERATORS
        capability = ProviderCapabilityV96(
            "$(operator)_provider_v96", "available", ["boundary"], String[], [operator],
            state_spaces, state_spaces, dimensions, dimensions, coordinates, coordinates,
            "v96.1", PHYSICAL_PROVIDER_RUNTIME_V96_CLAIM_BOUNDARY)
        register_physical_provider_v96!(registry, capability, _v96_declared_fragment)
    end
    registry
end

function physical_provider_registry_manifest_v96(registry::PhysicalProviderRegistryV96)
    providers = Dict{String,Any}[]
    for key in sort!(collect(keys(registry.manifests)))
        item = registry.manifests[key]
        push!(providers, Dict{String,Any}(
            "provider_key" => item.provider_key, "lifecycle_status" => item.lifecycle_status,
            "kinds" => item.kinds, "physical_states" => item.physical_states,
            "operators" => item.operators, "source_spaces" => item.source_spaces,
            "target_spaces" => item.target_spaces,
            "source_dimensions" => item.source_dimensions,
            "target_dimensions" => item.target_dimensions,
            "source_coordinates" => item.source_coordinates,
            "target_coordinates" => item.target_coordinates,
            "implementation_revision" => item.implementation_revision,
            "claim_boundary" => item.claim_boundary))
    end
    body = Dict{String,Any}(
        "protocol_id" => V96_PROTOCOL_ID, "provider_count" => length(providers),
        "providers" => providers, "routing_unit" => "single_declared_obligation",
        "claim_boundary" => PHYSICAL_PROVIDER_RUNTIME_V96_CLAIM_BOUNDARY)
    body["registry_hash"] = canonical_hash(body)
    body
end

function _v96_requirement(raw)
    item = Dict{String,Any}(_v93_plain(raw))
    ProviderRequirementV96(
        String(item["requirement_key"]), String(item["kind"]),
        String.(get(item, "physical_states", Any[])), String(item["operator"]),
        String(item["source_space"]), String(item["target_space"]),
        Int(item["source_dimension"]), Int(item["target_dimension"]),
        String(item["source_coordinate"]), String(item["target_coordinate"]),
        Dict{String,Any}(_v93_plain(item["payload"])))
end

function assemble_physical_graph_v96(graph_raw, registry::PhysicalProviderRegistryV96)
    graph = Dict{String,Any}(_v93_plain(graph_raw))
    regions = Dict{String,Any}.(get(graph, "regions", Any[]))
    variables = Dict{String,Any}.(get(graph, "variables", Any[]))
    equations = Dict{String,Any}.(get(graph, "equations", Any[]))
    requirements = ProviderRequirementV96[_v96_requirement(item)
        for item in get(graph, "requirements", Any[])]
    blockers = String[]
    append!(blockers, ["declaration:" * String(value)
        for value in get(graph, "declaration_blockers", Any[])])
    isempty(regions) && push!(blockers, "empty_region_inventory")
    isempty(variables) && push!(blockers, "empty_state_inventory")
    region_keys = Set(String(item["region_key"]) for item in regions)
    variable_keys = String[String(item["variable_key"]) for item in variables]
    row_keys = String[String(item["row_key"]) for item in equations]
    length(unique(variable_keys)) == length(variable_keys) || push!(blockers,
        "duplicate_variable_key")
    length(unique(row_keys)) == length(row_keys) || push!(blockers, "duplicate_row_key")
    length(variable_keys) == length(row_keys) || push!(blockers, "nonsquare_graph")
    all(item -> String(item["region_key"]) in region_keys, variables) || push!(blockers,
        "variable_region_unresolved")
    all(item -> String(item["region_key"]) in region_keys, equations) || push!(blockers,
        "equation_region_unresolved")
    variable_set = Set(variable_keys); row_set = Set(row_keys)
    routes = Dict{String,Any}[]
    for requirement in requirements
        route = route_physical_provider_v96(registry, requirement)
        push!(routes, route)
        route["status"] == "closed" || push!(blockers,
            route["status"] == "ambiguous" ? "provider_ambiguous:" * requirement.requirement_key :
            "provider_unavailable:" * requirement.requirement_key)
    end
    scales = Dict(String(item["variable_key"]) => Float64(item["scale"])
        for item in variables)
    all(value -> isfinite(value) && value > 0, values(scales)) || push!(blockers,
        "invalid_variable_scale")
    mesh_hash = String(get(graph, "mesh_hash", canonical_hash(get(graph, "regions", Any[]))))
    if !isempty(blockers)
        body = Dict("status" => "unsupported", "blockers" => sort!(unique(blockers)),
            "routes" => routes, "partial_subgraph_credit" => false, "mesh_hash" => mesh_hash)
        return PhysicalGraphAssemblyV96("unsupported", false, row_keys, variable_keys,
            nothing, nothing, routes, sort!(unique(blockers)), scales, mesh_hash,
            canonical_hash(body))
    end
    row_index = Dict(key => index for (index, key) in enumerate(row_keys))
    variable_index = Dict(key => index for (index, key) in enumerate(variable_keys))
    matrix = zeros(Float64, length(row_keys), length(variable_keys))
    rhs = zeros(Float64, length(row_keys)); owned = Dict(key => 0 for key in row_keys)
    conservative_interfaces = true
    fragments = ResidualFragmentV96[]
    for (requirement, route) in zip(requirements, routes)
        provider = String(route["selected_provider"])
        fragment = registry.implementations[provider](requirement)
        fragment isa ResidualFragmentV96 || throw(ArgumentError("invalid provider fragment"))
        fragment.requirement_key == requirement.requirement_key || throw(ArgumentError(
            "provider fragment requirement mismatch"))
        push!(fragments, fragment)
        for row in fragment.owned_rows
            row in row_set || throw(ArgumentError("provider owns undeclared row"))
            owned[row] += 1
        end
        for (row, variable, value) in fragment.entries
            row in row_set && variable in variable_set || throw(ArgumentError(
                "provider references undeclared graph key"))
            matrix[row_index[row], variable_index[variable]] += value
        end
        for (row, value) in fragment.rhs_entries
            row in row_set || throw(ArgumentError("provider rhs references undeclared row"))
            rhs[row_index[row]] += value
        end
        requirement.kind == "interface" && (conservative_interfaces &= fragment.conservative)
    end
    ownership_failures = sort!([key for (key, count) in owned if count != 1])
    isempty(ownership_failures) || push!(blockers, "primary_row_ownership_incomplete")
    conservative_interfaces || push!(blockers, "interface_conservation_not_attested")
    if !isempty(blockers)
        body = Dict("status" => "unsupported", "blockers" => blockers,
            "ownership_failures" => ownership_failures, "partial_subgraph_credit" => false)
        return PhysicalGraphAssemblyV96("unsupported", false, row_keys, variable_keys,
            nothing, nothing, routes, blockers, scales, mesh_hash, canonical_hash(body))
    end
    all(isfinite, matrix) && all(isfinite, rhs) || throw(ArgumentError(
        "nonfinite assembled system"))
    body = Dict{String,Any}(
        "status" => "closed", "row_keys" => row_keys, "variable_keys" => variable_keys,
        "matrix" => vec(matrix), "rhs" => rhs, "mesh_hash" => mesh_hash,
        "fragment_hashes" => [item.fragment_hash for item in fragments],
        "interface_conservation_attested" => conservative_interfaces,
        "partial_subgraph_credit" => false)
    PhysicalGraphAssemblyV96("closed", true, row_keys, variable_keys, matrix, rhs,
        routes, String[], scales, mesh_hash, canonical_hash(body))
end

physical_residual_v96(assembly::PhysicalGraphAssemblyV96, state) =
    assembly.solver_allowed ? assembly.matrix * state - assembly.rhs :
    throw(ArgumentError("whole graph is not solver eligible"))

physical_jacobian_v96(assembly::PhysicalGraphAssemblyV96, state = nothing) =
    assembly.solver_allowed ? copy(assembly.matrix) :
    throw(ArgumentError("whole graph is not solver eligible"))

function solve_physical_graph_v96(assembly::PhysicalGraphAssemblyV96)
    if !assembly.solver_allowed
        return Dict{String,Any}(
            "status" => "unsupported", "solver_executed" => false,
            "whole_graph_closed" => false, "partial_subgraph_credit" => false,
            "blockers" => assembly.blockers, "assembly_hash" => assembly.assembly_hash)
    end
    state = try
        assembly.matrix \ assembly.rhs
    catch error
        return Dict{String,Any}(
            "status" => "numerical_fail", "solver_executed" => true,
            "whole_graph_closed" => true, "partial_subgraph_credit" => false,
            "reason" => sprint(showerror, error), "assembly_hash" => assembly.assembly_hash)
    end
    residual = physical_residual_v96(assembly, state)
    normalized_residual = norm(residual) / max(norm(assembly.rhs), 1.0)
    jacobian = physical_jacobian_v96(assembly, state)
    epsilon = 1e-7; finite_difference = similar(jacobian)
    base = physical_residual_v96(assembly, state)
    for column in axes(jacobian, 2)
        perturbed = copy(state); perturbed[column] += epsilon
        finite_difference[:, column] .=
            (physical_residual_v96(assembly, perturbed) - base) / epsilon
    end
    jacobian_error = norm(finite_difference - jacobian) / max(norm(jacobian), eps())
    passed = all(isfinite, state) && normalized_residual <= 1e-10 && jacobian_error <= 1e-7
    state_map = Dict(assembly.variable_keys[index] => state[index]
        for index in eachindex(state))
    physical_map = Dict(key => state_map[key] * assembly.variable_scales[key]
        for key in assembly.variable_keys)
    body = Dict{String,Any}(
        "status" => passed ? "pass" : "numerical_fail", "solver_executed" => true,
        "whole_graph_closed" => true, "partial_subgraph_credit" => false,
        "state" => state, "state_map" => state_map, "physical_state_map" => physical_map,
        "normalized_residual" => normalized_residual,
        "jacobian_relative_error" => jacobian_error, "exact_jacobian_used" => true,
        "assembly_hash" => assembly.assembly_hash, "mesh_hash" => assembly.mesh_hash)
    body["solve_hash"] = canonical_hash(body)
    body
end

function physical_graph_assembly_to_dict_v96(assembly::PhysicalGraphAssemblyV96)
    Dict{String,Any}(
        "status" => assembly.status, "solver_allowed" => assembly.solver_allowed,
        "row_count" => length(assembly.row_keys), "variable_count" => length(assembly.variable_keys),
        "routes" => assembly.routes, "blockers" => assembly.blockers,
        "mesh_hash" => assembly.mesh_hash, "assembly_hash" => assembly.assembly_hash,
        "partial_subgraph_credit" => false,
        "claim_boundary" => PHYSICAL_PROVIDER_RUNTIME_V96_CLAIM_BOUNDARY)
end
