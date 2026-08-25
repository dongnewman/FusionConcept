function default_open_world_rule_coverage_v1(rules = default_open_world_physics_rules_v1())
    ruleset_hash = open_world_ruleset_hash_v1(rules)
    return Dict{String,Any}(
        "ruleset_id" => "open_world_minimal_rules_v1",
        "ruleset_hash" => ruleset_hash,
        "covered_domains" => Any["plasma", "vacuum", "material", "radiation", "circuit", "environment"],
        "covered_operator_classes" => Any["equation_set", "known_operator_ref", "program", "partial_operator"],
        "covered_scale_ranges" => Dict("mode" => "declaration_and_dimension_only"),
        "covered_boundary_classes" => Any["fixed", "moving", "deforming", "periodic_remap", "topology_event"],
        "covered_material_states" => Any["unspecified", "solid", "fluid", "plasma"],
        "partially_covered_regions" => Any["partial_operator", "event_system", "multi_domain_conservation"],
        "uncovered_regions" => Any["learned_operator", "full_3d_reactor_engineering", "unknown_operator_class"],
        "obligation_only_regions" => Any["partial_operator_identification", "novel_material_state", "solver_validation"],
        "known_rule_interactions" => Any["minimum_effect_size_vs_noise_floor", "promotion_scope_vs_ruleset_hash"],
        "known_blind_spots" => Any["unknown_fundamental_physics", "semantic_equivalence_proof", "complete_DAE_index_analysis"],
        "fixture_coverage" => Dict("public_positive" => 5, "public_negative" => 3, "blind" => 0),
    )
end

function validate_rule_coverage_manifest_v1(value)
    item = _plain_json(value)
    errors = String[]
    required = ["ruleset_id", "ruleset_hash", "covered_domains", "covered_operator_classes",
        "covered_scale_ranges", "covered_boundary_classes", "covered_material_states",
        "partially_covered_regions", "uncovered_regions", "obligation_only_regions",
        "known_rule_interactions", "known_blind_spots", "fixture_coverage"]
    for key in required
        haskey(item, key) || push!(errors, "RuleCoverageManifest missing $key")
    end
    return errors
end

function open_world_coverage_gaps_v1(genome::OpenWorldGenomeV2, coverage)
    data = genome.data
    covered_domains = Set(String.(get(coverage, "covered_domains", Any[])))
    covered_operators = Set(String.(get(coverage, "covered_operator_classes", Any[])))
    gaps = Dict{String,Any}[]
    for domain in get(data, "domains", Any[])
        kind = String(get(domain, "kind", "unknown"))
        kind in covered_domains || push!(gaps, Dict("subject_ref" => String(get(domain, "domain_id", "unknown_domain")),
            "region" => "domain:$kind", "reason" => "domain class is not covered"))
    end
    for interaction in get(data, "interactions", Any[])
        spec = get(interaction, "operator_spec", Dict{String,Any}())
        form = String(get(spec, "form", "unknown_operator_class"))
        form in covered_operators || push!(gaps, Dict("subject_ref" => String(get(interaction, "interaction_id", "unknown_interaction")),
            "region" => "operator:$form", "reason" => "operator class is not covered"))
    end
    return gaps
end

