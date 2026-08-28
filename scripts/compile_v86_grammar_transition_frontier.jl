using FusionConceptAI
using JSON3

length(ARGS) == 3 || error(
    "usage: compile_v86_grammar_transition_frontier.jl PARENT SUMMARY OUTPUT")

read_json(path) = FusionConceptAI._stage3_plain_v1(JSON3.read(
    read(abspath(path), String), Dict{String,Any}))

parent = read_json(ARGS[1])
summary = read_json(ARGS[2])
promotions = [item for item in summary["basis_promotion_requests"] if
    Int(item["basis_level"]) == 3 &&
    !isempty(item["frontier_rank"]) &&
    Float64(item["frontier_rank"][1]) == 0.0]
filtered = deepcopy(summary)
filtered["basis_promotion_requests"] = promotions
filtered["grammar_transition_filter"] = Dict{String,Any}(
    "source_basis_level" => 2,
    "target_basis_level" => 3,
    "requires_no_poincare_escape" => true,
    "selection_role" => "focused_grammar_falsification_only",
    "candidate_feasibility_credit" => false,
    "topology_expansion" => false)
campaign = compile_v86_promoted_campaign_v1(parent, filtered)
FusionConceptAI._stage3_atomic_json_v1(abspath(ARGS[3]), campaign)
println(JSON3.write(Dict(
    "status" => "complete",
    "source_promotion_count" => length(summary["basis_promotion_requests"]),
    "selected_no_escape_count" => length(promotions),
    "request_count" => length(campaign["requests"]),
    "campaign_hash" => campaign["campaign_hash"],
    "output" => abspath(ARGS[3]))))
