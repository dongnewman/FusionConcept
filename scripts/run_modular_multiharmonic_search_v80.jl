using FusionConceptAI

first_seed = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 1
last_seed = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 10_000
output_path = length(ARGS) >= 3 ? ARGS[3] : joinpath("runs",
    "physical_device_v80_20260825", "modular_multiharmonic_search_10000.json")
shortlist = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 128
finalists = length(ARGS) >= 5 ? parse(Int, ARGS[5]) : 8
artifact = run_modular_multiharmonic_search_v80(72, first_seed, last_seed;
    shortlist_count = shortlist, finalist_count = finalists,
    output_path = output_path)
println("status=", artifact["status"])
println("searched_candidate_count=", artifact["searched_candidate_count"])
println("uncaught_exception_count=", artifact["uncaught_exception_count"])
println("four_turn_unknown_count=", artifact["four_turn_unknown_count"])
println("eight_turn_unknown_count=", artifact["eight_turn_unknown_count"])
if artifact["winner"] !== nothing
    row = artifact["winner"]["row"]
    println("winner_seed=", row["modular_seed"])
    println("winner_conclusion=", row["closed_field_conclusion"])
    println("winner_transform=", row["minimum_absolute_rotational_transform"])
    println("winner_excursion=", row["maximum_normalized_minor_radius_excursion"])
end
println("result_hash=", artifact["result_hash"])
println("artifact=", abspath(output_path))
