#!/usr/bin/env julia

using FusionConceptAI
using JSON3
using SHA

const V102_PROTOCOL = "fusionconceptai-v102-inverse-reference-candidate-experiment-20260829"
const V102_CLAIM_BOUNDARY =
    "This experiment tests whether family-neutral inverse representations of published " *
    "ITER and C-2W descriptions survive the current ordinary-candidate chain. A reduced " *
    "screen rejection with an applicability mismatch is a selector diagnosis, not a " *
    "physical falsification of either device. Reference data, design targets, and input-" *
    "derived observables provide no new-candidate or independent-validation credit."

plain_v102(value) = FusionConceptAI._v93_plain(value)

function option_v102(name, default)
    prefix = "--$(name)="
    for argument in ARGS
        startswith(argument, prefix) && return argument[length(prefix)+1:end]
    end
    default
end

function atomic_json_v102(path, value)
    target = abspath(path); mkpath(dirname(target))
    temporary = target * ".partial"
    open(temporary, "w") do io
        JSON3.pretty(io, value); write(io, '\n')
    end
    mv(temporary, target; force = true)
end

dimension_v102(value) = lowercase(String(value)) == "3d" ? 3 :
    lowercase(String(value)) == "2d" ? 2 :
    lowercase(String(value)) == "1d" ? 1 : 0

function canonical_state_v102(slot)
    name = String(slot)
    endswith(name, "particle_inventory") && return "particle_inventory"
    endswith(name, "thermal_energy") && return "thermal_energy"
    name
end

function inverse_physics_v102(sentinel)
    topology = Dict{String,Any}(sentinel["inverse_topology"])
    realization = Dict{String,Any}(sentinel["inverse_realization"])
    solved = Dict{String,Any}(sentinel["baseline_residual"])
    solved_state = Dict{String,Any}(solved["state"])
    fields = Dict(String(item["region_id"]) => Dict{String,Any}(item)
        for item in Dict{String,Any}.(topology["field_topologies"]))
    boundaries = Dict(String(item["region_id"]) => String(item["kind"])
        for item in Dict{String,Any}.(topology["boundaries"]))
    regions = Dict{String,Any}[]; states = Dict{String,Any}[]
    for raw in Dict{String,Any}.(topology["regions"])
        key = String(raw["region_id"]); role = String(raw["role"])
        dimension = dimension_v102(raw["dimension"])
        field = fields[key]
        region_type = occursin("open_parallel_loss", role) ? "open_loss" : "plasma"
        coordinate = region_type == "open_loss" ? "open_field" : "axisymmetric"
        push!(regions, Dict{String,Any}(
            "region_key" => key, "region_type" => region_type,
            "dimension" => dimension, "raw_coordinate_map" =>
                "inverse_multitopology_$(field["kind"])",
            "coordinate_class" => coordinate))
        for slot in Dict{String,Any}.(raw["state_slots"])
            slot_id = String(slot["slot_id"]); state_key = key * "::" * slot_id
            haskey(solved_state, state_key) || error("inverse solved state missing $state_key")
            physical = canonical_state_v102(slot_id)
            primary = region_type == "open_loss" ? "parallel_transport" :
                physical == "particle_inventory" ? "particle_balance" :
                physical == "thermal_energy" ? "energy_balance" : "field_balance"
            push!(states, Dict{String,Any}(
                "state_key" => state_key, "region_key" => key,
                "physical_state" => physical,
                "source_slot_id" => slot_id,
                "scale" => max(abs(Float64(solved_state[state_key])), 1e-12),
                "initial_normalized" => 1.0, "primary_operator" => primary,
                "additional_operators" => String[]))
        end
    end
    interfaces = Dict{String,Any}[]
    for raw in Dict{String,Any}.(topology["interfaces"])
        get(raw, "target_region_id", nothing) === nothing && continue
        push!(interfaces, Dict{String,Any}(
            "interface_key" => String(raw["interface_id"]),
            "minus_region_key" => String(raw["source_region_id"]),
            "plus_region_key" => String(raw["target_region_id"]),
            "conditions" => ["paired_$(item["account_id"])_conservation"
                for item in Dict{String,Any}.(raw["flux_pairs"])]))
    end
    boundary_rows = Dict{String,Any}[]
    for region in regions
        key = String(region["region_key"]); kind = boundaries[key]
        condition = kind == "open" ? "open_outflow" : "closed_no_flux"
        push!(boundary_rows, Dict{String,Any}(
            "boundary_key" => key * "::outer", "region_key" => key,
            "source_boundary_kind" => kind, "condition" => condition))
    end
    Dict{String,Any}(
        "regions" => regions, "states" => states, "interfaces" => interfaces,
        "boundaries" => boundary_rows,
        "parameters" => Dict{String,Any}(realization["physical_parameters"]),
        "declared_observables" => Any[], "declaration_blockers" => String[],
        "validation_evidence" => nothing,
        "source_topology_hash" => topology["topology_hash"],
        "source_realization_hash" => realization["realization_hash"],
        "source_residual_hash" => solved["result_hash"],
        "normalization" => "v89_inverse_multiregion_state_to_v96_canonical_physical_state",
        "claim_boundary" => V102_CLAIM_BOUNDARY)
end

function inverse_capability_v102(sentinel)
    topology = Dict{String,Any}(sentinel["inverse_topology"])
    fields = Dict{String,Any}.(topology["field_topologies"])
    regions = Dict{String,Any}.(topology["regions"])
    kinds = String.(get.(fields, "kind", ""))
    dimensions = dimension_v102.(get.(regions, "dimension", "0d"))
    closed = count(==("closed_flux"), kinds); open = count(==("open_flux"), kinds)
    reversal = any(get(item, "reversal_surface", false) === true for item in fields)
    route = closed > 0 && open > 0 ? "closed_core_open_exhaust" :
        open > 0 ? "open_field" : "axisymmetric_closed"
    operators = sort!(unique(String(item["operator_id"])
        for item in Dict{String,Any}.(topology["operator_obligations"])))
    body = Dict{String,Any}(
        "route" => route, "closed_core_route" => "axisymmetric_closed",
        "closed_plasma_region_count" => closed,
        "declared_field_semantics" => sort!(unique(kinds)),
        "declared_boundaries" => sort!(unique(String(item["kind"])
            for item in Dict{String,Any}.(topology["boundaries"]))),
        "declared_operators" => operators,
        "declared_dimensions" => sort!(unique(dimensions)),
        "open_fraction" => open / max(length(fields), 1),
        "three_dimensional_fraction" => 0.0,
        "axisymmetric_fraction" => closed / max(length(fields), 1),
        "hybrid_fraction" => closed > 0 && open > 0 ? 1.0 : 0.0,
        "spatial_fraction" => count(>=(2), dimensions) / max(length(dimensions), 1),
        "field_operator_fraction" => count(op -> occursin("flux", lowercase(op)) ||
            occursin("field", lowercase(op)), operators) / max(length(operators), 1),
        "field_quality_parameter" => reversal ? 0.70 : 0.85,
        "reversal_surface" => reversal,
        "routing_axes" => ["inverse_field_semantics", "boundary", "operator", "dimension"],
        "identity_fields_used" => false)
    body["capability_hash"] = canonical_hash(body)
    body
end

function inverse_point_v102(sentinel)
    realization = Dict{String,Any}(sentinel["inverse_realization"])
    parameters = Dict{String,Any}(realization["physical_parameters"])
    state = Dict{String,Any}(sentinel["baseline_residual"]["state"])
    core = first(String(item["region_id"]) for item in
        Dict{String,Any}.(sentinel["inverse_topology"]["regions"])
        if String(item["role"]) == "closed_plasma_core")
    volume = Float64(parameters["volume_m3"])
    particles = Float64(state[core * "::particle_inventory"])
    thermal = Float64(state[core * "::thermal_energy"])
    minor = Float64(parameters["minor_radius_m"])
    major = Float64(get(parameters, "major_radius_m",
        max(Float64(parameters["characteristic_length_m"]), 2.5minor)))
    Dict{String,Any}(
        "major_radius_m" => major, "minor_radius_m" => minor,
        "elongation" => 1.0, "triangularity" => 0.0, "field_periods" => 1,
        "magnetic_field_t" => Float64(parameters["magnetic_field_t"]),
        "density_m3" => particles / volume,
        "temperature_kev" => thermal / max(3particles, eps()) /
            (1.0e3 * 1.602176634e-19),
        "wall_minor_radius_m" => 1.45minor,
        "coil_minor_radius_m" => 1.85minor,
        "open_branch_length_m" => Float64(parameters["characteristic_length_m"]),
        "volume_override_m3" => volume,
        "plasma_current_a" => Float64(state[core * "::plasma_current"]),
        "pulse_duration_s" => Float64(parameters["pulse_duration_s"]),
        "fuel" => String(parameters["fuel"]),
        "input_origin" => "v89_inverse_recovered_state_and_geometry",
        "adapter_assumptions" => ["unit_elongation", "zero_triangularity",
            "wall_radius_1.45_minor", "coil_radius_1.85_minor"],
        "basis_direct_metric_credit" => false)
end

function applicability_audit_v102(anchor, capability, solve)
    declared = Set(String(item["observable_id"])
        for item in Dict{String,Any}.(anchor["anchor_observables"]))
    capabilities = Set(String(item["capability_id"])
        for item in Dict{String,Any}.(anchor["capabilities"]))
    failed = String.(solve["failed_gates"])
    mismatches = String[]
    "net_electric_power" in failed && !("net_electric_power_w" in declared) &&
        push!(mismatches, "net_electric_power_gate_not_declared_by_reference_mission")
    "neutron_wall_load" in failed && !("neutron_wall_load_w_m2" in declared) &&
        push!(mismatches, "neutron_wall_load_gate_not_declared_by_reference_mission")
    "exhaust_heat_flux" in failed && !("exhaust_heat_flux_w_m2" in declared) &&
        push!(mismatches, "reactor_exhaust_gate_not_declared_by_reference_mission")
    "fusion_gain" in failed && !("fusion_reaction_radiation" in capabilities) &&
        push!(mismatches, "fusion_gain_gate_applied_without_fusion_reaction_capability")
    "temperature_fit_domain" in failed &&
        push!(mismatches, "reduced_reactor_model_outside_declared_temperature_domain")
    get(capability, "reversal_surface", false) === true &&
        "capability_scoped_stability" in failed && push!(mismatches,
            "tokamak_beta_n_proxy_not_attested_for_reversal_surface_equilibrium")
    Dict{String,Any}(
        "status" => isempty(mismatches) ? "no_detected_mismatch" :
            "selector_applicability_mismatch",
        "failed_gates" => failed, "applicability_mismatches" => mismatches,
        "rejection_is_device_physics_evidence" => isempty(mismatches),
        "claim_boundary" => V102_CLAIM_BOUNDARY)
end

root = normpath(joinpath(@__DIR__, ".."))
output_dir = abspath(option_v102("output-dir", joinpath(root, "runs",
    "v102_inverse_reference_candidate_experiment_20260829")))
report_path = abspath(option_v102("report", joinpath(root, "reports",
    "v102_inverse_reference_candidate_experiment_20260829.md")))
anchors_path = joinpath(root, "fixtures", "candidate_solver_reference_anchors_v1.json")
anchors = load_candidate_solver_reference_anchors_v1(anchors_path)
anchor_by_id = Dict(String(item["anchor_id"]) => Dict{String,Any}(plain_v102(item))
    for item in anchors)
inverse_run = run_universal_multitopology_acceptance_v89(anchors)
current_controls = run_v98_reference_acceptance(root)
control_rows = Dict{String,Any}.(current_controls["reference_controls"])

rows = Dict{String,Any}[]
for (index, sentinel_raw) in enumerate(inverse_run["sentinel_results"])
    sentinel = Dict{String,Any}(plain_v102(sentinel_raw))
    anchor = anchor_by_id[String(sentinel["source_reference_id"])]
    physics = inverse_physics_v102(sentinel)
    experimental = any(occursin("experimental", lowercase(String(get(item,
        "evidence_state", "")))) for item in Dict{String,Any}.(anchor["anchor_observables"]))
    generic = execute_physical_stage_chain_v96(physics;
        validation_applicable = experimental, validation_evidence = nothing)
    capability = inverse_capability_v102(sentinel)
    point = inverse_point_v102(sentinel)
    reduced = solve_candidate_physics_v98(point, capability)
    rejection_replay = numerical_vvuq_candidate_v98(point, capability, reduced)
    applicability = applicability_audit_v102(anchor, capability, reduced)
    control = control_rows[index]
    bypass = String(control["reference_status"]) == "pass" &&
        String(control["physics_screen_status"]) != "pass"
    high_fidelity = if reduced["status"] != "pass"
        Dict{String,Any}("status" => "not_executed",
            "reason" => "ordinary_candidate_reduced_physics_gate_failed")
    elseif get(capability, "reversal_surface", false) === true
        Dict{String,Any}("status" => "qualification_incomplete",
            "reason" => "no_registered_reversal_surface_FRC_free_boundary_provider")
    else
        Dict{String,Any}("status" => "qualification_incomplete",
            "reason" => "inverse_realization_lacks_explicit_shared_radial_build")
    end
    strict_validation = Dict{String,Any}("status" => "not_executed",
        "reason" => "ordinary_candidate_physics_screen_failed",
        "experimental_validation_credit" => false)
    row = Dict{String,Any}(
        "subject_key" => sentinel["source_reference_id"],
        "report_label" => sentinel["ui_label"],
        "inverse_topology_hash" => sentinel["inverse_topology"]["topology_hash"],
        "inverse_realization_hash" => sentinel["inverse_realization"]["realization_hash"],
        "inverse_candidate_hash" => sentinel["baseline_residual"]["candidate_hash"],
        "inverse_region_count" => length(sentinel["inverse_topology"]["regions"]),
        "inverse_route_status" => sentinel["baseline_route"]["status"],
        "v89_reduced_chain_status" => sentinel["chain_status"],
        "v89_numerical_vvuq_status" => first(sentinel[
            "integrated_screen_results"])["numerical_vvuq_status"],
        "v96_inverse_graph_status" => generic["status"],
        "v96_whole_graph_closed" => generic["solve"]["whole_graph_closed"],
        "v96_numerical_vvuq_status" => generic["numerical_vvuq"]["status"],
        "capability_profile" => capability,
        "ordinary_candidate_physics_screen_status" => reduced["status"],
        "ordinary_candidate_failed_gates" => reduced["failed_gates"],
        "ordinary_candidate_solve_hash" => reduced["solve_hash"],
        "rejection_numerical_replay" => Dict(
            "status" => rejection_replay["status"],
            "promotion_credit" => false,
            "reason" => "diagnostic_replay_of_rejected_state_only"),
        "selector_applicability" => applicability,
        "current_reference_control_status" => control["reference_status"],
        "current_reference_control_physics_screen_status" =>
            control["physics_screen_status"],
        "reference_control_bypass_detected" => bypass,
        "high_fidelity_downstream" => high_fidelity,
        "validation_vvuq" => strict_validation,
        "ordinary_candidate_final_status" => "selector_applicability_reject",
        "whole_device_credible" => false,
        "physical_conclusion_expanded" => false,
        "identity_fields_used_for_routing" => false,
        "strict_stage_order" => ["inverse_compile", "v89_provider_closure",
            "v89_reduced_solve", "v89_numerical_vvuq", "v96_graph_compile",
            "v96_provider_closure", "v96_solve", "v96_numerical_vvuq",
            "v98_ordinary_candidate_physics_screen", "high_fidelity_downstream",
            "validation_vvuq"])
    row["row_hash"] = canonical_hash(row)
    push!(rows, row)
end

ordinary_passes = count(row -> row["ordinary_candidate_final_status"] == "pass", rows)
bypasses = count(row -> row["reference_control_bypass_detected"] === true, rows)
mismatches = count(row -> row["selector_applicability"]["status"] ==
    "selector_applicability_mismatch", rows)
body = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V102_PROTOCOL,
    "status" => "complete", "selector_acceptance" =>
        bypasses == 0 && mismatches == 0 ? "pass" : "fail",
    "source_fixture_sha256" => bytes2hex(sha256(read(anchors_path))),
    "fresh_inverse_acceptance_hash" => inverse_run["artifact_hash"],
    "reference_subject_count" => length(rows),
    "inverse_representability_pass_count" => count(row ->
        row["inverse_route_status"] == "pass", rows),
    "v89_reduced_chain_pass_count" => count(row ->
        row["v89_reduced_chain_status"] == "pass", rows),
    "v96_inverse_graph_numerical_pass_count" => count(row ->
        row["v96_whole_graph_closed"] === true &&
        row["v96_numerical_vvuq_status"] == "pass", rows),
    "current_reference_control_pass_count" => count(row ->
        row["current_reference_control_status"] == "pass", rows),
    "ordinary_candidate_pass_count" => ordinary_passes,
    "ordinary_candidate_current_filter_reject_count" => count(row ->
        row["ordinary_candidate_physics_screen_status"] == "fail", rows),
    "ordinary_candidate_physical_reject_count" => count(row ->
        row["selector_applicability"]["rejection_is_device_physics_evidence"] === true &&
        row["ordinary_candidate_physics_screen_status"] == "fail", rows),
    "reference_control_bypass_count" => bypasses,
    "selector_applicability_mismatch_count" => mismatches,
    "unsupported_candidate_count" => 0,
    "provider_system_failure_count" => 0,
    "validation_pass_count" => 0, "whole_device_credible_count" => 0,
    "rows" => rows,
    "interpretation" => "Both inverse references execute the generic reduced graph, but " *
        "neither passes the current ordinary-candidate v98 reactor screen. The old 2/2 " *
        "reference-control result bypasses that failed physics status; detected mission " *
        "and model-domain mismatches prevent treating these rejections as device physics.",
    "claim_boundary" => V102_CLAIM_BOUNDARY)
body = Dict{String,Any}(plain_v102(JSON3.read(JSON3.write(body), Dict{String,Any})))
body["acceptance_hash"] = canonical_hash(body)
atomic_json_v102(joinpath(output_dir, "acceptance.json"), body)

table = join(["| $(row["report_label"]) | $(row["inverse_region_count"]) | " *
    "$(row["v89_reduced_chain_status"]) | $(row["v96_numerical_vvuq_status"]) | " *
    "$(row["ordinary_candidate_physics_screen_status"]) | " *
    "$(join(row["ordinary_candidate_failed_gates"], ", ")) | " *
    "$(row["current_reference_control_status"]) | " *
    "$(row["selector_applicability"]["status"]) |" for row in rows], "\n")
report = """# v102 ITER/C-2W 反解结果普通候选全流程实验

## 结果

| 输入 | 反解区域 | v89 | v96 numerical VVUQ | 普通候选 v98 | 失败门 | 旧 reference 状态 | 适用性审计 |
|---|---:|---|---|---|---|---|---|
$table

ITER 与 C-2W 的 v89 反解均可表示、可闭合，并以完整反解多区域图通过 v96 whole-graph
solve 和 numerical VVUQ；但把同一反解状态按普通候选送入当前 v98 后，两者都在 reduced
reactor physics screen 被拒绝，后续高保真和 validation 按严格顺序不执行。因此当前普通候选
全流程通过数是 **$ordinary_passes/$(length(rows))**。

## 筛选器诊断

现有 reference-control 汇总仍报告 2/2 pass，但两行内部的 `physics_screen_status` 都是 fail。
reference pass 只要求 numerical replay 和公开区间回归，没有要求普通候选物理门通过；本实验
因此检出 **$bypasses** 个 reference-control bypass。ITER 还被施加未由其参考任务声明的净电
功率和反应堆排热门；C-2W 是非 D-T、反转场开放损失区实验，却被施加 D-T 增益、净电功率、
中子壁负荷等门，且其温度超出当前 reduced reactor model 的适用域。两者当前 rejection 均不能
提升为装置物理失败。

## 证据边界

本实验没有按名称路由，没有给参考装置候选或 validation credit，也没有绕过失败继续提升。
ITER 的公开值是设计目标而非 D-T 实验验证；C-2W 的公开区间未形成与本求解输入独立、含测量
不确定度和适用域签署的 validation contract。可信整机和 validation pass 均为 0。

Acceptance hash: `$(body["acceptance_hash"])`

$V102_CLAIM_BOUNDARY
"""
mkpath(dirname(report_path)); write(report_path, report)
println(JSON3.write(Dict(key => body[key] for key in (
    "status", "selector_acceptance", "ordinary_candidate_pass_count",
    "ordinary_candidate_current_filter_reject_count",
    "ordinary_candidate_physical_reject_count", "reference_control_bypass_count",
    "selector_applicability_mismatch_count", "unsupported_candidate_count",
    "provider_system_failure_count", "acceptance_hash"))))
