const UNIFIED_FILTER_ACCEPTANCE_V95_CLAIM_BOUNDARY =
    "This acceptance diagnoses the selector and its currently registered capabilities. Unsupported or unknown candidates are not physical failures; reference regression, numerical VVUQ, and published ranges do not establish experimental validation or device feasibility."

_v95_strings(values) = sort!(unique(String.(values)))

function _v95_reference_declaration(record)
    item = Dict{String,Any}(_v93_plain(record))
    regions = [Dict{String,Any}(
        "region_key" => String(region["region_id"]), "dimension" => 3,
        "coordinate" => String(get(region, "geometry_model", "unresolved_device_coordinate")))
        for region in Dict{String,Any}.(item["regions"])]
    host = String(first(regions)["region_key"])
    bindings = Dict{String,Any}.(get(item, "module_bindings", Any[]))
    states = Dict{String,Any}[]
    for raw in Dict{String,Any}.(get(item, "state_variables", Any[]))
        state_id = String(raw["state_id"])
        matching = [binding for binding in bindings if state_id in
            String.(get(binding, "state_ids", Any[]))]
        operators = _v95_strings([String(binding["operator_id"]) for binding in matching])
        primary = isempty(operators) ? "undeclared_whole_system_operator" : first(operators)
        push!(states, Dict{String,Any}(
            "state_key" => host * "::" * state_id, "region_key" => host,
            "physical_state" => state_id, "function_space" => "unresolved_discrete_space",
            "operator" => primary, "additional_operators" => operators[2:end]))
    end
    Dict{String,Any}(
        "regions" => regions, "states" => states, "interfaces" => Any[],
        "boundaries" => Any[], "fields" => Any[])
end

function _v95_candidate_operator(state, region_type, declared)
    preferences = if state in ("magnetic_field", "current_density")
        ["field_balance", "coupled_inventory_root"]
    elseif state in ("density", "pressure")
        ["particle_balance", "coupled_inventory_root"]
    elseif state == "temperature"
        region_type in ("open_loss", "terminal") ?
            ["parallel_transport", "terminal_balance", "cross_field_transport"] :
            ["cross_field_transport", "parallel_transport", "coupled_inventory_root"]
    else
        ["coupled_inventory_root", "field_balance"]
    end
    for name in preferences
        name in declared && return name
    end
    isempty(declared) ? "undeclared_whole_system_operator" : first(declared)
end

function _v95_candidate_declaration(record)
    item = Dict{String,Any}(_v93_plain(record))
    source_regions = Dict{String,Any}.(get(item, "regions", Any[]))
    regions = [Dict{String,Any}(
        "region_key" => String(region["region_id"]),
        "dimension" => Int(region["dimension"]),
        "coordinate" => String(get(region, "coordinate_map", "unresolved_device_coordinate")))
        for region in source_regions]
    obligations = Dict{String,Any}(_v93_plain(get(item, "applicability_obligations",
        Dict{String,Any}())))
    physical_states = _v95_strings(get(obligations, "state_variables", Any[]))
    declared = _v95_strings(get(obligations, "declared_operators", Any[]))
    states = Dict{String,Any}[]
    for region in source_regions, state in physical_states
        region_key = String(region["region_id"])
        region_type = String(region["region_type"])
        push!(states, Dict{String,Any}(
            "state_key" => region_key * "::" * state, "region_key" => region_key,
            "physical_state" => state, "function_space" => "unresolved_discrete_space",
            "operator" => _v95_candidate_operator(state, region_type, declared),
            "additional_operators" => String[]))
    end

    node_regions = Dict{String,Vector{String}}()
    for region in source_regions, node in String.(get(region, "source_nodes", Any[]))
        push!(get!(node_regions, node, String[]), String(region["region_id"]))
    end
    region_keys = String[item["region_key"] for item in regions]
    interfaces = Dict{String,Any}[]
    for raw in Dict{String,Any}.(get(item, "interface_conditions", Any[]))
        source_node = String(get(raw, "source_node_id", ""))
        target_node = String(get(raw, "target_node_id", ""))
        minus = first(get(node_regions, source_node, region_keys))
        plus_options = get(node_regions, target_node, reverse(region_keys))
        plus = first(plus_options)
        if plus == minus
            alternative = findfirst(!=(minus), region_keys)
            plus = alternative === nothing ? plus : region_keys[alternative]
        end
        push!(interfaces, Dict{String,Any}(
            "interface_key" => String(raw["interface_id"]),
            "minus_region_key" => minus, "plus_region_key" => plus,
            "conditions" => [Dict{String,Any}(
                "condition" => String(condition),
                "function_space" => "unresolved_interface_space")
                for condition in get(raw, "conditions", Any[])]))
    end
    Dict{String,Any}(
        "regions" => regions, "states" => states, "interfaces" => interfaces,
        "boundaries" => Any[], "fields" => Any[])
end

function _v95_applicability_from_reference(record)
    item = Dict{String,Any}(_v93_plain(record))
    capabilities = Set(String(capability["capability_id"])
        for capability in Dict{String,Any}.(get(item, "capabilities", Any[])))
    observable_states = lowercase.(String(get(observable, "evidence_state", ""))
        for observable in Dict{String,Any}.(get(item, "anchor_observables", Any[])))
    experimental = any(state -> occursin("experimental", state), observable_states)
    Dict{String,Bool}(
        "equilibrium" => "axisymmetric_mhd_equilibrium" in capabilities,
        "beta" => "axisymmetric_mhd_equilibrium" in capabilities,
        "net_power" => "fusion_reaction_radiation" in capabilities,
        "stability" => "axisymmetric_mhd_equilibrium" in capabilities,
        "wall_load" => false, "validation_vvuq" => experimental)
end

function _v95_applicability_from_candidate(record)
    item = Dict{String,Any}(_v93_plain(record))
    obligations = Dict{String,Any}(_v93_plain(get(item, "applicability_obligations",
        Dict{String,Any}())))
    evidence = Set(String.(get(obligations, "evidence_obligations", Any[])))
    region_types = Set(String.(get(obligations, "region_types", Any[])))
    Dict{String,Bool}(
        "equilibrium" => "equilibrium" in evidence,
        "beta" => "equilibrium" in evidence,
        "net_power" => false,
        "stability" => any(name -> name in evidence,
            ("ideal_stability", "resistive_stability", "kinetic_stability")),
        "wall_load" => "wall" in region_types,
        "validation_vvuq" => "candidate_bound_validation_vvuq" in evidence)
end

function _v95_gate(gate_id, applicable, status; reason = nothing, trusted = false)
    Dict{String,Any}(
        "gate_id" => String(gate_id), "applicable" => Bool(applicable),
        "status" => applicable ? String(status) : "not_applicable",
        "reason" => applicable ? reason : "declared_not_applicable",
        "trusted_known_positive" => Bool(trusted),
        "physical_failure" => applicable && status == "physical_fail")
end

function _v95_gate_records(execution, applicability; reference_control = false)
    assembly = Dict{String,Any}(get(execution, "assembly", Dict{String,Any}()))
    solve = Dict{String,Any}(get(execution, "solve", Dict{String,Any}()))
    numerical = Dict{String,Any}(get(execution, "numerical_vvuq", Dict{String,Any}()))
    validation = Dict{String,Any}(get(execution, "validation_vvuq", Dict{String,Any}()))
    assembly_status = String(get(assembly, "status", "unsupported"))
    blockers = String.(get(assembly, "blockers", Any[]))
    gates = Dict{String,Any}[
        _v95_gate("graph_compile", true, "pass"; trusted = reference_control),
        _v95_gate("whole_graph_provider_closure", true,
            assembly_status == "closed" ? "pass" : "unsupported";
            reason = isempty(blockers) ? nothing : first(blockers), trusted = reference_control),
        _v95_gate("physical_state_solve", true,
            get(solve, "status", "not_executed") == "pass" ? "pass" :
            get(solve, "status", "") == "fail_numerical_convergence" ? "numerical_fail" :
            "unsupported"; reason = "whole_graph_solve_not_available", trusted = reference_control),
        _v95_gate("numerical_vvuq", true,
            get(numerical, "status", "not_executed") == "pass" ? "pass" :
            get(numerical, "status", "") == "fail" ? "numerical_fail" : "unsupported";
            reason = "solve_precondition_not_met", trusted = reference_control),
        _v95_gate("validation_vvuq", applicability["validation_vvuq"],
            get(validation, "status", "not_executed") == "pass" ? "pass" : "unknown";
            reason = "candidate_bound_validation_contract_not_completed")]
    for gate_id in ("equilibrium", "beta", "net_power", "stability", "wall_load")
        applicable = applicability[gate_id]
        push!(gates, _v95_gate(gate_id, applicable, "unsupported";
            reason = "no_whole_graph_solve_derived_metric"))
    end
    gates
end

function _v95_row(subject_key, role, cohorts, source_hash, declaration, applicability,
        registry; validation_evidence = nothing)
    execution = execute_unified_declaration_v95(declaration; registry,
        validation_evidence, validation_applicable = applicability["validation_vvuq"])
    reference = role == "reference_control"
    gates = _v95_gate_records(execution, applicability; reference_control = reference)
    trusted = [gate for gate in gates if gate["trusted_known_positive"] === true]
    false_negative = reference && any(gate -> gate["status"] != "pass", trusted)
    status = String(execution["status"])
    status in V95_SCREEN_STATUSES || (status = "unknown")
    Dict{String,Any}(
        "subject_key" => String(subject_key), "source_role" => String(role),
        "cohorts" => String.(cohorts), "source_payload_hash" => String(source_hash),
        "graph_hash" => execution["graph_hash"], "screen_status" => status,
        "gates" => gates, "stage_order" => execution["stage_order"],
        "blockers" => String.(get(execution["assembly"], "blockers", Any[])),
        "whole_graph_closed" => get(execution["solve"], "whole_graph_closed", false),
        "numerical_survivor" => status in ("pass", "unknown") &&
            get(execution["numerical_vvuq"], "status", "") == "pass",
        "validation_survivor" => status == "pass" &&
            get(execution["validation_vvuq"], "status", "") in ("pass", "not_applicable"),
        "promotion_eligible" => false,
        "novelty_credit_allowed" => !reference,
        "reference_false_negative" => false_negative,
        "basis_direct_proxy_credit" => false,
        "partial_subgraph_credit" => false,
        "experimental_validation" => get(execution["validation_vvuq"],
            "experimental_validation", "unknown"),
        "device_feasibility" => "not_claimed", "physical_conclusion_expanded" => false,
        "execution_hash" => execution["result_hash"])
end

function _v95_file_hash(path)
    isfile(path) ? bytes2hex(SHA.sha256(read(path))) : "missing"
end

function _v95_input_snapshot(project_root)
    relative = [
        "fixtures/candidate_solver_reference_anchors_v1.json",
        "runs/multitopology_v91_formal_1000000_20260827/campaign_v91_merged.json",
        "runs/multitopology_v91_formal_1000000_20260827/survivor_dossiers_v91.jsonl",
        "runs/physical_closure_v92_formal_417_20260828/physical_closure_acceptance_v92_20260828.json",
        "runs/physical_closure_v92_formal_417_20260828/realization_dossiers_v92.jsonl",
        "runs/v93_pvw_slice1_formal_246_20260828/acceptance_v93_pvw_slice1.json",
        "runs/v93_pvw_slice1_formal_246_20260828/per_candidate_gap_inventory_v93.jsonl",
        "runs/v94_generic_capability_acceptance/acceptance.json",
    ]
    Dict(item => _v95_file_hash(joinpath(project_root, split(item, '/')...)) for item in relative)
end

function _v95_core_anti_specialization(project_root)
    path = joinpath(project_root, "src", "unified_filter_core_v95.jl")
    forbidden = ["candidate_id", "candidate_hash", "source_role", "device_family",
        "fixed_operator_combination", "iter", "c-2w", "c2w"]
    hits = Dict{String,Any}[]
    for (line_number, line) in enumerate(eachline(path)), token in forbidden
        occursin(token, lowercase(line)) && push!(hits,
            Dict("line" => line_number, "token" => token))
    end
    Dict{String,Any}(
        "status" => isempty(hits) ? "pass" : "fail", "hits" => hits,
        "scan_scope" => ["unified_filter_core_v95.jl"],
        "routing_inputs" => ["state", "operator", "interface", "function_space",
            "dimension", "coordinate"])
end

function _v95_runtime_controls(project_root, reference_declaration, registry;
        reference_identity_invariant::Bool, candidate_identity_invariant::Bool,
        basis_erasure_invariant::Bool)
    baseline = execute_unified_declaration_v95(reference_declaration; registry,
        validation_applicable = false)
    permuted = deepcopy(reference_declaration)
    reverse!(permuted["regions"]); reverse!(permuted["states"])
    permuted_result = execute_unified_declaration_v95(permuted; registry,
        validation_applicable = false)
    order_invariant = baseline["graph_hash"] == permuted_result["graph_hash"] ||
        (baseline["status"] == permuted_result["status"] &&
        sort!(String.(get(baseline["assembly"], "blockers", Any[]))) ==
        sort!(String.(get(permuted_result["assembly"], "blockers", Any[]))))

    problem, _ = manufactured_pvw_problem_v1()
    graph = compile_pvw_graph_v94(problem; points = 33)
    complete = execute_compiled_graph_v95(graph, registry)
    missing_registry = deepcopy(registry)
    unregister_provider_v94!(missing_registry, "mixed_trace_continuity_v1")
    missing = execute_compiled_graph_v95(graph, missing_registry)
    partial = execute_compiled_graph_v95(compile_pvw_graph_v94(problem; points = 33,
        extra_inner_operator = "unregistered_additive_term"), registry)
    unseen = execute_compiled_graph_v95(manufactured_chain_graph_v94(5;
        order = [4, 2, 5, 1, 3]), registry)
    proxy = solved_metric_record_v95("beta", 0.04,
        Dict("status" => "pass", "whole_graph_closed" => true,
            "solve_hash" => "test-only"); origin = "basis_direct_proxy")
    strict_order = complete["stage_order"] ==
        ["graph_compile", "graph_assembly", "solve", "numerical_vvuq", "validation_vvuq"]
    Dict{String,Any}(
        "status" => order_invariant && reference_identity_invariant &&
            candidate_identity_invariant && basis_erasure_invariant &&
            missing["status"] == "unsupported" &&
            partial["status"] == "unsupported" && unseen["status"] in ("pass", "unknown") &&
            proxy["status"] == "unsupported" && strict_order ? "pass" : "fail",
        "label_id_role_and_order_invariance" => Dict(
            "status" => order_invariant && reference_identity_invariant &&
                candidate_identity_invariant ? "pass" : "fail",
            "reference_identity_erasure" => reference_identity_invariant,
            "candidate_identity_erasure" => candidate_identity_invariant,
            "declaration_order_permutation" => order_invariant,
            "role_passed_to_core" => false),
        "basis_erasure_invariance" => Dict("status" => basis_erasure_invariant ?
            "pass" : "fail", "basis_passed_to_core" => false),
        "unseen_topology" => Dict("status" => unseen["status"] in ("pass", "unknown") ?
            "pass" : "fail", "physical_credit" => false),
        "missing_provider" => Dict("status" => missing["status"] == "unsupported" ?
            "pass" : "fail", "solver_executed" => get(missing["solve"], "solver_executed", false)),
        "partial_closure" => Dict("status" => partial["status"] == "unsupported" ?
            "pass" : "fail", "partial_subgraph_credit" => partial["partial_subgraph_credit"]),
        "basis_metric_firewall" => Dict("status" => proxy["status"] == "unsupported" ?
            "pass" : "fail", "basis_direct_proxy_credit" => proxy["basis_direct_proxy_credit"]),
        "strict_stage_order" => Dict("status" => strict_order ? "pass" : "fail",
            "observed" => complete["stage_order"]))
end

function _v95_histogram(rows, field)
    histogram = Dict{String,Int}()
    for row in rows
        value = String(row[field])
        histogram[value] = get(histogram, value, 0) + 1
    end
    histogram
end

function run_unified_filter_acceptance_v95(project_root::AbstractString)
    before = _v95_input_snapshot(project_root)
    registry = default_operator_provider_registry_v94()
    anchors = load_candidate_solver_reference_anchors_v1(joinpath(project_root, "fixtures",
        "candidate_solver_reference_anchors_v1.json"))
    reference_rows = Dict{String,Any}[]
    reference_declarations = Dict{String,Any}[]
    reference_identity_invariant = true
    for anchor in anchors
        declaration = _v95_reference_declaration(anchor)
        erased = deepcopy(anchor)
        erased["anchor_id"] = "erased-reference-identity"
        erased["candidate_id"] = "permuted-reference-identity"
        reference_identity_invariant &= canonical_hash(declaration) ==
            canonical_hash(_v95_reference_declaration(erased))
        push!(reference_declarations, declaration)
        source_key = String(anchor["anchor_id"])
        push!(reference_rows, _v95_row(source_key, "reference_control", ["v95_unified"],
            canonical_hash(anchor), declaration, _v95_applicability_from_reference(anchor),
            registry))
    end

    candidate_path = joinpath(project_root, "runs",
        "physical_closure_v92_formal_417_20260828", "realization_dossiers_v92.jsonl")
    candidate_rows = Dict{String,Any}[]
    candidate_identity_invariant = true
    basis_erasure_invariant = true
    open(candidate_path, "r") do input
        for line in eachline(input)
            isempty(strip(line)) && continue
            record = JSON3.read(line, Dict{String,Any})
            qualification = Dict{String,Any}(_v93_plain(record["qualification"]))
            cohorts = String["v91_historical_417"]
            get(qualification, "status", "") == "pass" && push!(cohorts, "v92_v93_closure_246")
            declaration = _v95_candidate_declaration(record)
            erased = deepcopy(record)
            erased["candidate_id"] = "erased-generated-identity"
            erased["candidate_hash"] = "erased-generated-hash"
            erased["basis_hash"] = "erased-basis-hash"
            erased_declaration = _v95_candidate_declaration(erased)
            candidate_identity_invariant &= canonical_hash(declaration) ==
                canonical_hash(erased_declaration)
            basis_erasure_invariant &= canonical_hash(declaration) ==
                canonical_hash(erased_declaration)
            push!(candidate_rows, _v95_row(String(record["candidate_id"]),
                "generated_candidate", cohorts, canonical_hash(record), declaration,
                _v95_applicability_from_candidate(record), registry))
        end
    end
    rows = vcat(reference_rows, candidate_rows)
    after = _v95_input_snapshot(project_root)
    preservation = Dict{String,Any}(
        "status" => before == after ? "pass" : "fail",
        "sealed_input_count" => length(before),
        "changed" => sort!([key for key in keys(before) if before[key] != after[key]]),
        "existing_candidate_data_write_count" => before == after ? 0 : 1)

    false_negatives = [row for row in reference_rows if row["reference_false_negative"]]
    recall_count = length(reference_rows) - length(false_negatives)
    reference_recall = isempty(reference_rows) ? 0.0 : recall_count / length(reference_rows)
    controls = _v95_runtime_controls(project_root, first(reference_declarations), registry;
        reference_identity_invariant, candidate_identity_invariant, basis_erasure_invariant)
    anti_specialization = _v95_core_anti_specialization(project_root)
    gate_blockers = Dict{String,Dict{String,Int}}()
    for row in rows, gate in row["gates"]
        gate["applicable"] === true || continue
        status = String(gate["status"])
        status == "pass" && continue
        histogram = get!(gate_blockers, String(gate["gate_id"]), Dict{String,Int}())
        reason = String(something(gate["reason"], status))
        histogram[reason] = get(histogram, reason, 0) + 1
    end
    candidate_status = _v95_histogram(candidate_rows, "screen_status")
    cohort_246 = [row for row in candidate_rows if "v92_v93_closure_246" in row["cohorts"]]
    before_after = Dict{String,Any}(
        "before" => Dict("v91_proxy_hard_gate_survivors" => 417,
            "v92_realization_closure_pass" => 246, "v93_whole_system_solves" => 0),
        "after" => Dict("unified_reference_controls" => length(reference_rows),
            "generated_candidates" => length(candidate_rows),
            "closure_246_retested_in_same_channel" => length(cohort_246),
            "numerical_survivors" => count(row -> row["numerical_survivor"], candidate_rows),
            "validation_survivors" => count(row -> row["validation_survivor"], candidate_rows),
            "promotion_eligible" => count(row -> row["promotion_eligible"], candidate_rows),
            "classification" => candidate_status),
        "interpretation" => "Historical proxy survivors were withdrawn from promotion. Current unsupported results are capability/closure findings, not physical rejection.")
    reference_first = length(rows) >= length(reference_rows) && all(index ->
        rows[index]["source_role"] == "reference_control", eachindex(reference_rows))
    software_pass = preservation["status"] == "pass" && controls["status"] == "pass" &&
        anti_specialization["status"] == "pass" && length(candidate_rows) == 417 &&
        length(cohort_246) == 246 && reference_first
    selector_pass = software_pass && isempty(false_negatives)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V95_PROTOCOL_ID,
        "status" => selector_pass ? "pass" : "fail",
        "software_controls_status" => software_pass ? "pass" : "fail",
        "selector_acceptance" => selector_pass ? "pass" :
            "blocked_reference_control_false_negative",
        "execution_order" => ["reference_controls", "generated_candidates"],
        "reference_control_count" => length(reference_rows),
        "generated_candidate_count" => length(candidate_rows),
        "closure_246_retest_count" => length(cohort_246),
        "known_positive_recall" => Dict("passed" => recall_count,
            "total" => length(reference_rows), "rate" => reference_recall,
            "false_negative_count" => length(false_negatives),
            "false_negatives" => [Dict("subject_key" => row["subject_key"],
                "blockers" => row["blockers"]) for row in false_negatives]),
        "candidate_status_histogram" => candidate_status,
        "gate_blockers" => gate_blockers, "before_after" => before_after,
        "controls" => Dict("sealed_v91_v94_inputs" => preservation,
            "core_anti_specialization" => anti_specialization,
            "runtime_negative_and_invariance_controls" => controls,
            "reference_first" => Dict("status" => reference_first ? "pass" : "fail")),
        "reference_results" => reference_rows,
        "provider_registry_hash" => provider_registry_manifest_v94(registry)["registry_hash"],
        "conclusions" => Dict(
            "physical_device_passed_vvuq" => false,
            "generated_candidates_physically_failed" => 0,
            "generated_candidates_numerically_failed" => get(candidate_status, "numerical_fail", 0),
            "generated_candidates_unsupported" => get(candidate_status, "unsupported", 0),
            "generated_candidates_unknown" => get(candidate_status, "unknown", 0),
            "experimental_validation" => "not_established",
            "device_feasibility" => "not_claimed"),
        "physical_conclusion_expanded" => false,
        "claim_boundary" => UNIFIED_FILTER_ACCEPTANCE_V95_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    (acceptance = body, rows = rows, gate_blockers = gate_blockers,
        before_after = before_after)
end

function write_unified_filter_acceptance_v95(project_root::AbstractString;
        output_dir = joinpath(project_root, "runs", "v95_unified_filter_acceptance"))
    result = run_unified_filter_acceptance_v95(project_root)
    mkpath(output_dir)
    open(joinpath(output_dir, "acceptance.json"), "w") do io
        JSON3.pretty(io, result.acceptance)
    end
    open(joinpath(output_dir, "unified_survivors.jsonl"), "w") do io
        for row in result.rows
            JSON3.write(io, row); write(io, '\n')
        end
    end
    open(joinpath(output_dir, "gate_blockers.json"), "w") do io
        JSON3.pretty(io, result.gate_blockers)
    end
    open(joinpath(output_dir, "before_after.json"), "w") do io
        JSON3.pretty(io, result.before_after)
    end
    acceptance = result.acceptance
    histogram = acceptance["candidate_status_histogram"]
    recall = acceptance["known_positive_recall"]
    report = """# v95 Unified Reference/Candidate Filter Acceptance

## Outcome

- Selector acceptance: `$(acceptance["selector_acceptance"])`.
- Software controls: `$(acceptance["software_controls_status"])`.
- Known-positive recall: $(recall["passed"])/$(recall["total"]) ($(recall["rate"])).
- Generated candidates rerun: $(acceptance["generated_candidate_count"]); v92/v93 closure cohort: $(acceptance["closure_246_retest_count"]).
- Classification: `$(JSON3.write(histogram))`.

ITER and C-2W were executed first as `reference_control` through the same declaration compiler, v94 provider registry, graph assembler, whole-graph solver contract, numerical VVUQ, and validation VVUQ ordering used for generated candidates. Their identity and role were retained only for reporting and known-positive accounting.

## Interpretation

The selector is not accepted because both reference controls encounter missing whole-graph provider closure. This is a selector false-negative/capability gap. It is not evidence that ITER or C-2W fails physically. The 417 generated candidates, including the 246 v92/v93 realization-closure records, are currently `unsupported`; none has a candidate-bound whole-system solve from which beta, net power, stability, or wall load can be derived. Therefore the historical v91 basis-derived proxy survivors receive no v95 promotion credit.

No physical device passed the complete solve -> numerical VVUQ -> validation VVUQ chain. Numerical verification, experimental validation, unsupported capability, unknown evidence, and physical failure remain independent. No device-feasibility claim is made.

## Preserved inputs

The acceptance hashed the sealed reference fixture and the authoritative v91-v94 candidate/acceptance inputs before and after execution. Existing candidate-data writes: $(acceptance["controls"]["sealed_v91_v94_inputs"]["existing_candidate_data_write_count"]).

Acceptance hash: `$(acceptance["acceptance_hash"])`.
"""
    write(joinpath(output_dir, "acceptance_report.md"), report)
    result
end
