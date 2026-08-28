#!/usr/bin/env python3
"""Fail-closed structural and hash validation for curated v99 evidence."""

from __future__ import annotations

import hashlib
import json
import types
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / "runs" / "v99_full_device_qualification_20260829"


def canonical_hash(value: object) -> str:
    return hashlib.sha256(json.dumps(
        value, sort_keys=True, separators=(",", ":"), allow_nan=False,
    ).encode("utf-8")).hexdigest()


def checked_artifact(path: Path, hash_key: str) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    claimed = value.pop(hash_key)
    actual = canonical_hash(value)
    if claimed != actual:
        raise AssertionError(f"{path} {hash_key} mismatch: {claimed} != {actual}")
    value[hash_key] = claimed
    return value


def main() -> int:
    pinned = {
        ROOT / "scripts" / "desc_fourier_runner.py":
            "9e0130c1968ba0a99c6a4c0e956b1dd453d3b690787ab4d5b1a71a9a9b79f252",
        ROOT / "scripts" / "desc_stellarator_stability_runner.py":
            "274d91f3105244968ccb4700c6ce54ee582b44128f6e6d241dfbb3c0e37add67",
    }
    for path, expected in pinned.items():
        assert hashlib.sha256(path.read_bytes()).hexdigest() == expected
    import desc_axisymmetric_stability_v99_runner as extension
    module = types.ModuleType("desc_fourier_v99_negative_control")
    module.__file__ = str(ROOT / "scripts" / "desc_fourier_runner.py")
    exec(compile(extension.patched_fourier(Path(module.__file__)),
                 "desc_fourier_v99_negative_control", "exec"), module.__dict__)
    base = {
        "runner_version": module.RUNNER_VERSION,
        "model_id": module.AXISYMMETRIC_MODEL_ID,
        "source_binding": "DESC-0.17.3",
        "boundary": {"field_periods": 2, "stellarator_symmetric": True,
                     "R_modes": [{"m": 0, "n": 0, "coefficient_m": 6.0}],
                     "Z_modes": [{"m": -1, "n": 0, "coefficient_m": 1.0}]},
    }
    controls = [
        base,
        {**base, "boundary": {**base["boundary"], "field_periods": 1,
                               "R_modes": [{"m": 0, "n": 1,
                                            "coefficient_m": 6.0}]}},
        {**base, "model_id": module.MODEL_ID,
         "boundary": {**base["boundary"], "field_periods": 1}},
    ]
    for control in controls:
        try:
            module.solve(control)
        except ValueError:
            pass
        else:
            raise AssertionError("v99 routing negative control was accepted")
    cross = checked_artifact(RUN / "cross_code_batch_v1" / "acceptance.json",
                             "acceptance_hash")
    assert cross["status"] == "complete"
    assert cross["candidate_count"] == cross["processed_count"] == 31
    assert cross["provider_system_failure_count"] == 0
    assert cross["unsupported_candidate_count"] == 0
    assert sum(cross["candidate_state_histogram"].values()) == 31
    result_states = Counter()
    result_versions = Counter()
    for row in cross["rows"]:
        path = RUN / "cross_code_batch_v1" / "results" / f"v99_{row['request_index']:07d}.json"
        item = checked_artifact(path, "result_hash")
        assert item["candidate_result_hash"]
        assert item["identity_fields_used_for_routing"] is False
        assert item["unsupported_candidate_classification_used"] is False
        assert item["whole_device_credible"] is False
        assert item["candidate_state"] == row["candidate_state"]
        assert item["result_hash"] == row["result_hash"]
        result_states[item["candidate_state"]] += 1
        result_versions[item["runner_version"]] += 1
    assert dict(sorted(result_states.items())) == cross["candidate_state_histogram"]
    assert dict(sorted(result_versions.items())) == cross["runner_version_histogram"]
    static = checked_artifact(
        RUN / "static_robustness" / "v99_static_0068443.json", "result_hash")
    assert static["scenario_count"] == 9
    assert all(row["solver_passed"] for row in static["records"])
    assert static["candidate_state"] == "static_robustness_fail"
    assert set(static["failed_gates"]) == {
        "additive_peak_field_proxy", "membrane_support_stress_proxy"}
    final = checked_artifact(RUN / "acceptance.json", "acceptance_hash")
    assert final["status"] == "complete"
    assert final["candidate_count"] == 31
    assert final["provider_system_failure_count"] == 0
    assert final["unsupported_candidate_count"] == 0
    assert final["whole_device_credible_count"] == 0
    assert final["validation_pass_count"] == 0
    assert sum(final["candidate_state_histogram"].values()) == 31
    references = checked_artifact(RUN / "reference_controls.json", "acceptance_hash")
    assert references["status"] == "pass"
    assert references["reference_control_count"] == 2
    assert references["validation_pass_count"] == 0
    assert references["whole_device_credible_count"] == 0
    assert all(row["validation_credit"] is False
               for row in references["reference_controls"])
    print(json.dumps({
        "status": "pass",
        "cross_code_acceptance_hash": cross["acceptance_hash"],
        "full_device_acceptance_hash": final["acceptance_hash"],
        "candidate_state_histogram": final["candidate_state_histogram"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
