const GENERIC_VVUQ_RUNTIME_V94_CLAIM_BOUNDARY =
    "Execution order is solve, then numerical VVUQ, then validation VVUQ. A numerical pass is not validation, and absent experimental evidence remains unknown rather than pass or physical fail."

function solve_graph_system_v94(assembly::GraphAssemblyV94)
    if !assembly.solver_allowed
        return Dict{String,Any}(
            "status" => "unsupported", "solver_executed" => false,
            "whole_graph_closed" => false, "partial_subgraph_credit" => false,
            "blockers" => assembly.blockers, "assembly_hash" => assembly.assembly_hash)
    end
    matrix = assembly.matrix::Matrix{Float64}; rhs = assembly.rhs::Vector{Float64}
    state = try
        matrix \ rhs
    catch error
        return Dict{String,Any}(
            "status" => "fail_numerical_convergence", "solver_executed" => true,
            "whole_graph_closed" => true, "partial_subgraph_credit" => false,
            "reason" => sprint(showerror, error), "assembly_hash" => assembly.assembly_hash)
    end
    residual = graph_residual_v94(assembly, state)
    normalized = norm(residual) / max(norm(rhs), 1.0)
    jacobian = graph_jacobian_v94(assembly, state)
    epsilon = 1e-7; fd = similar(jacobian); base = graph_residual_v94(assembly, state)
    for column in axes(jacobian, 2)
        perturbed = copy(state); perturbed[column] += epsilon
        fd[:, column] .= (graph_residual_v94(assembly, perturbed) - base) / epsilon
    end
    jacobian_error = norm(fd - jacobian) / max(norm(jacobian), eps())
    passed = all(isfinite, state) && normalized <= 1e-10 && jacobian_error <= 1e-7
    state_map = Dict(assembly.variable_keys[index] => state[index] for index in eachindex(state))
    body = Dict{String,Any}(
        "status" => passed ? "pass" : "fail_numerical_convergence",
        "solver_executed" => true, "whole_graph_closed" => true,
        "partial_subgraph_credit" => false, "state" => state,
        "state_map" => state_map, "normalized_residual" => normalized,
        "jacobian_relative_error" => jacobian_error,
        "exact_jacobian_used" => true, "assembly_hash" => assembly.assembly_hash)
    body["solve_hash"] = canonical_hash(body)
    body
end

function audit_validation_vvuq_v94(evidence = nothing)
    evidence === nothing && return Dict{String,Any}(
        "status" => "unknown_validation_domain", "actual_measurement_dataset_count" => 0,
        "experimental_validation" => "unknown", "proxy_data_used" => false,
        "reason" => "candidate_bound_validation_measurements_unavailable")
    record = Dict{String,Any}(_v93_plain(evidence))
    actual_count = Int(get(record, "actual_measurement_dataset_count", 0))
    independent = get(record, "independent_from_solver", false) === true
    uncertainty = get(record, "measurement_uncertainty_quantified", false) === true
    domain = get(record, "validation_domain_attested", false) === true
    requested_pass = get(record, "comparison_status", "unknown") == "pass"
    passed = actual_count > 0 && independent && uncertainty && domain && requested_pass
    Dict{String,Any}(
        "status" => passed ? "pass" : "unknown_validation_domain",
        "actual_measurement_dataset_count" => actual_count,
        "experimental_validation" => passed ? "pass" : "unknown",
        "independent_from_solver" => independent,
        "measurement_uncertainty_quantified" => uncertainty,
        "validation_domain_attested" => domain,
        "proxy_data_used" => get(record, "proxy_data_used", false),
        "reason" => passed ? nothing : "validation_evidence_contract_incomplete")
end

function _pvw_energy_v94(problem, graph, solve)
    observations = Dict{String,Any}(graph["observables"])
    state_map = Dict{String,Any}(solve["state_map"])
    energy = 0.0
    for (grid_key, q_key) in (("inner_grid", "inner_q_keys"), ("outer_grid", "outer_q_keys"))
        grid = Float64.(observations[grid_key]); q = String.(observations[q_key])
        for i in 1:(length(grid) - 1)
            dr = grid[i + 1] - grid[i]
            energy += dr * (grid[i] * Float64(state_map[q[i]])^2 +
                grid[i + 1] * Float64(state_map[q[i + 1]])^2) / 2
        end
    end
    energy
end

function run_pvw_numerical_vvuq_v94(problem::PlasmaVacuumWallProblemV1,
        registry::OperatorProviderRegistryV94)
    levels = Dict{String,Any}[]
    for points in (33, 65, 129)
        graph = compile_pvw_graph_v94(problem; points = points)
        assembly = assemble_graph_residual_jacobian_v94(graph, registry)
        solve = solve_graph_system_v94(assembly)
        independent = solve_pvw_domain_decomposed_v1(problem; points = points)
        difference = solve["status"] == "pass" ?
            norm(Float64.(solve["state"]) - Float64.(independent["state"])) : Inf
        energy = solve["status"] == "pass" ? _pvw_energy_v94(problem, graph, solve) : nothing
        push!(levels, Dict{String,Any}(
            "points" => points, "assembly_status" => assembly.status,
            "solve" => solve, "independent_algorithm" => independent["algorithm"],
            "independent_status" => independent["status"],
            "independent_state_difference" => difference,
            "magnetic_energy_proxy_t2_m2" => energy))
    end
    solve_pass = all(item -> item["solve"]["status"] == "pass" &&
        item["independent_status"] == "pass" &&
        item["independent_state_difference"] <= 1e-9, levels)
    if !solve_pass
        return Dict{String,Any}(
            "status" => "fail", "levels" => levels,
            "verification_type" => "mesh_and_independent_algorithm",
            "experimental_validation_credit" => false)
    end
    energy = Float64[item["magnetic_energy_proxy_t2_m2"] for item in levels]
    d_cm = abs(energy[1] - energy[2]); d_mf = abs(energy[2] - energy[3])
    if d_cm <= eps(maximum(abs, energy)) || d_mf <= eps(maximum(abs, energy))
        return Dict{String,Any}(
            "status" => "unknown", "levels" => levels,
            "reason" => "observed_order_not_resolved_above_roundoff",
            "verification_type" => "mesh_and_independent_algorithm",
            "experimental_validation_credit" => false)
    end
    order = log2(d_cm / d_mf)
    gci = 1.25 * d_mf / max(2.0^order - 1.0, eps()) /
        max(abs(energy[3]), eps()) * 100
    passed = order > 0 && gci <= 2.0
    Dict{String,Any}(
        "status" => passed ? "pass" : "fail", "levels" => levels,
        "energy_observables" => energy, "observed_order" => order,
        "gci_fine_percent" => gci,
        "verification_type" => "mesh_and_independent_algorithm",
        "independent_algorithm_is_validation_evidence" => false,
        "experimental_validation_credit" => false)
end

function execute_pvw_generic_stage_chain_v94(problem::PlasmaVacuumWallProblemV1;
        registry = default_operator_provider_registry_v94(), validation_evidence = nothing)
    stage_log = String[]
    graph = compile_pvw_graph_v94(problem; points = 129)
    assembly = assemble_graph_residual_jacobian_v94(graph, registry)
    push!(stage_log, "solve")
    solve = solve_graph_system_v94(assembly)
    if solve["status"] != "pass"
        body = Dict{String,Any}(
            "protocol_id" => V94_PROTOCOL_ID, "status" => solve["status"],
            "stage_order" => stage_log, "assembly" => graph_assembly_to_dict_v94(assembly),
            "solve" => solve, "numerical_vvuq" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "unknown_independent" => true, "unsupported_independent" => solve["status"] == "unsupported",
            "numerical_verification_independent" => true,
            "experimental_validation_independent" => true,
            "claim_boundary" => GENERIC_VVUQ_RUNTIME_V94_CLAIM_BOUNDARY)
        body["result_hash"] = canonical_hash(body); return body
    end
    push!(stage_log, "numerical_vvuq")
    numerical = run_pvw_numerical_vvuq_v94(problem, registry)
    if numerical["status"] != "pass"
        body = Dict{String,Any}(
            "protocol_id" => V94_PROTOCOL_ID,
            "status" => numerical["status"] == "unknown" ? "unknown_numerical_vvuq" : "fail_numerical_vvuq",
            "stage_order" => stage_log, "assembly" => graph_assembly_to_dict_v94(assembly),
            "solve" => solve, "numerical_vvuq" => numerical,
            "validation_vvuq" => Dict("status" => "not_executed"),
            "unknown_independent" => numerical["status"] == "unknown",
            "unsupported_independent" => false, "numerical_verification_independent" => true,
            "experimental_validation_independent" => true,
            "claim_boundary" => GENERIC_VVUQ_RUNTIME_V94_CLAIM_BOUNDARY)
        body["result_hash"] = canonical_hash(body); return body
    end
    push!(stage_log, "validation_vvuq")
    validation = audit_validation_vvuq_v94(validation_evidence)
    status = validation["status"] == "pass" ? "pass" : "unknown_validation_domain"
    body = Dict{String,Any}(
        "protocol_id" => V94_PROTOCOL_ID, "status" => status,
        "stage_order" => stage_log, "assembly" => graph_assembly_to_dict_v94(assembly),
        "solve" => solve, "numerical_vvuq" => numerical,
        "validation_vvuq" => validation,
        "unknown_independent" => validation["status"] != "pass",
        "unsupported_independent" => false,
        "numerical_verification_independent" => true,
        "experimental_validation_independent" => true,
        "physical_conclusion_expanded" => false,
        "claim_boundary" => GENERIC_VVUQ_RUNTIME_V94_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body)
    body
end
