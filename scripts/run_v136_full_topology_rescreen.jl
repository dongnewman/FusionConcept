#!/usr/bin/env julia

using FusionConceptAI
using JSON3
using SHA

const ROOT = normpath(joinpath(@__DIR__, ".."))
const CARDINALITY = 1_048_576
const CLASSES = collect(V136_CAPABILITY_CLASSES)

file_sha(path) = bytes2hex(sha256(read(path)))

function write_json(path, value)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON3.pretty(io, value); write(io, '\n')
    end
end

dimension(value) = begin
    found = match(r"[123]", lowercase(String(value)))
    found === nothing ? 0 : parse(Int, found.match)
end

function fast_route(topology)
    physical = [node for node in topology["nodes"] if String(node["field_semantics"])
        in ("axisymmetric_closed", "three_dimensional_closed",
            "open_guiding_field", "open_field", "hybrid_field")]
    isempty(physical) && return ("unsupported", "no_physical_realization_region", 0.0)
    classes = String[]
    for node in physical
        semantics = String(node["field_semantics"]); dim = dimension(node["dimension"])
        semantics == "hybrid_field" && return ("unsupported",
            "hybrid_region_requires_explicit_subregions", 0.0)
        class = semantics == "axisymmetric_closed" ? "axisymmetric_closed" :
            semantics == "three_dimensional_closed" ? "three_dimensional_closed" :
            "open_field"
        supported = class == "axisymmetric_closed" ? dim in (2, 3) :
            class == "three_dimensional_closed" ? dim == 3 : dim in (1, 2, 3)
        supported || return ("unsupported", "region_dimension_provider_mismatch", 0.0)
        push!(classes, class)
    end
    unique_classes = unique(classes)
    class = length(unique_classes) == 1 ? only(unique_classes) : "mixed_multiregion"
    spatial = sum(dimension(node["dimension"]) for node in physical)
    field_ops = count(node -> String(node["operator"]) == "field_balance", physical)
    # This score is intentionally only a compute scheduler feature.
    score = spatial / (3length(physical)) + 0.05field_ops / length(physical)
    class, "closed", score
end

function offer!(frontier, row, quota)
    length(frontier) < quota && (push!(frontier, row); return)
    worst = 1
    for index in 2:length(frontier)
        if (frontier[index]["scheduler_score"], -frontier[index]["request_index"]) <
                (frontier[worst]["scheduler_score"], -frontier[worst]["request_index"])
            worst = index
        end
    end
    current = frontier[worst]
    if (row["scheduler_score"], -row["request_index"]) >
            (current["scheduler_score"], -current["request_index"])
        frontier[worst] = row
    end
end

function main()
    positional = [arg for arg in ARGS if !startswith(arg, "--")]
    output_dir = !isempty(positional) ? abspath(first(positional)) : joinpath(ROOT, "runs",
        "v136_full_topology_rescreen_1048576_20260830")
    if "--refresh-bindings" in ARGS
        path = joinpath(output_dir, "acceptance.json")
        isfile(path) || error("cannot refresh missing full-rescreen acceptance")
        body = Dict{String,Any}(JSON3.read(read(path, String), Dict{String,Any}))
        body["source_saved_topology_acceptance_sha256"] = file_sha(joinpath(ROOT,
            "runs", "v97_exhaustive_physical_rescreen_1048576_20260829",
            "acceptance.json"))
        body["reference_workload_acceptance_sha256"] = file_sha(joinpath(ROOT,
            "runs", "v136_reference_workloads_20260830", "acceptance.json"))
        delete!(body, "acceptance_hash")
        body["acceptance_hash"] = canonical_hash(body)
        write_json(path, body)
        println(JSON3.write(Dict("status" => body["status"],
            "processed" => body["processed"], "refreshed_bindings" => true,
            "acceptance_hash" => body["acceptance_hash"])))
        return
    end
    quotas = Dict(class => 64 for class in CLASSES)
    frontiers = Dict(class => Dict{String,Any}[] for class in CLASSES)
    class_counts = Dict(class => 0 for class in CLASSES)
    blocker_counts = Dict{String,Int}()
    for index in 1:CARDINALITY
        topology = generate_family_neutral_topology_v91(index)
        class, status, score = fast_route(topology)
        if status != "closed"
            blocker_counts[status] = get(blocker_counts, status, 0) + 1
            continue
        end
        class_counts[class] += 1
        offer!(frontiers[class], Dict{String,Any}(
            "request_index" => index, "scheduler_score" => score,
            "topology_hash" => topology["topology_hash"],
            "physical_credit" => false), quotas[class])
    end
    selected = Dict{String,Any}()
    planner_failures = Dict{String,Any}[]
    for class in CLASSES
        rows = sort!(frontiers[class]; by = item ->
            (-item["scheduler_score"], item["request_index"]))
        selected_rows = Dict{String,Any}[]
        for row in rows
            topology = generate_family_neutral_topology_v91(row["request_index"])
            plan = compile_region_realization_plan_v136(topology)
            if plan["status"] != "closed" || plan["capability_class"] != class
                push!(planner_failures, Dict("request_index" => row["request_index"],
                    "fast_class" => class, "planner_status" => plan["status"],
                    "planner_class" => plan["capability_class"],
                    "blockers" => plan["blockers"]))
            end
            push!(selected_rows, merge(row, Dict(
                "realization_plan_hash" => plan["plan_hash"],
                "realization_plan_status" => plan["status"],
                "provider_execution_status" => "scheduled_not_executed",
                "physical_credit" => false)))
        end
        selected[class] = selected_rows
    end
    closed_count = sum(values(class_counts)); unsupported_count = CARDINALITY - closed_count
    source_acceptance = joinpath(ROOT, "runs",
        "v97_exhaustive_physical_rescreen_1048576_20260829", "acceptance.json")
    reference_acceptance = joinpath(ROOT, "runs",
        "v136_reference_workloads_20260830", "acceptance.json")
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V136_PROTOCOL_ID,
        "status" => isempty(planner_failures) ? "pass" : "fail",
        "source_saved_topology_acceptance_sha256" => file_sha(source_acceptance),
        "reference_workload_acceptance_sha256" => file_sha(reference_acceptance),
        "grammar_cardinality" => CARDINALITY, "processed" => CARDINALITY,
        "grammar_exhaustive" => true, "capability_closed_count" => closed_count,
        "unsupported_count" => unsupported_count,
        "capability_class_histogram" => class_counts,
        "blocker_histogram" => blocker_counts,
        "quotas" => quotas, "selected_by_class" => selected,
        "selected_count" => sum(length(value) for value in values(selected)),
        "quota_is_physical_gate" => false, "scheduler_proxy_physical_credit" => false,
        "selected_candidate_physical_credit" => false,
        "provider_execution_deferred_to_selected_frontier" => true,
        "planner_equivalence_failure_count" => length(planner_failures),
        "planner_equivalence_failures" => planner_failures,
        "identity_fields_used_for_routing" => false,
        "majority_route_used" => false, "partial_subgraph_promotion_allowed" => false,
        "validation_pass_count" => 0, "whole_device_credible_count" => 0,
        "claim_boundary" => "Every topology in the saved 20-bit grammar was rerouted by per-region capability. Quotas only schedule expensive providers; no selected row receives physical or validation credit until its complete graph executes solve, numerical VVUQ, then validation VVUQ.")
    body["acceptance_hash"] = canonical_hash(body)
    write_json(joinpath(output_dir, "acceptance.json"), body)
    report = """# v136 全量拓扑 capability 重筛\n\n""" *
        "处理：$(CARDINALITY) / $(CARDINALITY)；逐区域闭合：$(closed_count)；" *
        "unsupported：$(unsupported_count)。\n\n" *
        "分层计数：`$(JSON3.write(class_counts))`。每层最多调度 64 个；配额和" *
        "调度分数不提供物理信用。当前仅完成全量重路由和高成本队列选择，未把" *
        "任何子图或参考负载结果提升为新候选整机通过。\n\n" *
        "Acceptance hash: `$(body["acceptance_hash"])`\n"
    write(joinpath(output_dir, "acceptance_report.md"), report)
    println(JSON3.write(Dict("status" => body["status"],
        "processed" => body["processed"], "closed" => closed_count,
        "unsupported" => unsupported_count, "selected" => body["selected_count"],
        "acceptance_hash" => body["acceptance_hash"])))
end

main()
