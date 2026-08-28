using FusionConceptAI
using JSON3

root = normpath(joinpath(@__DIR__, ".."))
seal_audit = assert_protocol_sealed_v92(root)
run_root = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828")
realization_summary = FusionConceptAI._v92_json(joinpath(run_root,
    "realization_summary_v92.json"))
pilot_summary = FusionConceptAI._v92_json(joinpath(run_root,
    "high_fidelity_pilot_summary_v92.json"))
qualification_summary = FusionConceptAI._v92_json(joinpath(run_root,
    "qualification_gate_summary_v92.json"))
control_summary = FusionConceptAI._v92_json(joinpath(run_root, "controls",
    "control_qualification_summary_v92.json"))
negative_controls = FusionConceptAI._v92_json(joinpath(run_root, "controls",
    "negative_control_results_v92.json"))
coverage = FusionConceptAI._v92_json(joinpath(run_root,
    "capability_route_coverage_matrix_v92.json"))
installation = FusionConceptAI._v92_json(joinpath(run_root, "controls",
    "solver_installation_audit_v92.json"))
validation_report = FusionConceptAI._v92_json(joinpath(root, "reports",
    "v92_artifact_validation_20260828.json"))
regression = FusionConceptAI._v92_json(joinpath(run_root, "logs",
    "full_regression_v92.json"))
regression["status"] == "pass" || error("v92 full regression did not pass")
resource_usage = FusionConceptAI._v92_json(joinpath(run_root,
    "per_stage_resource_usage_v92.json"))

realizations = FusionConceptAI._v92_read_nonempty_jsonl(joinpath(run_root,
    "realization_dossiers_v92.jsonl"))
decisions = FusionConceptAI._v92_read_nonempty_jsonl(joinpath(run_root,
    "promotion_decisions_v92.jsonl"))
pilot_hashes = Set(String(row["candidate_hash"]) for row in decisions)
blocker_rows = Dict{String,Any}[]
blocker_histogram = Dict{String,Int}()
for realization in realizations
    status = String(realization["qualification"]["status"])
    candidate_hash = String(realization["candidate_hash"])
    blocker, blocker_stage = if status == "fail"
        (String(realization["qualification"]["first_blocker"]),
            "physical_realization")
    elseif candidate_hash in pilot_hashes
        ("unsupported_mixed_topology_equilibrium_backend", "applicable_equilibrium")
    else
        ("full_qualification_not_scheduled_pilot_transition_failed",
            "campaign_transition")
    end
    row = Dict{String,Any}(
        "candidate_id" => realization["candidate_id"],
        "candidate_hash" => candidate_hash,
        "realization_status" => status, "first_blocker_stage" => blocker_stage,
        "first_blocker" => blocker,
        "computationally_credible_fusion_device_concept" => false)
    row["row_hash"] = canonical_hash(row); push!(blocker_rows, row)
    blocker_histogram[blocker] = get(blocker_histogram, blocker, 0) + 1
end
length(blocker_rows) == 417 || error("v92 all-candidate blocker count mismatch")
sum(values(blocker_histogram)) == 417 || error("v92 blocker histogram mismatch")
blocker_path = joinpath(run_root, "all_candidate_first_blockers_v92.jsonl")
FusionConceptAI._v92_write_immutable(blocker_path,
    FusionConceptAI._v92_jsonl_text(blocker_rows))

farthest_path = joinpath(run_root, "farthest_candidate_v92",
    "farthest_candidate_complete_dossier_v92.json")
farthest = FusionConceptAI._v92_json(farthest_path)
validation_split_path = joinpath(root, "config", "v92",
    "validation_dataset_split_v92.json")
stage_status = Dict{String,Any}(
    "physical_realization" => realization_summary["status_histogram"],
    "applicable_equilibrium_pilot" => Dict("unsupported" => 229),
    "field_line_orbit_pilot" => Dict("unsupported" => 229),
    "all_applicable_stability_pilot" => Dict("unsupported" => 229),
    "independent_solver_comparison_pilot" =>
        Dict("unknown_independent_model_missing" => 229),
    "numerical_vvuq_pilot" => Dict("unsupported" => 229),
    "parameter_uq_pilot" => Dict("unsupported" => 229),
    "candidate_bound_validation_vvuq_pilot" => Dict("unknown" => 229),
    "engineering_obligations_pilot" => Dict("unsupported" => 229),
    "full_qualification" => Dict("not_scheduled_transition_failed" => 246))

acceptance = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "acceptance_id" => "physical_closure_acceptance_v92_20260828",
    "protocol_seal" => Dict(
        "status" => seal_audit["status"],
        "seal_material_sha256" => seal_audit["seal_material_sha256"],
        "sealed_before_any_v92_high_fidelity_result" => true),
    "input_baseline" => seal_audit["input_audit"],
    "realization_campaign" => realization_summary,
    "solver_installation_audit" => Dict(
        "audit_hash" => installation["audit_hash"],
        "available_capabilities" => installation["available_capabilities"]),
    "known_and_negative_controls" => Dict(
        "qualification_status" => control_summary["known_device_control_qualification_status"],
        "first_blocker" => control_summary["first_blocker"],
        "vmex_control" => control_summary["vmex_control"],
        "freegs_control" => control_summary["freegs_control"],
        "missing_controls" => control_summary["missing_controls"],
        "negative_controls" => negative_controls),
    "high_fidelity_pilot" => pilot_summary,
    "capability_route_coverage" => coverage,
    "qualification_gates" => qualification_summary,
    "validation_dataset_provenance" => Dict(
        "manifest_path" => "config/v92/validation_dataset_split_v92.json",
        "manifest_sha256" => FusionConceptAI._v92_sha256_file(validation_split_path),
        "actual_holdout_measurement_inventory_status" => "not_attested",
        "published_range_substitution_used" => false,
        "ITER_design_point_validation_credit" => false),
    "full_regression" => regression,
    "per_stage_resource_usage" => resource_usage,
    "artifact_validation" => validation_report,
    "stage_status_histogram" => stage_status,
    "all_candidate_first_blocker_histogram" => blocker_histogram,
    "all_candidate_first_blocker_count" => length(blocker_rows),
    "realization_dossier_count" => 417,
    "high_fidelity_pilot_dossier_count" => 229,
    "full_qualification_scheduled_count" => 0,
    "pilot_to_full_transition_allowed" => false,
    "farthest_candidate" => Dict(
        "candidate_id" => farthest["candidate_id"],
        "candidate_hash" => farthest["candidate_hash"],
        "bundle_hash" => farthest["bundle_hash"],
        "dossier_path" => replace(relpath(farthest_path, root), '\\' => '/'),
        "materialized_mesh_count" => length(farthest["materialized_meshes"])),
    "interactive_visualization" =>
        "interactive_v92_closure_explorer/index.html",
    "computationally_credible_new_device_count" => 0,
    "experimentally_validated_new_fusion_device_count" => 0,
    "engineering_qualified_new_device_count" => 0,
    "unresolved_solver_disagreement_count" => 229,
    "manufactured_sentinel_or_published_interval_credit_count" => 0,
    "threshold_changed_after_results" => false,
    "family_or_device_label_routing_count" => 0,
    "open_field_to_nested_surface_misrouting_count" => 0,
    "claim_boundary" => "V92 executed 417/417 physical-realization qualification and every preregistered pilot request. No compatible mixed-topology equilibrium backend or complete control/validation chain was available, so all downstream applicable hard gates remain unsupported or unknown and no candidate is promoted.",
    "artifact_manifest_path" =>
        "runs/physical_closure_v92_formal_417_20260828/artifact_hash_manifest_v92.json")
acceptance["artifact_hash"] = canonical_hash(acceptance)
acceptance_path = joinpath(run_root, "physical_closure_acceptance_v92_20260828.json")
FusionConceptAI._v92_write_immutable(acceptance_path,
    FusionConceptAI._v92_json_text(acceptance))

report_path = joinpath(root, "reports",
    "physical_closure_acceptance_v92_20260828.md")
report = """# FusionConceptAI v92 高保真物理纵向闭合验收

协议：`$(V92_PROTOCOL_ID)`<br>
acceptance hash：`$(acceptance["artifact_hash"])`

## 最终结论

- `computationally_credible_new_device_count = 0`
- `experimentally_validated_new_fusion_device_count = 0`
- 417/417 个 v91 survivors 完成 PhysicalRealizationV92 qualification：246 pass，171 fail。
- 预注册 pilot 共 229 个 capability signatures，229/229 进入 capability router；全部声明 mixed topology，均因无兼容 coupled equilibrium backend 而为 `unsupported`。
- pilot→full transition 未通过，因 solver coverage、C-2W 实测 holdout、matched DESC–VMEX cross-code control 与完整 validation VVUQ 均未闭合；因此全量 high-fidelity qualification 调度数为 0，而不是“具备继续运行条件”。

## 实际执行的 controls

- VMEX 0.7.0 3D fixed-boundary control 实际执行：`ier_flag=$(control_summary["vmex_control"]["metrics"]["ier_flag"])`，`fsqr=$(control_summary["vmex_control"]["metrics"]["fsqr"])`，`fsqz=$(control_summary["vmex_control"]["metrics"]["fsqz"])`，`fsql=$(control_summary["vmex_control"]["metrics"]["fsql"])`。它缺少预注册 divB/boundary/cross-code observables，因此只保留 control convergence，不授予 candidate 或 validation credit。
- FreeGS 0.8.2 equilibrium verification tests 实际执行并通过，只属于 code verification。
- C-2W actual shot/run measurements、matched DESC–VMEX identical-input control、ITER engineering transformer 未完成，状态保持 unknown。

## 阶段统计与首阻塞

- realization fail：`missing_spatial_field_balance_backbone=152`，`missing_spatial_plasma_operator_backbone=19`。
- pilot 首阻塞：`applicable_equilibrium=229`。
- realization-pass 但非 pilot 代表的 17 个候选：由于 transition fail，full qualification 未调度。
- unresolved solver disagreement：229。
- manufactured/sentinel/published-interval 替代信用：0。

## 最远候选

`$(farthest["candidate_id"])` / `$(farthest["candidate_hash"])`。其 GeometryIR、三档 volume/wall meshes（6 个实际 HDF5 mesh）、field sources、profiles、solver request、blocked equilibrium/orbit/stability、ModeCoverage、cross-code、VVUQ 和 promotion decision 位于：

`$(replace(relpath(farthest_path, root), '\\' => '/'))`

equilibrium fields、residuals、convergence、orbits 和 modes 因上游 equilibrium unsupported 而为 `null`；未用 synthetic data 填充。

## 验证

- 完整 Julia regression：exit `$(regression["exit_code"])`，日志 `$(regression["log_path"])`，SHA-256 `$(regression["log_sha256"])`。
- v92 artifact/schema/HDF5 validation：`$(validation_report["status"])`。
- 交互式离线查看器：`interactive_v92_closure_explorer/index.html`；GeometryIR 可旋转缩放，其他页明确显示 unsupported/unknown，不画伪磁面、轨道或模态。

## 证据边界

solver 启动、单域 control 收敛、manufactured verification、reduced screens 和 published intervals 均未被称为物理闭合。所有适用 hard gates 未同时 pass，因此零晋级是本次协议下唯一合规结论。
"""
FusionConceptAI._v92_write_immutable(report_path, report)

candidate_paths = String[]
for directory in (joinpath(root, "config", "v92"), joinpath(root, "src"),
        joinpath(root, "schemas"), joinpath(root, "test"),
        joinpath(root, "scripts"), run_root,
        joinpath(root, "interactive_v92_closure_explorer"))
    isdir(directory) || continue
    for (walk_root, _, files) in walkdir(directory), file in files
        path = joinpath(walk_root, file)
        if directory in (joinpath(root, "src"), joinpath(root, "schemas"),
                joinpath(root, "test"), joinpath(root, "scripts"))
            occursin("v92", lowercase(file)) || continue
        end
        basename(path) == "artifact_hash_manifest_v92.json" && continue
        push!(candidate_paths, path)
    end
end
push!(candidate_paths, report_path)
unique!(candidate_paths); sort!(candidate_paths)
artifact_rows = [Dict{String,Any}(
    "path" => replace(relpath(path, root), '\\' => '/'),
    "sha256" => FusionConceptAI._v92_sha256_file(path),
    "bytes" => filesize(path)) for path in candidate_paths]
manifest = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "acceptance_artifact_hash" => acceptance["artifact_hash"],
    "artifact_count" => length(artifact_rows), "artifacts" => artifact_rows,
    "excluded_self" => "artifact_hash_manifest_v92.json")
manifest["manifest_hash"] = canonical_hash(manifest)
manifest_path = joinpath(run_root, "artifact_hash_manifest_v92.json")
FusionConceptAI._v92_write_immutable(manifest_path,
    FusionConceptAI._v92_json_text(manifest))
println(JSON3.write(Dict("acceptance_path" => replace(relpath(acceptance_path,
    root), '\\' => '/'), "acceptance_hash" => acceptance["artifact_hash"],
    "report_path" => replace(relpath(report_path, root), '\\' => '/'),
    "artifact_count" => length(artifact_rows),
    "artifact_manifest_hash" => manifest["manifest_hash"])))
