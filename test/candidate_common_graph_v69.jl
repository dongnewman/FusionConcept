using Test
using FusionConceptAI

function manufactured_state_v69()
    binding = canonical_hash(Dict("candidate" => "manufactured_common_chain_v69"))
    state_hash = canonical_hash(Dict("state" => "manufactured_exact_state_v69"))
    evidence = canonical_hash(Dict("evidence" => "manufactured_exact_state_v69"))
    quantity(id, value, unit) = compile_c2_quantity_field_v1(id, value, unit, evidence)
    particles = [quantity("fuel_particle_inventory", 2.0, "particle"),
        quantity("electron_inventory", 2.0, "particle")]
    energies = [quantity("ion_thermal_energy", 4.0, "J"),
        quantity("electron_thermal_energy", 4.0, "J")]
    species = [compile_c2_species_state_v1("fuel_a", 1.0, "particle", 1.0, evidence),
        compile_c2_species_state_v1("fuel_b", 1.0, "particle", 1.0, evidence)]
    actuators = C2ActuatorStateV1[]
    for (id, role, unit) in (("fuel", :fueling, "particle/s"),
            ("heat", :heating, "W"), ("exhaust", :exhaust, "particle/s"),
            ("radiation", :radiation_control, "W"))
        push!(actuators, compile_c2_actuator_state_v1(id, role; demand = 1.0,
            output = 1.0, capacity = 2.0, output_unit = unit,
            wall_plug_efficiency = 0.5, evidence_hash = evidence))
    end
    power_accounts = [quantity(id, value, "W") for (id, value) in (
        ("reaction_power", 100.0), ("self_heating_power", 20.0),
        ("radiation_loss_power", 5.0), ("actuator_delivered_power", 10.0),
        ("wall_input_power", 20.0), ("gross_electric_power", 40.0),
        ("net_electric_lower_bound", 15.0))]
    ledger = compile_c2_power_ledger_v1(power_accounts;
        balance_residual_w = 0.0, evidence_hash = evidence)
    evidence_fields = [compile_c2_evidence_field_v1(id, :complete, evidence,
        "manufactured exact-state regression only") for id in (
            "state_solution", "residual_convergence", "conservation",
            "interface_flux", "actuator_fulfillment", "physical_bounds",
            "validity_domain", "resolution_trend", "jacobian_audit",
            "independent_residual_audit", "stability", "engineering")]
    capabilities = ["declared_boundary_flux_v1", "regional_particle_continuity_v1",
        "regional_ion_energy_balance_v1", "regional_electron_energy_balance_v1",
        "regional_actuator_fulfillment_v1", "regional_power_ledger_v1",
        "regional_species_balance_v1", "minimum_b_stabilization_path_v2_capability"]
    return compile_c2_candidate_state_package_v1(
        candidate_binding_hash = binding, state_result_hash = state_hash,
        time_mode = :steady, boundary_classes = ["open_flux"],
        capability_ids = capabilities, region_ids = ["manufactured_region"],
        particle_accounts = particles, energy_accounts = energies,
        species_states = species, actuator_states = actuators,
        power_ledger = ledger, evidence_fields = evidence_fields)
end

@testset "v69 common ports, radiation, plant and exact-state closure" begin
    state = manufactured_state_v69()
    ports = compile_unified_port_capabilities_v69(state)
    @test length(ports) == 6
    @test Set(getfield.(ports, :capability_id)) == Set(UNIFIED_PORT_CAPABILITY_IDS_V69)
    @test all(item -> item.candidate_binding_hash == state.candidate_binding_hash &&
        item.state_result_hash == state.state_result_hash, ports)
    packets = [execute_unified_port_capability_v69(item,
        Dict(resource => resource == "state_vector" ? [1.0, 2.0] :
            resource == "field_state" ? [0.0, 0.0, 1.0] : 1.0
            for resource in item.resource_ids)) for item in ports]
    @test all(packet -> packet["status"] == "pass", packets)
    @test all(packet -> packet["candidate_binding_hash"] ==
        state.candidate_binding_hash, packets)
    grammar = compile_stage34_control_volume_grammar_v2(state;
        dimension = "axisymmetric_2d", boundary_class = "open_flux",
        symmetry_id = "none",
        required_stability_operator_ids = ["minimum_b_stabilization_path_v2"])
    topology = compile_stage34_topology_v2(state, grammar;
        bound_capability_evidence = port_capability_evidence_to_dict_v69.(ports))
    @test topology.status == :pass
    @test !any(contains("missing_port_capability"), topology.reasons)

    primary = canonical_hash(Dict("radiation" => "primary"))
    independent = canonical_hash(Dict("radiation" => "independent"))
    channels = RadiationChannelEvidenceV69[]
    for id in COMPLETE_RADIATION_CHANNEL_IDS_V69
        if id in ("free_free_bremsstrahlung", "cyclotron_synchrotron",
                "free_bound_recombination")
            push!(channels, compile_radiation_channel_evidence_v69(id;
                applicability = :applicable, lower_power_w = 0.9,
                nominal_power_w = 1.0, upper_power_w = 1.1,
                model_id = "manufactured_analytic_channel_v1",
                applicability_basis = "exact manufactured channel",
                primary_source_hash = primary,
                independent_source_hash = independent))
        else
            push!(channels, compile_radiation_channel_evidence_v69(id;
                applicability = :not_applicable,
                model_id = "manufactured_absence_proof_v1",
                applicability_basis = "species inventory proves this channel absent",
                primary_source_hash = primary,
                independent_source_hash = independent))
        end
    end
    radiation = compile_complete_radiation_closure_v69(
        state.candidate_binding_hash, state.state_result_hash, channels)
    @test radiation.status == :complete
    @test radiation.nominal_power_w == 3.0
    @test isempty(radiation.unresolved_channel_ids)

    roles = PlantPowerRoleV69[]
    for id in FusionConceptAI.PLANT_SUBSYSTEM_ROLE_IDS_V1
        direction = id == "gross_electric_generation" ? :generation :
            id == "direct_energy_recovery" ? :recovery : :auxiliary_load
        if id == "direct_energy_recovery"
            push!(roles, compile_plant_power_role_v69(id; direction = direction,
                applicability = :not_applicable, primary_source_hash = primary,
                independent_source_hash = independent))
        else
            value = direction == :generation ? 120.0 : 5.0
            push!(roles, compile_plant_power_role_v69(id; direction = direction,
                applicability = :applicable, lower_power_w = 0.9value,
                nominal_power_w = value, upper_power_w = 1.1value,
                primary_source_hash = primary, independent_source_hash = independent))
        end
    end
    plant = compile_complete_plant_power_ledger_v69(state.candidate_binding_hash,
        state.state_result_hash, roles)
    @test plant.completeness == :complete
    @test plant.sign_conclusion == :pass
    @test plant.net_lower_w > 0.0

    exact = Dict("state_x" => 2.0, "state_y" => 3.0)
    primary_values = Dict("state_x" => 2.0, "state_y" => 3.0,
        "stress_margin" => 0.2, "thermal_margin" => 0.1)
    independent_values = copy(primary_values)
    engineering = verify_exact_state_engineering_v69(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash, exact_state = exact,
        primary_values = primary_values, independent_values = independent_values,
        engineering_margin_ids = ["stress_margin", "thermal_margin"],
        relative_tolerance = 1.0e-12, absolute_tolerance = 1.0e-12,
        primary_source_hash = primary, independent_source_hash = independent)
    @test engineering.completeness == :complete
    @test engineering.conclusion == :pass

    gates = [Dict{String,Any}("gate_id" => id, "status" => "pass",
        "evidence_hashes" => [radiation.closure_hash]) for id in COMPLETE_C2_GATE_IDS_V69]
    decision = compile_complete_c2_decision_v69(state.candidate_binding_hash,
        state.state_result_hash, gates; source_decision_hashes = [plant.ledger_hash])
    @test decision.completeness == :complete
    @test decision.conclusion == :pass
end

@testset "terminal failure closes applicability, not feasibility credit" begin
    state = manufactured_state_v69()
    source = canonical_hash(Dict("terminal" => "source"))
    failure = compile_c2_narrow_failure_v1("engineering:hard", "engineering",
        "fail_exact_state_stress_margin", :assembly;
        affected_ids = ["selected_component"],
        excluded_claims = ["alternative_component"], authoritative_for_gate = true,
        terminates_candidate = true, source_result_hash = source)
    gates = C2GateDecisionV1[
        compile_c2_gate_decision_v1("stage_3_residual"; required = true,
            completeness = :incomplete, conclusion = :unknown,
            evidence_tasks = ["complete_radiation"]),
        compile_c2_gate_decision_v1("stage_4_stability"; required = true,
            completeness = :incomplete, conclusion = :unknown,
            evidence_tasks = ["complete_operator"]),
        compile_c2_gate_decision_v1("engineering"; required = true,
            completeness = :complete, conclusion = :fail,
            narrow_failures = [failure], evidence_hashes = [source]),
        compile_c2_gate_decision_v1("independent_evidence"; required = true,
            completeness = :complete, conclusion = :pass, evidence_hashes = [source])]
    old = compile_c2_decision_envelope_v1(state, gates)
    @test old.completeness == :incomplete
    closed = close_terminal_c2_decision_v69(state, old)
    @test closed.completeness == :complete
    @test closed.conclusion == :fail
    @test any(item -> item["status"] == "not_applicable" &&
        item["closure_basis"] == "not_applicable_after_terminal_failure",
        closed.gate_records)
    @test !any(item -> get(item, "preserved_original_status", "") ==
        "incomplete/unknown" && item["status"] == "pass", closed.gate_records)
end

@testset "graph-native compile, mutation, adaptive depth, QD and queues" begin
    topology = generate_graph_native_topology_v69(1)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    @test compilation.status == :pass
    @test compilation.checks["label_routing_used"] === false
    @test graph_isomorphism_hash_v69(topology) ==
        graph_isomorphism_hash_v69(normalize_graph_native_topology_v69(topology))
    @test compile_graph_native_topology_candidate_v69(
        generate_graph_native_topology_v69(29)).status == :unsupported
    @test compile_graph_native_topology_candidate_v69(
        generate_graph_native_topology_v69(31)).status == :fail
    @test compile_graph_native_topology_candidate_v69(
        generate_graph_native_topology_v69(37)).status == :fail
    _, removed = mutate_graph_native_topology_v69(topology,
        Dict("mutation_kind" => "remove_port", "port_id" => "r1_sensor"))
    @test removed.status == :fail
    @test adaptive_state_sampling_depth_v69(:fail, :unknown, 1.0) == 0
    @test adaptive_state_sampling_depth_v69(:pass, :unknown, 0.2) == 1
    @test adaptive_state_sampling_depth_v69(:pass, :unknown, 0.6) == 4
    @test adaptive_state_sampling_depth_v69(:pass, :unknown, 0.8) == 16
    @test adaptive_state_sampling_depth_v69(:pass, :unknown, 0.95) == 64
    @test adaptive_state_sampling_depth_v69(:pass, :pass, 0.0) == 64
    result = run_graph_native_topology_search_v69(120)
    @test result.metrics["raw_topology_count"] == 120
    @test result.metrics["unique_topology_compile_pass_count"] > 100
    @test result.archive.scalar_score_used === false
    @test result.queues.high_fidelity_feedback_role == "next_evidence_selection_only"
    priorities = legacy_candidate_cost_priorities_v69()
    @test priorities[1]["evidence_cost_to_next_gate"] == 66
    @test priorities[3]["evidence_cost_to_next_gate"] == 82
    @test all(item -> item["priority_basis"] == "cost_to_next_gate_only", priorities)
end
