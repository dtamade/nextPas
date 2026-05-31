#!/usr/bin/env python3
"""Contract tier runner for nextpas.core.tls.

Usage:
    python3 scripts/run_contracts.py --tier core
    python3 scripts/run_contracts.py --tier release
    python3 scripts/run_contracts.py --tier full
    python3 scripts/run_contracts.py --lint
"""

import json
import subprocess
import sys
import time
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PROJECT_ROOT / "tests" / "contracts.manifest.json"


def load_manifest():
    with open(MANIFEST_PATH) as f:
        return json.load(f)


def run_tier(tier_name: str) -> int:
    manifest = load_manifest()
    contracts = [c for c in manifest["contracts"] if c["tier"] == tier_name]

    if not contracts:
        print(f"No contracts found for tier: {tier_name}")
        return 1

    print(f"Running {len(contracts)} {tier_name} contracts...")
    print("=" * 50)

    passed = 0
    failed = 0
    failed_names = []
    start = time.time()

    for contract in contracts:
        path = PROJECT_ROOT / contract["path"]
        if not path.exists():
            print(f"  MISSING: {contract['path']}")
            failed += 1
            failed_names.append(contract["path"])
            continue

        result = subprocess.run(
            ["bash", str(path)],
            capture_output=True,
            text=True,
            cwd=str(PROJECT_ROOT),
            timeout=30,
        )

        if result.returncode == 0:
            passed += 1
        else:
            failed += 1
            failed_names.append(contract["path"])
            stderr = result.stderr.strip() or result.stdout.strip()
            last_line = stderr.split("\n")[-1] if stderr else "unknown error"
            print(f"  FAIL: {contract['path']}")
            print(f"        {last_line}")

    elapsed = time.time() - start
    print("=" * 50)
    print(f"Results: {passed} passed, {failed} failed ({elapsed:.1f}s)")

    if failed_names:
        print(f"\nFailed:")
        for name in failed_names:
            print(f"  - {name}")
        return 1

    print(f"\n[PASS] All {tier_name} contracts green")
    return 0


def lint_manifest() -> int:
    manifest = load_manifest()
    errors = []

    tier_counts = {}
    for contract in manifest["contracts"]:
        tier = contract["tier"]
        tier_counts[tier] = tier_counts.get(tier, 0) + 1

        path = PROJECT_ROOT / contract["path"]
        if not path.exists():
            errors.append(f"Missing file: {contract['path']}")

        if tier in ("core", "release"):
            basename = Path(contract["path"]).name
            if any(w in basename for w in ("wave_b", "wave_c", "archive", "handoff", "closeout")):
                errors.append(
                    f"Wave/archive contract in {tier} tier: {contract['path']}"
                )

    for tier_name, tier_def in manifest["tiers"].items():
        count = tier_counts.get(tier_name, 0)
        max_count = tier_def["max_count"]
        if count > max_count:
            errors.append(
                f"Tier '{tier_name}' has {count} contracts (max {max_count})"
            )

    if errors:
        print("Manifest lint FAILED:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print("Manifest lint PASSED")
    for tier_name in manifest["tiers"]:
        count = tier_counts.get(tier_name, 0)
        max_c = manifest["tiers"][tier_name]["max_count"]
        print(f"  {tier_name}: {count}/{max_c}")
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    if sys.argv[1] == "--lint":
        return lint_manifest()

    if sys.argv[1] == "--tier" and len(sys.argv) >= 3:
        tier = sys.argv[2]
        if tier == "full":
            core_result = run_tier("core")
            release_result = run_tier("release")
            return core_result or release_result
        return run_tier(tier)

    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main())
