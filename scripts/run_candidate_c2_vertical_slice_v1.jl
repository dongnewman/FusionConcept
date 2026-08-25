using JSON3
using SHA
using FusionConceptAI

const ROOT = normpath(joinpath(@__DIR__, ".."))
const FRONTIER_PATH = joinpath(ROOT, "runs", "c1_c2_frontier_candidates_v1_20260816.json")
const CLOSED_AUDIT_PATH = joinpath(ROOT, "runs",
    "topology_desc_stability_pool24_medium_fine_audit_v4_20260816.json")
const CLOSED_COIL_PATH = joinpath(ROOT, "runs",
    "topology_desc_discrete_coil_cut_pool24_v7_20260816.json")
const OPEN_WINDING_PATH = joinpath(ROOT, "runs",
    "candidate_specific_mirror_winding_candidates_v1_20260816.jsonl")
const OUTPUT_PATH = joinpath(ROOT, "runs", "candidate_c2_vertical_slice_v1_20260825.json")
const REPORT_PATH = joinpath(ROOT, "reports", "candidate_c2_vertical_slice_v1_20260825.md")

file_hash(path) = bytes2hex(sha256(read(path)))

function plain(value)
    value isa AbstractDict && return Dict{String,Any}(String(key) => plain(child)
        for (key, child) in pairs(value))
    value isa AbstractVector && return Any[plain(child) for child in value]
    return value
end

function declaration(id, value, unit, provenance, source_hash; role = nothing)
    result = Dict{String,Any}("declaration_id" => id, "value" => value,
        "unit" => unit, "provenance_kind" => provenance,
        "source_hash" => source_hash)
    role === nothing || (result["role"] = role)
    return result
end

function operating_point(base_hash, volume, pressure, ti, te, source_hash;
        complete_radiation = false)
    states = [
        declaration("plasma_volume_m3", volume, "m^3", "candidate_design_declaration", source_hash),
        declaration("thermal_pressure_pa", pressure, "Pa", "candidate_design_declaration", source_hash),
        declaration("ion_temperature_kev", ti, "keV", "candidate_design_declaration", source_hash),
        declaration("electron_temperature_kev", te, "keV", "candidate_design_declaration", source_hash)]
    actuators = [
        declaration("fueling_capacity", 1.0, "normalized_capacity",
            "candidate_design_declaration", source_hash; role = "fueling"),
        declaration("heating_capacity", 1.0, "normalized_capacity",
            "candidate_design_declaration", source_hash; role = "heating"),
        declaration("exhaust_capacity", 1.0, "normalized_capacity",
            "candidate_design_declaration", source_hash; role = "exhaust"),
        declaration("radiation_control_capacity", 1.0, "normalized_capacity",
            "candidate_design_declaration", source_hash; role = "radiation_control")]
    models = [
        declaration("transport_response", 1.0, "compiled_response",
            "compiler_derived", source_hash),
        declaration("complete_radiation_model", complete_radiation, "boolean",
            "candidate_design_declaration", source_hash)]
    return compile_candidate_operating_point_v1(
        base_candidate_binding_hash = base_hash, state_declarations = states,
        actuator_declarations = actuators, model_declarations = models)
end

function frontier_record(id)
    raw = plain(JSON3.read(read(FRONTIER_PATH, String)))
    return only(filter(item -> String(item["candidate_id"]) == id, raw["candidates"]))
end

function winding_record(base_hash)
    for line in eachline(OPEN_WINDING_PATH)
        isempty(strip(line)) && continue
        record = plain(JSON3.read(line))
        String(record["physical_result_hash"]) == base_hash && return record
    end
    error("open winding record not found")
end

frontier_hash = file_hash(FRONTIER_PATH)

closed_record = frontier_record("stellarator_fourier_8647ca48b309418d")
closed_parameters = Dict{String,Any}(closed_record["parameters"])
closed_base = String(closed_parameters["candidate_physics_hash"])
closed_geometry = Dict{String,Any}(closed_parameters["geometry"])
closed_state = Dict{String,Any}(closed_parameters["operating_state"])
closed_coils = Dict{String,Any}(plain(JSON3.read(read(CLOSED_COIL_PATH, String))))
closed_cut = only(filter(item -> Int(item["total_physical_coil_count"]) == 32,
    closed_coils["cuts"]))
closed_operating = operating_point(closed_base,
    Float64(closed_geometry["plasma_volume_m3"]),
    Float64(first(closed_state["pressure_power_series_Pa"])), 10.0, 10.0,
    frontier_hash; complete_radiation = false)
closed_actuator_hash = canonical_hash(Dict("declarations" =>
    closed_operating.actuator_declarations))
closed_engineering_manifest_hash = canonical_hash(Dict(
    "required_obligations" => ["field_source_boundary_fidelity",
        "finite_build_load_path", "material_margin"],
    "normalized_bn_rms_limit" => 0.01))
closed_assembly = compile_candidate_assembly_binding_v1(closed_operating;
    plasma_configuration_hash = String(closed_parameters["stability_problem_hash"]),
    field_source_component_hashes = [String(closed_cut["coil_state_hash"])],
    boundary_hash = canonical_hash(Dict("geometry" => closed_geometry,
        "boundary_class" => "closed_flux")),
    actuator_manifest_hash = closed_actuator_hash,
    engineering_manifest_hash = closed_engineering_manifest_hash)
closed_plan, closed_result, closed_package = solve_candidate_c2_longitudinal_slice_v1(
    closed_operating, closed_assembly; flux_semantics = :radial_boundary,
    transport_operator_id = "closed_surface_radial_affine_response_v1",
    topology_boundary_class = "closed_flux")
closed_stability = compile_closed_assembly_stage4_projection_v1(closed_assembly,
    closed_package; audit_path = CLOSED_AUDIT_PATH, frontier_path = FRONTIER_PATH)
closed_engineering = compile_c2_bound_gate_evidence_v1(
    candidate_binding_hash = closed_assembly.assembly_hash,
    state_result_hash = closed_package.state_result_hash, gate_id = "engineering",
    status = :fail, obligation_ids = ["field_source_boundary_fidelity",
        "finite_build_load_path", "material_margin"],
    failed_obligation_ids = ["field_source_boundary_fidelity"],
    evidence_hashes = [file_hash(CLOSED_COIL_PATH), String(closed_cut["coil_state_hash"]),
        closed_assembly.assembly_hash], terminates_candidate = true,
    claim_boundary = "The selected 32-line-current component has normalized boundary-normal field RMS $(closed_cut["normalized_bn_rms"]), above the assembly limit 0.01. This hard-fails only this composite field-source realization; the base plasma boundary and alternative coil grammars remain unfalsified.")
closed_slice = compile_candidate_c2_vertical_slice_result_v1(closed_operating,
    closed_assembly, closed_plan, closed_result, closed_package, closed_stability,
    closed_engineering)

open_record = frontier_record("mirror_repair_3bcbc727c31cba40")
open_parameters = Dict{String,Any}(open_record["parameters"])
open_base = String(open_parameters["candidate_physics_hash"])
open_geometry = Dict{String,Any}(open_parameters["geometry"])
open_state = Dict{String,Any}(open_parameters["operating_state"])
open_winding = winding_record(open_base)
open_selected = Dict{String,Any}(open_winding["selected_repair"])
open_repair = Dict{String,Any}(open_selected["minimum_similarity_repair"])
open_volume = pi * Float64(open_geometry["plasma_radius_m"])^2 *
    (2.0 * Float64(open_geometry["pair_half_separation_m"]))
# A bounded operating-point declaration used to exercise the shared state package;
# it is not promoted to device performance evidence.
open_operating = operating_point(open_base, open_volume, 2500.0, 10.0, 10.0,
    frontier_hash; complete_radiation = false)
open_actuator_hash = canonical_hash(Dict("declarations" =>
    open_operating.actuator_declarations))
open_engineering_manifest_hash = canonical_hash(Dict(
    "required_obligations" => ["finite_winding_field_limit", "structural_load_path",
        "material_margin"], "peak_field_limit_t" =>
        Float64(open_repair["peak_conductor_field_limit_T"])))
open_assembly = compile_candidate_assembly_binding_v1(open_operating;
    plasma_configuration_hash = open_base,
    field_source_component_hashes = [String(open_winding["refined_solver_problem_hash"])],
    boundary_hash = canonical_hash(Dict("geometry" => open_geometry,
        "boundary_class" => "open_flux")),
    actuator_manifest_hash = open_actuator_hash,
    engineering_manifest_hash = open_engineering_manifest_hash)
open_plan, open_result, open_package = solve_candidate_c2_longitudinal_slice_v1(
    open_operating, open_assembly; flux_semantics = :parallel_boundary,
    transport_operator_id = "open_boundary_parallel_affine_response_v1",
    topology_boundary_class = "open_flux")
open_stability = compile_open_assembly_minimum_b_stage4_v1(open_assembly,
    open_package; winding_jsonl_path = OPEN_WINDING_PATH,
    base_candidate_binding_hash = open_base)
open_engineering = compile_c2_bound_gate_evidence_v1(
    candidate_binding_hash = open_assembly.assembly_hash,
    state_result_hash = open_package.state_result_hash, gate_id = "engineering",
    status = :unknown, obligation_ids = ["finite_winding_field_limit",
        "structural_load_path", "material_margin"],
    evidence_hashes = [file_hash(OPEN_WINDING_PATH)],
    evidence_tasks = ["resolve_selected_winding_structural_load_path",
        "bind_temperature_dependent_material_margin_to_shared_state"],
    claim_boundary = "The selected finite winding has converged vacuum-field and force lower-bound evidence, but no complete structural load path or temperature-dependent material margin.")
open_slice = compile_candidate_c2_vertical_slice_result_v1(open_operating,
    open_assembly, open_plan, open_result, open_package, open_stability,
    open_engineering)

closed_projection = c2_state_structural_projection_v1(closed_package)
open_projection = c2_state_structural_projection_v1(open_package)
closed_projection == open_projection || error(
    "closed and open assemblies did not produce the same C2 state-package shape")
closed_slice.decision.required_gate_ids == open_slice.decision.required_gate_ids || error(
    "closed and open assemblies did not traverse the same C2 gate chain")
all(slice -> slice.decision.candidate_conclusion == :fail &&
        slice.decision.terminate, (closed_slice, open_slice)) || error(
    "both selected assemblies must produce authoritative terminal hard failures")

artifact = Dict{String,Any}(
    "schema_version" => "1.0.0", "run_date" => "2026-08-25",
    "chain_contract" => Dict("gate_ids" => closed_slice.decision.required_gate_ids,
        "shared_state_projection" => closed_projection,
        "family_or_device_routing_used" => false,
        "candidate_declarations_are_feasibility_evidence" => false),
    "rows" => [Dict("route_metadata" => "closed_flux",
            "base_candidate_binding_hash" => closed_base,
            "slice" => candidate_c2_vertical_slice_to_dict_v1(closed_slice)),
        Dict("route_metadata" => "open_flux",
            "base_candidate_binding_hash" => open_base,
            "slice" => candidate_c2_vertical_slice_to_dict_v1(open_slice))],
    "summary" => Dict("evaluated_assembly_count" => 2,
        "terminal_hard_failure_count" => 2,
        "complete_c2_evidence_count" => count(slice ->
            slice.decision.completeness == :complete, (closed_slice, open_slice)),
        "claim_boundary" => "Two real candidate-derived composite assemblies traversed the identical four-gate C2 aggregator. Terminal hard failure is independent of remaining evidence completeness and does not falsify alternative assemblies."))
artifact["deterministic_hash"] = canonical_hash(artifact)
mkpath(dirname(OUTPUT_PATH))
open(OUTPUT_PATH, "w") do io
    JSON3.pretty(io, artifact)
    write(io, '\n')
end

function decision_line(label, slice)
    decision = slice.decision
    return "| $label | $(decision.completeness) | $(decision.candidate_conclusion) | $(decision.terminate) | $(join(decision.failed_gate_ids, ", ")) | $(join(decision.incomplete_gate_ids, ", ")) |"
end
report = join([
    "# Candidate-bound C2 vertical slice v1",
    "",
    "闭合与开放装配使用完全相同的粒子、能量、物种、执行器、功率与证据状态包，并经过同一组四个 C2 汇总门。候选/设备标签只保留为报告元数据，不参与能力选择。",
    "",
    "| 装配 | 完整度 | 候选结论 | 终止 | 失败门 | 未完成门 |",
    "|---|---:|---:|---:|---|---|",
    decision_line("闭合场 32 线圈装配", closed_slice),
    decision_line("开放场双线圈最小 B 装配", open_slice),
    "",
    "两个结论都是候选装配级硬失败，但 C2 完整度仍诚实保留为 incomplete：闭合装配缺 error-field/fast-ion 完整 Stage-4 证据；开放装配缺结构载荷路径与材料裕量。终止授权来自已经闭合的必要条件失败，而不是把未知证据补写成 pass。",
    "",
    "Artifact hash: `$(artifact["deterministic_hash"])`"
], "\n")
mkpath(dirname(REPORT_PATH))
open(REPORT_PATH, "w") do io
    write(io, report, '\n')
end

println(JSON3.write(Dict("artifact_path" => OUTPUT_PATH,
    "report_path" => REPORT_PATH,
    "deterministic_hash" => artifact["deterministic_hash"],
    "closed" => c2_decision_envelope_to_dict_v1(closed_slice.decision),
    "open" => c2_decision_envelope_to_dict_v1(open_slice.decision))))
