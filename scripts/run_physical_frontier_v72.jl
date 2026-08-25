using FusionConceptAI

output_path = length(ARGS) >= 1 ? ARGS[1] : joinpath("runs",
    "physical_device_v71_20260825", "physical_frontier_v72.json")
specs = [
    Dict{String,Any}("seed" => 35, "particle_count" => 256,
        "step_count" => 2000, "required_transit_fraction" => 1.0),
    Dict{String,Any}("seed" => 98, "particle_count" => 256,
        "step_count" => 1000, "required_transit_fraction" => 1.0),
]
artifact = run_physical_frontier_v72(specs; output_path = output_path)
winner = artifact["winner"]
println("status=$(artifact["status"])")
println("candidate_count=$(artifact["candidate_count"])")
println("uncaught_exception_count=$(artifact["uncaught_exception_count"])")
if winner !== nothing
    println("winner_seed=$(winner["seed"])")
    println("winner_screen=$(winner["screen"]["conclusion"])")
    println("winner_transport=$(winner["transport"]["conclusion"])")
    println("winner_transport_code=$(winner["transport"]["classification_code"])")
end
println("result_hash=$(artifact["result_hash"])")
println("artifact=$(abspath(output_path))")
