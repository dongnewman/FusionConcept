using FusionConceptAI

output_path = length(ARGS) >= 1 ? ARGS[1] : joinpath("runs",
    "physical_device_v81_20260825", "v80_frontier_poincare_128turn.json")
seeds = [9283, 4148, 2114, 3884, 2696, 9281, 886, 9393]
artifact = run_v80_poincare_frontier_v81(seeds; output_path = output_path,
    target_toroidal_turns = 128, steps_per_turn = 180)
println("status=", artifact["status"])
println("candidate_count=", artifact["candidate_count"])
println("uncaught_exception_count=", artifact["uncaught_exception_count"])
println("poincare_unknown_count=", artifact["poincare_unknown_count"])
if artifact["winner"] !== nothing
    row = artifact["winner"]["row"]
    println("winner_seed=", row["modular_seed"])
    println("winner_conclusion=", row["conclusion"])
    println("winner_code=", row["classification_code"])
    println("winner_transform=", row["minimum_absolute_rotational_transform"])
    println("winner_residual=", row["maximum_fourier_residual"])
    println("winner_bin_spread=", row["maximum_repeated_bin_radial_spread"])
end
println("result_hash=", artifact["result_hash"])
println("artifact=", abspath(output_path))
