using Test
using JSON3
using SHA
using FusionConceptAI

const C2V1_EVIDENCE_IDS = [
    "state_solution", "residual_convergence", "conservation", "interface_flux",
    "actuator_fulfillment", "physical_bounds", "validity_domain",
    "resolution_trend", "jacobian_audit", "independent_residual_audit",
    "stability", "engineering"]

function c2v1_state_packet(boundary_class::String, digit::String;
        capability_ids::Vector{String} = ["particle_balance", "energy_balance",
            "species_balance", "actuator_balance", "power_balance"],
        region_ids::Vector{String} = ["region_0"],
        power_overrides::Dict{String,Float64} = Dict{String,Float64}())
    evidence_hash = repeat(digit, 64)
    quantity(id, value, unit) = compile_c2_quantity_field_v1(id, value, unit,
        evidence_hash)
    particles = [quantity("total_particle_inventory", 2.0e20, "particle")]
    energies = [quantity("ion_thermal_energy", 1.1e6, "J"),
        quantity("electron_thermal_energy", 0.9e6, "J")]
    species = [compile_c2_species_state_v1("fuel_ion", 2.0e20, "particle", 1.0,
        evidence_hash)]
    actuators = C2ActuatorStateV1[
        compile_c2_actuator_state_v1("fueling_0", :fueling; demand = 4.0,
            output = 4.0, capacity = 5.0, output_unit = "particle/s",
            wall_plug_efficiency = 0.8, evidence_hash = evidence_hash),
        compile_c2_actuator_state_v1("heating_0", :heating; demand = 12.0,
            output = 10.0, capacity = 10.0, output_unit = "W",
            wall_plug_efficiency = 0.5, evidence_hash = evidence_hash),
        compile_c2_actuator_state_v1("exhaust_0", :exhaust; demand = 2.0,
            output = 2.0, capacity = 3.0, output_unit = "particle/s",
            wall_plug_efficiency = 0.7, evidence_hash = evidence_hash),
        compile_c2_actuator_state_v1("radiation_control_0", :radiation_control;
            demand = 1.0, output = 1.0, capacity = 2.0, output_unit = "W",
            wall_plug_efficiency = 0.6, evidence_hash = evidence_hash)]
    power_value(id, fallback) = get(power_overrides, id, fallback)
    power = compile_c2_power_ledger_v1([
        quantity("reaction_power", power_value("reaction_power", 3.0), "W"),
        quantity("self_heating_power", power_value("self_heating_power", 1.0), "W"),
        quantity("radiation_loss_power", power_value("radiation_loss_power", 4.0), "W"),
        quantity("actuator_delivered_power", power_value("actuator_delivered_power", 10.0), "W"),
        quantity("wall_input_power", power_value("wall_input_power", 20.0), "W"),
        quantity("gross_electric_power", power_value("gross_electric_power", 0.0), "W"),
        quantity("net_electric_lower_bound", power_value("net_electric_lower_bound", -20.0), "W")];
        balance_residual_w = 0.0, evidence_hash = evidence_hash)
    evidence = [compile_c2_evidence_field_v1(id, :complete, evidence_hash,
        "manufactured protocol-conformance field only") for id in C2V1_EVIDENCE_IDS]
    return compile_c2_candidate_state_package_v1(
        candidate_binding_hash = evidence_hash, state_result_hash = repeat(digit == "a" ? "c" : "d", 64),
        time_mode = :steady, boundary_classes = [boundary_class],
        capability_ids = capability_ids, region_ids = region_ids,
        particle_accounts = particles, energy_accounts = energies,
        species_states = species, actuator_states = actuators,
        power_ledger = power, evidence_fields = evidence)
end

@testset "candidate-bound acquisition DAG joins Stage 3 and Stage 4 without label routing" begin
    root = normpath(joinpath(@__DIR__, ".."))
    schema = JSON3.read(read(joinpath(root, "schemas",
        "candidate_c2_acquisition_plan_v1.schema.json"), String))
    @test schema[Symbol("\$schema")] ==
        "https://json-schema.org/draft/2020-12/schema"
    artifact = JSON3.read(read(joinpath(root, "runs",
        "candidate_c2_acquisition_front_v1_20260825.json"), String),
        Dict{String,Any})
    @test Set(artifact["selected_panel_entry_ids"]) == Set([
        "closed_candidate_pool24", "closed_candidate_pool56",
        "open_candidate_mirror_high_ratio", "open_candidate_mirror_low_force"])
    @test length(artifact["entries"]) == 4
    for entry in artifact["entries"]
        plan = entry["acquisition_plan"]
        @test plan["candidate_binding_hash"] == entry["candidate_binding_hash"]
        @test occursin(r"^[0-9a-f]{64}$", String(plan["shared_state_result_hash"]))
        @test plan["status"] == "acquisition_required"
        @test length(plan["batches"]) == 10
        batches = Dict(String(item["batch_id"]) => item for item in plan["batches"])
        @test length(batches["s3_02_physical_closure"]["longitudinal_input_ids"]) == 10
        @test length(batches["s3_03_actuator_delivery"]["longitudinal_input_ids"]) == 17
        @test length(batches["s3_04_control_power_targets"]["longitudinal_input_ids"]) == 14
        @test batches["s4_01_operator_inputs"]["prerequisite_batch_ids"] ==
            ["s3_01_state_species_scales"]
        @test batches["s3_05_v68_execution"]["prerequisite_batch_ids"] ==
            ["s3_04_control_power_targets"]
        @test Set(batches["s4_02_operator_execution_audit"][
            "prerequisite_batch_ids"]) ==
            Set(["s3_05_v68_execution", "s4_01_operator_inputs"])
        @test Set(batches["s3_05_v68_execution"]["evidence_actions"]) == Set([
            "execute_candidate_bound_v68_after_input_completion",
            "seal_shared_state_result_hash_for_stage4"])
        @test Set(batches["c2_01_recompute_and_aggregate"]["prerequisite_batch_ids"]) ==
            Set(["s5_01_engineering_evidence", "s6_01_independent_evidence"])
        @test Set(batches["s5_01_engineering_evidence"]["prerequisite_batch_ids"]) ==
            Set(["s3_05_v68_execution", "s4_02_operator_execution_audit"])
        @test Set(batches["s6_01_independent_evidence"]["prerequisite_batch_ids"]) ==
            Set(["s3_05_v68_execution", "s4_02_operator_execution_audit"])
        @test plan["outstanding_c2_evidence_gate_ids"] ==
            ["engineering", "independent_evidence"]
        @test Set(batches["s5_01_engineering_evidence"]["evidence_actions"]) == Set([
            "compile_c2_engineering_evidence_v1",
            "run_candidate_engineering_multiphysics_on_shared_state:$(plan["shared_state_result_hash"])"])
        @test Set(batches["s6_01_independent_evidence"]["evidence_actions"]) == Set([
            "recalculate_independent_residual_on_shared_state:$(plan["shared_state_result_hash"])",
            "acquire_candidate_bound_uncertainty_interval:$(plan["shared_state_result_hash"])",
            "compile_c2_independent_evidence_from_v68_v1"])
        physical_actions = batches["s3_02_physical_closure"]["evidence_actions"]
        @test "bind_candidate_capability:candidate_reaction_bremsstrahlung:parameter:reaction_coefficient_per_particle_s" in physical_actions
        @test "bind_candidate_capability:candidate_transport_response:parameter:ion_energy_loss_s" in physical_actions
        forbidden = Set(["family", "device_name", "candidate_id", "route"])
        function assert_label_free(value)
            if value isa AbstractDict
                @test isempty(intersect(Set(String.(keys(value))), forbidden))
                foreach(assert_label_free, values(value))
            elseif value isa AbstractVector
                foreach(assert_label_free, value)
            end
        end
        assert_label_free(plan)
        @test entry["current_c2"]["completeness"] == "incomplete"
        @test entry["current_c2"]["candidate_conclusion"] == "unknown"
        @test entry["current_c2"]["terminate"] === false
        if startswith(String(entry["panel_entry_id"]), "closed_")
            @test length(plan["outstanding_longitudinal_input_ids"]) == 55
            @test length(batches["s3_01_state_species_scales"]["longitudinal_input_ids"]) == 14
            @test !("parameter:energy_scale" in
                plan["outstanding_longitudinal_input_ids"])
            @test length(plan["outstanding_stage4_operator_ids"]) == 5
            @test length(plan["outstanding_stage4_input_ids"]) == 11
        else
            @test length(plan["outstanding_longitudinal_input_ids"]) == 56
            @test length(batches["s3_01_state_species_scales"]["longitudinal_input_ids"]) == 15
            @test length(plan["outstanding_stage4_operator_ids"]) == 7
            @test length(plan["outstanding_stage4_input_ids"]) == 26
        end
    end
    core = deepcopy(artifact); delete!(core, "deterministic_hash")
    @test FusionConceptAI.canonical_hash(core) == artifact["deterministic_hash"]
end

@testset "Stage 3 and 4 topology grammar is capability-routed" begin
    stage3_capabilities = [
        "regional_particle_continuity_v1", "regional_ion_energy_balance_v1",
        "regional_electron_energy_balance_v1", "regional_species_balance_v1",
        "regional_actuator_fulfillment_v1", "regional_power_ledger_v1",
        "declared_boundary_flux_v1"]
    all_accounts = [:particle, :ion_energy, :electron_energy, :species, :actuator, :power]
    cases = [
        ("closed_flux", "periodic_3d", "three_dimensional_equilibrium_v2",
            "three_dimensional_equilibrium_v2_capability", "a"),
        ("open_flux", "axisymmetric_2d", "interchange_flute_v2",
            "interchange_flute_v2_capability", "b")]
    compilations = Stage34TopologyCompilationV1[]
    for (boundary, dimension, operator_id, stage4_capability, digit) in cases
        state = c2v1_state_packet(boundary, digit;
            capability_ids = vcat(stage3_capabilities, [stage4_capability]))
        node = compile_stage34_topology_node_v1("region_0"; dimension = dimension,
            boundary_class = boundary, time_mode = "steady", account_ids = all_accounts)
        edge = compile_stage34_topology_interface_v1("external_boundary", "region_0",
            nothing; account_ids = [:particle, :ion_energy, :electron_energy, :species],
            flux_capability_id = "declared_boundary_flux_v1")
        grammar = compile_stage34_topology_grammar_v1(state.candidate_binding_hash,
            [node], [edge]; required_stability_operator_ids = [operator_id])
        compiled = compile_stage34_topology_v1(state, grammar)
        @test compiled.status == :pass
        @test compiled.classification_code == "pass_stage34_topology_compilation"
        @test length(compiled.stage3_bindings) == 6
        @test length(compiled.stage4_bindings) == 1
        @test compiled.audits["stage4_requirement_source"] == "explicit_operator_ids"
        @test compiled.audits["routing_inputs"] == ["state_package", "topology_nodes",
            "interfaces", "capability_contracts"]
        push!(compilations, compiled)
    end
    @test stage34_topology_structural_projection_v1(compilations[1]) ==
        stage34_topology_structural_projection_v1(compilations[2])

    internal_state = c2v1_state_packet("closed_flux", "a";
        capability_ids = vcat(stage3_capabilities,
            ["three_dimensional_equilibrium_v2_capability"]),
        region_ids = ["region_0", "region_1"])
    nodes = [compile_stage34_topology_node_v1(id; dimension = "periodic_3d",
        boundary_class = "closed_flux", time_mode = "steady", account_ids = all_accounts)
        for id in internal_state.region_ids]
    interface = compile_stage34_topology_interface_v1("internal_0_1", "region_0",
        "region_1"; account_ids = [:particle, :ion_energy],
        flux_capability_id = "declared_boundary_flux_v1")
    grammar = compile_stage34_topology_grammar_v1(internal_state.candidate_binding_hash,
        nodes, [interface];
        required_stability_operator_ids = ["three_dimensional_equilibrium_v2"])
    internal = compile_stage34_topology_v1(internal_state, grammar)
    @test internal.status == :pass
    for account in ("particle", "ion_energy")
        records = filter(item -> item["account_id"] == account,
            internal.interface_flux_pairs)
        @test length(records) == 2
        @test sum(item["sign"] for item in records) == 0
    end

    incomplete_capabilities = filter(!=("regional_power_ledger_v1"),
        internal_state.capability_ids)
    unsupported_state = c2v1_state_packet("closed_flux", "a";
        capability_ids = incomplete_capabilities, region_ids = ["region_0", "region_1"])
    unsupported = compile_stage34_topology_v1(unsupported_state, grammar)
    @test unsupported.status == :unsupported
    @test "missing_stage3_capability:regional_power_ledger_v1" in unsupported.reasons
end

@testset "C2 schemas and uniform two-boundary audit artifact" begin
    root = normpath(joinpath(@__DIR__, ".."))
    state_schema = JSON3.read(read(joinpath(root, "schemas",
        "c2_candidate_state_package_v1.schema.json"), String))
    decision_schema = JSON3.read(read(joinpath(root, "schemas",
        "c2_decision_envelope_v1.schema.json"), String))
    @test state_schema[Symbol("\$schema")] ==
        "https://json-schema.org/draft/2020-12/schema"
    @test decision_schema[Symbol("\$schema")] ==
        "https://json-schema.org/draft/2020-12/schema"
    artifact = JSON3.read(read(joinpath(root, "runs",
        "c2_uniform_decision_panel_v1_20260824.json"), String), Dict{String,Any})
    @test artifact["source_kind"] == "manufactured_protocol_conformance"
    @test artifact["same_state_schema"] === true
    @test artifact["same_decision_chain"] === true
    @test artifact["same_topology_compiler_shape"] === true
    @test artifact["new_specialized_physics_modules_added"] === false
    @test length(artifact["entries"]) == 2
    @test Set(String(entry["boundary_class"]) for entry in artifact["entries"]) ==
        Set(["closed_flux", "open_flux"])
    for entry in artifact["entries"]
        decision = entry["decision"]
        @test decision["completeness"] == "complete"
        @test decision["candidate_conclusion"] == "fail"
        @test decision["terminate"] === true
        @test length(decision["narrow_failures"]) == 1
        @test entry["topology_compilation"]["status"] == "pass"
    end
    energy = artifact["energy_target_search"]
    @test energy["scalar_score_used"] === false
    @test isempty(energy["priority_front_binding_hashes"])
    @test length(energy["c2_terminated_binding_hashes"]) == 2
    topology_schema = JSON3.read(read(joinpath(root, "schemas",
        "stage34_topology_compilation_v1.schema.json"), String))
    energy_schema = JSON3.read(read(joinpath(root, "schemas",
        "hierarchical_energy_target_search_v1.schema.json"), String))
    @test topology_schema[Symbol("\$schema")] ==
        "https://json-schema.org/draft/2020-12/schema"
    @test energy_schema[Symbol("\$schema")] ==
        "https://json-schema.org/draft/2020-12/schema"
    grammar_source = read(joinpath(root, "src", "search",
        "stage34_topology_grammar_v1.jl"), String)
    @test !occursin("genome.family", grammar_source)
    @test !occursin("candidate_id", grammar_source)
end

function c2v1_complete_hard_failure(state::C2CandidateStatePackageV1)
    failure = compile_c2_narrow_failure_v1("actuator_capacity", "stage_3_residual",
        "fail_actuator_capacity_shortfall", :actuator;
        affected_ids = ["heating_0"],
        excluded_claims = ["other_actuators", "other_residual_blocks"],
        authoritative_for_gate = true, terminates_candidate = true,
        source_result_hash = state.state_result_hash)
    gates = C2GateDecisionV1[
        compile_c2_gate_decision_v1("stage_3_residual"; required = true,
            completeness = :complete, conclusion = :fail, narrow_failures = [failure],
            evidence_hashes = [state.state_result_hash]),
        compile_c2_gate_decision_v1("stage_4_stability"; required = true,
            completeness = :complete, conclusion = :pass,
            evidence_hashes = [state.state_result_hash]),
        compile_c2_gate_decision_v1("engineering"; required = true,
            completeness = :complete, conclusion = :pass,
            evidence_hashes = [state.state_result_hash]),
        compile_c2_gate_decision_v1("independent_evidence"; required = true,
            completeness = :complete, conclusion = :pass,
            evidence_hashes = [state.state_result_hash])]
    return compile_c2_decision_envelope_v1(state, gates)
end

function c2v1_complete_pass(state::C2CandidateStatePackageV1)
    gates = [compile_c2_gate_decision_v1(id; required = true,
        completeness = :complete, conclusion = :pass,
        evidence_hashes = [state.state_result_hash]) for id in
        ("stage_3_residual", "stage_4_stability", "engineering",
            "independent_evidence")]
    return compile_c2_decision_envelope_v1(state, gates)
end

function c2v1_unknown_decision(state::C2CandidateStatePackageV1)
    gate = compile_c2_gate_decision_v1("stage_3_residual"; required = true,
        completeness = :incomplete, conclusion = :unknown,
        evidence_tasks = ["complete_residual_evidence"])
    return compile_c2_decision_envelope_v1(state, [gate])
end

function c2v1_closed_topology(state::C2CandidateStatePackageV1)
    accounts = [:particle, :ion_energy, :electron_energy, :species, :actuator, :power]
    node = compile_stage34_topology_node_v1("region_0"; dimension = "periodic_3d",
        boundary_class = "closed_flux", time_mode = "steady", account_ids = accounts)
    edge = compile_stage34_topology_interface_v1("external_boundary", "region_0",
        nothing; account_ids = [:particle, :ion_energy, :electron_energy, :species],
        flux_capability_id = "declared_boundary_flux_v1")
    grammar = compile_stage34_topology_grammar_v1(state.candidate_binding_hash,
        [node], [edge];
        required_stability_operator_ids = ["three_dimensional_equilibrium_v2"])
    return compile_stage34_topology_v1(state, grammar)
end

@testset "C2 decision envelope keeps four decision dimensions independent" begin
    closed_state = c2v1_state_packet("closed_flux", "a")
    open_state = c2v1_state_packet("open_flux", "b")
    @test c2_state_structural_projection_v1(closed_state) ==
        c2_state_structural_projection_v1(open_state)
    @test Set(fieldnames(C2CandidateStatePackageV1)) == Set((:schema_version,
        :candidate_binding_hash, :state_result_hash, :time_mode, :boundary_classes,
        :capability_ids, :region_ids, :particle_accounts, :energy_accounts,
        :species_states, :actuator_states, :power_ledger, :evidence_fields, :package_hash))
    @test !(:family in fieldnames(C2CandidateStatePackageV1))
    @test !(:device_name in fieldnames(C2CandidateStatePackageV1))

    closed_decision = c2v1_complete_hard_failure(closed_state)
    open_decision = c2v1_complete_hard_failure(open_state)
    for decision in (closed_decision, open_decision)
        @test decision.completeness == :complete
        @test decision.candidate_conclusion == :fail
        @test length(decision.narrow_failures) == 1
        @test decision.narrow_failures[1].affected_ids == ["heating_0"]
        @test decision.terminate
        @test decision.termination_scope == :candidate_evaluation
        @test decision.termination_reason == "complete_c2_hard_failure"
    end
    @test c2_decision_structural_projection_v1(closed_decision) ==
        c2_decision_structural_projection_v1(open_decision)
end

@testset "post-physics C2 evidence is bound to the exact solved state" begin
    state = c2v1_state_packet("closed_flux", "a")
    engineering = compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash, gate_id = "engineering",
        status = :pass,
        obligation_ids = ["structural_margin", "thermal_margin", "quench_margin"],
        evidence_hashes = [repeat("b", 64)],
        claim_boundary = "Candidate-bound engineering checks on the shared state.")
    independent = compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash,
        gate_id = "independent_evidence", status = :fail,
        obligation_ids = ["independent_residual", "uncertainty_interval"],
        failed_obligation_ids = ["uncertainty_interval"],
        evidence_hashes = [repeat("c", 64)],
        claim_boundary = "Independent recomputation and uncertainty interval only.")
    engineering_gate = c2_gate_from_bound_evidence_v1(state, engineering)
    independent_gate = c2_gate_from_bound_evidence_v1(state, independent)
    @test engineering_gate.completeness == :complete
    @test engineering_gate.conclusion == :pass
    @test independent_gate.completeness == :complete
    @test independent_gate.conclusion == :fail
    @test only(independent_gate.narrow_failures).affected_ids ==
        ["uncertainty_interval"]
    @test !only(independent_gate.narrow_failures).terminates_candidate
    residual_gate = compile_c2_gate_decision_v1("stage_3_residual";
        required = true, completeness = :complete, conclusion = :pass,
        evidence_hashes = [state.state_result_hash])
    stability_gate = compile_c2_gate_decision_v1("stage_4_stability";
        required = true, completeness = :complete, conclusion = :pass,
        evidence_hashes = [state.state_result_hash])
    decision = compile_c2_decision_envelope_v1(state,
        [residual_gate, stability_gate, engineering_gate, independent_gate])
    @test decision.completeness == :complete
    @test decision.candidate_conclusion == :fail
    @test decision.terminate
    @test decision.termination_reason == "complete_c2_hard_failure"
    @test c2_bound_gate_evidence_to_dict_v1(independent)["evidence_bundle_hash"] ==
        independent.evidence_bundle_hash
    engineering_result = EngineeringMultiphysicsResultEnvelopeV1("1.0.0",
        "metadata_only_candidate_id", state.candidate_binding_hash,
        state.state_result_hash, repeat("4", 64), repeat("5", 64),
        repeat("6", 64), repeat("7", 64), repeat("8", 64), :pass,
        "converged_exact_lumped_balances", Dict{String,Any}[],
        [Dict{String,Any}("check_id" => "thermal_margin", "status" => "pass")],
        Dict{String,Any}[], Dict{String,Any}[], String[],
        "Candidate-bound engineering fixture.", repeat("9", 64))
    adapted_engineering = compile_c2_engineering_evidence_v1(state,
        engineering_result)
    @test adapted_engineering.status == :pass
    @test adapted_engineering.obligation_ids == ["thermal_margin"]
    @test adapted_engineering.state_result_hash == state.state_result_hash
    wrong_state = c2v1_state_packet("closed_flux", "d")
    @test_throws ArgumentError c2_gate_from_bound_evidence_v1(wrong_state, engineering)
    @test_throws ArgumentError compile_c2_engineering_evidence_v1(wrong_state,
        engineering_result)
    @test_throws ArgumentError compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash, gate_id = "engineering",
        status = :fail, obligation_ids = ["thermal_margin"],
        evidence_hashes = [repeat("e", 64)], claim_boundary = "Missing failure scope.")
    terminal_engineering = compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash, gate_id = "engineering",
        status = :fail, obligation_ids = ["necessary_field_source"],
        failed_obligation_ids = ["necessary_field_source"],
        evidence_hashes = [repeat("f", 64)], terminates_candidate = true,
        claim_boundary = "Necessary selected-assembly failure fixture.")
    terminal_gate = c2_gate_from_bound_evidence_v1(state, terminal_engineering)
    @test only(terminal_gate.narrow_failures).terminates_candidate
    terminal_partial = compile_c2_decision_envelope_v1(state,
        [terminal_gate, compile_c2_gate_decision_v1("stage_3_residual";
            required = true, completeness = :incomplete, conclusion = :unknown,
            evidence_tasks = ["complete_residual_evidence"])])
    @test terminal_partial.completeness == :incomplete
    @test terminal_partial.candidate_conclusion == :fail
    @test terminal_partial.terminate
    @test_throws ArgumentError compile_c2_bound_gate_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash, gate_id = "engineering",
        status = :pass, obligation_ids = ["necessary_field_source"],
        evidence_hashes = [repeat("f", 64)], terminates_candidate = true,
        claim_boundary = "Invalid terminal pass fixture.")
    schema = JSON3.read(read(joinpath(@__DIR__, "..", "schemas",
        "c2_bound_gate_evidence_v1.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    interval_schema = JSON3.read(read(joinpath(@__DIR__, "..", "schemas",
        "c2_uncertainty_interval_evidence_v1.schema.json"), String))
    @test interval_schema[Symbol("\$schema")] ==
        "https://json-schema.org/draft/2020-12/schema"
    @test_throws ArgumentError compile_c2_uncertainty_interval_evidence_v1(
        candidate_binding_hash = state.candidate_binding_hash,
        state_result_hash = state.state_result_hash, quantity_id = "net_power",
        lower = 2.0, upper = 1.0, unit = "W", coverage_probability = 0.95,
        method = "invalid_order", source_result_hash = repeat("3", 64))
end

@testset "auxiliary failure is retained without candidate-failure propagation" begin
    state = c2v1_state_packet("open_flux", "b")
    auxiliary_failure = compile_c2_narrow_failure_v1("local_diagnostic",
        "auxiliary_diagnostic", "fail_local_diagnostic", :operator;
        affected_ids = ["local_operator"], excluded_claims = ["complete_stability"],
        authoritative_for_gate = true, terminates_candidate = false,
        source_result_hash = state.state_result_hash)
    required_gate = compile_c2_gate_decision_v1("stage_4_stability"; required = true,
        completeness = :incomplete, conclusion = :unknown,
        evidence_tasks = ["complete_required_operator"])
    auxiliary_gate = compile_c2_gate_decision_v1("auxiliary_diagnostic"; required = false,
        completeness = :complete, conclusion = :fail,
        narrow_failures = [auxiliary_failure], evidence_hashes = [state.state_result_hash])
    decision = compile_c2_decision_envelope_v1(state, [required_gate, auxiliary_gate])
    @test decision.completeness == :incomplete
    @test decision.candidate_conclusion == :unknown
    @test length(decision.narrow_failures) == 1
    @test !decision.terminate
    @test decision.termination_scope == :none
    @test isempty(decision.failed_gate_ids)

    terminal_failure = compile_c2_narrow_failure_v1("necessary_condition",
        "stage_3_residual", "fail_nonrecoverable_capacity", :actuator;
        affected_ids = ["heating_0"], excluded_claims = ["unrelated_accounts"],
        authoritative_for_gate = true, terminates_candidate = true,
        source_result_hash = state.state_result_hash)
    partial_failed_gate = compile_c2_gate_decision_v1("stage_3_residual";
        required = true, completeness = :incomplete, conclusion = :fail,
        narrow_failures = [terminal_failure],
        evidence_tasks = ["complete_unrelated_residual_blocks"])
    terminal = compile_c2_decision_envelope_v1(state, [partial_failed_gate])
    @test terminal.completeness == :incomplete
    @test terminal.candidate_conclusion == :fail
    @test terminal.terminate
    @test terminal.termination_reason == "authoritative_terminal_failure"
end

@testset "hierarchical energy target search preserves gates and Pareto coordinates" begin
    capabilities = [
        "regional_particle_continuity_v1", "regional_ion_energy_balance_v1",
        "regional_electron_energy_balance_v1", "regional_species_balance_v1",
        "regional_actuator_fulfillment_v1", "regional_power_ledger_v1",
        "declared_boundary_flux_v1", "three_dimensional_equilibrium_v2_capability"]
    powers = Dict(
        "a" => Dict("net_electric_lower_bound" => 20.0,
            "wall_input_power" => 50.0, "actuator_delivered_power" => 20.0),
        "b" => Dict("net_electric_lower_bound" => 25.0,
            "wall_input_power" => 60.0, "actuator_delivered_power" => 25.0),
        "e" => Dict("net_electric_lower_bound" => 15.0,
            "wall_input_power" => 70.0, "actuator_delivered_power" => 28.0),
        "f" => Dict("net_electric_lower_bound" => 30.0,
            "wall_input_power" => 40.0, "actuator_delivered_power" => 18.0),
        "9" => Dict("net_electric_lower_bound" => 5.0,
            "wall_input_power" => 45.0, "actuator_delivered_power" => 18.0))
    states = Dict(digit => c2v1_state_packet("closed_flux", digit;
        capability_ids = capabilities, power_overrides = values)
        for (digit, values) in powers)
    topologies = Dict(digit => c2v1_closed_topology(state)
        for (digit, state) in states)
    decisions = Dict(
        "a" => c2v1_complete_pass(states["a"]),
        "b" => c2v1_complete_pass(states["b"]),
        "e" => c2v1_unknown_decision(states["e"]),
        "f" => c2v1_complete_hard_failure(states["f"]),
        "9" => c2v1_complete_pass(states["9"]))
    inputs = [compile_energy_search_input_v1(states[digit], topologies[digit],
        decisions[digit]) for digit in sort!(collect(keys(states)))]
    objectives = [
        compile_energy_objective_spec_v1("net_lower_bound",
            "net_electric_lower_bound", :maximize; tier = 1, target = 10.0,
            scale = 10.0, unit = "W"),
        compile_energy_objective_spec_v1("wall_input", "wall_input_power", :minimize;
            tier = 2, target = 80.0, scale = 10.0, unit = "W"),
        compile_energy_objective_spec_v1("delivered_actuation",
            "actuator_delivered_power", :minimize; tier = 2, target = 30.0,
            scale = 10.0, unit = "W")]
    result = search_hierarchical_energy_targets_v1(inputs, objectives)
    @test result.scalar_score_used === false
    @test result.priority_front_binding_hashes == [repeat("b", 64)]
    @test result.target_shortfall_binding_hashes == [repeat("9", 64)]
    @test result.c2_terminated_binding_hashes == [repeat("f", 64)]
    @test result.evidence_queue_binding_hashes == [repeat("e", 64)]
    @test isempty(result.topology_rejected_binding_hashes)
    by_binding = Dict(entry.candidate_binding_hash => entry for entry in result.entries)
    @test by_binding[repeat("f", 64)].objective_coordinates == Dict{String,Any}[]
    @test by_binding[repeat("e", 64)].disposition == :evidence_queue
    @test by_binding[repeat("9", 64)].disposition == :target_shortfall
    @test all(length(by_binding[repeat(digit, 64)].objective_coordinates) == 3
        for digit in ("a", "b", "9"))
end

@testset "real fixed-panel candidates enter one label-free C2 chain" begin
    root = normpath(joinpath(@__DIR__, ".."))
    panel_path = joinpath(root, "fixtures", "candidate_v68_real_panel_v1.json")
    stage4_path = joinpath(root, "fixtures", "candidate_stage4_real_panel_v2.json")
    panel = load_candidate_v68_real_panel_v1(panel_path)
    typed_results = Dict{String,RealCandidatePanelCompilationV1}()
    for entry in panel["entries"]
        typed_results[entry.panel_entry_id] = compile_real_candidate_panel_entry_v1(
            entry, root, panel["required_obligations"])
    end
    stage4 = audit_candidate_stage4_real_panel_v2(panel_path, stage4_path; root = root)
    stage4_by_id = Dict(String(row["panel_entry_id"]) => row["compilation"]
        for row in stage4["rows"])
    selected = ["closed_candidate_pool24", "open_candidate_mirror_low_force"]
    states = C2CandidateStatePackageV1[]
    decisions = C2DecisionEnvelope[]
    for id in selected
        result = typed_results[id]
        state = compile_real_candidate_state_package_v1(result)
        decision = compile_real_candidate_c2_decision_v1(state, result,
            stage4_by_id[id])
        @test state.candidate_binding_hash == result.candidate_binding_hash
        @test all(item -> item.value === nothing,
            vcat(state.particle_accounts, state.energy_accounts,
                state.power_ledger.accounts))
        @test all(item -> item.demand === nothing && item.output === nothing &&
            item.capacity === nothing && item.wall_plug_efficiency === nothing,
            state.actuator_states)
        @test decision.completeness == :incomplete
        @test decision.candidate_conclusion == :unknown
        @test !decision.terminate
        @test decision.required_gate_ids == ["engineering", "independent_evidence",
            "stage_3_residual", "stage_4_stability"]
        engineering_gate = only(filter(item -> item.gate_id == "engineering",
            decision.gate_decisions))
        independent_gate = only(filter(item -> item.gate_id == "independent_evidence",
            decision.gate_decisions))
        @test engineering_gate.completeness == :incomplete
        @test independent_gate.completeness == :incomplete
        if id == "closed_candidate_pool24"
            engineering_evidence = compile_c2_bound_gate_evidence_v1(
                candidate_binding_hash = state.candidate_binding_hash,
                state_result_hash = state.state_result_hash, gate_id = "engineering",
                status = :pass, obligation_ids = ["engineering_constraints"],
                evidence_hashes = [repeat("1", 64)],
                claim_boundary = "Exact-state override fixture.")
            independent_evidence = compile_c2_bound_gate_evidence_v1(
                candidate_binding_hash = state.candidate_binding_hash,
                state_result_hash = state.state_result_hash,
                gate_id = "independent_evidence", status = :pass,
                obligation_ids = ["independent_residual", "uncertainty_interval"],
                evidence_hashes = [repeat("2", 64)],
                claim_boundary = "Exact-state override fixture.")
            overridden = compile_real_candidate_c2_decision_v1(state, result,
                stage4_by_id[id]; engineering_evidence = engineering_evidence,
                independent_evidence = independent_evidence)
            @test Set(overridden.complete_gate_ids) ==
                Set(["engineering", "independent_evidence"])
            @test overridden.completeness == :incomplete
        end
        stability_gate = only(filter(item -> item.gate_id == "stage_4_stability",
            decision.gate_decisions))
        shared_state_tasks = filter(task -> startswith(task,
            "recompute_stability_operator_on_shared_state:"),
            stability_gate.evidence_tasks)
        if id == "closed_candidate_pool24"
            @test length(shared_state_tasks) == 4
            @test all(occursin(state.state_result_hash, task) for task in shared_state_tasks)
        else
            @test isempty(shared_state_tasks)
        end
        readiness = compile_candidate_longitudinal_input_readiness_v1(state)
        @test readiness.status == :unknown
        @test length(readiness.requirements) == 56
        @test length(readiness.missing_input_ids) == 56
        push!(states, state); push!(decisions, decision)
    end
    @test c2_state_structural_projection_v1(states[1]) ==
        c2_state_structural_projection_v1(states[2])
    @test decisions[1].required_gate_ids == decisions[2].required_gate_ids
    @test isempty(decisions[1].narrow_failures)
    @test length(decisions[2].narrow_failures) == 2
    @test all(!item.terminates_candidate for item in decisions[2].narrow_failures)
    state_dict = c2_candidate_state_package_to_dict_v1(states[1])
    @test !haskey(state_dict, "candidate_id")
    @test !haskey(state_dict, "family")
    @test !haskey(state_dict, "device_name")

    artifact = JSON3.read(read(joinpath(root, "runs",
        "real_candidate_uniform_c2_chain_v1_20260825.json"), String),
        Dict{String,Any})
    @test artifact["source_kind"] == "real_candidate_bound_inventory"
    @test artifact["same_state_shape"] === true
    @test artifact["same_required_gate_chain"] === true
    @test artifact["complete_c2_count"] == 0
    @test artifact["terminal_count"] == 0
    @test artifact["unknown_count"] == 2
    @test all(entry -> entry["real_numeric_value_count"] == 0 &&
        entry["missing_numeric_value_count"] == entry["real_numeric_slot_count"],
        artifact["entries"])
    core = deepcopy(artifact); delete!(core, "deterministic_hash")
    @test FusionConceptAI.canonical_hash(core) == artifact["deterministic_hash"]
end

@testset "candidate-bound longitudinal input readiness rejects template substitution" begin
    root = normpath(joinpath(@__DIR__, ".."))
    schema = JSON3.read(read(joinpath(root, "schemas",
        "candidate_longitudinal_input_readiness_v1.schema.json"), String))
    @test schema[Symbol("\$schema")] ==
        "https://json-schema.org/draft/2020-12/schema"
    state = c2v1_state_packet("closed_flux", "a")
    forbidden = Dict{String,Dict{String,Any}}(
        "parameter:charge_a" => Dict("value" => 1.0, "unit" => "1",
            "evidence_status" => "complete", "source_kind" => "device_template",
            "source_result_hash" => repeat("1", 64)))
    rejected = compile_candidate_longitudinal_input_readiness_v1(state;
        overlays = forbidden)
    @test rejected.status == :unsupported
    @test rejected.unsupported_input_ids == ["parameter:charge_a"]

    empty_readiness = compile_candidate_longitudinal_input_readiness_v1(state)
    overlays = Dict{String,Dict{String,Any}}()
    for requirement in empty_readiness.requirements
        value = 1.0
        if requirement.input_id in ("parameter:fuel_fraction_a",
                "parameter:fuel_fraction_b", "parameter:exhaust_fraction_a",
                "parameter:exhaust_fraction_b", "parameter:alpha_ion_fraction",
                "parameter:alpha_electron_fraction")
            value = 0.5
        elseif occursin("efficiency", requirement.input_id)
            value = 0.5
        end
        overlays[requirement.input_id] = Dict("value" => value,
            "unit" => requirement.unit, "evidence_status" => "complete",
            "source_kind" => "candidate_solver",
            "source_result_hash" => repeat("2", 64))
    end
    ready = compile_candidate_longitudinal_input_readiness_v1(state;
        overlays = overlays)
    @test ready.status == :pass
    @test isempty(ready.missing_input_ids)
    module_instance, initials = compile_candidate_longitudinal_module_from_readiness_v1(
        ready; module_id = "candidate_longitudinal", region_id = "primary_region",
        transport_operator_id = "declared_transport")
    @test length(module_instance.parameters) == 46
    @test length(initials) == 10
    @test validity_domain(module_instance)["status"] == "applicable"

    anchors_path = joinpath(root, "fixtures", "candidate_solver_reference_anchors_v1.json")
    anchors = JSON3.read(read(anchors_path, String), Dict{String,Any})["anchors"]
    anchor = first(anchors)
    source_hash = bytes2hex(SHA.sha256(read(anchors_path)))
    anchor_overlays = compile_reference_anchor_longitudinal_overlays_v1(anchor,
        source_hash; source_kind = :published_candidate_design_input)
    anchor_readiness = compile_candidate_longitudinal_input_readiness_v1(state;
        overlays = anchor_overlays)
    @test count(item -> item.evidence_status == :complete,
        anchor_readiness.requirements) == 5
    @test length(anchor_readiness.missing_input_ids) == 51
    @test anchor_readiness.status == :unknown

    coverage = JSON3.read(read(joinpath(root, "runs",
        "fixed_panel_longitudinal_coverage_v1_20260825.json"), String),
        Dict{String,Any})
    @test length(coverage["rows"]) == 10
    coverage_by_id = Dict(String(row["panel_entry_id"]) => row
        for row in coverage["rows"])
    @test coverage_by_id["closed_positive_iter"]["longitudinal_complete_input_count"] == 5
    @test coverage_by_id["open_positive_c2w"]["longitudinal_complete_input_count"] == 5
    @test coverage_by_id["closed_candidate_pool24"]["longitudinal_complete_input_count"] == 1
    @test coverage_by_id["open_candidate_mirror_low_force"]["longitudinal_complete_input_count"] == 0
    @test Set(coverage["readiness_selection"]["closed_flux"]["candidate_front_entry_ids"]) ==
        Set(["closed_candidate_pool24", "closed_candidate_pool56"])
    @test Set(coverage["readiness_selection"]["open_flux"]["candidate_front_entry_ids"]) ==
        Set(["open_candidate_mirror_high_ratio", "open_candidate_mirror_low_force"])
    desc_energy = JSON3.read(read(joinpath(root, "runs",
        "candidate_desc_scalar_pressure_energy_v1_20260825.json"), String),
        Dict{String,Any})
    pool24_binding = String(first(desc_energy["candidates"])["candidate_binding_hash"])
    desc_overlays = compile_desc_candidate_scalar_pressure_energy_overlays_v1(
        desc_energy, pool24_binding)
    @test collect(keys(desc_overlays)) == ["parameter:energy_scale"]
    @test desc_overlays["parameter:energy_scale"]["value"] > 0
    widened = deepcopy(desc_energy)
    widened["candidates"][1]["authorized_longitudinal_input_ids"] =
        ["initial:ion_thermal_energy", "parameter:energy_scale"]
    @test_throws ArgumentError compile_desc_candidate_scalar_pressure_energy_overlays_v1(
        widened, pool24_binding)

    binding = repeat("9", 64)
    species = SpeciesPopulationSpecV1[
        SpeciesPopulationSpecV1("electron", :electron, -1, 9.1093837139e-31, true),
        SpeciesPopulationSpecV1("deuterium", :fuel_ion, 1, 3.344e-27, true),
        SpeciesPopulationSpecV1("tritium", :fuel_ion, 1, 5.008e-27, true)]
    species_problem = RuntimeSpeciesStateProblemV1(
        "runtime_species_state_compiler_v1.0.0", "candidate_state_fixture",
        binding, "D-T", ["plasma"], true, species,
        RuntimeSpeciesStateRequirementV1[], String[], repeat("8", 64))
    inventories = Dict(
        "plasma:deuterium:particle_inventory" => 2.0e20,
        "plasma:tritium:particle_inventory" => 3.0e20,
        "plasma:electron:particle_inventory" => 5.0e20)
    energies = Dict(
        "plasma:deuterium:thermal_energy" => 2.0e5,
        "plasma:tritium:thermal_energy" => 3.0e5,
        "plasma:electron:thermal_energy" => 5.0e5)
    species_assessment = RuntimeSpeciesStateAssessmentV1(
        "candidate_state_fixture", binding, :pass, true, true, false,
        inventories, Dict{String,Float64}(), Dict{String,Vector{Float64}}(),
        energies, Dict{String,Float64}(), Dict("plasma" => 0.0),
        Dict("plasma" => 0.0), String[], String[], String[], repeat("7", 64))
    state_overlays = compile_runtime_species_state_longitudinal_overlays_v1(
        species_problem, species_assessment, binding)
    @test length(state_overlays) == 9
    @test state_overlays["initial:fuel_a_inventory"]["value"] == 2.0e20
    @test state_overlays["initial:fuel_b_inventory"]["value"] == 3.0e20
    @test state_overlays["initial:electron_inventory"]["value"] == 5.0e20
    @test state_overlays["initial:ion_thermal_energy"]["value"] == 5.0e5
    @test state_overlays["parameter:energy_scale"]["value"] == 1.0e6
    @test !haskey(state_overlays, "parameter:target_particle_inventory")
    rejected_assessment = RuntimeSpeciesStateAssessmentV1(
        "candidate_state_fixture", binding, :unknown, true, false, false,
        inventories, Dict{String,Float64}(), Dict{String,Vector{Float64}}(),
        energies, Dict{String,Float64}(), Dict("plasma" => 0.0),
        Dict("plasma" => 0.0), String[], String[], String[], repeat("6", 64))
    @test_throws ArgumentError compile_runtime_species_state_longitudinal_overlays_v1(
        species_problem, rejected_assessment, binding)
    coverage_core = deepcopy(coverage); delete!(coverage_core, "deterministic_hash")
    @test FusionConceptAI.canonical_hash(coverage_core) == coverage["deterministic_hash"]
end
