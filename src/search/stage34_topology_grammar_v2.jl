const _STAGE34_PORT_KINDS_V2 = Set((:flux, :field_source, :energy_source,
    :boundary, :heat_rejection, :actuator, :sensor, :control))
const _STAGE34_PORT_DIRECTIONS_V2 = Set((:input, :output, :bidirectional))
const _STAGE34_DEPENDENCY_KINDS_V2 = Set((:flux, :field, :energy, :data, :control))
const _STAGE34_OBLIGATION_KINDS_V2 = Set((:conservation, :causal, :validity,
    :boundary, :evidence))
const _STAGE34_REQUIRED_OBLIGATION_KINDS_V2 = copy(_STAGE34_OBLIGATION_KINDS_V2)
const _STAGE34_REQUIRED_PORT_KINDS_V2 = copy(_STAGE34_PORT_KINDS_V2)
const _STAGE34_MUTATION_KINDS_V2 = Set((:add_node, :remove_node, :split_node,
    :reconnect_interface, :set_boundary, :add_port, :remove_port,
    :add_dependency, :remove_dependency, :set_symmetry, :set_time_mode))

"A resource port independent of any device or family label."
struct Stage34PortSpecV2
    port_id::String
    node_id::String
    port_kind::Symbol
    direction::Symbol
    resource_ids::Vector{String}
    capability_id::String
    exclusive_output::Bool
    port_hash::String
end

"A causal/resource edge. Immediate edges must form a DAG; delayed edges close feedback loops."
struct Stage34DependencyV2
    dependency_id::String
    source_port_id::String
    target_port_id::String
    dependency_kind::Symbol
    delayed::Bool
    dependency_hash::String
end

"A required conservation, causal, validity, boundary or evidence obligation."
struct Stage34ObligationV2
    obligation_id::String
    obligation_kind::Symbol
    subject_ids::Vector{String}
    required_capability_ids::Vector{String}
    required_evidence_field_ids::Vector{String}
    claim_boundary::String
    obligation_hash::String
end

struct Stage34TopologyGrammarV2
    schema_version::String
    base_grammar::Stage34TopologyGrammarV1
    symmetry_id::String
    ports::Vector{Stage34PortSpecV2}
    dependencies::Vector{Stage34DependencyV2}
    obligations::Vector{Stage34ObligationV2}
    grammar_hash::String
end

struct Stage34TopologyCompilationV2
    schema_version::String
    candidate_binding_hash::String
    state_package_hash::String
    grammar_hash::String
    status::Symbol
    classification_code::String
    base_compilation::Stage34TopologyCompilationV1
    bound_capability_evidence_hashes::Vector{String}
    port_bindings::Vector{Dict{String,Any}}
    dependency_order::Vector{String}
    obligation_audits::Vector{Dict{String,Any}}
    audits::Dict{String,Any}
    reasons::Vector{String}
    compilation_hash::String
end

struct Stage34TopologyMutationV2
    schema_version::String
    mutation_id::String
    mutation_kind::Symbol
    payload::Dict{String,Any}
    mutation_hash::String
end

function compile_stage34_port_v2(port_id::AbstractString, node_id::AbstractString;
        port_kind::Symbol, direction::Symbol, resource_ids,
        capability_id::AbstractString, exclusive_output::Bool = false)
    all(!isempty, (port_id, node_id, capability_id)) || throw(ArgumentError(
        "Stage34 port identifiers cannot be empty"))
    port_kind in _STAGE34_PORT_KINDS_V2 || throw(ArgumentError(
        "unsupported Stage34 port kind"))
    direction in _STAGE34_PORT_DIRECTIONS_V2 || throw(ArgumentError(
        "unsupported Stage34 port direction"))
    resources = sort!(unique(String.(resource_ids)))
    isempty(resources) && throw(ArgumentError("Stage34 port requires resources"))
    any(isempty, resources) && throw(ArgumentError("Stage34 port resource cannot be empty"))
    exclusive_output && direction == :input && throw(ArgumentError(
        "an input-only port cannot own an exclusive output"))
    core = Dict{String,Any}("port_id" => String(port_id), "node_id" => String(node_id),
        "port_kind" => String(port_kind), "direction" => String(direction),
        "resource_ids" => resources, "capability_id" => String(capability_id),
        "exclusive_output" => exclusive_output)
    return Stage34PortSpecV2(String(port_id), String(node_id), port_kind, direction,
        resources, String(capability_id), exclusive_output, canonical_hash(core))
end

function compile_stage34_dependency_v2(dependency_id::AbstractString,
        source_port_id::AbstractString, target_port_id::AbstractString;
        dependency_kind::Symbol, delayed::Bool = false)
    all(!isempty, (dependency_id, source_port_id, target_port_id)) ||
        throw(ArgumentError("Stage34 dependency identifiers cannot be empty"))
    source_port_id == target_port_id && throw(ArgumentError(
        "Stage34 dependency cannot self-connect"))
    dependency_kind in _STAGE34_DEPENDENCY_KINDS_V2 || throw(ArgumentError(
        "unsupported Stage34 dependency kind"))
    core = Dict{String,Any}("dependency_id" => String(dependency_id),
        "source_port_id" => String(source_port_id),
        "target_port_id" => String(target_port_id),
        "dependency_kind" => String(dependency_kind), "delayed" => delayed)
    return Stage34DependencyV2(String(dependency_id), String(source_port_id),
        String(target_port_id), dependency_kind, delayed, canonical_hash(core))
end

function compile_stage34_obligation_v2(obligation_id::AbstractString;
        obligation_kind::Symbol, subject_ids, required_capability_ids = String[],
        required_evidence_field_ids = String[], claim_boundary::AbstractString)
    isempty(obligation_id) && throw(ArgumentError("Stage34 obligation id cannot be empty"))
    obligation_kind in _STAGE34_OBLIGATION_KINDS_V2 || throw(ArgumentError(
        "unsupported Stage34 obligation kind"))
    subjects = sort!(unique(String.(subject_ids)))
    isempty(subjects) && throw(ArgumentError("Stage34 obligation requires subjects"))
    capabilities = sort!(unique(String.(required_capability_ids)))
    evidence = sort!(unique(String.(required_evidence_field_ids)))
    boundary = String(claim_boundary)
    isempty(boundary) && throw(ArgumentError("Stage34 obligation claim boundary is required"))
    core = Dict{String,Any}("obligation_id" => String(obligation_id),
        "obligation_kind" => String(obligation_kind), "subject_ids" => subjects,
        "required_capability_ids" => capabilities,
        "required_evidence_field_ids" => evidence, "claim_boundary" => boundary)
    return Stage34ObligationV2(String(obligation_id), obligation_kind, subjects,
        capabilities, evidence, boundary, canonical_hash(core))
end

function compile_stage34_topology_grammar_v2(base::Stage34TopologyGrammarV1;
        symmetry_id::AbstractString, ports::Vector{Stage34PortSpecV2},
        dependencies::Vector{Stage34DependencyV2},
        obligations::Vector{Stage34ObligationV2})
    isempty(symmetry_id) && throw(ArgumentError("Stage34 symmetry id cannot be empty"))
    isempty(ports) && throw(ArgumentError("Stage34 v2 requires explicit ports"))
    isempty(obligations) && throw(ArgumentError("Stage34 v2 requires explicit obligations"))
    for values in (getfield.(ports, :port_id), getfield.(dependencies, :dependency_id),
            getfield.(obligations, :obligation_id))
        length(unique(values)) == length(values) || throw(ArgumentError(
            "Stage34 v2 identifiers must be unique within their kind"))
    end
    kinds = Set(getfield.(obligations, :obligation_kind))
    isempty(setdiff(_STAGE34_REQUIRED_OBLIGATION_KINDS_V2, kinds)) ||
        throw(ArgumentError("Stage34 v2 requires every declared obligation kind"))
    ordered_ports = sort!(copy(ports); by = item -> item.port_id)
    ordered_dependencies = sort!(copy(dependencies); by = item -> item.dependency_id)
    ordered_obligations = sort!(copy(obligations); by = item -> item.obligation_id)
    core = Dict{String,Any}("schema_version" => "2.0.0",
        "base_grammar_hash" => base.grammar_hash, "symmetry_id" => String(symmetry_id),
        "port_hashes" => getfield.(ordered_ports, :port_hash),
        "dependency_hashes" => getfield.(ordered_dependencies, :dependency_hash),
        "obligation_hashes" => getfield.(ordered_obligations, :obligation_hash))
    return Stage34TopologyGrammarV2("2.0.0", base, String(symmetry_id), ordered_ports,
        ordered_dependencies, ordered_obligations, canonical_hash(core))
end

"Build the common one-control-volume Stage 3/4 grammar from structural declarations."
function compile_stage34_control_volume_grammar_v2(state::C2CandidateStatePackageV1;
        dimension::AbstractString, boundary_class::AbstractString,
        symmetry_id::AbstractString, required_stability_operator_ids::Vector{String})
    length(state.region_ids) == 1 || throw(ArgumentError(
        "control-volume grammar requires exactly one declared region"))
    region = only(state.region_ids)
    boundary = String(boundary_class)
    boundary in state.boundary_classes || throw(ArgumentError(
        "control-volume boundary must be declared by the state package"))
    accounts = sort!(collect(_STAGE34_ACCOUNT_IDS_V1); by = String)
    node = compile_stage34_topology_node_v1(region; dimension = String(dimension),
        boundary_class = boundary, time_mode = String(state.time_mode),
        account_ids = accounts)
    interface = compile_stage34_topology_interface_v1("external_boundary", region,
        nothing; account_ids = [:particle, :ion_energy, :electron_energy, :species],
        flux_capability_id = "declared_boundary_flux_v1")
    base = compile_stage34_topology_grammar_v1(state.candidate_binding_hash,
        [node], [interface];
        required_stability_operator_ids = required_stability_operator_ids)
    port(kind, direction, resources, capability; exclusive = false) =
        compile_stage34_port_v2(String(kind), region; port_kind = kind,
            direction = direction, resource_ids = resources,
            capability_id = capability, exclusive_output = exclusive)
    ports = Stage34PortSpecV2[
        port(:flux, :bidirectional,
            ["particle", "ion_energy", "electron_energy", "species"],
            "declared_boundary_flux_v1"),
        port(:field_source, :output, ["field_state"], "field_source_port_v2";
            exclusive = true),
        port(:energy_source, :output, ["thermal_energy"], "energy_source_port_v2"),
        port(:boundary, :bidirectional,
            ["particle", "ion_energy", "electron_energy", "species", "field_state"],
            "declared_boundary_flux_v1"),
        port(:heat_rejection, :input, ["thermal_energy"], "heat_rejection_port_v2"),
        port(:actuator, :input, ["actuator_command"], "actuator_port_v2"),
        port(:sensor, :output, ["state_vector"], "sensor_port_v2"),
        port(:control, :bidirectional, ["state_vector", "actuator_command"],
            "control_port_v2")]
    dependencies = Stage34DependencyV2[
        compile_stage34_dependency_v2("field_to_boundary", "field_source", "boundary";
            dependency_kind = :field),
        compile_stage34_dependency_v2("energy_to_heat_rejection", "energy_source",
            "heat_rejection"; dependency_kind = :energy),
        compile_stage34_dependency_v2("sensor_to_control", "sensor", "control";
            dependency_kind = :data),
        compile_stage34_dependency_v2("control_to_actuator", "control", "actuator";
            dependency_kind = :control)]
    obligations = Stage34ObligationV2[
        compile_stage34_obligation_v2("conservation";
            obligation_kind = :conservation, subject_ids = [region, "external_boundary"],
            required_capability_ids = ["regional_particle_continuity_v1",
                "regional_power_ledger_v1", "declared_boundary_flux_v1"],
            required_evidence_field_ids = ["conservation", "interface_flux"],
            claim_boundary = "Declared control-volume balances and paired fluxes only."),
        compile_stage34_obligation_v2("causal"; obligation_kind = :causal,
            subject_ids = ["sensor_to_control", "control_to_actuator"],
            required_capability_ids = ["sensor_port_v2", "control_port_v2",
                "actuator_port_v2"],
            required_evidence_field_ids = ["actuator_fulfillment"],
            claim_boundary = "Declared sensor-control-actuator path only."),
        compile_stage34_obligation_v2("validity"; obligation_kind = :validity,
            subject_ids = [region, "field_source", "energy_source"],
            required_evidence_field_ids = ["validity_domain", "physical_bounds"],
            claim_boundary = "Candidate-bound solved-state validity only."),
        compile_stage34_obligation_v2("boundary"; obligation_kind = :boundary,
            subject_ids = ["external_boundary", "flux", "boundary"],
            required_capability_ids = ["declared_boundary_flux_v1"],
            required_evidence_field_ids = ["interface_flux"],
            claim_boundary = "Explicit boundary and equal-opposite interface flux only."),
        compile_stage34_obligation_v2("evidence"; obligation_kind = :evidence,
            subject_ids = [region], required_evidence_field_ids =
                ["resolution_trend", "jacobian_audit", "independent_residual_audit"],
            claim_boundary = "No claim beyond enumerated numerical evidence.")]
    return compile_stage34_topology_grammar_v2(base; symmetry_id = symmetry_id,
        ports = ports, dependencies = dependencies, obligations = obligations)
end

function _stage34_dependency_order_v2(port_ids::Vector{String},
        dependencies::Vector{Stage34DependencyV2})
    outgoing = Dict(id => String[] for id in port_ids)
    indegree = Dict(id => 0 for id in port_ids)
    for edge in dependencies
        edge.delayed && continue
        haskey(outgoing, edge.source_port_id) && haskey(indegree, edge.target_port_id) ||
            continue
        push!(outgoing[edge.source_port_id], edge.target_port_id)
        indegree[edge.target_port_id] += 1
    end
    ready = sort!(String[id for id in port_ids if indegree[id] == 0])
    order = String[]
    while !isempty(ready)
        id = popfirst!(ready)
        push!(order, id)
        for target in sort!(outgoing[id])
            indegree[target] -= 1
            indegree[target] == 0 && push!(ready, target)
        end
        sort!(ready)
    end
    return order, length(order) == length(port_ids)
end

function _stage34_path_exists_v2(source::String, target::String,
        dependencies::Vector{Stage34DependencyV2}; include_delayed::Bool = true)
    outgoing = Dict{String,Vector{String}}()
    for edge in dependencies
        !include_delayed && edge.delayed && continue
        push!(get!(outgoing, edge.source_port_id, String[]), edge.target_port_id)
    end
    seen = Set([source]); queue = [source]
    while !isempty(queue)
        id = popfirst!(queue)
        id == target && return true
        for next in get(outgoing, id, String[])
            next in seen || (push!(seen, next); push!(queue, next))
        end
    end
    return false
end

function _stage34_v2_subject_inventory(grammar::Stage34TopologyGrammarV2)
    return Set(vcat(getfield.(grammar.base_grammar.nodes, :node_id),
        getfield.(grammar.base_grammar.interfaces, :interface_id),
        getfield.(grammar.ports, :port_id), getfield.(grammar.dependencies, :dependency_id)))
end

function compile_stage34_topology_v2(state::C2CandidateStatePackageV1,
        grammar::Stage34TopologyGrammarV2;
        stability_registry::Vector{StabilityCapabilityContractV2} =
            default_stability_capability_registry_v2(),
        bound_capability_evidence::Vector{Dict{String,Any}} = Dict{String,Any}[])
    external_capability_ids = String[]; external_evidence_hashes = String[]
    for raw in bound_capability_evidence
        item = Dict{String,Any}(String(key) => value for (key, value) in pairs(raw))
        _c2_assert_label_free_v1(item, "bound_topology_capability_evidence")
        String(get(item, "candidate_binding_hash", "")) == state.candidate_binding_hash ||
            throw(ArgumentError("bound topology capability candidate mismatch"))
        String(get(item, "state_result_hash", "")) == state.state_result_hash ||
            throw(ArgumentError("bound topology capability solved-state mismatch"))
        get(item, "candidate_binding_verified", false) === true || throw(ArgumentError(
            "bound topology capability candidate verification is required"))
        get(item, "evidence_authorized", false) === true || throw(ArgumentError(
            "bound topology capability evidence is not authorized"))
        capability_id = String(get(item, "capability_id", ""))
        isempty(capability_id) && throw(ArgumentError(
            "bound topology capability id is required"))
        evidence_hash = _c2_check_hash_v1(String(get(item, "evidence_hash", "")),
            "bound topology capability evidence hash")
        push!(external_capability_ids, capability_id)
        push!(external_evidence_hashes, evidence_hash)
    end
    external_capability_ids = sort!(unique(external_capability_ids))
    external_evidence_hashes = sort!(unique(external_evidence_hashes))
    declared_capabilities = Set(vcat(state.capability_ids, external_capability_ids))
    base = compile_stage34_topology_v1(state, grammar.base_grammar;
        stability_registry = stability_registry,
        additional_capability_ids = external_capability_ids)
    fail = String[]; unsupported = String[]; unknown = String[]
    base.status == :fail && append!(fail, base.reasons)
    base.status == :unsupported && append!(unsupported, base.reasons)
    base.status == :unknown && append!(unknown, base.reasons)
    node_ids = Set(getfield.(grammar.base_grammar.nodes, :node_id))
    port_by_id = Dict(item.port_id => item for item in grammar.ports)
    port_ids = collect(keys(port_by_id))
    port_bindings = Dict{String,Any}[]
    for port in grammar.ports
        port.node_id in node_ids || push!(fail, "port_node_missing:$(port.port_id)")
        port.capability_id in declared_capabilities || push!(unsupported,
            "missing_port_capability:$(port.capability_id)")
        push!(port_bindings, Dict{String,Any}("port_id" => port.port_id,
            "node_id" => port.node_id, "port_kind" => String(port.port_kind),
            "direction" => String(port.direction), "resource_ids" => port.resource_ids,
            "capability_id" => port.capability_id,
            "exclusive_output" => port.exclusive_output))
    end
    port_kinds = Set(getfield.(grammar.ports, :port_kind))
    missing_port_kinds = setdiff(_STAGE34_REQUIRED_PORT_KINDS_V2, port_kinds)
    isempty(missing_port_kinds) || push!(unknown,
        "required_port_kind_missing:$(join(sort!(String.(collect(missing_port_kinds))), ','))")

    for dependency in grammar.dependencies
        haskey(port_by_id, dependency.source_port_id) || push!(fail,
            "dependency_source_missing:$(dependency.dependency_id)")
        haskey(port_by_id, dependency.target_port_id) || push!(fail,
            "dependency_target_missing:$(dependency.dependency_id)")
        if haskey(port_by_id, dependency.source_port_id) &&
                port_by_id[dependency.source_port_id].direction == :input
            push!(fail, "dependency_source_is_input_only:$(dependency.dependency_id)")
        end
        if haskey(port_by_id, dependency.target_port_id) &&
                port_by_id[dependency.target_port_id].direction == :output
            push!(fail, "dependency_target_is_output_only:$(dependency.dependency_id)")
        end
        if haskey(port_by_id, dependency.source_port_id) &&
                haskey(port_by_id, dependency.target_port_id)
            source_resources = Set(port_by_id[dependency.source_port_id].resource_ids)
            target_resources = Set(port_by_id[dependency.target_port_id].resource_ids)
            isempty(intersect(source_resources, target_resources)) && push!(fail,
                "dependency_resource_mismatch:$(dependency.dependency_id)")
        end
    end
    dependency_order, causal_dag = _stage34_dependency_order_v2(port_ids,
        grammar.dependencies)
    causal_dag || push!(fail, "undeclared_immediate_causal_cycle")

    exclusive_groups = Dict{Tuple{String,Symbol,String},Vector{String}}()
    for port in grammar.ports, resource in port.resource_ids
        port.exclusive_output || continue
        push!(get!(exclusive_groups, (port.node_id, port.port_kind, resource), String[]),
            port.port_id)
    end
    for (key, ids) in exclusive_groups
        length(ids) <= 1 || push!(fail,
            "competing_exclusive_output:$(key[1]):$(key[2]):$(key[3])")
    end

    outgoing_ids = Set(getfield.(grammar.dependencies, :source_port_id))
    incoming_ids = Set(getfield.(grammar.dependencies, :target_port_id))
    for port in grammar.ports
        port.port_kind in (:field_source, :energy_source, :sensor) &&
            !(port.port_id in outgoing_ids) && push!(unknown,
                "unconsumed_output_port:$(port.port_id)")
        port.port_kind in (:actuator, :heat_rejection) &&
            !(port.port_id in incoming_ids) && push!(unknown,
                "unfulfilled_input_port:$(port.port_id)")
    end
    sensor_ids = String[item.port_id for item in grammar.ports if item.port_kind == :sensor]
    control_ids = String[item.port_id for item in grammar.ports if item.port_kind == :control]
    actuator_ids = String[item.port_id for item in grammar.ports if item.port_kind == :actuator]
    for actuator in actuator_ids
        controlled = any(control -> _stage34_path_exists_v2(control, actuator,
            grammar.dependencies), control_ids)
        observed = any(sensor -> any(control ->
            _stage34_path_exists_v2(sensor, control, grammar.dependencies) &&
            _stage34_path_exists_v2(control, actuator, grammar.dependencies), control_ids),
            sensor_ids)
        controlled || push!(unknown, "actuator_missing_control_path:$actuator")
        observed || push!(unknown, "actuator_missing_sensor_feedback_path:$actuator")
    end

    for interface in grammar.base_grammar.interfaces
        endpoint_ids = interface.target_node_id === nothing ? [interface.source_node_id] :
            [interface.source_node_id, interface.target_node_id]
        for node_id in endpoint_ids
            matches = [port for port in grammar.ports if port.node_id == node_id &&
                port.capability_id == interface.flux_capability_id &&
                !isempty(intersect(Set(port.resource_ids), Set(String.(interface.account_ids))))]
            isempty(matches) && push!(unknown,
                "interface_missing_port:$(interface.interface_id):$node_id")
        end
        if interface.target_node_id === nothing
            boundary_ports = [port for port in grammar.ports if
                port.node_id == interface.source_node_id &&
                port.port_kind in (:boundary, :heat_rejection, :flux)]
            isempty(boundary_ports) && push!(unknown,
                "external_interface_missing_boundary_port:$(interface.interface_id)")
        end
    end

    evidence_status = Dict(item.field_id => item.status for item in state.evidence_fields)
    inventory = _stage34_v2_subject_inventory(grammar)
    obligation_audits = Dict{String,Any}[]
    for obligation in grammar.obligations
        missing_subjects = sort!(collect(setdiff(Set(obligation.subject_ids), inventory)))
        missing_caps = sort!(collect(setdiff(Set(obligation.required_capability_ids),
            declared_capabilities)))
        field_states = Dict(id => get(evidence_status, id, :unknown)
            for id in obligation.required_evidence_field_ids)
        status = !isempty(missing_subjects) ? :fail : !isempty(missing_caps) ?
            :unsupported : any(==(:fail), values(field_states)) ? :fail :
            all(value -> value in (:complete, :not_applicable), values(field_states)) ?
                :pass : :unknown
        isempty(field_states) && (status = isempty(missing_subjects) &&
            isempty(missing_caps) ? :pass : status)
        status == :fail && push!(fail, "obligation_failed:$(obligation.obligation_id)")
        status == :unsupported && push!(unsupported,
            "obligation_unsupported:$(obligation.obligation_id)")
        status == :unknown && push!(unknown,
            "obligation_evidence_unknown:$(obligation.obligation_id)")
        push!(obligation_audits, Dict{String,Any}(
            "obligation_id" => obligation.obligation_id,
            "obligation_kind" => String(obligation.obligation_kind),
            "status" => String(status), "missing_subject_ids" => missing_subjects,
            "missing_capability_ids" => missing_caps,
            "evidence_field_states" => Dict(id => String(value)
                for (id, value) in field_states),
            "claim_boundary" => obligation.claim_boundary))
    end
    obligation_kinds = Set(getfield.(grammar.obligations, :obligation_kind))
    missing_obligation_kinds = setdiff(_STAGE34_REQUIRED_OBLIGATION_KINDS_V2,
        obligation_kinds)
    isempty(missing_obligation_kinds) || push!(fail, "required_obligation_kind_missing")

    fail = sort!(unique(fail)); unsupported = sort!(unique(unsupported))
    unknown = sort!(unique(unknown))
    status = !isempty(fail) ? :fail : !isempty(unsupported) ? :unsupported :
        !isempty(unknown) ? :unknown : :pass
    code = status == :pass ? "pass_stage34_topology_v2" : status == :fail ?
        "fail_stage34_topology_v2" : status == :unsupported ?
        "unsupported_stage34_capability_v2" : "unknown_stage34_evidence_v2"
    audits = Dict{String,Any}(
        "base_topology_status" => String(base.status),
        "port_endpoint_compatibility" => any(startswith(reason, "port_node_missing")
            for reason in fail) ? "fail" : "pass",
        "immediate_dependency_dag" => causal_dag ? "pass" : "fail",
        "delayed_feedback_edges" => count(item -> item.delayed, grammar.dependencies),
        "exclusive_output_ownership" => any(startswith(reason,
            "competing_exclusive_output") for reason in fail) ? "fail" : "pass",
        "required_port_kinds" => isempty(missing_port_kinds) ? "pass" : "unknown",
        "required_obligation_kinds" => isempty(missing_obligation_kinds) ? "pass" : "fail",
        "routing_inputs" => ["state_package", "region_state_slots", "resource_ports",
            "flux_interfaces", "causal_dependencies", "capability_contracts",
            "evidence_obligations", "dimension", "boundary", "time_mode", "symmetry"],
        "label_routing_used" => false)
    reasons = vcat(fail, unsupported, unknown)
    ordered_bindings = sort!(port_bindings; by = item -> item["port_id"])
    ordered_obligations = sort!(obligation_audits; by = item -> item["obligation_id"])
    core = Dict{String,Any}("schema_version" => "2.0.0",
        "candidate_binding_hash" => state.candidate_binding_hash,
        "state_package_hash" => state.package_hash, "grammar_hash" => grammar.grammar_hash,
        "status" => String(status), "classification_code" => code,
        "base_compilation_hash" => base.compilation_hash,
        "bound_capability_evidence_hashes" => external_evidence_hashes,
        "port_bindings" => ordered_bindings, "dependency_order" => dependency_order,
        "obligation_audits" => ordered_obligations, "audits" => audits,
        "reasons" => reasons)
    return Stage34TopologyCompilationV2("2.0.0", state.candidate_binding_hash,
        state.package_hash, grammar.grammar_hash, status, code, base,
        external_evidence_hashes, ordered_bindings, dependency_order,
        ordered_obligations, audits, reasons, canonical_hash(core))
end

function compile_stage34_topology_mutation_v2(mutation_id::AbstractString,
        mutation_kind::Symbol, payload::AbstractDict)
    isempty(mutation_id) && throw(ArgumentError("topology mutation id cannot be empty"))
    mutation_kind in _STAGE34_MUTATION_KINDS_V2 || throw(ArgumentError(
        "unsupported topology mutation kind"))
    data = Dict{String,Any}(String(key) => value for (key, value) in pairs(payload))
    _c2_assert_label_free_v1(data, "topology_mutation")
    core = Dict{String,Any}("schema_version" => "2.0.0",
        "mutation_id" => String(mutation_id), "mutation_kind" => String(mutation_kind),
        "payload" => data)
    return Stage34TopologyMutationV2("2.0.0", String(mutation_id), mutation_kind,
        data, canonical_hash(core))
end

function _stage34_node_from_payload_v2(item)
    data = Dict{String,Any}(String(key) => value for (key, value) in pairs(item))
    return compile_stage34_topology_node_v1(String(data["node_id"]);
        dimension = String(data["dimension"]),
        boundary_class = String(data["boundary_class"]),
        time_mode = String(data["time_mode"]),
        account_ids = Symbol.(String.(data["account_ids"])))
end

function _stage34_port_from_payload_v2(item)
    data = Dict{String,Any}(String(key) => value for (key, value) in pairs(item))
    return compile_stage34_port_v2(String(data["port_id"]), String(data["node_id"]);
        port_kind = Symbol(String(data["port_kind"])),
        direction = Symbol(String(data["direction"])),
        resource_ids = String.(data["resource_ids"]),
        capability_id = String(data["capability_id"]),
        exclusive_output = Bool(get(data, "exclusive_output", false)))
end

function _stage34_dependency_from_payload_v2(item)
    data = Dict{String,Any}(String(key) => value for (key, value) in pairs(item))
    return compile_stage34_dependency_v2(String(data["dependency_id"]),
        String(data["source_port_id"]), String(data["target_port_id"]);
        dependency_kind = Symbol(String(data["dependency_kind"])),
        delayed = Bool(get(data, "delayed", false)))
end

function apply_stage34_topology_mutation_v2(grammar::Stage34TopologyGrammarV2,
        mutation::Stage34TopologyMutationV2)
    nodes = copy(grammar.base_grammar.nodes); interfaces = copy(grammar.base_grammar.interfaces)
    ports = copy(grammar.ports); dependencies = copy(grammar.dependencies)
    symmetry = grammar.symmetry_id; payload = mutation.payload
    if mutation.mutation_kind == :add_node
        push!(nodes, _stage34_node_from_payload_v2(payload["node"]))
    elseif mutation.mutation_kind == :remove_node
        id = String(payload["node_id"])
        filter!(item -> item.node_id != id, nodes)
        removed_interfaces = Set(item.interface_id for item in interfaces if
            item.source_node_id == id || item.target_node_id == id)
        filter!(item -> !(item.interface_id in removed_interfaces), interfaces)
        removed_ports = Set(item.port_id for item in ports if item.node_id == id)
        filter!(item -> !(item.port_id in removed_ports), ports)
        filter!(item -> !(item.source_port_id in removed_ports ||
            item.target_port_id in removed_ports), dependencies)
    elseif mutation.mutation_kind == :split_node
        id = String(payload["node_id"])
        filter!(item -> item.node_id != id, nodes)
        append!(nodes, [_stage34_node_from_payload_v2(item) for item in payload["new_nodes"]])
        mapping = Dict{String,Any}(String(key) => value for (key, value) in
            pairs(payload["interface_node_map"]))
        interfaces = [begin
            map = haskey(mapping, edge.interface_id) ? Dict{String,Any}(
                String(key) => value for (key, value) in pairs(mapping[edge.interface_id])) :
                Dict{String,Any}()
            source = edge.source_node_id == id ? String(map["source_node_id"]) :
                edge.source_node_id
            target = edge.target_node_id == id ? String(map["target_node_id"]) :
                edge.target_node_id
            compile_stage34_topology_interface_v1(edge.interface_id, source, target;
                account_ids = edge.account_ids,
                flux_capability_id = edge.flux_capability_id)
        end for edge in interfaces]
        port_map = Dict{String,String}(String(key) => String(value) for (key, value) in
            pairs(payload["port_node_map"]))
        ports = [port.node_id == id ? compile_stage34_port_v2(port.port_id,
            port_map[port.port_id]; port_kind = port.port_kind,
            direction = port.direction, resource_ids = port.resource_ids,
            capability_id = port.capability_id,
            exclusive_output = port.exclusive_output) : port for port in ports]
    elseif mutation.mutation_kind == :reconnect_interface
        id = String(payload["interface_id"])
        index = findfirst(item -> item.interface_id == id, interfaces)
        index === nothing && throw(ArgumentError("mutation interface not found"))
        edge = interfaces[index]
        target_value = get(payload, "target_node_id", edge.target_node_id)
        target = target_value === nothing ? nothing : String(target_value)
        interfaces[index] = compile_stage34_topology_interface_v1(id,
            String(get(payload, "source_node_id", edge.source_node_id)), target;
            account_ids = edge.account_ids, flux_capability_id = edge.flux_capability_id)
    elseif mutation.mutation_kind in (:set_boundary, :set_time_mode)
        id = String(payload["node_id"])
        nodes = [node.node_id == id ? compile_stage34_topology_node_v1(node.node_id;
            dimension = node.dimension,
            boundary_class = mutation.mutation_kind == :set_boundary ?
                String(payload["boundary_class"]) : node.boundary_class,
            time_mode = mutation.mutation_kind == :set_time_mode ?
                String(payload["time_mode"]) : node.time_mode,
            account_ids = node.account_ids) : node for node in nodes]
    elseif mutation.mutation_kind == :add_port
        push!(ports, _stage34_port_from_payload_v2(payload["port"]))
    elseif mutation.mutation_kind == :remove_port
        id = String(payload["port_id"]); filter!(item -> item.port_id != id, ports)
        filter!(item -> item.source_port_id != id && item.target_port_id != id, dependencies)
    elseif mutation.mutation_kind == :add_dependency
        push!(dependencies, _stage34_dependency_from_payload_v2(payload["dependency"]))
    elseif mutation.mutation_kind == :remove_dependency
        id = String(payload["dependency_id"])
        filter!(item -> item.dependency_id != id, dependencies)
    elseif mutation.mutation_kind == :set_symmetry
        symmetry = String(payload["symmetry_id"])
    end
    base = compile_stage34_topology_grammar_v1(
        grammar.base_grammar.candidate_binding_hash, nodes, interfaces;
        required_stability_operator_ids = grammar.base_grammar.required_stability_operator_ids)
    return compile_stage34_topology_grammar_v2(base; symmetry_id = symmetry,
        ports = ports, dependencies = dependencies, obligations = grammar.obligations)
end

function compile_stage34_topology_mutation_v2(state::C2CandidateStatePackageV1,
        grammar::Stage34TopologyGrammarV2, mutation::Stage34TopologyMutationV2;
        stability_registry::Vector{StabilityCapabilityContractV2} =
            default_stability_capability_registry_v2())
    mutated = apply_stage34_topology_mutation_v2(grammar, mutation)
    return mutated, compile_stage34_topology_v2(state, mutated;
        stability_registry = stability_registry)
end

function stage34_topology_compilation_to_dict_v2(item::Stage34TopologyCompilationV2)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "state_package_hash" => item.state_package_hash,
        "grammar_hash" => item.grammar_hash, "status" => String(item.status),
        "classification_code" => item.classification_code,
        "base_compilation" => stage34_topology_compilation_to_dict_v1(item.base_compilation),
        "bound_capability_evidence_hashes" => item.bound_capability_evidence_hashes,
        "port_bindings" => item.port_bindings,
        "dependency_order" => item.dependency_order,
        "obligation_audits" => item.obligation_audits, "audits" => item.audits,
        "reasons" => item.reasons, "compilation_hash" => item.compilation_hash)
end

function stage34_topology_structural_projection_v2(item::Stage34TopologyCompilationV2)
    return Dict{String,Any}("status" => String(item.status),
        "base" => stage34_topology_structural_projection_v1(item.base_compilation),
        "port_kinds" => sort!(String[binding["port_kind"] for binding in item.port_bindings]),
        "dependency_node_count" => length(item.dependency_order),
        "obligation_kinds" => sort!(String[audit["obligation_kind"]
            for audit in item.obligation_audits]),
        "label_routing_used" => item.audits["label_routing_used"])
end
