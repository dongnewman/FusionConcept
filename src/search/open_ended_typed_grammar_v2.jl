function _search_interaction_v2(index::Int)
    return Dict{String,Any}(
        "interaction_id" => "generated_interaction_$index", "role_annotations" => Any["generated_balance_path"],
        "inputs" => Any["stored_energy"], "outputs" => Any["stored_energy"],
        "affected_domains" => Any["plasma_domain"],
        "operator_spec" => Dict("form" => "known_operator_ref", "ref" => "bounded_exchange_variant_$(mod(index, 4) + 1)"),
        "parameter_specs" => Any[Dict("name" => "rate", "value" => 0.1 + 0.01index, "unit" => "s^-1")],
        "assumptions" => Any["bounded_reduced_fixture"], "validity_claims" => Any[],
        "conservation_effects" => Any[Dict("account" => "energy", "source_reservoir" => "driver_reservoir",
            "sink_reservoir" => "plasma_reservoir")],
        "symmetry_claims" => Any[], "timescale_claims" => Any[], "observable_links" => Any["stored_energy_observable"],
        "epistemic_state" => "declared_known", "unknown_refs" => Any[], "promotion_scope_ref" => "method_c1_scope",
        "failure_scope_options" => Any["parameter_instance", "numerical_method"],
        "provenance" => Dict("source" => "open_ended_typed_grammar_v2"),
    )
end

"Deterministic typed mutations for interface and archive testing, not physics discovery claims."
function generate_open_world_candidates_v2(seed, count::Integer; generator_seed = 20260821)
    count > 0 || return Dict{String,Any}[]
    base = seed isa OpenWorldGenomeV2 ? seed.data : _plain_json(seed)
    candidates = Dict{String,Any}[]
    for index in 0:(count - 1)
        candidate = deepcopy(base)
        design_id = "open_world_pilot_$(lpad(index + 1, 5, '0'))"
        candidate["identity"]["design_id"] = design_id
        candidate["identity"]["revision_id"] = "$(design_id)_r1"
        candidate["identity"]["topology_skeleton_id"] = "topology_bits_$(string(index; base = 16))"
        candidate["identity"]["model_choice_id"] = "bounded_balance_models_v1"
        candidate["identity"]["parameter_instance_id"] = "parameters_$(index + 1)"
        candidate["identity"]["human_label"] = nothing
        candidate["classifications"] = Any[]
        pop!(candidate, "family", nothing)
        interactions = Any[deepcopy(candidate["interactions"][1])]
        for bit in 0:9
            ((index >> bit) & 1) == 1 && push!(interactions, _search_interaction_v2(bit + 1))
        end
        candidate["interactions"] = interactions
        candidate["search_metadata"] = Dict(
            "generator_id" => "open_ended_typed_grammar_v2", "version" => "1.0.0",
            "generator_seed" => generator_seed, "parent_ids" => Any[String(get(base["identity"], "design_id", "seed"))],
            "mutation_trace" => Any[Dict("operation" => "typed_interaction_bitset", "bitset" => index)],
            "archive_descriptor" => "C0_controlled_pilot", "pareto_dimensions" => Dict(
                "novelty" => count_ones(index), "evidence_cost" => 1.0 + 0.1count_ones(index)),
            "novelty_status" => "unassessed", "expected_information_gain" => 1.0 + 0.05count_ones(index),
            "estimated_evidence_cost" => 1.0 + 0.1count_ones(index),
            "minimum_tuning_budget" => 1.0, "tuning_budget_consumed" => 0.0,
            "neutrality_quota_class" => "family_free", "semantic_duplicate_risk" => 0.0,
        )
        push!(candidates, candidate)
    end
    return candidates
end

