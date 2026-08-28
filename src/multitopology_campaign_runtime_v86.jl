const MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY =
    "v86 provides label-free multi-topology scheduling, content-addressed solver-input reuse, resumable shards, progressive Poincare admission, an actual finite-filament open-field end-loss executor, and a candidate-bound low-beta paraxial scalar-pressure flux-tube executor. Acquisition and basis promotion never grant retroactive feasibility credit. The open-field finite-pressure executor is a bounded screening equilibrium, not anisotropic, kinetic, ambipolar, nonlinear-stability, or complete open-field equilibrium evidence; open-field candidates therefore remain outside minimality. No full-engineering, VVUQ, net-power, originality, or build-ready claim is made."

const V86_CACHE_STAGES_V1 = (
    "finite_filament_field", "poincare_32", "poincare_64", "poincare_128",
    "open_field_end_loss", "open_field_finite_pressure_capability",
    "finite_pressure_equilibrium",
    "sampled_ideal_mhd_stability")

_v86_json_plain(value::AbstractDict) = _stage3_plain_v1(JSON3.read(
    canonical_json(value), Dict{String,Any}))

struct TopologyCapabilitySignatureV1
    schema_version::String
    structure_hash::String
    numerical_ir_hash::String
    spatial_dimensions::Vector{Int}
    time_semantics::Vector{String}
    boundary_kinds::Vector{String}
    state_kinds::Vector{String}
    port_kinds::Vector{String}
    capability_ids::Vector{String}
    geometry_class::String
    required_hard_gate_chain::Vector{String}
    minimality_eligible::Bool
    exclusion_reasons::Vector{String}
    capability_cell_hash::String
    budget_stratum_hash::String
    comparison_scope_hash::String
    capability_signature_hash::String
end

struct CandidateSolveRequestV86
    schema_version::String
    request_index::Int
    structure_seed::Int
    topology_hash::String
    structure_hash::String
    compilation_hash::String
    grammar_hash::String
    physical_variant::Int
    operating_variant::Int
    control_variant::Int
    route::String
    basis_level::Int
    base_coil_count::Int
    basis_override::Union{Nothing,Dict{String,Any}}
    initial_design::CandidateJointDesignV1
    capability_signature::TopologyCapabilitySignatureV1
    request_hash::String
end

function topology_capability_signature_to_dict_v1(item::TopologyCapabilitySignatureV1)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "structure_hash" => item.structure_hash,
        "numerical_ir_hash" => item.numerical_ir_hash,
        "spatial_dimensions" => item.spatial_dimensions,
        "time_semantics" => item.time_semantics,
        "boundary_kinds" => item.boundary_kinds,
        "state_kinds" => item.state_kinds,
        "port_kinds" => item.port_kinds,
        "capability_ids" => item.capability_ids,
        "geometry_class" => item.geometry_class,
        "required_hard_gate_chain" => item.required_hard_gate_chain,
        "minimality_eligible" => item.minimality_eligible,
        "exclusion_reasons" => item.exclusion_reasons,
        "capability_cell_hash" => item.capability_cell_hash,
        "budget_stratum_hash" => item.budget_stratum_hash,
        "comparison_scope_hash" => item.comparison_scope_hash,
        "capability_signature_hash" => item.capability_signature_hash)
end

function _v86_restore_capability_signature_v1(raw)
    item = _stage3_plain_v1(raw)
    claimed_hash = String(item["capability_signature_hash"])
    body = deepcopy(item)
    delete!(body, "capability_signature_hash")
    # This routing audit bit is part of the signed body but intentionally is not
    # stored as a struct field in the v1 wire representation.
    body["device_family_routing_used"] = false
    canonical_hash(body) == claimed_hash || throw(ArgumentError(
        "v86 serialized capability signature hash mismatch"))
    return TopologyCapabilitySignatureV1(
        String(item["schema_version"]), String(item["structure_hash"]),
        String(item["numerical_ir_hash"]), Int.(item["spatial_dimensions"]),
        String.(item["time_semantics"]), String.(item["boundary_kinds"]),
        String.(item["state_kinds"]), String.(item["port_kinds"]),
        String.(item["capability_ids"]), String(item["geometry_class"]),
        String.(item["required_hard_gate_chain"]),
        Bool(item["minimality_eligible"]), String.(item["exclusion_reasons"]),
        String(item["capability_cell_hash"]),
        String(item["budget_stratum_hash"]),
        String(item["comparison_scope_hash"]), claimed_hash)
end

function compile_topology_capability_signature_v1(topology, compilation,
        binding)
    structure_hash = graph_isomorphism_hash_v69(topology)
    ir = compile_stage3_physics_ir_v1(topology, compilation, binding)
    dimensions = sort!(unique(region.spatial_dimension for region in ir.regions))
    times = sort!(unique(String(region.time_semantics) for region in ir.regions))
    boundaries = sort!(unique(String(region.boundary_kind) for region in ir.regions))
    states = sort!(unique(String(state.state_kind) for state in ir.states))
    ports = sort!(unique(String(port["port_kind"]) for port in topology.ports))
    capabilities = sort!(unique(String(port["capability_id"]) for port in
        topology.ports))
    geometry = String(binding["geometry_class"])
    chain = if geometry == "toroidal_volume_v1"
        ["finite_filament_field", "poincare_32", "poincare_64",
            "poincare_128", "finite_pressure_equilibrium",
            "sampled_ideal_mhd_stability"]
    else
        ["finite_filament_field", "open_field_end_loss",
            "open_field_finite_pressure_capability"]
    end
    exclusions = String[]
    if geometry == "linear_volume_v1"
        append!(exclusions, [
            "open_field_paraxial_finite_pressure_screen_not_complete_equilibrium",
            "missing_candidate_bound_open_field_kinetic_end_closure",
            "missing_candidate_bound_open_field_stability_capability"])
    end
    !isempty(ir.reasons) && append!(exclusions,
        ["stage3_ir:$reason" for reason in ir.reasons])
    eligible = isempty(exclusions)
    cell_body = Dict{String,Any}(
        "spatial_dimensions" => dimensions, "time_semantics" => times,
        "boundary_kinds" => boundaries, "state_kinds" => states,
        "port_kinds" => ports, "capability_ids" => capabilities,
        "geometry_class" => geometry, "required_hard_gate_chain" => chain,
        "minimality_eligible" => eligible,
        "exclusion_reasons" => sort!(unique(exclusions)),
        "device_family_routing_used" => false)
    cell_hash = canonical_hash(cell_body)
    budget_body = Dict{String,Any}(
        "scope_kind" => "capability_budget_stratum_v1",
        "geometry_class" => geometry,
        "required_hard_gate_chain" => chain,
        "minimality_eligible" => eligible,
        "executor_validity_class" => geometry == "toroidal_volume_v1" ?
            "closed_field_progressive_poincare_desc_v1" :
            "open_field_end_loss_and_paraxial_finite_pressure_v1",
        "device_family_routing_used" => false)
    comparison_body = Dict{String,Any}(
        "scope_kind" => "candidate_comparison_scope_v1",
        "geometry_class" => geometry,
        "required_hard_gate_chain" => chain,
        "minimality_eligible" => eligible,
        "evidence_depth" => eligible ? "complete_declared_v86_hard_chain" :
            "excluded_incomplete_declared_v86_hard_chain",
        "complexity_protocol" => "DeviceComplexityManifestV1",
        "device_family_routing_used" => false)
    budget_hash = canonical_hash(budget_body)
    comparison_hash = canonical_hash(comparison_body)
    body = merge(Dict{String,Any}(
        "schema_version" => "1.1.0", "structure_hash" => structure_hash,
        "numerical_ir_hash" => ir.numerical_ir_hash,
        "capability_cell_hash" => cell_hash,
        "budget_stratum_hash" => budget_hash,
        "comparison_scope_hash" => comparison_hash), cell_body)
    return TopologyCapabilitySignatureV1("1.1.0", structure_hash,
        ir.numerical_ir_hash, dimensions, times, boundaries, states, ports,
        capabilities, geometry, chain, eligible, sort!(unique(exclusions)),
        cell_hash, budget_hash, comparison_hash, canonical_hash(body))
end

const V86_STRUCTURAL_TRANSITIONS_V1 = Set([
    "prescribed_electrostatic_end_barrier_pair_v1",
    "declared_internal_current_ring_flux_core_v1"])

function compile_structural_transition_grammar_v86(structure_hash,
        transition_id)
    transition = String(transition_id)
    transition in V86_STRUCTURAL_TRANSITIONS_V1 || throw(ArgumentError(
        "unsupported v86 structural transition $transition"))
    base = default_candidate_realization_grammar_v2(String(structure_hash))
    rules = copy(base.component_rules)
    if transition == "prescribed_electrostatic_end_barrier_pair_v1"
        push!(rules, RealizationComponentRuleV2(
            "prescribed_electrostatic_end_barrier_pair", true, 1, 1,
            [:actuator_timing]))
        routes = ["open/mixed"]
    else
        push!(rules, RealizationComponentRuleV2(
            "declared_internal_current_ring_flux_core", true, 1, 1,
            [:current_potential]))
        routes = ["closed/mixed"]
    end
    grammar = compile_candidate_realization_grammar_v2(
        structure_hash = String(structure_hash),
        topology_contract_id = "graph_native_topology_with_$transition",
        component_rules = rules, allowed_routes = routes)
    return compile_joint_optimization_grammar_v1(grammar)
end

function _v86_basis_override(structure_hash, physical_variant, basis_level,
        design::Union{Nothing,CandidateJointDesignV1} = nothing)
    level = Int(basis_level)
    0 <= level <= 3 || throw(ArgumentError(
        "v86 basis level must be 0, 1, 2, or 3"))
    level == 0 && return nothing, 16
    order = 2 + level
    design === nothing && throw(ArgumentError(
        "v86 promoted basis requires its low-order design"))
    fourier = copy(design.coil_fourier_coefficients)
    bspline = copy(design.coil_bspline_control_points)
    potential = copy(design.current_potential_coefficients)
    for incremental_level in 1:level
        rng = _v84_stream_rng(String(structure_hash),
            "v86_basis_increment_$incremental_level", Int(physical_variant))
        append!(fourier, [0.055 / incremental_level * randn(rng) for _ in 1:2])
        append!(bspline, [0.045 / incremental_level * randn(rng) for _ in 1:2])
        append!(potential, [0.040 / incremental_level * randn(rng) for _ in 1:2])
    end
    override = Dict{String,Any}(
        "basis_level" => level, "fourier_order" => order,
        "bspline_control_count" => length(bspline),
        "current_potential_order" => order,
        "coil_fourier_coefficients" => fourier,
        "coil_bspline_control_points" => bspline,
        "current_potential_coefficients" => potential,
        "feedback_role" => "next_request_sampling_only",
        "retroactive_feasibility_credit" => false)
    if level == 3
        override["winding_model"] =
            "winding_surface_current_potential_level_set_filaments_v7"
        override["contour_current_scale"] = 0.35
        override["contour_count"] = 16 + 4level
        override["dominant_poloidal_mode_m"] = 1
        override["dominant_toroidal_mode_n"] = 1
        override["supply_group_count"] = 2
        override["grammar_transition"] =
            "helical_level_sets_to_poloidal_modular_2d_current_potential_contours_v3"
    end
    return override, 16 + 4level
end

function _v86_request_body(item::CandidateSolveRequestV86)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "request_index" => item.request_index,
        "structure_seed" => item.structure_seed,
        "topology_hash" => item.topology_hash,
        "structure_hash" => item.structure_hash,
        "compilation_hash" => item.compilation_hash,
        "grammar_hash" => item.grammar_hash,
        "physical_variant" => item.physical_variant,
        "operating_variant" => item.operating_variant,
        "control_variant" => item.control_variant, "route" => item.route,
        "basis_level" => item.basis_level,
        "base_coil_count" => item.base_coil_count,
        "basis_override" => item.basis_override,
        "initial_design" => candidate_joint_design_to_dict_v1(item.initial_design),
        "capability_signature" =>
            topology_capability_signature_to_dict_v1(item.capability_signature))
end

function candidate_solve_request_to_dict_v86(item::CandidateSolveRequestV86)
    body = _v86_request_body(item); body["request_hash"] = item.request_hash
    return body
end

function _v86_joint_design_from_dict(raw, grammar::JointOptimizationGrammarV1)
    item = _stage3_plain_v1(raw)
    design = compile_candidate_joint_design_v1(grammar;
        route = String(item["route"]),
        coil_fourier_coefficients = item["coil_fourier_coefficients"],
        coil_bspline_control_points = item["coil_bspline_control_points"],
        current_potential_coefficients = item[
            "current_potential_coefficients"],
        plasma_boundary_coefficients = item["plasma_boundary_coefficients"],
        actuator_timing_coefficients = item["actuator_timing_coefficients"],
        controller_modal_coefficients = item["controller_modal_coefficients"],
        field_current_a = item["field_current_a"],
        density_scale = item["density_scale"],
        temperature_scale = item["temperature_scale"])
    haskey(item, "design_hash") && design.design_hash != String(item[
        "design_hash"]) && throw(ArgumentError(
        "v86 serialized joint design hash mismatch"))
    return design
end

function compile_candidate_solve_request_v86(request_index, structure_seed,
        topology, compilation, grammar, physical_variant, operating_variant,
        control_variant, route; basis_level = 0,
        capability_signature::Union{Nothing,TopologyCapabilitySignatureV1} = nothing,
        initial_design_override::Union{Nothing,CandidateJointDesignV1} = nothing,
        serialized_basis_override = nothing, parent_basis_override = nothing)
    compilation.status == :pass || throw(ArgumentError(
        "v86 requests require a compile-pass topology"))
    design = initial_design_override === nothing ?
        seed_candidate_joint_design_v1(grammar;
            physical_variant = physical_variant,
            operating_variant = operating_variant,
            control_variant = control_variant, route = String(route)) :
        initial_design_override
    design.structure_hash == grammar.base_grammar.structure_hash ||
        throw(ArgumentError("v86 initial-design override structure mismatch"))
    design.grammar_hash == grammar.grammar_hash || throw(ArgumentError(
        "v86 initial-design override grammar mismatch"))
    design.route == String(route) || throw(ArgumentError(
        "v86 initial-design override route mismatch"))
    generated_override, coil_count = _v86_basis_override(
        grammar.base_grammar.structure_hash,
        physical_variant, basis_level, design)
    serialized_basis_override !== nothing && parent_basis_override !== nothing &&
        throw(ArgumentError(
            "v86 cannot restore and promote a basis override simultaneously"))
    override = if serialized_basis_override !== nothing
        restored = _stage3_plain_v1(serialized_basis_override)
        Int(get(restored, "basis_level", basis_level)) == Int(basis_level) ||
            throw(ArgumentError("v86 serialized basis level mismatch"))
        restored
    elseif parent_basis_override !== nothing
        generated_override === nothing && throw(ArgumentError(
            "v86 parent basis override requires a promoted nonzero level"))
        promoted = deepcopy(generated_override)
        parent = _stage3_plain_v1(parent_basis_override)
        for key in ("coil_fourier_coefficients",
                "coil_bspline_control_points",
                "current_potential_coefficients")
            haskey(parent, key) || continue
            parent_values = Float64.(parent[key])
            promoted_values = Float64.(promoted[key])
            length(parent_values) <= length(promoted_values) || throw(
                ArgumentError("v86 promoted $key basis is shorter than its parent"))
            promoted_values[1:length(parent_values)] .= parent_values
            promoted[key] = promoted_values
        end
        promoted["parent_optimized_basis_override_hash"] = canonical_hash(parent)
        promoted
    else
        generated_override
    end
    signature = if capability_signature === nothing
        compiled = compile_joint_physical_realization_v85(topology, compilation,
            design; basis_override = override, base_coil_count = coil_count)
        compile_topology_capability_signature_v1(topology, compilation,
            compiled.binding)
    else
        capability_signature.structure_hash == grammar.base_grammar.structure_hash ||
            throw(ArgumentError("v86 reused capability signature structure mismatch"))
        capability_signature
    end
    provisional = CandidateSolveRequestV86("1.0.0", Int(request_index),
        Int(structure_seed), topology.topology_hash,
        grammar.base_grammar.structure_hash, compilation.compilation_hash,
        grammar.grammar_hash, Int(physical_variant), Int(operating_variant),
        Int(control_variant), String(route), Int(basis_level), coil_count,
        override, design, signature, "")
    return CandidateSolveRequestV86(provisional.schema_version,
        provisional.request_index, provisional.structure_seed,
        provisional.topology_hash, provisional.structure_hash,
        provisional.compilation_hash, provisional.grammar_hash,
        provisional.physical_variant, provisional.operating_variant,
        provisional.control_variant, provisional.route, provisional.basis_level,
        provisional.base_coil_count, provisional.basis_override,
        provisional.initial_design, provisional.capability_signature,
        canonical_hash(_v86_request_body(provisional)))
end

function _v86_restore_request(raw)
    item = _stage3_plain_v1(raw)
    seed = Int(item["structure_seed"])
    topology = generate_graph_native_topology_v69(seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    structure_hash = graph_isomorphism_hash_v69(topology)
    structure_hash == String(item["structure_hash"]) || throw(ArgumentError(
        "v86 restored topology structure hash mismatch"))
    policy = get(item, "representative_policy", nothing)
    override = get(item, "basis_override", nothing)
    transition = override === nothing ? "" : String(get(override,
        "grammar_transition", ""))
    grammar = if transition in V86_STRUCTURAL_TRANSITIONS_V1
        compiled_grammar = compile_structural_transition_grammar_v86(
            structure_hash, transition)
        policy === nothing ? compiled_grammar :
            compile_joint_optimization_grammar_v1(
                compiled_grammar.base_grammar; representative_policy = policy)
    else
        compile_joint_optimization_grammar_v1(
            default_candidate_realization_grammar_v2(structure_hash);
            representative_policy = policy)
    end
    serialized_design = _v86_joint_design_from_dict(item["initial_design"], grammar)
    serialized_signature = _v86_restore_capability_signature_v1(item[
        "capability_signature"])
    serialized_signature.structure_hash == structure_hash || throw(ArgumentError(
        "v86 restored capability signature structure mismatch"))
    request = compile_candidate_solve_request_v86(Int(item["request_index"]),
        seed, topology, compilation, grammar, Int(item["physical_variant"]),
        Int(item["operating_variant"]), Int(item["control_variant"]),
        String(item["route"]); basis_level = Int(item["basis_level"]),
        initial_design_override = serialized_design,
        serialized_basis_override = get(item, "basis_override", nothing),
        capability_signature = serialized_signature)
    request.request_hash == String(item["request_hash"]) || throw(ArgumentError(
        "v86 restored request hash mismatch"))
    return (request = request, topology = topology, compilation = compilation,
        grammar = grammar)
end

function compile_multitopology_campaign_v86(; structure_seeds,
        physical_variants, operating_variants, control_variants,
        routes = ["closed/mixed", "open/mixed"], basis_levels = [0])
    seeds = sort!(unique(Int.(collect(structure_seeds))))
    physical = sort!(unique(Int.(collect(physical_variants))))
    operating = sort!(unique(Int.(collect(operating_variants))))
    control = sort!(unique(Int.(collect(control_variants))))
    route_values = sort!(unique(String.(collect(routes))))
    levels = sort!(unique(Int.(collect(basis_levels))))
    isempty(seeds) && throw(ArgumentError("v86 structure_seeds cannot be empty"))
    isempty(physical) && throw(ArgumentError("v86 physical_variants cannot be empty"))
    isempty(operating) && throw(ArgumentError("v86 operating_variants cannot be empty"))
    isempty(control) && throw(ArgumentError("v86 control_variants cannot be empty"))
    isempty(route_values) && throw(ArgumentError("v86 routes cannot be empty"))
    isempty(levels) && throw(ArgumentError("v86 basis_levels cannot be empty"))
    all(>(0), vcat(seeds, physical, operating, control)) || throw(ArgumentError(
        "v86 structure and variant indices must be positive"))
    all(level -> 0 <= level <= 2, levels) || throw(ArgumentError(
        "v86 basis levels must be 0..2"))
    topology_rows = Dict{String,Any}[]; requests = Dict{String,Any}[]
    seen_structures = Dict{String,Int}(); request_index = 0
    for seed in seeds
        topology = generate_graph_native_topology_v69(seed)
        compilation = compile_graph_native_topology_candidate_v69(topology)
        structure_hash = graph_isomorphism_hash_v69(topology)
        duplicate_of = get(seen_structures, structure_hash, nothing)
        if duplicate_of === nothing
            seen_structures[structure_hash] = seed
        end
        push!(topology_rows, Dict{String,Any}(
            "structure_seed" => seed, "topology_hash" => topology.topology_hash,
            "structure_hash" => structure_hash,
            "compilation_status" => String(compilation.status),
            "classification_code" => compilation.classification_code,
            "isomorphic_duplicate_of_seed" => duplicate_of))
        compilation.status == :pass && duplicate_of === nothing || continue
        grammar = compile_joint_optimization_grammar_v1(
            default_candidate_realization_grammar_v2(structure_hash))
        probe_design = seed_candidate_joint_design_v1(grammar;
            physical_variant = first(physical), operating_variant = first(operating),
            control_variant = first(control), route = first(route_values))
        probe_compiled = compile_joint_physical_realization_v85(topology, compilation,
            probe_design)
        signature = compile_topology_capability_signature_v1(topology, compilation,
            probe_compiled.binding)
        for p in physical, o in operating, c in control, route in route_values,
                level in levels
            route in grammar.base_grammar.allowed_routes || continue
            request_index += 1
            request = compile_candidate_solve_request_v86(request_index, seed,
                topology, compilation, grammar, p, o, c, route;
                basis_level = level, capability_signature = signature)
            push!(requests, candidate_solve_request_to_dict_v86(request))
        end
    end
    groups = Dict{String,Vector{Dict{String,Any}}}()
    stratum_cells = Dict{String,Set{String}}()
    for request in requests
        cell = String(request["capability_signature"]["capability_cell_hash"])
        push!(get!(groups, cell, Dict{String,Any}[]), request)
        stratum = String(request["capability_signature"]["budget_stratum_hash"])
        push!(get!(stratum_cells, stratum, Set{String}()), cell)
    end
    for rows in values(groups)
        sort!(rows; by = row -> String(row["request_hash"]))
    end
    stratum_queues = Dict{String,Vector{Int}}()
    for (stratum, cell_set) in stratum_cells
        queue = Int[]; depth = 1
        while true
            added = false
            for cell in sort!(collect(cell_set))
                depth <= length(groups[cell]) || continue
                push!(queue, Int(groups[cell][depth]["request_index"])); added = true
            end
            added || break
            depth += 1
        end
        stratum_queues[stratum] = queue
    end
    schedule = Int[]; depth = 1
    while length(schedule) < length(requests)
        added = false
        for stratum in sort!(collect(keys(stratum_queues)))
            depth <= length(stratum_queues[stratum]) || continue
            push!(schedule, stratum_queues[stratum][depth]); added = true
        end
        added || break
        depth += 1
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "structure_seeds" => seeds,
        "physical_variants" => physical, "operating_variants" => operating,
        "control_variants" => control, "routes" => route_values,
        "basis_levels" => levels,
        "raw_topology_count" => length(topology_rows),
        "unique_structure_count" => length(seen_structures),
        "compile_pass_unique_structure_count" => count(row -> row[
            "compilation_status"] == "pass" && row[
            "isomorphic_duplicate_of_seed"] === nothing, topology_rows),
        "request_count" => length(requests),
        "topologies" => topology_rows,
        "request_hashes" => [request["request_hash"] for request in requests],
        "capability_cell_count" => length(groups),
        "budget_stratum_count" => length(stratum_queues),
        "fair_schedule_request_indices" => schedule,
        "fairness_policy" => "budget_stratum_then_capability_cell_round_robin_v2",
        "seed_streams_independent" => true,
        "isomorphism_dedup_before_variants" => true)
    campaign = Dict{String,Any}("schema_version" => "1.0.0",
        "specification" => body, "requests" => requests,
        "campaign_hash" => canonical_hash(body),
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
    return campaign
end

function compile_structural_transition_campaign_v86(; structure_seeds,
        physical_variants, operating_variants, control_variants,
        transition_id)
    transition = String(transition_id)
    transition in V86_STRUCTURAL_TRANSITIONS_V1 || throw(ArgumentError(
        "unsupported v86 structural transition $transition"))
    target_geometry = transition ==
        "prescribed_electrostatic_end_barrier_pair_v1" ?
        "linear_volume_v1" : "toroidal_volume_v1"
    route = target_geometry == "linear_volume_v1" ? "open/mixed" :
        "closed/mixed"
    seeds = sort!(unique(Int.(collect(structure_seeds))))
    physical = sort!(unique(Int.(collect(physical_variants))))
    operating = sort!(unique(Int.(collect(operating_variants))))
    control = sort!(unique(Int.(collect(control_variants))))
    all(!isempty, (seeds, physical, operating, control)) || throw(ArgumentError(
        "v86 structural-transition campaign axes cannot be empty"))
    all(>(0), vcat(seeds, physical, operating, control)) || throw(ArgumentError(
        "v86 structural-transition indices must be positive"))
    topology_rows = Dict{String,Any}[]; requests = Dict{String,Any}[]
    seen_structures = Dict{String,Int}(); request_index = 0
    for seed in seeds
        topology = generate_graph_native_topology_v69(seed)
        compilation = compile_graph_native_topology_candidate_v69(topology)
        structure_hash = graph_isomorphism_hash_v69(topology)
        duplicate_of = get(seen_structures, structure_hash, nothing)
        if duplicate_of === nothing; seen_structures[structure_hash] = seed; end
        row = Dict{String,Any}(
            "structure_seed" => seed, "topology_hash" => topology.topology_hash,
            "structure_hash" => structure_hash,
            "compilation_status" => String(compilation.status),
            "classification_code" => compilation.classification_code,
            "isomorphic_duplicate_of_seed" => duplicate_of)
        compilation.status == :pass && duplicate_of === nothing || begin
            push!(topology_rows, row); continue
        end
        topology_geometry = topology.symmetry in ("rotational", "helical") ?
            "toroidal_volume_v1" : "linear_volume_v1"
        topology_geometry == target_geometry || continue
        grammar = compile_structural_transition_grammar_v86(structure_hash,
            transition)
        accepted_structure = false
        for p in physical, o in operating, c in control
            design = if transition ==
                    "declared_internal_current_ring_flux_core_v1"
                physical_rng = _v84_stream_rng(structure_hash,
                    "internal_flux_core_physical", p)
                operating_rng = _v84_stream_rng(structure_hash,
                    "internal_flux_core_operating", o)
                control_rng = _v84_stream_rng(structure_hash,
                    "internal_flux_core_control", c)
                amplitude = p == 1 ? 0.0 : 0.004
                compile_candidate_joint_design_v1(grammar; route = route,
                    coil_fourier_coefficients = amplitude .* randn(physical_rng, 5),
                    coil_bspline_control_points = amplitude .* randn(physical_rng, 6),
                    current_potential_coefficients = amplitude .* randn(physical_rng, 5),
                    plasma_boundary_coefficients = amplitude .* randn(physical_rng, 5),
                    actuator_timing_coefficients = 0.01 .* randn(control_rng, 5),
                    controller_modal_coefficients = 0.01 .* randn(control_rng, 4),
                    field_current_a = 1.0e5 * (0.95 + 0.10 * rand(physical_rng)),
                    density_scale = 0.90 + 0.20 * rand(operating_rng),
                    temperature_scale = 0.90 + 0.20 * rand(operating_rng))
            else
                seed_candidate_joint_design_v1(grammar;
                    physical_variant = p, operating_variant = o,
                    control_variant = c, route = route)
            end
            override = Dict{String,Any}(
                "basis_level" => 0, "grammar_transition" => transition,
                "retroactive_feasibility_credit" => false)
            if transition == "prescribed_electrostatic_end_barrier_pair_v1"
                fractions = (0.55, 0.75, 0.95)
                override["end_barrier_potential_fraction_of_injector"] =
                    fractions[mod1(p, length(fractions))]
            else
                fractions = (0.04, 0.06, 0.08, 0.10, 0.12)
                override["internal_ring_current_fraction"] =
                    fractions[mod1(p, length(fractions))]
                override["internal_ring_excluded_core_radius_m"] = 0.08
            end
            compiled = compile_joint_physical_realization_v85(topology,
                compilation, design; basis_override = override,
                base_coil_count = 16)
            String(compiled.binding["geometry_class"]) == target_geometry ||
                continue
            signature = compile_topology_capability_signature_v1(topology,
                compilation, compiled.binding)
            request_index += 1; accepted_structure = true
            request = compile_candidate_solve_request_v86(request_index, seed,
                topology, compilation, grammar, p, o, c, route;
                basis_level = 0, initial_design_override = design,
                serialized_basis_override = override,
                capability_signature = signature)
            push!(requests, candidate_solve_request_to_dict_v86(request))
        end
        accepted_structure && push!(topology_rows, row)
    end
    groups = Dict{String,Vector{Dict{String,Any}}}()
    for request in requests
        cell = String(request["capability_signature"]["capability_cell_hash"])
        push!(get!(groups, cell, Dict{String,Any}[]), request)
    end
    for rows in values(groups); sort!(rows; by = row -> String(row["request_hash"])); end
    schedule = Int[]; depth = 1
    while length(schedule) < length(requests)
        added = false
        for cell in sort!(collect(keys(groups)))
            depth <= length(groups[cell]) || continue
            push!(schedule, Int(groups[cell][depth]["request_index"])); added = true
        end
        added || break; depth += 1
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "campaign_kind" => "structural_transition_campaign_v1",
        "structural_transition_id" => transition,
        "target_geometry_class" => target_geometry,
        "raw_topology_count" => length(seeds),
        "unique_structure_count" => length(topology_rows),
        "compile_pass_unique_structure_count" => length(topology_rows),
        "request_count" => length(requests), "topologies" => topology_rows,
        "request_hashes" => [request["request_hash"] for request in requests],
        "capability_cell_count" => length(groups),
        "budget_stratum_count" => length(unique(String(request[
            "capability_signature"]["budget_stratum_hash"]) for request in requests)),
        "fair_schedule_request_indices" => schedule,
        "fairness_policy" => "capability_cell_round_robin_v1",
        "seed_streams_independent" => true,
        "isomorphism_dedup_before_variants" => true,
        "retroactive_feasibility_credit" => false)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "specification" => body,
        "requests" => requests, "campaign_hash" => canonical_hash(body),
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
end

function compile_v86_capability_subset_catalog_v1(parent_campaign;
        required_gate = nothing, minimality_eligible = nothing)
    gate = required_gate === nothing ? nothing : String(required_gate)
    eligibility = minimality_eligible === nothing ? nothing :
        Bool(minimality_eligible)
    requests = Dict{String,Any}[]
    for raw_value in parent_campaign["requests"]
        raw = _stage3_plain_v1(raw_value)
        signature = raw["capability_signature"]
        gate !== nothing && !(gate in String.(signature[
            "required_hard_gate_chain"])) && continue
        eligibility !== nothing && Bool(signature["minimality_eligible"]) !=
            eligibility && continue
        push!(requests, raw)
    end
    cells = unique(String(raw["capability_signature"]["capability_cell_hash"])
        for raw in requests)
    strata = unique(String(raw["capability_signature"]["budget_stratum_hash"])
        for raw in requests)
    parent_schedule = Int.(parent_campaign["specification"][
        "fair_schedule_request_indices"])
    selected_indices = Set(Int(raw["request_index"]) for raw in requests)
    schedule = [index for index in parent_schedule if index in selected_indices]
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "campaign_kind" => "capability_filtered_request_catalog_v1",
        "parent_campaign_hash" => parent_campaign["campaign_hash"],
        "filter" => Dict{String,Any}(
            "required_gate" => gate,
            "minimality_eligible" => eligibility,
            "device_family_filter_used" => false),
        "request_count" => length(requests),
        "request_hashes" => [raw["request_hash"] for raw in requests],
        "capability_cell_count" => length(cells),
        "budget_stratum_count" => length(strata),
        "fair_schedule_request_indices" => schedule,
        "fairness_policy" => parent_campaign["specification"]["fairness_policy"],
        "seed_streams_independent" => true,
        "isomorphism_dedup_before_variants" => true)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "specification" => body,
        "requests" => requests, "campaign_hash" => canonical_hash(body),
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
end

const V86_BUDGETED_GATE_ORDER_V1 = (
    "finite_filament_field", "poincare_32", "poincare_64", "poincare_128",
    "open_field_end_loss", "open_field_finite_pressure_capability",
    "finite_pressure_equilibrium",
    "sampled_ideal_mhd_stability")

function compile_v86_capability_budget_policy_v1(;
        minimum_initial_exploration_per_cell::Integer = 1,
        maximum_stage_requests_per_cell = Dict(
            "finite_filament_field" => 16, "poincare_32" => 8,
            "poincare_64" => 4, "poincare_128" => 2,
            "open_field_end_loss" => 8,
            "open_field_finite_pressure_capability" => 4,
            "finite_pressure_equilibrium" => 1,
            "sampled_ideal_mhd_stability" => 1),
        maximum_stage_requests_per_stratum = Dict(
            "finite_filament_field" => 512, "poincare_32" => 256,
            "poincare_64" => 128, "poincare_128" => 64,
            "open_field_end_loss" => 256,
            "open_field_finite_pressure_capability" => 128,
            "finite_pressure_equilibrium" => 32,
            "sampled_ideal_mhd_stability" => 16),
        maximum_exceptions_per_cell::Integer = 3,
        maximum_basis_upgrades_per_cell::Integer = 2)
    per_cell = Dict{String,Int}(String(key) => Int(value) for (key, value) in
        maximum_stage_requests_per_cell)
    per_stratum = Dict{String,Int}(String(key) => Int(value) for (key, value) in
        maximum_stage_requests_per_stratum)
    Set(keys(per_cell)) == Set(V86_BUDGETED_GATE_ORDER_V1) || throw(ArgumentError(
        "v86 per-cell budget must cover every budgeted gate"))
    Set(keys(per_stratum)) == Set(V86_BUDGETED_GATE_ORDER_V1) ||
        throw(ArgumentError(
            "v86 per-stratum budget must cover every budgeted gate"))
    minimum_initial_exploration_per_cell > 0 || throw(ArgumentError(
        "v86 minimum initial exploration must be positive"))
    all(>(0), values(per_cell)) || throw(ArgumentError(
        "v86 per-cell stage budgets must be positive"))
    all(>(0), values(per_stratum)) || throw(ArgumentError(
        "v86 per-stratum stage budgets must be positive"))
    per_cell["finite_filament_field"] >= minimum_initial_exploration_per_cell ||
        throw(ArgumentError("v86 field budget is below the cell exploration floor"))
    maximum_exceptions_per_cell >= 0 || throw(ArgumentError(
        "v86 exception budget cannot be negative"))
    maximum_basis_upgrades_per_cell >= 0 || throw(ArgumentError(
        "v86 basis-upgrade budget cannot be negative"))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "minimum_initial_exploration_per_cell" =>
            Int(minimum_initial_exploration_per_cell),
        "maximum_stage_requests_per_cell" => per_cell,
        "maximum_stage_requests_per_stratum" => per_stratum,
        "maximum_exceptions_per_cell" => Int(maximum_exceptions_per_cell),
        "maximum_basis_upgrades_per_cell" =>
            Int(maximum_basis_upgrades_per_cell),
        "cache_hits_consume_solver_budget" => false,
        "parallel_completion_order_affects_selection" => false,
        "retroactive_feasibility_credit" => false)
    body["budget_policy_hash"] = canonical_hash(body)
    return body
end

function _v86_frontier_rank_lt(left, right)
    left_rank = Float64.(get(left, "frontier_rank", Float64[]))
    right_rank = Float64.(get(right, "frontier_rank", Float64[]))
    for index in 1:max(length(left_rank), length(right_rank))
        a = index <= length(left_rank) ? left_rank[index] : 0.0
        b = index <= length(right_rank) ? right_rank[index] : 0.0
        a == b || return a < b
    end
    return String(left["request_hash"]) < String(right["request_hash"])
end

function _v86_budget_select_requests(requests, scheduled_gate, budget_policy;
        initial::Bool = false)
    gate = String(scheduled_gate)
    gate in V86_BUDGETED_GATE_ORDER_V1 || throw(ArgumentError(
        "unsupported v86 budgeted gate $gate"))
    deduplicated = Dict{String,Dict{String,Any}}()
    duplicate_count = 0
    for raw_value in requests
        raw = _stage3_plain_v1(raw_value)
        key = String(get(raw, "frontier_deduplication_key",
            raw["request_hash"]))
        if haskey(deduplicated, key)
            duplicate_count += 1
            _v86_frontier_rank_lt(raw, deduplicated[key]) &&
                (deduplicated[key] = raw)
        else
            deduplicated[key] = raw
        end
    end
    candidates = collect(values(deduplicated))
    groups = Dict{String,Dict{String,Vector{Dict{String,Any}}}}()
    for raw in candidates
        signature = raw["capability_signature"]
        stratum = String(signature["budget_stratum_hash"])
        cell = String(signature["capability_cell_hash"])
        push!(get!(get!(groups, stratum,
            Dict{String,Vector{Dict{String,Any}}}()), cell,
            Dict{String,Any}[]), raw)
    end
    for cells in values(groups), rows in values(cells)
        sort!(rows; lt = _v86_frontier_rank_lt)
    end
    selected = Dict{String,Any}[]
    per_cell_limit = Int(budget_policy["maximum_stage_requests_per_cell"][gate])
    per_stratum_limit = Int(budget_policy[
        "maximum_stage_requests_per_stratum"][gate])
    minimum = initial ? Int(budget_policy[
        "minimum_initial_exploration_per_cell"]) : 0
    decisions = Dict{String,Any}[]
    for stratum in sort!(collect(keys(groups)))
        cells = groups[stratum]
        minimum * length(cells) <= per_stratum_limit || throw(ArgumentError(
            "v86 stratum budget cannot satisfy the per-cell exploration floor"))
        counts = Dict(cell => 0 for cell in keys(cells))
        stratum_selected = Dict{String,Any}[]
        for cell in sort!(collect(keys(cells)))
            for raw in Iterators.take(cells[cell], minimum)
                push!(stratum_selected, raw); counts[cell] += 1
            end
        end
        depth = minimum + 1
        while length(stratum_selected) < per_stratum_limit
            added = false
            for cell in sort!(collect(keys(cells)))
                counts[cell] < per_cell_limit || continue
                depth <= length(cells[cell]) || continue
                push!(stratum_selected, cells[cell][depth])
                counts[cell] += 1; added = true
                length(stratum_selected) >= per_stratum_limit && break
            end
            added || break
            depth += 1
        end
        append!(selected, stratum_selected)
        push!(decisions, Dict{String,Any}(
            "budget_stratum_hash" => stratum,
            "candidate_count_after_input_dedup" => sum(length, values(cells)),
            "selected_count" => length(stratum_selected),
            "rejected_by_budget_count" => sum(length, values(cells)) -
                length(stratum_selected),
            "selected_count_by_capability_cell" => counts))
    end
    sort!(selected; by = raw -> String(raw["request_hash"]))
    return (selected = selected, decisions = decisions,
        duplicate_input_count = duplicate_count)
end

function _v86_hierarchical_stage_schedule(requests)
    cells = Dict{String,Vector{Dict{String,Any}}}()
    strata = Dict{String,Set{String}}()
    for raw in requests
        signature = raw["capability_signature"]
        cell = String(signature["capability_cell_hash"])
        stratum = String(signature["budget_stratum_hash"])
        push!(get!(cells, cell, Dict{String,Any}[]), raw)
        push!(get!(strata, stratum, Set{String}()), cell)
    end
    for rows in values(cells)
        sort!(rows; lt = _v86_frontier_rank_lt)
    end
    queues = Dict{String,Vector{Int}}()
    for (stratum, cell_set) in strata
        queue = Int[]; depth = 1
        while true
            added = false
            for cell in sort!(collect(cell_set))
                depth <= length(cells[cell]) || continue
                push!(queue, Int(cells[cell][depth]["request_index"])); added = true
            end
            added || break
            depth += 1
        end
        queues[stratum] = queue
    end
    schedule = Int[]; depth = 1
    while length(schedule) < length(requests)
        added = false
        for stratum in sort!(collect(keys(queues)))
            depth <= length(queues[stratum]) || continue
            push!(schedule, queues[stratum][depth]); added = true
        end
        added || break
        depth += 1
    end
    return schedule
end

function _v86_build_stage_campaign(parent_campaign, selected, scheduled_gate,
        budget_policy, budget_decisions; campaign_kind, frontier_metadata =
            Dict{String,Any}(), design_execution_policy::AbstractString =
            "joint_optimize_and_reaudit_v1")
    design_execution_policy in ("joint_optimize_and_reaudit_v1",
        "frozen_promoted_design_reaudit_v1",
        "frozen_declared_design_reaudit_v1") || throw(ArgumentError(
        "unknown v86 design execution policy $design_execution_policy"))
    requests = Dict{String,Any}[]
    for raw_value in selected
        raw = _stage3_plain_v1(raw_value)
        raw["scheduled_gate"] = String(scheduled_gate)
        raw["design_execution_policy"] = String(design_execution_policy)
        push!(requests, raw)
    end
    schedule = _v86_hierarchical_stage_schedule(requests)
    stage_map = Dict(String(raw["request_hash"]) => raw["scheduled_gate"] for
        raw in requests)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "campaign_kind" => String(campaign_kind),
        "parent_campaign_hash" => parent_campaign["campaign_hash"],
        "scheduled_gate" => String(scheduled_gate),
        "request_count" => length(requests),
        "request_hashes" => [raw["request_hash"] for raw in requests],
        "scheduled_gate_by_request_hash" => stage_map,
        "capability_cell_count" => length(unique(String(raw[
            "capability_signature"]["capability_cell_hash"]) for raw in requests)),
        "budget_stratum_count" => length(unique(String(raw[
            "capability_signature"]["budget_stratum_hash"]) for raw in requests)),
        "fair_schedule_request_indices" => schedule,
        "fairness_policy" =>
            "budget_stratum_then_capability_cell_round_robin_v2",
        "budget_policy" => budget_policy,
        "budget_decisions" => budget_decisions,
        "frontier_metadata" => frontier_metadata,
        "design_execution_policy" => String(design_execution_policy),
        "seed_streams_independent" => true,
        "isomorphism_dedup_before_variants" => true,
        "retroactive_feasibility_credit" => false)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "specification" => body,
        "requests" => requests, "campaign_hash" => canonical_hash(body),
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
end

function compile_v86_initial_stage_campaign_v1(catalog_campaign;
        budget_policy = compile_v86_capability_budget_policy_v1(),
        stop_manifest = nothing, allow_after_stop::Bool = false,
        design_execution_policy::AbstractString =
            "joint_optimize_and_reaudit_v1")
    adaptive_followup = get(catalog_campaign["specification"], "campaign_kind",
        "") in ("adaptive_basis_promotion_followup_v1",
        "current_potential_inverse_followup_v1")
    if stop_manifest !== nothing && get(stop_manifest,
            "stop_topology_expansion", false) === true && !adaptive_followup &&
            !allow_after_stop
        throw(ArgumentError(
            "v86 stop manifest forbids further topology expansion"))
    end
    retired = stop_manifest === nothing ? Set{String}() : Set(String.(get(
        stop_manifest, "retired_basis_basin_keys", String[])))
    candidates = Dict{String,Any}[]
    for raw_value in catalog_campaign["requests"]
        raw = _stage3_plain_v1(raw_value)
        basin_key = canonical_hash(Dict{String,Any}(
            "comparison_scope_hash" => raw["capability_signature"][
                "comparison_scope_hash"],
            "basis_level" => raw["basis_level"]))
        basin_key in retired && continue
        haskey(raw, "frontier_rank") || (raw["frontier_rank"] = Float64[])
        push!(candidates, raw)
    end
    selection = _v86_budget_select_requests(candidates,
        "finite_filament_field", budget_policy; initial = true)
    metadata = Dict{String,Any}(
        "source_request_count" => length(candidates),
        "duplicate_input_count_before_execution" =>
            selection.duplicate_input_count,
        "retired_basis_basin_count" => length(retired),
        "selection_uses_solver_results" => false)
    return _v86_build_stage_campaign(catalog_campaign, selection.selected,
        "finite_filament_field", budget_policy, selection.decisions;
        campaign_kind = "initial_field_frontier_v1",
        frontier_metadata = metadata,
        design_execution_policy = design_execution_policy)
end

function compile_v86_next_stage_frontier_v1(parent_campaign, merged_summary;
        budget_policy = get(parent_campaign["specification"], "budget_policy",
            compile_v86_capability_budget_policy_v1()), target_gate = nothing)
    String(merged_summary["campaign_hash"]) == String(parent_campaign[
        "campaign_hash"]) || throw(ArgumentError(
        "v86 frontier summary and parent campaign differ"))
    records = _stage3_plain_v1.(collect(get(merged_summary,
        "stage_frontier_records", Any[])))
    isempty(records) && throw(ArgumentError(
        "v86 merge has no stage frontier records"))
    next_gates = sort!(unique(String(record["next_applicable_gate"]) for record in
        records if get(record, "promotion_eligible", false) === true))
    isempty(next_gates) && return nothing
    next_gate = if target_gate === nothing
        length(next_gates) == 1 || throw(ArgumentError(
            "v86 next frontier has multiple target gates; select one explicitly"))
        only(next_gates)
    else
        requested = String(target_gate)
        requested in next_gates || throw(ArgumentError(
            "requested v86 target gate has no eligible frontier records"))
        requested
    end
    raw_by_hash = Dict(String(raw["request_hash"]) => raw for raw in
        parent_campaign["requests"])
    exception_counts = Dict{String,Int}()
    for record in records
        get(record, "is_exception", false) === true || continue
        cell = String(record["capability_cell_hash"])
        exception_counts[cell] = get(exception_counts, cell, 0) + 1
    end
    candidates = Dict{String,Any}[]; stopped_cells = Set{String}()
    for record in records
        get(record, "promotion_eligible", false) === true || continue
        String(record["next_applicable_gate"]) == next_gate || continue
        cell = String(record["capability_cell_hash"])
        if get(exception_counts, cell, 0) >= Int(budget_policy[
                "maximum_exceptions_per_cell"])
            push!(stopped_cells, cell); continue
        end
        raw = _stage3_plain_v1(raw_by_hash[String(record["request_hash"])])
        restored = _v86_restore_request(raw)
        optimized_design = _v86_joint_design_from_dict(record[
            "optimized_design"], restored.grammar)
        next_request = compile_candidate_solve_request_v86(
            restored.request.request_index, restored.request.structure_seed,
            restored.topology, restored.compilation, restored.grammar,
            restored.request.physical_variant,
            restored.request.operating_variant,
            restored.request.control_variant, restored.request.route;
            basis_level = restored.request.basis_level,
            capability_signature = restored.request.capability_signature,
            initial_design_override = optimized_design,
            serialized_basis_override = get(record,
                "optimized_basis_override", restored.request.basis_override))
        next_raw = candidate_solve_request_to_dict_v86(next_request)
        next_raw["parent_request_hash"] = raw["request_hash"]
        next_raw["frontier_rank"] = Float64.(record["frontier_rank"])
        next_raw["frontier_deduplication_key"] = String(record[
            "completed_solver_input_hash"])
        next_raw["frontier_parent_record_hash"] = record[
            "frontier_record_hash"]
        next_raw["source_previous_stage_solver_input_hash"] = record[
            "completed_solver_input_hash"]
        next_raw["retroactive_feasibility_credit"] = false
        push!(candidates, next_raw)
    end
    selection = _v86_budget_select_requests(candidates, next_gate,
        budget_policy)
    metadata = Dict{String,Any}(
        "source_result_hash" => merged_summary["result_hash"],
        "source_record_count" => length(records),
        "promotion_candidate_count" => length(candidates),
        "deduplicated_completed_solver_input_count" =>
            selection.duplicate_input_count,
        "exception_stopped_capability_cells" => sort!(collect(stopped_cells)),
        "selection_uses_only_completed_stage_evidence" => true,
        "retroactive_feasibility_credit" => false)
    return _v86_build_stage_campaign(parent_campaign, selection.selected,
        next_gate, budget_policy, selection.decisions;
        campaign_kind = "merged_evidence_stage_frontier_v1",
        frontier_metadata = metadata,
        design_execution_policy = "frozen_promoted_design_reaudit_v1")
end

function compile_v86_next_stage_frontiers_v1(parent_campaign, merged_summary;
        budget_policy = get(parent_campaign["specification"], "budget_policy",
            compile_v86_capability_budget_policy_v1()))
    gates = sort!(unique(String(record["next_applicable_gate"]) for record in
        get(merged_summary, "stage_frontier_records", Any[]) if get(record,
            "promotion_eligible", false) === true))
    return Dict(gate => compile_v86_next_stage_frontier_v1(parent_campaign,
        merged_summary; budget_policy = budget_policy, target_gate = gate) for
        gate in gates)
end

function _v86_cache_path(cache_root, stage, solver_input_hash)
    String(stage) in V86_CACHE_STAGES_V1 || throw(ArgumentError(
        "unknown v86 cache stage $stage"))
    hash = String(solver_input_hash)
    length(hash) == 64 || throw(ArgumentError("solver input hash must be sha256-sized"))
    return joinpath(String(cache_root), String(stage), hash[1:2], hash * ".json")
end

function _v86_cache_object(stage, solver_input_hash, payload)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "stage" => String(stage),
        "solver_input_hash" => String(solver_input_hash),
        "payload" => _v86_json_plain(payload),
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
    body["cache_object_hash"] = canonical_hash(body)
    return body
end

function _v86_read_cache(cache_root, stage, solver_input_hash)
    path = _v86_cache_path(cache_root, stage, solver_input_hash)
    isfile(path) || return nothing
    item = _stage3_plain_v1(JSON3.read(read(path, String), Dict{String,Any}))
    String(item["stage"]) == String(stage) &&
        String(item["solver_input_hash"]) == String(solver_input_hash) ||
        throw(ArgumentError("v86 cache key mismatch"))
    expected = canonical_hash(Dict{String,Any}(String(key) => value for
        (key, value) in item if String(key) != "cache_object_hash"))
    expected == String(item["cache_object_hash"]) || throw(ArgumentError(
        "v86 cache object hash mismatch"))
    return item
end

function _v86_write_cache(cache_root, stage, solver_input_hash, payload)
    existing = _v86_read_cache(cache_root, stage, solver_input_hash)
    existing !== nothing && return existing, true
    path = _v86_cache_path(cache_root, stage, solver_input_hash)
    mkpath(dirname(path)); lock_path = path * ".lock"
    acquired = false
    for _ in 1:200
        try
            mkdir(lock_path); acquired = true; break
        catch
            isfile(path) && return _v86_read_cache(cache_root, stage,
                solver_input_hash), true
            sleep(0.025)
        end
    end
    acquired || throw(ArgumentError("timed out acquiring v86 cache lock"))
    try
        existing = _v86_read_cache(cache_root, stage, solver_input_hash)
        existing !== nothing && return existing, true
        item = _v86_cache_object(stage, solver_input_hash, payload)
        temporary = path * ".$(getpid()).partial"
        open(temporary, "w") do io
            JSON3.pretty(io, item); write(io, '\n')
        end
        mv(temporary, path; force = true)
        return item, false
    finally
        isdir(lock_path) && rm(lock_path; recursive = true, force = true)
    end
end

function _v86_cached_execution(cache_root, stage, solver_input_hash, producer)
    existing = _v86_read_cache(cache_root, stage, solver_input_hash)
    existing !== nothing && return (payload = existing["payload"],
        cache_hit = true, cache_object_hash = existing["cache_object_hash"])
    path = _v86_cache_path(cache_root, stage, solver_input_hash)
    mkpath(dirname(path)); lock_path = path * ".execute.lock"
    acquired = false
    for _ in 1:12000
        try
            mkdir(lock_path); acquired = true; break
        catch
            existing = _v86_read_cache(cache_root, stage, solver_input_hash)
            existing !== nothing && return (payload = existing["payload"],
                cache_hit = true,
                cache_object_hash = existing["cache_object_hash"])
            if isdir(lock_path)
                age_seconds = time() - stat(lock_path).mtime
                if age_seconds > 86400
                    try
                        rm(lock_path; force = true)
                    catch
                    end
                end
            end
            sleep(0.05)
        end
    end
    acquired || throw(ArgumentError(
        "timed out waiting for v86 solver execution lock"))
    try
        existing = _v86_read_cache(cache_root, stage, solver_input_hash)
        existing !== nothing && return (payload = existing["payload"],
            cache_hit = true, cache_object_hash = existing["cache_object_hash"])
        payload = producer()
        item = _v86_cache_object(stage, solver_input_hash, payload)
        temporary = path * ".$(getpid()).partial"
        open(temporary, "w") do io
            JSON3.pretty(io, item); write(io, '\n')
        end
        mv(temporary, path; force = true)
        return (payload = item["payload"], cache_hit = false,
            cache_object_hash = item["cache_object_hash"])
    finally
        isdir(lock_path) && rm(lock_path; force = true)
    end
end

_v86_cached_execution(producer::Function, cache_root, stage,
    solver_input_hash) = _v86_cached_execution(cache_root, stage,
        solver_input_hash, producer)

function _v86_cached_execution_if_present(cache_root, stage, solver_input_hash)
    existing = _v86_read_cache(cache_root, stage, solver_input_hash)
    existing === nothing && return nothing
    return (payload = existing["payload"], cache_hit = true,
        cache_object_hash = existing["cache_object_hash"])
end

function _v86_open_trace(realization, cache, start, direction;
        maximum_steps::Integer = 3000)
    region = _v71_primary_region(realization)
    minor = Float64(region["minor_radius_m"])
    half_length = Float64(region["half_length_m"])
    center = Float64.(region["center_m"])
    step_m = min(minor / 32, half_length / 80)
    position = Float64.(start); path = 0.0; minimum_field = floatmax(Float64)
    maximum_field = 0.0; reason = "maximum_steps"; completed_steps = 0
    for step_index in 1:Int(maximum_steps)
        field = finite_filament_field_v71(cache, position)
        magnitude = norm(field)
        if !isfinite(magnitude) || magnitude <= 1.0e-10
            reason = "field_singular"; break
        end
        minimum_field = min(minimum_field, magnitude)
        maximum_field = max(maximum_field, magnitude)
        position .+= Float64(direction) * step_m .* field ./ magnitude
        path += step_m; completed_steps = step_index
        axial = abs(position[3] - center[3])
        radial = hypot(position[1] - center[1], position[2] - center[2])
        if axial >= half_length
            reason = "axial_end"; break
        elseif radial >= 1.05 * minor
            reason = "radial_escape"; break
        end
    end
    finite_minimum = minimum_field == floatmax(Float64) ? nothing : minimum_field
    return Dict{String,Any}(
        "start_m" => Float64.(start), "direction" => Int(direction),
        "end_m" => position, "termination" => reason,
        "completed_steps" => completed_steps, "path_length_m" => path,
        "minimum_field_t" => finite_minimum,
        "maximum_field_t" => maximum_field,
        "reached_axial_end" => reason == "axial_end")
end

function v86_open_field_solver_input_hash_v1(compiled, field_solver_input_hash)
    binding = compiled.binding; region = _v71_primary_region(compiled.realization)
    return canonical_hash(Dict{String,Any}(
        "field_solver_input_hash" => String(field_solver_input_hash),
        "region_geometry" => region,
        "target_total_ion_density_m3" => binding["target_total_ion_density_m3"],
        "target_ion_temperature_kev" => binding["target_ion_temperature_kev"],
        "target_electron_temperature_kev" =>
            binding["target_electron_temperature_kev"],
        "fueling_capacity_per_s" => binding["fueling_capacity_per_s"],
        "heating_power_w" => binding["heating_power_w"],
        "actuator_capacity_w" => binding["actuator_capacity_w"],
        "prescribed_open_end_barrier" => get(binding,
            "v85_open_end_barrier", nothing),
        "trace_model" => "bidirectional_finite_filament_open_end_v1",
        "maximum_steps" => 3000))
end

function evaluate_open_field_end_loss_gate_v86(compiled, biot_gate)
    biot_gate["status"] == "pass" || return _v85_gate_record(
        "open_field_end_loss", "not_admitted", "biot_savart_hard_gate_not_passed";
        missing_requirements = ["finite_filament_field_pass"])
    realization = compiled.realization; binding = compiled.binding
    region = _v71_primary_region(realization)
    String(region["geometry_class"]) == "linear_volume_v1" || return
        _v85_gate_record("open_field_end_loss", "unsupported",
            "open_end_executor_requires_linear_volume";
            missing_requirements = ["applicable_open_field_geometry"])
    cache = compile_finite_filament_field_cache_v71(realization)
    minor = Float64(region["minor_radius_m"]); center = Float64.(region["center_m"])
    starts = [[center[1] + fraction * minor, center[2], center[3]] for fraction in
        (0.0, 0.30, 0.60)]
    traces = [_v86_open_trace(realization, cache, start, direction) for
        start in starts for direction in (-1, 1)]
    connected = [trace for trace in traces if trace["reached_axial_end"] === true]
    fields_min = Float64[trace["minimum_field_t"] for trace in connected if
        trace["minimum_field_t"] !== nothing]
    fields_max = Float64[trace["maximum_field_t"] for trace in connected]
    elementary_charge = 1.602176634e-19; ion_mass = 2.5 * 1.66053906660e-27
    temperature_j = Float64(binding["target_ion_temperature_kev"]) * 1.0e3 *
        elementary_charge
    thermal_speed = sqrt(2temperature_j / ion_mass)
    mean_path = isempty(connected) ? nothing : sum(Float64(trace["path_length_m"])
        for trace in connected) / length(connected)
    mirror_ratio = isempty(fields_min) ? nothing : maximum(fields_max) /
        max(minimum(fields_min), 1.0e-12)
    loss_fraction = mirror_ratio === nothing ? nothing : clamp(2 *
        (1 - sqrt(max(0.0, 1 - 1 / max(mirror_ratio, 1.0)))), 0.0, 1.0)
    ballistic_tau = mean_path === nothing || loss_fraction === nothing ? nothing :
        mean_path / thermal_speed / max(loss_fraction, 1.0e-6)
    density = Float64(binding["target_total_ion_density_m3"])
    inventory = density * Float64(region["volume_m3"])
    unmitigated_particle_end_flux = ballistic_tau === nothing ? nothing :
        inventory / ballistic_tau
    unmitigated_end_power = ballistic_tau === nothing ? nothing : 1.5 * inventory *
        temperature_j / ballistic_tau
    barrier = get(binding, "v85_open_end_barrier", nothing)
    barrier_potential_kev = barrier === nothing ? 0.0 : Float64(barrier[
        "potential_kev"])
    barrier_exponent = barrier === nothing ? 0.0 : barrier_potential_kev /
        max(Float64(binding["target_ion_temperature_kev"]), 1.0e-9)
    maxwellian_transmission = barrier === nothing ? 1.0 : exp(-min(
        barrier_exponent, 80.0))
    particle_end_flux = unmitigated_particle_end_flux === nothing ? nothing :
        unmitigated_particle_end_flux * maxwellian_transmission
    barrier_energy_j = barrier_potential_kev * 1.0e3 * elementary_charge
    end_power = particle_end_flux === nothing ? nothing : particle_end_flux *
        (1.5 * temperature_j + barrier_energy_j)
    capacity_ok = particle_end_flux === nothing ? false : particle_end_flux <=
        Float64(binding["fueling_capacity_per_s"])
    power_ok = end_power === nothing ? false : end_power <=
        Float64(binding["actuator_capacity_w"])
    evidence = Dict{String,Any}(
        "model_id" => "bidirectional_finite_filament_open_end_loss_v1",
        "traces" => traces, "axial_end_connection_count" => length(connected),
        "required_connection_count" => length(traces), "mean_end_path_m" => mean_path,
        "thermal_speed_m_s" => thermal_speed, "sampled_mirror_ratio" => mirror_ratio,
        "isotropic_two_end_loss_cone_fraction" => loss_fraction,
        "unmitigated_ballistic_confinement_s" => ballistic_tau,
        "unmitigated_particle_end_flux_per_s" => unmitigated_particle_end_flux,
        "unmitigated_end_power_w" => unmitigated_end_power,
        "prescribed_end_barrier" => barrier,
        "barrier_potential_kev" => barrier_potential_kev,
        "barrier_to_ion_temperature_ratio" => barrier_exponent,
        "maxwellian_barrier_transmission" => maxwellian_transmission,
        "screened_particle_end_flux_per_s" => particle_end_flux,
        "screened_end_power_w" => end_power,
        "fueling_capacity_per_s" => binding["fueling_capacity_per_s"],
        "actuator_capacity_w" => binding["actuator_capacity_w"],
        "particle_capacity_check" => capacity_ok,
        "power_capacity_check" => power_ok,
        "prescribed_electrostatic_barrier_credit" => barrier === nothing ? 0.0 : 1.0,
        "ambipolar_credit" => 0.0, "kinetic_credit" => 0.0,
        "finite_pressure_credit" => 0.0)
    nonphysical_trace = any(trace["termination"] in ("field_null", "step_limit")
        for trace in traces)
    if nonphysical_trace
        return _v85_gate_record("open_field_end_loss", "unknown",
            "open_end_trace_incomplete_or_field_null"; evidence = evidence,
            missing_requirements = ["resolved_bidirectional_open_field_trace"])
    elseif length(connected) != length(traces)
        return _v85_gate_record("open_field_end_loss", "fail",
            "field_line_radial_escape_before_declared_end_ports";
            evidence = evidence)
    elseif !capacity_ok || !power_ok
        return _v85_gate_record("open_field_end_loss", "fail",
            barrier === nothing ? "unmitigated_open_end_capacity_shortfall" :
                "prescribed_electrostatic_barrier_capacity_shortfall";
            evidence = evidence)
    end
    return _v85_gate_record("open_field_end_loss", "pass",
        barrier === nothing ? "unmitigated_ballistic_open_end_capacity_satisfied" :
            "prescribed_electrostatic_barrier_open_end_capacity_satisfied";
        evidence = evidence)
end

function _v86_open_end_loss_acquisition_v1(compiled)
    biot = evaluate_v85_biot_savart_gate_v1(compiled)
    if String(biot["status"]) != "pass"
        return Dict{String,Any}(
            "model_id" => "candidate_bound_open_end_loss_acquisition_v1",
            "status" => "not_admitted",
            "classification_code" => "finite_filament_field_not_passed",
            "acquisition_penalty" => 20.0,
            "feasibility_credit" => false,
            "applies_to_current_sampling_rank_only" => true)
    end
    gate = evaluate_open_field_end_loss_gate_v86(compiled, biot)
    evidence = get(gate, "evidence", Dict{String,Any}())
    particle_flux = get(evidence, "screened_particle_end_flux_per_s",
        get(evidence, "unmitigated_particle_end_flux_per_s", nothing))
    power = get(evidence, "screened_end_power_w",
        get(evidence, "unmitigated_end_power_w", nothing))
    particle_capacity = Float64(get(evidence, "fueling_capacity_per_s", 0.0))
    power_capacity = Float64(get(evidence, "actuator_capacity_w", 0.0))
    particle_ratio = particle_flux === nothing || particle_capacity <= 0.0 ? Inf :
        Float64(particle_flux) / particle_capacity
    power_ratio = power === nothing || power_capacity <= 0.0 ? Inf :
        Float64(power) / power_capacity
    connection_count = Int(get(evidence, "axial_end_connection_count", 0))
    required_connections = max(1, Int(get(evidence, "required_connection_count", 1)))
    connection_shortfall = max(0.0,
        (required_connections - connection_count) / required_connections)
    finite_ratio_penalty(value) = isfinite(value) ? log1p(max(0.0, value - 1.0)) : 20.0
    penalty = finite_ratio_penalty(particle_ratio) +
        finite_ratio_penalty(power_ratio) + 5.0 * connection_shortfall
    return Dict{String,Any}(
        "model_id" => "candidate_bound_open_end_loss_acquisition_v1",
        "status" => gate["status"],
        "classification_code" => gate["classification_code"],
        "particle_capacity_ratio" => particle_ratio,
        "power_capacity_ratio" => power_ratio,
        "axial_end_connection_fraction" => connection_count /
            required_connections,
        "sampled_mirror_ratio" => get(evidence, "sampled_mirror_ratio", nothing),
        "acquisition_penalty" => penalty,
        "feasibility_credit" => false,
        "formal_gate_credit" => false,
        "applies_to_current_sampling_rank_only" => true)
end

function compile_open_field_paraxial_finite_pressure_input_v1(compiled, biot_gate;
        axial_sample_count::Integer = 25,
        radial_sample_fractions = [0.0, 0.35, 0.70],
        reference_flux_tube_fraction::Real = 0.55,
        maximum_valid_beta::Real = 0.25,
        maximum_valid_field_pitch::Real = 0.35,
        maximum_valid_flux_tube_slope::Real = 0.35,
        maximum_wall_fill_fraction::Real = 0.90)
    biot_gate["status"] == "pass" || throw(ArgumentError(
        "open finite-pressure input requires a passed finite-filament field gate"))
    region = _v71_primary_region(compiled.realization)
    String(region["geometry_class"]) == "linear_volume_v1" || throw(ArgumentError(
        "open finite-pressure input requires a linear open-boundary region"))
    axial_sample_count >= 5 || throw(ArgumentError(
        "open finite-pressure axial grid requires at least five samples"))
    radial = sort!(unique(Float64.(collect(radial_sample_fractions))))
    !isempty(radial) && first(radial) >= 0.0 && last(radial) < 1.0 ||
        throw(ArgumentError("open finite-pressure radial samples must lie in [0,1)"))
    0.0 < reference_flux_tube_fraction < maximum_wall_fill_fraction < 1.0 ||
        throw(ArgumentError("open finite-pressure flux-tube fractions are invalid"))
    maximum_valid_beta > 0.0 || throw(ArgumentError(
        "open finite-pressure beta validity limit must be positive"))
    maximum_valid_field_pitch > 0.0 || throw(ArgumentError(
        "open finite-pressure field-pitch validity limit must be positive"))
    maximum_valid_flux_tube_slope > 0.0 || throw(ArgumentError(
        "open finite-pressure flux-tube slope validity limit must be positive"))
    binding = compiled.binding
    elementary_charge = 1.602176634e-19
    pressure_axis = Float64(binding["target_total_ion_density_m3"]) *
        (Float64(binding["target_ion_temperature_kev"]) +
         Float64(binding["target_electron_temperature_kev"])) *
        1.0e3 * elementary_charge
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "model_id" => "candidate_bound_paraxial_scalar_pressure_flux_tube_v1",
        "field_solver_input_hash" => v85_solver_input_hashes_v1(compiled)[
            "field_solver_input_hash"],
        "source_realization_hash" => compiled.realization.realization_hash,
        "region_geometry" => deepcopy(region),
        "profiles" => Dict{String,Any}(
            "axis_pressure_pa" => pressure_axis,
            "radial_pressure_shape" => "p_axis_times_one_minus_rho_squared_squared_v1",
            "parallel_pressure_semantics" => "constant_on_sampled_flux_tube_v1",
            "target_total_ion_density_m3" => binding[
                "target_total_ion_density_m3"],
            "target_ion_temperature_kev" => binding[
                "target_ion_temperature_kev"],
            "target_electron_temperature_kev" => binding[
                "target_electron_temperature_kev"]),
        "grid" => Dict{String,Any}(
            "axial_sample_count" => Int(axial_sample_count),
            "axial_extent_fraction" => 0.65,
            "radial_sample_fractions" => radial,
            "reference_flux_tube_fraction" => Float64(
                reference_flux_tube_fraction)),
        "validity_domain" => Dict{String,Any}(
            "maximum_beta" => Float64(maximum_valid_beta),
            "maximum_field_pitch" => Float64(maximum_valid_field_pitch),
            "maximum_flux_tube_slope" => Float64(
                maximum_valid_flux_tube_slope),
            "maximum_wall_fill_fraction" => Float64(
                maximum_wall_fill_fraction),
            "scalar_pressure_only" => true,
            "axisymmetric_paraxial_only" => true,
            "anisotropic_pressure_credit" => false,
            "kinetic_end_closure_credit" => false,
            "stability_credit" => false),
        "solver" => Dict{String,Any}(
            "magnetic_pressure_balance" =>
                "B_equilibrium_squared_equals_B_vacuum_squared_minus_2_mu0_p",
            "flux_conservation" => "area_times_axis_field_constant_v1",
            "vacuum_field_source" => "candidate_finite_filament_biot_savart_v71",
            "mu0_h_m" => 4pi * 1.0e-7))
    body["solver_input_hash"] = canonical_hash(body)
    return body
end

function evaluate_open_field_paraxial_finite_pressure_gate_v1(compiled,
        biot_gate, end_loss_gate; kwargs...)
    biot_gate["status"] == "pass" || return _v85_gate_record(
        "open_field_finite_pressure_capability", "not_admitted",
        "finite_filament_field_hard_gate_not_passed";
        missing_requirements = ["finite_filament_field_pass"])
    end_loss_gate["status"] == "pass" || return _v85_gate_record(
        "open_field_finite_pressure_capability", "not_admitted",
        "open_field_end_loss_hard_gate_not_passed";
        missing_requirements = ["open_field_end_loss_pass"])
    region = _v71_primary_region(compiled.realization)
    String(region["geometry_class"]) == "linear_volume_v1" || return
        _v85_gate_record("open_field_finite_pressure_capability", "unsupported",
            "paraxial_open_equilibrium_requires_linear_volume";
            missing_requirements = ["applicable_open_field_geometry"])
    input = compile_open_field_paraxial_finite_pressure_input_v1(compiled,
        biot_gate; kwargs...)
    input_hash = String(input["solver_input_hash"])
    grid = input["grid"]; limits = input["validity_domain"]
    center = Float64.(region["center_m"])
    half_length = Float64(region["half_length_m"])
    minor = Float64(region["minor_radius_m"])
    axial_count = Int(grid["axial_sample_count"])
    axial_extent = Float64(grid["axial_extent_fraction"]) * half_length
    z_values = collect(range(center[3] - axial_extent,
        center[3] + axial_extent; length = axial_count))
    radial_fractions = Float64.(grid["radial_sample_fractions"])
    reference_radius = Float64(grid["reference_flux_tube_fraction"]) * minor
    pressure_axis = Float64(input["profiles"]["axis_pressure_pa"])
    mu0 = Float64(input["solver"]["mu0_h_m"])
    cache = compile_finite_filament_field_cache_v71(compiled.realization)
    axis_fields = Float64[]
    for z in z_values
        push!(axis_fields, norm(finite_filament_field_v71(cache,
            [center[1], center[2], z])))
    end
    reference_index = argmin(abs.(z_values .- center[3]))
    reference_field = axis_fields[reference_index]
    if !isfinite(reference_field) || reference_field <= 1.0e-8 ||
            any(value -> !isfinite(value) || value <= 1.0e-8, axis_fields)
        evidence = Dict{String,Any}(
            "model_id" => input["model_id"], "solver_input" => input,
            "axis_vacuum_field_t" => axis_fields, "candidate_bound" => true,
            "device_family_routing_used" => false,
            "full_open_field_equilibrium_credit" => 0.0)
        return _v85_gate_record("open_field_finite_pressure_capability", "unknown",
            "paraxial_equilibrium_axis_field_null_or_nonfinite";
            solver_input_hash = input_hash, evidence = evidence,
            missing_requirements = ["resolved_nonzero_axis_field"])
    end
    tube_radii = reference_radius .* sqrt.(reference_field ./ axis_fields)
    tube_slopes = abs.(diff(tube_radii) ./ diff(z_values))
    maximum_tube_slope = isempty(tube_slopes) ? 0.0 : maximum(tube_slopes)
    rows = Dict{String,Any}[]
    maximum_beta = 0.0; maximum_pitch = 0.0
    maximum_balance_residual = 0.0; negative_discriminant_count = 0
    for (axial_index, z) in enumerate(z_values)
        tube_radius = tube_radii[axial_index]
        for rho in radial_fractions
            point = [center[1] + rho * tube_radius, center[2], z]
            field = finite_filament_field_v71(cache, point)
            vacuum_field = norm(field)
            pressure = pressure_axis * (1.0 - rho^2)^2
            magnetic_discriminant = vacuum_field^2 - 2mu0 * pressure
            beta = vacuum_field <= 1.0e-12 ? Inf :
                2mu0 * pressure / vacuum_field^2
            pitch = abs(field[3]) <= 1.0e-12 ? Inf :
                hypot(field[1], field[2]) / abs(field[3])
            equilibrium_field = magnetic_discriminant > 0.0 ?
                sqrt(magnetic_discriminant) : 0.0
            balance_scale = max(vacuum_field^2 / (2mu0), 1.0e-12)
            balance_residual = abs(pressure + equilibrium_field^2 / (2mu0) -
                vacuum_field^2 / (2mu0)) / balance_scale
            magnetic_discriminant <= 0.0 && (negative_discriminant_count += 1)
            maximum_beta = max(maximum_beta, beta)
            maximum_pitch = max(maximum_pitch, pitch)
            maximum_balance_residual = max(maximum_balance_residual,
                balance_residual)
            push!(rows, Dict{String,Any}(
                "axial_index" => axial_index, "z_m" => z,
                "normalized_flux_radius" => rho, "position_m" => point,
                "vacuum_field_t" => vacuum_field,
                "pressure_pa" => pressure, "vacuum_beta" => beta,
                "field_pitch" => pitch,
                "equilibrium_field_t" => equilibrium_field,
                "normalized_transverse_balance_residual" => balance_residual,
                "positive_magnetic_pressure_discriminant" =>
                    magnetic_discriminant > 0.0))
        end
    end
    maximum_wall_fill = maximum(tube_radii) / minor
    hard_failure = negative_discriminant_count > 0 ||
        maximum_wall_fill >= Float64(limits["maximum_wall_fill_fraction"])
    outside_validity = maximum_beta > Float64(limits["maximum_beta"]) ||
        maximum_pitch > Float64(limits["maximum_field_pitch"]) ||
        maximum_tube_slope > Float64(limits["maximum_flux_tube_slope"])
    evidence = Dict{String,Any}(
        "model_id" => input["model_id"], "solver_input" => input,
        "candidate_bound" => true, "device_family_routing_used" => false,
        "axis_z_m" => z_values, "axis_vacuum_field_t" => axis_fields,
        "flux_tube_radius_m" => tube_radii,
        "reference_flux_tube_radius_m" => reference_radius,
        "maximum_flux_tube_wall_fill_fraction" => maximum_wall_fill,
        "maximum_flux_tube_slope" => maximum_tube_slope,
        "maximum_sampled_vacuum_beta" => maximum_beta,
        "maximum_sampled_field_pitch" => maximum_pitch,
        "maximum_normalized_transverse_balance_residual" =>
            maximum_balance_residual,
        "negative_magnetic_pressure_discriminant_count" =>
            negative_discriminant_count,
        "sample_count" => length(rows), "samples" => rows,
        "declared_paraxial_finite_pressure_credit" =>
            (!hard_failure && !outside_validity ? 1.0 : 0.0),
        "full_open_field_equilibrium_credit" => 0.0,
        "anisotropic_pressure_credit" => 0.0,
        "ambipolar_credit" => 0.0, "kinetic_credit" => 0.0,
        "stability_credit" => 0.0)
    if hard_failure
        return _v85_gate_record("open_field_finite_pressure_capability", "fail",
            negative_discriminant_count > 0 ?
                "finite_pressure_exceeds_local_vacuum_magnetic_pressure" :
                "finite_pressure_flux_tube_intersects_declared_wall_margin";
            solver_input_hash = input_hash, evidence = evidence)
    elseif outside_validity
        missing = String[]
        maximum_beta > Float64(limits["maximum_beta"]) && push!(missing,
            "higher_fidelity_finite_beta_equilibrium")
        maximum_pitch > Float64(limits["maximum_field_pitch"]) && push!(missing,
            "nonparaxial_open_field_equilibrium")
        maximum_tube_slope > Float64(limits["maximum_flux_tube_slope"]) &&
            push!(missing, "nonparaxial_flux_tube_geometry")
        return _v85_gate_record("open_field_finite_pressure_capability", "unknown",
            "candidate_outside_paraxial_scalar_pressure_validity_domain";
            solver_input_hash = input_hash, evidence = evidence,
            missing_requirements = sort!(unique(missing)))
    end
    return _v85_gate_record("open_field_finite_pressure_capability", "pass",
        "paraxial_scalar_pressure_flux_tube_balance_accepted";
        solver_input_hash = input_hash, evidence = evidence)
end

function poincare_acquisition_metrics_v86(gate)
    evidence = get(get(gate, "evidence", Dict{String,Any}()),
        "poincare_evidence", Dict{String,Any}())
    traces = get(evidence, "traces", Any[])
    target_turns = Int(get(evidence, "target_toroidal_turns", 1))
    steps_per_turn = Int(get(evidence, "steps_per_turn", 1))
    expected_steps = max(1, target_turns * steps_per_turn)
    completion = isempty(traces) ? 0.0 : minimum(min(1.0,
        Float64(get(trace, "completed_steps", 0)) / expected_steps) for trace in traces)
    transform = Float64(get(evidence,
        "minimum_absolute_rotational_transform", 0.0))
    maximum_radius = get(evidence, "maximum_normalized_minor_radius", nothing)
    wall_margin = maximum_radius === nothing ? 0.0 : max(0.0, 1.0 -
        Float64(maximum_radius))
    ordering = Float64(get(evidence, "surface_ordering_fraction", 0.0))
    residual = get(evidence, "maximum_fourier_residual", nothing)
    spread = get(evidence, "maximum_repeated_bin_radial_spread", nothing)
    drift = get(evidence, "maximum_secular_residual_drift_per_turn", nothing)
    score = [get(evidence, "any_trace_escaped", true) === true ? 1.0 : 0.0,
        1.0 - completion, max(0.0, 0.02 - transform),
        residual === nothing ? 1.0 : Float64(residual),
        spread === nothing ? 1.0 : Float64(spread),
        drift === nothing ? 1.0 : abs(Float64(drift)),
        1.0 - ordering, -wall_margin]
    return Dict{String,Any}(
        "short_horizon_only" => target_turns < 128,
        "minimum_trace_completion_fraction" => completion,
        "minimum_absolute_rotational_transform" => transform,
        "minimum_sampled_wall_margin_fraction" => wall_margin,
        "surface_ordering_fraction" => ordering,
        "maximum_fourier_residual" => residual,
        "maximum_repeated_bin_radial_spread" => spread,
        "maximum_secular_residual_drift_per_turn" => drift,
        "acquisition_score_lexicographic" => score,
        "feasibility_credit" => false)
end

function compile_v86_basis_feedback_v1(request::CandidateSolveRequestV86,
        poincare_gate)
    status = String(poincare_gate["status"])
    classification = String(get(poincare_gate, "classification_code", ""))
    shaping_failures = Set([
        "periodic_magnetic_axis_not_located",
        "poincare_field_line_escape",
        "insufficient_long_horizon_rotational_transform",
        "insufficient_poloidal_recurrence_coverage",
        "stochastic_or_broken_poincare_surface",
        "secular_cross_surface_drift",
        "loss_of_nested_poincare_surface_ordering"])
    mechanism_allows_expansion = status == "fail" &&
        classification in shaping_failures
    promote = mechanism_allows_expansion && request.basis_level < 3
    trigger = if promote
        request.basis_level == 2 ?
            "poincare_shaping_failure_replace_retired_coil_current_potential_grammar" :
            "poincare_shaping_failure_expand_next_sampling_basis"
    elseif status in ("unsupported", "unknown")
        "evidence_or_capability_gap_no_basis_expansion"
    elseif !mechanism_allows_expansion && status != "pass"
        "non_shaping_failure_no_basis_expansion"
    else
        "retain_basis_level"
    end
    body = Dict{String,Any}(
        "request_hash" => request.request_hash,
        "source_basis_level" => request.basis_level,
        "recommended_basis_level" => promote ? request.basis_level + 1 :
            request.basis_level,
        "recommended_base_coil_count" => promote ? request.base_coil_count + 4 :
            request.base_coil_count,
        "recommended_winding_model" => promote && request.basis_level == 2 ?
            "winding_surface_current_potential_level_set_filaments_v7" :
            get(request.basis_override === nothing ? Dict{String,Any}() :
                request.basis_override, "winding_model",
                "v85_joint_base_helical_low_order_filaments_v1"),
        "trigger" => trigger, "source_gate_status" => status,
        "source_classification_code" => classification,
        "mechanism_allows_basis_expansion" => mechanism_allows_expansion,
        "source_gate_evidence_hash" => poincare_gate["evidence_hash"],
        "retroactive_feasibility_credit" => false,
        "applies_to_next_request_only" => true)
    body["feedback_hash"] = canonical_hash(body)
    return body
end

function _v86_not_admitted_gate(gate_id, upstream)
    return _v85_gate_record(gate_id, "not_admitted",
        "upstream_$(upstream)_not_passed";
        missing_requirements = ["$(upstream)_pass"])
end

function _v86_not_scheduled_gate(gate_id, scheduled_gate)
    return _v85_gate_record(gate_id, "not_scheduled",
        "beyond_current_stage_frontier";
        missing_requirements = ["promotion_after_$(scheduled_gate)_merge"])
end

function _v86_execute_request(request::CandidateSolveRequestV86, topology,
        compilation, grammar; cache_root, maximum_sweeps::Integer = 1,
        maximum_evaluations::Integer = 20,
        poincare_steps_per_turn::Integer = 180, execute_desc::Bool = true,
        scheduled_gate::Union{Nothing,AbstractString} = nothing,
        design_execution_policy::AbstractString =
            "joint_optimize_and_reaudit_v1")
    chain = request.capability_signature.required_hard_gate_chain
    target_gate = scheduled_gate === nothing ? last(chain) : String(scheduled_gate)
    target_index = findfirst(==(target_gate), chain)
    target_index === nothing && throw(ArgumentError(
        "scheduled gate $target_gate is not applicable to this request"))
    acquisition_turns = target_gate == "poincare_32" ? 8 :
        target_gate == "poincare_64" ? 16 :
        target_gate == "poincare_128" ? 32 : 2
    toroidal = request.capability_signature.geometry_class ==
        "toroidal_volume_v1"
    capability_acquisition = toroidal ? nothing :
        _v86_open_end_loss_acquisition_v1
    frozen_design = design_execution_policy in (
        "frozen_promoted_design_reaudit_v1",
        "frozen_declared_design_reaudit_v1")
    design_execution_policy in ("joint_optimize_and_reaudit_v1",
        "frozen_promoted_design_reaudit_v1",
        "frozen_declared_design_reaudit_v1") || throw(ArgumentError(
        "unknown v86 design execution policy $design_execution_policy"))
    effective_sweeps = frozen_design ? 0 : maximum_sweeps
    effective_evaluations = frozen_design ? 1 : maximum_evaluations
    optimization = optimize_joint_physical_design_v85(topology, compilation,
        grammar, request.initial_design; maximum_sweeps = effective_sweeps,
        maximum_evaluations = effective_evaluations,
        parameter_binding_seed = v85_physical_variant_parameter_seed_v1(
            request.structure_hash, request.physical_variant),
        basis_override = request.basis_override,
        base_coil_count = request.base_coil_count,
        poincare_aware_acquisition = toroidal,
        capability_acquisition = capability_acquisition,
        acquisition_toroidal_turns = acquisition_turns,
        acquisition_steps_per_turn = min(120, poincare_steps_per_turn))
    frozen_design && String(optimization["optimized_design"].design_hash) !=
        String(request.initial_design.design_hash) && throw(ArgumentError(
        "frozen promoted design changed during v86 execution"))
    design = optimization["optimized_design"]
    compiled = optimization["final_evaluation"]["compiled"]
    field_hash = v85_solver_input_hashes_v1(compiled)["field_solver_input_hash"]
    cache_hits = Dict{String,Bool}(); cache_objects = Dict{String,String}()
    solver_hashes = Dict{String,String}("finite_filament_field" => field_hash)
    field_result = _v86_cached_execution(cache_root, "finite_filament_field",
        field_hash) do
        evaluate_v85_biot_savart_gate_v1(compiled)
    end
    biot = field_result.payload; cache_hits["finite_filament_field"] =
        field_result.cache_hit
    cache_objects["finite_filament_field"] = field_result.cache_object_hash
    gates = Dict{String,Any}("finite_filament_field" => biot)
    acquisition = Dict{String,Any}(); feedback_source = nothing

    if request.capability_signature.geometry_class == "toroidal_volume_v1"
        upstream_pass = String(biot["status"]) == "pass"
        for (offset, turns) in enumerate((32, 64, 128))
            stage = "poincare_$turns"
            stage_index = offset + 1
            gate = if stage_index > target_index
                cache_hits[stage] = false
                _v86_not_scheduled_gate(stage, target_gate)
            elseif upstream_pass
                budget = Dict{String,Any}("turns" => turns,
                    "steps_per_turn" => poincare_steps_per_turn,
                    "fourier_order" => 4, "bin_count" => 16,
                    "boundary_frame_semantics" =>
                        "candidate_bound_periodic_axis_elliptic_v3")
                input_hash = v85_solver_input_hashes_v1(compiled;
                    poincare_budget = budget)["poincare_solver_input_hash"]
                solver_hashes[stage] = input_hash
                result = _v86_cached_execution(cache_root, stage, input_hash) do
                    evaluate_v85_poincare_gate_v1(compiled, biot;
                        target_toroidal_turns = turns,
                        steps_per_turn = poincare_steps_per_turn,
                        fourier_order = 4, bin_count = 16)
                end
                cache_hits[stage] = result.cache_hit
                cache_objects[stage] = result.cache_object_hash
                result.payload
            else
                cache_hits[stage] = false
                _v86_not_admitted_gate(stage, turns == 32 ?
                    "finite_filament_field" : "poincare_$(turns ÷ 2)")
            end
            gates[stage] = gate
            if !(String(gate["status"]) in ("not_admitted", "not_scheduled"))
                acquisition[stage] = poincare_acquisition_metrics_v86(gate)
            end
            if !(String(gate["status"]) in ("pass", "not_admitted",
                    "not_scheduled")) &&
                    feedback_source === nothing
                feedback_source = gate
            end
            upstream_pass = upstream_pass && String(gate["status"]) == "pass"
        end
        p128 = gates["poincare_128"]
        equilibrium = if target_index < 5
            cache_hits["finite_pressure_equilibrium"] = false
            _v86_not_scheduled_gate("finite_pressure_equilibrium", target_gate)
        elseif String(p128["status"]) == "pass"
            input = compile_v85_desc_equilibrium_input_v1(design, compiled, p128)
            input_hash = canonical_hash(input)
            solver_hashes["finite_pressure_equilibrium"] = input_hash
            if execute_desc
                result = _v86_cached_execution(cache_root,
                    "finite_pressure_equilibrium", input_hash) do
                    evaluate_v85_desc_equilibrium_gate_v1(design, compiled, p128;
                        execute_solver = true)
                end
                cache_hits["finite_pressure_equilibrium"] = result.cache_hit
                cache_objects["finite_pressure_equilibrium"] =
                    result.cache_object_hash
                result.payload
            else
                result = _v86_cached_execution_if_present(cache_root,
                    "finite_pressure_equilibrium", input_hash)
                if result === nothing
                    cache_hits["finite_pressure_equilibrium"] = false
                    evaluate_v85_desc_equilibrium_gate_v1(design, compiled,
                        p128; execute_solver = false)
                else
                    cache_hits["finite_pressure_equilibrium"] = true
                    cache_objects["finite_pressure_equilibrium"] =
                        result.cache_object_hash
                    result.payload
                end
            end
        else
            cache_hits["finite_pressure_equilibrium"] = false
            _v86_not_admitted_gate("finite_pressure_equilibrium", "poincare_128")
        end
        gates["finite_pressure_equilibrium"] = equilibrium
        stability = if target_index < 6
            cache_hits["sampled_ideal_mhd_stability"] = false
            _v86_not_scheduled_gate("sampled_ideal_mhd_stability", target_gate)
        elseif String(equilibrium["status"]) == "pass"
            input = compile_v85_desc_stability_input_v1(design, compiled, p128,
                equilibrium)
            input_hash = canonical_hash(input)
            solver_hashes["sampled_ideal_mhd_stability"] = input_hash
            if execute_desc
                result = _v86_cached_execution(cache_root,
                    "sampled_ideal_mhd_stability", input_hash) do
                    evaluate_v85_desc_stability_gate_v1(design, compiled, p128,
                        equilibrium; execute_solver = true)
                end
                cache_hits["sampled_ideal_mhd_stability"] = result.cache_hit
                cache_objects["sampled_ideal_mhd_stability"] =
                    result.cache_object_hash
                result.payload
            else
                result = _v86_cached_execution_if_present(cache_root,
                    "sampled_ideal_mhd_stability", input_hash)
                if result === nothing
                    cache_hits["sampled_ideal_mhd_stability"] = false
                    evaluate_v85_desc_stability_gate_v1(design, compiled, p128,
                        equilibrium; execute_solver = false)
                else
                    cache_hits["sampled_ideal_mhd_stability"] = true
                    cache_objects["sampled_ideal_mhd_stability"] =
                        result.cache_object_hash
                    result.payload
                end
            end
        else
            cache_hits["sampled_ideal_mhd_stability"] = false
            _v86_not_admitted_gate("sampled_ideal_mhd_stability",
                "finite_pressure_equilibrium")
        end
        gates["sampled_ideal_mhd_stability"] = stability
    else
        open_gate = if target_index < 2
            cache_hits["open_field_end_loss"] = false
            _v86_not_scheduled_gate("open_field_end_loss", target_gate)
        elseif String(biot["status"]) == "pass"
            open_hash = v86_open_field_solver_input_hash_v1(compiled, field_hash)
            solver_hashes["open_field_end_loss"] = open_hash
            result = _v86_cached_execution(cache_root, "open_field_end_loss",
                open_hash) do
                evaluate_open_field_end_loss_gate_v86(compiled, biot)
            end
            cache_hits["open_field_end_loss"] = result.cache_hit
            cache_objects["open_field_end_loss"] = result.cache_object_hash
            result.payload
        else
            cache_hits["open_field_end_loss"] = false
            _v86_not_admitted_gate("open_field_end_loss",
                "finite_filament_field")
        end
        gates["open_field_end_loss"] = open_gate
        open_finite_pressure = if target_index < 3
            cache_hits["open_field_finite_pressure_capability"] = false
            _v86_not_scheduled_gate("open_field_finite_pressure_capability",
                target_gate)
        elseif String(open_gate["status"]) == "pass"
            input = compile_open_field_paraxial_finite_pressure_input_v1(compiled,
                biot)
            input_hash = String(input["solver_input_hash"])
            solver_hashes["open_field_finite_pressure_capability"] = input_hash
            result = _v86_cached_execution(cache_root,
                "open_field_finite_pressure_capability", input_hash) do
                evaluate_open_field_paraxial_finite_pressure_gate_v1(compiled,
                    biot, open_gate)
            end
            cache_hits["open_field_finite_pressure_capability"] = result.cache_hit
            cache_objects["open_field_finite_pressure_capability"] =
                result.cache_object_hash
            result.payload
        else
            cache_hits["open_field_finite_pressure_capability"] = false
            _v86_not_admitted_gate("open_field_finite_pressure_capability",
                "open_field_end_loss")
        end
        gates["open_field_finite_pressure_capability"] = open_finite_pressure
    end

    all_pass = if request.capability_signature.geometry_class ==
            "toroidal_volume_v1"
        all(String(gates[id]["status"]) == "pass" for id in
            ("finite_filament_field", "poincare_32", "poincare_64",
                "poincare_128", "finite_pressure_equilibrium",
                "sampled_ideal_mhd_stability"))
    else
        all(String(gates[id]["status"]) == "pass" for id in
            ("finite_filament_field", "open_field_end_loss",
                "open_field_finite_pressure_capability"))
    end
    complexity = if all_pass && request.capability_signature.minimality_eligible
        old_chain = Dict{String,Any}(
            "finite_filament_biot_savart" => gates["finite_filament_field"],
            "poincare_nested_surfaces" => gates["poincare_128"],
            "finite_pressure_equilibrium" => gates[
                "finite_pressure_equilibrium"],
            "sampled_ideal_mhd_stability" => gates[
                "sampled_ideal_mhd_stability"])
        actual_device_complexity_manifest_to_dict_v2(
            compile_actual_device_complexity_manifest_v2(design, compiled,
                old_chain))
    else
        nothing
    end
    feedback = feedback_source === nothing ? nothing :
        compile_v86_basis_feedback_v1(request, feedback_source)
    optimization_record = Dict{String,Any}(
        "optimizer" => optimization["optimizer"],
        "evaluations" => optimization["evaluations"],
        "evaluated_coordinate_names" => optimization[
            "evaluated_coordinate_names"],
        "initial_rank" => optimization["initial_rank"],
        "final_rank" => optimization["final_rank"],
        "optimized_basis_override_hash" => optimization[
            "optimized_basis_override_hash"],
        "global_resampling_evaluations" => optimization[
            "global_resampling_evaluations"],
        "poincare_aware_acquisition" => toroidal,
        "capability_acquisition_model_id" => toroidal ? nothing :
            "candidate_bound_open_end_loss_acquisition_v1",
        "final_capability_acquisition" => optimization["final_evaluation"][
            "capability_acquisition"],
        "acquisition_toroidal_turns" => acquisition_turns,
        "acquisition_steps_per_turn" => min(120,
            poincare_steps_per_turn),
        "acquisition_only" => true, "trace" => optimization["trace"])
    return Dict{String,Any}(
        "request_hash" => request.request_hash,
        "request_index" => request.request_index,
        "structure_seed" => request.structure_seed,
        "structure_hash" => request.structure_hash,
        "grammar_hash" => request.grammar_hash,
        "capability_signature_hash" => request.capability_signature.
            capability_signature_hash,
        "capability_cell_hash" => request.capability_signature.capability_cell_hash,
        "budget_stratum_hash" => request.capability_signature.budget_stratum_hash,
        "comparison_scope_hash" => request.capability_signature.
            comparison_scope_hash,
        "minimality_eligible" => request.capability_signature.minimality_eligible,
        "minimality_exclusion_reasons" => request.capability_signature.
            exclusion_reasons,
        "physical_variant" => request.physical_variant,
        "operating_variant" => request.operating_variant,
        "control_variant" => request.control_variant, "route" => request.route,
        "basis_level" => request.basis_level,
        "scheduled_gate" => target_gate,
        "scheduled_gate_status" => String(gates[target_gate]["status"]),
        "scheduled_gate_passed" => String(gates[target_gate]["status"]) == "pass",
        "optimized_design" => candidate_joint_design_to_dict_v1(design),
        "optimized_basis_override" => optimization[
            "optimized_basis_override"],
        "optimization" => optimization_record,
        "design_execution_policy" => String(design_execution_policy),
        "solver_input_hashes" => solver_hashes,
        "cache_hits" => cache_hits, "cache_object_hashes" => cache_objects,
        "gate_chain" => gates, "poincare_acquisition" => acquisition,
        "basis_feedback" => feedback,
        "all_required_hard_gates_pass" => all_pass,
        "complexity_manifest" => complexity,
        "retroactive_feasibility_credit" => false,
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
end

function run_v86_campaign_shard_v1(campaign, shard_id::Integer,
        first_schedule_position::Integer, last_schedule_position::Integer;
        output_directory::AbstractString, cache_directory::AbstractString =
            joinpath(output_directory, "solver_cache"),
        checkpoint_interval::Integer = 5, resume::Bool = true,
        stop_after_candidates::Union{Nothing,Integer} = nothing,
        maximum_sweeps::Integer = 1, maximum_evaluations::Integer = 20,
        poincare_steps_per_turn::Integer = 180, execute_desc::Bool = true)
    shard_id > 0 || throw(ArgumentError("v86 shard_id must be positive"))
    checkpoint_interval > 0 || throw(ArgumentError(
        "v86 checkpoint_interval must be positive"))
    schedule = Int.(campaign["specification"]["fair_schedule_request_indices"])
    1 <= first_schedule_position <= last_schedule_position <= length(schedule) ||
        throw(ArgumentError("invalid v86 shard schedule range"))
    by_index = Dict(Int(item["request_index"]) => item for item in
        campaign["requests"])
    mkpath(output_directory); mkpath(cache_directory)
    prefix = "v86_campaign_shard_$(lpad(Int(shard_id), 3, '0'))"
    partial_path = joinpath(output_directory, prefix * ".jsonl.partial")
    stream_path = joinpath(output_directory, prefix * ".jsonl")
    summary_path = joinpath(output_directory, prefix * ".summary.json")
    if isfile(summary_path) && isfile(stream_path)
        summary = _stage3_plain_v1(JSON3.read(read(summary_path, String),
            Dict{String,Any}))
        String(summary["campaign_hash"]) == String(campaign["campaign_hash"]) ||
            throw(ArgumentError("completed v86 shard campaign mismatch"))
        String(summary["stream_sha256"]) == _s70_file_sha256(stream_path) ||
            throw(ArgumentError("completed v86 shard stream mismatch"))
        return summary
    end
    !resume && isfile(partial_path) && rm(partial_path; force = true)
    previous = resume ? _v84_read_valid_json_lines(partial_path; repair = true) :
        Dict{String,Any}[]
    expected_positions = collect(Int(first_schedule_position):
        Int(first_schedule_position) + length(previous) - 1)
    Int.(getindex.(previous, "schedule_position")) == expected_positions ||
        throw(ArgumentError("partial v86 shard is not contiguous"))
    start_position = Int(first_schedule_position) + length(previous)
    added = 0; interrupted = false; start_time = time()
    open(partial_path, isempty(previous) ? "w" : "a") do io
        for position in start_position:Int(last_schedule_position)
            request_raw = by_index[schedule[position]]
            restored = _v86_restore_request(request_raw)
            row = try
                _v86_execute_request(restored.request, restored.topology,
                    restored.compilation, restored.grammar;
                    cache_root = cache_directory, maximum_sweeps = maximum_sweeps,
                    maximum_evaluations = maximum_evaluations,
                    poincare_steps_per_turn = poincare_steps_per_turn,
                    execute_desc = execute_desc,
                    scheduled_gate = get(request_raw, "scheduled_gate", nothing),
                    design_execution_policy = get(request_raw,
                        "design_execution_policy",
                        "joint_optimize_and_reaudit_v1"))
            catch error
                Dict{String,Any}(
                    "request_hash" => request_raw["request_hash"],
                    "request_index" => request_raw["request_index"],
                    "structure_seed" => request_raw["structure_seed"],
                    "structure_hash" => request_raw["structure_hash"],
                    "capability_cell_hash" => request_raw["capability_signature"][
                        "capability_cell_hash"],
                    "budget_stratum_hash" => request_raw["capability_signature"][
                        "budget_stratum_hash"],
                    "comparison_scope_hash" => request_raw["capability_signature"][
                        "comparison_scope_hash"],
                    "scheduled_gate" => get(request_raw, "scheduled_gate",
                        last(request_raw["capability_signature"][
                            "required_hard_gate_chain"])),
                    "scheduled_gate_status" => "exception",
                    "scheduled_gate_passed" => false,
                    "all_required_hard_gates_pass" => false,
                    "complexity_manifest" => nothing,
                    "classification_code" =>
                        "uncaught_$(nameof(typeof(error)))",
                    "exception_type" => String(nameof(typeof(error))),
                    "exception_message" => sprint(showerror, error),
                    "retroactive_feasibility_credit" => false,
                    "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
            end
            row["schema_version"] = "1.0.0"; row["shard_id"] = Int(shard_id)
            row["schedule_position"] = position
            row = _v86_json_plain(row)
            row["record_hash"] = _v84_record_hash(row)
            _v84_write_json_line(io, row); added += 1
            added % checkpoint_interval == 0 && flush(io)
            if stop_after_candidates !== nothing && added >= stop_after_candidates
                flush(io); interrupted = true; break
            end
        end
        flush(io)
    end
    if interrupted
        return Dict{String,Any}(
            "status" => "interrupted", "shard_id" => Int(shard_id),
            "processed_count" => length(previous) + added,
            "partial_path" => partial_path,
            "campaign_hash" => campaign["campaign_hash"],
            "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
    end
    mv(partial_path, stream_path; force = true)
    rows = _v84_read_valid_json_lines(stream_path)
    summary = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "stage" => "v86_multitopology_campaign", "shard_id" => Int(shard_id),
        "first_schedule_position" => Int(first_schedule_position),
        "last_schedule_position" => Int(last_schedule_position),
        "candidate_count" => length(rows),
        "campaign_hash" => String(campaign["campaign_hash"]),
        "cache_directory" => abspath(cache_directory),
        "hard_gate_pass_count" => count(row -> get(row,
            "all_required_hard_gates_pass", false) === true, rows),
        "uncaught_exception_count" => count(row -> startswith(String(get(row,
            "classification_code", "")), "uncaught_"), rows),
        "stream_sha256" => _s70_file_sha256(stream_path),
        "elapsed_seconds" => time() - start_time,
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
    deterministic = Dict{String,Any}(key => value for (key, value) in summary if
        !(key in ("elapsed_seconds", "cache_directory")))
    summary["shard_result_hash"] = canonical_hash(deterministic)
    _stage3_atomic_json_v1(summary_path, summary)
    return summary
end

function _v86_complexity_tuple(raw)
    return (Int(raw["component_count"]), Int(raw["power_supply_count"]),
        Float64(raw["conductor_length_m"]),
        Float64(raw["maximum_curvature_m_inv"]),
        Float64(raw["support_mass_kg"]), Int(raw["control_complexity"]))
end

function _v86_nondominated(rows)
    unique_rows = Dict{String,Any}[]; seen = Set{String}()
    for row in sort!(copy(rows); by = item -> String(item[
            "optimized_design"]["design_hash"]))
        vector_hash = canonical_hash(collect(_v86_complexity_tuple(row[
            "complexity_manifest"])))
        vector_hash in seen && continue
        push!(seen, vector_hash); push!(unique_rows, row)
    end
    result = Dict{String,Any}[]
    for (index, row) in enumerate(unique_rows)
        target = _v86_complexity_tuple(row["complexity_manifest"])
        dominated = any(other_index != index && begin
            source = _v86_complexity_tuple(unique_rows[other_index][
                "complexity_manifest"])
            all(source[i] <= target[i] for i in eachindex(source)) &&
                any(source[i] < target[i] for i in eachindex(source))
        end for other_index in eachindex(unique_rows))
        dominated || push!(result, row)
    end
    sort!(result; by = row -> (_v86_complexity_tuple(row[
        "complexity_manifest"]), String(row["optimized_design"]["design_hash"])))
    return result
end

function _v86_firewall_audit(rows)
    violations = String[]
    deferred(status) = String(status) in ("not_admitted", "not_scheduled")
    for row in rows
        haskey(row, "gate_chain") || continue
        gates = row["gate_chain"]
        if haskey(gates, "poincare_32")
            String(gates["finite_filament_field"]["status"]) == "pass" ||
                deferred(gates["poincare_32"]["status"]) ||
                push!(violations, "poincare32_without_field:$(row["request_hash"])")
            String(gates["poincare_32"]["status"]) == "pass" ||
                deferred(gates["poincare_64"]["status"]) ||
                push!(violations, "poincare64_without_32:$(row["request_hash"])")
            String(gates["poincare_64"]["status"]) == "pass" ||
                deferred(gates["poincare_128"]["status"]) ||
                push!(violations, "poincare128_without_64:$(row["request_hash"])")
            String(gates["poincare_128"]["status"]) == "pass" ||
                String(gates["finite_pressure_equilibrium"]["status"]) ==
                    "not_admitted" || String(gates[
                    "finite_pressure_equilibrium"]["status"]) ==
                    "not_scheduled" || push!(violations,
                    "equilibrium_without_128:$(row["request_hash"])")
            String(gates["finite_pressure_equilibrium"]["status"]) == "pass" ||
                String(gates["sampled_ideal_mhd_stability"]["status"]) ==
                    "not_admitted" || String(gates[
                    "sampled_ideal_mhd_stability"]["status"]) ==
                    "not_scheduled" || push!(violations,
                    "stability_without_equilibrium:$(row["request_hash"])")
        end
        get(row, "complexity_manifest", nothing) === nothing ||
            get(row, "all_required_hard_gates_pass", false) === true ||
            push!(violations, "complexity_before_hard_gates:$(row["request_hash"])")
        get(row, "retroactive_feasibility_credit", true) === false ||
            push!(violations, "retroactive_credit:$(row["request_hash"])")
    end
    return sort!(unique(violations))
end

function merge_v86_campaign_shards_v1(campaign;
        output_directory::AbstractString, expected_shard_ids,
        expected_candidate_count::Integer = length(campaign["requests"]))
    rows = Dict{String,Any}[]; shard_hashes = String[]
    for shard_id in sort!(unique(Int.(collect(expected_shard_ids))))
        prefix = "v86_campaign_shard_$(lpad(shard_id, 3, '0'))"
        stream_path = joinpath(output_directory, prefix * ".jsonl")
        summary_path = joinpath(output_directory, prefix * ".summary.json")
        isfile(stream_path) && isfile(summary_path) || throw(ArgumentError(
            "missing completed v86 shard $shard_id"))
        summary = _stage3_plain_v1(JSON3.read(read(summary_path, String),
            Dict{String,Any}))
        String(summary["campaign_hash"]) == String(campaign["campaign_hash"]) ||
            throw(ArgumentError("v86 shard campaign hash mismatch"))
        String(summary["stream_sha256"]) == _s70_file_sha256(stream_path) ||
            throw(ArgumentError("v86 shard stream hash mismatch"))
        append!(rows, _v84_read_valid_json_lines(stream_path))
        push!(shard_hashes, String(summary["shard_result_hash"]))
    end
    sort!(rows; by = row -> Int(row["schedule_position"]))
    Int.(getindex.(rows, "schedule_position")) == collect(1:expected_candidate_count) ||
        throw(ArgumentError("v86 shards do not exactly cover the fair schedule"))
    length(unique(String(row["request_hash"]) for row in rows)) == length(rows) ||
        throw(ArgumentError("duplicate v86 request across shards"))
    expected_hashes = Set(String(item["request_hash"]) for item in
        campaign["requests"])
    Set(String(row["request_hash"]) for row in rows) == expected_hashes ||
        throw(ArgumentError("v86 merged request set differs from campaign"))
    violations = _v86_firewall_audit(rows)
    isempty(violations) || throw(ArgumentError(
        "v86 evidence firewall violation: $(join(violations, ';'))"))

    stage_status = Dict{String,Dict{String,Int}}()
    cache_keys = Dict{String,Set{String}}(); cache_hits = Dict{String,Int}()
    cache_misses = Dict{String,Int}(); miss_by_input = Dict{String,Int}()
    for row in rows
        for (stage, gate) in get(row, "gate_chain", Dict{String,Any}())
            status = String(get(gate, "status", "missing"))
            histogram = get!(stage_status, String(stage), Dict{String,Int}())
            histogram[status] = get(histogram, status, 0) + 1
        end
        for (stage, object_hash) in get(row, "cache_object_hashes",
                Dict{String,Any}())
            input_hash = String(row["solver_input_hashes"][stage])
            push!(get!(cache_keys, String(stage), Set{String}()), input_hash)
            hit = Bool(get(row["cache_hits"], stage, false))
            if hit
                cache_hits[String(stage)] = get(cache_hits, String(stage), 0) + 1
            else
                cache_misses[String(stage)] = get(cache_misses, String(stage), 0) + 1
                key = "$(stage)|$input_hash"
                miss_by_input[key] = get(miss_by_input, key, 0) + 1
            end
            length(String(object_hash)) == 64 || throw(ArgumentError(
                "invalid v86 cache object hash"))
        end
    end
    duplicate_execution_keys = sort!(String[key for (key, count) in miss_by_input if
        count > 1])
    isempty(duplicate_execution_keys) || throw(ArgumentError(
        "same v86 solver input executed more than once"))

    request_by_hash = Dict(String(raw["request_hash"]) => raw for raw in
        campaign["requests"])
    frontier_records = Dict{String,Any}[]
    exception_counts_by_cell = Dict{String,Int}()
    for row in rows
        raw = request_by_hash[String(row["request_hash"])]
        chain = String.(raw["capability_signature"]["required_hard_gate_chain"])
        scheduled_gate = String(get(row, "scheduled_gate", last(chain)))
        scheduled_index = findfirst(==(scheduled_gate), chain)
        scheduled_index === nothing && throw(ArgumentError(
            "v86 row scheduled gate is outside its capability chain"))
        next_gate = scheduled_index < length(chain) ? chain[scheduled_index + 1] :
            nothing
        status = String(get(row, "scheduled_gate_status", "exception"))
        classification = String(get(row, "classification_code", ""))
        is_exception = status == "exception" || startswith(classification,
            "uncaught_")
        cell = String(row["capability_cell_hash"])
        is_exception && (exception_counts_by_cell[cell] = get(
            exception_counts_by_cell, cell, 0) + 1)
        rank = if haskey(get(row, "poincare_acquisition", Dict{String,Any}()),
                scheduled_gate)
            Float64.(row["poincare_acquisition"][scheduled_gate][
                "acquisition_score_lexicographic"])
        elseif haskey(get(row, "optimization", Dict{String,Any}()), "final_rank")
            Float64.(row["optimization"]["final_rank"])
        else
            Float64[]
        end
        completed_hash = String(get(get(row, "solver_input_hashes",
            Dict{String,Any}()), scheduled_gate, ""))
        # The capability signature is the execution contract.  Minimality
        # eligibility is a later archive decision and must not truncate a
        # declared, candidate-bound physics chain.
        next_supported = next_gate !== nothing
        promotion_eligible = status == "pass" && next_supported &&
            length(completed_hash) == 64
        disposition = if is_exception
            "exception_not_promoted"
        elseif status != "pass"
            "scheduled_gate_not_passed"
        elseif next_gate === nothing
            "declared_chain_complete"
        elseif !next_supported
            "next_gate_not_declared_supported"
        else
            "eligible_for_budgeted_next_stage"
        end
        record = Dict{String,Any}(
            "request_hash" => row["request_hash"],
            "request_index" => row["request_index"],
            "structure_hash" => get(row, "structure_hash", ""),
            "grammar_hash" => get(row, "grammar_hash", ""),
            "basis_level" => get(row, "basis_level", 0),
            "capability_cell_hash" => cell,
            "budget_stratum_hash" => row["budget_stratum_hash"],
            "comparison_scope_hash" => row["comparison_scope_hash"],
            "scheduled_gate" => scheduled_gate,
            "scheduled_gate_status" => status,
            "poincare_formal_applicable" => "poincare_128" in chain,
            "next_applicable_gate" => next_gate,
            "next_gate_supported" => next_supported,
            "promotion_eligible" => promotion_eligible,
            "completed_solver_input_hash" => completed_hash,
            "frontier_rank" => rank, "is_exception" => is_exception,
            "optimized_design" => get(row, "optimized_design", nothing),
            "optimized_basis_override" => get(row,
                "optimized_basis_override", nothing),
            "disposition" => disposition,
            "retroactive_feasibility_credit" => false)
        record["frontier_record_hash"] = canonical_hash(record)
        push!(frontier_records, record)
    end
    sort!(frontier_records; by = record -> Int(record["request_index"]))

    eligible = [row for row in rows if get(row,
        "all_required_hard_gates_pass", false) === true && get(row,
        "complexity_manifest", nothing) !== nothing]
    grammar_archives = Dict{String,Any}[]
    for grammar_hash in sort!(unique(String(row["grammar_hash"]) for row in eligible))
        group = [row for row in eligible if String(row["grammar_hash"]) == grammar_hash]
        pareto = _v86_nondominated(group)
        push!(grammar_archives, Dict{String,Any}(
            "scope" => "same_grammar_same_gate_depth",
            "grammar_hash" => grammar_hash, "eligible_count" => length(group),
            "pareto_design_hashes" => [row["optimized_design"]["design_hash"]
                for row in pareto]))
    end
    cell_archives = Dict{String,Any}[]
    for cell_hash in sort!(unique(String(row["capability_cell_hash"]) for row in eligible))
        group = [row for row in eligible if String(row[
            "capability_cell_hash"]) == cell_hash]
        pareto = _v86_nondominated(group)
        push!(cell_archives, Dict{String,Any}(
            "scope" => "same_capability_signature_cross_topology",
            "capability_cell_hash" => cell_hash,
            "eligible_count" => length(group),
            "pareto_design_hashes" => [row["optimized_design"]["design_hash"]
                for row in pareto]))
    end
    comparison_archives = Dict{String,Any}[]
    for scope_hash in sort!(unique(String(row["comparison_scope_hash"]) for row in
            eligible))
        group = [row for row in eligible if String(row[
            "comparison_scope_hash"]) == scope_hash]
        pareto = _v86_nondominated(group)
        push!(comparison_archives, Dict{String,Any}(
            "scope" => "same_declared_hard_chain_and_evidence_depth_cross_topology",
            "comparison_scope_hash" => scope_hash,
            "eligible_count" => length(group),
            "source_capability_cell_hashes" => sort!(unique(String(row[
                "capability_cell_hash"]) for row in group)),
            "pareto_design_hashes" => [row["optimized_design"]["design_hash"]
                for row in pareto]))
    end
    parallel_cells = sort!(unique(String(row["capability_cell_hash"]) for row in
        rows if haskey(row, "capability_cell_hash")))
    budget_strata = sort!(unique(String(row["budget_stratum_hash"]) for row in
        rows if haskey(row, "budget_stratum_hash")))
    promotions = Dict{String,Any}[]; seen_promotions = Set{String}()
    for row in rows
        feedback = get(row, "basis_feedback", nothing)
        if feedback !== nothing && haskey(row, "request_hash")
            source_raw = request_by_hash[String(row["request_hash"])]
            source_request = _v86_restore_request(source_raw).request
            source_gate_id = String(get(row, "scheduled_gate", ""))
            source_gate = get(get(row, "gate_chain", Dict{String,Any}()),
                source_gate_id, nothing)
            if source_gate !== nothing && startswith(source_gate_id, "poincare_")
                # Feedback is a next-sampling policy, not solver evidence.  It
                # may be deterministically recompiled when a retired grammar is
                # replaced without changing the historical gate result.
                feedback = compile_v86_basis_feedback_v1(source_request,
                    source_gate)
            end
        end
        feedback === nothing && continue
        Int(feedback["recommended_basis_level"]) > Int(feedback[
            "source_basis_level"]) || continue
        source_design = _stage3_plain_v1(row["optimized_design"])
        physics_body = copy(source_design)
        delete!(physics_body, "route"); delete!(physics_body, "design_hash")
        source_basis_override = get(row, "optimized_basis_override",
            get(request_by_hash[String(row["request_hash"])],
                "basis_override", nothing))
        physics_body["basis_override"] = source_basis_override
        physics_design_hash = canonical_hash(physics_body)
        scheduled_gate = String(get(row, "scheduled_gate", ""))
        frontier_rank = haskey(get(row, "poincare_acquisition",
            Dict{String,Any}()), scheduled_gate) ? Float64.(row[
            "poincare_acquisition"][scheduled_gate][
            "acquisition_score_lexicographic"]) : Float64.(row[
            "optimization"]["final_rank"])
        key = canonical_hash(Dict("structure_hash" => row["structure_hash"],
            "source_physics_design_hash" => physics_design_hash,
            "comparison_scope_hash" => row["comparison_scope_hash"],
            "basis_level" => feedback["recommended_basis_level"]))
        key in seen_promotions && continue
        push!(seen_promotions, key)
        push!(promotions, Dict{String,Any}(
            "promotion_key" => key, "request_hash" => row["request_hash"],
            "source_request_hash" => row["request_hash"],
            "structure_seed" => row["structure_seed"],
            "capability_cell_hash" => row["capability_cell_hash"],
            "physical_variant" => row["physical_variant"],
            "operating_variant" => row["operating_variant"],
            "control_variant" => row["control_variant"], "route" => row["route"],
            "basis_level" => feedback["recommended_basis_level"],
            "frontier_rank" => frontier_rank,
            "source_optimized_design" => source_design,
            "source_optimized_basis_override" => source_basis_override,
            "source_physics_design_hash" => physics_design_hash,
            "source_feedback_hash" => feedback["feedback_hash"],
            "retroactive_feasibility_credit" => false))
    end
    rejected_basis_promotions = 0
    if haskey(campaign["specification"], "budget_policy")
        limit = Int(campaign["specification"]["budget_policy"][
            "maximum_basis_upgrades_per_cell"])
        retained = Dict{String,Any}[]
        for cell in sort!(unique(String(item["capability_cell_hash"]) for item in
                promotions))
            group = sort!([item for item in promotions if String(item[
                "capability_cell_hash"]) == cell]; lt = _v86_frontier_rank_lt)
            append!(retained, Iterators.take(group, limit))
            rejected_basis_promotions += max(0, length(group) - limit)
        end
        promotions = retained
    end
    merged_path = joinpath(output_directory, "v86_campaign_merged.jsonl")
    _v84_write_jsonl_atomic(merged_path, rows)
    summary = Dict{String,Any}(
        "schema_version" => "1.0.0", "status" => "complete",
        "campaign_hash" => String(campaign["campaign_hash"]),
        "candidate_count" => length(rows),
        "unique_request_count" => length(unique(String(row["request_hash"])
            for row in rows)),
        "source_shard_hashes" => sort!(shard_hashes),
        "stage_status_histograms" => stage_status,
        "unique_solver_input_counts" => Dict(stage => length(keys) for
            (stage, keys) in cache_keys),
        "cache_hit_counts" => cache_hits,
        "actual_execution_counts" => cache_misses,
        "duplicate_solver_execution_keys" => duplicate_execution_keys,
        "stage_frontier_records" => frontier_records,
        "exception_counts_by_capability_cell" => exception_counts_by_cell,
        "evidence_firewall_passed" => true,
        "retroactive_feasibility_credit" => false,
        "all_hard_gates_pass_count" => length(eligible),
        "grammar_pareto_archives" => grammar_archives,
        "capability_cell_pareto_archives" => cell_archives,
        "comparison_scope_pareto_archives" => comparison_archives,
        "budget_stratum_hashes" => budget_strata,
        "cross_capability_disposition" => Dict(
            "capability_cell_hashes" => parallel_cells,
            "dominance_claimed_across_cells" => false,
            "disposition" => "parallel_candidate_sets"),
        "basis_promotion_requests" => promotions,
        "basis_promotions_rejected_by_budget_count" =>
            rejected_basis_promotions,
        "merged_stream_sha256" => _s70_file_sha256(merged_path),
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
    summary["result_hash"] = canonical_hash(summary)
    _stage3_atomic_json_v1(joinpath(output_directory,
        "v86_campaign_merged.summary.json"), summary)
    return summary
end

function compile_v86_promoted_campaign_v1(parent_campaign, merged_summary)
    String(merged_summary["campaign_hash"]) == String(parent_campaign[
        "campaign_hash"]) || throw(ArgumentError(
        "v86 promotion summary and parent campaign differ"))
    promotions = get(merged_summary, "basis_promotion_requests", Any[])
    requests = Dict{String,Any}[]; topology_rows = Dict{String,Any}[]
    seen_structures = Set{String}(); request_index = 0
    for promotion in sort!(_stage3_plain_v1.(collect(promotions)); by = item ->
            String(item["promotion_key"]))
        seed = Int(promotion["structure_seed"])
        topology = generate_graph_native_topology_v69(seed)
        compilation = compile_graph_native_topology_candidate_v69(topology)
        compilation.status == :pass || continue
        structure_hash = graph_isomorphism_hash_v69(topology)
        if !(structure_hash in seen_structures)
            push!(seen_structures, structure_hash)
            push!(topology_rows, Dict{String,Any}(
                "structure_seed" => seed, "topology_hash" => topology.topology_hash,
                "structure_hash" => structure_hash,
                "compilation_status" => String(compilation.status),
                "classification_code" => compilation.classification_code,
                "isomorphic_duplicate_of_seed" => nothing))
        end
        grammar = compile_joint_optimization_grammar_v1(
            default_candidate_realization_grammar_v2(structure_hash))
        source_design = _v86_joint_design_from_dict(
            promotion["source_optimized_design"], grammar)
        request_index += 1
        request = compile_candidate_solve_request_v86(request_index, seed,
            topology, compilation, grammar, Int(promotion["physical_variant"]),
            Int(promotion["operating_variant"]), Int(promotion["control_variant"]),
            String(promotion["route"]); basis_level = Int(promotion["basis_level"]),
            initial_design_override = source_design,
            parent_basis_override = get(promotion,
                "source_optimized_basis_override", nothing))
        raw = candidate_solve_request_to_dict_v86(request)
        raw["parent_request_hash"] = promotion["source_request_hash"]
        raw["source_feedback_hash"] = promotion["source_feedback_hash"]
        raw["source_physics_design_hash"] = promotion[
            "source_physics_design_hash"]
        raw["frontier_rank"] = promotion["frontier_rank"]
        raw["retroactive_feasibility_credit"] = false
        # Parent links are provenance, not solver identity.
        push!(requests, raw)
    end
    groups = Dict{String,Vector{Dict{String,Any}}}()
    stratum_cells = Dict{String,Set{String}}()
    for request in requests
        cell = String(request["capability_signature"]["capability_cell_hash"])
        push!(get!(groups, cell, Dict{String,Any}[]), request)
        stratum = String(request["capability_signature"]["budget_stratum_hash"])
        push!(get!(stratum_cells, stratum, Set{String}()), cell)
    end
    for rows in values(groups); sort!(rows; by = row -> String(row["request_hash"])); end
    stratum_queues = Dict{String,Vector{Int}}()
    for (stratum, cell_set) in stratum_cells
        queue = Int[]; depth = 1
        while true
            added = false
            for cell in sort!(collect(cell_set))
                depth <= length(groups[cell]) || continue
                push!(queue, Int(groups[cell][depth]["request_index"])); added = true
            end
            added || break
            depth += 1
        end
        stratum_queues[stratum] = queue
    end
    schedule = Int[]; depth = 1
    while length(schedule) < length(requests)
        added = false
        for stratum in sort!(collect(keys(stratum_queues)))
            depth <= length(stratum_queues[stratum]) || continue
            push!(schedule, stratum_queues[stratum][depth]); added = true
        end
        added || break
        depth += 1
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "campaign_kind" => "adaptive_basis_promotion_followup_v1",
        "parent_campaign_hash" => parent_campaign["campaign_hash"],
        "parent_result_hash" => merged_summary["result_hash"],
        "raw_topology_count" => length(topology_rows),
        "unique_structure_count" => length(seen_structures),
        "compile_pass_unique_structure_count" => length(seen_structures),
        "request_count" => length(requests), "topologies" => topology_rows,
        "request_hashes" => [item["request_hash"] for item in requests],
        "capability_cell_count" => length(groups),
        "budget_stratum_count" => length(stratum_queues),
        "fair_schedule_request_indices" => schedule,
        "fairness_policy" => "budget_stratum_then_capability_cell_round_robin_v2",
        "seed_streams_independent" => true,
        "isomorphism_dedup_before_variants" => true,
        "retroactive_feasibility_credit" => false)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "specification" => body,
        "requests" => requests, "campaign_hash" => canonical_hash(body),
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
end

function compile_v86_capability_coverage_manifest_v1(campaign)
    cells = Dict{String,Dict{String,Any}}()
    structures = Dict{String,Set{String}}()
    for request in campaign["requests"]
        signature = request["capability_signature"]
        cell_hash = String(signature["capability_cell_hash"])
        cell = get!(cells, cell_hash, Dict{String,Any}(
            "capability_cell_hash" => cell_hash,
            "budget_stratum_hash" => signature["budget_stratum_hash"],
            "comparison_scope_hash" => signature["comparison_scope_hash"],
            "geometry_class" => signature["geometry_class"],
            "spatial_dimensions" => signature["spatial_dimensions"],
            "time_semantics" => signature["time_semantics"],
            "boundary_kinds" => signature["boundary_kinds"],
            "state_kinds" => signature["state_kinds"],
            "port_kinds" => signature["port_kinds"],
            "capability_ids" => signature["capability_ids"],
            "required_hard_gate_chain" => signature[
                "required_hard_gate_chain"],
            "minimality_eligible" => signature["minimality_eligible"],
            "exclusion_reasons" => signature["exclusion_reasons"],
            "request_count" => 0,
            "executor_coverage" => Dict{String,Any}()))
        cell["request_count"] = Int(cell["request_count"]) + 1
        push!(get!(structures, cell_hash, Set{String}()),
            String(request["structure_hash"]))
    end
    for (cell_hash, cell) in cells
        geometry = String(cell["geometry_class"])
        coverage = Dict{String,Any}(
            "finite_filament_field" => "available_candidate_bound",
            "poincare_nested_surfaces" => geometry == "toroidal_volume_v1" ?
                "available_candidate_bound" : "not_applicable",
            "open_field_end_loss" => geometry == "linear_volume_v1" ?
                "available_candidate_bound" : "not_applicable",
            "open_field_finite_pressure_capability" =>
                geometry == "linear_volume_v1" ?
                "available_candidate_bound_paraxial_screen" : "not_applicable",
            "finite_pressure_equilibrium" => geometry == "toroidal_volume_v1" ?
                "available_candidate_bound_desc" : "unsupported",
            "sampled_ideal_mhd_stability" => geometry == "toroidal_volume_v1" ?
                "available_candidate_bound_desc" : "unsupported")
        cell["executor_coverage"] = coverage
        cell["unique_structure_count"] = length(structures[cell_hash])
        cell["coverage_complete_for_declared_minimality"] = Bool(cell[
            "minimality_eligible"]) && all(value != "unsupported" for value in
            values(coverage))
    end
    rows = sort!(collect(values(cells)); by = item -> String(item[
        "capability_cell_hash"]))
    body = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "campaign_hash" => campaign["campaign_hash"],
        "capability_cell_count" => length(rows), "cells" => rows,
        "budget_stratum_count" => length(unique(String(row[
            "budget_stratum_hash"]) for row in rows)),
        "comparison_scope_count" => length(unique(String(row[
            "comparison_scope_hash"]) for row in rows)),
        "request_count" => length(campaign["requests"]),
        "minimality_eligible_request_count" => count(request -> Bool(request[
            "capability_signature"]["minimality_eligible"]), campaign["requests"]),
        "minimality_excluded_request_count" => count(request -> !Bool(request[
            "capability_signature"]["minimality_eligible"]), campaign["requests"]),
        "routing_inputs" => ["spatial_dimensions", "time_semantics",
            "boundary_kinds", "state_kinds", "port_kinds", "capability_ids",
            "geometry_class", "solver_validity_domain"],
        "device_family_routing_used" => false,
        "cross_capability_pareto_dominance_allowed" => false,
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
    body["coverage_manifest_hash"] = canonical_hash(body)
    return body
end

function compile_v86_search_stop_manifest_v1(batches;
        minimum_unique_biot_pass_inputs::Integer = 500,
        required_consecutive_zero_survival_batches::Integer = 2,
        minimum_unique_inputs_per_basis_basin::Integer = 64)
    minimum_unique_biot_pass_inputs > 0 || throw(ArgumentError(
        "v86 stop-rule field-input threshold must be positive"))
    required_consecutive_zero_survival_batches > 0 || throw(ArgumentError(
        "v86 stop-rule consecutive batch count must be positive"))
    minimum_unique_inputs_per_basis_basin > 0 || throw(ArgumentError(
        "v86 basis-basin input threshold must be positive"))
    batch_values = collect(batches)
    batch_rows = Dict{String,Any}[]
    all_field_pass = Set{String}(); applicable_field_pass = Set{String}()
    all_p128_pass = Set{String}()
    basin_field_inputs = Dict{String,Set{String}}()
    basin_p128_passes = Dict{String,Set{String}}()
    basin_metadata = Dict{String,Dict{String,Any}}()
    for (batch_index, batch_value) in enumerate(batch_values)
        summaries = batch_value isa AbstractDict ? [batch_value] :
            collect(batch_value)
        records = Dict{String,Any}[]
        for summary in summaries
            append!(records, _stage3_plain_v1.(collect(get(summary,
                "stage_frontier_records", Any[]))))
        end
        field_pass = Set{String}(); applicable_pass = Set{String}()
        p32_pass = Set{String}()
        p64_pass = Set{String}(); p128_pass = Set{String}()
        for record in records
            gate = String(record["scheduled_gate"])
            status = String(record["scheduled_gate_status"])
            input_hash = String(record["completed_solver_input_hash"])
            basis_level = Int(get(record, "basis_level", 0))
            poincare_applicable = get(record, "poincare_formal_applicable",
                false) === true
            basin_key = canonical_hash(Dict{String,Any}(
                "comparison_scope_hash" => record["comparison_scope_hash"],
                "basis_level" => basis_level))
            if poincare_applicable
                basin_metadata[basin_key] = Dict{String,Any}(
                    "basis_basin_key" => basin_key,
                    "comparison_scope_hash" => record["comparison_scope_hash"],
                    "basis_level" => basis_level)
            end
            if gate == "finite_filament_field" && status == "pass" &&
                    length(input_hash) == 64
                push!(field_pass, input_hash); push!(all_field_pass, input_hash)
                if poincare_applicable
                    push!(applicable_pass, input_hash)
                    push!(applicable_field_pass, input_hash)
                    push!(get!(basin_field_inputs, basin_key, Set{String}()),
                        input_hash)
                end
            elseif gate == "poincare_32" && status == "pass" &&
                    length(input_hash) == 64
                push!(p32_pass, input_hash)
            elseif gate == "poincare_64" && status == "pass" &&
                    length(input_hash) == 64
                push!(p64_pass, input_hash)
            elseif gate == "poincare_128" && status == "pass" &&
                    length(input_hash) == 64
                push!(p128_pass, input_hash); push!(all_p128_pass, input_hash)
                push!(get!(basin_p128_passes, basin_key, Set{String}()), input_hash)
            end
        end
        push!(batch_rows, Dict{String,Any}(
            "batch_index" => batch_index,
            "source_result_hashes" => sort!(String[String(summary[
                "result_hash"]) for summary in summaries]),
            "unique_biot_pass_field_input_count" => length(field_pass),
            "poincare_applicable_unique_biot_pass_field_input_count" =>
                length(applicable_pass),
            "poincare_32_pass_count" => length(p32_pass),
            "poincare_64_pass_count" => length(p64_pass),
            "formal_poincare_128_pass_count" => length(p128_pass),
            "exception_count" => count(record -> get(record, "is_exception",
                false) === true, records)))
    end
    enough_batches = length(batch_rows) >=
        required_consecutive_zero_survival_batches
    zero_tail = enough_batches && all(row[
        "formal_poincare_128_pass_count"] == 0 for row in last(batch_rows,
        required_consecutive_zero_survival_batches))
    enough_inputs = length(applicable_field_pass) >=
        minimum_unique_biot_pass_inputs
    stop = enough_inputs && zero_tail
    basin_rows = Dict{String,Any}[]; retired = String[]
    for basin_key in sort!(collect(keys(basin_metadata)))
        inputs = length(get(basin_field_inputs, basin_key, Set{String}()))
        survivors = length(get(basin_p128_passes, basin_key, Set{String}()))
        retire = inputs >= minimum_unique_inputs_per_basis_basin && survivors == 0
        retire && push!(retired, basin_key)
        row = copy(basin_metadata[basin_key])
        row["unique_biot_pass_field_input_count"] = inputs
        row["formal_poincare_128_pass_count"] = survivors
        row["retire_from_next_sampling"] = retire
        row["retirement_reason"] = retire ?
            "sufficient_unique_inputs_with_zero_formal_poincare_survival" :
            "insufficient_evidence_for_retirement"
        push!(basin_rows, row)
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "batch_count" => length(batch_rows),
        "batches" => batch_rows,
        "minimum_unique_biot_pass_inputs" =>
            Int(minimum_unique_biot_pass_inputs),
        "required_consecutive_zero_survival_batches" =>
            Int(required_consecutive_zero_survival_batches),
        "minimum_unique_inputs_per_basis_basin" =>
            Int(minimum_unique_inputs_per_basis_basin),
        "all_capability_unique_biot_pass_field_input_count" =>
            length(all_field_pass),
        "unique_biot_pass_field_input_count" => length(applicable_field_pass),
        "poincare_applicable_unique_biot_pass_field_input_count" =>
            length(applicable_field_pass),
        "formal_poincare_128_pass_count" => length(all_p128_pass),
        "consecutive_zero_survival_condition_met" => zero_tail,
        "stop_topology_expansion" => stop,
        "recommended_action" => stop ?
            "stop_seed_expansion_and_modify_coil_current_potential_grammar" :
            "continue_only_within_declared_budget",
        "basis_basin_dispositions" => basin_rows,
        "retired_basis_basin_keys" => retired,
        "retroactive_feasibility_credit" => false,
        "claim_boundary" => MULTITOPOLOGY_CAMPAIGN_V86_CLAIM_BOUNDARY)
    body["stop_manifest_hash"] = canonical_hash(body)
    return body
end
