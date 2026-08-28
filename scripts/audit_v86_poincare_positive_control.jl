using FusionConceptAI
using JSON3

const FCA = FusionConceptAI

function positive_control_compiled(base_compiled, toroidal_current_fraction)
    base = base_compiled.realization
    binding = base_compiled.binding
    components = deepcopy(base.components)
    field_index = findfirst(component -> component["component_kind"] ==
        "finite_filament_coil_array_v1", components)
    field_index === nothing && error("positive control has no field component")
    component = components[field_index]
    base_loops = [loop for loop in component["loops"] if
        get(loop, "winding_role", "") == "toroidal_field_base"]
    isempty(base_loops) && error("positive control has no toroidal-field loops")
    region = FCA._v71_primary_region(base)
    major = Float64(region["major_radius_m"])
    axis_loop = Dict{String,Any}(
        "loop_id" => "benchmark_only_axis_toroidal_current",
        "winding_role" => "benchmark_only_axis_toroidal_current",
        "centerline_m" => FCA._v71_circular_loop([0.0, 0.0, 0.0],
            [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], major, 256),
        "current_a" => Float64(binding["field_current_a"]) *
            Float64(toroidal_current_fraction),
        "turns" => Int(binding["field_turns"]),
        "supply_group" => "benchmark_only_not_a_candidate_component")
    component["loops"] = vcat(deepcopy(base_loops), [axis_loop])
    component["winding_basis"] =
        "benchmark_tf_plus_axis_toroidal_current_positive_control_v1"
    component["benchmark_only"] = true
    component["feasibility_credit"] = false
    component["component_hash"] = FCA.canonical_hash(component)
    components[field_index] = component
    claim = "Positive-control field for validating the candidate-bound finite-filament and Poincare numerical chain. The axis toroidal current lies inside the declared plasma volume, is not a realizable external coil, and grants zero candidate feasibility or minimality credit."
    registry_hash = FCA.canonical_hash(Dict(
        "base_registry_hash" => base.registry_hash,
        "extension_id" => "poincare_positive_control_v1",
        "toroidal_current_fraction" => Float64(toroidal_current_fraction)))
    body = Dict{String,Any}(
        "schema_version" => base.schema_version,
        "topology_hash" => base.topology_hash,
        "compilation_hash" => base.compilation_hash,
        "candidate_binding_hash" => base.candidate_binding_hash,
        "registry_hash" => registry_hash,
        "completeness" => String(base.completeness),
        "conclusion" => String(base.conclusion),
        "classification_code" => "benchmark_only_positive_control",
        "geometry" => base.geometry, "components" => components,
        "port_mappings" => base.port_mappings,
        "dependency_mappings" => base.dependency_mappings,
        "missing_requirements" => base.missing_requirements,
        "claim_boundary" => claim)
    realization = PhysicalDeviceRealizationV71(base.schema_version,
        base.topology_hash, base.compilation_hash, base.candidate_binding_hash,
        registry_hash, base.completeness, base.conclusion,
        "benchmark_only_positive_control", base.geometry, components,
        base.port_mappings, base.dependency_mappings, base.missing_requirements,
        claim, FCA.canonical_hash(body))
    return (binding = binding, realization = realization)
end

function run_positive_control_audit(; output_path = nothing,
        structure_seed = 72, turns = 32, steps_per_turn = 120,
        fractions = collect(0.04:0.04:0.80))
    topology = generate_graph_native_topology_v69(structure_seed)
    compilation = compile_graph_native_topology_candidate_v69(topology)
    compilation.status == :pass || error("positive-control topology did not compile")
    base_grammar = default_candidate_realization_grammar_v2(
        graph_isomorphism_hash_v69(topology))
    grammar = compile_joint_optimization_grammar_v1(base_grammar)
    design = compile_candidate_joint_design_v1(grammar; route = "closed/mixed",
        coil_fourier_coefficients = zeros(5),
        coil_bspline_control_points = zeros(6),
        current_potential_coefficients = zeros(5),
        plasma_boundary_coefficients = zeros(5),
        actuator_timing_coefficients = zeros(5),
        controller_modal_coefficients = zeros(4), field_current_a = 1.0e5,
        density_scale = 1.0, temperature_scale = 1.0)
    base = compile_joint_physical_realization_v85(topology, compilation, design)
    rows = Dict{String,Any}[]
    for fraction in Float64.(collect(fractions))
        compiled = positive_control_compiled(base, fraction)
        biot = evaluate_v85_biot_savart_gate_v1(compiled;
            maximum_rms_relative_normal_field = 0.30)
        poincare = evaluate_v85_poincare_gate_v1(compiled, biot;
            target_toroidal_turns = turns,
            steps_per_turn = steps_per_turn)
        evidence = get(get(poincare, "evidence", Dict{String,Any}()),
            "poincare_evidence", Dict{String,Any}())
        push!(rows, Dict{String,Any}(
            "toroidal_current_fraction" => fraction,
            "biot_status" => biot["status"],
            "poincare_status" => poincare["status"],
            "classification_code" => poincare["classification_code"],
            "minimum_absolute_rotational_transform" => get(evidence,
                "minimum_absolute_rotational_transform", nothing),
            "maximum_normalized_minor_radius" => get(evidence,
                "maximum_normalized_minor_radius", nothing),
            "surface_ordering_fraction" => get(evidence,
                "surface_ordering_fraction", nothing),
            "minimum_fitted_surface_gap" => get(evidence,
                "minimum_fitted_surface_gap", nothing)))
    end
    pass_rows = [row for row in rows if row["poincare_status"] == "pass"]
    artifact = Dict{String,Any}(
        "schema_version" => "1.0.0",
        "benchmark_kind" => "finite_filament_poincare_positive_control_v1",
        "structure_seed" => structure_seed, "target_toroidal_turns" => turns,
        "steps_per_turn" => steps_per_turn, "rows" => rows,
        "pass_count" => length(pass_rows),
        "numerical_chain_positive_control_passed" => !isempty(pass_rows),
        "candidate_feasibility_credit" => false,
        "minimality_credit" => false,
        "claim_boundary" => "The internal axis-current filament is a numerical positive control only and is excluded from the candidate grammar, complexity Pareto, and every feasibility claim.")
    artifact["result_hash"] = FCA.canonical_hash(artifact)
    if output_path !== nothing
        FCA._stage3_atomic_json_v1(String(output_path), artifact)
    end
    return artifact
end

if abspath(PROGRAM_FILE) == @__FILE__
    output = isempty(ARGS) ? nothing : ARGS[1]
    artifact = run_positive_control_audit(; output_path = output)
    println(JSON3.write(Dict(
        "pass_count" => artifact["pass_count"],
        "numerical_chain_positive_control_passed" => artifact[
            "numerical_chain_positive_control_passed"],
        "result_hash" => artifact["result_hash"])))
end
