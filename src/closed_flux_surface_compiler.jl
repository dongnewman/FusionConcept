struct AxisymmetricFluxFieldGridV1
    design_id::String
    genome_physics_hash::String
    field_source_id::String
    declared_field_source_hash::String
    artifact_sha256::String
    covered_domain_ids::Vector{String}
    radial_grid_m::Vector{Float64}
    axial_grid_m::Vector{Float64}
    br_t::Matrix{Float64}
    bphi_t::Matrix{Float64}
    bz_t::Matrix{Float64}
    normalized_poloidal_flux::Matrix{Float64}
    magnetic_axis_r_m::Float64
    magnetic_axis_z_m::Float64
    separatrix_r_m::Vector{Float64}
    separatrix_z_m::Vector{Float64}
end

struct ClosedFluxSurfaceConfigV1
    normalized_flux_levels::Vector{Float64}
    angular_sample_count::Int
    radial_sample_count::Int
    maximum_tangency_residual::Float64
    maximum_flux_root_error::Float64
    minimum_nesting_gap_m::Float64

    function ClosedFluxSurfaceConfigV1(;
            normalized_flux_levels = collect(0.1:0.1:0.8),
            angular_sample_count::Integer = 72,
            radial_sample_count::Integer = 256,
            maximum_tangency_residual::Real = 0.02,
            maximum_flux_root_error::Real = 1.0e-4,
            minimum_nesting_gap_m::Real = 0.005)
        levels = Float64.(collect(normalized_flux_levels))
        !isempty(levels) && issorted(levels) && length(unique(levels)) == length(levels) ||
            throw(ArgumentError("normalized flux levels must be nonempty, unique, and sorted"))
        all(0 < level < 1 for level in levels) || throw(ArgumentError(
            "normalized flux levels must lie strictly inside (0, 1)"))
        angular_sample_count >= 16 || throw(ArgumentError(
            "closed-surface analysis needs at least 16 angular samples"))
        radial_sample_count >= 32 || throw(ArgumentError(
            "closed-surface analysis needs at least 32 radial samples"))
        maximum_tangency_residual >= 0 || throw(ArgumentError(
            "tangency residual limit must be non-negative"))
        maximum_flux_root_error >= 0 || throw(ArgumentError(
            "flux root-error limit must be non-negative"))
        minimum_nesting_gap_m >= 0 || throw(ArgumentError(
            "minimum nesting gap must be non-negative"))
        return new(levels, Int(angular_sample_count), Int(radial_sample_count),
            Float64(maximum_tangency_residual), Float64(maximum_flux_root_error),
            Float64(minimum_nesting_gap_m))
    end
end

struct ClosedFluxSurfaceRecordV1
    normalized_flux_level::Float64
    resolved_ray_fraction::Float64
    radial_distances_m::Vector{Float64}
    points_rz_m::Vector{NTuple{2,Float64}}
    maximum_flux_root_error::Union{Nothing,Float64}
    maximum_tangency_residual::Union{Nothing,Float64}
    status::Symbol
end

struct ClosedFluxSurfaceDataProductV1
    schema_version::String
    design_id::String
    genome_physics_hash::String
    field_source_id::String
    field_source_hash::String
    source_kind::Symbol
    candidate_binding_verified::Bool
    resolution_id::String
    resolution_stride::Int
    covered_domain_ids::Vector{String}
    config::ClosedFluxSurfaceConfigV1
    surfaces::Vector{ClosedFluxSurfaceRecordV1}
    minimum_observed_nesting_gap_m::Union{Nothing,Float64}
    status::Symbol
    c1_support_authorized::Bool
    evidence_tasks::Vector{String}
    product_hash::String
end

struct ClosedFluxSurfaceConvergenceContractV1
    minimum_resolution_refinement_ratio::Float64
    maximum_mean_radius_relative_difference::Float64
    maximum_pointwise_radius_relative_difference::Float64

    function ClosedFluxSurfaceConvergenceContractV1(;
            minimum_resolution_refinement_ratio::Real = 2.0,
            maximum_mean_radius_relative_difference::Real = 0.05,
            maximum_pointwise_radius_relative_difference::Real = 0.10)
        minimum_resolution_refinement_ratio > 1 || throw(ArgumentError(
            "closed-surface resolution refinement must exceed one"))
        maximum_mean_radius_relative_difference >= 0 || throw(ArgumentError(
            "mean-radius convergence tolerance must be non-negative"))
        maximum_pointwise_radius_relative_difference >= 0 || throw(ArgumentError(
            "pointwise-radius convergence tolerance must be non-negative"))
        return new(Float64(minimum_resolution_refinement_ratio),
            Float64(maximum_mean_radius_relative_difference),
            Float64(maximum_pointwise_radius_relative_difference))
    end
end

struct ClosedFluxSurfaceConvergenceResultV1
    design_id::String
    genome_physics_hash::String
    coarse_product_hash::String
    fine_product_hash::String
    covered_domain_ids::Vector{String}
    status::Symbol
    checks::Dict{String,Bool}
    diagnostics::Dict{String,Float64}
    c1_support_authorized::Bool
    evidence_tasks::Vector{String}
    convergence_hash::String
end

function load_axisymmetric_flux_field_grid_v1(path::AbstractString;
        expected_design_id::Union{Nothing,AbstractString} = nothing,
        expected_genome_physics_hash::Union{Nothing,AbstractString} = nothing)
    bytes = read(path)
    artifact_sha256 = bytes2hex(sha256(bytes))
    raw = JSON3.read(String(copy(bytes)), Dict{String,Any})
    get(raw, "status", nothing) == "pass" || throw(ArgumentError(
        "axisymmetric flux-field artifact is not passing"))
    get(raw, "coordinate_system", nothing) == "cylindrical_axisymmetric" ||
        throw(ArgumentError("flux-field artifact is not axisymmetric cylindrical"))
    haskey(raw, "normalized_poloidal_flux") || throw(ArgumentError(
        "flux-field artifact lacks normalized poloidal flux"))
    design_id = String(raw["design_id"])
    physics_hash = String(raw["genome_physics_hash"])
    expected_design_id === nothing || design_id == expected_design_id ||
        throw(ArgumentError("flux-field design binding mismatch"))
    expected_genome_physics_hash === nothing || physics_hash ==
        expected_genome_physics_hash || throw(ArgumentError(
        "flux-field Genome physics-hash binding mismatch"))
    radial = Float64.(collect(raw["radial_grid_m"]))
    axial = Float64.(collect(raw["axial_grid_m"]))
    nr, nz = length(radial), length(axial)
    nr >= 17 && nz >= 17 || throw(ArgumentError(
        "flux-field grid needs at least 17 points on both axes"))
    all(diff(radial) .> 0) && all(diff(axial) .> 0) || throw(ArgumentError(
        "flux-field grid axes must be strictly increasing"))
    br = _matrix_from_json_rows_v1(raw["br_t"], "br_t", nz, nr)
    bphi = _matrix_from_json_rows_v1(raw["bphi_t"], "bphi_t", nz, nr)
    bz = _matrix_from_json_rows_v1(raw["bz_t"], "bz_t", nz, nr)
    psi = _matrix_from_json_rows_v1(raw["normalized_poloidal_flux"],
        "normalized_poloidal_flux", nz, nr)
    separatrix = raw["separatrix"]
    separatrix_r = Float64.(collect(separatrix["r_m"]))
    separatrix_z = Float64.(collect(separatrix["z_m"]))
    length(separatrix_r) == length(separatrix_z) >= 32 || throw(ArgumentError(
        "separatrix needs at least 32 paired points"))
    axis_r = Float64(raw["magnetic_axis_r_m"])
    axis_z = Float64(raw["magnetic_axis_z_m"])
    first(radial) < axis_r < last(radial) && first(axial) < axis_z < last(axial) ||
        throw(ArgumentError("magnetic axis lies outside the flux-field grid"))
    return AxisymmetricFluxFieldGridV1(design_id, physics_hash,
        String(raw["field_source_id"]), String(raw["field_source_hash"]),
        artifact_sha256, sort!(String.(collect(raw["covered_domain_ids"]))),
        radial, axial, br, bphi, bz, psi, axis_r, axis_z,
        separatrix_r, separatrix_z)
end

function _strided_axis_indices_v1(count::Int, stride::Int)
    stride >= 1 || throw(ArgumentError("resolution stride must be positive"))
    indices = collect(1:stride:count)
    last(indices) == count || push!(indices, count)
    return indices
end

function _scalar_grid_value_v1(radial::Vector{Float64}, axial::Vector{Float64},
        values::Matrix{Float64}, radius::Float64, z::Float64)
    first(radial) <= radius <= last(radial) && first(axial) <= z <= last(axial) ||
        return NaN
    ir = clamp(searchsortedlast(radial, radius), 1, length(radial) - 1)
    iz = clamp(searchsortedlast(axial, z), 1, length(axial) - 1)
    r0, r1 = radial[ir], radial[ir + 1]
    z0, z1 = axial[iz], axial[iz + 1]
    tr, tz = (radius - r0) / (r1 - r0), (z - z0) / (z1 - z0)
    return (1 - tr) * (1 - tz) * values[iz, ir] +
        tr * (1 - tz) * values[iz, ir + 1] +
        (1 - tr) * tz * values[iz + 1, ir] +
        tr * tz * values[iz + 1, ir + 1]
end

function _maximum_ray_distance_v1(axis_r::Float64, axis_z::Float64,
        cosine::Float64, sine::Float64, radial, axial)
    distances = Float64[]
    cosine > 0 && push!(distances, (last(radial) - axis_r) / cosine)
    cosine < 0 && push!(distances, (first(radial) - axis_r) / cosine)
    sine > 0 && push!(distances, (last(axial) - axis_z) / sine)
    sine < 0 && push!(distances, (first(axial) - axis_z) / sine)
    return minimum(distances)
end

function _surface_point_on_ray_v1(level::Float64, angle::Float64,
        axis_r::Float64, axis_z::Float64, radial, axial, psi,
        radial_sample_count::Int)
    cosine, sine = cos(angle), sin(angle)
    maximum_rho = 0.995 * _maximum_ray_distance_v1(axis_r, axis_z,
        cosine, sine, radial, axial)
    previous_rho = 0.0
    previous_value = _scalar_grid_value_v1(radial, axial, psi, axis_r, axis_z)
    isfinite(previous_value) || return nothing
    for index in 1:radial_sample_count
        rho = maximum_rho * index / radial_sample_count
        radius, z = axis_r + rho * cosine, axis_z + rho * sine
        value = _scalar_grid_value_v1(radial, axial, psi, radius, z)
        isfinite(value) || return nothing
        if (previous_value - level) * (value - level) <= 0 && value != previous_value
            lower_rho, upper_rho = previous_rho, rho
            lower_value, upper_value = previous_value, value
            for _ in 1:48
                middle_rho = (lower_rho + upper_rho) / 2
                middle_r = axis_r + middle_rho * cosine
                middle_z = axis_z + middle_rho * sine
                middle_value = _scalar_grid_value_v1(radial, axial, psi,
                    middle_r, middle_z)
                if (lower_value - level) * (middle_value - level) <= 0
                    upper_rho, upper_value = middle_rho, middle_value
                else
                    lower_rho, lower_value = middle_rho, middle_value
                end
            end
            root_rho = (lower_rho + upper_rho) / 2
            root_r, root_z = axis_r + root_rho * cosine, axis_z + root_rho * sine
            root_value = _scalar_grid_value_v1(radial, axial, psi, root_r, root_z)
            return (point = (root_r, root_z), rho = root_rho,
                root_error = abs(root_value - level))
        end
        previous_rho, previous_value = rho, value
    end
    return nothing
end

function _tangency_residual_v1(point::NTuple{2,Float64}, radial, axial,
        br, bphi, bz, psi)
    radius, z = point
    h_r = minimum(diff(radial)) / 2
    h_z = minimum(diff(axial)) / 2
    dpsi_dr = (_scalar_grid_value_v1(radial, axial, psi, radius + h_r, z) -
        _scalar_grid_value_v1(radial, axial, psi, radius - h_r, z)) / (2h_r)
    dpsi_dz = (_scalar_grid_value_v1(radial, axial, psi, radius, z + h_z) -
        _scalar_grid_value_v1(radial, axial, psi, radius, z - h_z)) / (2h_z)
    field = (
        _scalar_grid_value_v1(radial, axial, br, radius, z),
        _scalar_grid_value_v1(radial, axial, bphi, radius, z),
        _scalar_grid_value_v1(radial, axial, bz, radius, z))
    all(isfinite, (dpsi_dr, dpsi_dz, field...)) || return nothing
    gradient_norm = hypot(dpsi_dr, dpsi_dz)
    field_norm = sqrt(sum(value^2 for value in field))
    gradient_norm > 0 && field_norm > 0 || return nothing
    return abs(field[1] * dpsi_dr + field[3] * dpsi_dz) /
        (field_norm * gradient_norm)
end

function _closed_surface_record_to_dict_v1(item::ClosedFluxSurfaceRecordV1)
    return Dict{String,Any}(
        "normalized_flux_level" => item.normalized_flux_level,
        "resolved_ray_fraction" => item.resolved_ray_fraction,
        "radial_distances_m" => item.radial_distances_m,
        "points_rz_m" => [collect(point) for point in item.points_rz_m],
        "maximum_flux_root_error" => item.maximum_flux_root_error,
        "maximum_tangency_residual" => item.maximum_tangency_residual,
        "status" => String(item.status))
end

function _closed_surface_payload_v1(item::ClosedFluxSurfaceDataProductV1)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "field_source_id" => item.field_source_id,
        "field_source_hash" => item.field_source_hash,
        "source_kind" => String(item.source_kind),
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_id" => item.resolution_id,
        "resolution_stride" => item.resolution_stride,
        "covered_domain_ids" => item.covered_domain_ids,
        "config" => Dict{String,Any}(
            "normalized_flux_levels" => item.config.normalized_flux_levels,
            "angular_sample_count" => item.config.angular_sample_count,
            "radial_sample_count" => item.config.radial_sample_count,
            "maximum_tangency_residual" => item.config.maximum_tangency_residual,
            "maximum_flux_root_error" => item.config.maximum_flux_root_error,
            "minimum_nesting_gap_m" => item.config.minimum_nesting_gap_m),
        "surfaces" => [_closed_surface_record_to_dict_v1(surface)
            for surface in item.surfaces],
        "minimum_observed_nesting_gap_m" => item.minimum_observed_nesting_gap_m,
        "status" => String(item.status),
        "c1_support_authorized" => item.c1_support_authorized,
        "evidence_tasks" => item.evidence_tasks)
end

function analyze_closed_flux_surfaces_v1(grid::AxisymmetricFluxFieldGridV1,
        config::ClosedFluxSurfaceConfigV1;
        resolution_id::AbstractString, resolution_stride::Integer,
        source_kind::Symbol, candidate_binding_verified::Bool,
        covered_domain_ids::Vector{String} = copy(grid.covered_domain_ids))
    source_kind in _FIELD_TOPOLOGY_SOURCE_KINDS_V1 || throw(ArgumentError(
        "unknown closed-surface source kind: $source_kind"))
    source_kind == :manufactured_control && candidate_binding_verified &&
        throw(ArgumentError("manufactured closed-surface controls cannot claim binding"))
    isempty(covered_domain_ids) && throw(ArgumentError(
        "closed-surface product must cover at least one physical domain"))
    length(unique(covered_domain_ids)) == length(covered_domain_ids) ||
        throw(ArgumentError("closed-surface covered domain ids must be unique"))
    all(id -> id in grid.covered_domain_ids, covered_domain_ids) ||
        throw(ArgumentError(
            "closed-surface covered domains must be a subset of the source grid coverage"))
    radial_indices = _strided_axis_indices_v1(length(grid.radial_grid_m),
        Int(resolution_stride))
    axial_indices = _strided_axis_indices_v1(length(grid.axial_grid_m),
        Int(resolution_stride))
    radial, axial = grid.radial_grid_m[radial_indices], grid.axial_grid_m[axial_indices]
    br = grid.br_t[axial_indices, radial_indices]
    bphi = grid.bphi_t[axial_indices, radial_indices]
    bz = grid.bz_t[axial_indices, radial_indices]
    psi = grid.normalized_poloidal_flux[axial_indices, radial_indices]
    angles = [2pi * index / config.angular_sample_count
        for index in 0:(config.angular_sample_count - 1)]
    surfaces = ClosedFluxSurfaceRecordV1[]
    for level in config.normalized_flux_levels
        roots = [_surface_point_on_ray_v1(level, angle, grid.magnetic_axis_r_m,
            grid.magnetic_axis_z_m, radial, axial, psi, config.radial_sample_count)
            for angle in angles]
        valid = filter(!isnothing, roots)
        resolved_fraction = length(valid) / length(roots)
        points = NTuple{2,Float64}[root.point for root in valid]
        distances = Float64[root.rho for root in valid]
        root_errors = Float64[root.root_error for root in valid]
        tangencies = Union{Nothing,Float64}[_tangency_residual_v1(point,
            radial, axial, br, bphi, bz, psi) for point in points]
        tangency_complete = all(!isnothing, tangencies)
        maximum_root_error = isempty(root_errors) ? nothing : maximum(root_errors)
        maximum_tangency = !tangency_complete || isempty(tangencies) ? nothing :
            maximum(Float64[value for value in tangencies if value !== nothing])
        status = resolved_fraction == 1.0 && tangency_complete &&
            maximum_root_error <= config.maximum_flux_root_error &&
            maximum_tangency <= config.maximum_tangency_residual ? :pass : :unknown
        push!(surfaces, ClosedFluxSurfaceRecordV1(level, resolved_fraction,
            distances, points, maximum_root_error, maximum_tangency, status))
    end
    nesting_gaps = Float64[]
    nesting_complete = all(length(surface.radial_distances_m) ==
        config.angular_sample_count for surface in surfaces)
    if nesting_complete
        for level_index in 1:(length(surfaces) - 1),
                angle_index in 1:config.angular_sample_count
            push!(nesting_gaps, surfaces[level_index + 1].radial_distances_m[angle_index] -
                surfaces[level_index].radial_distances_m[angle_index])
        end
    end
    minimum_gap = isempty(nesting_gaps) ? nothing : minimum(nesting_gaps)
    nested = nesting_complete && minimum_gap !== nothing &&
        minimum_gap >= config.minimum_nesting_gap_m
    status = all(surface.status == :pass for surface in surfaces) && nested ?
        :pass : :unknown
    authorized = status == :pass && source_kind == :candidate_bound_solver_field &&
        candidate_binding_verified
    tasks = String[]
    all(surface.resolved_ray_fraction == 1.0 for surface in surfaces) || push!(tasks,
        "supply a non-star-shaped contour/Poincare backend or repair incomplete flux surfaces")
    all(surface.maximum_tangency_residual !== nothing &&
        surface.maximum_tangency_residual <= config.maximum_tangency_residual
        for surface in surfaces) || push!(tasks,
        "reduce B-dot-grad-psi tangency residual or refine the field/flux solution")
    all(surface.maximum_flux_root_error !== nothing &&
        surface.maximum_flux_root_error <= config.maximum_flux_root_error
        for surface in surfaces) || push!(tasks,
        "refine scalar-flux contour roots below the declared error limit")
    nested || push!(tasks, "establish strictly nested closed surfaces at every requested level")
    placeholder = ClosedFluxSurfaceDataProductV1("1.0.0", grid.design_id,
        grid.genome_physics_hash, grid.field_source_id, grid.artifact_sha256,
        source_kind, candidate_binding_verified, String(resolution_id),
        Int(resolution_stride), sort(copy(covered_domain_ids)), config, surfaces,
        minimum_gap, status, authorized, sort!(unique(tasks)), "")
    payload = _closed_surface_payload_v1(placeholder)
    return ClosedFluxSurfaceDataProductV1(placeholder.schema_version,
        placeholder.design_id, placeholder.genome_physics_hash,
        placeholder.field_source_id, placeholder.field_source_hash,
        placeholder.source_kind, placeholder.candidate_binding_verified,
        placeholder.resolution_id, placeholder.resolution_stride,
        placeholder.covered_domain_ids, placeholder.config, placeholder.surfaces,
        placeholder.minimum_observed_nesting_gap_m, placeholder.status,
        placeholder.c1_support_authorized, placeholder.evidence_tasks,
        canonical_hash(payload))
end

function closed_flux_surface_data_product_to_dict_v1(
        item::ClosedFluxSurfaceDataProductV1)
    payload = _closed_surface_payload_v1(item)
    payload["product_hash"] = item.product_hash
    payload["promotion_authorized"] = false
    return payload
end

function compare_closed_flux_surface_resolutions_v1(
        coarse::ClosedFluxSurfaceDataProductV1,
        fine::ClosedFluxSurfaceDataProductV1;
        contract::ClosedFluxSurfaceConvergenceContractV1 =
            ClosedFluxSurfaceConvergenceContractV1())
    same_levels = coarse.config.normalized_flux_levels ==
        fine.config.normalized_flux_levels
    same_angles = coarse.config.angular_sample_count == fine.config.angular_sample_count
    comparable = same_levels && same_angles &&
        length(coarse.surfaces) == length(fine.surfaces) &&
        all(length(coarse.surfaces[index].radial_distances_m) ==
            length(fine.surfaces[index].radial_distances_m) ==
            coarse.config.angular_sample_count for index in eachindex(coarse.surfaces))
    mean_differences = Float64[]
    pointwise_differences = Float64[]
    if comparable
        for index in eachindex(coarse.surfaces)
            coarse_radii = coarse.surfaces[index].radial_distances_m
            fine_radii = fine.surfaces[index].radial_distances_m
            push!(mean_differences, _relative_difference_v1(
                sum(coarse_radii) / length(coarse_radii),
                sum(fine_radii) / length(fine_radii)))
            append!(pointwise_differences, [_relative_difference_v1(a, b)
                for (a, b) in zip(coarse_radii, fine_radii)])
        end
    end
    maximum_mean_difference = isempty(mean_differences) ? 0.0 : maximum(mean_differences)
    maximum_pointwise_difference = isempty(pointwise_differences) ? 0.0 :
        maximum(pointwise_differences)
    checks = Dict{String,Bool}(
        "same_design" => coarse.design_id == fine.design_id,
        "same_genome_physics_hash" => coarse.genome_physics_hash ==
            fine.genome_physics_hash,
        "same_field_source" => coarse.field_source_id == fine.field_source_id &&
            coarse.field_source_hash == fine.field_source_hash &&
            coarse.source_kind == fine.source_kind,
        "same_covered_domains" => coarse.covered_domain_ids == fine.covered_domain_ids,
        "same_flux_levels" => same_levels,
        "same_angular_samples" => same_angles,
        "distinct_resolution_ids" => coarse.resolution_id != fine.resolution_id,
        "resolution_refinement" => coarse.resolution_stride /
            fine.resolution_stride >= contract.minimum_resolution_refinement_ratio,
        "source_products_pass" => coarse.status == :pass && fine.status == :pass,
        "surface_records_comparable" => comparable,
        "mean_surface_radius_converged" => comparable && maximum_mean_difference <=
            contract.maximum_mean_radius_relative_difference,
        "pointwise_surface_radius_converged" => comparable &&
            maximum_pointwise_difference <=
                contract.maximum_pointwise_radius_relative_difference)
    status = all(values(checks)) ? :pass : :unknown
    authorized = status == :pass && coarse.c1_support_authorized &&
        fine.c1_support_authorized
    diagnostics = Dict{String,Float64}(
        "resolution_refinement_ratio" => coarse.resolution_stride /
            fine.resolution_stride,
        "maximum_mean_surface_radius_relative_difference" => maximum_mean_difference,
        "maximum_pointwise_surface_radius_relative_difference" =>
            maximum_pointwise_difference,
        "coarse_minimum_nesting_gap_m" => something(
            coarse.minimum_observed_nesting_gap_m, 0.0),
        "fine_minimum_nesting_gap_m" => something(
            fine.minimum_observed_nesting_gap_m, 0.0))
    tasks = sort!(String["repair closed-surface convergence check: $id"
        for (id, passed) in checks if !passed])
    payload = Dict{String,Any}(
        "design_id" => coarse.design_id,
        "genome_physics_hash" => coarse.genome_physics_hash,
        "coarse_product_hash" => coarse.product_hash,
        "fine_product_hash" => fine.product_hash,
        "covered_domain_ids" => fine.covered_domain_ids,
        "status" => String(status), "checks" => checks,
        "diagnostics" => diagnostics,
        "c1_support_authorized" => authorized,
        "evidence_tasks" => tasks)
    return ClosedFluxSurfaceConvergenceResultV1(coarse.design_id,
        coarse.genome_physics_hash, coarse.product_hash, fine.product_hash,
        fine.covered_domain_ids, status, checks, diagnostics, authorized,
        tasks, canonical_hash(payload))
end

function closed_flux_surface_convergence_to_dict_v1(
        item::ClosedFluxSurfaceConvergenceResultV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "coarse_product_hash" => item.coarse_product_hash,
        "fine_product_hash" => item.fine_product_hash,
        "covered_domain_ids" => item.covered_domain_ids,
        "status" => String(item.status), "checks" => item.checks,
        "diagnostics" => item.diagnostics,
        "c1_support_authorized" => item.c1_support_authorized,
        "evidence_tasks" => item.evidence_tasks,
        "convergence_hash" => item.convergence_hash,
        "promotion_authorized" => false)
end

"Candidate-bound supporting evidence; this metric cannot alone resolve all topology domains."
function closed_flux_surface_evidence_bundle_v1(
        result::ClosedFluxSurfaceConvergenceResultV1; fidelity::Integer = 1)
    authorized = result.c1_support_authorized
    status = authorized ? :pass : :unknown
    warnings = authorized ? String[
        "closed-surface support does not resolve open/SOL/exhaust domains or authorize promotion"] :
        vcat(["closed-surface convergence lacks candidate-bound support authority"],
            result.evidence_tasks)
    run_hash = canonical_hash(Dict{String,Any}(
        "evaluator" => "closed_flux_surface_descriptor_v1",
        "convergence_hash" => result.convergence_hash,
        "status" => String(status)))
    metric = MetricResult("closed_flux_surface_descriptor_resolved",
        authorized ? true : nothing; fidelity = Int(fidelity), status = status,
        applicability = "Axisymmetric star-shaped nested scalar-flux surfaces with candidate-bound total field and B-dot-grad-psi tangency audit.",
        constraints_checked = sort!(collect(keys(result.checks))),
        solver_name = "closed_flux_surface_descriptor_v1", solver_version = "1.0.0",
        input_hash = result.genome_physics_hash, run_hash = run_hash,
        source_basis = [result.coarse_product_hash, result.fine_product_hash],
        warnings = warnings, residuals = copy(result.diagnostics))
    bundle_hash = canonical_hash(Dict{String,Any}(
        "metric_run_hash" => run_hash, "convergence_hash" => result.convergence_hash))
    return EvaluationBundle("closed_flux_surface_descriptor_v1", result.design_id,
        "topology_independent", Int(fidelity), status, [metric], warnings,
        result.genome_physics_hash, bundle_hash,
        authorized ? "C1_support_closed_surface_only" : "C0_closed_surface_unknown")
end
