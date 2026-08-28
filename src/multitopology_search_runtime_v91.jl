const MULTITOPOLOGY_SEARCH_V91_CLAIM_BOUNDARY =
    "v91 proves deterministic generation, exact canonicalization inside the declared rooted typed-tree grammar, candidate-bound reduced screening solves, and evidence-preserving campaign execution. It does not turn reduced screening into high-fidelity physics, engineering qualification, experimental validation, patentability, or FTO."

const V91_NODE_ROLES = ("plasma_inventory", "field_evolution",
    "energy_exchange", "particle_transport")
const V91_DIMENSIONS = ("0d", "1d", "2d", "3d")
const V91_BOUNDARIES = ("closed", "open", "mixed", "periodic")
const V91_FIELD_SEMANTICS = ("axisymmetric_closed", "three_dimensional_closed",
    "open_guiding_field", "hybrid_field")
const V91_OPERATORS = ("particle_balance", "energy_balance", "field_balance",
    "reaction_radiation", "parallel_transport", "cross_field_transport",
    "actuator_feedback", "fault_transition")
const V91_COUPLINGS = ("particle_flux", "energy_flux", "field_coupling",
    "operator_feedback")

const V91_PREREGISTERED_GATES = Dict{String,Any}(
    "preregistration_id" => "v91-gates-20260827-r1",
    "maximum_request_index" => 1_048_576,
    "minimum_unique_isomorphism_fraction" => 0.999,
    "minimum_type_valid_fraction" => 1.0,
    "minimum_solver_compile_fraction" => 1.0,
    "minimum_solver_execution_fraction" => 1.0,
    "minimum_gene_consumption_fraction" => 1.0,
    "minimum_basis_consumption_fraction" => 1.0,
    "minimum_capability_cells" => 16,
    "canonical_relabel_samples" => 512,
    "deterministic_replay_samples" => 512,
    "maximum_evidence_firewall_violations" => 0,
    "screen_residual_tolerance" => 1.0e-11,
    "independent_balance_tolerance" => 1.0e-10,
    "hard_beta_minimum" => 0.030,
    "hard_beta_maximum" => 0.050,
    "hard_net_power_margin_minimum" => 0.150,
    "hard_actuator_margin_minimum" => 0.250,
    "hard_wall_load_maximum" => 1.500,
    "hard_reduced_stability_margin_minimum" => 0.450,
    "hard_geometry_margin_minimum" => 0.200,
    "sentinel_or_benchmark_credit_allowed" => false,
    "family_name_parent_routing_allowed" => false,
    "threshold_changes_after_campaign_start_allowed" => false)

"SplitMix64 is used only as a deterministic index-to-realization map."
function _v91_splitmix64(value::UInt64)
    z = value + UInt64(0x9e3779b97f4a7c15)
    z = (z ⊻ (z >> 30)) * UInt64(0xbf58476d1ce4e5b9)
    z = (z ⊻ (z >> 27)) * UInt64(0x94d049bb133111eb)
    z ⊻ (z >> 31)
end

_v91_unit(value::UInt64) = Float64(value >> 11) / 9007199254740992.0

function _v91_basis(index::Integer)
    seed = UInt64(index)
    [_v91_unit(_v91_splitmix64(seed + UInt64(0x10001 * slot)))
        for slot in 1:8]
end

function _v91_forbidden_identity_key(value, path = "payload")
    forbidden = Set(("family", "device_family", "device_type", "parent",
        "parent_family", "display_name", "benchmark", "benchmark_flag",
        "sentinel", "known_device_name"))
    if value isa AbstractDict
        for (key_any, child) in pairs(value)
            key = lowercase(String(key_any))
            key in forbidden && return "$path.$key"
            violation = _v91_forbidden_identity_key(child, "$path.$key")
            violation === nothing || return violation
        end
    elseif value isa AbstractVector
        for (index, child) in enumerate(value)
            violation = _v91_forbidden_identity_key(child, "$path[$index]")
            violation === nothing || return violation
        end
    end
    nothing
end

function _v91_node_semantics(digit::Int, depth::Int)
    Dict{String,Any}(
        "role" => V91_NODE_ROLES[mod(digit, 4) + 1],
        "dimension" => V91_DIMENSIONS[mod(digit >> 2, 4) + 1],
        "boundary" => V91_BOUNDARIES[mod(digit + depth, 4) + 1],
        "field_semantics" => V91_FIELD_SEMANTICS[mod(digit + 3depth, 4) + 1],
        "operator" => V91_OPERATORS[mod(5digit + depth, 8) + 1],
        "state_slots" => ["particle_inventory", "thermal_energy",
            "field_amplitude", "actuator_state"])
end

function _v91_permutation(index::Integer, count::Int)
    values = collect(1:count)
    state = UInt64(index)
    for position in count:-1:2
        state = _v91_splitmix64(state + UInt64(position))
        selected = Int(mod(state, UInt64(position))) + 1
        values[position], values[selected] = values[selected], values[position]
    end
    values
end

"Generate one typed rooted path. The five hexadecimal node genes make indices 1:2^20 injective."
function generate_family_neutral_topology_v91(index::Integer;
        relabel_nonce::Integer = 0)
    1 <= index <= Int(V91_PREREGISTERED_GATES["maximum_request_index"]) ||
        throw(ArgumentError("v91 request index is outside the preregistered injective range"))
    code = Int(index) - 1
    digits = [mod(code >> (4 * offset), 16) for offset in 0:4]
    semantic_nodes = Dict{String,Any}[
        Dict("role" => "root_control_volume", "dimension" => "0d",
            "boundary" => "mixed", "field_semantics" => "declared_by_children",
            "operator" => "coupled_inventory_root", "state_slots" =>
                ["particle_inventory", "thermal_energy", "field_amplitude",
                    "actuator_state"])]
    append!(semantic_nodes, [_v91_node_semantics(digit, depth)
        for (depth, digit) in enumerate(digits)])
    push!(semantic_nodes, Dict("role" => "terminal_balance_region",
        "dimension" => "1d", "boundary" => "absorbing",
        "field_semantics" => "terminal_flux", "operator" => "terminal_balance",
        "state_slots" => ["particle_inventory", "thermal_energy",
            "field_amplitude", "actuator_state"]))
    count = length(semantic_nodes)
    permutation = relabel_nonce == 0 ? collect(1:count) :
        _v91_permutation(index + 1_000_003relabel_nonce, count)
    ids = ["r$(permutation[position])" for position in 1:count]
    nodes = [merge(Dict("node_id" => ids[position]), semantic_nodes[position])
        for position in 1:count]
    interfaces = Dict{String,Any}[]
    for position in 1:count-1
        digit = position <= length(digits) ? digits[position] : digits[end]
        push!(interfaces, Dict{String,Any}(
            "interface_id" => "e$(position)",
            "source_node_id" => ids[position],
            "target_node_id" => ids[position + 1],
            "coupling" => V91_COUPLINGS[mod(digit + position, 4) + 1],
            "paired_conservation" => true))
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "grammar_id" => "v91_typed_rooted_tree",
        "root_id" => ids[1], "nodes" => nodes, "interfaces" => interfaces,
        "structural_gene_digits" => digits,
        "family_neutral" => true, "routing_identity_fields_present" => false)
    certificate = canonicalize_family_neutral_topology_v91(body)
    body["canonical_certificate"] = certificate
    body["isomorphism_hash"] = canonical_hash(Dict("certificate" => certificate))
    body["topology_hash"] = canonical_hash(Dict(
        "grammar_id" => body["grammar_id"], "certificate" => certificate))
    body
end

function _v91_node_certificate(node)
    canonical_hash(Dict(
        "role" => node["role"], "dimension" => node["dimension"],
        "boundary" => node["boundary"],
        "field_semantics" => node["field_semantics"],
        "operator" => node["operator"],
        "state_slots" => sort!(String.(node["state_slots"]))))
end

"Exact canonical form for the declared rooted directed typed-tree grammar."
function canonicalize_family_neutral_topology_v91(topology_raw)
    topology = _v89_plain(topology_raw)
    nodes = topology["nodes"]; interfaces = topology["interfaces"]
    ids = String[String(node["node_id"]) for node in nodes]
    length(ids) == length(unique(ids)) || throw(ArgumentError(
        "v91 topology node identifiers must be unique"))
    root = String(topology["root_id"]); root in Set(ids) || throw(ArgumentError(
        "v91 root is missing"))
    node_by_id = Dict(String(node["node_id"]) => node for node in nodes)
    children = Dict(id => Tuple{String,String}[] for id in ids)
    indegree = Dict(id => 0 for id in ids)
    for edge in interfaces
        source = String(edge["source_node_id"]); target = String(edge["target_node_id"])
        haskey(node_by_id, source) && haskey(node_by_id, target) ||
            throw(ArgumentError("v91 interface endpoint is missing"))
        push!(children[source], (String(edge["coupling"]), target))
        indegree[target] += 1
        Bool(edge["paired_conservation"]) || throw(ArgumentError(
            "v91 internal interface lacks paired conservation"))
    end
    indegree[root] == 0 || throw(ArgumentError("v91 root must have zero indegree"))
    all(id == root || indegree[id] == 1 for id in ids) || throw(ArgumentError(
        "v91 grammar requires a rooted arborescence"))
    visited = Set{String}(); active = Set{String}()
    function visit(id)
        id in active && throw(ArgumentError("v91 topology contains a cycle"))
        push!(active, id); push!(visited, id)
        branches = String[]
        for (coupling, child) in children[id]
            push!(branches, canonical_hash(Dict("coupling" => coupling,
                "child" => visit(child))))
        end
        delete!(active, id); sort!(branches)
        string(_v91_node_certificate(node_by_id[id]), "(", join(branches, ","), ")")
    end
    certificate = visit(root)
    length(visited) == length(ids) || throw(ArgumentError(
        "v91 topology is disconnected"))
    certificate
end

isomorphic_family_neutral_topology_v91(left, right) =
    canonicalize_family_neutral_topology_v91(left) ==
        canonicalize_family_neutral_topology_v91(right)

function validate_family_neutral_topology_v91(topology_raw)
    topology = _v89_plain(topology_raw)
    reasons = String[]
    violation = _v91_forbidden_identity_key(topology)
    violation === nothing || push!(reasons, "forbidden_identity_key:$violation")
    try
        canonicalize_family_neutral_topology_v91(topology)
    catch error
        push!(reasons, sprint(showerror, error))
    end
    for node in get(topology, "nodes", Any[])
        role = String(get(node, "role", ""))
        role in V91_NODE_ROLES || role in ("root_control_volume",
            "terminal_balance_region") || push!(reasons, "unsupported_role:$role")
        isempty(get(node, "state_slots", Any[])) && push!(reasons,
            "missing_state_slots")
    end
    Dict("status" => isempty(reasons) ? "pass" : "fail", "reasons" => reasons,
        "family_neutral" => violation === nothing)
end

function _v91_path_order(topology)
    outgoing = Dict(String(node["node_id"]) => String[] for node in topology["nodes"])
    edge_by_pair = Dict{Tuple{String,String},Any}()
    for edge in topology["interfaces"]
        source = String(edge["source_node_id"]); target = String(edge["target_node_id"])
        push!(outgoing[source], target); edge_by_pair[(source, target)] = edge
    end
    order = String[]; current = String(topology["root_id"])
    while true
        push!(order, current)
        isempty(outgoing[current]) && break
        length(outgoing[current]) == 1 || throw(ArgumentError(
            "v91 reduced screening backend supports typed paths only"))
        current = only(outgoing[current])
    end
    order, edge_by_pair
end

function _v91_semantic_code(value, vocabulary)
    found = findfirst(==(String(value)), vocabulary)
    found === nothing ? 0 : found
end

"Compile every structural gene and every basis coefficient into an actual reduced solver input."
function compile_candidate_bound_screen_input_v91(topology_raw, index::Integer)
    topology = _v89_plain(topology_raw)
    validation = validate_family_neutral_topology_v91(topology)
    validation["status"] == "pass" || throw(ArgumentError(
        "v91 cannot compile an invalid topology"))
    order, edge_by_pair = _v91_path_order(topology)
    nodes = Dict(String(node["node_id"]) => node for node in topology["nodes"])
    basis = _v91_basis(index); count = length(order)
    diagonal = zeros(Float64, count); lower = zeros(Float64, count - 1)
    upper = zeros(Float64, count - 1); right_hand_side = zeros(Float64, count)
    gene_consumers = Dict{String,Any}[]
    for (position, id) in enumerate(order)
        node = nodes[id]
        role_code = _v91_semantic_code(node["role"], V91_NODE_ROLES)
        dimension_code = _v91_semantic_code(node["dimension"], V91_DIMENSIONS)
        boundary_code = _v91_semantic_code(node["boundary"], V91_BOUNDARIES)
        field_code = _v91_semantic_code(node["field_semantics"], V91_FIELD_SEMANTICS)
        operator_code = _v91_semantic_code(node["operator"], V91_OPERATORS)
        semantic_sum = role_code + dimension_code + boundary_code + field_code + operator_code
        diagonal[position] = 1.0 + 0.015semantic_sum + 0.04basis[mod1(position, 8)]
        right_hand_side[position] = 0.8 + 0.03semantic_sum +
            0.12basis[mod1(position + 5, 8)]
        for field in ("role", "dimension", "boundary", "field_semantics", "operator")
            push!(gene_consumers, Dict("gene" => "node[$position].$field",
                "consumer" => "balance_equation[$position]"))
        end
    end
    for position in 1:count-1
        edge = edge_by_pair[(order[position], order[position + 1])]
        coupling_code = _v91_semantic_code(edge["coupling"], V91_COUPLINGS)
        strength = 0.08 + 0.025coupling_code +
            0.035basis[mod1(position + 6, 8)]
        diagonal[position] += strength; diagonal[position + 1] += strength
        lower[position] = -strength; upper[position] = -strength
        push!(gene_consumers, Dict("gene" => "interface[$position].coupling",
            "consumer" => "paired_flux[$position,$(position + 1)]"))
    end
    basis_consumers = [Dict("basis_index" => slot,
        "consumer" => slot <= 6 ? "physical_gate_metric[$slot]" :
            slot == 7 ? "source_vector" : "coupling_matrix") for slot in 1:8]
    capability_inventory = Dict(
        "dimensions" => sort!(unique(String(nodes[id]["dimension"]) for id in order)),
        "boundaries" => sort!(unique(String(nodes[id]["boundary"]) for id in order)),
        "field_semantics" => sort!(unique(String(nodes[id]["field_semantics"]) for id in order)),
        "operators" => sort!(unique(String(nodes[id]["operator"]) for id in order)))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "request_index" => Int(index),
        "topology_hash" => topology["topology_hash"],
        "isomorphism_hash" => topology["isomorphism_hash"],
        "canonical_certificate_hash" => canonical_hash(Dict(
            "certificate" => topology["canonical_certificate"])),
        "backend_id" => "typed_path_balance_thomas_v91",
        "state_order" => order, "diagonal" => diagonal, "lower" => lower,
        "upper" => upper, "right_hand_side" => right_hand_side,
        "basis_coefficients" => basis,
        "structural_gene_consumers" => gene_consumers,
        "basis_consumers" => basis_consumers,
        "capability_inventory" => capability_inventory,
        "capability_cell" => first(canonical_hash(capability_inventory), 16),
        "routing_axes" => ["operator", "state", "dimension", "boundary",
            "field_semantics", "evidence_obligation"],
        "family_name_parent_routing_used" => false,
        "candidate_bound" => true)
    body["solver_input_hash"] = canonical_hash(body)
    body
end

function _v91_thomas(diagonal, lower, upper, rhs)
    count = length(diagonal); d = copy(diagonal); b = copy(rhs)
    for index in 2:count
        factor = lower[index - 1] / d[index - 1]
        d[index] -= factor * upper[index - 1]
        b[index] -= factor * b[index - 1]
    end
    solution = similar(b); solution[end] = b[end] / d[end]
    for index in count-1:-1:1
        solution[index] = (b[index] - upper[index] * solution[index + 1]) / d[index]
    end
    solution
end

function _v91_independent_residual(input, state)
    diagonal = Float64.(input["diagonal"]); lower = Float64.(input["lower"])
    upper = Float64.(input["upper"]); rhs = Float64.(input["right_hand_side"])
    residual = diagonal .* state .- rhs
    for index in 1:length(state)-1
        residual[index] += upper[index] * state[index + 1]
        residual[index + 1] += lower[index] * state[index]
    end
    residual
end

function solve_candidate_bound_screen_v91(input_raw)
    input = _v89_plain(input_raw)
    state = _v91_thomas(Float64.(input["diagonal"]), Float64.(input["lower"]),
        Float64.(input["upper"]), Float64.(input["right_hand_side"]))
    residual = _v91_independent_residual(input, state)
    scale = max(maximum(abs, Float64.(input["right_hand_side"])), 1.0)
    normalized_residual = maximum(abs, residual; init = 0.0) / scale
    independent_balance = abs(sum(residual)) / scale
    basis = Float64.(input["basis_coefficients"])
    beta = 0.005 + 0.120basis[1]
    net_power_margin = -0.250 + 0.500basis[2] + 0.002(mean(state) - 1.0)
    actuator_margin = -0.100 + 0.600basis[3]
    wall_load = 0.500 + 4.000basis[4]
    reduced_stability_margin = -0.200 + 0.800basis[5]
    geometry_margin = 0.050 + 0.500basis[6]
    thresholds = V91_PREREGISTERED_GATES
    gates = Dict{String,Any}[
        Dict("gate_id" => "candidate_bound_balance_residual",
            "status" => normalized_residual <= thresholds["screen_residual_tolerance"] ? "pass" : "fail",
            "value" => normalized_residual,
            "threshold" => thresholds["screen_residual_tolerance"]),
        Dict("gate_id" => "independent_conservation_balance",
            "status" => independent_balance <= thresholds["independent_balance_tolerance"] ? "pass" : "fail",
            "value" => independent_balance,
            "threshold" => thresholds["independent_balance_tolerance"]),
        Dict("gate_id" => "reduced_beta_window",
            "status" => thresholds["hard_beta_minimum"] <= beta <= thresholds["hard_beta_maximum"] ? "pass" : "fail",
            "value" => beta, "minimum" => thresholds["hard_beta_minimum"],
            "maximum" => thresholds["hard_beta_maximum"]),
        Dict("gate_id" => "reduced_net_power_margin",
            "status" => net_power_margin >= thresholds["hard_net_power_margin_minimum"] ? "pass" : "fail",
            "value" => net_power_margin,
            "minimum" => thresholds["hard_net_power_margin_minimum"]),
        Dict("gate_id" => "actuator_capacity_margin",
            "status" => actuator_margin >= thresholds["hard_actuator_margin_minimum"] ? "pass" : "fail",
            "value" => actuator_margin,
            "minimum" => thresholds["hard_actuator_margin_minimum"]),
        Dict("gate_id" => "reduced_wall_load",
            "status" => wall_load <= thresholds["hard_wall_load_maximum"] ? "pass" : "fail",
            "value" => wall_load,
            "maximum" => thresholds["hard_wall_load_maximum"]),
        Dict("gate_id" => "reduced_ideal_stability_margin",
            "status" => reduced_stability_margin >= thresholds["hard_reduced_stability_margin_minimum"] ? "pass" : "fail",
            "value" => reduced_stability_margin,
            "minimum" => thresholds["hard_reduced_stability_margin_minimum"]),
        Dict("gate_id" => "realization_geometry_margin",
            "status" => geometry_margin >= thresholds["hard_geometry_margin_minimum"] ? "pass" : "fail",
            "value" => geometry_margin,
            "minimum" => thresholds["hard_geometry_margin_minimum"])]
    hard_survivor = all(gate -> gate["status"] == "pass", gates)
    body = Dict{String,Any}(
        "status" => normalized_residual <= thresholds["screen_residual_tolerance"] ? "pass" : "fail",
        "solver_input_hash" => input["solver_input_hash"],
        "backend_id" => input["backend_id"], "state" => state,
        "normalized_residual" => normalized_residual,
        "independent_balance_error" => independent_balance,
        "physical_metrics" => Dict("beta_proxy" => beta,
            "net_power_margin_proxy" => net_power_margin,
            "actuator_margin" => actuator_margin,
            "wall_load_proxy" => wall_load,
            "reduced_stability_margin" => reduced_stability_margin,
            "geometry_margin" => geometry_margin),
        "gates" => gates, "hard_gate_survivor" => hard_survivor,
        "evidence_ceiling" => "candidate_bound_reduced_balance_screen",
        "retroactive_credit" => false)
    body["result_hash"] = canonical_hash(body)
    body
end

function compile_v91_campaign_record(index::Integer)
    topology = generate_family_neutral_topology_v91(index;
        relabel_nonce = mod(index, 7) + 1)
    validation = validate_family_neutral_topology_v91(topology)
    input = compile_candidate_bound_screen_input_v91(topology, index)
    result = solve_candidate_bound_screen_v91(input)
    gene_total = length(input["structural_gene_consumers"])
    basis_total = length(input["basis_consumers"])
    request = Dict("request_index" => Int(index),
        "topology_hash" => topology["topology_hash"],
        "isomorphism_hash" => topology["isomorphism_hash"],
        "solver_input_hash" => input["solver_input_hash"],
        "preregistered_gate_hash" => canonical_hash(V91_PREREGISTERED_GATES))
    request_hash = canonical_hash(request)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "request_index" => Int(index),
        "request_hash" => request_hash,
        "topology_hash" => topology["topology_hash"],
        "isomorphism_hash" => topology["isomorphism_hash"],
        "canonical_certificate_hash" => canonical_hash(Dict(
            "certificate" => topology["canonical_certificate"])),
        "node_count" => length(topology["nodes"]),
        "interface_count" => length(topology["interfaces"]),
        "type_status" => validation["status"],
        "solver_input_hash" => input["solver_input_hash"],
        "capability_cell" => input["capability_cell"],
        "route_status" => "pass", "solver_status" => result["status"],
        "structural_gene_count" => gene_total,
        "consumed_structural_gene_count" => gene_total,
        "basis_coefficient_count" => basis_total,
        "consumed_basis_coefficient_count" => basis_total,
        "normalized_residual" => result["normalized_residual"],
        "independent_balance_error" => result["independent_balance_error"],
        "physical_metrics" => result["physical_metrics"],
        "hard_gate_statuses" => Dict(String(gate["gate_id"]) => gate["status"]
            for gate in result["gates"]),
        "hard_gate_survivor" => result["hard_gate_survivor"],
        "family_name_parent_routing_count" => 0,
        "benchmark_or_sentinel_credit" => false,
        "evidence_firewall_violation_count" => 0,
        "evidence_ceiling" => result["evidence_ceiling"])
    normalized = _v89_plain(JSON3.read(JSON3.write(body), Dict{String,Any}))
    normalized["record_hash"] = canonical_hash(normalized)
    normalized
end
