#!/usr/bin/env python3
"""Run candidate-bound VMEX/NEO/GKX/ESSOS qualification diagnostics.

This provider consumes only declared equilibrium capabilities and hash-bound
field data.  Candidate identity is used for evidence binding, never routing or
metric generation.  The output deliberately keeps local stability, transport
proxies, numerical VVUQ, complete-physics credit, and validation credit apart.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import math
import time
from pathlib import Path

import numpy as np


PROTOCOL_ID = "fusionconceptai-v128-vmex-qualification-20260830"
PINNED_PACKAGES = {
    "vmex": "0.7.0",
    "neo-jax": "1.0.2",
    "gkx": "1.8.2",
    "essos": "0.16",
    "virtual-casing-jax": "0.0.5",
    "jax": "0.11.1",
    "jaxlib": "0.11.1",
    "numpy": "2.5.2",
}


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"),
                         allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def finite_list(value) -> list[float]:
    result = np.asarray(value, dtype=float)
    if not np.all(np.isfinite(result)):
        raise FloatingPointError("provider produced non-finite diagnostics")
    return result.tolist()


def _installed_versions() -> dict[str, str]:
    versions = {name: importlib.metadata.version(name) for name in PINNED_PACKAGES}
    mismatches = {
        name: {"expected": PINNED_PACKAGES[name], "actual": actual}
        for name, actual in versions.items() if actual != PINNED_PACKAGES[name]
    }
    if mismatches:
        raise RuntimeError(f"unsealed VMEX provider environment: {mismatches}")
    return versions


def _bound_inputs(candidate_path: Path, manifest_path: Path, wout_path: Path):
    candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("status") != "pass":
        raise ValueError("DESC wout export did not pass")
    for field in ("result_hash", "solver_input_hash", "graph_hash"):
        if manifest.get(f"candidate_{field}") != candidate.get(field):
            raise ValueError(f"candidate/export {field} binding mismatch")
    if manifest.get("wout_sha256") != sha256_file(wout_path):
        raise ValueError("wout content hash mismatch")
    return candidate, manifest


def input_from_wout(wout):
    """Rebuild the target fixed-boundary deck required by state_from_wout."""
    import vmex

    nfp = int(wout.nfp)
    mpol = int(wout.mpol)
    ntor = int(wout.ntor)
    rbc = np.zeros((2 * ntor + 1, mpol))
    zbs = np.zeros_like(rbc)
    rbs = np.zeros_like(rbc)
    zbc = np.zeros_like(rbc)
    for k, (m_value, xn_value) in enumerate(zip(wout.xm, wout.xn, strict=True)):
        m = int(round(float(m_value)))
        n = int(round(float(xn_value))) // max(nfp, 1)
        if m >= mpol or abs(n) > ntor:
            continue
        rbc[n + ntor, m] = float(wout.rmnc[-1, k])
        zbs[n + ntor, m] = float(wout.zmns[-1, k])
        if bool(wout.lasym):
            rbs[n + ntor, m] = float(wout.rmns[-1, k])
            zbc[n + ntor, m] = float(wout.zmnc[-1, k])
    return vmex.VmecInput(
        lasym=bool(wout.lasym), nfp=nfp, mpol=mpol, ntor=ntor,
        ns_array=[int(wout.ns)], ftol_array=[1.0e-10], niter_array=[100],
        phiedge=float(np.asarray(wout.phi)[-1]),
        pmass_type=str(wout.pmass_type), am=np.asarray(wout.am), pres_scale=1.0,
        ncurr=0, piota_type=str(wout.piota_type), ai=np.asarray(wout.ai),
        pcurr_type=str(wout.pcurr_type), ac=np.asarray(wout.ac), curtor=0.0,
        raxis_c=np.asarray(wout.raxis_cc), zaxis_s=np.asarray(wout.zaxis_cs),
        raxis_s=(None if wout.raxis_cs is None else np.asarray(wout.raxis_cs)),
        zaxis_c=(None if wout.zaxis_cc is None else np.asarray(wout.zaxis_cc)),
        rbc=rbc, zbs=zbs, rbs=rbs, zbc=zbc, lfreeb=False,
    )


def reconstructed_state(wout):
    import vmex
    from vmex.core.solver import prepare_runtime, resolution_from_input
    from vmex.core.solver import runtime_with_baselines

    inp = input_from_wout(wout)
    resolution = resolution_from_input(inp, ns=int(wout.ns))
    state = vmex.state_from_wout(wout, inp=inp, ns=int(wout.ns))
    runtime = prepare_runtime(inp, resolution)
    runtime = runtime_with_baselines(runtime, state)
    return inp, state, runtime


def _summary(values) -> dict[str, float]:
    array = np.asarray(values, dtype=float)
    if array.size == 0 or not np.all(np.isfinite(array)):
        raise FloatingPointError("empty or non-finite provider profile")
    return {
        "minimum": float(np.min(array)),
        "maximum": float(np.max(array)),
        "median": float(np.median(array)),
    }


def run_local_stability(wout, state, runtime) -> dict:
    from vmex.core.stability import (
        ballooning_lambda,
        d_merc_state,
        glasser_d_r_state,
        mercier_shear_state,
    )

    started = time.perf_counter()
    dmerc_state = np.asarray(d_merc_state(state, runtime), dtype=float)
    dmerc_wout = np.asarray(wout.DMerc, dtype=float)
    dmerc_abs = np.abs(dmerc_state[2:-1] - dmerc_wout[2:-1])
    dmerc_scale = np.maximum(np.abs(dmerc_wout[2:-1]), 1.0e-12)
    dmerc_rel = dmerc_abs / dmerc_scale
    glasser = np.asarray(glasser_d_r_state(state, runtime), dtype=float)
    shear = np.asarray(mercier_shear_state(state, runtime), dtype=float)
    surface_indices = tuple(sorted({
        min(max(int(round(f * (int(wout.ns) - 1))), 2), int(wout.ns) - 2)
        for f in (0.35, 0.60, 0.85)
    }))
    coarse = np.asarray(ballooning_lambda(
        state, runtime, s_indices=surface_indices,
        alphas=(0.0, math.pi / 2.0, math.pi), zeta0s=(0.0,),
        npoints=61, nturns=1.5), dtype=float)
    refined = np.asarray(ballooning_lambda(
        state, runtime, s_indices=surface_indices,
        alphas=(0.0, math.pi / 2.0, math.pi), zeta0s=(0.0,),
        npoints=121, nturns=3.0), dtype=float)
    max_drift = float(np.max(np.abs(refined - coarse)))
    interior = slice(2, -1)
    shear_scale = max(float(np.max(np.abs(shear[interior]))), 1.0e-30)
    nonzero_shear = bool(np.all(np.abs(shear[interior]) > 1.0e-10 * shear_scale))
    numerical_pass = bool(
        np.max(dmerc_abs) <= 1.0e-8 + 5.0e-3 * np.max(np.abs(dmerc_wout[2:-1]))
        and max_drift <= 0.15
    )
    return {
        "status": "pass",
        "provider": "vmex_local_stability",
        "declared_scope": [
            "mercier_local_ideal_interchange",
            "glasser_resistive_interchange_necessary_condition",
            "infinite_n_ideal_ballooning",
        ],
        "mercier": {
            "state_profile": finite_list(dmerc_state),
            "wout_profile": finite_list(dmerc_wout),
            "interior_summary": _summary(dmerc_state[interior]),
            "stable": bool(np.all(dmerc_state[interior] > 0.0)),
            "state_wout_max_absolute_difference": float(np.max(dmerc_abs)),
            "state_wout_max_relative_difference": float(np.max(dmerc_rel)),
        },
        "glasser": {
            "profile": finite_list(glasser),
            "interior_summary": _summary(glasser[interior]),
            "nonzero_shear_prerequisite": nonzero_shear,
            "necessary_condition_satisfied": bool(
                nonzero_shear and np.all(glasser[interior] <= 0.0)),
        },
        "infinite_n_ballooning": {
            "surface_indices": list(surface_indices),
            "coarse_lambda": finite_list(coarse),
            "refined_lambda": finite_list(refined),
            "coarse_maximum": float(np.max(coarse)),
            "refined_maximum": float(np.max(refined)),
            "stable": bool(np.max(refined) <= 0.0),
            "max_absolute_resolution_drift": max_drift,
        },
        "numerical_vvuq": "pass" if numerical_pass else "fail",
        "physical_gate_pass": bool(
            np.all(dmerc_state[interior] > 0.0)
            and nonzero_shear and np.all(glasser[interior] <= 0.0)
            and np.max(refined) <= 0.0
        ),
        "complete_stability_credit": False,
        "uncovered_obligations": [
            "finite_n_global_ideal_modes", "tearing_and_resistive_modes",
            "kinetic_modes", "nonlinear_saturation", "disruption_dynamics",
        ],
        "wall_time_s": time.perf_counter() - started,
    }


def run_neoclassical(wout) -> dict:
    import vmex
    from vmex.core.neoclassical import diagnostic_neo_config

    started = time.perf_counter()
    surfaces = (0.1953125, 0.4921875, 0.8046875)
    config = diagnostic_neo_config()
    coarse = np.asarray(vmex.epsilon_effective_from_wout(
        wout, surfaces=surfaces, mboz=8, nboz=4, config=config), dtype=float)
    refined = np.asarray(vmex.epsilon_effective_from_wout(
        wout, surfaces=surfaces, mboz=12, nboz=6, config=config), dtype=float)
    absolute = np.abs(refined - coarse)
    relative = absolute / np.maximum(np.abs(refined), 1.0e-12)
    numerical_pass = bool(np.all(np.isfinite(refined)) and
                          np.max(absolute) <= 2.0e-4 and
                          np.max(relative) <= 0.5)
    return {
        "status": "pass",
        "provider": "neo_jax_effective_ripple",
        "surfaces": list(surfaces),
        "coarse_epsilon_eff_3_over_2": finite_list(coarse),
        "refined_epsilon_eff_3_over_2": finite_list(refined),
        "max_absolute_resolution_drift": float(np.max(absolute)),
        "max_relative_resolution_drift": float(np.max(relative)),
        "numerical_vvuq": "pass" if numerical_pass else "fail",
        "physical_gate_pass": None,
        "complete_transport_credit": False,
        "wall_time_s": time.perf_counter() - started,
    }


def _pressure_gradient_splits(wout, surface_index: int) -> dict:
    s = np.linspace(0.0, 1.0, int(wout.ns))
    pressure = np.asarray(wout.presf, dtype=float)
    dp_ds = float(np.gradient(pressure, s, edge_order=2)[surface_index])
    p = float(pressure[surface_index])
    aspect = float(wout.Rmajor_p / wout.Aminor_p)
    rho = math.sqrt(float(s[surface_index]))
    r_over_lp = max(0.0, -aspect * 2.0 * rho * dp_ds / max(p, 1.0e-30))
    return {
        str(fraction): {
            "r_over_lt": fraction * r_over_lp,
            "r_over_ln": (1.0 - fraction) * r_over_lp,
        }
        for fraction in (0.25, 0.50, 0.75)
    }


def run_turbulence(wout, state, runtime) -> dict:
    from vmex.core.turbulence import (
        TURBULENCE_OBJECTIVE_NAMES,
        nonlinear_heat_flux_proxy,
        turbulence_objective_vector,
    )

    started = time.perf_counter()
    surface_index = min(max(int(round(0.6 * (int(wout.ns) - 1))), 2),
                        int(wout.ns) - 2)
    splits = _pressure_gradient_splits(wout, surface_index)
    rows = []
    for split, gradients in splits.items():
        common = dict(
            s_index=surface_index, selected_ky_index=1,
            n_laguerre=2, n_hermite=3, nx=1, ny=4,
            r_over_lt=gradients["r_over_lt"],
            r_over_ln=gradients["r_over_ln"],
        )
        coarse = np.asarray(turbulence_objective_vector(
            state, runtime, ntheta=16, **common), dtype=float)
        refined = np.asarray(turbulence_objective_vector(
            state, runtime, ntheta=32, **common), dtype=float)
        nonlinear = float(np.asarray(nonlinear_heat_flux_proxy(
            state, runtime, ntheta=32, **common)))
        drift = np.abs(refined - coarse)
        rows.append({
            "temperature_gradient_fraction_of_pressure_gradient": float(split),
            **gradients,
            "coarse": dict(zip(TURBULENCE_OBJECTIVE_NAMES,
                                finite_list(coarse), strict=True)),
            "refined": dict(zip(TURBULENCE_OBJECTIVE_NAMES,
                                 finite_list(refined), strict=True)),
            "nonlinear_window_heat_flux_proxy": nonlinear,
            "max_absolute_geometry_resolution_drift": float(np.max(drift)),
        })
    all_finite = all(
        all(np.isfinite(list(row["refined"].values()))) and
        np.isfinite(row["nonlinear_window_heat_flux_proxy"])
        for row in rows
    )
    return {
        "status": "pass" if all_finite else "provider_failure",
        "provider": "gkx_gradient_split_sensitivity",
        "surface_index": surface_index,
        "pressure_constraint": (
            "R/Lp is computed from the candidate-bound wout pressure profile; "
            "R/Lp=R/LT+R/Ln is scanned over three declared splits because the "
            "equilibrium does not identify density and temperature profiles separately."
        ),
        "gradient_split_ensemble": rows,
        "numerical_vvuq": "pass" if all_finite else "fail",
        "physical_gate_pass": None,
        "complete_transport_credit": False,
        "claim_boundary": (
            "Linear and quasilinear GKX observables plus its nonlinear-window "
            "surrogate are diagnostic proxies, not a production nonlinear "
            "gyrokinetic transport validation."
        ),
        "wall_time_s": time.perf_counter() - started,
    }


def _alpha_summary(result) -> dict:
    return {
        "nparticles": int(result.nparticles),
        "loss_fraction": float(result.loss_fraction),
        "particles_lost": int(result.particles_lost),
        "particles_unresolved": int(result.particles_unresolved),
        "particles_failed": int(result.particles_failed),
        "loss_fraction_history": finite_list(result.loss_fractions),
        "wall_time_s": float(result.wall_time_s),
    }


def run_alpha_orbits(wout_path: Path) -> dict:
    import vmex

    started = time.perf_counter()
    coarse = vmex.trace_alphas(
        str(wout_path), tmax=1.0e-4, nparticles=64, s=0.25, seed=128,
        timestep=2.0e-6, times_to_trace=51)
    refined = vmex.trace_alphas(
        str(wout_path), tmax=1.0e-4, nparticles=64, s=0.25, seed=128,
        timestep=1.0e-6, times_to_trace=101)
    numerical_pass = bool(
        coarse.particles_failed == refined.particles_failed == 0
        and coarse.particles_unresolved == refined.particles_unresolved == 0
        and abs(coarse.loss_fraction - refined.loss_fraction) <= 1.0 / 64.0
    )
    return {
        "status": "pass",
        "provider": "essos_alpha_orbit_sample",
        "coarse": _alpha_summary(coarse),
        "refined": _alpha_summary(refined),
        "numerical_vvuq": "pass" if numerical_pass else "fail",
        "physical_gate_pass": None,
        "complete_alpha_confinement_credit": False,
        "claim_boundary": (
            "A deterministic short 64-particle orbit sample checks execution and "
            "time-step sensitivity only; it is not reactor-lifetime alpha "
            "confinement or wall-load qualification."
        ),
        "wall_time_s": time.perf_counter() - started,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--wout", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--skip-turbulence", action="store_true")
    parser.add_argument("--local-stability-only", action="store_true")
    args = parser.parse_args()
    candidate_path = Path(args.candidate).resolve()
    manifest_path = Path(args.manifest).resolve()
    wout_path = Path(args.wout).resolve()
    output_path = Path(args.output).resolve()
    versions = _installed_versions()
    candidate, manifest = _bound_inputs(candidate_path, manifest_path, wout_path)

    import vmex
    wout = vmex.read_wout(wout_path)
    _, state, runtime = reconstructed_state(wout)
    providers = {"local_stability": run_local_stability(wout, state, runtime)}
    if not args.local_stability_only:
        providers["neoclassical"] = run_neoclassical(wout)
        providers["alpha_orbits"] = run_alpha_orbits(wout_path)
        if not args.skip_turbulence:
            providers["turbulence"] = run_turbulence(wout, state, runtime)
    provider_failures = [name for name, value in providers.items()
                         if value["status"] != "pass"]
    numerical_failures = [name for name, value in providers.items()
                          if value.get("numerical_vvuq") == "fail"]
    physical_failures = [name for name, value in providers.items()
                         if value.get("physical_gate_pass") is False]
    body = {
        "schema_version": "1.0.0",
        "protocol_id": PROTOCOL_ID,
        "status": ("provider_failure" if provider_failures else
                   "numerical_vvuq_fail" if numerical_failures else "pass"),
        "candidate_result_hash": candidate["result_hash"],
        "candidate_solver_input_hash": candidate["solver_input_hash"],
        "candidate_graph_hash": candidate["graph_hash"],
        "source_export_result_hash": manifest["result_hash"],
        "wout_sha256": sha256_file(wout_path),
        "environment": versions,
        "routing_declaration": {
            "state": "candidate_bound_converged_equilibrium",
            "operators": [
                "local_stability", "neoclassical_transport",
                "gyrokinetic_transport_proxy", "alpha_orbit_tracing",
            ],
            "interfaces": ["vmec_wout"],
            "function_space": "vmec_fourier_flux_surfaces",
            "dimension": 3,
            "coordinates": ["s", "theta", "zeta"],
            "identity_fields_used_for_routing": False,
        },
        "providers": providers,
        "provider_failures": provider_failures,
        "numerical_failures": numerical_failures,
        "physical_failures": physical_failures,
        "solve_stage": "pass",
        "numerical_vvuq_stage": (
            "pass" if not numerical_failures and not provider_failures else "fail"),
        "validation_vvuq_stage": "external_evidence_required",
        "unsupported_candidate_classification_used": False,
        "screening_mode": ("local_stability_prefilter" if
                           args.local_stability_only else "full_v128_diagnostics"),
        "downstream_not_scheduled": ([
            "neoclassical", "turbulence", "alpha_orbits"] if
            args.local_stability_only else []),
        "partial_subgraph_promotion_allowed": False,
        "advanced_numerical_survivor": bool(
            not provider_failures and not numerical_failures and
            not physical_failures and not args.local_stability_only),
        "complete_stability_credit": False,
        "complete_transport_credit": False,
        "validation_credit": False,
        "whole_device_credible": False,
        "remaining_external_obligations": [
            "complete_finite_n_resistive_kinetic_nonlinear_disruption_stability",
            "production_nonlinear_transport_and_profile_evolution",
            "plasma_neutral_detachment_and_material_exhaust_limits",
            "complete_materials_thermal_hydraulics_quench_blanket_maintenance",
            "candidate_bound_dynamic_control_and_fault_response",
            "independent_measurement_dataset_bound_to_exact_generated_design",
        ],
        "claim_boundary": (
            "Provider execution and numerical VVUQ are distinct from physical "
            "gate results and from validation VVUQ. No local or proxy diagnostic "
            "is promoted to complete device credibility."
        ),
    }
    body["result_hash"] = canonical_hash(body)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(body, indent=2, sort_keys=True,
                                      allow_nan=False) + "\n", encoding="utf-8")
    print(json.dumps({
        "status": body["status"],
        "candidate_result_hash": body["candidate_result_hash"],
        "provider_failures": provider_failures,
        "numerical_failures": numerical_failures,
        "physical_failures": physical_failures,
        "advanced_numerical_survivor": body["advanced_numerical_survivor"],
        "result_hash": body["result_hash"],
    }, sort_keys=True))
    return 0 if not provider_failures else 2


if __name__ == "__main__":
    raise SystemExit(main())
