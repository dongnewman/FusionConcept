const CANDIDATE_SOLVE_STATUS_V1 = Set([:pass, :fail, :unknown, :unsupported])

"A family-neutral, capability-routed numerical input contract."
struct CandidateSolveManifestV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    regions::Vector{Dict{String,Any}}
    mesh::Dict{String,Any}
    state_variables::Vector{Dict{String,Any}}
    capability_declarations::Vector{Dict{String,Any}}
    module_bindings::Vector{Dict{String,Any}}
    boundaries::Vector{Dict{String,Any}}
    sources_sinks::Vector{Dict{String,Any}}
    time_mode::String
    initial_conditions::Dict{String,Float64}
    numerical_tolerances::Dict{String,Float64}
    discretization_levels::Vector{Int}
    required_outputs::Vector{String}
    applicability_scope::Dict{String,Any}
    parameters::Dict{String,Any}
    manifest_hash::String
end

"Hash-sealed result contract shared by candidate-selected numerical operators."
struct SolverResultEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    input_hash::String
    software_hash::String
    container_hash::String
    status::Symbol
    convergence_status::String
    residual_history::Vector{Dict{String,Any}}
    state_trajectory::Dict{String,Any}
    conservation_slots::Vector{Dict{String,Any}}
    resolution::Dict{String,Any}
    error_estimates::Dict{String,Any}
    module_results::Vector{Dict{String,Any}}
    evidence_ceiling::String
    unsupported_reasons::Vector{String}
    result_hash::String
end

abstract type AbstractCandidatePhysicsModuleV1 end

"A candidate-bound numerical operator selected only from declared capabilities."
struct CandidatePhysicsModuleV1 <: AbstractCandidatePhysicsModuleV1
    module_id::String
    capability_id::String
    operator_id::String
    state_ids::Vector{String}
    parameters::Dict{String,Any}
end

solver_capability(physics_module::CandidatePhysicsModuleV1) = physics_module.capability_id
state_layout(physics_module::CandidatePhysicsModuleV1, manifest::CandidateSolveManifestV1) =
    [item for item in manifest.state_variables if String(item["state_id"]) in physics_module.state_ids]
applicability(physics_module::CandidatePhysicsModuleV1, manifest::CandidateSolveManifestV1) =
    Dict{String,Any}("status" => "applicable", "capability_id" => physics_module.capability_id,
        "operator_id" => physics_module.operator_id, "manifest_hash" => manifest.manifest_hash)

const _CSR_V1_E_CHARGE = 1.602176634e-19
const _CSR_V1_AMU = 1.66053906660e-27
const _CSR_V1_DT_FUSION_J = 17.6e6 * _CSR_V1_E_CHARGE
const _CSR_V1_DT_ALPHA_J = 3.5e6 * _CSR_V1_E_CHARGE

function _csr_v1_plain_dict(value)
    value isa AbstractDict || return Dict{String,Any}()
    return Dict{String,Any}(String(key) => _plain_json(item) for (key, item) in value)
end

function _csr_v1_json_safe(value)
    if value isa AbstractDict
        return Dict{String,Any}(String(key) => _csr_v1_json_safe(item)
            for (key, item) in value)
    elseif value isa AbstractVector
        return Any[_csr_v1_json_safe(item) for item in value]
    elseif value isa AbstractFloat && !isfinite(value)
        return nothing
    end
    return _plain_json(value)
end

function _csr_v1_manifest_body(; schema_version, candidate_id, physics_hash, regions,
        mesh, state_variables, capability_declarations, module_bindings, boundaries,
        sources_sinks, time_mode, initial_conditions, numerical_tolerances,
        discretization_levels, required_outputs, applicability_scope, parameters)
    return Dict{String,Any}(
        "schema_version" => schema_version, "candidate_id" => candidate_id,
        "physics_hash" => physics_hash, "regions" => regions, "mesh" => mesh,
        "state_variables" => state_variables,
        "capability_declarations" => capability_declarations,
        "module_bindings" => module_bindings, "boundaries" => boundaries,
        "sources_sinks" => sources_sinks, "time_mode" => time_mode,
        "initial_conditions" => initial_conditions,
        "numerical_tolerances" => numerical_tolerances,
        "discretization_levels" => discretization_levels,
        "required_outputs" => required_outputs,
        "applicability_scope" => applicability_scope, "parameters" => parameters)
end

function CandidateSolveManifestV1(; candidate_id, physics_hash, regions,
        mesh = Dict{String,Any}("kind" => "control_volume", "cell_count" => 1),
        state_variables, capability_declarations, module_bindings, boundaries = Dict{String,Any}[],
        sources_sinks = Dict{String,Any}[], time_mode = "transient", initial_conditions,
        numerical_tolerances = Dict("normalized_residual" => 1.0e-4,
            "steady_time_term" => 1.0e-4, "relative_resolution" => 5.0e-2),
        discretization_levels = [32],
        required_outputs = ["state_trajectory", "conservation_slots", "observables"],
        applicability_scope = Dict{String,Any}(), parameters = Dict{String,Any}())
    length(String(physics_hash)) == 64 || throw(ArgumentError(
        "CandidateSolveManifestV1 requires a sha256-sized physics_hash"))
    levels = sort!(unique(Int.(discretization_levels)))
    !isempty(levels) && all(>(1), levels) || throw(ArgumentError(
        "CandidateSolveManifestV1 discretization levels must exceed one"))
    mode = String(time_mode)
    mode in ("steady", "transient", "pulsed") || throw(ArgumentError(
        "unsupported CandidateSolveManifestV1 time mode $mode"))
    states = Dict{String,Any}[_csr_v1_plain_dict(item) for item in state_variables]
    state_ids = String[String(item["state_id"]) for item in states]
    length(unique(state_ids)) == length(state_ids) || throw(ArgumentError(
        "CandidateSolveManifestV1 state IDs must be unique"))
    initial = Dict{String,Float64}(String(key) => Float64(value)
        for (key, value) in initial_conditions)
    all(id -> haskey(initial, id), state_ids) || throw(ArgumentError(
        "CandidateSolveManifestV1 initial conditions must cover every state"))
    capabilities = Dict{String,Any}[_csr_v1_plain_dict(item)
        for item in capability_declarations]
    bindings = Dict{String,Any}[_csr_v1_plain_dict(item) for item in module_bindings]
    body = _csr_v1_manifest_body(schema_version = "1.0.0",
        candidate_id = String(candidate_id), physics_hash = String(physics_hash),
        regions = Dict{String,Any}[_csr_v1_plain_dict(item) for item in regions],
        mesh = _csr_v1_plain_dict(mesh), state_variables = states,
        capability_declarations = capabilities, module_bindings = bindings,
        boundaries = Dict{String,Any}[_csr_v1_plain_dict(item) for item in boundaries],
        sources_sinks = Dict{String,Any}[_csr_v1_plain_dict(item) for item in sources_sinks],
        time_mode = mode, initial_conditions = initial,
        numerical_tolerances = Dict{String,Float64}(String(k) => Float64(v)
            for (k, v) in numerical_tolerances), discretization_levels = levels,
        required_outputs = sort!(unique(String.(required_outputs))),
        applicability_scope = _csr_v1_plain_dict(applicability_scope),
        parameters = _csr_v1_json_safe(parameters))
    hash = canonical_hash(body)
    return CandidateSolveManifestV1(body["schema_version"], body["candidate_id"],
        body["physics_hash"], body["regions"], body["mesh"], body["state_variables"],
        body["capability_declarations"], body["module_bindings"], body["boundaries"],
        body["sources_sinks"], body["time_mode"], body["initial_conditions"],
        body["numerical_tolerances"], body["discretization_levels"],
        body["required_outputs"], body["applicability_scope"], body["parameters"], hash)
end

function candidate_solve_manifest_to_dict_v1(manifest::CandidateSolveManifestV1)
    body = _csr_v1_manifest_body(schema_version = manifest.schema_version,
        candidate_id = manifest.candidate_id, physics_hash = manifest.physics_hash,
        regions = manifest.regions, mesh = manifest.mesh,
        state_variables = manifest.state_variables,
        capability_declarations = manifest.capability_declarations,
        module_bindings = manifest.module_bindings, boundaries = manifest.boundaries,
        sources_sinks = manifest.sources_sinks, time_mode = manifest.time_mode,
        initial_conditions = manifest.initial_conditions,
        numerical_tolerances = manifest.numerical_tolerances,
        discretization_levels = manifest.discretization_levels,
        required_outputs = manifest.required_outputs,
        applicability_scope = manifest.applicability_scope,
        parameters = manifest.parameters)
    body["manifest_hash"] = manifest.manifest_hash
    return body
end

function _csr_v1_declared_capabilities(module_ids)
    catalog = Dict(item.id => item for item in default_topology_module_catalog_v17())
    declarations = Dict{String,Dict{String,Any}}()
    function declare!(capability, module_id, basis)
        item = get!(declarations, String(capability), Dict{String,Any}(
            "capability_id" => String(capability), "declared_by_module_ids" => String[],
            "declaration_basis" => String[]))
        push!(item["declared_by_module_ids"], String(module_id))
        push!(item["declaration_basis"], String(basis))
    end
    for raw_id in module_ids
        id = String(raw_id)
        haskey(catalog, id) || continue
        spec = catalog[id]
        tags = lowercase.(collect(spec.provides))
        evaluators = lowercase.(spec.required_evaluators)
        text = join(vcat(tags, evaluators), "|")
        spec.layer == :core && begin
            declare!("conserved_particle_inventory", id, "core module conservation scope")
            declare!("conserved_thermal_energy", id, "core module conservation scope")
        end
        any(tag -> occursin("topology:closed", tag) || occursin("topology:compact_toroid", tag), tags) &&
            declare!("closed_field_control_volume", id, "declared topology tag")
        any(tag -> occursin("topology:open", tag) || occursin("two_open_ends", tag), tags) &&
            declare!("open_field_control_volume", id, "declared topology tag")
        occursin("symmetry:axisymmetric", text) && occursin("device:magnetic", text) &&
            declare!("axisymmetric_mhd_equilibrium", id, "declared symmetry and magnetic-domain tags")
        occursin("symmetry:3d", text) &&
            declare!("three_dimensional_mhd_equilibrium", id, "declared three-dimensional symmetry tag")
        any(token -> occursin(token, text), ("open_end_loss", "open_field", "loss_cone",
                "multiple_mirror_kinetics", "end_expander_transport")) &&
            declare!("open_field_kinetic_transport", id, "declared kinetic/open-loss evaluator")
        any(token -> occursin(token, text), ("radiation_hydrodynamics", "implosion",
                "ablation", "shock_timing", "mix_and_lpi")) &&
            declare!("radiation_hydrodynamics", id, "declared pulsed radiation-hydrodynamics evaluator")
        any(token -> occursin(token, text), ("finite_coil", "magnet", "conductor",
                "peak_field", "coil_force", "coil_stress", "quench")) &&
            declare!("finite_conductor_electromagnetics", id, "declared electromagnetic engineering evaluator")
        any(token -> occursin(token, text), ("transport", "end_loss", "target_heat_flux")) &&
            declare!("state_derived_transport", id, "declared transport evaluator")
        any(tag -> startswith(tag, "contract:net_electric"), tags) &&
            declare!("fusion_reaction_radiation", id, "declared fusion mission contract tag")
    end
    result = collect(values(declarations))
    for item in result
        item["declared_by_module_ids"] = sort!(unique(item["declared_by_module_ids"]))
        item["declaration_basis"] = sort!(unique(item["declaration_basis"]))
    end
    return sort!(result; by = item -> String(item["capability_id"]))
end

function _csr_v1_quantity(genome::Genome, predicate::Function, unit::String)
    candidates = Tuple{String,Float64}[]
    collections = Any[genome.mission.targets]
    append!(collections, [item.parameters for item in genome.plasma_regions])
    append!(collections, [item.parameters for item in genome.field_sources])
    append!(collections, [item.parameters for item in genome.actuators])
    for parameters in collections, (id, value) in parameters
        value.unit == unit && predicate(lowercase(String(id))) && isfinite(value.value) &&
            push!(candidates, (String(id), Float64(value.value)))
    end
    isempty(candidates) && return nothing
    sort!(candidates; by = first)
    return first(candidates)[2]
end

function _csr_v1_power(genome::Genome)
    total = 0.0
    found = false
    for actuator in genome.actuators, (id, value) in actuator.parameters
        if value.unit == "W" && occursin("power", lowercase(String(id))) && isfinite(value.value)
            total += max(0.0, value.value)
            found = true
        end
    end
    return found ? total : 0.0
end

function _csr_v1_contract_inputs(genome::Genome)
    contracts = get(genome.normalized, "solver_ready_contracts", Dict{String,Any}())
    magnetic = get(contracts, "magnetic_constraint", Dict{String,Any}())
    boundary = get(magnetic, "boundary", Dict{String,Any}())
    profiles = get(magnetic, "profiles", Dict{String,Any}())
    special = get(contracts, "mirror_or_dipole", Dict{String,Any}())
    gaps = String[]
    major = get(boundary, "major_radius_m", nothing)
    minor = get(boundary, "minor_radius_m", nothing)
    volume = if major isa Real && minor isa Real && major > 0 && minor > 0
        2.0 * pi^2 * Float64(major) * Float64(minor)^2
    elseif get(special, "plasma_radius_m", nothing) isa Real &&
            get(special, "central_cell_length_m", nothing) isa Real
        pi * Float64(special["plasma_radius_m"])^2 * Float64(special["central_cell_length_m"])
    else
        push!(gaps, "candidate geometry does not define a finite control-volume measure")
        NaN
    end
    length_scale = get(special, "central_cell_length_m", nothing) isa Real ?
        Float64(special["central_cell_length_m"]) :
        (minor isa Real ? 2.0 * Float64(minor) : NaN)
    pressure_spec = get(profiles, "pressure", Dict{String,Any}())
    coeffs = get(pressure_spec, "coefficients_pa", Any[])
    pressure = if coeffs isa AbstractVector && !isempty(coeffs) && all(x -> x isa Real, coeffs)
        values = Float64.(coeffs)
        max(0.0, sum(values[index] / index for index in eachindex(values)))
    else
        push!(gaps, "candidate profile contract lacks a numeric pressure field")
        NaN
    end
    temperature = _csr_v1_quantity(genome, id -> occursin("temperature", id), "J")
    temperature === nothing && push!(gaps, "candidate declares no absolute temperature state")
    field = get(profiles, "design_field_t", nothing)
    field isa Real || (field = _csr_v1_quantity(genome, id -> occursin("field", id), "T"))
    current_spec = get(profiles, "current", Dict{String,Any}())
    current = get(current_spec, "total_current_a", nothing)
    particle_inventory = all(isfinite, (volume, pressure)) && temperature !== nothing && temperature > 0 ?
        pressure * volume / (2.0 * temperature) : NaN
    thermal_energy = all(isfinite, (volume, pressure)) ? 1.5 * pressure * volume : NaN
    flux = field isa Real && minor isa Real ? pi * Float64(minor)^2 * Float64(field) : NaN
    return Dict{String,Any}(
        "volume_m3" => volume, "characteristic_length_m" => length_scale,
        "minor_radius_m" => minor isa Real ? Float64(minor) : NaN,
        "pressure_pa" => pressure, "temperature_j" => temperature,
        "magnetic_field_t" => field isa Real ? Float64(field) : NaN,
        "plasma_current_a" => current isa Real ? Float64(current) : NaN,
        "magnetic_flux_wb" => flux, "particle_inventory" => particle_inventory,
        "thermal_energy_j" => thermal_energy, "input_power_w" => _csr_v1_power(genome),
        "fuel" => genome.mission.fuel, "input_gaps" => sort!(unique(gaps)))
end

function compile_candidate_solve_manifest_v1(genome::Genome, module_ids;
        discretization_levels = [32], parameter_overrides = Dict{String,Any}())
    capabilities = _csr_v1_declared_capabilities(module_ids)
    capability_ids = Set(String(item["capability_id"]) for item in capabilities)
    inputs = _csr_v1_contract_inputs(genome)
    merge!(inputs, _csr_v1_plain_dict(parameter_overrides))
    states = Dict{String,Any}[]
    initial = Dict{String,Float64}()
    if isfinite(Float64(get(inputs, "particle_inventory", NaN)))
        push!(states, Dict("state_id" => "particle_inventory", "account" => "particles",
            "unit" => "1", "positivity_required" => true))
        initial["particle_inventory"] = Float64(inputs["particle_inventory"])
    end
    if isfinite(Float64(get(inputs, "thermal_energy_j", NaN)))
        push!(states, Dict("state_id" => "thermal_energy", "account" => "energy",
            "unit" => "J", "positivity_required" => true))
        initial["thermal_energy"] = Float64(inputs["thermal_energy_j"])
    end
    if isfinite(Float64(get(inputs, "plasma_current_a", NaN)))
        push!(states, Dict("state_id" => "plasma_current", "account" => "current",
            "unit" => "A", "positivity_required" => false))
        initial["plasma_current"] = Float64(inputs["plasma_current_a"])
    end
    if isfinite(Float64(get(inputs, "magnetic_flux_wb", NaN)))
        push!(states, Dict("state_id" => "magnetic_flux", "account" => "magnetic_flux",
            "unit" => "Wb", "positivity_required" => false))
        initial["magnetic_flux"] = Float64(inputs["magnetic_flux_wb"])
    end
    bindings = Dict{String,Any}[]
    function bind!(id, capability, operator, state_ids; evidence_ceiling = "L1_screening_only")
        capability in capability_ids || return
        push!(bindings, Dict("module_id" => id, "capability_id" => capability,
            "operator_id" => operator, "state_ids" => String.(state_ids),
            "evidence_ceiling" => evidence_ceiling))
    end
    bind!("particle_control_volume", "conserved_particle_inventory",
        "control_volume_particle_inventory_v1", ["particle_inventory"])
    bind!("thermal_control_volume", "conserved_thermal_energy",
        "control_volume_thermal_energy_v1", ["thermal_energy"])
    bind!("closed_field_transport", "closed_field_control_volume",
        "state_derived_bohm_transport_l1_v1", ["particle_inventory", "thermal_energy"])
    bind!("open_field_transport", "open_field_control_volume",
        "state_derived_parallel_streaming_l1_v1", ["particle_inventory", "thermal_energy"])
    bind!("fusion_reaction_radiation", "fusion_reaction_radiation",
        "state_derived_dt_reaction_bremsstrahlung_l1_v1", ["particle_inventory", "thermal_energy"])
    bind!("fixed_magnetic_inventory", "axisymmetric_mhd_equilibrium",
        "fixed_current_flux_inventory_l1_v1", ["plasma_current", "magnetic_flux"])
    bind!("fixed_magnetic_inventory_3d", "three_dimensional_mhd_equilibrium",
        "fixed_current_flux_inventory_l1_v1", ["plasma_current", "magnetic_flux"])
    gaps = String.(get(inputs, "input_gaps", String[]))
    for required in ("particle_inventory", "thermal_energy")
        haskey(initial, required) || push!(gaps, "missing initial state $required")
    end
    isempty(bindings) && push!(gaps, "no declared capability selects an implemented numerical operator")
    regions = Dict{String,Any}[Dict("region_id" => item.id, "kind" => item.kind,
        "geometry_model" => item.geometry_model) for item in genome.plasma_regions]
    boundaries = Dict{String,Any}[Dict("from_region_id" => item.from_region_id,
        "to_region_id" => item.to_region_id, "kind" => item.kind)
        for item in genome.flux_connections]
    sources_sinks = Dict{String,Any}[
        Dict("id" => item.id, "kind" => item.kind, "role" => "declared_actuator")
        for item in genome.actuators]
    mode_text = lowercase(genome.mission.operating_mode)
    mode = occursin("steady", mode_text) ? "steady" :
        occursin("pulse", mode_text) ? "pulsed" : "transient"
    return CandidateSolveManifestV1(candidate_id = genome.design_id,
        physics_hash = genome.physics_hash, regions = regions,
        state_variables = states, capability_declarations = capabilities,
        module_bindings = bindings, boundaries = boundaries, sources_sinks = sources_sinks,
        time_mode = mode, initial_conditions = initial,
        discretization_levels = discretization_levels,
        applicability_scope = Dict("status" => isempty(gaps) ? "applicable" : "unsupported",
            "unsupported_reasons" => sort!(unique(gaps)),
            "routing_basis" => "declared_module_capabilities_only",
            "nonrouting_fields" => ["family", "parent_family", "display_label"]),
        parameters = inputs)
end

function _csr_v1_modules(manifest::CandidateSolveManifestV1)
    return CandidatePhysicsModuleV1[
        CandidatePhysicsModuleV1(String(item["module_id"]), String(item["capability_id"]),
            String(item["operator_id"]), String.(get(item, "state_ids", Any[])),
            deepcopy(manifest.parameters)) for item in manifest.module_bindings]
end

function _csr_v1_state_index(manifest::CandidateSolveManifestV1)
    return Dict(String(item["state_id"]) => index for (index, item) in
        enumerate(manifest.state_variables))
end

function _csr_v1_temperature_j(u, index)
    haskey(index, "particle_inventory") && haskey(index, "thermal_energy") || return NaN
    particles = max(u[index["particle_inventory"]], eps())
    return max(u[index["thermal_energy"]] / (3.0 * particles), 0.0)
end

function _csr_v1_dt_rates(u, index, parameters)
    volume = Float64(get(parameters, "volume_m3", NaN))
    temperature_j = _csr_v1_temperature_j(u, index)
    particles = haskey(index, "particle_inventory") ? max(u[index["particle_inventory"]], 0.0) : 0.0
    if !all(isfinite, (volume, temperature_j)) || volume <= 0 || temperature_j <= 0
        return (reaction = 0.0, fusion = 0.0, alpha = 0.0, radiation = 0.0)
    end
    temperature_kev = temperature_j / (_CSR_V1_E_CHARGE * 1.0e3)
    reactivity = 1.1e-24 * temperature_kev^2 / (1.0 + (temperature_kev / 5.0)^2)
    density = particles / volume
    reaction = 0.25 * density^2 * reactivity * volume
    fusion = reaction * _CSR_V1_DT_FUSION_J
    alpha = reaction * _CSR_V1_DT_ALPHA_J
    temperature_ev = temperature_j / _CSR_V1_E_CHARGE
    radiation = 1.69e-38 * density^2 * sqrt(max(temperature_ev, 0.0)) * volume
    return (reaction = reaction, fusion = fusion, alpha = alpha, radiation = radiation)
end

function _csr_v1_transport_rates(operator_id, u, index, parameters)
    particles = haskey(index, "particle_inventory") ? max(u[index["particle_inventory"]], 0.0) : 0.0
    energy = haskey(index, "thermal_energy") ? max(u[index["thermal_energy"]], 0.0) : 0.0
    temperature_j = _csr_v1_temperature_j(u, index)
    if operator_id == "state_derived_parallel_streaming_l1_v1"
        length_m = Float64(get(parameters, "characteristic_length_m", NaN))
        tau = all(isfinite, (length_m, temperature_j)) && length_m > 0 && temperature_j > 0 ?
            length_m / sqrt(2.0 * temperature_j / (2.5 * _CSR_V1_AMU)) : Inf
        return (particle_loss = particles / tau, energy_loss = energy / tau, tau = tau)
    elseif operator_id == "state_derived_bohm_transport_l1_v1"
        radius = Float64(get(parameters, "minor_radius_m", NaN))
        field = abs(Float64(get(parameters, "magnetic_field_t", NaN)))
        temperature_ev = temperature_j / _CSR_V1_E_CHARGE
        diffusion = isfinite(temperature_ev) && field > 0 ? temperature_ev / (16.0 * field) : NaN
        tau = all(isfinite, (radius, diffusion)) && radius > 0 && diffusion > 0 ?
            radius^2 / (4.0 * diffusion) : Inf
        return (particle_loss = particles / tau, energy_loss = energy / tau, tau = tau)
    end
    return (particle_loss = 0.0, energy_loss = 0.0, tau = Inf)
end

function source_terms!(source, physics_module::CandidatePhysicsModuleV1, state, t,
        manifest::CandidateSolveManifestV1)
    index = _csr_v1_state_index(manifest)
    operator = physics_module.operator_id
    if operator == "control_volume_thermal_energy_v1" && haskey(index, "thermal_energy")
        source[index["thermal_energy"]] += Float64(get(physics_module.parameters, "input_power_w", 0.0))
    elseif operator == "state_derived_dt_reaction_bremsstrahlung_l1_v1"
        rates = _csr_v1_dt_rates(state, index, physics_module.parameters)
        haskey(index, "thermal_energy") && (source[index["thermal_energy"]] += rates.alpha)
    end
    return source
end

function boundary_flux!(flux, physics_module::CandidatePhysicsModuleV1, state, boundary,
        manifest::CandidateSolveManifestV1)
    index = _csr_v1_state_index(manifest)
    operator = physics_module.operator_id
    if operator in ("state_derived_parallel_streaming_l1_v1",
            "state_derived_bohm_transport_l1_v1")
        rates = _csr_v1_transport_rates(operator, state, index, physics_module.parameters)
        haskey(index, "particle_inventory") &&
            (flux[index["particle_inventory"]] += rates.particle_loss)
        haskey(index, "thermal_energy") &&
            (flux[index["thermal_energy"]] += rates.energy_loss)
    elseif operator == "state_derived_dt_reaction_bremsstrahlung_l1_v1"
        rates = _csr_v1_dt_rates(state, index, physics_module.parameters)
        haskey(index, "particle_inventory") &&
            (flux[index["particle_inventory"]] += 2.0 * rates.reaction)
        haskey(index, "thermal_energy") &&
            (flux[index["thermal_energy"]] += rates.radiation)
    end
    return flux
end

function _csr_v1_source_flux(modules, state, t, manifest)
    source = zeros(length(state))
    flux = zeros(length(state))
    for physics_module in modules
        source_terms!(source, physics_module, state, t, manifest)
        boundary_flux!(flux, physics_module, state, manifest.boundaries, manifest)
    end
    return source, flux
end

function residual!(r, physics_module::CandidatePhysicsModuleV1, u, du, parameters, t)
    manifest = parameters["manifest"]::CandidateSolveManifestV1
    source = zeros(length(u)); flux = zeros(length(u))
    source_terms!(source, physics_module, u, t, manifest)
    boundary_flux!(flux, physics_module, u, manifest.boundaries, manifest)
    r .= du .+ flux .- source
    return r
end

function observables(physics_module::CandidatePhysicsModuleV1, state, trajectory,
        manifest::CandidateSolveManifestV1)
    index = _csr_v1_state_index(manifest)
    result = Dict{String,Any}("module_id" => physics_module.module_id,
        "capability_id" => physics_module.capability_id, "operator_id" => physics_module.operator_id,
        "status" => "computed")
    if physics_module.operator_id == "control_volume_thermal_energy_v1"
        result["input_power_w"] = Float64(get(physics_module.parameters, "input_power_w", 0.0))
    elseif physics_module.operator_id in ("state_derived_parallel_streaming_l1_v1",
            "state_derived_bohm_transport_l1_v1")
        rates = _csr_v1_transport_rates(physics_module.operator_id, state, index, physics_module.parameters)
        merge!(result, Dict("particle_loss_rate_per_s" => rates.particle_loss,
            "energy_loss_power_w" => rates.energy_loss,
            "state_derived_transport_time_s" => rates.tau))
    elseif physics_module.operator_id == "state_derived_dt_reaction_bremsstrahlung_l1_v1"
        rates = _csr_v1_dt_rates(state, index, physics_module.parameters)
        merge!(result, Dict("fusion_reaction_rate_per_s" => rates.reaction,
            "fusion_power_w" => rates.fusion, "self_heating_power_w" => rates.alpha,
            "radiation_loss_power_w" => rates.radiation))
    end
    safe_result = _csr_v1_json_safe(result)
    safe_result["observation_hash"] = canonical_hash(safe_result)
    return safe_result
end

function _csr_v1_characteristic_time(modules, u, manifest)
    index = _csr_v1_state_index(manifest)
    times = Float64[]
    for physics_module in modules
        physics_module.operator_id in ("state_derived_parallel_streaming_l1_v1",
            "state_derived_bohm_transport_l1_v1") || continue
        rates = _csr_v1_transport_rates(physics_module.operator_id, u, index, physics_module.parameters)
        isfinite(rates.tau) && rates.tau > 0 && push!(times, rates.tau)
    end
    return isempty(times) ? 1.0 : minimum(times)
end

function _csr_v1_integrate(manifest, modules, steps)
    state_ids = String[String(item["state_id"]) for item in manifest.state_variables]
    u = Float64[manifest.initial_conditions[id] for id in state_ids]
    tau = _csr_v1_characteristic_time(modules, u, manifest)
    declared_duration = get(manifest.parameters, "pulse_duration_s", nothing)
    final_time = manifest.time_mode == "pulsed" && declared_duration isa Real &&
        isfinite(declared_duration) && declared_duration > 0 ? Float64(declared_duration) :
        clamp(12.0 * tau, 1.0e-9, 10.0)
    dt = final_time / steps
    maximum_internal_dt = max(0.2 * tau, final_time / (steps * 10_000))
    times = collect(range(0.0, final_time; length = steps + 1))
    states = Vector{Vector{Float64}}(undef, steps + 1)
    states[1] = copy(u)
    positive = Bool[get(item, "positivity_required", false) === true
        for item in manifest.state_variables]
    rhs(value, t) = begin
        source, flux = _csr_v1_source_flux(modules, value, t, manifest)
        source .- flux
    end
    audit_previous_state = copy(u)
    audit_dt = dt
    for step in 1:steps
        output_start = times[step]
        internal_steps = max(1, ceil(Int, dt / maximum_internal_dt))
        internal_dt = dt / internal_steps
        for substep in 1:internal_steps
            t = output_start + (substep - 1) * internal_dt
            audit_previous_state = copy(u)
            audit_dt = internal_dt
            k1 = rhs(u, t)
            k2 = rhs(u .+ 0.5 * internal_dt .* k1, t + 0.5 * internal_dt)
            k3 = rhs(u .+ 0.5 * internal_dt .* k2, t + 0.5 * internal_dt)
            k4 = rhs(u .+ internal_dt .* k3, t + internal_dt)
            candidate = u .+ internal_dt .* (k1 .+ 2k2 .+ 2k3 .+ k4) ./ 6.0
            for index in eachindex(candidate)
                positive[index] && (candidate[index] = max(candidate[index], 0.0))
            end
            all(isfinite, candidate) || return Dict{String,Any}(
                "status" => "fail", "reason" => "nonfinite_state", "times" => times[1:step],
                "states" => states[1:step], "final_time_s" => times[step])
            u = candidate
        end
        states[step + 1] = copy(u)
    end
    return Dict{String,Any}("status" => "computed", "times" => times,
        "states" => states, "final_time_s" => final_time, "time_step_s" => dt,
        "maximum_internal_time_step_s" => maximum_internal_dt,
        "audit_previous_state" => audit_previous_state, "audit_time_step_s" => audit_dt)
end

"Independently recompute dU/dt + div(F) - S from the stored trajectory."
function audit_conservation_residuals_v1(manifest::CandidateSolveManifestV1,
        modules, trajectory)
    states = trajectory["states"]
    times = trajectory["times"]
    length(states) >= 2 || return Dict{String,Any}[]
    dt = Float64(get(trajectory, "audit_time_step_s", times[end] - times[end - 1]))
    final = states[end]
    previous = get(trajectory, "audit_previous_state", states[end - 1])
    derivative = (final .- previous) ./ dt
    source, flux = _csr_v1_source_flux(modules, final, times[end], manifest)
    records = Dict{String,Any}[]
    for (index, item) in enumerate(manifest.state_variables)
        account = String(item["account"])
        normalization = max(abs(derivative[index]) + abs(flux[index]) + abs(source[index]), 1.0)
        normalized = abs(derivative[index] + flux[index] - source[index]) / normalization
        push!(records, Dict("state_id" => String(item["state_id"]), "account" => account,
            "dU_dt" => derivative[index], "divergence_F" => flux[index],
            "source_S" => source[index], "normalization" => normalization,
            "normalized_residual" => normalized))
    end
    return records
end

function _csr_v1_envelope_body(; candidate_id, physics_hash, manifest_hash, input_hash,
        software_hash, container_hash, status, convergence_status, residual_history,
        state_trajectory, conservation_slots, resolution, error_estimates, module_results,
        evidence_ceiling, unsupported_reasons)
    return Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_id" => candidate_id,
        "physics_hash" => physics_hash, "manifest_hash" => manifest_hash,
        "input_hash" => input_hash, "software_hash" => software_hash,
        "container_hash" => container_hash, "status" => String(status),
        "convergence_status" => convergence_status,
        "residual_history" => residual_history, "state_trajectory" => state_trajectory,
        "conservation_slots" => conservation_slots, "resolution" => resolution,
        "error_estimates" => error_estimates, "module_results" => module_results,
        "evidence_ceiling" => evidence_ceiling,
        "unsupported_reasons" => unsupported_reasons)
end

function _csr_v1_make_envelope(manifest; status, convergence_status,
        residual_history = Dict{String,Any}[], state_trajectory = Dict{String,Any}(),
        conservation_slots = Dict{String,Any}[], resolution = Dict{String,Any}(),
        error_estimates = Dict{String,Any}(), module_results = Dict{String,Any}[],
        evidence_ceiling = "L1_candidate_bound_screening_only",
        unsupported_reasons = String[])
    status in CANDIDATE_SOLVE_STATUS_V1 || throw(ArgumentError("invalid solver status"))
    software_hash = canonical_hash(Dict("runtime" => "candidate_solver_runtime_v1",
        "algorithm" => "capability_assembled_control_volume_rk4_v1"))
    container_hash = canonical_hash(Dict("julia_version" => string(VERSION),
        "machine" => Sys.MACHINE, "kernel" => Sys.KERNEL,
        "environment_kind" => "process_environment_not_sealed_container_image"))
    body = _csr_v1_envelope_body(candidate_id = manifest.candidate_id,
        physics_hash = manifest.physics_hash, manifest_hash = manifest.manifest_hash,
        input_hash = manifest.manifest_hash, software_hash = software_hash,
        container_hash = container_hash, status = status,
        convergence_status = convergence_status, residual_history = residual_history,
        state_trajectory = state_trajectory, conservation_slots = conservation_slots,
        resolution = resolution, error_estimates = error_estimates,
        module_results = module_results, evidence_ceiling = evidence_ceiling,
        unsupported_reasons = sort!(unique(String.(unsupported_reasons))))
    body = _csr_v1_json_safe(body)
    result_hash = canonical_hash(body)
    return SolverResultEnvelopeV1(body["schema_version"], body["candidate_id"],
        body["physics_hash"], body["manifest_hash"], body["input_hash"],
        body["software_hash"], body["container_hash"], status,
        body["convergence_status"], body["residual_history"],
        body["state_trajectory"], body["conservation_slots"], body["resolution"],
        body["error_estimates"], body["module_results"], body["evidence_ceiling"],
        body["unsupported_reasons"], result_hash)
end

function solver_result_envelope_to_dict_v1(result::SolverResultEnvelopeV1)
    body = _csr_v1_envelope_body(candidate_id = result.candidate_id,
        physics_hash = result.physics_hash, manifest_hash = result.manifest_hash,
        input_hash = result.input_hash, software_hash = result.software_hash,
        container_hash = result.container_hash, status = result.status,
        convergence_status = result.convergence_status,
        residual_history = result.residual_history,
        state_trajectory = result.state_trajectory,
        conservation_slots = result.conservation_slots, resolution = result.resolution,
        error_estimates = result.error_estimates, module_results = result.module_results,
        evidence_ceiling = result.evidence_ceiling,
        unsupported_reasons = result.unsupported_reasons)
    body["result_hash"] = result.result_hash
    return body
end

function solve_candidate_manifest_v1(manifest::CandidateSolveManifestV1)
    unsupported = String.(get(manifest.applicability_scope,
        "unsupported_reasons", String[]))
    if get(manifest.applicability_scope, "status", "unsupported") != "applicable"
        return _csr_v1_make_envelope(manifest; status = :unsupported,
            convergence_status = "not_run_missing_inputs_or_operator",
            unsupported_reasons = unsupported,
            evidence_ceiling = "none_unsupported_problem")
    end
    modules = _csr_v1_modules(manifest)
    runs = Dict(level => _csr_v1_integrate(manifest, modules, level)
        for level in manifest.discretization_levels)
    finest_level = maximum(manifest.discretization_levels)
    finest = runs[finest_level]
    if finest["status"] != "computed"
        return _csr_v1_make_envelope(manifest; status = :fail,
            convergence_status = String(get(finest, "reason", "solver_failure")),
            resolution = Dict("levels" => manifest.discretization_levels),
            unsupported_reasons = unsupported)
    end
    slots = audit_conservation_residuals_v1(manifest, modules, finest)
    maximum_residual = isempty(slots) ? Inf : maximum(Float64(item["normalized_residual"])
        for item in slots)
    tolerance = manifest.numerical_tolerances["normalized_residual"]
    state_ids = String[String(item["state_id"]) for item in manifest.state_variables]
    final = finest["states"][end]
    source, flux = _csr_v1_source_flux(modules, final, finest["times"][end], manifest)
    derivative_norm = maximum(abs.(source .- flux) ./
        max.(abs.(source) .+ abs.(flux), 1.0))
    steady_tolerance = manifest.numerical_tolerances["steady_time_term"]
    converged = maximum_residual <= tolerance &&
        (manifest.time_mode != "steady" || derivative_norm <= steady_tolerance)
    status = converged ? :pass : :unknown
    convergence = converged ? "converged" : "trajectory_computed_not_converged"
    error_estimates = Dict{String,Any}("maximum_normalized_conservation_residual" => maximum_residual,
        "final_normalized_time_term" => derivative_norm)
    if length(manifest.discretization_levels) >= 2
        coarse_level = manifest.discretization_levels[end - 1]
        coarse = runs[coarse_level]
        if coarse["status"] == "computed"
            coarse_final = coarse["states"][end]
            relative = maximum(abs.(final .- coarse_final) ./ max.(abs.(final), 1.0))
            error_estimates["relative_resolution_change"] = relative
            error_estimates["resolution_converged"] = relative <=
                manifest.numerical_tolerances["relative_resolution"]
        end
    end
    trajectory = Dict{String,Any}("time_samples_s" => finest["times"],
        "state_ids" => state_ids, "states" => finest["states"],
        "complete" => true, "final_state" => Dict(state_ids[index] => final[index]
            for index in eachindex(state_ids)))
    module_results = [observables(physics_module, final, trajectory, manifest)
        for physics_module in modules]
    residual_history = Dict{String,Any}[
        Dict("time_s" => finest["times"][end],
            "maximum_normalized_residual" => maximum_residual,
            "normalized_time_term" => derivative_norm)]
    return _csr_v1_make_envelope(manifest; status = status,
        convergence_status = convergence, residual_history = residual_history,
        state_trajectory = trajectory, conservation_slots = slots,
        resolution = Dict("levels" => manifest.discretization_levels,
            "selected_level" => finest_level, "time_step_s" => finest["time_step_s"],
            "maximum_internal_time_step_s" => finest["maximum_internal_time_step_s"]),
        error_estimates = error_estimates, module_results = module_results,
        unsupported_reasons = unsupported)
end

function solver_state_for_v55_v1(result::SolverResultEnvelopeV1,
        manifest::CandidateSolveManifestV1)
    supported = result.status != :unsupported
    slots = result.status == :pass ? result.conservation_slots : Dict{String,Any}[]
    required = sort!(unique(String(item["account"]) for item in manifest.state_variables
        if String(item["account"]) in ("particles", "energy")))
    times = supported ? get(result.state_trajectory, "time_samples_s", Any[]) : Any[]
    return Dict{String,Any}(
        "mode" => manifest.time_mode, "solver_derived" => supported,
        "generated_nominal" => false, "solver_output_hash" => supported ? result.result_hash : "",
        "time_samples_s" => times,
        "complete_time_trajectory" => supported && get(result.state_trajectory, "complete", false) === true,
        "normalized_residual_tolerance" => manifest.numerical_tolerances["normalized_residual"],
        "steady_time_term_tolerance" => manifest.numerical_tolerances["steady_time_term"],
        "required_accounts" => required, "residuals" => slots,
        "residual_audit" => result.conservation_slots,
        "solver_status" => String(result.status), "evidence_ceiling" => result.evidence_ceiling)
end

function transport_burn_for_v55_v1(result::SolverResultEnvelopeV1,
        manifest::CandidateSolveManifestV1)
    supported = result.status != :unsupported
    admissible = result.status == :pass
    observations = Dict(String(item["operator_id"]) => item for item in result.module_results)
    reaction = get(observations, "state_derived_dt_reaction_bremsstrahlung_l1_v1", Dict{String,Any}())
    transports = [item for item in result.module_results if String(item["operator_id"]) in
        ("state_derived_parallel_streaming_l1_v1", "state_derived_bohm_transport_l1_v1")]
    loss_power = sum((get(item, "energy_loss_power_w", nothing) isa Real ?
        Float64(item["energy_loss_power_w"]) : 0.0 for item in transports); init = 0.0) +
        (get(reaction, "radiation_loss_power_w", nothing) isa Real ?
            Float64(reaction["radiation_loss_power_w"]) : 0.0)
    transport_body = Dict{String,Any}(
        "state_solution_hash" => supported ? result.result_hash : "",
        "confinement_time_source" => supported ? "candidate_bound_state_derived_operator" : "",
        "fusion_reaction_rate_per_s" => admissible ? get(reaction, "fusion_reaction_rate_per_s", nothing) : nothing,
        "fusion_power_w" => admissible ? get(reaction, "fusion_power_w", nothing) : nothing,
        "self_heating_power_w" => admissible ? get(reaction, "self_heating_power_w", nothing) : nothing,
        "loss_power_w" => admissible ? loss_power : nothing,
        "module_observation_hashes" => String[get(item, "observation_hash", "")
            for item in result.module_results])
    transport_hash = supported ? canonical_hash(transport_body) : ""
    return Dict{String,Any}(
        "solver_derived" => supported, "generated_nominal" => false,
        "state_solution_hash" => transport_body["state_solution_hash"],
        "solver_output_hash" => transport_hash,
        "confinement_time_source" => transport_body["confinement_time_source"],
        "particle_paths" => Any[
            Dict("role" => "production", "path" => "declared_sources_to_control_volume"),
            Dict("role" => "loss", "path" => "state_derived_transport_boundary_flux"),
            Dict("role" => "burn", "path" => "state_derived_reaction_sink")],
        "energy_paths" => Any[
            Dict("role" => "deposition", "path" => "declared_actuator_power_to_state"),
            Dict("role" => "transport", "path" => "state_derived_transport_operator"),
            Dict("role" => "escape", "path" => "boundary_and_radiation_flux")],
        "fusion_reaction_rate_per_s" => transport_body["fusion_reaction_rate_per_s"],
        "fusion_power_w" => transport_body["fusion_power_w"],
        "self_heating_power_w" => transport_body["self_heating_power_w"],
        "loss_power_w" => transport_body["loss_power_w"],
        "numerical_admissibility" => admissible ? "converged" :
            supported ? "unknown_nonconverged" : "unsupported",
        "evidence_ceiling" => result.evidence_ceiling)
end

"Aggregate only hashed stage outputs; unavailable roles remain absent and therefore unknown."
function strict_power_ledger_v1(result::SolverResultEnvelopeV1, transport;
        engineering_output = nothing)
    terms = Dict{String,Any}[]
    state_hash = result.status == :unsupported ? "" : result.result_hash
    transport_hash = String(get(transport, "solver_output_hash", ""))
    fusion = get(transport, "fusion_power_w", nothing)
    loss = get(transport, "loss_power_w", nothing)
    thermal = findfirst(item -> String(item["operator_id"]) ==
        "control_volume_thermal_energy_v1", result.module_results)
    input_power = thermal === nothing ? nothing :
        get(result.module_results[thermal], "input_power_w", nothing)
    fusion isa Real && push!(terms, Dict("role" => "fusion", "value_w" => Float64(fusion),
        "solver_derived" => true, "source_output_hash" => transport_hash))
    input_power isa Real && begin
        push!(terms, Dict("role" => "drive", "value_w" => -Float64(input_power),
            "solver_derived" => true, "source_output_hash" => state_hash))
    end
    loss isa Real && push!(terms, Dict("role" => "loss", "value_w" => -Float64(loss),
        "solver_derived" => true, "source_output_hash" => transport_hash))
    if engineering_output isa AbstractDict && get(engineering_output, "solver_derived", false) === true
        hash = String(get(engineering_output, "solver_output_hash", ""))
        value = get(engineering_output, "recirculating_power_w", nothing)
        value isa Real && length(hash) == 64 && push!(terms, Dict("role" => "recirculating",
            "value_w" => -Float64(value), "solver_derived" => true,
            "source_output_hash" => hash))
    end
    reported = sum((Float64(item["value_w"]) for item in terms); init = 0.0)
    roles = Set(String(item["role"]) for item in terms)
    return Dict{String,Any}(
        "generated_nominal" => false, "artificially_closed" => false,
        "terms" => terms, "reported_net_power_w" => reported,
        "closure_tolerance_w" => max(abs(reported), 1.0) * 1.0e-12,
        "status" => all(role -> role in roles, ("fusion", "drive", "loss", "recirculating")) ?
            "complete" : "unknown_missing_solver_output_role",
        "ledger_hash" => canonical_hash(terms),
        "evidence_ceiling" => result.evidence_ceiling)
end
