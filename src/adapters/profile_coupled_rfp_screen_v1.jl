const _PROFILE_COUPLED_RFP_SOURCE_BASIS = unique(vcat(
    _SELF_ORGANIZED_V7_SOURCE_BASIS,
    ["rfp_sheq_martines_2011", "rfp_mpfm_shen_sprott_1991"]))

const _PROFILE_COUPLED_RFP_CLAIM_BOUNDARY =
    "Fidelity-0 profile-coupled RFP rejection screen inside the sealed v5 " *
    "outer-envelope contracts. The alpha-Theta0 force-free profile is searched " *
    "with alpha >= 1.05 and F/Theta are derived by a deterministic cylindrical " *
    "ODE integration rather than independent genes. This does not establish a " *
    "3D helical equilibrium, Ohmic consistency, nonlinear resistive-MHD " *
    "stability, PPCD sustainment, reactor-scale transport, divertor operation, " *
    "net electricity, or reactor feasibility."

struct ProfileCoupledRFPScreenV1 <: AbstractEvaluator
    contract::SharedOuterEnvelopeContractV1
    allowed_contract_hashes::Set{String}
end

function ProfileCoupledRFPScreenV1(contract::SharedOuterEnvelopeContractV1;
        allowed_contracts::Vector{SharedOuterEnvelopeContractV1} =
            shared_outer_envelope_contracts_v1())
    ProfileCoupledRFPScreenV1(contract,
        Set(canonical_hash(_oe_contract_dict(item)) for item in allowed_contracts))
end

function evaluator_spec(::ProfileCoupledRFPScreenV1)
    EvaluatorSpec("profile_coupled_rfp_screen_v1", "1.0.0",
        ["reversed_field_pinch"], 0,
        Dict("rfp_current_profile_and_sustainment" => :proxy,
            "resistive_mhd_rfp" => :proxy, "rfp_mode_spectrum" => :proxy,
            "finite_build_coils" => :proxy, "coil_stress" => :proxy,
            "shielding" => :proxy, "maintenance_access" => :proxy,
            "neutronics" => :proxy, "actuator_power" => :proxy),
        "screening_only")
end

@inline function _pcrfp_rhs(x::Float64, bz::Float64, bt::Float64,
        theta0::Float64, alpha::Float64)
    lambda = 2.0theta0 * (1.0 - x^alpha)
    (-lambda * bt, lambda * bz - bt / x, 2.0bz * x)
end

"Deterministic fixed-step RK4 projection from an alpha-Theta0 profile to F/Theta."
function _pcrfp_profile_projection(theta0::Real, alpha::Real; steps::Int = 96)
    t0, a = Float64(theta0), Float64(alpha)
    0.05 <= t0 <= 6.0 || throw(ArgumentError("theta0 outside [0.05, 6]"))
    1.0 < a <= 12.0 || throw(ArgumentError("alpha must be in (1, 12]"))
    steps >= 32 || throw(ArgumentError("at least 32 RK4 steps are required"))
    epsilon = 1.0e-7
    h = (1.0 - epsilon) / steps
    x = epsilon
    bz = 1.0 - 0.5t0^2 * epsilon^2
    bt = t0 * epsilon
    mean = epsilon^2
    for _ in 1:steps
        k1 = _pcrfp_rhs(x, bz, bt, t0, a)
        k2 = _pcrfp_rhs(x + 0.5h, bz + 0.5h * k1[1],
            bt + 0.5h * k1[2], t0, a)
        k3 = _pcrfp_rhs(x + 0.5h, bz + 0.5h * k2[1],
            bt + 0.5h * k2[2], t0, a)
        k4 = _pcrfp_rhs(x + h, bz + h * k3[1], bt + h * k3[2], t0, a)
        bz += h / 6.0 * (k1[1] + 2k2[1] + 2k3[1] + k4[1])
        bt += h / 6.0 * (k1[2] + 2k2[2] + 2k3[2] + k4[2])
        mean += h / 6.0 * (k1[3] + 2k2[3] + 2k3[3] + k4[3])
        x += h
    end
    abs(mean) > 1.0e-12 || throw(ArgumentError(
        "cross-section averaged axial field is singular"))
    (theta0 = t0, alpha = a, reversal_parameter = bz / mean,
        pinch_parameter = bt / mean, mean_Bz_over_axis_Bz = mean,
        steps = steps)
end

function _pcrfp_profile_parameters(genome::Genome)
    theta0 = _so_target(genome, "screen_rfp_profile_theta0", NaN, "1")
    alpha = _so_target(genome, "screen_rfp_profile_alpha", NaN, "1")
    projection = _pcrfp_profile_projection(theta0, alpha)
    declared_f = _so_target(genome, "screen_reversal_parameter", NaN, "1")
    declared_theta = _so_target(genome, "screen_pinch_parameter", NaN, "1")
    return merge(projection, (declared_reversal_parameter = declared_f,
        declared_pinch_parameter = declared_theta,
        reversal_residual = declared_f - projection.reversal_parameter,
        pinch_residual = declared_theta - projection.pinch_parameter))
end

function _pcrfp_profile_margin(profile)
    min((profile.reversal_parameter + 0.35) / 0.25,
        (-0.02 - profile.reversal_parameter) / 0.08,
        (profile.pinch_parameter - 1.35) / 0.30,
        (1.95 - profile.pinch_parameter) / 0.30,
        (profile.alpha - 1.05) / 0.50)
end

function _pcrfp_nominal(genome::Genome, contract, features, profile)
    # The legacy confinement anchor contains a fractional Theta exponent.  A
    # profile outside the declared RFP domain may derive Theta <= 0; use a
    # positive numerical sentinel for that one anchor, then reject on the
    # explicit profile margin below. No out-of-domain candidate receives a pass.
    safe_features = merge(features,
        (pinch_parameter = max(features.pinch_parameter, 1.0e-6),))
    nominal = _so_nominal(genome, contract, safe_features)
    margin = _pcrfp_profile_margin(profile)
    nominal["margins"]["on_axis_regular_current_profile"] = margin
    nominal["rfp_profile_theta0"] = profile.theta0
    nominal["rfp_profile_alpha"] = profile.alpha
    nominal["derived_reversal_parameter"] = profile.reversal_parameter
    nominal["derived_pinch_parameter"] = profile.pinch_parameter
    nominal["profile_projection_steps"] = profile.steps
    nominal["physics_gate_passed"] =
        nominal["physics_gate_passed"] === true && margin >= 0.0
    nominal["minimum_normalized_margin"] =
        minimum(Float64.(collect(values(nominal["margins"]))))
    nominal
end

function _pcrfp_graph_errors(genome::Genome, features, profile, contract)
    errors = _so_graph_errors(genome, features, contract)
    profile.alpha >= 1.05 || push!(errors,
        "profile-coupled RFP requires alpha >= 1.05")
    abs(profile.reversal_residual) <= 1.0e-8 || push!(errors,
        "declared F is not derived from the current-profile ODE")
    abs(profile.pinch_residual) <= 1.0e-8 || push!(errors,
        "declared Theta is not derived from the current-profile ODE")
    current_sources = filter(source -> occursin("self_organized_plasma_current",
        lowercase(source.kind)), genome.field_sources)
    length(current_sources) == 1 || push!(errors,
        "exactly one self-organized plasma-current source is required")
    if length(current_sources) == 1
        source = only(current_sources)
        for (name, expected) in (("profile_theta0", profile.theta0),
                ("profile_alpha", profile.alpha),
                ("derived_reversal_parameter", profile.reversal_parameter),
                ("derived_pinch_parameter", profile.pinch_parameter))
            q = get(source.parameters, name, nothing)
            if q === nothing || q.unit != "1" ||
                    !isapprox(q.value, expected; rtol = 1.0e-10, atol = 1.0e-10)
                push!(errors, "plasma-current source $name is not synchronized")
            end
        end
    end
    sort!(unique(errors))
end

function evaluator_applicability(evaluator::ProfileCoupledRFPScreenV1,
        genome::Genome)
    genome.family == "reversed_field_pinch" || return false,
        "profile-coupled screen applies only to reversed_field_pinch"
    genome.mission.fuel == "D-T" || return false,
        "profile-coupled screen is restricted to the common D-T mission"
    try
        profile = _pcrfp_profile_parameters(genome)
        features = _so_features(genome)
        isempty(_pcrfp_graph_errors(genome, features, profile,
            evaluator.contract)) || return false,
            "profile-coupled RFP graph or parameter synchronization failed"
    catch error
        return false, sprint(showerror, error)
    end
    true, "same outer-envelope contract with a causally derived RFP profile"
end

function _pcrfp_robustness(genome::Genome, contract, features, profile)
    rng = MersenneTwister(contract.base.robustness_seed + 8)
    records, pass_count, worst = Dict{String,Any}[], 0, Inf
    for sample in 1:contract.base.robustness_samples
        field_delta = 0.02 * (2rand(rng) - 1)
        beta_delta = 0.15 * (2rand(rng) - 1)
        dimension_delta = 0.01 * (2rand(rng) - 1)
        coil_offset_m = 0.003 * (2rand(rng) - 1)
        control_error = 0.10 * (2rand(rng) - 1)
        target_occlusion = 0.10rand(rng)
        theta0_error = 0.02 * (2rand(rng) - 1)
        alpha_error = 0.05 * (2rand(rng) - 1)
        perturbed_profile = _pcrfp_profile_projection(
            profile.theta0 * (1 + theta0_error),
            max(1.000001, profile.alpha * (1 + alpha_error)))
        perturbed_features = merge(features, (
            reversal_parameter = perturbed_profile.reversal_parameter,
            pinch_parameter = perturbed_profile.pinch_parameter))
        quality_penalty = abs(coil_offset_m) /
            max(contract.outer_radial_extent_m, 1.0e-9) +
            0.03abs(control_error)
        safe_perturbed_features = merge(perturbed_features,
            (pinch_parameter = max(
                perturbed_features.pinch_parameter, 1.0e-6),))
        nominal = _so_nominal(genome, contract, safe_perturbed_features;
            field_multiplier = 1 + field_delta,
            beta_multiplier = 1 + beta_delta,
            dimension_multiplier = 1 + dimension_delta,
            field_quality_penalty = quality_penalty,
            control_multiplier = 1 + control_error,
            target_area_multiplier = 1 - target_occlusion)
        profile_margin = _pcrfp_profile_margin(perturbed_profile)
        nominal["margins"]["on_axis_regular_current_profile"] = profile_margin
        passed = nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true && profile_margin >= 0
        passed && (pass_count += 1)
        sample_worst = minimum(Float64.(collect(values(nominal["margins"]))))
        worst = min(worst, sample_worst)
        push!(records, Dict{String,Any}(
            "sample" => sample, "field_delta_fraction" => field_delta,
            "beta_delta_fraction" => beta_delta,
            "dimension_delta_fraction" => dimension_delta,
            "coil_offset_m" => coil_offset_m,
            "control_power_error_fraction" => control_error,
            "target_occlusion_fraction" => target_occlusion,
            "profile_theta0_error_fraction" => theta0_error,
            "profile_alpha_error_fraction" => alpha_error,
            "derived_reversal_parameter" =>
                perturbed_profile.reversal_parameter,
            "derived_pinch_parameter" => perturbed_profile.pinch_parameter,
            "passed" => passed,
            "minimum_normalized_margin" => sample_worst))
    end
    fraction = pass_count / contract.base.robustness_samples
    Dict{String,Any}(
        "sample_count" => contract.base.robustness_samples,
        "common_random_seed" => contract.base.robustness_seed + 8,
        "pass_count" => pass_count, "pass_fraction" => fraction,
        "required_pass_fraction" =>
            contract.base.robustness_required_pass_fraction,
        "gate_passed" =>
            fraction >= contract.base.robustness_required_pass_fraction,
        "worst_minimum_normalized_margin" => worst, "records" => records)
end

function _profile_coupled_rfp_result(e::ProfileCoupledRFPScreenV1,
        genome::Genome)
    features0 = _so_features(genome)
    profile = _pcrfp_profile_parameters(genome)
    features = merge(features0, (
        reversal_parameter = profile.reversal_parameter,
        pinch_parameter = profile.pinch_parameter))
    graph_errors = _pcrfp_graph_errors(genome, features, profile, e.contract)
    graph_gate = isempty(graph_errors)
    nominal = _pcrfp_nominal(genome, e.contract, features, profile)
    robustness = if graph_gate && nominal["physics_gate_passed"] === true &&
            nominal["engineering_gate_passed"] === true
        _pcrfp_robustness(genome, e.contract, features, profile)
    else
        Dict{String,Any}(
            "sample_count" => 0,
            "maximum_sample_budget" => e.contract.base.robustness_samples,
            "common_random_seed" => e.contract.base.robustness_seed + 8,
            "pass_count" => 0, "pass_fraction" => 0.0,
            "required_pass_fraction" =>
                e.contract.base.robustness_required_pass_fraction,
            "gate_passed" => false,
            "worst_minimum_normalized_margin" =>
                nominal["minimum_normalized_margin"],
            "records" => Dict{String,Any}[],
            "skipped_due_nominal_gate_failure" => true)
    end
    contract_hash = canonical_hash(_oe_contract_dict(e.contract))
    contract_gate = contract_hash in e.allowed_contract_hashes
    all_five = graph_gate && nominal["physics_gate_passed"] === true &&
        nominal["engineering_gate_passed"] === true && contract_gate &&
        robustness["gate_passed"] === true
    result = Dict{String,Any}(
        "contract" => _oe_contract_dict(e.contract),
        "contract_hash" => contract_hash,
        "claim_boundary" => _PROFILE_COUPLED_RFP_CLAIM_BOUNDARY,
        "source_basis" => _PROFILE_COUPLED_RFP_SOURCE_BASIS,
        "current_profile" => Dict(String(k) => v for (k, v) in pairs(profile)),
        "topology_features" =>
            Dict(String(k) => v for (k, v) in pairs(features)),
        "topology_graph_errors" => graph_errors,
        "nominal" => nominal, "robustness" => robustness,
        "gates" => Dict(
            "variable_topology_representation" => graph_gate,
            "unified_low_fidelity_physics" => nominal["physics_gate_passed"],
            "minimal_engineering_closure" =>
                nominal["engineering_gate_passed"],
            "same_outer_envelope_contract" => contract_gate,
            "cheap_robustness_screen" => robustness["gate_passed"]),
        "all_five_gates_passed" => all_five,
        "positive_net_power_closure_passed" =>
            nominal["net_electric_power_W"] > 0,
        "classification" => all_five ?
            "profile_coupled_rfp_survivor_pending_3d_equilibrium" :
            "obviously_infeasible_or_unresolved",
        "device_complexity_proxy" => length(genome.field_sources) +
            1.5length(genome.actuators) + 0.5length(genome.plasma_regions) +
            0.25length(genome.flux_connections))
    result["result_hash"] = canonical_hash(result)
    result
end

function run_evaluator(e::ProfileCoupledRFPScreenV1, genome::Genome; kwargs...)
    applicable, reason = evaluator_applicability(e, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(e), genome, reason)
    result = _profile_coupled_rfp_result(e, genome)
    run_hash = canonical_hash(Dict(
        "input_hash" => genome.physics_hash,
        "evaluator" => "profile_coupled_rfp_screen_v1",
        "version" => "1.0.0", "result_hash" => result["result_hash"]))
    status = result["all_five_gates_passed"] === true ? :pass : :fail
    metric = MetricResult("profile_coupled_rfp_five_gate_pass",
        result["all_five_gates_passed"] ? 1.0 : 0.0;
        fidelity = 0, applicability = reason, status = status,
        constraints_checked = sort!(collect(keys(result["gates"]))),
        solver_name = "profile_coupled_rfp_screen_v1",
        solver_version = "1.0.0", input_hash = genome.physics_hash,
        run_hash = run_hash, source_basis = _PROFILE_COUPLED_RFP_SOURCE_BASIS,
        warnings = [result["claim_boundary"]])
    EvaluationBundle("profile_coupled_rfp_screen_v1", genome.design_id,
        genome.family, 0, status, [metric], String[], genome.physics_hash,
        run_hash, "screening_only")
end
