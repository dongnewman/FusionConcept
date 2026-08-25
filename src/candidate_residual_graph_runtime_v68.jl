const V68_SOLVE_STATUSES = Set([:pass, :fail, :unknown, :unsupported])
const V68_JACOBIAN_MODES = Set([:analytic, :automatic_differentiation,
    :matrix_free_jvp, :finite_difference_l1_only, :unavailable])

"A module-owned state block with explicit scales, bounds, region and time semantics."
struct StateBlockSpecV1
    module_id::String
    block_id::String
    region_id::String
    state_ids::Vector{String}
    units::Vector{String}
    residual_units::Vector{String}
    scales::Vector{Float64}
    lower_bounds::Vector{Float64}
    upper_bounds::Vector{Float64}
    spatial_dimension::Int
    allowed_time_modes::Vector{String}
end

"Declares the rows produced by a residual block and every state on which they depend."
struct ResidualBlockContractV1
    module_id::String
    block_id::String
    assembly_role::Symbol
    row_state_ids::Vector{String}
    row_units::Vector{String}
    dependency_state_ids::Vector{String}
    region_ids::Vector{String}
    boundary_ids::Vector{String}
    interface_fluxes::Vector{Dict{String,Any}}
    exclusive_outputs::Vector{String}
end

"Declares the numerical derivative provider and its exact row/column slots."
struct JacobianBlockContractV1
    module_id::String
    block_id::String
    mode::Symbol
    row_state_ids::Vector{String}
    column_state_ids::Vector{String}
    audit_relative_tolerance::Float64
    audit_absolute_tolerance::Float64
end

"Declares which rows are differential and which are algebraic constraints."
struct MassMatrixBlockContractV1
    module_id::String
    block_id::String
    row_state_ids::Vector{String}
    kinds::Vector{Symbol}
end

"Hash-sealed output of capability-graph compilation; it contains no backend-native types."
struct CoupledSolvePlanV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    status::Symbol
    state_ids::Vector{String}
    residual_row_ids::Vector{String}
    state_scales::Vector{Float64}
    residual_scales::Vector{Float64}
    lower_bounds::Vector{Float64}
    upper_bounds::Vector{Float64}
    differential_mask::Vector{Bool}
    module_order::Vector{String}
    dependency_graph::Dict{String,Any}
    compiler_audits::Dict{String,Any}
    reasons::Vector{String}
    evidence_ceiling::String
    plan_hash::String
end

"A backend-neutral nonlinear/DAE result with block, conservation and derivative audits."
struct NonlinearSolveResultEnvelopeV1
    schema_version::String
    candidate_id::String
    physics_hash::String
    manifest_hash::String
    plan_hash::String
    backend_id::String
    status::Symbol
    classification_code::String
    convergence_status::String
    final_state::Dict{String,Float64}
    residual_history::Vector{Dict{String,Any}}
    block_residuals::Vector{Dict{String,Any}}
    trajectory::Vector{Dict{String,Any}}
    observables::Dict{String,Any}
    audits::Dict{String,Any}
    unresolved_reasons::Vector{String}
    evidence_ceiling::String
    result_hash::String
end

abstract type AbstractResidualPhysicsModuleV1 end
abstract type AbstractNonlinearBackendAdapterV1 end

"Repository-owned reference adapter. Sparse assembly and Krylov iteration stay behind this type."
struct NativeSparseNewtonKrylovBackendV1 <: AbstractNonlinearBackendAdapterV1
    backend_id::String
    max_newton_iterations::Int
    max_krylov_iterations::Int
    homotopy_steps::Vector{Float64}
    dae_steps::Int
    dae_dt::Float64
end

NativeSparseNewtonKrylovBackendV1(; max_newton_iterations = 40,
        max_krylov_iterations = 40, homotopy_steps = collect(0.0:0.2:1.0),
        dae_steps = 24, dae_dt = 0.1) =
    NativeSparseNewtonKrylovBackendV1("native_sparse_newton_krylov_v1",
        max_newton_iterations, max_krylov_iterations, Float64.(homotopy_steps),
        dae_steps, Float64(dae_dt))

residual_module_id(::AbstractResidualPhysicsModuleV1) =
    throw(MethodError(residual_module_id, (AbstractResidualPhysicsModuleV1,)))
residual_contracts(::AbstractResidualPhysicsModuleV1, ::CandidateSolveManifestV1) =
    throw(MethodError(residual_contracts, (AbstractResidualPhysicsModuleV1, CandidateSolveManifestV1)))
jacobian_contracts(::AbstractResidualPhysicsModuleV1, ::CandidateSolveManifestV1) =
    throw(MethodError(jacobian_contracts, (AbstractResidualPhysicsModuleV1, CandidateSolveManifestV1)))
mass_matrix_contracts(::AbstractResidualPhysicsModuleV1, ::CandidateSolveManifestV1) =
    throw(MethodError(mass_matrix_contracts, (AbstractResidualPhysicsModuleV1, CandidateSolveManifestV1)))
validity_domain(::AbstractResidualPhysicsModuleV1) = Dict{String,Any}(
    "status" => "unknown", "reason" => "validity_domain_not_declared")

function residual_block!(r, ::AbstractResidualPhysicsModuleV1, u, du, p, t, context)
    throw(MethodError(residual_block!, (typeof(r), AbstractResidualPhysicsModuleV1,
        typeof(u), typeof(du), typeof(p), typeof(t), typeof(context))))
end

function jacobian_block!(J, ::AbstractResidualPhysicsModuleV1, u, du, p, t, context)
    throw(MethodError(jacobian_block!, (typeof(J), AbstractResidualPhysicsModuleV1,
        typeof(u), typeof(du), typeof(p), typeof(t), typeof(context))))
end


function mass_matrix_block!(M, ::AbstractResidualPhysicsModuleV1, u, p, t, context)
    throw(MethodError(mass_matrix_block!, (typeof(M), AbstractResidualPhysicsModuleV1,
        typeof(u), typeof(p), typeof(t), typeof(context))))
end

boundary_flux!(f, ::AbstractResidualPhysicsModuleV1, u, boundary, t, context) = fill!(f, 0.0)
source_terms!(s, ::AbstractResidualPhysicsModuleV1, u, actuator_state, t, context) = fill!(s, 0.0)
observables(::AbstractResidualPhysicsModuleV1, u, trajectory, context) = Dict{String,Any}()
power_ledger_contribution(::AbstractResidualPhysicsModuleV1, u, trajectory, context) =
    Dict{String,Any}()
coupled_term_contract(::AbstractResidualPhysicsModuleV1) = Dict{String,Any}(
    "expected_term_ids" => String[], "provided_term_ids" => String[])

"Assemble module-declared power terms without routing on module type or candidate labels."
function compile_v68_power_ledger_v1(manifest::CandidateSolveManifestV1,
        modules::Vector{<:AbstractResidualPhysicsModuleV1}, u, trajectory, context)
    contributions = Dict{String,Any}[]
    for module_instance in modules
        contribution = power_ledger_contribution(module_instance, u, trajectory, context)
        isempty(contribution) && continue
        record = Dict{String,Any}(String(key) => value for (key, value) in contribution)
        record["module_id"] = residual_module_id(module_instance)
        push!(contributions, record)
    end

    core_records = [item for item in contributions
        if String(get(item, "role", "")) == "longitudinal_balance"]
    unresolved = String[]
    competing = String[]
    length(core_records) == 1 || push!(length(core_records) > 1 ? competing : unresolved,
        "longitudinal_balance")
    core = length(core_records) == 1 ? only(core_records) : Dict{String,Any}()
    expected = Set(String.(get(core, "externally_owned_term_ids", String[])))
    providers = Dict{String,Vector{Dict{String,Any}}}()
    for item in contributions, term_id in String.(get(item, "provided_term_ids", String[]))
        push!(get!(providers, term_id, Dict{String,Any}[]), item)
    end
    for term_id in sort!(collect(expected))
        count = length(get(providers, term_id, Dict{String,Any}[]))
        count == 1 || push!(count > 1 ? competing : unresolved, term_id)
    end
    for (term_id, records) in providers
        term_id in expected || push!(competing, "unexpected_provider:$term_id")
        length(records) <= 1 || push!(competing, term_id)
    end

    core_terms = get(core, "terms", Dict{String,Any}())
    fusion_provider = length(get(providers, "fusion_reaction", Dict{String,Any}[])) == 1 ?
        only(providers["fusion_reaction"]) : Dict{String,Any}()
    radiation_provider = length(get(providers, "fuel_ion_bremsstrahlung",
        Dict{String,Any}[])) == 1 ? only(providers["fuel_ion_bremsstrahlung"]) :
        Dict{String,Any}()
    transport_provider = length(get(providers, "transport_response",
        Dict{String,Any}[])) == 1 ? only(providers["transport_response"]) :
        Dict{String,Any}()
    fusion_terms = get(fusion_provider, "terms", Dict{String,Any}())
    radiation_terms = get(radiation_provider, "terms", Dict{String,Any}())
    transport_terms = get(transport_provider, "terms", Dict{String,Any}())

    external_fusion = "fusion_reaction" in expected
    external_radiation = "fuel_ion_bremsstrahlung" in expected
    external_transport = "transport_response" in expected
    fusion_power = external_fusion ? get(fusion_terms, "total_fusion_power_w", nothing) :
        get(core_terms, "total_fusion_power_w", nothing)
    charged_power = external_fusion ? get(fusion_terms, "charged_fusion_power_w", nothing) :
        get(core_terms, "charged_fusion_power_w", nothing)
    neutral_power = external_fusion ? get(fusion_terms, "neutral_fusion_power_w", nothing) :
        get(core_terms, "neutral_fusion_power_w", nothing)
    radiation_power = external_radiation ?
        get(radiation_terms, "radiation_power_w", nothing) :
        get(core_terms, "radiation_power_w", nothing)
    transport_power = external_transport ?
        get(transport_terms, "total_energy_transport_power_w", nothing) :
        get(core_terms, "total_energy_transport_power_w", nothing)
    wall_terms = get(core_terms, "actuator_wall_power", Dict{String,Any}())
    wall_total = get(core_terms, "total_wall_input_power_w", nothing)
    conversion = get(core_terms, "electric_conversion_efficiency", nothing)
    gross_electric = fusion_power isa Real && conversion isa Real ?
        Float64(fusion_power) * Float64(conversion) : nothing
    net_lower = gross_electric isa Real && wall_total isa Real ?
        Float64(gross_electric) - Float64(wall_total) : nothing

    for item in contributions
        String(get(item, "status", "unknown")) == "complete" || append!(unresolved,
            String.(get(item, "unresolved_roles", ["contribution:$(item["module_id"])"])))
    end
    for (id, value) in (("total_fusion_power_w", fusion_power),
            ("charged_fusion_power_w", charged_power),
            ("neutral_fusion_power_w", neutral_power),
            ("radiation_power_w", radiation_power),
            ("total_energy_transport_power_w", transport_power),
            ("total_wall_input_power_w", wall_total),
            ("electric_conversion_efficiency", conversion))
        value isa Real || push!(unresolved, id)
    end
    status = !isempty(competing) ? "unsupported" : isempty(unresolved) ? "complete" :
        "unknown"
    body = Dict{String,Any}(
        "schema_version" => "1.0.0", "candidate_id" => manifest.candidate_id,
        "physics_hash" => manifest.physics_hash, "status" => status,
        "scope" => "coupled_control_volume_and_declared_actuators",
        "terms" => Dict{String,Any}(
            "total_fusion_power_w" => fusion_power,
            "charged_fusion_power_w" => charged_power,
            "neutral_fusion_power_w" => neutral_power,
            "radiation_power_w" => radiation_power,
            "total_energy_transport_power_w" => transport_power,
            "actuator_wall_power" => wall_terms,
            "total_wall_input_power_w" => wall_total,
            "gross_electric_power_w" => gross_electric,
            "net_electric_lower_bound_w" => net_lower),
        "externally_owned_term_ids" => sort!(collect(expected)),
        "unresolved_roles" => sort!(unique(unresolved)),
        "competing_roles" => sort!(unique(competing)),
        "source_module_ids" => sort!(String[item["module_id"] for item in contributions]),
        "claim_boundary" => "Control-volume fusion, radiation, transport and realized actuator wall input only; plant balance remains separate.")
    body["ledger_hash"] = canonical_hash(_csr_v1_json_safe(body))
    return body
end

function _v68_plan_body(plan::CoupledSolvePlanV1)
    return Dict{String,Any}("schema_version" => plan.schema_version,
        "candidate_id" => plan.candidate_id, "physics_hash" => plan.physics_hash,
        "manifest_hash" => plan.manifest_hash, "status" => String(plan.status),
        "state_ids" => plan.state_ids, "residual_row_ids" => plan.residual_row_ids,
        "state_scales" => plan.state_scales, "residual_scales" => plan.residual_scales,
        "lower_bounds" => plan.lower_bounds, "upper_bounds" => plan.upper_bounds,
        "differential_mask" => plan.differential_mask, "module_order" => plan.module_order,
        "dependency_graph" => plan.dependency_graph, "compiler_audits" => plan.compiler_audits,
        "reasons" => plan.reasons, "evidence_ceiling" => plan.evidence_ceiling)
end

function coupled_solve_plan_to_dict_v1(plan::CoupledSolvePlanV1)
    body = _v68_plan_body(plan)
    body["plan_hash"] = plan.plan_hash
    return body
end

_v68_status(value) = lowercase(String(value))

"Compile and fail-close the module/state/residual/Jacobian/mass dependency graph."
function compile_coupled_solve_plan_v1(manifest::CandidateSolveManifestV1,
        modules::Vector{<:AbstractResidualPhysicsModuleV1})
    reasons_unsupported = String[]
    reasons_unknown = String[]
    isempty(modules) && push!(reasons_unsupported, "no_residual_modules_selected")
    module_ids = String[residual_module_id(m) for m in modules]
    length(unique(module_ids)) == length(module_ids) ||
        push!(reasons_unsupported, "duplicate_module_id")
    states = StateBlockSpecV1[]
    residuals = ResidualBlockContractV1[]
    jacobians = JacobianBlockContractV1[]
    masses = MassMatrixBlockContractV1[]
    module_status = Dict{String,Any}()
    for m in modules
        id = residual_module_id(m)
        append!(states, state_layout(m, manifest))
        append!(residuals, residual_contracts(m, manifest))
        append!(jacobians, jacobian_contracts(m, manifest))
        append!(masses, mass_matrix_contracts(m, manifest))
        app = applicability(m, manifest)
        domain = validity_domain(m)
        module_status[id] = Dict("applicability" => app, "validity_domain" => domain)
        for record in (app, domain)
            status = _v68_status(get(record, "status", "unknown"))
            status == "unsupported" && push!(reasons_unsupported,
                "$id:$(get(record, "reason", "unsupported"))")
            status == "not_applicable" && push!(reasons_unsupported,
                "$id:not_applicable_selected_module")
            status in ("unknown", "insufficient") && push!(reasons_unknown,
                "$id:$(get(record, "reason", "validity_or_input_evidence_unknown"))")
        end
    end

    state_ids = reduce(vcat, (s.state_ids for s in states); init = String[])
    state_units = reduce(vcat, (s.units for s in states); init = String[])
    residual_units = reduce(vcat, (s.residual_units for s in states); init = String[])
    state_scales = reduce(vcat, (s.scales for s in states); init = Float64[])
    lower = reduce(vcat, (s.lower_bounds for s in states); init = Float64[])
    upper = reduce(vcat, (s.upper_bounds for s in states); init = Float64[])
    length(unique(state_ids)) == length(state_ids) ||
        push!(reasons_unsupported, "state_slot_has_multiple_owners")
    all(s -> length(s.state_ids) == length(s.units) == length(s.residual_units) ==
        length(s.scales) == length(s.lower_bounds) == length(s.upper_bounds), states) ||
        push!(reasons_unsupported, "state_block_vector_length_mismatch")
    all(isfinite, state_scales) && all(>(0.0), state_scales) ||
        push!(reasons_unsupported, "invalid_state_scale")
    all(i -> lower[i] < upper[i], eachindex(lower)) ||
        push!(reasons_unsupported, "invalid_state_bounds")
    all(s -> manifest.time_mode in s.allowed_time_modes, states) ||
        push!(reasons_unsupported, "state_block_time_mode_incompatible")
    manifest_regions = Dict{String,Any}()
    for region in manifest.regions
        id = String(get(region, "region_id", get(region, "id", "")))
        isempty(id) || (manifest_regions[id] = region)
    end
    for s in states
        haskey(manifest_regions, s.region_id) ||
            push!(reasons_unsupported, "state_block_region_not_declared:$(s.block_id)")
        declared_dimension = get(get(manifest_regions, s.region_id, Dict{String,Any}()),
            "spatial_dimension", nothing)
        declared_dimension === nothing || Int(declared_dimension) == s.spatial_dimension ||
            push!(reasons_unsupported, "state_block_dimension_incompatible:$(s.block_id)")
    end

    produced_rows = reduce(vcat, (r.row_state_ids for r in residuals); init = String[])
    governing_rows = reduce(vcat,
        (r.assembly_role == :governing ? r.row_state_ids : String[] for r in residuals);
        init = String[])
    all(r -> r.assembly_role in (:governing, :additive), residuals) ||
        push!(reasons_unsupported, "invalid_residual_assembly_role")
    for id in state_ids
        count(==(id), governing_rows) == 1 ||
            push!(reasons_unsupported, "state_requires_exactly_one_governing_residual:$id")
    end
    Set(produced_rows) == Set(state_ids) || begin
        for id in setdiff(Set(state_ids), Set(produced_rows))
            push!(reasons_unsupported, "missing_residual_producer:$id")
        end
        for id in setdiff(Set(produced_rows), Set(state_ids))
            push!(reasons_unsupported, "residual_row_without_state:$id")
        end
    end
    rows = copy(state_ids)
    unit_by_state = Dict(state_ids .=> residual_units)
    for r in residuals
        length(r.row_state_ids) == length(r.row_units) ||
            push!(reasons_unsupported, "$(r.block_id):residual_unit_length_mismatch")
        all(id -> id in state_ids, r.dependency_state_ids) ||
            push!(reasons_unsupported, "$(r.block_id):unknown_residual_dependency")
        all(id -> haskey(manifest_regions, id), r.region_ids) ||
            push!(reasons_unsupported, "$(r.block_id):residual_region_not_declared")
        for (id, unit) in zip(r.row_state_ids, r.row_units)
            get(unit_by_state, id, nothing) == unit ||
                push!(reasons_unsupported, "$(r.block_id):residual_unit_mismatch:$id")
        end
    end
    manifest_boundaries = Set(String(get(item, "boundary_id", get(item, "id", "")))
        for item in manifest.boundaries)
    for r in residuals
        all(id -> id in manifest_boundaries, r.boundary_ids) ||
            push!(reasons_unsupported, "$(r.block_id):boundary_not_declared")
    end

    mass_kinds = Dict{String,Vector{Symbol}}()
    for m in masses
        length(m.row_state_ids) == length(m.kinds) ||
            push!(reasons_unsupported, "$(m.block_id):mass_kind_length_mismatch")
        for (id, kind) in zip(m.row_state_ids, m.kinds)
            kind in (:differential, :algebraic) ||
                push!(reasons_unsupported, "$(m.block_id):invalid_mass_kind:$id")
            push!(get!(mass_kinds, id, Symbol[]), kind)
        end
    end
    for id in state_ids
        length(get(mass_kinds, id, Symbol[])) == 1 ||
            push!(reasons_unsupported, "state_requires_exactly_one_mass_or_constraint:$id")
    end
    differential = [get(mass_kinds, id, [:algebraic])[1] == :differential for id in state_ids]

    jac_by_block = Dict(j.block_id => j for j in jacobians)
    length(jac_by_block) == length(jacobians) ||
        push!(reasons_unsupported, "duplicate_jacobian_block")
    for r in residuals
        if !haskey(jac_by_block, r.block_id)
            push!(reasons_unsupported, "missing_jacobian_block:$(r.block_id)")
            continue
        end
        j = jac_by_block[r.block_id]
        j.mode in V68_JACOBIAN_MODES ||
            push!(reasons_unsupported, "$(r.block_id):invalid_jacobian_mode")
        j.mode == :unavailable && push!(reasons_unsupported,
            "$(r.block_id):jacobian_unavailable")
        j.mode == :finite_difference_l1_only && push!(reasons_unknown,
            "$(r.block_id):finite_difference_l1_evidence_ceiling")
        j.row_state_ids == r.row_state_ids ||
            push!(reasons_unsupported, "$(r.block_id):jacobian_row_slot_mismatch")
        Set(j.column_state_ids) == Set(r.dependency_state_ids) ||
            push!(reasons_unsupported, "$(r.block_id):jacobian_dependency_slot_mismatch")
    end

    exclusive = Dict{String,Vector{String}}()
    for r in residuals, output in r.exclusive_outputs
        push!(get!(exclusive, output, String[]), r.module_id)
    end
    for (output, owners) in exclusive
        length(unique(owners)) == 1 ||
            push!(reasons_unsupported, "exclusive_output_competition:$output")
    end
    term_contracts = Dict{String,Any}()
    expected_term_owners = Dict{String,Vector{String}}()
    provided_term_owners = Dict{String,Vector{String}}()
    for module_instance in modules
        id = residual_module_id(module_instance)
        contract = Dict{String,Any}(String(key) => value
            for (key, value) in coupled_term_contract(module_instance))
        expected_ids = sort!(unique(String.(get(contract, "expected_term_ids", String[]))))
        provided_ids = sort!(unique(String.(get(contract, "provided_term_ids", String[]))))
        term_contracts[id] = Dict("expected_term_ids" => expected_ids,
            "provided_term_ids" => provided_ids)
        for term_id in expected_ids
            push!(get!(expected_term_owners, term_id, String[]), id)
        end
        for term_id in provided_ids
            push!(get!(provided_term_owners, term_id, String[]), id)
        end
    end
    for (term_id, owners) in expected_term_owners
        length(owners) == 1 || push!(reasons_unsupported,
            "coupled_term_has_multiple_consumers:$term_id")
        provider_count = length(get(provided_term_owners, term_id, String[]))
        provider_count == 0 && push!(reasons_unknown,
            "coupled_term_missing_provider:$term_id")
        provider_count > 1 && push!(reasons_unsupported,
            "coupled_term_competing_providers:$term_id")
    end
    for term_id in setdiff(Set(keys(provided_term_owners)), Set(keys(expected_term_owners)))
        push!(reasons_unsupported, "coupled_term_without_consumer:$term_id")
    end
    flux_groups = Dict{Tuple{String,String},Vector{Dict{String,Any}}}()
    for r in residuals, flux in r.interface_fluxes
        key = (String(flux["interface_id"]), String(flux["account"]))
        push!(get!(flux_groups, key, Dict{String,Any}[]), flux)
    end
    for (key, group) in flux_groups
        signs = sort(Float64[get(item, "sign", 0.0) for item in group])
        length(group) == 2 && isapprox(signs[1], -signs[2]; atol = 0.0, rtol = 0.0) ||
            push!(reasons_unsupported, "interface_flux_not_equal_and_opposite:$(key[1]):$(key[2])")
        units = unique(String(get(item, "unit", "")) for item in group)
        length(units) == 1 && only(units) != "" ||
            push!(reasons_unsupported, "interface_flux_unit_mismatch:$(key[1]):$(key[2])")
    end

    edges = Dict{String,Any}[]
    for r in residuals, dep in r.dependency_state_ids
        push!(edges, Dict("from_state" => dep, "to_residual" => r.block_id,
            "to_state_rows" => r.row_state_ids))
    end
    graph = Dict{String,Any}("states" => state_ids,
        "residual_blocks" => [r.block_id for r in residuals], "edges" => edges,
        "module_status" => module_status, "coupled_term_contracts" => term_contracts)
    audits = Dict{String,Any}(
        "state_ownership" => length(unique(state_ids)) == length(state_ids) ? "pass" : "fail",
        "residual_producers" => Set(produced_rows) == Set(state_ids) &&
            all(id -> count(==(id), governing_rows) == 1, state_ids) ? "pass" : "fail",
        "mass_or_constraint" => all(id -> length(get(mass_kinds, id, Symbol[])) == 1,
            state_ids) ? "pass" : "fail",
        "jacobian_slots" => isempty(filter(x -> occursin("jacobian_", x),
            reasons_unsupported)) ? "pass" : "fail",
        "interface_flux_pairs" => isempty(filter(x -> occursin("interface_flux_", x),
            reasons_unsupported)) ? "pass" : "fail",
        "exclusive_outputs" => isempty(filter(x -> occursin("exclusive_output_", x),
            reasons_unsupported)) ? "pass" : "fail",
        "coupled_term_producers" => !isempty(filter(x ->
            occursin("coupled_term_missing_provider", x), reasons_unknown)) ? "unknown" :
            isempty(filter(x -> occursin("coupled_term_", x), reasons_unsupported)) ?
                "pass" : "fail",
        "routing_inputs" => "declared_capabilities_states_operators_domains_boundaries_only")
    status = !isempty(reasons_unsupported) ? :unsupported :
        !isempty(reasons_unknown) ? :unknown : :pass
    reasons = sort!(unique(vcat(reasons_unsupported, reasons_unknown)))
    ceiling = status == :pass ? "v68_nonlinear_coupled_runtime_eligible" :
        status == :unknown ? "L1_or_input_evidence_only" : "none_unsupported_graph"
    residual_scale_by_state = Dict{String,Float64}()
    for s in states, (id, scale) in zip(s.state_ids, s.scales)
        residual_scale_by_state[id] = scale
    end
    rscales = [get(residual_scale_by_state, id, 1.0) for id in rows]
    provisional = CoupledSolvePlanV1("1.0.0", manifest.candidate_id,
        manifest.physics_hash, manifest.manifest_hash, status, state_ids, rows,
        state_scales, rscales, lower, upper, differential, module_ids, graph, audits,
        reasons, ceiling, "")
    hash = canonical_hash(_v68_plan_body(provisional))
    return CoupledSolvePlanV1(provisional.schema_version, provisional.candidate_id,
        provisional.physics_hash, provisional.manifest_hash, provisional.status,
        provisional.state_ids, provisional.residual_row_ids, provisional.state_scales,
        provisional.residual_scales, provisional.lower_bounds, provisional.upper_bounds,
        provisional.differential_mask, provisional.module_order, provisional.dependency_graph,
        provisional.compiler_audits, provisional.reasons, provisional.evidence_ceiling, hash)
end

function _v68_contract_maps(manifest, modules)
    module_by_id = Dict(residual_module_id(m) => m for m in modules)
    residuals = reduce(vcat, (residual_contracts(m, manifest) for m in modules);
        init = ResidualBlockContractV1[])
    jacobians = reduce(vcat, (jacobian_contracts(m, manifest) for m in modules);
        init = JacobianBlockContractV1[])
    masses = reduce(vcat, (mass_matrix_contracts(m, manifest) for m in modules);
        init = MassMatrixBlockContractV1[])
    return module_by_id, residuals, Dict(j.block_id => j for j in jacobians), masses
end

function _v68_context(plan, manifest, block, state_index)
    return Dict{String,Any}("plan_hash" => plan.plan_hash,
        "manifest_hash" => manifest.manifest_hash, "block_id" => block.block_id,
        "state_index" => state_index, "row_state_ids" => block.row_state_ids,
        "dependency_state_ids" => block.dependency_state_ids)
end

function _v68_assemble_residual(plan, manifest, modules, u, du, t)
    state_index = Dict(id => i for (i, id) in enumerate(plan.state_ids))
    row_index = Dict(id => i for (i, id) in enumerate(plan.residual_row_ids))
    module_by_id, residuals, _, _ = _v68_contract_maps(manifest, modules)
    result = zeros(Float64, length(plan.residual_row_ids))
    blocks = Dict{String,Vector{Float64}}()
    for block in residuals
        local_r = zeros(Float64, length(block.row_state_ids))
        context = _v68_context(plan, manifest, block, state_index)
        residual_block!(local_r, module_by_id[block.module_id], u, du,
            manifest.parameters, t, context)
        blocks[block.block_id] = copy(local_r)
        for (id, value) in zip(block.row_state_ids, local_r)
            result[row_index[id]] += value
        end
    end
    return result, blocks
end

function _v68_assemble_jacobian(plan, manifest, modules, u, du, t)
    state_index = Dict(id => i for (i, id) in enumerate(plan.state_ids))
    row_index = Dict(id => i for (i, id) in enumerate(plan.residual_row_ids))
    module_by_id, residuals, jacobians, _ = _v68_contract_maps(manifest, modules)
    rows = Int[]; columns = Int[]; values = Float64[]
    local_blocks = Dict{String,Matrix{Float64}}()
    for block in residuals
        contract = jacobians[block.block_id]
        local_j = zeros(Float64, length(contract.row_state_ids),
            length(contract.column_state_ids))
        context = _v68_context(plan, manifest, block, state_index)
        context["column_state_ids"] = contract.column_state_ids
        jacobian_block!(local_j, module_by_id[block.module_id], u, du,
            manifest.parameters, t, context)
        local_blocks[block.block_id] = copy(local_j)
        for (i, rid) in enumerate(contract.row_state_ids),
                (j, cid) in enumerate(contract.column_state_ids)
            value = local_j[i, j]
            value == 0.0 && continue
            push!(rows, row_index[rid]); push!(columns, state_index[cid]); push!(values, value)
        end
    end
    return sparse(rows, columns, values, length(plan.residual_row_ids),
        length(plan.state_ids)), local_blocks
end

function _v68_assemble_mass(plan, manifest, modules, u, t)
    state_index = Dict(id => i for (i, id) in enumerate(plan.state_ids))
    module_by_id, _, _, masses = _v68_contract_maps(manifest, modules)
    matrix = spzeros(Float64, length(plan.state_ids), length(plan.state_ids))
    for contract in masses
        local_m = zeros(Float64, length(contract.row_state_ids), length(contract.row_state_ids))
        context = Dict{String,Any}("plan_hash" => plan.plan_hash,
            "manifest_hash" => manifest.manifest_hash, "block_id" => contract.block_id,
            "state_index" => state_index, "row_state_ids" => contract.row_state_ids)
        mass_matrix_block!(local_m, module_by_id[contract.module_id], u,
            manifest.parameters, t, context)
        for (i, rid) in enumerate(contract.row_state_ids),
                (j, cid) in enumerate(contract.row_state_ids)
            local_m[i, j] == 0.0 && continue
            matrix[state_index[rid], state_index[cid]] += local_m[i, j]
        end
    end
    return matrix
end

function _v68_gmres(A, b, tolerance, maximum_iterations)
    n = length(b)
    norm(b) <= tolerance && return zeros(Float64, n), true, 0
    m = min(maximum_iterations, n)
    V = zeros(Float64, n, m + 1)
    H = zeros(Float64, m + 1, m)
    beta = norm(b)
    V[:, 1] .= b ./ beta
    rhs = zeros(Float64, m + 1); rhs[1] = beta
    best = zeros(Float64, n)
    for k in 1:m
        w = A * view(V, :, k)
        for j in 1:k
            H[j, k] = dot(view(V, :, j), w)
            w .-= H[j, k] .* view(V, :, j)
        end
        H[k + 1, k] = norm(w)
        H[k + 1, k] > eps(Float64) && (V[:, k + 1] .= w ./ H[k + 1, k])
        y = H[1:k + 1, 1:k] \ rhs[1:k + 1]
        best .= V[:, 1:k] * y
        norm(A * best - b) <= tolerance && return best, true, k
    end
    return best, norm(A * best - b) <= max(tolerance, 1.0e-10), m
end

function _v68_scaled_norm(residual, scales)
    return maximum(abs.(residual) ./ max.(abs.(scales), eps(Float64)); init = 0.0)
end

function _v68_newton_step(plan, manifest, modules, u, u_l1, lambda, backend,
        history; time_term = nothing, previous = nothing, dt = 1.0, t = 0.0)
    tolerance = get(manifest.numerical_tolerances, "normalized_residual", 1.0e-8)
    du = zeros(Float64, length(u))
    for iteration in 1:backend.max_newton_iterations
        full_r, blocks = _v68_assemble_residual(plan, manifest, modules, u, du, t)
        full_j, _ = _v68_assemble_jacobian(plan, manifest, modules, u, du, t)
        if time_term === nothing
            residual = (1.0 - lambda) .* (u .- u_l1) .+ lambda .* full_r
            jacobian = (1.0 - lambda) .* sparse(I, length(u), length(u)) .+ lambda .* full_j
        else
            mass = _v68_assemble_mass(plan, manifest, modules, u, t)
            residual = mass * ((u .- previous) ./ dt) .+ full_r
            jacobian = mass ./ dt .+ full_j
        end
        norm_r = _v68_scaled_norm(residual, plan.residual_scales)
        push!(history, Dict("phase" => time_term === nothing ? "homotopy_newton" :
            "implicit_dae", "lambda" => lambda, "time" => t,
            "iteration" => iteration, "normalized_residual" => norm_r,
            "block_norms" => Dict(id => _v68_scaled_norm(value,
                fill(maximum(plan.residual_scales; init = 1.0), length(value)))
                for (id, value) in blocks)))
        norm_r <= tolerance && return u, true
        left_scale = spdiagm(0 => 1.0 ./ max.(plan.residual_scales, eps(Float64)))
        right_scale = spdiagm(0 => plan.state_scales)
        scaled_j = left_scale * jacobian * right_scale
        scaled_rhs = -(left_scale * residual)
        delta_scaled, ok, _ = _v68_gmres(scaled_j, scaled_rhs,
            max(tolerance * 0.1, 1.0e-12), backend.max_krylov_iterations)
        if !ok
            try
                delta_scaled = scaled_j \ scaled_rhs
            catch
                return u, false
            end
        end
        delta = right_scale * delta_scaled
        accepted = false
        step = 1.0
        for _ in 1:24
            trial = u .+ step .* delta
            feasible = all(i -> plan.lower_bounds[i] <= trial[i] <= plan.upper_bounds[i],
                eachindex(trial))
            if feasible
                trial_full, _ = _v68_assemble_residual(plan, manifest, modules,
                    trial, du, t)
                trial_r = time_term === nothing ?
                    (1.0 - lambda) .* (trial .- u_l1) .+ lambda .* trial_full :
                    _v68_assemble_mass(plan, manifest, modules, trial, t) *
                        ((trial .- previous) ./ dt) .+ trial_full
                if _v68_scaled_norm(trial_r, plan.residual_scales) < norm_r
                    u .= trial; accepted = true; break
                end
            end
            step *= 0.5
        end
        accepted || return u, false
    end
    return u, false
end

function audit_jacobian_blocks_v1(plan::CoupledSolvePlanV1,
        manifest::CandidateSolveManifestV1,
        modules::Vector{<:AbstractResidualPhysicsModuleV1}, u::Vector{Float64}; t = 0.0)
    state_index = Dict(id => i for (i, id) in enumerate(plan.state_ids))
    module_by_id, residuals, jacobians, _ = _v68_contract_maps(manifest, modules)
    row_index = Dict(id => i for (i, id) in enumerate(plan.residual_row_ids))
    audits = Dict{String,Any}[]
    du = zeros(Float64, length(u))
    for block in residuals
        contract = jacobians[block.block_id]
        context = _v68_context(plan, manifest, block, state_index)
        context["column_state_ids"] = contract.column_state_ids
        r0 = zeros(Float64, length(block.row_state_ids))
        residual_block!(r0, module_by_id[block.module_id], u, du,
            manifest.parameters, t, context)
        J = zeros(Float64, length(block.row_state_ids), length(contract.column_state_ids))
        jacobian_block!(J, module_by_id[block.module_id], u, du,
            manifest.parameters, t, context)
        scaled_direction = collect(1.0:length(contract.column_state_ids))
        scaled_direction ./= max(norm(scaled_direction), 1.0)
        physical_direction = [scaled_direction[j] *
            plan.state_scales[state_index[id]]
            for (j, id) in enumerate(contract.column_state_ids)]
        scaled_state_norm = norm(u ./ plan.state_scales)
        epsilon = sqrt(eps(Float64)) * max(scaled_state_norm, 1.0)
        perturbed = copy(u)
        for (j, id) in enumerate(contract.column_state_ids)
            perturbed[state_index[id]] += epsilon * physical_direction[j]
        end
        r1 = similar(r0)
        residual_block!(r1, module_by_id[block.module_id], perturbed, du,
            manifest.parameters, t, context)
        fd = (r1 .- r0) ./ epsilon
        jvp = J * physical_direction
        row_scales = [plan.residual_scales[row_index[id]]
            for id in contract.row_state_ids]
        scaled_fd = fd ./ row_scales
        scaled_jvp = jvp ./ row_scales
        error = norm(scaled_fd - scaled_jvp) /
            max(norm(scaled_fd), norm(scaled_jvp), contract.audit_absolute_tolerance)
        undeclared_error = 0.0
        for id in setdiff(plan.state_ids, contract.column_state_ids)
            trial = copy(u)
            trial[state_index[id]] += epsilon * plan.state_scales[state_index[id]]
            rx = similar(r0)
            residual_block!(rx, module_by_id[block.module_id], trial, du,
                manifest.parameters, t, context)
            undeclared_error = max(undeclared_error,
                norm(((rx .- r0) ./ epsilon) ./ row_scales))
        end
        passed = error <= contract.audit_relative_tolerance &&
            undeclared_error <= contract.audit_relative_tolerance
        push!(audits, Dict("block_id" => block.block_id, "mode" => String(contract.mode),
            "directional_relative_error" => error,
            "undeclared_dependency_error" => undeclared_error,
            "relative_tolerance" => contract.audit_relative_tolerance,
            "status" => passed ? "pass" : "fail"))
    end
    return audits
end

function _v68_interface_flux_audit(plan, manifest, modules, u)
    module_by_id, residuals, _, _ = _v68_contract_maps(manifest, modules)
    state_index = Dict(id => i for (i, id) in enumerate(plan.state_ids))
    grouped = Dict{Tuple{String,String},Vector{Dict{String,Any}}}()
    for block in residuals, declaration in block.interface_fluxes
        context = _v68_context(plan, manifest, block, state_index)
        value = zeros(Float64, 1)
        boundary_flux!(value, module_by_id[block.module_id], u, declaration, 0.0, context)
        record = Dict{String,Any}("module_id" => block.module_id,
            "block_id" => block.block_id, "interface_id" => declaration["interface_id"],
            "account" => declaration["account"], "unit" => declaration["unit"],
            "sign" => declaration["sign"], "residual_flux" => value[1])
        key = (String(declaration["interface_id"]), String(declaration["account"]))
        push!(get!(grouped, key, Dict{String,Any}[]), record)
    end
    pairs = Dict{String,Any}[]
    passed = true
    for (key, records) in sort!(collect(grouped); by = first)
        closure = sum(Float64(item["residual_flux"]) for item in records)
        scale = max(sum(abs(Float64(item["residual_flux"])) for item in records), 1.0)
        normalized = abs(closure) / scale
        tolerance = get(manifest.numerical_tolerances, "normalized_residual", 1.0e-8)
        pair_pass = length(records) == 2 && normalized <= tolerance
        passed &= pair_pass
        push!(pairs, Dict("interface_id" => key[1], "account" => key[2],
            "entries" => records, "closure_error" => closure,
            "normalized_closure_error" => normalized,
            "status" => pair_pass ? "pass" : "fail"))
    end
    return Dict{String,Any}("status" => passed ? "pass" : "fail",
        "pairs" => pairs, "pair_count" => length(pairs))
end

function _v68_envelope(manifest, plan, backend; status, classification_code,
        convergence_status, final_state = Dict{String,Float64}(), residual_history = Dict{String,Any}[],
        block_residuals = Dict{String,Any}[], trajectory = Dict{String,Any}[],
        observable_values = Dict{String,Any}(), audits = Dict{String,Any}(),
        reasons = String[], evidence_ceiling = "none")
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "candidate_id" => manifest.candidate_id, "physics_hash" => manifest.physics_hash,
        "manifest_hash" => manifest.manifest_hash, "plan_hash" => plan.plan_hash,
        "backend_id" => backend.backend_id, "status" => String(status),
        "classification_code" => classification_code,
        "convergence_status" => convergence_status, "final_state" => final_state,
        "residual_history" => residual_history, "block_residuals" => block_residuals,
        "trajectory" => trajectory, "observables" => observable_values, "audits" => audits,
        "unresolved_reasons" => sort!(unique(String.(reasons))),
        "evidence_ceiling" => evidence_ceiling)
    safe = _csr_v1_json_safe(body)
    return NonlinearSolveResultEnvelopeV1(safe["schema_version"], safe["candidate_id"],
        safe["physics_hash"], safe["manifest_hash"], safe["plan_hash"], safe["backend_id"],
        status, safe["classification_code"], safe["convergence_status"],
        Dict{String,Float64}(String(k) => Float64(v) for (k, v) in safe["final_state"]),
        safe["residual_history"], safe["block_residuals"], safe["trajectory"],
        safe["observables"], safe["audits"], safe["unresolved_reasons"],
        safe["evidence_ceiling"], canonical_hash(safe))
end

function nonlinear_solve_result_to_dict_v1(result::NonlinearSolveResultEnvelopeV1)
    return Dict{String,Any}("schema_version" => result.schema_version,
        "candidate_id" => result.candidate_id, "physics_hash" => result.physics_hash,
        "manifest_hash" => result.manifest_hash, "plan_hash" => result.plan_hash,
        "backend_id" => result.backend_id, "status" => String(result.status),
        "classification_code" => result.classification_code,
        "convergence_status" => result.convergence_status, "final_state" => result.final_state,
        "residual_history" => result.residual_history, "block_residuals" => result.block_residuals,
        "trajectory" => result.trajectory, "observables" => result.observables,
        "audits" => result.audits, "unresolved_reasons" => result.unresolved_reasons,
        "evidence_ceiling" => result.evidence_ceiling, "result_hash" => result.result_hash)
end

"Solve with L1 initialization, residual homotopy, damped Newton-Krylov and implicit DAE fallback."
function solve_coupled_plan_v1(manifest::CandidateSolveManifestV1,
        modules::Vector{<:AbstractResidualPhysicsModuleV1}, plan::CoupledSolvePlanV1;
        backend::AbstractNonlinearBackendAdapterV1 = NativeSparseNewtonKrylovBackendV1(),
        l1_state::Union{Nothing,Dict{String,<:Real}} = nothing)
    backend isa NativeSparseNewtonKrylovBackendV1 || throw(ArgumentError(
        "no implementation registered for backend adapter $(typeof(backend))"))
    plan.status == :unsupported && return _v68_envelope(manifest, plan, backend;
        status = :unsupported, classification_code = "unsupported_compiled_graph",
        convergence_status = "not_started", reasons = plan.reasons)
    plan.status == :unknown && return _v68_envelope(manifest, plan, backend;
        status = :unknown, classification_code = "unknown_input_or_validity_evidence",
        convergence_status = "not_started", reasons = plan.reasons,
        evidence_ceiling = plan.evidence_ceiling)
    initial = Dict{String,Float64}(manifest.initial_conditions)
    l1_state === nothing || merge!(initial,
        Dict{String,Float64}(String(k) => Float64(v) for (k, v) in l1_state))
    all(id -> haskey(initial, id), plan.state_ids) || return _v68_envelope(
        manifest, plan, backend; status = :unknown,
        classification_code = "unknown_missing_l1_initial_state",
        convergence_status = "not_started", reasons = ["L1_initial_state_does_not_cover_plan"])
    u_l1 = Float64[initial[id] for id in plan.state_ids]
    feasible = all(i -> plan.lower_bounds[i] <= u_l1[i] <= plan.upper_bounds[i], eachindex(u_l1))
    feasible || return _v68_envelope(manifest, plan, backend; status = :fail,
        classification_code = "fail_nonphysical_initial_state",
        convergence_status = "not_started", reasons = ["L1_initial_state_outside_bounds"])
    u = copy(u_l1)
    history = Dict{String,Any}[]
    converged = true
    for lambda in backend.homotopy_steps
        last_converged_u = copy(u)
        trial_u, step_ok = _v68_newton_step(plan, manifest, modules, copy(u), u_l1,
            lambda, backend, history)
        if !step_ok
            u = last_converged_u
            converged = false
            break
        end
        u = trial_u
    end
    trajectory = Dict{String,Any}[]
    if !converged
        previous = copy(u)
        dae_complete = true
        for step in 1:backend.dae_steps
            trial = copy(previous)
            trial, ok = _v68_newton_step(plan, manifest, modules, trial, u_l1, 1.0,
                backend, history; time_term = :implicit_dae, previous = previous,
                dt = backend.dae_dt, t = step * backend.dae_dt)
            ok || (dae_complete = false; break)
            previous .= trial
            push!(trajectory, Dict("time" => step * backend.dae_dt,
                "state" => Dict(plan.state_ids .=> copy(previous))))
        end
        if dae_complete
            final_state = Dict(plan.state_ids .=> previous)
            return _v68_envelope(manifest, plan, backend; status = :unknown,
                classification_code = "unknown_no_steady_state_transient_complete",
                convergence_status = "implicit_dae_trajectory_complete",
                final_state, residual_history = history, trajectory,
                reasons = ["full_steady_residual_did_not_converge"],
                evidence_ceiling = "v68_implicit_dae_trajectory_not_steady_pass")
        end
        return _v68_envelope(manifest, plan, backend; status = :unknown,
            classification_code = "unknown_nonlinear_and_dae_nonconvergence",
            convergence_status = "backend_exhausted", final_state = Dict(plan.state_ids .=> u),
            residual_history = history, trajectory,
            reasons = ["homotopy_step_failed", "implicit_dae_step_failed"],
            evidence_ceiling = "diagnostic_L1_and_partial_iteration_only")
    end

    final_r, blocks = _v68_assemble_residual(plan, manifest, modules, u,
        zeros(Float64, length(u)), 0.0)
    independent_r, _ = _v68_assemble_residual(plan, manifest, modules, copy(u),
        zeros(Float64, length(u)), 0.0)
    jacobian_audits = audit_jacobian_blocks_v1(plan, manifest, modules, u)
    jacobian_pass = all(item -> item["status"] == "pass", jacobian_audits)
    interface_audit = _v68_interface_flux_audit(plan, manifest, modules, u)
    tolerance = get(manifest.numerical_tolerances, "normalized_residual", 1.0e-8)
    block_records = Dict{String,Any}[]
    _, residual_contract_list, _, _ = _v68_contract_maps(manifest, modules)
    residual_contract_by_id = Dict(item.block_id => item for item in residual_contract_list)
    for (id, values) in sort!(collect(blocks); by = first)
        contract = residual_contract_by_id[id]
        push!(block_records, Dict("block_id" => id, "residual" => values,
            "assembly_role" => String(contract.assembly_role),
            "row_state_ids" => contract.row_state_ids, "region_ids" => contract.region_ids,
            "maximum_absolute_residual" => maximum(abs, values; init = 0.0)))
    end
    context = Dict{String,Any}("plan_hash" => plan.plan_hash,
        "manifest_hash" => manifest.manifest_hash,
        "state_index" => Dict(id => i for (i, id) in enumerate(plan.state_ids)))
    observable_values = Dict{String,Any}()
    for module_instance in modules
        observable_values[residual_module_id(module_instance)] =
            observables(module_instance, u, trajectory, context)
    end
    observable_values["candidate_power_ledger"] = compile_v68_power_ledger_v1(
        manifest, modules, u, trajectory, context)
    capacity_shortfall = any(get(value, "capacity_shortfall", false) === true
        for value in values(observable_values))
    state_blocks = reduce(vcat, (state_layout(item, manifest) for item in modules);
        init = StateBlockSpecV1[])
    spatial_modules = Set(block.module_id for block in state_blocks if block.spatial_dimension > 0)
    resolution_required = !isempty(spatial_modules)
    resolution_records = Dict{String,Any}[]
    for id in sort!(collect(spatial_modules))
        value = get(observable_values, id, Dict{String,Any}())
        trend = get(value, "resolution_trend", Dict{String,Any}())
        push!(resolution_records, Dict("module_id" => id,
            "status" => get(trend, "status", "unknown"),
            "levels" => get(trend, "levels", Any[]),
            "relative_changes" => get(trend, "relative_changes", Any[])))
    end
    resolution_pass = !resolution_required || all(item ->
        item["status"] == "pass" && Set(Int.(item["levels"])) == Set([32, 64, 128]),
        resolution_records)
    physical = all(i -> plan.lower_bounds[i] <= u[i] <= plan.upper_bounds[i], eachindex(u))
    residual_pass = _v68_scaled_norm(final_r, plan.residual_scales) <= tolerance
    independent_pass = norm(final_r - independent_r) <= max(tolerance, 1.0e-12)
    audits = Dict{String,Any}(
        "all_residual_blocks" => residual_pass ? "pass" : "fail",
        "conservation_slots" => [Dict("state_id" => id, "residual" => final_r[index])
            for (index, id) in enumerate(plan.residual_row_ids)],
        "interface_flux_pair_closure" => interface_audit,
        "independent_residual_recalculation" => independent_pass ? "pass" : "fail",
        "physical_state_bounds" => physical ? "pass" : "fail",
        "jacobian_directional_audits" => jacobian_audits,
        "candidate_power_ledger" => Dict(
            "status" => observable_values["candidate_power_ledger"]["status"],
            "unresolved_roles" =>
                observable_values["candidate_power_ledger"]["unresolved_roles"],
            "competing_roles" =>
                observable_values["candidate_power_ledger"]["competing_roles"]),
        "resolution_trend" => Dict("status" => !resolution_required ? "not_applicable" :
            resolution_pass ? "pass" : "unknown",
            "requested_levels" => manifest.discretization_levels,
            "module_records" => resolution_records),
        "l1_role" => "initial_state_homotopy_origin_and_diagnostic_baseline",
        "full_model_lambda" => 1.0)
    if capacity_shortfall
        return _v68_envelope(manifest, plan, backend; status = :fail,
            classification_code = "fail_actuator_capacity_shortfall",
            convergence_status = "nonlinear_residual_converged_but_capacity_violated",
            final_state = Dict(plan.state_ids .=> u), residual_history = history,
            block_residuals = block_records, trajectory, observable_values, audits,
            reasons = ["actuator_saturated_with_unmet_target"],
            evidence_ceiling = "failure_evidence_actuator_capacity")
    end
    if !(residual_pass && independent_pass && jacobian_pass && physical &&
            interface_audit["status"] == "pass")
        return _v68_envelope(manifest, plan, backend; status = :unknown,
            classification_code = "unknown_numerical_audit_failure",
            convergence_status = "nonlinear_solution_failed_post_audit",
            final_state = Dict(plan.state_ids .=> u), residual_history = history,
            block_residuals = block_records, trajectory, observable_values, audits,
            reasons = ["one_or_more_required_post_solve_audits_failed"],
            evidence_ceiling = "diagnostic_numerical_audit_only")
    end
    if !resolution_pass
        return _v68_envelope(manifest, plan, backend; status = :unknown,
            classification_code = "unknown_missing_resolution_trend",
            convergence_status = "nonlinear_residual_converged_resolution_evidence_incomplete",
            final_state = Dict(plan.state_ids .=> u), residual_history = history,
            block_residuals = block_records, trajectory, observable_values, audits,
            reasons = ["nonzero_dimensional_module_missing_32_64_128_trend"],
            evidence_ceiling = "v68_converged_state_without_resolution_evidence")
    end
    return _v68_envelope(manifest, plan, backend; status = :pass,
        classification_code = "pass_v68_full_coupled_residual",
        convergence_status = "homotopy_and_damped_newton_krylov_converged",
        final_state = Dict(plan.state_ids .=> u), residual_history = history,
        block_residuals = block_records, trajectory, observable_values, audits,
        evidence_ceiling = "v68_manufactured_or_declared_module_coupled_residual_evidence")
end

"A capability module used to validate that reaction, radiation and realized actuators share one residual."
struct ZeroDParticleEnergyActuatorModuleV1 <: AbstractResidualPhysicsModuleV1
    module_id::String
    region_id::String
    particle_target::Float64
    energy_target::Float64
    particle_capacity::Float64
    heating_capacity::Float64
    particle_loss::Float64
    energy_loss::Float64
    reaction_rate::Float64
    radiation_rate::Float64
    self_heating_fraction::Float64
    heating_efficiency::Float64
    particle_controller_gain::Float64
    energy_controller_gain::Float64
end

function ZeroDParticleEnergyActuatorModuleV1(; module_id = "zero_d_particle_energy_actuator_v1",
        region_id = "control_volume_0", particle_target = 1.0, energy_target = 1.0,
        particle_capacity = 2.0, heating_capacity = 2.0, particle_loss = 0.35,
        energy_loss = 0.25, reaction_rate = 0.08, radiation_rate = 0.04,
        self_heating_fraction = 0.2, heating_efficiency = 0.8,
        particle_controller_gain = 0.8, energy_controller_gain = 0.8)
    return ZeroDParticleEnergyActuatorModuleV1(String(module_id), String(region_id),
        particle_target, energy_target, particle_capacity, heating_capacity,
        particle_loss, energy_loss, reaction_rate, radiation_rate,
        self_heating_fraction, heating_efficiency, particle_controller_gain,
        energy_controller_gain)
end

residual_module_id(module_instance::ZeroDParticleEnergyActuatorModuleV1) = module_instance.module_id

function state_layout(module_instance::ZeroDParticleEnergyActuatorModuleV1,
        manifest::CandidateSolveManifestV1)
    return [StateBlockSpecV1(module_instance.module_id, "zero_d_state", module_instance.region_id,
        ["particle_inventory", "thermal_energy", "particle_actuator_output",
            "heating_actuator_output"], ["1", "J", "1/s", "W"],
        ["1/s", "W", "1/s", "W"], [1.0, 1.0, 1.0, 1.0],
        [1.0e-12, 1.0e-12, 0.0, 0.0],
        [floatmax(Float64), floatmax(Float64), module_instance.particle_capacity,
            module_instance.heating_capacity],
        0, ["steady", "transient", "pulsed"])]
end

function residual_contracts(module_instance::ZeroDParticleEnergyActuatorModuleV1,
        manifest::CandidateSolveManifestV1)
    ids = ["particle_inventory", "thermal_energy", "particle_actuator_output",
        "heating_actuator_output"]
    return [ResidualBlockContractV1(module_instance.module_id, "zero_d_coupled_balance",
        :governing, ids, ["1/s", "W", "1/s", "W"], ids, [module_instance.region_id], String[],
        Dict{String,Any}[], ["particle_actuator_output", "heating_actuator_output"])]
end

function jacobian_contracts(module_instance::ZeroDParticleEnergyActuatorModuleV1,
        manifest::CandidateSolveManifestV1)
    ids = ["particle_inventory", "thermal_energy", "particle_actuator_output",
        "heating_actuator_output"]
    return [JacobianBlockContractV1(module_instance.module_id, "zero_d_coupled_balance",
        :analytic, ids, ids, 2.0e-6, 1.0e-10)]
end

function mass_matrix_contracts(module_instance::ZeroDParticleEnergyActuatorModuleV1,
        manifest::CandidateSolveManifestV1)
    ids = ["particle_inventory", "thermal_energy", "particle_actuator_output",
        "heating_actuator_output"]
    return [MassMatrixBlockContractV1(module_instance.module_id, "zero_d_mass",
        ids, [:differential, :differential, :algebraic, :algebraic])]
end

validity_domain(module_instance::ZeroDParticleEnergyActuatorModuleV1) = Dict{String,Any}(
    "status" => "applicable", "particle_range" => [1.0e-12, "unbounded"],
    "energy_range" => [1.0e-12, "unbounded"], "spatial_dimension" => 0,
    "model_scope" => "manufactured_control_volume_particle_energy_actuator_closure")

applicability(module_instance::ZeroDParticleEnergyActuatorModuleV1,
    manifest::CandidateSolveManifestV1) = Dict{String,Any}("status" => "applicable",
    "reason" => "explicit_zero_dimensional_control_volume_contract",
    "routing_basis" => "declared_state_operator_and_time_semantics")

function _v68_zero_d_terms(module_instance, u, context)
    index = context["state_index"]
    n = u[index["particle_inventory"]]
    e = u[index["thermal_energy"]]
    xp = u[index["particle_actuator_output"]]
    xh = u[index["heating_actuator_output"]]
    reaction = module_instance.reaction_rate * n^2 * sqrt(e)
    radiation = module_instance.radiation_rate * e^2
    target_reaction = module_instance.reaction_rate * module_instance.particle_target^2 *
        sqrt(module_instance.energy_target)
    target_radiation = module_instance.radiation_rate * module_instance.energy_target^2
    particle_demand = module_instance.particle_loss * module_instance.particle_target +
        target_reaction + module_instance.particle_controller_gain *
        (module_instance.particle_target - n)
    heating_demand = (module_instance.energy_loss * module_instance.energy_target +
        target_radiation - module_instance.self_heating_fraction * target_reaction +
        module_instance.energy_controller_gain * (module_instance.energy_target - e)) /
        module_instance.heating_efficiency
    realized_particle = clamp(particle_demand, 0.0, module_instance.particle_capacity)
    realized_heating = clamp(heating_demand, 0.0, module_instance.heating_capacity)
    return (; n, e, xp, xh, reaction, radiation, particle_demand, heating_demand,
        realized_particle, realized_heating)
end

function residual_block!(r, module_instance::ZeroDParticleEnergyActuatorModuleV1,
        u, du, p, t, context)
    q = _v68_zero_d_terms(module_instance, u, context)
    index = context["state_index"]
    r[1] = du[index["particle_inventory"]] + module_instance.particle_loss * q.n +
        q.reaction - q.xp
    r[2] = du[index["thermal_energy"]] + module_instance.energy_loss * q.e +
        q.radiation - module_instance.self_heating_fraction * q.reaction -
        module_instance.heating_efficiency * q.xh
    r[3] = q.xp - q.realized_particle
    r[4] = q.xh - q.realized_heating
    return r
end

function jacobian_block!(J, module_instance::ZeroDParticleEnergyActuatorModuleV1,
        u, du, p, t, context)
    q = _v68_zero_d_terms(module_instance, u, context)
    dr_dn = 2.0 * module_instance.reaction_rate * q.n * sqrt(q.e)
    dr_de = module_instance.reaction_rate * q.n^2 / (2.0 * sqrt(q.e))
    J[1, 1] = module_instance.particle_loss + dr_dn
    J[1, 2] = dr_de
    J[1, 3] = -1.0
    J[2, 1] = -module_instance.self_heating_fraction * dr_dn
    J[2, 2] = module_instance.energy_loss + 2.0 * module_instance.radiation_rate * q.e -
        module_instance.self_heating_fraction * dr_de
    J[2, 4] = -module_instance.heating_efficiency
    particle_unsaturated = 0.0 < q.particle_demand < module_instance.particle_capacity
    heating_unsaturated = 0.0 < q.heating_demand < module_instance.heating_capacity
    J[3, 1] = particle_unsaturated ? module_instance.particle_controller_gain : 0.0
    J[3, 3] = 1.0
    J[4, 2] = heating_unsaturated ?
        module_instance.energy_controller_gain / module_instance.heating_efficiency : 0.0
    J[4, 4] = 1.0
    return J
end

function mass_matrix_block!(M, module_instance::ZeroDParticleEnergyActuatorModuleV1,
        u, p, t, context)
    M[1, 1] = 1.0
    M[2, 2] = 1.0
    return M
end

function source_terms!(s, module_instance::ZeroDParticleEnergyActuatorModuleV1,
        u, actuator_state, t, context)
    q = _v68_zero_d_terms(module_instance, u, context)
    s[1] = q.xp
    s[2] = module_instance.heating_efficiency * q.xh +
        module_instance.self_heating_fraction * q.reaction
    return s
end

function boundary_flux!(f, module_instance::ZeroDParticleEnergyActuatorModuleV1,
        u, boundary, t, context)
    q = _v68_zero_d_terms(module_instance, u, context)
    f[1] = module_instance.particle_loss * q.n + q.reaction
    f[2] = module_instance.energy_loss * q.e + q.radiation
    return f
end

function observables(module_instance::ZeroDParticleEnergyActuatorModuleV1,
        u, trajectory, context)
    q = _v68_zero_d_terms(module_instance, u, context)
    target_error = max(abs(q.n - module_instance.particle_target) /
        module_instance.particle_target, abs(q.e - module_instance.energy_target) /
        module_instance.energy_target)
    particle_saturated = q.particle_demand >= module_instance.particle_capacity * (1.0 - 1.0e-10)
    heating_saturated = q.heating_demand >= module_instance.heating_capacity * (1.0 - 1.0e-10)
    return Dict{String,Any}("particle_inventory" => q.n, "thermal_energy" => q.e,
        "reaction_rate" => q.reaction, "radiation_loss" => q.radiation,
        "particle_actuator_demand" => q.particle_demand,
        "particle_actuator_actual" => q.xp, "heating_actuator_demand" => q.heating_demand,
        "heating_actuator_actual" => q.xh, "maximum_target_relative_error" => target_error,
        "capacity_shortfall" => target_error > 1.0e-6 &&
            (particle_saturated || heating_saturated))
end
