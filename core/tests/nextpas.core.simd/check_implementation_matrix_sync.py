#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import check_nonx86_key_slot_audit as key_slot_audit


REPO_ROOT = SCRIPT_DIR.parent.parent
IMPLEMENTATION_MATRIX_FILE = REPO_ROOT / "docs" / "simd" / "implementation-matrix.md"

NONX86_BACKEND_NAMES = {"neon": "NEON", "riscvv": "RISCVV"}
ACTIVE_NONX86_ROW_SLOTS = {
    "neon": (
        "AndI64x8",
        "NotI64x8",
        "ShiftLeftI32x16",
        "ShiftRightArithI64x4",
        "SubI32x8",
        "MinU32x8",
        "AddI64x4",
        "MulI32x16",
        "MaxU32x16",
        "SubI64x8",
    ),
    "riscvv": (
        "AndI64x8",
        "NotI64x8",
        "ShiftLeftI32x16",
        "ShiftRightArithI64x4",
        "ShiftLeftU32x8",
        "ShiftRightU32x8",
        "SubI32x8",
        "MinU32x8",
        "AddI64x4",
        "MulI32x16",
        "MaxU32x16",
        "SubI64x8",
    ),
}
MANUAL_NONX86_ROW_CONTRACTS = {
    "riscvv": {
        "ShiftLeftU32x8": "reuse_base_scalar",
        "ShiftRightU32x8": "reuse_base_scalar",
    },
}
EXPECTED_X86_ROW_PREFIXES = (
    "SSE2 | structure / contracts smoke |",
    "SSE2 | CmpEqI64x2 / CmpGtI64x2 |",
    "SSE2 | RoundF32x4 / DotF32x3 / CrossF32x3 |",
    "SSE3 | ReduceAddF32x4 / DotF32x4 / NormalizeF32x4 |",
    "SSSE3 | MinI8x16 / MaxI8x16 |",
    "SSE41 | MulI32x4 / DotF32x4 / RoundF32x4 / SelectF32x4 / NormalizeF32x4 / NormalizeF32x3 / CmpEqI64x2 |",
    "SSE42 | CmpGtI64x2 |",
    "AVX512 | U32x16 / U64x8 shift boundary |",
    "AVX2 | SelectF32x16 / SelectF64x8 |",
    "AVX2 | FmaF32x16 / FmaF64x8 |",
)
REQUIRED_SECTION_HEADERS = (
    "# SIMD Implementation Matrix",
    "## Current Focus",
    "## Non-X86 Ownership Matrix",
    "## X86 Bounded Frontier Ledger",
    "## Execution Baseline",
)
REQUIRED_DOC_FRAGMENTS = (
    "live `check_nonx86_helper_semantics.py --summary-line` source truth",
    "`check_riscvv_sensitive_hold_set.py`",
    "`RISCVVRcpF64x4 / RISCVVClampF64x4 / RISCVVClampF64x8 / RISCVVReduceAddF64x4 / RISCVVReduceAddF64x8 / RISCVVReduceMulF64x4 / RISCVVReduceMulF64x8`",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Fail-close sync check for docs/simd/implementation-matrix.md"
    )
    parser.add_argument("--json", action="store_true", help="Print JSON payload to stdout.")
    parser.add_argument(
        "--json-file",
        default="",
        help="Write JSON payload to file.",
    )
    parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print one-line summary for log scraping.",
    )
    return parser.parse_args()


def load_lines(path: Path) -> list[str]:
    return path.read_text(encoding="utf-8").splitlines()


def parse_table_cells(line: str) -> list[str]:
    return [part.strip() for part in line.split("|")]


def collect_nonx86_rows(lines: list[str]) -> dict[str, dict[str, dict[str, object]]]:
    rows: dict[str, dict[str, dict[str, object]]] = {backend: {} for backend in NONX86_BACKEND_NAMES}
    for line_no, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped.startswith(("NEON |", "RISCVV |")):
            continue

        cells = parse_table_cells(stripped)
        if len(cells) < 7:
            raise RuntimeError(
                f"invalid non-x86 matrix row at line {line_no}: expected >=7 columns, got {len(cells)}"
            )

        backend_name = cells[0]
        backend = backend_name.lower()
        slot = cells[1]
        contract = cells[2]

        backend_rows = rows.setdefault(backend, {})
        if slot in backend_rows:
            raise RuntimeError(
                f"duplicate non-x86 matrix row for {backend_name}.{slot} at line {line_no}"
            )

        backend_rows[slot] = {
            "contract": contract,
            "line": line_no,
            "source_truth": cells[3],
            "runtime_evidence": cells[4],
            "current_status": cells[5],
            "next_action": cells[6],
        }
    return rows


def collect_x86_row_hits(lines: list[str]) -> dict[str, list[int]]:
    hits: dict[str, list[int]] = {prefix: [] for prefix in EXPECTED_X86_ROW_PREFIXES}
    for line_no, line in enumerate(lines, start=1):
        stripped = line.strip()
        for prefix in EXPECTED_X86_ROW_PREFIXES:
            if stripped.startswith(prefix):
                hits[prefix].append(line_no)
    return hits


def make_issue(kind: str, detail: str) -> dict[str, str]:
    return {"kind": kind, "detail": detail}


def build_report() -> dict[str, object]:
    if not IMPLEMENTATION_MATRIX_FILE.is_file():
        return {
            "ok": False,
            "issues": [make_issue("missing-file", f"missing {IMPLEMENTATION_MATRIX_FILE}")],
            "nonx86_slots_checked": 0,
            "x86_rows_checked": 0,
            "file": str(IMPLEMENTATION_MATRIX_FILE),
        }

    lines = load_lines(IMPLEMENTATION_MATRIX_FILE)
    text = "\n".join(lines)
    issues: list[dict[str, str]] = []

    for header in REQUIRED_SECTION_HEADERS:
        if header not in text:
            issues.append(make_issue("missing-header", header))
    for fragment in REQUIRED_DOC_FRAGMENTS:
        if fragment not in text:
            issues.append(make_issue("missing-doc-fragment", fragment))
    for line_no, line in enumerate(lines, start=1):
        if "`runtime evidence`" in line and "`checks=" in line:
            issues.append(
                make_issue("stale-helper-count", f"line={line_no}: {line.strip()}")
            )

    expected_modes = key_slot_audit.collect_expected_slot_modes_from_dispatchapi()
    nonx86_rows = collect_nonx86_rows(lines)

    nonx86_slots_checked = 0
    for backend, slot_expectations in expected_modes.items():
        backend_rows = nonx86_rows.get(backend, {})
        active_slots = set(ACTIVE_NONX86_ROW_SLOTS[backend])
        manual_contracts = MANUAL_NONX86_ROW_CONTRACTS.get(backend, {})
        expected_slots = set(slot_expectations) | set(manual_contracts)
        undefined_active_slots = sorted(active_slots - expected_slots)
        for slot in undefined_active_slots:
            issues.append(
                make_issue(
                    "missing-key-slot-ledger-expectation",
                    f"{NONX86_BACKEND_NAMES[backend]}.{slot}",
                )
            )
        if undefined_active_slots:
            continue
        actual_slots = set(backend_rows)
        missing_slots = sorted(active_slots - actual_slots)
        extra_slots = sorted(actual_slots - active_slots)

        for slot in missing_slots:
            issues.append(
                make_issue(
                    "missing-nonx86-row",
                    f"{NONX86_BACKEND_NAMES[backend]}.{slot}",
                )
            )
        for slot in extra_slots:
            issues.append(
                make_issue(
                    "extra-nonx86-row",
                    f"{NONX86_BACKEND_NAMES[backend]}.{slot} line={backend_rows[slot]['line']}",
                )
            )

        for slot in ACTIVE_NONX86_ROW_SLOTS[backend]:
            expected_contract = manual_contracts.get(slot)
            if expected_contract is None:
                expected_contract = slot_expectations[slot].mode
            row = backend_rows.get(slot)
            if row is None:
                continue
            nonx86_slots_checked += 1
            actual_contract = str(row["contract"])
            if actual_contract != expected_contract:
                issues.append(
                    make_issue(
                        "contract-mismatch",
                        (
                            f"{NONX86_BACKEND_NAMES[backend]}.{slot} "
                            f"expected={expected_contract} actual={actual_contract} "
                            f"line={row['line']}"
                        ),
                    )
                )

    x86_hits = collect_x86_row_hits(lines)
    x86_rows_checked = 0
    for prefix, line_numbers in x86_hits.items():
        if not line_numbers:
            issues.append(make_issue("missing-x86-row", prefix))
            continue
        if len(line_numbers) > 1:
            issues.append(
                make_issue(
                    "duplicate-x86-row",
                    f"{prefix} lines={','.join(str(item) for item in line_numbers)}",
                )
            )
            continue
        x86_rows_checked += 1

    return {
        "ok": len(issues) == 0,
        "issues": issues,
        "nonx86_slots_checked": nonx86_slots_checked,
        "x86_rows_checked": x86_rows_checked,
        "file": str(IMPLEMENTATION_MATRIX_FILE),
    }


def render_summary(report: dict[str, object]) -> str:
    return (
        "IMPLEMENTATION_MATRIX_SYNC "
        f"nonx86_slots={report['nonx86_slots_checked']} "
        f"x86_rows={report['x86_rows_checked']} "
        f"issues={len(report['issues'])} "
        f"status={'ok' if report['ok'] else 'fail'}"
    )


def print_human_report(report: dict[str, object]) -> None:
    print(f"[IMPL-MATRIX] file={report['file']}")
    if report["ok"]:
        print(
            f"[IMPL-MATRIX] OK nonx86_slots={report['nonx86_slots_checked']} "
            f"x86_rows={report['x86_rows_checked']}"
        )
        return

    print(
        f"[IMPL-MATRIX] FAILED nonx86_slots={report['nonx86_slots_checked']} "
        f"x86_rows={report['x86_rows_checked']} issues={len(report['issues'])}"
    )
    for issue in report["issues"]:
        print(f"  - {issue['kind']}: {issue['detail']}")


def main() -> int:
    args = parse_args()
    report = build_report()

    if args.json_file:
        output_path = Path(args.json_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print_human_report(report)

    if args.summary_line:
        print(render_summary(report))

    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
