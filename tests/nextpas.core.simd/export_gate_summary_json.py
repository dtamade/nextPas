#!/usr/bin/env python3
"""Export SIMD gate summary markdown table to machine-readable JSON."""

from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path


def parse_markdown_rows(summary_text: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []

    for line in summary_text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        if line.startswith("|---") or line.startswith("| Time "):
            continue

        parts = [part.strip() for part in line.split("|")[1:-1]]
        if len(parts) < 6:
            continue
        if len(parts) < 7:
            parts.append("-")

        rows.append(
            {
                "time": parts[0],
                "step": parts[1],
                "status": parts[2],
                "duration_ms": parts[3],
                "event": parts[4],
                "detail": parts[5],
                "artifacts": parts[6],
            }
        )

    return rows


def apply_filter(rows: list[dict[str, str]], filter_mode: str) -> list[dict[str, str]]:
    if filter_mode == "ALL":
        return rows
    if filter_mode == "FAIL":
        return [row for row in rows if row.get("status") == "FAIL"]
    if filter_mode == "SLOW":
        # Keep SLOW_FAIL for backward compatibility with older rehearsals/snapshots.
        return [row for row in rows if row.get("event") in {"SLOW_WARN", "SLOW_CRIT", "SLOW_FAIL"}]
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Export SIMD gate summary markdown to JSON")
    parser.add_argument("--input", required=True, dest="input_path", help="Path to gate_summary.md")
    parser.add_argument("--output", required=True, dest="output_path", help="Path to output JSON")
    parser.add_argument("--filter", default="ALL", choices=["ALL", "FAIL", "SLOW"], help="Row filter")
    parser.add_argument("--warn-ms", type=int, default=20000, help="Slow warning threshold")
    parser.add_argument("--fail-ms", type=int, default=120000, help="Slow failure threshold")
    args = parser.parse_args()

    input_path = Path(args.input_path)
    output_path = Path(args.output_path)

    if not input_path.exists():
        print(f"[EXPORT-GATE-SUMMARY] Missing input: {input_path}")
        return 2

    all_rows = parse_markdown_rows(input_path.read_text(encoding="utf-8"))
    matched_rows = apply_filter(all_rows, args.filter)

    payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "summary_file": str(input_path),
        "filter": args.filter,
        "warn_ms": args.warn_ms,
        "fail_ms": args.fail_ms,
        "total_rows": len(all_rows),
        "matched_rows": len(matched_rows),
        "rows": matched_rows,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
