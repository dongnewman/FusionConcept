function _test_v67_provider(requirement, ordinal; independence_group = nothing)
    resource_class = String(requirement["resource_class"])
    artifacts = resource_class == "numerical_backend" ?
        Dict("software_hash" => repeat(string(mod(ordinal, 10)), 64),
            "container_hash" => repeat(string(mod(ordinal + 1, 10)), 64)) :
        resource_class == "material_data" ?
        Dict("data_hash" => repeat(string(mod(ordinal + 2, 10)), 64)) :
        Dict("raw_data_hash" => repeat("a", 64),
            "calibration_hash" => repeat("b", 64),
            "transfer_function_hash" => repeat("c", 64),
            "uncertainty_covariance_hash" => repeat("d", 64))
    return Dict{String,Any}(
        "provider_id" => "provider_$(requirement["requirement_id"])_$ordinal",
        "resource_class" => resource_class,
        "provides_capabilities" => requirement["requires_capabilities"],
        "provides_outputs" => requirement["requires_outputs"],
        "spatial_representations" => [requirement["spatial_representation"]],
        "time_modes" => [requirement["time_mode"]],
        "region_kinds" => requirement["region_kinds"],
        "validity_domain" => Dict("requirement_hash" => requirement["requirement_hash"]),
        "artifact_hashes" => artifacts, "access_state" => "acquired",
        "independence_group" => independence_group === nothing ?
            "independent_group_$ordinal" : String(independence_group),
        "authority" => "independent_external_provider")
end

@testset "Capability-routed external evidence resources v1" begin
    seeds = load_genomes(joinpath(@__DIR__, "..", "examples", "seed_devices.json"))
    grammar = run_attribute_graph_grammar_v17(maximum_archive = 1000)
    context = build_recoverable_cross_topology_context_v20(grammar, seeds)
    base = compile_candidate_solver_judgment_input_v66(context, 1;
        discretization_levels = [32, 64])
    requirements = compile_external_resource_requirements_v1(base["manifest"];
        pulsed_rhd_manifest = base["pulsed_rhd_manifest"])
    @test requirements.status == :requirements_complete
    @test all(item -> item["family_label_used"] === false, requirements.requirements)
    @test any(item -> item["requirement_id"] ==
        "independent_numerical_replication:axisymmetric_mhd_equilibrium",
        requirements.requirements)
    @test any(item -> item["requirement_id"] == "calibrated_experimental_anchor",
        requirements.requirements)

    providers = Dict{String,Any}[]; ordinal = 1
    for requirement in requirements.requirements
        for _ in 1:Int(requirement["minimum_provider_count"])
            push!(providers, _test_v67_provider(requirement, ordinal))
            ordinal += 2
        end
    end
    ready = match_external_resources_v1(requirements, providers)
    @test ready.status == :ready_for_external_execution
    @test ready.ready_requirement_count == ready.total_requirement_count
    @test ready.family_label_used === false

    copied = deepcopy(providers)
    for provider in copied
        provider["resource_class"] == "numerical_backend" || continue
        provider["independence_group"] = "copied_pipeline"
    end
    copied_match = match_external_resources_v1(requirements, copied)
    @test copied_match.status == :unsupported_provider_capability_gap ||
        copied_match.status == :unknown_acquisition_required
    @test copied_match.ready_requirement_count < copied_match.total_requirement_count

    defaults = default_external_evidence_provider_catalog_v1()
    @test all(item -> item.status == :declared_unacquired, defaults)
    default_match = match_external_resources_v1(requirements, defaults)
    @test default_match.status in
        (:unknown_acquisition_required, :unsupported_provider_capability_gap)
    @test default_match.status != :ready_for_external_execution
end
