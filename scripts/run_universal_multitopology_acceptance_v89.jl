#!/usr/bin/env julia

using FusionConceptAI
using JSON3
using SHA

const ROOT_V89 = normpath(joinpath(@__DIR__, ".."))

function option_v89(name, default)
    prefix = "--$(name)="
    for argument in ARGS
        startswith(argument, prefix) && return argument[length(prefix)+1:end]
    end
    default
end

function atomic_write_v89(path, content)
    target = abspath(path); mkpath(dirname(target))
    temporary = target * ".partial"
    open(temporary, "w") do io
        write(io, content)
    end
    mv(temporary, target; force = true)
    target
end

sha256_file_v89(path) = bytes2hex(sha256(read(path)))

function pretty_json_v89(value)
    io = IOBuffer()
    JSON3.pretty(io, value)
    String(take!(io))
end

anchors_path = joinpath(ROOT_V89, "fixtures", "candidate_solver_reference_anchors_v1.json")
anchors = load_candidate_solver_reference_anchors_v1(anchors_path)
result = run_universal_multitopology_acceptance_v89(anchors)
pop!(result, "artifact_hash", nothing)
source_files = [
    "src/universal_multiregion_topology_grammar_v89.jl",
    "src/universal_realization_grammar_v89.jl",
    "src/universal_device_grammar_v89.jl",
    "src/operator_capability_router_v89.jl",
    "src/multiregion_residual_compiler_v89.jl",
    "src/known_device_sentinel_runtime_v89.jl"]
result["source_integrity"] = Dict{String,Any}(
    "anchor_fixture_sha256" => sha256_file_v89(anchors_path),
    "implementation_sha256" => Dict(file => sha256_file_v89(joinpath(ROOT_V89, file))
        for file in source_files),
    "schema_ids" => [
        "universal_multiregion_topology_v89",
        "universal_realization_v89", "universal_device_candidate_v89",
        "solver_capability_manifest_v89", "multiregion_residual_plan_v89",
        "universal_multitopology_acceptance_v89"])
# Seal the JSON-normalized value so 0.0 -> 0 serialization cannot change replay hashes.
result = FusionConceptAI._stage3_plain_v1(JSON3.read(JSON3.write(result),
    Dict{String,Any}))
result["artifact_hash"] = canonical_hash(result)

json_path = option_v89("output", joinpath(ROOT_V89, "runs",
    "universal_multitopology_acceptance_v89_20260827.json"))
report_path = option_v89("report", joinpath(ROOT_V89, "reports",
    "universal_multitopology_acceptance_v89_20260827.md"))
atomic_write_v89(json_path, pretty_json_v89(result) * "\n")

summary = result["summary"]
sentinel_lines = String[]
for item in result["sentinel_results"]
    counts = item["layer_counts"]
    topology = item["inverse_topology"]
    boundaries = join(sort!(unique(String(boundary["kind"])
        for boundary in topology["boundaries"])), ", ")
    integrated = only(item["integrated_screen_results"])
    push!(sentinel_lines, "| $(item["ui_label"]) | $(length(topology["regions"])) | $boundaries | $(item["baseline_route"]["status"]) | $(item["baseline_residual"]["status"]) | $(counts["hard_gate_survivors"]) | $(counts["pareto_survivors"]) | $(integrated["status"]) | $(integrated["published_interval_regression_status"]) | unknown |")
end

report = """# 统一多拓扑装置生成与筛选 v89 验收

状态：`$(result["status"])`<br>
产物哈希：`$(result["artifact_hash"])`

## 结论

ITER 与 C-2W 都由公开 reference description 反解为同一套 family-neutral topology、realization、operator obligation 和 candidate-bound solver input。两者与无标签混合拓扑控制共用同一个执行器，没有按名称、family 或 benchmark flag 路由，也没有专用阈值或 promotion credit。

整条链路均已执行：

`抽象拓扑生成 → 抽象一致性筛选 → physical realization 生成 → 硬物理漏斗 → 成活者稀疏化与 Pareto → integrated reduced-L2 整装筛选 → 证据边界内最简可信候选`

| 输入 | 反解区域数 | 边界 | operator 路由 | 多区域 residual | 硬门成活者 | Pareto | 整装筛选 | 公开区间回归 | 工程/实验 V&V |
|---|---:|---|---|---|---:|---:|---|---|---|
$(join(sentinel_lines, "\n"))

验收汇总：known-device chain `$(summary["known_device_chain_pass_count"])/$(summary["known_device_count"])`；不同 hard-survivor capability cells `$(summary["distinct_hard_survivor_capability_cells"])`；无标签控制 `$(summary["generated_unlabeled_chain_status"])`；负控制 `$(summary["negative_control_status"])`；family routing `$(summary["family_routing_count"])`；benchmark threshold override `$(summary["benchmark_threshold_override_count"])`。

## ITER 与 C-2W 的反解含义

- ITER：反解为闭合等离子体控制体、闭合边界、内部电流/外部场导体/功率执行器/材料边界/传感控制组件，以及公开 operator obligations。
- C-2W：其 declared region semantics 被拆为闭合核心和开放平行损失区，二者通过粒子与能量成对守恒接口连接；核心为 mixed boundary，损失区为 open boundary。
- 两者的 anchor observables 均未进入 topology、realization 或模型预测；只在完成 candidate-bound 计算后作区间比较。标签擦除和加入 benchmark flag 后，topology hash、isomorphism hash、realization hash、solver input hash、route hash 与硬门结论保持不变。

## 物理与证据边界

这次的硬门包括类型/几何正值、界面守恒、有限压力 beta 上界、磁通库存一致性、热库存一致性、降阶电流密度界、执行器容量、capability fail-closed 和多区域 residual 收敛。整装层为三分辨率的 integrated reduced control-volume L2 数值筛选；ITER 的 D-T 功率来自 candidate state 与 Bosch-Hale 反应率，C-2W 温度来自 candidate state，公开区间仅用于事后回归。

因此本次可以声明统一软件链、反解 containment、降阶硬物理筛选和 numerical VVUQ 范围内通过；不能声明自由边界 MHD、完整 kinetic/transport、材料/结构/维护工程、实验 validation VVUQ、可部署装置、外部新颖性、专利性或 FTO。完整 engineering/V&V candidate 数仍为 `$(summary["complete_engineering_vv_device_count"])`。

## 负控制

- 缺 operator manifest → `unsupported/missing_operator_capability`；
- 破坏内部界面成对守恒 → 静态编译拒绝；
- 执行器容量不足 → 硬门 `fail`；
- Pareto 输入含硬门失败候选 → 拒绝执行 Pareto。

完整逐候选、逐层、逐门和哈希证据见 `$(basename(json_path))`。
"""
atomic_write_v89(report_path, report)

println(JSON3.write(Dict(
    "status" => result["status"], "artifact_hash" => result["artifact_hash"],
    "known_device_chain_pass_count" => summary["known_device_chain_pass_count"],
    "known_device_count" => summary["known_device_count"],
    "distinct_hard_survivor_capability_cells" =>
        summary["distinct_hard_survivor_capability_cells"],
    "output" => abspath(json_path), "report" => abspath(report_path))))
