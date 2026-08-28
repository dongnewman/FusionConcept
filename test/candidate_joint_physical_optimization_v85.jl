using Test
using FusionConceptAI
using LinearAlgebra

@testset "v85 joint physical optimization and hard-gate minimality" begin
    topology = generate_graph_native_topology_v69(72)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    base_grammar = default_candidate_realization_grammar_v2(
        graph_isomorphism_hash_v69(topology))
    grammar = compile_joint_optimization_grammar_v1(base_grammar)

    zero_design(route = "closed/mixed") = compile_candidate_joint_design_v1(
        grammar; route = route, coil_fourier_coefficients = zeros(5),
        coil_bspline_control_points = zeros(6),
        current_potential_coefficients = zeros(5),
        plasma_boundary_coefficients = zeros(5),
        actuator_timing_coefficients = zeros(5),
        controller_modal_coefficients = zeros(4), field_current_a = 1.0e5,
        density_scale = 1.0, temperature_scale = 1.0)

    closed = zero_design("closed/mixed")
    open_label = zero_design("open/mixed")
    closed_compiled = compile_joint_physical_realization_v85(topology,
        compilation, closed)
    open_compiled = compile_joint_physical_realization_v85(topology,
        compilation, open_label)
    closed_hashes = v85_solver_input_hashes_v1(closed_compiled)
    open_hashes = v85_solver_input_hashes_v1(open_compiled)
    @test closed_hashes["field_solver_input_hash"] ==
        open_hashes["field_solver_input_hash"]
    @test closed_hashes["poincare_solver_input_hash"] ==
        open_hashes["poincare_solver_input_hash"]

    function changed_design(; fourier = zeros(5), bspline = zeros(6),
            potential = zeros(5), boundary = zeros(5), actuator = zeros(5),
            controller = zeros(4), current = 1.0e5, density = 1.0,
            temperature = 1.0)
        return compile_candidate_joint_design_v1(grammar; route = "closed/mixed",
            coil_fourier_coefficients = fourier,
            coil_bspline_control_points = bspline,
            current_potential_coefficients = potential,
            plasma_boundary_coefficients = boundary,
            actuator_timing_coefficients = actuator,
            controller_modal_coefficients = controller,
            field_current_a = current, density_scale = density,
            temperature_scale = temperature)
    end
    field_variants = CandidateJointDesignV1[
        changed_design(fourier = [0.03, 0, 0, 0, 0]),
        changed_design(bspline = [0.03, 0, 0, 0, 0, 0]),
        changed_design(potential = [0, 0, 0.03, 0, 0]),
        changed_design(boundary = [0, 0.03, 0, 0, 0]),
        changed_design(current = 1.1e5)]
    @test all(v85_solver_input_hashes_v1(
        compile_joint_physical_realization_v85(topology, compilation, item))[
            "field_solver_input_hash"] != closed_hashes["field_solver_input_hash"]
        for item in field_variants)
    fixed_seed = v85_physical_variant_parameter_seed_v1(
        graph_isomorphism_hash_v69(topology), 17)
    fixed_a = compile_joint_physical_realization_v85(topology, compilation,
        closed; parameter_binding_seed = fixed_seed)
    fixed_b = compile_joint_physical_realization_v85(topology, compilation,
        changed_design(current = 1.1e5); parameter_binding_seed = fixed_seed)
    @test fixed_a.binding["v85_parameter_binding_seed_scope"] ==
        "fixed_physical_variant_stream_v1"
    @test all(fixed_a.binding[key] == fixed_b.binding[key] for key in
        ("target_total_ion_density_m3", "target_ion_temperature_kev",
            "target_electron_temperature_kev", "injector_energy_kev"))
    @test fixed_a.binding["field_current_a"] != fixed_b.binding["field_current_a"]
    operating = changed_design(density = 1.05)
    @test v85_solver_input_hashes_v1(compile_joint_physical_realization_v85(
        topology, compilation, operating))["equilibrium_solver_input_hash"] !=
        closed_hashes["equilibrium_solver_input_hash"]
    actuator = changed_design(actuator = [0, 0, 0, 0, 0.02])
    controller = changed_design(controller = [0, 0, 0, 0.02])
    @test closed_compiled.binding["v85_control_schedule"] !=
        compile_joint_physical_realization_v85(topology, compilation,
            actuator).binding["v85_control_schedule"]
    @test closed_compiled.binding["v85_control_schedule"] !=
        compile_joint_physical_realization_v85(topology, compilation,
            controller).binding["v85_control_schedule"]

    metadata = FusionConceptAI._v85_coordinate_metadata()
    @test length(metadata.names) == 33
    @test all(any(startswith(name, prefix) for name in metadata.names) for prefix in
        ("coil_fourier", "coil_bspline", "current_potential",
            "plasma_boundary", "actuator_timing", "controller_modal",
            "log10_field_current", "operating_density",
            "operating_temperature"))
    optimized = optimize_joint_physical_design_v85(topology, compilation,
        grammar, closed; maximum_sweeps = 1, maximum_evaluations = 5)
    @test Tuple(optimized["final_rank"]) <= Tuple(optimized["initial_rank"])
    @test optimized["acquisition_only"] === true
    @test optimized["optimizer"] ==
        "deterministic_feasibility_first_trust_region_pattern_search_v2"
    @test optimized["trust_region_policy"][
        "constraint_violation_precedes_merit"] === true
    @test optimized["trust_region_contractions"] +
        optimized["trust_region_expansions"] == 1
    direction = FusionConceptAI._v85_trust_region_direction(3, 33)
    @test length(direction) == 33
    @test direction == FusionConceptAI._v85_trust_region_direction(3, 33)
    @test all(-1.0 <= value < 1.0 for value in direction)

    fake_gates = Dict{String,Any}(gate_id => Dict{String,Any}(
        "status" => "pass", "evidence" => gate_id ==
            "finite_filament_biot_savart" ? Dict("field" => Dict(
                "maximum_field_t" => 2.0)) : Dict{String,Any}()) for gate_id in
        grammar.hard_gate_ids)
    manifest = compile_actual_device_complexity_manifest_v2(closed,
        closed_compiled, fake_gates)
    loops = first(filter(component -> component["component_kind"] ==
        "finite_filament_coil_array_v1", closed_compiled.realization.components))[
            "loops"]
    recomputed = sum(sum(norm(Float64.(loop["centerline_m"][index + 1]) -
        Float64.(loop["centerline_m"][index])) for index in
        1:length(loop["centerline_m"])-1) * Int(loop["turns"]) for loop in loops)
    @test manifest.conductor_length_m ≈ recomputed
    @test manifest.bom["field_solver_input_hash"] ==
        closed_hashes["field_solver_input_hash"]

    make_manifest(design, values) = ActualDeviceComplexityManifestV2("2.0.0",
        design.design_hash, closed_hashes["field_solver_input_hash"], values[1],
        values[2], values[3], values[4], 1.0, values[5], values[6], Dict(),
        canonical_hash(values))
    d2 = changed_design(density = 1.01)
    d3 = changed_design(temperature = 1.01)
    m1 = make_manifest(closed, (10, 3, 100.0, 1.0, 20.0, 4))
    m2 = make_manifest(d2, (11, 3, 90.0, 1.0, 20.0, 4))
    m3 = make_manifest(d3, (10, 3, 100.0, 1.0, 20.0, 4))
    rows = [Dict{String,Any}("design" => d, "all_hard_gates_pass" => true,
        "complexity_manifest" => m) for (d, m) in
        ((closed, m1), (d2, m2), (d3, m3))]
    archive = build_realization_pareto_archive_v85(rows)
    @test archive.artifact["pareto_count"] == 2
    @test archive.artifact["unique_complexity_count"] == 2
    @test archive.representative === nothing
    explicit_archive = build_realization_pareto_archive_v85(rows;
        representative_policy = "lexicographic_complexity_v1")
    @test explicit_archive.representative !== nothing

    biot = evaluate_v85_biot_savart_gate_v1(closed_compiled)
    poincare = evaluate_v85_poincare_gate_v1(closed_compiled, biot;
        target_toroidal_turns = 8, steps_per_turn = 60)
    if poincare["status"] != "pass"
        equilibrium = evaluate_v85_desc_equilibrium_gate_v1(closed,
            closed_compiled, poincare; execute_solver = false)
        stability = evaluate_v85_desc_stability_gate_v1(closed, closed_compiled,
            poincare, equilibrium; execute_solver = false)
        @test equilibrium["status"] == "not_admitted"
        @test stability["status"] == "not_admitted"
    end
    contract_poincare = FusionConceptAI._v85_gate_record(
        "poincare_nested_surfaces", "pass", "contract_test_only";
        evidence = Dict("poincare_evidence" => Dict(
            "minimum_absolute_rotational_transform" => 0.05,
            "traces" => [Dict("minimum_field_t" => 1.0,
                "maximum_field_t" => 1.2)])))
    equilibrium_input = compile_v85_desc_equilibrium_input_v1(closed,
        closed_compiled, contract_poincare)
    contract_equilibrium = FusionConceptAI._v85_gate_record(
        "finite_pressure_equilibrium", "pass", "contract_test_only";
        solver_input_hash = canonical_hash(equilibrium_input),
        evidence = Dict("solver_input" => equilibrium_input,
            "raw_result" => Dict("result_hash" => repeat("a", 64),
                "after" => Dict{String,Any}())))
    stability_input = compile_v85_desc_stability_input_v1(closed,
        closed_compiled, contract_poincare, contract_equilibrium)
    @test stability_input["equilibrium_solver_input"]["resolution"] ==
        Dict{String,Any}("L" => 6, "M" => 6, "N" => 4,
            "L_grid" => 12, "M_grid" => 12, "N_grid" => 8)
    @test stability_input["equilibrium_reference"]["input_hash"] ==
        canonical_hash(equilibrium_input)
    @test stability_input["equilibrium_reference"]["result_hash"] == repeat("a", 64)
    @test stability_input["stability"] ==
        FusionConceptAI._desc_stability_settings_medium()

    open_topology = generate_graph_native_topology_v69(2)
    open_compilation = compile_graph_native_topology_candidate_v69(open_topology)
    open_grammar = compile_joint_optimization_grammar_v1(
        default_candidate_realization_grammar_v2(
            graph_isomorphism_hash_v69(open_topology)))
    open_design = seed_candidate_joint_design_v1(open_grammar;
        physical_variant = 1, operating_variant = 1, control_variant = 1,
        route = "open/mixed")
    open_realization = compile_joint_physical_realization_v85(open_topology,
        open_compilation, open_design)
    @test open_realization.binding["geometry_class"] == "linear_volume_v1"
    open_biot = evaluate_v85_biot_savart_gate_v1(open_realization)
    open_poincare = evaluate_v85_poincare_gate_v1(open_realization, open_biot;
        target_toroidal_turns = 8, steps_per_turn = 60)
    @test open_poincare["status"] == "unsupported"
    @test open_poincare["classification_code"] ==
        "not_applicable_non_toroidal_geometry"
end
