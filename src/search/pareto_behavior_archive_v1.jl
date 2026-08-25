function _open_world_pareto_dominates_v1(a, b)
    ainfo, binfo = Float64(a["expected_information_gain"]), Float64(b["expected_information_gain"])
    acost, bcost = Float64(a["estimated_evidence_cost"]), Float64(b["estimated_evidence_cost"])
    anovel, bnovel = Float64(a["novelty_descriptor"]), Float64(b["novelty_descriptor"])
    no_worse = ainfo >= binfo && acost <= bcost && anovel >= bnovel
    strictly = ainfo > binfo || acost < bcost || anovel > bnovel
    return no_worse && strictly
end

function build_pareto_behavior_archive_v1(compiled_candidates)
    unique_records = Dict{String,Any}()
    rejected = Dict{String,Int}("c0_not_pass" => 0, "semantic_duplicate" => 0)
    for item in compiled_candidates
        compilation = item["compilation"]
        compilation.assessments["C0"]["status"] == "pass" ||
            (rejected["c0_not_pass"] += 1; continue)
        semantic_key = String(get(item, "semantic_key", compilation.genome.structural_hash))
        if haskey(unique_records, semantic_key)
            rejected["semantic_duplicate"] += 1
            continue
        end
        metadata = get(compilation.genome.data, "search_metadata", Dict{String,Any}())
        unique_records[semantic_key] = Dict{String,Any}(
            "candidate_id" => compilation.genome.data["identity"]["design_id"],
            "structural_hash" => compilation.genome.structural_hash, "semantic_key" => semantic_key,
            "novelty_descriptor" => Float64(length(get(compilation.genome.data, "interactions", Any[]))),
            "expected_information_gain" => Float64(get(metadata, "expected_information_gain", 0.0)),
            "estimated_evidence_cost" => Float64(get(metadata, "estimated_evidence_cost", Inf)),
            "minimum_tuning_budget" => Float64(get(metadata, "minimum_tuning_budget", 0.0)),
            "c0_status" => "pass", "promotion_claim" => "none_from_archive",
        )
    end
    records = collect(values(unique_records))
    pareto = [record for record in records if !any(other -> other !== record &&
        _open_world_pareto_dominates_v1(other, record), records)]
    sort!(pareto; by = item -> String(item["candidate_id"]))
    return Dict{String,Any}(
        "archive_id" => "pareto_behavior_archive_v1", "unique_records" => records,
        "pareto_records" => pareto, "rejected" => rejected,
        "semantic_duplicate_rate" => isempty(compiled_candidates) ? 0.0 :
            rejected["semantic_duplicate"] / length(compiled_candidates),
        "replacement_policy" => "noncompensating_C0_then_Pareto_information_cost_novelty",
        "physics_winner_claimed" => false,
    )
end

function archive_stagnation_status_v1(insertion_counts; window = 5)
    counts = Int.(insertion_counts)
    stagnant = length(counts) >= window && sum(counts[(end - window + 1):end]) == 0
    return Dict("stagnant" => stagnant, "restart_recommended" => stagnant,
        "window" => window, "restart_policy" => "retain_ruleset_and_seed_new_neutrality_cell")
end
