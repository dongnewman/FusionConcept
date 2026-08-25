const _MU0_V1 = 4.0e-7 * pi

"Static magnetic-energy inventory on one explicitly bounded field grid."
struct MagneticEnergyObservationV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    coordinate_system::String
    radial_points::Int
    axial_points::Int
    domain_volume_m3::Float64
    magnetic_energy_j::Float64
    poloidal_energy_j::Float64
    toroidal_energy_j::Float64
    peak_energy_density_j_m3::Float64
    source_artifact_id::String
    source_artifact_hash::String
    source_result_hash::String
    source_solver_status::Symbol
    candidate_binding_verified::Bool
    fidelity::Int
    finite_build_resolved::Bool
    status::Symbol
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    observation_hash::String
end

"Three-or-more-grid convergence result for a finite computational-domain inventory."
struct MagneticEnergyConvergenceV1
    design_id::String
    genome_physics_hash::String
    domain_id::String
    observation_hashes::Vector{String}
    grid_points::Vector{Int}
    magnetic_energy_j::Vector{Float64}
    medium_to_fine_relative_change::Float64
    convergence_limit::Float64
    status::Symbol
    c2_inventory_support_authorized::Bool
    complete_magnet_engineering_authorized::Bool
    conservation_power_term_authorized::Bool
    evidence_tasks::Vector{String}
    warnings::Vector{String}
    convergence_hash::String
end

function _trapezoid_weights_v1(grid::Vector{Float64})
    length(grid) >= 2 || throw(ArgumentError("integration grid needs at least two points"))
    all(isfinite, grid) || throw(ArgumentError("integration grid must be finite"))
    all(diff(grid) .> 0) || throw(ArgumentError("integration grid must be strictly increasing"))
    weights = zeros(length(grid))
    weights[1] = (grid[2] - grid[1]) / 2
    weights[end] = (grid[end] - grid[end - 1]) / 2
    for index in 2:(length(grid) - 1)
        weights[index] = (grid[index + 1] - grid[index - 1]) / 2
    end
    return weights
end

"Integrate B^2/(2 mu0) over an axisymmetric cylindrical finite domain."
function integrate_axisymmetric_magnetic_energy_v1(radial_grid_m::Vector{Float64},
        axial_grid_m::Vector{Float64}, br_t::Matrix{Float64},
        bphi_t::Matrix{Float64}, bz_t::Matrix{Float64})
    expected = (length(axial_grid_m), length(radial_grid_m))
    size(br_t) == expected || throw(ArgumentError("br_t shape must be axial by radial"))
    size(bphi_t) == expected || throw(ArgumentError("bphi_t shape must be axial by radial"))
    size(bz_t) == expected || throw(ArgumentError("bz_t shape must be axial by radial"))
    all(isfinite, br_t) && all(isfinite, bphi_t) && all(isfinite, bz_t) ||
        throw(ArgumentError("field components must be finite"))
    first(radial_grid_m) >= 0 || throw(ArgumentError("cylindrical radius cannot be negative"))
    wr = _trapezoid_weights_v1(radial_grid_m)
    wz = _trapezoid_weights_v1(axial_grid_m)
    total = 0.0
    poloidal = 0.0
    toroidal = 0.0
    volume = 0.0
    peak = 0.0
    for iz in eachindex(axial_grid_m), ir in eachindex(radial_grid_m)
        volume_weight = wz[iz] * wr[ir] * 2pi * radial_grid_m[ir]
        up = (br_t[iz, ir]^2 + bz_t[iz, ir]^2) / (2 * _MU0_V1)
        ut = bphi_t[iz, ir]^2 / (2 * _MU0_V1)
        poloidal += up * volume_weight
        toroidal += ut * volume_weight
        volume += volume_weight
        peak = max(peak, up + ut)
    end
    return Dict{String,Float64}(
        "domain_volume_m3" => volume,
        "magnetic_energy_j" => poloidal + toroidal,
        "poloidal_energy_j" => poloidal,
        "toroidal_energy_j" => toroidal,
        "peak_energy_density_j_m3" => peak)
end

function compile_magnetic_energy_observation_v1(; design_id::AbstractString,
        genome_physics_hash::AbstractString, domain_id::AbstractString,
        coordinate_system::AbstractString, radial_points::Integer,
        axial_points::Integer, domain_volume_m3::Real, magnetic_energy_j::Real,
        poloidal_energy_j::Real, toroidal_energy_j::Real,
        peak_energy_density_j_m3::Real, source_artifact_id::AbstractString,
        source_artifact_hash::AbstractString, source_result_hash::AbstractString,
        source_solver_status::Symbol, candidate_binding_verified::Bool,
        fidelity::Integer, finite_build_resolved::Bool = false)
    source_solver_status in (:pass, :fail, :unknown, :error) ||
        throw(ArgumentError("invalid source solver status"))
    fidelity >= 0 || throw(ArgumentError("fidelity must be non-negative"))
    radial_points >= 2 && axial_points >= 2 ||
        throw(ArgumentError("magnetic-energy grid must be at least 2 by 2"))
    values = Float64[domain_volume_m3, magnetic_energy_j, poloidal_energy_j,
        toroidal_energy_j, peak_energy_density_j_m3]
    all(isfinite, values) || throw(ArgumentError("magnetic-energy values must be finite"))
    all(values .>= 0) || throw(ArgumentError("magnetic-energy values must be non-negative"))
    isapprox(values[2], values[3] + values[4]; rtol = 1e-10, atol = 1e-9) ||
        throw(ArgumentError("total magnetic energy must equal component energies"))
    tasks = String[]
    isempty(design_id) && push!(tasks, "provide_design_id")
    length(genome_physics_hash) == 64 || push!(tasks, "provide_genome_physics_hash")
    isempty(domain_id) && push!(tasks, "declare_finite_integration_domain")
    coordinate_system == "cylindrical_axisymmetric" ||
        push!(tasks, "provide_supported_volume_jacobian")
    isempty(source_artifact_id) && push!(tasks, "provide_source_artifact_id")
    length(source_artifact_hash) == 64 || push!(tasks, "provide_source_artifact_hash")
    length(source_result_hash) == 64 || push!(tasks, "provide_source_result_hash")
    candidate_binding_verified || push!(tasks, "verify_candidate_binding")
    fidelity >= 2 || push!(tasks, "raise_field_solver_fidelity_to_c2")
    source_solver_status == :pass || push!(tasks, "obtain_passing_field_solver_result")
    warnings = String[
        "Inventory covers only the declared finite computational domain; exterior field energy is omitted.",
        "Static magnetic energy is not a storage rate or a power-balance term."]
    finite_build_resolved || push!(warnings,
        "Filament/source singularity and finite conductor build are not resolved.")
    authoritative = isempty(tasks)
    status = source_solver_status == :fail || source_solver_status == :error ? :fail :
        authoritative ? :pass : :unknown
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => String(design_id),
        "genome_physics_hash" => String(genome_physics_hash),
        "domain_id" => String(domain_id), "coordinate_system" => String(coordinate_system),
        "radial_points" => Int(radial_points), "axial_points" => Int(axial_points),
        "domain_volume_m3" => values[1], "magnetic_energy_j" => values[2],
        "poloidal_energy_j" => values[3], "toroidal_energy_j" => values[4],
        "peak_energy_density_j_m3" => values[5],
        "source_artifact_id" => String(source_artifact_id),
        "source_artifact_hash" => String(source_artifact_hash),
        "source_result_hash" => String(source_result_hash),
        "source_solver_status" => String(source_solver_status),
        "candidate_binding_verified" => candidate_binding_verified,
        "fidelity" => Int(fidelity), "finite_build_resolved" => finite_build_resolved,
        "status" => String(status), "evidence_tasks" => sort!(unique(tasks)),
        "warnings" => warnings)
    return MagneticEnergyObservationV1(String(design_id), String(genome_physics_hash),
        String(domain_id), String(coordinate_system), Int(radial_points),
        Int(axial_points), values..., String(source_artifact_id),
        String(source_artifact_hash), String(source_result_hash), source_solver_status,
        candidate_binding_verified, Int(fidelity), finite_build_resolved, status,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

function magnetic_energy_observation_to_dict_v1(item::MagneticEnergyObservationV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "coordinate_system" => item.coordinate_system,
        "radial_points" => item.radial_points, "axial_points" => item.axial_points,
        "domain_volume_m3" => item.domain_volume_m3,
        "magnetic_energy_j" => item.magnetic_energy_j,
        "poloidal_energy_j" => item.poloidal_energy_j,
        "toroidal_energy_j" => item.toroidal_energy_j,
        "peak_energy_density_j_m3" => item.peak_energy_density_j_m3,
        "source_artifact_id" => item.source_artifact_id,
        "source_artifact_hash" => item.source_artifact_hash,
        "source_result_hash" => item.source_result_hash,
        "source_solver_status" => String(item.source_solver_status),
        "candidate_binding_verified" => item.candidate_binding_verified,
        "fidelity" => item.fidelity, "finite_build_resolved" => item.finite_build_resolved,
        "status" => String(item.status), "evidence_tasks" => item.evidence_tasks,
        "warnings" => item.warnings, "observation_hash" => item.observation_hash)
end

function compile_magnetic_energy_convergence_v1(
        observations::Vector{MagneticEnergyObservationV1};
        convergence_limit::Real = 0.02)
    length(observations) >= 3 || throw(ArgumentError(
        "at least three magnetic-energy resolutions are required"))
    0 < convergence_limit < 1 || throw(ArgumentError("invalid convergence limit"))
    design_id = first(observations).design_id
    genome_hash = first(observations).genome_physics_hash
    domain_id = first(observations).domain_id
    all(item -> item.design_id == design_id, observations) ||
        throw(ArgumentError("magnetic-energy design mismatch"))
    all(item -> item.genome_physics_hash == genome_hash, observations) ||
        throw(ArgumentError("magnetic-energy Genome hash mismatch"))
    all(item -> item.domain_id == domain_id, observations) ||
        throw(ArgumentError("magnetic-energy domain mismatch"))
    ordered = sort(observations; by = item -> item.radial_points * item.axial_points)
    points = [item.radial_points * item.axial_points for item in ordered]
    length(unique(points)) == length(points) || throw(ArgumentError(
        "magnetic-energy resolutions must be distinct"))
    medium, fine = ordered[end - 1], ordered[end]
    relative_change = abs(fine.magnetic_energy_j - medium.magnetic_energy_j) /
        max(abs(fine.magnetic_energy_j), 1e-30)
    tasks = String[]
    any(item -> item.status != :pass, ordered) && push!(tasks,
        "resolve_all_grid_observations")
    relative_change <= convergence_limit || push!(tasks,
        "resolve_magnetic_energy_grid_nonconvergence")
    volumes = [item.domain_volume_m3 for item in ordered]
    volume_spread = (maximum(volumes) - minimum(volumes)) / max(maximum(volumes), 1e-30)
    volume_spread <= 1e-10 || push!(tasks, "use_identical_physical_domain_across_grids")
    observations_authoritative = all(item -> item.status == :pass, ordered)
    domain_consistent = volume_spread <= 1e-10
    status = !(observations_authoritative && domain_consistent) ? :unknown :
        relative_change > convergence_limit ? :fail : :pass
    authorized = status == :pass
    warnings = String[
        "Convergence authorizes only finite-domain static magnetic-energy inventory support.",
        "Complete magnet engineering and conservation power terms remain unauthorized."]
    core = Dict{String,Any}(
        "schema_version" => "1.0.0", "design_id" => design_id,
        "genome_physics_hash" => genome_hash, "domain_id" => domain_id,
        "observation_hashes" => [item.observation_hash for item in ordered],
        "grid_points" => points,
        "magnetic_energy_j" => [item.magnetic_energy_j for item in ordered],
        "medium_to_fine_relative_change" => relative_change,
        "convergence_limit" => Float64(convergence_limit), "status" => String(status),
        "c2_inventory_support_authorized" => authorized,
        "complete_magnet_engineering_authorized" => false,
        "conservation_power_term_authorized" => false,
        "evidence_tasks" => sort!(unique(tasks)), "warnings" => warnings)
    return MagneticEnergyConvergenceV1(design_id, genome_hash, domain_id,
        [item.observation_hash for item in ordered], points,
        [item.magnetic_energy_j for item in ordered], relative_change,
        Float64(convergence_limit), status, authorized, false, false,
        sort!(unique(tasks)), warnings, canonical_hash(core))
end

function magnetic_energy_convergence_to_dict_v1(item::MagneticEnergyConvergenceV1)
    return Dict{String,Any}(
        "design_id" => item.design_id, "genome_physics_hash" => item.genome_physics_hash,
        "domain_id" => item.domain_id, "observation_hashes" => item.observation_hashes,
        "grid_points" => item.grid_points, "magnetic_energy_j" => item.magnetic_energy_j,
        "medium_to_fine_relative_change" => item.medium_to_fine_relative_change,
        "convergence_limit" => item.convergence_limit, "status" => String(item.status),
        "c2_inventory_support_authorized" => item.c2_inventory_support_authorized,
        "complete_magnet_engineering_authorized" => item.complete_magnet_engineering_authorized,
        "conservation_power_term_authorized" => item.conservation_power_term_authorized,
        "evidence_tasks" => item.evidence_tasks, "warnings" => item.warnings,
        "convergence_hash" => item.convergence_hash)
end

function magnetic_energy_evidence_bundle_v1(genome::Genome,
        item::MagneticEnergyConvergenceV1)
    genome.design_id == item.design_id || throw(ArgumentError("design mismatch"))
    genome.physics_hash == item.genome_physics_hash || throw(ArgumentError("Genome hash mismatch"))
    value = item.status == :pass ? true : item.status == :fail ? false : nothing
    metric = MetricResult("finite_domain_magnetic_energy_inventory_converged", value;
        fidelity = 2, applicability = "Declared finite field-solver domain only.",
        status = item.status,
        constraints_checked = ["candidate binding", "three-grid convergence",
            "identical physical integration domain"],
        solver_name = "magnetic_energy_inventory_compiler_v1",
        solver_version = "1.0.0", input_hash = item.genome_physics_hash,
        run_hash = item.convergence_hash, source_basis = item.observation_hashes,
        warnings = vcat(item.warnings, item.evidence_tasks),
        residuals = Dict("medium_to_fine_relative_change" =>
            item.medium_to_fine_relative_change))
    claim = item.c2_inventory_support_authorized ?
        "C2_support_finite_domain_magnetic_energy_inventory_only" :
        "C2_magnetic_energy_inventory_unknown_or_failed"
    return EvaluationBundle("magnetic_energy_inventory_compiler_v1",
        item.design_id, genome.family, 2, item.status, [metric], copy(metric.warnings),
        item.genome_physics_hash, item.convergence_hash, claim)
end
