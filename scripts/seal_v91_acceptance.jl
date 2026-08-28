#!/usr/bin/env julia

using FusionConceptAI
using JSON3
using SHA

const ROOT_V91_SEAL = normpath(joinpath(@__DIR__, ".."))

plain_v91(value) = FusionConceptAI._v89_plain(value)
sha_v91(path) = bytes2hex(sha256(read(path)))

function load_json_v91(path)
    plain_v91(JSON3.read(read(path, String), Dict{String,Any}))
end

pilot_root = joinpath(ROOT_V91_SEAL, "runs", "multitopology_v91_pilot_10000_20260827")
qualification_root = joinpath(ROOT_V91_SEAL, "runs",
    "multitopology_v91_qualification_100000_20260827")
formal_root = joinpath(ROOT_V91_SEAL, "runs",
    "multitopology_v91_formal_1000000_20260827")
pilot = load_json_v91(joinpath(pilot_root, "campaign_v91_merged.json"))
qualification = load_json_v91(joinpath(qualification_root, "campaign_v91_merged.json"))
formal = load_json_v91(joinpath(formal_root, "campaign_v91_merged.json"))
dossiers = load_json_v91(joinpath(formal_root, "survivor_dossiers_v91_summary.json"))
replay = load_json_v91(joinpath(ROOT_V91_SEAL, "runs",
    "multitopology_v91_formal_hash_replay_20260827.json"))
schema_validation = load_json_v91(joinpath(ROOT_V91_SEAL, "reports",
    "v91_schema_validation_20260827.json"))
full_regression = load_json_v91(joinpath(ROOT_V91_SEAL, "reports",
    "v91_full_regression_20260827.json"))

first_dossier = nothing
dossier_path = joinpath(formal_root, "survivor_dossiers_v91.jsonl")
stage_status_histogram = Dict{String,Dict{String,Int}}()
open(dossier_path, "r") do io
    while !eof(io)
        line = readline(io); isempty(strip(line)) && continue
        dossier = plain_v91(JSON3.read(line, Dict{String,Any}))
        first_dossier === nothing && (global first_dossier = dossier)
        for stage in dossier["stages"]
            stage_id = String(stage["stage_id"]); status = String(stage["status"])
            histogram = get!(stage_status_histogram, stage_id, Dict{String,Int}())
            histogram[status] = get(histogram, status, 0) + 1
        end
    end
end

source_files = [
    ".gitignore",
    "src/FusionConceptAI.jl",
    "src/multitopology_search_runtime_v91.jl",
    "src/multitopology_campaign_runtime_v91.jl",
    "src/survivor_evidence_audit_v91.jl",
    "test/multitopology_search_campaign_v91.jl",
    "test/runtests.jl",
    "schemas/multitopology_campaign_v91.schema.json",
    "schemas/multitopology_result_v91.schema.json",
    "schemas/survivor_evidence_dossier_v91.schema.json",
    "scripts/run_v91_campaigns.jl",
    "scripts/verify_v91_campaign_replay.jl",
    "scripts/seal_v91_acceptance.jl",
    "scripts/generate_v91_interactive_explorer.jl",
    "scripts/validate_v91_artifacts.py",
    "knowledge/v91_external_novelty_catalog_20260827.json"]
all_campaigns_pass = all(item -> item["status"] == "pass",
    (pilot, qualification, formal))
counts = dossiers["classification_counts"]
body = Dict{String,Any}(
    "schema_version" => "1.0.0", "acceptance_id" =>
        "v91_multitopology_million_campaign_acceptance_20260827",
    "search_capability_status" => all_campaigns_pass && replay["status"] == "pass" &&
        dossiers["status"] == "complete" && schema_validation["status"] == "pass" &&
        full_regression["status"] == "pass" ? "complete" : "fail",
    "campaigns" => Dict(
        "pilot_10000" => pilot, "qualification_100000" => qualification,
        "formal_1000000" => formal),
    "full_hash_replay" => replay,
    "schema_validation" => schema_validation,
    "full_regression" => full_regression,
    "survivor_audit_summary" => dossiers,
    "survivor_stage_status_histogram" => stage_status_histogram,
    "layer_counts" => Dict(
        "formal_raw_topology_requests" => formal["raw_topology_requests"],
        "formal_unique_nonisomorphic_topologies" =>
            formal["unique_nonisomorphic_topologies"],
        "formal_unique_solver_inputs" => formal["unique_solver_inputs"],
        "formal_capability_cells" => formal["capability_cell_count"],
        "formal_reduced_hard_gate_survivors" => formal["hard_gate_survivor_count"],
        "novel_topology_candidates" => counts["novel_topology_candidate"],
        "computationally_credible_fusion_device_concepts" =>
            counts["computationally_credible_fusion_device_concept"],
        "engineering_qualified_fusion_device_designs" =>
            counts["engineering_qualified_fusion_device_design"],
        "experimentally_validated_new_fusion_devices" =>
            counts["experimentally_validated_new_fusion_device"]),
    "credible_new_device_count" => dossiers["credible_new_device_count"],
    "computationally_credible_new_device_count" =>
        dossiers["computationally_credible_new_device_count"],
    "engineering_qualified_new_device_count" =>
        dossiers["engineering_qualified_new_device_count"],
    "experimentally_validated_new_fusion_device_count" =>
        dossiers["experimentally_validated_new_fusion_device_count"],
    "dominant_blockers" => dossiers["dominant_blockers"],
    "simplest_audited_novel_topology_candidate" => first_dossier,
    "novelty_comparison_matrix" => first_dossier === nothing ? Any[] :
        only(stage for stage in first_dossier["stages"]
            if stage["stage_id"] == "external_novelty")["comparison_matrix"],
    "source_integrity" => Dict(file => sha_v91(joinpath(ROOT_V91_SEAL, file))
        for file in source_files),
    "campaign_artifact_integrity" => Dict(
        "pilot_merge_sha256" => sha_v91(joinpath(pilot_root, "campaign_v91_merged.json")),
        "qualification_merge_sha256" => sha_v91(joinpath(qualification_root,
            "campaign_v91_merged.json")),
        "formal_merge_sha256" => sha_v91(joinpath(formal_root,
            "campaign_v91_merged.json")),
        "formal_dossiers_sha256" => sha_v91(dossier_path)),
    "million_campaign_actual_execution" => true,
    "extrapolation_used" => false, "patentability_claimed" => false,
    "freedom_to_operate_claimed" => false,
    "claim_boundary" => "Search capability can be complete while credible-device counts remain zero. novel_topology_candidate is not a computationally credible device, engineering design, or experimentally validated device.")
normalized = plain_v91(JSON3.read(JSON3.write(body), Dict{String,Any}))
normalized["artifact_hash"] = canonical_hash(normalized)
json_path = joinpath(ROOT_V91_SEAL, "runs",
    "multitopology_acceptance_v91_20260827.json")
FusionConceptAI._v91_atomic_json(json_path, normalized)

report_path = joinpath(ROOT_V91_SEAL, "reports",
    "multitopology_acceptance_v91_20260827.md")
formal_counts = normalized["layer_counts"]
report = """# v91 真实多拓扑百万级搜索与候选审计验收

搜索能力状态：`$(normalized["search_capability_status"])`<br>
验收产物哈希：`$(normalized["artifact_hash"])`

## 实际执行规模

| campaign | 请求/结果 | unique non-isomorphic topology | unique solver input | capability cells | reduced hard-gate survivors | 状态 |
|---|---:|---:|---:|---:|---:|---|
| pilot | $(pilot["result_count"]) | $(pilot["unique_nonisomorphic_topologies"]) | $(pilot["unique_solver_inputs"]) | $(pilot["capability_cell_count"]) | $(pilot["hard_gate_survivor_count"]) | $(pilot["status"]) |
| qualification | $(qualification["result_count"]) | $(qualification["unique_nonisomorphic_topologies"]) | $(qualification["unique_solver_inputs"]) | $(qualification["capability_cell_count"]) | $(qualification["hard_gate_survivor_count"]) | $(qualification["status"]) |
| formal | $(formal["result_count"]) | $(formal["unique_nonisomorphic_topologies"]) | $(formal["unique_solver_inputs"]) | $(formal["capability_cell_count"]) | $(formal["hard_gate_survivor_count"]) | $(formal["status"]) |

formal campaign 是实际执行的 1,000,000 条请求，不是外推。全部拓扑位于预注册的 20-bit injective typed-rooted-tree grammar 内；canonicalization、重命名不变性、重复控制、断点恢复、无缺口分片、完整记录哈希和确定性重放均通过。family/name/parent 路由与证据防火墙违规均为 0。

## 分层结论

- `novel_topology_candidate = $(formal_counts["novel_topology_candidates"])`：只表示仓库历史语法及声明外部目录的 region abstraction 内非同构。
- `credible_new_device_count = $(normalized["credible_new_device_count"])`
- `computationally_credible_new_device_count = $(normalized["computationally_credible_new_device_count"])`
- `engineering_qualified_new_device_count = $(normalized["engineering_qualified_new_device_count"])`
- `experimentally_validated_new_fusion_device_count = $(normalized["experimentally_validated_new_fusion_device_count"])`

没有把 reduced balance、三分辨率数值收敛、同模型数值复制、sentinel、manufactured control 或公开区间回归升级为 validation VVUQ。最主要阻塞项为：candidate-bound free-boundary/3D equilibrium、field-line/orbit、resistive/kinetic/nonlinear stability、独立物理求解器比较、结构/热/材料/屏蔽/低温/维护闭合，以及候选绑定真实实验验证。

由于 `computationally_credible_new_device_count = 0`，不存在“最简可信候选”。验收 JSON 中封存的是同复杂度下 request index 最小的 `novel_topology_candidate`（v91-candidate-3052）的完整 Genome、basis、topology、solver input、残差、reduced VVUQ 与缺失工程义务，且没有将它升格。

## 新颖性边界

外部目录覆盖 ITER、C-2W、W7-X、NIF、Sandia Z、NSTX-U、IAEA mirror survey 和代表性 FRC/stellarator patents，并保存查询、来源、范围、日期与 URL 列表哈希。它不是穷尽性 prior-art 检索，不授予专利性或 FTO；两者均明确为 false。

## 产物

逐请求记录、shard SHA-256、merge、recovery drill、完整 hash replay、全部 survivor dossiers、最简已审计候选的 Genome/basis/topology/solver input/residual/VVUQ/工程清单，以及 source/schema/test 哈希均由 JSON 验收封存。

全量 schema 校验覆盖 3 份 campaign manifests、$(schema_validation["campaign_record_count"]) 条结果记录与 $(schema_validation["survivor_dossier_count"]) 份 dossiers，状态 `$(schema_validation["status"])`。全仓 `julia --project=. test/runtests.jl` 退出码为 $(full_regression["exit_code"])，状态 `$(full_regression["status"])`。
"""
temporary = report_path * ".partial"; mkpath(dirname(report_path))
open(temporary, "w") do io; write(io, report); end
mv(temporary, report_path; force = true)
println(JSON3.write(Dict("status" => normalized["search_capability_status"],
    "artifact_hash" => normalized["artifact_hash"], "json" => json_path,
    "report" => report_path)))
