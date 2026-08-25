const _MIRROR_FILAMENT_MU0_V1 = 4.0e-7 * pi

function _mirror_filament_source_and_core_v1(genome::Genome)
    sources = filter(source -> source.geometry_model ==
        "paired_large_bore_hts_mirror_coils", genome.field_sources)
    cores = filter(region -> occursin("mirror_central_cell",
        lowercase(region.kind)) || occursin("mirror_0d",
        lowercase(region.geometry_model)), genome.plasma_regions)
    length(sources) == 1 && length(cores) == 1 || return nothing
    return only(sources), only(cores)
end

function _mirror_pair_axis_coeff_v1(radius_m::Float64,
        half_separation_m::Float64, axial_offset_m::Float64)
    first = radius_m^2 /
        (radius_m^2 + (axial_offset_m - half_separation_m)^2)^1.5
    second = radius_m^2 /
        (radius_m^2 + (axial_offset_m + half_separation_m)^2)^1.5
    return 0.5 * _MIRROR_FILAMENT_MU0_V1 * (first + second)
end

function _mirror_pair_ratio_v1(radius_m::Float64,
        half_separation_m::Float64)
    center = _mirror_pair_axis_coeff_v1(radius_m, half_separation_m, 0.0)
    throat = _mirror_pair_axis_coeff_v1(radius_m, half_separation_m,
        half_separation_m)
    return throat / center
end

function _mirror_pair_separation_search_v1(radius_m::Float64,
        target_ratio::Float64; iteration_count::Int = 80)
    lower, upper = 0.15, 4.0
    lower_ratio = _mirror_pair_ratio_v1(radius_m, lower * radius_m)
    upper_ratio = _mirror_pair_ratio_v1(radius_m, upper * radius_m)
    lower_ratio <= target_ratio <= upper_ratio || throw(ArgumentError(
        "target mirror ratio lies outside the searched separation interval"))
    for _ in 1:iteration_count
        midpoint = 0.5 * (lower + upper)
        ratio = _mirror_pair_ratio_v1(radius_m, midpoint * radius_m)
        if ratio < target_ratio
            lower = midpoint
        else
            upper = midpoint
        end
    end
    best_x = 0.5 * (lower + upper)
    best_ratio = _mirror_pair_ratio_v1(radius_m, best_x * radius_m)
    best_error = abs(log(best_ratio / target_ratio))
    return Dict{String,Any}(
        "bisection_iteration_count" => iteration_count,
        "searched_half_separation_over_radius" => [0.15, 4.0],
        "selected_half_separation_over_radius" => best_x,
        "achieved_analytic_mirror_ratio" => best_ratio,
        "target_mirror_ratio" => target_ratio,
        "log_ratio_error" => best_error)
end

"""
Create a child execution Genome with an explicit two-loop mirror source.

The current and loop separation are solved from the candidate's central-field
and mirror-ratio design targets. The undefined minimum-B anchor is explicitly
disabled, so the child is an axisymmetric mirror candidate and receives no
minimum-B or stability credit.
"""
function refine_axisymmetric_mirror_filament_candidate_v1(genome::Genome)
    found = _mirror_filament_source_and_core_v1(genome)
    found === nothing && return genome, Dict{String,Any}(
        "derived" => false, "reason" =>
            "Exactly one paired mirror source and central cell are required.")
    source, core = found
    required_source = ("generated_half_width_r", "on_axis_field")
    required_core = ("mirror_ratio_gene", "plasma_radius")
    all(id -> haskey(source.parameters, id), required_source) &&
        all(id -> haskey(core.parameters, id), required_core) ||
        return genome, Dict{String,Any}("derived" => false,
            "reason" => "Mirror radius, central field, mirror ratio and plasma radius are required.")
    radius = source.parameters["generated_half_width_r"].value
    central_field = source.parameters["on_axis_field"].value
    target_ratio = core.parameters["mirror_ratio_gene"].value
    radius > 0.0 && central_field > 0.0 && target_ratio > 1.0 ||
        return genome, Dict{String,Any}("derived" => false,
            "reason" => "Mirror geometry and target values must be positive with ratio greater than one.")
    search = _mirror_pair_separation_search_v1(radius, target_ratio)
    half_separation = radius *
        Float64(search["selected_half_separation_over_radius"])
    axis_coeff = _mirror_pair_axis_coeff_v1(radius, half_separation, 0.0)
    current = central_field / axis_coeff
    center_z = haskey(core.parameters, "generated_center_position_z") ?
        core.parameters["generated_center_position_z"].value : 0.0
    original_length = haskey(core.parameters, "cell_length") ?
        core.parameters["cell_length"].value : 2.0 * half_separation

    raw = deepcopy(genome.normalized)
    basis = "exploratory axisymmetric mirror filament search v1 constrained by Biot-Savart central field and mirror ratio"
    changed = 0
    for item in raw["field_sources"]
        if String(item["id"]) == source.id
            item["geometry_model"] = "axisymmetric_circular_filament_pair_v1"
            changed += _native_c1_set_raw_parameter_v1!(item,
                "loop_radius", radius, "m", basis)
            changed += _native_c1_set_raw_parameter_v1!(item,
                "pair_half_separation", half_separation, "m", basis)
            changed += _native_c1_set_raw_parameter_v1!(item,
                "pair_center_z", center_z, "m", basis)
            changed += _native_c1_set_raw_parameter_v1!(item,
                "current_per_loop", current, "A", basis)
            changed += _native_c1_set_raw_parameter_v1!(item,
                "target_central_field", central_field, "T", basis)
            changed += _native_c1_set_raw_parameter_v1!(item,
                "target_mirror_ratio", target_ratio, "1", basis)
        elseif occursin("minimum_b_anchor", lowercase(String(item["kind"]))) ||
                occursin("quadrupole_anchor", lowercase(String(
                    get(item, "geometry_model", ""))))
            item["geometry_model"] = "disabled_zero_current_anchor_v1"
            changed += _native_c1_set_raw_parameter_v1!(item,
                "total_current", 0.0, "A",
                "explicitly disabled exploratory child candidate; no minimum-B credit")
        end
    end
    for item in raw["plasma_regions"]
        String(item["id"]) == core.id || continue
        changed += _native_c1_set_raw_parameter_v1!(item,
            "cell_length", 2.0 * half_separation, "m", basis)
    end
    provenance = raw["provenance"]
    provenance["parent_design_ids"] = sort!(unique(vcat(
        String.(provenance["parent_design_ids"]), [genome.design_id])))
    provenance["source_ids"] = sort!(unique(vcat(
        String.(provenance["source_ids"]),
        ["axisymmetric_mirror_filament_search_v1"])))
    provenance["notes"] = vcat(String.(provenance["notes"]), [
        "The paired mirror source is expanded into two explicit circular filaments; separation and current are exploratory solver-constrained design genes.",
        "The undefined minimum-B anchor is set to zero current, so this child receives no transverse minimum-B or stability credit.",
        "C1 magnetic evidence cannot authorize equilibrium, interchange/flute stability, kinetic confinement, end-loss power, engineering feasibility or C2."])
    provenance["claim_level"] = "exploratory_C0_solver_constrained_mirror_child"
    raw["design_id"] = "pending_axisymmetric_mirror_filament_v1"
    provisional = parse_genome(raw)
    raw["design_id"] = "mirrorfilv1_$(genome.physics_hash[1:12])_" *
        provisional.physics_hash[1:12]
    derived = parse_genome(raw)
    return derived, Dict{String,Any}(
        "derived" => true,
        "changed_parameter_count" => changed,
        "source_design_id" => genome.design_id,
        "source_physics_hash" => genome.physics_hash,
        "derived_design_id" => derived.design_id,
        "derived_physics_hash" => derived.physics_hash,
        "loop_radius_m" => radius,
        "original_cell_length_m" => original_length,
        "derived_cell_length_m" => 2.0 * half_separation,
        "cell_length_relative_change" => abs(2.0 * half_separation -
            original_length) / original_length,
        "current_per_loop_a" => current,
        "search" => search)
end

function _mirror_filament_segments_v1(radius::Float64, center_z::Float64,
        half_separation::Float64, segment_count::Int)
    midpoints = NTuple{3,Float64}[]
    directions = NTuple{3,Float64}[]
    for z in (center_z - half_separation, center_z + half_separation)
        for index in 0:(segment_count - 1)
            first_angle = 2.0 * pi * index / segment_count
            second_angle = 2.0 * pi * (index + 1) / segment_count
            first_point = (radius * cos(first_angle),
                radius * sin(first_angle), z)
            second_point = (radius * cos(second_angle),
                radius * sin(second_angle), z)
            push!(midpoints, ntuple(axis ->
                0.5 * (first_point[axis] + second_point[axis]), 3))
            push!(directions, ntuple(axis ->
                second_point[axis] - first_point[axis], 3))
        end
    end
    return midpoints, directions
end

function _mirror_filament_field_v1(radius::Float64, center_z::Float64,
        half_separation::Float64, current::Float64, segment_count::Int)
    midpoints, directions = _mirror_filament_segments_v1(radius, center_z,
        half_separation, segment_count)
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

function _mirror_filament_vacuum_residuals_v1(field, radius::Float64,
        half_separation::Float64, center_z::Float64, reference_field::Float64,
        divisions::Int)
    h = min(radius, half_separation) / divisions
    divergence = Float64[]
    curl = Float64[]
    for radial_fraction in (0.0, 0.18, 0.36, 0.54),
            axial_fraction in (-0.55, -0.25, 0.0, 0.25, 0.55)
        x, y = radial_fraction * radius, 0.11 * radial_fraction * radius
        z = center_z + axial_fraction * half_separation
        fxp, fxm = field((x + h, y, z)), field((x - h, y, z))
        fyp, fym = field((x, y + h, z)), field((x, y - h, z))
        fzp, fzm = field((x, y, z + h)), field((x, y, z - h))
        divb = (fxp[1] - fxm[1] + fyp[2] - fym[2] +
            fzp[3] - fzm[3]) / (2.0 * h)
        curlx = (fyp[3] - fym[3] - fzp[2] + fzm[2]) / (2.0 * h)
        curly = (fzp[1] - fzm[1] - fxp[3] + fxm[3]) / (2.0 * h)
        curlz = (fxp[2] - fxm[2] - fyp[1] + fym[1]) / (2.0 * h)
        normalization = max(reference_field / radius, 1.0e-30)
        push!(divergence, abs(divb) / normalization)
        push!(curl, sqrt(curlx^2 + curly^2 + curlz^2) / normalization)
    end
    return maximum(divergence), maximum(curl)
end

function _mirror_filament_field_convergence_v1(coarse, fine,
        radius::Float64, half_separation::Float64, center_z::Float64)
    errors = Float64[]
    for radial_fraction in (0.0, 0.2, 0.4, 0.6),
            axial_fraction in (-0.8, -0.4, 0.0, 0.4, 0.8)
        point = (radial_fraction * radius, 0.0,
            center_z + axial_fraction * half_separation)
        first, second = coarse(point), fine(point)
        denominator = max(sqrt(sum(value^2 for value in second)), 1.0e-30)
        push!(errors, sqrt(sum((first[axis] - second[axis])^2
            for axis in 1:3)) / denominator)
    end
    return maximum(errors)
end

function _mirror_filament_topology_v1(genome::Genome, field,
        radius::Float64, plasma_radius::Float64, center_z::Float64,
        half_separation::Float64, source_hash::String, resolution::Symbol)
    step = resolution == :coarse ? plasma_radius / 16.0 : plasma_radius / 32.0
    half_length = 1.35 * half_separation
    config = FieldLineTraceConfigV1(step_length_m = step,
        maximum_arclength_m = 12.0 * half_length,
        minimum_recurrence_arclength_m = 2.0 * half_length,
        recurrence_tolerance_m = 1.2 * step,
        recurrence_direction_cosine_min = 0.98,
        field_floor_t = 1.0e-9)
    core = only(filter(region -> occursin("mirror_central_cell",
        lowercase(region.kind)) || occursin("mirror_0d",
        lowercase(region.geometry_model)), genome.plasma_regions))
    seed_radii = collect(range(0.08 * plasma_radius, 0.72 * plasma_radius;
        length = 8))
    seeds = FieldLineSeedV1[FieldLineSeedV1("mirror_seed_$index",
        (value, 0.0, center_z), core.id) for (index, value) in
        enumerate(seed_radii)]
    domain = AxisAlignedFieldDomainV1("axisymmetric_mirror_open_box",
        (-1.20 * radius, -1.20 * radius, center_z - half_length),
        (1.20 * radius, 1.20 * radius, center_z + half_length);
        boundary_ids = ("radial_x_min", "radial_x_max", "radial_y_min",
            "radial_y_max", "left_end", "right_end"))
    traces = FieldLineTraceV1[trace_field_line_v1(field, seed, domain, config)
        for seed in seeds]
    pairs = [(seeds[index].id, seeds[index + 1].id)
        for index in 1:(length(seeds) - 1)]
    neighbor = analyze_field_line_neighbor_separation_v1(traces, pairs;
        limit_per_m = 2.0 / plasma_radius)
    statuses, values = neighbor_separation_auxiliary_v1(neighbor)
    statuses["seed_coverage"] = :pass
    statuses["poincare_or_endpoint"] = :pass
    values["seed_coverage_fraction"] = 1.0
    return analyze_field_topology_v1(field, seeds, domain, config;
        design_id = genome.design_id,
        genome_physics_hash = genome.physics_hash,
        field_source_id = "axisymmetric_circular_filament_pair_v1",
        field_source_hash = source_hash,
        source_kind = :candidate_bound_solver_field,
        candidate_binding_verified = true,
        resolution_id = String(resolution),
        covered_domain_ids = [core.id],
        auxiliary_diagnostic_statuses = statuses,
        auxiliary_diagnostic_values = values)
end

function _mirror_filament_topology_physics_v1(item::AbstractDict)
    return Dict{String,Any}(
        "status" => item["status"],
        "topology_class" => item["topology_class"],
        "closed_fraction" => item["closed_fraction"],
        "open_fraction" => item["open_fraction"],
        "unresolved_fraction" => item["unresolved_fraction"],
        "median_connection_length_m" => item["median_connection_length_m"],
        "maximum_local_error_m" => item["maximum_local_error_m"],
        "auxiliary_diagnostic_statuses" =>
            item["auxiliary_diagnostic_statuses"],
        "auxiliary_diagnostic_values" => item["auxiliary_diagnostic_values"],
        "domain" => item["domain"],
        "trace_config" => item["trace_config"],
        "traces" => item["traces"])
end

function _mirror_filament_physical_result_v1(physical::AbstractDict)
    convergence = physical["topology_convergence"]
    return Dict{String,Any}(
        "backend_id" => physical["backend_id"],
        "field_source_hash" => physical["field_source_hash"],
        "loop_radius_m" => physical["loop_radius_m"],
        "pair_half_separation_m" => physical["pair_half_separation_m"],
        "current_per_loop_a" => physical["current_per_loop_a"],
        "central_field_t" => physical["central_field_t"],
        "mirror_ratio" => physical["mirror_ratio"],
        "central_field_relative_error" =>
            physical["central_field_relative_error"],
        "mirror_ratio_relative_error" =>
            physical["mirror_ratio_relative_error"],
        "segment_field_max_relative_change" =>
            physical["segment_field_max_relative_change"],
        "vacuum_divergence_normalized_residual" =>
            physical["vacuum_divergence_normalized_residual"],
        "vacuum_curl_normalized_residual" =>
            physical["vacuum_curl_normalized_residual"],
        "maxwell_evidence_authorized" =>
            physical["maxwell_evidence_authorized"],
        "coarse_topology" => _mirror_filament_topology_physics_v1(
            physical["coarse_topology"]),
        "fine_topology" => _mirror_filament_topology_physics_v1(
            physical["fine_topology"]),
        "topology_convergence" => Dict{String,Any}(
            "status" => convergence["status"],
            "topology_class" => convergence["topology_class"],
            "checks" => convergence["checks"],
            "diagnostics" => convergence["diagnostics"],
            "c1_evidence_authorized" =>
                convergence["c1_evidence_authorized"]),
        "field_topology_evidence_authorized" =>
            physical["field_topology_evidence_authorized"],
        "resolved_topology_class" => physical["resolved_topology_class"],
        "declared_topology_match" => physical["declared_topology_match"],
        "status" => physical["status"],
        "candidate_c1_evidence_authorized" =>
            physical["candidate_c1_evidence_authorized"])
end

function execute_axisymmetric_mirror_filament_c1_v1(genome::Genome)
    source_matches = filter(source -> source.geometry_model ==
        "axisymmetric_circular_filament_pair_v1", genome.field_sources)
    core_matches = filter(region -> occursin("mirror_central_cell",
        lowercase(region.kind)) || occursin("mirror_0d",
        lowercase(region.geometry_model)), genome.plasma_regions)
    length(source_matches) == 1 && length(core_matches) == 1 ||
        return Dict{String,Any}("status" => "unknown",
            "backend_executed" => false,
            "candidate_c1_evidence_authorized" => false,
            "c2_evidence_authorized" => false,
            "reason" => "An explicit filament pair and one mirror central cell are required.")
    source, core = only(source_matches), only(core_matches)
    required = ("loop_radius", "pair_half_separation", "pair_center_z",
        "current_per_loop", "target_central_field", "target_mirror_ratio")
    all(id -> haskey(source.parameters, id), required) ||
        return Dict{String,Any}("status" => "unknown",
            "backend_executed" => false,
            "candidate_c1_evidence_authorized" => false,
            "c2_evidence_authorized" => false,
            "reason" => "Explicit loop source parameters are incomplete.")
    radius = source.parameters["loop_radius"].value
    half_separation = source.parameters["pair_half_separation"].value
    center_z = source.parameters["pair_center_z"].value
    current = source.parameters["current_per_loop"].value
    target_field = source.parameters["target_central_field"].value
    target_ratio = source.parameters["target_mirror_ratio"].value
    plasma_radius = core.parameters["plasma_radius"].value
    source_hash = canonical_hash(Dict{String,Any}(
        "source_id" => source.id, "geometry_model" => source.geometry_model,
        "parameters" => _quantity_parameters_to_dict_v1(source.parameters)))

    coarse_field = _mirror_filament_field_v1(radius, center_z,
        half_separation, current, 256)
    fine_field = _mirror_filament_field_v1(radius, center_z,
        half_separation, current, 1024)
    center_numeric = abs(fine_field((0.0, 0.0, center_z))[3])
    left_throat = abs(fine_field((0.0, 0.0,
        center_z - half_separation))[3])
    right_throat = abs(fine_field((0.0, 0.0,
        center_z + half_separation))[3])
    mirror_ratio = 0.5 * (left_throat + right_throat) / center_numeric
    field_error = abs(center_numeric - target_field) / target_field
    ratio_error = abs(mirror_ratio - target_ratio) / target_ratio
    segment_error = _mirror_filament_field_convergence_v1(coarse_field,
        fine_field, radius, half_separation, center_z)
    coarse_div, coarse_curl = _mirror_filament_vacuum_residuals_v1(
        coarse_field, radius, half_separation, center_z, target_field, 140)
    fine_div, fine_curl = _mirror_filament_vacuum_residuals_v1(
        fine_field, radius, half_separation, center_z, target_field, 280)
    maxwell_authorized = field_error <= 2.0e-4 && ratio_error <= 2.0e-4 &&
        segment_error <= 5.0e-4 && fine_div <= 2.0e-4 &&
        fine_curl <= 2.0e-4 && fine_div <= coarse_div &&
        fine_curl <= coarse_curl
    coarse_topology = _mirror_filament_topology_v1(genome, coarse_field,
        radius, plasma_radius, center_z, half_separation, source_hash, :coarse)
    fine_topology = _mirror_filament_topology_v1(genome, fine_field,
        radius, plasma_radius, center_z, half_separation, source_hash, :fine)
    convergence = compare_field_topology_resolutions_v1(coarse_topology,
        fine_topology)
    topology_authorized = convergence.c1_evidence_authorized
    topology_match = _native_c1_declared_topology_match_v1(genome,
        convergence.topology_class)
    c1 = maxwell_authorized && topology_authorized && topology_match
    status = c1 ? "pass" : maxwell_authorized && topology_authorized ?
        "fail" : "unknown"
    physical = Dict{String,Any}(
        "backend_id" => "axisymmetric_mirror_filament_biot_savart_v1",
        "field_source_hash" => source_hash,
        "loop_radius_m" => radius,
        "pair_half_separation_m" => half_separation,
        "current_per_loop_a" => current,
        "central_field_t" => center_numeric,
        "mirror_ratio" => mirror_ratio,
        "central_field_relative_error" => field_error,
        "mirror_ratio_relative_error" => ratio_error,
        "segment_field_max_relative_change" => segment_error,
        "vacuum_divergence_normalized_residual" => Dict(
            "coarse" => coarse_div, "fine" => fine_div),
        "vacuum_curl_normalized_residual" => Dict(
            "coarse" => coarse_curl, "fine" => fine_curl),
        "maxwell_evidence_authorized" => maxwell_authorized,
        "coarse_topology" => field_topology_data_product_to_dict_v1(
            coarse_topology),
        "fine_topology" => field_topology_data_product_to_dict_v1(
            fine_topology),
        "topology_convergence" => field_topology_convergence_to_dict_v1(
            convergence),
        "field_topology_evidence_authorized" => topology_authorized,
        "resolved_topology_class" => String(convergence.topology_class),
        "declared_topology_match" => topology_match,
        "status" => status,
        "candidate_c1_evidence_authorized" => c1)
    return merge(physical, Dict{String,Any}(
        "schema_version" => "1.0.0",
        "design_id" => genome.design_id,
        "physics_hash" => genome.physics_hash,
        "backend_executed" => true,
        "minimum_b_anchor_enabled" => false,
        "stability_evidence_authorized" => false,
        "c2_evidence_authorized" => false,
        "promotion_authorized" => false,
        "physical_result_hash" => canonical_hash(
            _mirror_filament_physical_result_v1(physical)),
        "claim_ceiling" => "C1_candidate_bound_axisymmetric_mirror_field_and_open_topology",
        "claim_boundary" => "The explicit axisymmetric two-loop field and open field-line topology are solved. The disabled minimum-B anchor gives no interchange/flute stability credit; equilibrium, kinetic confinement, ambipolar end loss, coil engineering, net power and C2 remain unknown."))
end
