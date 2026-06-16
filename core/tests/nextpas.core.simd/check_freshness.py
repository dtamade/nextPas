#!/usr/bin/env python3
"""Freshness checker: compare source code recency against evidence artifacts.

Usage:
  python3 check_freshness.py [--strict] [--summary-line] [--json-file PATH] [--text-file PATH]

Environment variables:
  SIMD_FRESHNESS_STRICT=1   Treat missing evidence as FAIL instead of SKIP
  SIMD_OUTPUT_ROOT=PATH     Override default output root (same as BuildOrTest.sh)
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass, asdict, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional


def _find_repo_root() -> Path:
    """Return the git repo root via `git rev-parse`, falling back to 3 parents up."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=10,
            cwd=str(Path(__file__).resolve().parent),
        )
        if result.returncode == 0 and result.stdout.strip():
            return Path(result.stdout.strip())
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    # Fallback: core-simd worktree layout = 3 parents up
    return Path(__file__).resolve().parents[3]


REPO_ROOT = _find_repo_root()
CORE_ROOT = REPO_ROOT / "core"
TEST_ROOT = CORE_ROOT / "tests" / "nextpas.core.simd"

# Align with BuildOrTest.sh lines 9-10:
#   DEFAULT_OUTPUT_ROOT="${CORE_ROOT}/build/tests/nextpas.core.simd"
#   OUTPUT_ROOT="${SIMD_OUTPUT_ROOT:-${DEFAULT_OUTPUT_ROOT}}"
OUTPUT_ROOT = Path(os.environ.get(
    "SIMD_OUTPUT_ROOT",
    str(CORE_ROOT / "build" / "tests" / "nextpas.core.simd"),
))
LOGS_DIR = OUTPUT_ROOT / "logs"

# ── Source vs Evidence comparison matrix ──────────────────────────────
# Source paths are repo-relative (fed to `git log`).
# Evidence paths are relative to OUTPUT_ROOT (where BuildOrTest.sh writes).
COMPARISON_MATRIX = [
    {
        "sources": ["core/src/nextpas.core.simd*.pas"],
        "evidence": "logs/gate_summary.md",
        "desc": "Linux gate summary vs SIMD sources",
    },
    {
        "sources": ["core/src/nextpas.core.simd*.pas"],
        "evidence": "logs/windows_b07_gate.log",
        "desc": "Windows B07 gate log vs SIMD sources",
    },
    {
        "sources": ["core/tests/nextpas.core.simd/buildOrTest.bat"],
        "evidence": "logs/windows_b07_gate.log",
        "desc": "Windows B07 gate log vs buildOrTest.bat",
    },
    {
        "sources": ["logs/windows_b07_gate.log"],  # relative to OUTPUT_ROOT for git log
        "evidence": "logs/windows_b07_closeout_summary.md",
        "desc": "Windows closeout summary vs B07 gate log",
    },
]


@dataclass
class FreshnessResult:
    comparison: str
    source_newest_ts: Optional[int]   # unix timestamp, None if no source found
    evidence_newest_ts: Optional[int]  # unix timestamp, None if no evidence found
    evidence_exists: bool
    status: str  # "PASS", "SKIP", "FAIL"
    detail: str


@dataclass
class FreshnessReport:
    timestamp: str
    results: List[FreshnessResult] = field(default_factory=list)
    overall_status: str = "PASS"


def git_log_timestamp(paths: List[str], cwd: Optional[Path] = None) -> Optional[int]:
    """Return the latest git commit timestamp (unix epoch) touching any of the given paths.

    Uses `git log -1 --format=%ct` so the result is stable across checkouts
    and immune to filesystem mtime noise.
    """
    if not paths:
        return None
    cmd = [
        "git", "log", "-1",
        "--format=%ct",
        "--",
    ] + paths
    try:
        result = subprocess.run(
            cmd,
            capture_output=True, text=True, timeout=30,
            cwd=str(cwd or REPO_ROOT),
        )
        if result.returncode == 0 and result.stdout.strip():
            return int(result.stdout.strip())
    except (subprocess.TimeoutExpired, ValueError, FileNotFoundError):
        pass
    return None


def glob_expand(patterns: List[str], root: Path) -> List[str]:
    """Expand glob patterns relative to `root`, return list of matched paths relative to REPO_ROOT."""
    import glob as glob_mod
    matched = []
    for pattern in patterns:
        full_pattern = str(root / pattern)
        matched.extend(glob_mod.glob(full_pattern))
    # Return paths relative to REPO_ROOT for git commands
    return [str(Path(p).relative_to(REPO_ROOT)) for p in matched]


def check_freshness(strict: bool = False) -> FreshnessReport:
    report = FreshnessReport(
        timestamp=datetime.now(timezone.utc).isoformat(),
    )

    for entry in COMPARISON_MATRIX:
        result = FreshnessResult(
            comparison=entry["desc"],
            source_newest_ts=None,
            evidence_newest_ts=None,
            evidence_exists=False,
            status="PASS",
            detail="",
        )

        # Resolve source paths — repo-relative
        source_paths = glob_expand(entry["sources"], REPO_ROOT)
        result.source_newest_ts = git_log_timestamp(source_paths) if source_paths else None

        # Resolve evidence path — relative to OUTPUT_ROOT
        evidence_path = OUTPUT_ROOT / entry["evidence"]
        result.evidence_exists = evidence_path.is_file()

        if not result.evidence_exists:
            if strict:
                result.status = "FAIL"
                result.detail = (
                    f"Evidence file missing: {entry['evidence']}; "
                    f"strict mode enabled (SIMD_FRESHNESS_STRICT=1)"
                )
            else:
                result.status = "SKIP"
                result.detail = f"Evidence file not found: {entry['evidence']} (non-strict: skipped)"
        elif result.source_newest_ts is None:
            result.status = "SKIP"
            result.detail = "No matching source files found for comparison"
        else:
            # Evidence git timestamp — use OUTPUT_ROOT-relative path
            evd_rel = str(Path(entry["evidence"]))
            result.evidence_newest_ts = git_log_timestamp([evd_rel], cwd=OUTPUT_ROOT)
            if result.evidence_newest_ts is None:
                # Evidence exists but isn't tracked by git — use file mtime as fallback
                try:
                    result.evidence_newest_ts = int(evidence_path.stat().st_mtime)
                except OSError:
                    pass

            if result.evidence_newest_ts is not None and result.source_newest_ts > result.evidence_newest_ts:
                result.status = "FAIL"
                src_time = datetime.fromtimestamp(result.source_newest_ts, tz=timezone.utc)
                evd_time = datetime.fromtimestamp(result.evidence_newest_ts, tz=timezone.utc)
                result.detail = (
                    f"Source newer than evidence: "
                    f"source={src_time.isoformat()}, "
                    f"evidence={evd_time.isoformat()}; "
                    f"re-run gate/closeout to refresh evidence"
                )
            else:
                result.status = "PASS"
                result.detail = "Evidence is current"

        report.results.append(result)

    # Determine overall status
    statuses = {r.status for r in report.results}
    if "FAIL" in statuses:
        report.overall_status = "FAIL"
    elif "SKIP" in statuses:
        report.overall_status = "SKIP"
    else:
        report.overall_status = "PASS"

    return report


def main():
    parser = argparse.ArgumentParser(description="Check freshness of SIMD evidence against sources")
    parser.add_argument("--summary-line", action="store_true",
                        help="Print a single summary line instead of full report")
    parser.add_argument("--strict", action="store_true",
                        help="Treat missing evidence as FAIL instead of SKIP")
    parser.add_argument("--json-file", type=str, default=None,
                        help="Write JSON report to this file")
    parser.add_argument("--text-file", type=str, default=None,
                        help="Write text report to this file")
    args = parser.parse_args()

    strict = os.environ.get("SIMD_FRESHNESS_STRICT", "0") == "1" or args.strict
    report = check_freshness(strict=strict)

    if args.summary_line:
        print(
            f"FRESHNESS overall={report.overall_status} "
            f"pass={sum(1 for r in report.results if r.status == 'PASS')} "
            f"skip={sum(1 for r in report.results if r.status == 'SKIP')} "
            f"fail={sum(1 for r in report.results if r.status == 'FAIL')} "
            f"total={len(report.results)}"
        )
    else:
        print(f"[FRESHNESS] Overall: {report.overall_status}")
        print(f"[FRESHNESS] Timestamp: {report.timestamp}")
        print()

        for r in report.results:
            icon = {"PASS": "✅", "SKIP": "⏭️", "FAIL": "❌"}.get(r.status, "?")
            print(f"  {icon} {r.comparison}: {r.status}")
            if r.detail:
                print(f"     {r.detail}")
        print()

    # JSON output
    json_data = {
        "timestamp": report.timestamp,
        "overall_status": report.overall_status,
        "results": [asdict(r) for r in report.results],
    }

    json_file = args.json_file or str(LOGS_DIR / "freshness_check.json")
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    with open(json_file, "w") as f:
        json.dump(json_data, f, indent=2)
    if not args.summary_line:
        print(f"[FRESHNESS] JSON report: {json_file}")

    # Text output
    text_file = args.text_file or str(LOGS_DIR / "freshness_check.txt")
    with open(text_file, "w") as f:
        f.write(f"Freshness Check Report\n")
        f.write(f"Timestamp: {report.timestamp}\n")
        f.write(f"Overall: {report.overall_status}\n\n")
        for r in report.results:
            icon = {"PASS": "OK", "SKIP": "SKIP", "FAIL": "FAIL"}.get(r.status, "?")
            f.write(f"[{icon}] {r.comparison}\n")
            if r.detail:
                f.write(f"  Detail: {r.detail}\n")
            if r.source_newest_ts:
                f.write(f"  Source newest: {r.source_newest_ts}\n")
            if r.evidence_newest_ts:
                f.write(f"  Evidence newest: {r.evidence_newest_ts}\n")
            f.write("\n")
    if not args.summary_line:
        print(f"[FRESHNESS] Text report: {text_file}")

    # Exit code
    if report.overall_status == "FAIL":
        sys.exit(1)
    else:
        sys.exit(0)


if __name__ == "__main__":
    main()
