const TRANSPORT_RESPONSE_STATE_IDS_V1 = ["fuel_a_inventory", "fuel_b_inventory",
    "electron_inventory", "ion_thermal_energy", "electron_thermal_energy"]
const TRANSPORT_RESPONSE_FLUX_IDS_V1 = ["fuel_a_particle_flux",
    "fuel_b_particle_flux", "ion_energy_flux", "electron_energy_flux"]

"Candidate-bound affine response of radial or parallel transport fluxes."
struct CandidateTransportResponseModuleV1 <: AbstractResidualPhysicsModuleV1
    module_id::String
    region_id::String
    candidate_binding_hash::String
    transport_operator_id::String
    flux_semantics::Symbol
    reference_state::Vector{Float64}
    reference_flux::Vector{Float64}
    response_jacobian::Matrix{Float64}
    validity_relative_radius::Float64
    evidence_status::Dict{String,String}
    source_result_hash::String
end

function CandidateTransportResponseModuleV1(; module_id, region_id,
        candidate_binding_hash, transport_operator_id, flux_semantics::Symbol,
        reference_state, reference_flux, response_jacobian,
        validity_relative_radius, evidence_status, source_result_hash)
    flux_semantics in (:radial_boundary, :parallel_boundary) || throw(ArgumentError(
        "transport flux semantics must be radial_boundary or parallel_boundary"))
    state = Float64.(reference_state); flux = Float64.(reference_flux)
    jacobian = Matrix{Float64}(response_jacobian)
    length(state) == 5 && length(flux) == 4 && size(jacobian) == (4, 5) ||
        throw(ArgumentError("transport response dimensions must be 5, 4 and 4x5"))
    all(isfinite, state) && all(isfinite, flux) && all(isfinite, jacobian) ||
        throw(ArgumentError("transport response must contain finite values"))
    all(>(0.0), state) || throw(ArgumentError(
        "transport reference state must be strictly positive"))
    radius = Float64(validity_relative_radius)
    isfinite(radius) && 0.0 < radius <= 1.0 || throw(ArgumentError(
        "transport response validity radius must be in (0,1]"))
    binding = _c2_check_hash_v1(String(candidate_binding_hash),
        "transport response candidate binding hash")
    result_hash = _c2_check_hash_v1(String(source_result_hash),
        "transport response source result hash")
    evidence = Dict{String,String}(String(key) => String(value)
        for (key, value) in evidence_status)
    return CandidateTransportResponseModuleV1(String(module_id), String(region_id),
        binding, String(transport_operator_id), flux_semantics, state, flux,
        jacobian, radius, evidence, result_hash)
end

residual_module_id(module_instance::CandidateTransportResponseModuleV1) =
    module_instance.module_id
coupled_term_contract(::CandidateTransportResponseModuleV1) = Dict{String,Any}(
    "expected_term_ids" => String[], "provided_term_ids" => ["transport_response"])
state_layout(::CandidateTransportResponseModuleV1,
    ::CandidateSolveManifestV1) = StateBlockSpecV1[]

function residual_contracts(module_instance::CandidateTransportResponseModuleV1,
        manifest::CandidateSolveManifestV1)
    return [ResidualBlockContractV1(module_instance.module_id,
        "candidate_transport_response", :additive,
        ["fuel_a_inventory", "fuel_b_inventory", "ion_thermal_energy",
            "electron_thermal_energy"],
        ["particle/s", "particle/s", "W", "W"],
        copy(TRANSPORT_RESPONSE_STATE_IDS_V1), [module_instance.region_id],
        String[], Dict{String,Any}[], ["particle_energy_transport_flux"])]
end

function jacobian_contracts(module_instance::CandidateTransportResponseModuleV1,
        manifest::CandidateSolveManifestV1)
    return [JacobianBlockContractV1(module_instance.module_id,
        "candidate_transport_response", :analytic,
        ["fuel_a_inventory", "fuel_b_inventory", "ion_thermal_energy",
            "electron_thermal_energy"], copy(TRANSPORT_RESPONSE_STATE_IDS_V1),
        3.0e-6, 1.0e-8)]
end

mass_matrix_contracts(::CandidateTransportResponseModuleV1,
    ::CandidateSolveManifestV1) = MassMatrixBlockContractV1[]

function validity_domain(module_instance::CandidateTransportResponseModuleV1)
    required = ["candidate_binding", "flux_values", "response_jacobian",
        "resolution_convergence", "validity_radius"]
    gaps = sort!(String[id for id in required
        if get(module_instance.evidence_status, id, "unknown") != "complete"])
    return Dict{String,Any}("status" => isempty(gaps) ? "applicable" : "unknown",
        "reason" => isempty(gaps) ? "candidate_bound_transport_response_covered" :
            "transport_response_evidence_incomplete:$(join(gaps, ","))",
        "transport_operator_id" => module_instance.transport_operator_id,
        "flux_semantics" => String(module_instance.flux_semantics),
        "evidence_gaps" => gaps,
        "source_result_hash" => module_instance.source_result_hash)
end

function applicability(module_instance::CandidateTransportResponseModuleV1,
        manifest::CandidateSolveManifestV1)
    manifest.physics_hash == module_instance.candidate_binding_hash || return
        Dict{String,Any}("status" => "unsupported",
            "reason" => "transport_response_candidate_binding_mismatch")
    return validity_domain(module_instance)
end

function _transport_response_flux_v1(module_instance, u, context)
    index = context["state_index"]
    state = Float64[u[index[id]] for id in TRANSPORT_RESPONSE_STATE_IDS_V1]
    relative_delta = (state .- module_instance.reference_state) ./
        module_instance.reference_state
    radius = maximum(abs, relative_delta)
    radius <= module_instance.validity_relative_radius || throw(DomainError(radius,
        "transport state left the declared local response domain"))
    flux = module_instance.reference_flux + module_instance.response_jacobian *
        (state - module_instance.reference_state)
    return state, relative_delta, flux
end

function residual_block!(r, module_instance::CandidateTransportResponseModuleV1,
        u, du, parameters, t, context)
    _, _, flux = _transport_response_flux_v1(module_instance, u, context)
    r .= flux
    return r
end

function jacobian_block!(J, module_instance::CandidateTransportResponseModuleV1,
        u, du, parameters, t, context)
    J .= module_instance.response_jacobian
    return J
end

function boundary_flux!(f, module_instance::CandidateTransportResponseModuleV1,
        u, boundary, t, context)
    _, _, flux = _transport_response_flux_v1(module_instance, u, context)
    length(f) == 4 || throw(ArgumentError("transport boundary flux requires four slots"))
    f .= flux
    return f
end

function observables(module_instance::CandidateTransportResponseModuleV1,
        u, trajectory, context)
    _, relative_delta, flux = _transport_response_flux_v1(module_instance, u, context)
    return Dict{String,Any}(
        "transport_operator_id" => module_instance.transport_operator_id,
        "flux_semantics" => String(module_instance.flux_semantics),
        "fluxes" => Dict(TRANSPORT_RESPONSE_FLUX_IDS_V1 .=> flux),
        "maximum_reference_state_relative_delta" => maximum(abs, relative_delta),
        "validity_relative_radius" => module_instance.validity_relative_radius,
        "claim_boundary" => "Candidate-bound local affine transport response inside its declared state radius; no extrapolation outside that domain.")
end

function power_ledger_contribution(module_instance::CandidateTransportResponseModuleV1,
        u, trajectory, context)
    _, _, flux = _transport_response_flux_v1(module_instance, u, context)
    return Dict{String,Any}(
        "role" => "particle_energy_transport",
        "status" => "complete",
        "provided_term_ids" => ["transport_response"],
        "unresolved_roles" => String[],
        "terms" => Dict{String,Any}(
            "ion_energy_transport_power_w" => flux[3],
            "electron_energy_transport_power_w" => flux[4],
            "total_energy_transport_power_w" => flux[3] + flux[4]),
        "flux_semantics" => String(module_instance.flux_semantics),
        "source_result_hash" => module_instance.source_result_hash)
end
