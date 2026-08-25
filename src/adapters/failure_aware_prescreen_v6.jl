const _PF_V6_CLAIM_BOUNDARY =
    "FreeGS-informed analytic rejection prescreen. The 0.60 Ip best-layout PF current " *
    "assumption is deliberately more optimistic than all six completed v5 refined " *
    "observations, so failure is useful for rejection; passing remains unresolved and " *
    "requires a candidate-specific free-boundary equilibrium and finite-winding review."

struct FailureAwarePrescreenV6 <: AbstractEvaluator
    v5_review_result_hash::String
end

FailureAwarePrescreenV6() = FailureAwarePrescreenV6(
    "e0d9adabaebcaad618b45d77374554bc93269fc43bbb8d25be41344b0ba9fadf")

function evaluator_spec(::FailureAwarePrescreenV6)
    return EvaluatorSpec("failure_aware_prescreen_v6", "1.0.0",
        ["tokamak_axisymmetric"], 0,
        Dict("pf_coil_current_and_peak_field" => :proxy,
            "pf_coil_force_and_support" => :proxy), _PF_V6_CLAIM_BOUNDARY)
end

function _pf_failure_prescreen_v6(genome::Genome,
        contract::SharedOuterEnvelopeContractV1)
    features = _oe_features(genome)
    geometry = _oe_geometry(features, contract)
    base = contract.base
    pack = features.coil_pack_thickness_m
    support = features.support_thickness_m
    inner_radius = geometry.R - geometry.a -
        (base.shield_thickness_m + base.maintenance_gap_m + 0.5 * pack)
    plasma_current_A = 1.0e6 * _oe_plasma_current_MA(features, geometry, contract)
    optimistic_pf_current_A_turn = 0.60 * plasma_current_A
    tf_at_inner = inner_radius > 0.0 ?
        contract.plasma_field_T * geometry.R / inner_radius : Inf
    local_self = 4.0e-7 * pi * optimistic_pf_current_A_turn /
        (pi * max(pack, 1.0e-6))
    additive_peak = tf_at_inner + local_self
    magnetic_pressure = additive_peak^2 / (2.0 * 4.0e-7 * pi)
    membrane_stress = magnetic_pressure * max(inner_radius, 0.0) /
        max(support, 1.0e-6)
    margins = Dict{String,Float64}(
        "inner_pf_centerline" => inner_radius /
            max(contract.outer_radial_extent_m, 1.0e-9),
        "optimistic_pf_additive_peak_field" =>
            (base.peak_conductor_field_limit_T - additive_peak) /
            base.peak_conductor_field_limit_T,
        "optimistic_pf_membrane_support_stress" =>
            (base.support_stress_limit_Pa - membrane_stress) /
            base.support_stress_limit_Pa,
    )
    passed = all(value -> value >= 0.0, values(margins))
    return Dict{String,Any}(
        "status" => passed ? "pass_unresolved" : "reject",
        "passed" => passed,
        "v5_review_result_hash" =>
            "e0d9adabaebcaad618b45d77374554bc93269fc43bbb8d25be41344b0ba9fadf",
        "observed_refined_sample_count" => 6,
        "observed_outcome" => "six_of_six_failed_additive_peak_field",
        "optimistic_pf_current_fraction_of_plasma_current" => 0.60,
        "inner_pf_centerline_radius_m" => inner_radius,
        "plasma_current_A" => plasma_current_A,
        "optimistic_pf_current_A_turn" => optimistic_pf_current_A_turn,
        "toroidal_field_at_inner_pf_T" => tf_at_inner,
        "local_pf_self_field_proxy_T" => local_self,
        "additive_peak_field_proxy_T" => additive_peak,
        "membrane_support_stress_proxy_Pa" => membrane_stress,
        "margins" => margins,
        "claim_boundary" => _PF_V6_CLAIM_BOUNDARY,
    )
end

function run_evaluator(evaluator::FailureAwarePrescreenV6, genome::Genome;
        contract::SharedOuterEnvelopeContractV1 =
            only(filter(item -> item.id == "outer_reference_B4_v1",
                shared_outer_envelope_contracts_v1())), kwargs...)
    applicable, reason = evaluator_applicability(evaluator, genome)
    applicable || return _non_applicable_bundle(evaluator_spec(evaluator), genome,
        reason)
    result = _pf_failure_prescreen_v6(genome, contract)
    run_hash = canonical_hash(Dict("input_hash" => genome.physics_hash,
        "contract" => _oe_contract_dict(contract), "result" => result))
    metric = MetricResult("pf_optimistic_rejection_prescreen_passed",
        result["passed"];
        fidelity = 0, applicability = reason,
        status = result["passed"] ? :pass : :fail,
        solver_name = "failure_aware_prescreen_v6", solver_version = "1.0.0",
        input_hash = genome.physics_hash, run_hash = run_hash,
        warnings = [_PF_V6_CLAIM_BOUNDARY])
    return EvaluationBundle("failure_aware_prescreen_v6", genome.design_id,
        genome.family, 0, result["passed"] ? :pass : :fail, [metric],
        [_PF_V6_CLAIM_BOUNDARY], genome.physics_hash, run_hash,
        _PF_V6_CLAIM_BOUNDARY)
end
