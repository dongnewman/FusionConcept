const PHYSICAL_VVUQ_RUNTIME_V96_CLAIM_BOUNDARY =
    "Execution is graph compilation and closure, solve, numerical VVUQ, solve-derived reduced observables, then validation VVUQ. Numerical or reference-control success is not experimental validation or device feasibility."

function solved_physical_metric_v96(metric_id, value, solve; units, evidence_ceiling)
    allowed = get(solve, "status", "") == "pass" &&
        get(solve, "whole_graph_closed", false) === true && haskey(solve, "solve_hash") &&
        value !== nothing && value isa Real && isfinite(value)
    Dict{String,Any}(
        "metric_id" => String(metric_id), "status" => allowed ? "available" : "unsupported",
        "value" => allowed ? Float64(value) : nothing, "units" => String(units),
        "origin" => allowed ? "whole_graph_solve_derived" : nothing,
        "solve_hash" => allowed ? solve["solve_hash"] : nothing,
        "evidence_ceiling" => String(evidence_ceiling),
        "basis_direct_proxy_credit" => false,
        "reason" => allowed ? nothing : "successful_whole_graph_solve_required")
end

function numerical_vvuq_physical_graph_v96(assembly::PhysicalGraphAssemblyV96, solve)
    get(solve, "status", "") == "pass" || return Dict{String,Any}(
        "status" => "not_executed", "reason" => "solve_not_passed",
        "experimental_validation_credit" => false)
    replay = solve_physical_graph_v96(assembly)
    independent_state = try
        qr(assembly.matrix) \ assembly.rhs
    catch
        fill(NaN, length(assembly.rhs))
    end
    state = Float64.(solve["state"])
    replay_difference = get(replay, "status", "") == "pass" ?
        maximum(abs, state - Float64.(replay["state"]); init = 0.0) : Inf
    independent_difference = all(isfinite, independent_state) ?
        maximum(abs, state - independent_state; init = 0.0) : Inf
    passed = replay_difference <= 1e-12 && independent_difference <= 1e-9 &&
        Float64(solve["normalized_residual"]) <= 1e-10 &&
        Float64(solve["jacobian_relative_error"]) <= 1e-7
    body = Dict{String,Any}(
        "status" => passed ? "pass" : "numerical_fail",
        "deterministic_replay_difference" => replay_difference,
        "independent_qr_difference" => independent_difference,
        "primary_algorithm" => "dense_lu_v96", "independent_algorithm" => "qr_v96",
        "same_reduced_physics_model" => true,
        "normalized_residual" => solve["normalized_residual"],
        "jacobian_relative_error" => solve["jacobian_relative_error"],
        "verification_type" => "residual_jacobian_replay_and_independent_linear_algorithm",
        "experimental_validation_credit" => false,
        "claim_boundary" => PHYSICAL_VVUQ_RUNTIME_V96_CLAIM_BOUNDARY)
    body["vvuq_hash"] = canonical_hash(body)
    body
end

function _v96_state_value(solve, suffixes, fallback = nothing)
    state_map = Dict{String,Any}(get(solve, "physical_state_map", Dict{String,Any}()))
    for suffix in suffixes
        matches = sort!([String(key) for key in keys(state_map)
            if endswith(String(key), "::" * String(suffix))])
        isempty(matches) || return Float64(state_map[first(matches)])
    end
    fallback
end

function evaluate_solve_derived_observables_v96(physics_raw, graph_raw,
        assembly::PhysicalGraphAssemblyV96, solve)
    physics = Dict{String,Any}(_v93_plain(physics_raw))
    graph = Dict{String,Any}(_v93_plain(graph_raw))
    parameters = Dict{String,Any}(_v93_plain(get(physics, "parameters", Dict{String,Any}())))
    regions = Dict{String,Any}.(physics["regions"])
    meshes = Dict{String,Any}.(graph["meshes"])
    plasma_index = findfirst(item -> String(item["region_type"]) == "plasma", regions)
    plasma_index === nothing && (plasma_index = 1)
    plasma_measure = Float64(meshes[plasma_index]["cell_measure"])
    magnetic_field = _v96_state_value(solve, ["magnetic_field"],
        get(parameters, "magnetic_field_t", get(parameters, "reference_field_t", nothing)))
    pressure = _v96_state_value(solve, ["pressure"], nothing)
    if pressure === nothing
        thermal = _v96_state_value(solve, ["thermal_energy"], nothing)
        pressure = thermal === nothing ? nothing : (2.0 / 3.0) * thermal / plasma_measure
    end
    density = _v96_state_value(solve, ["density"], nothing)
    if density === nothing
        inventory = _v96_state_value(solve, ["particle_inventory"], nothing)
        density = inventory === nothing ? nothing : inventory / plasma_measure
    end
    temperature = _v96_state_value(solve, ["temperature"],
        haskey(parameters, "temperature_j") ? Float64(parameters["temperature_j"]) /
            1.602176634e-19 : get(parameters, "reference_temperature_ev", nothing))
    beta = pressure === nothing || magnetic_field === nothing ? nothing :
        2 * (4pi * 1e-7) * pressure / max(magnetic_field^2, eps())
    stability_margin = assembly.solver_allowed ? minimum(eigvals(Symmetric(
        (assembly.matrix + assembly.matrix') / 2))) : nothing
    wall_index = findfirst(item -> String(item["region_type"]) == "wall", regions)
    wall_load = if wall_index === nothing
        nothing
    else
        wall_temperature = _v96_state_value(solve, ["temperature"], nothing)
        area = max(Float64(meshes[wall_index]["cell_measure"])^(2 / 3), 1e-9)
        wall_temperature === nothing ? nothing : wall_temperature * 1.602176634e-19 / area
    end
    reaction_declared = any(requirement -> String(requirement["operator"]) ==
        "reaction_radiation", Dict{String,Any}.(graph["requirements"]))
    input_power = Float64(get(parameters, "input_power_w", 0.0))
    net_power = if reaction_declared && density !== nothing && temperature !== nothing
        reactivity = 1e-24 * max(temperature, 0.0)^2 /
            (1.0 + max(temperature, 0.0)^2 / 1e8)
        fusion_power = 0.25 * density^2 * reactivity * plasma_measure *
            17.6e6 * 1.602176634e-19
        fusion_power - input_power
    else
        nothing
    end
    ceiling = "reduced_lumped_multiregion_solve_derived_not_device_prediction"
    metrics = Dict{String,Any}(
        "beta" => solved_physical_metric_v96("beta", beta, solve;
            units = "1", evidence_ceiling = ceiling),
        "net_power_w" => solved_physical_metric_v96("net_power_w", net_power, solve;
            units = "W", evidence_ceiling = ceiling),
        "stability_margin" => solved_physical_metric_v96("stability_margin",
            stability_margin, solve; units = "normalized", evidence_ceiling = ceiling),
        "wall_load_w_m2" => solved_physical_metric_v96("wall_load_w_m2", wall_load,
            solve; units = "W/m^2", evidence_ceiling = ceiling))
    body = Dict{String,Any}(
        "status" => all(item -> item["status"] in ("available", "unsupported"),
            values(metrics)) ? "pass" : "unknown",
        "metrics" => metrics, "solve_hash" => get(solve, "solve_hash", nothing),
        "threshold_gate_credit" => false, "experimental_validation_credit" => false,
        "claim_boundary" => PHYSICAL_VVUQ_RUNTIME_V96_CLAIM_BOUNDARY)
    body["observable_hash"] = canonical_hash(body)
    body
end

function execute_physical_stage_chain_v96(physics_raw;
        registry = default_physical_provider_registry_v96(),
        validation_applicable::Bool = true, validation_evidence = nothing)
    stage_order = String["graph_compile"]
    graph = compile_physical_graph_v96(physics_raw)
    push!(stage_order, "provider_closure")
    assembly = assemble_physical_graph_v96(graph, registry)
    if !assembly.solver_allowed
        body = Dict{String,Any}(
            "protocol_id" => V96_PROTOCOL_ID, "status" => "unsupported",
            "stage_order" => stage_order, "graph_hash" => graph["graph_hash"],
            "assembly" => physical_graph_assembly_to_dict_v96(assembly),
            "solve" => Dict("status" => "not_executed", "solver_executed" => false),
            "numerical_vvuq" => Dict("status" => "not_executed"),
            "observables" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "partial_subgraph_credit" => false, "physical_conclusion_expanded" => false,
            "claim_boundary" => PHYSICAL_VVUQ_RUNTIME_V96_CLAIM_BOUNDARY)
        body["result_hash"] = canonical_hash(body); return body
    end
    push!(stage_order, "solve")
    solve = solve_physical_graph_v96(assembly)
    if solve["status"] != "pass"
        body = Dict{String,Any}(
            "protocol_id" => V96_PROTOCOL_ID, "status" => "numerical_fail",
            "stage_order" => stage_order, "graph_hash" => graph["graph_hash"],
            "assembly" => physical_graph_assembly_to_dict_v96(assembly), "solve" => solve,
            "numerical_vvuq" => Dict("status" => "not_executed"),
            "observables" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "partial_subgraph_credit" => false, "physical_conclusion_expanded" => false,
            "claim_boundary" => PHYSICAL_VVUQ_RUNTIME_V96_CLAIM_BOUNDARY)
        body["result_hash"] = canonical_hash(body); return body
    end
    push!(stage_order, "numerical_vvuq")
    numerical = numerical_vvuq_physical_graph_v96(assembly, solve)
    if numerical["status"] != "pass"
        body = Dict{String,Any}(
            "protocol_id" => V96_PROTOCOL_ID, "status" => "numerical_fail",
            "stage_order" => stage_order, "graph_hash" => graph["graph_hash"],
            "assembly" => physical_graph_assembly_to_dict_v96(assembly), "solve" => solve,
            "numerical_vvuq" => numerical, "observables" => Dict("status" => "not_executed"),
            "validation_vvuq" => Dict("status" => "not_executed"),
            "partial_subgraph_credit" => false, "physical_conclusion_expanded" => false,
            "claim_boundary" => PHYSICAL_VVUQ_RUNTIME_V96_CLAIM_BOUNDARY)
        body["result_hash"] = canonical_hash(body); return body
    end
    push!(stage_order, "solve_derived_observables")
    observables = evaluate_solve_derived_observables_v96(physics_raw, graph, assembly, solve)
    push!(stage_order, "validation_vvuq")
    validation = validation_applicable ? audit_validation_vvuq_v94(validation_evidence) :
        Dict{String,Any}("status" => "not_applicable", "experimental_validation" =>
            "not_applicable", "reason" => "declared_not_applicable")
    status = validation["status"] == "pass" || validation["status"] == "not_applicable" ?
        "pass" : "unknown"
    body = Dict{String,Any}(
        "protocol_id" => V96_PROTOCOL_ID, "status" => status,
        "stage_order" => stage_order, "graph_hash" => graph["graph_hash"],
        "assembly" => physical_graph_assembly_to_dict_v96(assembly), "solve" => solve,
        "numerical_vvuq" => numerical, "observables" => observables,
        "validation_vvuq" => validation, "partial_subgraph_credit" => false,
        "physical_conclusion_expanded" => false,
        "claim_boundary" => PHYSICAL_VVUQ_RUNTIME_V96_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body)
    body
end
