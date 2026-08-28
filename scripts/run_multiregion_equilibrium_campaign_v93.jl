using FusionConceptAI
using JSON3
using SHA
using Dates

const PROJECT_ROOT_V93 = normpath(joinpath(@__DIR__, ".."))
const SOURCE_RUN_V93 = joinpath(PROJECT_ROOT_V93, "runs", "physical_closure_v92_formal_417_20260828")
const RUN_ROOT_V93 = joinpath(PROJECT_ROOT_V93, "runs", "multiregion_equilibrium_v93_formal_20260828")

plain_v93(x) = x isa JSON3.Object ? Dict{String,Any}(String(k) => plain_v93(v) for (k, v) in pairs(x)) :
    x isa JSON3.Array ? Any[plain_v93(v) for v in x] : x
json_v93(x) = JSON3.write(x; allow_inf = false)

function immutable_write_v93(path::AbstractString, content::AbstractString)
    mkpath(dirname(path))
    if isfile(path)
        read(path, String) == content || error("immutable artifact mismatch: $(path)")
        return path
    end
    temporary = path * ".tmp-" * string(getpid())
    open(temporary, "w") do io
        write(io, content)
    end
    mv(temporary, path)
    path
end

function json_artifact_v93(relative, value)
    immutable_write_v93(joinpath(RUN_ROOT_V93, relative), json_v93(value) * "\n")
end

function jsonl_artifact_v93(relative, values)
    immutable_write_v93(joinpath(RUN_ROOT_V93, relative),
        join((json_v93(value) for value in values), "\n") * "\n")
end

function histogram_v93(values)
    result = Dict{String,Int}()
    for value in values
        key = String(value); result[key] = get(result, key, 0) + 1
    end
    result
end

function verify_existing_campaign_v93()
    manifest_path = joinpath(RUN_ROOT_V93, "artifact_hash_manifest_v93.json")
    acceptance_path = joinpath(RUN_ROOT_V93, "multiregion_acceptance_v93.json")
    isfile(manifest_path) && isfile(acceptance_path) || return nothing
    manifest = plain_v93(JSON3.read(read(manifest_path, String)))
    mismatches = Dict{String,Any}[]
    for artifact in get(manifest, "artifacts", Any[])
        path = joinpath(RUN_ROOT_V93, split(String(artifact["path"]), '/')...)
        actual = isfile(path) ? bytes2hex(SHA.sha256(read(path))) : "missing"
        actual == artifact["sha256"] || push!(mismatches,
            Dict("path" => artifact["path"], "expected" => artifact["sha256"], "actual" => actual))
    end
    isempty(mismatches) || error("immutable v93 campaign artifact verification failed")
    acceptance = plain_v93(JSON3.read(read(acceptance_path, String)))
    println(json_v93(Dict("status" => acceptance["status"], "mode" => "verify_existing_immutable_campaign",
        "artifact_count" => manifest["artifact_count"], "acceptance_hash" => acceptance["acceptance_hash"],
        "run_root" => RUN_ROOT_V93)))
    acceptance
end

function main_v93()
    seal = assert_protocol_sealed_v93(PROJECT_ROOT_V93)
    existing = verify_existing_campaign_v93()
    existing === nothing || return existing
    selection = plain_v93(JSON3.read(read(joinpath(SOURCE_RUN_V93, "pilot_selection_v92.json"), String)))
    selected = get(selection, "selected", Any[])
    length(selected) == 229 || error("sealed v92 pilot selection count mismatch")
    dossiers_path = joinpath(SOURCE_RUN_V93, "realization_dossiers_v92.jsonl")
    realization_by_ref = Dict{String,Dict{String,Any}}()
    for line in eachline(dossiers_path)
        isempty(strip(line)) && continue
        record = Dict{String,Any}(plain_v93(JSON3.read(line)))
        realization_by_ref[String(record["candidate_hash"])] = record
    end

    controls = Dict{String,Any}(
        "protocol_seal" => seal,
        "manufactured_verification" => run_manufactured_verification_v93(),
        "negative_controls" => run_v93_negative_controls(),
        "holdout_capability" => audit_holdout_capability_fixtures_v93(PROJECT_ROOT_V93),
        "static_anti_specialization" => audit_v93_static_anti_specialization(PROJECT_ROOT_V93),
        "known_device_validation" => Dict("status" => "unknown_validation_domain",
            "reason" => "no_attested_actual_measurement_files_with_run_ids_diagnostics_calibration_uncertainty_boundaries_initial_conditions_and_hashes",
            "candidate_credit" => false))

    timed = @timed begin
        requests = MultiRegionEquilibriumRequestV93[]
        results = MultiRegionEquilibriumResultV93[]
        label_audits = Dict{String,Any}[]
        replay = Dict{String,Any}[]
        for (index, item) in enumerate(selected)
            source_ref = String(item["candidate_hash"])
            realization = realization_by_ref[source_ref]
            provenance = Dict{String,Any}("source_protocol_id" => String(realization["protocol_id"]),
                "source_campaign_id" => String(realization["campaign_id"]),
                "source_record_reference" => source_ref,
                "source_display_identifier" => get(item, "candidate_id", nothing),
                "pilot_selection_index" => index,
                "source_realization_hash" => String(realization["realization_hash"]))
            request = compile_v92_realization_request_v93(realization; source_provenance = provenance)
            result = execute_multiregion_equilibrium_request_v93(request)
            replay_request = compile_v92_realization_request_v93(deepcopy(realization);
                source_provenance = Dict("replay" => true))
            replay_result = execute_multiregion_equilibrium_request_v93(replay_request)
            push!(requests, request); push!(results, result)
            push!(replay, Dict("source_record_reference" => source_ref,
                "request_hash_match" => request.request_hash == replay_request.request_hash,
                "result_hash_match" => result.result_hash == replay_result.result_hash))
            relabeled = deepcopy(realization)
            relabeled["display_label"] = "erased-$(index)"
            relabeled["family"] = "randomized-$(229-index)"
            relabeled_request = compile_v92_realization_request_v93(relabeled;
                source_provenance = Dict("relabeled" => true))
            push!(label_audits, Dict("source_record_reference" => source_ref,
                "problem_hash_match" => request.problem_hash == relabeled_request.problem_hash,
                "route_hash_match" => request.route_hash == relabeled_request.route_hash,
                "request_hash_match" => request.request_hash == relabeled_request.request_hash))
        end
        (requests, results, label_audits, replay)
    end
    requests, results, label_audits, replay = timed.value
    request_dicts = multiregion_equilibrium_request_to_dict_v93.(requests)
    result_dicts = multiregion_equilibrium_result_to_dict_v93.(results)
    execution_logs = [Dict("request_hash" => requests[i].request_hash,
        "status" => results[i].status, "solver_executed" => results[i].solver_executed,
        "event" => "solver_not_started", "reason" => results[i].first_blocker)
        for i in eachindex(results)]
    pilot_dossiers = [Dict("source_provenance" => requests[i].source_provenance,
        "problem_hash" => requests[i].problem_hash, "route_hash" => requests[i].route_hash,
        "request_hash" => requests[i].request_hash, "result_hash" => results[i].result_hash,
        "status" => results[i].status, "first_blocker" => results[i].first_blocker,
        "translation_gaps" => requests[i].translation_gaps,
        "solver_executed" => results[i].solver_executed,
        "equilibrium_credit" => false) for i in eachindex(results)]

    jsonl_artifact_v93(joinpath("requests", "pilot_requests_v93.jsonl"), request_dicts)
    jsonl_artifact_v93(joinpath("results", "pilot_results_v93.jsonl"), result_dicts)
    jsonl_artifact_v93(joinpath("logs", "pilot_execution_log_v93.jsonl"), execution_logs)
    jsonl_artifact_v93("pilot_dossiers_v93.jsonl", pilot_dossiers)
    json_artifact_v93(joinpath("controls", "manufactured_verification_v93.json"), controls["manufactured_verification"])
    json_artifact_v93(joinpath("controls", "negative_controls_v93.json"), controls["negative_controls"])
    json_artifact_v93(joinpath("controls", "holdout_capability_v93.json"), controls["holdout_capability"])
    json_artifact_v93(joinpath("controls", "static_anti_specialization_v93.json"), controls["static_anti_specialization"])
    json_artifact_v93(joinpath("controls", "known_device_validation_v93.json"), controls["known_device_validation"])

    label_pass = all(x -> x["problem_hash_match"] && x["route_hash_match"] && x["request_hash_match"], label_audits)
    replay_pass = all(x -> x["request_hash_match"] && x["result_hash_match"], replay)
    reverse_hashes = reverse([compile_v92_realization_request_v93(realization_by_ref[String(item["candidate_hash"])]).request_hash
        for item in reverse(selected)])
    forward_hashes = [request.request_hash for request in requests]
    permutation_pass = forward_hashes == reverse_hashes
    json_artifact_v93("invariance_audit_v93.json", Dict("label_erasure_status" => label_pass ? "pass" : "fail",
        "candidate_permutation_status" => permutation_pass ? "pass" : "fail",
        "label_erasure_records" => label_audits))
    json_artifact_v93("replay_audit_v93.json", Dict("status" => replay_pass ? "pass" : "fail",
        "record_count" => length(replay), "records" => replay))

    statuses = [result.status for result in results]
    coverage = Dict{String,Any}("primary_capability" => "candidate_bound_multiregion_fem_snes_fieldsplit",
        "required_request_count" => 229, "supported_request_count" => count(==("pass"), statuses),
        "unsupported_request_count" => count(==("unsupported_operator_or_backend"), statuses),
        "solver_execution_count" => count(result -> result.solver_executed, results),
        "status" => all(==("pass"), statuses) ? "pass" : "fail",
        "missing_declaration_fields" => sort!(unique(vcat((request.translation_gaps for request in requests)...))))
    json_artifact_v93("capability_coverage_matrix_v93.json", coverage)
    json_artifact_v93("independent_cross_code_matrix_v93.json", Dict(
        "status" => "unsupported", "candidate_comparison_count" => 0,
        "reason" => "no_primary_candidate_equilibrium_and_no_independent_backend_model_intersection_execution",
        "independence_requirements" => ["codebase", "residual_or_model_lineage", "discretization",
            "mesh_generation", "input_transformer", "maintenance_organization"]))
    json_artifact_v93("mesh_partition_manifest_v93.json", Dict("status" => "unsupported",
        "v93_candidate_mesh_count" => 0, "v93_partition_count" => 0,
        "reason" => "candidate_bound_v93_discretization_not_compilable_from_v92_realization_records"))
    json_artifact_v93("checkpoint_restart_manifest_v93.json", Dict("status" => "not_executed",
        "checkpoint_count" => 0, "restart_count" => 0, "request_result_replay_status" => replay_pass ? "pass" : "fail",
        "reason" => "no_solver_execution"))
    json_artifact_v93("validation_vvuq_summary_v93.json", Dict("status" => "unknown_validation_domain",
        "candidate_dossier_count" => 0, "actual_measurement_dataset_count" => 0,
        "proxy_data_used" => false, "published_ranges_used_as_measurements" => false))
    resource = Dict("stage" => "v93_pilot_compile_route_and_unsupported_execution",
        "wall_seconds" => timed.time, "allocated_bytes" => timed.bytes,
        "gc_seconds" => timed.gctime, "threads" => Threads.nthreads(), "processes" => 1,
        "cpu_or_gpu_solver_execution_count" => 0)
    json_artifact_v93("per_stage_resource_usage_v93.json", resource)

    controls_pass = controls["manufactured_verification"]["status"] == "pass" &&
        controls["negative_controls"]["status"] == "pass" &&
        controls["holdout_capability"]["status"] == "pass" &&
        controls["static_anti_specialization"]["status"] == "pass"
    transition = coverage["status"] == "pass" && controls_pass && replay_pass && label_pass && permutation_pass &&
        controls["known_device_validation"]["status"] == "pass"
    acceptance_body = Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V93_PROTOCOL_ID,
        "campaign_id" => "multiregion_equilibrium_v93_formal_20260828",
        "status" => transition ? "pass" : "unsupported", "pilot_count" => length(results),
        "pilot_status_histogram" => histogram_v93(statuses),
        "pilot_to_full_transition_allowed" => transition,
        "full_campaign_executed" => false, "full_campaign_eligible_count" => 246,
        "downstream_orbit_stability_independent_vvuq_executed_count" => 0,
        "computationally_credible_new_device_count" => 0,
        "experimentally_validated_new_fusion_device_count" => 0,
        "first_campaign_blocker" => "solver_coverage_for_candidate_bound_multiregion_residual",
        "known_device_validation_status" => controls["known_device_validation"]["status"],
        "manufactured_verification_status" => controls["manufactured_verification"]["status"],
        "replay_status" => replay_pass ? "pass" : "fail",
        "label_erasure_status" => label_pass ? "pass" : "fail",
        "candidate_permutation_status" => permutation_pass ? "pass" : "fail",
        "claim_boundary" => "All 229 requests were compiled and capability-routed; unsupported is not numerical or physical failure and no equilibrium solver was executed.")
    acceptance_body["acceptance_hash"] = canonical_hash(acceptance_body)
    json_artifact_v93("multiregion_acceptance_v93.json", acceptance_body)
    farthest = first(sort!(copy(pilot_dossiers); by = item -> String(item["request_hash"])))
    json_artifact_v93("farthest_candidate_dossier_v93.json", merge(farthest, Dict(
        "farthest_reached_stage" => "candidate_declaration_compilation",
        "field_residual_convergence_orbit_stability_vvuq" => nothing,
        "reason" => "all_pilots_share_the_same_first_evidence_layer_blocker")))

    report = """# FusionConceptAI v93 multi-region equilibrium acceptance

- Protocol: `$(V93_PROTOCOL_ID)`
- Stage-0 seal: **$(seal["status"])**
- Manufactured monolithic/domain-decomposed verification: **$(controls["manufactured_verification"]["status"])** (verification only)
- Sealed unseen capability fixtures: **$(controls["holdout_capability"]["status"])** (compilation/routing only)
- Pilot requests: **$(length(results))**
- Pilot outcomes: **$(histogram_v93(statuses))**
- Candidate solver executions: **$(count(result -> result.solver_executed, results))**
- Pilot-to-full transition: **$(transition ? "allowed" : "blocked")**
- 246-candidate full campaign executed: **no**
- First blocker: `solver_coverage_for_candidate_bound_multiregion_residual`
- Known-device validation: `unknown_validation_domain`
- Computationally credible new concepts: **0**
- Experimentally validated new concepts: **0**

The v92 realization records describe geometry, profiles, capability obligations, and interface condition labels, but do not bind every state to a discrete space and region, do not declare exactly one governing residual per equation with validity metadata, and do not bind source-node interfaces to explicit v93 region endpoints and multiplier spaces. v93 therefore does not project these requests onto a reduced or easier model. Every pilot remains `unsupported_operator_or_backend`; this is not a claim that equilibrium does not exist and not a numerical convergence failure.

Manufactured verification checks the native Lagrange-multiplier assembly, monolithic solve, Schur domain decomposition, exact Jacobian, conservation residual, and final monolithic reaudit. It grants no candidate physical or validation credit. No proxy data or published range was used as measurement evidence.
"""
    immutable_write_v93(joinpath(PROJECT_ROOT_V93, "reports", "multiregion_equilibrium_acceptance_v93_20260828.md"), report)

    artifact_records = Dict{String,Any}[]
    for (directory, _, files) in walkdir(RUN_ROOT_V93)
        for file in files
            file == "artifact_hash_manifest_v93.json" && continue
            path = joinpath(directory, file)
            push!(artifact_records, Dict("path" => replace(relpath(path, RUN_ROOT_V93), '\\' => '/'),
                "bytes" => filesize(path), "sha256" => bytes2hex(SHA.sha256(read(path)))))
        end
    end
    sort!(artifact_records; by = item -> item["path"])
    manifest = Dict{String,Any}("schema_version" => "1.0.0", "protocol_id" => V93_PROTOCOL_ID,
        "campaign_id" => "multiregion_equilibrium_v93_formal_20260828",
        "artifact_count" => length(artifact_records), "artifacts" => artifact_records)
    manifest["manifest_hash"] = canonical_hash(manifest)
    json_artifact_v93("artifact_hash_manifest_v93.json", manifest)
    println(json_v93(Dict("status" => acceptance_body["status"], "pilot_count" => length(results),
        "solver_execution_count" => coverage["solver_execution_count"], "transition" => transition,
        "acceptance_hash" => acceptance_body["acceptance_hash"], "run_root" => RUN_ROOT_V93)))
end

main_v93()
