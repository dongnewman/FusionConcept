const V92_PROTOCOL_ID = "fusionconceptai-v92-hifi-closure-20260828"
const V92_PROTOCOL_MANIFEST_FILES = (
    "campaign_manifest_v92.json",
    "capability_route_manifest_v92.json",
    "solver_independence_manifest_v92.json",
    "threshold_manifest_v92.json",
    "validation_dataset_split_v92.json",
)

function _v92_plain(value)
    value isa AbstractDict && return Dict{String,Any}(
        String(key) => _v92_plain(item) for (key, item) in pairs(value))
    value isa AbstractVector && return Any[_v92_plain(item) for item in value]
    return value
end

_v92_sha256_file(path::AbstractString) = bytes2hex(SHA.sha256(read(path)))

function _v92_json(path::AbstractString)
    isfile(path) || throw(ArgumentError("missing v92 protocol file: $(path)"))
    text = read(path, String)
    startswith(text, '\ufeff') && (text = chop(text; head = 1, tail = 0))
    return _v92_plain(JSON3.read(text))
end

function _v92_count_nonempty_lines(path::AbstractString)
    count = 0
    open(path, "r") do io
        for line in eachline(io)
            isempty(strip(line)) || (count += 1)
        end
    end
    return count
end

function verify_protocol_seal_v92(project_root::AbstractString;
        enforce_pre_result_state::Bool = false)
    root = abspath(project_root)
    config_root = joinpath(root, "config", "v92")
    seal_path = joinpath(config_root, "protocol_seal_v92.json")
    seal = _v92_json(seal_path)
    seal["protocol_id"] == V92_PROTOCOL_ID || throw(ArgumentError(
        "v92 protocol_id mismatch in seal"))
    declared_files = String.(seal["seal_material_order"])
    declared_files == collect(V92_PROTOCOL_MANIFEST_FILES) ||
        throw(ArgumentError("v92 seal material order mismatch"))
    declared_hashes = seal["manifest_hashes_sha256"]
    actual_hashes = Dict{String,String}()
    for filename in V92_PROTOCOL_MANIFEST_FILES
        path = joinpath(config_root, filename)
        actual = _v92_sha256_file(path)
        declared = lowercase(String(declared_hashes[filename]))
        actual == declared || throw(ArgumentError(
            "sealed v92 manifest changed: $(filename)"))
        manifest = _v92_json(path)
        manifest["protocol_id"] == V92_PROTOCOL_ID || throw(ArgumentError(
            "v92 protocol_id mismatch in $(filename)"))
        get(manifest, "mutable", true) == false || throw(ArgumentError(
            "sealed v92 manifest must declare mutable=false: $(filename)"))
        actual_hashes[filename] = actual
    end
    material = join(("$(name)=$(actual_hashes[name])" for name in
        V92_PROTOCOL_MANIFEST_FILES), "\n") * "\n"
    material_hash = bytes2hex(SHA.sha256(codeunits(material)))
    material_hash == lowercase(String(seal["seal_material_sha256"])) ||
        throw(ArgumentError("v92 protocol seal material hash mismatch"))

    campaign = _v92_json(joinpath(config_root,
        "campaign_manifest_v92.json"))
    input_audit = Dict{String,Any}[]
    for item_raw in campaign["inputs"]
        item = _v92_plain(item_raw)
        path = joinpath(root, split(String(item["path"]), '/')...)
        actual = _v92_sha256_file(path)
        expected = lowercase(String(item["sha256"]))
        actual == expected || throw(ArgumentError(
            "v92 campaign input hash mismatch: $(item["role"])"))
        count = String(item["role"]) == "v91_survivor_dossiers" ?
            _v92_count_nonempty_lines(path) : 1
        count == Int(item["expected_count"]) || throw(ArgumentError(
            "v92 campaign input count mismatch: $(item["role"])"))
        push!(input_audit, Dict{String,Any}(
            "role" => item["role"], "path" => item["path"],
            "sha256" => actual, "count" => count, "status" => "pass"))
    end

    result_root = joinpath(root, split(String(seal["v92_result_namespace"]),
        '/')...)
    result_files = isdir(result_root) ? [joinpath(directory, file) for
        (directory, _, files) in walkdir(result_root) for file in files if
        isfile(joinpath(directory, file))] : String[]
    if enforce_pre_result_state
        length(result_files) == Int(seal["high_fidelity_result_count_at_seal"]) ||
            throw(ArgumentError("v92 pre-result seal state no longer holds"))
    end
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "protocol_id" => V92_PROTOCOL_ID,
        "status" => "pass",
        "seal_material_sha256" => material_hash,
        "manifest_hashes_sha256" => actual_hashes,
        "input_audit" => input_audit,
        "result_file_count_now" => length(result_files),
        "pre_result_state_enforced" => enforce_pre_result_state,
        "claim_boundary" => "This verifies protocol and input immutability only; it grants no physical, numerical, or validation credit.")
end

function assert_protocol_sealed_v92(project_root::AbstractString)
    audit = verify_protocol_seal_v92(project_root)
    audit["status"] == "pass" || error("v92 protocol seal verification failed")
    return audit
end
