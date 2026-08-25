const _FIELD_TOPOLOGY_SOURCE_KINDS_V1 = Set((
    :manufactured_control,
    :candidate_bound_solver_field,
    :imported_unverified_field,
))

struct CylindricalFieldGridV1
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
end

function _matrix_from_json_rows_v1(raw, name::String, nz::Int, nr::Int)
    rows = [Float64.(collect(row)) for row in raw]
    length(rows) == nz || throw(ArgumentError("$name axial dimension mismatch"))
    all(length(row) == nr for row in rows) || throw(ArgumentError(
        "$name radial dimension mismatch"))
    matrix = Matrix{Float64}(undef, nz, nr)
    for iz in 1:nz, ir in 1:nr
        matrix[iz, ir] = rows[iz][ir]
    end
    all(isfinite, matrix) || throw(ArgumentError("$name contains non-finite values"))
    return matrix
end

function load_cylindrical_field_grid_v1(path::AbstractString;
        expected_design_id::Union{Nothing,AbstractString} = nothing,
        expected_genome_physics_hash::Union{Nothing,AbstractString} = nothing)
    bytes = read(path)
    artifact_sha256 = bytes2hex(sha256(bytes))
    raw = JSON3.read(String(copy(bytes)), Dict{String,Any})
    get(raw, "status", nothing) == "pass" || throw(ArgumentError(
        "field grid artifact is not a passing solver product"))
    get(raw, "coordinate_system", nothing) == "cylindrical_axisymmetric" ||
        throw(ArgumentError("field grid is not cylindrical axisymmetric"))
    design_id = String(raw["design_id"])
    physics_hash = String(raw["genome_physics_hash"])
    expected_design_id === nothing || design_id == expected_design_id ||
        throw(ArgumentError("field grid design binding mismatch"))
    expected_genome_physics_hash === nothing || physics_hash ==
        expected_genome_physics_hash || throw(ArgumentError(
        "field grid Genome physics-hash binding mismatch"))
    radial = Float64.(collect(raw["radial_grid_m"]))
    axial = Float64.(collect(raw["axial_grid_m"]))
    length(radial) >= 2 && length(axial) >= 2 || throw(ArgumentError(
        "field grid needs at least two points on each axis"))
    all(diff(radial) .> 0) && all(diff(axial) .> 0) || throw(ArgumentError(
        "field grid axes must be strictly increasing"))
    nr, nz = length(radial), length(axial)
    br = _matrix_from_json_rows_v1(raw["br_t"], "br_t", nz, nr)
    bphi = _matrix_from_json_rows_v1(raw["bphi_t"], "bphi_t", nz, nr)
    bz = _matrix_from_json_rows_v1(raw["bz_t"], "bz_t", nz, nr)
    magnitude = sqrt.(br .^ 2 .+ bphi .^ 2 .+ bz .^ 2)
    minimum(magnitude) > 0 || throw(ArgumentError("field grid contains a magnetic null"))
    return CylindricalFieldGridV1(design_id, physics_hash,
        String(raw["field_source_id"]), String(raw["field_source_hash"]),
        artifact_sha256, sort!(String.(collect(raw["covered_domain_ids"]))),
        radial, axial, br, bphi, bz)
end

function _bilinear_field_value_v1(grid::CylindricalFieldGridV1,
        matrix::Matrix{Float64}, radius::Float64, axial::Float64)
    (first(grid.radial_grid_m) <= radius <= last(grid.radial_grid_m) &&
        first(grid.axial_grid_m) <= axial <= last(grid.axial_grid_m)) || return NaN
    ir = clamp(searchsortedlast(grid.radial_grid_m, radius), 1,
        length(grid.radial_grid_m) - 1)
    iz = clamp(searchsortedlast(grid.axial_grid_m, axial), 1,
        length(grid.axial_grid_m) - 1)
    r0, r1 = grid.radial_grid_m[ir], grid.radial_grid_m[ir + 1]
    z0, z1 = grid.axial_grid_m[iz], grid.axial_grid_m[iz + 1]
    tr = (radius - r0) / (r1 - r0)
    tz = (axial - z0) / (z1 - z0)
    return (1 - tr) * (1 - tz) * matrix[iz, ir] +
        tr * (1 - tz) * matrix[iz, ir + 1] +
        (1 - tr) * tz * matrix[iz + 1, ir] +
        tr * tz * matrix[iz + 1, ir + 1]
end

"Return a Cartesian B(x,y,z) callback backed by an axisymmetric cylindrical grid."
function cylindrical_field_callback_v1(grid::CylindricalFieldGridV1)
    return function(point)
        x, y, axial = Float64.(collect(point))
        radius = hypot(x, y)
        br = _bilinear_field_value_v1(grid, grid.br_t, radius, axial)
        bphi = _bilinear_field_value_v1(grid, grid.bphi_t, radius, axial)
        bz = _bilinear_field_value_v1(grid, grid.bz_t, radius, axial)
        all(isfinite, (br, bphi, bz)) || return (NaN, NaN, NaN)
        if radius <= eps(Float64)
            return (0.0, 0.0, bz)
        end
        cosine, sine = x / radius, y / radius
        return (br * cosine - bphi * sine,
            br * sine + bphi * cosine, bz)
    end
end

function _ready_field_module_v1(executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1, implementation_id::String)
    statuses = Dict(item.module_id => item.status for item in program.modules)
    for physics_module in executable.modules
        physics_module.role == :field || continue
        get(statuses, physics_module.id, :invalid) == :ready_for_execution || continue
        any(backend -> backend.status == :available &&
            backend.capability_id == "maxwell_magnetostatic_field_v1" &&
            backend.implementation_id == implementation_id,
            physics_module.backend_requirements) && return physics_module
    end
    return nothing
end

"Bind a passing spatial field grid to the exact executable field module without family routing."
function field_grid_evidence_bundle_v1(executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1,
        grid::CylindricalFieldGridV1,
        field_implementation_id::AbstractString;
        source_kind::Symbol,
        candidate_binding_verified::Bool,
        fidelity::Integer = 1)
    source_kind in _FIELD_TOPOLOGY_SOURCE_KINDS_V1 || throw(ArgumentError(
        "unknown field-grid source kind: $source_kind"))
    source_kind == :manufactured_control && candidate_binding_verified &&
        throw(ArgumentError("manufactured field grids cannot claim candidate binding"))
    grid.design_id == executable.base_genome.design_id || throw(ArgumentError(
        "field grid design does not match executable Genome"))
    grid.genome_physics_hash == executable.base_genome.physics_hash ||
        throw(ArgumentError(
            "field grid is not bound to the executable Genome physics hash"))
    implementation_id = String(field_implementation_id)
    ready_module = _ready_field_module_v1(executable, program, implementation_id)
    field_state_domains = ready_module === nothing ? String[] : sort!(unique(vcat(
        [state.domain_ids for state in ready_module.state_variables
            if state.id == "magnetic_field"]...)))
    domain_coverage_complete = ready_module !== nothing &&
        !isempty(field_state_domains) && all(id -> id in grid.covered_domain_ids,
            field_state_domains)
    authorized = source_kind == :candidate_bound_solver_field &&
        candidate_binding_verified && ready_module !== nothing &&
        domain_coverage_complete
    status = authorized ? :pass : :unknown
    warnings = String[]
    source_kind == :candidate_bound_solver_field || push!(warnings,
        "field grid is not a candidate-bound solver field")
    candidate_binding_verified || push!(warnings,
        "field-grid candidate binding was not verified")
    ready_module === nothing && push!(warnings,
        "no ready executable field module declares this exact field implementation")
    ready_module !== nothing && !domain_coverage_complete && push!(warnings,
        "field grid does not cover every magnetic-field state domain")
    metric_hash = canonical_hash(Dict{String,Any}(
        "evaluator" => "field_grid_evidence_bridge_v1",
        "program_hash" => program.program_hash,
        "field_grid_artifact_sha256" => grid.artifact_sha256,
        "field_implementation_id" => implementation_id,
        "field_state_domain_ids" => field_state_domains,
        "status" => String(status)))
    metric = MetricResult("field_solution_converged",
        authorized ? true : nothing; fidelity = Int(fidelity),
        applicability = "Candidate-bound finite total-field grid covering every spatial magnetic-field state domain of one ready executable field module.",
        status = status,
        constraints_checked = ["candidate_binding", "field_module_ready",
            "magnetic_field_state_domain_coverage", "finite_nonzero_field_grid"],
        solver_name = "field_grid_evidence_bridge_v1", solver_version = "1.0.0",
        input_hash = executable.base_genome.physics_hash, run_hash = metric_hash,
        source_basis = [implementation_id, grid.artifact_sha256,
            grid.declared_field_source_hash], warnings = warnings)
    bundle_hash = canonical_hash(Dict{String,Any}(
        "metric_run_hash" => metric.run_hash,
        "program_hash" => program.program_hash))
    return EvaluationBundle("field_grid_evidence_bridge_v1", grid.design_id,
        executable.base_genome.family, Int(fidelity), status, [metric], warnings,
        executable.base_genome.physics_hash, bundle_hash,
        authorized ? "C1_support_candidate_bound_field_solution" :
            "C0_field_solution_unknown")
end

struct FieldLineSeedV1
    id::String
    point_m::NTuple{3,Float64}
    region_id::String

    function FieldLineSeedV1(id::AbstractString, point, region_id::AbstractString)
        values = Tuple(Float64.(collect(point)))
        length(values) == 3 || throw(ArgumentError("field-line seed must be three-dimensional"))
        all(isfinite, values) || throw(ArgumentError("field-line seed coordinates must be finite"))
        isempty(id) && throw(ArgumentError("field-line seed id cannot be empty"))
        return new(String(id), (values[1], values[2], values[3]), String(region_id))
    end
end

abstract type AbstractFieldLineDomainV1 end

struct AxisAlignedFieldDomainV1 <: AbstractFieldLineDomainV1
    id::String
    lower_m::NTuple{3,Float64}
    upper_m::NTuple{3,Float64}
    boundary_ids::NTuple{6,String}

    function AxisAlignedFieldDomainV1(id::AbstractString, lower, upper;
            boundary_ids = ("x_min", "x_max", "y_min", "y_max", "z_min", "z_max"))
        lo = Tuple(Float64.(collect(lower)))
        hi = Tuple(Float64.(collect(upper)))
        labels = Tuple(String.(collect(boundary_ids)))
        length(lo) == 3 && length(hi) == 3 || throw(ArgumentError(
            "field-line domain bounds must be three-dimensional"))
        length(labels) == 6 || throw(ArgumentError("field-line domain needs six boundary ids"))
        all(isfinite, lo) && all(isfinite, hi) || throw(ArgumentError(
            "field-line domain bounds must be finite"))
        all(hi[index] > lo[index] for index in 1:3) || throw(ArgumentError(
            "field-line domain upper bounds must exceed lower bounds"))
        return new(String(id), (lo[1], lo[2], lo[3]), (hi[1], hi[2], hi[3]),
            (labels[1], labels[2], labels[3], labels[4], labels[5], labels[6]))
    end
end

"""
Axisymmetric material boundary embedded in a larger numerical field box.

The polygon is interpreted in `(R, Z)` and revolved about the Z axis.  It is an
absorbing trace boundary only; this type does not imply a conducting-wall field
response or any engineering/heat-flux model.
"""
struct AxisymmetricPolygonFieldDomainV1 <: AbstractFieldLineDomainV1
    id::String
    wall_r_m::Vector{Float64}
    wall_z_m::Vector{Float64}
    numerical_lower_m::NTuple{3,Float64}
    numerical_upper_m::NTuple{3,Float64}
    material_boundary_id::String
    numerical_boundary_ids::NTuple{6,String}
    wall_geometry_source_id::String
    wall_geometry_hash::String

    function AxisymmetricPolygonFieldDomainV1(id::AbstractString, wall_r, wall_z,
            numerical_lower, numerical_upper;
            material_boundary_id::AbstractString = "material_wall",
            numerical_boundary_ids = ("x_min", "x_max", "y_min", "y_max",
                "z_min", "z_max"),
            wall_geometry_source_id::AbstractString,
            wall_geometry_hash::AbstractString)
        radii = Float64.(collect(wall_r))
        axial = Float64.(collect(wall_z))
        lo = Tuple(Float64.(collect(numerical_lower)))
        hi = Tuple(Float64.(collect(numerical_upper)))
        labels = Tuple(String.(collect(numerical_boundary_ids)))
        isempty(id) && throw(ArgumentError("field-line domain id cannot be empty"))
        length(radii) == length(axial) >= 3 || throw(ArgumentError(
            "axisymmetric wall needs at least three matched (R, Z) vertices"))
        all(isfinite, radii) && all(isfinite, axial) || throw(ArgumentError(
            "axisymmetric wall vertices must be finite"))
        all(>=(0.0), radii) || throw(ArgumentError(
            "axisymmetric wall radii must be non-negative"))
        length(Set(zip(radii, axial))) >= 3 || throw(ArgumentError(
            "axisymmetric wall needs at least three distinct vertices"))
        twice_area = sum(radii[index] * axial[index == length(radii) ? 1 : index + 1] -
            radii[index == length(radii) ? 1 : index + 1] * axial[index]
            for index in eachindex(radii))
        abs(twice_area) > 64eps(Float64) || throw(ArgumentError(
            "axisymmetric wall polygon area must be nonzero"))
        length(lo) == 3 && length(hi) == 3 || throw(ArgumentError(
            "numerical field bounds must be three-dimensional"))
        length(labels) == 6 || throw(ArgumentError(
            "numerical field bounds need six boundary ids"))
        all(isfinite, lo) && all(isfinite, hi) || throw(ArgumentError(
            "numerical field bounds must be finite"))
        all(hi[index] > lo[index] for index in 1:3) || throw(ArgumentError(
            "numerical upper bounds must exceed lower bounds"))
        maximum_radius = maximum(radii)
        lo[1] <= -maximum_radius && hi[1] >= maximum_radius &&
            lo[2] <= -maximum_radius && hi[2] >= maximum_radius ||
            throw(ArgumentError("revolved wall radial extent exceeds numerical field box"))
        minimum(axial) >= lo[3] && maximum(axial) <= hi[3] || throw(ArgumentError(
            "wall axial extent exceeds numerical field box"))
        isempty(material_boundary_id) && throw(ArgumentError(
            "material boundary id cannot be empty"))
        isempty(wall_geometry_source_id) && throw(ArgumentError(
            "wall geometry source id cannot be empty"))
        isempty(wall_geometry_hash) && throw(ArgumentError(
            "wall geometry hash cannot be empty"))
        return new(String(id), radii, axial, (lo[1], lo[2], lo[3]),
            (hi[1], hi[2], hi[3]), String(material_boundary_id),
            (labels[1], labels[2], labels[3], labels[4], labels[5], labels[6]),
            String(wall_geometry_source_id), String(wall_geometry_hash))
    end
end

struct FieldLineTraceConfigV1
    step_length_m::Float64
    maximum_arclength_m::Float64
    minimum_recurrence_arclength_m::Float64
    recurrence_tolerance_m::Float64
    recurrence_direction_cosine_min::Float64
    field_floor_t::Float64

    function FieldLineTraceConfigV1(; step_length_m::Real,
            maximum_arclength_m::Real, minimum_recurrence_arclength_m::Real,
            recurrence_tolerance_m::Real, recurrence_direction_cosine_min::Real = 0.95,
            field_floor_t::Real = 1.0e-9)
        step_length_m > 0 || throw(ArgumentError("field-line step length must be positive"))
        maximum_arclength_m > step_length_m || throw(ArgumentError(
            "maximum arclength must exceed one step"))
        0 < minimum_recurrence_arclength_m < maximum_arclength_m || throw(ArgumentError(
            "minimum recurrence arclength must lie inside the trace interval"))
        recurrence_tolerance_m > 0 || throw(ArgumentError(
            "recurrence tolerance must be positive"))
        -1 <= recurrence_direction_cosine_min <= 1 || throw(ArgumentError(
            "recurrence direction cosine must lie in [-1, 1]"))
        field_floor_t > 0 || throw(ArgumentError("field floor must be positive"))
        return new(Float64(step_length_m), Float64(maximum_arclength_m),
            Float64(minimum_recurrence_arclength_m), Float64(recurrence_tolerance_m),
            Float64(recurrence_direction_cosine_min), Float64(field_floor_t))
    end
end

struct DirectedFieldLineTraceV1
    termination::Symbol
    arclength_m::Float64
    step_count::Int
    boundary_id::Union{Nothing,String}
    final_point_m::Union{Nothing,NTuple{3,Float64}}
    minimum_return_distance_m::Union{Nothing,Float64}
    maximum_local_error_m::Float64
    minimum_field_t::Union{Nothing,Float64}
    maximum_field_t::Union{Nothing,Float64}
end

struct FieldLineTraceV1
    seed::FieldLineSeedV1
    forward::DirectedFieldLineTraceV1
    backward::DirectedFieldLineTraceV1
    fate::Symbol
    connection_length_m::Union{Nothing,Float64}
end

struct FieldLineNeighborSeparationRecordV1
    seed_a_id::String
    seed_b_id::String
    direction::Symbol
    initial_separation_m::Float64
    final_separation_m::Union{Nothing,Float64}
    comparison_arclength_m::Union{Nothing,Float64}
    log_amplification_per_m::Union{Nothing,Float64}
    compatible_endpoint::Bool
    reason::String
end

struct FieldLineNeighborSeparationResultV1
    pair_count::Int
    directional_record_count::Int
    valid_directional_record_count::Int
    maximum_log_amplification_per_m::Union{Nothing,Float64}
    median_log_amplification_per_m::Union{Nothing,Float64}
    limit_per_m::Float64
    status::Symbol
    records::Vector{FieldLineNeighborSeparationRecordV1}
    result_hash::String
end

struct FieldTopologyDataProductV1
    schema_version::String
    design_id::String
    genome_physics_hash::String
    field_source_id::String
    field_source_hash::String
    source_kind::Symbol
    candidate_binding_verified::Bool
    resolution_id::String
    covered_domain_ids::Vector{String}
    domain::AbstractFieldLineDomainV1
    trace_config::FieldLineTraceConfigV1
    traces::Vector{FieldLineTraceV1}
    auxiliary_diagnostic_statuses::Dict{String,Symbol}
    auxiliary_diagnostic_values::Dict{String,Float64}
    status::Symbol
    topology_class::Symbol
    closed_fraction::Float64
    open_fraction::Float64
    unresolved_fraction::Float64
    median_connection_length_m::Union{Nothing,Float64}
    maximum_local_error_m::Float64
    evidence_tasks::Vector{String}
    product_hash::String
end

struct FieldTopologyConvergenceContractV1
    minimum_seed_count::Int
    minimum_step_refinement_ratio::Float64
    minimum_fate_agreement_fraction::Float64
    maximum_fraction_difference::Float64
    maximum_connection_length_relative_difference::Float64
    maximum_fine_to_coarse_local_error_ratio::Float64
    maximum_neighbor_log_amplification_absolute_difference_per_m::Float64

    function FieldTopologyConvergenceContractV1(; minimum_seed_count::Integer = 6,
            minimum_step_refinement_ratio::Real = 1.5,
            minimum_fate_agreement_fraction::Real = 0.95,
            maximum_fraction_difference::Real = 0.05,
            maximum_connection_length_relative_difference::Real = 0.05,
            maximum_fine_to_coarse_local_error_ratio::Real = 1.05,
            maximum_neighbor_log_amplification_absolute_difference_per_m::Real = 0.05)
        minimum_seed_count >= 2 || throw(ArgumentError("at least two topology seeds are required"))
        minimum_step_refinement_ratio > 1 || throw(ArgumentError(
            "step refinement ratio must exceed one"))
        0 <= minimum_fate_agreement_fraction <= 1 || throw(ArgumentError(
            "fate agreement threshold must lie in [0, 1]"))
        maximum_fraction_difference >= 0 || throw(ArgumentError(
            "fraction tolerance must be non-negative"))
        maximum_connection_length_relative_difference >= 0 || throw(ArgumentError(
            "connection-length tolerance must be non-negative"))
        maximum_fine_to_coarse_local_error_ratio >= 0 || throw(ArgumentError(
            "local-error ratio must be non-negative"))
        maximum_neighbor_log_amplification_absolute_difference_per_m >= 0 ||
            throw(ArgumentError("neighbor-amplification tolerance must be non-negative"))
        return new(Int(minimum_seed_count), Float64(minimum_step_refinement_ratio),
            Float64(minimum_fate_agreement_fraction), Float64(maximum_fraction_difference),
            Float64(maximum_connection_length_relative_difference),
            Float64(maximum_fine_to_coarse_local_error_ratio),
            Float64(maximum_neighbor_log_amplification_absolute_difference_per_m))
    end
end

struct FieldTopologyConvergenceResultV1
    design_id::String
    genome_physics_hash::String
    coarse_product_hash::String
    fine_product_hash::String
    covered_domain_ids::Vector{String}
    status::Symbol
    topology_class::Symbol
    checks::Dict{String,Bool}
    diagnostics::Dict{String,Float64}
    c1_evidence_authorized::Bool
    evidence_tasks::Vector{String}
    convergence_hash::String
end

_point_add_v1(a, b) = (a[1] + b[1], a[2] + b[2], a[3] + b[3])
_point_scale_v1(a, scale) = (a[1] * scale, a[2] * scale, a[3] * scale)
_point_distance_v1(a, b) = sqrt(sum((a[index] - b[index])^2 for index in 1:3))
_point_dot_v1(a, b) = sum(a[index] * b[index] for index in 1:3)

function _field_vector_v1(field, point, floor_t::Float64)
    raw = field(point)
    values = Tuple(Float64.(collect(raw)))
    length(values) == 3 || throw(ArgumentError("magnetic-field callback must return three values"))
    all(isfinite, values) || return nothing
    magnitude = sqrt(sum(value^2 for value in values))
    magnitude >= floor_t || return nothing
    return (values = (values[1], values[2], values[3]), magnitude = magnitude,
        unit = (values[1] / magnitude, values[2] / magnitude, values[3] / magnitude))
end

function _inside_domain_v1(domain::AxisAlignedFieldDomainV1, point)
    return all(domain.lower_m[index] <= point[index] <= domain.upper_m[index]
        for index in 1:3)
end

function _inside_numerical_bounds_v1(domain::AxisymmetricPolygonFieldDomainV1, point)
    return all(domain.numerical_lower_m[index] <= point[index] <=
        domain.numerical_upper_m[index] for index in 1:3)
end

function _point_on_segment_rz_v1(radius::Float64, axial::Float64,
        r1::Float64, z1::Float64, r2::Float64, z2::Float64)
    scale = max(abs(radius), abs(axial), abs(r1), abs(z1), abs(r2), abs(z2), 1.0)
    tolerance = 64eps(Float64) * scale
    cross = (radius - r1) * (z2 - z1) - (axial - z1) * (r2 - r1)
    abs(cross) <= tolerance || return false
    return min(r1, r2) - tolerance <= radius <= max(r1, r2) + tolerance &&
        min(z1, z2) - tolerance <= axial <= max(z1, z2) + tolerance
end

function _inside_wall_polygon_v1(domain::AxisymmetricPolygonFieldDomainV1, point)
    radius, axial = hypot(point[1], point[2]), Float64(point[3])
    inside = false
    count_vertices = length(domain.wall_r_m)
    previous = count_vertices
    for current in 1:count_vertices
        r1, z1 = domain.wall_r_m[previous], domain.wall_z_m[previous]
        r2, z2 = domain.wall_r_m[current], domain.wall_z_m[current]
        _point_on_segment_rz_v1(radius, axial, r1, z1, r2, z2) && return true
        crosses = (z1 > axial) != (z2 > axial)
        if crosses
            intersection_r = r1 + (axial - z1) * (r2 - r1) / (z2 - z1)
            radius < intersection_r && (inside = !inside)
        end
        previous = current
    end
    return inside
end

function _inside_domain_v1(domain::AxisymmetricPolygonFieldDomainV1, point)
    return _inside_numerical_bounds_v1(domain, point) &&
        _inside_wall_polygon_v1(domain, point)
end

function _boundary_id_v1(domain::AxisAlignedFieldDomainV1, point)
    for index in 1:3
        point[index] < domain.lower_m[index] && return domain.boundary_ids[2index - 1]
        point[index] > domain.upper_m[index] && return domain.boundary_ids[2index]
    end
    return nothing
end

function _boundary_id_v1(domain::AxisymmetricPolygonFieldDomainV1, point)
    for index in 1:3
        point[index] < domain.numerical_lower_m[index] &&
            return domain.numerical_boundary_ids[2index - 1]
        point[index] > domain.numerical_upper_m[index] &&
            return domain.numerical_boundary_ids[2index]
    end
    _inside_wall_polygon_v1(domain, point) && return nothing
    return domain.material_boundary_id
end

function _rk4_endpoint_v1(field, point, signed_step::Float64, floor_t::Float64)
    direction = sign(signed_step)
    h = abs(signed_step)
    k1 = _field_vector_v1(field, point, floor_t)
    k1 === nothing && return nothing
    p2 = _point_add_v1(point, _point_scale_v1(k1.unit, direction * h / 2))
    k2 = _field_vector_v1(field, p2, floor_t)
    k2 === nothing && return nothing
    p3 = _point_add_v1(point, _point_scale_v1(k2.unit, direction * h / 2))
    k3 = _field_vector_v1(field, p3, floor_t)
    k3 === nothing && return nothing
    p4 = _point_add_v1(point, _point_scale_v1(k3.unit, direction * h))
    k4 = _field_vector_v1(field, p4, floor_t)
    k4 === nothing && return nothing
    weighted = (
        k1.unit[1] + 2k2.unit[1] + 2k3.unit[1] + k4.unit[1],
        k1.unit[2] + 2k2.unit[2] + 2k3.unit[2] + k4.unit[2],
        k1.unit[3] + 2k2.unit[3] + 2k3.unit[3] + k4.unit[3])
    endpoint = _point_add_v1(point, _point_scale_v1(weighted, direction * h / 6))
    return endpoint
end

function _trace_direction_v1(field, seed::FieldLineSeedV1,
        domain::AbstractFieldLineDomainV1, config::FieldLineTraceConfigV1,
        direction::Int)
    _inside_domain_v1(domain, seed.point_m) || return DirectedFieldLineTraceV1(
        :invalid_seed, 0.0, 0, _boundary_id_v1(domain, seed.point_m),
        seed.point_m, nothing, 0.0, nothing, nothing)
    initial = _field_vector_v1(field, seed.point_m, config.field_floor_t)
    initial === nothing && return DirectedFieldLineTraceV1(
        :field_null, 0.0, 0, nothing, seed.point_m, nothing, 0.0, nothing, nothing)
    point = seed.point_m
    arclength = 0.0
    steps = 0
    minimum_return = Inf
    maximum_local_error = 0.0
    minimum_field = initial.magnitude
    maximum_field = initial.magnitude
    while arclength < config.maximum_arclength_m
        h = min(config.step_length_m, config.maximum_arclength_m - arclength)
        full = _rk4_endpoint_v1(field, point, direction * h, config.field_floor_t)
        half = _rk4_endpoint_v1(field, point, direction * h / 2, config.field_floor_t)
        half === nothing && return DirectedFieldLineTraceV1(:field_null, arclength,
            steps, nothing, point, isfinite(minimum_return) ? minimum_return : nothing,
            maximum_local_error, minimum_field, maximum_field)
        refined = _rk4_endpoint_v1(field, half, direction * h / 2, config.field_floor_t)
        (full === nothing || refined === nothing) && return DirectedFieldLineTraceV1(
            :field_null, arclength, steps, nothing,
            point, isfinite(minimum_return) ? minimum_return : nothing,
            maximum_local_error, minimum_field, maximum_field)
        maximum_local_error = max(maximum_local_error, _point_distance_v1(full, refined))
        point = refined
        arclength += h
        steps += 1
        if !_inside_domain_v1(domain, point)
            return DirectedFieldLineTraceV1(:boundary, arclength, steps,
                _boundary_id_v1(domain, point), point,
                isfinite(minimum_return) ? minimum_return : nothing,
                maximum_local_error, minimum_field, maximum_field)
        end
        state = _field_vector_v1(field, point, config.field_floor_t)
        state === nothing && return DirectedFieldLineTraceV1(:field_null, arclength,
            steps, nothing, point, isfinite(minimum_return) ? minimum_return : nothing,
            maximum_local_error, minimum_field, maximum_field)
        minimum_field = min(minimum_field, state.magnitude)
        maximum_field = max(maximum_field, state.magnitude)
        if arclength >= config.minimum_recurrence_arclength_m
            distance = _point_distance_v1(point, seed.point_m)
            minimum_return = min(minimum_return, distance)
            direction_cosine = _point_dot_v1(state.unit, initial.unit)
            if distance <= config.recurrence_tolerance_m &&
                    direction_cosine >= config.recurrence_direction_cosine_min
                return DirectedFieldLineTraceV1(:recurrence, arclength, steps,
                    nothing, point, minimum_return, maximum_local_error,
                    minimum_field, maximum_field)
            end
        end
    end
    return DirectedFieldLineTraceV1(:maximum_arclength, arclength, steps, nothing,
        point, isfinite(minimum_return) ? minimum_return : nothing,
        maximum_local_error, minimum_field, maximum_field)
end

function trace_field_line_v1(field, seed::FieldLineSeedV1,
        domain::AbstractFieldLineDomainV1, config::FieldLineTraceConfigV1)
    forward = try
        _trace_direction_v1(field, seed, domain, config, 1)
    catch
        DirectedFieldLineTraceV1(:integrator_error, 0.0, 0, nothing, nothing,
            nothing, Inf, nothing, nothing)
    end
    backward = try
        _trace_direction_v1(field, seed, domain, config, -1)
    catch
        DirectedFieldLineTraceV1(:integrator_error, 0.0, 0, nothing, nothing,
            nothing, Inf, nothing, nothing)
    end
    terminations = (forward.termination, backward.termination)
    fate = all(==(:recurrence), terminations) ? :closed :
        all(==(:boundary), terminations) ? :open :
        any(==(:boundary), terminations) ? :one_sided_open :
        all(==(:maximum_arclength), terminations) ? :bounded_unresolved : :unknown
    connection = fate == :open ? forward.arclength_m + backward.arclength_m : nothing
    return FieldLineTraceV1(seed, forward, backward, fate, connection)
end

function _neighbor_record_to_dict_v1(item::FieldLineNeighborSeparationRecordV1)
    return Dict{String,Any}(
        "seed_a_id" => item.seed_a_id, "seed_b_id" => item.seed_b_id,
        "direction" => String(item.direction),
        "initial_separation_m" => item.initial_separation_m,
        "final_separation_m" => item.final_separation_m,
        "comparison_arclength_m" => item.comparison_arclength_m,
        "log_amplification_per_m" => item.log_amplification_per_m,
        "compatible_endpoint" => item.compatible_endpoint,
        "reason" => item.reason)
end

function field_line_neighbor_separation_to_dict_v1(
        item::FieldLineNeighborSeparationResultV1)
    return Dict{String,Any}(
        "pair_count" => item.pair_count,
        "directional_record_count" => item.directional_record_count,
        "valid_directional_record_count" => item.valid_directional_record_count,
        "maximum_log_amplification_per_m" => item.maximum_log_amplification_per_m,
        "median_log_amplification_per_m" => item.median_log_amplification_per_m,
        "limit_per_m" => item.limit_per_m,
        "status" => String(item.status),
        "records" => [_neighbor_record_to_dict_v1(record) for record in item.records],
        "result_hash" => item.result_hash,
        "promotion_authorized" => false)
end

"Measure finite-box separation of explicitly paired neighboring field lines."
function analyze_field_line_neighbor_separation_v1(traces::Vector{FieldLineTraceV1},
        neighbor_pairs::Vector{Tuple{String,String}};
        limit_per_m::Real, separation_floor_m::Real = 1.0e-12)
    isfinite(limit_per_m) && limit_per_m >= 0 || throw(ArgumentError(
        "neighbor log-amplification limit must be finite and non-negative"))
    isfinite(separation_floor_m) && separation_floor_m > 0 || throw(ArgumentError(
        "neighbor separation floor must be finite and positive"))
    isempty(neighbor_pairs) && throw(ArgumentError(
        "neighbor-separation analysis needs at least one pair"))
    trace_by_id = Dict(trace.seed.id => trace for trace in traces)
    length(trace_by_id) == length(traces) || throw(ArgumentError(
        "field-line trace seed ids must be unique"))
    normalized_pairs = [a <= b ? (a, b) : (b, a) for (a, b) in neighbor_pairs]
    length(unique(normalized_pairs)) == length(normalized_pairs) || throw(ArgumentError(
        "neighbor pairs must be unique without regard to ordering"))
    records = FieldLineNeighborSeparationRecordV1[]
    for (seed_a_id, seed_b_id) in neighbor_pairs
        seed_a_id != seed_b_id || throw(ArgumentError(
            "neighbor pair must contain two distinct seed ids"))
        haskey(trace_by_id, seed_a_id) && haskey(trace_by_id, seed_b_id) ||
            throw(ArgumentError("neighbor pair references an unknown seed id"))
        trace_a, trace_b = trace_by_id[seed_a_id], trace_by_id[seed_b_id]
        initial = _point_distance_v1(trace_a.seed.point_m, trace_b.seed.point_m)
        initial > separation_floor_m || throw(ArgumentError(
            "neighbor pair initial separation must exceed the separation floor"))
        for direction in (:forward, :backward)
            directed_a = getfield(trace_a, direction)
            directed_b = getfield(trace_b, direction)
            endpoint_compatible = directed_a.termination == directed_b.termination &&
                ((directed_a.termination == :boundary &&
                    directed_a.boundary_id == directed_b.boundary_id &&
                    directed_a.boundary_id !== nothing) ||
                 directed_a.termination == :recurrence)
            endpoints_present = directed_a.final_point_m !== nothing &&
                directed_b.final_point_m !== nothing
            arclength = min(directed_a.arclength_m, directed_b.arclength_m)
            valid = endpoint_compatible && endpoints_present && arclength > 0
            if valid
                final = _point_distance_v1(directed_a.final_point_m,
                    directed_b.final_point_m)
                rate = max(0.0, log(max(final, Float64(separation_floor_m)) /
                    initial) / arclength)
                push!(records, FieldLineNeighborSeparationRecordV1(seed_a_id,
                    seed_b_id, direction, initial, final, arclength, rate, true,
                    "same physical termination surface"))
            else
                reason = !endpoint_compatible ? "termination or boundary mismatch" :
                    !endpoints_present ? "endpoint unavailable" :
                    "non-positive comparison arclength"
                push!(records, FieldLineNeighborSeparationRecordV1(seed_a_id,
                    seed_b_id, direction, initial, nothing, nothing, nothing,
                    false, reason))
            end
        end
    end
    valid_rates = Float64[record.log_amplification_per_m for record in records
        if record.log_amplification_per_m !== nothing]
    complete = length(valid_rates) == length(records)
    maximum_rate = isempty(valid_rates) ? nothing : maximum(valid_rates)
    median_rate = isempty(valid_rates) ? nothing : _median_v1(valid_rates)
    status = !complete ? :unknown : maximum_rate <= limit_per_m ? :pass : :fail
    payload = Dict{String,Any}(
        "pair_count" => length(neighbor_pairs),
        "directional_record_count" => length(records),
        "valid_directional_record_count" => length(valid_rates),
        "maximum_log_amplification_per_m" => maximum_rate,
        "median_log_amplification_per_m" => median_rate,
        "limit_per_m" => Float64(limit_per_m),
        "status" => String(status),
        "records" => [_neighbor_record_to_dict_v1(record) for record in records])
    return FieldLineNeighborSeparationResultV1(length(neighbor_pairs),
        length(records), length(valid_rates), maximum_rate, median_rate,
        Float64(limit_per_m), status, records, canonical_hash(payload))
end

function neighbor_separation_auxiliary_v1(item::FieldLineNeighborSeparationResultV1)
    statuses = Dict("neighbor_separation" => item.status)
    values = Dict{String,Float64}(
        "neighbor_pair_count" => Float64(item.pair_count),
        "valid_neighbor_directional_record_count" =>
            Float64(item.valid_directional_record_count),
        "neighbor_log_amplification_limit_per_m" => item.limit_per_m)
    item.maximum_log_amplification_per_m === nothing ||
        (values["maximum_neighbor_log_amplification_per_m"] =
            item.maximum_log_amplification_per_m)
    item.median_log_amplification_per_m === nothing ||
        (values["median_neighbor_log_amplification_per_m"] =
            item.median_log_amplification_per_m)
    return statuses, values
end

function _median_v1(values::Vector{Float64})
    isempty(values) && return nothing
    ordered = sort(copy(values))
    middle = length(ordered) ÷ 2
    return isodd(length(ordered)) ? ordered[middle + 1] :
        (ordered[middle] + ordered[middle + 1]) / 2
end

function _topology_class_v1(closed_fraction::Float64, open_fraction::Float64,
        unresolved_fraction::Float64)
    unresolved_fraction > 0.05 && return :unresolved
    closed_fraction >= 0.8 && open_fraction <= 0.05 && return :closed_dominated
    open_fraction >= 0.8 && closed_fraction <= 0.05 && return :open_dominated
    closed_fraction >= 0.15 && open_fraction >= 0.15 && return :mixed
    return :unresolved
end

# Keep the legacy axis-aligned payload byte-for-byte compatible with v1 hashes.
function _field_line_domain_to_dict_v1(domain::AxisAlignedFieldDomainV1)
    return Dict{String,Any}("id" => domain.id,
        "lower_m" => collect(domain.lower_m),
        "upper_m" => collect(domain.upper_m),
        "boundary_ids" => collect(domain.boundary_ids))
end

function _field_line_domain_to_dict_v1(domain::AxisymmetricPolygonFieldDomainV1)
    return Dict{String,Any}(
        "id" => domain.id,
        "kind" => "axisymmetric_polygon_absorbing_boundary_v1",
        "wall_r_m" => domain.wall_r_m,
        "wall_z_m" => domain.wall_z_m,
        "numerical_lower_m" => collect(domain.numerical_lower_m),
        "numerical_upper_m" => collect(domain.numerical_upper_m),
        "material_boundary_id" => domain.material_boundary_id,
        "numerical_boundary_ids" => collect(domain.numerical_boundary_ids),
        "wall_geometry_source_id" => domain.wall_geometry_source_id,
        "wall_geometry_hash" => domain.wall_geometry_hash,
        "physical_semantics" => "absorbing trace boundary only; no conducting-wall field response")
end

function _field_line_domain_scale_v1(domain::AxisAlignedFieldDomainV1)
    return maximum(domain.upper_m[index] - domain.lower_m[index] for index in 1:3)
end

function _field_line_domain_scale_v1(domain::AxisymmetricPolygonFieldDomainV1)
    radial_span = maximum(domain.wall_r_m) - minimum(domain.wall_r_m)
    axial_span = maximum(domain.wall_z_m) - minimum(domain.wall_z_m)
    return max(radial_span, axial_span)
end

function _field_topology_payload_v1(design_id, physics_hash, source_id, source_hash,
        source_kind, binding, resolution_id, covered_domain_ids, domain, config,
        traces, auxiliary, auxiliary_values,
        status, topology_class, closed_fraction, open_fraction, unresolved_fraction,
        median_connection, maximum_error, tasks)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => design_id,
        "genome_physics_hash" => physics_hash, "field_source_id" => source_id,
        "field_source_hash" => source_hash, "source_kind" => String(source_kind),
        "candidate_binding_verified" => binding, "resolution_id" => resolution_id,
        "covered_domain_ids" => covered_domain_ids,
        "domain" => _field_line_domain_to_dict_v1(domain),
        "trace_config" => Dict("step_length_m" => config.step_length_m,
            "maximum_arclength_m" => config.maximum_arclength_m,
            "minimum_recurrence_arclength_m" => config.minimum_recurrence_arclength_m,
            "recurrence_tolerance_m" => config.recurrence_tolerance_m,
            "recurrence_direction_cosine_min" => config.recurrence_direction_cosine_min,
            "field_floor_t" => config.field_floor_t),
        "traces" => [field_line_trace_to_dict_v1(trace) for trace in traces],
        "auxiliary_diagnostic_statuses" => Dict(key => String(value)
            for (key, value) in auxiliary),
        "auxiliary_diagnostic_values" => auxiliary_values,
        "status" => String(status), "topology_class" => String(topology_class),
        "closed_fraction" => closed_fraction, "open_fraction" => open_fraction,
        "unresolved_fraction" => unresolved_fraction,
        "median_connection_length_m" => median_connection,
        "maximum_local_error_m" => maximum_error, "evidence_tasks" => tasks)
end

function analyze_field_topology_v1(field, seeds::Vector{FieldLineSeedV1},
        domain::AbstractFieldLineDomainV1, config::FieldLineTraceConfigV1;
        design_id::AbstractString, genome_physics_hash::AbstractString,
        field_source_id::AbstractString, field_source_hash::AbstractString,
        source_kind::Symbol, candidate_binding_verified::Bool,
        resolution_id::AbstractString,
        covered_domain_ids::Vector{String} = [domain.id],
        auxiliary_diagnostic_statuses::Dict{String,Symbol} = Dict(
            "seed_coverage" => :unknown,
            "poincare_or_endpoint" => :unknown,
            "neighbor_separation" => :unknown),
        auxiliary_diagnostic_values::Dict{String,Float64} = Dict{String,Float64}())
    source_kind in _FIELD_TOPOLOGY_SOURCE_KINDS_V1 || throw(ArgumentError(
        "unknown field topology source kind: $source_kind"))
    isempty(seeds) && throw(ArgumentError("field topology analysis needs at least one seed"))
    length(unique(getfield.(seeds, :id))) == length(seeds) || throw(ArgumentError(
        "field-line seed ids must be unique"))
    isempty(covered_domain_ids) && throw(ArgumentError(
        "field topology product must declare at least one covered physical domain"))
    length(unique(covered_domain_ids)) == length(covered_domain_ids) || throw(ArgumentError(
        "covered physical domain ids must be unique"))
    source_kind == :manufactured_control && candidate_binding_verified && throw(ArgumentError(
        "manufactured controls cannot claim candidate binding"))
    traces = FieldLineTraceV1[trace_field_line_v1(field, seed, domain, config)
        for seed in seeds]
    count_total = length(traces)
    closed_fraction = count(trace -> trace.fate == :closed, traces) / count_total
    open_fraction = count(trace -> trace.fate == :open, traces) / count_total
    unresolved_fraction = 1 - closed_fraction - open_fraction
    topology_class = _topology_class_v1(closed_fraction, open_fraction,
        unresolved_fraction)
    endpoint_fraction = closed_fraction + open_fraction
    diagnostic_values = copy(auxiliary_diagnostic_values)
    diagnostic_values["endpoint_or_recurrence_resolved_fraction"] = endpoint_fraction
    for (key, value) in diagnostic_values
        isfinite(value) || throw(ArgumentError("auxiliary diagnostic $key must be finite"))
    end
    coverage_valid = haskey(diagnostic_values, "seed_coverage_fraction") &&
        0 <= diagnostic_values["seed_coverage_fraction"] <= 1
    endpoint_valid = endpoint_fraction >= 0.95
    neighbor_valid = haskey(diagnostic_values, "neighbor_pair_count") &&
        diagnostic_values["neighbor_pair_count"] >= 1 &&
        haskey(diagnostic_values, "maximum_neighbor_log_amplification_per_m") &&
        haskey(diagnostic_values, "neighbor_log_amplification_limit_per_m") &&
        diagnostic_values["maximum_neighbor_log_amplification_per_m"] <=
            diagnostic_values["neighbor_log_amplification_limit_per_m"]
    auxiliary = copy(auxiliary_diagnostic_statuses)
    get(auxiliary, "seed_coverage", :unknown) == :pass && !coverage_valid &&
        throw(ArgumentError("seed coverage pass requires a bounded seed_coverage_fraction"))
    get(auxiliary, "poincare_or_endpoint", :unknown) == :pass && !endpoint_valid &&
        throw(ArgumentError("endpoint pass requires at least 95% resolved traces"))
    get(auxiliary, "neighbor_separation", :unknown) == :pass && !neighbor_valid &&
        throw(ArgumentError("neighbor-separation pass requires pair count, measured amplification, and limit"))
    connection_lengths = Float64[trace.connection_length_m for trace in traces
        if trace.connection_length_m !== nothing]
    median_connection = _median_v1(connection_lengths)
    maximum_error = maximum(vcat([trace.forward.maximum_local_error_m
        for trace in traces], [trace.backward.maximum_local_error_m for trace in traces]))
    tasks = String[]
    unresolved_fraction > 0 && push!(tasks,
        "increase arclength, improve boundary geometry, or add a return-map diagnostic for unresolved seeds")
    for required in ("seed_coverage", "poincare_or_endpoint", "neighbor_separation")
        get(auxiliary, required, :unknown) == :pass || push!(tasks,
            "complete topology diagnostic: $required")
    end
    status = topology_class == :unresolved ? :unknown : :pass
    payload = _field_topology_payload_v1(String(design_id), String(genome_physics_hash),
        String(field_source_id), String(field_source_hash), source_kind,
        candidate_binding_verified, String(resolution_id), sort(copy(covered_domain_ids)),
        domain, config, traces, auxiliary, diagnostic_values,
        status, topology_class, closed_fraction,
        open_fraction, unresolved_fraction, median_connection, maximum_error, tasks)
    return FieldTopologyDataProductV1("1.0.0", String(design_id),
        String(genome_physics_hash), String(field_source_id), String(field_source_hash),
        source_kind, candidate_binding_verified, String(resolution_id),
        sort(copy(covered_domain_ids)), domain, config, traces,
        auxiliary, diagnostic_values, status, topology_class,
        closed_fraction, open_fraction, unresolved_fraction, median_connection,
        maximum_error, sort!(unique(tasks)), canonical_hash(payload))
end

function _relative_difference_v1(a::Float64, b::Float64)
    return abs(a - b) / max(abs(a), abs(b), 1.0e-30)
end

function compare_field_topology_resolutions_v1(coarse::FieldTopologyDataProductV1,
        fine::FieldTopologyDataProductV1;
        contract::FieldTopologyConvergenceContractV1 = FieldTopologyConvergenceContractV1())
    coarse_ids = getfield.(getfield.(coarse.traces, :seed), :id)
    fine_ids = getfield.(getfield.(fine.traces, :seed), :id)
    coarse_fates = Dict(trace.seed.id => trace.fate for trace in coarse.traces)
    fine_fates = Dict(trace.seed.id => trace.fate for trace in fine.traces)
    common_ids = intersect(Set(coarse_ids), Set(fine_ids))
    fate_agreement = isempty(common_ids) ? 0.0 : count(id ->
        coarse_fates[id] == fine_fates[id], common_ids) / length(common_ids)
    connection_relative = if coarse.median_connection_length_m === nothing &&
            fine.median_connection_length_m === nothing
        0.0
    elseif coarse.median_connection_length_m === nothing ||
            fine.median_connection_length_m === nothing
        Inf
    else
        _relative_difference_v1(coarse.median_connection_length_m,
            fine.median_connection_length_m)
    end
    domain_scale = _field_line_domain_scale_v1(fine.domain)
    local_error_floor = 64eps(Float64) * domain_scale
    local_error_ratio = coarse.maximum_local_error_m <= local_error_floor &&
        fine.maximum_local_error_m <= local_error_floor ? 1.0 :
        fine.maximum_local_error_m / max(coarse.maximum_local_error_m,
            local_error_floor)
    auxiliary_complete = all(get(coarse.auxiliary_diagnostic_statuses, id, :unknown) == :pass &&
        get(fine.auxiliary_diagnostic_statuses, id, :unknown) == :pass
        for id in ("seed_coverage", "poincare_or_endpoint", "neighbor_separation"))
    neighbor_rates_available = all(haskey(product.auxiliary_diagnostic_values,
        "maximum_neighbor_log_amplification_per_m") for product in (coarse, fine))
    neighbor_limits_available = all(haskey(product.auxiliary_diagnostic_values,
        "neighbor_log_amplification_limit_per_m") for product in (coarse, fine))
    coarse_neighbor_rate = get(coarse.auxiliary_diagnostic_values,
        "maximum_neighbor_log_amplification_per_m", 0.0)
    fine_neighbor_rate = get(fine.auxiliary_diagnostic_values,
        "maximum_neighbor_log_amplification_per_m", 0.0)
    coarse_neighbor_limit = get(coarse.auxiliary_diagnostic_values,
        "neighbor_log_amplification_limit_per_m", 0.0)
    fine_neighbor_limit = get(fine.auxiliary_diagnostic_values,
        "neighbor_log_amplification_limit_per_m", 0.0)
    neighbor_rate_difference = neighbor_rates_available ?
        abs(coarse_neighbor_rate - fine_neighbor_rate) : 0.0
    checks = Dict{String,Bool}(
        "same_design" => coarse.design_id == fine.design_id,
        "same_genome_physics_hash" => coarse.genome_physics_hash == fine.genome_physics_hash,
        "same_field_source" => coarse.field_source_id == fine.field_source_id &&
            coarse.field_source_hash == fine.field_source_hash &&
            coarse.source_kind == fine.source_kind,
        "same_covered_domains" => coarse.covered_domain_ids == fine.covered_domain_ids,
        "distinct_resolution_ids" => coarse.resolution_id != fine.resolution_id,
        "identical_seed_ids" => coarse_ids == fine_ids,
        "minimum_seed_count" => length(coarse_ids) >= contract.minimum_seed_count,
        "step_refinement" => coarse.trace_config.step_length_m /
            fine.trace_config.step_length_m >= contract.minimum_step_refinement_ratio,
        "source_products_resolved" => coarse.status == :pass && fine.status == :pass,
        "topology_class_agreement" => coarse.topology_class == fine.topology_class,
        "fate_agreement" => fate_agreement >= contract.minimum_fate_agreement_fraction,
        "closed_fraction_converged" => abs(coarse.closed_fraction - fine.closed_fraction) <=
            contract.maximum_fraction_difference,
        "open_fraction_converged" => abs(coarse.open_fraction - fine.open_fraction) <=
            contract.maximum_fraction_difference,
        "connection_length_converged" => connection_relative <=
            contract.maximum_connection_length_relative_difference,
        "local_error_nonincreasing" => local_error_ratio <=
            contract.maximum_fine_to_coarse_local_error_ratio,
        "neighbor_values_available" => neighbor_rates_available &&
            neighbor_limits_available,
        "neighbor_limit_agreement" => neighbor_limits_available &&
            isfinite(coarse_neighbor_limit) &&
            coarse_neighbor_limit == fine_neighbor_limit,
        "neighbor_amplification_converged" => neighbor_rates_available &&
            isfinite(neighbor_rate_difference) &&
            neighbor_rate_difference <= contract.
                maximum_neighbor_log_amplification_absolute_difference_per_m,
        "auxiliary_diagnostics_complete" => auxiliary_complete)
    status = all(values(checks)) ? :pass : :unknown
    authorized = status == :pass && coarse.source_kind == :candidate_bound_solver_field &&
        coarse.candidate_binding_verified && fine.candidate_binding_verified
    tasks = sort!(String["repair field-topology convergence check: $id"
        for (id, passed) in checks if !passed])
    diagnostics = Dict{String,Float64}(
        "fate_agreement_fraction" => fate_agreement,
        "closed_fraction_absolute_difference" => abs(coarse.closed_fraction - fine.closed_fraction),
        "open_fraction_absolute_difference" => abs(coarse.open_fraction - fine.open_fraction),
        "connection_length_relative_difference" => connection_relative,
        "fine_to_coarse_local_error_ratio" => local_error_ratio,
        "coarse_maximum_neighbor_log_amplification_per_m" => coarse_neighbor_rate,
        "fine_maximum_neighbor_log_amplification_per_m" => fine_neighbor_rate,
        "neighbor_log_amplification_absolute_difference_per_m" =>
            neighbor_rate_difference,
        "neighbor_values_available" => neighbor_rates_available ? 1.0 : 0.0,
        "local_error_absolute_floor_m" => local_error_floor,
        "step_refinement_ratio" => coarse.trace_config.step_length_m /
            fine.trace_config.step_length_m)
    payload = Dict{String,Any}(
        "design_id" => coarse.design_id,
        "genome_physics_hash" => coarse.genome_physics_hash,
        "coarse_product_hash" => coarse.product_hash,
        "fine_product_hash" => fine.product_hash,
        "covered_domain_ids" => fine.covered_domain_ids,
        "status" => String(status), "topology_class" => String(fine.topology_class),
        "checks" => checks, "diagnostics" => diagnostics,
        "c1_evidence_authorized" => authorized, "evidence_tasks" => tasks)
    return FieldTopologyConvergenceResultV1(coarse.design_id,
        coarse.genome_physics_hash, coarse.product_hash, fine.product_hash,
        fine.covered_domain_ids, status, fine.topology_class, checks, diagnostics,
        authorized, tasks,
        canonical_hash(payload))
end

function _directed_trace_to_dict_v1(item::DirectedFieldLineTraceV1)
    return Dict{String,Any}(
        "termination" => String(item.termination), "arclength_m" => item.arclength_m,
        "step_count" => item.step_count, "boundary_id" => item.boundary_id,
        "final_point_m" => item.final_point_m === nothing ? nothing :
            collect(item.final_point_m),
        "minimum_return_distance_m" => item.minimum_return_distance_m,
        "maximum_local_error_m" => item.maximum_local_error_m,
        "minimum_field_t" => item.minimum_field_t, "maximum_field_t" => item.maximum_field_t)
end

function field_line_trace_to_dict_v1(item::FieldLineTraceV1)
    return Dict{String,Any}(
        "seed" => Dict("id" => item.seed.id, "point_m" => collect(item.seed.point_m),
            "region_id" => item.seed.region_id),
        "forward" => _directed_trace_to_dict_v1(item.forward),
        "backward" => _directed_trace_to_dict_v1(item.backward),
        "fate" => String(item.fate), "connection_length_m" => item.connection_length_m)
end

function field_topology_data_product_to_dict_v1(item::FieldTopologyDataProductV1)
    payload = _field_topology_payload_v1(item.design_id, item.genome_physics_hash,
        item.field_source_id, item.field_source_hash, item.source_kind,
        item.candidate_binding_verified, item.resolution_id, item.covered_domain_ids,
        item.domain,
        item.trace_config, item.traces, item.auxiliary_diagnostic_statuses,
        item.auxiliary_diagnostic_values, item.status, item.topology_class,
        item.closed_fraction, item.open_fraction,
        item.unresolved_fraction, item.median_connection_length_m,
        item.maximum_local_error_m, item.evidence_tasks)
    payload["product_hash"] = item.product_hash
    payload["promotion_authorized"] = false
    return payload
end

function field_topology_convergence_to_dict_v1(item::FieldTopologyConvergenceResultV1)
    return Dict{String,Any}(
        "design_id" => item.design_id,
        "genome_physics_hash" => item.genome_physics_hash,
        "coarse_product_hash" => item.coarse_product_hash,
        "fine_product_hash" => item.fine_product_hash,
        "covered_domain_ids" => item.covered_domain_ids,
        "status" => String(item.status), "topology_class" => String(item.topology_class),
        "checks" => item.checks, "diagnostics" => item.diagnostics,
        "c1_evidence_authorized" => item.c1_evidence_authorized,
        "evidence_tasks" => item.evidence_tasks,
        "convergence_hash" => item.convergence_hash,
        "promotion_authorized" => false)
end

function _ready_topology_module_v1(executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1, implementation_id::String)
    statuses = Dict(item.module_id => item.status for item in program.modules)
    for physics_module in executable.modules
        get(statuses, physics_module.id, :invalid) == :ready_for_execution || continue
        any(backend -> backend.status == :available &&
            backend.capability_id == "field_line_topology_trace_v1" &&
            backend.implementation_id == implementation_id,
            physics_module.backend_requirements) && return physics_module
    end
    return nothing
end

"Create C1 topology evidence only from a ready native module and candidate-bound convergence."
function field_topology_evidence_bundle_v1(executable::ExecutableGenomeV1,
        program::CompiledExecutablePhysicsProgramV1,
        result::FieldTopologyConvergenceResultV1,
        topology_implementation_id::AbstractString;
        fidelity::Integer = 1)
    result.design_id == executable.base_genome.design_id || throw(ArgumentError(
        "field-topology result design does not match executable Genome"))
    result.genome_physics_hash == executable.base_genome.physics_hash || throw(ArgumentError(
        "field-topology result is not bound to the executable Genome physics hash"))
    ready_module = _ready_topology_module_v1(executable, program,
        String(topology_implementation_id))
    module_ready = ready_module !== nothing
    domain_coverage_complete = module_ready && all(id -> id in result.covered_domain_ids,
        ready_module.domain_ids)
    authorized = result.c1_evidence_authorized && module_ready && domain_coverage_complete
    status = authorized ? :pass : :unknown
    warnings = String[]
    result.c1_evidence_authorized || push!(warnings,
        "two-resolution topology result lacks candidate-bound C1 authority")
    module_ready || push!(warnings,
        "no ready executable topology module declares this exact field-line implementation")
    module_ready && !domain_coverage_complete && push!(warnings,
        "field-line products do not cover every physical domain declared by the ready topology module")
    metric_hash = canonical_hash(Dict{String,Any}(
        "evaluator" => "field_topology_compiler_v1",
        "program_hash" => program.program_hash,
        "convergence_hash" => result.convergence_hash,
        "topology_implementation_id" => String(topology_implementation_id),
        "covered_domain_ids" => result.covered_domain_ids,
        "status" => String(status)))
    metric = MetricResult("field_line_topology_resolved",
        authorized ? true : nothing; fidelity = Int(fidelity),
        applicability = "Candidate-bound magnetic field, explicit trace domain, seed coverage, endpoint/return-map and neighbor-separation diagnostics, and two-resolution convergence.",
        status = status, constraints_checked = sort!(collect(keys(result.checks))),
        solver_name = "field_topology_compiler_v1", solver_version = "1.0.0",
        input_hash = executable.base_genome.physics_hash, run_hash = metric_hash,
        source_basis = [String(topology_implementation_id), result.coarse_product_hash,
            result.fine_product_hash], warnings = warnings,
        residuals = copy(result.diagnostics))
    bundle_hash = canonical_hash(Dict{String,Any}(
        "metric_run_hash" => metric.run_hash, "program_hash" => program.program_hash))
    return EvaluationBundle("field_topology_compiler_v1", result.design_id,
        executable.base_genome.family, Int(fidelity), status, [metric], warnings,
        executable.base_genome.physics_hash, bundle_hash,
        authorized ? "C1_candidate_specific_topology_evidence" :
            "C0_topology_evidence_unknown")
end
