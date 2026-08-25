"A versioned, append-only package of confinement-family definitions."
struct FamilyExtensionPackage
    id::String
    version::String
    schema_overlay_id::String
    family_specs::Vector{FamilySpec}
    source_ids::Vector{String}
    claim_boundary::String

    function FamilyExtensionPackage(id::AbstractString, version::AbstractString,
            schema_overlay_id::AbstractString, family_specs::Vector{FamilySpec},
            source_ids, claim_boundary::AbstractString)
        package_id = String(id)
        package_version = String(version)
        isempty(package_id) && throw(ArgumentError("extension package ID must not be empty"))
        occursin(r"^[0-9]+\.[0-9]+\.[0-9]+$", package_version) ||
            throw(ArgumentError("extension package version must use major.minor.patch"))
        isempty(schema_overlay_id) &&
            throw(ArgumentError("schema overlay ID must not be empty"))
        isempty(family_specs) &&
            throw(ArgumentError("extension package must declare at least one family"))
        ids = getfield.(family_specs, :id)
        length(unique(ids)) == length(ids) ||
            throw(ArgumentError("duplicate family ID inside extension package"))
        sources = sort!(unique(String.(collect(source_ids))))
        isempty(sources) &&
            throw(ArgumentError("extension package must cite at least one source"))
        isempty(claim_boundary) &&
            throw(ArgumentError("extension package claim boundary must not be empty"))
        return new(package_id, package_version, String(schema_overlay_id),
            family_specs, sources, String(claim_boundary))
    end
end

"Base registry plus collision-checked extension packages; the base is never mutated."
mutable struct FamilyExtensionRegistry
    base::FamilyRegistry
    sealed_base_manifest_hash::String
    packages::Dict{String,FamilyExtensionPackage}
end

function _family_spec_to_dict(spec::FamilySpec)
    return Dict{String,Any}(
        "id" => spec.id,
        "field_line_classes" => sort!(collect(spec.field_line_classes)),
        "symmetry_classes" => sort!(collect(spec.symmetry_classes)),
        "coordinate_chart" => spec.coordinate_chart,
        "fidelity1_solvers" => sort!(copy(spec.fidelity1_solvers)),
        "claim_ceiling_without_fidelity1" =>
            spec.claim_ceiling_without_fidelity1,
    )
end

function family_registry_manifest(registry::FamilyRegistry)
    return Dict{String,Any}(
        "families" => [_family_spec_to_dict(spec)
            for spec in sort!(collect(values(registry.specs)); by = item -> item.id)],
    )
end

family_registry_hash(registry::FamilyRegistry) =
    canonical_hash(family_registry_manifest(registry))

function FamilyExtensionRegistry(base::FamilyRegistry = default_family_registry())
    return FamilyExtensionRegistry(base, family_registry_hash(base),
        Dict{String,FamilyExtensionPackage}())
end

function register_extension!(registry::FamilyExtensionRegistry,
        package::FamilyExtensionPackage)
    haskey(registry.packages, package.id) && throw(ArgumentError(
        "extension package already registered: $(package.id)"))
    occupied = Set(keys(registry.base.specs))
    for existing in values(registry.packages)
        union!(occupied, getfield.(existing.family_specs, :id))
    end
    collisions = sort!(collect(intersect(occupied,
        Set(getfield.(package.family_specs, :id)))))
    isempty(collisions) || throw(ArgumentError(
        "extension family IDs collide with registered families: $(join(collisions, ", "))"))
    registry.packages[package.id] = package
    return registry
end

function family_extension_manifest(registry::FamilyExtensionRegistry)
    packages = Dict{String,Any}[]
    for package in sort!(collect(values(registry.packages)); by = item -> item.id)
        push!(packages, Dict{String,Any}(
            "id" => package.id,
            "version" => package.version,
            "schema_overlay_id" => package.schema_overlay_id,
            "families" => [_family_spec_to_dict(spec) for spec in
                sort!(copy(package.family_specs); by = item -> item.id)],
            "source_ids" => copy(package.source_ids),
            "claim_boundary" => package.claim_boundary,
        ))
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "sealed_base_manifest_hash" => registry.sealed_base_manifest_hash,
        "packages" => packages,
    )
end

family_extension_hash(registry::FamilyExtensionRegistry) =
    canonical_hash(family_extension_manifest(registry))

function effective_family_registry(registry::FamilyExtensionRegistry)
    specs = collect(values(registry.base.specs))
    for package in values(registry.packages)
        append!(specs, package.family_specs)
    end
    return FamilyRegistry(specs)
end

family_spec(registry::FamilyExtensionRegistry, id::AbstractString) =
    family_spec(effective_family_registry(registry), id)

validate_family(registry::FamilyExtensionRegistry, genome::Genome) =
    validate_family(effective_family_registry(registry), genome)

const _MISSION_ANCHOR_POLICIES = Set([
    :forbidden,
    :bounded_nonpromotable_allowed,
])

"A typed selector and comparison contract for one scientifically distinct mission."
struct MissionContractSpec
    id::String
    version::String
    mission_kinds::Set{String}
    fuels::Set{String}
    operating_modes::Set{String}
    family_ids::Set{String}
    objective_semantics::Vector{String}
    hard_gate_ids::Vector{String}
    anchor_policy::Symbol
    require_same_fuel_for_comparison::Bool
    comparison_scope::String
    claim_ceiling::String

    function MissionContractSpec(id::AbstractString, version::AbstractString,
            mission_kinds, fuels, operating_modes, family_ids,
            objective_semantics, hard_gate_ids;
            anchor_policy::Symbol = :forbidden,
            require_same_fuel_for_comparison::Bool = true,
            comparison_scope::AbstractString,
            claim_ceiling::AbstractString)
        contract_id = String(id)
        contract_version = String(version)
        isempty(contract_id) && throw(ArgumentError("mission contract ID must not be empty"))
        occursin(r"^[0-9]+\.[0-9]+\.[0-9]+$", contract_version) ||
            throw(ArgumentError("mission contract version must use major.minor.patch"))
        selectors = (Set(String.(collect(mission_kinds))),
            Set(String.(collect(fuels))), Set(String.(collect(operating_modes))),
            Set(String.(collect(family_ids))))
        any(isempty, selectors) &&
            throw(ArgumentError("mission contract selectors must not be empty"))
        objectives = sort!(unique(String.(collect(objective_semantics))))
        gates = sort!(unique(String.(collect(hard_gate_ids))))
        isempty(objectives) &&
            throw(ArgumentError("mission contract requires objective semantics"))
        isempty(gates) && throw(ArgumentError("mission contract requires hard gates"))
        anchor_policy in _MISSION_ANCHOR_POLICIES ||
            throw(ArgumentError("unsupported anchor policy $anchor_policy"))
        isempty(comparison_scope) &&
            throw(ArgumentError("comparison scope must not be empty"))
        isempty(claim_ceiling) &&
            throw(ArgumentError("claim ceiling must not be empty"))
        return new(contract_id, contract_version, selectors[1], selectors[2],
            selectors[3], selectors[4], objectives, gates, anchor_policy,
            require_same_fuel_for_comparison, String(comparison_scope),
            String(claim_ceiling))
    end
end

mutable struct MissionContractRegistry
    specs::Dict{String,MissionContractSpec}
end

MissionContractRegistry() =
    MissionContractRegistry(Dict{String,MissionContractSpec}())

function register_mission_contract!(registry::MissionContractRegistry,
        spec::MissionContractSpec)
    haskey(registry.specs, spec.id) &&
        throw(ArgumentError("mission contract already registered: $(spec.id)"))
    registry.specs[spec.id] = spec
    return registry
end

_selector_matches(values::Set{String}, value::String) =
    "*" in values || value in values

function mission_contract_matches(spec::MissionContractSpec, mission::MissionSpec,
        family::AbstractString)
    return _selector_matches(spec.mission_kinds, mission.kind) &&
        _selector_matches(spec.fuels, mission.fuel) &&
        _selector_matches(spec.operating_modes, mission.operating_mode) &&
        _selector_matches(spec.family_ids, String(family))
end

mission_contract_matches(spec::MissionContractSpec, genome::Genome) =
    mission_contract_matches(spec, genome.mission, genome.family)

function _mission_contract_specificity(spec::MissionContractSpec)
    return count(values -> !("*" in values),
        (spec.mission_kinds, spec.fuels, spec.operating_modes, spec.family_ids))
end

function mission_contract_for(registry::MissionContractRegistry, mission::MissionSpec,
        family::AbstractString)
    matches = [spec for spec in values(registry.specs)
        if mission_contract_matches(spec, mission, family)]
    isempty(matches) && throw(ArgumentError(
        "no mission contract for $(mission.kind)|$(mission.fuel)|" *
        "$(mission.operating_mode)|$(family)"))
    best_specificity = maximum(_mission_contract_specificity.(matches))
    best = sort!(filter(spec -> _mission_contract_specificity(spec) ==
        best_specificity, matches); by = item -> item.id)
    length(best) == 1 || throw(ArgumentError(
        "ambiguous mission contracts: $(join(getfield.(best, :id), ", "))"))
    return only(best)
end

mission_contract_for(registry::MissionContractRegistry, genome::Genome) =
    mission_contract_for(registry, genome.mission, genome.family)

function mission_comparison_compatible(registry::MissionContractRegistry,
        a::Genome, b::Genome)
    a_contract = mission_contract_for(registry, a)
    b_contract = mission_contract_for(registry, b)
    reasons = String[]
    a_contract.id == b_contract.id || push!(reasons,
        "mission contracts differ: $(a_contract.id) versus $(b_contract.id)")
    if a_contract.id == b_contract.id &&
            a_contract.require_same_fuel_for_comparison &&
            a.mission.fuel != b.mission.fuel
        push!(reasons, "fuel bases differ: $(a.mission.fuel) versus $(b.mission.fuel)")
    end
    return isempty(reasons), reasons
end

function _mission_contract_to_dict(spec::MissionContractSpec)
    return Dict{String,Any}(
        "id" => spec.id,
        "version" => spec.version,
        "selector" => Dict(
            "mission_kinds" => sort!(collect(spec.mission_kinds)),
            "fuels" => sort!(collect(spec.fuels)),
            "operating_modes" => sort!(collect(spec.operating_modes)),
            "family_ids" => sort!(collect(spec.family_ids))),
        "objective_semantics" => copy(spec.objective_semantics),
        "hard_gate_ids" => copy(spec.hard_gate_ids),
        "anchor_policy" => String(spec.anchor_policy),
        "require_same_fuel_for_comparison" =>
            spec.require_same_fuel_for_comparison,
        "comparison_scope" => spec.comparison_scope,
        "claim_ceiling" => spec.claim_ceiling,
    )
end

function mission_contract_manifest(registry::MissionContractRegistry)
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "contracts" => [_mission_contract_to_dict(spec) for spec in
            sort!(collect(values(registry.specs)); by = item -> item.id)],
    )
end

mission_contract_hash(registry::MissionContractRegistry) =
    canonical_hash(mission_contract_manifest(registry))

function _register_default_contract!(registry, id, kind, mode, objectives, gates;
        anchor_policy = :forbidden, claim_ceiling = "screening_only")
    return register_mission_contract!(registry, MissionContractSpec(
        id, "1.0.0", [kind], ["*"], [mode], ["*"], objectives, gates;
        anchor_policy = anchor_policy,
        comparison_scope = "same contract, operating mode, fuel, and declared outer envelope",
        claim_ceiling = claim_ceiling))
end

function default_mission_contract_registry()
    registry = MissionContractRegistry()
    common_gates = ["variable_topology_representation",
        "unified_physics_evaluation", "minimal_engineering_closure",
        "same_outer_envelope", "cheap_robustness"]
    for mode in ("steady_state", "long_pulse", "pulsed")
        suffix = replace(mode, "_" => "-")
        _register_default_contract!(registry, "science_gain_$(suffix)_v1",
            "science_gain_demo", mode,
            ["scientific_gain", "stability_margin", "device_complexity"],
            common_gates; claim_ceiling = "physics_proxy")
    end
    for mode in ("steady_state", "pulsed")
        suffix = replace(mode, "_" => "-")
        _register_default_contract!(registry, "net_electric_$(suffix)_v1",
            "net_electric_pilot", mode,
            ["average_net_electric_power", "availability", "device_complexity"],
            vcat(common_gates, ["independent_power_and_lifetime_evidence"]))
        _register_default_contract!(registry, "fusion_neutron_source_$(suffix)_v1",
            "fusion_neutron_source", mode,
            ["verified_neutron_output", "availability", "device_complexity"],
            ["variable_topology_representation", "source_yield_domain",
                "minimal_engineering_closure", "cheap_robustness"];
            anchor_policy = :bounded_nonpromotable_allowed,
            claim_ceiling = "bounded_neutron_source_only")
    end
    _register_default_contract!(registry, "single_shot_target_gain_pulsed_v1",
        "single_shot_target_gain_science", "pulsed",
        ["single_shot_target_gain"],
        ["energy_conservation", "target_gain_experimental_validation"];
        anchor_policy = :bounded_nonpromotable_allowed,
        claim_ceiling = "bounded_single_shot_target_gain_only")
    return registry
end
