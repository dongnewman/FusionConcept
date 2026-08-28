using FusionConceptAI
using JSON3

const FCA = FusionConceptAI

length(ARGS) >= 4 || error(
    "usage: run_v86_current_potential_inverse_frontier.jl P32_CAMPAIGN MERGED_JSONL RESULT_OUTPUT FOLLOWUP_CATALOG_OUTPUT [--active-indices=1,2] [--acquisition-turns=4] [--acquisition-steps=60] [--axis-refinements=4] [--maximum-iterations=1]")

read_json(path) = FCA._stage3_plain_v1(JSON3.read(
    read(abspath(path), String), Dict{String,Any}))

function option(name, default = nothing)
    prefix = "--$(name)="
    match = findfirst(value -> startswith(value, prefix), ARGS[5:end])
    return match === nothing ? default : split(ARGS[match + 4], "=";
        limit = 2)[2]
end

active_index_specification = option("active-indices")
acquisition_turns = parse(Int, option("acquisition-turns", "4"))
acquisition_steps = parse(Int, option("acquisition-steps", "60"))
axis_refinements = parse(Int, option("axis-refinements", "4"))
maximum_iterations = parse(Int, option("maximum-iterations", "1"))

function p32_metrics(row)
    gate = row["gate_chain"]["poincare_32"]
    evidence = get(gate, "evidence", Dict{String,Any}())
    poincare = get(evidence, "poincare_evidence", Dict{String,Any}())
    traces = get(poincare, "traces", Any[])
    completion = isempty(traces) ? 0.0 : minimum(min(1.0,
        Float64(get(trace, "toroidal_turns", 0.0)) / 32.0) for trace in traces)
    return (completion = completion,
        transform = Float64(get(poincare,
            "minimum_absolute_rotational_transform", 0.0)),
        ordering = Float64(get(poincare, "surface_ordering_fraction", 0.0)),
        classification_code = String(get(gate, "classification_code", "")))
end

campaign = read_json(ARGS[1])
rows = FCA._v84_read_valid_json_lines(abspath(ARGS[2]))
result_output = abspath(ARGS[3])
checkpoint_directory = result_output * ".checkpoints"
mkpath(checkpoint_directory)
prior_results = if isfile(result_output)
    get(read_json(result_output), "inverse_results", Any[])
else
    Any[]
end
prior_by_source = Dict(String(result["source_request_hash"]) => result for
    result in FCA._stage3_plain_v1.(collect(prior_results)))
request_hashes = Set(String(raw["request_hash"]) for raw in
    campaign["requests"])
eligible = [row for row in rows if String(row["request_hash"]) in
    request_hashes && String(row["scheduled_gate"]) == "poincare_32" &&
    String(row["route"]) == "closed/mixed" &&
    String(row["optimized_basis_override"]["winding_model"]) ==
        "winding_surface_current_potential_level_set_filaments_v7"]
isempty(eligible) && error("no candidate-bound v7 P32 rows were found")
sort!(eligible; by = row -> begin
    metrics = p32_metrics(row)
    (-metrics.completion, -metrics.transform, -metrics.ordering,
        String(row["request_hash"]))
end)
selected = Dict{String,Any}[]
seen_structures = Set{String}()
for row in eligible
    structure_hash = String(row["structure_hash"])
    structure_hash in seen_structures && continue
    push!(selected, row); push!(seen_structures, structure_hash)
    length(selected) == min(3, length(unique(String(item["structure_hash"])
        for item in eligible))) && break
end

raw_by_hash = Dict(String(raw["request_hash"]) => raw for raw in
    campaign["requests"])
results = Dict{String,Any}[]
selection = Dict{String,Any}[]
recovered_result_count = Ref(0)
fresh_result_count = Ref(0)
for row in selected
    source_hash = String(row["request_hash"])
    restored = FCA._v86_restore_request(raw_by_hash[source_hash])
    design = FCA._v86_joint_design_from_dict(row["optimized_design"],
        restored.grammar)
    override = FCA._stage3_plain_v1(row["optimized_basis_override"])
    coefficients = Float64.(override["current_potential_coefficients"])
    active_indices = active_index_specification === nothing ?
        collect(eachindex(coefficients)) : sort!(unique(parse.(Int,
            split(String(active_index_specification), ','))))
    inverse_request = compile_current_potential_inverse_request_v1(
        restored.request, design, override;
        active_coefficient_indices = active_indices,
        target_rotational_transform = 0.02,
        theta_count = 4, phi_count = 6,
        acquisition_toroidal_turns = acquisition_turns,
        acquisition_steps_per_turn = acquisition_steps,
        axis_locator_refinement_levels = axis_refinements,
        maximum_iterations = maximum_iterations,
        finite_difference_step = 0.015,
        trust_radius = 0.10,
        tikhonov_regularization = 0.05)
    checkpoint_path = joinpath(checkpoint_directory,
        source_hash * ".result.json")
    result = if isfile(checkpoint_path)
        recovered_result_count[] += 1
        read_json(checkpoint_path)
    elseif haskey(prior_by_source, source_hash)
        recovered_result_count[] += 1
        prior_by_source[source_hash]
    else
        fresh_result_count[] += 1
        run_current_potential_inverse_v1(inverse_request,
            restored.topology, restored.compilation, restored.grammar,
            design, override;
            base_coil_count = restored.request.base_coil_count)
    end
    String(result["inverse_request"]["request_hash"]) ==
        inverse_request.request_hash || error(
        "inverse checkpoint request hash mismatch for $source_hash")
    canonical_hash(result["optimized_basis_override"]) == String(result[
        "optimized_basis_override_hash"]) || error(
        "inverse checkpoint basis override hash mismatch for $source_hash")
    unhashed = deepcopy(result); delete!(unhashed, "result_hash")
    replay_hash = FCA._v86_inverse_serialized_hash(unhashed)
    if replay_hash != String(result["result_hash"])
        legacy_hash = String(result["result_hash"])
        result = deepcopy(result)
        result["legacy_in_memory_result_hash"] = legacy_hash
        result["hash_normalization"] = "json_roundtrip_canonical_v1"
        delete!(result, "result_hash")
        result["result_hash"] = FCA._v86_inverse_serialized_hash(result)
        unhashed = deepcopy(result); delete!(unhashed, "result_hash")
        FCA._v86_inverse_serialized_hash(unhashed) ==
            String(result["result_hash"]) || error(
            "inverse checkpoint normalized result hash mismatch for $source_hash")
    end
    FCA._stage3_atomic_json_v1(checkpoint_path, result)
    push!(results, result)
    metrics = p32_metrics(row)
    push!(selection, Dict{String,Any}(
        "request_hash" => source_hash,
        "structure_hash" => row["structure_hash"],
        "structure_seed" => row["structure_seed"],
        "p32_classification_code" => metrics.classification_code,
        "p32_completion_fraction" => metrics.completion,
        "p32_minimum_absolute_rotational_transform" => metrics.transform,
        "p32_surface_ordering_fraction" => metrics.ordering,
        "inverse_request_hash" => inverse_request.request_hash,
        "inverse_result_hash" => result["result_hash"]))
end

followup = compile_v86_inverse_initialized_campaign_v1(campaign, results)
artifact = Dict{String,Any}(
    "schema_version" => "1.0.0",
    "audit_kind" => "v86_current_potential_inverse_frontier_v1",
    "source_campaign_hash" => campaign["campaign_hash"],
    "selected_distinct_structure_count" => length(selected),
    "selection_policy" =>
        "closed_route_distinct_structure_hash_then_p32_completion_transform_ordering_v1",
    "selection" => selection,
    "inverse_configuration" => Dict{String,Any}(
        "active_coefficient_indices" =>
            (active_index_specification === nothing ? "all_declared" :
                parse.(Int, split(String(active_index_specification), ','))),
        "acquisition_toroidal_turns" => acquisition_turns,
        "acquisition_steps_per_turn" => acquisition_steps,
        "axis_locator_refinement_levels" => axis_refinements,
        "maximum_iterations" => maximum_iterations),
    "inverse_results" => results,
    "recovered_result_count" => recovered_result_count[],
    "fresh_result_count" => fresh_result_count[],
    "per_structure_atomic_checkpointing" => true,
    "followup_campaign_hash" => followup["campaign_hash"],
    "candidate_feasibility_credit" => false,
    "campaign_promotion_credit" => false,
    "retroactive_feasibility_credit" => false,
    "claim_boundary" => SURFACE_CURRENT_POTENTIAL_INVERSE_V86_CLAIM_BOUNDARY)
artifact["result_hash"] = FCA._v86_inverse_serialized_hash(artifact)
FCA._stage3_atomic_json_v1(result_output, artifact)
FCA._stage3_atomic_json_v1(abspath(ARGS[4]), followup)
println(JSON3.write(Dict{String,Any}(
    "status" => "complete",
    "selected_distinct_structure_count" => length(selected),
    "inverse_result_hash" => artifact["result_hash"],
    "followup_campaign_hash" => followup["campaign_hash"],
    "result_output" => abspath(ARGS[3]),
    "followup_catalog_output" => abspath(ARGS[4]))))
