const _MU0 = 4.0e-7 * pi

"""Bounded continuous parameters for the first search-ready stellarator family.

The v1 boundary has five non-zero stellarator-symmetric Fourier coefficients:
R(0,0), R(1,0), R(0,1), Z(-1,0), and Z(0,-1). It is a deliberately small
search chart, not a claim of quasi-symmetry or coil realizability.
"""
struct StellaratorFourierBuildSpec
    field_periods::Int
    major_radius_m::Float64
    minor_radius_r_m::Float64
    minor_radius_z_m::Float64
    helical_axis_r_m::Float64
    helical_axis_z_m::Float64
    nominal_field_t::Float64
    pressure_axis_pa::Float64
    iota_axis::Float64
    iota_edge::Float64
    spectral_l::Int
    spectral_m::Int
    spectral_n::Int
    grid_l::Int
    grid_m::Int
    grid_n::Int
    solver_max_iterations::Int
    solver_ftol::Float64
    solver_xtol::Float64
    solver_gtol::Float64
    pressure_step::Float64
    boundary_step::Float64
    shaping_first::Bool
    max_normalized_force_error::Float64
    max_fixed_constraint_error::Float64
    min_sqrt_g::Float64
end

function StellaratorFourierBuildSpec(;
        field_periods::Integer = 3,
        major_radius_m::Real = 3.0,
        minor_radius_r_m::Real = 0.5,
        minor_radius_z_m::Real = 0.5,
        helical_axis_r_m::Real = 0.18,
        helical_axis_z_m::Real = 0.18,
        nominal_field_t::Real = 1.5,
        pressure_axis_pa::Real = 5000.0,
        iota_axis::Real = 0.45,
        iota_edge::Real = 0.60,
        spectral_l::Integer = 4,
        spectral_m::Integer = 4,
        spectral_n::Integer = 3,
        grid_l::Integer = 8,
        grid_m::Integer = 8,
        grid_n::Integer = 6,
        solver_max_iterations::Integer = 30,
        solver_ftol::Real = 1.0e-8,
        solver_xtol::Real = 1.0e-8,
        solver_gtol::Real = 1.0e-6,
        pressure_step::Real = 0.5,
        boundary_step::Real = 0.5,
        shaping_first::Bool = false,
        max_normalized_force_error::Real = 0.01,
        max_fixed_constraint_error::Real = 1.0e-12,
        min_sqrt_g::Real = 1.0e-4)
    values = Float64[major_radius_m, minor_radius_r_m, minor_radius_z_m,
        helical_axis_r_m, helical_axis_z_m, nominal_field_t, pressure_axis_pa,
        iota_axis, iota_edge, solver_ftol, solver_xtol, solver_gtol,
        pressure_step, boundary_step, max_normalized_force_error,
        max_fixed_constraint_error, min_sqrt_g]
    all(isfinite, values) || throw(ArgumentError("stellarator build values must be finite"))
    2 <= field_periods <= 8 || throw(ArgumentError("field_periods must be in 2..8"))
    1.0 <= major_radius_m <= 20.0 ||
        throw(ArgumentError("major_radius_m must be in 1..20"))
    0.05 <= minor_radius_r_m <= 5.0 ||
        throw(ArgumentError("minor_radius_r_m must be in 0.05..5"))
    0.05 <= minor_radius_z_m <= 5.0 ||
        throw(ArgumentError("minor_radius_z_m must be in 0.05..5"))
    aspect = major_radius_m / sqrt(minor_radius_r_m * minor_radius_z_m)
    2.5 <= aspect <= 20.0 || throw(ArgumentError("geometric aspect ratio must be in 2.5..20"))
    0.0 <= helical_axis_r_m <= 0.8 * minor_radius_r_m ||
        throw(ArgumentError("helical_axis_r_m is outside the v1 chart"))
    0.0 <= helical_axis_z_m <= 0.8 * minor_radius_z_m ||
        throw(ArgumentError("helical_axis_z_m is outside the v1 chart"))
    major_radius_m > 2.0 * (minor_radius_r_m + helical_axis_r_m) ||
        throw(ArgumentError("major radius is too small for the supplied R amplitudes"))
    0.1 <= nominal_field_t <= 12.0 ||
        throw(ArgumentError("nominal_field_t must be in 0.1..12"))
    1.0 <= pressure_axis_pa <= 1.0e7 ||
        throw(ArgumentError("pressure_axis_pa must be in 1..1e7"))
    0.02 <= abs(iota_axis) <= 3.0 ||
        throw(ArgumentError("iota_axis magnitude must be in 0.02..3"))
    0.02 <= abs(iota_edge) <= 3.0 ||
        throw(ArgumentError("iota_edge magnitude must be in 0.02..3"))
    sign(iota_axis) == sign(iota_edge) ||
        throw(ArgumentError("iota profile may not cross zero in builder v1"))
    2 <= spectral_l <= 12 || throw(ArgumentError("spectral_l must be in 2..12"))
    2 <= spectral_m <= 12 || throw(ArgumentError("spectral_m must be in 2..12"))
    1 <= spectral_n <= 12 || throw(ArgumentError("spectral_n must be in 1..12"))
    spectral_l <= grid_l <= 24 || throw(ArgumentError("grid_l must cover spectral_l and be <=24"))
    spectral_m <= grid_m <= 24 || throw(ArgumentError("grid_m must cover spectral_m and be <=24"))
    spectral_n <= grid_n <= 24 || throw(ArgumentError("grid_n must cover spectral_n and be <=24"))
    1 <= solver_max_iterations <= 200 ||
        throw(ArgumentError("solver_max_iterations must be in 1..200"))
    all(value -> 1.0e-12 <= value <= 1.0e-3,
        (solver_ftol, solver_xtol, solver_gtol)) ||
        throw(ArgumentError("solver tolerances must be in 1e-12..1e-3"))
    0.05 <= pressure_step <= 1.0 ||
        throw(ArgumentError("pressure_step must be in 0.05..1"))
    0.05 <= boundary_step <= 1.0 ||
        throw(ArgumentError("boundary_step must be in 0.05..1"))
    1.0e-5 <= max_normalized_force_error <= 0.1 ||
        throw(ArgumentError("force threshold must be in 1e-5..0.1"))
    1.0e-15 <= max_fixed_constraint_error <= 1.0e-8 ||
        throw(ArgumentError("fixed-constraint threshold must be in 1e-15..1e-8"))
    0.0 <= min_sqrt_g <= 1.0 ||
        throw(ArgumentError("min_sqrt_g must be in 0..1"))
    return StellaratorFourierBuildSpec(Int(field_periods), Float64(major_radius_m),
        Float64(minor_radius_r_m), Float64(minor_radius_z_m),
        Float64(helical_axis_r_m), Float64(helical_axis_z_m),
        Float64(nominal_field_t), Float64(pressure_axis_pa),
        Float64(iota_axis), Float64(iota_edge), Int(spectral_l), Int(spectral_m),
        Int(spectral_n), Int(grid_l), Int(grid_m), Int(grid_n),
        Int(solver_max_iterations), Float64(solver_ftol), Float64(solver_xtol),
        Float64(solver_gtol), Float64(pressure_step), Float64(boundary_step),
        shaping_first, Float64(max_normalized_force_error),
        Float64(max_fixed_constraint_error), Float64(min_sqrt_g))
end

function _stellarator_build_spec_dict(spec::StellaratorFourierBuildSpec)
    return Dict{String,Any}(String(name) => getfield(spec, name)
        for name in fieldnames(StellaratorFourierBuildSpec))
end

_stellarator_quantity(value, unit, basis) =
    Dict{String,Any}("value" => value, "unit" => unit, "basis" => basis)

"Create an explicit, solver-addressable geometry from a structural stellarator parent."
function build_stellarator_fourier_genome(parent::Genome,
        spec::StellaratorFourierBuildSpec = StellaratorFourierBuildSpec();
        design_id::Union{Nothing,AbstractString} = nothing)
    parent.family == "stellarator" ||
        throw(ArgumentError("stellarator Fourier builder requires a stellarator parent"))
    raw = deepcopy(parent.normalized)
    spec_dict = _stellarator_build_spec_dict(spec)
    suffix = first(canonical_hash(spec_dict), 16)
    id = design_id === nothing ? "stellarator_fourier_$suffix" : String(design_id)
    occursin(r"^[a-z0-9_]+$", id) ||
        throw(ArgumentError("design_id must use lowercase letters, digits, and underscores"))
    flux = spec.nominal_field_t * pi * spec.minor_radius_r_m * spec.minor_radius_z_m
    beta_axis_target = 2.0 * _MU0 * spec.pressure_axis_pa / spec.nominal_field_t^2
    iota_quadratic = spec.iota_edge - spec.iota_axis
    core_id = "fourier_stellarator_core"
    edge_id = "fourier_stellarator_edge_interface"
    basis = "Explicit search variable for DESC fixed-boundary input; not an achieved device value"
    raw["design_id"] = id
    raw["label"] = "Explicit three-dimensional Fourier stellarator search candidate"
    raw["mission"] = Dict{String,Any}(
        "kind" => "science_gain_demo",
        "fuel" => "D-T",
        "operating_mode" => "long_pulse",
        "targets" => Dict{String,Any}(
            "on_axis_field" => _stellarator_quantity(spec.nominal_field_t, "T", basis),
            "vacuum_axis_beta" => _stellarator_quantity(beta_axis_target, "1", basis),
        ),
    )
    raw["family"] = "stellarator"
    raw["topology"] = Dict{String,Any}(
        "field_line_class" => "closed_toroidal_nested",
        "rotation_transform_sources" => ["three_dimensional_external_field"],
        "expected_flux_surfaces" => true,
        "expected_separatrix" => false,
    )
    raw["symmetry"] = Dict{String,Any}(
        "class" => "stellarator_symmetric",
        "field_periods" => spec.field_periods,
        "hard_constraints" => ["stellarator symmetry",
            "$(spec.field_periods)-fold periodicity", "fixed boundary only"],
    )
    params = Dict{String,Any}(
        "major_radius" => _stellarator_quantity(spec.major_radius_m, "m", basis),
        "minor_radius_r" => _stellarator_quantity(spec.minor_radius_r_m, "m", basis),
        "minor_radius_z" => _stellarator_quantity(spec.minor_radius_z_m, "m", basis),
        "helical_axis_r" => _stellarator_quantity(spec.helical_axis_r_m, "m", basis),
        "helical_axis_z" => _stellarator_quantity(spec.helical_axis_z_m, "m", basis),
        "nominal_field" => _stellarator_quantity(spec.nominal_field_t, "T", basis),
        "toroidal_flux" => _stellarator_quantity(flux, "Wb", basis),
        "pressure_axis" => _stellarator_quantity(spec.pressure_axis_pa, "Pa", basis),
        "pressure_profile_exponent" => _stellarator_quantity(2, "1", "p=p0*(1-rho^2)^2"),
        "iota_axis" => _stellarator_quantity(spec.iota_axis, "1", basis),
        "iota_edge" => _stellarator_quantity(spec.iota_edge, "1", basis),
        "iota_quadratic" => _stellarator_quantity(iota_quadratic, "1", "iota=iota_axis+iota_quadratic*rho^2"),
        "spectral_l" => _stellarator_quantity(spec.spectral_l, "1", "DESC radial spectral resolution"),
        "spectral_m" => _stellarator_quantity(spec.spectral_m, "1", "DESC poloidal spectral resolution"),
        "spectral_n" => _stellarator_quantity(spec.spectral_n, "1", "DESC toroidal spectral resolution"),
        "grid_l" => _stellarator_quantity(spec.grid_l, "1", "DESC radial collocation resolution"),
        "grid_m" => _stellarator_quantity(spec.grid_m, "1", "DESC poloidal collocation resolution"),
        "grid_n" => _stellarator_quantity(spec.grid_n, "1", "DESC toroidal collocation resolution"),
        "solver_max_iterations" => _stellarator_quantity(spec.solver_max_iterations, "1", "Per-continuation-state limit"),
        "solver_ftol" => _stellarator_quantity(spec.solver_ftol, "1", "DESC lsq-exact tolerance"),
        "solver_xtol" => _stellarator_quantity(spec.solver_xtol, "1", "DESC lsq-exact tolerance"),
        "solver_gtol" => _stellarator_quantity(spec.solver_gtol, "1", "DESC lsq-exact tolerance"),
        "pressure_step" => _stellarator_quantity(spec.pressure_step, "1", "Automatic continuation step"),
        "boundary_step" => _stellarator_quantity(spec.boundary_step, "1", "Automatic continuation step"),
        "shaping_first" => _stellarator_quantity(spec.shaping_first ? 1 : 0, "1", "Boolean encoded as 0 or 1"),
        "max_normalized_force_error" => _stellarator_quantity(spec.max_normalized_force_error, "1", "Equation-residual gate"),
        "max_fixed_constraint_error" => _stellarator_quantity(spec.max_fixed_constraint_error, "1", "Fixed input drift gate"),
        "min_sqrt_g" => _stellarator_quantity(spec.min_sqrt_g, "1", "Positive-coordinate-Jacobian gate away from axis"),
    )
    raw["plasma_regions"] = Any[
        Dict{String,Any}("id" => core_id, "kind" => "closed_toroidal_core",
            "geometry_model" => "desc_stellarator_symmetric_fourier_v1",
            "parameters" => params),
        Dict{String,Any}("id" => edge_id, "kind" => "divertor_or_exhaust_region",
            "geometry_model" => "unresolved_fixed_boundary_edge_interface",
            "parameters" => Dict{String,Any}()),
    ]
    raw["field_sources"] = Any[
        Dict{String,Any}(
            "id" => "unresolved_stellarator_coils",
            "kind" => "three_dimensional_modular_coil",
            "geometry_model" => "not_designed_by_fixed_boundary_desc_v1",
            "parameters" => Dict{String,Any}(),
            "material" => "unresolved superconducting coil system",
        ),
    ]
    raw["actuators"] = Any[]
    raw["stability_mechanisms"] = Any[
        Dict{String,Any}(
            "id" => "fourier_fixed_boundary_evidence_requirements",
            "mechanism" => "other",
            "target_modes" => ["static ideal-MHD force balance",
                "nested coordinate map", "future Mercier and ballooning stability"],
            "actuator_ids" => String[],
            "assumptions" => [
                "the five-mode boundary is a search chart, not a quasi-symmetry claim",
                "external coils have not been designed",
                "force balance does not imply stability or good transport",
            ],
            "required_evaluators" => ["explicit_fourier_boundary", "vmec_or_desc",
                "finite_beta_equilibrium", "three_dimensional_force_balance",
                "mercier", "ballooning", "neoclassical_transport", "alpha_orbits"],
            "source_ids" => ["desc_software_0_17_3",
                "stellarator_precise_qs_landreman_paul_2022"],
        ),
    ]
    raw["flux_connections"] = Any[]
    raw["exhaust"] = Dict{String,Any}(
        "kind" => "limiter",
        "region_ids" => [edge_id],
        "evaluation_requirements" => ["edge_heat_flux", "detachment",
            "impurity_screening"],
    )
    raw["engineering"] = Dict{String,Any}(
        "magnet_technology" => ["unresolved three-dimensional superconducting coils"],
        "blanket" => Dict{String,Any}(
            "required" => true,
            "concept" => "unresolved blanket outside a future winding surface"),
        "maintenance" => Dict{String,Any}(
            "architecture" => "unresolved modular access",
            "access_paths" => ["must be created between future coils"]),
        "required_evaluators" => ["coil_curvature", "coil_separation",
            "assembly_tolerance", "port_access", "blanket_clearance",
            "neutronics", "structural_fea", "remote_maintenance"],
    )
    source_ids = sort!(unique(vcat(parent.provenance.source_ids,
        ["desc_software_0_17_3", "stellarator_precise_qs_landreman_paul_2022"])))
    raw["provenance"] = Dict{String,Any}(
        "origin" => "generated",
        "source_ids" => source_ids,
        "parent_design_ids" => [parent.design_id],
        "claim_level" => "structural_example",
        "notes" => [
            "Generated by stellarator_fourier_builder_v1 from an explicit bounded search chart.",
            "No quasi-symmetry, stability, transport, coil, exhaust, performance, or engineering claim is made.",
        ],
    )
    genome = parse_genome(raw)
    report = validate_genome(genome)
    report.valid || throw(ArgumentError("builder produced invalid genome: $(join(report.errors, "; "))"))
    return genome
end
