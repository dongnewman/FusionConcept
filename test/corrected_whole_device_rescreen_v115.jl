using Test
using FusionConceptAI

@testset "v115 corrected whole-device rescreen" begin
    root = normpath(joinpath(@__DIR__, ".."))
    frontier = load_v114_provider_frontier_v115(root)
    @test length(frontier) == 9
    item = first(frontier)
    assemblies = generate_corrected_whole_device_assemblies_v115(item["candidate"])
    @test length(assemblies) == 24
    @test sort(unique(Float64(assembly["physical_design"]["thermal_cycle"][
        "declared_coolant_delta_t_k"]) for assembly in assemblies)) ==
        V115_COOLANT_DELTA_T_K
    @test all(assembly -> audit_whole_device_assembly_inputs_v105(assembly)["status"] ==
        "closed", assemblies)
    extrema = actual_static_extrema_v115(item["artifacts"]["static"])
    @test extrema["scenario_count"] == 9
    screen = screen_corrected_whole_device_assembly_v115(first(assemblies),
        item["candidate"], item["artifacts"]["static"])
    @test screen["outputs"]["peak_field_t"] == extrema["peak_field_t"]
    @test screen["actual_static_extrema"]["static_result_hash"] ==
        item["artifacts"]["static"]["result_hash"]
    @test screen["unsupported_candidate_classification_used"] === false
    overlay = generate_controller_overlays_v108(first(assemblies))[2]
    dynamic = execute_corrected_dynamic_fault_provider_v115(first(assemblies),
        overlay, item["candidate"], item["artifacts"]["static"])
    quench = only(result for result in dynamic["scenario_results"] if
        result["scenario_id"] == "quench")
    @test quench["independent_dump_circuit_count"] == 4
    @test quench["per_circuit_terminal_voltage_v"] <= 20000.0
    @test quench["final_current_fraction_at_2s"] <= 0.01
    @test quench["status"] == "pass"
end
