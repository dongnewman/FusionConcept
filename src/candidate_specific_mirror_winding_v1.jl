const _CSMW_MU0_V1 = 4.0 * pi * 1.0e-7

struct _CSMWSegmentV1
    midpoint::NTuple{3,Float64}
    direction::NTuple{3,Float64}
    current_A::Float64
    group::Int
end

function _csmw_explicit_input_v1(record::AbstractDict)
    parameters = record["parameters"]
    backend = record["backend_result"]
    required_parameters = ("coil_radius_m", "derived_half_separation_m",
        "plasma_radius_m", "declared_peak_field_screen_t",
        "target_mirror_ratio")
    all(key -> haskey(parameters, key), required_parameters) ||
        throw(ArgumentError("explicit circular-pair geometry is incomplete"))
    haskey(backend, "current_per_loop_a") ||
        throw(ArgumentError("explicit ampere-turns are missing"))
    haskey(backend, "central_field_t") ||
        throw(ArgumentError("resolved central field is missing"))
    return Dict{String,Any}(
        "geometry_model" => "axisymmetric_circular_pair_square_winding_pack_v1",
        "coil_centerline_radius_m" =>
            Float64(parameters["coil_radius_m"]),
        "pair_half_separation_m" =>
            Float64(parameters["derived_half_separation_m"]),
        "pair_center_z_m" => 0.0,
        "ampere_turns_per_coil_A" =>
            abs(Float64(backend["current_per_loop_a"])),
        "plasma_radius_m" => Float64(parameters["plasma_radius_m"]),
        "resolved_central_field_T" => Float64(backend["central_field_t"]),
        "target_mirror_ratio" => Float64(parameters["target_mirror_ratio"]),
        "declared_peak_field_screen_T" =>
            Float64(parameters["declared_peak_field_screen_t"]))
end

"""
Compile the finite-winding problem from explicit geometry and field quantities.
Candidate family and route labels are deliberately ignored. The shared contract
is a comparison boundary, not a material critical-surface qualification.
"""
function compile_candidate_specific_mirror_winding_problem_v1(
        record::AbstractDict; pack_grid::Integer = 11,
        circle_segments::Integer = 256)
    pack_grid >= 5 && isodd(pack_grid) ||
        throw(ArgumentError("pack_grid must be odd and at least 5"))
    circle_segments >= 64 ||
        throw(ArgumentError("circle_segments must be at least 64"))
    explicit = _csmw_explicit_input_v1(record)
    contract = default_common_comparison_contract()
    numerical = Dict{String,Any}(
        "pack_grid" => Int(pack_grid),
        "circle_segments" => Int(circle_segments),
        "self_cell_treatment" =>
            "symmetric_volume_cell_zero_at_centroid_plus_surface_upper_bound")
    solver_input = Dict{String,Any}(
        "explicit_geometry_and_field" => explicit,
        "shared_engineering_boundary" => Dict{String,Any}(
            "contract_id" => contract.id,
            "shield_thickness_m" => contract.shield_thickness_m,
            "maintenance_gap_m" => contract.maintenance_gap_m,
            "engineering_current_density_limit_A_m2" =>
                contract.engineering_current_density_limit_A_mm2 * 1.0e6,
            "peak_conductor_field_limit_T" =>
                min(contract.peak_conductor_field_limit_T,
                    explicit["declared_peak_field_screen_T"]),
            "support_stress_limit_Pa" => contract.support_stress_limit_Pa,
            "minimum_coil_curvature_radius_m" =>
                contract.minimum_coil_curvature_radius_m),
        "numerical_contract" => numerical)
    return Dict{String,Any}(
        "compiler_version" => "candidate_specific_mirror_winding_problem_v1",
        "status" => "ready",
        "candidate_physics_hash" => get(record, "physics_hash", nothing),
        "family_label_used" => false,
        "ignored_metadata_fields" => ["family", "route", "label"],
        "solver_input" => solver_input,
        "solver_problem_hash" => canonical_hash(solver_input),
        "claim_boundary" => "This problem represents only the explicit circular-pair geometry, a square distributed winding pack, and the shared generic engineering screen. It does not establish minimum-B, plasma stability, a superconductor critical surface, structural support, quench protection, exhaust or complete C2.")
end

function _csmw_original_build_v1(input::Dict{String,Any}, boundary)
    radius = Float64(input["coil_centerline_radius_m"])
    separation = Float64(input["pair_half_separation_m"])
    plasma_radius = Float64(input["plasma_radius_m"])
    ampere_turns = Float64(input["ampere_turns_per_coil_A"])
    current_density = Float64(boundary["engineering_current_density_limit_A_m2"])
    width = sqrt(ampere_turns / current_density)
    shield = Float64(boundary["shield_thickness_m"])
    maintenance = Float64(boundary["maintenance_gap_m"])
    radial_margin = radius - plasma_radius - shield - maintenance - 0.5 * width
    inner_radius = radius - 0.5 * width
    axial_margin = separation - 0.5 * width
    curvature_margin = inner_radius -
        Float64(boundary["minimum_coil_curvature_radius_m"])
    gates = Dict{String,Bool}(
        "plasma_shield_maintenance_and_winding_pack_fit" =>
            radial_margin >= 0.0,
        "symmetric_winding_packs_do_not_overlap" => axial_margin >= 0.0,
        "minimum_inner_bend_radius" => curvature_margin >= 0.0)
    return Dict{String,Any}(
        "winding_pack_width_m_at_current_density_ceiling" => width,
        "available_centerline_to_plasma_clearance_m" => radius - plasma_radius,
        "required_inboard_build_m" => shield + maintenance + 0.5 * width,
        "radial_build_margin_m" => radial_margin,
        "inner_winding_radius_m" => inner_radius,
        "axial_pack_separation_margin_m" => axial_margin,
        "minimum_curvature_margin_m" => curvature_margin,
        "gates" => gates,
        "all_necessary_geometry_gates_passed" => all(values(gates)),
        "hard_falsified_as_declared" => !all(values(gates)))
end

function _csmw_minimum_similarity_repair_v1(input::Dict{String,Any}, boundary)
    radius = Float64(input["coil_centerline_radius_m"])
    separation = Float64(input["pair_half_separation_m"])
    plasma_radius = Float64(input["plasma_radius_m"])
    ampere_turns = Float64(input["ampere_turns_per_coil_A"])
    current_density = Float64(boundary["engineering_current_density_limit_A_m2"])
    fixed_build = plasma_radius + Float64(boundary["shield_thickness_m"]) +
        Float64(boundary["maintenance_gap_m"])
    coefficient = 0.5 * sqrt(ampere_turns / current_density)
    root = (coefficient + sqrt(coefficient^2 + 4.0 * radius * fixed_build)) /
        (2.0 * radius)
    # Move one floating-point scale step beyond exact tangency. No engineering
    # tolerance credit is attached to this numerical reserve.
    scale = root^2 * (1.0 + 1.0e-8)
    repaired_radius = scale * radius
    repaired_separation = scale * separation
    repaired_ampere_turns = scale * ampere_turns
    width = sqrt(repaired_ampere_turns / current_density)
    repaired = Dict{String,Any}(
        "repair_model" => "on_axis_field_preserving_geometric_similarity_v1",
        "similarity_scale" => scale,
        "coil_centerline_radius_m" => repaired_radius,
        "pair_half_separation_m" => repaired_separation,
        "ampere_turns_per_coil_A" => repaired_ampere_turns,
        "plasma_radius_m" => plasma_radius,
        "winding_pack_width_m" => width,
        "engineering_current_density_A_m2" => current_density,
        "radial_build_margin_m" => repaired_radius - plasma_radius -
            Float64(boundary["shield_thickness_m"]) -
            Float64(boundary["maintenance_gap_m"]) - 0.5 * width,
        "inner_winding_radius_m" => repaired_radius - 0.5 * width,
        "axial_pack_separation_margin_m" => repaired_separation - 0.5 * width,
        "target_central_field_T" => input["resolved_central_field_T"],
        "target_mirror_ratio" => input["target_mirror_ratio"],
        "peak_conductor_field_limit_T" => boundary["peak_conductor_field_limit_T"])
    repaired["repair_problem_hash"] = canonical_hash(repaired)
    return repaired
end

function _csmw_pack_segments_v1(radius::Float64, separation::Float64,
        width::Float64, ampere_turns::Float64, grid::Int, segments::Int)
    cell_width = width / grid
    offsets = collect(range(-0.5 * width + 0.5 * cell_width,
        0.5 * width - 0.5 * cell_width; length = grid))
    current = ampere_turns / grid^2
    output = _CSMWSegmentV1[]
    groups = Dict{Tuple{Int,Int,Int},Int}()
    group = 0
    for side in (-1, 1), (ir, radial_offset) in enumerate(offsets),
            (iz, axial_offset) in enumerate(offsets)
        group += 1
        groups[(side, ir, iz)] = group
        local_radius = radius + radial_offset
        local_z = side * (separation + axial_offset)
        for index in 0:(segments - 1)
            angle1 = 2.0 * pi * index / segments
            angle2 = 2.0 * pi * (index + 1) / segments
            p1 = (local_radius * cos(angle1), local_radius * sin(angle1), local_z)
            p2 = (local_radius * cos(angle2), local_radius * sin(angle2), local_z)
            midpoint = ntuple(axis -> 0.5 * (p1[axis] + p2[axis]), 3)
            direction = ntuple(axis -> p2[axis] - p1[axis], 3)
            push!(output, _CSMWSegmentV1(midpoint, direction, current, group))
        end
    end
    return output, groups, offsets, current, cell_width
end

function _csmw_field_v1(point::NTuple{3,Float64},
        segments::Vector{_CSMWSegmentV1}; excluded_group::Int = 0)
    bx = by = bz = 0.0
    for segment in segments
        segment.group == excluded_group && continue
        rx = point[1] - segment.midpoint[1]
        ry = point[2] - segment.midpoint[2]
        rz = point[3] - segment.midpoint[3]
        radius_squared = rx^2 + ry^2 + rz^2
        radius_squared > 1.0e-18 || continue
        scale = 1.0e-7 * segment.current_A /
            (radius_squared * sqrt(radius_squared))
        dx, dy, dz = segment.direction
        bx += (dy * rz - dz * ry) * scale
        by += (dz * rx - dx * rz) * scale
        bz += (dx * ry - dy * rx) * scale
    end
    return (bx, by, bz)
end

_csmw_norm_v1(field) = sqrt(field[1]^2 + field[2]^2 + field[3]^2)

function _csmw_numerical_case_v1(repair::Dict{String,Any}, grid::Int,
        circle_segments::Int)
    radius = Float64(repair["coil_centerline_radius_m"])
    separation = Float64(repair["pair_half_separation_m"])
    width = Float64(repair["winding_pack_width_m"])
    ampere_turns = Float64(repair["ampere_turns_per_coil_A"])
    segments, groups, offsets, cell_current, cell_width =
        _csmw_pack_segments_v1(radius, separation, width, ampere_turns,
            grid, circle_segments)
    center_field = _csmw_norm_v1(_csmw_field_v1((0.0, 0.0, 0.0), segments))
    axis_samples = Dict{String,Any}[]
    throat_field = -Inf
    throat_z = 0.0
    for z in range(0.0, separation + 0.75 * width; length = 97)
        magnitude = _csmw_norm_v1(_csmw_field_v1((0.0, 0.0, z), segments))
        push!(axis_samples, Dict("z_m" => z, "field_T" => magnitude))
        if magnitude > throat_field
            throat_field = magnitude
            throat_z = z
        end
    end
    peak_upper = -Inf
    peak_background = -Inf
    peak_location = nothing
    maximum_cell_line_load = 0.0
    radial_force_N = 0.0
    axial_force_N = 0.0
    absolute_force_N = 0.0
    for (ir, radial_offset) in enumerate(offsets),
            (iz, axial_offset) in enumerate(offsets)
        local_radius = radius + radial_offset
        local_z = separation + axial_offset
        group = groups[(1, ir, iz)]
        field = _csmw_field_v1((local_radius, 0.0, local_z), segments;
            excluded_group = group)
        background = _csmw_norm_v1(field)
        # The omitted symmetric volume cell has zero field at its centroid.
        # This conservative surface term bounds its unresolved sub-cell scale
        # and vanishes under pack-grid refinement.
        self_cell_surface_bound = _CSMW_MU0_V1 * cell_current /
            (pi * cell_width)
        upper = background + self_cell_surface_bound
        if upper > peak_upper
            peak_upper = upper
            peak_background = background
            peak_location = Dict("radius_m" => local_radius, "z_m" => local_z,
                "radial_cell_index" => ir, "axial_cell_index" => iz,
                "excluded_self_group" => group,
                "self_cell_surface_bound_T" => self_cell_surface_bound)
        end
        radial_line_load = cell_current * field[3]
        axial_line_load = -cell_current * field[1]
        line_load = hypot(radial_line_load, axial_line_load)
        maximum_cell_line_load = max(maximum_cell_line_load, line_load)
        circumference = 2.0 * pi * local_radius
        radial_force_N += circumference * radial_line_load
        axial_force_N += circumference * axial_line_load
        absolute_force_N += circumference * line_load
    end
    return Dict{String,Any}(
        "pack_grid" => grid,
        "circle_segments" => circle_segments,
        "distributed_filament_count" => 2 * grid^2,
        "biot_savart_segment_count" => length(segments),
        "cell_current_A_turn" => cell_current,
        "cell_width_m" => cell_width,
        "central_field_T" => center_field,
        "sampled_axis_throat_field_T" => throat_field,
        "sampled_axis_throat_z_m" => throat_z,
        "sampled_mirror_ratio" => throat_field / center_field,
        "peak_winding_background_field_T" => peak_background,
        "peak_winding_field_upper_bound_T" => peak_upper,
        "peak_location" => peak_location,
        "maximum_cell_line_load_N_m" => maximum_cell_line_load,
        "net_radial_force_per_coil_N" => radial_force_N,
        "net_axial_force_per_coil_N" => axial_force_N,
        "absolute_integrated_force_per_coil_N" => absolute_force_N,
        "axis_samples" => axis_samples)
end

function _csmw_assess_repair_case_v1(explicit::Dict{String,Any},
        base_boundary::Dict{String,Any}, current_density_A_m2::Float64,
        coarse_pack_grid::Int, refined_pack_grid::Int,
        coarse_circle_segments::Int, refined_circle_segments::Int)
    boundary = deepcopy(base_boundary)
    boundary["engineering_current_density_limit_A_m2"] = current_density_A_m2
    repair = _csmw_minimum_similarity_repair_v1(explicit, boundary)
    coarse_result = _csmw_numerical_case_v1(repair, coarse_pack_grid,
        coarse_circle_segments)
    refined_result = _csmw_numerical_case_v1(repair, refined_pack_grid,
        refined_circle_segments)
    relative_change(key) = abs(Float64(refined_result[key]) -
        Float64(coarse_result[key])) /
        max(abs(Float64(refined_result[key])), 1.0e-12)
    convergence = Dict{String,Any}(
        "central_field_relative_change" => relative_change("central_field_T"),
        "mirror_ratio_relative_change" => relative_change("sampled_mirror_ratio"),
        "peak_field_upper_bound_relative_change" =>
            relative_change("peak_winding_field_upper_bound_T"),
        "radial_force_relative_change" =>
            relative_change("net_radial_force_per_coil_N"),
        "axial_force_relative_change" =>
            relative_change("net_axial_force_per_coil_N"))
    convergence_passed = convergence["central_field_relative_change"] <= 0.01 &&
        convergence["mirror_ratio_relative_change"] <= 0.01 &&
        convergence["peak_field_upper_bound_relative_change"] <= 0.08 &&
        convergence["radial_force_relative_change"] <= 0.10 &&
        convergence["axial_force_relative_change"] <= 0.10
    central_error = abs(Float64(refined_result["central_field_T"]) /
        Float64(explicit["resolved_central_field_T"]) - 1.0)
    ratio_error = abs(Float64(refined_result["sampled_mirror_ratio"]) /
        Float64(explicit["target_mirror_ratio"]) - 1.0)
    gates = Dict{String,Bool}(
        "shared_radial_build" => repair["radial_build_margin_m"] >= -1.0e-8,
        "minimum_inner_bend_radius" => repair["inner_winding_radius_m"] >=
            Float64(boundary["minimum_coil_curvature_radius_m"]),
        "symmetric_pack_separation" =>
            repair["axial_pack_separation_margin_m"] >= 0.0,
        "central_field_preserved_within_2_percent" => central_error <= 0.02,
        "mirror_ratio_preserved_within_2_percent" => ratio_error <= 0.02,
        "peak_winding_field_screen" =>
            refined_result["peak_winding_field_upper_bound_T"] <=
                Float64(boundary["peak_conductor_field_limit_T"]),
        "numerical_refinement" => convergence_passed)
    component = all(values(gates))
    support_limit = Float64(boundary["support_stress_limit_Pa"])
    force_support_lower_bounds = Dict{String,Any}(
        "shared_allowable_stress_Pa" => support_limit,
        "minimum_net_radial_support_area_m2" => abs(Float64(
            refined_result["net_radial_force_per_coil_N"])) / support_limit,
        "minimum_net_axial_support_area_m2" => abs(Float64(
            refined_result["net_axial_force_per_coil_N"])) / support_limit,
        "minimum_absolute_load_support_area_m2" => Float64(
            refined_result["absolute_integrated_force_per_coil_N"]) /
            support_limit,
        "evidence_status" => "necessary_lower_bound_only_no_load_path")
    return Dict{String,Any}(
        "engineering_current_density_A_m2" => current_density_A_m2,
        "minimum_similarity_repair" => repair,
        "coarse_numerical_result" => coarse_result,
        "refined_numerical_result" => refined_result,
        "refinement" => convergence,
        "repair_central_field_relative_error" => central_error,
        "repair_mirror_ratio_relative_error" => ratio_error,
        "repair_gates" => gates,
        "force_support_lower_bounds" => force_support_lower_bounds,
        "candidate_specific_finite_winding_vacuum_component_authorized" =>
            component)
end

"""
Evaluate the declared zero-thickness candidate and a minimum similarity repair.
The original hard failure is exact only under the shared comparison boundary;
the repair result is a bounded vacuum electromagnetic component, not a device
or all-mode-stability pass.
"""
function evaluate_candidate_specific_mirror_winding_v1(record::AbstractDict;
        coarse_pack_grid::Integer = 7, refined_pack_grid::Integer = 11,
        coarse_circle_segments::Integer = 128,
        refined_circle_segments::Integer = 256)
    coarse = compile_candidate_specific_mirror_winding_problem_v1(record;
        pack_grid = coarse_pack_grid, circle_segments = coarse_circle_segments)
    refined = compile_candidate_specific_mirror_winding_problem_v1(record;
        pack_grid = refined_pack_grid, circle_segments = refined_circle_segments)
    explicit = refined["solver_input"]["explicit_geometry_and_field"]
    boundary = refined["solver_input"]["shared_engineering_boundary"]
    original = _csmw_original_build_v1(explicit, boundary)
    repair_cases = Dict{String,Any}[]
    for current_density_A_m2 in (5.0e7, 1.0e8, 2.0e8, 5.0e8)
        push!(repair_cases, _csmw_assess_repair_case_v1(explicit, boundary,
            current_density_A_m2, Int(coarse_pack_grid), Int(refined_pack_grid),
            Int(coarse_circle_segments), Int(refined_circle_segments)))
    end
    passing = filter(item ->
        item["candidate_specific_finite_winding_vacuum_component_authorized"] ===
            true, repair_cases)
    selected = isempty(passing) ?
        repair_cases[argmin(Float64(item["refined_numerical_result"][
            "peak_winding_field_upper_bound_T"]) for item in repair_cases)] :
        passing[argmin(Float64(item["minimum_similarity_repair"][
            "similarity_scale"]) for item in passing)]
    component = selected[
        "candidate_specific_finite_winding_vacuum_component_authorized"] === true
    repair = selected["minimum_similarity_repair"]
    physical = Dict{String,Any}(
        "explicit_input" => explicit,
        "shared_engineering_boundary" => boundary,
        "original_declared_realization" => original,
        "repair_current_density_search_A_m2" =>
            [5.0e7, 1.0e8, 2.0e8, 5.0e8],
        "repair_cases" => repair_cases,
        "selected_repair" => selected,
        "candidate_specific_finite_winding_vacuum_component_authorized" => component)
    result_hash = canonical_hash(physical)
    return merge(physical, Dict{String,Any}(
        "schema_version" => "1.0.0",
        "evaluator_version" => "candidate_specific_mirror_winding_v1",
        "candidate_physics_hash" => get(record, "physics_hash", nothing),
        "family_label_used" => false,
        "coarse_solver_problem_hash" => coarse["solver_problem_hash"],
        "refined_solver_problem_hash" => refined["solver_problem_hash"],
        "repair_candidate_id" => "mirror_repair_" *
            first(String(repair["repair_problem_hash"]), 16),
        "physical_result_hash" => result_hash,
        "original_candidate_hard_falsified" =>
            original["hard_falsified_as_declared"],
        "finite_coil_material_evidence_authorized" => false,
        "structural_support_evidence_authorized" => false,
        "minimum_b_stability_evidence_authorized" => false,
        "kinetic_stability_evidence_authorized" => false,
        "complete_c2_evidence_authorized" => false,
        "promotion_authorized" => false,
        "status" => component ?
            "narrow_finite_winding_vacuum_component" :
            "repair_realization_failed_or_numerically_unknown",
        "claim_ceiling" => component ?
            "narrow_C2_candidate_specific_finite_winding_vacuum_electromagnetics" :
            "C1_finite_winding_repair_attempt",
        "claim_boundary" => "The original candidate is hard-falsified only as the declared geometry under the shared shield, maintenance and current-density boundary. The repaired child is a candidate-specific distributed-winding vacuum electromagnetic calculation. It does not supply a minimum-B well, plasma equilibrium or stability, an HTS critical surface, detailed force/stress support, quench protection, exhaust, coupled balances or complete C2."))
end
