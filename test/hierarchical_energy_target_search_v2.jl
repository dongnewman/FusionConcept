function energyv2_interval(state::C2CandidateStatePackageV1, lower, upper, digit)
    return compile_c2_uncertainty_interval_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash,
        quantity_id = "net_electric_lower_bound", lower = lower, upper = upper,
        unit = "W", coverage_probability = 0.95,
        method = "manufactured_protocol_interval", source_result_hash = repeat(digit, 64))
end

function energyv2_input(digit::String; net::Float64, wall::Float64,
        interval_bounds = (1.0, 2.0), decision_kind::Symbol = :pass,
        complexity::Float64 = 5.0, acquisition = HighFidelityAcquisitionSignalV2[])
    state = c2v1_state_packet("closed_flux", digit;
        capability_ids = vcat(STAGE34_V2_STAGE3_CAPABILITIES,
            ["three_dimensional_equilibrium_v2_capability"]),
        power_overrides = Dict("net_electric_lower_bound" => net,
            "wall_input_power" => wall))
    topology = compile_stage34_topology_v2(state,
        stage34v2_grammar(state, "closed_flux"))
    decision = if decision_kind == :pass
        c2v1_complete_pass(state)
    elseif decision_kind == :unknown
        c2v1_unknown_decision(state)
    elseif decision_kind == :terminal_partial
        failure = compile_c2_narrow_failure_v1("selected_assembly_failure",
            "engineering", "fail_selected_assembly_necessary_condition", :assembly;
            affected_ids = ["selected_assembly"], excluded_claims = ["other_assemblies"],
            authoritative_for_gate = true, terminates_candidate = true,
            source_result_hash = state.state_result_hash)
        engineering = compile_c2_gate_decision_v1("engineering"; required = true,
            completeness = :complete, conclusion = :fail, narrow_failures = [failure],
            evidence_hashes = [state.state_result_hash])
        residual = compile_c2_gate_decision_v1("stage_3_residual"; required = true,
            completeness = :incomplete, conclusion = :unknown,
            evidence_tasks = ["complete_residual_evidence"])
        compile_c2_decision_envelope_v1(state, [engineering, residual])
    else
        error("unknown decision fixture")
    end
    interval = interval_bounds === nothing ? nothing :
        energyv2_interval(state, interval_bounds[1], interval_bounds[2], digit)
    metric = compile_energy_search_metric_v2("assembly_complexity", complexity,
        "count", repeat(digit, 64))
    return compile_energy_search_input_v2(state, topology, decision;
        net_power_interval = interval, metrics = [metric],
        acquisition_signals = acquisition)
end

@testset "hierarchical energy search v2 grants rank only after every hard gate" begin
    high_fidelity = compile_high_fidelity_acquisition_signal_v2(
        "complete_residual_evidence"; expected_information_gain = 1.0e9,
        normalized_cost = 0.01, source_hash = repeat("5", 64))
    inputs = EnergySearchInputV2[
        energyv2_input("1"; net = 20.0, wall = 50.0, complexity = 4.0,
            interval_bounds = (10.0, 30.0)),
        energyv2_input("2"; net = 30.0, wall = 60.0, complexity = 7.0,
            interval_bounds = (15.0, 40.0)),
        energyv2_input("3"; net = -1.0, wall = 20.0,
            interval_bounds = (-2.0, -0.5)),
        energyv2_input("4"; net = 12.0, wall = 30.0,
            interval_bounds = (-1.0, 20.0)),
        energyv2_input("5"; net = 100.0, wall = 1.0,
            interval_bounds = (90.0, 110.0), decision_kind = :unknown,
            acquisition = [high_fidelity]),
        energyv2_input("6"; net = 100.0, wall = 1.0,
            interval_bounds = (90.0, 110.0), decision_kind = :terminal_partial)]
    objectives = EnergyObjectiveSpecV1[
        compile_energy_objective_spec_v1("net_power", "net_electric_lower_bound",
            :maximize; tier = 1, target = 10.0, scale = 10.0, unit = "W"),
        compile_energy_objective_spec_v1("wall_power", "wall_input_power", :minimize;
            tier = 2, target = 100.0, scale = 10.0, unit = "W"),
        compile_energy_objective_spec_v1("complexity", "assembly_complexity", :minimize;
            tier = 2, target = 10.0, scale = 1.0, unit = "count")]
    result = search_hierarchical_energy_targets_v2(inputs, objectives)
    @test result.priority_front_binding_hashes == [repeat("2", 64)]
    @test result.net_power_shortfall_binding_hashes == [repeat("3", 64)]
    @test result.uncertainty_crosses_zero_binding_hashes == [repeat("4", 64)]
    @test result.evidence_queue_binding_hashes == [repeat("5", 64)]
    @test result.c2_terminated_binding_hashes == [repeat("6", 64)]
    @test result.scalar_score_used === false
    @test result.proxy_feasibility_credit_used === false
    @test result.high_fidelity_feedback_role == "evidence_acquisition_only"
    unknown_entry = only(filter(item -> item.candidate_binding_hash == repeat("5", 64),
        result.entries))
    @test unknown_entry.disposition == :evidence_queue
    @test unknown_entry.acquisition_priority_tasks == ["complete_residual_evidence"]
    @test isempty(unknown_entry.objective_coordinates)
    terminal_entry = only(filter(item -> item.candidate_binding_hash == repeat("6", 64),
        result.entries))
    @test terminal_entry.disposition == :c2_terminated
    @test any(audit -> audit["gate_id"] == "topology_compile" &&
        audit["status"] == "pass", terminal_entry.gate_audits)

    state = inputs[1].state
    wrong_interval = compile_c2_uncertainty_interval_evidence_v1(
        candidate_binding_hash = repeat("7", 64), state_result_hash = repeat("d", 64),
        quantity_id = "net_electric_lower_bound", lower = 1.0, upper = 2.0,
        unit = "W", coverage_probability = 0.95, method = "wrong_binding",
        source_result_hash = repeat("7", 64))
    @test_throws ArgumentError compile_energy_search_input_v2(state,
        inputs[1].topology, inputs[1].decision; net_power_interval = wrong_interval)

    root = normpath(joinpath(@__DIR__, ".."))
    schema = JSON3.read(read(joinpath(root, "schemas",
        "hierarchical_energy_target_search_v2.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    source = read(joinpath(root, "src", "search",
        "hierarchical_energy_target_search_v2.jl"), String)
    @test !occursin("genome.family", source)
    @test !occursin("device_name", source)
    @test !occursin("candidate_name", source)

    artifact = JSON3.read(read(joinpath(root, "runs",
        "candidate_stage34_energy_gate_v2_20260825.json"), String), Dict{String,Any})
    @test artifact["chain_contract"]["family_or_device_routing_used"] === false
    @test artifact["chain_contract"]["specialized_adapter_added"] === false
    @test length(artifact["executed_assembly_rows"]) == 2
    @test length(artifact["acquisition_front_rows"]) == 4
    @test all(row -> row["energy_gate"]["disposition"] == "c2_terminated",
        artifact["executed_assembly_rows"])
    @test isempty(artifact["energy_target_search"]["priority_front_binding_hashes"])
    @test artifact["energy_target_search"]["proxy_feasibility_credit_used"] === false
end
