using FusionConceptAI
using JSON3

const ROOT_V70 = normpath(joinpath(@__DIR__, ".."))

function acceptance_topology_v70(dimension::String, time_mode::String)
    base = generate_graph_native_topology_v69(4)
    regions = deepcopy(base.regions)
    regions[1]["dimension"] = dimension
    regions[1]["time_mode"] = time_mode
    regions[1]["boundary_class"] = "mixed"
    regions[1]["state_slots"] = deepcopy(regions[1]["state_slots"][1:5])
    regions[1]["algebraic_slots"] = time_mode == "dae" ? ["constraint_1"] : String[]
    topology = compile_graph_native_topology_v69(regions = regions,
        interfaces = deepcopy(base.interfaces), ports = deepcopy(base.ports),
        dependencies = deepcopy(base.dependencies), symmetry = base.symmetry,
        obligations = deepcopy(base.obligations))
    return topology, compile_graph_native_topology_candidate_v69(topology)
end

function acceptance_request_v70(dimension, time_mode, model;
        extra = Dict{String,Any}(), samples = 1, levels = [16, 64, 256])
    topology, compilation = acceptance_topology_v70(dimension, time_mode)
    binding = Dict{String,Any}("execution_model" => model)
    merge!(binding, extra)
    return compile_stage3_execution_request_v1(topology, compilation;
        parameter_binding = binding,
        sample_spec = Dict{String,Any}("required_sample_count" => samples,
            "dimension" => 2, "sequence" => "halton_v1"),
        budget = Stage3ExecutionBudgetV1(maximum_wall_seconds = 30.0,
            maximum_time_steps = 512, maximum_degrees_of_freedom = 20_000,
            resolution_levels = levels))
end

function acceptance_record_v70(id, dimension, mode, model; kwargs...)
    request = acceptance_request_v70(dimension, mode, model; kwargs...)
    plan, evidence = execute_stage3_request_v1(request)
    return Dict{String,Any}("control_id" => id,
        "plan" => stage3_execution_plan_to_dict_v1(plan),
        "evidence" => stage3_evidence_envelope_to_dict_v1(evidence))
end

positive_specs = [
    ("positive_0d_steady_nonlinear", "0d", "steady",
        Dict("kind" => "nonlinear_balance", "source" => [1.0, 0.8],
            "decay" => [1.0, 1.5], "quadratic" => [0.2, 0.1])),
    ("positive_0d_transient_source_loss", "0d", "transient",
        Dict("kind" => "linear_transient", "loss_rate" => 0.7,
            "source" => 1.2, "initial" => 0.2, "time_steps" => 128)),
    ("positive_0d_index1_dae", "0d", "dae",
        Dict("kind" => "index1_dae", "rate" => 2.0, "gain" => 0.5,
            "offset" => 0.1, "time_steps" => 128)),
    ("positive_1d_steady_diffusion_reaction", "1d", "steady",
        Dict("kind" => "manufactured_diffusion", "dimension" => 1,
            "diffusion" => 0.8)),
    ("positive_1d_transient_advection_diffusion", "1d", "transient",
        Dict("kind" => "manufactured_diffusion", "dimension" => 1,
            "diffusion" => 0.5, "advection" => 0.3,
            "transient" => true, "time_steps" => 128)),
    ("positive_2d_steady_elliptic", "2d", "steady",
        Dict("kind" => "manufactured_diffusion", "dimension" => 2,
            "diffusion" => 0.8)),
    ("positive_2d_transient_conservative_diffusion", "2d", "transient",
        Dict("kind" => "manufactured_diffusion", "dimension" => 2,
            "diffusion" => 0.4, "transient" => true, "time_steps" => 128)),
    ("positive_3d_steady_diffusion", "3d", "steady",
        Dict("kind" => "manufactured_diffusion", "dimension" => 3,
            "diffusion" => 0.7)),
    ("positive_multi_region_paired_flux", "0d", "steady",
        Dict("kind" => "multi_region_flux", "matrix" => [[2.0, -1.0], [-1.0, 2.0]],
            "source" => [1.0, 1.0], "interface_flux_signs" => [1.0, -1.0])),
    ("positive_closed_loop_tracking", "0d", "steady",
        Dict("kind" => "closed_loop_control", "matrix" => [[2.0, -0.2], [-0.2, 1.5]],
            "source" => [1.0, 0.2], "controller_poles" => [-1.0, -2.0],
            "actuator_load" => 0.5, "actuator_capacity" => 1.0)),
    ("positive_mixed_0d_1d", "1d", "steady",
        Dict("kind" => "mixed_0d_1d", "diffusion" => 0.8,
            "coupling" => 0.2, "zero_d_loss" => 1.0, "pde_source" => 0.5))]
positive = [acceptance_record_v70(spec...) for spec in positive_specs]

negative_specs = [
    ("diagnostic_actuator_capacity", Dict("kind" => "generic_graph_balance",
        "actuator_load" => 2.0, "actuator_capacity" => 1.0), Dict{String,Any}()),
    ("diagnostic_source_not_closed", Dict("kind" => "generic_graph_balance",
        "declared_source" => 2.0, "declared_sink" => 1.0), Dict{String,Any}()),
    ("negative_interface_sign", Dict("kind" => "multi_region_flux",
        "interface_flux_signs" => [1.0, 1.0]), Dict{String,Any}()),
    ("negative_physical_bound", Dict("kind" => "generic_graph_balance"),
        Dict{String,Any}("state_bindings" => Dict("electron_inventory" =>
            Dict("upper_bound" => 0.5)))),
    ("negative_dae_drift", Dict("kind" => "index1_dae",
        "declared_constraint_drift" => 1.0e-3,
        "constraint_drift_tolerance" => 1.0e-8), Dict{String,Any}()),
    ("negative_control_instability", Dict("kind" => "closed_loop_control",
        "controller_poles" => [-1.0, 0.2]), Dict{String,Any}()),
    ("negative_heat_rejection", Dict("kind" => "generic_graph_balance",
        "thermal_load" => 4.0, "heat_rejection_capacity" => 3.0),
        Dict{String,Any}())]
negative = Dict{String,Any}[]
for (id, model, extra) in negative_specs
    mode = id == "negative_dae_drift" ? "dae" : "steady"
    push!(negative, acceptance_record_v70(id, "0d", mode, model; extra = extra))
end

unsupported_features = ["high_index_dae", "nonlocal_operator",
    "missing_boundary_condition", "moving_grid", "missing_governing_residual",
    "missing_discretization", "missing_jacobian"]
unsupported = [acceptance_record_v70("unsupported_$feature", "1d", "steady",
    Dict("kind" => "generic_graph_balance");
    extra = Dict{String,Any}("unsupported_features" => [feature]))
    for feature in unsupported_features]

real_panel_specs = [
    ("lowest_cost_structure_a", Dict("missing_inputs" =>
        ["missing_boundary_heat_flux_operator"])),
    ("lowest_cost_structure_b", Dict("missing_inputs" =>
        ["unknown_actuator_efficiency_domain"])),
    ("reference_state_package_a_label_erased", Dict("missing_inputs" =>
        ["missing_ion_energy_initial_state"])),
    ("reference_state_package_b_label_erased", Dict("unsupported_features" =>
        ["unsupported_2d_anisotropic_transport"])),
    ("new_graph_native_candidate", Dict{String,Any}())]
real_panel = Dict{String,Any}[]
for (id, extra) in real_panel_specs
    push!(real_panel, acceptance_record_v70(id, "0d", "steady",
        Dict("kind" => "generic_graph_balance"); extra = extra))
end

# T6 deterministic checkpoint/recovery and cache replay acceptance.
resume_request = acceptance_request_v70("1d", "steady",
    Dict("kind" => "manufactured_diffusion", "dimension" => 1,
        "diffusion" => 1.0); samples = 4)
resume_plan = compile_stage3_execution_plan_v1(resume_request)
resume_dir = mktempdir()
checkpoint_path = joinpath(resume_dir, "checkpoint.json")
interrupted = execute_stage3_plan_v1(resume_plan, resume_request;
    checkpoint_path = checkpoint_path, interrupt_after_samples = 2)
resumed = execute_stage3_plan_v1(resume_plan, resume_request;
    checkpoint_path = checkpoint_path)
clean = execute_stage3_plan_v1(resume_plan, resume_request)
cache_dir = joinpath(resume_dir, "cache")
_, cache_first = execute_stage3_request_v1(resume_request; cache_directory = cache_dir)
_, cache_replay = execute_stage3_request_v1(resume_request; cache_directory = cache_dir)
recovery = Dict{String,Any}(
    "interrupted_classification" => interrupted.classification_code,
    "checkpoint_exists" => isfile(checkpoint_path),
    "resumed_evidence_hash" => resumed.evidence_hash,
    "clean_evidence_hash" => clean.evidence_hash,
    "resume_hash_match" => resumed.evidence_hash == clean.evidence_hash,
    "cache_first_hash" => cache_first.evidence_hash,
    "cache_replay_hash" => cache_replay.evidence_hash,
    "cache_hash_match" => cache_first.evidence_hash == cache_replay.evidence_hash,
    "cache_hit" => Bool(cache_replay.execution_cost_record["cache_hit"]))

scale = run_stage3_graph_numerical_loops_v70(10_000;
    complete_pass_target = 100,
    budget = Stage3ExecutionBudgetV1(maximum_wall_seconds = 20.0,
        maximum_degrees_of_freedom = 10_000, resolution_levels = [8, 16, 32]))

runtime_source = lowercase(read(joinpath(ROOT_V70, "src",
    "stage3_universal_runtime_v70.jl"), String))
auditor_source = lowercase(read(joinpath(ROOT_V70, "src",
    "stage3_independent_balance_auditor_v1.jl"), String))
source_audit = Dict{String,Any}(
    "family_equality_branch_count" => length(collect(eachmatch(r"family\s*==", runtime_source))),
    "device_type_equality_branch_count" => length(collect(eachmatch(
        r"device_type\s*==", runtime_source))),
    "main_solver_path_reference_in_independent_auditor" =>
        occursin("_stage3_solve_", auditor_source) || occursin("assemble_residual",
            auditor_source),
    "label_routing_used" => false)

positive_pass = all(item -> item["evidence"]["completeness"] == "complete" &&
    item["evidence"]["conclusion"] == "pass", positive)
negative_pass = all(item -> item["evidence"]["completeness"] == "complete" &&
    item["evidence"]["conclusion"] == "fail", negative)
unsupported_pass = all(item -> item["evidence"]["completeness"] == "incomplete" &&
    item["evidence"]["conclusion"] == "unsupported", unsupported)
scale_metrics = scale["metrics"]
admission = positive_pass && negative_pass && unsupported_pass &&
    recovery["resume_hash_match"] && recovery["cache_hash_match"] &&
    source_audit["family_equality_branch_count"] == 0 &&
    source_audit["device_type_equality_branch_count"] == 0 &&
    !source_audit["main_solver_path_reference_in_independent_auditor"] &&
    scale_metrics["raw_topology_count"] == 10_000 &&
    scale_metrics["uncaught_exception_count"] == 0 &&
    scale_metrics["stage3_complete_pass_structural_hash_count"] >= 100 &&
    scale_metrics["stage3_complete_pass_qd_cell_count"] > 1

result = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "version" => "v70",
    "positive_controls" => positive,
    "negative_controls" => negative,
    "unsupported_controls" => unsupported,
    "real_candidate_gap_panel" => real_panel,
    "recovery_and_cache" => recovery,
    "source_audit" => source_audit,
    "scale_acceptance" => scale,
    "formal_graph_loop_admission" => admission,
    "claim_boundary" => "Admission applies to the bounded Stage 3 reference capability registry and its manufactured/control matrix. It does not close missing candidate-bound fusion inputs or prove a physical device feasible.")
# Seal the exact JSON-normalized representation that will be persisted.  This
# avoids a write-time 0.0-to-0 normalization changing the recomputed hash.
result["result_hash"] = canonical_hash(JSON3.read(JSON3.write(result)))

run_path = joinpath(ROOT_V70, "runs", "stage3_universal_acceptance_v70_20260825.json")
mkpath(dirname(run_path))
open(run_path, "w") do io
    JSON3.pretty(io, result); write(io, '\n')
end

gap_lines = ["- `$(item["control_id"])`: `$(item["evidence"]["completeness"])/$(item["evidence"]["conclusion"])` — `$(item["evidence"]["classification_code"])`"
    for item in real_panel]
report = """# Stage 3 universal runtime v70 acceptance

- Result hash: `$(result["result_hash"])`
- Formal bounded graph-loop admission: **$(admission)**
- Positive controls: $(count(item -> item["evidence"]["conclusion"] == "pass", positive))/$(length(positive))
- Negative controls: $(count(item -> item["evidence"]["conclusion"] == "fail", negative))/$(length(negative))
- Unsupported controls: $(count(item -> item["evidence"]["conclusion"] == "unsupported", unsupported))/$(length(unsupported))
- Topologies run: $(scale_metrics["raw_topology_count"])
- Uncaught exceptions: $(scale_metrics["uncaught_exception_count"])
- Structurally distinct Stage 3 complete/pass: $(scale_metrics["stage3_complete_pass_structural_hash_count"])
- Complete/pass QD cells: $(scale_metrics["stage3_complete_pass_qd_cell_count"])
- Resume hash match: $(recovery["resume_hash_match"])
- Cache hash match: $(recovery["cache_hash_match"])
- Family/device equality routing branches: $(source_audit["family_equality_branch_count"])/$(source_audit["device_type_equality_branch_count"])

## Real-candidate gap panel

$(join(gap_lines, "\n"))

## Claim boundary

$(result["claim_boundary"])
"""
report_path = joinpath(ROOT_V70, "reports",
    "stage3_universal_acceptance_v70_20260825.md")
open(report_path, "w") do io
    write(io, report)
end

println(JSON3.write(Dict("run_path" => run_path, "report_path" => report_path,
    "result_hash" => result["result_hash"], "formal_graph_loop_admission" => admission,
    "scale_metrics" => scale_metrics)))
