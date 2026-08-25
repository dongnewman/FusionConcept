using FusionConceptAI

function _argument(index, default)
    return length(ARGS) >= index ? ARGS[index] : default
end

first_seed = parse(Int, _argument(1, "1"))
last_seed = parse(Int, _argument(2, "128"))
output_path = _argument(3, joinpath("runs", "physical_device_v71",
    "physical_device_search_$(first_seed)_$(last_seed).json"))
particle_count = parse(Int, _argument(4, "4"))
step_count = parse(Int, _argument(5, "80"))

artifact = run_physical_device_search_v71(first_seed, last_seed;
    output_path = output_path, particle_count = particle_count, step_count = step_count)
winner = artifact["winner"]
println("status=$(artifact["status"])")
println("raw_candidate_count=$(artifact["raw_candidate_count"])")
println("evaluated_physical_candidate_count=$(artifact["evaluated_physical_candidate_count"])")
println("uncaught_exception_count=$(artifact["uncaught_exception_count"])")
println("screen_conclusion_counts=$(artifact["screen_conclusion_counts"])")
if winner !== nothing
    println("winner_seed=$(winner["seed"])")
    println("winner_gate_depth=$(winner["screen"]["passed_gate_count"])/$(winner["screen"]["required_gate_count"])")
    println("winner_conclusion=$(winner["screen"]["conclusion"])")
    println("winner_evidence_hash=$(winner["screen"]["evidence_hash"])")
end
println("result_hash=$(artifact["result_hash"])")
println("artifact=$(abspath(output_path))")
