const PROVIDER_CLOSURE_ACCEPTANCE_V96_CLAIM_BOUNDARY =
    "Acceptance establishes reduced provider closure and numerical execution in declared domains. Unsupported declarations, unknown validation, numerical failure, and physical failure remain distinct; no experimental or device-feasibility conclusion is promoted."

function _v96_validation_applicable(record)
    states = lowercase.(String(get(item, "evidence_state", ""))
        for item in Dict{String,Any}.(get(record, "anchor_observables", Any[])))
    any(value -> occursin("experimental", value), states)
end

function _v96_subject_row(subject_key, role, cohorts, source_hash, physics, registry;
        validation_applicable, validation_evidence = nothing)
    execution = execute_physical_stage_chain_v96(physics; registry,
        validation_applicable, validation_evidence)
    assembly = Dict{String,Any}(execution["assembly"])
    solve = Dict{String,Any}(execution["solve"])
    numerical = Dict{String,Any}(execution["numerical_vvuq"])
    validation = Dict{String,Any}(execution["validation_vvuq"])
    trusted_pass = assembly["status"] == "closed" && get(solve, "status", "") == "pass" &&
        get(numerical, "status", "") == "pass"
    reference = role == "reference_control"
    status = String(execution["status"])
    status in ("pass", "physical_fail", "numerical_fail", "unsupported", "unknown") ||
        (status = "unknown")
    metrics = get(get(execution, "observables", Dict{String,Any}()), "metrics",
        Dict{String,Any}())
    row = Dict{String,Any}(
        "subject_key" => String(subject_key), "source_role" => String(role),
        "cohorts" => String.(cohorts), "source_payload_hash" => String(source_hash),
        "screen_status" => status, "stage_order" => execution["stage_order"],
        "graph_hash" => execution["graph_hash"], "assembly_hash" => assembly["assembly_hash"],
        "solve_hash" => get(solve, "solve_hash", nothing),
        "whole_graph_closed" => get(solve, "whole_graph_closed", false),
        "numerical_vvuq" => get(numerical, "status", "not_executed"),
        "validation_vvuq" => get(validation, "status", "not_executed"),
        "metrics" => metrics, "blockers" => String.(get(assembly, "blockers", Any[])),
        "trusted_applicable_chain_pass" => trusted_pass,
        "reference_false_negative" => reference && !trusted_pass,
        "novelty_credit_allowed" => !reference,
        "promotion_eligible" => !reference && status == "pass" &&
            get(validation, "status", "") == "pass",
        "basis_direct_proxy_credit" => false, "partial_subgraph_credit" => false,
        "experimental_validation" => get(validation, "experimental_validation", "unknown"),
        "device_feasibility" => "not_claimed", "physical_conclusion_expanded" => false,
        "execution_hash" => execution["result_hash"])
    row, Dict{String,Any}.(get(assembly, "routes", Any[]))
end

function _v96_coverage_matrix(route_sets)
    counts = Dict{String,Dict{String,Int}}()
    for routes in route_sets, route in routes
        key = String(route["requirement_key"])
        family = first(split(key, "::"))
        record = get!(counts, family, Dict("closed" => 0, "unsupported" => 0,
            "ambiguous" => 0))
        status = String(route["status"])
        record[status] = get(record, status, 0) + 1
    end
    total_closed = sum(get(value, "closed", 0) for value in values(counts))
    total_unsupported = sum(get(value, "unsupported", 0) for value in values(counts))
    total_ambiguous = sum(get(value, "ambiguous", 0) for value in values(counts))
    body = Dict{String,Any}(
        "status" => total_unsupported == 0 && total_ambiguous == 0 ? "pass" : "fail",
        "by_requirement_kind" => counts, "closed" => total_closed,
        "unsupported" => total_unsupported, "ambiguous" => total_ambiguous,
        "routing_axes" => ["kind", "physical_states", "operator", "source_space",
            "target_space", "source_dimension", "target_dimension",
            "source_coordinate", "target_coordinate"])
    body["coverage_hash"] = canonical_hash(body)
    body
end

function _v96_input_snapshot(project_root)
    relative = [
        "fixtures/candidate_solver_reference_anchors_v1.json",
        "runs/multitopology_v91_formal_1000000_20260827/campaign_v91_merged.json",
        "runs/multitopology_v91_formal_1000000_20260827/survivor_dossiers_v91.jsonl",
        "runs/physical_closure_v92_formal_417_20260828/realization_dossiers_v92.jsonl",
        "runs/physical_closure_v92_formal_417_20260828/physical_closure_acceptance_v92_20260828.json",
        "runs/v93_pvw_slice1_formal_246_20260828/acceptance_v93_pvw_slice1.json",
        "runs/v94_generic_capability_acceptance/acceptance.json",
        "runs/v95_unified_filter_acceptance/acceptance.json",
        "runs/v95_unified_filter_acceptance/unified_survivors.jsonl",
    ]
    Dict(item => _v95_file_hash(joinpath(project_root, split(item, '/')...)) for item in relative)
end

function _v96_core_anti_specialization(project_root)
    files = ["physical_provider_runtime_v96.jl", "physical_vvuq_runtime_v96.jl"]
    forbidden = ["candidate_id", "candidate_hash", "source_role", "device_family",
        "parent_family", "fixed_operator_combination", "basis_coefficients"]
    hits = Dict{String,Any}[]
    for file in files
        for (line_number, line) in enumerate(eachline(joinpath(project_root, "src", file)))
            for token in forbidden
                occursin(token, lowercase(line)) && push!(hits,
                    Dict("file" => file, "line" => line_number, "token" => token))
            end
        end
    end
    Dict{String,Any}(
        "status" => isempty(hits) ? "pass" : "fail", "hits" => hits,
        "scan_scope" => files, "identity_or_basis_passed_to_provider" => false)
end

function _v96_controls(reference_record, generated_record, registry)
    reference_physics = normalize_reference_physics_v96(reference_record)
    reference_execution = execute_physical_stage_chain_v96(reference_physics; registry,
        validation_applicable = false)
    generated_physics = normalize_generated_physics_v96(generated_record)
    generated_execution = execute_physical_stage_chain_v96(generated_physics; registry)

    reference_erased = deepcopy(reference_record)
    reference_erased["anchor_id"] = "erased-reference"
    reference_erased["candidate_id"] = "permuted-reference"
    generated_erased = deepcopy(generated_record)
    generated_erased["candidate_id"] = "erased-generated"
    generated_erased["candidate_hash"] = "erased-hash"
    generated_erased["basis_hash"] = "erased-basis"
    identity_pass = canonical_hash(reference_physics) ==
        canonical_hash(normalize_reference_physics_v96(reference_erased)) &&
        canonical_hash(generated_physics) ==
        canonical_hash(normalize_generated_physics_v96(generated_erased))

    graph = compile_physical_graph_v96(generated_physics)
    mixed_routes = [route for route in generated_execution["assembly"]["routes"]
        if occursin("interface", String(route["requirement_key"]))]
    missing_registry = deepcopy(registry)
    missing_key = isempty(mixed_routes) ? "field_balance_provider_v96" :
        String(first(mixed_routes)["selected_provider"])
    unregister_physical_provider_v96!(missing_registry, missing_key)
    missing_assembly = assemble_physical_graph_v96(graph, missing_registry)
    partial_graph = deepcopy(graph)
    extra = deepcopy(first(partial_graph["requirements"]))
    extra["requirement_key"] = "additional::unregistered_negative_control"
    extra["operator"] = "unregistered_negative_control"
    extra["kind"] = "additional_operator"
    push!(partial_graph["requirements"], extra)
    partial_assembly = assemble_physical_graph_v96(partial_graph, registry)
    metric = solved_physical_metric_v96("beta", 0.04,
        Dict("status" => "pass", "whole_graph_closed" => true,
            "solve_hash" => "negative-control"); units = "1",
        evidence_ceiling = "negative_control")
    strict_order = reference_execution["stage_order"] == ["graph_compile",
        "provider_closure", "solve", "numerical_vvuq", "solve_derived_observables",
        "validation_vvuq"]
    interface_pass = !isempty(mixed_routes) && all(route -> route["status"] == "closed",
        mixed_routes)
    pass = identity_pass && missing_assembly.status == "unsupported" &&
        partial_assembly.status == "unsupported" && metric["status"] == "available" &&
        metric["solve_hash"] == "negative-control" && strict_order && interface_pass
    Dict{String,Any}(
        "status" => pass ? "pass" : "fail",
        "identity_label_basis_erasure" => Dict("status" => identity_pass ? "pass" : "fail",
            "identity_or_basis_passed_to_provider" => false),
        "coordinate_and_mixed_dimension_interfaces" => Dict(
            "status" => interface_pass ? "pass" : "fail",
            "closed_interface_requirement_count" => count(route -> route["status"] == "closed",
                mixed_routes)),
        "missing_provider" => Dict("status" => missing_assembly.status == "unsupported" ?
            "pass" : "fail", "solver_executed" => false),
        "partial_closure" => Dict("status" => partial_assembly.status == "unsupported" ?
            "pass" : "fail", "partial_subgraph_credit" => false),
        "solve_hash_metric_firewall" => Dict("status" => metric["status"] == "available" &&
            metric["solve_hash"] == "negative-control" ? "pass" : "fail",
            "basis_direct_proxy_credit" => false),
        "strict_stage_order" => Dict("status" => strict_order ? "pass" : "fail",
            "observed" => reference_execution["stage_order"]))
end

function _v96_histogram(rows, key)
    counts = Dict{String,Int}()
    for row in rows
        value = String(row[key]); counts[value] = get(counts, value, 0) + 1
    end
    counts
end

function _v96_blocker_histogram(rows)
    counts = Dict{String,Int}()
    for row in rows, blocker in row["blockers"]
        key = String(blocker); counts[key] = get(counts, key, 0) + 1
    end
    counts
end

function _v96_structural_inventory(topology)
    nodes = Dict{String,Any}.(topology["nodes"])
    Dict{String,Any}(
        "dimensions" => sort!(unique(String(node["dimension"]) for node in nodes)),
        "boundaries" => sort!(unique(String(node["boundary"]) for node in nodes)),
        "field_semantics" => sort!(unique(String(node["field_semantics"]) for node in nodes)),
        "operators" => sort!(unique(String(node["operator"]) for node in nodes)))
end

function _v96_synthetic_realization(index::Integer)
    topology = generate_family_neutral_topology_v91(index;
        relabel_nonce = mod(index, 7) + 1)
    input = compile_candidate_bound_screen_input_v91(topology, index)
    body = Dict{String,Any}(
        "candidate_id" => "v96-replay-$(index)", "request_index" => Int(index),
        "genome" => Dict("grammar_id" => topology["grammar_id"],
            "structural_gene_digits" => topology["structural_gene_digits"],
            "topology" => topology), "basis" => input["basis_coefficients"],
        "realization" => Dict("solver_input_hash" => input["solver_input_hash"],
            "capability_inventory" => input["capability_inventory"],
            "capability_cell" => input["capability_cell"]))
    body["dossier_hash"] = canonical_hash(body)
    physical_realization_to_dict_v92(compile_physical_realization_v92(body))
end

function replay_million_no_proxy_v96(project_root::AbstractString;
        total::Integer = 1_000_000, representatives_per_cell::Integer = 8,
        execute_frontier::Bool = true)
    total_int = Int(total); per_cell = Int(representatives_per_cell)
    total_int > 0 || throw(ArgumentError("replay total must be positive"))
    per_cell > 0 || throw(ArgumentError("representatives_per_cell must be positive"))
    root = joinpath(project_root, "runs", "multitopology_v91_formal_1000000_20260827")
    cells = Dict{String,Int}(); representatives = Dict{String,Vector{Int}}()
    processed = 0; structurally_routed = 0
    for shard in 1:20
        path = joinpath(root, "results_shard_$(lpad(shard, 3, '0')).jsonl")
        open(path, "r") do io
            for line in eachline(io)
                processed >= total_int && break
                index_match = match(r"\"request_index\":([0-9]+)", line)
                cell_match = match(r"\"capability_cell\":\"([0-9a-f]+)\"", line)
                type_match = match(r"\"type_status\":\"([^\"]+)\"", line)
                route_match = match(r"\"route_status\":\"([^\"]+)\"", line)
                any(value -> value === nothing, (index_match, cell_match, type_match, route_match)) &&
                    throw(ArgumentError("v91 replay line is missing structural fields"))
                index = parse(Int, index_match.captures[1]); cell = cell_match.captures[1]
                processed += 1
                cells[cell] = get(cells, cell, 0) + 1
                structural_pass = type_match.captures[1] == "pass" &&
                    route_match.captures[1] == "pass"
                structural_pass || continue
                structurally_routed += 1
                selected = get!(representatives, cell, Int[])
                length(selected) < per_cell && push!(selected, index)
            end
        end
        processed >= total_int && break
    end
    processed == total_int || throw(ArgumentError(
        "million replay expected $(total_int) rows, processed $(processed)"))
    stored = JSON3.read(read(joinpath(root, "campaign_v91_merged.json"), String),
        Dict{String,Any})
    histogram_match = total_int == 1_000_000 ? Dict{String,Int}(String(key) => Int(value)
        for (key, value) in stored["capability_cells"]) == cells : true
    frontier_rows = Dict{String,Any}[]
    if execute_frontier
        registry = default_physical_provider_registry_v96()
        for cell in sort!(collect(keys(representatives)))
            chosen = nothing; realization = nothing
            for index in representatives[cell]
                trial = _v96_synthetic_realization(index)
                qualification = Dict{String,Any}(trial["qualification"])
                if get(qualification, "status", "") == "pass"
                    chosen = index; realization = trial; break
                end
            end
            if chosen === nothing
                push!(frontier_rows, Dict{String,Any}(
                    "capability_cell" => cell, "request_index" => nothing,
                    "screen_status" => "unsupported", "reason" =>
                        "no_structurally_complete_realization_in_preregistered_cell_sample",
                    "high_cost_executed" => false, "basis_metric_credit" => false))
                continue
            end
            physics = normalize_generated_physics_v96(realization)
            execution = execute_physical_stage_chain_v96(physics; registry)
            push!(frontier_rows, Dict{String,Any}(
                "capability_cell" => cell, "request_index" => chosen,
                "screen_status" => execution["status"], "high_cost_executed" => true,
                "graph_hash" => execution["graph_hash"],
                "solve_hash" => get(execution["solve"], "solve_hash", nothing),
                "numerical_vvuq" => get(execution["numerical_vvuq"], "status", "not_executed"),
                "validation_vvuq" => get(execution["validation_vvuq"], "status", "not_executed"),
                "basis_used_as_design_parameter" => true, "basis_metric_credit" => false,
                "physical_conclusion_expanded" => false))
        end
    end
    frontier_status = _v96_histogram(frontier_rows, "screen_status")
    body = Dict{String,Any}(
        "status" => histogram_match && processed == total_int ? "pass" : "fail",
        "source_campaign" => "multitopology_v91_formal_1000000_20260827",
        "processed" => processed, "structurally_routed" => structurally_routed,
        "capability_cell_count" => length(cells), "stored_histogram_match" => histogram_match,
        "fields_read_from_sealed_rows" => ["request_index", "capability_cell",
            "type_status", "route_status"],
        "basis_or_historical_physical_metrics_used_for_selection" => false,
        "representatives_per_cell_limit" => per_cell,
        "frontier_row_count" => length(frontier_rows),
        "frontier_status_histogram" => frontier_status,
        "high_cost_execution_scope" => "first structurally complete representative_per_capability_cell",
        "exhaustive_high_cost_solve_of_all_million" => false,
        "claim_boundary" => PROVIDER_CLOSURE_ACCEPTANCE_V96_CLAIM_BOUNDARY)
    body["replay_hash"] = canonical_hash(body)
    (summary = body, frontier_rows = frontier_rows)
end

function run_provider_closure_acceptance_v96(project_root::AbstractString;
        million_replay::Bool = false, million_total::Integer = 1_000_000,
        execute_million_frontier::Bool = true)
    before = _v96_input_snapshot(project_root)
    registry = default_physical_provider_registry_v96()
    anchors = load_candidate_solver_reference_anchors_v1(joinpath(project_root, "fixtures",
        "candidate_solver_reference_anchors_v1.json"))
    rows = Dict{String,Any}[]; route_sets = Vector{Dict{String,Any}}[]
    reference_rows = Dict{String,Any}[]
    for anchor in anchors
        physics = normalize_reference_physics_v96(anchor)
        row, routes = _v96_subject_row(String(anchor["anchor_id"]), "reference_control",
            ["v96_reference_control"], canonical_hash(anchor), physics, registry;
            validation_applicable = _v96_validation_applicable(anchor))
        push!(reference_rows, row); push!(rows, row); push!(route_sets, routes)
    end
    candidate_rows = Dict{String,Any}[]; first_qualified = nothing
    path = joinpath(project_root, "runs", "physical_closure_v92_formal_417_20260828",
        "realization_dossiers_v92.jsonl")
    open(path, "r") do io
        for line in eachline(io)
            isempty(strip(line)) && continue
            record = JSON3.read(line, Dict{String,Any})
            qualification = Dict{String,Any}(record["qualification"])
            cohorts = String["v91_historical_417"]
            if get(qualification, "status", "") == "pass"
                push!(cohorts, "v92_v93_closure_246")
                first_qualified === nothing && (first_qualified = deepcopy(record))
            end
            physics = normalize_generated_physics_v96(record)
            row, routes = _v96_subject_row(String(record["candidate_id"]),
                "generated_candidate", cohorts, canonical_hash(record), physics, registry;
                validation_applicable = true)
            push!(candidate_rows, row); push!(rows, row); push!(route_sets, routes)
        end
    end
    first_qualified === nothing && throw(ArgumentError("v96 requires a qualified control record"))
    coverage = _v96_coverage_matrix(route_sets)
    controls = _v96_controls(first(anchors), first_qualified, registry)
    anti = _v96_core_anti_specialization(project_root)
    false_negatives = [row for row in reference_rows if row["reference_false_negative"]]
    recall_passed = length(reference_rows) - length(false_negatives)
    recall_rate = isempty(reference_rows) ? 0.0 : recall_passed / length(reference_rows)
    references_pass = isempty(false_negatives)
    replay = if million_replay && references_pass && coverage["status"] == "pass"
        replay_million_no_proxy_v96(project_root; total = million_total,
            execute_frontier = execute_million_frontier)
    else
        (summary = Dict{String,Any}("status" => "not_executed",
            "reason" => million_replay ? "reference_or_provider_coverage_gate_failed" :
                "formal_million_replay_not_requested"), frontier_rows = Dict{String,Any}[])
    end
    after = _v96_input_snapshot(project_root)
    preservation = Dict{String,Any}(
        "status" => before == after ? "pass" : "fail",
        "sealed_input_count" => length(before),
        "changed" => sort!([key for key in keys(before) if before[key] != after[key]]),
        "existing_candidate_or_acceptance_write_count" => before == after ? 0 : 1)
    candidate_histogram = _v96_histogram(candidate_rows, "screen_status")
    blockers = _v96_blocker_histogram(rows)
    before_after = Dict{String,Any}(
        "before" => Dict("v95_reference_recall" => 0.0,
            "v95_generated_unsupported" => 417, "v95_numerical_survivors" => 0),
        "after" => Dict("v96_reference_recall" => recall_rate,
            "v96_generated_status" => candidate_histogram,
            "v96_provider_coverage" => coverage["status"],
            "v96_whole_graph_solve_count" => count(row -> row["whole_graph_closed"], rows),
            "v96_promotion_eligible" => count(row -> row["promotion_eligible"], rows)),
        "interpretation" => "Provider closure repairs software execution only; validation and device feasibility remain independent.")
    reference_first = all(index -> rows[index]["source_role"] == "reference_control",
        eachindex(reference_rows))
    software_pass = preservation["status"] == "pass" && controls["status"] == "pass" &&
        anti["status"] == "pass" && coverage["status"] == "pass" && reference_first &&
        length(candidate_rows) == 417 && count(row -> "v92_v93_closure_246" in row["cohorts"],
            candidate_rows) == 246
    replay_pass = !million_replay || replay.summary["status"] == "pass"
    accepted = software_pass && references_pass && replay_pass
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V96_PROTOCOL_ID,
        "status" => accepted ? "pass" : "fail",
        "software_controls_status" => software_pass ? "pass" : "fail",
        "selector_acceptance" => accepted ? "pass" :
            !references_pass ? "blocked_reference_control_false_negative" :
            !replay_pass ? "blocked_million_replay" : "blocked_software_controls",
        "execution_order" => ["manufactured_and_negative_controls", "reference_controls",
            "provider_coverage", "generated_417_with_246_subcohort", "million_no_proxy_replay"],
        "reference_control_count" => length(reference_rows),
        "generated_candidate_count" => length(candidate_rows),
        "closure_246_retest_count" => count(row -> "v92_v93_closure_246" in row["cohorts"],
            candidate_rows),
        "known_positive_recall" => Dict("passed" => recall_passed,
            "total" => length(reference_rows), "rate" => recall_rate,
            "false_negative_count" => length(false_negatives),
            "false_negatives" => [Dict("subject_key" => row["subject_key"],
                "blockers" => row["blockers"]) for row in false_negatives]),
        "candidate_status_histogram" => candidate_histogram,
        "provider_registry" => physical_provider_registry_manifest_v96(registry),
        "provider_coverage" => coverage, "blocker_statistics" => blockers,
        "before_after" => before_after, "million_no_proxy_replay" => replay.summary,
        "controls" => Dict("sealed_v91_v95_inputs" => preservation,
            "core_anti_specialization" => anti, "runtime_controls" => controls,
            "reference_first" => Dict("status" => reference_first ? "pass" : "fail")),
        "reference_results" => reference_rows,
        "conclusions" => Dict(
            "physical_device_passed_complete_vvuq" => false,
            "numerically_executed_reduced_reference_controls" => count(row ->
                row["trusted_applicable_chain_pass"], reference_rows),
            "generated_physical_fail" => get(candidate_histogram, "physical_fail", 0),
            "generated_numerical_fail" => get(candidate_histogram, "numerical_fail", 0),
            "generated_unsupported" => get(candidate_histogram, "unsupported", 0),
            "generated_unknown" => get(candidate_histogram, "unknown", 0),
            "experimental_validation" => "not_established",
            "device_feasibility" => "not_claimed"),
        "physical_conclusion_expanded" => false,
        "claim_boundary" => PROVIDER_CLOSURE_ACCEPTANCE_V96_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    (acceptance = body, rows = rows, coverage = coverage, blockers = blockers,
        before_after = before_after, frontier_rows = replay.frontier_rows)
end

function write_provider_closure_acceptance_v96(project_root::AbstractString;
        output_dir = joinpath(project_root, "runs", "v96_provider_closure_acceptance"),
        million_replay::Bool = true, million_total::Integer = 1_000_000,
        execute_million_frontier::Bool = true)
    result = run_provider_closure_acceptance_v96(project_root; million_replay,
        million_total, execute_million_frontier)
    mkpath(output_dir)
    for (name, value) in (("acceptance.json", result.acceptance),
            ("provider_coverage_matrix.json", result.coverage),
            ("blocker_statistics.json", result.blockers),
            ("before_after.json", result.before_after),
            ("million_no_proxy_replay.json", result.acceptance["million_no_proxy_replay"]))
        open(joinpath(output_dir, name), "w") do io; JSON3.pretty(io, value); end
    end
    open(joinpath(output_dir, "unified_survivor_table.jsonl"), "w") do io
        for row in result.rows; JSON3.write(io, row); write(io, '\n'); end
    end
    open(joinpath(output_dir, "million_frontier_high_cost.jsonl"), "w") do io
        for row in result.frontier_rows; JSON3.write(io, row); write(io, '\n'); end
    end
    acceptance = result.acceptance; recall = acceptance["known_positive_recall"]
    report = """# v96 Physical Provider Closure Acceptance

## Outcome

- Selector acceptance: `$(acceptance["selector_acceptance"])`.
- Software controls: `$(acceptance["software_controls_status"])`.
- ITER/C-2W trusted applicable chain recall: $(recall["passed"])/$(recall["total"]).
- Generated 417 classification: `$(JSON3.write(acceptance["candidate_status_histogram"]))`.
- Provider coverage: `$(acceptance["provider_coverage"]["status"])` with $(acceptance["provider_coverage"]["closed"]) closed obligations.
- Million no-proxy replay: `$(acceptance["million_no_proxy_replay"]["status"])`.

The same normalized physics compiler, physical provider registry, conservative interface assembler, whole-graph solver, numerical VVUQ, solve-derived observable firewall, and validation VVUQ ordering was used for reference controls and generated records. Identity, labels, and basis values are not provider-routing inputs. Basis-derived historical gate metrics receive no credit.

The v96 finite-volume model is a reduced lumped perturbation closure, not a full-fidelity free-boundary equilibrium, engineering design, or experimental validation. Reference-control numerical execution checks the common software chain only. Generated `unknown` records lack candidate-bound validation; `unsupported` records retain explicit declaration blockers. No physical device is claimed to pass complete VVUQ or feasibility.

Acceptance hash: `$(acceptance["acceptance_hash"])`.
"""
    write(joinpath(output_dir, "acceptance_report.md"), report)
    result
end
