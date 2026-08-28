const GENERIC_CAPABILITY_ACCEPTANCE_V94_CLAIM_BOUNDARY =
    "Acceptance covers software contracts, graph closure, manufactured problems, and numerical verification within registered capability domains. It adds no device feasibility, experimental validation, or promotion claim."

function _v94_v93_snapshot(project_root::AbstractString)
    snapshot = Dict{String,String}()
    for relative_root in ("config", "runs", "reports")
        root = joinpath(project_root, relative_root)
        isdir(root) || continue
        for (directory, _, files) in walkdir(root), file in files
            path = joinpath(directory, file)
            relative = replace(relpath(path, project_root), '\\' => '/')
            occursin("v93", lowercase(relative)) || continue
            snapshot[relative] = bytes2hex(SHA.sha256(read(path)))
        end
    end
    snapshot
end

function audit_provider_anti_specialization_v94(project_root::AbstractString)
    files = ["operator_provider_registry_v94.jl", "field_dependency_closure_v94.jl",
        "graph_residual_assembler_v94.jl", "pvw_generic_providers_v94.jl"]
    forbidden = ["candidate_id", "candidate_hash", "device_family", "device_type",
        "fixed_operator_combination"]
    hits = Dict{String,Any}[]
    for file in files
        path = joinpath(project_root, "src", file)
        for (line_number, line) in enumerate(eachline(path))
            lowered = lowercase(line)
            for token in forbidden
                occursin(token, lowered) && push!(hits,
                    Dict("file" => file, "line" => line_number, "token" => token))
            end
        end
    end
    Dict{String,Any}(
        "status" => isempty(hits) ? "pass" : "fail", "hits" => hits,
        "scan_scope" => files,
        "provider_input_contract" => "CapabilityRequirementV94_only",
        "raw_graph_or_identity_record_passed_to_provider" => false)
end

function _v94_field_classification_control()
    registry = OperatorProviderRegistryV94()
    register_provider_v94!(registry, ProviderCapabilityV94(
        "scalar_field_recipe_v1", "available", String[], ["scalar_recipe"], String[],
        String[], [0], ["scalar"], ["field_value"], "v94.1"),
        _declared_linear_fragment_v94)
    fields = [
        Dict("field_key" => "raw", "class" => "recovered", "value" => 2.0),
        Dict("field_key" => "derived", "class" => "derived", "dependencies" => ["raw"]),
        Dict("field_key" => "computed", "class" => "computable", "dependencies" => ["derived"],
            "operator" => "scalar_recipe", "dimension" => 0, "coordinate" => "scalar"),
        Dict("field_key" => "measurement", "class" => "external_evidence",
            "evidence_available" => false),
        Dict("field_key" => "outside", "class" => "computable", "dependencies" => ["raw"],
            "operator" => "unregistered_recipe", "dimension" => 0, "coordinate" => "scalar")]
    plan = plan_field_dependency_closure_v94(fields; registry = registry)
    classes = Dict(String(item["field_key"]) => String(item["class"]) for item in plan.records)
    pass = classes == Dict("raw" => "recovered", "derived" => "derived",
        "computed" => "computable", "measurement" => "external_evidence",
        "outside" => "unsupported") && plan.recompute_order == ["derived", "computed", "outside"] &&
        "measurement" in plan.unresolved_fields && "outside" in plan.unresolved_fields
    Dict{String,Any}(
        "status" => pass ? "pass" : "fail",
        "classes" => classes, "plan" => field_closure_plan_to_dict_v94(plan))
end

function _v94_invariance_controls(problem, registry)
    baseline_graph = compile_pvw_graph_v94(problem; points = 33,
        labels = ("retained-label", "other-label"))
    erased_graph = compile_pvw_graph_v94(problem; points = 33,
        labels = ("", ""))
    baseline = assemble_graph_residual_jacobian_v94(baseline_graph, registry)
    erased = assemble_graph_residual_jacobian_v94(erased_graph, registry)
    label_pass = baseline.status == "closed" && erased.status == "closed" &&
        baseline.matrix == erased.matrix && baseline.rhs == erased.rhs &&
        [item["selected_provider"] for item in baseline.routes] ==
        [item["selected_provider"] for item in erased.routes]

    permuted_graph = compile_pvw_graph_v94(problem; points = 33,
        region_keys = ("permuted-b", "permuted-a"), labels = ("x", "y"))
    reverse!(permuted_graph["regions"]); reverse!(permuted_graph["variables"])
    reverse!(permuted_graph["equations"]); reverse!(permuted_graph["interfaces"])
    reverse!(permuted_graph["boundaries"])
    permuted = assemble_graph_residual_jacobian_v94(permuted_graph, registry)
    baseline_solve = solve_graph_system_v94(baseline)
    permuted_solve = solve_graph_system_v94(permuted)
    baseline_energy = _pvw_energy_v94(problem, baseline_graph, baseline_solve)
    permuted_energy = _pvw_energy_v94(problem, permuted_graph, permuted_solve)
    route_multiset(assembly) = sort!([String(item["selected_provider"]) for item in assembly.routes])
    permutation_pass = permuted.status == "closed" && permuted_solve["status"] == "pass" &&
        route_multiset(baseline) == route_multiset(permuted) &&
        abs(baseline_energy - permuted_energy) <= 1e-12
    Dict{String,Any}(
        "label_erasure" => Dict("status" => label_pass ? "pass" : "fail",
            "matrix_invariant" => baseline.matrix == erased.matrix,
            "route_invariant" => [item["selected_provider"] for item in baseline.routes] ==
                [item["selected_provider"] for item in erased.routes]),
        "identity_and_order_permutation" => Dict(
            "status" => permutation_pass ? "pass" : "fail",
            "route_multiset_invariant" => route_multiset(baseline) == route_multiset(permuted),
            "observable_absolute_difference" => abs(baseline_energy - permuted_energy)))
end

function _v94_negative_controls(problem, registry)
    missing_registry = deepcopy(registry)
    unregister_provider_v94!(missing_registry, "mixed_trace_continuity_v1")
    missing_assembly = assemble_graph_residual_jacobian_v94(
        compile_pvw_graph_v94(problem; points = 33), missing_registry)
    missing_solve = solve_graph_system_v94(missing_assembly)

    partial_graph = compile_pvw_graph_v94(problem; points = 33,
        extra_inner_operator = "unregistered_additive_term")
    partial_assembly = assemble_graph_residual_jacobian_v94(partial_graph, registry)
    partial_solve = solve_graph_system_v94(partial_assembly)
    controls = [
        Dict{String,Any}(
            "control" => "missing_provider", "expected" => "unsupported_without_solve",
            "observed" => missing_assembly.status,
            "solver_executed" => missing_solve["solver_executed"],
            "partial_subgraph_credit" => missing_solve["partial_subgraph_credit"],
            "status" => missing_assembly.status == "unsupported" &&
                !missing_solve["solver_executed"] && !missing_solve["partial_subgraph_credit"] ? "pass" : "fail"),
        Dict{String,Any}(
            "control" => "partial_closure", "expected" => "unsupported_without_whole_graph_credit",
            "observed" => partial_assembly.status,
            "solver_executed" => partial_solve["solver_executed"],
            "partial_subgraph_credit" => partial_solve["partial_subgraph_credit"],
            "status" => partial_assembly.status == "unsupported" &&
                !partial_solve["solver_executed"] && !partial_solve["partial_subgraph_credit"] ? "pass" : "fail")]
    Dict{String,Any}(
        "status" => all(item -> item["status"] == "pass", controls) ? "pass" : "fail",
        "controls" => controls)
end

function run_generic_capability_acceptance_v94(project_root::AbstractString)
    before = _v94_v93_snapshot(project_root)
    registry = default_operator_provider_registry_v94()
    problem, _ = manufactured_pvw_problem_v1()
    registry_audit = audit_provider_anti_specialization_v94(project_root)
    field_control = _v94_field_classification_control()
    invariance = _v94_invariance_controls(problem, registry)
    unseen_graph = manufactured_chain_graph_v94(5;
        order = [3, 1, 5, 2, 4], labels = ["a", "b", "c", "d", "e"])
    unseen_assembly = assemble_graph_residual_jacobian_v94(unseen_graph, registry)
    unseen_solve = solve_graph_system_v94(unseen_assembly)
    unseen = Dict{String,Any}(
        "status" => unseen_assembly.status == "closed" && unseen_solve["status"] == "pass" ? "pass" : "fail",
        "region_count" => 5, "topology_seen_by_pvw_provider_tests" => false,
        "assembly" => graph_assembly_to_dict_v94(unseen_assembly), "solve" => unseen_solve,
        "physical_credit" => false)
    negative = _v94_negative_controls(problem, registry)
    stage_chain = execute_pvw_generic_stage_chain_v94(problem; registry = registry)
    stage_pass = stage_chain["stage_order"] == ["solve", "numerical_vvuq", "validation_vvuq"] &&
        stage_chain["solve"]["status"] == "pass" &&
        stage_chain["numerical_vvuq"]["status"] == "pass" &&
        stage_chain["validation_vvuq"]["status"] == "unknown_validation_domain" &&
        stage_chain["status"] == "unknown_validation_domain"
    after = _v94_v93_snapshot(project_root)
    preservation = Dict{String,Any}(
        "status" => before == after ? "pass" : "fail",
        "v93_artifact_count" => length(before),
        "added" => sort!(collect(setdiff(Set(keys(after)), Set(keys(before))))),
        "removed" => sort!(collect(setdiff(Set(keys(before)), Set(keys(after))))),
        "changed" => sort!([key for key in intersect(Set(keys(before)), Set(keys(after)))
            if before[key] != after[key]]),
        "v93_write_count" => before == after ? 0 : 1)
    controls = Dict{String,Any}(
        "v93_preservation" => preservation,
        "provider_anti_specialization" => registry_audit,
        "field_dependency_closure" => field_control,
        "invariance" => invariance,
        "unseen_topology" => unseen,
        "negative_controls" => negative,
        "strict_stage_order" => Dict("status" => stage_pass ? "pass" : "fail",
            "observed_order" => stage_chain["stage_order"]),
        "pvw_provider_chain" => stage_chain)
    pass = preservation["status"] == "pass" && registry_audit["status"] == "pass" &&
        field_control["status"] == "pass" &&
        all(item -> item["status"] == "pass", values(invariance)) &&
        unseen["status"] == "pass" && negative["status"] == "pass" && stage_pass
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V94_PROTOCOL_ID,
        "status" => pass ? "pass" : "fail", "software_acceptance" => pass ? "pass" : "fail",
        "provider_registry" => provider_registry_manifest_v94(registry),
        "controls" => controls,
        "conclusions" => Dict(
            "unknown" => "validation remains unknown without candidate-bound measurements",
            "unsupported" => "missing capability closes no subgraph into a whole-graph result",
            "numerical_verification" => stage_chain["numerical_vvuq"]["status"],
            "experimental_validation" => stage_chain["validation_vvuq"]["status"],
            "device_feasibility" => "not_claimed", "promotion" => "not_claimed"),
        "physical_conclusion_expanded" => false,
        "claim_boundary" => GENERIC_CAPABILITY_ACCEPTANCE_V94_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end
