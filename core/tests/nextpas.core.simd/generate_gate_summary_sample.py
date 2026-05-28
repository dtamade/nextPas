#!/usr/bin/env python3
"""Generate deterministic gate summary markdown samples for diagnostics rehearsal."""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta
from pathlib import Path


def build_rows(scenario: str, warn_ms: int, fail_ms: int) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = [
        {
            "step": "gate",
            "status": "START",
            "duration": "-",
            "event": "START",
            "detail": "mode=Debug; wiring=1; coverage=0; perf=0",
            "artifacts": "logs/build.txt; logs/test.txt; logs/wiring_sync.txt",
        },
        {
            "step": "build-check",
            "status": "PASS",
            "duration": "6200",
            "event": "NORMAL",
            "detail": "build/check/parity passed",
            "artifacts": "logs/build.txt",
        },
        {
            "step": "wiring-sync",
            "status": "PASS",
            "duration": "180",
            "event": "NORMAL",
            "detail": "legacy=116 grouped=116 missing=0 extra=0 markers_missing=0 strict_extra=1",
            "artifacts": "logs/wiring_sync.txt; logs/wiring_sync.json",
        },
    ]

    if scenario == "pass":
        rows.extend(
            [
                {
                    "step": "run-all-chain",
                    "status": "PASS",
                    "duration": "8500",
                    "event": "NORMAL",
                    "detail": "filtered run_all passed",
                    "artifacts": "tests/_run_all_logs_sh; tests/run_all_tests_summary_sh.txt",
                },
                {
                    "step": "gate",
                    "status": "PASS",
                    "duration": "15480",
                    "event": "NORMAL",
                    "detail": "all steps passed",
                    "artifacts": "-",
                },
            ]
        )
    elif scenario == "fail":
        rows.extend(
            [
                {
                    "step": "cpuinfo-x86",
                    "status": "FAIL",
                    "duration": "1333",
                    "event": "FAILED",
                    "detail": "rc=1; cpuinfo x86 suite failed; cmd=gate_step_cpuinfo_x86 /mock/tests",
                    "artifacts": "tests/nextpas.core.simd.cpuinfo.x86/logs/test.txt",
                },
                {
                    "step": "gate",
                    "status": "FAIL",
                    "duration": "9800",
                    "event": "FAILED",
                    "detail": "failed-step=cpuinfo-x86",
                    "artifacts": "-",
                },
            ]
        )
    elif scenario == "slow":
        rows.extend(
            [
                {
                    "step": "run-all-chain",
                    "status": "PASS",
                    "duration": str(warn_ms + 4500),
                    "event": "SLOW_WARN",
                    "detail": "filtered run_all passed; logs=tests/_run_all_logs_sh; summary=tests/run_all_tests_summary_sh.txt",
                    "artifacts": "tests/_run_all_logs_sh; tests/run_all_tests_summary_sh.txt",
                },
                {
                    "step": "gate",
                    "status": "PASS",
                    "duration": str(fail_ms + 5000),
                    "event": "SLOW_CRIT",
                    "detail": "all steps passed",
                    "artifacts": "-",
                },
            ]
        )
    else:  # mixed
        rows.extend(
            [
                {
                    "step": "run-all-chain",
                    "status": "PASS",
                    "duration": str(warn_ms + 3000),
                    "event": "SLOW_WARN",
                    "detail": "filtered run_all passed; logs=tests/_run_all_logs_sh; summary=tests/run_all_tests_summary_sh.txt",
                    "artifacts": "tests/_run_all_logs_sh; tests/run_all_tests_summary_sh.txt",
                },
                {
                    "step": "perf-smoke",
                    "status": "FAIL",
                    "duration": "621",
                    "event": "FAILED",
                    "detail": "rc=1; perf-smoke failed; cmd=run_perf_smoke",
                    "artifacts": "logs/test.txt",
                },
                {
                    "step": "gate",
                    "status": "FAIL",
                    "duration": str(warn_ms + 7000),
                    "event": "FAILED",
                    "detail": "failed-step=perf-smoke",
                    "artifacts": "-",
                },
            ]
        )

    return rows


def write_markdown(rows: list[dict[str, str]], output_path: Path, start_time: datetime) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "| Time | Step | Status | DurationMs | Event | Detail | Artifacts |",
        "|---|---|---|---|---|---|---|",
    ]

    current = start_time
    for row in rows:
        lines.append(
            "| {time} | {step} | {status} | {duration} | {event} | {detail} | {artifacts} |".format(
                time=current.strftime("%Y-%m-%d %H:%M:%S"),
                step=row["step"],
                status=row["status"],
                duration=row["duration"],
                event=row["event"],
                detail=row["detail"],
                artifacts=row["artifacts"],
            )
        )
        current += timedelta(seconds=1)

    output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate gate_summary sample markdown")
    parser.add_argument("--scenario", default="mixed", choices=["pass", "fail", "slow", "mixed"], help="Sample scenario")
    parser.add_argument("--output", required=True, help="Output markdown file")
    parser.add_argument("--warn-ms", type=int, default=20000, help="Warn threshold for slow sample")
    parser.add_argument("--fail-ms", type=int, default=120000, help="Fail threshold for slow sample")
    parser.add_argument("--time", default="2026-02-10 00:00:00", help="Start timestamp (YYYY-MM-DD HH:MM:SS)")
    args = parser.parse_args()

    start = datetime.strptime(args.time, "%Y-%m-%d %H:%M:%S")
    rows = build_rows(args.scenario, args.warn_ms, args.fail_ms)
    write_markdown(rows, Path(args.output), start)
    print(f"[GATE-SUMMARY-SAMPLE] scenario={args.scenario} rows={len(rows)} output={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
