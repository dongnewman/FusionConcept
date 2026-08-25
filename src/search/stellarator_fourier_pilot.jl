"Configuration for the first bounded, evidence-acquisition stellarator pilot."
struct StellaratorFourierPilotConfig
    proposal_count::Int
    promotion_count::Int

    function StellaratorFourierPilotConfig(; proposal_count::Integer = 16,
            promotion_count::Integer = 4)
        4 <= proposal_count <= 64 ||
            throw(ArgumentError("proposal_count must be in 4..64"))
        1 <= promotion_count <= proposal_count ||
            throw(ArgumentError("promotion_count must be in 1..proposal_count"))
        return new(Int(proposal_count), Int(promotion_count))
    end
end

"One deterministic Halton proposal and its optional promotion rank."
struct StellaratorFourierPilotProposal
    pool_index::Int
    build_spec::StellaratorFourierBuildSpec
    genome::Genome
    normalized_parameters::Vector{Float64}
    promotion_rank::Union{Nothing,Int}
    acquisition_distance::Union{Nothing,Float64}
end

struct StellaratorFourierPilotPlan
    algorithm::String
    proposals::Vector{StellaratorFourierPilotProposal}
    promotion_count::Int
end

function _radical_inverse(index::Int, base::Int)
    index >= 1 || throw(ArgumentError("Halton index must be positive"))
    inverse = 1.0 / base
    factor = inverse
    value = 0.0
    current = index
    while current > 0
        value += (current % base) * factor
        current = div(current, base)
        factor *= inverse
    end
    return value
end

const _STELLARATOR_PILOT_BASES = (2, 3, 5, 7, 11, 13, 17, 19, 23)

function _stellarator_pilot_build_spec(index::Int)
    u = Float64[_radical_inverse(index, base)
        for base in _STELLARATOR_PILOT_BASES]
    field_periods = 2 + min(3, floor(Int, 4.0 * u[1]))
    aspect = 4.5 + 4.0 * u[2]
    minor_r = 0.5
    minor_z = 0.5 * (0.80 + 0.40 * u[3])
    major = aspect * sqrt(minor_r * minor_z)
    helical_r = minor_r * (0.12 + 0.43 * u[4])
    helical_z = minor_z * (0.12 + 0.43 * u[5])
    iota_axis = 0.30 + 0.45 * u[6]
    iota_edge = iota_axis - 0.05 + 0.30 * u[7]
    nominal_field = 1.20 + 1.30 * u[8]
    pressure_axis = 2500.0 + 12500.0 * u[9]
    spec = StellaratorFourierBuildSpec(
        field_periods = field_periods,
        major_radius_m = major,
        minor_radius_r_m = minor_r,
        minor_radius_z_m = minor_z,
        helical_axis_r_m = helical_r,
        helical_axis_z_m = helical_z,
        nominal_field_t = nominal_field,
        pressure_axis_pa = pressure_axis,
        iota_axis = iota_axis,
        iota_edge = iota_edge,
    )
    normalized = Float64[
        (field_periods - 2) / 3,
        u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9],
    ]
    return spec, normalized
end

_pilot_distance(left::Vector{Float64}, right::Vector{Float64}) =
    sqrt(sum((left .- right) .^ 2))

function _pilot_selection(parameters::Vector{Vector{Float64}},
        specs::Vector{StellaratorFourierBuildSpec}, count::Int)
    selected = Int[]
    distances = Dict{Int,Float64}()
    center = fill(0.5, length(first(parameters)))
    first_index = argmin([(_pilot_distance(item, center), index)
        for (index, item) in enumerate(parameters)])
    push!(selected, first_index)
    distances[first_index] = _pilot_distance(parameters[first_index], center)

    while length(selected) < count
        remaining = setdiff(collect(eachindex(parameters)), selected)
        represented = Set(specs[index].field_periods for index in selected)
        unrepresented = filter(index ->
            !(specs[index].field_periods in represented), remaining)
        eligible = !isempty(unrepresented) &&
            length(selected) < length(unique(getfield.(specs, :field_periods))) ?
            unrepresented : remaining
        scored = [(
            minimum(_pilot_distance(parameters[index], parameters[chosen])
                for chosen in selected),
            -index,
            index,
        ) for index in eligible]
        _, _, next_index = maximum(scored)
        push!(selected, next_index)
        distances[next_index] = minimum(
            _pilot_distance(parameters[next_index], parameters[chosen])
            for chosen in selected if chosen != next_index)
    end
    return selected, distances
end

"Generate a deterministic, space-filling acquisition plan without merit claims."
function plan_stellarator_fourier_pilot(parent::Genome;
        config::StellaratorFourierPilotConfig = StellaratorFourierPilotConfig())
    parent.family == "stellarator" ||
        throw(ArgumentError("stellarator pilot requires a stellarator parent"))
    specs = StellaratorFourierBuildSpec[]
    parameters = Vector{Float64}[]
    genomes = Genome[]
    for index in 1:config.proposal_count
        spec, normalized = _stellarator_pilot_build_spec(index)
        genome = build_stellarator_fourier_genome(parent, spec)
        push!(specs, spec)
        push!(parameters, normalized)
        push!(genomes, genome)
    end
    length(unique(getfield.(genomes, :physics_hash))) == length(genomes) ||
        error("stellarator pilot generated duplicate physics hashes")
    selected, distances = _pilot_selection(parameters, specs,
        config.promotion_count)
    ranks = Dict(index => rank for (rank, index) in enumerate(selected))
    proposals = StellaratorFourierPilotProposal[
        StellaratorFourierPilotProposal(index, specs[index], genomes[index],
            parameters[index], get(ranks, index, nothing),
            get(distances, index, nothing))
        for index in eachindex(genomes)
    ]
    return StellaratorFourierPilotPlan(
        "halton_v1_plus_field_period_stratified_greedy_maximin_v1",
        proposals, config.promotion_count)
end

function promoted_stellarator_fourier_proposals(plan::StellaratorFourierPilotPlan)
    selected = filter(item -> item.promotion_rank !== nothing, plan.proposals)
    return sort!(selected; by = item -> item.promotion_rank)
end

function stellarator_fourier_pilot_plan_to_dict(plan::StellaratorFourierPilotPlan)
    return Dict{String,Any}(
        "algorithm" => plan.algorithm,
        "claim_boundary" => "Space-filling evidence acquisition only; no score is predicted stability, transport, fusion output, engineering feasibility, simplicity, or device merit.",
        "proposal_count" => length(plan.proposals),
        "promotion_count" => plan.promotion_count,
        "parameter_chart" => Dict(
            "field_periods" => [2, 5],
            "geometric_aspect_ratio" => [4.5, 8.5],
            "minor_radius_r_m" => [0.5, 0.5],
            "minor_radius_z_m" => [0.4, 0.6],
            "helical_fraction_r" => [0.12, 0.55],
            "helical_fraction_z" => [0.12, 0.55],
            "iota_axis" => [0.30, 0.75],
            "iota_edge_minus_axis" => [-0.05, 0.25],
            "nominal_field_t" => [1.20, 2.50],
            "pressure_axis_pa" => [2500.0, 15000.0],
        ),
        "proposals" => [Dict{String,Any}(
            "pool_index" => item.pool_index,
            "design_id" => item.genome.design_id,
            "physics_hash" => item.genome.physics_hash,
            "field_periods" => item.build_spec.field_periods,
            "build_spec" => _stellarator_build_spec_dict(item.build_spec),
            "normalized_parameters" => item.normalized_parameters,
            "promotion_rank" => item.promotion_rank,
            "acquisition_distance" => item.acquisition_distance,
        ) for item in plan.proposals],
    )
end
