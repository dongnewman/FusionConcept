const _MDV25_CLAIM_BOUNDARY =
    "V25 is an isolated rejection-only mirror field-allocation and finite-build vacuum geometry bridge. It independently varies central-axis current, end-axis current, end-coil position, minimum-B anchor current, anchor axial extent, phase, and radii while preserving the v20 plasma and shared engineering envelope. The cheap allocation precondition may reject but never grant equilibrium, stability, confinement, C1, medium-fidelity, superiority, or reactor credit. A strict geometry pass authorizes only separate anisotropic-equilibrium and end-loss admission tasks."

struct MirrorDecoupledVacuumGeometryV25
    layout::String
    random_starts::Int
    seed::Int
    coarse_segments::Int
    refined_segments::Int
    coarse_pack_grid::Int
    refined_pack_grid::Int

    function MirrorDecoupledVacuumGeometryV25(layout::AbstractString;
            random_starts::Integer = 16, seed::Integer = 20260814,
            coarse_segments::Integer = 24, refined_segments::Integer = 48,
            coarse_pack_grid::Integer = 3, refined_pack_grid::Integer = 5)
        String(layout) in _MIRROR_LAYOUT_VACUUM_GEOMETRIES ||
            throw(ArgumentError("unsupported decoupled mirror layout"))
        random_starts >= 16 || throw(ArgumentError(
            "random_starts must be at least 16"))
        coarse_segments >= 16 || throw(ArgumentError(
            "coarse_segments must be at least 16"))
        refined_segments > coarse_segments || throw(ArgumentError(
            "refined_segments must exceed coarse_segments"))
        isodd(coarse_pack_grid) && coarse_pack_grid >= 3 ||
            throw(ArgumentError("coarse_pack_grid must be odd and at least 3"))
        isodd(refined_pack_grid) && refined_pack_grid > coarse_pack_grid ||
            throw(ArgumentError(
                "refined_pack_grid must be odd and exceed coarse_pack_grid"))
        return new(String(layout), Int(random_starts), Int(seed),
            Int(coarse_segments), Int(refined_segments),
            Int(coarse_pack_grid), Int(refined_pack_grid))
    end
end

function _mdv25_parameter(source::FieldSource, name::String, unit::String)
    haskey(source.parameters, name) || error("missing v25 parameter $name")
    item = source.parameters[name]
    item.unit == unit || error("v25 parameter $name must use $unit")
    return Float64(item.value)
end

function _mdv25_axis_reallocate(axis::Dict{String,Any},
        central_current_scale::Float64, end_current_scale::Float64,
        end_position_scale::Float64, half_length_m::Float64,
        target_central_field_T::Float64, mirror_ratio::Float64,
        segment_count::Int)
    result = deepcopy(axis)
    positions = Float64.(result["positions_m"])
    currents = Float64.(result["currents_A"])
    cap_A = Float64(result["current_cap_A"])
    for index in eachindex(positions)
        is_end_group = positions[index] >= 0.45 * half_length_m
        if is_end_group
            positions[index] = min(0.985 * half_length_m,
                positions[index] * end_position_scale)
            currents[index] = clamp(currents[index] * end_current_scale,
                0.0, cap_A)
        else
            currents[index] = clamp(currents[index] * central_current_scale,
                0.0, cap_A)
        end
    end
    result["positions_m"] = positions
    result["currents_A"] = currents
    axis_segments = _mf_centerline_axis_segments(result, segment_count)
    metrics = _mlv_axis_metrics(axis_segments, target_central_field_T,
        mirror_ratio, half_length_m)
    result["center_field_T"] = metrics["center_field_T"]
    result["throat_field_T"] = metrics["throat_field_T"]
    result["achieved_mirror_ratio"] = metrics["mirror_ratio"]
    result["axis_rms_relative_error"] = metrics["rms_relative_error"]
    result["axis_grid_m"] = metrics["grid_m"]
    result["axis_target_T"] = metrics["target_T"]
    result["axis_predicted_T"] = metrics["predicted_T"]
    result["active_pair_count"] = count(current -> current > 1.0e4,
        currents)
    result["v25_current_groups"] = Dict{String,Any}(
        "central_current_scale" => central_current_scale,
        "end_current_scale" => end_current_scale,
        "end_position_scale" => end_position_scale,
        "central_pair_indices" => [index for index in eachindex(positions)
            if positions[index] < 0.45 * half_length_m],
        "end_pair_indices" => [index for index in eachindex(positions)
            if positions[index] >= 0.45 * half_length_m],
    )
    return result
end

function _mdv25_selected(source::FieldSource, axis::Dict{String,Any},
        current_density_limit_A_m2::Float64, pack_m::Float64)
    cell_count = round(Int, _mdv25_parameter(source, "cell_count", "1"))
    end_high = _mdv25_parameter(source, "anchor_axial_fraction", "1")
    central_radius = axis["central_cage_radius_m"] *
        _mdv25_parameter(source, "central_radius_scale", "1")
    end_radius = axis["end_cage_radius_m"] *
        _mdv25_parameter(source, "end_radius_scale", "1")
    current_cap = current_density_limit_A_m2 * pack_m^2
    current_fraction = _mdv25_parameter(source,
        "anchor_current_fraction", "1")
    return Dict{String,Any}(
        "cell_count" => cell_count,
        "end_high_fraction" => end_high,
        "anchor_plane_fraction" => clamp(0.70 * end_high, 0.40, 0.75),
        "central_radius_m" => central_radius,
        "end_radius_m" => end_radius,
        "phase_rad" => _mdv25_parameter(source, "anchor_phase", "rad"),
        "current_A_turn" => current_fraction * current_cap,
        "current_cap_A_turn" => current_cap,
        "anchor_current_fraction" => current_fraction,
        "evaluated_phase_current_count" => 1,
    )
end

function _mdv25_centerline_segments(evaluator::MirrorDecoupledVacuumGeometryV25,
        axis::Dict{String,Any}, selected::Dict{String,Any},
        half_length_m::Float64, segment_count::Int)
    axis_segments = _mf_centerline_axis_segments(axis, segment_count)
    layout_segments = _mlv_layout_segments(evaluator.layout,
        selected["cell_count"], selected["end_high_fraction"],
        selected["central_radius_m"], selected["end_radius_m"],
        half_length_m, selected["phase_rad"],
        selected["current_A_turn"], segment_count)
    return vcat(axis_segments, layout_segments)
end

function _mdv25_transverse_wells(segments::Vector{_MFSegment},
        central_field_T::Float64, mirror_ratio::Float64,
        half_length_m::Float64, plasma_radius_m::Float64,
        anchor_plane_fraction::Float64)
    records = Dict{String,Any}[]
    planes = (("central", 0.0),
        ("left_anchor", -anchor_plane_fraction * half_length_m),
        ("right_anchor", anchor_plane_fraction * half_length_m))
    for (label, z_m) in planes
        local_target = _mf_target_field_T(z_m, central_field_T, mirror_ratio,
            half_length_m)
        local_radius = plasma_radius_m * sqrt(central_field_T / local_target)
        sample_radius = 0.5 * local_radius
        axis_magnitude = _mf_norm(_mf_field((0.0, 0.0, z_m), segments))
        ring = Float64[]
        for theta in range(0.0, 2.0 * pi; length = 9)[1:8]
            push!(ring, _mf_norm(_mf_field((sample_radius * cos(theta),
                sample_radius * sin(theta), z_m), segments)))
        end
        well = minimum(ring) / max(axis_magnitude, 1.0e-12) - 1.0
        push!(records, Dict{String,Any}(
            "plane" => label,
            "z_m" => z_m,
            "sample_radius_m" => sample_radius,
            "axis_field_T" => axis_magnitude,
            "minimum_ring_field_T" => minimum(ring),
            "maximum_ring_field_T" => maximum(ring),
            "minimum_well_fraction" => well,
        ))
    end
    return records
end

function _mdv25_precondition(evaluator::MirrorDecoupledVacuumGeometryV25,
        axis::Dict{String,Any}, selected::Dict{String,Any},
        central_field_T::Float64, mirror_ratio::Float64,
        half_length_m::Float64, plasma_radius_m::Float64,
        shield_m::Float64, maintenance_m::Float64, pack_m::Float64)
    segments = _mdv25_centerline_segments(evaluator, axis, selected,
        half_length_m, 16)
    axis_metrics = _mlv_axis_metrics(segments, central_field_T, mirror_ratio,
        half_length_m)
    wells = _mdv25_transverse_wells(segments, central_field_T, mirror_ratio,
        half_length_m, plasma_radius_m, selected["anchor_plane_fraction"])
    minimum_well = minimum(record["minimum_well_fraction"] for record in wells)
    center_error = abs(axis_metrics["center_field_T"] / central_field_T - 1.0)
    ratio_error = abs(axis_metrics["mirror_ratio"] / mirror_ratio - 1.0)
    anchor_z = selected["anchor_plane_fraction"] * half_length_m
    anchor_target = _mf_target_field_T(anchor_z, central_field_T,
        mirror_ratio, half_length_m)
    anchor_plasma_radius = plasma_radius_m * sqrt(central_field_T / anchor_target)
    central_clearance = selected["central_radius_m"] - 0.5 * pack_m -
        plasma_radius_m - shield_m - maintenance_m
    end_clearance = selected["end_radius_m"] - 0.5 * pack_m -
        anchor_plasma_radius - shield_m - maintenance_m
    minimum_clearance = min(central_clearance, end_clearance)
    gates = Dict{String,Bool}(
        "coarse_center_field_allocation" => center_error <= 0.75,
        "coarse_mirror_ratio_allocation" => ratio_error <= 1.00,
        "coarse_transverse_well_noncatastrophic" => minimum_well >= -0.08,
        "coarse_on_axis_transverse_fraction" =>
            axis_metrics["maximum_on_axis_transverse_fraction"] <= 0.15,
        "repairable_clearance_precondition" => minimum_clearance >= -0.25,
    )
    return Dict{String,Any}(
        "model" => "coarse_decoupled_field_allocation_v25",
        "gates" => gates,
        "passed" => all(values(gates)),
        "failed_gates" => sort!([key for (key, value) in gates if !value]),
        "center_field_T" => axis_metrics["center_field_T"],
        "mirror_ratio" => axis_metrics["mirror_ratio"],
        "center_relative_error" => center_error,
        "mirror_ratio_relative_error" => ratio_error,
        "maximum_on_axis_transverse_fraction" =>
            axis_metrics["maximum_on_axis_transverse_fraction"],
        "minimum_well_fraction" => minimum_well,
        "minimum_clearance_margin_m" => minimum_clearance,
        "rejection_credit" => !all(values(gates)),
        "promotion_credit" => false,
        "claim_boundary" => _MDV25_CLAIM_BOUNDARY,
    )
end

function _mdv25_geometry_summary(evaluator::MirrorDecoupledVacuumGeometryV25,
        genome::Genome; run_finite_geometry::Bool = true)
    source = _mlv_layout_source(genome)
    source === nothing && error("missing supported v25 layout source")
    source.geometry_model == evaluator.layout || error(
        "v25 evaluator layout does not match genome")
    core = only(filter(region -> region.kind == "mirror_central_cell",
        genome.plasma_regions))
    central_field_T = _mirror_reduced_parameter(core, "central_field", "T")
    mirror_ratio = _mirror_reduced_parameter(core, "mirror_ratio_gene", "1")
    cell_length_m = _mirror_reduced_parameter(core, "cell_length", "m")
    plasma_radius_m = _mirror_reduced_parameter(core, "plasma_radius", "m")
    half_length_m = 0.5 * cell_length_m
    axis_field_share = _mdv25_parameter(source, "axis_field_share", "1")
    central_current_scale = _mdv25_parameter(source,
        "central_axis_current_scale", "1")
    end_current_scale = _mdv25_parameter(source,
        "end_axis_current_scale", "1")
    end_position_scale = _mdv25_parameter(source,
        "end_axis_position_scale", "1")
    contract = default_common_comparison_contract()
    shield_m = contract.shield_thickness_m
    maintenance_m = contract.maintenance_gap_m
    pack_m = _screen_target(genome, "screen_coil_pack_thickness", 0.45, "m")
    current_density_limit_A_m2 =
        contract.engineering_current_density_limit_A_mm2 * 1.0e6
    axis_evaluator = MirrorFiniteCoilGeometryV1(
        random_starts = evaluator.random_starts, seed = evaluator.seed,
        coarse_segments = evaluator.coarse_segments,
        refined_segments = evaluator.refined_segments)
    axis = _mf_axis_geometry_search(axis_evaluator,
        axis_field_share * central_field_T, mirror_ratio, half_length_m,
        plasma_radius_m, shield_m, maintenance_m, pack_m, pack_m,
        current_density_limit_A_m2)
    axis = _mdv25_axis_reallocate(axis, central_current_scale,
        end_current_scale, end_position_scale, half_length_m,
        axis_field_share * central_field_T, mirror_ratio,
        evaluator.coarse_segments)
    selected = _mdv25_selected(source, axis, current_density_limit_A_m2, pack_m)
    precondition = _mdv25_precondition(evaluator, axis, selected,
        central_field_T, mirror_ratio, half_length_m, plasma_radius_m,
        shield_m, maintenance_m, pack_m)
    if !run_finite_geometry || precondition["passed"] !== true
        return Dict{String,Any}(
            "model" => "decoupled_mirror_allocation_v25",
            "layout" => evaluator.layout,
            "inputs" => Dict{String,Any}(
                "central_field_T" => central_field_T,
                "target_mirror_ratio" => mirror_ratio,
                "cell_length_m" => cell_length_m,
                "central_plasma_radius_m" => plasma_radius_m,
            ),
            "precondition" => precondition,
            "finite_geometry_executed" => false,
            "finite_geometry" => nothing,
            "all_geometry_gates_passed" => false,
            "disposition" => precondition["passed"] === true ?
                "eligible_for_finite_geometry" :
                "rejected_by_decoupled_allocation_precondition",
            "claim_boundary" => _MDV25_CLAIM_BOUNDARY,
        )
    end

    full_segments = _mdv25_centerline_segments(evaluator, axis, selected,
        half_length_m, evaluator.refined_segments)
    refined_axis = _mlv_axis_metrics(full_segments, central_field_T,
        mirror_ratio, half_length_m)
    refined_wells = _mdv25_transverse_wells(full_segments, central_field_T,
        mirror_ratio, half_length_m, plasma_radius_m,
        selected["anchor_plane_fraction"])
    refined_minimum_well = minimum(record["minimum_well_fraction"]
        for record in refined_wells)
    field_lines = _mlv_field_line_audit(full_segments, central_field_T,
        mirror_ratio, half_length_m, plasma_radius_m)
    layout_evaluator = MirrorLayoutVacuumGeometryV1(evaluator.layout;
        random_starts = evaluator.random_starts, seed = evaluator.seed,
        coarse_segments = evaluator.coarse_segments,
        refined_segments = evaluator.refined_segments,
        coarse_pack_grid = evaluator.coarse_pack_grid,
        refined_pack_grid = evaluator.refined_pack_grid)
    coarse_peak = _mlv_peak_winding_field(layout_evaluator, axis, selected,
        half_length_m, pack_m, evaluator.coarse_pack_grid,
        evaluator.coarse_segments)
    refined_peak = _mlv_peak_winding_field(layout_evaluator, axis, selected,
        half_length_m, pack_m, evaluator.refined_pack_grid,
        evaluator.refined_segments)
    peak_change = abs(refined_peak["peak_field_T"] -
        coarse_peak["peak_field_T"]) / max(refined_peak["peak_field_T"], 1.0e-12)
    center_error = abs(refined_axis["center_field_T"] / central_field_T - 1.0)
    ratio_error = abs(refined_axis["mirror_ratio"] / mirror_ratio - 1.0)
    maximum_axis_current_density = maximum(axis["currents_A"]) / pack_m^2
    layout_current_density = abs(selected["current_A_turn"]) / pack_m^2
    maximum_current_density = max(maximum_axis_current_density,
        layout_current_density)
    anchor_z = selected["anchor_plane_fraction"] * half_length_m
    anchor_target = _mf_target_field_T(anchor_z, central_field_T,
        mirror_ratio, half_length_m)
    anchor_plasma_radius = plasma_radius_m * sqrt(central_field_T / anchor_target)
    central_clearance = selected["central_radius_m"] - 0.5 * pack_m -
        plasma_radius_m - shield_m - maintenance_m
    end_clearance = selected["end_radius_m"] - 0.5 * pack_m -
        anchor_plasma_radius - shield_m - maintenance_m
    minimum_clearance = min(central_clearance, end_clearance)
    reserved_bend_radius_m = min(0.40,
        0.45 * min(selected["central_radius_m"], selected["end_radius_m"]))
    magnetic_pressure_Pa = refined_peak["peak_field_T"]^2 /
        (2.0 * 4.0 * pi * 1.0e-7)
    support_stress_proxy_Pa = magnetic_pressure_Pa *
        max(selected["central_radius_m"], selected["end_radius_m"]) /
        _screen_target(genome, "screen_support_thickness", 0.7, "m")
    gates = Dict{String,Bool}(
        "axis_field_and_mirror_ratio" => center_error <= 0.03 &&
            ratio_error <= 0.05 && refined_axis["rms_relative_error"] <= 0.10 &&
            refined_axis["maximum_on_axis_transverse_fraction"] <= 0.01,
        "transverse_minimum_b_well" => refined_minimum_well >= 0.002,
        "open_field_line_integrity" => field_lines["passed"],
        "finite_build_peak_field" => refined_peak["peak_field_T"] <=
            contract.peak_conductor_field_limit_T,
        "winding_current_density" => maximum_current_density <=
            current_density_limit_A_m2,
        "plasma_shield_maintenance_and_coil_clearance" =>
            minimum_clearance >= 0.0,
        "minimum_bend_radius_reservation" => reserved_bend_radius_m >=
            contract.minimum_coil_curvature_radius_m,
        "membrane_support_stress_proxy" => support_stress_proxy_Pa <=
            contract.support_stress_limit_Pa,
        "biot_savart_resolution_audit" => peak_change <= 0.15,
    )
    active_pairs = Dict{String,Any}[]
    for index in eachindex(axis["positions_m"])
        axis["currents_A"][index] > 1.0e4 || continue
        push!(active_pairs, Dict{String,Any}(
            "pair_index" => index,
            "absolute_z_m" => axis["positions_m"][index],
            "centerline_radius_m" => axis["radii_m"][index],
            "current_per_coil_A_turn" => axis["currents_A"][index],
        ))
    end
    finite = Dict{String,Any}(
        "axis_system" => Dict{String,Any}(
            "active_symmetric_coil_pairs" => active_pairs,
            "active_pair_count" => length(active_pairs),
            "current_groups" => axis["v25_current_groups"],
            "combined_refined" => refined_axis,
        ),
        "minimum_b_system" => Dict{String,Any}(
            "layout" => evaluator.layout,
            "cell_count" => selected["cell_count"],
            "anchor_axial_fraction" => selected["end_high_fraction"],
            "anchor_plane_fraction" => selected["anchor_plane_fraction"],
            "central_radius_m" => selected["central_radius_m"],
            "end_radius_m" => selected["end_radius_m"],
            "phase_rad" => selected["phase_rad"],
            "current_A_turn" => selected["current_A_turn"],
            "anchor_current_fraction" => selected["anchor_current_fraction"],
            "well_records" => refined_wells,
            "minimum_well_fraction" => refined_minimum_well,
        ),
        "finite_build" => Dict{String,Any}(
            "coarse_peak_field" => coarse_peak,
            "refined_peak_field" => refined_peak,
            "peak_field_resolution_change_fraction" => peak_change,
            "maximum_current_density_A_m2" => maximum_current_density,
            "minimum_declared_clearance_margin_m" => minimum_clearance,
            "reserved_minimum_bend_radius_m" => reserved_bend_radius_m,
            "magnetic_pressure_at_refined_peak_Pa" => magnetic_pressure_Pa,
            "membrane_support_stress_proxy_Pa" => support_stress_proxy_Pa,
        ),
        "field_line_audit" => field_lines,
        "gates" => gates,
        "all_geometry_gates_passed" => all(values(gates)),
    )
    return Dict{String,Any}(
        "model" => "decoupled_axis_end_anchor_vacuum_geometry_v25",
        "layout" => evaluator.layout,
        "inputs" => Dict{String,Any}(
            "central_field_T" => central_field_T,
            "target_mirror_ratio" => mirror_ratio,
            "cell_length_m" => cell_length_m,
            "central_plasma_radius_m" => plasma_radius_m,
            "axis_field_share_gene" => axis_field_share,
            "shield_thickness_m" => shield_m,
            "maintenance_gap_m" => maintenance_m,
            "winding_pack_width_m" => pack_m,
            "peak_conductor_field_limit_T" =>
                contract.peak_conductor_field_limit_T,
            "engineering_current_density_limit_A_m2" =>
                current_density_limit_A_m2,
            "support_stress_limit_Pa" => contract.support_stress_limit_Pa,
        ),
        "precondition" => precondition,
        "finite_geometry_executed" => true,
        "finite_geometry" => finite,
        "all_geometry_gates_passed" => finite["all_geometry_gates_passed"],
        "disposition" => finite["all_geometry_gates_passed"] ?
            "vacuum_geometry_provisional_advance_with_blocking_unknowns" :
            "rejected_before_anisotropic_equilibrium",
        "claim_boundary" => _MDV25_CLAIM_BOUNDARY,
    )
end
