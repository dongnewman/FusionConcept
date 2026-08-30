#!/usr/bin/env julia

using FusionConceptAI
using JSON3
using SHA

const ROOT = normpath(joinpath(@__DIR__, ".."))
plain(value) = FusionConceptAI._v93_plain(value)
file_sha(path) = bytes2hex(sha256(read(path)))

function write_json(path, value)
    mkpath(dirname(path))
    open(path, "w") do io
        JSON3.pretty(io, value); write(io, '\n')
    end
end

function main()
    output_dir = length(ARGS) >= 1 ? abspath(ARGS[1]) : joinpath(ROOT, "runs",
        "v136_generic_multiregion_acceptance")
    reference_path = joinpath(ROOT, "runs", "v136_reference_workloads_20260830",
        "acceptance.json")
    rescreen_path = joinpath(ROOT, "runs",
        "v136_full_topology_rescreen_1048576_20260830", "acceptance.json")
    reference = plain(JSON3.read(read(reference_path, String), Dict{String,Any}))
    rescreen = plain(JSON3.read(read(rescreen_path, String), Dict{String,Any}))
    registry = default_region_realization_registry_v136()
    manifest = provider_registry_manifest_v94(registry)
    serialized_manifest = lowercase(String(JSON3.write(manifest)))
    forbidden = [key for key in ("candidate_id", "candidate_hash", "device_family")
        if occursin(key, serialized_manifest)]

    nfp_declaration = Dict{String,Any}(
        "field_periods" => 2,
        "R_modes" => [Dict("m" => 0, "n" => 0, "coefficient_m" => 5.5),
            Dict("m" => 1, "n" => 0, "coefficient_m" => 0.5),
            Dict("m" => 1, "n" => 1, "coefficient_m" => 0.08)],
        "Z_modes" => [Dict("m" => 1, "n" => 0, "coefficient_m" => 0.5),
            Dict("m" => 1, "n" => 1, "coefficient_m" => 0.08)],
        "coil_templates" => [Dict("major_radius_m" => 6.4,
            "minor_radius_m" => 0.35, "vertical_m" => 0.0,
            "phase_fraction" => 0.1, "current_a" => 1e6)])
    nfp2 = materialize_periodic_boundary_coils_v136(nfp_declaration)
    nfp_declaration["field_periods"] = 5
    nfp5 = materialize_periodic_boundary_coils_v136(nfp_declaration)
    sensitivity = audit_field_period_sensitivity_v136(nfp2, nfp5)
    unchanged1 = deepcopy(nfp5); unchanged1["field_periods"] = 1
    unchanged = audit_field_period_sensitivity_v136(unchanged1, nfp5)

    proxy = audit_proxy_gate_separation_v136(Dict(
        "physical_gates" => [Dict("gate_id" => "equilibrium_residual")],
        "scheduling_features" => Dict("field_quality" => 0.8,
            "fixed_3d_peak_field_penalty" => 0.1)))
    source_paths = [
        joinpath(ROOT, "src", "operator_provider_registry_v94.jl"),
        joinpath(ROOT, "src", "region_realization_runtime_v136.jl"),
        joinpath(ROOT, "src", "end_to_end_device_pipeline_v98.jl"),
        joinpath(ROOT, "scripts", "run_v136_reference_workloads.jl"),
        joinpath(ROOT, "scripts", "run_v136_full_topology_rescreen.jl")]
    gates = Dict{String,Bool}(
        "four_equal_provider_manifests" => manifest["provider_count"] == 4,
        "provider_manifest_identity_free" => isempty(forbidden),
        "all_reference_classes_reached_equilibrium_and_stability" =>
            reference["all_four_capability_classes_reached_equilibrium_and_stability"] === true,
        "full_saved_grammar_rescreened" => rescreen["processed"] == 1_048_576 &&
            rescreen["grammar_exhaustive"] === true,
        "per_region_routing_only" => rescreen["majority_route_used"] === false,
        "quota_scheduling_only" => rescreen["quota_is_physical_gate"] === false &&
            rescreen["selected_candidate_physical_credit"] === false,
        "proxy_physical_gate_separation" => proxy["status"] == "pass" &&
            proxy["proxy_physical_credit"] === false,
        "field_period_changes_geometry" => sensitivity["status"] == "pass",
        "unchanged_1_to_5_geometry_fails" => unchanged["status"] == "fail",
        "no_partial_subgraph_promotion" =>
            rescreen["partial_subgraph_promotion_allowed"] === false,
        "unknown_validation_independent" => reference["validation_pass_count"] == 0 &&
            reference["whole_device_credible_count"] == 0)
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V136_PROTOCOL_ID,
        "status" => all(values(gates)) ? "pass" : "fail",
        "gates" => Dict(sort!(collect(gates))), "provider_registry" => manifest,
        "forbidden_manifest_fields" => forbidden,
        "proxy_separation_audit" => proxy,
        "field_period_sensitivity" => sensitivity,
        "unchanged_1_to_5_negative_control" => unchanged,
        "reference_workloads" => Dict("artifact" =>
            "runs/v136_reference_workloads_20260830/acceptance.json",
            "sha256" => file_sha(reference_path), "status" => reference["status"],
            "validation_pass_count" => reference["validation_pass_count"],
            "whole_device_credible_count" => reference["whole_device_credible_count"]),
        "full_topology_rescreen" => Dict("artifact" =>
            "runs/v136_full_topology_rescreen_1048576_20260830/acceptance.json",
            "sha256" => file_sha(rescreen_path), "processed" => rescreen["processed"],
            "closed" => rescreen["capability_closed_count"],
            "unsupported" => rescreen["unsupported_count"],
            "selected" => rescreen["selected_count"]),
        "source_hashes" => Dict(replace(relpath(path, ROOT), '\\' => '/') =>
            file_sha(path) for path in source_paths),
        "strict_stage_order" => ["per_region_provider_closure", "solve",
            "numerical_vvuq", "validation_vvuq"],
        "basis_direct_metric_credit" => false,
        "physical_conclusion_expanded" => false,
        "experimental_validation_credit" => false,
        "whole_device_credible_count" => 0,
        "claim_boundary" => REGION_REALIZATION_RUNTIME_V136_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    write_json(joinpath(output_dir, "acceptance.json"), body)
    report = """# v136 通用多区域 realization 验收\n\n""" *
        "状态：**$(body["status"])**。registry 含 4 个按状态、算子、接口、" *
        "函数空间、维度与坐标声明的 provider，未使用候选 ID/hash 或设备家族。\n\n" *
        "四类参考负载均到达候选绑定平衡与稳定性阶段，但 ITER 的 FreeGS q95 门和" *
        "3D 参考的 sampled local stability 可能给出物理 fail；它们不再变成 unsupported。" *
        "实验 validation pass 和可信整机仍均为 0。\n\n" *
        "全量 1,048,576 拓扑逐区域重路由后，$(rescreen["capability_closed_count"]) 个" *
        "闭合，$(rescreen["unsupported_count"]) 个保持 unsupported；各能力层配额仅选择" *
        "高成本计算对象，没有物理信用。\n\n" *
        "Acceptance hash: `$(body["acceptance_hash"])`\n"
    write(joinpath(output_dir, "acceptance_report.md"), report)
    println(JSON3.write(Dict("status" => body["status"],
        "acceptance_hash" => body["acceptance_hash"])))
end

main()
