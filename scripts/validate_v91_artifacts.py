#!/usr/bin/env python3
"""Full streaming JSON Schema validation for sealed v91 campaign artifacts."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import fastjsonschema


ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "runs"
CAMPAIGNS = (
    "multitopology_v91_pilot_10000_20260827",
    "multitopology_v91_qualification_100000_20260827",
    "multitopology_v91_formal_1000000_20260827",
)


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_validator(name: str):
    schema = json.loads((ROOT / "schemas" / name).read_text(encoding="utf-8"))
    return fastjsonschema.compile(schema)


validate_campaign = load_validator("multitopology_campaign_v91.schema.json")
validate_result = load_validator("multitopology_result_v91.schema.json")
validate_dossier = load_validator("survivor_evidence_dossier_v91.schema.json")

campaign_summaries = []
record_count = 0
for campaign_name in CAMPAIGNS:
    campaign_root = RUNS / campaign_name
    manifest_path = campaign_root / "campaign_v91.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    validate_campaign(manifest)
    local_count = 0
    stream_hashes = {}
    for shard in manifest["shards"]:
        stream_path = campaign_root / shard["result_stream"]
        with stream_path.open("r", encoding="utf-8") as stream:
            for line in stream:
                if not line.strip():
                    continue
                validate_result(json.loads(line))
                local_count += 1
        stream_hashes[stream_path.name] = file_sha256(stream_path)
    if local_count != manifest["total_requests"]:
        raise RuntimeError(
            f"{campaign_name}: validated {local_count}, expected {manifest['total_requests']}"
        )
    record_count += local_count
    campaign_summaries.append(
        {
            "campaign_id": manifest["campaign_id"],
            "manifest_sha256": file_sha256(manifest_path),
            "validated_record_count": local_count,
            "stream_sha256": stream_hashes,
        }
    )

formal_root = RUNS / CAMPAIGNS[-1]
dossier_path = formal_root / "survivor_dossiers_v91.jsonl"
dossier_count = 0
with dossier_path.open("r", encoding="utf-8") as stream:
    for line in stream:
        if not line.strip():
            continue
        validate_dossier(json.loads(line))
        dossier_count += 1

expected_dossiers = json.loads(
    (formal_root / "survivor_dossiers_v91_summary.json").read_text(encoding="utf-8")
)["dossier_count"]
if dossier_count != expected_dossiers:
    raise RuntimeError(
        f"validated {dossier_count} dossiers, expected {expected_dossiers}"
    )

report = {
    "schema_version": "1.0.0",
    "status": "pass",
    "validator": "fastjsonschema",
    "campaign_manifest_count": len(CAMPAIGNS),
    "campaign_record_count": record_count,
    "survivor_dossier_count": dossier_count,
    "campaigns": campaign_summaries,
    "dossier_stream_sha256": file_sha256(dossier_path),
    "schemas": {
        name: file_sha256(ROOT / "schemas" / name)
        for name in (
            "multitopology_campaign_v91.schema.json",
            "multitopology_result_v91.schema.json",
            "survivor_evidence_dossier_v91.schema.json",
        )
    },
}
report_without_hash = json.dumps(
    report, sort_keys=True, separators=(",", ":"), ensure_ascii=False
).encode("utf-8")
report["validation_artifact_hash"] = hashlib.sha256(report_without_hash).hexdigest()
output = ROOT / "reports" / "v91_schema_validation_20260827.json"
temporary = output.with_suffix(output.suffix + ".partial")
temporary.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
temporary.replace(output)
print(
    json.dumps(
        {
            "status": report["status"],
            "campaign_record_count": record_count,
            "survivor_dossier_count": dossier_count,
            "validation_artifact_hash": report["validation_artifact_hash"],
            "output": str(output),
        },
        ensure_ascii=False,
    )
)
