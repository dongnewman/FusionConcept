const REALIZATION_MINIMALITY_V84_CLAIM_BOUNDARY =
    "v84 compares realizations only inside one declared fixed-topology grammar, one evidence level, and a common set of passed hard gates. Its low-order Stage 3-5 vertical slices are coupled residual tests, not finite-pressure equilibrium, all-mode stability, kinetic transport, engineering feasibility, net-power, or originality evidence."

const REALIZATION_COMPLEXITY_OBJECTIVES_V1 = [
    "component_count", "power_supply_count", "conductor_length_m",
    "maximum_curvature_m_inv", "support_mass_kg", "control_complexity"]

const REALIZATION_FIDELITY_LADDER_V1 = [
    "analytic_lower_bound", "fast_biot_savart", "poincare",
    "finite_pressure_equilibrium", "stability", "kinetic_transport",
    "complete_engineering", "vvuq_dual_code"]

const REALIZATION_BASIS_FAMILIES_V1 = Set([
    :periodic_fourier_coil, :periodic_bspline_coil, :current_potential,
    :plasma_boundary, :actuator_timing, :controller_modal])

"A component rule in a fixed-topology realization grammar."
struct RealizationComponentRuleV2
    component_kind::String
    required::Bool
    minimum_count::Int
    maximum_count::Int
    allowed_basis_families::Vector{Symbol}
end

"Declares the only realization choices over which a minimality claim is meaningful."
struct CandidateRealizationGrammarV2
    schema_version::String
    structure_hash::String
    topology_contract_id::String
    component_rules::Vector{RealizationComponentRuleV2}
    allowed_routes::Vector{String}
    grammar_hash::String
end

"Six independent complexity coordinates; no proxy-weighted scalar is authorized."
struct DeviceComplexityManifestV1
    schema_version::String
    candidate_binding_hash::String
    grammar_hash::String
    structure_hash::String
    evidence_level::String
    component_count::Int
    power_supply_count::Int
    conductor_length_m::Float64
    maximum_curvature_m_inv::Float64
    support_mass_kg::Float64
    control_complexity::Int
    source_hash::String
    manifest_hash::String
end

"Scope of a bounded minimality statement."
struct MinimalityScopeV1
    schema_version::String
    grammar_hash::String
    structure_hash::String
    evidence_level::String
    hard_gate_ids::Vector{String}
    complexity_objectives::Vector{String}
    included_component_kinds::Vector{String}
    excluded_component_kinds::Vector{String}
    fidelity_ladder::Vector{String}
    claim_boundary::String
    scope_hash::String
end

"Feasibility-first Pareto archive. Entries must pass every hard gate first."
mutable struct RealizationParetoArchiveV1
    schema_version::String
    scope::MinimalityScopeV1
    entries::Vector{Dict{String,Any}}
    rejected::Vector{Dict{String,Any}}
end

"Independent variant coordinates for a fixed structure hash."
struct RealizationVariantTupleV1
    structure_hash::String
    physical_variant::Int
    operating_variant::Int
    control_variant::Int
    tuple_hash::String
end

"Repository-owned low-order basis declaration."
struct RealizationBasisSpecV1
    basis_id::String
    family::Symbol
    order::Int
    coefficients::Vector{Float64}
    periods::Tuple{Int,Int}
    basis_hash::String
end

function _v84_rule_dict(rule::RealizationComponentRuleV2)
    return Dict{String,Any}("component_kind" => rule.component_kind,
        "required" => rule.required, "minimum_count" => rule.minimum_count,
        "maximum_count" => rule.maximum_count,
        "allowed_basis_families" => sort!(String.(rule.allowed_basis_families)))
end

function compile_candidate_realization_grammar_v2(; structure_hash,
        topology_contract_id = "fixed_graph_native_topology_v69",
        component_rules, allowed_routes = ["closed/mixed", "open/mixed"])
    length(String(structure_hash)) == 64 || throw(ArgumentError(
        "CandidateRealizationGrammarV2 requires a sha256-sized structure_hash"))
    rules = RealizationComponentRuleV2[]
    for raw in component_rules
        rule = raw isa RealizationComponentRuleV2 ? raw :
            RealizationComponentRuleV2(String(raw["component_kind"]),
                Bool(raw["required"]), Int(raw["minimum_count"]),
                Int(raw["maximum_count"]), Symbol.(raw["allowed_basis_families"]))
        0 <= rule.minimum_count <= rule.maximum_count || throw(ArgumentError(
            "invalid component count range for $(rule.component_kind)"))
        rule.required && rule.minimum_count < 1 && throw(ArgumentError(
            "required component $(rule.component_kind) must have minimum_count >= 1"))
        all(family -> family in REALIZATION_BASIS_FAMILIES_V1,
            rule.allowed_basis_families) || throw(ArgumentError(
            "unknown basis family in $(rule.component_kind)"))
        push!(rules, rule)
    end
    sort!(rules; by = rule -> rule.component_kind)
    length(unique(rule.component_kind for rule in rules)) == length(rules) ||
        throw(ArgumentError("component kinds must be unique"))
    routes = sort!(unique(String.(allowed_routes)))
    all(route -> route in ("closed/mixed", "open/mixed"), routes) ||
        throw(ArgumentError("v84 supports only closed/mixed and open/mixed slices"))
    body = Dict{String,Any}("schema_version" => "2.0.0",
        "structure_hash" => String(structure_hash),
        "topology_contract_id" => String(topology_contract_id),
        "component_rules" => _v84_rule_dict.(rules), "allowed_routes" => routes)
    return CandidateRealizationGrammarV2("2.0.0", String(structure_hash),
        String(topology_contract_id), rules, routes, canonical_hash(body))
end

function default_candidate_realization_grammar_v2(structure_hash::AbstractString)
    return compile_candidate_realization_grammar_v2(structure_hash = structure_hash,
        component_rules = [
            RealizationComponentRuleV2("magnetic_field_coil_set", true, 1, 2,
                [:periodic_fourier_coil, :periodic_bspline_coil, :current_potential]),
            RealizationComponentRuleV2("plasma_boundary_description", true, 1, 1,
                [:plasma_boundary]),
            RealizationComponentRuleV2("particle_fuel_exhaust_loop", true, 1, 1,
                Symbol[]),
            RealizationComponentRuleV2("heating_power_supply", true, 1, 2,
                [:actuator_timing]),
            RealizationComponentRuleV2("state_feedback_controller", true, 1, 1,
                [:controller_modal]),
            RealizationComponentRuleV2("auxiliary_trim_coil", false, 0, 1,
                [:periodic_fourier_coil, :periodic_bspline_coil]),
            RealizationComponentRuleV2("auxiliary_heating_supply", false, 0, 1,
                [:actuator_timing])])
end

function candidate_realization_grammar_to_dict_v2(grammar::CandidateRealizationGrammarV2)
    return Dict{String,Any}("schema_version" => grammar.schema_version,
        "structure_hash" => grammar.structure_hash,
        "topology_contract_id" => grammar.topology_contract_id,
        "component_rules" => _v84_rule_dict.(grammar.component_rules),
        "allowed_routes" => grammar.allowed_routes, "grammar_hash" => grammar.grammar_hash)
end

function compile_realization_variant_tuple_v1(grammar::CandidateRealizationGrammarV2;
        physical_variant, operating_variant, control_variant)
    values = Int[physical_variant, operating_variant, control_variant]
    all(>(0), values) || throw(ArgumentError("variant indices must be positive"))
    body = Dict{String,Any}("structure_hash" => grammar.structure_hash,
        "physical_variant" => values[1], "operating_variant" => values[2],
        "control_variant" => values[3])
    return RealizationVariantTupleV1(grammar.structure_hash, values...,
        canonical_hash(body))
end

function _v84_stream_rng(structure_hash, stream_id, variant)
    digest = canonical_hash(Dict("structure_hash" => String(structure_hash),
        "stream_id" => String(stream_id), "variant" => Int(variant)))
    seed = Int(parse(UInt64, digest[1:16]; base = 16) % UInt64(typemax(Int)))
    return MersenneTwister(seed)
end

function generate_decoupled_realization_binding_v1(
        grammar::CandidateRealizationGrammarV2, variants::RealizationVariantTupleV1)
    variants.structure_hash == grammar.structure_hash || throw(ArgumentError(
        "variant tuple and grammar structure hashes differ"))
    physical_rng = _v84_stream_rng(grammar.structure_hash, "physical",
        variants.physical_variant)
    operating_rng = _v84_stream_rng(grammar.structure_hash, "operating",
        variants.operating_variant)
    control_rng = _v84_stream_rng(grammar.structure_hash, "control",
        variants.control_variant)
    auxiliary_trim = rand(physical_rng) > 0.55
    auxiliary_heat = rand(control_rng) > 0.65
    fourier_coefficients = [0.08 * randn(physical_rng) for _ in 1:5]
    bspline_controls = [0.06 * randn(physical_rng) for _ in 1:6]
    current_potential_coefficients = [0.05 * randn(physical_rng) for _ in 1:5]
    boundary_coefficients = [0.04 * randn(physical_rng) for _ in 1:5]
    field_coil_count = auxiliary_trim ? 2 : 1
    geometry_metrics = _v84_low_order_coil_geometry_metrics(fourier_coefficients,
        bspline_controls, field_coil_count)
    physical = Dict{String,Any}(
        "physical_variant" => variants.physical_variant,
        "coil_fourier_coefficients" => fourier_coefficients,
        "coil_bspline_control_points" => bspline_controls,
        "current_potential_coefficients" => current_potential_coefficients,
        "plasma_boundary_coefficients" => boundary_coefficients,
        "field_coil_count" => field_coil_count,
        "auxiliary_trim_coil_enabled" => auxiliary_trim,
        "conductor_length_m" => geometry_metrics["conductor_length_m"],
        "maximum_curvature_m_inv" => geometry_metrics[
            "maximum_curvature_m_inv"],
        "support_mass_kg" => geometry_metrics["support_mass_kg"],
        "geometry_metric_model" => "sampled_low_order_centerline_v1")
    operating = Dict{String,Any}(
        "operating_variant" => variants.operating_variant,
        "target_particle_inventory" => 1.8 + 0.4 * rand(operating_rng),
        "target_ion_energy_j" => 0.85 + 0.3 * rand(operating_rng),
        "target_electron_energy_j" => 0.85 + 0.3 * rand(operating_rng),
        "density_scale" => 0.85 + 0.3 * rand(operating_rng),
        "temperature_scale" => 0.85 + 0.3 * rand(operating_rng))
    control = Dict{String,Any}(
        "control_variant" => variants.control_variant,
        "actuator_timing_coefficients" => [0.06 * randn(control_rng) for _ in 1:5],
        "controller_modal_coefficients" => [0.05 * randn(control_rng) for _ in 1:4],
        "active_controller_modes" => rand(control_rng, 1:3),
        "actuator_timing_knot_count" => rand(control_rng, 3:6),
        "auxiliary_heating_supply_enabled" => auxiliary_heat)
    body = Dict{String,Any}("structure_hash" => grammar.structure_hash,
        "grammar_hash" => grammar.grammar_hash, "variant_tuple_hash" => variants.tuple_hash,
        "physical" => physical, "operating" => operating, "control" => control)
    body["candidate_binding_hash"] = canonical_hash(body)
    return body
end

function compile_realization_basis_spec_v1(; basis_id, family, order,
        coefficients, periods = (1, 1))
    family_symbol = Symbol(family)
    family_symbol in REALIZATION_BASIS_FAMILIES_V1 ||
        throw(ArgumentError("unsupported realization basis family $family_symbol"))
    Int(order) >= 0 || throw(ArgumentError("basis order must be nonnegative"))
    values = Float64.(coefficients)
    isempty(values) && throw(ArgumentError("basis coefficients cannot be empty"))
    p = (Int(periods[1]), Int(periods[2]))
    all(>(0), p) || throw(ArgumentError("basis periods must be positive"))
    body = Dict{String,Any}("basis_id" => String(basis_id),
        "family" => String(family_symbol), "order" => Int(order),
        "coefficients" => values, "periods" => collect(p))
    return RealizationBasisSpecV1(String(basis_id), family_symbol, Int(order),
        values, p, canonical_hash(body))
end

function _v84_fourier(coefficients, angle, order)
    value = coefficients[1]
    cursor = 2
    for harmonic in 1:order
        cursor <= length(coefficients) && (value += coefficients[cursor] * cos(harmonic * angle))
        cursor += 1
        cursor <= length(coefficients) && (value += coefficients[cursor] * sin(harmonic * angle))
        cursor += 1
    end
    return value
end

function _v84_periodic_cubic_bspline(control_points, phase)
    count = length(control_points)
    count >= 4 || throw(ArgumentError("periodic cubic B-spline needs at least four controls"))
    coordinate = mod(Float64(phase), 2pi) / (2pi) * count
    cell = floor(Int, coordinate)
    x = coordinate - cell
    weights = ((1 - x)^3 / 6, (3x^3 - 6x^2 + 4) / 6,
        (-3x^3 + 3x^2 + 3x + 1) / 6, x^3 / 6)
    return sum(weights[j] * control_points[mod1(cell + j - 1, count)] for j in 1:4)
end

function _v84_low_order_coil_geometry_metrics(fourier_coefficients,
        bspline_controls, coil_count)
    point_count = 128
    total_length = 0.0
    maximum_curvature = 0.0
    for coil_index in 1:Int(coil_count)
        phase = 2pi * (coil_index - 1) / max(Int(coil_count), 1)
        points = Vector{Vector{Float64}}()
        for point_index in 0:point_count
            angle = 2pi * point_index / point_count
            radial_delta = 0.22 * (_v84_fourier(fourier_coefficients,
                angle + phase, 2) + _v84_periodic_cubic_bspline(
                    bspline_controls, angle - phase))
            radius = 3.0 + radial_delta
            vertical = 0.28 * _v84_fourier(fourier_coefficients,
                angle + phase + pi / 2, 2)
            push!(points, [radius * cos(angle), radius * sin(angle), vertical])
        end
        segment_lengths = [norm(points[index + 1] - points[index])
            for index in 1:point_count]
        total_length += sum(segment_lengths)
        for index in 2:point_count
            a = norm(points[index] - points[index - 1])
            b = norm(points[index + 1] - points[index])
            c = norm(points[index + 1] - points[index - 1])
            denominator = max(a * b * c, 1.0e-12)
            curvature = 2norm(cross(points[index] - points[index - 1],
                points[index + 1] - points[index - 1])) / denominator
            maximum_curvature = max(maximum_curvature, curvature)
        end
    end
    return Dict{String,Float64}(
        "conductor_length_m" => total_length,
        "maximum_curvature_m_inv" => maximum_curvature,
        "support_mass_kg" => 320.0 + 22.0 * total_length + 90.0 * Int(coil_count))
end

"Evaluate one of the six repository-owned low-order basis families."
function evaluate_realization_basis_v1(spec::RealizationBasisSpecV1, x::Real,
        y::Real = 0.0)
    c = spec.coefficients
    if spec.family == :periodic_bspline_coil
        return _v84_periodic_cubic_bspline(c, spec.periods[1] * x)
    elseif spec.family in (:periodic_fourier_coil, :plasma_boundary,
            :actuator_timing, :controller_modal)
        return _v84_fourier(c, spec.periods[1] * x, spec.order)
    elseif spec.family == :current_potential
        base = c[1]
        cursor = 2
        for mode in 1:spec.order
            cursor <= length(c) && (base += c[cursor] * cos(mode * spec.periods[1] * x))
            cursor += 1
            cursor <= length(c) && (base += c[cursor] * sin(mode * spec.periods[2] * y))
            cursor += 1
        end
        return base
    end
    throw(ArgumentError("unreachable basis family $(spec.family)"))
end

function default_realization_basis_library_v1(binding)
    physical = binding["physical"]; control = binding["control"]
    return Dict{Symbol,RealizationBasisSpecV1}(
        :periodic_fourier_coil => compile_realization_basis_spec_v1(
            basis_id = "coil_fourier_low_order", family = :periodic_fourier_coil,
            order = 2, coefficients = physical["coil_fourier_coefficients"]),
        :periodic_bspline_coil => compile_realization_basis_spec_v1(
            basis_id = "coil_periodic_bspline_low_order", family = :periodic_bspline_coil,
            order = 3, coefficients = physical["coil_bspline_control_points"]),
        :current_potential => compile_realization_basis_spec_v1(
            basis_id = "surface_current_potential_low_order", family = :current_potential,
            order = 2, coefficients = physical["current_potential_coefficients"]),
        :plasma_boundary => compile_realization_basis_spec_v1(
            basis_id = "plasma_boundary_low_order", family = :plasma_boundary,
            order = 2, coefficients = physical["plasma_boundary_coefficients"]),
        :actuator_timing => compile_realization_basis_spec_v1(
            basis_id = "actuator_timing_low_order", family = :actuator_timing,
            order = 2, coefficients = control["actuator_timing_coefficients"]),
        :controller_modal => compile_realization_basis_spec_v1(
            basis_id = "controller_modal_low_order", family = :controller_modal,
            order = 1, coefficients = control["controller_modal_coefficients"]))
end

const REALIZATION_RESIDUAL_STATE_IDS_V2 = [
    "coil_fourier_amplitude", "coil_bspline_amplitude",
    "current_potential_amplitude", "plasma_boundary_amplitude",
    "operating_density_scale", "operating_temperature_scale",
    "actuator_timing_amplitude", "controller_modal_amplitude",
    "stage5_stability_margin"]

"Low-order coil/operating/actuator block assembled directly into the v68 residual graph."
struct CandidateRealizationResidualModuleV2 <: AbstractResidualPhysicsModuleV1
    module_id::String
    region_id::String
    route::String
    binding::Dict{String,Any}
    basis_library::Dict{Symbol,RealizationBasisSpecV1}
    evidence_status::Dict{String,String}
end

function CandidateRealizationResidualModuleV2(; module_id, region_id, route,
        binding, basis_library = default_realization_basis_library_v1(binding),
        evidence_status = Dict(family => "complete_low_order" for family in
            String.(collect(REALIZATION_BASIS_FAMILIES_V1))))
    String(route) in ("closed/mixed", "open/mixed") ||
        throw(ArgumentError("unsupported v84 longitudinal route $route"))
    return CandidateRealizationResidualModuleV2(String(module_id), String(region_id),
        String(route), Dict{String,Any}(binding), basis_library,
        Dict{String,String}(String(k) => String(v) for (k, v) in evidence_status))
end

residual_module_id(module_instance::CandidateRealizationResidualModuleV2) =
    module_instance.module_id

function state_layout(module_instance::CandidateRealizationResidualModuleV2,
        manifest::CandidateSolveManifestV1)
    return [StateBlockSpecV1(module_instance.module_id,
        "realization_coil_operating_actuator_state_v2", module_instance.region_id,
        copy(REALIZATION_RESIDUAL_STATE_IDS_V2), fill("1", 9), fill("1", 9),
        ones(9), fill(1.0e-4, 9), fill(8.0, 9), 0,
        ["steady", "transient", "pulsed"])]
end

function _v84_realization_dependencies()
    return vcat(copy(REALIZATION_RESIDUAL_STATE_IDS_V2), [
        "fuel_a_inventory", "fuel_b_inventory", "ion_thermal_energy",
        "electron_thermal_energy", "ion_heating_output", "electron_heating_output"])
end

function residual_contracts(module_instance::CandidateRealizationResidualModuleV2,
        manifest::CandidateSolveManifestV1)
    return [ResidualBlockContractV1(module_instance.module_id,
        "realization_stage4_stage5_joint_constraints_v2", :governing,
        copy(REALIZATION_RESIDUAL_STATE_IDS_V2), fill("1", 9),
        _v84_realization_dependencies(), [module_instance.region_id], String[],
        Dict{String,Any}[], ["stage4_field_boundary_state", "stage5_stability_state"])]
end

function jacobian_contracts(module_instance::CandidateRealizationResidualModuleV2,
        manifest::CandidateSolveManifestV1)
    return [JacobianBlockContractV1(module_instance.module_id,
        "realization_stage4_stage5_joint_constraints_v2", :analytic,
        copy(REALIZATION_RESIDUAL_STATE_IDS_V2), _v84_realization_dependencies(),
        4.0e-6, 1.0e-8)]
end

function mass_matrix_contracts(module_instance::CandidateRealizationResidualModuleV2,
        manifest::CandidateSolveManifestV1)
    return [MassMatrixBlockContractV1(module_instance.module_id,
        "realization_stage4_stage5_algebraic_mass_v2",
        copy(REALIZATION_RESIDUAL_STATE_IDS_V2), fill(:algebraic, 9))]
end

function validity_domain(module_instance::CandidateRealizationResidualModuleV2)
    missing = sort!(String[family for family in String.(collect(
        REALIZATION_BASIS_FAMILIES_V1)) if get(module_instance.evidence_status,
        family, "unknown") != "complete_low_order"])
    status = isempty(missing) ? "applicable" : "unknown"
    return Dict{String,Any}("status" => status,
        "reason" => isempty(missing) ? "all_six_low_order_bases_candidate_bound" :
            "basis_evidence_incomplete:$(join(missing, ','))",
        "route" => module_instance.route, "missing_basis_evidence" => missing,
        "evidence_ceiling" => "L1_joint_residual_only")
end

applicability(module_instance::CandidateRealizationResidualModuleV2,
    manifest::CandidateSolveManifestV1) = validity_domain(module_instance)

function _v84_basis_targets(module_instance)
    library = module_instance.basis_library
    target(family, x, y = 0.0) = clamp(1.0 + evaluate_realization_basis_v1(
        library[family], x, y), 0.2, 2.0)
    return (fourier = target(:periodic_fourier_coil, 0.37),
        bspline = target(:periodic_bspline_coil, 1.11),
        potential = target(:current_potential, 0.73, 1.29),
        boundary = target(:plasma_boundary, 0.91),
        actuator = target(:actuator_timing, 0.41),
        controller = target(:controller_modal, 0.63))
end

function _v84_realization_state(module_instance, u, context)
    index = context["state_index"]
    value(id) = u[index[id]]
    targets = _v84_basis_targets(module_instance)
    operating = module_instance.binding["operating"]
    na = value("fuel_a_inventory"); nb = value("fuel_b_inventory")
    wi = value("ion_thermal_energy"); we = value("electron_thermal_energy")
    hi = value("ion_heating_output"); he = value("electron_heating_output")
    particle_target = Float64(operating["target_particle_inventory"])
    energy_target = Float64(operating["target_ion_energy_j"]) +
        Float64(operating["target_electron_energy_j"])
    heating_reference = max(0.275, 0.5 * energy_target)
    density_target = Float64(operating["density_scale"]) * (na + nb) / particle_target
    temperature_target = Float64(operating["temperature_scale"]) *
        (wi + we) / energy_target
    actuator_target = targets.actuator * (0.5 + 0.5 * (hi + he) / heating_reference)
    controller_target = targets.controller *
        (0.5 + 0.5 * value("actuator_timing_amplitude"))
    field_metric = (value("coil_fourier_amplitude") +
        value("coil_bspline_amplitude") + value("current_potential_amplitude")) / 3
    denominator = max(value("operating_density_scale") *
        value("operating_temperature_scale") * value("plasma_boundary_amplitude"),
        1.0e-8)
    route_factor = module_instance.route == "closed/mixed" ? 1.15 : 0.82
    stability_target = route_factor * field_metric^2 / denominator
    return (; value, targets, density_target, temperature_target, actuator_target,
        controller_target, field_metric, denominator, route_factor, stability_target,
        particle_target, energy_target, heating_reference, na, nb, wi, we, hi, he)
end

function residual_block!(r, module_instance::CandidateRealizationResidualModuleV2,
        u, du, parameters, t, context)
    q = _v84_realization_state(module_instance, u, context)
    r[1] = q.value("coil_fourier_amplitude") - q.targets.fourier
    r[2] = q.value("coil_bspline_amplitude") - q.targets.bspline
    r[3] = q.value("current_potential_amplitude") - q.targets.potential
    r[4] = q.value("plasma_boundary_amplitude") - q.targets.boundary
    r[5] = q.value("operating_density_scale") - q.density_target
    r[6] = q.value("operating_temperature_scale") - q.temperature_target
    r[7] = q.value("actuator_timing_amplitude") - q.actuator_target
    r[8] = q.value("controller_modal_amplitude") - q.controller_target
    r[9] = q.value("stage5_stability_margin") - q.stability_target
    return r
end

function jacobian_block!(J, module_instance::CandidateRealizationResidualModuleV2,
        u, du, parameters, t, context)
    q = _v84_realization_state(module_instance, u, context)
    columns = context["column_state_ids"]
    column(id) = findfirst(==(id), columns)
    for row in 1:9
        J[row, column(REALIZATION_RESIDUAL_STATE_IDS_V2[row])] = 1.0
    end
    density_factor = Float64(module_instance.binding["operating"]["density_scale"]) /
        q.particle_target
    J[5, column("fuel_a_inventory")] = -density_factor
    J[5, column("fuel_b_inventory")] = -density_factor
    temperature_factor = Float64(module_instance.binding["operating"][
        "temperature_scale"]) / q.energy_target
    J[6, column("ion_thermal_energy")] = -temperature_factor
    J[6, column("electron_thermal_energy")] = -temperature_factor
    heat_factor = -0.5 * q.targets.actuator / q.heating_reference
    J[7, column("ion_heating_output")] = heat_factor
    J[7, column("electron_heating_output")] = heat_factor
    J[8, column("actuator_timing_amplitude")] = -0.5 * q.targets.controller
    field_derivative = -q.route_factor * 2q.field_metric / (3q.denominator)
    for id in ("coil_fourier_amplitude", "coil_bspline_amplitude",
            "current_potential_amplitude")
        J[9, column(id)] = field_derivative
    end
    stability = q.stability_target
    J[9, column("operating_density_scale")] = stability /
        q.value("operating_density_scale")
    J[9, column("operating_temperature_scale")] = stability /
        q.value("operating_temperature_scale")
    J[9, column("plasma_boundary_amplitude")] = stability /
        q.value("plasma_boundary_amplitude")
    return J
end


function mass_matrix_block!(M, module_instance::CandidateRealizationResidualModuleV2,
        u, parameters, t, context)
    return M
end

function observables(module_instance::CandidateRealizationResidualModuleV2,
        u, trajectory, context)
    q = _v84_realization_state(module_instance, u, context)
    threshold = module_instance.route == "closed/mixed" ? 0.20 : 0.12
    return Dict{String,Any}("route" => module_instance.route,
        "basis_targets" => Dict(String(key) => value for (key, value) in
            pairs(q.targets)), "stage_residual_rows" => Dict(
            "stage_3" => LONGITUDINAL_STATE_IDS_V1,
            "stage_4" => REALIZATION_RESIDUAL_STATE_IDS_V2[1:6],
            "stage_5" => REALIZATION_RESIDUAL_STATE_IDS_V2[7:9]),
        "stage5_stability_margin" => q.value("stage5_stability_margin"),
        "stage5_required_margin" => threshold,
        "stage5_low_order_gate_passed" =>
            q.value("stage5_stability_margin") >= threshold,
        "joint_optimization_variables" => ["coil_basis", "operating_point",
            "actuator_timing", "controller_modes"],
        "evidence_ceiling" => "L1_joint_residual_only")
end

function _v84_complexity_body(item::DeviceComplexityManifestV1)
    return Dict{String,Any}("schema_version" => item.schema_version,
        "candidate_binding_hash" => item.candidate_binding_hash,
        "grammar_hash" => item.grammar_hash, "structure_hash" => item.structure_hash,
        "evidence_level" => item.evidence_level,
        "component_count" => item.component_count,
        "power_supply_count" => item.power_supply_count,
        "conductor_length_m" => item.conductor_length_m,
        "maximum_curvature_m_inv" => item.maximum_curvature_m_inv,
        "support_mass_kg" => item.support_mass_kg,
        "control_complexity" => item.control_complexity,
        "source_hash" => item.source_hash)
end

function compile_device_complexity_manifest_v1(
        grammar::CandidateRealizationGrammarV2, binding;
        evidence_level = "analytic_lower_bound", source_hash = binding[
            "candidate_binding_hash"])
    String(evidence_level) in REALIZATION_FIDELITY_LADDER_V1 ||
        throw(ArgumentError("unknown realization evidence level $evidence_level"))
    physical = binding["physical"]; control = binding["control"]
    required_count = sum(rule.minimum_count for rule in grammar.component_rules
        if rule.required)
    optional_count = Int(Bool(physical["auxiliary_trim_coil_enabled"])) +
        Int(Bool(control["auxiliary_heating_supply_enabled"]))
    component_count = required_count + optional_count
    power_supplies = 1 + Int(Bool(physical["auxiliary_trim_coil_enabled"])) +
        1 + Int(Bool(control["auxiliary_heating_supply_enabled"]))
    control_complexity = Int(control["active_controller_modes"]) +
        Int(control["actuator_timing_knot_count"]) + power_supplies
    provisional = DeviceComplexityManifestV1("1.0.0",
        String(binding["candidate_binding_hash"]), grammar.grammar_hash,
        grammar.structure_hash, String(evidence_level), component_count,
        power_supplies, Float64(physical["conductor_length_m"]),
        Float64(physical["maximum_curvature_m_inv"]),
        Float64(physical["support_mass_kg"]), control_complexity,
        String(source_hash), "")
    hash = canonical_hash(_v84_complexity_body(provisional))
    return DeviceComplexityManifestV1(provisional.schema_version,
        provisional.candidate_binding_hash, provisional.grammar_hash,
        provisional.structure_hash, provisional.evidence_level,
        provisional.component_count, provisional.power_supply_count,
        provisional.conductor_length_m, provisional.maximum_curvature_m_inv,
        provisional.support_mass_kg, provisional.control_complexity,
        provisional.source_hash, hash)
end

function device_complexity_manifest_to_dict_v1(item::DeviceComplexityManifestV1)
    body = _v84_complexity_body(item); body["manifest_hash"] = item.manifest_hash
    return body
end

function compile_minimality_scope_v1(grammar::CandidateRealizationGrammarV2;
        evidence_level = "analytic_lower_bound",
        hard_gate_ids = ["v68_plan_compiles", "v68_residual_converges",
            "stage3_balance", "stage4_field_boundary", "stage5_low_order_margin",
            "actuator_capacity", "finite_geometry"],
        excluded_component_kinds = String[])
    String(evidence_level) in REALIZATION_FIDELITY_LADDER_V1 ||
        throw(ArgumentError("unknown realization evidence level $evidence_level"))
    included = sort!(String[rule.component_kind for rule in grammar.component_rules])
    excluded = sort!(unique(String.(excluded_component_kinds)))
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "grammar_hash" => grammar.grammar_hash,
        "structure_hash" => grammar.structure_hash,
        "evidence_level" => String(evidence_level),
        "hard_gate_ids" => sort!(unique(String.(hard_gate_ids))),
        "complexity_objectives" => copy(REALIZATION_COMPLEXITY_OBJECTIVES_V1),
        "included_component_kinds" => included,
        "excluded_component_kinds" => excluded,
        "fidelity_ladder" => copy(REALIZATION_FIDELITY_LADDER_V1),
        "claim_boundary" => REALIZATION_MINIMALITY_V84_CLAIM_BOUNDARY)
    return MinimalityScopeV1("1.0.0", grammar.grammar_hash,
        grammar.structure_hash, String(evidence_level), body["hard_gate_ids"],
        body["complexity_objectives"], included, excluded,
        body["fidelity_ladder"], body["claim_boundary"], canonical_hash(body))
end

function minimality_scope_to_dict_v1(scope::MinimalityScopeV1)
    return Dict{String,Any}("schema_version" => scope.schema_version,
        "grammar_hash" => scope.grammar_hash, "structure_hash" => scope.structure_hash,
        "evidence_level" => scope.evidence_level,
        "hard_gate_ids" => scope.hard_gate_ids,
        "complexity_objectives" => scope.complexity_objectives,
        "included_component_kinds" => scope.included_component_kinds,
        "excluded_component_kinds" => scope.excluded_component_kinds,
        "fidelity_ladder" => scope.fidelity_ladder,
        "claim_boundary" => scope.claim_boundary, "scope_hash" => scope.scope_hash)
end

RealizationParetoArchiveV1(scope::MinimalityScopeV1) =
    RealizationParetoArchiveV1("1.0.0", scope, Dict{String,Any}[],
        Dict{String,Any}[])

function _v84_complexity_vector(item::DeviceComplexityManifestV1)
    return Float64[item.component_count, item.power_supply_count,
        item.conductor_length_m, item.maximum_curvature_m_inv,
        item.support_mass_kg, item.control_complexity]
end

function _v84_dominates(a::DeviceComplexityManifestV1,
        b::DeviceComplexityManifestV1)
    av = _v84_complexity_vector(a); bv = _v84_complexity_vector(b)
    return all(av .<= bv) && any(av .< bv)
end

function insert_realization_pareto_v1!(archive::RealizationParetoArchiveV1;
        candidate_id, complexity::DeviceComplexityManifestV1, hard_gates,
        payload = Dict{String,Any}())
    gate_map = Dict{String,Bool}(String(key) => Bool(value)
        for (key, value) in hard_gates)
    reasons = String[]
    complexity.grammar_hash == archive.scope.grammar_hash ||
        push!(reasons, "grammar_hash_mismatch")
    complexity.structure_hash == archive.scope.structure_hash ||
        push!(reasons, "structure_hash_mismatch")
    complexity.evidence_level == archive.scope.evidence_level ||
        push!(reasons, "evidence_level_mismatch")
    for gate_id in archive.scope.hard_gate_ids
        get(gate_map, gate_id, false) || push!(reasons, "hard_gate_not_passed:$gate_id")
    end
    record = Dict{String,Any}("candidate_id" => String(candidate_id),
        "complexity" => complexity, "hard_gates" => gate_map,
        "payload" => Dict{String,Any}(payload), "reasons" => sort!(unique(reasons)))
    if !isempty(reasons)
        push!(archive.rejected, record)
        return Dict{String,Any}("status" => "rejected_before_pareto",
            "reasons" => record["reasons"], "removed_candidate_ids" => String[])
    end
    any(existing -> _v84_dominates(existing["complexity"], complexity),
        archive.entries) && return Dict{String,Any}("status" => "dominated",
            "reasons" => ["dominated_within_scope"], "removed_candidate_ids" => String[])
    removed = String[]
    keep = Dict{String,Any}[]
    for existing in archive.entries
        if _v84_dominates(complexity, existing["complexity"])
            push!(removed, String(existing["candidate_id"]))
        else
            push!(keep, existing)
        end
    end
    archive.entries = keep
    push!(archive.entries, record)
    sort!(archive.entries; by = item -> (Tuple(_v84_complexity_vector(
        item["complexity"]))..., String(item["candidate_id"])))
    return Dict{String,Any}("status" => "inserted",
        "reasons" => String[], "removed_candidate_ids" => sort!(removed))
end

function realization_pareto_archive_to_dict_v1(archive::RealizationParetoArchiveV1)
    encode(record) = Dict{String,Any}("candidate_id" => record["candidate_id"],
        "complexity" => device_complexity_manifest_to_dict_v1(record["complexity"]),
        "hard_gates" => record["hard_gates"], "payload" => record["payload"],
        "reasons" => record["reasons"])
    body = Dict{String,Any}("schema_version" => archive.schema_version,
        "scope" => minimality_scope_to_dict_v1(archive.scope),
        "entries" => encode.(archive.entries), "rejected" => encode.(archive.rejected),
        "selection_rule" => "hard_gates_then_six_coordinate_nondominance_no_scalar_score")
    body["archive_hash"] = canonical_hash(body)
    return body
end

function _v84_longitudinal_parameters(binding, route)
    operating = binding["operating"]
    target_n = Float64(operating["target_particle_inventory"])
    target_wi = Float64(operating["target_ion_energy_j"])
    target_we = Float64(operating["target_electron_energy_j"])
    open_factor = route == "open/mixed" ? 1.35 : 1.0
    return Dict{String,Float64}(
        "charge_a" => 1.0, "charge_b" => 1.0, "particle_scale" => target_n,
        "energy_scale" => target_wi + target_we, "particle_rate_scale" => 1.0,
        "power_scale" => 1.0, "particle_transport_a_s" => 0.08 * open_factor,
        "particle_transport_b_s" => 0.08 * open_factor,
        "ion_energy_loss_s" => 0.08 * open_factor,
        "electron_energy_loss_s" => 0.08 * open_factor,
        "reaction_coefficient_per_particle_s" => 0.008,
        "reaction_energy_j" => 2.0, "alpha_ion_fraction" => 0.5,
        "alpha_electron_fraction" => 0.5,
        "radiation_coefficient_per_particle_s" => 0.008,
        "ion_electron_exchange_rate_s" => 0.02, "fuel_fraction_a" => 0.5,
        "fuel_fraction_b" => 0.5, "exhaust_fraction_a" => 0.5,
        "exhaust_fraction_b" => 0.5, "fueling_capacity_s" => 2.0,
        "ion_heating_capacity_w" => 2.0, "electron_heating_capacity_w" => 2.0,
        "exhaust_capacity_s" => 1.0, "radiation_control_capacity_w" => 1.0,
        "fueling_baseline_s" => 0.24 * open_factor,
        "ion_heating_baseline_w" => 0.10 * open_factor,
        "electron_heating_baseline_w" => 0.13 * open_factor,
        "exhaust_baseline_s" => 0.08 * open_factor,
        "radiation_control_baseline_w" => 0.015,
        "target_particle_inventory" => target_n,
        "target_ion_energy_j" => target_wi,
        "target_electron_energy_j" => target_we,
        "fueling_controller_gain_s" => 0.4, "ion_heating_controller_gain_s" => 0.4,
        "electron_heating_controller_gain_s" => 0.4,
        "exhaust_controller_gain_s" => 0.3, "radiation_controller_gain_s" => 0.3,
        "ion_heating_deposition_efficiency" => 0.8,
        "electron_heating_deposition_efficiency" => 0.8,
        "fueling_wall_energy_j_per_particle" => 0.1,
        "exhaust_wall_energy_j_per_particle" => 0.1,
        "ion_heating_wall_plug_efficiency" => 0.5,
        "electron_heating_wall_plug_efficiency" => 0.5,
        "radiation_control_wall_plug_efficiency" => 0.5,
        "electric_conversion_efficiency" => 0.4)
end

function compile_realization_vertical_slice_v84(
        grammar::CandidateRealizationGrammarV2,
        variants::RealizationVariantTupleV1, route::AbstractString)
    route in grammar.allowed_routes || throw(ArgumentError(
        "route $route is outside the declared realization grammar"))
    binding = generate_decoupled_realization_binding_v1(grammar, variants)
    parameters = _v84_longitudinal_parameters(binding, String(route))
    evidence = Dict(key => "complete" for key in keys(parameters))
    core = CandidateLongitudinalBalanceModuleV1(
        module_id = "v84_$(replace(String(route), '/' => '_'))_stage3_balance",
        region_id = "candidate_control_volume",
        transport_operator_id = route == "closed/mixed" ?
            "closed_mixed_low_order_transport_v1" :
            "open_mixed_low_order_transport_v1",
        parameters = parameters, parameter_evidence = evidence)
    realization = CandidateRealizationResidualModuleV2(
        module_id = "v84_$(replace(String(route), '/' => '_'))_stage4_stage5",
        region_id = "candidate_control_volume", route = route, binding = binding)
    initial = Dict{String,Float64}(
        "fuel_a_inventory" => 0.45 * parameters["target_particle_inventory"],
        "fuel_b_inventory" => 0.45 * parameters["target_particle_inventory"],
        "electron_inventory" => 0.90 * parameters["target_particle_inventory"],
        "ion_thermal_energy" => 0.90 * parameters["target_ion_energy_j"],
        "electron_thermal_energy" => 0.90 * parameters["target_electron_energy_j"],
        "fueling_output" => parameters["fueling_baseline_s"],
        "ion_heating_output" => parameters["ion_heating_baseline_w"],
        "electron_heating_output" => parameters["electron_heating_baseline_w"],
        "exhaust_output" => parameters["exhaust_baseline_s"],
        "radiation_control_output" => parameters["radiation_control_baseline_w"])
    for id in REALIZATION_RESIDUAL_STATE_IDS_V2
        initial[id] = 1.0
    end
    core_manifest = compile_longitudinal_candidate_manifest_v1(core;
        candidate_id = "v84_$(replace(String(route), '/' => '_'))_$(variants.tuple_hash[1:12])",
        physics_hash = binding["candidate_binding_hash"], initial_conditions =
            Dict(id => initial[id] for id in LONGITUDINAL_STATE_IDS_V1))
    layout = only(state_layout(realization, core_manifest))
    state_variables = vcat(core_manifest.state_variables,
        [Dict{String,Any}("state_id" => id, "unit" => unit)
            for (id, unit) in zip(layout.state_ids, layout.units)])
    manifest = CandidateSolveManifestV1(candidate_id = core_manifest.candidate_id,
        physics_hash = core_manifest.physics_hash, regions = core_manifest.regions,
        state_variables = state_variables,
        capability_declarations = vcat(core_manifest.capability_declarations,
            [Dict{String,Any}("capability_id" => id) for id in
                ("candidate_bound_low_order_coil_basis_v2",
                 "candidate_bound_operating_point_v1",
                 "candidate_bound_actuator_controller_basis_v1",
                 "joint_stage3_stage4_stage5_residual_v1")]),
        module_bindings = vcat(core_manifest.module_bindings,
            [Dict{String,Any}("module_id" => realization.module_id,
                "route" => String(route), "grammar_hash" => grammar.grammar_hash)]),
        time_mode = "steady", initial_conditions = initial,
        numerical_tolerances = Dict("normalized_residual" => 1.0e-8,
            "steady_time_term" => 1.0e-8, "relative_resolution" => 1.0e-8),
        discretization_levels = [16, 32, 64],
        applicability_scope = Dict{String,Any}(
            "minimality_scope" => "fixed_topology_declared_grammar_only",
            "evidence_ceiling" => "L1_joint_residual_only"),
        parameters = Dict{String,Any}("longitudinal" => parameters,
            "grammar_hash" => grammar.grammar_hash,
            "variant_tuple_hash" => variants.tuple_hash))
    modules = AbstractResidualPhysicsModuleV1[core, realization]
    plan = compile_coupled_solve_plan_v1(manifest, modules)
    return (binding = binding, core = core, realization = realization,
        manifest = manifest, modules = modules, plan = plan)
end

function evaluate_realization_vertical_slice_v84(
        grammar::CandidateRealizationGrammarV2,
        variants::RealizationVariantTupleV1, route::AbstractString;
        evidence_level = "analytic_lower_bound")
    compiled = compile_realization_vertical_slice_v84(grammar, variants, route)
    result = solve_coupled_plan_v1(compiled.manifest, compiled.modules, compiled.plan)
    realization_observables = get(result.observables,
        compiled.realization.module_id, Dict{String,Any}())
    physical = compiled.binding["physical"]
    normalized_final = isempty(result.residual_history) ? Inf : Float64(get(
        last(result.residual_history), "normalized_residual", Inf))
    hard_gates = Dict{String,Bool}(
        "v68_plan_compiles" => compiled.plan.status == :pass,
        "v68_residual_converges" => result.status == :pass && normalized_final <= 1.0e-8,
        "stage3_balance" => result.status == :pass,
        "stage4_field_boundary" => all(id -> haskey(result.final_state, id),
            REALIZATION_RESIDUAL_STATE_IDS_V2[1:6]),
        "stage5_low_order_margin" => Bool(get(realization_observables,
            "stage5_low_order_gate_passed", false)),
        "actuator_capacity" => result.classification_code !=
            "fail_actuator_capacity_shortfall",
        "finite_geometry" => Float64(physical["conductor_length_m"]) > 0.0 &&
            isfinite(Float64(physical["maximum_curvature_m_inv"])) &&
            Float64(physical["maximum_curvature_m_inv"]) <= 3.0)
    complexity = compile_device_complexity_manifest_v1(grammar, compiled.binding;
        evidence_level = evidence_level, source_hash = result.result_hash)
    return Dict{String,Any}("candidate_id" => compiled.manifest.candidate_id,
        "route" => String(route), "variant_tuple" => variants,
        "binding" => compiled.binding, "plan" => compiled.plan, "result" => result,
        "hard_gates" => hard_gates, "hard_gate_passed" => all(values(hard_gates)),
        "complexity" => complexity,
        "claim_boundary" => REALIZATION_MINIMALITY_V84_CLAIM_BOUNDARY)
end

"High-fidelity evidence controls only the next acquisition; it cannot rewrite prior feasibility."
function compile_one_way_fidelity_feedback_v1(; candidate_binding_hash,
        completed_level, completed_status, next_sample_count, next_basis_order,
        evidence_hash)
    level = String(completed_level)
    index = findfirst(==(level), REALIZATION_FIDELITY_LADDER_V1)
    index === nothing && throw(ArgumentError("unknown completed fidelity level $level"))
    next_level = index == length(REALIZATION_FIDELITY_LADDER_V1) ? nothing :
        REALIZATION_FIDELITY_LADDER_V1[index + 1]
    body = Dict{String,Any}(
        "candidate_binding_hash" => String(candidate_binding_hash),
        "completed_level" => level, "completed_status" => String(completed_status),
        "next_level" => next_level, "next_sample_count" => Int(next_sample_count),
        "next_basis_order" => Int(next_basis_order),
        "evidence_hash" => String(evidence_hash),
        "may_update_sampling" => true, "may_update_basis_order" => true,
        "may_rewrite_lower_fidelity_feasibility" => false,
        "credit_direction" => "forward_only")
    body["feedback_hash"] = canonical_hash(body)
    return body
end

"Compile an ordered, gap-free evidence ladder without cross-level feasibility credit."
function compile_realization_fidelity_progression_v1(; candidate_binding_hash,
        records)
    normalized = Dict{String,Any}[]
    for raw in records
        item = Dict{String,Any}(String(key) => value for (key, value) in raw)
        level = String(item["level"])
        level in REALIZATION_FIDELITY_LADDER_V1 ||
            throw(ArgumentError("unknown fidelity level $level"))
        status = String(item["status"])
        status in ("pass", "fail", "unknown", "unsupported") ||
            throw(ArgumentError("invalid fidelity status $status"))
        length(String(item["evidence_hash"])) == 64 || throw(ArgumentError(
            "fidelity evidence hash must be sha256-sized"))
        push!(normalized, Dict{String,Any}("level" => level, "status" => status,
            "evidence_hash" => String(item["evidence_hash"]),
            "feasibility_at_this_level" => status,
            "inherits_feasibility_credit_from_higher_level" => false))
    end
    indices = [findfirst(==(String(item["level"])),
        REALIZATION_FIDELITY_LADDER_V1) for item in normalized]
    indices == collect(1:length(indices)) || throw(ArgumentError(
        "fidelity records must be ordered, contiguous, and start at analytic_lower_bound"))
    may_advance = !isempty(normalized) && last(normalized)["status"] == "pass"
    next_level = may_advance && length(normalized) < length(
        REALIZATION_FIDELITY_LADDER_V1) ?
        REALIZATION_FIDELITY_LADDER_V1[length(normalized) + 1] : nothing
    body = Dict{String,Any}(
        "candidate_binding_hash" => String(candidate_binding_hash),
        "records" => normalized, "next_level" => next_level,
        "may_advance" => may_advance && next_level !== nothing,
        "higher_fidelity_may_update" => ["sampling", "basis_order"],
        "higher_fidelity_may_rewrite_lower_feasibility" => false,
        "credit_direction" => "forward_only")
    body["progression_hash"] = canonical_hash(body)
    return body
end

function run_fixed_topology_minimality_v84(grammar::CandidateRealizationGrammarV2;
        physical_variants = 1:2, operating_variants = 1:2,
        control_variants = 1:2, routes = grammar.allowed_routes,
        evidence_level = "analytic_lower_bound")
    String(evidence_level) == "analytic_lower_bound" || throw(ArgumentError(
        "the v84 native runner produces analytic_lower_bound evidence only; ingest later levels through the forward-only fidelity progression"))
    scope = compile_minimality_scope_v1(grammar; evidence_level = evidence_level)
    archive = RealizationParetoArchiveV1(scope)
    evaluations = Dict{String,Any}[]
    for physical in physical_variants, operating in operating_variants,
            control in control_variants, route in routes
        variants = compile_realization_variant_tuple_v1(grammar;
            physical_variant = physical, operating_variant = operating,
            control_variant = control)
        evaluation = evaluate_realization_vertical_slice_v84(grammar, variants, route;
            evidence_level = evidence_level)
        insert_realization_pareto_v1!(archive;
            candidate_id = evaluation["candidate_id"],
            complexity = evaluation["complexity"],
            hard_gates = evaluation["hard_gates"],
            payload = Dict{String,Any}("route" => route,
                "variant_tuple_hash" => variants.tuple_hash,
                "result_hash" => evaluation["result"].result_hash))
        push!(evaluations, evaluation)
    end
    archive_dict = realization_pareto_archive_to_dict_v1(archive)
    simplest = isempty(archive.entries) ? nothing : first(archive.entries)
    equivalent_ids = simplest === nothing ? String[] : sort!(String[
        entry["candidate_id"] for entry in archive.entries
        if _v84_complexity_vector(entry["complexity"]) ==
            _v84_complexity_vector(simplest["complexity"])])
    body = Dict{String,Any}("schema_version" => "1.0.0",
        "structure_hash" => grammar.structure_hash,
        "grammar" => candidate_realization_grammar_to_dict_v2(grammar),
        "scope" => minimality_scope_to_dict_v1(scope),
        "evaluated_count" => length(evaluations),
        "hard_gate_pass_count" => count(item -> item["hard_gate_passed"], evaluations),
        "pareto_archive" => archive_dict,
        "simplest_candidate_within_declared_grammar_and_evidence" =>
            simplest === nothing ? nothing : Dict{String,Any}(
                "candidate_id" => simplest["candidate_id"],
                "complexity" => device_complexity_manifest_to_dict_v1(
                    simplest["complexity"]), "payload" => simplest["payload"],
                "representative_selection_rule" =>
                    "lexicographic_six_coordinate_then_candidate_id",
                "representative_not_unique" => length(equivalent_ids) > 1,
                "pareto_equivalent_candidate_ids" => equivalent_ids),
        "fidelity_policy" => Dict{String,Any}(
            "ladder" => REALIZATION_FIDELITY_LADDER_V1,
            "high_fidelity_feedback_direction" => "sampling_and_basis_order_only",
            "retroactive_feasibility_credit" => false),
        "next_fidelity_queue" => [compile_realization_fidelity_progression_v1(
            candidate_binding_hash = entry["complexity"].candidate_binding_hash,
            records = [Dict{String,Any}("level" => evidence_level,
                "status" => "pass", "evidence_hash" =>
                    String(entry["payload"]["result_hash"]))])
            for entry in archive.entries],
        "claim_boundary" => REALIZATION_MINIMALITY_V84_CLAIM_BOUNDARY)
    body["result_hash"] = canonical_hash(body)
    return body
end
