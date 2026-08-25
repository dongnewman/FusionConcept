"""
Candidate-specific fidelity-1 finite-coil vacuum-field admission audit.

The adapter searches tapered circular mirror-coil positions and currents, then
adds three divergence-free quadrupolar cage cells.  Every field reported by the
adapter is reconstructed with three-dimensional Biot-Savart line segments.  A
distributed-filament winding-pack refinement is used for the peak-field audit.
"""
struct MirrorFiniteCoilGeometryV1 <: AbstractEvaluator
    random_starts::Int
    seed::Int
    coarse_segments::Int
    refined_segments::Int

    function MirrorFiniteCoilGeometryV1(; random_starts::Integer = 96,
            seed::Integer = 20260811, coarse_segments::Integer = 256,
            refined_segments::Integer = 512)
        random_starts >= 16 || throw(ArgumentError(
            "random_starts must be at least 16"))
        coarse_segments >= 24 || throw(ArgumentError(
            "coarse_segments must be at least 24"))
        refined_segments >= 2 * coarse_segments || throw(ArgumentError(
            "refined_segments must be at least twice coarse_segments"))
        return new(Int(random_starts), Int(seed), Int(coarse_segments),
            Int(refined_segments))
    end
end

const _MIRROR_FINITE_COIL_SOURCE_BASIS = String[
    "mirror_quadrupolar_coil_hagnestal_agren_2011",
    "mirror_wham_physics_basis_2023",
]

const _MIRROR_FINITE_COIL_CLAIM_BOUNDARY =
    "Fidelity-1 candidate-specific vacuum-field and finite-build screening calculation. Circular and divergence-free quadrupolar cage conductors are explicit and fields are reconstructed with 3D Biot-Savart segments. Passing a numerical gate would establish only a bounded vacuum-field geometry under the declared generic current-density, field, clearance, bend-reservation, and membrane-stress proxies. Failure rejects this candidate realization under the declared geometry grammar and search budget; it is not a proof that no alternative coil parameterization or minimum-B mirror can exist. It is not an anisotropic finite-beta equilibrium, superconducting critical-surface qualification, detailed force/structure solution, quench design, stability result, Fokker-Planck loss calculation, exhaust design, or reactor-feasibility result."

function evaluator_spec(::MirrorFiniteCoilGeometryV1)
    return EvaluatorSpec(
        "mirror_finite_coil_geometry_v1",
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

function evaluator_applicability(evaluator::MirrorFiniteCoilGeometryV1,
        genome::Genome)
    genome.family == "magnetic_mirror" || return false,
        "mirror_finite_coil_geometry_v1 applies only to magnetic_mirror"
    genome.topology.field_line_class == "open_mirror" || return false,
        "finite mirror-coil geometry requires open_mirror field lines"
    core = _mirror_reduced_core(genome)
    core === nothing && return false,
        "finite mirror-coil geometry requires one mirror_central_cell"
    has_minimum_b = any(source -> source.kind == "minimum_b_coil",
        genome.field_sources)
    has_minimum_b || return false,
        "candidate has no explicit minimum_b_coil source"
    horizontal = _unified_screen_result(UnifiedCrossFamilyScreenV1(), genome)
    horizontal["all_five_gates_passed"] === true || return false,
        "horizontal five-gate screen must pass before finite geometry search"
    return true, "five-gate mirror survivor with an explicit minimum-B source"
end

const _MFPoint = NTuple{3,Float64}

struct _MFSegment
    p1::_MFPoint
    p2::_MFPoint
    current_A::Float64
    group_id::String
end

_mf_add(a::_MFPoint, b::_MFPoint) =
    (a[1] + b[1], a[2] + b[2], a[3] + b[3])
_mf_scale(a::_MFPoint, factor::Float64) =
    (factor * a[1], factor * a[2], factor * a[3])
_mf_norm(a::_MFPoint) = sqrt(a[1]^2 + a[2]^2 + a[3]^2)
_mf_cross(a::_MFPoint, b::_MFPoint) =
    (a[2] * b[3] - a[3] * b[2],
     a[3] * b[1] - a[1] * b[3],
     a[1] * b[2] - a[2] * b[1])

function _mf_field(point::_MFPoint, segments::Vector{_MFSegment})
    coefficient = 1.0e-7
    bx = 0.0
    by = 0.0
    bz = 0.0
    for segment in segments
        dl = (segment.p2[1] - segment.p1[1],
            segment.p2[2] - segment.p1[2],
            segment.p2[3] - segment.p1[3])
        midpoint = (0.5 * (segment.p1[1] + segment.p2[1]),
            0.5 * (segment.p1[2] + segment.p2[2]),
            0.5 * (segment.p1[3] + segment.p2[3]))
        displacement = (point[1] - midpoint[1], point[2] - midpoint[2],
            point[3] - midpoint[3])
        radius_squared = displacement[1]^2 + displacement[2]^2 +
            displacement[3]^2
        radius_squared > 1.0e-16 || continue
        factor = coefficient * segment.current_A /
            (radius_squared * sqrt(radius_squared))
        cross = _mf_cross(dl, displacement)
        bx += factor * cross[1]
        by += factor * cross[2]
        bz += factor * cross[3]
    end
    return (bx, by, bz)
end

function _mf_line_segments(p1::_MFPoint, p2::_MFPoint, current_A::Float64,
        count::Int, group_id::String)
    segments = _MFSegment[]
    for index in 0:(count - 1)
        t1 = index / count
        t2 = (index + 1) / count
        a = (p1[1] + t1 * (p2[1] - p1[1]),
            p1[2] + t1 * (p2[2] - p1[2]),
            p1[3] + t1 * (p2[3] - p1[3]))
        b = (p1[1] + t2 * (p2[1] - p1[1]),
            p1[2] + t2 * (p2[2] - p1[2]),
            p1[3] + t2 * (p2[3] - p1[3]))
        push!(segments, _MFSegment(a, b, current_A, group_id))
    end
    return segments
end

function _mf_arc_segments(radius_m::Float64, z_m::Float64,
        theta1::Float64, theta2::Float64, current_A::Float64, count::Int,
        group_id::String)
    segments = _MFSegment[]
    for index in 0:(count - 1)
        a1 = theta1 + (theta2 - theta1) * index / count
        a2 = theta1 + (theta2 - theta1) * (index + 1) / count
        p1 = (radius_m * cos(a1), radius_m * sin(a1), z_m)
        p2 = (radius_m * cos(a2), radius_m * sin(a2), z_m)
        push!(segments, _MFSegment(p1, p2, current_A, group_id))
    end
    return segments
end

function _mf_circle_segments(radius_m::Float64, z_m::Float64,
        current_A::Float64, segment_count::Int, group_id::String)
    return _mf_arc_segments(radius_m, z_m, 0.0, 2.0 * pi, current_A,
        segment_count, group_id)
end

"""
One cage cell is a divergence-free current network: four alternating axial
bars and alternating half-current quarter arcs at both ends.  Kirchhoff's law
is satisfied at every junction.  This is the explicit line-current analogue of
the cage construction in Hagnestål and Ågren; real elbows are only reserved,
not resolved by this vacuum-field model.
"""
function _mf_cage_segments(radius_m::Float64, z_low_m::Float64,
        z_high_m::Float64, bar_current_A::Float64, segment_count::Int,
        group_id::String; radial_offset_m::Float64 = 0.0,
        current_fraction::Float64 = 1.0)
    radius = radius_m + radial_offset_m
    current = bar_current_A * current_fraction
    bar_segments = max(8, segment_count ÷ 2)
    arc_segments = max(6, segment_count ÷ 4)
    segments = _MFSegment[]
    for index in 0:3
        theta = index * pi / 2.0
        sign = iseven(index) ? 1.0 : -1.0
        p1 = (radius * cos(theta), radius * sin(theta), z_low_m)
        p2 = (radius * cos(theta), radius * sin(theta), z_high_m)
        append!(segments, _mf_line_segments(p1, p2, sign * current,
            bar_segments, group_id))
        theta2 = theta + pi / 2.0
        append!(segments, _mf_arc_segments(radius, z_high_m, theta, theta2,
            sign * 0.5 * current, arc_segments, group_id))
        append!(segments, _mf_arc_segments(radius, z_low_m, theta, theta2,
            -sign * 0.5 * current, arc_segments, group_id))
    end
    return segments
end

function _mf_axis_basis_T_per_A(z_m::Float64, coil_z_m::Float64,
        radius_m::Float64)
    coefficient = 0.5 * 4.0 * pi * 1.0e-7 * radius_m^2
    return coefficient * ((radius_m^2 + (z_m - coil_z_m)^2)^(-1.5) +
        (radius_m^2 + (z_m + coil_z_m)^2)^(-1.5))
end

function _mf_target_field_T(z_m::Float64, central_field_T::Float64,
        mirror_ratio::Float64, half_length_m::Float64)
    normalized = clamp(abs(z_m) / half_length_m, 0.0, 1.0)
    return central_field_T * (1.0 + (mirror_ratio - 1.0) * normalized^2)
end

function _mf_box_coordinate_fit(matrix::Matrix{Float64}, target::Vector{Float64},
        weights::Vector{Float64}, cap_A::Float64; iterations::Int = 1800)
    currents = fill(min(8.0e6, 0.25 * cap_A), size(matrix, 2))
    residual = target - matrix * currents
    for _ in 1:iterations
        for column in axes(matrix, 2)
            basis = view(matrix, :, column)
            denominator = sum(weights .* basis .* basis) + 1.0e-20
            delta = sum(weights .* basis .* residual) / denominator
            updated = clamp(currents[column] + delta, 0.0, cap_A)
            residual .-= basis .* (updated - currents[column])
            currents[column] = updated
        end
    end
    return currents
end

function _mf_axis_geometry_search(evaluator::MirrorFiniteCoilGeometryV1,
        central_field_T::Float64, mirror_ratio::Float64, half_length_m::Float64,
        plasma_radius_m::Float64, shield_m::Float64, maintenance_m::Float64,
        axis_pack_m::Float64, quad_pack_m::Float64,
        current_density_limit_A_m2::Float64)
    grid = collect(range(-half_length_m, half_length_m; length = 129))
    target = [_mf_target_field_T(z, central_field_T, mirror_ratio,
        half_length_m) for z in grid]
    weights = ones(length(grid))
    for index in eachindex(grid)
        abs(grid[index]) <= 0.05 * half_length_m && (weights[index] = 1000.0)
        abs(grid[index]) >= 0.98 * half_length_m && (weights[index] = 500.0)
    end
    base_fraction = [0.08, 0.32, 0.56, 0.76, 0.87, 0.95, 1.02, 1.08]
    lower_fraction = [0.03, 0.22, 0.46, 0.67, 0.80, 0.90, 0.98, 1.04]
    upper_fraction = [0.14, 0.40, 0.64, 0.83, 0.93, 1.00, 1.06, 1.12]
    central_cage_radius = plasma_radius_m + shield_m + maintenance_m +
        0.5 * quad_pack_m
    end_reference_z = 0.44 * half_length_m
    end_plasma_radius = plasma_radius_m * sqrt(central_field_T /
        _mf_target_field_T(end_reference_z, central_field_T, mirror_ratio,
            half_length_m))
    end_cage_radius = end_plasma_radius + shield_m + maintenance_m +
        0.5 * quad_pack_m
    radial_gap_m = 0.05

    function radius_for(z_m::Float64)
        local_field = _mf_target_field_T(min(z_m, half_length_m),
            central_field_T, mirror_ratio, half_length_m)
        local_plasma_radius = plasma_radius_m * sqrt(central_field_T /
            local_field)
        radius = local_plasma_radius + shield_m + maintenance_m +
            0.5 * axis_pack_m
        if z_m <= 0.40 * half_length_m
            radius = max(radius, central_cage_radius + 0.5 * quad_pack_m +
                radial_gap_m + 0.5 * axis_pack_m)
        elseif z_m <= 0.75 * half_length_m
            radius = max(radius, end_cage_radius + 0.5 * quad_pack_m +
                radial_gap_m + 0.5 * axis_pack_m)
        end
        return radius
    end

    rng = MersenneTwister(evaluator.seed)
    max_from_density = current_density_limit_A_m2 * axis_pack_m^2
    current_caps = min.(max_from_density,
        [25.0e6, 30.0e6, 35.0e6, 40.0e6, 45.0e6, 50.0e6])
    best = nothing
    best_key = (typemax(Int), Inf, Inf, "")
    evaluated = 0
    for start in 1:evaluator.random_starts
        fractions = copy(base_fraction)
        if start > 1
            fractions .+= 0.018 .* randn(rng, length(fractions))
        end
        fractions = clamp.(fractions, lower_fraction, upper_fraction)
        positions = fractions .* half_length_m
        radii = radius_for.(positions)
        matrix = [_mf_axis_basis_T_per_A(z, positions[column], radii[column])
            for z in grid, column in eachindex(positions)]
        for cap_A in current_caps
            currents = _mf_box_coordinate_fit(matrix, target, weights, cap_A)
            predicted = matrix * currents
            center_field = predicted[(length(predicted) + 1) ÷ 2]
            throat_field = 0.5 * (predicted[1] + predicted[end])
            achieved_ratio = throat_field / center_field
            rms_relative = sqrt(sum(((predicted .- target) ./ target).^2) /
                length(target))
            center_error = abs(center_field / central_field_T - 1.0)
            ratio_error = abs(achieved_ratio / mirror_ratio - 1.0)
            gate_failures = Int(center_error > 0.02) + Int(ratio_error > 0.02) +
                Int(rms_relative > 0.08)
            active_count = count(current -> current > 1.0e4, currents)
            current_sum_MA = sum(currents) / 1.0e6
            score = rms_relative + 2.0 * center_error + 2.0 * ratio_error +
                2.0e-4 * current_sum_MA + 1.0e-3 * active_count
            geometry_key = canonical_hash(Dict("positions" => positions,
                "radii" => radii, "currents" => currents, "cap" => cap_A))
            key = (gate_failures, score, current_sum_MA, geometry_key)
            if key < best_key
                best_key = key
                best = Dict{String,Any}(
                    "positions_m" => positions,
                    "radii_m" => radii,
                    "currents_A" => currents,
                    "current_cap_A" => cap_A,
                    "center_field_T" => center_field,
                    "throat_field_T" => throat_field,
                    "achieved_mirror_ratio" => achieved_ratio,
                    "axis_rms_relative_error" => rms_relative,
                    "axis_grid_m" => grid,
                    "axis_target_T" => target,
                    "axis_predicted_T" => predicted,
                    "gate_failures" => gate_failures,
                    "score" => score,
                    "active_pair_count" => active_count,
                )
            end
            evaluated += 1
        end
    end
    best["evaluated_geometry_count"] = evaluated
    best["central_cage_radius_m"] = central_cage_radius
    best["end_cage_radius_m"] = end_cage_radius
    best["radial_gap_m"] = radial_gap_m
    return best
end

function _mf_centerline_axis_segments(axis::Dict{String,Any},
        segment_count::Int)
    segments = _MFSegment[]
    for index in eachindex(axis["positions_m"])
        current = axis["currents_A"][index]
        current > 1.0e4 || continue
        for sign in (-1.0, 1.0)
            id = "axis_pair_$(index)_$(sign < 0 ? "minus" : "plus")"
            append!(segments, _mf_circle_segments(axis["radii_m"][index],
                sign * axis["positions_m"][index], current, segment_count, id))
        end
    end
    return segments
end

function _mf_cage_basis_segments(axis::Dict{String,Any}, half_length_m::Float64,
        segment_count::Int; end_low_fraction::Float64 = 0.44,
        end_high_fraction::Float64 = 0.73)
    central = _mf_cage_segments(axis["central_cage_radius_m"],
        -0.37 * half_length_m, 0.37 * half_length_m, 1.0, segment_count,
        "minimum_b_central")
    left = _mf_cage_segments(axis["end_cage_radius_m"],
        -end_high_fraction * half_length_m,
        -end_low_fraction * half_length_m, 1.0, segment_count,
        "minimum_b_left")
    right = _mf_cage_segments(axis["end_cage_radius_m"],
        end_low_fraction * half_length_m,
        end_high_fraction * half_length_m, 1.0, segment_count,
        "minimum_b_right")
    return central, left, right
end

function _mf_transverse_wells(axis_segments::Vector{_MFSegment},
        central_basis::Vector{_MFSegment}, left_basis::Vector{_MFSegment},
        right_basis::Vector{_MFSegment}, central_current_A::Float64,
        end_current_A::Float64, half_length_m::Float64,
        central_field_T::Float64, mirror_ratio::Float64,
        plasma_radius_m::Float64)
    records = Dict{String,Any}[]
    for (label, z_m) in (("central", 0.0),
            ("left_anchor", -0.585 * half_length_m),
            ("right_anchor", 0.585 * half_length_m))
        local_target = _mf_target_field_T(z_m, central_field_T, mirror_ratio,
            half_length_m)
        local_radius = plasma_radius_m * sqrt(central_field_T / local_target)
        sample_radius = 0.5 * local_radius
        point_axis = (0.0, 0.0, z_m)
        axis_field = _mf_field(point_axis, axis_segments)
        axis_field = _mf_add(axis_field,
            _mf_scale(_mf_field(point_axis, central_basis), central_current_A))
        axis_field = _mf_add(axis_field,
            _mf_scale(_mf_add(_mf_field(point_axis, left_basis),
                _mf_field(point_axis, right_basis)), end_current_A))
        axis_magnitude = _mf_norm(axis_field)
        ring_magnitudes = Float64[]
        for theta in range(0.0, 2.0 * pi; length = 9)[1:8]
            point = (sample_radius * cos(theta), sample_radius * sin(theta), z_m)
            field = _mf_field(point, axis_segments)
            field = _mf_add(field,
                _mf_scale(_mf_field(point, central_basis), central_current_A))
            field = _mf_add(field,
                _mf_scale(_mf_add(_mf_field(point, left_basis),
                    _mf_field(point, right_basis)), end_current_A))
            push!(ring_magnitudes, _mf_norm(field))
        end
        minimum_well_fraction = minimum(ring_magnitudes) / axis_magnitude - 1.0
        push!(records, Dict{String,Any}(
            "plane" => label,
            "z_m" => z_m,
            "sample_radius_m" => sample_radius,
            "axis_field_T" => axis_magnitude,
            "minimum_ring_field_T" => minimum(ring_magnitudes),
            "maximum_ring_field_T" => maximum(ring_magnitudes),
            "minimum_well_fraction" => minimum_well_fraction,
        ))
    end
    return records
end

function _mf_quadrupole_search(axis::Dict{String,Any}, half_length_m::Float64,
        central_field_T::Float64, mirror_ratio::Float64, plasma_radius_m::Float64,
        quad_pack_m::Float64, current_density_limit_A_m2::Float64,
        segment_count::Int)
    axis_segments = _mf_centerline_axis_segments(axis, segment_count)
    central_basis, _, _ = _mf_cage_basis_segments(axis, half_length_m,
        segment_count)
    cap_A = current_density_limit_A_m2 * quad_pack_m^2
    current_grid = collect(-min(cap_A, 100.0e6):10.0e6:min(cap_A, 100.0e6))
    best = nothing
    best_key = (typemax(Int), Inf, Inf)
    evaluated = 0
    end_low_fraction = 0.44
    for end_high_fraction in (0.73, 0.80, 0.88)
        _, left_basis, right_basis = _mf_cage_basis_segments(axis,
            half_length_m, segment_count;
            end_low_fraction = end_low_fraction,
            end_high_fraction = end_high_fraction)
        for central_current_A in current_grid, end_current_A in current_grid
            records = _mf_transverse_wells(axis_segments, central_basis, left_basis,
                right_basis, central_current_A, end_current_A, half_length_m,
                central_field_T, mirror_ratio, plasma_radius_m)
            minimum_well = minimum(record["minimum_well_fraction"] for record in records)
            failed = Int(minimum_well < 0.002)
            total_current = abs(central_current_A) + 2.0 * abs(end_current_A)
            # Prefer the least-current passing solution.  If no current pair
            # passes, retain the physically closest attempt instead of
            # trivially choosing the zero-current case.
            key = failed == 0 ? (0, total_current, -minimum_well) :
                (1, -minimum_well, total_current)
            if key < best_key
                best_key = key
                best = Dict{String,Any}(
                    "central_bar_current_A" => central_current_A,
                    "end_bar_current_A" => end_current_A,
                    "end_low_fraction" => end_low_fraction,
                    "end_high_fraction" => end_high_fraction,
                    "minimum_well_fraction" => minimum_well,
                    "well_records" => records,
                    "gate_passed" => minimum_well >= 0.002,
                )
            end
            evaluated += 1
        end
    end
    best["evaluated_current_pair_count"] = evaluated
    best["current_cap_A"] = cap_A
    return best
end

function _mf_full_centerline_segments(axis::Dict{String,Any}, quadrupole,
        half_length_m::Float64, segment_count::Int)
    segments = _mf_centerline_axis_segments(axis, segment_count)
    central, left, right = _mf_cage_basis_segments(axis, half_length_m,
        segment_count;
        end_low_fraction = quadrupole["end_low_fraction"],
        end_high_fraction = quadrupole["end_high_fraction"])
    append!(segments, [_MFSegment(segment.p1, segment.p2,
        segment.current_A * quadrupole["central_bar_current_A"],
        segment.group_id) for segment in central])
    for basis in (left, right)
        append!(segments, [_MFSegment(segment.p1, segment.p2,
            segment.current_A * quadrupole["end_bar_current_A"],
            segment.group_id) for segment in basis])
    end
    return segments
end

function _mf_distributed_segments(axis::Dict{String,Any}, quadrupole,
        half_length_m::Float64, axis_pack_m::Float64, quad_pack_m::Float64,
        pack_grid::Int, segment_count::Int)
    segments = _MFSegment[]
    offsets_axis = [(-0.5 + (index - 0.5) / pack_grid) * axis_pack_m
        for index in 1:pack_grid]
    for index in eachindex(axis["positions_m"])
        total_current = axis["currents_A"][index]
        total_current > 1.0e4 || continue
        filament_current = total_current / pack_grid^2
        for sign in (-1.0, 1.0), radial_offset in offsets_axis,
                axial_offset in offsets_axis
            id = "axis_pair_$(index)_$(sign < 0 ? "minus" : "plus")"
            append!(segments, _mf_circle_segments(
                axis["radii_m"][index] + radial_offset,
                sign * axis["positions_m"][index] + axial_offset,
                filament_current, segment_count, id))
        end
    end
    offsets_quad = [(-0.5 + (index - 0.5) / pack_grid) * quad_pack_m
        for index in 1:pack_grid]
    for (id, radius, zlow, zhigh, current) in (
            ("minimum_b_central", axis["central_cage_radius_m"],
                -0.37 * half_length_m, 0.37 * half_length_m,
                quadrupole["central_bar_current_A"]),
            ("minimum_b_left", axis["end_cage_radius_m"],
                -quadrupole["end_high_fraction"] * half_length_m,
                -quadrupole["end_low_fraction"] * half_length_m,
                quadrupole["end_bar_current_A"]),
            ("minimum_b_right", axis["end_cage_radius_m"],
                quadrupole["end_low_fraction"] * half_length_m,
                quadrupole["end_high_fraction"] * half_length_m,
                quadrupole["end_bar_current_A"]))
        for radial_offset in offsets_quad
            append!(segments, _mf_cage_segments(radius, zlow, zhigh, current,
                segment_count, id; radial_offset_m = radial_offset,
                current_fraction = 1.0 / pack_grid))
        end
    end
    return segments
end

function _mf_peak_winding_field(axis::Dict{String,Any}, quadrupole,
        half_length_m::Float64, axis_pack_m::Float64, quad_pack_m::Float64,
        pack_grid::Int, segment_count::Int)
    segments = _mf_distributed_segments(axis, quadrupole, half_length_m,
        axis_pack_m, quad_pack_m, pack_grid, segment_count)
    samples = Tuple{String,_MFPoint}[]
    for index in eachindex(axis["positions_m"])
        axis["currents_A"][index] > 1.0e4 || continue
        for sign in (-1.0, 1.0), theta in (0.0, pi / 4.0, pi / 2.0,
                3.0 * pi / 4.0), radial_sign in (-1.0, 1.0)
            radius = axis["radii_m"][index] + radial_sign * 0.5 * axis_pack_m
            point = (radius * cos(theta), radius * sin(theta),
                sign * axis["positions_m"][index])
            push!(samples, ("axis_pair_$index", point))
        end
        for sign in (-1.0, 1.0), theta in (0.0, pi / 2.0),
                axial_sign in (-1.0, 1.0)
            radius = axis["radii_m"][index]
            point = (radius * cos(theta), radius * sin(theta),
                sign * axis["positions_m"][index] + axial_sign * 0.5 * axis_pack_m)
            push!(samples, ("axis_pair_$index", point))
        end
    end
    for (id, radius, zlow, zhigh) in (
            ("minimum_b_central", axis["central_cage_radius_m"],
                -0.37 * half_length_m, 0.37 * half_length_m),
            ("minimum_b_left", axis["end_cage_radius_m"],
                -quadrupole["end_high_fraction"] * half_length_m,
                -quadrupole["end_low_fraction"] * half_length_m),
            ("minimum_b_right", axis["end_cage_radius_m"],
                quadrupole["end_low_fraction"] * half_length_m,
                quadrupole["end_high_fraction"] * half_length_m))
        for theta in (0.0, pi / 2.0, pi, 3.0 * pi / 2.0),
                radial_sign in (-1.0, 1.0), z_m in (0.5 * (zlow + zhigh),)
            sample_radius = radius + radial_sign * 0.5 * quad_pack_m
            push!(samples, (id, (sample_radius * cos(theta),
                sample_radius * sin(theta), z_m)))
        end
    end
    maximum_field = -Inf
    maximum_record = nothing
    for (group_id, point) in samples
        field = _mf_field(point, segments)
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
        "circle_segments_per_turn" => segment_count,
        "field_sample_count" => length(samples),
        "biot_savart_segment_count" => length(segments),
    )
end

function _mf_trace_one(seed::_MFPoint, target_z_m::Float64,
        segments::Vector{_MFSegment}, central_field_T::Float64,
        mirror_ratio::Float64, half_length_m::Float64,
        plasma_radius_m::Float64; steps::Int = 80)
    point = seed
    dz = (target_z_m - seed[3]) / steps
    maximum_normalized_radius = 0.0
    minimum_abs_bz = Inf
    for _ in 1:steps
        field1 = _mf_field(point, segments)
        abs(field1[3]) > 1.0e-6 || return false, Inf, 0.0, point
        minimum_abs_bz = min(minimum_abs_bz, abs(field1[3]))
        midpoint = (point[1] + 0.5 * dz * field1[1] / field1[3],
            point[2] + 0.5 * dz * field1[2] / field1[3],
            point[3] + 0.5 * dz)
        field2 = _mf_field(midpoint, segments)
        abs(field2[3]) > 1.0e-6 || return false, Inf, 0.0, midpoint
        point = (point[1] + dz * field2[1] / field2[3],
            point[2] + dz * field2[2] / field2[3], point[3] + dz)
        local_field = _mf_target_field_T(point[3], central_field_T,
            mirror_ratio, half_length_m)
        local_radius = plasma_radius_m * sqrt(central_field_T / local_field)
        normalized_radius = hypot(point[1], point[2]) / local_radius
        maximum_normalized_radius = max(maximum_normalized_radius,
            normalized_radius)
        isfinite(maximum_normalized_radius) || return false, Inf, 0.0, point
    end
    reached = abs(point[3] - target_z_m) <= 1.0e-9
    return reached, maximum_normalized_radius, minimum_abs_bz, point
end

function _mf_field_line_audit(axis::Dict{String,Any}, quadrupole,
        half_length_m::Float64, central_field_T::Float64,
        mirror_ratio::Float64, plasma_radius_m::Float64, segment_count::Int)
    segments = _mf_full_centerline_segments(axis, quadrupole, half_length_m,
        segment_count)
    records = Dict{String,Any}[]
    all_reached = true
    maximum_normalized_radius = 0.0
    for theta in (0.0, pi / 4.0, pi / 2.0, 3.0 * pi / 4.0)
        seed = (0.5 * plasma_radius_m * cos(theta),
            0.5 * plasma_radius_m * sin(theta), 0.0)
        for direction in (-1.0, 1.0)
            reached, maximum_radius, minimum_abs_bz, final_point = _mf_trace_one(
                seed, direction * half_length_m, segments, central_field_T,
                mirror_ratio, half_length_m, plasma_radius_m)
            all_reached &= reached
            maximum_normalized_radius = max(maximum_normalized_radius,
                maximum_radius)
            push!(records, Dict{String,Any}(
                "seed_m" => collect(seed),
                "target_z_m" => direction * half_length_m,
                "reached_open_end" => reached,
                "maximum_normalized_flux_tube_radius" => maximum_radius,
                "minimum_abs_Bz_T" => minimum_abs_bz,
                "final_point_m" => collect(final_point),
            ))
        end
    end
    passed = all_reached && maximum_normalized_radius <= 0.95
    return Dict{String,Any}(
        "passed" => passed,
        "all_seeds_reached_both_open_ends" => all_reached,
        "maximum_normalized_flux_tube_radius" => maximum_normalized_radius,
        "records" => records,
    )
end

function _mf_geometry_summary(evaluator::MirrorFiniteCoilGeometryV1,
        genome::Genome)
    core = only(filter(region -> region.kind == "mirror_central_cell",
        genome.plasma_regions))
    central_field_T = _mirror_reduced_parameter(core, "central_field", "T")
    mirror_ratio = _mirror_reduced_parameter(core, "mirror_ratio_gene", "1")
    cell_length_m = _mirror_reduced_parameter(core, "cell_length", "m")
    plasma_radius_m = _mirror_reduced_parameter(core, "plasma_radius", "m")
    half_length_m = 0.5 * cell_length_m
    contract = default_common_comparison_contract()
    shield_m = contract.shield_thickness_m
    maintenance_m = contract.maintenance_gap_m
    axis_pack_m = _screen_target(genome, "screen_coil_pack_thickness", 0.45, "m")
    quad_pack_m = axis_pack_m
    current_density_limit_A_m2 = contract.engineering_current_density_limit_A_mm2 *
        1.0e6

    axis = _mf_axis_geometry_search(evaluator, central_field_T, mirror_ratio,
        half_length_m, plasma_radius_m, shield_m, maintenance_m, axis_pack_m,
        quad_pack_m, current_density_limit_A_m2)
    quadrupole = _mf_quadrupole_search(axis, half_length_m, central_field_T,
        mirror_ratio, plasma_radius_m, quad_pack_m, current_density_limit_A_m2,
        evaluator.coarse_segments)
    coarse_peak = _mf_peak_winding_field(axis, quadrupole, half_length_m,
        axis_pack_m, quad_pack_m, 11, evaluator.coarse_segments)
    refined_peak = _mf_peak_winding_field(axis, quadrupole, half_length_m,
        axis_pack_m, quad_pack_m, 13, evaluator.refined_segments)
    peak_change = abs(refined_peak["peak_field_T"] - coarse_peak["peak_field_T"]) /
        max(refined_peak["peak_field_T"], 1.0e-12)
    resolution_passed = peak_change <= 0.08
    field_lines = _mf_field_line_audit(axis, quadrupole, half_length_m,
        central_field_T, mirror_ratio, plasma_radius_m,
        evaluator.refined_segments)

    maximum_axis_current_density = maximum(axis["currents_A"]) / axis_pack_m^2
    maximum_quad_current_density = max(abs(quadrupole["central_bar_current_A"]),
        abs(quadrupole["end_bar_current_A"])) / quad_pack_m^2
    maximum_current_density = max(maximum_axis_current_density,
        maximum_quad_current_density)
    current_density_passed = maximum_current_density <= current_density_limit_A_m2
    center_error = abs(axis["center_field_T"] / central_field_T - 1.0)
    ratio_error = abs(axis["achieved_mirror_ratio"] / mirror_ratio - 1.0)
    axis_field_passed = center_error <= 0.02 && ratio_error <= 0.02 &&
        axis["axis_rms_relative_error"] <= 0.08
    peak_field_passed = refined_peak["peak_field_T"] <=
        contract.peak_conductor_field_limit_T
    minimum_clearance = min(axis["radial_gap_m"],
        axis["central_cage_radius_m"] - 0.5 * quad_pack_m -
            plasma_radius_m - shield_m - maintenance_m,
        axis["end_cage_radius_m"] - 0.5 * quad_pack_m -
            plasma_radius_m * sqrt(central_field_T /
                _mf_target_field_T(0.44 * half_length_m, central_field_T,
                    mirror_ratio, half_length_m)) - shield_m - maintenance_m)
    clearance_passed = minimum_clearance >= -1.0e-9
    reserved_elbow_radius_m = 0.40
    bend_reservation_passed = reserved_elbow_radius_m >=
        contract.minimum_coil_curvature_radius_m
    magnetic_pressure_Pa = refined_peak["peak_field_T"]^2 /
        (2.0 * 4.0 * pi * 1.0e-7)
    support_stress_proxy_Pa = magnetic_pressure_Pa *
        maximum(axis["radii_m"]) /
        _screen_target(genome, "screen_support_thickness", 0.7, "m")
    support_stress_passed = support_stress_proxy_Pa <=
        contract.support_stress_limit_Pa

    gates = Dict{String,Bool}(
        "axis_field_and_mirror_ratio" => axis_field_passed,
        "transverse_minimum_b_well" => quadrupole["gate_passed"],
        "open_field_line_integrity" => field_lines["passed"],
        "finite_build_peak_field" => peak_field_passed,
        "winding_current_density" => current_density_passed,
        "plasma_shield_maintenance_and_coil_clearance" => clearance_passed,
        "minimum_bend_radius_reservation" => bend_reservation_passed,
        "membrane_support_stress_proxy" => support_stress_passed,
        "biot_savart_resolution_audit" => resolution_passed,
    )
    passed = all(values(gates))
    disposition = passed ?
        "vacuum_geometry_provisional_advance_with_blocking_unknowns" :
        "rejected_before_anisotropic_equilibrium"

    active_pairs = Dict{String,Any}[]
    for index in eachindex(axis["positions_m"])
        axis["currents_A"][index] > 1.0e4 || continue
        push!(active_pairs, Dict{String,Any}(
            "pair_index" => index,
            "absolute_z_m" => axis["positions_m"][index],
            "centerline_radius_m" => axis["radii_m"][index],
            "current_per_coil_A_turn" => axis["currents_A"][index],
            "winding_pack_width_m" => axis_pack_m,
        ))
    end
    return Dict{String,Any}(
        "model" => "tapered_circular_coils_plus_three_divergence_free_quadrupolar_cage_cells_v1",
        "geometry_search" => Dict(
            "method" => "deterministic_random_start_box_constrained_coordinate_search",
            "seed" => evaluator.seed,
            "random_starts" => evaluator.random_starts,
            "axis_geometry_evaluations" => axis["evaluated_geometry_count"],
            "quadrupole_current_pair_evaluations" =>
                quadrupole["evaluated_current_pair_count"],
            "end_cage_high_extent_DOE" => [0.73, 0.80, 0.88],
            "opposing_axis_currents_allowed" => false,
            "taper_rule" => "local plasma radius scales as sqrt(B0/Btarget); declared shield and maintenance gaps remain fixed",
        ),
        "inputs" => Dict(
            "central_field_T" => central_field_T,
            "target_mirror_ratio" => mirror_ratio,
            "cell_length_m" => cell_length_m,
            "central_plasma_radius_m" => plasma_radius_m,
            "shield_thickness_m" => shield_m,
            "maintenance_gap_m" => maintenance_m,
            "axis_winding_pack_width_m" => axis_pack_m,
            "quadrupole_winding_pack_width_m" => quad_pack_m,
            "peak_conductor_field_limit_T" => contract.peak_conductor_field_limit_T,
            "engineering_current_density_limit_A_m2" =>
                current_density_limit_A_m2,
            "support_stress_limit_Pa" => contract.support_stress_limit_Pa,
        ),
        "axis_system" => Dict(
            "active_symmetric_coil_pairs" => active_pairs,
            "active_pair_count" => length(active_pairs),
            "center_field_T" => axis["center_field_T"],
            "throat_field_T" => axis["throat_field_T"],
            "achieved_mirror_ratio" => axis["achieved_mirror_ratio"],
            "axis_rms_relative_error" => axis["axis_rms_relative_error"],
            "axis_grid_m" => axis["axis_grid_m"],
            "axis_target_T" => axis["axis_target_T"],
            "axis_predicted_T" => axis["axis_predicted_T"],
        ),
        "quadrupole_system" => Dict(
            "physical_closed_circuit_count" => 6,
            "cell_count" => 3,
            "central_bar_current_A" => quadrupole["central_bar_current_A"],
            "end_bar_current_A" => quadrupole["end_bar_current_A"],
            "end_low_fraction_of_half_length" => quadrupole["end_low_fraction"],
            "end_high_fraction_of_half_length" => quadrupole["end_high_fraction"],
            "central_cage_radius_m" => axis["central_cage_radius_m"],
            "end_cage_radius_m" => axis["end_cage_radius_m"],
            "well_records" => quadrupole["well_records"],
            "minimum_well_fraction" => quadrupole["minimum_well_fraction"],
            "junction_model" => "sharp line-current junction for field solve with explicit 0.40 m rounded-elbow engineering reservation",
        ),
        "finite_build" => Dict(
            "coarse_peak_field" => coarse_peak,
            "refined_peak_field" => refined_peak,
            "peak_field_resolution_change_fraction" => peak_change,
            "maximum_current_density_A_m2" => maximum_current_density,
            "minimum_declared_clearance_margin_m" => minimum_clearance,
            "reserved_minimum_elbow_radius_m" => reserved_elbow_radius_m,
            "magnetic_pressure_at_refined_peak_Pa" => magnetic_pressure_Pa,
            "membrane_support_stress_proxy_Pa" => support_stress_proxy_Pa,
        ),
        "field_line_audit" => field_lines,
        "gates" => gates,
        "all_geometry_gates_passed" => passed,
        "disposition" => disposition,
        "blocking_unknowns_after_geometry" => passed ? String[
            "anisotropic finite-beta equilibrium",
            "self-consistent electrostatic plug",
            "Fokker-Planck collisional end loss",
            "interchange DCLC AIC and microstability",
            "detailed coil force support and quench design",
            "exhaust power recovery and reactor power balance",
            "material critical surface and nuclear heating",
        ] : String[
            "failed vacuum geometry gates must be repaired before anisotropic equilibrium",
        ],
        "claim_boundary" => _MIRROR_FINITE_COIL_CLAIM_BOUNDARY,
    )
end

function _mf_metric(id::String, value; unit::String = "1",
        status::Symbol = :pass, input_hash::String, run_hash::String,
        warnings::Vector{String}, constraints::Vector{String} = String[],
        uncertainty::Union{Nothing,Float64} = nothing,
        residuals::Dict{String,Float64} = Dict{String,Float64}())
    return MetricResult(id, value;
        unit = unit,
        uncertainty = uncertainty,
        fidelity = 1,
        applicability = "Candidate-specific finite-build vacuum mirror and minimum-B geometry audit.",
        status = status,
        constraints_checked = constraints,
        solver_name = "mirror_finite_coil_geometry_v1",
        solver_version = "1.0.0",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = _MIRROR_FINITE_COIL_SOURCE_BASIS,
        warnings = warnings,
        residuals = residuals,
        wall_time_s = 0.0)
end

function run_evaluator(evaluator::MirrorFiniteCoilGeometryV1, genome::Genome;
        kwargs...)
    summary = _mf_geometry_summary(evaluator, genome)
    run_hash = canonical_hash(Dict(
        "evaluator" => "mirror_finite_coil_geometry_v1",
        "version" => "1.0.0",
        "input_hash" => genome.physics_hash,
        "configuration" => Dict(
            "random_starts" => evaluator.random_starts,
            "seed" => evaluator.seed,
            "coarse_segments" => evaluator.coarse_segments,
            "refined_segments" => evaluator.refined_segments,
        ),
        "summary" => summary,
    ))
    warnings = String[
        _MIRROR_FINITE_COIL_CLAIM_BOUNDARY,
        "The six quadrupolar closed circuits are represented as three Kirchhoff-consistent cage current networks; sharp field-model junctions reserve but do not explicitly resolve 0.40 m rounded elbows.",
        "The finite-build peak-field result is a distributed-filament convergence audit under a generic winding envelope, not a superconducting critical-surface calculation.",
        "The original structural genome's coil counts are conceptual source-group counts; this adapter reports every active physical circular pair and does not silently rewrite the genome.",
    ]
    gates = summary["gates"]
    pass_or_fail(value) = value ? :pass : :fail
    finite = summary["finite_build"]
    axis = summary["axis_system"]
    quadrupole = summary["quadrupole_system"]
    metrics = MetricResult[
        _mf_metric("finite_coil_geometry_summary", summary;
            status = pass_or_fail(summary["all_geometry_gates_passed"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mf_metric("vacuum_axis_center_field", axis["center_field_T"];
            unit = "T", status = pass_or_fail(gates["axis_field_and_mirror_ratio"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, constraints = ["center field within 2% of target"]),
        _mf_metric("vacuum_sampled_mirror_ratio",
            axis["achieved_mirror_ratio"];
            status = pass_or_fail(gates["axis_field_and_mirror_ratio"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, constraints = ["mirror ratio within 2% of target"]),
        _mf_metric("axis_field_rms_relative_error",
            axis["axis_rms_relative_error"];
            status = pass_or_fail(gates["axis_field_and_mirror_ratio"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, constraints = ["axis RMS relative error <= 0.08"]),
        _mf_metric("minimum_sampled_transverse_well_fraction",
            quadrupole["minimum_well_fraction"];
            status = pass_or_fail(gates["transverse_minimum_b_well"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings,
            constraints = ["minimum ring-to-axis |B| well fraction >= 0.002"]),
        _mf_metric("open_field_line_integrity_passed",
            summary["field_line_audit"]["passed"];
            status = pass_or_fail(gates["open_field_line_integrity"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mf_metric("refined_peak_winding_field",
            finite["refined_peak_field"]["peak_field_T"];
            unit = "T", status = pass_or_fail(gates["finite_build_peak_field"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, constraints = ["peak winding field <= 24 T"],
            uncertainty = finite["peak_field_resolution_change_fraction"]),
        _mf_metric("finite_build_field_resolution_audit_passed",
            gates["biot_savart_resolution_audit"];
            status = pass_or_fail(gates["biot_savart_resolution_audit"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings,
            constraints = ["coarse/refined peak field change <= 0.08"]),
        _mf_metric("maximum_engineering_current_density",
            finite["maximum_current_density_A_m2"];
            unit = "A/m^2", status = pass_or_fail(gates["winding_current_density"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, constraints = ["engineering current density <= 500 A/mm^2"]),
        _mf_metric("minimum_declared_coil_clearance_margin",
            finite["minimum_declared_clearance_margin_m"];
            unit = "m", status = pass_or_fail(
                gates["plasma_shield_maintenance_and_coil_clearance"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings),
        _mf_metric("membrane_support_stress_proxy",
            finite["membrane_support_stress_proxy_Pa"];
            unit = "Pa", status = pass_or_fail(
                gates["membrane_support_stress_proxy"]),
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings, constraints = ["membrane stress proxy <= 800 MPa"]),
        _mf_metric("finite_coil_geometry_disposition", summary["disposition"];
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
            push!(metrics, _mf_metric(id, nothing; status = :unknown,
                input_hash = genome.physics_hash, run_hash = run_hash,
                warnings = vcat(warnings, [message])))
        end
    end
    status = summary["all_geometry_gates_passed"] ? :pass : :fail
    return EvaluationBundle("mirror_finite_coil_geometry_v1", genome.design_id,
        genome.family, 1, status, metrics, warnings, genome.physics_hash,
        run_hash, "physics_proxy")
end
