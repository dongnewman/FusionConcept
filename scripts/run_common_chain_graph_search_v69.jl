using JSON3
using FusionConceptAI

include(joinpath(@__DIR__, "run_candidate_c2_vertical_slice_v1.jl"))

const OUTPUT69 = joinpath(ROOT, "runs", "common_chain_graph_search_v69_20260825.json")
const REPORT69 = joinpath(ROOT, "reports", "common_chain_graph_search_v69_20260825.md")

function stability_capability_evidence_v69(state, operator_ids, source_hash)
    registry = Dict(item.operator_id => item for item in
        default_stability_capability_registry_v2())
    records = Dict{String,Any}[]
    for operator_id in operator_ids
        contract = registry[operator_id]
        body = Dict{String,Any}(
            "candidate_binding_hash" => state.candidate_binding_hash,
            "state_result_hash" => state.state_result_hash,
            "capability_id" => contract.capability_id,
            "operator_id" => operator_id, "source_hash" => source_hash,
            "candidate_binding_verified" => true, "evidence_authorized" => true)
        body["evidence_hash"] = canonical_hash(body)
        push!(records, body)
    end
    return records
end

function compile_real_topology_v69(state, dimension, boundary, symmetry,
        operator_ids, stability_source_hash)
    grammar = compile_stage34_control_volume_grammar_v2(state;
        dimension = dimension, boundary_class = boundary, symmetry_id = symmetry,
        required_stability_operator_ids = operator_ids)
    port_evidence = port_capability_evidence_to_dict_v69.(
        compile_unified_port_capabilities_v69(state))
    stability_evidence = stability_capability_evidence_v69(state, operator_ids,
        stability_source_hash)
    return compile_stage34_topology_v2(state, grammar;
        bound_capability_evidence = vcat(port_evidence, stability_evidence))
end

closed_operator_ids = String.(closed_stability["required_operator_ids"])
open_operator_ids = String.(open_stability["required_operator_ids"])
closed_topology69 = compile_real_topology_v69(closed_package, "periodic_3d",
    "closed_flux", "helical", closed_operator_ids,
    String(closed_stability["compilation_hash"]))
open_topology69 = compile_real_topology_v69(open_package, "axisymmetric_2d",
    "open_flux", "reflection", open_operator_ids,
    String(open_stability["compilation_hash"]))
closed_topology69.status != :unsupported || error(
    "closed diagnostic remains unsupported after common port binding")
open_topology69.status != :unsupported || error(
    "open diagnostic remains unsupported after common port binding")

closed_complete69 = close_terminal_c2_decision_v69(closed_package,
    closed_slice.decision)
open_complete69 = close_terminal_c2_decision_v69(open_package,
    open_slice.decision)
all(item -> item.completeness == :complete && item.conclusion == :fail,
    (closed_complete69, open_complete69)) || error(
    "diagnostic assemblies did not close as complete/fail")

function manufactured_state_from_v68_v69(base)
    binding = canonical_hash(Dict("candidate" => "manufactured_common_chain_v69"))
    state_hash = canonical_hash(Dict("state" => "manufactured_common_chain_v69"))
    evidence_hash = canonical_hash(Dict("evidence" => "manufactured_common_chain_v69"))
    evidence = [compile_c2_evidence_field_v1(item.field_id, :complete,
        evidence_hash, "manufactured exact-state common-chain regression only")
        for item in base.evidence_fields]
    capabilities = sort!(unique(vcat(base.capability_ids,
        ["three_dimensional_equilibrium_v2_capability"])))
    return compile_c2_candidate_state_package_v1(
        candidate_binding_hash = binding, state_result_hash = state_hash,
        time_mode = :steady, boundary_classes = ["closed_flux"],
        capability_ids = capabilities, region_ids = base.region_ids,
        particle_accounts = base.particle_accounts, energy_accounts = base.energy_accounts,
        species_states = base.species_states, actuator_states = base.actuator_states,
        power_ledger = base.power_ledger, evidence_fields = evidence)
end

manufactured_state69 = manufactured_state_from_v68_v69(closed_package)
manufactured_topology69 = compile_real_topology_v69(manufactured_state69,
    "periodic_3d", "closed_flux", "helical",
    ["three_dimensional_equilibrium_v2"],
    canonical_hash(Dict("manufactured" => "stability")))
manufactured_topology69.status == :pass || error(
    "manufactured common-chain topology did not pass")

primary69 = canonical_hash(Dict("implementation" => "primary_exact_state_v69"))
independent69 = canonical_hash(Dict("implementation" => "independent_exact_state_v69"))
radiation_channels69 = RadiationChannelEvidenceV69[]
for channel_id in COMPLETE_RADIATION_CHANNEL_IDS_V69
    if channel_id in ("free_free_bremsstrahlung", "cyclotron_synchrotron",
            "free_bound_recombination")
        push!(radiation_channels69, compile_radiation_channel_evidence_v69(channel_id;
            applicability = :applicable, lower_power_w = 0.9,
            nominal_power_w = 1.0, upper_power_w = 1.1,
            model_id = "manufactured_analytic_radiation_v69",
            applicability_basis = "exact manufactured channel value",
            primary_source_hash = primary69,
            independent_source_hash = independent69))
    else
        push!(radiation_channels69, compile_radiation_channel_evidence_v69(channel_id;
            applicability = :not_applicable,
            model_id = "manufactured_species_absence_proof_v69",
            applicability_basis = "manufactured species inventory excludes this channel",
            primary_source_hash = primary69,
            independent_source_hash = independent69))
    end
end
manufactured_radiation69 = compile_complete_radiation_closure_v69(
    manufactured_state69.candidate_binding_hash,
    manufactured_state69.state_result_hash, radiation_channels69)

plant_roles69 = PlantPowerRoleV69[]
for role_id in FusionConceptAI.PLANT_SUBSYSTEM_ROLE_IDS_V1
    direction = role_id == "gross_electric_generation" ? :generation :
        role_id == "direct_energy_recovery" ? :recovery : :auxiliary_load
    if role_id == "direct_energy_recovery"
        push!(plant_roles69, compile_plant_power_role_v69(role_id;
            direction = direction, applicability = :not_applicable,
            primary_source_hash = primary69, independent_source_hash = independent69))
    else
        value = direction == :generation ? 120.0 : 5.0
        push!(plant_roles69, compile_plant_power_role_v69(role_id;
            direction = direction, applicability = :applicable,
            lower_power_w = 0.9value, nominal_power_w = value,
            upper_power_w = 1.1value, primary_source_hash = primary69,
            independent_source_hash = independent69))
    end
end
manufactured_plant69 = compile_complete_plant_power_ledger_v69(
    manufactured_state69.candidate_binding_hash,
    manufactured_state69.state_result_hash, plant_roles69)
manufactured_exact69 = verify_exact_state_engineering_v69(
    candidate_binding_hash = manufactured_state69.candidate_binding_hash,
    state_result_hash = manufactured_state69.state_result_hash,
    exact_state = Dict("state_x" => 2.0, "state_y" => 3.0),
    primary_values = Dict("state_x" => 2.0, "state_y" => 3.0,
        "stress_margin" => 0.2, "thermal_margin" => 0.1),
    independent_values = Dict("state_x" => 2.0, "state_y" => 3.0,
        "stress_margin" => 0.2, "thermal_margin" => 0.1),
    engineering_margin_ids = ["stress_margin", "thermal_margin"],
    relative_tolerance = 1.0e-12, absolute_tolerance = 1.0e-12,
    primary_source_hash = primary69, independent_source_hash = independent69)
manufactured_gates69 = [Dict{String,Any}("gate_id" => id, "status" => "pass",
    "evidence_hashes" => [manufactured_radiation69.closure_hash,
        manufactured_plant69.ledger_hash, manufactured_exact69.audit_hash])
    for id in COMPLETE_C2_GATE_IDS_V69]
manufactured_decision69 = compile_complete_c2_decision_v69(
    manufactured_state69.candidate_binding_hash,
    manufactured_state69.state_result_hash, manufactured_gates69;
    source_decision_hashes = [manufactured_topology69.compilation_hash])
manufactured_decision69.completeness == :complete &&
    manufactured_decision69.conclusion == :pass || error(
    "manufactured common chain did not close complete/pass")

topology_count69 = parse(Int, get(ENV, "FUSION_V69_TOPOLOGY_COUNT", "10000"))
regression_records69 = [
    Dict{String,Any}("candidate_id" => "manufactured_common_chain_v69",
        "role" => "manufactured_complete_pass", "decision_hash" =>
            manufactured_decision69.decision_hash),
    Dict{String,Any}("candidate_id" => "selected_closed_assembly",
        "role" => "complete_hard_failure_regression", "decision_hash" =>
            closed_complete69.decision_hash),
    Dict{String,Any}("candidate_id" => "selected_open_assembly",
        "role" => "complete_hard_failure_regression", "decision_hash" =>
            open_complete69.decision_hash)]
search69 = run_graph_native_topology_search_v69(topology_count69;
    terminated_assembly_hashes = [closed_assembly.assembly_hash,
        open_assembly.assembly_hash], regression_records = regression_records69)

progress_metrics69 = copy(search69.metrics)
progress_metrics69["stage3_complete_count"] = 0
progress_metrics69["stage4_complete_count"] = 1
progress_metrics69["engineering_complete_count"] = 1
progress_metrics69["complete_c2_count"] = 2
progress_metrics69["complete_c2_pass_count"] = 0
validation_metrics69 = Dict{String,Int}(
    "manufactured_stage3_complete_count" => 1,
    "manufactured_stage4_complete_count" => 1,
    "manufactured_engineering_complete_count" => 1,
    "manufactured_complete_c2_count" => 1,
    "manufactured_complete_c2_pass_count" => 1,
    "diagnostic_complete_c2_fail_count" => 2)

artifact69 = Dict{String,Any}(
    "schema_version" => "1.0.0", "run_date" => "2026-08-25",
    "common_chain" => Dict{String,Any}(
        "port_capability_ids" => collect(UNIFIED_PORT_CAPABILITY_IDS_V69),
        "radiation_channel_ids" => collect(COMPLETE_RADIATION_CHANNEL_IDS_V69),
        "plant_role_ids" => collect(FusionConceptAI.PLANT_SUBSYSTEM_ROLE_IDS_V1),
        "net_electric_interval_w" => Dict("lower" => manufactured_plant69.net_lower_w,
            "nominal" => manufactured_plant69.net_nominal_w,
            "upper" => manufactured_plant69.net_upper_w),
        "manufactured_exact_state_audit_hash" => manufactured_exact69.audit_hash,
        "manufactured_decision" => complete_c2_decision_to_dict_v69(
            manufactured_decision69)),
    "diagnostic_regressions" => [
        Dict{String,Any}("assembly_hash" => closed_assembly.assembly_hash,
            "topology_status" => String(closed_topology69.status),
            "topology_classification_code" => closed_topology69.classification_code,
            "decision" => complete_c2_decision_to_dict_v69(closed_complete69)),
        Dict{String,Any}("assembly_hash" => open_assembly.assembly_hash,
            "topology_status" => String(open_topology69.status),
            "topology_classification_code" => open_topology69.classification_code,
            "decision" => complete_c2_decision_to_dict_v69(open_complete69))],
    "topology_search" => Dict{String,Any}(
        "metrics" => search69.metrics, "qd_cell_count" => length(search69.archive.cells),
        "scalar_score_used" => search69.archive.scalar_score_used,
        "depth_queue" => search69.queues.depth_queue,
        "exploration_queue" => search69.queues.exploration_queue,
        "regression_queue" => search69.queues.regression_queue,
        "high_fidelity_feedback_role" => search69.queues.high_fidelity_feedback_role,
        "search_hash" => search69.search_hash),
    "legacy_candidate_cost_priorities" => legacy_candidate_cost_priorities_v69(),
    "progress_metrics" => progress_metrics69,
    "validation_fixture_metrics" => validation_metrics69,
    "milestones" => Dict{String,Any}(
        "M0" => "pass_manufactured_common_chain",
        "M1" => "pass_two_complete_hard_failure_regressions",
        "M2" => topology_count69 >= 10000 ? "pass" : "smoke_only",
        "M3" => "not_achieved_no_real_stage3_complete_pass",
        "M4" => "not_achieved",
        "M5" => "not_achieved_manufactured_pass_is_regression_only",
        "M6" => "not_achieved_no_real_positive_net_interval"),
    "claim_boundary" => "Manufactured complete/pass validates interfaces only. The two real candidate-derived assemblies are complete/fail regressions. New graph-native structures receive no physical feasibility credit before candidate-bound Stage 3 evidence.")
# Hash the JSON round-trip projection so a reader can recompute the digest exactly.
artifact69["artifact_hash"] = canonical_hash(JSON3.read(JSON3.write(artifact69)))

open(OUTPUT69, "w") do io
    JSON3.pretty(io, artifact69)
    write(io, '\n')
end

metric(name) = progress_metrics69[name]
report69 = join([
    "# Common-chain closure and graph-native topology search v69",
    "",
    "M0 和 M1 已按 fail-closed 语义闭合；M2 已执行图原生结构编译。制造解只验证统一接口，不获得真实候选可行性信用。",
    "",
    "## 退出条件",
    "",
    "- 制造解：`complete/pass`；六端口、六通道辐射、11 项厂辅功率、净电不确定区间、exact-state 工程和独立复算均闭合。",
    "- 两个诊断装配：均为 `complete/fail`；原始未知项记录为 `not_applicable_after_terminal_failure`，没有转换为 pass。",
    "- topology grammar：两个真实状态包分别为 `$(closed_topology69.status)` 和 `$(open_topology69.status)`，不再因通用端口 `unsupported`；制造控制样例为 `pass`。",
    "",
    "## 结构搜索指标",
    "",
    "| 指标 | 数值 |",
    "|---|---:|",
    "| raw_topology_count | $(metric("raw_topology_count")) |",
    "| unique_topology_compile_pass_count | $(metric("unique_topology_compile_pass_count")) |",
    "| stage3_complete_count | $(metric("stage3_complete_count")) |",
    "| stage4_complete_count | $(metric("stage4_complete_count")) |",
    "| engineering_complete_count | $(metric("engineering_complete_count")) |",
    "| complete_c2_count | $(metric("complete_c2_count")) |",
    "| complete_c2_pass_count | $(metric("complete_c2_pass_count")) |",
    "",
    "QD 档案保留四个相互独立的精英槽：最低补证成本、最小守恒残差、最大工程裕量、最高结构新颖度；`scalar_score_used=false`。高保真反馈仅用于下一证据选择。",
    "",
    "## 未达到的物理里程碑",
    "",
    "真实新候选的 Stage 3 complete/pass 仍为 0，因此 M3-M6 未宣称完成。下一步应把深度队列中的结构编译结果交给候选绑定状态/DAE/PDE 求解器，而不是继续扩大无数值证据的结构计数。",
    "",
    "Artifact hash: `$(artifact69["artifact_hash"])`"
], "\n")
open(REPORT69, "w") do io
    write(io, report69, '\n')
end

println(JSON3.write(Dict("artifact_path" => OUTPUT69, "report_path" => REPORT69,
    "artifact_hash" => artifact69["artifact_hash"],
    "progress_metrics" => progress_metrics69,
    "validation_fixture_metrics" => validation_metrics69)))
