"One kinetic species in the parallel bi-Maxwellian AIC dielectric response."
struct AICBiMaxwellianSpeciesV1
    species_id::String
    cyclotron_to_reference_ratio::Float64
    plasma_to_reference_cyclotron_ratio_sq::Float64
    parallel_thermal_to_alfven_ratio::Float64
    perpendicular_to_parallel_temperature_ratio::Float64
    collision_to_reference_cyclotron_ratio::Float64
    species_hash::String
end

"Candidate-bound upper-half-plane root census for the parallel AIC branch."
struct OpenFieldAICProblemV1
    candidate_binding_hash::String
    state_result_hash::String
    resolution_id::String
    normalized_wavenumbers::Vector{Float64}
    light_to_alfven_speed_ratio::Float64
    polarization_sign::Int
    species::Vector{AICBiMaxwellianSpeciesV1}
    root_real_bounds::Tuple{Float64,Float64}
    root_growth_bounds::Tuple{Float64,Float64}
    root_seed_counts::Tuple{Int,Int}
    contour_points_per_side::Int
    plasma_dispersion_quadrature_count::Int
    validity_domain_covered::Bool
    source_artifact_paths::Vector{String}
    source_artifact_hashes::Vector{String}
    claim_boundary::String
    problem_hash::String
end

struct OpenFieldAICRootV1
    normalized_wavenumber::Float64
    normalized_frequency::ComplexF64
    dispersion_residual::Float64
    converged::Bool
end

struct OpenFieldAICObservationV1
    candidate_binding_hash::String
    state_result_hash::String
    resolution_id::String
    status::Symbol
    maximum_normalized_growth_rate::Union{Nothing,Float64}
    maximum_dispersion_residual::Union{Nothing,Float64}
    unstable_root_count::Union{Nothing,Int}
    root_census_complete::Bool
    contour_counts::Vector{Int}
    roots::Vector{OpenFieldAICRootV1}
    problem_hash::String
    observation_hash::String
end

struct OpenFieldAICConvergenceV1
    candidate_binding_hash::String
    state_result_hash::String
    status::Symbol
    favorable::Union{Nothing,Bool}
    maximum_normalized_growth_rate::Union{Nothing,Float64}
    maximum_growth_change::Union{Nothing,Float64}
    unstable_root_count::Union{Nothing,Int}
    resolution_verified::Bool
    observations::Vector{OpenFieldAICObservationV1}
    convergence_hash::String
end

function AICBiMaxwellianSpeciesV1(species_id::AbstractString;
        cyclotron_to_reference_ratio::Real,
        plasma_to_reference_cyclotron_ratio_sq::Real,
        parallel_thermal_to_alfven_ratio::Real,
        perpendicular_to_parallel_temperature_ratio::Real,
        collision_to_reference_cyclotron_ratio::Real = 0.0)
    values = Float64.((cyclotron_to_reference_ratio,
        plasma_to_reference_cyclotron_ratio_sq, parallel_thermal_to_alfven_ratio,
        perpendicular_to_parallel_temperature_ratio,
        collision_to_reference_cyclotron_ratio))
    all(isfinite, values) || throw(ArgumentError("AIC species parameters must be finite"))
    values[1] != 0.0 || throw(ArgumentError("AIC cyclotron ratio cannot be zero"))
    values[2] > 0.0 || throw(ArgumentError("AIC plasma-frequency ratio must be positive"))
    values[3] > 0.0 || throw(ArgumentError("AIC parallel thermal speed must be positive"))
    values[4] > 0.0 || throw(ArgumentError("AIC temperature ratio must be positive"))
    values[5] >= 0.0 || throw(ArgumentError("AIC collision ratio cannot be negative"))
    core = Dict{String,Any}("schema_version" => "1.0.0", "species_id" => String(species_id),
        "cyclotron_to_reference_ratio" => values[1],
        "plasma_to_reference_cyclotron_ratio_sq" => values[2],
        "parallel_thermal_to_alfven_ratio" => values[3],
        "perpendicular_to_parallel_temperature_ratio" => values[4],
        "collision_to_reference_cyclotron_ratio" => values[5])
    return AICBiMaxwellianSpeciesV1(String(species_id), values..., canonical_hash(core))
end

function _aic_species_to_dict_v1(species::AICBiMaxwellianSpeciesV1)
    return Dict{String,Any}("species_id" => species.species_id,
        "cyclotron_to_reference_ratio" => species.cyclotron_to_reference_ratio,
        "plasma_to_reference_cyclotron_ratio_sq" =>
            species.plasma_to_reference_cyclotron_ratio_sq,
        "parallel_thermal_to_alfven_ratio" => species.parallel_thermal_to_alfven_ratio,
        "perpendicular_to_parallel_temperature_ratio" =>
            species.perpendicular_to_parallel_temperature_ratio,
        "collision_to_reference_cyclotron_ratio" =>
            species.collision_to_reference_cyclotron_ratio,
        "species_hash" => species.species_hash)
end

function compile_open_field_aic_problem_v1(; candidate_binding_hash::AbstractString,
        state_result_hash::AbstractString, resolution_id::AbstractString,
        normalized_wavenumbers::AbstractVector, light_to_alfven_speed_ratio::Real,
        polarization_sign::Integer = 1,
        species::Vector{AICBiMaxwellianSpeciesV1}, root_real_bounds::Tuple,
        root_growth_bounds::Tuple, root_seed_counts::Tuple{<:Integer,<:Integer} = (16, 8),
        contour_points_per_side::Integer = 128,
        plasma_dispersion_quadrature_count::Integer = 64,
        validity_domain_covered::Bool, source_artifact_paths::AbstractVector = String[],
        source_artifact_hashes::AbstractVector = String[], claim_boundary::AbstractString)
    ks = Float64.(normalized_wavenumbers)
    !isempty(ks) && all(isfinite, ks) && all(ks .> 0.0) || throw(ArgumentError(
        "AIC normalized wavenumbers must be finite and positive"))
    cva = Float64(light_to_alfven_speed_ratio)
    isfinite(cva) && cva > 1.0 || throw(ArgumentError(
        "AIC light-to-Alfven speed ratio must exceed one"))
    s = Int(polarization_sign)
    s in (-1, 1) || throw(ArgumentError("AIC polarization sign must be -1 or +1"))
    isempty(species) && throw(ArgumentError("AIC requires at least one kinetic species"))
    length(unique(getfield.(species, :species_id))) == length(species) || throw(ArgumentError(
        "AIC species identifiers must be unique"))
    rb = Float64.((root_real_bounds[1], root_real_bounds[2]))
    gb = Float64.((root_growth_bounds[1], root_growth_bounds[2]))
    all(isfinite, rb) && 0.0 < rb[1] < rb[2] || throw(ArgumentError(
        "AIC real root bounds must be finite, ordered, and exclude zero"))
    all(isfinite, gb) && 0.0 < gb[1] < gb[2] || throw(ArgumentError(
        "AIC growth bounds must be finite, positive, and ordered"))
    seeds = (Int(root_seed_counts[1]), Int(root_seed_counts[2]))
    all(x -> x >= 3, seeds) || throw(ArgumentError(
        "AIC root census requires at least a 3 by 3 seed grid"))
    contour = Int(contour_points_per_side)
    contour >= 32 || throw(ArgumentError("AIC contour requires at least 32 points per side"))
    nq = Int(plasma_dispersion_quadrature_count)
    nq >= 16 && iseven(nq) || throw(ArgumentError(
        "AIC plasma-dispersion quadrature must be even and at least 16"))
    paths, hashes = String.(source_artifact_paths), String.(source_artifact_hashes)
    length(paths) == length(hashes) || throw(ArgumentError("source paths and hashes must pair"))
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => String(candidate_binding_hash),
        "state_result_hash" => String(state_result_hash), "resolution_id" => String(resolution_id),
        "normalized_wavenumbers" => ks, "light_to_alfven_speed_ratio" => cva,
        "polarization_sign" => s, "species" => _aic_species_to_dict_v1.(species),
        "root_real_bounds" => collect(rb), "root_growth_bounds" => collect(gb),
        "root_seed_counts" => collect(seeds), "contour_points_per_side" => contour,
        "plasma_dispersion_quadrature_count" => nq,
        "validity_domain_covered" => validity_domain_covered,
        "source_artifact_paths" => paths, "source_artifact_hashes" => hashes,
        "claim_boundary" => String(claim_boundary))
    return OpenFieldAICProblemV1(String(candidate_binding_hash), String(state_result_hash),
        String(resolution_id), ks, cva, s, copy(species), (rb[1], rb[2]), (gb[1], gb[2]),
        seeds, contour, nq, validity_domain_covered, paths, hashes,
        String(claim_boundary), canonical_hash(core))
end

const _AIC_GAUSS_HERMITE_CACHE_V1 = Dict{Int,Tuple{Vector{Float64},Vector{Float64}}}()

function _aic_gauss_hermite_v1(count::Int)
    return get!(_AIC_GAUSS_HERMITE_CACHE_V1, count) do
        matrix = SymTridiagonal(zeros(count), sqrt.(collect(1:count-1) ./ 2.0))
        decomposition = eigen(matrix)
        nodes = Vector{Float64}(decomposition.values)
        weights = sqrt(pi) .* Vector{Float64}(decomposition.vectors[1, :] .^ 2)
        (nodes, weights)
    end
end

"Landau-contour plasma dispersion function, evaluated by Gauss-Hermite quadrature."
function plasma_dispersion_function_v1(zeta::Complex, quadrature_count::Integer)
    z = ComplexF64(zeta)
    isfinite(real(z)) && isfinite(imag(z)) || return ComplexF64(Inf, Inf)
    nodes, weights = _aic_gauss_hermite_v1(Int(quadrature_count))
    real_axis_integral = sum(weights ./ (nodes .- z)) / sqrt(pi)
    if imag(z) > 0.0
        return real_axis_integral
    elseif imag(z) < 0.0
        return real_axis_integral + 2.0im * sqrt(pi) * exp(-z^2)
    end
    return real(real_axis_integral) + im * sqrt(pi) * exp(-real(z)^2)
end

plasma_dispersion_function_v1(zeta::Real, quadrature_count::Integer) =
    plasma_dispersion_function_v1(ComplexF64(zeta), quadrature_count)

function open_field_aic_dispersion_v1(problem::OpenFieldAICProblemV1,
        normalized_wavenumber::Real, normalized_frequency::Complex)
    q, z = Float64(normalized_wavenumber), ComplexF64(normalized_frequency)
    q > 0.0 || throw(ArgumentError("AIC normalized wavenumber must be positive"))
    abs(z) > 1.0e-14 || return ComplexF64(Inf, Inf)
    response = 0.0 + 0.0im
    for item in problem.species
        zeta0 = z / (q * item.parallel_thermal_to_alfven_ratio)
        zetas = (z - problem.polarization_sign * item.cyclotron_to_reference_ratio +
            im * item.collision_to_reference_cyclotron_ratio) /
            (q * item.parallel_thermal_to_alfven_ratio)
        plasma_z = plasma_dispersion_function_v1(zetas,
            problem.plasma_dispersion_quadrature_count)
        anisotropy = item.perpendicular_to_parallel_temperature_ratio
        kinetic_term = zeta0 * plasma_z + (anisotropy - 1.0) *
            (1.0 + zetas * plasma_z)
        response += item.plasma_to_reference_cyclotron_ratio_sq * kinetic_term / z^2
    end
    refractive = (problem.light_to_alfven_speed_ratio * q / z)^2
    return refractive - 1.0 - response
end

function _aic_rectangle_v1(real_bounds, growth_bounds, points::Int)
    r0, r1 = real_bounds; g0, g1 = growth_bounds
    bottom = ComplexF64.(range(r0, r1; length = points) .+ im * g0)
    right = ComplexF64.(r1 .+ im .* range(g0, g1; length = points)[2:end])
    top = ComplexF64.(range(r1, r0; length = points)[2:end] .+ im * g1)
    left = ComplexF64.(r0 .+ im .* range(g1, g0; length = points)[2:end-1])
    return vcat(bottom, right, top, left)
end

function _aic_contour_root_count_v1(problem::OpenFieldAICProblemV1, q::Float64,
        points::Int; boundary_tolerance::Float64 = 1.0e-8)
    contour = _aic_rectangle_v1(problem.root_real_bounds, problem.root_growth_bounds, points)
    values = [open_field_aic_dispersion_v1(problem, q, z) for z in contour]
    all(z -> isfinite(real(z)) && isfinite(imag(z)), values) || return 0, false, Inf, 0.0
    magnitudes = abs.(values)
    minimum(magnitudes) > boundary_tolerance || return 0, false, Inf, minimum(magnitudes)
    phases = angle.(values)
    changes = [atan(sin(phases[mod1(i + 1, length(phases))] - phases[i]),
        cos(phases[mod1(i + 1, length(phases))] - phases[i])) for i in eachindex(phases)]
    max_change = maximum(abs.(changes))
    count_float = sum(changes) / (2.0 * pi)
    count = round(Int, count_float)
    reliable = count >= 0 && abs(count_float - count) <= 5.0e-3 && max_change <= pi / 2.0
    return count, reliable, max_change, minimum(magnitudes)
end

function _aic_inside_root_box_v1(problem::OpenFieldAICProblemV1, z::Complex)
    return problem.root_real_bounds[1] < real(z) < problem.root_real_bounds[2] &&
        problem.root_growth_bounds[1] < imag(z) < problem.root_growth_bounds[2]
end

function _refine_aic_root_v1(problem::OpenFieldAICProblemV1, q::Float64, initial::Complex;
        tolerance::Float64 = 1.0e-9, max_iterations::Int = 80)
    z = ComplexF64(initial)
    for _ in 1:max_iterations
        value = open_field_aic_dispersion_v1(problem, q, z)
        isfinite(abs(value)) || return z, Inf, false
        abs(value) <= tolerance && return z, abs(value), _aic_inside_root_box_v1(problem, z)
        h = 1.0e-6 * max(abs(z), 1.0)
        derivative = (open_field_aic_dispersion_v1(problem, q, z + h) -
            open_field_aic_dispersion_v1(problem, q, z - h)) / (2.0 * h)
        abs(derivative) > 1.0e-14 || return z, abs(value), false
        step = value / derivative
        abs(step) > 0.5 && (step *= 0.5 / abs(step))
        accepted = false
        for damping in (1.0, 0.5, 0.25, 0.125, 0.0625)
            trial = z - damping * step
            if _aic_inside_root_box_v1(problem, trial)
                z = trial; accepted = true; break
            end
        end
        accepted || return z, abs(value), false
    end
    residual = abs(open_field_aic_dispersion_v1(problem, q, z))
    return z, residual, residual <= tolerance && _aic_inside_root_box_v1(problem, z)
end

function _aic_seed_grid_v1(problem::OpenFieldAICProblemV1)
    nr, ni = problem.root_seed_counts
    reals = range(problem.root_real_bounds[1], problem.root_real_bounds[2]; length = nr + 2)[2:end-1]
    imags = range(problem.root_growth_bounds[1], problem.root_growth_bounds[2]; length = ni + 2)[2:end-1]
    return ComplexF64[r + im * g for r in reals for g in imags]
end

function solve_open_field_aic_problem_v1(problem::OpenFieldAICProblemV1;
        root_tolerance::Real = 1.0e-8, boundary_tolerance::Real = 1.0e-8)
    if !problem.validity_domain_covered
        core = Dict("problem_hash" => problem.problem_hash, "status" => "unknown",
            "reason" => "validity_domain_not_covered")
        return OpenFieldAICObservationV1(problem.candidate_binding_hash,
            problem.state_result_hash, problem.resolution_id, :unknown, nothing, nothing,
            nothing, false, Int[], OpenFieldAICRootV1[], problem.problem_hash,
            canonical_hash(core))
    end
    roots = OpenFieldAICRootV1[]; contour_counts = Int[]; census_complete = true
    seeds = _aic_seed_grid_v1(problem)
    for q in problem.normalized_wavenumbers
        count1, reliable1, _, _ = _aic_contour_root_count_v1(problem, q,
            problem.contour_points_per_side; boundary_tolerance = Float64(boundary_tolerance))
        count2, reliable2, _, _ = _aic_contour_root_count_v1(problem, q,
            2 * problem.contour_points_per_side; boundary_tolerance = Float64(boundary_tolerance))
        push!(contour_counts, count2)
        local_roots = OpenFieldAICRootV1[]
        for seed in seeds
            z, residual, converged = _refine_aic_root_v1(problem, q, seed;
                tolerance = Float64(root_tolerance))
            converged || continue
            any(item -> abs(item.normalized_frequency - z) <= 1.0e-5, local_roots) && continue
            push!(local_roots, OpenFieldAICRootV1(q, z, residual, true))
        end
        census_complete &= reliable1 && reliable2 && count1 == count2 &&
            length(local_roots) == count2
        append!(roots, local_roots)
    end
    if !census_complete
        core = Dict("problem_hash" => problem.problem_hash, "status" => "unknown",
            "root_census_complete" => false, "contour_counts" => contour_counts,
            "found_root_count" => length(roots))
        return OpenFieldAICObservationV1(problem.candidate_binding_hash,
            problem.state_result_hash, problem.resolution_id, :unknown, nothing,
            isempty(roots) ? nothing : maximum(getfield.(roots, :dispersion_residual)),
            nothing, false, contour_counts, roots, problem.problem_hash, canonical_hash(core))
    end
    count = sum(contour_counts)
    growth = isempty(roots) ? 0.0 : maximum(imag(item.normalized_frequency) for item in roots)
    residual = isempty(roots) ? 0.0 : maximum(item.dispersion_residual for item in roots)
    status = count == 0 ? :pass : :fail
    core = Dict("problem_hash" => problem.problem_hash, "status" => String(status),
        "maximum_normalized_growth_rate" => growth, "maximum_dispersion_residual" => residual,
        "unstable_root_count" => count, "root_census_complete" => true,
        "contour_counts" => contour_counts,
        "roots" => [Dict("q" => r.normalized_wavenumber,
            "frequency" => Dict("real" => real(r.normalized_frequency),
                "imag" => imag(r.normalized_frequency)), "residual" => r.dispersion_residual)
            for r in roots])
    return OpenFieldAICObservationV1(problem.candidate_binding_hash,
        problem.state_result_hash, problem.resolution_id, status, growth, residual, count,
        true, contour_counts, roots, problem.problem_hash, canonical_hash(core))
end

function compile_open_field_aic_convergence_v1(observations::Vector{OpenFieldAICObservationV1};
        maximum_growth_change::Real)
    length(observations) >= 3 || throw(ArgumentError("AIC requires at least three resolutions"))
    bindings = unique((o.candidate_binding_hash, o.state_result_hash) for o in observations)
    length(bindings) == 1 || throw(ArgumentError("AIC observations must share bindings"))
    if any(o -> o.status == :unknown, observations)
        status = :unknown; favorable = nothing; growth = nothing; change = nothing
        count = nothing; verified = false
    else
        counts = getfield.(observations, :unstable_root_count)
        count_consistent = length(unique(counts)) == 1
        growths = Float64.(getfield.(observations, :maximum_normalized_growth_rate))
        change = maximum(abs.(diff(growths)))
        verified = count_consistent && all(getfield.(observations, :root_census_complete)) &&
            change <= Float64(maximum_growth_change)
        status = verified ? (counts[end] == 0 ? :pass : :fail) : :unknown
        favorable = verified ? status == :pass : nothing
        growth = verified ? growths[end] : nothing
        count = verified ? counts[end] : nothing
    end
    core = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_binding_hash" => observations[1].candidate_binding_hash,
        "state_result_hash" => observations[1].state_result_hash,
        "status" => String(status), "favorable" => favorable,
        "maximum_normalized_growth_rate" => growth, "maximum_growth_change" => change,
        "unstable_root_count" => count, "resolution_verified" => verified,
        "observation_hashes" => getfield.(observations, :observation_hash))
    return OpenFieldAICConvergenceV1(observations[1].candidate_binding_hash,
        observations[1].state_result_hash, status, favorable, growth, change, count,
        verified, copy(observations), canonical_hash(core))
end

function compile_aic_stage4_evidence_v2(problems::Vector{OpenFieldAICProblemV1},
        convergence::OpenFieldAICConvergenceV1;
        ion_distribution_verified::Bool, pressure_anisotropy_verified::Bool,
        beta_profile_verified::Bool, cyclotron_spectrum_verified::Bool,
        known_control_verified::Bool,
        registry::Vector{StabilityCapabilityContractV2} = default_stability_capability_registry_v2())
    length(problems) == length(convergence.observations) || throw(ArgumentError(
        "AIC problems and observations must be paired"))
    all(i -> problems[i].problem_hash == convergence.observations[i].problem_hash,
        eachindex(problems)) || throw(ArgumentError("AIC observation binding mismatch"))
    contract = only(filter(item -> item.operator_id == "alfven_ion_cyclotron_v2", registry))
    perturbation = StabilityPerturbationSpecV2("parallel_bimaxwellian_aic_v1",
        contract.operator_id;
        equations = ["N_parallel^2=epsilon_xx+i*epsilon_xy",
            "bi-Maxwellian kinetic susceptibility evaluated with the Landau plasma dispersion function"],
        state_input_ids = copy(contract.required_input_ids),
        boundary_conditions = ["uniform plasma; k parallel B; upper-half-plane root census",
            "finite-length mirror ends and nonlinear saturation excluded"],
        time_semantics = :eigenvalue, resolution_levels = getfield.(problems, :resolution_id),
        normalization = "frequency and growth normalized by the declared reference ion cyclotron frequency")
    history = Dict{String,Any}[Dict("resolution_id" => o.resolution_id,
        "problem_hash" => o.problem_hash, "maximum_normalized_growth_rate" =>
            o.maximum_normalized_growth_rate, "maximum_dispersion_residual" =>
            o.maximum_dispersion_residual, "unstable_root_count" => o.unstable_root_count,
        "root_census_complete" => o.root_census_complete,
        "contour_counts" => o.contour_counts) for o in convergence.observations]
    hash_by_path = Dict{String,String}()
    for p in problems, (path, hash) in zip(p.source_artifact_paths, p.source_artifact_hashes)
        hash_by_path[path] = hash
    end
    paths = sort!(collect(keys(hash_by_path))); hashes = [hash_by_path[p] for p in paths]
    gates = ion_distribution_verified && pressure_anisotropy_verified &&
        beta_profile_verified && cyclotron_spectrum_verified && known_control_verified
    covered = String[]
    ion_distribution_verified && push!(covered, "ion_distribution")
    pressure_anisotropy_verified && push!(covered, "pressure_anisotropy")
    beta_profile_verified && push!(covered, "beta_profile")
    cyclotron_spectrum_verified && push!(covered, "cyclotron_spectrum")
    favorable = gates && convergence.status != :unknown ? convergence.favorable : nothing
    margin = gates && convergence.maximum_normalized_growth_rate !== nothing ?
        problems[end].root_growth_bounds[1] - convergence.maximum_normalized_growth_rate : nothing
    return compile_stability_evidence_envelope_v2(convergence.candidate_binding_hash,
        convergence.state_result_hash, contract, perturbation; favorable,
        signed_normalized_margin = margin, convergence_history = history,
        validity_domain_covered = all(getfield.(problems, :validity_domain_covered)),
        resolution_verified = convergence.resolution_verified, covered_input_ids = covered,
        source_kind = :candidate_solver, source_artifact_paths = paths,
        source_artifact_hashes = hashes,
        source_result_hash = gates ? convergence.convergence_hash : "",
        candidate_binding_verified = true, claim_boundary = last(problems).claim_boundary)
end
