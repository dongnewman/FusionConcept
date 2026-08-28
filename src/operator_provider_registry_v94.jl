const V94_PROTOCOL_ID = "fusionconceptai-v94-generic-capability-multiregion-20260828"
const OPERATOR_PROVIDER_REGISTRY_V94_CLAIM_BOUNDARY =
    "Provider routing establishes declared capability coverage only. It is not a physical solve, numerical verification, validation, or experimental evidence."

const V94_PROVIDER_LIFECYCLE = Set(["available", "disabled"])
const V94_REQUIREMENT_KINDS = Set(["field", "operator", "additional_operator", "interface", "boundary"])

struct ProviderCapabilityV94
    provider_key::String
    lifecycle_status::String
    state_capabilities::Vector{String}
    operator_capabilities::Vector{String}
    interface_capabilities::Vector{String}
    function_space_capabilities::Vector{String}
    dimension_capabilities::Vector{Int}
    coordinate_capabilities::Vector{String}
    output_capabilities::Vector{String}
    implementation_revision::String
end

struct CapabilityRequirementV94
    requirement_key::String
    kind::String
    states::Vector{String}
    operator::Union{Nothing,String}
    interface::Union{Nothing,String}
    function_spaces::Vector{String}
    dimension::Int
    coordinate::String
    required_output::String
    payload::Dict{String,Any}
end

mutable struct OperatorProviderRegistryV94
    manifests::Dict{String,ProviderCapabilityV94}
    implementations::Dict{String,Function}
end

OperatorProviderRegistryV94() = OperatorProviderRegistryV94(
    Dict{String,ProviderCapabilityV94}(), Dict{String,Function}())

function provider_capability_to_dict_v94(capability::ProviderCapabilityV94)
    Dict{String,Any}(
        "provider_key" => capability.provider_key,
        "lifecycle_status" => capability.lifecycle_status,
        "state_capabilities" => sort!(unique(capability.state_capabilities)),
        "operator_capabilities" => sort!(unique(capability.operator_capabilities)),
        "interface_capabilities" => sort!(unique(capability.interface_capabilities)),
        "function_space_capabilities" => sort!(unique(capability.function_space_capabilities)),
        "dimension_capabilities" => sort!(unique(capability.dimension_capabilities)),
        "coordinate_capabilities" => sort!(unique(capability.coordinate_capabilities)),
        "output_capabilities" => sort!(unique(capability.output_capabilities)),
        "implementation_revision" => capability.implementation_revision,
        "routing_unit" => "single_declared_obligation",
        "claim_boundary" => OPERATOR_PROVIDER_REGISTRY_V94_CLAIM_BOUNDARY)
end

function _validate_provider_capability_v94(capability::ProviderCapabilityV94)
    isempty(capability.provider_key) && throw(ArgumentError("provider_key is required"))
    capability.lifecycle_status in V94_PROVIDER_LIFECYCLE ||
        throw(ArgumentError("invalid provider lifecycle status"))
    isempty(capability.dimension_capabilities) &&
        throw(ArgumentError("provider must declare dimension capabilities"))
    all(d -> d in 0:3, capability.dimension_capabilities) ||
        throw(ArgumentError("provider dimensions must be in 0:3"))
    isempty(capability.coordinate_capabilities) &&
        throw(ArgumentError("provider must declare coordinate capabilities"))
    isempty(capability.output_capabilities) &&
        throw(ArgumentError("provider must declare output capabilities"))
    capability
end

function register_provider_v94!(registry::OperatorProviderRegistryV94,
        capability::ProviderCapabilityV94, implementation::Function)
    _validate_provider_capability_v94(capability)
    haskey(registry.manifests, capability.provider_key) &&
        throw(ArgumentError("provider_key already registered"))
    registry.manifests[capability.provider_key] = capability
    registry.implementations[capability.provider_key] = implementation
    registry
end

function unregister_provider_v94!(registry::OperatorProviderRegistryV94, provider_key::AbstractString)
    delete!(registry.manifests, String(provider_key))
    delete!(registry.implementations, String(provider_key))
    registry
end

function _provider_matches_v94(capability::ProviderCapabilityV94,
        requirement::CapabilityRequirementV94)
    capability.lifecycle_status == "available" || return false, "provider_disabled"
    requirement.dimension in capability.dimension_capabilities ||
        return false, "dimension_capability_missing"
    requirement.coordinate in capability.coordinate_capabilities ||
        return false, "coordinate_capability_missing"
    isempty(setdiff(Set(requirement.states), Set(capability.state_capabilities))) ||
        return false, "state_capability_missing"
    isempty(setdiff(Set(requirement.function_spaces),
        Set(capability.function_space_capabilities))) ||
        return false, "function_space_capability_missing"
    requirement.required_output in capability.output_capabilities ||
        return false, "output_capability_missing"
    requirement.operator === nothing ||
        requirement.operator in capability.operator_capabilities ||
        return false, "operator_capability_missing"
    requirement.interface === nothing ||
        requirement.interface in capability.interface_capabilities ||
        return false, "interface_capability_missing"
    true, "pass"
end

function route_provider_v94(registry::OperatorProviderRegistryV94,
        requirement::CapabilityRequirementV94)
    requirement.kind in V94_REQUIREMENT_KINDS ||
        throw(ArgumentError("invalid v94 capability requirement kind"))
    matches = String[]
    mismatches = Dict{String,Any}[]
    for provider_key in sort!(collect(keys(registry.manifests)))
        capability = registry.manifests[provider_key]
        matched, reason = _provider_matches_v94(capability, requirement)
        if matched
            push!(matches, provider_key)
        else
            push!(mismatches, Dict("provider_key" => provider_key, "reason" => reason))
        end
    end
    body = Dict{String,Any}(
        "requirement_key" => requirement.requirement_key,
        "kind" => requirement.kind,
        "status" => isempty(matches) ? "unsupported" : "closed",
        "selected_provider" => isempty(matches) ? nothing : first(matches),
        "matching_providers" => matches,
        "mismatches" => mismatches,
        "routing_axes" => ["states", "operator", "interface", "function_spaces",
            "dimension", "coordinate", "required_output"],
        "routing_unit" => "single_declared_obligation")
    body["route_hash"] = canonical_hash(body)
    body
end

function provider_registry_manifest_v94(registry::OperatorProviderRegistryV94)
    records = [provider_capability_to_dict_v94(registry.manifests[key])
        for key in sort!(collect(keys(registry.manifests)))]
    body = Dict{String,Any}(
        "protocol_id" => V94_PROTOCOL_ID,
        "providers" => records,
        "provider_count" => length(records),
        "routing_unit" => "single_declared_obligation",
        "claim_boundary" => OPERATOR_PROVIDER_REGISTRY_V94_CLAIM_BOUNDARY)
    body["registry_hash"] = canonical_hash(body)
    body
end
