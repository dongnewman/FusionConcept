const _NATIVE_C1_MU0_V1 = 4.0e-7 * pi

_native_c1_parameter_v1(item, id::String) =
    haskey(item.parameters, id) ? item.parameters[id].value : nothing

function _native_c1_raw_quantity_v1(value::Real, unit::String, basis::String)
    return Dict{String,Any}("value" => Float64(value), "unit" => unit,
        "basis" => basis)
end

function _native_c1_set_raw_parameter_v1!(item::AbstractDict, id::String,
        value::Real, unit::String, basis::String)
    old = get(item["parameters"], id, nothing)
    replacement = _native_c1_raw_quantity_v1(value, unit, basis)
    old == replacement && return 0
    item["parameters"][id] = replacement
    return 1
end

function _native_c1_raw_xyz_v1(item::AbstractDict, prefix::String)
    parameters = item["parameters"]
    ids = ["$(prefix)_x", "$(prefix)_y", "$(prefix)_z"]
    all(id -> haskey(parameters, id), ids) || return nothing
    return (Float64(parameters[ids[1]]["value"]),
        Float64(parameters[ids[2]]["value"]),
        Float64(parameters[ids[3]]["value"]))
end

function _native_c1_actuator_xyz_v1(item::Actuator, prefix::String)
    ids = ["$(prefix)_x", "$(prefix)_y", "$(prefix)_z"]
    all(id -> haskey(item.parameters, id), ids) || return nothing
    return (item.parameters[ids[1]].value, item.parameters[ids[2]].value,
        item.parameters[ids[3]].value)
end

function _native_c1_component_tokens_v1(item)
    model = hasproperty(item, :geometry_model) ? getproperty(item, :geometry_model) : ""
    return lowercase("$(item.id)|$(item.kind)|$model")
end

function _native_c1_choose_driver_index_v1(source::AbstractDict,
        actuators::AbstractVector, driver_ids::Set{String})
    candidates = [(index, item) for (index, item) in enumerate(actuators)
        if String(item["id"]) in driver_ids]
    isempty(candidates) && return nothing
    source_text = lowercase("$(source["id"])|$(source["kind"])|" *
        String(get(source, "geometry_model", "")))
    wanted = occursin("fast", source_text) || occursin("ignitor", source_text) ?
        ("fast", "ignitor") : occursin("laser", source_text) ?
        ("laser", "compression") : ()
    for (index, actuator) in candidates
        text = lowercase("$(actuator["id"])|$(actuator["kind"])")
        any(token -> occursin(token, text), wanted) && return index
    end
    return first(candidates)[1]
end

"""
Create an append-only execution Genome for pulsed candidates.

The refinement aligns declared compression targets with their driver focal
points and turns aggregate beam sources into explicit procedural emitter
shells.  Every added value enters the new physics hash and remains an
exploratory design gene, never measured evidence.
"""
function refine_native_candidate_execution_genome_v1(genome::Genome)
    route = physics_c1_route_v2(genome)
    if !(route in (:pulsed_drive_geometry, :hybrid_magnetic_pulsed))
        raw = deepcopy(genome.normalized)
        basis = "exploratory native C1 execution refinement v1"
        changed = 0
        plasma_radii = Float64[value.value for region in genome.plasma_regions
            for (id, value) in region.parameters if id == "plasma_radius" &&
                value.unit == "m" && value.value > 0.0]
        for source in raw["field_sources"]
            String(get(source, "geometry_model", "")) ==
                "finite_radius_axial_current_density" || continue
            isempty(plasma_radii) && continue
            changed += _native_c1_set_raw_parameter_v1!(source,
                "generated_current_channel_radius", minimum(plasma_radii),
                "m", basis)
        end
        changed == 0 && return genome, Dict{String,Any}(
            "derived" => false, "changed_parameter_count" => 0,
            "source_physics_hash" => genome.physics_hash,
            "execution_physics_hash" => genome.physics_hash)
        provenance = raw["provenance"]
        provenance["parent_design_ids"] = sort!(unique(vcat(
            String.(provenance["parent_design_ids"]), [genome.design_id])))
        provenance["source_ids"] = sort!(unique(vcat(
            String.(provenance["source_ids"]),
            ["native_candidate_c1_backend_v1"])))
        provenance["notes"] = vcat(String.(provenance["notes"]), [
            "The finite-radius axial-current source is aligned to the candidate plasma current-channel radius; this is an exploratory execution gene, not measured geometry.",
            "The execution refinement may support a C1 Maxwell result but cannot authorize stability, transport, power or engineering claims."])
        provenance["claim_level"] = "exploratory_C0_native_execution_candidate"
        raw["design_id"] = "pending_native_c1_execution_v1"
        provisional = parse_genome(raw)
        raw["design_id"] = "execv1_$(genome.physics_hash[1:12])_" *
            provisional.physics_hash[1:12]
        derived = parse_genome(raw)
        validation = validate_genome(derived)
        validation.valid || throw(ArgumentError(
            "native C1 execution Genome invalid: $(join(validation.errors, "; "))"))
        return derived, Dict{String,Any}(
            "derived" => true, "changed_parameter_count" => changed,
            "source_physics_hash" => genome.physics_hash,
            "execution_physics_hash" => derived.physics_hash,
            "execution_design_id" => derived.design_id,
            "current_channel_alignment_count" => 1)
    end
    raw = deepcopy(genome.normalized)
    basis = "exploratory native C1 execution refinement v1"
    changed = 0
    driver_ids = Set{String}(String(id) for system in
        get(raw, "compression_systems", Any[]) for id in
        get(system, "driver_actuator_ids", Any[]))
    target_ids = Set{String}(String(id) for system in
        get(raw, "compression_systems", Any[]) for id in
        get(system, "target_region_ids", Any[]))
    actuator_targets = Tuple{Float64,Float64,Float64}[]
    for actuator in get(raw, "actuators", Any[])
        String(actuator["id"]) in driver_ids || continue
        target = _native_c1_raw_xyz_v1(actuator,
            "generated_target_position")
        target === nothing || push!(actuator_targets, target)
    end
    focal = isempty(actuator_targets) ? (0.0, 0.0, 0.0) :
        ntuple(axis -> sum(point[axis] for point in actuator_targets) /
            length(actuator_targets), 3)
    for region in raw["plasma_regions"]
        String(region["id"]) in target_ids || continue
        parameters = region["parameters"]
        if haskey(parameters, "generated_center_position_x")
            for (axis, value) in zip(("x", "y", "z"), focal)
                changed += _native_c1_set_raw_parameter_v1!(region,
                    "generated_center_position_$axis", value, "m", basis)
            end
        else
            changed += _native_c1_set_raw_parameter_v1!(region,
                "generated_center_position_r", hypot(focal[1], focal[2]),
                "m", basis)
            changed += _native_c1_set_raw_parameter_v1!(region,
                "generated_center_position_z", focal[3], "m", basis)
        end
    end
    source_distances = Float64[]
    for actuator in get(raw, "actuators", Any[])
        String(actuator["id"]) in driver_ids || continue
        source = _native_c1_raw_xyz_v1(actuator,
            "generated_source_position")
        source === nothing || push!(source_distances,
            sqrt(sum((source[axis] - focal[axis])^2 for axis in 1:3)))
    end
    shell_radius = isempty(source_distances) ? 1.0 : maximum(source_distances)
    actuator_list = get(raw, "actuators", Any[])
    for source in raw["field_sources"]
        text = lowercase("$(source["id"])|$(source["kind"])|" *
            String(get(source, "geometry_model", "")))
        (occursin("beam", text) || occursin("laser", text) ||
            occursin("ignitor", text)) || continue
        explicit_ids = ("generated_emitter_count",
            "generated_emitter_shell_radius",
            "generated_driver_actuator_index",
            "generated_focus_position_x", "generated_focus_position_y",
            "generated_focus_position_z")
        already_explicit = String(get(source, "geometry_model", "")) ==
            "procedural_fibonacci_emitter_shell_to_focus_v1" &&
            all(id -> haskey(source["parameters"], id), explicit_ids)
        already_explicit && continue
        driver_index = _native_c1_choose_driver_index_v1(source,
            actuator_list, driver_ids)
        driver_index === nothing && continue
        emitter_count = occursin("array", text) || occursin("multi", text) ?
            48 : 1
        changed += _native_c1_set_raw_parameter_v1!(source,
            "generated_emitter_count", emitter_count, "1", basis)
        changed += _native_c1_set_raw_parameter_v1!(source,
            "generated_emitter_shell_radius", shell_radius, "m", basis)
        changed += _native_c1_set_raw_parameter_v1!(source,
            "generated_driver_actuator_index", driver_index, "1", basis)
        for (axis, value) in zip(("x", "y", "z"), focal)
            changed += _native_c1_set_raw_parameter_v1!(source,
                "generated_focus_position_$axis", value, "m", basis)
        end
        source["geometry_model"] =
            "procedural_fibonacci_emitter_shell_to_focus_v1"
    end
    provenance = raw["provenance"]
    provenance["parent_design_ids"] = sort!(unique(vcat(
        String.(provenance["parent_design_ids"]), [genome.design_id])))
    provenance["source_ids"] = sort!(unique(vcat(
        String.(provenance["source_ids"]),
        ["native_candidate_c1_backend_v1"])))
    provenance["notes"] = vcat(String.(provenance["notes"]), [
        "Pulsed target alignment and procedural emitter geometry are exploratory execution genes, not measured hardware geometry.",
        "The execution refinement may support a C1 geometry result but cannot authorize radiation hydrodynamics, gain, repetition, chamber or engineering claims."])
    provenance["claim_level"] = "exploratory_C0_native_execution_candidate"
    raw["design_id"] = "pending_native_c1_execution_v1"
    provisional = parse_genome(raw)
    raw["design_id"] = "execv1_$(genome.physics_hash[1:12])_" *
        provisional.physics_hash[1:12]
    derived = parse_genome(raw)
    validation = validate_genome(derived)
    validation.valid || throw(ArgumentError(
        "native C1 execution Genome invalid: $(join(validation.errors, "; "))"))
    return derived, Dict{String,Any}(
        "derived" => true, "changed_parameter_count" => changed,
        "source_physics_hash" => genome.physics_hash,
        "execution_physics_hash" => derived.physics_hash,
        "execution_design_id" => derived.design_id,
        "target_alignment_count" => length(target_ids),
        "driver_count" => length(driver_ids))
end

function _native_c1_axial_current_source_v1(genome::Genome)
    active = FieldSource[]
    for source in genome.field_sources
        source.kind in ("passive_conductor", "conducting_shell",
            "external_flux_conserver") && continue
        push!(active, source)
    end
    supported = filter(source ->
        source.geometry_model == "finite_radius_axial_current_density" &&
        haskey(source.parameters, "total_current") &&
        haskey(source.parameters, "generated_half_width_r"), active)
    length(active) == 1 && length(supported) == 1 || return nothing
    return only(supported)
end

function _native_c1_axial_current_field_v1(current_a::Float64,
        radius_m::Float64)
    return function(point)
        x, y, _ = Float64.(collect(point))
        radius = hypot(x, y)
        radius <= eps(Float64) && return (0.0, 0.0, 0.0)
        enclosed = radius <= radius_m ? current_a * (radius / radius_m)^2 :
            current_a
        bphi = _NATIVE_C1_MU0_V1 * enclosed / (2.0 * pi * radius)
        return (-bphi * y / radius, bphi * x / radius, 0.0)
    end
end

function _native_c1_ampere_circulation_v1(field, radius::Float64, n::Int)
    points = [(radius * cos(2.0 * pi * index / n),
        radius * sin(2.0 * pi * index / n), 0.0) for index in 0:(n - 1)]
    total = 0.0
    for index in eachindex(points)
        first_point = points[index]
        second_point = points[mod1(index + 1, n)]
        b1, b2 = field(first_point), field(second_point)
        dl = ntuple(axis -> second_point[axis] - first_point[axis], 3)
        total += sum(0.5 * (b1[axis] + b2[axis]) * dl[axis]
            for axis in 1:3)
    end
    return total
end

function _native_c1_divergence_audit_v1(field, radius_m::Float64,
        edge_field_t::Float64, divisions::Int)
    h = radius_m / divisions
    values = Float64[]
    for x in range(-1.4 * radius_m, 1.4 * radius_m; length = 9),
            y in range(-1.4 * radius_m, 1.4 * radius_m; length = 9)
        radius = hypot(x, y)
        (radius < 0.15 * radius_m || abs(radius - radius_m) < 0.12 * radius_m) &&
            continue
        bx_plus = field((x + h, y, 0.0))[1]
        bx_minus = field((x - h, y, 0.0))[1]
        by_plus = field((x, y + h, 0.0))[2]
        by_minus = field((x, y - h, 0.0))[2]
        divergence = (bx_plus - bx_minus + by_plus - by_minus) / (2.0 * h)
        push!(values, abs(divergence) * radius_m / max(edge_field_t, 1.0e-30))
    end
    return maximum(values)
end

function _native_c1_topology_product_v1(genome::Genome, field,
        radius_m::Float64, half_length_m::Float64, source_hash::String,
        resolution::Symbol)
    step = resolution == :coarse ? radius_m / 18.0 : radius_m / 36.0
    config = FieldLineTraceConfigV1(step_length_m = step,
        maximum_arclength_m = 8.0 * radius_m,
        minimum_recurrence_arclength_m = 0.5 * radius_m,
        recurrence_tolerance_m = 1.35 * step,
        recurrence_direction_cosine_min = 0.98,
        field_floor_t = 1.0e-10)
    core = first(genome.plasma_regions)
    radii = collect(range(0.24 * radius_m, 0.84 * radius_m; length = 8))
    seeds = FieldLineSeedV1[FieldLineSeedV1("native_seed_$index",
        (radius, 0.0, (isodd(index) ? -0.15 : 0.15) * half_length_m),
        core.id) for (index, radius) in enumerate(radii)]
    domain = AxisAlignedFieldDomainV1("native_current_field_box",
        (-1.5 * radius_m, -1.5 * radius_m, -half_length_m),
        (1.5 * radius_m, 1.5 * radius_m, half_length_m))
    traces = FieldLineTraceV1[trace_field_line_v1(field, seed, domain, config)
        for seed in seeds]
    pairs = [(seeds[index].id, seeds[index + 1].id)
        for index in 1:(length(seeds) - 1)]
    neighbor = analyze_field_line_neighbor_separation_v1(traces, pairs;
        limit_per_m = 2.0 / radius_m)
    statuses, values = neighbor_separation_auxiliary_v1(neighbor)
    statuses["seed_coverage"] = :pass
    statuses["poincare_or_endpoint"] = :pass
    values["seed_coverage_fraction"] = 1.0
    return analyze_field_topology_v1(field, seeds, domain, config;
        design_id = genome.design_id,
        genome_physics_hash = genome.physics_hash,
        field_source_id = "finite_radius_axial_current_backend_v1",
        field_source_hash = source_hash,
        source_kind = :candidate_bound_solver_field,
        candidate_binding_verified = true,
        resolution_id = String(resolution),
        covered_domain_ids = [region.id for region in genome.plasma_regions],
        auxiliary_diagnostic_statuses = statuses,
        auxiliary_diagnostic_values = values)
end

function _native_c1_declared_topology_match_v1(genome::Genome,
        actual::Symbol)
    text = lowercase(genome.topology.field_line_class)
    occursin("open", text) && return actual == :open_dominated
    genome.topology.expected_flux_surfaces === true &&
        return actual in (:closed_dominated, :mixed)
    return true
end

function _native_c1_execute_magnetic_v1(genome::Genome)
    source = _native_c1_axial_current_source_v1(genome)
    source === nothing && return Dict{String,Any}(
        "status" => "unknown", "backend_executed" => false,
        "field_solution_evidence_authorized" => false,
        "field_topology_evidence_authorized" => false,
        "declared_topology_match" => nothing,
        "hard_falsified" => false,
        "reason" => "No exactly supported physical current source; nominal field values are not inverted into fictitious coil currents.")
    current = source.parameters["total_current"].value
    radius = haskey(source.parameters, "generated_current_channel_radius") ?
        source.parameters["generated_current_channel_radius"].value :
        source.parameters["generated_half_width_r"].value
    current != 0.0 && radius > 0.0 || return Dict{String,Any}(
        "status" => "unknown", "backend_executed" => false,
        "field_solution_evidence_authorized" => false,
        "field_topology_evidence_authorized" => false,
        "declared_topology_match" => nothing, "hard_falsified" => false,
        "reason" => "Axial-current backend requires nonzero current and positive radius.")
    half_length = maximum(vcat([value.value for region in genome.plasma_regions
        for (id, value) in region.parameters if occursin("half_length", id) &&
            value.unit == "m"], [4.0 * radius]))
    field = _native_c1_axial_current_field_v1(current, radius)
    sample_radii = radius .* [0.25, 0.50, 0.75, 1.25, 1.75]
    function ampere_residual(n)
        residuals = Float64[]
        for sample in sample_radii
            expected = _NATIVE_C1_MU0_V1 * current *
                (sample <= radius ? (sample / radius)^2 : 1.0)
            observed = _native_c1_ampere_circulation_v1(field, sample, n)
            push!(residuals, abs(observed - expected) /
                max(abs(expected), 1.0e-30))
        end
        return maximum(residuals)
    end
    coarse_ampere = ampere_residual(96)
    fine_ampere = ampere_residual(384)
    edge_field = abs(_NATIVE_C1_MU0_V1 * current / (2.0 * pi * radius))
    coarse_divergence = _native_c1_divergence_audit_v1(field, radius,
        edge_field, 80)
    fine_divergence = _native_c1_divergence_audit_v1(field, radius,
        edge_field, 160)
    declared_edges = Float64[value.value for region in genome.plasma_regions
        for (id, value) in region.parameters if id == "edge_azimuthal_field" &&
            value.unit == "T"]
    edge_relative = isempty(declared_edges) ? nothing :
        abs(edge_field - first(declared_edges)) /
            max(abs(first(declared_edges)), 1.0e-30)
    maxwell_authorized = fine_ampere <= 2.0e-4 &&
        fine_divergence <= 5.0e-5 &&
        fine_ampere < coarse_ampere && fine_divergence <= coarse_divergence &&
        (edge_relative === nothing || edge_relative <= 1.0e-6)
    source_hash = canonical_hash(Dict{String,Any}(
        "source_id" => source.id, "kind" => source.kind,
        "geometry_model" => source.geometry_model,
        "parameters" => _quantity_parameters_to_dict_v1(source.parameters)))
    coarse = _native_c1_topology_product_v1(genome, field, radius,
        half_length, source_hash, :coarse)
    fine = _native_c1_topology_product_v1(genome, field, radius,
        half_length, source_hash, :fine)
    convergence = compare_field_topology_resolutions_v1(coarse, fine)
    topology_authorized = convergence.c1_evidence_authorized
    topology_match = _native_c1_declared_topology_match_v1(genome,
        convergence.topology_class)
    hard_falsified = maxwell_authorized && topology_authorized && !topology_match
    status = hard_falsified ? "fail" :
        maxwell_authorized && topology_authorized ? "pass" : "unknown"
    return Dict{String,Any}(
        "status" => status, "backend_executed" => true,
        "backend_id" => "finite_radius_axial_current_maxwell_v1",
        "field_source_id" => source.id, "field_source_hash" => source_hash,
        "current_a" => current, "current_radius_m" => radius,
        "edge_field_t" => edge_field,
        "declared_edge_field_relative_error" => edge_relative,
        "ampere_relative_residual" => Dict("coarse" => coarse_ampere,
            "fine" => fine_ampere),
        "divergence_normalized_residual" => Dict(
            "coarse" => coarse_divergence, "fine" => fine_divergence),
        "field_solution_evidence_authorized" => maxwell_authorized,
        "coarse_topology" => field_topology_data_product_to_dict_v1(coarse),
        "fine_topology" => field_topology_data_product_to_dict_v1(fine),
        "topology_convergence" => field_topology_convergence_to_dict_v1(
            convergence),
        "field_topology_evidence_authorized" => topology_authorized,
        "declared_field_line_class" => genome.topology.field_line_class,
        "resolved_topology_class" => String(convergence.topology_class),
        "declared_topology_match" => topology_match,
        "hard_falsified" => hard_falsified,
        "reason" => hard_falsified ?
            "Candidate-bound Maxwell and field-line solves converge, but the resolved field-line topology contradicts the declared topology route." :
            "Candidate-bound analytic Maxwell source and field-line convergence were executed.")
end

function _native_c1_region_contains_v1(region::PlasmaRegion,
        point::NTuple{3,Float64})
    p = region.parameters
    if all(id -> haskey(p, id), ("generated_center_position_x",
            "generated_center_position_y", "generated_center_position_z",
            "generated_outer_radius"))
        center = (p["generated_center_position_x"].value,
            p["generated_center_position_y"].value,
            p["generated_center_position_z"].value)
        return sqrt(sum((point[axis] - center[axis])^2 for axis in 1:3)) <=
            p["generated_outer_radius"].value
    end
    if all(id -> haskey(p, id), ("generated_center_position_r",
            "generated_center_position_z", "generated_half_width_r",
            "generated_half_width_z"))
        radius = hypot(point[1], point[2])
        return abs(radius - p["generated_center_position_r"].value) <=
            p["generated_half_width_r"].value &&
            abs(point[3] - p["generated_center_position_z"].value) <=
            p["generated_half_width_z"].value
    end
    return false
end

function _native_c1_fibonacci_emitters_v1(count::Int, radius::Float64,
        focus::NTuple{3,Float64})
    golden = pi * (3.0 - sqrt(5.0))
    points = NTuple{3,Float64}[]
    for index in 0:(count - 1)
        y = 1.0 - 2.0 * (index + 0.5) / count
        radial = sqrt(max(0.0, 1.0 - y^2))
        angle = golden * index
        push!(points, (focus[1] + radius * radial * cos(angle),
            focus[2] + radius * y,
            focus[3] + radius * radial * sin(angle)))
    end
    return points
end

function _native_c1_execute_pulse_v1(genome::Genome)
    route = physics_c1_route_v2(genome)
    route in (:pulsed_drive_geometry, :hybrid_magnetic_pulsed) ||
        return Dict{String,Any}(
            "status" => "not_applicable", "backend_executed" => false,
            "drive_geometry_evidence_authorized" => false,
            "drive_source_map_evidence_authorized" => false,
            "hydrodynamics_input_ready" => false)
    actuator_by_id = Dict(item.id => item for item in genome.actuators)
    region_by_id = Dict(item.id => item for item in genome.plasma_regions)
    link_errors = String[]
    maps = Dict{String,Any}[]
    for system in genome.compression_systems
        for driver_id in system.driver_actuator_ids
            haskey(actuator_by_id, driver_id) || begin
                push!(link_errors, "missing driver actuator $driver_id")
                continue
            end
            actuator = actuator_by_id[driver_id]
            source = _native_c1_actuator_xyz_v1(actuator,
                "generated_source_position")
            target = _native_c1_actuator_xyz_v1(actuator,
                "generated_target_position")
            if source === nothing || target === nothing
                push!(link_errors, "driver $driver_id lacks source/target coordinates")
                continue
            end
            distance = sqrt(sum((source[axis] - target[axis])^2 for axis in 1:3))
            distance > 0.0 || push!(link_errors,
                "driver $driver_id has zero source-target distance")
            target_checks = Dict{String,Bool}()
            for target_id in system.target_region_ids
                if !haskey(region_by_id, target_id)
                    push!(link_errors, "missing compression target region $target_id")
                    target_checks[target_id] = false
                else
                    target_checks[target_id] = _native_c1_region_contains_v1(
                        region_by_id[target_id], target)
                    target_checks[target_id] || push!(link_errors,
                        "driver $driver_id focus lies outside target $target_id")
                end
            end
            push!(maps, Dict{String,Any}(
                "compression_system_id" => system.id,
                "driver_actuator_id" => driver_id,
                "source_position_m" => collect(source),
                "target_position_m" => collect(target),
                "path_length_m" => distance,
                "target_region_containment" => target_checks))
        end
    end
    emitter_maps = Dict{String,Any}[]
    source_binding_errors = String[]
    for source in genome.field_sources
        haskey(source.parameters, "generated_emitter_count") || continue
        count = round(Int, source.parameters["generated_emitter_count"].value)
        driver_index = round(Int,
            source.parameters["generated_driver_actuator_index"].value)
        if !(1 <= driver_index <= length(genome.actuators)) || count < 1
            push!(source_binding_errors, "invalid emitter/driver index for $(source.id)")
            continue
        end
        driver = genome.actuators[driver_index]
        focus = (source.parameters["generated_focus_position_x"].value,
            source.parameters["generated_focus_position_y"].value,
            source.parameters["generated_focus_position_z"].value)
        radius = source.parameters["generated_emitter_shell_radius"].value
        radius > 0.0 || begin
            push!(source_binding_errors, "nonpositive emitter radius for $(source.id)")
            continue
        end
        emitters = _native_c1_fibonacci_emitters_v1(count, radius, focus)
        map_hash = canonical_hash(Dict{String,Any}(
            "field_source_id" => source.id, "driver_actuator_id" => driver.id,
            "focus_position_m" => collect(focus), "emitter_positions_m" =>
                [collect(point) for point in emitters]))
        push!(emitter_maps, Dict{String,Any}(
            "field_source_id" => source.id,
            "driver_actuator_id" => driver.id,
            "emitter_count" => count, "shell_radius_m" => radius,
            "focus_position_m" => collect(focus),
            "minimum_path_length_m" => minimum(sqrt(sum(
                (point[axis] - focus[axis])^2 for axis in 1:3))
                for point in emitters),
            "maximum_path_length_m" => maximum(sqrt(sum(
                (point[axis] - focus[axis])^2 for axis in 1:3))
                for point in emitters),
            "source_map_hash" => map_hash))
    end
    beam_sources = count(source -> begin
        text = _native_c1_component_tokens_v1(source)
        occursin("beam", text) || occursin("laser", text) ||
            occursin("ignitor", text)
    end, genome.field_sources)
    drive_geometry = !isempty(maps) && isempty(link_errors)
    source_map = drive_geometry && isempty(source_binding_errors) &&
        (beam_sources == 0 || length(emitter_maps) == beam_sources)
    authorized = drive_geometry && source_map
    return Dict{String,Any}(
        "status" => authorized ? "pass" : "unknown",
        "backend_executed" => true,
        "backend_id" => "procedural_pulsed_drive_geometry_v1",
        "compression_path_count" => length(maps),
        "compression_paths" => maps,
        "beam_source_count" => beam_sources,
        "procedural_emitter_map_count" => length(emitter_maps),
        "procedural_emitter_count" => sum(Int(item["emitter_count"])
            for item in emitter_maps; init = 0),
        "emitter_maps" => emitter_maps,
        "link_errors" => sort!(unique(link_errors)),
        "source_binding_errors" => sort!(unique(source_binding_errors)),
        "drive_geometry_evidence_authorized" => drive_geometry,
        "drive_source_map_evidence_authorized" => source_map,
        "hydrodynamics_input_ready" => false,
        "hydrodynamics_missing_inputs" => ["candidate thermodynamic profiles",
            "candidate material properties", "radiation-hydrodynamics backend",
            "mesh/time-step convergence", "mix and instability spectrum"],
        "claim_boundary" => "This is a candidate-bound geometric source map only. It does not solve absorption, compression, burn, mix, radiation hydrodynamics, chamber clearing or repetition.")
end

function _native_c1_family_invariant_summary_v1(route::Symbol,
        magnetic::AbstractDict, pulse::AbstractDict, c1_authorized::Bool,
        hard_fail::Bool, status::String)
    fine_topology = get(magnetic, "fine_topology", Dict{String,Any}())
    magnetic_summary = Dict{String,Any}(
        "status" => get(magnetic, "status", "unknown"),
        "backend_executed" => get(magnetic, "backend_executed", false),
        "current_a" => get(magnetic, "current_a", nothing),
        "current_radius_m" => get(magnetic, "current_radius_m", nothing),
        "edge_field_t" => get(magnetic, "edge_field_t", nothing),
        "declared_edge_field_relative_error" => get(magnetic,
            "declared_edge_field_relative_error", nothing),
        "ampere_relative_residual" => get(magnetic,
            "ampere_relative_residual", nothing),
        "divergence_normalized_residual" => get(magnetic,
            "divergence_normalized_residual", nothing),
        "field_solution_evidence_authorized" => get(magnetic,
            "field_solution_evidence_authorized", false),
        "field_topology_evidence_authorized" => get(magnetic,
            "field_topology_evidence_authorized", false),
        "declared_field_line_class" => get(magnetic,
            "declared_field_line_class", nothing),
        "resolved_topology_class" => get(magnetic,
            "resolved_topology_class", nothing),
        "closed_fraction" => get(fine_topology, "closed_fraction", nothing),
        "open_fraction" => get(fine_topology, "open_fraction", nothing),
        "declared_topology_match" => get(magnetic,
            "declared_topology_match", nothing),
        "hard_falsified" => get(magnetic, "hard_falsified", false))
    pulse_summary = Dict{String,Any}(
        "status" => get(pulse, "status", "unknown"),
        "backend_executed" => get(pulse, "backend_executed", false),
        "compression_paths" => get(pulse, "compression_paths", Any[]),
        "beam_source_count" => get(pulse, "beam_source_count", 0),
        "procedural_emitter_count" => get(pulse,
            "procedural_emitter_count", 0),
        "emitter_maps" => get(pulse, "emitter_maps", Any[]),
        "link_errors" => get(pulse, "link_errors", Any[]),
        "source_binding_errors" => get(pulse,
            "source_binding_errors", Any[]),
        "drive_geometry_evidence_authorized" => get(pulse,
            "drive_geometry_evidence_authorized", false),
        "drive_source_map_evidence_authorized" => get(pulse,
            "drive_source_map_evidence_authorized", false))
    return Dict{String,Any}(
        "c1_route" => String(route), "magnetic" => magnetic_summary,
        "pulse" => pulse_summary,
        "candidate_c1_evidence_authorized" => c1_authorized,
        "hard_falsified" => hard_fail, "status" => status)
end

"Execute the available native C1 backends without using the family label."
function execute_native_candidate_c1_backend_v1(genome::Genome)
    execution_genome, refinement =
        refine_native_candidate_execution_genome_v1(genome)
    magnetic = _native_c1_execute_magnetic_v1(execution_genome)
    pulse = _native_c1_execute_pulse_v1(execution_genome)
    route = physics_c1_route_v2(execution_genome)
    magnetic_complete = get(magnetic,
        "field_solution_evidence_authorized", false) === true &&
        get(magnetic, "field_topology_evidence_authorized", false) === true
    magnetic_match = get(magnetic, "declared_topology_match", false) === true
    pulse_complete = get(pulse,
        "drive_geometry_evidence_authorized", false) === true &&
        get(pulse, "drive_source_map_evidence_authorized", false) === true
    hard_fail = get(magnetic, "hard_falsified", false) === true
    c1_authorized = route == :magnetic_field_topology ?
        magnetic_complete && magnetic_match :
        route == :pulsed_drive_geometry ? pulse_complete :
        route == :hybrid_magnetic_pulsed ?
            magnetic_complete && magnetic_match && pulse_complete : false
    status = hard_fail ? "fail" : c1_authorized ? "pass" : "unknown"
    physical_core = _native_c1_family_invariant_summary_v1(route, magnetic,
        pulse, c1_authorized, hard_fail, status)
    return Dict{String,Any}(
        "schema_version" => "1.0.0",
        "executor_version" => "native_candidate_c1_backend_v1.0.0",
        "source_design_id" => genome.design_id,
        "source_physics_hash" => genome.physics_hash,
        "execution_design_id" => execution_genome.design_id,
        "execution_physics_hash" => execution_genome.physics_hash,
        "execution_genome" => execution_genome.normalized,
        "execution_refinement" => refinement,
        "c1_route" => String(route), "magnetic" => magnetic,
        "pulse" => pulse, "status" => status,
        "candidate_c1_evidence_authorized" => c1_authorized,
        "hard_falsified" => hard_fail,
        "physical_result_hash" => canonical_hash(physical_core),
        "promotion_authorized" => false,
        "claim_ceiling" => c1_authorized ?
            "C1_candidate_bound_route_evidence_only" :
            hard_fail ? "C1_candidate_bound_hard_falsification" :
            "C0_C1_incomplete_unknown",
        "claim_boundary" => "C1 route evidence does not authorize equilibrium, stability, transport, fusion gain, engineering feasibility, C2, performance ranking or promotion.")
end
