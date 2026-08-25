function _csr_v5_midpoint_integrals(profile, volume::Float64, cells::Int)
    density = profile["particle_density"]
    temperature = profile["temperature"]
    na = Float64(density["axis_value_m3"])
    ne = Float64(density["edge_value_m3"])
    ta = Float64(temperature["axis_value_ev"])
    te = Float64(temperature["edge_value_ev"])
    a = Float64(density["exponent"])
    b = Float64(temperature["exponent"])
    particle = 0.0
    energy = 0.0
    for index in 1:cells
        s = (index - 0.5) / cells
        n = ne + (na - ne) * (1.0 - s)^a
        t = te + (ta - te) * (1.0 - s)^b
        particle += n
        energy += 3.0 * n * t * _CSR_V1_E_CHARGE
    end
    return Dict{String,Float64}("particle_inventory" => volume * particle / cells,
        "thermal_energy" => volume * energy / cells)
end

function _csr_v5_region_volume(raw_region::AbstractDict)
    mesh = get(raw_region, "mesh", Dict{String,Any}())
    mesh_volume = get(mesh, "region_volume_m3", nothing)
    mesh_volume isa Real && isfinite(mesh_volume) && mesh_volume > 0.0 &&
        return Float64(mesh_volume)
    matches = Float64[Float64(quantity["value"])
        for (id, quantity) in get(raw_region, "parameters", Dict{String,Any}())
        if occursin("volume", lowercase(String(id))) &&
            get(quantity, "unit", "") == "m^3" &&
            get(quantity, "value", 0.0) isa Real &&
            isfinite(quantity["value"]) && quantity["value"] > 0.0]
    return length(matches) == 1 ? only(matches) : nothing
end

"Compile explicit v61 region profiles at every manifest resolution."
function compile_region_state_specs_v2(genome::Genome, manifest::CandidateSolveManifestV1)
    specs = RegionStateSpecV1[]
    levels = sort!(unique(manifest.discretization_levels))
    regional_contract = genome.normalized["regional_solver_contract_v1"]
    declared_regions = Dict(String(item["region_id"]) => item
        for item in regional_contract["region_records"])
    for region in genome.plasma_regions
        declaration = declared_regions[region.id]
        volume = get(declaration, "volume_m3", nothing)
        missing = String[]
        volume isa Real || push!(missing, "missing_explicit_finite_region_geometry")
        profile = get(declaration, "state_profile", Dict{String,Any}())
        get(profile, "coordinate", "") == "normalized_volume" ||
            push!(missing, "missing_normalized_volume_profile_coordinate")
        get(profile, "basis", "") == "edge_plus_axis_power_v1" ||
            push!(missing, "missing_supported_explicit_profile_basis")
        haskey(profile, "particle_density") || push!(missing, "missing_particle_density_profile")
        haskey(profile, "temperature") || push!(missing, "missing_temperature_profile")
        level_integrals = Dict{String,Any}[]
        if isempty(missing)
            for level in levels
                values = _csr_v5_midpoint_integrals(profile, volume, level)
                push!(level_integrals, Dict("level" => level,
                    "particle_inventory" => values["particle_inventory"],
                    "thermal_energy" => values["thermal_energy"]))
            end
        end
        initial = isempty(level_integrals) ? Dict{String,Any}() : Dict{String,Any}(
            "particle_inventory" => last(level_integrals)["particle_inventory"],
            "thermal_energy" => last(level_integrals)["thermal_energy"])
        positive = all(value -> value isa Real && isfinite(value) && value > 0.0,
            values(initial)) && length(initial) == 2
        positive || isempty(missing) && push!(missing, "nonpositive_or_nonfinite_profile_integral")
        status = isempty(missing) ? "complete" : volume === nothing ? "unsupported" : "unknown"
        mesh = deepcopy(get(declaration, "mesh", Dict{String,Any}()))
        mesh["requested_levels"] = levels
        mesh["level_integrals"] = level_integrals
        mesh["profile_quadrature"] = "cell_center_midpoint_finite_volume"
        state_variables = Dict{String,Any}[
            Dict("state_id" => "particle_inventory", "unit" => "1", "positivity" => true),
            Dict("state_id" => "thermal_energy", "unit" => "J", "positivity" => true)]
        accounts = Dict{String,Any}[
            Dict("account" => "particle", "state_id" => "particle_inventory"),
            Dict("account" => "energy", "state_id" => "thermal_energy")]
        applicability = Dict{String,Any}("status" => status,
            "missing_requirements" => sort!(unique(missing)),
            "derivations" => [Dict("state_id" => "particle_inventory",
                "method" => "finite_volume_quadrature_of_explicit_density_profile"),
                Dict("state_id" => "thermal_energy",
                    "method" => "finite_volume_quadrature_of_explicit_density_temperature_profiles")],
            "routing_basis" => "region-local mesh, profile basis and units only",
            "forbidden_partition_methods" => ["equal_region_split",
                "default_volume_fraction", "family_template"])
        body = _csr_v4_region_spec_body(; manifest, region, mesh, volume,
            state_variables, initial_conditions = initial, conservation_accounts = accounts,
            applicability, evidence_ceiling = status == "complete" ?
                "L1_explicit_profile_finite_volume_state" : "none_missing_region_evidence")
        safe = _csr_v1_json_safe(body)
        push!(specs, RegionStateSpecV1(safe["schema_version"], safe["candidate_id"],
            safe["physics_hash"], safe["manifest_hash"], safe["region_id"],
            safe["geometry_model"], safe["mesh"], safe["volume_m3"],
            safe["state_variables"], safe["initial_conditions"],
            safe["conservation_accounts"], safe["applicability"],
            safe["evidence_ceiling"], canonical_hash(safe)))
    end
    return specs
end

"Compile the explicit interface area, BC, operator and analytic Jacobian declarations."
function compile_interface_flux_contracts_v2(genome::Genome,
        manifest::CandidateSolveManifestV1, specs::Vector{RegionStateSpecV1})
    spec_status = Dict(spec.region_id => String(spec.applicability["status"]) for spec in specs)
    contracts = InterfaceFluxContractV1[]
    regional_contract = genome.normalized["regional_solver_contract_v1"]
    for connection in regional_contract["interface_records"]
        from_region_id = String(connection["from_region_id"])
        to_region_id = String(connection["to_region_id"])
        area = get(connection, "area_m2", nothing)
        particle = get(connection, "particle_transfer_volume_m3_s", nothing)
        energy = get(connection, "energy_transfer_volume_m3_s", nothing)
        operator = get(connection, "operator_contract", Dict{String,Any}())
        missing = String[]
        area isa Real && area > 0.0 || push!(missing, "missing_explicit_interface_area")
        particle isa Real && particle > 0.0 || push!(missing, "missing_particle_flux_coefficient")
        energy isa Real && energy > 0.0 || push!(missing, "missing_energy_flux_coefficient")
        get(operator, "operator_id", "") == "finite_volume_two_point_flux_v1" ||
            push!(missing, "missing_supported_region_flux_operator")
        get(operator, "jacobian_provider", "") ==
            "analytic_two_point_flux_jacobian_v1" ||
            push!(missing, "missing_region_scoped_flux_jacobian")
        spec_status[from_region_id] == "complete" ||
            push!(missing, "upstream_region_state_incomplete")
        spec_status[to_region_id] == "complete" ||
            push!(missing, "downstream_region_state_incomplete")
        status = isempty(missing) ? "complete" : "unsupported"
        provider = Dict{String,Any}("status" => status,
            "operator_id" => get(operator, "operator_id", ""),
            "particle_transfer_volume_m3_s" => particle,
            "energy_transfer_volume_m3_s" => energy,
            "provided_flux_accounts" => get(operator, "provided_flux_accounts", Any[]))
        jacobian = Dict{String,Any}("status" => status,
            "provider_id" => get(operator, "jacobian_provider", ""),
            "structure" => "two_by_two_conservative_laplacian_block_per_account")
        body = Dict{String,Any}("schema_version" => "1.0.0",
            "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
            "manifest_hash" => manifest.manifest_hash,
            "interface_id" => String(connection["interface_id"]),
            "from_region_id" => from_region_id,
            "to_region_id" => to_region_id, "kind" => String(connection["kind"]),
            "interface_area_m2" => area,
            "flux_slots" => [Dict("account" => "particle", "unit" => "1/s"),
                Dict("account" => "energy", "unit" => "W")],
            "sign_convention" => get(operator, "sign_convention",
                "positive_from_upstream_to_downstream"),
            "boundary_conditions" => deepcopy(get(connection, "boundary_conditions", Any[])),
            "flux_provider" => provider, "jacobian_provider" => jacobian,
            "applicability" => Dict("status" => status,
                "missing_requirements" => sort!(unique(missing)),
                "routing_basis" => "declared endpoints, interface parameters and operator contract only"),
            "evidence_ceiling" => status == "complete" ?
                "L1_analytic_conservative_interface_flux" : "none_missing_interface_evidence")
        safe = _csr_v1_json_safe(body)
        push!(contracts, InterfaceFluxContractV1(safe["schema_version"],
            safe["candidate_id"], safe["physics_hash"], safe["manifest_hash"],
            safe["interface_id"], safe["from_region_id"], safe["to_region_id"],
            safe["kind"], safe["interface_area_m2"], safe["flux_slots"],
            safe["sign_convention"], safe["boundary_conditions"],
            safe["flux_provider"], safe["jacobian_provider"], safe["applicability"],
            safe["evidence_ceiling"], canonical_hash(safe)))
    end
    return contracts
end

function _csr_v5_actuator_realization(genome::Genome, account::String)
    contract = genome.normalized["regional_solver_contract_v1"]
    records = Dict{String,Any}[]
    sources = Dict{String,Float64}()
    missing = String[]
    shortfalls = String[]
    evidence_unknown = String[]
    for item in contract["actuator_sizing_records"]
        capability = String(item["capability"])
        is_particle = capability in ("particle_source", "particle_exhaust")
        (account == "particle") == is_particle || continue
        demand = Float64(item["demand"])
        capacity = Float64(item["capacity"])
        efficiency = get(item, "wall_plug_efficiency", nothing)
        actual = min(demand, capacity)
        target = String(item["target_region_id"])
        sign = capability in ("particle_source", "deposited_energy_source") ? 1.0 : -1.0
        sources[target] = get(sources, target, 0.0) + sign * actual
        capacity <= 0.0 && push!(missing, "$(item["actuator_id"]) has no capacity")
        capacity + max(demand, 1.0) * 1.0e-12 < demand &&
            push!(shortfalls, "$(item["actuator_id"]) capacity shortfall")
        efficiency isa Real && 0.0 < efficiency <= 1.0 ||
            push!(evidence_unknown, "$(item["actuator_id"]) efficiency missing")
        record = Dict{String,Any}("actuator_id" => item["actuator_id"],
            "target_region_id" => target, "capability" => capability,
            "demand" => demand, "capacity" => capacity, "actual_output" => actual,
            "demand_realization_error" => demand - actual,
            "unit" => item["unit"], "wall_plug_efficiency" => efficiency,
            "status" => capacity < demand ? "fail_capacity_shortfall" :
                efficiency isa Real ? "numerically_realized" :
                "unknown_missing_efficiency_evidence")
        record["output_hash"] = canonical_hash(record)
        push!(records, record)
    end
    status = !isempty(shortfalls) ? :fail : !isempty(missing) ? :unsupported :
        !isempty(evidence_unknown) ? :unknown : :pass
    return sources, records, status, vcat(missing, shortfalls, evidence_unknown)
end

function _csr_v5_laplacian(specs, interfaces, account::String)
    region_index = Dict(spec.region_id => index for (index, spec) in enumerate(specs))
    count = length(specs)
    matrix = zeros(Float64, count, count)
    for interface in interfaces
        i = region_index[interface.from_region_id]
        j = region_index[interface.to_region_id]
        key = account == "particle" ? "particle_transfer_volume_m3_s" :
            "energy_transfer_volume_m3_s"
        coefficient = Float64(interface.flux_provider[key])
        matrix[i, i] += coefficient
        matrix[i, j] -= coefficient
        matrix[j, i] -= coefficient
        matrix[j, j] += coefficient
    end
    return matrix, region_index
end

function _csr_v5_steady_state(specs, interfaces, sources, account::String,
        initial_state::Vector{Float64})
    laplacian, region_index = _csr_v5_laplacian(specs, interfaces, account)
    count = length(specs)
    volumes = Float64[spec.volume_m3 for spec in specs]
    source = Float64[get(sources, spec.region_id, 0.0) for spec in specs]
    density = zeros(Float64, count)
    density_deviation = zeros(Float64, count)
    density_reference = zeros(Float64, count)
    unvisited = Set(1:count)
    while !isempty(unvisited)
        root = first(unvisited)
        component = Int[]
        queue = [root]
        while !isempty(queue)
            node = popfirst!(queue)
            node in component && continue
            push!(component, node); delete!(unvisited, node)
            for neighbor in 1:count
                neighbor == node && continue
                abs(laplacian[node, neighbor]) > 0.0 &&
                    !(neighbor in component) && push!(queue, neighbor)
            end
        end
        n = length(component)
        augmented = zeros(Float64, n + 1, n + 1)
        local_laplacian = laplacian[component, component]
        operator_scale = maximum(abs, local_laplacian; init = 1.0)
        operator_scale = max(operator_scale, 1.0)
        volume_scale = sum(volumes[component])
        augmented[1:n, 1:n] .= local_laplacian ./ operator_scale
        augmented[1:n, n + 1] .= 1.0
        augmented[n + 1, 1:n] .= volumes[component] ./ volume_scale
        component_inventory = sum(initial_state[component])
        # Solve only the zero-volume-mean deviation.  Adding the large common
        # density inside the linear solve makes small interface gradients lose
        # significant digits when inventories are later divided by volume.
        # The graph Laplacian annihilates the component reference density, so
        # this centered representation is algebraically identical and keeps
        # the flux-producing part of the state independently auditable.
        rhs = vcat(source[component] ./ operator_scale, 0.0)
        solution = augmented \ rhs
        reference = component_inventory / volume_scale
        density_deviation[component] .= solution[1:n]
        density_reference[component] .= reference
        density[component] .= reference .+ solution[1:n]
    end
    return density .* volumes, laplacian, source, region_index,
        density_deviation, density_reference
end

function _csr_v5_resolution_error(specs, account::String)
    length(first(specs).mesh["level_integrals"]) >= 2 || return Inf
    coarse = sum(Float64(first(spec.mesh["level_integrals"])[account]) for spec in specs)
    fine = sum(Float64(last(spec.mesh["level_integrals"])[account]) for spec in specs)
    return abs(fine - coarse) / max(abs(fine), 1.0)
end

"Solve the explicit L1 regional steady balance and audit all three pre-full-search gates."
function solve_region_partition_v2(manifest::CandidateSolveManifestV1,
        specs::Vector{RegionStateSpecV1}, interfaces::Vector{InterfaceFluxContractV1},
        genome::Genome)
    complete = !isempty(specs) && all(spec -> spec.applicability["status"] == "complete", specs) &&
        all(item -> item.applicability["status"] == "complete", interfaces)
    complete || return solve_region_partition_v1(manifest, specs, interfaces)
    particle_sources, particle_outputs, particle_actuator_status, particle_reasons =
        _csr_v5_actuator_realization(genome, "particle")
    energy_sources, energy_outputs, energy_actuator_status, energy_reasons =
        _csr_v5_actuator_realization(genome, "energy")
    actuator_status = :fail in (particle_actuator_status, energy_actuator_status) ? :fail :
        :unsupported in (particle_actuator_status, energy_actuator_status) ? :unsupported :
        :unknown in (particle_actuator_status, energy_actuator_status) ? :unknown : :pass
    initial_particle = Float64[spec.initial_conditions["particle_inventory"] for spec in specs]
    initial_energy = Float64[spec.initial_conditions["thermal_energy"] for spec in specs]
    particle_state, particle_laplacian, particle_source, region_index,
        particle_deviation, particle_reference =
        _csr_v5_steady_state(specs, interfaces, particle_sources, "particle", initial_particle)
    energy_state, energy_laplacian, energy_source, _, energy_deviation, energy_reference =
        _csr_v5_steady_state(specs, interfaces, energy_sources, "energy", initial_energy)
    positive = all(isfinite, particle_state) && all(isfinite, energy_state) &&
        all(>(0.0), particle_state) && all(>(0.0), energy_state)
    tolerance = manifest.numerical_tolerances["normalized_residual"]
    regional_residuals = Dict{String,Any}[]
    region_trajectories = Dict{String,Any}[]
    for (index, spec) in enumerate(specs)
        push!(region_trajectories, Dict("region_id" => spec.region_id,
            "time_samples_s" => [0.0], "complete" => true,
            "final_state" => Dict("particle_inventory" => particle_state[index],
                "thermal_energy" => energy_state[index]),
            "centered_solver_state" => Dict(
                "particle_density_reference" => particle_reference[index],
                "particle_density_deviation" => particle_deviation[index],
                "energy_density_reference" => energy_reference[index],
                "energy_density_deviation" => energy_deviation[index])))
        for (account, deviation, laplacian, source) in (("particle", particle_deviation,
                particle_laplacian, particle_source),
                ("energy", energy_deviation, energy_laplacian, energy_source))
            volumes = Float64[item.volume_m3 for item in specs]
            divergence = (laplacian * deviation)[index]
            residual = divergence - source[index]
            coefficient_key = account == "particle" ?
                "particle_transfer_volume_m3_s" : "energy_transfer_volume_m3_s"
            incident_scale = 0.0
            for interface in interfaces
                i = region_index[interface.from_region_id]
                j = region_index[interface.to_region_id]
                index in (i, j) || continue
                coefficient = Float64(interface.flux_provider[coefficient_key])
                incident_scale += abs(coefficient *
                    (deviation[i] - deviation[j]))
            end
            normalization = max(incident_scale + abs(source[index]), 1.0)
            push!(regional_residuals, Dict("region_id" => spec.region_id,
                "account" => account, "dU_dt" => 0.0, "divergence_F" => divergence,
                "source_S" => source[index], "normalization" => normalization,
                "normalized_residual" => abs(residual) / normalization))
        end
    end
    paired = Dict{String,Any}[]
    volumes = Float64[spec.volume_m3 for spec in specs]
    for interface in interfaces
        i = region_index[interface.from_region_id]
        j = region_index[interface.to_region_id]
        for (account, deviation, key, unit) in (("particle", particle_deviation,
                "particle_transfer_volume_m3_s", "1/s"),
                ("energy", energy_deviation, "energy_transfer_volume_m3_s", "W"))
            coefficient = Float64(interface.flux_provider[key])
            flux = coefficient * (deviation[i] - deviation[j])
            push!(paired, Dict("interface_id" => interface.interface_id,
                "account" => account, "unit" => unit, "upstream_flux" => flux,
                "downstream_flux" => -flux, "pair_closure_error" => 0.0))
        end
    end
    max_residual = maximum(Float64[item["normalized_residual"]
        for item in regional_residuals]; init = 0.0)
    pair_error = maximum(abs(Float64(item["upstream_flux"]) +
        Float64(item["downstream_flux"])) for item in paired; init = 0.0)
    conservation_pass = positive && max_residual <= tolerance && pair_error <= tolerance
    particle_error = _csr_v5_resolution_error(specs, "particle_inventory")
    energy_error = _csr_v5_resolution_error(specs, "thermal_energy")
    resolution_error = max(particle_error, energy_error)
    resolution_tolerance = manifest.numerical_tolerances["relative_resolution"]
    resolution_pass = isfinite(resolution_error) && resolution_error <= resolution_tolerance
    gates = Dict{String,Any}(
        "regional_conservation" => Dict("status" => conservation_pass ? "pass" : "fail",
            "maximum_normalized_residual" => max_residual,
            "maximum_interface_pair_error" => pair_error,
            "positive_state" => positive),
        "actuator_realization" => Dict("status" => String(actuator_status),
            "outputs" => vcat(particle_outputs, energy_outputs),
            "maximum_demand_realization_error" => maximum(abs(Float64(item["demand_realization_error"]))
                for item in vcat(particle_outputs, energy_outputs); init = 0.0)),
        "resolution_convergence" => Dict("status" => resolution_pass ? "pass" : "fail",
            "particle_relative_error" => particle_error,
            "energy_relative_error" => energy_error,
            "tolerance" => resolution_tolerance))
    all_pass = conservation_pass && actuator_status == :pass && resolution_pass
    status = all_pass ? :pass : !conservation_pass || actuator_status == :fail ||
        !resolution_pass ? :fail : actuator_status
    global_residuals = Dict{String,Any}[
        Dict("account" => "particle", "dU_dt" => 0.0,
            "divergence_F" => sum((particle_laplacian * particle_deviation)),
            "source_S" => sum(particle_source), "normalization" =>
                max(sum(abs, particle_source), 1.0)),
        Dict("account" => "energy", "dU_dt" => 0.0,
            "divergence_F" => sum((energy_laplacian * energy_deviation)),
            "source_S" => sum(energy_source), "normalization" =>
                max(sum(abs, energy_source), 1.0))]
    reasons = vcat(particle_reasons, energy_reasons)
    !positive && push!(reasons, "regional steady solve produced a nonpositive state")
    body = _csr_v4_result_body(; manifest, status,
        convergence_status = all_pass ? "regional_actuator_and_resolution_gates_converged" :
            "regional_gate_failure", specs, interfaces, region_trajectories,
        paired_interface_fluxes = paired, regional_residuals, global_residuals,
        resolution = Dict("levels" => manifest.discretization_levels,
            "method" => "finite_volume_profile_quadrature_and_linear_steady_balance",
            "relative_error" => resolution_error),
        error_estimates = Dict("maximum_normalized_regional_residual" => max_residual,
            "maximum_interface_pair_error" => pair_error,
            "relative_resolution_error" => resolution_error), gate_statuses = gates,
        unresolved_reasons = sort!(unique(reasons)),
        evidence_ceiling = "L1_explicit_regional_control_volume_balance")
    safe = _csr_v1_json_safe(body)
    return RegionSolveResultEnvelopeV1(safe["schema_version"], safe["candidate_id"],
        safe["physics_hash"], safe["manifest_hash"], status, safe["convergence_status"],
        safe["region_spec_hashes"], safe["interface_contract_hashes"],
        safe["region_trajectories"], safe["paired_interface_fluxes"],
        safe["regional_residuals"], safe["global_residuals"], safe["resolution"],
        safe["error_estimates"], safe["gate_statuses"], safe["unresolved_reasons"],
        safe["evidence_ceiling"], canonical_hash(safe))
end
