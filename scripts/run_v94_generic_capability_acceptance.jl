using FusionConceptAI
using JSON3
using SHA

const ROOT_V94 = normpath(joinpath(@__DIR__, ".."))
const RUN_V94 = joinpath(ROOT_V94, "runs", "v94_generic_capability_acceptance")
const REPORT_V94 = joinpath(ROOT_V94, "reports", "v94_generic_capability_acceptance_20260828.md")

json_v94(value) = JSON3.write(value; allow_inf = false)

function immutable_write_v94(path, content)
    mkpath(dirname(path))
    if isfile(path)
        read(path, String) == content || error("immutable v94 artifact mismatch: $(path)")
        return
    end
    temporary = path * ".tmp-" * string(getpid())
    open(temporary, "w") do io
        write(io, content)
    end
    mv(temporary, path)
end

function acceptance_report_v94(acceptance)
    controls = acceptance["controls"]
    stage = controls["pvw_provider_chain"]
    preservation = controls["v93_preservation"]
    registry = acceptance["provider_registry"]
    numerical = stage["numerical_vvuq"]
    validation = stage["validation_vvuq"]
    """# FusionConceptAI v94 generic capability acceptance

## Acceptance result

- Software acceptance: **$(acceptance["software_acceptance"])**
- v93 preservation audit: **$(preservation["status"])** ($(preservation["v93_artifact_count"]) sealed-path files, $(preservation["v93_write_count"]) writes)
- Registered providers: **$(registry["provider_count"])**
- Provider anti-specialization audit: **$(controls["provider_anti_specialization"]["status"])**
- Field dependency closure control: **$(controls["field_dependency_closure"]["status"])**
- Label erasure: **$(controls["invariance"]["label_erasure"]["status"])**
- Identity/order permutation: **$(controls["invariance"]["identity_and_order_permutation"]["status"])**
- Unseen five-region topology: **$(controls["unseen_topology"]["status"])**
- Missing-provider and partial-closure negative controls: **$(controls["negative_controls"]["status"])**
- Strict stage order: **$(join(stage["stage_order"], " -> "))**

## Implemented closure

The registry routes one declared obligation at a time using state, operator, interface,
function-space, dimension, coordinate, and output capabilities. Provider callbacks receive
only a sanitized `CapabilityRequirementV94`; the graph or identity-bearing source record is
not passed into provider implementations. Routing therefore does not depend on identity,
hash, device-family metadata, or a fixed operator bundle.

The field planner preserves five separate classes: recovered, deterministically derived,
provider-computable, external evidence, and unsupported. It emits an explicit recomputation
DAG and does not convert absent external evidence into a computed value or a physical failure.

The graph residual/Jacobian assembler admits a solve only after every declared region,
equation row, interface condition, boundary condition, additional operator, and solve-required
field is closed. A missing interface provider and a missing additional-operator provider both
blocked the entire graph before execution; no solved subgraph received whole-system credit.

The former PVW slice is represented by separate registered providers for mixed radial flux
kinematics, radial source balance, axis regularity, essential flux trace, and mixed trace/jump
conditions. A five-region manufactured topology, not used by the PVW fixture, was assembled and
solved through the same per-obligation registry and graph assembler.

## VVUQ boundary

- Solve: **$(stage["solve"]["status"])**
- Numerical VVUQ: **$(numerical["status"])**; observed order $(numerical["observed_order"]), fine GCI $(numerical["gci_fine_percent"]) %
- Validation VVUQ: **$(validation["status"])**
- Experimental measurement datasets: **$(validation["actual_measurement_dataset_count"])**

The numerical result compares mesh levels and a separate domain-decomposition algorithm.
That is numerical verification, not experimental validation. Candidate-bound measurements
were not supplied, so validation remains `unknown_validation_domain`. Unsupported capability,
unknown validation, numerical verification, and experimental validation remain independent.
No device feasibility, engineering readiness, promotion, or expanded physical conclusion is claimed.

Acceptance hash: `$(acceptance["acceptance_hash"])`
"""
end

function main_v94()
    acceptance = run_generic_capability_acceptance_v94(ROOT_V94)
    acceptance["status"] == "pass" || error("v94 generic capability acceptance failed")
    report = acceptance_report_v94(acceptance)
    immutable_write_v94(joinpath(RUN_V94, "acceptance.json"), json_v94(acceptance) * "\n")
    immutable_write_v94(joinpath(RUN_V94, "acceptance_report.md"), report)
    immutable_write_v94(REPORT_V94, report)
    artifacts = [
        Dict("path" => "acceptance.json", "sha256" => bytes2hex(SHA.sha256(
            read(joinpath(RUN_V94, "acceptance.json"))))),
        Dict("path" => "acceptance_report.md", "sha256" => bytes2hex(SHA.sha256(
            read(joinpath(RUN_V94, "acceptance_report.md"))))) ]
    manifest = Dict{String,Any}("protocol_id" => V94_PROTOCOL_ID,
        "artifacts" => artifacts, "artifact_count" => length(artifacts))
    manifest["manifest_hash"] = canonical_hash(manifest)
    immutable_write_v94(joinpath(RUN_V94, "artifact_hashes.json"), json_v94(manifest) * "\n")
    println(json_v94(Dict("status" => acceptance["status"],
        "acceptance_hash" => acceptance["acceptance_hash"],
        "run_directory" => replace(relpath(RUN_V94, ROOT_V94), '\\' => '/'))))
    acceptance
end

main_v94()
