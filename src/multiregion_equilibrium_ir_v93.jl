const V93_PROTOCOL_ID = "fusionconceptai-v93-family-neutral-multiregion-20260828"
const MULTIREGION_EQUILIBRIUM_V93_CLAIM_BOUNDARY =
    "A compiled declaration proves structural well-posedness and capability requirements only. It grants no equilibrium, confinement, stability, validation, engineering, or promotion credit."

const V93_RESULT_STATUSES = Set([
    "fail_physical_model", "fail_invalid_geometry",
    "fail_boundary_or_interface_inconsistency",
    "fail_no_equilibrium_under_declared_model", "fail_numerical_convergence",
    "unknown_multiple_equilibrium_branches", "unknown_solver_disagreement",
    "unknown_validation_domain", "unsupported_operator_or_backend", "pass"])
const V93_REGION_TYPES = Set(["plasma", "vacuum", "coil", "wall", "open_loss", "terminal"])
const V93_OPERATOR_ROLES = Set(["governing", "additive"])

struct OperatorSpecV93
    operator_id::String
    role::String
    applicable_regions::Vector{String}
    required_states::Vector{String}
    conserved_quantities::Vector{String}
    residual_semantics::String
    source_citation::String
end

struct MultiRegionEquilibriumIRV93
    schema_version::String
    protocol_id::String
    regions::Vector{Dict{String,Any}}
    states::Vector{Dict{String,Any}}
    equations::Vector{Dict{String,Any}}
    interfaces::Vector{Dict{String,Any}}
    sources_sinks::Vector{Dict{String,Any}}
    model_validity_domains::Vector{Dict{String,Any}}
    evidence_obligations::Vector{String}
    discretization::Dict{String,Any}
    problem_hash::String
    access_audit::Vector{String}
end

function _v93_plain(value)
    value isa JSON3.Object && return Dict{String,Any}(String(k) => _v93_plain(v) for (k, v) in pairs(value))
    value isa AbstractDict && return Dict{String,Any}(String(k) => _v93_plain(v) for (k, v) in pairs(value))
    value isa JSON3.Array && return Any[_v93_plain(v) for v in value]
    value isa AbstractVector && return Any[_v93_plain(v) for v in value]
    value
end

_v93_sorted_plain(items) = sort!([_v93_plain(item) for item in items]; by = canonical_hash)

function default_operator_registry_v93()
    specs = [
        OperatorSpecV93("solenoidal_magnetic_constraint", "governing",
            ["plasma", "vacuum", "coil", "wall", "open_loss"], ["magnetic_field"],
            ["magnetic_flux"], "div(B)=0", "Maxwell magnetic Gauss law"),
        OperatorSpecV93("ampere_field_source_consistency", "governing",
            ["plasma", "vacuum", "coil", "wall", "open_loss"],
            ["magnetic_field", "current_density"], ["electric_current", "magnetic_flux"],
            "curl(B)/mu0-J-J_external=0", "Maxwell Ampere law"),
        OperatorSpecV93("declared_force_balance", "governing", ["plasma", "open_loss"],
            ["magnetic_field", "current_density", "pressure"], ["momentum"],
            "rho(u dot grad)u+grad(p)-J cross B-div(P_anisotropic)-F_declared=0",
            "steady momentum balance"),
        OperatorSpecV93("particle_conservation", "governing",
            ["plasma", "open_loss", "terminal"], ["density"], ["particles_by_species"],
            "div(Gamma_s)-S_s+L_s=0", "species continuity"),
        OperatorSpecV93("energy_conservation", "governing",
            ["plasma", "open_loss", "terminal", "wall"], ["species_temperature"],
            ["energy_by_species"], "div(q_s+h_s*Gamma_s)-Q_s+L_E_s=0",
            "species energy balance"),
        OperatorSpecV93("current_continuity", "governing",
            ["plasma", "vacuum", "coil", "wall", "open_loss", "terminal"],
            ["current_density"], ["electric_charge"], "div(J)-S_charge=0",
            "charge conservation"),
        OperatorSpecV93("induction_or_flux_balance", "governing",
            ["plasma", "vacuum", "coil", "wall", "open_loss"], ["magnetic_field"],
            ["magnetic_flux"], "declared steady or evolutionary Faraday residual",
            "Maxwell Faraday law"),
        OperatorSpecV93("vacuum_field_equations", "governing", ["vacuum"],
            ["vacuum_field"], ["magnetic_flux"], "curl(B_v)-mu0*J_external=0; div(B_v)=0",
            "vacuum Maxwell equations"),
        OperatorSpecV93("coil_circuit_coupling", "governing", ["coil"], ["coil_current"],
            ["magnetic_flux", "energy"], "V-RI-d(Phi_linked)/dt=0", "circuit Faraday law"),
        OperatorSpecV93("wall_electromagnetic_coupling", "governing", ["wall"],
            ["wall_current"], ["electric_charge", "magnetic_flux", "energy"],
            "declared thin or volume wall Ohm-Faraday residual", "resistive wall model"),
        OperatorSpecV93("anisotropic_pressure_addition", "additive", ["plasma", "open_loss"],
            ["pressure"], ["momentum"], "-div(P_anisotropic-pI)", "anisotropic stress"),
        OperatorSpecV93("flow_rotation_addition", "additive", ["plasma", "open_loss"],
            ["density", "flow_velocity"], ["momentum", "angular_momentum"],
            "declared inertial and rotating-frame terms", "fluid momentum balance"),
        OperatorSpecV93("extended_mhd_addition", "additive", ["plasma", "open_loss"],
            String[], ["declared"], "declared Hall electron-pressure resistive or two-fluid terms",
            "declared extended-MHD model"),
        OperatorSpecV93("material_transport_closure", "additive",
            ["plasma", "wall", "open_loss"], String[],
            ["particles_by_species", "energy", "momentum"], "declared constitutive flux",
            "declared material or transport closure"),
        OperatorSpecV93("source_sink_terminal_addition", "additive",
            ["plasma", "open_loss", "terminal"], String[], ["declared_inventory"],
            "declared source minus sink or terminal flux", "declared source/sink model")]
    Dict(spec.operator_id => spec for spec in specs)
end

function _v93_region_projection(region)
    Dict{String,Any}(
        "region_type" => get(region, "region_type", nothing),
        "dimension" => get(region, "dimension", nothing),
        "geometry_fields" => _v93_plain(get(region, "geometry_fields", Dict())),
        "material_fields" => _v93_plain(get(region, "material_fields", Dict())),
        "boundary_conditions" => _v93_sorted_plain(get(region, "boundary_conditions", Any[])))
end

function canonical_physics_projection_v93(declaration_raw)
    d = _v93_plain(declaration_raw)
    regions = get(d, "regions", Any[])
    signatures = Dict{String,String}()
    projected_regions = Dict{String,Any}[]
    for region in regions
        rid = String(get(region, "region_id", ""))
        body = _v93_region_projection(region)
        signatures[rid] = canonical_hash(body)
        push!(projected_regions, body)
    end
    states = Dict{String,Any}[]
    for state in get(d, "states", Any[])
        push!(states, Dict{String,Any}(
            "state_id" => get(state, "state_id", nothing),
            "region_signature" => get(signatures, String(get(state, "region_id", "")), "unresolved"),
            "units" => get(state, "units", nothing), "space" => get(state, "space", nothing),
            "components" => get(state, "components", 1),
            "species" => _v93_sorted_plain(get(state, "species", Any[]))))
    end
    equations = Dict{String,Any}[]
    for equation in get(d, "equations", Any[])
        push!(equations, Dict{String,Any}(
            "region_signature" => get(signatures, String(get(equation, "region_id", "")), "unresolved"),
            "state_owner" => get(equation, "state_owner", nothing),
            "units" => get(equation, "units", nothing),
            "governing_operator" => get(equation, "governing_operator", nothing),
            "additive_operators" => sort!(String.(get(equation, "additive_operators", Any[]))),
            "jacobian_blocks" => sort!(String.(get(equation, "jacobian_blocks", Any[]))),
            "conserved_quantities" => sort!(String.(get(equation, "conserved_quantities", Any[]))),
            "validity_domain" => _v93_plain(get(equation, "validity_domain", Dict())),
            "source_citation" => get(equation, "source_citation", nothing)))
    end
    interfaces = Dict{String,Any}[]
    for interface in get(d, "interfaces", Any[])
        endpoints = sort!([get(signatures, String(get(interface, "minus_region_id", "")), "unresolved"),
            get(signatures, String(get(interface, "plus_region_id", "")), "unresolved")])
        push!(interfaces, Dict{String,Any}(
            "endpoint_region_signatures" => endpoints,
            "geometry" => _v93_plain(get(interface, "geometry", Dict())),
            "conditions" => _v93_sorted_plain(get(interface, "conditions", Any[])),
            "coupling_method" => get(interface, "coupling_method", nothing),
            "multiplier_space" => get(interface, "multiplier_space", nothing)))
    end
    Dict{String,Any}(
        "schema_version" => "1.0.0", "protocol_id" => V93_PROTOCOL_ID,
        "regions" => _v93_sorted_plain(projected_regions), "states" => _v93_sorted_plain(states),
        "equations" => _v93_sorted_plain(equations), "interfaces" => _v93_sorted_plain(interfaces),
        "sources_sinks" => _v93_sorted_plain(get(d, "sources_sinks", Any[])),
        "model_validity_domains" => _v93_sorted_plain(get(d, "model_validity_domains", Any[])),
        "evidence_obligations" => sort!(unique(String.(get(d, "evidence_obligations", Any[])))),
        "discretization" => _v93_plain(get(d, "discretization", Dict())))
end

function compile_multiregion_equilibrium_ir_v93(declaration_raw;
        registry = default_operator_registry_v93())
    d = _v93_plain(declaration_raw)
    regions = Dict{String,Any}.(get(d, "regions", Any[]))
    states = Dict{String,Any}.(get(d, "states", Any[]))
    equations = Dict{String,Any}.(get(d, "equations", Any[]))
    interfaces = Dict{String,Any}.(get(d, "interfaces", Any[]))
    isempty(regions) && throw(ArgumentError("at least one explicit region is required"))
    region_ids = String[String(get(r, "region_id", "")) for r in regions]
    all(!isempty, region_ids) || throw(ArgumentError("every region requires region_id"))
    length(unique(region_ids)) == length(region_ids) || throw(ArgumentError("region_id must be unique"))
    for region in regions
        String(get(region, "region_type", "")) in V93_REGION_TYPES ||
            throw(ArgumentError("unsupported region_type declaration"))
        Int(get(region, "dimension", -1)) in 0:3 || throw(ArgumentError("region dimension must be 0..3"))
        haskey(region, "geometry_fields") || throw(ArgumentError("geometry_fields required for every region"))
        haskey(region, "material_fields") || throw(ArgumentError("material_fields required for every region"))
        haskey(region, "boundary_conditions") || throw(ArgumentError("boundary_conditions required for every region"))
    end
    state_ids = Set(String(get(s, "state_id", "")) for s in states)
    for state in states
        String(get(state, "region_id", "")) in region_ids || throw(ArgumentError("state owner region unresolved"))
        !isempty(String(get(state, "units", ""))) || throw(ArgumentError("state units required"))
        !isempty(String(get(state, "space", ""))) || throw(ArgumentError("state discrete space required"))
    end
    for equation in equations
        region_id = String(get(equation, "region_id", ""))
        region_id in region_ids || throw(ArgumentError("equation region unresolved"))
        owner = String(get(equation, "state_owner", ""))
        owner in state_ids || throw(ArgumentError("equation state owner unresolved"))
        governing = String(get(equation, "governing_operator", ""))
        haskey(registry, governing) || throw(ArgumentError("unregistered governing operator"))
        registry[governing].role == "governing" || throw(ArgumentError("equation must have exactly one governing operator"))
        for additive in String.(get(equation, "additive_operators", Any[]))
            haskey(registry, additive) || throw(ArgumentError("unregistered additive operator"))
            registry[additive].role == "additive" || throw(ArgumentError("non-additive operator in additive list"))
        end
        required = ("equation_id", "units", "jacobian_blocks", "conserved_quantities", "validity_domain", "source_citation")
        all(key -> haskey(equation, key), required) || throw(ArgumentError("equation residual metadata incomplete"))
    end
    for interface in interfaces
        minus = String(get(interface, "minus_region_id", "")); plus = String(get(interface, "plus_region_id", ""))
        minus in region_ids && plus in region_ids && minus != plus ||
            throw(ArgumentError("explicit interface endpoints invalid"))
        isempty(get(interface, "conditions", Any[])) && throw(ArgumentError("interface conditions required"))
        String(get(interface, "coupling_method", "")) in
            ("mixed_conforming_fem", "mortar", "lagrange_multiplier", "verified_nitsche") ||
            throw(ArgumentError("unsupported or penalty-only interface coupling"))
    end
    projection = canonical_physics_projection_v93(d)
    access = ["regions", "states", "equations", "interfaces", "sources_sinks",
        "model_validity_domains", "evidence_obligations", "discretization"]
    MultiRegionEquilibriumIRV93("1.0.0", V93_PROTOCOL_ID, regions, states, equations,
        interfaces, Dict{String,Any}.(get(d, "sources_sinks", Any[])),
        Dict{String,Any}.(get(d, "model_validity_domains", Any[])),
        sort!(unique(String.(get(d, "evidence_obligations", Any[])))),
        Dict{String,Any}(get(d, "discretization", Dict())), canonical_hash(projection), access)
end

function multiregion_equilibrium_ir_to_dict_v93(ir::MultiRegionEquilibriumIRV93)
    Dict{String,Any}("schema_version" => ir.schema_version, "protocol_id" => ir.protocol_id,
        "regions" => ir.regions, "states" => ir.states, "equations" => ir.equations,
        "interfaces" => ir.interfaces, "sources_sinks" => ir.sources_sinks,
        "model_validity_domains" => ir.model_validity_domains,
        "evidence_obligations" => ir.evidence_obligations, "discretization" => ir.discretization,
        "problem_hash" => ir.problem_hash, "access_audit" => ir.access_audit,
        "claim_boundary" => MULTIREGION_EQUILIBRIUM_V93_CLAIM_BOUNDARY)
end
