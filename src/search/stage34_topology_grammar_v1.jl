const _STAGE34_ACCOUNT_IDS_V1 = Set((:particle, :ion_energy, :electron_energy,
    :species, :actuator, :power))

struct Stage34TopologyNodeV1
    node_id::String
    dimension::String
    boundary_class::String
    time_mode::String
    account_ids::Vector{Symbol}
    node_hash::String
end

struct Stage34TopologyInterfaceV1
    interface_id::String
    source_node_id::String
    target_node_id::Union{Nothing,String}
    account_ids::Vector{Symbol}
    flux_capability_id::String
    interface_hash::String
end

struct Stage34TopologyGrammarV1
    schema_version::String
    candidate_binding_hash::String
    nodes::Vector{Stage34TopologyNodeV1}
    interfaces::Vector{Stage34TopologyInterfaceV1}
    required_stability_operator_ids::Vector{String}
    grammar_hash::String
end

struct Stage34TopologyCompilationV1
    schema_version::String
    candidate_binding_hash::String
    state_package_hash::String
    grammar_hash::String
    status::Symbol
    classification_code::String
    stage3_bindings::Vector{Dict{String,Any}}
    stage4_bindings::Vector{Dict{String,Any}}
    interface_flux_pairs::Vector{Dict{String,Any}}
    audits::Dict{String,Any}
    reasons::Vector{String}
    compilation_hash::String
end

const _STAGE34_ACCOUNT_CAPABILITIES_V1 = Dict{Symbol,String}(
    :particle => "regional_particle_continuity_v1",
    :ion_energy => "regional_ion_energy_balance_v1",
    :electron_energy => "regional_electron_energy_balance_v1",
    :species => "regional_species_balance_v1",
    :actuator => "regional_actuator_fulfillment_v1",
    :power => "regional_power_ledger_v1")

function compile_stage34_topology_node_v1(node_id::AbstractString;
        dimension::AbstractString, boundary_class::AbstractString,
        time_mode::AbstractString, account_ids::Vector{Symbol})
    all(!isempty, (node_id, dimension, boundary_class, time_mode)) ||
        throw(ArgumentError("topology node identifiers cannot be empty"))
    accounts = sort!(unique(copy(account_ids)); by = String)
    isempty(accounts) && throw(ArgumentError("topology node requires accounts"))
    all(id -> id in _STAGE34_ACCOUNT_IDS_V1, accounts) || throw(ArgumentError(
        "topology node declares an unknown account"))
    core = Dict{String,Any}("node_id" => String(node_id),
        "dimension" => String(dimension), "boundary_class" => String(boundary_class),
        "time_mode" => String(time_mode), "account_ids" => String.(accounts))
    return Stage34TopologyNodeV1(String(node_id), String(dimension),
        String(boundary_class), String(time_mode), accounts, canonical_hash(core))
end

function compile_stage34_topology_interface_v1(interface_id::AbstractString,
        source_node_id::AbstractString, target_node_id::Union{Nothing,AbstractString};
        account_ids::Vector{Symbol}, flux_capability_id::AbstractString)
    isempty(interface_id) && throw(ArgumentError("interface id cannot be empty"))
    isempty(source_node_id) && throw(ArgumentError("interface source cannot be empty"))
    target = target_node_id === nothing ? nothing : String(target_node_id)
    target == source_node_id && throw(ArgumentError("interface cannot self-connect"))
    accounts = sort!(unique(copy(account_ids)); by = String)
    isempty(accounts) && throw(ArgumentError("interface requires transported accounts"))
    all(id -> id in _STAGE34_ACCOUNT_IDS_V1, accounts) || throw(ArgumentError(
        "interface declares an unknown account"))
    isempty(flux_capability_id) && throw(ArgumentError("flux capability cannot be empty"))
    core = Dict{String,Any}("interface_id" => String(interface_id),
        "source_node_id" => String(source_node_id), "target_node_id" => target,
        "account_ids" => String.(accounts),
        "flux_capability_id" => String(flux_capability_id))
    return Stage34TopologyInterfaceV1(String(interface_id), String(source_node_id),
        target, accounts, String(flux_capability_id), canonical_hash(core))
end

function compile_stage34_topology_grammar_v1(candidate_binding_hash::AbstractString,
        nodes::Vector{Stage34TopologyNodeV1},
        interfaces::Vector{Stage34TopologyInterfaceV1};
        required_stability_operator_ids::Vector{String})
    binding = _c2_check_hash_v1(candidate_binding_hash, "topology candidate binding hash")
    isempty(nodes) && throw(ArgumentError("topology grammar requires nodes"))
    node_ids = getfield.(nodes, :node_id)
    length(unique(node_ids)) == length(node_ids) || throw(ArgumentError(
        "topology node ids must be unique"))
    interface_ids = getfield.(interfaces, :interface_id)
    length(unique(interface_ids)) == length(interface_ids) || throw(ArgumentError(
        "topology interface ids must be unique"))
    stability = sort!(unique(copy(required_stability_operator_ids)))
    isempty(stability) && throw(ArgumentError(
        "Stage 4 operator requirements must be explicit and non-empty"))
    ordered_nodes = sort!(copy(nodes); by = item -> item.node_id)
    ordered_interfaces = sort!(copy(interfaces); by = item -> item.interface_id)
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => binding,
        "node_hashes" => getfield.(ordered_nodes, :node_hash),
        "interface_hashes" => getfield.(ordered_interfaces, :interface_hash),
        "required_stability_operator_ids" => stability)
    return Stage34TopologyGrammarV1("1.0.0", binding, ordered_nodes,
        ordered_interfaces, stability, canonical_hash(core))
end

function _stage34_state_accounts_v1(state::C2CandidateStatePackageV1)
    accounts = Set{Symbol}()
    !isempty(state.particle_accounts) && push!(accounts, :particle)
    energy_ids = Set(getfield.(state.energy_accounts, :field_id))
    "ion_thermal_energy" in energy_ids && push!(accounts, :ion_energy)
    "electron_thermal_energy" in energy_ids && push!(accounts, :electron_energy)
    !isempty(state.species_states) && push!(accounts, :species)
    Set(getfield.(state.actuator_states, :role)) == _C2_ACTUATOR_ROLES_V1 &&
        push!(accounts, :actuator)
    power_ids = Set(getfield.(state.power_ledger.accounts, :field_id))
    _C2_REQUIRED_POWER_ACCOUNTS_V1 ⊆ power_ids && push!(accounts, :power)
    return accounts
end

function _stage34_flux_pairs_v1(interfaces::Vector{Stage34TopologyInterfaceV1})
    pairs = Dict{String,Any}[]
    for interface in interfaces, account in interface.account_ids
        push!(pairs, Dict{String,Any}("interface_id" => interface.interface_id,
            "node_id" => interface.source_node_id, "account_id" => String(account),
            "sign" => 1, "flux_capability_id" => interface.flux_capability_id))
        interface.target_node_id === nothing || push!(pairs, Dict{String,Any}(
            "interface_id" => interface.interface_id,
            "node_id" => interface.target_node_id, "account_id" => String(account),
            "sign" => -1, "flux_capability_id" => interface.flux_capability_id))
    end
    return sort!(pairs; by = item -> (item["interface_id"], item["account_id"],
        item["node_id"]))
end

function compile_stage34_topology_v1(state::C2CandidateStatePackageV1,
        grammar::Stage34TopologyGrammarV1;
        stability_registry::Vector{StabilityCapabilityContractV2} =
            default_stability_capability_registry_v2(),
        additional_capability_ids::Vector{String} = String[])
    state.candidate_binding_hash == grammar.candidate_binding_hash || throw(ArgumentError(
        "state package and topology grammar binding mismatch"))
    fail_reasons = String[]
    unsupported_reasons = String[]
    unknown_reasons = String[]
    declared_capability_ids = Set(vcat(state.capability_ids,
        sort!(unique(copy(additional_capability_ids)))))
    node_ids = Set(getfield.(grammar.nodes, :node_id))
    package_regions = Set(state.region_ids)
    node_ids == package_regions || push!(fail_reasons, "region_node_inventory_mismatch")
    all(node -> node.time_mode == String(state.time_mode), grammar.nodes) ||
        push!(fail_reasons, "node_time_mode_mismatch")
    package_boundaries = Set(state.boundary_classes)
    all(node -> node.boundary_class in package_boundaries, grammar.nodes) ||
        push!(fail_reasons, "node_boundary_not_declared_by_state_package")

    declared_accounts = reduce(union, (Set(node.account_ids) for node in grammar.nodes);
        init = Set{Symbol}())
    state_accounts = _stage34_state_accounts_v1(state)
    missing_grammar_accounts = setdiff(_STAGE34_ACCOUNT_IDS_V1, declared_accounts)
    missing_state_accounts = setdiff(declared_accounts, state_accounts)
    isempty(missing_grammar_accounts) || push!(fail_reasons,
        "missing_required_accounts:$(join(sort!(String.(collect(missing_grammar_accounts))), ','))")
    isempty(missing_state_accounts) || push!(unknown_reasons,
        "state_package_missing_accounts:$(join(sort!(String.(collect(missing_state_accounts))), ','))")

    stage3 = Dict{String,Any}[]
    producer_counts = Dict{String,Int}()
    for node in grammar.nodes, account in node.account_ids
        slot = "$(node.node_id)::$(account)"
        capability = _STAGE34_ACCOUNT_CAPABILITIES_V1[account]
        producer_counts[slot] = get(producer_counts, slot, 0) + 1
        capability in declared_capability_ids || push!(unsupported_reasons,
            "missing_stage3_capability:$capability")
        push!(stage3, Dict{String,Any}("binding_id" => "stage3:$slot",
            "stage" => "stage3", "node_id" => node.node_id,
            "account_id" => String(account), "row_slot_id" => slot,
            "capability_id" => capability))
    end
    all(==(1), values(producer_counts)) || push!(fail_reasons,
        "state_slot_must_have_exactly_one_stage3_producer")

    interface_errors = String[]
    for edge in grammar.interfaces
        edge.source_node_id in node_ids || push!(interface_errors,
            "$(edge.interface_id):missing_source")
        edge.target_node_id === nothing || edge.target_node_id in node_ids ||
            push!(interface_errors, "$(edge.interface_id):missing_target")
        source = findfirst(node -> node.node_id == edge.source_node_id, grammar.nodes)
        source === nothing || all(id -> id in grammar.nodes[source].account_ids,
            edge.account_ids) || push!(interface_errors,
            "$(edge.interface_id):source_account_mismatch")
        if edge.target_node_id !== nothing
            target = findfirst(node -> node.node_id == edge.target_node_id, grammar.nodes)
            target === nothing || all(id -> id in grammar.nodes[target].account_ids,
                edge.account_ids) || push!(interface_errors,
                "$(edge.interface_id):target_account_mismatch")
        end
        edge.flux_capability_id in declared_capability_ids || push!(unsupported_reasons,
            "missing_flux_capability:$(edge.flux_capability_id)")
    end
    isempty(interface_errors) || append!(fail_reasons, interface_errors)
    flux_pairs = _stage34_flux_pairs_v1(grammar.interfaces)
    internal_flux_closed = all(edge -> edge.target_node_id === nothing ||
        all(account -> begin
            records = filter(item -> item["interface_id"] == edge.interface_id &&
                item["account_id"] == String(account), flux_pairs)
            length(records) == 2 && sum(Int(item["sign"]) for item in records) == 0
        end, edge.account_ids), grammar.interfaces)
    internal_flux_closed || push!(fail_reasons, "internal_interface_flux_not_paired")

    stability_contracts = Dict(item.operator_id => item for item in stability_registry)
    stage4 = Dict{String,Any}[]
    for operator_id in grammar.required_stability_operator_ids
        if !haskey(stability_contracts, operator_id)
            push!(unsupported_reasons, "missing_stage4_operator:$operator_id")
            continue
        end
        contract = stability_contracts[operator_id]
        contract.backend_available || push!(unsupported_reasons,
            "stage4_backend_unavailable:$operator_id")
        compatible_nodes = sort!(String[node.node_id for node in grammar.nodes if
            node.dimension in contract.supported_dimensions &&
            node.boundary_class in contract.supported_boundary_classes &&
            node.time_mode in contract.supported_time_modes])
        isempty(compatible_nodes) && push!(unsupported_reasons,
            "stage4_context_incompatible:$operator_id")
        contract.capability_id in declared_capability_ids || push!(unsupported_reasons,
            "missing_stage4_capability:$(contract.capability_id)")
        push!(stage4, Dict{String,Any}("binding_id" => "stage4:$operator_id",
            "stage" => "stage4", "operator_id" => operator_id,
            "capability_id" => contract.capability_id,
            "compatible_node_ids" => compatible_nodes,
            "claim_boundary" => contract.claim_boundary))
    end

    fail_reasons = sort!(unique(fail_reasons))
    unsupported_reasons = sort!(unique(unsupported_reasons))
    unknown_reasons = sort!(unique(unknown_reasons))
    status = !isempty(fail_reasons) ? :fail : !isempty(unsupported_reasons) ?
        :unsupported : !isempty(unknown_reasons) ? :unknown : :pass
    code = status == :pass ? "pass_stage34_topology_compilation" :
        status == :fail ? "fail_topology_grammar" :
        status == :unsupported ? "unsupported_topology_capability" :
        "unknown_topology_state_evidence"
    audits = Dict{String,Any}(
        "region_node_inventory" => node_ids == package_regions ? "pass" : "fail",
        "required_account_coverage" => isempty(missing_grammar_accounts) ? "pass" : "fail",
        "state_account_coverage" => isempty(missing_state_accounts) ? "pass" : "unknown",
        "stage3_unique_producers" => all(==(1), values(producer_counts)) ? "pass" : "fail",
        "interface_endpoint_and_account_compatibility" =>
            isempty(interface_errors) ? "pass" : "fail",
        "internal_interface_equal_and_opposite_flux" => internal_flux_closed ? "pass" : "fail",
        "stage4_requirement_source" => "explicit_operator_ids",
        "routing_inputs" => ["state_package", "topology_nodes", "interfaces",
            "capability_contracts"])
    reasons = vcat(fail_reasons, unsupported_reasons, unknown_reasons)
    ordered_stage3 = sort!(stage3; by = item -> item["binding_id"])
    ordered_stage4 = sort!(stage4; by = item -> item["binding_id"])
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => state.candidate_binding_hash,
        "state_package_hash" => state.package_hash, "grammar_hash" => grammar.grammar_hash,
        "status" => String(status), "classification_code" => code,
        "stage3_bindings" => ordered_stage3, "stage4_bindings" => ordered_stage4,
        "interface_flux_pairs" => flux_pairs, "audits" => audits, "reasons" => reasons)
    return Stage34TopologyCompilationV1("1.0.0", state.candidate_binding_hash,
        state.package_hash, grammar.grammar_hash, status, code, ordered_stage3,
        ordered_stage4, flux_pairs, audits, reasons, canonical_hash(core))
end

function stage34_topology_compilation_to_dict_v1(item::Stage34TopologyCompilationV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_package_hash" => item.state_package_hash, "grammar_hash" => item.grammar_hash,
        "status" => String(item.status), "classification_code" => item.classification_code,
        "stage3_bindings" => item.stage3_bindings, "stage4_bindings" => item.stage4_bindings,
        "interface_flux_pairs" => item.interface_flux_pairs, "audits" => item.audits,
        "reasons" => item.reasons, "compilation_hash" => item.compilation_hash)
end

function stage34_topology_structural_projection_v1(item::Stage34TopologyCompilationV1)
    return Dict{String,Any}(
        "status" => String(item.status),
        "stage3_accounts" => sort!(String[binding["account_id"]
            for binding in item.stage3_bindings]),
        "stage3_capabilities" => sort!(String[binding["capability_id"]
            for binding in item.stage3_bindings]),
        "stage4_binding_count" => length(item.stage4_bindings),
        "interface_flux_shape" => sort!([(record["account_id"], record["sign"])
            for record in item.interface_flux_pairs]))
end
