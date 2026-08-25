using FusionConceptAI

first_seed = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 1
last_seed = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10_000
output_path = length(ARGS) >= 3 ? ARGS[3] : joinpath("runs",
    "physical_device_v82_20260825", "periodic_modular_search_10000.json")
artifact = run_periodic_modular_search_v82(72, first_seed, last_seed;
    output_path = output_path)
println("status=", artifact["status"])
println("searched_candidate_count=", artifact["searched_candidate_count"])
println("uncaught_exception_count=", artifact["uncaught_exception_count"])
println("poincare_unknown_count=", artifact["poincare_unknown_count"])
if artifact["winner"] !== nothing
    row = artifact["winner"]["row"]
    println("winner_seed=", row["periodic_modular_seed"])
    println("winner_conclusion=", row["conclusion"])
    println("winner_code=", row["classification_code"])
    println("winner_crossings=", row["minimum_crossing_count"])
end
println("result_hash=", artifact["result_hash"])
println("artifact=", abspath(output_path))
