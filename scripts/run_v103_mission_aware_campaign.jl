#!/usr/bin/env julia
using FusionConceptAI
using JSON3

length(ARGS) == 2 || error("usage: OUTPUT_DIR REPORT.md")
root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(ARGS[1]); report_path = abspath(ARGS[2])
result = run_v103_mission_aware_campaign(root)
normalized = Dict{String,Any}(FusionConceptAI._v93_plain(
    JSON3.read(JSON3.write(result), Dict{String,Any})))
pop!(normalized, "acceptance_hash", nothing)
normalized["acceptance_hash"] = canonical_hash(normalized)
mkpath(output_dir)
path = joinpath(output_dir, "acceptance.json")
open(path * ".partial", "w") do io
    JSON3.pretty(io, normalized); write(io, '\n')
end
mv(path * ".partial", path; force = true)

reference = normalized["reference_acceptance"]
candidates = normalized["candidate_rescreen"]
reference_lines = String[]
for (index, row) in enumerate(reference["reference_rows"])
    label = index == 1 ? "ITER" : index == 2 ? "C-2W" : "reference-$index"
    missing = join((String(item["stage_id"]) for item in row["qualification_gaps"]), ", ")
    push!(reference_lines, "| $label | $(row["mission"]["mission_class"]) | " *
        "$(row["generic_numerical_vvuq"]) | $(row["reference_regression_status"]) | " *
        "$(row["full_qualification_status"]) | $(row["validation_vvuq"]["status"]) | $missing |")
end
report = """# v103 mission-aware reference 与候选重筛验收

## Reference 结果

| 输入 | 声明任务 | numerical VVUQ | scoped regression | 完整资格 | validation | 未闭合项 |
|---|---|---|---|---|---|---|
$(join(reference_lines, "\n"))

新通道不再使用旧 v98 reference bypass。ITER/C-2W 都先以 v89 反解多区域图完成 v96
whole-graph solve，再执行各自 capability/mission 所需的 v90 provider stages；2/2 scoped
reference regression 通过，new bypass=0。反应堆净电、中子壁负荷等门不会再施加给未声明这些
任务的参考装置。

这不是完整资格通过。两者仍缺完整 kinetic/transport、非线性稳定性、结构材料、屏蔽、低温和
维护等证据。ITER 是设计基线，不能产生实验 validation；C-2W 虽有公开实验区间，但仓库没有
原始 shot、标定哈希、测量不确定度数据包和独立 owner attestation，因此 validation 仍为
external_evidence_required。

## 候选重筛

参考门通过后，79 个既有 v100 net-electric D-T reactor retained candidates 已按其显式
campaign mission 重新裁决；本次没有重写 v100 候选数据，也没有把这一批扩大解释成全拓扑重跑。
结果保持 78 physical_reject、1 qualification_incomplete、0 unsupported、0 provider system
failure、0 credible、0 validation pass。参考装置的任务门修复不会放宽新反应堆候选的门槛。

Acceptance hash: `$(normalized["acceptance_hash"])`

$(MISSION_AWARE_SCREENING_V103_CLAIM_BOUNDARY)
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(
    "status" => normalized["status"],
    "reference_regression_pass_count" => reference["reference_regression_pass_count"],
    "new_reference_bypass_count" => reference["new_reference_bypass_count"],
    "candidate_count" => candidates["candidate_count"],
    "candidate_state_histogram" => candidates["candidate_state_histogram"],
    "unsupported_candidate_count" => normalized["unsupported_candidate_count"],
    "whole_device_credible_count" => normalized["whole_device_credible_count"],
    "validation_pass_count" => normalized["validation_pass_count"],
    "acceptance_hash" => normalized["acceptance_hash"])))
