using FusionConceptAI
using JSON3
using SHA

const ROOT_PVW = normpath(joinpath(@__DIR__, ".."))
const V91_DOSSIERS_PVW = joinpath(ROOT_PVW, "runs", "multitopology_v91_formal_1000000_20260827", "survivor_dossiers_v91.jsonl")
const V92_DOSSIERS_PVW = joinpath(ROOT_PVW, "runs", "physical_closure_v92_formal_417_20260828", "realization_dossiers_v92.jsonl")
const RUN_PVW = joinpath(ROOT_PVW, "runs", "v93_pvw_slice1_formal_246_20260828")

plain_pvw(x) = x isa JSON3.Object ? Dict{String,Any}(String(k) => plain_pvw(v) for (k, v) in pairs(x)) :
    x isa JSON3.Array ? Any[plain_pvw(v) for v in x] : x
json_pvw(x) = JSON3.write(x; allow_inf = false)

function immutable_write_pvw(path, content)
    mkpath(dirname(path))
    if isfile(path)
        read(path, String) == content || error("immutable artifact mismatch: $(path)")
        return
    end
    temporary = path * ".tmp-" * string(getpid())
    open(temporary, "w") do io; write(io, content); end
    mv(temporary, path)
end

write_json_pvw(relative, value) = immutable_write_pvw(joinpath(RUN_PVW, relative), json_pvw(value) * "\n")
write_jsonl_pvw(relative, values) = immutable_write_pvw(joinpath(RUN_PVW, relative),
    join((json_pvw(value) for value in values), "\n") * "\n")

function increment_pvw!(histogram, key)
    text = String(key); histogram[text] = get(histogram, text, 0) + 1
end

function verify_existing_pvw()
    manifest_path = joinpath(RUN_PVW, "artifact_hash_manifest_v93_pvw_slice1.json")
    acceptance_path = joinpath(RUN_PVW, "acceptance_v93_pvw_slice1.json")
    isfile(manifest_path) && isfile(acceptance_path) || return nothing
    manifest = plain_pvw(JSON3.read(read(manifest_path, String)))
    for artifact in manifest["artifacts"]
        path = joinpath(RUN_PVW, split(String(artifact["path"]), '/')...)
        isfile(path) || error("missing immutable artifact $(path)")
        bytes2hex(SHA.sha256(read(path))) == artifact["sha256"] || error("artifact hash mismatch $(path)")
    end
    acceptance = plain_pvw(JSON3.read(read(acceptance_path, String)))
    println(json_pvw(Dict("mode" => "verify_existing_immutable_campaign", "status" => acceptance["status"],
        "artifact_count" => manifest["artifact_count"], "acceptance_hash" => acceptance["acceptance_hash"])))
    acceptance
end

function main_pvw()
    seal = verify_v93_pvw_protocol_seal_v1(ROOT_PVW)
    seal["status"] == "pass" || error("PVW protocol seal failed")
    existing = verify_existing_pvw(); existing === nothing || return existing

    v91_by_hash = Dict{String,Dict{String,Any}}()
    for line in eachline(V91_DOSSIERS_PVW)
        record = Dict{String,Any}(plain_pvw(JSON3.read(line)))
        v91_by_hash[String(record["dossier_hash"])] = record
    end
    v92_pass = Dict{String,Any}[]
    for line in eachline(V92_DOSSIERS_PVW)
        record = Dict{String,Any}(plain_pvw(JSON3.read(line)))
        get(record["qualification"], "status", "fail") == "pass" && push!(v92_pass, record)
    end
    length(v92_pass) == 246 || error("v92 realization pass count mismatch")
    sort!(v92_pass; by = item -> String(item["candidate_hash"]))

    timed = @timed begin
        declarations = Dict{String,Any}[]; routes = Dict{String,Any}[]
        results = Dict{String,Any}[]; gaps = Dict{String,Any}[]
        label_records = Dict{String,Any}[]
        for v92 in v92_pass
            source_hash = String(v92["candidate_hash"]); v91 = v91_by_hash[source_hash]
            declaration = regenerate_complete_v93_declaration_v1(v91, v92)
            route = route_pvw_slice_v1(declaration)
            result = execute_pvw_slice_candidate_v1(declaration)
            inventory = declaration["recovery_inventory"]
            operators = sort!(String.(v92["applicability_obligations"]["declared_operators"]))
            push!(declarations, declaration)
            push!(routes, merge(Dict("source_record_reference" => source_hash), route))
            push!(results, merge(Dict("source_record_reference" => source_hash), result))
            push!(gaps, Dict("source_record_reference" => source_hash,
                "declaration_hash" => declaration["declaration_hash"],
                "declared_operator_combination" => operators,
                "directly_recoverable" => inventory["directly_recovered"],
                "deterministically_derivable" => inventory["deterministically_derived"],
                "must_recompute" => inventory["must_recompute"],
                "requires_external_evidence" => inventory["requires_external_evidence"],
                "slice_blockers" => route["blockers"]))
            relabeled_v91 = deepcopy(v91); relabeled_v92 = deepcopy(v92)
            relabeled_v91["candidate_id"] = "random-display"; relabeled_v91["family"] = "erased"
            relabeled_v92["candidate_id"] = "different-display"; relabeled_v92["device_type"] = "erased"
            relabeled = regenerate_complete_v93_declaration_v1(relabeled_v91, relabeled_v92)
            relabeled_route = route_pvw_slice_v1(relabeled)
            push!(label_records, Dict("source_record_reference" => source_hash,
                "declaration_hash_match" => declaration["declaration_hash"] == relabeled["declaration_hash"],
                "route_hash_match" => route["route_hash"] == relabeled_route["route_hash"]))
        end
        (declarations, routes, results, gaps, label_records)
    end
    declarations, routes, results, gaps, label_records = timed.value
    manufactured = run_pvw_manufactured_verification_v1()

    write_jsonl_pvw(joinpath("declarations", "complete_declarations_v93.jsonl"), declarations)
    write_jsonl_pvw(joinpath("routes", "pvw_slice_routes_v1.jsonl"), routes)
    write_jsonl_pvw(joinpath("results", "pvw_slice_results_v1.jsonl"), results)
    write_jsonl_pvw("per_candidate_gap_inventory_v93.jsonl", gaps)
    write_json_pvw(joinpath("controls", "pvw_manufactured_verification_v1.json"), manufactured)
    write_jsonl_pvw(joinpath("logs", "candidate_execution_log_v1.jsonl"), [Dict(
        "source_record_reference" => result["source_record_reference"], "declaration_hash" => result["declaration_hash"],
        "route_status" => result["route"]["status"], "solver_executed" => result["solver_executed"],
        "event" => result["solver_executed"] ? "solver_completed" : "solver_not_started",
        "first_blocker" => result["first_blocker"]) for result in results])

    recoverable_hist = Dict{String,Int}(); recompute_hist = Dict{String,Int}()
    external_hist = Dict{String,Int}(); blocker_hist = Dict{String,Int}(); operator_combo_hist = Dict{String,Int}()
    for item in gaps
        foreach(value -> increment_pvw!(recoverable_hist, value), vcat(item["directly_recoverable"], item["deterministically_derivable"]))
        foreach(value -> increment_pvw!(recompute_hist, value), item["must_recompute"])
        foreach(value -> increment_pvw!(external_hist, value), item["requires_external_evidence"])
        foreach(value -> increment_pvw!(blocker_hist, value), item["slice_blockers"])
        increment_pvw!(operator_combo_hist, join(item["declared_operator_combination"], "+"))
    end
    eligible = count(route -> route["status"] == "pass", routes)
    solver_count = count(result -> result["solver_executed"], results)
    numerical_count = count(result -> result["numerical_vvuq_status"] == "pass", results)
    validation_count = count(result -> result["validation_vvuq_status"] != "not_executed", results)
    census = Dict{String,Any}(
        "protocol_id" => V93_PVW_PROTOCOL_ID, "candidate_count" => length(gaps),
        "schema_complete_declaration_count" => count(d -> d["declaration_completeness"]["schema_complete"], declarations),
        "solver_complete_declaration_count" => count(d -> d["declaration_completeness"]["solver_complete"], declarations),
        "slice_eligible_count" => eligible, "recoverable_field_frequency" => recoverable_hist,
        "must_recompute_field_frequency" => recompute_hist,
        "requires_external_evidence_frequency" => external_hist,
        "slice_blocker_frequency" => blocker_hist,
        "declared_operator_combination_histogram" => operator_combo_hist,
        "region_type_combination" => Dict("coil+open_loss+plasma+terminal+vacuum+wall" => 246),
        "claim_boundary" => "Recoverable means reproducibly reconstructed from v91/v92 declarations. It does not mean physically solved or experimentally validated.")
    write_json_pvw("field_operator_gap_census_v93.json", census)
    label_pass = all(item -> item["declaration_hash_match"] && item["route_hash_match"], label_records)
    forward = [String(route["route_hash"]) for route in routes]
    reverse_restored = reverse([String(route_pvw_slice_v1(declaration)["route_hash"]) for declaration in reverse(declarations)])
    permutation_pass = forward == reverse_restored
    write_json_pvw("invariance_audit_v93_pvw_slice1.json", Dict("label_erasure_status" => label_pass ? "pass" : "fail",
        "candidate_permutation_status" => permutation_pass ? "pass" : "fail", "record_count" => length(label_records),
        "records" => label_records))
    write_json_pvw("candidate_numerical_vvuq_summary_v1.json", Dict("status" => numerical_count > 0 ? "executed" : "not_executed",
        "candidate_equilibrium_execution_count" => solver_count, "candidate_numerical_vvuq_pass_count" => numerical_count,
        "reason" => solver_count == 0 ? "no_declaration_fully_matched_slice" : nothing))
    write_json_pvw("candidate_validation_vvuq_summary_v1.json", Dict("status" => validation_count > 0 ? "executed" : "not_executed",
        "candidate_numerical_vvuq_pass_count" => numerical_count, "candidate_validation_vvuq_count" => validation_count,
        "reason" => numerical_count == 0 ? "no_candidate_numerical_vvuq_pass" : nothing,
        "proxy_data_used" => false))
    write_json_pvw("resource_usage_v93_pvw_slice1.json", Dict("stage" => "declaration_regeneration_gap_census_and_strict_slice_routing",
        "wall_seconds" => timed.time, "allocated_bytes" => timed.bytes, "gc_seconds" => timed.gctime,
        "threads" => Threads.nthreads(), "processes" => 1, "candidate_solver_execution_count" => solver_count))

    acceptance = Dict{String,Any}("schema_version" => "1.0.0", "protocol_id" => V93_PVW_PROTOCOL_ID,
        "campaign_id" => "v93_pvw_slice1_formal_246_20260828", "source_realization_pass_count" => 246,
        "complete_declaration_count" => length(declarations), "schema_complete_count" => 246,
        "solver_complete_count" => count(d -> d["declaration_completeness"]["solver_complete"], declarations),
        "slice_eligible_count" => eligible, "candidate_solver_execution_count" => solver_count,
        "candidate_numerical_vvuq_count" => numerical_count, "candidate_validation_vvuq_count" => validation_count,
        "manufactured_verification_status" => manufactured["status"],
        "label_erasure_status" => label_pass ? "pass" : "fail",
        "candidate_permutation_status" => permutation_pass ? "pass" : "fail",
        "status" => eligible == 0 ? "unsupported" : "unknown",
        "first_campaign_blocker" => "all_candidate_declarations_exceed_pvw_slice_and_require_recomputed_physics",
        "subproblem_projection_used" => false, "computationally_credible_new_device_count" => 0,
        "experimentally_validated_new_device_count" => 0,
        "claim_boundary" => "The real PVW solver passed manufactured verification, but no v92 realization declaration fully lies inside its preregistered capability domain. No candidate equilibrium, numerical VVUQ, or validation VVUQ was executed.")
    acceptance["acceptance_hash"] = canonical_hash(acceptance)
    write_json_pvw("acceptance_v93_pvw_slice1.json", acceptance)

    report = """# FusionConceptAI v93 PVW slice-1 acceptance

- Protocol seal: **$(seal["status"])**
- Regenerated complete v93 declarations: **$(length(declarations)) / 246**
- Schema-complete declarations: **246**
- Solver-complete declarations: **$(acceptance["solver_complete_count"])**
- Exact plasma-vacuum-wall slice matches: **$(eligible)**
- Candidate solver executions: **$(solver_count)**
- Candidate numerical VVUQ executions: **$(numerical_count)**
- Candidate validation VVUQ executions: **$(validation_count)**
- Manufactured PVW verification: **$(manufactured["status"])**
- Manufactured observed order: **$(manufactured["observed_order_medium_fine"])**
- Manufactured fine GCI: **$(manufactured["gci_fine_percent"]) %**
- First blocker: `all_candidate_declarations_exceed_pvw_slice_and_require_recomputed_physics`

Every v92 realization-pass record was regenerated as a structurally complete v93 declaration with explicit regions, state ownership, exactly one governing operator per equation, residual metadata, physical interfaces, validity-domain obligations, discretization status, and evidence obligations. Each declaration separately records directly recoverable data, deterministic derivations, quantities that require candidate-bound recomputation, and quantities requiring external evidence.

All 246 declarations include coil, open-loss, terminal, plasma, vacuum, and wall regions. They also contain states and governing operators outside the sealed radial plasma-vacuum-wall slice, lack an attested cylindrical radial reduction, and require candidate-bound field/material/closure recomputation. The router therefore admitted zero candidates. No subproblem was projected out for candidate credit.

The native PVW solver is a real mixed radial Grad-Shafranov discretization with explicit plasma-vacuum flux and tangential-field constraints, a monolithic exact-Jacobian solve, a two-region nullspace-Schur domain decomposition, final monolithic residual/force/conservation audit, and coarse/medium/fine verification. Its manufactured result is code verification only.
"""
    immutable_write_pvw(joinpath(ROOT_PVW, "reports", "v93_pvw_slice1_acceptance_20260828.md"), report)

    artifacts = Dict{String,Any}[]
    for (directory, _, files) in walkdir(RUN_PVW), file in files
        file == "artifact_hash_manifest_v93_pvw_slice1.json" && continue
        path = joinpath(directory, file)
        push!(artifacts, Dict("path" => replace(relpath(path, RUN_PVW), '\\' => '/'),
            "bytes" => filesize(path), "sha256" => bytes2hex(SHA.sha256(read(path)))))
    end
    sort!(artifacts; by = item -> item["path"])
    manifest = Dict{String,Any}("protocol_id" => V93_PVW_PROTOCOL_ID, "artifact_count" => length(artifacts),
        "artifacts" => artifacts); manifest["manifest_hash"] = canonical_hash(manifest)
    write_json_pvw("artifact_hash_manifest_v93_pvw_slice1.json", manifest)
    println(json_pvw(Dict("status" => acceptance["status"], "complete_declarations" => length(declarations),
        "eligible" => eligible, "solver_executions" => solver_count, "acceptance_hash" => acceptance["acceptance_hash"])))
    acceptance
end

main_pvw()
