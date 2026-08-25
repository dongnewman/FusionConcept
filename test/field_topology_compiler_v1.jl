using Test
using JSON3
using SHA
using FusionConceptAI

const FT_ROOT = normpath(joinpath(@__DIR__, ".."))
const FT_BASE = joinpath(FT_ROOT, "examples", "freegs_testtokamak_regression_genome.json")
const FT_NATIVE = joinpath(FT_ROOT, "examples", "freegs_testtokamak_executable_physics_v1.json")

function topology_configs()
    coarse = FieldLineTraceConfigV1(step_length_m = 0.10,
        maximum_arclength_m = 16.0, minimum_recurrence_arclength_m = 3.5,
        recurrence_tolerance_m = 0.08)
    fine = FieldLineTraceConfigV1(step_length_m = 0.05,
        maximum_arclength_m = 16.0, minimum_recurrence_arclength_m = 3.5,
        recurrence_tolerance_m = 0.08)
    return coarse, fine
end

function topology_diagnostics(; neighbor = :pass)
    statuses = Dict("seed_coverage" => :pass, "poincare_or_endpoint" => :pass,
        "neighbor_separation" => neighbor)
    values = Dict("seed_coverage_fraction" => 1.0,
        "neighbor_pair_count" => 5.0,
        "maximum_neighbor_log_amplification_per_m" => 0.0,
        "neighbor_log_amplification_limit_per_m" => 0.1)
    return statuses, values
end

function analyze_pair(field, seeds, domain; design_id = "manufactured_control",
        physics_hash = repeat("a", 64), source_hash = repeat("b", 64),
        source_kind = :manufactured_control, binding = false,
        covered_domain_ids = [domain.id],
        auxiliary = topology_diagnostics())
    coarse_config, fine_config = topology_configs()
    common = (design_id = design_id, genome_physics_hash = physics_hash,
        field_source_id = "generic_field_line_tracer_v1",
        field_source_hash = source_hash, source_kind = source_kind,
        candidate_binding_verified = binding,
        covered_domain_ids = covered_domain_ids,
        auxiliary_diagnostic_statuses = auxiliary[1],
        auxiliary_diagnostic_values = auxiliary[2])
    coarse = analyze_field_topology_v1(field, seeds, domain, coarse_config;
        common..., resolution_id = "coarse")
    fine = analyze_field_topology_v1(field, seeds, domain, fine_config;
        common..., resolution_id = "fine")
    return coarse, fine, compare_field_topology_resolutions_v1(coarse, fine)
end

@testset "Topology-independent field-line data product and C1 gate v1" begin
    domain = AxisAlignedFieldDomainV1("manufactured_box", (-2.0, -2.0, -2.0),
        (2.0, 2.0, 2.0))
    closed_seeds = FieldLineSeedV1[
        FieldLineSeedV1("closed_$index", (radius, 0.0, z), "core")
        for (index, (radius, z)) in enumerate(((0.70, -0.3), (0.85, -0.1),
            (1.00, 0.1), (1.15, 0.3), (1.30, 0.0), (0.75, 0.4)))]
    open_seeds = FieldLineSeedV1[
        FieldLineSeedV1("open_$index", (radius, 0.0, 0.0), "core")
        for (index, radius) in enumerate((0.60, 0.75, 0.90, 1.05, 1.20, 1.35))]
    circular_field(point) = (-point[2], point[1], 0.0)
    axial_field(point) = (0.0, 0.0, 1.0 + 0.05 * (point[1]^2 + point[2]^2))

    closed_coarse, closed_fine, closed_convergence = analyze_pair(
        circular_field, closed_seeds, domain)
    @test closed_coarse.status == :pass
    @test closed_coarse.topology_class == :closed_dominated
    @test closed_coarse.closed_fraction == 1.0
    @test all(trace.fate == :closed for trace in closed_coarse.traces)
    @test closed_convergence.status == :pass
    @test closed_convergence.topology_class == :closed_dominated
    @test all(values(closed_convergence.checks))
    @test !closed_convergence.c1_evidence_authorized
    @test !field_topology_convergence_to_dict_v1(closed_convergence)[
        "promotion_authorized"]

    open_coarse, open_fine, open_convergence = analyze_pair(
        axial_field, open_seeds, domain; source_hash = repeat("c", 64))
    @test open_coarse.status == :pass
    @test open_coarse.topology_class == :open_dominated
    @test open_coarse.open_fraction == 1.0
    @test all(trace.fate == :open for trace in open_coarse.traces)
    @test all(trace.forward.boundary_id == "z_max" &&
        trace.backward.boundary_id == "z_min" for trace in open_coarse.traces)
    @test all(trace.forward.final_point_m !== nothing &&
        trace.backward.final_point_m !== nothing for trace in open_coarse.traces)
    @test open_convergence.status == :pass
    @test open_convergence.diagnostics["connection_length_relative_difference"] <= 0.05
    @test !open_convergence.c1_evidence_authorized
    open_pairs = [(open_seeds[index].id, open_seeds[index + 1].id)
        for index in 1:(length(open_seeds) - 1)]
    open_neighbor = analyze_field_line_neighbor_separation_v1(
        open_coarse.traces, open_pairs; limit_per_m = 0.1)
    @test open_neighbor.status == :pass
    @test open_neighbor.pair_count == 5
    @test open_neighbor.valid_directional_record_count == 10
    @test open_neighbor.maximum_log_amplification_per_m == 0.0
    @test field_line_neighbor_separation_to_dict_v1(open_neighbor)["result_hash"] ==
        open_neighbor.result_hash
    neighbor_statuses, neighbor_values = neighbor_separation_auxiliary_v1(
        open_neighbor)
    @test neighbor_statuses["neighbor_separation"] == :pass
    @test neighbor_values["neighbor_pair_count"] == 5

    wall_domain = AxisymmetricPolygonFieldDomainV1("manufactured_wall_domain",
        [0.50, 0.50, 1.50, 1.50], [-1.00, 1.00, 1.00, -1.00],
        (-2.0, -2.0, -2.0), (2.0, 2.0, 2.0);
        material_boundary_id = "first_wall",
        wall_geometry_source_id = "manufactured_polygon_control",
        wall_geometry_hash = repeat("e", 64))
    wall_seeds = FieldLineSeedV1[
        FieldLineSeedV1("wall_open_$index", (radius, 0.0, 0.0), "open_shell")
        for (index, radius) in enumerate((0.60, 0.75, 0.90, 1.05, 1.20, 1.35))]
    wall_coarse, wall_fine, wall_convergence = analyze_pair(
        axial_field, wall_seeds, wall_domain;
        design_id = "candidate_wall_control",
        physics_hash = repeat("f", 64), source_hash = repeat("1", 64),
        source_kind = :candidate_bound_solver_field, binding = true,
        covered_domain_ids = ["manufactured_wall_domain"])
    @test wall_coarse.topology_class == :open_dominated
    @test wall_coarse.open_fraction == 1.0
    @test all(trace.forward.boundary_id == "first_wall" &&
        trace.backward.boundary_id == "first_wall" for trace in wall_coarse.traces)
    @test wall_convergence.status == :pass
    @test wall_convergence.c1_evidence_authorized
    wall_payload = field_topology_data_product_to_dict_v1(wall_fine)
    @test wall_payload["domain"]["kind"] ==
        "axisymmetric_polygon_absorbing_boundary_v1"
    @test wall_payload["domain"]["physical_semantics"] ==
        "absorbing trace boundary only; no conducting-wall field response"
    outside_wall = trace_field_line_v1(axial_field,
        FieldLineSeedV1("outside_wall", (1.75, 0.0, 0.0), "open_shell"),
        wall_domain, topology_configs()[1])
    @test outside_wall.forward.termination == :invalid_seed
    @test outside_wall.forward.boundary_id == "first_wall"
    outside_numerical = trace_field_line_v1(axial_field,
        FieldLineSeedV1("outside_numerical", (0.75, 0.0, 2.10), "open_shell"),
        wall_domain, topology_configs()[1])
    @test outside_numerical.forward.termination == :invalid_seed
    @test outside_numerical.forward.boundary_id == "z_max"
    @test_throws ArgumentError AxisymmetricPolygonFieldDomainV1("bad_wall",
        [0.5, 0.6], [-1.0, 1.0], (-2.0, -2.0, -2.0), (2.0, 2.0, 2.0);
        wall_geometry_source_id = "bad", wall_geometry_hash = "bad")
    @test_throws ArgumentError AxisymmetricPolygonFieldDomainV1("outside_box",
        [0.5, 0.5, 2.5, 2.5], [-1.0, 1.0, 1.0, -1.0],
        (-2.0, -2.0, -2.0), (2.0, 2.0, 2.0);
        wall_geometry_source_id = "bad", wall_geometry_hash = "bad")

    divergent_field(point) = (0.4 * point[1], 0.0, 1.0)
    divergent_seeds = FieldLineSeedV1[
        FieldLineSeedV1("divergent_a", (0.20, 0.0, 0.0), "core"),
        FieldLineSeedV1("divergent_b", (0.30, 0.0, 0.0), "core")]
    divergent_traces = FieldLineTraceV1[trace_field_line_v1(divergent_field,
        seed, domain, topology_configs()[1]) for seed in divergent_seeds]
    divergent_neighbor = analyze_field_line_neighbor_separation_v1(
        divergent_traces, [("divergent_a", "divergent_b")]; limit_per_m = 0.0)
    @test divergent_neighbor.status == :fail
    @test divergent_neighbor.maximum_log_amplification_per_m > 0
    @test_throws ArgumentError analyze_field_line_neighbor_separation_v1(
        divergent_traces, [("divergent_a", "missing")]; limit_per_m = 1.0)

    mixed_field(point) = (-point[2], point[1], 0.5 *
        (point[1]^2 + point[2]^2 - 1.0))
    mixed_seeds = FieldLineSeedV1[
        FieldLineSeedV1("mixed_closed_$index", (1.0, 0.0, z), "closed_core")
        for (index, z) in enumerate((-0.4, -0.15, 0.15, 0.4))]
    append!(mixed_seeds, FieldLineSeedV1[
        FieldLineSeedV1("mixed_open_$index", (radius, 0.0, 0.0), "open_shell")
        for (index, radius) in enumerate((0.65, 0.75, 1.25, 1.35))])
    mixed_coarse, mixed_fine, mixed_convergence = analyze_pair(
        mixed_field, mixed_seeds, domain; source_hash = repeat("d", 64))
    @test mixed_coarse.topology_class == :mixed
    @test mixed_coarse.closed_fraction == 0.5
    @test mixed_coarse.open_fraction == 0.5
    @test mixed_convergence.status == :pass
    @test mixed_convergence.topology_class == :mixed
    incompatible_neighbor = analyze_field_line_neighbor_separation_v1(
        [first(closed_coarse.traces), first(open_coarse.traces)],
        [("closed_1", "open_1")]; limit_per_m = 1.0)
    @test incompatible_neighbor.status == :unknown
    @test incompatible_neighbor.valid_directional_record_count == 0

    repeated = analyze_field_topology_v1(circular_field, closed_seeds, domain,
        topology_configs()[1]; design_id = "manufactured_control",
        genome_physics_hash = repeat("a", 64),
        field_source_id = "generic_field_line_tracer_v1",
        field_source_hash = repeat("b", 64), source_kind = :manufactured_control,
        candidate_binding_verified = false, resolution_id = "coarse",
        auxiliary_diagnostic_statuses = topology_diagnostics()[1],
        auxiliary_diagnostic_values = topology_diagnostics()[2])
    @test repeated.product_hash == closed_coarse.product_hash
    @test field_topology_data_product_to_dict_v1(repeated)["product_hash"] ==
        closed_coarse.product_hash

    incomplete_coarse, incomplete_fine, incomplete_convergence = analyze_pair(
        circular_field, closed_seeds, domain; source_hash = repeat("e", 64),
        auxiliary = topology_diagnostics(neighbor = :unknown))
    @test incomplete_coarse.status == :pass
    @test incomplete_convergence.status == :unknown
    @test !incomplete_convergence.checks["auxiliary_diagnostics_complete"]
    @test any(contains("auxiliary_diagnostics_complete"),
        incomplete_convergence.evidence_tasks)
    missing_neighbor_values = (Dict("seed_coverage" => :pass,
        "poincare_or_endpoint" => :pass, "neighbor_separation" => :unknown),
        Dict("seed_coverage_fraction" => 1.0))
    _, _, missing_neighbor_convergence = analyze_pair(circular_field,
        closed_seeds, domain; source_hash = repeat("8", 64),
        auxiliary = missing_neighbor_values)
    @test missing_neighbor_convergence.status == :unknown
    @test !missing_neighbor_convergence.checks["neighbor_values_available"]
    @test missing_neighbor_convergence.diagnostics["neighbor_values_available"] == 0.0

    short_config = FieldLineTraceConfigV1(step_length_m = 0.1,
        maximum_arclength_m = 4.0, minimum_recurrence_arclength_m = 2.0,
        recurrence_tolerance_m = 0.05)
    short_statuses, short_values = topology_diagnostics()
    short_statuses["poincare_or_endpoint"] = :unknown
    unresolved = analyze_field_topology_v1(circular_field, closed_seeds, domain,
        short_config; design_id = "short_trace_control",
        genome_physics_hash = repeat("f", 64),
        field_source_id = "generic_field_line_tracer_v1",
        field_source_hash = repeat("1", 64), source_kind = :manufactured_control,
        candidate_binding_verified = false, resolution_id = "short",
        auxiliary_diagnostic_statuses = short_statuses,
        auxiliary_diagnostic_values = short_values)
    @test unresolved.status == :unknown
    @test unresolved.topology_class == :unresolved
    @test unresolved.unresolved_fraction == 1.0
    @test all(trace.fate == :bounded_unresolved for trace in unresolved.traces)

    bad_field(point) = (NaN, 0.0, 0.0)
    bad_trace = trace_field_line_v1(bad_field, first(closed_seeds), domain,
        topology_configs()[1])
    @test bad_trace.fate == :unknown
    @test bad_trace.forward.termination == :field_null
    @test_throws ArgumentError analyze_field_topology_v1(circular_field,
        closed_seeds, domain, topology_configs()[1];
        design_id = "invalid_authority", genome_physics_hash = repeat("2", 64),
        field_source_id = "generic_field_line_tracer_v1",
        field_source_hash = repeat("3", 64), source_kind = :manufactured_control,
        candidate_binding_verified = true, resolution_id = "invalid",
        auxiliary_diagnostic_statuses = topology_diagnostics()[1],
        auxiliary_diagnostic_values = topology_diagnostics()[2])

    executable = load_executable_genome_v1(FT_BASE, FT_NATIVE)
    program = compile_executable_physics_program_v1(executable)
    untrusted_coarse, untrusted_fine, untrusted_convergence = analyze_pair(
        circular_field, closed_seeds, domain;
        design_id = executable.base_genome.design_id,
        physics_hash = executable.base_genome.physics_hash,
        source_hash = repeat("6", 64))
    blocked_bundle = field_topology_evidence_bundle_v1(executable, program,
        untrusted_convergence, "generic_field_line_tracer_v1")
    @test blocked_bundle.status == :unknown
    @test only(blocked_bundle.metrics).status == :unknown
    @test any(contains("candidate-bound"), blocked_bundle.warnings)
    @test any(contains("no ready executable topology module"), blocked_bundle.warnings)

    genome_raw = JSON3.read(read(FT_BASE, String), Dict{String,Any})
    exhaust_region = only(filter(item -> item["id"] == "freegs_regression_exhaust",
        genome_raw["plasma_regions"]))
    exhaust_region["geometry_model"] = "axis_aligned_exhaust_box"
    exhaust_region["parameters"] = Dict{String,Any}(
        "domain_r_min" => Dict("value" => 0.8, "unit" => "m"),
        "domain_r_max" => Dict("value" => 1.5, "unit" => "m"),
        "domain_z_min" => Dict("value" => -1.0, "unit" => "m"),
        "domain_z_max" => Dict("value" => 1.0, "unit" => "m"))
    genome_raw["design_id"] = "field_topology_candidate_bound_unit_control"
    genome = parse_genome(genome_raw)
    raw = JSON3.read(read(FT_NATIVE, String), Dict{String,Any})
    raw["base_genome_physics_hash"] = genome.physics_hash
    topology_module = only(filter(item -> item["id"] == "field_line_topology_module",
        raw["physics_modules"]))
    topology_module["applicability_scales"][1]["status"] = "derived"
    for backend in topology_module["backend_requirements"]
        backend["status"] = "available"
    end
    ready_executable = parse_executable_genome_v1(genome, raw)
    ready_program = compile_executable_physics_program_v1(ready_executable)
    @test Dict(item.module_id => item.status for item in ready_program.modules)[
        "field_line_topology_module"] == :ready_for_execution

    partial_coarse, partial_fine, partial_convergence = analyze_pair(
        circular_field, closed_seeds, domain; design_id = genome.design_id,
        physics_hash = genome.physics_hash, source_hash = repeat("7", 64),
        source_kind = :candidate_bound_solver_field, binding = true)
    @test partial_convergence.c1_evidence_authorized
    partial_bundle = field_topology_evidence_bundle_v1(ready_executable,
        ready_program, partial_convergence, "generic_field_line_tracer_v1")
    @test partial_bundle.status == :unknown
    @test any(contains("do not cover every physical domain"), partial_bundle.warnings)

    candidate_coarse, candidate_fine, candidate_convergence = analyze_pair(
        circular_field, closed_seeds, domain; design_id = genome.design_id,
        physics_hash = genome.physics_hash, source_hash = repeat("4", 64),
        source_kind = :candidate_bound_solver_field, binding = true,
        covered_domain_ids = String.(topology_module["domain_ids"]))
    @test candidate_convergence.status == :pass
    @test candidate_convergence.c1_evidence_authorized
    topology_bundle = field_topology_evidence_bundle_v1(ready_executable,
        ready_program, candidate_convergence, "generic_field_line_tracer_v1")
    @test topology_bundle.status == :pass
    @test only(topology_bundle.metrics).status == :pass
    @test only(topology_bundle.metrics).value === true
    @test topology_bundle.claim_ceiling == "C1_candidate_specific_topology_evidence"

    closed_domain_support = topology_domain_support_v1(
        "closed_all_domains_unit_control", candidate_convergence)
    composition = compose_topology_domain_evidence_v1(ready_executable,
        ready_program, [closed_domain_support], "generic_field_line_tracer_v1")
    @test composition.status == :pass
    @test composition.c1_evidence_authorized
    @test all(values(composition.checks))
    @test composition.covered_domain_ids == sort(String.(topology_module["domain_ids"]))
    composition_bundle = topology_domain_composition_evidence_bundle_v1(
        ready_executable, ready_program, composition)
    @test composition_bundle.status == :pass
    @test only(composition_bundle.metrics).value === true
    duplicate_composition = compose_topology_domain_evidence_v1(ready_executable,
        ready_program, [closed_domain_support, closed_domain_support],
        "generic_field_line_tracer_v1")
    @test duplicate_composition.status == :unknown
    @test !duplicate_composition.checks["support_domains_do_not_overlap"]
    partial_support = topology_domain_support_v1(
        "partial_domain_unit_control", partial_convergence)
    missing_domain_composition = compose_topology_domain_evidence_v1(
        ready_executable, ready_program, [partial_support],
        "generic_field_line_tracer_v1")
    @test missing_domain_composition.status == :unknown
    @test !missing_domain_composition.checks[
        "domain_union_exactly_matches_topology_module"]

    registry = EvaluatorRegistry()
    register!(registry, TokamakFreeBoundaryFreeGSV1())
    solver_bundle = evaluate_design(registry, "tokamak_free_boundary_freegs_v1", genome)
    field_bridge = bridge_solver_evidence_v1(ready_executable, ready_program,
        solver_bundle)
    assessment = assess_physics_problem_v1(ready_program.base_problem, genome,
        [field_bridge.normalized_bundle, topology_bundle])
    @test assessment.highest_evidence_stage == "C1"
    @test assessment.hard_gate_status == :unknown
    @test !assessment.promotion_authorized

    wrong_hash_result = FieldTopologyConvergenceResultV1(
        candidate_convergence.design_id, repeat("5", 64),
        candidate_convergence.coarse_product_hash,
        candidate_convergence.fine_product_hash,
        candidate_convergence.covered_domain_ids, candidate_convergence.status,
        candidate_convergence.topology_class, candidate_convergence.checks,
        candidate_convergence.diagnostics,
        candidate_convergence.c1_evidence_authorized,
        candidate_convergence.evidence_tasks,
        candidate_convergence.convergence_hash)
    @test_throws ArgumentError field_topology_evidence_bundle_v1(ready_executable,
        ready_program, wrong_hash_result, "generic_field_line_tracer_v1")
    wrong_hash_support = topology_domain_support_v1(
        "wrong_hash_unit_control", wrong_hash_result)
    wrong_hash_composition = compose_topology_domain_evidence_v1(ready_executable,
        ready_program, [wrong_hash_support], "generic_field_line_tracer_v1")
    @test wrong_hash_composition.status == :unknown
    @test !wrong_hash_composition.checks[
        "all_supports_same_genome_physics_hash"]

    pleiades_grid_path = joinpath(FT_ROOT, "knowledge",
        "pleiades_wham_vacuum_field_grid_v1.json")
    pleiades_control_path = joinpath(FT_ROOT, "knowledge",
        "pleiades_wham_field_topology_control_v1.json")
    pleiades_genome = load_genome(joinpath(FT_ROOT, "examples",
        "pleiades_wham_isotropic_regression_genome.json"))
    grid = load_cylindrical_field_grid_v1(pleiades_grid_path;
        expected_design_id = pleiades_genome.design_id,
        expected_genome_physics_hash = pleiades_genome.physics_hash)
    @test grid.artifact_sha256 == bytes2hex(sha256(read(pleiades_grid_path)))
    @test grid.covered_domain_ids == ["pleiades_wham_isotropic_core"]
    @test size(grid.br_t) == (81, 31)
    sampled_field = cylindrical_field_callback_v1(grid)((0.20, 0.0, 0.0))
    @test all(isfinite, sampled_field)
    @test hypot(sampled_field...) > 0
    @test_throws ArgumentError load_cylindrical_field_grid_v1(pleiades_grid_path;
        expected_genome_physics_hash = repeat("9", 64))
    freegs_grid_path = joinpath(FT_ROOT, "knowledge", "freegs_total_field_grid_v1.json")
    freegs_genome = load_genome(joinpath(FT_ROOT, "examples",
        "freegs_testtokamak_regression_genome.json"))
    freegs_grid = load_cylindrical_field_grid_v1(freegs_grid_path;
        expected_design_id = freegs_genome.design_id,
        expected_genome_physics_hash = freegs_genome.physics_hash)
    @test freegs_grid.artifact_sha256 == bytes2hex(sha256(read(freegs_grid_path)))
    @test freegs_grid.covered_domain_ids == ["freegs_regression_core"]
    @test size(freegs_grid.br_t) == (65, 65)
    freegs_field = cylindrical_field_callback_v1(freegs_grid)
    @test all(isfinite, freegs_field((1.30, 0.0, 0.0)))
    @test hypot(freegs_field((1.30, 0.0, 0.0))...) > 0
    ready_field_raw = JSON3.read(read(FT_NATIVE, String), Dict{String,Any})
    ready_field_raw["base_genome_physics_hash"] = freegs_genome.physics_hash
    ready_field_executable = parse_executable_genome_v1(freegs_genome,
        ready_field_raw)
    ready_field_program = compile_executable_physics_program_v1(
        ready_field_executable)
    field_grid_bundle = field_grid_evidence_bundle_v1(ready_field_executable,
        ready_field_program, freegs_grid, "tokamak_free_boundary_freegs_v1";
        source_kind = :candidate_bound_solver_field,
        candidate_binding_verified = true)
    @test field_grid_bundle.status == :pass
    @test only(field_grid_bundle.metrics).metric_id == "field_solution_converged"
    @test only(field_grid_bundle.metrics).value === true
    manufactured_field_grid_bundle = field_grid_evidence_bundle_v1(
        ready_field_executable, ready_field_program, freegs_grid,
        "tokamak_free_boundary_freegs_v1";
        source_kind = :manufactured_control,
        candidate_binding_verified = false)
    @test manufactured_field_grid_bundle.status == :unknown
    flux_grid = load_axisymmetric_flux_field_grid_v1(freegs_grid_path;
        expected_design_id = freegs_genome.design_id,
        expected_genome_physics_hash = freegs_genome.physics_hash)
    @test flux_grid.artifact_sha256 == freegs_grid.artifact_sha256
    @test size(flux_grid.normalized_poloidal_flux) == (65, 65)
    flux_config = ClosedFluxSurfaceConfigV1()
    freegs_surface_coarse = analyze_closed_flux_surfaces_v1(flux_grid,
        flux_config; resolution_id = "stride_2", resolution_stride = 2,
        source_kind = :candidate_bound_solver_field,
        candidate_binding_verified = true)
    freegs_surface_fine = analyze_closed_flux_surfaces_v1(flux_grid,
        flux_config; resolution_id = "stride_1", resolution_stride = 1,
        source_kind = :candidate_bound_solver_field,
        candidate_binding_verified = true)
    @test freegs_surface_coarse.status == :pass
    @test freegs_surface_fine.status == :pass
    @test all(surface.resolved_ray_fraction == 1.0
        for surface in freegs_surface_fine.surfaces)
    @test maximum(surface.maximum_tangency_residual
        for surface in freegs_surface_fine.surfaces) < 0.003
    freegs_surface_convergence = compare_closed_flux_surface_resolutions_v1(
        freegs_surface_coarse, freegs_surface_fine)
    @test freegs_surface_convergence.status == :pass
    @test freegs_surface_convergence.c1_support_authorized
    @test freegs_surface_convergence.diagnostics[
        "maximum_mean_surface_radius_relative_difference"] < 0.05
    @test freegs_surface_convergence.diagnostics[
        "maximum_pointwise_surface_radius_relative_difference"] < 0.10
    support_bundle = closed_flux_surface_evidence_bundle_v1(
        freegs_surface_convergence)
    @test support_bundle.status == :pass
    @test support_bundle.claim_ceiling == "C1_support_closed_surface_only"
    @test only(support_bundle.metrics).metric_id ==
        "closed_flux_surface_descriptor_resolved"
    @test only(support_bundle.metrics).value === true
    tight_surface_convergence = compare_closed_flux_surface_resolutions_v1(
        freegs_surface_coarse, freegs_surface_fine;
        contract = ClosedFluxSurfaceConvergenceContractV1(
            maximum_mean_radius_relative_difference = 0.01,
            maximum_pointwise_radius_relative_difference = 0.01))
    @test tight_surface_convergence.status == :unknown
    @test !tight_surface_convergence.c1_support_authorized
    function manufactured_surface_copy(item, product_hash)
        return ClosedFluxSurfaceDataProductV1(item.schema_version,
            item.design_id, item.genome_physics_hash, item.field_source_id,
            item.field_source_hash, :manufactured_control, false,
            item.resolution_id, item.resolution_stride, item.covered_domain_ids,
            item.config, item.surfaces, item.minimum_observed_nesting_gap_m,
            item.status, false, item.evidence_tasks, product_hash)
    end
    manufactured_surface_coarse = manufactured_surface_copy(
        freegs_surface_coarse, repeat("a", 64))
    manufactured_surface_fine = manufactured_surface_copy(
        freegs_surface_fine, repeat("b", 64))
    manufactured_surface_convergence = compare_closed_flux_surface_resolutions_v1(
        manufactured_surface_coarse, manufactured_surface_fine)
    @test manufactured_surface_convergence.status == :pass
    @test !manufactured_surface_convergence.c1_support_authorized
    @test closed_flux_surface_evidence_bundle_v1(
        manufactured_surface_convergence).status == :unknown
    compact_surface_config = ClosedFluxSurfaceConfigV1(
        normalized_flux_levels = [0.5], angular_sample_count = 16,
        radial_sample_count = 64)
    @test_throws ArgumentError analyze_closed_flux_surfaces_v1(flux_grid,
        compact_surface_config; resolution_id = "invalid_manufactured_binding",
        resolution_stride = 1, source_kind = :manufactured_control,
        candidate_binding_verified = true)
    @test_throws ArgumentError load_axisymmetric_flux_field_grid_v1(
        freegs_grid_path; expected_genome_physics_hash = repeat("7", 64))
    desc_surface_grid_path = joinpath(FT_ROOT, "knowledge",
        "desc_w7x_periodic_surface_grid_v1.json")
    desc_genome = load_genome(joinpath(FT_ROOT, "examples",
        "desc_w7x_regression_genome.json"))
    desc_surface_grid = load_periodic_3d_surface_grid_v1(desc_surface_grid_path;
        expected_design_id = desc_genome.design_id,
        expected_genome_physics_hash = desc_genome.physics_hash)
    @test desc_surface_grid.artifact_sha256 == bytes2hex(sha256(
        read(desc_surface_grid_path)))
    @test desc_surface_grid.covered_domain_ids == ["desc_w7x_core"]
    @test size(desc_surface_grid.x_rpz_m) == (4, 17, 33)
    @test desc_surface_grid.field_periods == 5
    periodic_config = Periodic3DSurfaceConfigV1()
    desc_surface_coarse = analyze_periodic_3d_surfaces_v1(desc_surface_grid,
        periodic_config; resolution_id = "source_stride_2_17x9",
        resolution_stride = 2, source_kind = :candidate_bound_solver_field,
        candidate_binding_verified = true)
    desc_surface_fine = analyze_periodic_3d_surfaces_v1(desc_surface_grid,
        periodic_config; resolution_id = "source_stride_1_33x17",
        resolution_stride = 1, source_kind = :candidate_bound_solver_field,
        candidate_binding_verified = true)
    @test desc_surface_coarse.status == :pass
    @test desc_surface_fine.status == :pass
    @test maximum(surface.maximum_tangency_residual
        for surface in desc_surface_fine.surfaces) < 1.0e-12
    @test desc_surface_fine.minimum_observed_normal_nesting_gap_m > 0.04
    desc_surface_convergence = compare_periodic_3d_surface_resolutions_v1(
        desc_surface_coarse, desc_surface_fine)
    @test desc_surface_convergence.status == :pass
    @test desc_surface_convergence.c1_support_authorized
    @test desc_surface_convergence.diagnostics[
        "maximum_surface_area_relative_difference"] < 0.001
    @test desc_surface_convergence.diagnostics[
        "maximum_mean_major_radius_relative_difference"] < 0.0001
    desc_surface_bundle = periodic_3d_surface_evidence_bundle_v1(
        desc_surface_convergence)
    @test desc_surface_bundle.status == :pass
    @test desc_surface_bundle.claim_ceiling ==
        "C1_support_periodic_3d_surface_only"
    @test only(desc_surface_bundle.metrics).value === true
    tight_periodic_convergence = compare_periodic_3d_surface_resolutions_v1(
        desc_surface_coarse, desc_surface_fine;
        contract = Periodic3DSurfaceConvergenceContractV1(
            maximum_surface_area_relative_difference = 1.0e-5,
            maximum_mean_major_radius_relative_difference = 1.0e-5))
    @test tight_periodic_convergence.status == :unknown
    @test !tight_periodic_convergence.c1_support_authorized
    function manufactured_periodic_copy(item, product_hash)
        return Periodic3DSurfaceDataProductV1(item.schema_version,
            item.design_id, item.genome_physics_hash, item.surface_source_id,
            item.surface_source_hash, :manufactured_control, false,
            item.resolution_id, item.resolution_stride, item.covered_domain_ids,
            item.config, item.surfaces,
            item.minimum_observed_normal_nesting_gap_m, item.status, false,
            item.evidence_tasks, product_hash)
    end
    manufactured_periodic_coarse = manufactured_periodic_copy(
        desc_surface_coarse, repeat("c", 64))
    manufactured_periodic_fine = manufactured_periodic_copy(
        desc_surface_fine, repeat("d", 64))
    manufactured_periodic_convergence = compare_periodic_3d_surface_resolutions_v1(
        manufactured_periodic_coarse, manufactured_periodic_fine)
    @test manufactured_periodic_convergence.status == :pass
    @test !manufactured_periodic_convergence.c1_support_authorized
    @test periodic_3d_surface_evidence_bundle_v1(
        manufactured_periodic_convergence).status == :unknown
    @test_throws ArgumentError analyze_periodic_3d_surfaces_v1(
        desc_surface_grid, periodic_config; resolution_id = "invalid_binding",
        resolution_stride = 1, source_kind = :manufactured_control,
        candidate_binding_verified = true)
    @test_throws ArgumentError load_periodic_3d_surface_grid_v1(
        desc_surface_grid_path; expected_genome_physics_hash = repeat("6", 64))
    pleiades_control = JSON3.read(read(pleiades_control_path, String),
        Dict{String,Any})
    @test pleiades_control["summary"]["coarse_open_fraction"] == 1
    @test pleiades_control["summary"]["fine_open_fraction"] == 1
    @test pleiades_control["summary"]["C1_evidence_authorized"] == false
    @test pleiades_control["summary"]["highest_evidence_stage"] == "C0"
end
