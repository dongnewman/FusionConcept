function allocate_evidence_budget_v1(records; total_budget = 1200.0)
    ordered = sort!(deepcopy(collect(records)); by = item -> (
        -Float64(item["expected_information_gain"]) / max(Float64(item["estimated_evidence_cost"]), eps()),
        String(item["candidate_id"])))
    allocations = Dict{String,Any}[]
    remaining = Float64(total_budget)
    for record in ordered
        minimum = Float64(get(record, "minimum_tuning_budget", 0.0))
        granted = remaining >= minimum ? minimum : 0.0
        remaining -= granted
        push!(allocations, Dict(
            "candidate_id" => record["candidate_id"], "structural_hash" => record["structural_hash"],
            "minimum_tuning_budget" => minimum, "allocated_budget" => granted,
            "topology_failure_authorized" => granted >= minimum && minimum > 0,
            "priority_score" => Float64(record["expected_information_gain"]) /
                max(Float64(record["estimated_evidence_cost"]), eps()),
        ))
    end
    return Dict{String,Any}(
        "allocator_id" => "evidence_budget_allocator_v1", "total_budget" => Float64(total_budget),
        "allocated_budget" => Float64(total_budget) - remaining, "remaining_budget" => remaining,
        "allocations" => allocations,
        "policy" => "minimum_tuning_before_topology_failure_then_information_gain_per_cost",
    )
end

