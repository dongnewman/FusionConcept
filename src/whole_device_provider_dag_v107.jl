const V107_PROTOCOL_ID = "fusionconceptai-v107-whole-device-provider-dag-20260829"

const WHOLE_DEVICE_PROVIDER_DAG_V107_CLAIM_BOUNDARY =
    "v107 binds and executes every currently available candidate-bound provider in declared " *
    "order. Exact artifact binding and partial-stage pass do not close missing provider " *
    "fidelity, do not authorize high-cost expansion, and do not grant whole-device, " *
    "validation, or credibility credit. A preflight gap leaves the assembly " *
    "high_fidelity_pending, never unsupported, rejected, or promoted."

const V107_STAGE_ORDER = [
    "assembly_reduced_screen",
    "free_boundary_equilibrium",
    "cross_code_equilibrium",
    "sampled_local_ideal_mhd",
    "reduced_transport_and_confinement",
    "reduced_particle_and_heat_exhaust",
    "reduced_engineering_and_materials",
    "static_fault_response",
    "partial_numerical_vvuq",
    "whole_device_provider_preflight",
    "validation_vvuq",
]

function _v107_read_json(path)
    Dict{String,Any}(_v93_plain(JSON3.read(read(path, String))))
end

function _v107_find_artifact(root, directory, category, prefix, index)
    path = joinpath(root, "runs", directory, category, "results",
        "$(prefix)_$(index).json")
    isfile(path) || throw(ArgumentError("missing candidate-bound artifact: $path"))
    _v107_read_json(path)
end

function _v107_candidate_artifacts(root, candidate)
    index = Int(candidate["request_index"])
    result_hash = String(candidate["result_hash"])
    directories = (
        "v100_candidate_bound_design_refinement_20260829",
        "v100_candidate_bound_design_refinement_expanded_20260829",
    )
    for directory in directories
        freegs_path = joinpath(root, "runs", directory, "freegs_shared_radial_build",
            "results", "freegs_$(index).json")
        if !isfile(freegs_path)
            freegs_path = joinpath(root, "runs", directory, "freegs_low_beta_frontier",
                "results", "freegs_$(index).json")
        end
        isfile(freegs_path) || continue
        freegs = _v107_read_json(freegs_path)
        desc_category = isdir(joinpath(root, "runs", directory, "desc_cross_code")) ?
            "desc_cross_code" : "desc_low_beta_frontier"
        static_category = isdir(joinpath(root, "runs", directory, "static_robustness")) ?
            "static_robustness" : "static_robustness"
        desc = _v107_find_artifact(root, directory, desc_category, "v99", index)
        static = _v107_find_artifact(root, directory, static_category, "static", index)
        for (label, artifact) in (("FreeGS", freegs), ("DESC", desc), ("static", static))
            String(artifact["candidate_result_hash"]) == result_hash ||
                throw(ArgumentError("$label artifact candidate binding mismatch"))
        end
        return Dict{String,Any}(
            "freegs" => freegs, "desc" => desc, "static" => static,
            "artifact_directory" => directory)
    end
    throw(ArgumentError("no v100 provider artifacts for source candidate"))
end

function _v107_stage(stage_id, provider_key, status, evidence_level, result_hash;
        reason = nothing, complete_obligation = false)
    body = Dict{String,Any}(
        "stage_id" => String(stage_id), "provider_key" => String(provider_key),
        "status" => String(status), "evidence_level" => String(evidence_level),
        "result_hash" => result_hash, "reason" => reason,
        "complete_whole_device_obligation" => complete_obligation,
        "candidate_identity_used_for_routing" => false)
    body["stage_hash"] = canonical_hash(body)
    body
end

function execute_whole_device_provider_dag_v107(assembly_raw, screen_raw,
        source_candidate_raw, artifacts_raw)
    assembly = Dict{String,Any}(_v93_plain(assembly_raw))
    screen = Dict{String,Any}(_v93_plain(screen_raw))
    candidate = Dict{String,Any}(_v93_plain(source_candidate_raw))
    artifacts = Dict{String,Any}(_v93_plain(artifacts_raw))
    screen["status"] == "pass" || throw(ArgumentError(
        "v107 executes only v106 screen survivors"))
    screen["physical_design_hash"] == assembly["physical_design_hash"] ||
        throw(ArgumentError("assembly and v106 screen binding mismatch"))
    freegs = Dict{String,Any}(artifacts["freegs"])
    desc = Dict{String,Any}(artifacts["desc"])
    static = Dict{String,Any}(artifacts["static"])
    for (label, artifact) in (("FreeGS", freegs), ("DESC", desc), ("static", static))
        String(artifact["candidate_result_hash"]) == String(candidate["result_hash"]) ||
            throw(ArgumentError("$label artifact candidate binding mismatch"))
    end
    freegs_pass = freegs["status"] == "pass" &&
        freegs["numerical_vvuq"]["status"] == "pass"
    desc_pass = desc["candidate_state"] == "sampled_ideal_mhd_candidate" &&
        desc["cross_code_equilibrium"]["status"] == "pass"
    local_stability_pass = desc_pass && desc["desc_result"]["status"] == "pass" &&
        desc["desc_result"]["local_ideal_mhd"]["sampled_favorable"] === true
    static_pass = static["candidate_state"] == "static_robustness_proxy_pass" &&
        Int(static["case_pass_count"]) == Int(static["scenario_count"])
    reduced = Dict{String,Any}(candidate["physics_solve"])
    numerical = numerical_vvuq_candidate_v98(candidate["operating_point"],
        candidate["capability_profile"], reduced)
    preflight = compile_whole_device_preflight_v104(candidate["capability_profile"])
    stages = Dict{String,Any}[
        _v107_stage("assembly_reduced_screen", "whole_device_assembly_screen_v106",
            "pass", "reduced_candidate_bound", screen["result_hash"]),
        _v107_stage("free_boundary_equilibrium", "freegs_candidate_bound_v100",
            freegs_pass ? "pass" : "fail", "complete_candidate_bound",
            freegs["result_hash"]; complete_obligation = freegs_pass),
        _v107_stage("cross_code_equilibrium", "desc_cross_code_v100",
            desc_pass ? "pass" : "fail", "independent_validation", desc["result_hash"];
            complete_obligation = desc_pass),
        _v107_stage("sampled_local_ideal_mhd", "desc_sampled_local_ideal_mhd_v100",
            local_stability_pass ? "pass" : "fail", "sampled_candidate_bound",
            desc["desc_result"]["result_hash"];
            reason = "not_finite_n_resistive_kinetic_or_nonlinear"),
        _v107_stage("reduced_transport_and_confinement", "ipb98y2_zero_d_v98",
            reduced["status"], "reduced_candidate_bound", reduced["solve_hash"];
            reason = "not_spatial_species_resolved_transport"),
        _v107_stage("reduced_particle_and_heat_exhaust", "reduced_exhaust_area_v106",
            only(gate for gate in screen["gates"] if gate["gate_id"] ==
                "divertor_heat_flux")["status"], "reduced_candidate_bound",
            screen["result_hash"];
            reason = "not_scrape_off_layer_neutral_or_plasma_surface_interaction"),
        _v107_stage("reduced_engineering_and_materials", "assembly_engineering_v106",
            all(gate -> gate["status"] == "pass", [gate for gate in screen["gates"] if
                gate["gate_id"] in ("first_wall_thickness", "blanket_thickness",
                    "shield_thickness", "peak_field", "engineering_current_density",
                    "support_stress")]) ? "pass" : "fail",
            "sampled_candidate_bound", screen["result_hash"];
            reason = "not_material_curve_neutronics_damage_or_3d_component_qualification"),
        _v107_stage("static_fault_response", "static_pf_response_v100",
            static_pass ? "pass" : "fail", "sampled_candidate_bound",
            static["result_hash"];
            reason = "not_closed_loop_time_domain_fault_response"),
        _v107_stage("partial_numerical_vvuq", "v98_freegs_mesh_replay_uq",
            numerical["status"], "sampled_candidate_bound", numerical["vvuq_hash"];
            reason = "not_all_whole_device_providers"),
        _v107_stage("whole_device_provider_preflight", "whole_device_preflight_v104",
            preflight["status"] == "ready" ? "pass" : "not_ready", "none",
            preflight["preflight_hash"];
            reason = preflight["status"] == "ready" ? nothing :
                "complete_provider_fidelity_not_closed"),
        _v107_stage("validation_vvuq", "none",
            "not_executed_preflight_not_ready", "none", nothing;
            reason = "independent_candidate_bound_validation_provider_missing"),
    ]
    executed = [stage for stage in stages if !startswith(String(stage["status"]),
        "not_executed")]
    available_pass = all(stage -> stage["status"] in ("pass", "not_ready"), executed)
    complete_count = count(stage -> stage["complete_whole_device_obligation"] === true,
        stages)
    state = available_pass && preflight["status"] != "ready" ? "high_fidelity_pending" :
        available_pass ? "ready_for_complete_qualification" : "provider_stage_reject"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V107_PROTOCOL_ID,
        "physical_design_hash" => assembly["physical_design_hash"],
        "candidate_state" => state, "stage_order" => V107_STAGE_ORDER,
        "stages" => stages, "available_provider_stage_pass" => available_pass,
        "complete_obligation_count" => complete_count,
        "required_obligation_count" => preflight["required_obligation_count"],
        "whole_device_provider_preflight_status" => preflight["status"],
        "whole_device_pass_credit" => false, "validation_credit" => false,
        "unsupported_candidate_classification_used" => false,
        "partial_subgraph_promotion_allowed" => false,
        "identity_fields_used_for_routing" => false,
        "claim_boundary" => WHOLE_DEVICE_PROVIDER_DAG_V107_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body)
    body
end

function run_whole_device_provider_dag_v107(project_root::AbstractString)
    root = abspath(project_root)
    v106, screen_survivors = run_whole_device_assembly_screen_v106(root)
    generation, assemblies = run_whole_device_assembly_generation_v105(root)
    assembly_by_hash = Dict(String(item["physical_design_hash"]) => item for item in assemblies)
    candidates = _v104_load_v100_candidates(root)
    candidate_by_hash = Dict(String(item["result_hash"]) => item for item in values(candidates))
    artifact_cache = Dict{String,Any}()
    rows = Dict{String,Any}[]
    for screen in screen_survivors
        assembly = assembly_by_hash[String(screen["physical_design_hash"])]
        candidate = candidate_by_hash[String(assembly["source_candidate_result_hash"])]
        source_hash = String(candidate["result_hash"])
        artifacts = get!(artifact_cache, source_hash) do
            _v107_candidate_artifacts(root, candidate)
        end
        push!(rows, execute_whole_device_provider_dag_v107(assembly, screen,
            candidate, artifacts))
    end
    histogram = Dict{String,Int}()
    for row in rows
        state = String(row["candidate_state"])
        histogram[state] = get(histogram, state, 0) + 1
    end
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V107_PROTOCOL_ID,
        "status" => all(row -> row["available_provider_stage_pass"] === true, rows) ?
            "available_provider_dag_complete" : "provider_stage_failure",
        "source_v106_acceptance_hash" => v106["acceptance_hash"],
        "source_v105_acceptance_hash" => generation["acceptance_hash"],
        "input_survivor_count" => length(screen_survivors),
        "candidate_state_histogram" => Dict(sort!(collect(histogram))),
        "available_provider_dag_pass_count" => count(row ->
            row["available_provider_stage_pass"] === true, rows),
        "complete_whole_device_preflight_count" => count(row ->
            row["whole_device_provider_preflight_status"] == "ready", rows),
        "unsupported_candidate_count" => 0, "provider_system_failure_count" => 0,
        "whole_device_pass_count" => 0, "whole_device_credible_count" => 0,
        "validation_pass_count" => 0, "high_cost_expansion_authorized" => false,
        "identity_fields_used_for_routing" => false,
        "partial_subgraph_promotion_allowed" => false,
        "rows" => rows, "claim_boundary" => WHOLE_DEVICE_PROVIDER_DAG_V107_CLAIM_BOUNDARY)
    body["acceptance_hash"] = canonical_hash(body)
    body
end
