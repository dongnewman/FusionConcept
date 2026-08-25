struct Periodic3DSurfaceGridV1
    design_id::String
    genome_physics_hash::String
    surface_source_id::String
    declared_surface_source_hash::String
    artifact_sha256::String
    source_solver_result_hash::String
    covered_domain_ids::Vector{String}
    field_periods::Int
    field_period_angle_rad::Float64
    rho_levels::Vector{Float64}
    theta_values_rad::Vector{Float64}
    zeta_values_rad::Vector{Float64}
    x_rpz_m::Array{NTuple{3,Float64},3}
    b_rpz_t::Array{NTuple{3,Float64},3}
    e_rho_rpz_m::Array{NTuple{3,Float64},3}
    e_theta_rpz_m::Array{NTuple{3,Float64},3}
    e_zeta_rpz_m::Array{NTuple{3,Float64},3}
    sqrt_g_m3::Array{Float64,3}
end

struct Periodic3DSurfaceConfigV1
    maximum_spatial_seam_error_m::Float64
    maximum_angular_seam_error_rad::Float64
    maximum_tangency_residual::Float64
    minimum_signed_jacobian_m3::Float64
    maximum_jacobian_relative_error::Float64
    minimum_normal_nesting_gap_m::Float64

    function Periodic3DSurfaceConfigV1(;
            maximum_spatial_seam_error_m::Real = 1.0e-8,
            maximum_angular_seam_error_rad::Real = 1.0e-10,
            maximum_tangency_residual::Real = 1.0e-8,
            minimum_signed_jacobian_m3::Real = 1.0e-8,
            maximum_jacobian_relative_error::Real = 1.0e-8,
            minimum_normal_nesting_gap_m::Real = 0.01)
        values = (maximum_spatial_seam_error_m, maximum_angular_seam_error_rad,
            maximum_tangency_residual, minimum_signed_jacobian_m3,
            maximum_jacobian_relative_error, minimum_normal_nesting_gap_m)
        all(isfinite, values) && all(value >= 0 for value in values) ||
            throw(ArgumentError("periodic-surface thresholds must be finite and non-negative"))
        return new(Float64.(values)...)
    end
end

struct Periodic3DSurfaceRecordV1
    rho::Float64
    maximum_theta_spatial_seam_error_m::Float64
    maximum_theta_angular_seam_error_rad::Float64
    maximum_zeta_spatial_seam_error_m::Float64
    maximum_zeta_angular_seam_error_rad::Float64
    maximum_tangency_residual::Float64
    minimum_signed_jacobian_m3::Float64
    maximum_jacobian_relative_error::Float64
    estimated_surface_area_m2::Float64
    mean_major_radius_m::Float64
    status::Symbol
end

struct Periodic3DSurfaceDataProductV1
    schema_version::String
    design_id::String
    genome_physics_hash::String
    surface_source_id::String
    surface_source_hash::String
    source_kind::Symbol
    candidate_binding_verified::Bool
    resolution_id::String
    resolution_stride::Int
    covered_domain_ids::Vector{String}
    config::Periodic3DSurfaceConfigV1
    surfaces::Vector{Periodic3DSurfaceRecordV1}
    minimum_observed_normal_nesting_gap_m::Union{Nothing,Float64}
    status::Symbol
    c1_support_authorized::Bool
    evidence_tasks::Vector{String}
    product_hash::String
end

struct Periodic3DSurfaceConvergenceContractV1
    minimum_resolution_refinement_ratio::Float64
    maximum_surface_area_relative_difference::Float64
    maximum_mean_major_radius_relative_difference::Float64

    function Periodic3DSurfaceConvergenceContractV1(;
            minimum_resolution_refinement_ratio::Real = 2.0,
            maximum_surface_area_relative_difference::Real = 0.01,
            maximum_mean_major_radius_relative_difference::Real = 0.001)
        minimum_resolution_refinement_ratio > 1 || throw(ArgumentError(
            "periodic-surface resolution refinement must exceed one"))
        maximum_surface_area_relative_difference >= 0 || throw(ArgumentError(
            "surface-area convergence tolerance must be non-negative"))
        maximum_mean_major_radius_relative_difference >= 0 || throw(ArgumentError(
            "major-radius convergence tolerance must be non-negative"))
        return new(Float64(minimum_resolution_refinement_ratio),
            Float64(maximum_surface_area_relative_difference),
            Float64(maximum_mean_major_radius_relative_difference))
    end
end

struct Periodic3DSurfaceConvergenceResultV1
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

_tuple3_float_v1(value, label) = begin
    length(value) == 3 || throw(ArgumentError("$label entries must have three components"))
    item = Tuple(Float64.(collect(value)))
    all(isfinite, item) || throw(ArgumentError("$label contains non-finite values"))
    item
end

function _validate_declared_python_hash_v1(raw::Dict{String,Any}, key::String)
    haskey(raw, key) || throw(ArgumentError("periodic-surface source lacks $key"))
    declared = String(raw[key])
    occursin(r"^[0-9a-f]{64}$", declared) || throw(ArgumentError(
        "periodic-surface declared Python hash is malformed"))
    return declared
end

function load_periodic_3d_surface_grid_v1(path::AbstractString;
        expected_design_id::Union{Nothing,AbstractString} = nothing,
        expected_genome_physics_hash::Union{Nothing,AbstractString} = nothing)
    bytes = read(path)
    artifact_sha256 = bytes2hex(sha256(bytes))
    raw = JSON3.read(String(copy(bytes)), Dict{String,Any})
    get(raw, "status", nothing) == "pass" || throw(ArgumentError(
        "periodic-surface source is not passing"))
    get(raw, "coordinate_system", nothing) == "desc_flux_coordinates_periodic_3d" ||
        throw(ArgumentError("source is not a periodic 3D flux-coordinate product"))
    get(raw, "position_components", nothing) == Any["R_m", "phi_rad", "Z_m"] ||
        throw(ArgumentError("periodic 3D position components/units are ambiguous"))
    get(raw, "vector_components", nothing) == Any["R", "phi", "Z"] ||
        throw(ArgumentError("periodic 3D vector components are ambiguous"))
    design_id = String(raw["design_id"])
    physics_hash = String(raw["genome_physics_hash"])
    expected_design_id === nothing || design_id == expected_design_id ||
        throw(ArgumentError("periodic-surface design binding mismatch"))
    expected_genome_physics_hash === nothing || physics_hash ==
        expected_genome_physics_hash || throw(ArgumentError(
        "periodic-surface Genome physics-hash binding mismatch"))
    # Python and Julia JSON encoders do not guarantee identical float spellings.
    # The loader binds the exact file SHA-256; the Python-native validator
    # independently recomputes this declared semantic hash.
    declared_hash = _validate_declared_python_hash_v1(raw, "surface_source_hash")
    rhos = Float64.(collect(raw["rho_levels"]))
    thetas = Float64.(collect(raw["theta_values_rad"]))
    zetas = Float64.(collect(raw["zeta_values_rad"]))
    length(rhos) >= 2 && length(thetas) >= 9 && length(zetas) >= 9 ||
        throw(ArgumentError("periodic 3D source has insufficient grid resolution"))
    all(diff(rhos) .> 0) && all(diff(thetas) .> 0) && all(diff(zetas) .> 0) ||
        throw(ArgumentError("periodic 3D coordinates must be strictly increasing"))
    isapprox(first(thetas), 0.0; atol = 1.0e-12) &&
        isapprox(last(thetas), 2pi; atol = 1.0e-12) || throw(ArgumentError(
        "theta grid must include both periodic endpoints"))
    nfp = Int(raw["field_periods"])
    period = Float64(raw["field_period_angle_rad"])
    nfp >= 1 && isapprox(period, 2pi / nfp; rtol = 1.0e-12) ||
        throw(ArgumentError("field-period metadata is inconsistent"))
    isapprox(first(zetas), 0.0; atol = 1.0e-12) &&
        isapprox(last(zetas), period; atol = 1.0e-12) || throw(ArgumentError(
        "zeta grid must include one complete field period"))
    dims = (length(rhos), length(zetas), length(thetas))
    expected_count = prod(dims)
    Int(raw["node_count"]) == expected_count || throw(ArgumentError(
        "periodic 3D node count does not match coordinate product"))
    vectors = Dict(
        "x_rpz" => Array{NTuple{3,Float64},3}(undef, dims),
        "b_t" => Array{NTuple{3,Float64},3}(undef, dims),
        "e_rho_m" => Array{NTuple{3,Float64},3}(undef, dims),
        "e_theta_m" => Array{NTuple{3,Float64},3}(undef, dims),
        "e_zeta_m" => Array{NTuple{3,Float64},3}(undef, dims))
    sqrt_g = Array{Float64,3}(undef, dims)
    seen = falses(dims)
    node_rho = Float64.(collect(raw["node_rho"]))
    node_theta = Float64.(collect(raw["node_theta_rad"]))
    node_zeta = Float64.(collect(raw["node_zeta_rad"]))
    arrays = Dict(name => collect(raw[name]) for name in keys(vectors))
    raw_sqrt_g = Float64.(collect(raw["sqrt_g_m3"]))
    all(length(values) == expected_count for values in
        (node_rho, node_theta, node_zeta, raw_sqrt_g, values(arrays)...)) ||
        throw(ArgumentError("periodic 3D node arrays have inconsistent lengths"))
    for node in 1:expected_count
        ir = findfirst(==(node_rho[node]), rhos)
        it = findfirst(==(node_theta[node]), thetas)
        iz = findfirst(==(node_zeta[node]), zetas)
        any(isnothing, (ir, it, iz)) && throw(ArgumentError(
            "node coordinate is absent from declared axes"))
        index = (ir::Int, iz::Int, it::Int)
        seen[index...] && throw(ArgumentError("duplicate periodic 3D node"))
        seen[index...] = true
        for (name, output) in vectors
            output[index...] = _tuple3_float_v1(arrays[name][node], name)
        end
        isfinite(raw_sqrt_g[node]) || throw(ArgumentError("sqrt(g) is non-finite"))
        sqrt_g[index...] = raw_sqrt_g[node]
    end
    all(seen) || throw(ArgumentError("periodic 3D coordinate product is incomplete"))
    return Periodic3DSurfaceGridV1(design_id, physics_hash,
        String(raw["surface_source_id"]), declared_hash, artifact_sha256,
        String(raw["source_solver_result_hash"]),
        sort!(String.(collect(raw["covered_domain_ids"]))), nfp, period,
        rhos, thetas, zetas, vectors["x_rpz"], vectors["b_t"],
        vectors["e_rho_m"], vectors["e_theta_m"], vectors["e_zeta_m"], sqrt_g)
end

_dot3_v1(a, b) = a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
_norm3_v1(a) = sqrt(_dot3_v1(a, a))
_cross3_v1(a, b) = (a[2] * b[3] - a[3] * b[2],
    a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1])
_sub3_v1(a, b) = (a[1] - b[1], a[2] - b[2], a[3] - b[3])
_scale3_v1(a, scale) = (scale * a[1], scale * a[2], scale * a[3])
_wrap_angle_v1(angle) = mod(angle + pi, 2pi) - pi

function _rpz_point_to_xyz_v1(point)
    radius, phi, z = point
    return (radius * cos(phi), radius * sin(phi), z)
end

function _rpz_vector_to_xyz_v1(vector, phi)
    radial, toroidal, z = vector
    return (radial * cos(phi) - toroidal * sin(phi),
        radial * sin(phi) + toroidal * cos(phi), z)
end

function _trapezoid_surface_integral_v1(values::Matrix{Float64},
        zetas::Vector{Float64}, thetas::Vector{Float64})
    size(values) == (length(zetas), length(thetas)) || throw(ArgumentError(
        "surface-integral array has incompatible dimensions"))
    total = 0.0
    for iz in 1:(length(zetas) - 1), it in 1:(length(thetas) - 1)
        cell_mean = (values[iz, it] + values[iz + 1, it] +
            values[iz, it + 1] + values[iz + 1, it + 1]) / 4
        total += cell_mean * (zetas[iz + 1] - zetas[iz]) *
            (thetas[it + 1] - thetas[it])
    end
    return total
end

function _periodic_surface_record_to_dict_v1(item::Periodic3DSurfaceRecordV1)
    return Dict{String,Any}(
        "rho" => item.rho,
        "maximum_theta_spatial_seam_error_m" => item.maximum_theta_spatial_seam_error_m,
        "maximum_theta_angular_seam_error_rad" => item.maximum_theta_angular_seam_error_rad,
        "maximum_zeta_spatial_seam_error_m" => item.maximum_zeta_spatial_seam_error_m,
        "maximum_zeta_angular_seam_error_rad" => item.maximum_zeta_angular_seam_error_rad,
        "maximum_tangency_residual" => item.maximum_tangency_residual,
        "minimum_signed_jacobian_m3" => item.minimum_signed_jacobian_m3,
        "maximum_jacobian_relative_error" => item.maximum_jacobian_relative_error,
        "estimated_surface_area_m2" => item.estimated_surface_area_m2,
        "mean_major_radius_m" => item.mean_major_radius_m,
        "status" => String(item.status))
end

function _periodic_surface_payload_v1(item::Periodic3DSurfaceDataProductV1)
    return Dict{String,Any}(
        "schema_version" => item.schema_version,
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "surface_source_id" => item.surface_source_id,
        "surface_source_hash" => item.surface_source_hash,
        "source_kind" => String(item.source_kind),
        "candidate_binding_verified" => item.candidate_binding_verified,
        "resolution_id" => item.resolution_id,
        "resolution_stride" => item.resolution_stride,
        "covered_domain_ids" => item.covered_domain_ids,
        "config" => Dict{String,Any}(
            "maximum_spatial_seam_error_m" => item.config.maximum_spatial_seam_error_m,
            "maximum_angular_seam_error_rad" => item.config.maximum_angular_seam_error_rad,
            "maximum_tangency_residual" => item.config.maximum_tangency_residual,
            "minimum_signed_jacobian_m3" => item.config.minimum_signed_jacobian_m3,
            "maximum_jacobian_relative_error" => item.config.maximum_jacobian_relative_error,
            "minimum_normal_nesting_gap_m" => item.config.minimum_normal_nesting_gap_m),
        "surfaces" => [_periodic_surface_record_to_dict_v1(surface)
            for surface in item.surfaces],
        "minimum_observed_normal_nesting_gap_m" =>
            item.minimum_observed_normal_nesting_gap_m,
        "status" => String(item.status),
        "c1_support_authorized" => item.c1_support_authorized,
        "evidence_tasks" => item.evidence_tasks)
end

function analyze_periodic_3d_surfaces_v1(grid::Periodic3DSurfaceGridV1,
        config::Periodic3DSurfaceConfigV1; resolution_id::AbstractString,
        resolution_stride::Integer, source_kind::Symbol,
        candidate_binding_verified::Bool)
    source_kind in _FIELD_TOPOLOGY_SOURCE_KINDS_V1 || throw(ArgumentError(
        "unknown periodic-surface source kind: $source_kind"))
    source_kind == :manufactured_control && candidate_binding_verified &&
        throw(ArgumentError("manufactured periodic-surface controls cannot claim binding"))
    stride = Int(resolution_stride)
    theta_indices = _strided_axis_indices_v1(length(grid.theta_values_rad), stride)
    zeta_indices = _strided_axis_indices_v1(length(grid.zeta_values_rad), stride)
    length(theta_indices) >= 5 && length(zeta_indices) >= 5 || throw(ArgumentError(
        "strided periodic-surface grid is too sparse"))
    thetas, zetas = grid.theta_values_rad[theta_indices],
        grid.zeta_values_rad[zeta_indices]
    surfaces = Periodic3DSurfaceRecordV1[]
    normals = Array{NTuple{3,Float64},3}(undef,
        length(grid.rho_levels), length(zeta_indices), length(theta_indices))
    for ir in eachindex(grid.rho_levels)
        theta_spatial = Float64[]
        theta_angular = Float64[]
        zeta_spatial = Float64[]
        zeta_angular = Float64[]
        tangencies = Float64[]
        signed_jacobians = Float64[]
        jacobian_errors = Float64[]
        normal_norms = zeros(length(zeta_indices), length(theta_indices))
        radii = Float64[]
        for (kz, iz) in enumerate(zeta_indices), (kt, it) in enumerate(theta_indices)
            point = grid.x_rpz_m[ir, iz, it]
            field = grid.b_rpz_t[ir, iz, it]
            erho = grid.e_rho_rpz_m[ir, iz, it]
            normal = _cross3_v1(grid.e_theta_rpz_m[ir, iz, it],
                grid.e_zeta_rpz_m[ir, iz, it])
            normals[ir, kz, kt] = normal
            normal_norm, field_norm = _norm3_v1(normal), _norm3_v1(field)
            normal_norm > 0 && field_norm > 0 || throw(ArgumentError(
                "periodic surface contains a null field or degenerate tangent basis"))
            push!(tangencies, abs(_dot3_v1(field, normal)) /
                (field_norm * normal_norm))
            jacobian = _dot3_v1(erho, normal)
            push!(signed_jacobians, jacobian)
            reference = grid.sqrt_g_m3[ir, iz, it]
            push!(jacobian_errors, abs(jacobian - reference) /
                max(abs(reference), eps(Float64)))
            normal_norms[kz, kt] = normal_norm
            kz < length(zeta_indices) && kt < length(theta_indices) &&
                push!(radii, point[1])
        end
        for iz in zeta_indices
            initial = grid.x_rpz_m[ir, iz, first(theta_indices)]
            terminal = grid.x_rpz_m[ir, iz, last(theta_indices)]
            push!(theta_spatial, hypot(terminal[1] - initial[1],
                terminal[3] - initial[3]))
            push!(theta_angular, abs(_wrap_angle_v1(terminal[2] - initial[2])))
        end
        for it in theta_indices
            initial = grid.x_rpz_m[ir, first(zeta_indices), it]
            terminal = grid.x_rpz_m[ir, last(zeta_indices), it]
            push!(zeta_spatial, hypot(terminal[1] - initial[1],
                terminal[3] - initial[3]))
            push!(zeta_angular, abs(_wrap_angle_v1(
                terminal[2] - initial[2] - grid.field_period_angle_rad)))
        end
        diagnostics = (maximum(theta_spatial), maximum(theta_angular),
            maximum(zeta_spatial), maximum(zeta_angular), maximum(tangencies),
            minimum(signed_jacobians), maximum(jacobian_errors))
        passed = diagnostics[1] <= config.maximum_spatial_seam_error_m &&
            diagnostics[2] <= config.maximum_angular_seam_error_rad &&
            diagnostics[3] <= config.maximum_spatial_seam_error_m &&
            diagnostics[4] <= config.maximum_angular_seam_error_rad &&
            diagnostics[5] <= config.maximum_tangency_residual &&
            diagnostics[6] >= config.minimum_signed_jacobian_m3 &&
            diagnostics[7] <= config.maximum_jacobian_relative_error
        area = grid.field_periods * _trapezoid_surface_integral_v1(
            normal_norms, zetas, thetas)
        push!(surfaces, Periodic3DSurfaceRecordV1(grid.rho_levels[ir],
            diagnostics..., area, sum(radii) / length(radii),
            passed ? :pass : :unknown))
    end
    nesting_gaps = Float64[]
    for ir in 1:(length(grid.rho_levels) - 1),
            (kz, iz) in enumerate(zeta_indices), (kt, it) in enumerate(theta_indices)
        inner = grid.x_rpz_m[ir, iz, it]
        outer = grid.x_rpz_m[ir + 1, iz, it]
        delta = _sub3_v1(_rpz_point_to_xyz_v1(outer),
            _rpz_point_to_xyz_v1(inner))
        normal = _rpz_vector_to_xyz_v1(normals[ir, kz, kt], inner[2])
        erho = _rpz_vector_to_xyz_v1(grid.e_rho_rpz_m[ir, iz, it], inner[2])
        oriented = _dot3_v1(erho, normal) >= 0 ? normal : _scale3_v1(normal, -1)
        push!(nesting_gaps, _dot3_v1(delta, oriented) / _norm3_v1(oriented))
    end
    minimum_gap = isempty(nesting_gaps) ? nothing : minimum(nesting_gaps)
    nested = minimum_gap !== nothing &&
        minimum_gap >= config.minimum_normal_nesting_gap_m
    status = all(surface.status == :pass for surface in surfaces) && nested ?
        :pass : :unknown
    authorized = status == :pass && source_kind == :candidate_bound_solver_field &&
        candidate_binding_verified
    tasks = String[]
    all(surface.maximum_theta_spatial_seam_error_m <=
        config.maximum_spatial_seam_error_m &&
        surface.maximum_theta_angular_seam_error_rad <=
            config.maximum_angular_seam_error_rad &&
        surface.maximum_zeta_spatial_seam_error_m <=
            config.maximum_spatial_seam_error_m &&
        surface.maximum_zeta_angular_seam_error_rad <=
            config.maximum_angular_seam_error_rad for surface in surfaces) ||
        push!(tasks, "repair theta/field-period seam closure")
    all(surface.maximum_tangency_residual <= config.maximum_tangency_residual
        for surface in surfaces) || push!(tasks,
        "reduce field-to-surface-normal residual")
    all(surface.minimum_signed_jacobian_m3 >= config.minimum_signed_jacobian_m3 &&
        surface.maximum_jacobian_relative_error <=
            config.maximum_jacobian_relative_error for surface in surfaces) ||
        push!(tasks, "repair singular, inverted, or inconsistent flux coordinates")
    nested || push!(tasks, "establish positive normal separation between radial surfaces")
    placeholder = Periodic3DSurfaceDataProductV1("1.0.0", grid.design_id,
        grid.genome_physics_hash, grid.surface_source_id, grid.artifact_sha256,
        source_kind, candidate_binding_verified, String(resolution_id), stride,
        grid.covered_domain_ids, config, surfaces, minimum_gap, status,
        authorized, sort!(unique(tasks)), "")
    return Periodic3DSurfaceDataProductV1(placeholder.schema_version,
        placeholder.design_id, placeholder.genome_physics_hash,
        placeholder.surface_source_id, placeholder.surface_source_hash,
        placeholder.source_kind, placeholder.candidate_binding_verified,
        placeholder.resolution_id, placeholder.resolution_stride,
        placeholder.covered_domain_ids, placeholder.config, placeholder.surfaces,
        placeholder.minimum_observed_normal_nesting_gap_m, placeholder.status,
        placeholder.c1_support_authorized, placeholder.evidence_tasks,
        canonical_hash(_periodic_surface_payload_v1(placeholder)))
end

function periodic_3d_surface_data_product_to_dict_v1(
        item::Periodic3DSurfaceDataProductV1)
    payload = _periodic_surface_payload_v1(item)
    payload["product_hash"] = item.product_hash
    payload["promotion_authorized"] = false
    return payload
end

function compare_periodic_3d_surface_resolutions_v1(
        coarse::Periodic3DSurfaceDataProductV1,
        fine::Periodic3DSurfaceDataProductV1;
        contract::Periodic3DSurfaceConvergenceContractV1 =
            Periodic3DSurfaceConvergenceContractV1())
    comparable = length(coarse.surfaces) == length(fine.surfaces) &&
        [surface.rho for surface in coarse.surfaces] ==
            [surface.rho for surface in fine.surfaces]
    area_differences = comparable ? [_relative_difference_v1(
        coarse.surfaces[index].estimated_surface_area_m2,
        fine.surfaces[index].estimated_surface_area_m2)
        for index in eachindex(coarse.surfaces)] : Float64[]
    radius_differences = comparable ? [_relative_difference_v1(
        coarse.surfaces[index].mean_major_radius_m,
        fine.surfaces[index].mean_major_radius_m)
        for index in eachindex(coarse.surfaces)] : Float64[]
    maximum_area_difference = isempty(area_differences) ? 0.0 :
        maximum(area_differences)
    maximum_radius_difference = isempty(radius_differences) ? 0.0 :
        maximum(radius_differences)
    checks = Dict{String,Bool}(
        "same_design" => coarse.design_id == fine.design_id,
        "same_genome_physics_hash" => coarse.genome_physics_hash ==
            fine.genome_physics_hash,
        "same_surface_source" => coarse.surface_source_id == fine.surface_source_id &&
            coarse.surface_source_hash == fine.surface_source_hash &&
            coarse.source_kind == fine.source_kind,
        "same_covered_domains" => coarse.covered_domain_ids == fine.covered_domain_ids,
        "same_rho_levels" => comparable,
        "distinct_resolution_ids" => coarse.resolution_id != fine.resolution_id,
        "resolution_refinement" => coarse.resolution_stride /
            fine.resolution_stride >= contract.minimum_resolution_refinement_ratio,
        "source_products_pass" => coarse.status == :pass && fine.status == :pass,
        "surface_area_converged" => comparable && maximum_area_difference <=
            contract.maximum_surface_area_relative_difference,
        "mean_major_radius_converged" => comparable && maximum_radius_difference <=
            contract.maximum_mean_major_radius_relative_difference)
    status = all(values(checks)) ? :pass : :unknown
    authorized = status == :pass && coarse.c1_support_authorized &&
        fine.c1_support_authorized
    diagnostics = Dict{String,Float64}(
        "resolution_refinement_ratio" => coarse.resolution_stride /
            fine.resolution_stride,
        "maximum_surface_area_relative_difference" => maximum_area_difference,
        "maximum_mean_major_radius_relative_difference" => maximum_radius_difference,
        "coarse_minimum_normal_nesting_gap_m" => something(
            coarse.minimum_observed_normal_nesting_gap_m, 0.0),
        "fine_minimum_normal_nesting_gap_m" => something(
            fine.minimum_observed_normal_nesting_gap_m, 0.0))
    tasks = sort!(String["repair periodic 3D surface convergence check: $id"
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
    return Periodic3DSurfaceConvergenceResultV1(coarse.design_id,
        coarse.genome_physics_hash, coarse.product_hash, fine.product_hash,
        fine.covered_domain_ids, status, checks, diagnostics, authorized,
        tasks, canonical_hash(payload))
end

function periodic_3d_surface_convergence_to_dict_v1(
        item::Periodic3DSurfaceConvergenceResultV1)
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

"Candidate-bound periodic 3D surface support; not a complete field-line topology proof."
function periodic_3d_surface_evidence_bundle_v1(
        result::Periodic3DSurfaceConvergenceResultV1; fidelity::Integer = 1)
    authorized = result.c1_support_authorized
    status = authorized ? :pass : :unknown
    warnings = authorized ? String[
        "periodic coordinate-surface support does not independently prove field-line closure, islands, stochastic layers, exhaust, or promotion"] :
        vcat(["periodic 3D surface convergence lacks candidate-bound support authority"],
            result.evidence_tasks)
    run_hash = canonical_hash(Dict{String,Any}(
        "evaluator" => "periodic_3d_surface_descriptor_v1",
        "convergence_hash" => result.convergence_hash,
        "status" => String(status)))
    metric = MetricResult("periodic_3d_nested_surface_descriptor_resolved",
        authorized ? true : nothing; fidelity = Int(fidelity), status = status,
        applicability = "Periodic 3D nested flux-coordinate surfaces with seam, B-normal tangency, coordinate-Jacobian, normal-nesting, and resolution audits.",
        constraints_checked = sort!(collect(keys(result.checks))),
        solver_name = "periodic_3d_surface_descriptor_v1", solver_version = "1.0.0",
        input_hash = result.genome_physics_hash, run_hash = run_hash,
        source_basis = [result.coarse_product_hash, result.fine_product_hash],
        warnings = warnings, residuals = copy(result.diagnostics))
    bundle_hash = canonical_hash(Dict{String,Any}(
        "metric_run_hash" => run_hash, "convergence_hash" => result.convergence_hash))
    return EvaluationBundle("periodic_3d_surface_descriptor_v1", result.design_id,
        "topology_independent", Int(fidelity), status, [metric], warnings,
        result.genome_physics_hash, bundle_hash,
        authorized ? "C1_support_periodic_3d_surface_only" :
            "C0_periodic_3d_surface_unknown")
end
