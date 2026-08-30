const V120_PROTOCOL_ID = "fusionconceptai-v120-equilibrium-profile-repair-20260830"

const EQUILIBRIUM_PROFILE_REPAIR_V120_CLAIM_BOUNDARY =
    "v120 adds explicit pressure/current shape exponents to the candidate genome and " *
    "requires FreeGS and DESC to consume the same declaration and volume-average state. " *
    "Profile coordinates receive no direct metric, stability, validation or credibility " *
    "credit. Every proposal must rerun equilibrium and all downstream gates."

const V120_PROFILE_VARIANTS = [(1, 1), (1, 3), (2, 1), (2, 2)]

function generate_equilibrium_profile_repairs_v120(parents_raw)
    parents = Dict{String,Any}.(_v93_plain.(parents_raw))
    proposals = Dict{String,Any}[]
    for parent in parents
        parent["candidate_state"] == "computational_candidate" || throw(ArgumentError(
            "v120 parents must be computational candidates"))
        parent["physics_solve"]["status"] == "pass" || throw(ArgumentError(
            "v120 parent physics must pass"))
        parent["engineering_prefilter"]["status"] == "pass" || throw(ArgumentError(
            "v120 parent engineering prefilter must pass"))
        for (variant, (alpha_m, alpha_n)) in enumerate(V120_PROFILE_VARIANTS)
            declaration = Dict{String,Any}(
                "schema_version" => "1.0.0", "protocol_id" => V120_PROTOCOL_ID,
                "alpha_m" => alpha_m, "alpha_n" => alpha_n,
                "freegs_shape_semantics" => "jtor_and_pprime_proportional_to_(1-psi^m)^n",
                "desc_pressure_coordinate_binding" => "psi_normalized_equals_rho_squared",
                "shared_thermodynamic_state" => "volume_average_pressure",
                "basis_direct_metric_credit" => false,
                "identity_fields_used_for_generation" => false)
            declaration["profile_declaration_hash"] = canonical_hash(declaration)
            body = deepcopy(parent)
            body["schema_version"] = "1.0.0"
            body["protocol_id"] = V120_PROTOCOL_ID
            body["parent_protocol_id"] = parent["protocol_id"]
            body["parent_request_index"] = parent["request_index"]
            body["parent_candidate_result_hash"] = parent["result_hash"]
            body["equilibrium_profile_parameters"] = declaration
            body["repair_declaration"] = Dict{String,Any}(
                "kind" => "candidate_bound_equilibrium_profile_shape_repair",
                "variant_index" => variant,
                "profile_declaration_hash" => declaration["profile_declaration_hash"],
                "rerun_required" => ["freegs", "desc", "downstream_provider_dag"],
                "prior_pass_credit" => false)
            # This identifier is a storage key derived from declared content. Providers
            # and selection never inspect it.
            body["request_index"] = parse(Int, parent["result_hash"][1:13]; base = 16) *
                10 + variant
            body["solver_input_hash"] = canonical_hash(Dict(
                "parent_solver_input_hash" => parent["solver_input_hash"],
                "equilibrium_profile_parameters" => declaration))
            body["candidate_state"] = "computational_candidate"
            body["physical_pass_credit"] = false
            body["validation_credit"] = false
            body["whole_device_credible"] = false
            body["identity_fields_used_for_routing"] = false
            body["basis_direct_metric_credit"] = false
            body["unsupported_candidate_classification_used"] = false
            body["claim_boundary"] = EQUILIBRIUM_PROFILE_REPAIR_V120_CLAIM_BOUNDARY
            pop!(body, "result_hash", nothing)
            body["result_hash"] = canonical_hash(body)
            push!(proposals, body)
        end
    end
    proposals
end

function select_equilibrium_profile_parents_v120(candidate_stream::AbstractString,
        freegs_results_directory::AbstractString; maximum_parents::Int = 6)
    maximum_parents > 0 || throw(ArgumentError("maximum_parents must be positive"))
    candidates = [Dict{String,Any}(_v93_plain(JSON3.read(line))) for line in
        readlines(candidate_stream) if !isempty(strip(line))]
    by_hash = Dict(String(item["result_hash"]) => item for item in candidates)
    eligible = Tuple{Float64,Float64,String,Dict{String,Any}}[]
    for path in sort!(filter(name -> startswith(basename(name), "freegs_") &&
            endswith(name, ".json"), readdir(freegs_results_directory; join = true)))
        result = Dict{String,Any}(_v93_plain(JSON3.read(read(path, String))))
        result["status"] == "pass" || continue
        candidate_hash = String(result["candidate_result_hash"])
        haskey(by_hash, candidate_hash) || throw(ArgumentError(
            "passing FreeGS artifact is detached from candidate stream"))
        fine = last(result["grid_records"])
        push!(eligible, (Float64(fine["toroidal_beta"]), Float64(fine["beta_n"]),
            candidate_hash, by_hash[candidate_hash]))
    end
    sort!(eligible; by = row -> (row[1], row[2], row[3]))
    [row[4] for row in first(eligible, min(maximum_parents, length(eligible)))]
end
