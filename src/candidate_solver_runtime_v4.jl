const _CSR_V4_ALLOWED_STATUS = Set([:pass, :fail, :unknown, :unsupported])

"A hash-sealed, region-local state declaration. Missing values are never synthesized."
struct RegionStateSpecV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    region_id::String
    geometry_model::String
    mesh::Dict{String,Any}
    volume_m3::Union{Nothing,Float64}
    state_variables::Vector{Dict{String,Any}}
    initial_conditions::Dict{String,Any}
    conservation_accounts::Vector{Dict{String,Any}}
    applicability::Dict{String,Any}
    evidence_ceiling::String
    spec_hash::String
end

"A directed interface contract whose flux is positive from upstream to downstream."
struct InterfaceFluxContractV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    interface_id::String
    from_region_id::String
    to_region_id::String
    kind::String
    interface_area_m2::Union{Nothing,Float64}
    flux_slots::Vector{Dict{String,Any}}
    sign_convention::String
    boundary_conditions::Vector{Dict{String,Any}}
    flux_provider::Dict{String,Any}
    jacobian_provider::Dict{String,Any}
    applicability::Dict{String,Any}
    evidence_ceiling::String
    contract_hash::String
end

"Regional trajectories, paired interface fluxes and the three pre-full-search gates."
struct RegionSolveResultEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    status::Symbol
    convergence_status::String
    region_spec_hashes::Vector{String}
    interface_contract_hashes::Vector{String}
    region_trajectories::Vector{Dict{String,Any}}
    paired_interface_fluxes::Vector{Dict{String,Any}}
    regional_residuals::Vector{Dict{String,Any}}
    global_residuals::Vector{Dict{String,Any}}
    resolution::Dict{String,Any}
    error_estimates::Dict{String,Any}
    gate_statuses::Dict{String,Any}
    unresolved_reasons::Vector{String}
    evidence_ceiling::String
    result_hash::String
end

function _csr_v4_status_text(value)
    text = String(value)
    text in ("complete", "pass") && return :pass
    text == "fail" && return :fail
    text == "unsupported" && return :unsupported
    return :unknown
end

function _csr_v4_quantity(region::PlasmaRegion, predicate, units)
    matches = Tuple{String,Quantity}[]
    for (id, quantity) in region.parameters
        predicate(lowercase(String(id))) || continue
        quantity.unit in units || continue
        isfinite(quantity.value) && push!(matches, (String(id), quantity))
    end
    length(matches) == 1 || return nothing
    return only(matches)
end

function _csr_v4_volume(region::PlasmaRegion)
    explicit = _csr_v4_quantity(region, id -> occursin("volume", id), ("m^3",))
    if explicit !== nothing && explicit[2].value > 0.0
        return Float64(explicit[2].value), Dict{String,Any}(
            "method" => "explicit_region_volume", "source_parameter_ids" => [explicit[1]])
    end
    model = lowercase(region.geometry_model)
    radius = _csr_v4_quantity(region,
        id -> id in ("radius", "plasma_radius", "minor_radius"), ("m",))
    length_value = _csr_v4_quantity(region,
        id -> id in ("length", "cell_length"), ("m",))
    half_length = _csr_v4_quantity(region,
        id -> id in ("half_length", "half_height"), ("m",))
    if any(token -> occursin(token, model), ("cylinder", "flux_tube", "linear")) &&
            radius !== nothing && (length_value !== nothing || half_length !== nothing)
        axial = length_value === nothing ? 2.0 * half_length[2].value : length_value[2].value
        volume = pi * radius[2].value^2 * axial
        if isfinite(volume) && volume > 0.0
            ids = [radius[1], length_value === nothing ? half_length[1] : length_value[1]]
            return volume, Dict{String,Any}("method" => "finite_cylindrical_geometry_integral",
                "source_parameter_ids" => ids)
        end
    end
    major = _csr_v4_quantity(region, ==("major_radius"), ("m",))
    minor = _csr_v4_quantity(region, ==("minor_radius"), ("m",))
    elongation = _csr_v4_quantity(region, ==("elongation"), ("1",))
    if occursin("tor", model) && major !== nothing && minor !== nothing && elongation !== nothing
        volume = 2.0 * pi^2 * major[2].value * minor[2].value^2 * elongation[2].value
        if isfinite(volume) && volume > 0.0
            return volume, Dict{String,Any}("method" => "finite_elongated_torus_geometry_integral",
                "source_parameter_ids" => [major[1], minor[1], elongation[1]])
        end
    end
    return nothing, Dict{String,Any}("method" => "unresolved_no_explicit_finite_geometry",
        "source_parameter_ids" => String[])
end

function _csr_v4_region_initial_conditions(region::PlasmaRegion, volume)
    values = Dict{String,Any}()
    derivations = Dict{String,Any}[]
    inventory = _csr_v4_quantity(region,
        id -> occursin("particle_inventory", id) || id == "inventory", ("1",))
    density = _csr_v4_quantity(region,
        id -> occursin("density", id), ("m^-3", "1/m^3"))
    if inventory !== nothing && inventory[2].value >= 0.0
        values["particle_inventory"] = Float64(inventory[2].value)
        push!(derivations, Dict("state_id" => "particle_inventory",
            "method" => "explicit_region_inventory", "source_parameter_ids" => [inventory[1]]))
    elseif density !== nothing && volume isa Real && density[2].value >= 0.0
        values["particle_inventory"] = Float64(density[2].value * volume)
        push!(derivations, Dict("state_id" => "particle_inventory",
            "method" => "finite_geometry_density_integral",
            "source_parameter_ids" => [density[1]]))
    end
    thermal = _csr_v4_quantity(region,
        id -> occursin("thermal_energy", id) || id == "stored_energy", ("J",))
    pressure = _csr_v4_quantity(region, id -> occursin("pressure", id), ("Pa",))
    temperature = _csr_v4_quantity(region, id -> occursin("temperature", id),
        ("J", "eV", "keV", "MeV"))
    if thermal !== nothing && thermal[2].value >= 0.0
        values["thermal_energy"] = Float64(thermal[2].value)
        push!(derivations, Dict("state_id" => "thermal_energy",
            "method" => "explicit_region_stored_energy", "source_parameter_ids" => [thermal[1]]))
    elseif pressure !== nothing && volume isa Real && pressure[2].value >= 0.0
        values["thermal_energy"] = 1.5 * Float64(pressure[2].value * volume)
        push!(derivations, Dict("state_id" => "thermal_energy",
            "method" => "finite_geometry_pressure_integral", "source_parameter_ids" => [pressure[1]]))
    elseif temperature !== nothing && haskey(values, "particle_inventory")
        energy = _csr_v3_energy_j(temperature[2].value, temperature[2].unit)
        if energy isa Real && energy >= 0.0
            values["thermal_energy"] = 3.0 * values["particle_inventory"] * energy
            push!(derivations, Dict("state_id" => "thermal_energy",
                "method" => "explicit_temperature_particle_integral",
                "source_parameter_ids" => [temperature[1]]))
        end
    end
    return values, derivations
end

function _csr_v4_region_spec_body(; manifest, region, mesh, volume, state_variables,
        initial_conditions, conservation_accounts, applicability, evidence_ceiling)
    return Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "manifest_hash" => manifest.manifest_hash, "region_id" => region.id,
        "geometry_model" => region.geometry_model, "mesh" => mesh,
        "volume_m3" => volume, "state_variables" => state_variables,
        "initial_conditions" => initial_conditions,
        "conservation_accounts" => conservation_accounts,
        "applicability" => applicability, "evidence_ceiling" => evidence_ceiling)
end

function region_state_spec_to_dict_v1(spec::RegionStateSpecV1)
    return Dict{String,Any}("schema_version" => spec.schema_version,
        "candidate_id" => spec.candidate_id, "physics_hash" => spec.physics_hash,
        "manifest_hash" => spec.manifest_hash, "region_id" => spec.region_id,
        "geometry_model" => spec.geometry_model, "mesh" => spec.mesh,
        "volume_m3" => spec.volume_m3, "state_variables" => spec.state_variables,
        "initial_conditions" => spec.initial_conditions,
        "conservation_accounts" => spec.conservation_accounts,
        "applicability" => spec.applicability, "evidence_ceiling" => spec.evidence_ceiling,
        "spec_hash" => spec.spec_hash)
end

"Compile every declared region through one rule; no family or completeness branch exists."
function compile_region_state_specs_v1(genome::Genome, manifest::CandidateSolveManifestV1)
    specs = RegionStateSpecV1[]
    levels = sort!(unique(manifest.discretization_levels))
    for region in genome.plasma_regions
        volume, geometry_record = _csr_v4_volume(region)
        initial, derivations = _csr_v4_region_initial_conditions(region, volume)
        missing = String[]
        volume isa Real || push!(missing, "missing_explicit_finite_region_geometry")
        for id in ("particle_inventory", "thermal_energy")
            haskey(initial, id) || push!(missing, "missing_explicit_region_$id")
        end
        status = volume === nothing ? "unsupported" : isempty(missing) ? "complete" : "unknown"
        mesh = Dict{String,Any}("kind" => "finite_volume",
            "requested_levels" => levels,
            "geometry_integration" => geometry_record,
            "cell_count_source" => "CandidateSolveManifestV1.discretization_levels")
        state_variables = Dict{String,Any}[
            Dict("state_id" => "particle_inventory", "unit" => "1", "positivity" => true),
            Dict("state_id" => "thermal_energy", "unit" => "J", "positivity" => true)]
        accounts = Dict{String,Any}[
            Dict("account" => "particle", "state_id" => "particle_inventory"),
            Dict("account" => "energy", "state_id" => "thermal_energy")]
        applicability = Dict{String,Any}("status" => status,
            "missing_requirements" => sort!(unique(missing)),
            "derivations" => derivations,
            "routing_basis" => "region-local geometry, profiles and declared units only",
            "forbidden_partition_methods" => ["equal_region_split", "default_volume_fraction",
                "family_template"])
        body = _csr_v4_region_spec_body(; manifest, region, mesh, volume,
            state_variables, initial_conditions = initial, conservation_accounts = accounts,
            applicability, evidence_ceiling = status == "complete" ?
                "region_local_finite_volume_initial_state" : "none_missing_region_evidence")
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

function _csr_v4_interface_area(from::PlasmaRegion, to::PlasmaRegion)
    matches = Tuple{String,Quantity}[]
    for region in (from, to), (id, quantity) in region.parameters
        key = lowercase(String(id))
        occursin("interface", key) && occursin("area", key) && quantity.unit == "m^2" &&
            isfinite(quantity.value) && quantity.value > 0.0 &&
            push!(matches, ("$(region.id):$(id)", quantity))
    end
    length(matches) == 1 || return nothing, String[]
    return Float64(only(matches)[2].value), [only(matches)[1]]
end

function interface_flux_contract_to_dict_v1(contract::InterfaceFluxContractV1)
    return Dict{String,Any}("schema_version" => contract.schema_version,
        "candidate_id" => contract.candidate_id, "physics_hash" => contract.physics_hash,
        "manifest_hash" => contract.manifest_hash, "interface_id" => contract.interface_id,
        "from_region_id" => contract.from_region_id, "to_region_id" => contract.to_region_id,
        "kind" => contract.kind, "interface_area_m2" => contract.interface_area_m2,
        "flux_slots" => contract.flux_slots, "sign_convention" => contract.sign_convention,
        "boundary_conditions" => contract.boundary_conditions,
        "flux_provider" => contract.flux_provider,
        "jacobian_provider" => contract.jacobian_provider,
        "applicability" => contract.applicability,
        "evidence_ceiling" => contract.evidence_ceiling,
        "contract_hash" => contract.contract_hash)
end

"Compile directed internal interfaces. A global transport operator is not an interface provider."
function compile_interface_flux_contracts_v1(genome::Genome,
        manifest::CandidateSolveManifestV1, specs::Vector{RegionStateSpecV1})
    regions = Dict(region.id => region for region in genome.plasma_regions)
    spec_status = Dict(spec.region_id => String(spec.applicability["status"]) for spec in specs)
    contracts = InterfaceFluxContractV1[]
    for (index, edge) in enumerate(genome.flux_connections)
        from = get(regions, edge.from_region_id, nothing)
        to = get(regions, edge.to_region_id, nothing)
        area, area_sources = from === nothing || to === nothing ? (nothing, String[]) :
            _csr_v4_interface_area(from, to)
        scoped = Dict{String,Any}[]
        for binding in manifest.module_bindings
            String(get(binding, "from_region_id", "")) == edge.from_region_id || continue
            String(get(binding, "to_region_id", "")) == edge.to_region_id || continue
            push!(scoped, binding)
        end
        flux_provider = isempty(scoped) ? Dict{String,Any}(
            "status" => "unsupported", "reason" => "missing_region_scoped_flux_provider") :
            Dict{String,Any}("status" => "complete", "bindings" => scoped)
        jacobian = isempty(scoped) || !all(binding ->
            !isempty(String(get(binding, "jacobian_provider", ""))), scoped) ?
            Dict{String,Any}("status" => "unsupported",
                "reason" => "missing_region_scoped_flux_jacobian") :
            Dict{String,Any}("status" => "complete",
                "providers" => String[String(binding["jacobian_provider"]) for binding in scoped])
        missing = String[]
        from === nothing && push!(missing, "unknown_upstream_region")
        to === nothing && push!(missing, "unknown_downstream_region")
        area isa Real || push!(missing, "missing_explicit_interface_area")
        get(flux_provider, "status", "") == "complete" ||
            push!(missing, "missing_region_scoped_flux_provider")
        get(jacobian, "status", "") == "complete" ||
            push!(missing, "missing_region_scoped_flux_jacobian")
        get(spec_status, edge.from_region_id, "unsupported") == "complete" ||
            push!(missing, "upstream_region_state_incomplete")
        get(spec_status, edge.to_region_id, "unsupported") == "complete" ||
            push!(missing, "downstream_region_state_incomplete")
        status = isempty(missing) ? "complete" : "unsupported"
        body = Dict{String,Any}("schema_version" => "1.0.0",
            "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
            "manifest_hash" => manifest.manifest_hash,
            "interface_id" => "interface_$(lpad(index, 4, '0'))_$(edge.from_region_id)_to_$(edge.to_region_id)",
            "from_region_id" => edge.from_region_id, "to_region_id" => edge.to_region_id,
            "kind" => edge.kind, "interface_area_m2" => area,
            "flux_slots" => [Dict("account" => "particle", "unit" => "1/s"),
                Dict("account" => "energy", "unit" => "W"),
                Dict("account" => "radiation", "unit" => "W"),
                Dict("account" => "electromagnetic", "unit" => "W")],
            "sign_convention" => "positive_from_upstream_to_downstream; downstream contribution is the exact negative",
            "boundary_conditions" => Dict{String,Any}[], "flux_provider" => flux_provider,
            "jacobian_provider" => jacobian,
            "applicability" => Dict("status" => status,
                "missing_requirements" => sort!(unique(missing)),
                "interface_area_source_parameter_ids" => area_sources,
                "routing_basis" => "declared endpoints, scope, units and operator capabilities only"),
            "evidence_ceiling" => status == "complete" ?
                "region_scoped_interface_operator" : "none_missing_interface_evidence")
        safe = _csr_v1_json_safe(body)
        push!(contracts, InterfaceFluxContractV1(safe["schema_version"], safe["candidate_id"],
            safe["physics_hash"], safe["manifest_hash"], safe["interface_id"],
            safe["from_region_id"], safe["to_region_id"], safe["kind"],
            safe["interface_area_m2"], safe["flux_slots"], safe["sign_convention"],
            safe["boundary_conditions"], safe["flux_provider"], safe["jacobian_provider"],
            safe["applicability"], safe["evidence_ceiling"], canonical_hash(safe)))
    end
    return contracts
end

function _csr_v4_result_body(; manifest, status, convergence_status, specs, interfaces,
        region_trajectories, paired_interface_fluxes, regional_residuals, global_residuals,
        resolution, error_estimates, gate_statuses, unresolved_reasons, evidence_ceiling)
    return Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "manifest_hash" => manifest.manifest_hash, "status" => String(status),
        "convergence_status" => convergence_status,
        "region_spec_hashes" => String[spec.spec_hash for spec in specs],
        "interface_contract_hashes" => String[item.contract_hash for item in interfaces],
        "region_trajectories" => region_trajectories,
        "paired_interface_fluxes" => paired_interface_fluxes,
        "regional_residuals" => regional_residuals, "global_residuals" => global_residuals,
        "resolution" => resolution, "error_estimates" => error_estimates,
        "gate_statuses" => gate_statuses, "unresolved_reasons" => unresolved_reasons,
        "evidence_ceiling" => evidence_ceiling)
end

function region_solve_result_to_dict_v1(result::RegionSolveResultEnvelopeV1)
    body = Dict{String,Any}("schema_version" => result.schema_version,
        "candidate_id" => result.candidate_id, "physics_hash" => result.physics_hash,
        "manifest_hash" => result.manifest_hash, "status" => String(result.status),
        "convergence_status" => result.convergence_status,
        "region_spec_hashes" => result.region_spec_hashes,
        "interface_contract_hashes" => result.interface_contract_hashes,
        "region_trajectories" => result.region_trajectories,
        "paired_interface_fluxes" => result.paired_interface_fluxes,
        "regional_residuals" => result.regional_residuals,
        "global_residuals" => result.global_residuals, "resolution" => result.resolution,
        "error_estimates" => result.error_estimates, "gate_statuses" => result.gate_statuses,
        "unresolved_reasons" => result.unresolved_reasons,
        "evidence_ceiling" => result.evidence_ceiling, "result_hash" => result.result_hash)
    return body
end

"Apply the strict ordering: regional conservation first; actuator and resolution cannot pre-pass it."
function solve_region_partition_v1(manifest::CandidateSolveManifestV1,
        specs::Vector{RegionStateSpecV1}, interfaces::Vector{InterfaceFluxContractV1})
    reasons = String[]
    for spec in specs
        for reason in String.(get(spec.applicability, "missing_requirements", String[]))
            push!(reasons, "region $(spec.region_id): $reason")
        end
    end
    for interface in interfaces
        for reason in String.(get(interface.applicability, "missing_requirements", String[]))
            push!(reasons, "interface $(interface.interface_id): $reason")
        end
    end
    region_complete = !isempty(specs) && all(spec ->
        String(spec.applicability["status"]) == "complete", specs)
    interface_complete = all(item -> String(item.applicability["status"]) == "complete",
        interfaces)
    enough_levels = length(unique(manifest.discretization_levels)) >= 2
    gates = Dict{String,Any}(
        "regional_conservation" => Dict("status" => region_complete && interface_complete ?
            "unknown" : "unsupported", "reason" => region_complete && interface_complete ?
                "numerical_region_operator_execution_not_yet_available" :
                "region_or_interface_contract_incomplete"),
        "actuator_realization" => Dict("status" => "not_evaluated",
            "reason" => "blocked_until_regional_conservation_passes"),
        "resolution_convergence" => Dict("status" => enough_levels ? "not_evaluated" : "unsupported",
            "reason" => enough_levels ? "blocked_until_regional_conservation_passes" :
                "requires_at_least_two_declared_resolution_levels"))
    status = any(spec -> String(spec.applicability["status"]) == "unsupported", specs) ||
        any(item -> String(item.applicability["status"]) == "unsupported", interfaces) ?
        :unsupported : :unknown
    convergence = status == :unsupported ? "not_run_incomplete_region_or_interface_contract" :
        "not_run_region_operator_execution_pending"
    resolution = Dict{String,Any}("levels" => sort!(unique(manifest.discretization_levels)),
        "status" => String(gates["resolution_convergence"]["status"]),
        "cross_level_error" => nothing)
    body = _csr_v4_result_body(; manifest, status, convergence_status = convergence,
        specs, interfaces, region_trajectories = Dict{String,Any}[],
        paired_interface_fluxes = Dict{String,Any}[], regional_residuals = Dict{String,Any}[],
        global_residuals = Dict{String,Any}[], resolution,
        error_estimates = Dict{String,Any}(), gate_statuses = gates,
        unresolved_reasons = sort!(unique(reasons)),
        evidence_ceiling = "protocol_compilation_only_no_regional_solve")
    safe = _csr_v1_json_safe(body)
    hash = canonical_hash(safe)
    return RegionSolveResultEnvelopeV1(safe["schema_version"], safe["candidate_id"],
        safe["physics_hash"], safe["manifest_hash"], status, safe["convergence_status"],
        safe["region_spec_hashes"], safe["interface_contract_hashes"],
        safe["region_trajectories"], safe["paired_interface_fluxes"],
        safe["regional_residuals"], safe["global_residuals"], safe["resolution"],
        safe["error_estimates"], safe["gate_statuses"], safe["unresolved_reasons"],
        safe["evidence_ceiling"], hash)
end

function region_full_search_gate_passes_v1(result::RegionSolveResultEnvelopeV1)
    return all(id -> String(get(result.gate_statuses[id], "status", "")) == "pass",
        ("regional_conservation", "actuator_realization", "resolution_convergence"))
end
