function _dipole_ring_segments_v1(radius::Float64, center_z::Float64,
        segment_count::Int)
    midpoints = NTuple{3,Float64}[]
    directions = NTuple{3,Float64}[]
    for index in 0:(segment_count - 1)
        first_angle = 2.0 * pi * index / segment_count
        second_angle = 2.0 * pi * (index + 1) / segment_count
        first_point = (radius * cos(first_angle), radius * sin(first_angle),
            center_z)
        second_point = (radius * cos(second_angle), radius * sin(second_angle),
            center_z)
        push!(midpoints, ntuple(axis ->
            0.5 * (first_point[axis] + second_point[axis]), 3))
        push!(directions, ntuple(axis ->
            second_point[axis] - first_point[axis], 3))
    end
    return midpoints, directions
end

function _dipole_ring_field_v1(radius::Float64, center_z::Float64,
        current::Float64, segment_count::Int)
    midpoints, directions = _dipole_ring_segments_v1(radius, center_z,
        segment_count)
    coefficient = _MIRROR_FILAMENT_MU0_V1 * current / (4.0 * pi)
    return function(point)
        px, py, pz = Float64.(collect(point))
        bx = by = bz = 0.0
        for index in eachindex(midpoints)
            mx, my, mz = midpoints[index]
            dx, dy, dz = directions[index]
            rx, ry, rz = px - mx, py - my, pz - mz
            r2 = rx^2 + ry^2 + rz^2
            r2 > 1.0e-18 || continue
            scale = coefficient / (r2 * sqrt(r2))
            bx += (dy * rz - dz * ry) * scale
            by += (dz * rx - dx * rz) * scale
            bz += (dx * ry - dy * rx) * scale
        end
        return (bx, by, bz)
    end
end

function _dipole_ring_magnitude_v1(field, point)
    value = field(point)
    return sqrt(sum(component^2 for component in value))
end

function _dipole_ring_envelope_repair_search_v1(plasma_major::Float64,
        plasma_minor::Float64, plasma_z::Float64, loop_z::Float64,
        target_field::Float64, peak_screen::Float64,
        fixed_radial_build::Float64; sample_count::Int = 1025)
    maximum_radius = plasma_major - plasma_minor - fixed_radial_build
    minimum_radius = max(0.02 * plasma_minor, 1.0e-4)
    if maximum_radius <= minimum_radius
        return Dict{String,Any}(
            "executed" => false, "sample_count" => 0,
            "minimum_radius_m" => minimum_radius,
            "maximum_radius_m" => maximum_radius,
            "feasible" => false,
            "reason" => "No positive loop-radius interval remains inside the plasma inner radius after fixed radial build.")
    end
    best = nothing
    best_margin = -Inf
    target_point = (plasma_major, 0.0, plasma_z)
    for radius in range(minimum_radius, maximum_radius; length = sample_count)
        unit_field = _dipole_ring_field_v1(radius, loop_z, 1.0, 256)
        per_amp = _dipole_ring_magnitude_v1(unit_field, target_point)
        per_amp > 0.0 || continue
        current = target_field / per_amp
        axis_field = abs(_MIRROR_FILAMENT_MU0_V1 * current /
            (2.0 * radius))
        margin = peak_screen - axis_field
        if margin > best_margin
            best_margin = margin
            best = (radius, current, axis_field)
        end
    end
    best === nothing && return Dict{String,Any}(
        "executed" => true, "sample_count" => sample_count,
        "minimum_radius_m" => minimum_radius,
        "maximum_radius_m" => maximum_radius,
        "feasible" => false, "reason" => "No finite field coefficient was found.")
    best_radius = best[1]
    fine_unit = _dipole_ring_field_v1(best_radius, loop_z, 1.0, 1024)
    fine_per_amp = _dipole_ring_magnitude_v1(fine_unit, target_point)
    best_current = target_field / fine_per_amp
    best_axis_field = abs(_MIRROR_FILAMENT_MU0_V1 * best_current /
        (2.0 * best_radius))
    best_margin = peak_screen - best_axis_field
    return Dict{String,Any}(
        "executed" => true, "sample_count" => sample_count,
        "minimum_radius_m" => minimum_radius,
        "maximum_radius_m" => maximum_radius,
        "best_loop_radius_m" => best_radius,
        "best_required_equivalent_ampere_turns" => best_current,
        "best_ring_axis_center_field_t" => best_axis_field,
        "best_peak_field_margin_t" => best_margin,
        "feasible" => best_margin >= 0.0,
        "reason" => best_margin >= 0.0 ?
            "At least one radius satisfies the axis-center peak-field necessary condition." :
            "No searched radius inside the declared radial envelope satisfies the axis-center peak-field necessary condition.")
end

"""
Compile the internal levitated-dipole ring into a circular filament and test
two necessary conditions before field-line tracing: the declared plasma field
must be reachable without exceeding the internally linked peak-field screen,
and the declared winding/shield/maintenance stack must fit inside the plasma
inner radius. Failure is candidate-specific and independent of the family tag.
"""
function evaluate_levitated_dipole_ring_screen_v1(genome::Genome)
    sources = filter(item -> item.geometry_model ==
        "finite_build_floating_superconducting_ring", genome.field_sources)
    cores = filter(item -> item.kind == "closed_toroidal_core",
        genome.plasma_regions)
    length(sources) == 1 && length(cores) == 1 ||
        return Dict{String,Any}("status" => "unknown",
            "backend_executed" => false, "hard_falsified" => false,
            "candidate_c1_evidence_authorized" => false,
            "c2_evidence_authorized" => false,
            "reason" => "One floating ring and one closed toroidal core are required.")
    source, core = only(sources), only(cores)
    raw_targets = genome.normalized["mission"]["targets"]
    required_source = ("coil_radius", "generated_vertical_position",
        "peak_field")
    required_core = ("major_radius", "minor_radius",
        "generated_vertical_position")
    required_targets = ("on_axis_field", "screen_internal_coil_radius_fraction",
        "screen_internal_coil_field_ratio", "screen_coil_pack_thickness",
        "screen_internal_shield_thickness",
        "screen_internal_maintenance_gap")
    all(id -> haskey(source.parameters, id), required_source) &&
        all(id -> haskey(core.parameters, id), required_core) &&
        all(id -> haskey(raw_targets, id), required_targets) ||
        return Dict{String,Any}("status" => "unknown",
            "backend_executed" => false, "hard_falsified" => false,
            "candidate_c1_evidence_authorized" => false,
            "c2_evidence_authorized" => false,
            "reason" => "Dipole ring, plasma center and mission-linked engineering inputs are incomplete.")

    loop_radius = source.parameters["coil_radius"].value
    loop_z = source.parameters["generated_vertical_position"].value
    plasma_major = core.parameters["major_radius"].value
    plasma_minor = core.parameters["minor_radius"].value
    plasma_z = core.parameters["generated_vertical_position"].value
    peak_screen = source.parameters["peak_field"].value
    target_field = Float64(raw_targets["on_axis_field"]["value"])
    radius_fraction = Float64(raw_targets[
        "screen_internal_coil_radius_fraction"]["value"])
    internal_field_ratio = Float64(raw_targets[
        "screen_internal_coil_field_ratio"]["value"])
    coil_pack = Float64(raw_targets["screen_coil_pack_thickness"]["value"])
    shield = Float64(raw_targets[
        "screen_internal_shield_thickness"]["value"])
    maintenance_gap = Float64(raw_targets[
        "screen_internal_maintenance_gap"]["value"])

    radius_link_error = abs(loop_radius - radius_fraction * plasma_minor) /
        max(loop_radius, 1.0e-30)
    peak_link_error = abs(peak_screen - internal_field_ratio * target_field) /
        max(peak_screen, 1.0e-30)
    source_semantics_verified = radius_link_error <= 1.0e-12 &&
        peak_link_error <= 1.0e-12
    target_point = (plasma_major, 0.0, plasma_z)
    coarse_unit = _dipole_ring_field_v1(loop_radius, loop_z, 1.0, 256)
    fine_unit = _dipole_ring_field_v1(loop_radius, loop_z, 1.0, 1024)
    coarse_per_amp = _dipole_ring_magnitude_v1(coarse_unit, target_point)
    fine_per_amp = _dipole_ring_magnitude_v1(fine_unit, target_point)
    required_current = target_field / fine_per_amp
    coefficient_change = abs(coarse_per_amp - fine_per_amp) /
        max(fine_per_amp, 1.0e-30)
    solved_field = _dipole_ring_magnitude_v1(
        _dipole_ring_field_v1(loop_radius, loop_z, required_current, 1024),
        target_point)
    target_error = abs(solved_field - target_field) / target_field
    ring_axis_center_field = abs(_MIRROR_FILAMENT_MU0_V1 *
        required_current / (2.0 * loop_radius))
    peak_margin = peak_screen - ring_axis_center_field
    peak_screen_pass = peak_margin >= 0.0
    plasma_inner_radius = plasma_major - plasma_minor
    required_assembly_outer_radius = loop_radius + coil_pack + shield +
        maintenance_gap
    assembly_margin = plasma_inner_radius - required_assembly_outer_radius
    assembly_fits = assembly_margin >= 0.0
    repair = _dipole_ring_envelope_repair_search_v1(plasma_major,
        plasma_minor, plasma_z, loop_z, target_field, peak_screen,
        coil_pack + shield + maintenance_gap)
    envelope_repair_feasible = repair["feasible"] === true
    maxwell_coefficient_authorized = coefficient_change <= 1.0e-4 &&
        target_error <= 1.0e-12
    hard_falsified = source_semantics_verified &&
        maxwell_coefficient_authorized && !envelope_repair_feasible
    status = hard_falsified ? "fail" : "unknown"
    physical = Dict{String,Any}(
        "loop_radius_m" => loop_radius,
        "loop_center_z_m" => loop_z,
        "plasma_target_point_m" => collect(target_point),
        "target_field_t" => target_field,
        "solved_target_field_t" => solved_field,
        "target_field_relative_error" => target_error,
        "required_equivalent_ampere_turns" => required_current,
        "ring_axis_center_field_t" => ring_axis_center_field,
        "declared_peak_field_screen_t" => peak_screen,
        "peak_field_margin_t" => peak_margin,
        "peak_screen_pass" => peak_screen_pass,
        "plasma_inner_radius_m" => plasma_inner_radius,
        "required_assembly_outer_radius_m" =>
            required_assembly_outer_radius,
        "assembly_radial_margin_m" => assembly_margin,
        "assembly_fits_inside_plasma_inner_radius" => assembly_fits,
        "envelope_repair_search" => repair,
        "envelope_repair_feasible" => envelope_repair_feasible,
        "coil_radius_gene_link_relative_error" => radius_link_error,
        "peak_field_gene_link_relative_error" => peak_link_error,
        "source_semantics_verified" => source_semantics_verified,
        "biot_savart_coarse_fine_relative_change" => coefficient_change,
        "maxwell_coefficient_evidence_authorized" =>
            maxwell_coefficient_authorized,
        "hard_falsified" => hard_falsified,
        "status" => status)
    return merge(physical, Dict{String,Any}(
        "schema_version" => "1.0.0",
        "evaluator_version" => "levitated_dipole_ring_screen_v1",
        "design_id" => genome.design_id,
        "physics_hash" => genome.physics_hash,
        "backend_executed" => true,
        "field_topology_evidence_authorized" => false,
        "candidate_c1_evidence_authorized" => false,
        "c2_evidence_authorized" => false,
        "promotion_authorized" => false,
        "physical_result_hash" => canonical_hash(physical),
        "claim_ceiling" => hard_falsified ?
            "C1_candidate_bound_dipole_field_and_geometry_hard_falsification" :
            "C0_C1_dipole_field_necessary_condition_unknown",
        "claim_boundary" => "The circular internal-coil path, mission-linked radius/peak semantics and Biot-Savart field requirement are candidate bound. A hard failure stops before field-line topology. No levitation force, support, shielding, closed-surface topology, equilibrium, stability, transport, power, C2 or feasibility credit is granted."))
end
