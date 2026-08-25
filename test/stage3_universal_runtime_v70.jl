using Test
using FusionConceptAI
using JSON3

function v70_topology(dimension::String, time_mode::String;
        region_id = "domain", unit_variant = false, reverse_ports = false)
    base = generate_graph_native_topology_v69(4)
    regions = deepcopy(base.regions)
    original_region = String(regions[1]["region_id"])
    regions[1]["region_id"] = region_id
    regions[1]["dimension"] = dimension
    regions[1]["time_mode"] = time_mode
    regions[1]["boundary_class"] = "mixed"
    regions[1]["state_slots"] = deepcopy(regions[1]["state_slots"][1:5])
    if unit_variant
        for slot in regions[1]["state_slots"]
            slot["unit"] == "particle" && (slot["unit"] = "particles")
        end
    end
    regions[1]["algebraic_slots"] = time_mode == "dae" ? ["constraint_1"] : String[]
    ports = deepcopy(base.ports)
    for port in ports
        port["region_id"] = region_id
    end
    reverse_ports && reverse!(ports)
    interfaces = deepcopy(base.interfaces)
    for interface in interfaces
        interface["source_region_id"] == original_region &&
            (interface["source_region_id"] = region_id)
        get(interface, "target_region_id", nothing) == original_region &&
            (interface["target_region_id"] = region_id)
    end
    topology = compile_graph_native_topology_v69(regions = regions,
        interfaces = interfaces, ports = ports,
        dependencies = deepcopy(base.dependencies), symmetry = base.symmetry,
        obligations = deepcopy(base.obligations))
    return topology, compile_graph_native_topology_candidate_v69(topology)
end

function v70_request(dimension, time_mode, model;
        extras = Dict{String,Any}(), sample_count = 1,
        levels = [16, 64, 256], region_id = "domain", unit_variant = false,
        reverse_ports = false, maximum_time_steps = 512)
    topology, compilation = v70_topology(dimension, time_mode;
        region_id = region_id, unit_variant = unit_variant,
        reverse_ports = reverse_ports)
    binding = Dict{String,Any}("execution_model" => model)
    merge!(binding, extras)
    budget = Stage3ExecutionBudgetV1(maximum_wall_seconds = 30.0,
        maximum_time_steps = maximum_time_steps,
        maximum_degrees_of_freedom = 20_000,
        resolution_levels = levels)
    return compile_stage3_execution_request_v1(topology, compilation;
        parameter_binding = binding,
        sample_spec = Dict{String,Any}("required_sample_count" => sample_count,
            "dimension" => 2, "sequence" => "halton_v1"), budget = budget)
end

function v70_execute(dimension, time_mode, model; kwargs...)
    request = v70_request(dimension, time_mode, model; kwargs...)
    plan, evidence = execute_stage3_request_v1(request)
    return request, plan, evidence
end

@testset "v70 T0-T3 contracts, Physics IR and capability routing" begin
    registry = default_stage3_capability_registry_v1()
    @test length(registry.capabilities) >= 12
    @test length(registry.registry_hash) == 64
    request = v70_request("0d", "steady", Dict("kind" => "nonlinear_balance",
        "source" => [1.0, 2.0], "decay" => [1.0, 2.0],
        "quadratic" => [0.1, 0.2]))
    plan = compile_stage3_execution_plan_v1(request)
    @test plan.completeness == :complete
    @test plan.classification_code == "stage3_plan_compiled"
    @test plan.numerical_ir !== nothing
    @test all(region.time_semantics == :steady for region in plan.numerical_ir.regions)
    @test all(region.spatial_dimension == 0 for region in plan.numerical_ir.regions)
    @test length(plan.solve_plan_hash) == 64
    @test !isempty(plan.state_layout)
    @test !isempty(plan.residual_plan)
    @test !Bool(stage3_execution_plan_to_dict_v1(plan)["backend_native_objects_present"])
    @test all(item["status"] == "supported" for item in plan.capability_matches)

    dae_request = v70_request("0d", "dae", Dict("kind" => "index1_dae"))
    dae_plan = compile_stage3_execution_plan_v1(dae_request)
    @test any(!item["differential"] for item in dae_plan.state_layout)
    @test any(item["diagonal"] == 0.0 for item in dae_plan.mass_matrix_plan)
    @test :index1_dae in getfield.(dae_plan.numerical_ir.regions, :time_semantics)

    label_request = v70_request("0d", "steady", Dict("kind" =>
        "generic_graph_balance"); extras = Dict("family" => "alpha",
        "device_type" => "beta", "candidate_label" => "gamma"))
    erased_request = v70_request("0d", "steady", Dict("kind" =>
        "generic_graph_balance"))
    @test label_request.candidate_binding_hash == erased_request.candidate_binding_hash
    @test compile_stage3_execution_plan_v1(label_request).solve_plan_hash ==
        compile_stage3_execution_plan_v1(erased_request).solve_plan_hash
end

@testset "v70 T4 positive manufactured and coupled controls" begin
    positive = Tuple{String,String,Dict{String,Any}}[
        ("0d", "steady", Dict("kind" => "nonlinear_balance",
            "source" => [1.0, 0.8], "decay" => [1.0, 1.5],
            "quadratic" => [0.2, 0.1])),
        ("0d", "transient", Dict("kind" => "linear_transient",
            "loss_rate" => 0.7, "source" => 1.2, "initial" => 0.2,
            "time_steps" => 128)),
        ("0d", "dae", Dict("kind" => "index1_dae", "rate" => 2.0,
            "gain" => 0.5, "offset" => 0.1, "time_steps" => 128)),
        ("1d", "steady", Dict("kind" => "manufactured_diffusion",
            "dimension" => 1, "diffusion" => 0.8)),
        ("1d", "transient", Dict("kind" => "manufactured_diffusion",
            "dimension" => 1, "diffusion" => 0.5, "advection" => 0.3,
            "transient" => true,
            "time_steps" => 128)),
        ("2d", "steady", Dict("kind" => "manufactured_diffusion",
            "dimension" => 2, "diffusion" => 0.8)),
        ("2d", "transient", Dict("kind" => "manufactured_diffusion",
            "dimension" => 2, "diffusion" => 0.4, "transient" => true,
            "time_steps" => 128)),
        ("3d", "steady", Dict("kind" => "manufactured_diffusion",
            "dimension" => 3, "diffusion" => 0.7)),
        ("0d", "steady", Dict("kind" => "multi_region_flux",
            "matrix" => [2.0 -1.0; -1.0 2.0], "source" => [1.0, 1.0],
            "interface_flux_signs" => [1.0, -1.0])),
        ("0d", "steady", Dict("kind" => "closed_loop_control",
            "matrix" => [2.0 -0.2; -0.2 1.5], "source" => [1.0, 0.2],
            "controller_poles" => [-1.0, -2.0], "actuator_load" => 0.5,
            "actuator_capacity" => 1.0)),
        ("1d", "steady", Dict("kind" => "mixed_0d_1d",
            "diffusion" => 0.8, "coupling" => 0.2, "zero_d_loss" => 1.0,
            "pde_source" => 0.5))]
    outcomes = Stage3EvidenceEnvelopeV1[]
    for (dimension, mode, model) in positive
        _, plan, evidence = v70_execute(dimension, mode, model)
        @test plan.completeness == :complete
        @test evidence.completeness == :complete
        @test evidence.conclusion == :pass
        @test evidence.independent_recomputation_evidence["status"] == "pass"
        @test evidence.convergence_evidence["resolution_status"] == "complete"
        if haskey(model, "advection")
            @test any(item["operator_kind"] == "advection"
                for item in plan.capability_matches)
        end
        if model["kind"] == "index1_dae"
            @test evidence.convergence_evidence["time_step_convergence"] == "pass"
        elseif model["kind"] == "mixed_0d_1d"
            dofs = Int.(get.(first(evidence.sample_records)["resolution_records"],
                "dof", 0))
            @test length(unique(dofs)) == length(dofs)
        end
        push!(outcomes, evidence)
    end
    @test length(outcomes) == 11
end

@testset "v70 T4 negative controls are complete physical failures" begin
    cases = Dict{String,Any}[
        Dict("kind" => "generic_graph_balance", "actuator_load" => 2.0,
            "actuator_capacity" => 1.0),
        Dict("kind" => "generic_graph_balance", "declared_source" => 2.0,
            "declared_sink" => 1.0),
        Dict("kind" => "multi_region_flux", "interface_flux_signs" => [1.0, 1.0]),
        Dict("kind" => "generic_graph_balance"),
        Dict("kind" => "index1_dae", "declared_constraint_drift" => 1.0e-3,
            "constraint_drift_tolerance" => 1.0e-8),
        Dict("kind" => "closed_loop_control", "controller_poles" => [-1.0, 0.2]),
        Dict("kind" => "generic_graph_balance", "thermal_load" => 4.0,
            "heat_rejection_capacity" => 3.0)]
    codes = String[]
    for (index, model) in enumerate(cases)
        extras = index == 4 ? Dict{String,Any}("state_bindings" =>
            Dict("electron_inventory" => Dict("upper_bound" => 0.5))) :
            Dict{String,Any}()
        mode = index == 5 ? "dae" : "steady"
        _, _, evidence = v70_execute("0d", mode, model; extras = extras)
        @test evidence.completeness == :complete
        @test evidence.conclusion == :fail
        push!(codes, evidence.classification_code)
    end
    @test length(unique(codes)) == 7
end

@testset "v70 unsupported and unknown controls fail closed" begin
    controls = [
        ("high_index_dae", "unsupported_high_index_dae"),
        ("nonlocal_operator", "unsupported_unregistered_nonlocal_operator"),
        ("missing_boundary_condition", "unsupported_pde_boundary_condition_missing"),
        ("moving_grid", "unsupported_moving_grid_capability"),
        ("missing_governing_residual", "unsupported_state_without_governing_residual"),
        ("missing_discretization", "unsupported_discretization_capability_missing"),
        ("missing_jacobian", "unsupported_jacobian_capability_missing")]
    for (feature, code) in controls
        request = v70_request("1d", "steady", Dict("kind" =>
            "generic_graph_balance"); extras = Dict("unsupported_features" => [feature]))
        plan, evidence = execute_stage3_request_v1(request)
        @test plan.completeness == :incomplete
        @test plan.conclusion == :unsupported
        @test evidence.completeness == :incomplete
        @test evidence.conclusion == :unsupported
        @test evidence.classification_code == code
    end
    request = v70_request("0d", "steady", Dict("kind" =>
        "generic_graph_balance"); extras = Dict("missing_inputs" =>
        ["missing_ion_energy_initial_state"]))
    _, evidence = execute_stage3_request_v1(request)
    @test evidence.completeness == :incomplete
    @test evidence.conclusion == :unknown
    @test "missing_ion_energy_initial_state" in evidence.unresolved_reasons

    invalid_samples = v70_request("0d", "steady", Dict("kind" =>
        "generic_graph_balance"); sample_count = 1)
    invalid_samples.sample_spec["required_sample_count"] = 3
    _, invalid_evidence = execute_stage3_request_v1(invalid_samples)
    @test invalid_evidence.conclusion == :unknown
    @test invalid_evidence.classification_code ==
        "unknown_invalid_state_sample_specification"
end

@testset "v70 T5-T7 resolution, independent audit, cache and resume" begin
    request = v70_request("1d", "steady", Dict("kind" =>
        "manufactured_diffusion", "dimension" => 1, "diffusion" => 1.0);
        sample_count = 4, levels = [16, 64, 256])
    plan = compile_stage3_execution_plan_v1(request)
    temporary = mktempdir()
    checkpoint = joinpath(temporary, "checkpoint.json")
    interrupted = execute_stage3_plan_v1(plan, request;
        checkpoint_path = checkpoint, interrupt_after_samples = 2)
    @test interrupted.completeness == :incomplete
    @test interrupted.conclusion == :unknown
    @test isfile(checkpoint)
    resumed = execute_stage3_plan_v1(plan, request; checkpoint_path = checkpoint)
    clean = execute_stage3_plan_v1(plan, request)
    @test resumed.completeness == :complete
    @test resumed.conclusion == :pass
    @test resumed.evidence_hash == clean.evidence_hash
    @test length(resumed.sample_records) == 4

    cache_dir = joinpath(temporary, "cache")
    _, first_run = execute_stage3_request_v1(request; cache_directory = cache_dir)
    _, replay = execute_stage3_request_v1(request; cache_directory = cache_dir)
    @test first_run.evidence_hash == replay.evidence_hash
    @test Bool(replay.execution_cost_record["cache_hit"])

    biased = v70_request("0d", "steady", Dict("kind" =>
        "generic_graph_balance", "independent_source_bias" => 0.1))
    _, biased_evidence = execute_stage3_request_v1(biased)
    @test biased_evidence.completeness == :complete
    @test biased_evidence.conclusion == :fail
    @test biased_evidence.independent_recomputation_evidence["status"] == "fail"
    @test next_stage3_sampling_depth_v1(:pass, biased_evidence.sample_records) == 1
    @test next_stage3_sampling_depth_v1(:unsupported, Dict{String,Any}[]) == 0
end

@testset "v70 T9 metamorphic routing invariance" begin
    base = v70_request("0d", "steady", Dict("kind" => "generic_graph_balance"))
    base_plan = compile_stage3_execution_plan_v1(base)
    for index in 1:1000
        renamed = v70_request("0d", "steady", Dict("kind" =>
            "generic_graph_balance"); extras = Dict("candidate_label" => "candidate_$index"))
        relabeled = v70_request("0d", "steady", Dict("kind" =>
            "generic_graph_balance"); extras = Dict("family" => "metadata_$index",
            "parent_family" => "parent_$index", "device_type" => "type_$index"))
        @test compile_stage3_execution_plan_v1(renamed).solve_plan_hash ==
            base_plan.solve_plan_hash
        @test compile_stage3_execution_plan_v1(relabeled).solve_plan_hash ==
            base_plan.solve_plan_hash
    end
    renamed_region = v70_request("0d", "steady", Dict("kind" =>
        "generic_graph_balance"); region_id = "renamed_domain")
    reordered_ports = v70_request("0d", "steady", Dict("kind" =>
        "generic_graph_balance"); reverse_ports = true)
    converted_units = v70_request("0d", "steady", Dict("kind" =>
        "generic_graph_balance"); unit_variant = true)
    @test compile_stage3_execution_plan_v1(renamed_region).solve_plan_hash ==
        base_plan.solve_plan_hash
    @test compile_stage3_execution_plan_v1(reordered_ports).solve_plan_hash ==
        base_plan.solve_plan_hash
    @test compile_stage3_execution_plan_v1(converted_units).solve_plan_hash ==
        base_plan.solve_plan_hash

    source = read(joinpath(@__DIR__, "..", "src", "stage3_universal_runtime_v70.jl"),
        String)
    @test isnothing(match(r"family\s*==", lowercase(source)))
    auditor_source = read(joinpath(@__DIR__, "..", "src",
        "stage3_independent_balance_auditor_v1.jl"), String)
    @test !occursin("_stage3_solve_", auditor_source)
    @test !occursin("assemble_residual", auditor_source)
end

@testset "v70 schemas and evidence aggregation" begin
    schema_names = ["stage3_execution_budget_v1.schema.json",
        "stage3_execution_request_v1.schema.json",
        "stage3_execution_plan_v1.schema.json",
        "stage3_evidence_envelope_v1.schema.json"]
    for name in schema_names
        schema = JSON3.read(read(joinpath(@__DIR__, "..", "schemas", name), String))
        @test schema["\$schema"] == "https://json-schema.org/draft/2020-12/schema"
        @test !isempty(schema["required"])
    end
    request, plan, evidence = v70_execute("0d", "steady",
        Dict("kind" => "generic_graph_balance"))
    metrics = aggregate_stage3_metrics_v1([plan], [evidence])
    @test metrics["stage3_complete_count"] == 1
    @test metrics["stage3_pass_count"] == 1
    @test metrics["aggregation_source"] == "sealed_stage3_evidence_envelopes"
    @test !metrics["label_or_device_coverage_used"]
    @test length(stage3_evidence_envelope_to_dict_v1(evidence)["evidence_hash"]) == 64
    persisted = Dict{String,Any}(String(key) => value for (key, value) in pairs(
        JSON3.read(JSON3.write(stage3_evidence_envelope_to_dict_v1(evidence)))))
    @test persisted["evidence_hash"] == FusionConceptAI._stage3_persisted_hash_v1(
        FusionConceptAI._stage3_evidence_hash_projection_v1(persisted))
    sample = Dict{String,Any}(String(key) => value for (key, value) in
        pairs(first(persisted["sample_records"])))
    sample_hash = pop!(sample, "sample_hash")
    @test sample_hash == FusionConceptAI._stage3_persisted_hash_v1(sample)
    audit = Dict{String,Any}(String(key) => value for (key, value) in
        pairs(sample["independent_audit"]))
    audit_hash = pop!(audit, "audit_hash")
    @test audit_hash == FusionConceptAI._stage3_persisted_hash_v1(audit)
end
