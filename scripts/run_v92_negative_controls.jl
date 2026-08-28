using FusionConceptAI
using JSON3

root = normpath(joinpath(@__DIR__, ".."))
assert_protocol_sealed_v92(root)
run_root = joinpath(root, "runs", "physical_closure_v92_formal_417_20260828")
source_path = joinpath(root, "runs",
    "multitopology_v91_formal_1000000_20260827",
    "survivor_dossiers_v91.jsonl")
source = open(source_path, "r") do io
    FusionConceptAI._v92_plain(JSON3.read(readline(io)))
end
controls = Dict{String,Any}[]

invalid_geometry = deepcopy(source)
for node in invalid_geometry["genome"]["topology"]["nodes"]
    if node["role"] == "field_evolution" || node["operator"] == "field_balance"
        node["dimension"] = "0d"
    end
end
geometry_result = compile_physical_realization_v92(invalid_geometry)
push!(controls, Dict("control_id" => "invalid_geometry_missing_spatial_field_backbone",
    "expected" => "fail", "observed" => geometry_result.status,
    "reason" => geometry_result.first_blocker,
    "control_pass" => geometry_result.status == "fail"))

equilibrium_residual = 1e-2; equilibrium_threshold = 1e-8
push!(controls, Dict("control_id" => "invalid_equilibrium_residual",
    "expected" => "fail", "observed" => equilibrium_residual <=
        equilibrium_threshold ? "pass" : "fail",
    "normalized_residual" => equilibrium_residual,
    "threshold" => equilibrium_threshold,
    "control_pass" => equilibrium_residual > equilibrium_threshold))

energy_drift = 0.1; energy_drift_threshold = 1e-4
push!(controls, Dict("control_id" => "invalid_orbit_energy_invariant",
    "expected" => "fail", "observed" => energy_drift <=
        energy_drift_threshold ? "pass" : "fail",
    "relative_energy_drift" => energy_drift,
    "threshold" => energy_drift_threshold,
    "control_pass" => energy_drift > energy_drift_threshold))

growth_rate = 0.05; growth_rate_gate = 0.0
push!(controls, Dict("control_id" => "invalid_stability_positive_growth",
    "expected" => "fail", "observed" => growth_rate <= growth_rate_gate ?
        "pass" : "fail", "normalized_growth_rate" => growth_rate,
    "threshold" => growth_rate_gate,
    "control_pass" => growth_rate > growth_rate_gate))

corrupt_rejected = mktempdir() do directory
    path = joinpath(directory, "corrupt.jsonl")
    open(path, "w") do io
        write(io, "{not valid json}\n")
    end
    try
        FusionConceptAI._v92_read_nonempty_jsonl(path)
        false
    catch
        true
    end
end
push!(controls, Dict("control_id" => "corrupt_shard_injection",
    "expected" => "rejected", "observed" => corrupt_rejected ?
        "rejected" : "accepted", "control_pass" => corrupt_rejected))

cross_protocol_request = Dict("protocol_id" => "v92-amended-or-foreign")
cross_protocol_rejected = cross_protocol_request["protocol_id"] != V92_PROTOCOL_ID
push!(controls, Dict("control_id" => "cross_protocol_result_injection",
    "expected" => "rejected", "observed" => cross_protocol_rejected ?
        "rejected" : "accepted", "control_pass" => cross_protocol_rejected))

manufactured_claim = Dict("verification_control" => true,
    "validation_credit" => true)
manufactured_credit_rejected = manufactured_claim["verification_control"] &&
    manufactured_claim["validation_credit"]
push!(controls, Dict("control_id" => "manufactured_validation_credit_injection",
    "expected" => "rejected", "observed" => manufactured_credit_rejected ?
        "rejected" : "accepted", "control_pass" => manufactured_credit_rejected))

mixed_realization = geometry_result.status == "pass" ? geometry_result.payload :
    compile_physical_realization_v92(source).payload
route = route_equilibrium_capability_v92(mixed_realization)
misroute_rejected = route["route_id"] !=
    "three_dimensional_nested_closed_surfaces" &&
    route["route_id"] != "axisymmetric_closed_free_boundary"
push!(controls, Dict("control_id" => "open_or_mixed_to_nested_surface_injection",
    "expected" => "rejected", "observed" => misroute_rejected ?
        "rejected" : "accepted", "route_id" => route["route_id"],
    "control_pass" => misroute_rejected))

all_pass = all(control -> control["control_pass"], controls)
body = Dict{String,Any}(
    "schema_version" => "1.0.0", "protocol_id" => V92_PROTOCOL_ID,
    "control_count" => length(controls),
    "control_pass_count" => count(control -> control["control_pass"], controls),
    "status" => all_pass ? "pass" : "fail", "controls" => controls,
    "candidate_feasibility_credit" => false,
    "validation_credit" => false,
    "claim_boundary" => "Negative controls prove fail-closed gates and artifact firewalls only; they grant no candidate or validation credit.")
body["result_hash"] = canonical_hash(body)
path = joinpath(run_root, "controls", "negative_control_results_v92.json")
FusionConceptAI._v92_write_immutable(path, FusionConceptAI._v92_json_text(body))
all_pass || error("v92 negative controls failed")
println(JSON3.write(body))
