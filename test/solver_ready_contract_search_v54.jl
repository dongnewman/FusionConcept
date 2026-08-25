using Test
using JSON3
using FusionConceptAI

@testset "solver-ready contract search v54" begin
    root = normpath(joinpath(@__DIR__, ".."))
    seeds = load_genomes(joinpath(root, "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)

    function module_index(needle)
        return only(first(findall(assembly -> any(token ->
            occursin(needle, lowercase(token)), assembly.module_ids),
            context.assemblies), 1))
    end

    indices = Dict(
        "icf" => module_index("icf"),
        "dipole" => module_index("dipole"),
        "mirror" => module_index("mirror"),
        "zpinch" => module_index("zpinch"),
        "stellarator" => module_index("stellarator"))

    for index in values(indices)
        candidate = evaluate_solver_ready_candidate_v54(context, index)
        genome = candidate.prescreen.compiled.genome
        audit = solver_contract_audit_v54(genome,
            candidate.prescreen.compiled.module_ids)
        @test audit["status"] == "ready"
        @test audit["parent_synthesized"] === false
        @test genome.normalized["solver_ready_contracts"]["generation_stage"] ==
            "before_common_screen"
        @test all(haskey(genome.normalized["solver_ready_contracts"]["ledgers"], id)
            for id in ("power", "particle", "fuel_inventory", "end_loss"))
        replay = evaluate_solver_ready_candidate_v54(context, index)
        @test replay.prescreen.compiled.genome.physics_hash == genome.physics_hash
    end

    mirror = evaluate_solver_ready_candidate_v54(context, indices["mirror"])
    mirror_contract = mirror.prescreen.compiled.genome.normalized[
        "solver_ready_contracts"]["mirror_or_dipole"]
    @test mirror_contract["kind"] == "axisymmetric_mirror_filament_pair_v1"
    @test length(mirror_contract["filaments"]) == 2
    mirror_high = higher_fidelity_solver_contract_validation_v54(
        context, indices["mirror"])
    @test any(attempt -> attempt["route_id"] ==
        "axisymmetric_mirror_filament_c1_v1" && attempt["executed"] === true,
        mirror_high["attempts"])

    dipole_high = higher_fidelity_solver_contract_validation_v54(
        context, indices["dipole"])
    @test any(attempt -> attempt["route_id"] ==
        "levitated_dipole_ring_screen_v1" && attempt["executed"] === true,
        dipole_high["attempts"])

    icf = evaluate_solver_ready_candidate_v54(context, indices["icf"])
    pulsed = icf.prescreen.compiled.genome.normalized[
        "solver_ready_contracts"]["pulsed_device"]
    @test length(pulsed["materials"]) >= 2
    @test pulsed["mesh_convergence"]["fine_cells"] >
        pulsed["mesh_convergence"]["coarse_cells"]
    icf_high = higher_fidelity_solver_contract_validation_v54(context, indices["icf"])
    @test any(attempt -> attempt["route_id"] ==
        "time_resolved_drive_energy_audit_v54" && attempt["status"] == "pass",
        icf_high["attempts"])

    zpinch = evaluate_solver_ready_candidate_v54(context, indices["zpinch"])
    @test any(source -> source.geometry_model ==
        "finite_radius_axial_current_density",
        zpinch.prescreen.compiled.genome.field_sources)

    records = [solver_ready_candidate_to_dict_v54(
        evaluate_solver_ready_candidate_v54(context, index)) for index in 1:20]
    archive = build_solver_ready_search_archive_v54(records)
    @test archive["summary"]["solver_contract_ready_count"] == 20
    @test archive["summary"]["solver_contract_invalid_count"] == 0
    @test all(record -> any(screen -> screen["screen_id"] ==
        "solver_input_contract_readiness" && screen["status"] == "pass",
        record["screens"]), archive["screened_records"])

    schema = JSON3.read(read(joinpath(root, "schemas",
        "solver_ready_contract_v54.schema.json"), String))
    @test String(schema["properties"]["generation_stage"]["const"]) ==
        "before_common_screen"
end
