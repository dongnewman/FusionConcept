const _MIRROR_LAYOUT_VACUUM_GEOMETRIES = Set([
    "split_ioffe_saddle_pair",
    "continuous_baseball_seam_pair",
    "yin_yang_end_anchor_pair",
])

const _MIRROR_LAYOUT_VACUUM_SOURCE_BASIS = String[
    "mirror_quadrupolar_coil_hagnestal_agren_2011",
    "mftf_b_superconducting_magnet_system",
    "tandem_mirror_magnet_design_baldwin",
]

const _MIRROR_LAYOUT_VACUUM_CLAIM_BOUNDARY =
    "Fidelity-1 reduced layout-specific vacuum-field and finite-build screening calculation. The declared split-Ioffe, continuous baseball-seam, or Yin-Yang end-anchor centerline is an explicit closed current path and is never evaluated by the cage-only adapter. Passing would establish only the recorded vacuum-field, field-line, generic current-density, stand-off peak-field, clearance, bend-reservation, and membrane-stress proxy gates. It is not a detailed winding design, mutual-force structural solution, superconducting critical-surface or quench qualification, anisotropic finite-beta equilibrium, interchange or microstability result, Fokker-Planck end-loss calculation, exhaust design, reactor power balance, global optimum, or evidence that the named historical coil has been faithfully reproduced."

"""One geometry-specific mirror vacuum-field task from the v2 topology round."""
struct MirrorLayoutVacuumGeometryV1 <: AbstractEvaluator
    layout::String
    random_starts::Int
    seed::Int
    coarse_segments::Int
    refined_segments::Int
    coarse_pack_grid::Int
    refined_pack_grid::Int

    function MirrorLayoutVacuumGeometryV1(layout::AbstractString;
            random_starts::Integer = 24, seed::Integer = 20260811,
            coarse_segments::Integer = 48, refined_segments::Integer = 96,
            coarse_pack_grid::Integer = 3, refined_pack_grid::Integer = 5)
        String(layout) in _MIRROR_LAYOUT_VACUUM_GEOMETRIES ||
            throw(ArgumentError("unsupported mirror layout vacuum geometry"))
        random_starts >= 16 || throw(ArgumentError(
            "random_starts must be at least 16"))
        coarse_segments >= 32 || throw(ArgumentError(
            "coarse_segments must be at least 32"))
        refined_segments >= 2 * coarse_segments || throw(ArgumentError(
            "refined_segments must be at least twice coarse_segments"))
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

_mlv_task_id(layout::String) = "mirror_$(layout)_vacuum_geometry_v1"

function evaluator_spec(evaluator::MirrorLayoutVacuumGeometryV1)
    return EvaluatorSpec(
        _mlv_task_id(evaluator.layout),
        "1.0.0",
        ["magnetic_mirror"],
        1,
        Dict(
            "finite_build_coils" => :proxy,
            "line_current_geometry" => :full,
            "axisymmetric_green_function_fields" => :full,
            "minimum_b_transverse_well" => :proxy,
            "field_line_and_particle_following" => :proxy,
            "coil_curvature" => :proxy,
            "coil_separation" => :proxy,
            "engineering_current_density" => :proxy,
            "peak_conductor_field" => :proxy,
            "assembly_tolerance" => :proxy,
            "structural_fea" => :proxy,
        ),
        "physics_proxy",
    )
end

function _mlv_layout_source(genome::Genome)
    matches = filter(source -> source.kind == "minimum_b_coil" &&
        source.geometry_model in _MIRROR_LAYOUT_VACUUM_GEOMETRIES,
        genome.field_sources)
    return length(matches) == 1 ? only(matches) : nothing
end

function evaluator_applicability(evaluator::MirrorLayoutVacuumGeometryV1,
        genome::Genome)
    genome.family == "magnetic_mirror" || return false,
        "layout-specific mirror geometry applies only to magnetic_mirror"
    genome.topology.field_line_class == "open_mirror" || return false,
        "layout-specific mirror geometry requires open_mirror field lines"
    _mirror_reduced_core(genome) === nothing && return false,
        "layout-specific mirror geometry requires one mirror_central_cell"
    source = _mlv_layout_source(genome)
    source === nothing && return false,
        "candidate must declare exactly one supported minimum_b_coil geometry"
    source.geometry_model == evaluator.layout || return false,
        "candidate geometry $(source.geometry_model) does not match $(evaluator.layout)"
    horizontal = _unified_screen_result(UnifiedCrossFamilyScreenV1(), genome)
    horizontal["all_five_gates_passed"] === true || return false,
        "horizontal five-gate screen must pass before layout geometry"
    return true, "explicit $(evaluator.layout) current-path genome with a passing horizontal screen"
end

function _mlv_parameter(source::FieldSource, name::String, unit::String)
    haskey(source.parameters, name) || error("missing layout parameter $name")
    item = source.parameters[name]
    item.unit == unit || error("layout parameter $name must use $unit")
    return Float64(item.value)
end

function _mlv_integer_parameter(source::FieldSource, name::String)
    value = _mlv_parameter(source, name, "1")
    isinteger(value) || error("layout parameter $name must be integral")
    return Int(round(value))
end

function _mlv_polyline_segments(points::Vector{_MFPoint}, current_A::Float64,
        group_id::String; closed::Bool = true)
    segments = _MFSegment[]
    length(points) >= 3 || return segments
    for index in 1:(length(points) - 1)
        push!(segments, _MFSegment(points[index], points[index + 1],
            current_A, group_id))
    end
    closed && push!(segments, _MFSegment(points[end], points[1], current_A,
        group_id))
    return segments
end

function _mlv_saddle_points(radius_m::Float64, z_low_m::Float64,
        z_high_m::Float64, phase::Float64, segment_count::Int;
        radial_offset_m::Float64 = 0.0, axial_offset_m::Float64 = 0.0)
    radius = radius_m + radial_offset_m
    zlow = z_low_m + axial_offset_m
    zhigh = z_high_m + axial_offset_m
    side_count = max(8, segment_count ÷ 4)
    arc_count = max(16, segment_count ÷ 2)
    points = _MFPoint[]
    for index in 0:(side_count - 1)
        fraction = index / side_count
        push!(points, (radius * cos(phase), radius * sin(phase),
            zlow + fraction * (zhigh - zlow)))
    end
    for index in 0:(arc_count - 1)
        theta = phase + pi * index / arc_count
        push!(points, (radius * cos(theta), radius * sin(theta), zhigh))
    end
    for index in 0:(side_count - 1)
        fraction = index / side_count
        push!(points, (radius * cos(phase + pi),
            radius * sin(phase + pi), zhigh - fraction * (zhigh - zlow)))
    end
    for index in 0:(arc_count - 1)
        theta = phase + pi - pi * index / arc_count
        push!(points, (radius * cos(theta), radius * sin(theta), zlow))
    end
    return points
end

function _mlv_seam_points(radius_m::Float64, half_span_m::Float64,
        center_z_m::Float64, harmonic::Int, phase::Float64,
        segment_count::Int; radial_offset_m::Float64 = 0.0,
        axial_offset_m::Float64 = 0.0)
    radius = radius_m + radial_offset_m
    count = max(64, 2 * segment_count)
    return _MFPoint[
        (radius * cos(theta + phase), radius * sin(theta + phase),
            center_z_m + axial_offset_m +
                half_span_m * sin(harmonic * theta))
        for theta in range(0.0, 2.0 * pi; length = count + 1)[1:end-1]
    ]
end

function _mlv_layout_segments(layout::String, cell_count::Int,
        end_high_fraction::Float64, central_radius_m::Float64,
        end_radius_m::Float64, half_length_m::Float64, phase::Float64,
        current_A::Float64, segment_count::Int;
        radial_offset_m::Float64 = 0.0, axial_offset_m::Float64 = 0.0)
    segments = _MFSegment[]
    if layout == "split_ioffe_saddle_pair"
        edges = collect(range(-end_high_fraction * half_length_m,
            end_high_fraction * half_length_m; length = cell_count + 1))
        for cell in 1:cell_count
            radius = (cell == 1 || cell == cell_count) ? end_radius_m :
                central_radius_m
            for (pair, offset, sign) in ((1, 0.0, 1.0),
                    (2, 0.5 * pi, -1.0))
                points = _mlv_saddle_points(radius, edges[cell],
                    edges[cell + 1], phase + offset, segment_count;
                    radial_offset_m = radial_offset_m,
                    axial_offset_m = axial_offset_m)
                append!(segments, _mlv_polyline_segments(points,
                    sign * current_A, "split_ioffe_cell_$(cell)_pair_$pair"))
            end
        end
    elseif layout == "continuous_baseball_seam_pair"
        span = end_high_fraction * half_length_m
        for (pair, offset) in ((1, 0.0), (2, 0.5 * pi))
            points = _mlv_seam_points(central_radius_m, span, 0.0,
                cell_count, phase + offset, segment_count;
                radial_offset_m = radial_offset_m,
                axial_offset_m = axial_offset_m)
            append!(segments, _mlv_polyline_segments(points, current_A,
                "continuous_baseball_pair_$pair"))
        end
    elseif layout == "yin_yang_end_anchor_pair"
        anchor_count = max(2, cell_count)
        centers = collect(range(-0.62 * end_high_fraction * half_length_m,
            0.62 * end_high_fraction * half_length_m; length = anchor_count))
        local_span = min(0.30 * half_length_m,
            0.55 * end_high_fraction * half_length_m)
        for (anchor, center) in enumerate(centers)
            for (pair, offset, zsign) in ((1, 0.0, 1.0),
                    (2, 0.5 * pi, -1.0))
                points = _mlv_seam_points(end_radius_m, local_span, center,
                    2, phase + offset, segment_count;
                    radial_offset_m = radial_offset_m,
                    axial_offset_m = axial_offset_m)
                # Reversing both the geometric z phase and traversal current
                # produces the reduced interlinked Yin-Yang pair.
                zsign < 0 && reverse!(points)
                append!(segments, _mlv_polyline_segments(points, current_A,
                    "yin_yang_anchor_$(anchor)_pair_$pair"))
            end
        end
    else
        error("unsupported layout $layout")
    end
    return segments
end

function _mlv_axis_metrics(segments::Vector{_MFSegment}, central_field_T::Float64,
        mirror_ratio::Float64, half_length_m::Float64)
    grid = collect(range(-half_length_m, half_length_m; length = 41))
    target = [_mf_target_field_T(z, central_field_T, mirror_ratio,
        half_length_m) for z in grid]
    magnitudes = Float64[]
    transverse = Float64[]
    for z in grid
        field = _mf_field((0.0, 0.0, z), segments)
        magnitude = _mf_norm(field)
        push!(magnitudes, magnitude)
        push!(transverse, hypot(field[1], field[2]) / max(magnitude, 1.0e-12))
    end
    middle = (length(grid) + 1) ÷ 2
    center = magnitudes[middle]
    throat = 0.5 * (magnitudes[1] + magnitudes[end])
    return Dict{String,Any}(
        "grid_m" => grid,
        "target_T" => target,
        "predicted_T" => magnitudes,
        "center_field_T" => center,
        "throat_field_T" => throat,
        "mirror_ratio" => throat / max(center, 1.0e-12),
        "rms_relative_error" => sqrt(sum(((magnitudes .- target) ./ target).^2) /
            length(target)),
        "maximum_on_axis_transverse_fraction" => maximum(transverse),
    )
end

function _mlv_transverse_wells(segments::Vector{_MFSegment},
        central_field_T::Float64, mirror_ratio::Float64,
        half_length_m::Float64, plasma_radius_m::Float64)
    records = Dict{String,Any}[]
    for (label, z_m) in (("central", 0.0),
            ("left_anchor", -0.55 * half_length_m),
            ("right_anchor", 0.55 * half_length_m))
        local_target = _mf_target_field_T(z_m, central_field_T, mirror_ratio,
            half_length_m)
        local_radius = plasma_radius_m * sqrt(central_field_T / local_target)
        sample_radius = 0.5 * local_radius
        axis_magnitude = _mf_norm(_mf_field((0.0, 0.0, z_m), segments))
        ring = Float64[]
        for theta in range(0.0, 2.0 * pi; length = 9)[1:8]
            point = (sample_radius * cos(theta), sample_radius * sin(theta), z_m)
            push!(ring, _mf_norm(_mf_field(point, segments)))
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

function _mlv_field_line_audit(segments::Vector{_MFSegment},
        central_field_T::Float64, mirror_ratio::Float64,
        half_length_m::Float64, plasma_radius_m::Float64)
    records = Dict{String,Any}[]
    all_reached = true
    maximum_radius = 0.0
    for theta in (0.0, pi / 4.0, pi / 2.0, 3.0 * pi / 4.0)
        seed = (0.5 * plasma_radius_m * cos(theta),
            0.5 * plasma_radius_m * sin(theta), 0.0)
        for direction in (-1.0, 1.0)
            reached, normalized_radius, minimum_abs_bz, final_point =
                _mf_trace_one(seed, direction * half_length_m, segments,
                    central_field_T, mirror_ratio, half_length_m,
                    plasma_radius_m; steps = 96)
            all_reached &= reached
            maximum_radius = max(maximum_radius, normalized_radius)
            push!(records, Dict{String,Any}(
                "seed_m" => collect(seed),
                "target_z_m" => direction * half_length_m,
                "reached_open_end" => reached,
                "maximum_normalized_flux_tube_radius" => normalized_radius,
                "minimum_abs_Bz_T" => minimum_abs_bz,
                "final_point_m" => collect(final_point),
            ))
        end
    end
    return Dict{String,Any}(
        "passed" => all_reached && maximum_radius <= 0.95,
        "all_seeds_reached_both_open_ends" => all_reached,
        "maximum_normalized_flux_tube_radius" => maximum_radius,
        "records" => records,
    )
end

function _mlv_search(evaluator::MirrorLayoutVacuumGeometryV1,
        axis::Dict{String,Any}, source::FieldSource, central_field_T::Float64,
        mirror_ratio::Float64, half_length_m::Float64,
        plasma_radius_m::Float64, pack_m::Float64,
        current_density_limit_A_m2::Float64)
    cell_count = _mlv_integer_parameter(source, "cell_count")
    end_high = _mlv_parameter(source, "end_high_fraction", "1")
    central_scale = _mlv_parameter(source, "central_radius_scale", "1")
    end_scale = _mlv_parameter(source, "end_radius_scale", "1")
    central_radius = axis["central_cage_radius_m"] * central_scale
    end_radius = axis["end_cage_radius_m"] * end_scale
    axis_segments = _mf_centerline_axis_segments(axis,
        evaluator.coarse_segments)
    current_cap = current_density_limit_A_m2 * pack_m^2
    current_grid = collect(range(-current_cap, current_cap; length = 25))
    phases = evaluator.layout == "yin_yang_end_anchor_pair" ?
        (0.0, pi / 8.0, pi / 4.0) : (0.0, pi / 8.0)
    best = nothing
    best_key = (typemax(Int), Inf, Inf, "")
    evaluated = 0
    for phase in phases, current_A in current_grid
        layout_segments = _mlv_layout_segments(evaluator.layout, cell_count,
            end_high, central_radius, end_radius, half_length_m, phase,
            current_A, evaluator.coarse_segments)
        segments = vcat(axis_segments, layout_segments)
        axis_metrics = _mlv_axis_metrics(segments, central_field_T,
            mirror_ratio, half_length_m)
        wells = _mlv_transverse_wells(segments, central_field_T,
            mirror_ratio, half_length_m, plasma_radius_m)
        minimum_well = minimum(record["minimum_well_fraction"] for record in wells)
        center_error = abs(axis_metrics["center_field_T"] / central_field_T - 1.0)
        ratio_error = abs(axis_metrics["mirror_ratio"] / mirror_ratio - 1.0)
        failures = Int(center_error > 0.03) + Int(ratio_error > 0.05) +
            Int(axis_metrics["rms_relative_error"] > 0.10) +
            Int(axis_metrics["maximum_on_axis_transverse_fraction"] > 0.01) +
            Int(minimum_well < 0.002)
        score = 3.0 * center_error + 2.0 * ratio_error +
            axis_metrics["rms_relative_error"] +
            2.0 * axis_metrics["maximum_on_axis_transverse_fraction"] +
            10.0 * max(0.0, 0.002 - minimum_well) +
            0.02 * abs(current_A) / max(current_cap, 1.0)
        geometry_hash = canonical_hash(Dict("phase" => phase,
            "current_A" => current_A, "layout" => evaluator.layout))
        key = (failures, score, abs(current_A), geometry_hash)
        if key < best_key
            best_key = key
            best = Dict{String,Any}(
                "current_A_turn" => current_A,
                "phase_rad" => phase,
                "cell_count" => cell_count,
                "end_high_fraction" => end_high,
                "central_radius_m" => central_radius,
                "end_radius_m" => end_radius,
                "axis_metrics" => axis_metrics,
                "well_records" => wells,
                "minimum_well_fraction" => minimum_well,
                "coarse_gate_failures" => failures,
                "coarse_score" => score,
            )
        end
        evaluated += 1
    end
    best["evaluated_phase_current_count"] = evaluated
    best["current_cap_A_turn"] = current_cap
    return best
end

function _mlv_full_centerline_segments(evaluator::MirrorLayoutVacuumGeometryV1,
        axis::Dict{String,Any}, selected::Dict{String,Any},
        half_length_m::Float64, segment_count::Int)
    axis_segments = _mf_centerline_axis_segments(axis, segment_count)
    layout_segments = _mlv_layout_segments(evaluator.layout,
        selected["cell_count"], selected["end_high_fraction"],
        selected["central_radius_m"], selected["end_radius_m"],
        half_length_m, selected["phase_rad"], selected["current_A_turn"],
        segment_count)
    return vcat(axis_segments, layout_segments)
end

function _mlv_distributed_segments(evaluator::MirrorLayoutVacuumGeometryV1,
        axis::Dict{String,Any}, selected::Dict{String,Any},
        half_length_m::Float64, pack_m::Float64, pack_grid::Int,
        segment_count::Int)
    offsets = [(-0.5 + (index - 0.5) / pack_grid) * pack_m
        for index in 1:pack_grid]
    segments = _MFSegment[]
    for index in eachindex(axis["positions_m"])
        total_current = axis["currents_A"][index]
        total_current > 1.0e4 || continue
        filament_current = total_current / pack_grid^2
        for sign in (-1.0, 1.0), radial_offset in offsets,
                axial_offset in offsets
            append!(segments, _mf_circle_segments(
                axis["radii_m"][index] + radial_offset,
                sign * axis["positions_m"][index] + axial_offset,
                filament_current, segment_count,
                "axis_pair_$(index)_$(sign < 0 ? "minus" : "plus")"))
        end
    end
    filament_current = selected["current_A_turn"] / pack_grid^2
    for radial_offset in offsets, axial_offset in offsets
        append!(segments, _mlv_layout_segments(evaluator.layout,
            selected["cell_count"], selected["end_high_fraction"],
            selected["central_radius_m"], selected["end_radius_m"],
            half_length_m, selected["phase_rad"], filament_current,
            segment_count; radial_offset_m = radial_offset,
            axial_offset_m = axial_offset))
    end
    return segments
end

function _mlv_peak_winding_field(evaluator::MirrorLayoutVacuumGeometryV1,
        axis::Dict{String,Any}, selected::Dict{String,Any},
        half_length_m::Float64, pack_m::Float64, pack_grid::Int,
        segment_count::Int)
    distributed = _mlv_distributed_segments(evaluator, axis, selected,
        half_length_m, pack_m, pack_grid, segment_count)
    samples = Tuple{String,_MFPoint}[]
    for index in eachindex(axis["positions_m"])
        axis["currents_A"][index] > 1.0e4 || continue
        for sign in (-1.0, 1.0), theta in (0.0, pi / 2.0),
                radial_sign in (-1.0, 1.0)
            radius = axis["radii_m"][index] + radial_sign * 0.5 * pack_m
            push!(samples, ("axis_pair_$index",
                (radius * cos(theta), radius * sin(theta),
                    sign * axis["positions_m"][index])))
        end
    end
    centerline_layout = _mlv_layout_segments(evaluator.layout,
        selected["cell_count"], selected["end_high_fraction"],
        selected["central_radius_m"], selected["end_radius_m"],
        half_length_m, selected["phase_rad"], selected["current_A_turn"],
        segment_count)
    stride = max(1, length(centerline_layout) ÷ 96)
    for segment in centerline_layout[1:stride:end]
        midpoint = (0.5 * (segment.p1[1] + segment.p2[1]),
            0.5 * (segment.p1[2] + segment.p2[2]),
            0.5 * (segment.p1[3] + segment.p2[3]))
        radial_norm = max(hypot(midpoint[1], midpoint[2]), 1.0e-12)
        for sign in (-1.0, 1.0)
            push!(samples, (segment.group_id,
                (midpoint[1] + sign * 0.5 * pack_m * midpoint[1] / radial_norm,
                 midpoint[2] + sign * 0.5 * pack_m * midpoint[2] / radial_norm,
                 midpoint[3])))
        end
    end
    maximum_field = -Inf
    maximum_record = nothing
    for (group_id, point) in samples
        field = _mf_field(point, distributed)
        magnitude = _mf_norm(field)
        if magnitude > maximum_field
            maximum_field = magnitude
            maximum_record = Dict{String,Any}(
                "group_id" => group_id,
                "point_m" => collect(point),
                "field_vector_T" => collect(field),
                "field_magnitude_T" => magnitude,
            )
        end
    end
    return Dict{String,Any}(
        "peak_field_T" => maximum_field,
        "peak_record" => maximum_record,
        "pack_grid" => pack_grid,
        "centerline_segments_per_loop" => segment_count,
        "field_sample_count" => length(samples),
        "biot_savart_segment_count" => length(distributed),
    )
end

function _mlv_geometry_summary(evaluator::MirrorLayoutVacuumGeometryV1,
        genome::Genome)
    source = _mlv_layout_source(genome)
    source === nothing && error("missing supported layout source")
    core = only(filter(region -> region.kind == "mirror_central_cell",
        genome.plasma_regions))
    central_field_T = _mirror_reduced_parameter(core, "central_field", "T")
    mirror_ratio = _mirror_reduced_parameter(core, "mirror_ratio_gene", "1")
    cell_length_m = _mirror_reduced_parameter(core, "cell_length", "m")
    plasma_radius_m = _mirror_reduced_parameter(core, "plasma_radius", "m")
    half_length_m = 0.5 * cell_length_m
    axis_field_share = _mlv_parameter(source, "axis_field_share", "1")
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
    selected = _mlv_search(evaluator, axis, source, central_field_T,
        mirror_ratio, half_length_m, plasma_radius_m, pack_m,
        current_density_limit_A_m2)
    full_segments = _mlv_full_centerline_segments(evaluator, axis, selected,
        half_length_m, evaluator.refined_segments)
    refined_axis = _mlv_axis_metrics(full_segments, central_field_T,
        mirror_ratio, half_length_m)
    refined_wells = _mlv_transverse_wells(full_segments, central_field_T,
        mirror_ratio, half_length_m, plasma_radius_m)
    refined_minimum_well = minimum(record["minimum_well_fraction"]
        for record in refined_wells)
    field_lines = _mlv_field_line_audit(full_segments, central_field_T,
        mirror_ratio, half_length_m, plasma_radius_m)
    coarse_peak = _mlv_peak_winding_field(evaluator, axis, selected,
        half_length_m, pack_m, evaluator.coarse_pack_grid,
        evaluator.coarse_segments)
    refined_peak = _mlv_peak_winding_field(evaluator, axis, selected,
        half_length_m, pack_m, evaluator.refined_pack_grid,
        evaluator.refined_segments)
    peak_change = abs(refined_peak["peak_field_T"] -
        coarse_peak["peak_field_T"]) / max(refined_peak["peak_field_T"], 1.0e-12)

    center_error = abs(refined_axis["center_field_T"] / central_field_T - 1.0)
    ratio_error = abs(refined_axis["mirror_ratio"] / mirror_ratio - 1.0)
    axis_passed = center_error <= 0.03 && ratio_error <= 0.05 &&
        refined_axis["rms_relative_error"] <= 0.10 &&
        refined_axis["maximum_on_axis_transverse_fraction"] <= 0.01
    well_passed = refined_minimum_well >= 0.002
    peak_passed = refined_peak["peak_field_T"] <=
        contract.peak_conductor_field_limit_T
    maximum_axis_current_density = maximum(axis["currents_A"]) / pack_m^2
    layout_current_density = abs(selected["current_A_turn"]) / pack_m^2
    maximum_current_density = max(maximum_axis_current_density,
        layout_current_density)
    current_density_passed = maximum_current_density <=
        current_density_limit_A_m2
    central_clearance = selected["central_radius_m"] - 0.5 * pack_m -
        plasma_radius_m - shield_m - maintenance_m
    anchor_z = 0.55 * half_length_m
    anchor_target = _mf_target_field_T(anchor_z, central_field_T,
        mirror_ratio, half_length_m)
    anchor_plasma_radius = plasma_radius_m * sqrt(central_field_T / anchor_target)
    end_clearance = selected["end_radius_m"] - 0.5 * pack_m -
        anchor_plasma_radius - shield_m - maintenance_m
    minimum_clearance = min(central_clearance, end_clearance)
    clearance_passed = minimum_clearance >= 0.0
    reserved_bend_radius_m = min(0.40,
        0.45 * min(selected["central_radius_m"], selected["end_radius_m"]))
    bend_passed = reserved_bend_radius_m >=
        contract.minimum_coil_curvature_radius_m
    resolution_passed = peak_change <= 0.15
    magnetic_pressure_Pa = refined_peak["peak_field_T"]^2 /
        (2.0 * 4.0 * pi * 1.0e-7)
    support_stress_proxy_Pa = magnetic_pressure_Pa *
        max(selected["central_radius_m"], selected["end_radius_m"]) /
        _screen_target(genome, "screen_support_thickness", 0.7, "m")
    support_passed = support_stress_proxy_Pa <= contract.support_stress_limit_Pa
    gates = Dict{String,Bool}(
        "axis_field_and_mirror_ratio" => axis_passed,
        "transverse_minimum_b_well" => well_passed,
        "open_field_line_integrity" => field_lines["passed"],
        "finite_build_peak_field" => peak_passed,
        "winding_current_density" => current_density_passed,
        "plasma_shield_maintenance_and_coil_clearance" => clearance_passed,
        "minimum_bend_radius_reservation" => bend_passed,
        "membrane_support_stress_proxy" => support_passed,
        "biot_savart_resolution_audit" => resolution_passed,
    )
    passed = all(values(gates))
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
    return Dict{String,Any}(
        "model" => "reduced_explicit_$(evaluator.layout)_plus_tapered_axis_coils_v1",
        "layout" => evaluator.layout,
        "inputs" => Dict(
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
        "geometry_search" => Dict(
            "method" => "deterministic_axis_random_starts_plus_layout_phase_current_scan",
            "seed" => evaluator.seed,
            "axis_random_starts" => evaluator.random_starts,
            "axis_geometry_evaluations" => axis["evaluated_geometry_count"],
            "layout_phase_current_evaluations" =>
                selected["evaluated_phase_current_count"],
            "opposing_axis_currents_allowed" => false,
        ),
        "axis_system" => Dict(
            "active_symmetric_coil_pairs" => active_pairs,
            "active_pair_count" => length(active_pairs),
            "axis_only_center_field_T" => axis["center_field_T"],
            "combined_refined" => refined_axis,
        ),
        "minimum_b_system" => Dict(
            "layout" => evaluator.layout,
            "cell_count" => selected["cell_count"],
            "end_high_fraction" => selected["end_high_fraction"],
            "central_radius_m" => selected["central_radius_m"],
            "end_radius_m" => selected["end_radius_m"],
            "phase_rad" => selected["phase_rad"],
            "current_A_turn" => selected["current_A_turn"],
            "current_cap_A_turn" => selected["current_cap_A_turn"],
            "well_records" => refined_wells,
            "minimum_well_fraction" => refined_minimum_well,
        ),
        "finite_build" => Dict(
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
        "all_geometry_gates_passed" => passed,
        "disposition" => passed ?
            "vacuum_geometry_provisional_advance_with_blocking_unknowns" :
            "rejected_before_anisotropic_equilibrium",
        "blocking_unknowns_after_geometry" => passed ? String[
            "anisotropic finite-beta equilibrium",
            "interchange DCLC AIC and microstability",
            "mutual coil forces detailed supports quench and critical surface",
            "Fokker-Planck end loss and exhaust power recovery",
        ] : String[
            "failed layout-specific vacuum geometry gates must be repaired",
        ],
        "claim_boundary" => _MIRROR_LAYOUT_VACUUM_CLAIM_BOUNDARY,
    )
end

function _mlv_metric(evaluator::MirrorLayoutVacuumGeometryV1, id::String,
        value; unit::String = "1", status::Symbol = :pass,
        input_hash::String, run_hash::String, warnings::Vector{String},
        constraints::Vector{String} = String[],
        uncertainty::Union{Nothing,Float64} = nothing)
    return MetricResult(id, value;
        unit = unit, uncertainty = uncertainty, fidelity = 1,
        applicability = "Layout-specific finite-build vacuum mirror geometry audit.",
        status = status, constraints_checked = constraints,
        solver_name = _mlv_task_id(evaluator.layout),
        solver_version = "1.0.0", input_hash = input_hash,
        run_hash = run_hash, source_basis = _MIRROR_LAYOUT_VACUUM_SOURCE_BASIS,
        warnings = warnings, wall_time_s = 0.0)
end

function run_evaluator(evaluator::MirrorLayoutVacuumGeometryV1,
        genome::Genome; kwargs...)
    summary = _mlv_geometry_summary(evaluator, genome)
    task_id = _mlv_task_id(evaluator.layout)
    run_hash = canonical_hash(Dict(
        "evaluator" => task_id,
        "version" => "1.0.0",
        "input_hash" => genome.physics_hash,
        "configuration" => Dict(
            "random_starts" => evaluator.random_starts,
            "seed" => evaluator.seed,
            "coarse_segments" => evaluator.coarse_segments,
            "refined_segments" => evaluator.refined_segments,
            "coarse_pack_grid" => evaluator.coarse_pack_grid,
            "refined_pack_grid" => evaluator.refined_pack_grid,
        ),
        "summary" => summary,
    ))
    warnings = String[
        _MIRROR_LAYOUT_VACUUM_CLAIM_BOUNDARY,
        "Historical coil-family names label reduced topology primitives; the centerlines are explicit in this evaluator but are not detailed reproductions of a specific machine.",
        "Peak field is a distributed-filament stand-off audit under a generic square winding pack, not a superconducting material qualification.",
        "Sharp saddle transitions retain a 0.40 m engineering bend reservation; conductor bends and joints are not resolved solids.",
    ]
    gates = summary["gates"]
    finite = summary["finite_build"]
    axis = summary["axis_system"]["combined_refined"]
    minimum_b = summary["minimum_b_system"]
    pass_or_fail(value) = value ? :pass : :fail
    metrics = MetricResult[
        _mlv_metric(evaluator, "layout_specific_vacuum_geometry_summary",
            summary; status = pass_or_fail(summary["all_geometry_gates_passed"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mlv_metric(evaluator, "vacuum_axis_center_field",
            axis["center_field_T"]; unit = "T",
            status = pass_or_fail(gates["axis_field_and_mirror_ratio"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mlv_metric(evaluator, "vacuum_sampled_mirror_ratio",
            axis["mirror_ratio"];
            status = pass_or_fail(gates["axis_field_and_mirror_ratio"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mlv_metric(evaluator, "axis_field_rms_relative_error",
            axis["rms_relative_error"];
            status = pass_or_fail(gates["axis_field_and_mirror_ratio"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mlv_metric(evaluator, "minimum_sampled_transverse_well_fraction",
            minimum_b["minimum_well_fraction"];
            status = pass_or_fail(gates["transverse_minimum_b_well"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings,
            constraints = ["minimum ring-to-axis |B| well fraction >= 0.002"]),
        _mlv_metric(evaluator, "open_field_line_integrity_passed",
            summary["field_line_audit"]["passed"];
            status = pass_or_fail(gates["open_field_line_integrity"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mlv_metric(evaluator, "refined_peak_winding_field",
            finite["refined_peak_field"]["peak_field_T"]; unit = "T",
            status = pass_or_fail(gates["finite_build_peak_field"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings,
            constraints = ["peak winding field <= 24 T"],
            uncertainty = finite["peak_field_resolution_change_fraction"]),
        _mlv_metric(evaluator, "finite_build_field_resolution_audit_passed",
            gates["biot_savart_resolution_audit"];
            status = pass_or_fail(gates["biot_savart_resolution_audit"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings,
            constraints = ["coarse/refined stand-off peak-field change <= 0.15"]),
        _mlv_metric(evaluator, "maximum_engineering_current_density",
            finite["maximum_current_density_A_m2"]; unit = "A/m^2",
            status = pass_or_fail(gates["winding_current_density"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mlv_metric(evaluator, "minimum_declared_coil_clearance_margin",
            finite["minimum_declared_clearance_margin_m"]; unit = "m",
            status = pass_or_fail(
                gates["plasma_shield_maintenance_and_coil_clearance"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mlv_metric(evaluator, "membrane_support_stress_proxy",
            finite["membrane_support_stress_proxy_Pa"]; unit = "Pa",
            status = pass_or_fail(gates["membrane_support_stress_proxy"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mlv_metric(evaluator, "layout_specific_vacuum_geometry_disposition",
            summary["disposition"];
            status = pass_or_fail(summary["all_geometry_gates_passed"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
    ]
    if summary["all_geometry_gates_passed"]
        for (id, message) in (
                ("anisotropic_finite_beta_equilibrium_feasible",
                    "vacuum geometry does not solve anisotropic finite-beta equilibrium"),
                ("fokker_planck_end_loss_feasible",
                    "vacuum geometry does not calculate collisional end loss"),
                ("interchange_and_microstability_feasible",
                    "vacuum geometry does not solve interchange or kinetic microstability"))
            push!(metrics, _mlv_metric(evaluator, id, nothing; status = :unknown,
                input_hash = genome.physics_hash, run_hash = run_hash,
                warnings = vcat(warnings, [message])))
        end
    end
    status = summary["all_geometry_gates_passed"] ? :pass : :fail
    return EvaluationBundle(task_id, genome.design_id, genome.family, 1,
        status, metrics, warnings, genome.physics_hash, run_hash,
        "physics_proxy")
end
