using FusionConceptAI

output_path = length(ARGS) >= 1 ? ARGS[1] : joinpath("runs",
    "physical_device_v83_20260825", "periodic_coil_regularization_270.json")
artifact = run_periodic_coil_regularization_v83(output_path = output_path)
println("status=", artifact["status"])
println("grid_candidate_count=", artifact["grid_candidate_count"])
println("poincare_unknown_count=", artifact["poincare_unknown_count"])
if artifact["winner"] !== nothing
    row = artifact["winner"]["row"]
    println("winner_key=", row["variant_key"])
    println("winner_conclusion=", row["conclusion"])
    println("winner_code=", row["classification_code"])
    println("winner_crossings=", row["minimum_crossing_count"])
    println("winner_transform=", row["minimum_absolute_rotational_transform"])
end
println("result_hash=", artifact["result_hash"])
println("artifact=", abspath(output_path))
