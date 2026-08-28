using FusionConceptAI
using JSON3

root = normpath(joinpath(@__DIR__, ".."))
run_root = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828")
acceptance_path = joinpath(run_root,
    "physical_closure_acceptance_v92_20260828.json")
manifest_path = joinpath(run_root, "artifact_hash_manifest_v92.json")
acceptance = FusionConceptAI._v92_json(acceptance_path)
manifest = FusionConceptAI._v92_json(manifest_path)
body = deepcopy(acceptance); declared_hash = pop!(body, "artifact_hash")
canonical_hash(body) == declared_hash || error("v92 acceptance hash mismatch")
manifest["acceptance_artifact_hash"] == declared_hash ||
    error("v92 acceptance/manifest link mismatch")
manifest_body = deepcopy(manifest); manifest_hash = pop!(manifest_body,
    "manifest_hash")
canonical_hash(manifest_body) == manifest_hash ||
    error("v92 artifact manifest hash mismatch")
for artifact in manifest["artifacts"]
    path = joinpath(root, split(String(artifact["path"]), '/')...)
    isfile(path) || error("missing v92 artifact: $(artifact["path"])")
    filesize(path) == Int(artifact["bytes"]) || error(
        "v92 artifact size mismatch: $(artifact["path"])")
    FusionConceptAI._v92_sha256_file(path) == artifact["sha256"] || error(
        "v92 artifact hash mismatch: $(artifact["path"])")
end
blockers = FusionConceptAI._v92_read_nonempty_jsonl(joinpath(run_root,
    "all_candidate_first_blockers_v92.jsonl"))
length(blockers) == acceptance["all_candidate_first_blocker_count"] == 417 ||
    error("v92 all-candidate blocker coverage mismatch")
sum(values(Dict{String,Any}(acceptance[
    "all_candidate_first_blocker_histogram"]))) == 417 ||
    error("v92 blocker histogram total mismatch")
acceptance["computationally_credible_new_device_count"] == 0 ||
    error("v92 computational credible count must be zero")
acceptance["experimentally_validated_new_fusion_device_count"] == 0 ||
    error("v92 experimental count must be zero")
acceptance["pilot_to_full_transition_allowed"] == false ||
    error("v92 pilot transition must remain blocked")
acceptance["full_qualification_scheduled_count"] == 0 ||
    error("v92 full qualification scheduling mismatch")
result = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "status" => "pass", "acceptance_hash" => declared_hash,
    "artifact_manifest_hash" => manifest_hash,
    "artifact_count" => manifest["artifact_count"],
    "verified_artifact_count" => length(manifest["artifacts"]),
    "all_candidate_first_blocker_count" => length(blockers),
    "computationally_credible_new_device_count" => 0,
    "experimentally_validated_new_fusion_device_count" => 0)
println(JSON3.write(result))
