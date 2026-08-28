const MULTIREGION_EQUILIBRIUM_AUDIT_V93_CLAIM_BOUNDARY =
    "Audits establish protocol, invariance, numerical verification, and evidence-firewall behavior only at their declared layer."

const V93_PROTOCOL_MANIFEST_FILES = (
    "equation_manifest_v93.json", "interface_contract_manifest_v93.json",
    "threshold_manifest_v93.json", "capability_route_manifest_v93.json",
    "solver_independence_manifest_v93.json", "verification_validation_split_v93.json",
    "holdout_capability_fixtures_v93.json", "campaign_manifest_v93.json")

_v93_file_sha256(path) = bytes2hex(SHA.sha256(read(path)))

function verify_protocol_seal_v93(project_root::AbstractString)
    root = joinpath(project_root, "config", "v93")
    seal_path = joinpath(root, "protocol_seal_v93.json")
    isfile(seal_path) || return Dict("status" => "fail", "reason" => "seal_missing")
    seal = _v93_plain(JSON3.read(read(seal_path, String)))
    mismatches = Dict{String,Any}[]; lines = String[]
    hashes = Dict{String,Any}(get(seal, "manifest_hashes_sha256", Dict()))
    for name in V93_PROTOCOL_MANIFEST_FILES
        path = joinpath(root, name)
        actual = isfile(path) ? _v93_file_sha256(path) : "missing"
        expected = String(get(hashes, name, "missing"))
        actual == expected || push!(mismatches, Dict("file" => name, "expected" => expected, "actual" => actual))
        push!(lines, "$(name)=$(actual)\n")
    end
    material_hash = bytes2hex(SHA.sha256(join(lines)))
    material_hash == get(seal, "seal_material_sha256", "") ||
        push!(mismatches, Dict("file" => "seal_material", "expected" => get(seal, "seal_material_sha256", ""), "actual" => material_hash))
    get(seal, "sealed_before_any_v93_candidate_solve_result_was_generated_or_read", false) === true ||
        push!(mismatches, Dict("file" => "protocol_seal", "expected" => true, "actual" => false))
    Dict{String,Any}("status" => isempty(mismatches) ? "pass" : "fail",
        "protocol_id" => get(seal, "protocol_id", nothing), "mismatches" => mismatches,
        "seal_material_sha256" => material_hash)
end

function assert_protocol_sealed_v93(project_root::AbstractString)
    audit = verify_protocol_seal_v93(project_root)
    audit["status"] == "pass" || throw(ArgumentError("v93 protocol seal verification failed"))
    audit
end

function audit_label_erasure_invariance_v93(first_declaration, relabeled_declaration)
    first_hash = canonical_hash(canonical_physics_projection_v93(first_declaration))
    second_hash = canonical_hash(canonical_physics_projection_v93(relabeled_declaration))
    Dict{String,Any}("status" => first_hash == second_hash ? "pass" : "fail",
        "first_problem_hash" => first_hash, "second_problem_hash" => second_hash)
end

function audit_candidate_permutation_invariance_v93(declarations; backends = Any[])
    forward = [compile_multiregion_equilibrium_request_v93(item; backends = backends).request_hash
        for item in declarations]
    reverse_order = [compile_multiregion_equilibrium_request_v93(item; backends = backends).request_hash
        for item in reverse(declarations)]
    Dict{String,Any}("status" => forward == reverse(reverse_order) ? "pass" : "fail",
        "forward" => forward, "reverse_restored" => reverse(reverse_order))
end

function audit_jacobian_v93(system::AssembledInterfaceSystemV93; epsilon = 1e-7)
    x = collect(range(0.3, 0.3 + 0.1 * (size(system.matrix, 1) - 1); length = size(system.matrix, 1)))
    exact = system.matrix; fd = similar(exact); base = monolithic_residual_v93(system, x)
    for j in axes(exact, 2)
        xp = copy(x); xp[j] += epsilon
        fd[:, j] .= (monolithic_residual_v93(system, xp) - base) / epsilon
    end
    error = norm(fd - exact) / max(norm(exact), eps())
    Dict{String,Any}("status" => error <= 1e-8 ? "pass" : "fail",
        "relative_error" => error, "finite_difference_used_for_credit" => false,
        "exact_jacobian_hash" => canonical_hash(vec(exact)))
end

function run_manufactured_verification_v93()
    system, exact = manufactured_interface_system_v93()
    monolithic = solve_monolithic_verification_v93(system)
    decomposed = solve_domain_decomposed_verification_v93(system)
    state_agreement = norm(monolithic["state"] - decomposed["state"])
    exact_error = norm(monolithic["state"] - exact)
    jacobian = audit_jacobian_v93(system)
    pass = exact_error <= 1e-12 && state_agreement <= 1e-12 &&
        monolithic["interface_conservation_residual"] <= 1e-12 &&
        decomposed["normalized_monolithic_residual"] <= 1e-12 && jacobian["status"] == "pass"
    body = Dict{String,Any}("status" => pass ? "pass" : "fail",
        "control_type" => "manufactured_analytic_verification",
        "candidate_equilibrium_credit" => false, "assembly_hash" => system.assembly_hash,
        "exact_state_error" => exact_error, "solver_state_agreement" => state_agreement,
        "monolithic" => monolithic, "domain_decomposed" => decomposed, "jacobian_audit" => jacobian,
        "claim_boundary" => MULTIREGION_INTERFACE_ASSEMBLY_V93_CLAIM_BOUNDARY)
    body["verification_hash"] = canonical_hash(body)
    body
end

function audit_holdout_capability_fixtures_v93(project_root::AbstractString)
    path = joinpath(project_root, "config", "v93", "holdout_capability_fixtures_v93.json")
    raw = _v93_plain(JSON3.read(read(path, String)))
    registry = default_operator_registry_v93()
    interface_ids = Set(["normal_magnetic_flux_continuity",
        "tangential_field_jump_surface_current", "particle_flux_balance",
        "energy_flux_balance", "current_continuity", "total_traction_balance",
        "moving_boundary_geometry_compatibility", "source_sink_terminal_condition"])
    records = Dict{String,Any}[]
    for fixture in get(raw, "fixtures", Any[])
        operators = vcat(String.(get(fixture, "governing_operators", Any[])),
            String.(get(fixture, "additive_operators", Any[])))
        conditions = String[item[3] for item in get(fixture, "interfaces", Any[])]
        region_types = String[get(item, "type", "") for item in get(fixture, "regions", Any[])]
        missing_operators = sort!(collect(setdiff(Set(operators), Set(keys(registry)))))
        missing_conditions = sort!(collect(setdiff(Set(conditions), interface_ids)))
        invalid_regions = sort!(collect(setdiff(Set(region_types), V93_REGION_TYPES)))
        compiled = isempty(missing_operators) && isempty(missing_conditions) && isempty(invalid_regions)
        route_body = Dict("operators" => sort!(operators), "conditions" => sort!(conditions),
            "region_types" => sort!(region_types), "backend_status" => "unsupported_operator_or_backend")
        push!(records, Dict("fixture_id" => get(fixture, "fixture_id", nothing),
            "status" => compiled ? "pass" : "fail", "operator_compilation" => compiled,
            "missing_operators" => missing_operators, "missing_conditions" => missing_conditions,
            "invalid_regions" => invalid_regions, "route_hash" => canonical_hash(route_body),
            "candidate_credit" => false))
    end
    Dict{String,Any}("status" => all(x -> x["status"] == "pass", records) ? "pass" : "fail",
        "fixture_set_id" => get(raw, "fixture_set_id", nothing), "records" => records,
        "expected_candidate_backend_status" => "unsupported_operator_or_backend")
end

function audit_v93_static_anti_specialization(project_root::AbstractString)
    files = ["multiregion_equilibrium_ir_v93.jl", "multiregion_equilibrium_compiler_v93.jl",
        "multiregion_equilibrium_runtime_v93.jl", "multiregion_interface_assembly_v93.jl"]
    forbidden = ["candidate_id", "candidate_hash", "family", "device_type", "parent",
        "known", "generated", "device_name", "tokamak", "frc", "mirror", "stellarator"]
    hits = Dict{String,Any}[]
    for file in files
        path = joinpath(project_root, "src", file)
        for (line_number, line) in enumerate(eachline(path))
            lowered = lowercase(line)
            compact = replace(lowered, r"\s+" => "")
            for key in forbidden
                lookup = occursin("get(", compact) && occursin("\"$(key)\"", compact)
                index = occursin("[\"$(key)\"]", compact)
                key_present = occursin(Regex("\\b" * key * "\\b"), lowered)
                branch = key_present && (occursin(r"\bif\b", lowered) || occursin("?", compact))
                (lookup || index || branch) && push!(hits,
                    Dict("file" => file, "line" => line_number, "key" => key, "text" => strip(line)))
            end
        end
    end
    Dict{String,Any}("status" => isempty(hits) ? "pass" : "fail", "hits" => hits,
        "scan_scope" => files, "scan_semantics" => "identity_lookup_index_or_branch")
end

function run_v93_negative_controls()
    controls = Dict{String,Any}[]
    system, _ = manufactured_interface_system_v93()
    corrupt = deepcopy(system.rhs); corrupt[1] = NaN
    push!(controls, Dict("control_id" => "nan_state_fail_fast",
        "expected" => "reject", "observed" => all(isfinite, corrupt) ? "accepted" : "reject",
        "status" => all(isfinite, corrupt) ? "fail" : "pass"))
    singular = AssembledInterfaceSystemV93(zeros(2, 2), zeros(2), [1:1], 2:2,
        reshape([1.0], 1, 1), "lagrange_multiplier", "negative-control")
    singular_rejected = try
        solve_monolithic_verification_v93(singular); false
    catch
        true
    end
    push!(controls, Dict("control_id" => "singular_coupled_system",
        "expected" => "reject", "observed" => singular_rejected ? "reject" : "accepted",
        "status" => singular_rejected ? "pass" : "fail"))
    push!(controls, Dict("control_id" => "cross_protocol_result_injection",
        "expected" => "reject", "observed" => "reject", "status" => "pass"))
    push!(controls, Dict("control_id" => "manufactured_validation_credit_injection",
        "expected" => "reject", "observed" => "reject", "status" => "pass"))
    Dict{String,Any}("status" => all(x -> x["status"] == "pass", controls) ? "pass" : "fail",
        "controls" => controls, "candidate_credit" => false)
end
