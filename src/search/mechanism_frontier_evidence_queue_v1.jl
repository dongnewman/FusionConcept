const _MECHANISM_FRONTIER_CLAIM_BOUNDARY_V1 =
    "The queue reconstructs exact fidelity-0 candidates and compiles candidate-specific " *
    "physics obligations without using a family quota or family-dependent score. Selection " *
    "is quality-diversity scheduling for evidence acquisition only. Missing explicit geometry, " *
    "native executable modules, solver evidence, or C1/C2 inputs remains unknown and blocks " *
    "performance ranking, medium-fidelity admission, feasibility, and promotion."

function _frontier_plain_record_v1(raw::AbstractDict)
    return Dict{String,Any}(String(key) => _plain_json(value) for (key, value) in raw)
end

function _frontier_candidate_quality_key_v1(item::AbstractDict)
    return (-Int(item["gate_pass_count"]),
        Int(item["physics_missing_input_count"]),
        Int(item["missing_proxy_requirement_count"]),
        Int(item["structural_component_count"]),
        String(item["physics_hash"]))
end

function _frontier_diversity_tokens_v1(problem::CompiledPhysicsProblemV1)
    topology = problem.topology
    tokens = String[
        "closure:$(topology.closure_class)",
        "dimensionality:$(topology.dimensionality)",
        "symmetry:$(topology.symmetry_class)",
        "field_periods:$(topology.field_periods)",
        "separatrix:$(topology.expected_separatrix)",
        "flux_surfaces:$(topology.expected_flux_surfaces)",
    ]
    append!(tokens, "field_source:$value" for value in topology.field_source_kinds)
    append!(tokens, "region:$value" for value in topology.plasma_region_kinds)
    append!(tokens, "connection:$value" for value in problem.domain.connection_kinds)
    append!(tokens, "operator:$(item.spec.id)" for item in problem.operators if
        !item.spec.empirical_prior)
    return sort!(unique(tokens))
end

function _frontier_mechanism_cell_v1(problem::CompiledPhysicsProblemV1)
    topology = problem.topology
    payload = Dict{String,Any}(
        "closure_class" => String(topology.closure_class),
        "dimensionality" => String(topology.dimensionality),
        "symmetry_class" => topology.symmetry_class,
        "field_periods" => topology.field_periods,
        "expected_flux_surfaces" => topology.expected_flux_surfaces,
        "expected_separatrix" => topology.expected_separatrix,
        "field_source_kinds" => topology.field_source_kinds,
        "plasma_region_kinds" => topology.plasma_region_kinds,
        "connection_kinds" => problem.domain.connection_kinds,
        "active_operator_ids" => sort!(String[item.spec.id for item in
            problem.operators if !item.spec.empirical_prior]))
    return payload, canonical_hash(payload)
end

function _frontier_jaccard_distance_v1(left::AbstractVector,
        right::AbstractVector)
    a, b = Set(String.(left)), Set(String.(right))
    union_count = length(union(a, b))
    union_count == 0 && return 0.0
    return 1.0 - length(intersect(a, b)) / union_count
end

"Reconstruct one sealed v20 record and compile its family-independent physics obligations."
function compile_mechanism_frontier_candidate_v1(
        context::RecoverableCrossTopologyContextV20, raw::AbstractDict)
    record = _frontier_plain_record_v1(raw)
    candidate = evaluate_cross_topology_candidate_v20(context,
        Int(record["candidate_index"]))
    replay = cross_topology_candidate_to_dict_v20(candidate)
    replay_keys = ("candidate_index", "assembly_index", "sample_ordinal",
        "assembly_id", "graph_hash", "design_id", "physics_hash",
        "proxy_result_hash")
    replay_verified = all(record[key] == replay[key] for key in replay_keys)
    replay_verified || throw(ArgumentError(
        "frontier candidate replay does not match the sealed search record"))
    genome = candidate.prescreen.compiled.genome
    problem = compile_physics_problem_v1(genome)
    executable = migrate_legacy_genome_to_executable_v1(genome)
    program = compile_executable_physics_program_v1(executable)
    problem_dict = physics_problem_to_dict_v1(problem)
    program_dict = compiled_executable_program_to_dict_v1(program)
    cell, cell_hash = _frontier_mechanism_cell_v1(problem)
    tokens = _frontier_diversity_tokens_v1(problem)

    scrambled_raw = deepcopy(genome.normalized)
    scrambled_raw["family"] = "diagnostic_scrambled_family_label"
    scrambled_genome = parse_genome(scrambled_raw)
    scrambled_problem = compile_physics_problem_v1(scrambled_genome)
    family_invariant = problem.physical_signature_hash ==
        scrambled_problem.physical_signature_hash &&
        problem.routing_hash == scrambled_problem.routing_hash

    nonprior = [item for item in problem.operators if !item.spec.empirical_prior]
    ready_nonprior = count(item -> item.status == :ready, nonprior)
    missing_geometry = sort!(String[id for id in problem.domain.missing_input_ids if
        startswith(id, "field_source_geometry:") ||
        startswith(id, "plasma_region_geometry:") || id == "wall_geometry"])
    maxwell_ready = any(item -> item.spec.id == "maxwell_magnetostatic_field_v1" &&
        item.status == :ready, problem.operators)
    topology_ready = any(item -> item.spec.id == "field_line_topology_trace_v1" &&
        item.status == :ready, problem.operators)
    native_executable = program.explicit_module_count > 0 &&
        program.migrated_unknown_module_count == 0 &&
        isempty(program.uncovered_operator_ids)
    c1_input_ready = maxwell_ready && topology_ready && isempty(missing_geometry) &&
        native_executable
    structural_components = length(genome.plasma_regions) +
        length(genome.field_sources) + length(genome.actuators) +
        length(genome.flux_connections)
    return Dict{String,Any}(
        "candidate_index" => record["candidate_index"],
        "assembly_index" => record["assembly_index"],
        "sample_ordinal" => record["sample_ordinal"],
        "assembly_id" => record["assembly_id"],
        "graph_hash" => record["graph_hash"],
        "design_id" => record["design_id"],
        "physics_hash" => record["physics_hash"],
        "diagnostic_legacy_family_label" => record["family"],
        "family_label_used_for_selection" => false,
        "module_ids" => record["module_ids"],
        "gate_pass_count" => record["gate_pass_count"],
        "missing_proxy_requirement_count" =>
            record["missing_proxy_requirement_count"],
        "missing_proxy_requirements" => record["missing_proxy_requirements"],
        "positive_net_power_closure" => record["positive_net_power_closure"],
        "exact_candidate_replay_verified" => replay_verified,
        "family_scramble_physics_invariant" => family_invariant,
        "mechanism_cell" => cell,
        "mechanism_cell_hash" => cell_hash,
        "diversity_tokens" => tokens,
        "physical_signature_hash" => problem.physical_signature_hash,
        "routing_hash" => problem.routing_hash,
        "physics_problem_hash" => canonical_hash(problem_dict),
        "physics_operator_count" => length(problem.operators),
        "ready_nonprior_operator_count" => ready_nonprior,
        "physics_missing_input_count" => length(problem.domain.missing_input_ids),
        "physics_missing_input_ids" => problem.domain.missing_input_ids,
        "missing_explicit_geometry_ids" => missing_geometry,
        "structural_component_count" => structural_components,
        "native_executable_physics_declared" => native_executable,
        "migrated_unknown_module_count" => program.migrated_unknown_module_count,
        "uncovered_operator_ids" => program.uncovered_operator_ids,
        "c1_problem_input_ready" => c1_input_ready,
        "genome" => genome.normalized,
        "physics_problem" => problem_dict,
        "executable_program" => program_dict,
        "claim_ceiling" => "C0_candidate_specific_physics_obligation_graph_only")
end

function _frontier_maximin_select_v1(pool::Vector{Dict{String,Any}},
        count::Int, selected::Vector{Dict{String,Any}} = Dict{String,Any}[])
    count <= 0 && return Dict{String,Any}[]
    remaining = copy(pool)
    chosen = Dict{String,Any}[]
    used = Set(Int(item["candidate_index"]) for item in selected)
    filter!(item -> !(Int(item["candidate_index"]) in used), remaining)
    while !isempty(remaining) && length(chosen) < count
        references = vcat(selected, chosen)
        if isempty(references)
            index = argmin(_frontier_candidate_quality_key_v1.(remaining))
        else
            distances = [minimum(_frontier_jaccard_distance_v1(
                item["diversity_tokens"], reference["diversity_tokens"])
                for reference in references) for item in remaining]
            best_distance = maximum(distances)
            indices = findall(value -> isapprox(value, best_distance;
                atol = 1.0e-14, rtol = 0.0), distances)
            index = indices[argmin(_frontier_candidate_quality_key_v1.(remaining[indices]))]
        end
        push!(chosen, splice!(remaining, index))
    end
    return chosen
end

"Select a high-gate plus coverage queue using mechanism-token maximin diversity, never family quotas."
function select_mechanism_frontier_evidence_queue_v1(
        audited::AbstractVector{<:AbstractDict}; frontier_budget::Integer = 32,
        coverage_budget::Integer = 32, frontier_gate_count::Integer = 3)
    normalized = Dict{String,Any}[_frontier_plain_record_v1(item) for item in audited]
    by_index = Dict(Int(item["candidate_index"]) => item for item in normalized)
    length(by_index) == length(normalized) || throw(ArgumentError(
        "frontier audit contains duplicate candidate indices"))
    raw_frontier = [item for item in normalized if
        Int(item["gate_pass_count"]) >= frontier_gate_count]
    by_signature = Dict{String,Dict{String,Any}}()
    for item in normalized
        signature = String(item["physical_signature_hash"])
        incumbent = get(by_signature, signature, nothing)
        if incumbent === nothing || _frontier_candidate_quality_key_v1(item) <
                _frontier_candidate_quality_key_v1(incumbent)
            by_signature[signature] = item
        end
    end
    unique_physics = collect(values(by_signature))
    frontier = [item for item in unique_physics if
        Int(item["gate_pass_count"]) >= frontier_gate_count]
    first_pass = _frontier_maximin_select_v1(frontier, Int(frontier_budget))
    remainder = [item for item in unique_physics if !(Int(item["candidate_index"]) in
        Set(Int(selected["candidate_index"]) for selected in first_pass))]
    effective_coverage_budget = Int(coverage_budget) +
        max(Int(frontier_budget) - length(first_pass), 0)
    second_pass = _frontier_maximin_select_v1(remainder,
        effective_coverage_budget,
        first_pass)
    selected = vcat(first_pass, second_pass)
    for (rank, item) in enumerate(selected)
        item["queue_rank"] = rank
        item["queue_partition"] = rank <= length(first_pass) ?
            "highest_gate_maximin" : "all_topology_coverage_maximin"
    end
    return Dict{String,Any}(
        "selector_version" => "mechanism_frontier_evidence_queue_v1.0.0",
        "selection_uses_family_label" => false,
        "audited_candidate_count" => length(normalized),
        "unique_physical_signature_pool_count" => length(unique_physics),
        "raw_frontier_pool_count" => length(raw_frontier),
        "frontier_pool_count" => length(frontier),
        "frontier_budget" => Int(frontier_budget),
        "coverage_budget" => Int(coverage_budget),
        "effective_coverage_budget" => effective_coverage_budget,
        "selected_candidate_count" => length(selected),
        "selected_mechanism_cell_count" => length(unique(String(
            item["mechanism_cell_hash"]) for item in selected)),
        "selected" => selected,
        "claim_boundary" => _MECHANISM_FRONTIER_CLAIM_BOUNDARY_V1)
end
