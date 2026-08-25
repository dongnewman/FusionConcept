const STAGE34_V2_ACCOUNTS = [:particle, :ion_energy, :electron_energy,
    :species, :actuator, :power]
const STAGE34_V2_STAGE3_CAPABILITIES = [
    "regional_particle_continuity_v1", "regional_ion_energy_balance_v1",
    "regional_electron_energy_balance_v1", "regional_species_balance_v1",
    "regional_actuator_fulfillment_v1", "regional_power_ledger_v1",
    "declared_boundary_flux_v1", "field_source_port_v2",
    "energy_source_port_v2", "sensor_port_v2", "control_port_v2",
    "actuator_port_v2", "heat_rejection_port_v2"]

function stage34v2_state(boundary::String, digit::String)
    operator_capability = boundary == "closed_flux" ?
        "three_dimensional_equilibrium_v2_capability" :
        "interchange_flute_v2_capability"
    return c2v1_state_packet(boundary, digit;
        capability_ids = vcat(STAGE34_V2_STAGE3_CAPABILITIES, [operator_capability]))
end

function stage34v2_grammar(state::C2CandidateStatePackageV1, boundary::String)
    dimension = boundary == "closed_flux" ? "periodic_3d" : "axisymmetric_2d"
    operator = boundary == "closed_flux" ? "three_dimensional_equilibrium_v2" :
        "interchange_flute_v2"
    node = compile_stage34_topology_node_v1("region_0"; dimension = dimension,
        boundary_class = boundary, time_mode = "steady",
        account_ids = STAGE34_V2_ACCOUNTS)
    interface = compile_stage34_topology_interface_v1("external_boundary", "region_0",
        nothing; account_ids = [:particle, :ion_energy, :electron_energy, :species],
        flux_capability_id = "declared_boundary_flux_v1")
    base = compile_stage34_topology_grammar_v1(state.candidate_binding_hash,
        [node], [interface]; required_stability_operator_ids = [operator])
    ports = Stage34PortSpecV2[
        compile_stage34_port_v2("interface_flux", "region_0";
            port_kind = :flux, direction = :bidirectional,
            resource_ids = ["particle", "ion_energy", "electron_energy", "species"],
            capability_id = "declared_boundary_flux_v1"),
        compile_stage34_port_v2("field_source", "region_0";
            port_kind = :field_source, direction = :output,
            resource_ids = ["field_state"], capability_id = "field_source_port_v2",
            exclusive_output = true),
        compile_stage34_port_v2("energy_source", "region_0";
            port_kind = :energy_source, direction = :output,
            resource_ids = ["thermal_energy"], capability_id = "energy_source_port_v2"),
        compile_stage34_port_v2("state_sensor", "region_0";
            port_kind = :sensor, direction = :output, resource_ids = ["state_vector"],
            capability_id = "sensor_port_v2"),
        compile_stage34_port_v2("control", "region_0";
            port_kind = :control, direction = :bidirectional,
            resource_ids = ["state_vector", "actuator_command"],
            capability_id = "control_port_v2"),
        compile_stage34_port_v2("actuator", "region_0";
            port_kind = :actuator, direction = :input,
            resource_ids = ["actuator_command"], capability_id = "actuator_port_v2"),
        compile_stage34_port_v2("heat_rejection", "region_0";
            port_kind = :heat_rejection, direction = :input,
            resource_ids = ["thermal_energy"], capability_id = "heat_rejection_port_v2"),
        compile_stage34_port_v2("boundary_flux", "region_0";
            port_kind = :boundary, direction = :bidirectional,
            resource_ids = ["particle", "ion_energy", "electron_energy", "species",
                "field_state"], capability_id = "declared_boundary_flux_v1")]
    dependencies = Stage34DependencyV2[
        compile_stage34_dependency_v2("field_to_boundary", "field_source",
            "boundary_flux"; dependency_kind = :field),
        compile_stage34_dependency_v2("energy_to_rejection", "energy_source",
            "heat_rejection"; dependency_kind = :energy),
        compile_stage34_dependency_v2("sensor_to_control", "state_sensor", "control";
            dependency_kind = :data),
        compile_stage34_dependency_v2("control_to_actuator", "control", "actuator";
            dependency_kind = :control)]
    obligations = Stage34ObligationV2[
        compile_stage34_obligation_v2("conservation_obligation";
            obligation_kind = :conservation,
            subject_ids = ["region_0", "external_boundary"],
            required_capability_ids = ["regional_particle_continuity_v1",
                "regional_power_ledger_v1", "declared_boundary_flux_v1"],
            required_evidence_field_ids = ["conservation", "interface_flux"],
            claim_boundary = "Only declared state slots and paired boundary fluxes."),
        compile_stage34_obligation_v2("causal_obligation";
            obligation_kind = :causal,
            subject_ids = ["sensor_to_control", "control_to_actuator"],
            required_capability_ids = ["sensor_port_v2", "control_port_v2",
                "actuator_port_v2"],
            required_evidence_field_ids = ["actuator_fulfillment"],
            claim_boundary = "Only the declared sensor-control-actuator path."),
        compile_stage34_obligation_v2("validity_obligation";
            obligation_kind = :validity, subject_ids = ["region_0", "field_source"],
            required_evidence_field_ids = ["validity_domain", "physical_bounds"],
            claim_boundary = "Only the declared solved-state validity evidence."),
        compile_stage34_obligation_v2("boundary_obligation";
            obligation_kind = :boundary,
            subject_ids = ["external_boundary", "boundary_flux"],
            required_capability_ids = ["declared_boundary_flux_v1"],
            required_evidence_field_ids = ["interface_flux"],
            claim_boundary = "Only the explicitly paired boundary flux."),
        compile_stage34_obligation_v2("evidence_obligation";
            obligation_kind = :evidence, subject_ids = ["region_0"],
            required_evidence_field_ids = ["resolution_trend", "jacobian_audit",
                "independent_residual_audit"],
            claim_boundary = "No promotion beyond the enumerated evidence fields.")]
    return compile_stage34_topology_grammar_v2(base; symmetry_id = "declared_symmetry",
        ports = ports, dependencies = dependencies, obligations = obligations)
end

@testset "Stage 3 and 4 topology grammar v2 is structural and label-free" begin
    closed = stage34v2_state("closed_flux", "1")
    open = stage34v2_state("open_flux", "2")
    closed_grammar = stage34v2_grammar(closed, "closed_flux")
    open_grammar = stage34v2_grammar(open, "open_flux")
    closed_result = compile_stage34_topology_v2(closed, closed_grammar)
    open_result = compile_stage34_topology_v2(open, open_grammar)
    @test closed_result.status == :pass
    @test open_result.status == :pass
    @test stage34_topology_structural_projection_v2(closed_result) ==
        stage34_topology_structural_projection_v2(open_result)
    @test closed_result.audits["label_routing_used"] === false
    @test closed_result.audits["immediate_dependency_dag"] == "pass"
    @test Set(fieldnames(Stage34TopologyGrammarV2)) == Set((:schema_version,
        :base_grammar, :symmetry_id, :ports, :dependencies, :obligations, :grammar_hash))
    for forbidden in (:family, :device_name, :candidate_name, :route)
        @test !(forbidden in fieldnames(Stage34TopologyGrammarV2))
        @test !(forbidden in fieldnames(Stage34TopologyMutationV2))
    end

    missing_capability = c2v1_state_packet("closed_flux", "3";
        capability_ids = filter(!=("field_source_port_v2"),
            vcat(STAGE34_V2_STAGE3_CAPABILITIES,
                ["three_dimensional_equilibrium_v2_capability"])))
    missing_result = compile_stage34_topology_v2(missing_capability,
        stage34v2_grammar(missing_capability, "closed_flux"))
    @test missing_result.status == :unsupported
    @test "missing_port_capability:field_source_port_v2" in missing_result.reasons

    boundary_mutation = compile_stage34_topology_mutation_v2("change_boundary",
        :set_boundary, Dict("node_id" => "region_0", "boundary_class" => "open_flux"))
    _, boundary_result = compile_stage34_topology_mutation_v2(closed, closed_grammar,
        boundary_mutation)
    @test boundary_result.status == :fail
    @test "node_boundary_not_declared_by_state_package" in boundary_result.reasons

    competing = compile_stage34_topology_mutation_v2("competing_source", :add_port,
        Dict("port" => Dict("port_id" => "field_source_2", "node_id" => "region_0",
            "port_kind" => "field_source", "direction" => "output",
            "resource_ids" => ["field_state"],
            "capability_id" => "field_source_port_v2", "exclusive_output" => true)))
    _, competing_result = compile_stage34_topology_mutation_v2(closed, closed_grammar,
        competing)
    @test competing_result.status == :fail
    @test any(startswith(reason, "competing_exclusive_output")
        for reason in competing_result.reasons)

    cycle = compile_stage34_topology_mutation_v2("immediate_cycle", :add_dependency,
        Dict("dependency" => Dict("dependency_id" => "boundary_to_field",
            "source_port_id" => "boundary_flux", "target_port_id" => "field_source",
            "dependency_kind" => "field", "delayed" => false)))
    _, cycle_result = compile_stage34_topology_mutation_v2(closed, closed_grammar, cycle)
    @test cycle_result.status == :fail
    @test "undeclared_immediate_causal_cycle" in cycle_result.reasons
    @test_throws ArgumentError compile_stage34_topology_mutation_v2("bad_label",
        :set_symmetry, Dict("family" => "forbidden", "symmetry_id" => "x"))

    root = normpath(joinpath(@__DIR__, ".."))
    schema = JSON3.read(read(joinpath(root, "schemas",
        "stage34_topology_compilation_v2.schema.json"), String))
    @test schema[Symbol("\$schema")] == "https://json-schema.org/draft/2020-12/schema"
    source = read(joinpath(root, "src", "search", "stage34_topology_grammar_v2.jl"), String)
    @test !occursin("genome.family", source)
    @test !occursin("device_name", source)
    @test !occursin("candidate_name", source)
end
