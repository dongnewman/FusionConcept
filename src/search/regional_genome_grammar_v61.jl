const _V61_CLAIM_BOUNDARY =
    "V61 adds explicit candidate-search genes for every declared region, interface and " *
    "region-targeted L1 actuator. The generated values enter the Genome physics hash. " *
    "They are candidate design hypotheses, not measurements or family defaults, and grant " *
    "no equilibrium, burn, engineering, net-power, VVUQ or promotion credit."

function _v61_unit(seed::String, ordinal::Integer)
    digest = canonical_hash(Dict("seed" => seed, "ordinal" => Int(ordinal)))
    raw = parse(UInt64, digest[1:13]; base = 16)
    return (Float64(raw) + 0.5) / Float64(UInt64(1) << 52)
end

_v61_q(value, unit, basis = "v61 explicit deterministic candidate search gene") =
    Dict{String,Any}("value" => Float64(value), "unit" => String(unit),
        "basis" => String(basis))

function _v61_total_volume(genome::Genome)
    contracts = genome.normalized["solver_ready_contracts"]
    magnetic = get(contracts, "magnetic_constraint", Dict{String,Any}())
    if get(magnetic, "applicable", false) === true
        boundary = magnetic["boundary"]
        major = Float64(boundary["major_radius_m"])
        minor = Float64(boundary["minor_radius_m"])
        elongation = Float64(boundary["elongation"])
        volume = 2.0 * pi^2 * major * minor^2 * elongation
        isfinite(volume) && volume > 0.0 && return volume,
            "finite_elongated_torus_solver_contract"
    end
    pulsed = get(contracts, "pulsed_device", Dict{String,Any}())
    if get(pulsed, "applicable", true) !== false && haskey(pulsed, "geometry")
        radius = Float64(pulsed["geometry"]["outer_radius_m"])
        volume = 4.0 * pi * radius^3 / 3.0
        isfinite(volume) && volume > 0.0 && return volume,
            "finite_spherical_pulsed_solver_contract"
    end
    values = Float64[]
    for region in genome.plasma_regions, (id, quantity) in region.parameters
        occursin("volume", lowercase(id)) && quantity.unit == "m^3" &&
            quantity.value > 0.0 && push!(values, Float64(quantity.value))
    end
    !isempty(values) && return sum(values), "sum_of_explicit_region_volumes"
    throw(ArgumentError("v61 requires a finite candidate-bound total geometry"))
end

function _v61_pressure(genome::Genome)
    magnetic = genome.normalized["solver_ready_contracts"]["magnetic_constraint"]
    if get(magnetic, "applicable", false) === true
        coefficients = magnetic["profiles"]["pressure"]["coefficients_pa"]
        value = maximum(abs.(Float64.(coefficients)); init = 0.0)
        value > 0.0 && return value
    end
    return nothing
end

function _v61_existing_density(raw_region)
    values = Float64[]
    for (id, quantity) in raw_region["parameters"]
        unit = String(get(quantity, "unit", ""))
        occursin("density", lowercase(String(id))) && unit in ("m^-3", "1/m^3") &&
            get(quantity, "value", 0.0) > 0.0 && push!(values, Float64(quantity["value"]))
    end
    return isempty(values) ? nothing : maximum(values)
end

function _v61_profile_integrals(profile, volume::Float64)
    density = profile["particle_density"]
    temperature = profile["temperature"]
    na = Float64(density["axis_value_m3"])
    ne = Float64(density["edge_value_m3"])
    ta = Float64(temperature["axis_value_ev"])
    te = Float64(temperature["edge_value_ev"])
    a = Float64(density["exponent"])
    b = Float64(temperature["exponent"])
    dn = na - ne
    dt = ta - te
    n_average = ne + dn / (a + 1.0)
    nt_average = ne * te + ne * dt / (b + 1.0) +
        te * dn / (a + 1.0) + dn * dt / (a + b + 1.0)
    return Dict{String,Float64}(
        "particle_inventory" => volume * n_average,
        "thermal_energy_j" => 3.0 * volume * nt_average * _CSR_V1_E_CHARGE)
end

function _v61_region_contracts!(raw, base::Genome, seed::String)
    regions = raw["plasma_regions"]
    count = length(regions)
    count > 0 || throw(ArgumentError("v61 candidate has no regions"))
    total_volume, volume_basis = _v61_total_volume(base)
    weights = Float64[0.05 + 0.95 * _v61_unit(seed * ":region_weight:$index", index)
        for index in 1:count]
    weights ./= sum(weights)
    pressure = _v61_pressure(base)
    records = Dict{String,Any}[]
    for (index, region) in enumerate(regions)
        region_id = String(region["id"])
        region_seed = seed * ":region:" * region_id
        volume = total_volume * weights[index]
        temperature_axis = 10.0^(2.0 + 2.4 * _v61_unit(region_seed, 1))
        temperature_edge = temperature_axis * (0.20 + 0.55 * _v61_unit(region_seed, 2))
        existing_density = _v61_existing_density(region)
        density_axis = if existing_density isa Real
            existing_density * (0.85 + 0.30 * _v61_unit(region_seed, 3))
        elseif pressure isa Real
            pressure / (2.0 * temperature_axis * _CSR_V1_E_CHARGE) *
                (0.70 + 0.60 * _v61_unit(region_seed, 3))
        else
            10.0^(18.0 + 5.0 * _v61_unit(region_seed, 3))
        end
        density_edge = density_axis * (0.25 + 0.55 * _v61_unit(region_seed, 4))
        density_exponent = 0.7 + 2.6 * _v61_unit(region_seed, 5)
        temperature_exponent = 0.7 + 2.6 * _v61_unit(region_seed, 6)
        profile = Dict{String,Any}(
            "schema_version" => "1.0.0",
            "coordinate" => "normalized_volume",
            "basis" => "edge_plus_axis_power_v1",
            "particle_density" => Dict("axis_value_m3" => density_axis,
                "edge_value_m3" => density_edge, "exponent" => density_exponent,
                "unit" => "m^-3"),
            "temperature" => Dict("axis_value_ev" => temperature_axis,
                "edge_value_ev" => temperature_edge,
                "exponent" => temperature_exponent, "unit" => "eV"),
            "integration_measure" => "dV=region_volume*d(normalized_volume)",
            "generation_basis" => "explicit deterministic candidate search coordinates")
        mesh = Dict{String,Any}(
            "kind" => "finite_volume",
            "coordinate" => "normalized_volume",
            "declared_levels" => [32, 64],
            "cell_measure" => "equal_normalized_volume",
            "region_volume_m3" => volume,
            "volume_basis" => volume_basis)
        integrals = _v61_profile_integrals(profile, volume)
        push!(records, Dict("region_id" => region_id, "volume_m3" => volume,
            "partition_weight" => weights[index], "mesh" => mesh,
            "state_profile" => deepcopy(profile),
            "analytic_integrals" => integrals))
    end
    return records
end

function _v61_interface_contracts!(raw, region_records, seed::String)
    by_region = Dict(String(item["region_id"]) => item for item in region_records)
    records = Dict{String,Any}[]
    for (index, edge) in enumerate(raw["flux_connections"])
        from_id = String(edge["from_region_id"])
        to_id = String(edge["to_region_id"])
        from_volume = Float64(by_region[from_id]["volume_m3"])
        to_volume = Float64(by_region[to_id]["volume_m3"])
        edge_seed = seed * ":interface:$index:$from_id:$to_id"
        area = min(from_volume, to_volume)^(2.0 / 3.0) *
            (0.15 + 0.85 * _v61_unit(edge_seed, 1))
        characteristic_speed = 10.0^(1.0 + 4.0 * _v61_unit(edge_seed, 2))
        particle_transfer = area * characteristic_speed *
            (0.02 + 0.18 * _v61_unit(edge_seed, 3))
        energy_transfer = particle_transfer *
            (0.35 + 1.30 * _v61_unit(edge_seed, 4))
        interface_id = "v61_interface_$(lpad(index, 4, '0'))_$(from_id)_to_$(to_id)"
        boundary_conditions = Any[
            Dict("account" => "particle", "condition" => "two_sided_continuity"),
            Dict("account" => "energy", "condition" => "two_sided_continuity"),
            Dict("account" => "radiation", "condition" => "not_applicable",
                "applicability_basis" => "L1 material interface has no declared radiation exchange"),
            Dict("account" => "electromagnetic", "condition" => "not_applicable",
                "applicability_basis" => "L1 state layout has no interface electromagnetic account")]
        operator_contract = Dict{String,Any}(
            "capability" => "region_interface_conservative_transport",
            "operator_id" => "finite_volume_two_point_flux_v1",
            "provided_flux_accounts" => ["particle", "energy"],
            "requires" => ["region_volume", "particle_inventory", "thermal_energy"],
            "jacobian_provider" => "analytic_two_point_flux_jacobian_v1",
            "sign_convention" => "positive_from_upstream_to_downstream",
            "time_modes" => ["steady", "transient", "pulsed"],
            "validity" => Dict("minimum_volume_m3" => min(from_volume, to_volume),
                "positive_state_required" => true),
            "generation_basis" => "candidate-search interface coefficients; no family routing")
        push!(records, Dict("interface_id" => interface_id,
            "from_region_id" => from_id, "to_region_id" => to_id,
            "kind" => edge["kind"], "area_m2" => area,
            "area_unit" => "m^2", "transfer_volume_unit" => "m^3/s",
            "boundary_conditions" => boundary_conditions,
            "particle_transfer_volume_m3_s" => particle_transfer,
            "energy_transfer_volume_m3_s" => energy_transfer,
            "operator_contract" => operator_contract))
    end
    return records
end

function _v61_actuator!(raw, id, kind, target, capability, demand, unit, seed, ordinal)
    oversize = 1.05 + 0.90 * _v61_unit(seed * ":actuator:$id", ordinal)
    capacity = demand * oversize
    efficiency = 0.35 + 0.55 * _v61_unit(seed * ":efficiency:$id", ordinal)
    operator_contract = Dict("operator_id" => "bounded_regional_actuator_v1",
        "capacity_jacobian_provider" => "analytic_box_constraint_jacobian_v1",
        "output_distribution" => "uniform_over_target_region_volume",
        "capacity_design_basis" => "generation-time constrained sizing, not runtime expansion")
    return Dict{String,Any}("actuator_id" => id, "target_region_id" => target,
        "kind" => kind, "target_region_ids" => [target],
        "capability" => capability, "capabilities" => [capability],
        "demand" => demand, "capacity" => capacity,
        "unit" => unit, "wall_plug_efficiency" => efficiency,
        "deposition_efficiency" => 0.92 + 0.07 * _v61_unit(seed, ordinal + 20),
        "response_time_s" => 1.0e-4 + 0.05 * _v61_unit(seed, ordinal + 40),
        "oversize_factor" => oversize, "operator_contract" => operator_contract)
end

function _v61_region_components(raw)
    ids = String[String(region["id"]) for region in raw["plasma_regions"]]
    adjacency = Dict(id => String[] for id in ids)
    for edge in raw["flux_connections"]
        from = String(edge["from_region_id"])
        to = String(edge["to_region_id"])
        push!(adjacency[from], to); push!(adjacency[to], from)
    end
    roots = Dict{String,String}()
    for id in ids
        haskey(roots, id) && continue
        component = String[]
        queue = [id]
        while !isempty(queue)
            node = popfirst!(queue)
            node in component && continue
            push!(component, node)
            append!(queue, adjacency[node])
        end
        root = first(component)
        for node in component
            roots[node] = root
        end
    end
    return roots
end

function _v61_positive_demand_scales(region_records, interface_records, pending,
        components, account::String; minimum_relative_state::Float64 = 0.10)
    ids = String[String(item["region_id"]) for item in region_records]
    region_index = Dict(id => index for (index, id) in enumerate(ids))
    count = length(ids)
    coefficient_key = account == "particle" ? "particle_transfer_volume_m3_s" :
        "energy_transfer_volume_m3_s"
    inventory_key = account == "particle" ? "particle_inventory" : "thermal_energy_j"
    laplacian = zeros(Float64, count, count)
    for item in interface_records
        i = region_index[String(item["from_region_id"])]
        j = region_index[String(item["to_region_id"])]
        coefficient = Float64(item[coefficient_key])
        laplacian[i, i] += coefficient; laplacian[i, j] -= coefficient
        laplacian[j, i] -= coefficient; laplacian[j, j] += coefficient
    end
    volumes = Float64[Float64(item["volume_m3"]) for item in region_records]
    inventories = Float64[Float64(item["analytic_integrals"][inventory_key])
        for item in region_records]
    scales = Dict{String,Float64}()
    for root in unique(values(components))
        component = Int[region_index[id] for id in ids if components[id] == root]
        local_pending = [item for item in pending if item["component_root"] == root]
        isempty(local_pending) && continue
        source = zeros(Float64, count)
        for item in local_pending
            demand = Float64(item[account])
            source[region_index[String(item["source_region_id"])]] += demand
            source[region_index[String(item["exhaust_region_id"])]] -= demand
        end
        n = length(component)
        local_laplacian = laplacian[component, component]
        operator_scale = max(maximum(abs, local_laplacian; init = 1.0), 1.0)
        volume_scale = sum(volumes[component])
        augmented = zeros(Float64, n + 1, n + 1)
        augmented[1:n, 1:n] .= local_laplacian ./ operator_scale
        augmented[1:n, n + 1] .= 1.0
        augmented[n + 1, 1:n] .= volumes[component] ./ volume_scale
        deviation = (augmented \ vcat(source[component] ./ operator_scale, 0.0))[1:n]
        reference = sum(inventories[component]) / volume_scale
        admissible = 1.0
        for value in deviation
            value < 0.0 || continue
            admissible = min(admissible,
                (1.0 - minimum_relative_state) * reference / (-value))
        end
        scales[root] = clamp(admissible, 0.0, 1.0)
    end
    return scales
end

function _v61_actuator_contracts!(raw, region_records, interface_records, seed::String)
    by_region = Dict(String(item["region_id"]) => item for item in region_records)
    components = _v61_region_components(raw)
    exhaust_ids = unique(String.(raw["exhaust"]["region_ids"]))
    isempty(exhaust_ids) && (exhaust_ids = [String(last(raw["plasma_regions"])["id"])])
    pending = Dict{String,Any}[]
    for (index, region_id) in enumerate(exhaust_ids)
        integrals = by_region[region_id]["analytic_integrals"]
        volume = Float64(by_region[region_id]["volume_m3"])
        component_root = components[region_id]
        component_records = [item for item in region_records if
            components[String(item["region_id"])] == component_root]
        component_particle_floor = minimum(Float64(item["analytic_integrals"]["particle_inventory"]) /
            Float64(item["volume_m3"]) for item in component_records)
        component_energy_floor = minimum(Float64(item["analytic_integrals"]["thermal_energy_j"]) /
            Float64(item["volume_m3"]) for item in component_records)
        incident = [item for item in interface_records if
            item["from_region_id"] == region_id || item["to_region_id"] == region_id]
        particle_capacity = sum(Float64(item["particle_transfer_volume_m3_s"])
            for item in incident; init = 0.0) * component_particle_floor
        energy_capacity = sum(Float64(item["energy_transfer_volume_m3_s"])
            for item in incident; init = 0.0) * component_energy_floor
        extraction_fraction = 1.0e-5 + 9.0e-5 *
            _v61_unit(seed * ":boundary_extraction_fraction:$region_id", index)
        particle = extraction_fraction * particle_capacity
        energy = extraction_fraction * energy_capacity
        source_region = component_root
        push!(pending, Dict{String,Any}("ordinal" => index,
            "exhaust_region_id" => region_id, "source_region_id" => source_region,
            "component_root" => component_root, "extraction_fraction" => extraction_fraction,
            "particle" => particle, "energy" => energy))
    end
    particle_scales = _v61_positive_demand_scales(region_records, interface_records,
        pending, components, "particle")
    energy_scales = _v61_positive_demand_scales(region_records, interface_records,
        pending, components, "energy")
    demands = Dict{String,Any}[]
    for item in pending
        index = Int(item["ordinal"])
        region_id = String(item["exhaust_region_id"])
        source_region = String(item["source_region_id"])
        component_root = String(item["component_root"])
        extraction_fraction = Float64(item["extraction_fraction"])
        particle_scale = particle_scales[component_root]
        energy_scale = energy_scales[component_root]
        particle = Float64(item["particle"]) * particle_scale
        energy = Float64(item["energy"]) * energy_scale
        push!(demands, _v61_actuator!(raw, "v61_particle_exhaust_$index",
            "other", region_id, "particle_exhaust", particle, "1/s", seed, 4index - 3))
        push!(demands, _v61_actuator!(raw, "v61_radiation_control_$index",
            "other", region_id, "radiation_control", energy, "W", seed, 4index - 2))
        push!(demands, _v61_actuator!(raw, "v61_particle_source_$index", "fueling",
            source_region, "particle_source", particle, "1/s", seed, 4index - 1))
        push!(demands, _v61_actuator!(raw, "v61_energy_source_$index", "other",
            source_region, "deposited_energy_source", energy, "W", seed, 4index))
        for (offset, record) in enumerate(demands[(end - 3):end])
            feasibility_scale = isodd(offset) ? particle_scale : energy_scale
            record["requested_interface_capacity_fraction"] = extraction_fraction
            record["positive_state_feasibility_scale"] = feasibility_scale
            record["effective_interface_capacity_fraction"] =
                extraction_fraction * feasibility_scale
            record["minimum_relative_steady_state"] = 0.10
            record["source_sink_component_root"] = source_region
        end
    end
    return demands
end

function generate_regional_solver_genome_v61(base::Genome, module_ids,
        sample_ordinal::Integer)
    raw = deepcopy(base.normalized)
    seed = canonical_hash(Dict("base_physics_hash" => base.physics_hash,
        "module_ids" => String.(module_ids), "sample_ordinal" => Int(sample_ordinal),
        "generator" => "regional_genome_grammar_v61"))
    region_records = _v61_region_contracts!(raw, base, seed)
    interface_records = _v61_interface_contracts!(raw, region_records, seed)
    actuator_records = _v61_actuator_contracts!(raw, region_records,
        interface_records, seed)
    contract = Dict{String,Any}(
        "schema_version" => "1.0.0", "generation_stage" => "before_common_screen",
        "generator_id" => "regional_genome_grammar_v61",
        "routing_basis" => "declared regions, interfaces, units and capabilities only",
        "family_label_used" => false, "region_records" => region_records,
        "interface_records" => interface_records,
        "actuator_sizing_records" => actuator_records,
        "forbidden_methods" => ["equal_region_split", "default_volume_fraction",
            "runtime_capacity_expansion", "family_template"])
    contract["contract_hash"] = canonical_hash(contract)
    raw["regional_solver_contract_v1"] = contract
    provenance = raw["provenance"]
    _v18_push_unique!(provenance["notes"], ["regional_genome_grammar_v61",
        "region/interface/actuator genes generated before common screening",
        "no validation parent, equal split, default volume fraction or family routing"])
    raw["design_id"] = "pending_regional_solver_v61"
    provisional = parse_genome(raw)
    raw["design_id"] = "v61_$(canonical_hash(module_ids)[1:12])_s$(lpad(Int(sample_ordinal), 6, '0'))_" *
        provisional.physics_hash[1:12]
    result = parse_genome(raw)
    result.physics_hash != base.physics_hash || error("v61 regional genes did not enter physics hash")
    return result
end

function evaluate_regional_solver_candidate_v61(
        context::RecoverableCrossTopologyContextV20, candidate_index::Integer;
        halton_skip::Integer = 4096)
    base = evaluate_solver_ready_candidate_v54(context, candidate_index;
        halton_skip = halton_skip)
    old = base.prescreen.compiled
    regional = generate_regional_solver_genome_v61(old.genome, old.module_ids,
        base.sample_ordinal)
    report = validate_genome(regional)
    report.valid || throw(ArgumentError("generated v61 genome invalid: " *
        join(report.errors, "; ")))
    compiled = CompiledAttributeGenomeV18(old.assembly_id, old.graph_hash, old.family,
        old.mission_contract_id, copy(old.module_ids), regional, old.evaluator_id,
        old.projection_id, sort!(unique(vcat(old.projection_limitations,
            ["explicit region/interface/actuator L1 genes added by v61"]))),
        copy(old.declared_requirements), sort!(unique(vcat(old.validation_warnings,
            report.warnings))))
    prescreen = _v18_prescreen(compiled, context.evaluators, context.evaluator_registry)
    return CrossTopologyCandidateV20(Int(candidate_index), base.assembly_index,
        base.sample_ordinal, prescreen)
end

function regional_solver_contract_audit_v61(genome::Genome)
    contract = get(genome.normalized, "regional_solver_contract_v1", nothing)
    errors = String[]
    contract isa AbstractDict || push!(errors, "regional_solver_contract_v1 missing")
    if contract isa AbstractDict
        get(contract, "generation_stage", "") == "before_common_screen" ||
            push!(errors, "regional contract was not generated before screening")
        get(contract, "family_label_used", true) === false ||
            push!(errors, "family label used in regional generation")
        length(get(contract, "region_records", Any[])) == length(genome.plasma_regions) ||
            push!(errors, "region record count mismatch")
        length(get(contract, "interface_records", Any[])) == length(genome.flux_connections) ||
            push!(errors, "interface record count mismatch")
        expected = get(contract, "contract_hash", "")
        body = Dict{String,Any}(String(key) => deepcopy(value) for (key, value) in contract
            if String(key) != "contract_hash")
        expected == canonical_hash(body) || push!(errors, "regional contract hash mismatch")
    end
    return Dict{String,Any}("status" => isempty(errors) ? "ready" : "invalid",
        "errors" => sort!(unique(errors)),
        "contract_hash" => contract isa AbstractDict ?
            get(contract, "contract_hash", nothing) : nothing)
end
