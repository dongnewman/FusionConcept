#!/usr/bin/env julia

using FusionConceptAI
using JSON3
using SHA

const ROOT_V90 = normpath(joinpath(@__DIR__, ".."))

function option_v90(name, default)
    prefix = "--$(name)="
    for argument in ARGS
        startswith(argument, prefix) && return argument[length(prefix)+1:end]
    end
    default
end

function atomic_write_v90(path, content)
    target = abspath(path); mkpath(dirname(target)); temporary = target * ".partial"
    open(temporary, "w") do io; write(io, content); end
    mv(temporary, target; force = true); target
end

function pretty_json_v90(value)
    io = IOBuffer(); JSON3.pretty(io, value); String(take!(io))
end

sha256_file_v90(path) = bytes2hex(sha256(read(path)))

campaign = abspath(option_v90("campaign", joinpath(ROOT_V90, "runs",
    "multitopology_campaign_v90_100000_20260827")))
merge_path = joinpath(campaign, "campaign_v90_merged.json")
isfile(merge_path) || error("merged v90 campaign not found: $merge_path")
merged = JSON3.read(read(merge_path, String), Dict{String,Any})
anchors_path = joinpath(ROOT_V90, "fixtures",
    "candidate_solver_reference_anchors_v1.json")
anchors = load_candidate_solver_reference_anchors_v1(anchors_path)
acceptance = run_universal_multitopology_acceptance_v90(anchors;
    campaign_merge = merged)
pop!(acceptance, "artifact_hash", nothing)
source_files = [
    "src/multiregion_nonlinear_runtime_v90.jl",
    "src/capability_solver_portfolio_v90.jl",
    "src/survivor_fidelity_vvuq_v90.jl",
    "src/multitopology_campaign_runtime_v90.jl",
    "src/universal_multitopology_acceptance_v90.jl"]
acceptance["source_integrity"] = Dict(
    "anchor_fixture_sha256" => sha256_file_v90(anchors_path),
    "implementation_sha256" => Dict(file => sha256_file_v90(joinpath(ROOT_V90, file))
        for file in source_files),
    "campaign_specification_sha256" => sha256_file_v90(joinpath(campaign,
        "campaign_v90.json")),
    "campaign_merge_sha256" => sha256_file_v90(merge_path))
normalized = JSON3.read(JSON3.write(acceptance), Dict{String,Any})
normalized["artifact_hash"] = canonical_hash(normalized)

json_path = option_v90("output", joinpath(ROOT_V90, "runs",
    "universal_multitopology_acceptance_v90_20260827.json"))
report_path = option_v90("report", joinpath(ROOT_V90, "reports",
    "universal_multitopology_acceptance_v90_20260827.md"))
atomic_write_v90(json_path, pretty_json_v90(normalized) * "\n")

report = """# 统一多拓扑候选绑定非线性装置链 v90 验收

实现验收：`$(normalized["implementation_acceptance_status"])`<br>
可信大范围搜索声明：`$(normalized["credible_large_range_search_claim_status"])`<br>
声明授权：`$(normalized["credible_large_range_search_claim_authorized"])`<br>
产物哈希：`$(normalized["artifact_hash"])`

## 已验证结果

- campaign：`$(merged["batch_count"])` 批，`$(merged["result_count"])` 条请求/结果，实际 solver input 唯一率 `$(merged["actual_solver_inputs_unique_fraction"])`。
- candidate-bound 多区域非线性闭合：`$(merged["nonlinear_closure_pass_count"])/$(merged["result_count"])`。
- 两个不同 capability cell 的硬门成活者：`$(merged["hard_gate_survivor_count"])`；只对硬门调度的 survivor 进入后续高保真链。
- family/name 路由、benchmark threshold override、证据防火墙违规分别为 `$(merged["family_routing_count"])`、`$(merged["name_routing_count"])`、`$(merged["benchmark_threshold_override_count"])`、`$(merged["evidence_firewall_violation_count"])`。
- 缓存重放审计：`$(merged["cache_replay_audit"]["status"])`；批次无缺口/重叠：`$(merged["batch_ranges_no_gap_or_overlap"])`。
- 两个生成切片的 numerical VVUQ 为 PASS；ITER 与 C-2W 仅作为同链 sentinel containment，promotion credit 为 false。

## 严格封存边界

软件链通过不等于装置可行或大范围多拓扑搜索可信。当前仍缺 candidate-bound kinetic/碰撞验证、适用的自由边界或三维平衡、resistive/kinetic/nonlinear 稳定性、结构/热/材料/屏蔽/低温/维护闭合、实验 validation VVUQ，以及外部新颖性/专利/FTO。相关阶段保持 `unknown` 或 `unsupported`，不可由 Pareto、参考装置或 campaign 数量补偿。

因此 `credible_large_range_search_claim_status` 被固定封存为 `fail`，完整 engineering candidate 数为 0。完整逐请求、逐门、哈希、缓存及重放证据见 `$(basename(json_path))` 与 campaign 目录。
"""
atomic_write_v90(report_path, report)
println(JSON3.write(Dict(
    "implementation_acceptance_status" => normalized["implementation_acceptance_status"],
    "credible_large_range_search_claim_status" => normalized["credible_large_range_search_claim_status"],
    "artifact_hash" => normalized["artifact_hash"],
    "output" => abspath(json_path), "report" => abspath(report_path))))
