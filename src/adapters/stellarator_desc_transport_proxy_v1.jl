struct StellaratorDESCTransportProxyV1 <: AbstractEvaluator
    base_input_path::String
    base_raw_path::String
    refined_input_path::String
    refined_raw_path::String
    resolution_audit_path::String
    runner_path::String

    function StellaratorDESCTransportProxyV1(
            base_input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_transport_pool16_low_order_base_input.json")),
            base_raw_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_transport_pool16_low_order_base_raw.json")),
            refined_input_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_transport_pool16_low_order_refined_input.json")),
            refined_raw_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_transport_pool16_low_order_refined_raw.json")),
            resolution_audit_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "runs", "stellarator_transport_pool16_low_order_resolution_audit.json")),
            runner_path::AbstractString = normpath(joinpath(@__DIR__, "..", "..",
                "scripts", "desc_stellarator_transport_runner.py")))
        paths = abspath.(String.((base_input_path, base_raw_path, refined_input_path,
            refined_raw_path, resolution_audit_path, runner_path)))
        labels = ("base input", "base raw", "refined input", "refined raw",
            "resolution audit", "runner")
        for (path, label) in zip(paths, labels)
            isfile(path) || throw(ArgumentError("DESC transport $label not found at $path"))
        end
        return new(paths...)
    end
end

const _DESC_TRANSPORT_PROXY_PHYSICS_HASH =
    "8bc6df1ccf3cb758a4b76ee207315de6df8f31a15ae631dbb5d057f4a451dd6a"
const _DESC_TRANSPORT_PROXY_RUNNER_VERSION =
    "desc_stellarator_qs_effective_ripple_runner_v1"
const _DESC_TRANSPORT_BASE_INPUT_HASH =
    "28ac045d6b332d35d4f3ef3e21b064ae9b498cfad237a3428a55670cdf191492"
const _DESC_TRANSPORT_BASE_RESULT_HASH =
    "0ea2d21f2e0a164ce4d4f994f9443a9ce5676df98fe794071e887d088cf9f65b"
const _DESC_TRANSPORT_REFINED_INPUT_HASH =
    "c1eaefc2c2f54b7b054587065d89ee128b0025ce128c84e17665772c6ed2504b"
const _DESC_TRANSPORT_REFINED_RESULT_HASH =
    "d5460ed1ec5db1f8cca925224f58e7d701e79a85b4e6f5c888a24745aba877ba"
const _DESC_TRANSPORT_PROXY_CLAIM_BOUNDARY =
    "Sampled Boozer |B| symmetry-breaking spectra and Nemov effective-ripple proxy on a re-solved fixed-boundary equilibrium only; not a drift-kinetic transport solve, turbulent transport, alpha confinement, transport feasibility, fusion performance, engineering feasibility, or superiority."

function evaluator_spec(::StellaratorDESCTransportProxyV1)
    return EvaluatorSpec(
        "stellarator_qs_effective_ripple_desc_v1",
        "1.0.0",
        ["stellarator"],
        1,
        Dict(
            "explicit_fourier_boundary" => :full,
            "finite_beta_equilibrium" => :full,
            "boozer_transform" => :full,
            "sampled_quasisymmetry_spectrum" => :full,
            "neoclassical_transport" => :proxy,
        ),
        "physics_concept",
    )
end

function evaluator_applicability(
        evaluator::StellaratorDESCTransportProxyV1, genome::Genome)
    spec = evaluator_spec(evaluator)
    genome.family in spec.families || return false,
        "evaluator $(spec.id) does not apply to family $(genome.family)"
    genome.physics_hash == _DESC_TRANSPORT_PROXY_PHYSICS_HASH || return false,
        "version 1 is bound to the audited pool-16 NFP=2 stellarator candidate"
    mismatches = _desc_fourier_mismatches(genome)
    return isempty(mismatches), isempty(mismatches) ?
        "exact pool-16 generated Fourier stellarator with a source-bound two-resolution transport proxy" :
        "stellarator_qs_effective_ripple_desc_v1 mismatch: $(join(mismatches, "; "))"
end

function _desc_transport_metric(id, value; unit = "1", status = :pass,
        constraints = String[], input_hash, run_hash, warnings = String[],
        residuals = Dict{String,Float64}())
    return MetricResult(id, value;
        unit = unit,
        fidelity = 1,
        applicability = "DESC 0.17.3 sampled Boozer spectra plus the low-order Bounce1D effective-ripple proxy on the pool-16 fixed-boundary equilibrium.",
        status = status,
        constraints_checked = constraints,
        solver_name = "stellarator_qs_effective_ripple_desc_v1",
        solver_version = "1.0.0+DESC-0.17.3+JAX-0.9.2",
        input_hash = input_hash,
        run_hash = run_hash,
        source_basis = ["desc_software_0_17_3", "nemov_effective_ripple_1999",
            "rodriguez_quasisymmetry_measures_2022",
            "unalmis_bounce_averaging_2026"],
        warnings = warnings,
        residuals = residuals,
        wall_time_s = 0.0)
end

function _read_desc_transport_json(path::AbstractString)
    return _plain_json(JSON3.read(read(path, String), Dict{String,Any}))
end

function _validate_desc_transport_raw(raw::Dict{String,Any},
        input::Dict{String,Any}, genome::Genome, label::AbstractString,
        expected_input_hash::AbstractString, expected_result_hash::AbstractString)
    raw["status"] == "pass" || error("DESC transport $label status is not pass")
    raw["runner_version"] == _DESC_TRANSPORT_PROXY_RUNNER_VERSION || error(
        "DESC transport $label runner version mismatch")
    raw["claim_boundary"] == _DESC_TRANSPORT_PROXY_CLAIM_BOUNDARY || error(
        "DESC transport $label claim boundary mismatch")
    raw["physics_hash"] == genome.physics_hash || error(
        "DESC transport $label is detached from genome")
    raw["input_hash"] == expected_input_hash || error(
        "DESC transport $label input hash mismatch")
    raw["result_hash"] == expected_result_hash || error(
        "DESC transport $label result hash mismatch")
    raw["equilibrium"]["accepted"] === true || error(
        "DESC transport $label equilibrium did not pass")
    raw["equilibrium_reference"]["matched"] === true || error(
        "DESC transport $label equilibrium reference did not match")
    raw["interpretation"]["quasisymmetry_established"] === false || error(
        "DESC transport $label crossed quasisymmetry boundary")
    raw["interpretation"]["drift_kinetic_transport_solved"] === false || error(
        "DESC transport $label crossed drift-kinetic boundary")
    raw["interpretation"]["neoclassical_transport_feasibility_established"] ===
        false || error("DESC transport $label crossed neoclassical boundary")
    raw["interpretation"]["transport_feasibility_established"] === false || error(
        "DESC transport $label crossed transport boundary")
end

function _desc_transport_proxy_bundle_from_files(
        adapter::StellaratorDESCTransportProxyV1, genome::Genome)
    base_input = _read_desc_transport_json(adapter.base_input_path)
    base_raw = _read_desc_transport_json(adapter.base_raw_path)
    refined_input = _read_desc_transport_json(adapter.refined_input_path)
    refined_raw = _read_desc_transport_json(adapter.refined_raw_path)
    audit = _read_desc_transport_json(adapter.resolution_audit_path)
    _validate_desc_transport_raw(base_raw, base_input, genome, "base",
        _DESC_TRANSPORT_BASE_INPUT_HASH, _DESC_TRANSPORT_BASE_RESULT_HASH)
    _validate_desc_transport_raw(refined_raw, refined_input, genome, "refined",
        _DESC_TRANSPORT_REFINED_INPUT_HASH, _DESC_TRANSPORT_REFINED_RESULT_HASH)
    audit["physics_hash"] == genome.physics_hash || error(
        "DESC transport audit is detached from genome")
    audit["all_passed"] === true || error("DESC transport resolution audit failed")
    audit["source_files"]["base_input_sha256"] ==
        bytes2hex(sha256(read(adapter.base_input_path))) || error(
        "DESC transport audit base input hash mismatch")
    audit["source_files"]["base_result_sha256"] ==
        bytes2hex(sha256(read(adapter.base_raw_path))) || error(
        "DESC transport audit base result hash mismatch")
    audit["source_files"]["refined_input_sha256"] ==
        bytes2hex(sha256(read(adapter.refined_input_path))) || error(
        "DESC transport audit refined input hash mismatch")
    audit["source_files"]["refined_result_sha256"] ==
        bytes2hex(sha256(read(adapter.refined_raw_path))) || error(
        "DESC transport audit refined result hash mismatch")
    audit["source_files"]["runner_sha256"] ==
        bytes2hex(sha256(read(adapter.runner_path))) || error(
        "DESC transport audit runner source hash mismatch")
    audit["source_hashes"]["base_result_hash"] == base_raw["result_hash"] ||
        error("DESC transport audit base result binding mismatch")
    audit["source_hashes"]["refined_result_hash"] == refined_raw["result_hash"] ||
        error("DESC transport audit refined result binding mismatch")
    audit["interpretation"]["high_order_bounce2d_available"] === false || error(
        "DESC transport audit unexpectedly claims high-order Bounce2D")
    audit["interpretation"]["neoclassical_transport_feasibility_established"] ===
        false || error("DESC transport audit crossed neoclassical boundary")

    qa = only(filter(record -> record["helicity_M"] == 1 &&
        record["helicity_N"] == 0, refined_raw["quasisymmetry"]["records"]))
    qh = only(filter(record -> record["helicity_M"] == 1 &&
        record["helicity_N"] == 2, refined_raw["quasisymmetry"]["records"]))
    ripple = refined_raw["effective_ripple"]
    warnings_out = String[
        "The Boozer result compares predeclared QA and QH spectra; choosing the lower sampled RMS does not establish quasisymmetry.",
        "The effective-ripple values use DESC's documented low-order Bounce1D comparison algorithm because jax_finufft is unavailable on this Windows environment.",
        "The 0.02 line is a comparison reference, not a universal transport-feasibility threshold.",
        "No high-order Bounce2D, drift-kinetic, turbulent, alpha-orbit, impurity, bootstrap-current, exhaust, fusion-performance, or engineering calculation was performed.",
    ]
    append!(warnings_out, String.(audit["warnings"]))
    unique!(warnings_out)
    residuals = Dict{String,Float64}(
        "maximum_qs_normalized_absolute_resolution_change" => Float64(
            audit["maximum_qs_normalized_absolute_change"]),
        "maximum_effective_ripple_absolute_resolution_change" => Float64(
            audit["effective_ripple_comparison"]["maximum_absolute_change"]),
        "force_normalized_to_magnetic_gradient" => Float64(
            refined_raw["equilibrium"]["after"]["force_normalized_to_magnetic_gradient"]),
    )
    file_hashes = Dict(
        "base_input" => bytes2hex(sha256(read(adapter.base_input_path))),
        "base_raw" => bytes2hex(sha256(read(adapter.base_raw_path))),
        "refined_input" => bytes2hex(sha256(read(adapter.refined_input_path))),
        "refined_raw" => bytes2hex(sha256(read(adapter.refined_raw_path))),
        "audit" => bytes2hex(sha256(read(adapter.resolution_audit_path))),
        "runner" => bytes2hex(sha256(read(adapter.runner_path))),
        "adapter" => bytes2hex(sha256(read(@__FILE__))),
    )
    run_hash = canonical_hash(Dict(
        "physics_hash" => genome.physics_hash,
        "base_result_hash" => base_raw["result_hash"],
        "refined_result_hash" => refined_raw["result_hash"],
        "resolution_audit_hash" => audit["audit_hash"],
        "file_hashes" => file_hashes,
        "evaluator" => "stellarator_qs_effective_ripple_desc_v1",
        "version" => "1.0.0",
    ))
    constraints = ["source-bound equilibrium re-solve",
        "base-to-refined Boozer-spectrum absolute-drift gate",
        "base-to-refined low-order effective-ripple absolute-drift gate",
        "unchanged 0.02 comparison-reference classification"]
    metrics = MetricResult[
        _desc_transport_metric("sampled_boozer_spectrum_computation_completed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("sampled_boozer_spectrum_resolution_audit_passed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = sort!(collect(keys(audit["gates"]))),
            warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("refined_sampled_qa_symmetry_breaking_rms",
            qa["rms_normalized_symmetry_breaking"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("refined_sampled_qh_symmetry_breaking_rms",
            qh["rms_normalized_symmetry_breaking"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("low_order_effective_ripple_computation_completed", true;
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("low_order_effective_ripple_resolution_audit_passed",
            true; input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = constraints, warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("refined_maximum_low_order_effective_ripple",
            ripple["maximum_effective_ripple"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("refined_rms_low_order_effective_ripple",
            ripple["rms_effective_ripple"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("low_order_effective_ripple_reference_met",
            ripple["all_sampled_radii_meet_comparison_reference"];
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["all five sampled radii <= 0.02 comparison reference"],
            warnings = warnings_out, residuals = residuals),
        _desc_transport_metric("high_order_bounce2d_available", false; status = :fail,
            input_hash = genome.physics_hash, run_hash = run_hash,
            constraints = ["jax_finufft import unavailable"],
            warnings = warnings_out, residuals = residuals),
    ]
    for (id, message) in (
            ("quasisymmetry_established",
                "finite sampled symmetry-breaking spectra have no universal QS threshold"),
            ("drift_kinetic_transport_solved",
                "effective ripple is a low-collisionality proxy, not a drift-kinetic solution"),
            ("neoclassical_transport_feasible",
                "high-order effective ripple and independent drift-kinetic transport were not evaluated"),
            ("alpha_orbits_feasible", "alpha-particle orbits were not evaluated"),
            ("transport_feasible",
                "turbulent, impurity, alpha, and integrated particle/heat transport were not evaluated"))
        push!(metrics, _desc_transport_metric(id, nothing; status = :unknown,
            input_hash = genome.physics_hash, run_hash = run_hash,
            warnings = vcat(warnings_out, [message]), residuals = residuals))
    end
    return EvaluationBundle("stellarator_qs_effective_ripple_desc_v1",
        genome.design_id, genome.family, 1, :pass, metrics, warnings_out,
        genome.physics_hash, run_hash, "physics_concept")
end

function run_evaluator(adapter::StellaratorDESCTransportProxyV1,
        genome::Genome; kwargs...)
    return _desc_transport_proxy_bundle_from_files(adapter, genome)
end
