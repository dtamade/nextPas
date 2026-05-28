#!/usr/bin/env python3
"""Generate nextpas.core.simd.backend.adapter.map.inc from the CSV spec."""

from __future__ import annotations

import argparse
import csv
import difflib
import re
import sys
from dataclasses import dataclass
from pathlib import Path

OPS_PATH_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)+$")
DISPATCH_SLOT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


@dataclass(frozen=True)
class AdapterMappingRow:
    ops_path: str
    dispatch_slot: str


def repo_root() -> Path:
    return Path(__file__).resolve().parents[2]


def default_spec_path() -> Path:
    return repo_root() / "src" / "nextpas.core.simd.backend.adapter.map.csv"


def default_output_path() -> Path:
    return repo_root() / "src" / "nextpas.core.simd.backend.adapter.map.inc"


def normalize_text(a_text: str) -> str:
    return a_text.replace("\r\n", "\n").replace("\r", "\n")


def load_mapping_rows(a_csv_path: Path) -> list[AdapterMappingRow]:
    if not a_csv_path.is_file():
        raise RuntimeError(f"missing CSV spec: {a_csv_path}")

    with a_csv_path.open("r", encoding="utf-8", newline="") as l_file:
        l_reader = csv.DictReader(l_file)
        if l_reader.fieldnames is None:
            raise RuntimeError(f"CSV header missing in {a_csv_path}")

        l_fieldnames = [l_name.strip() for l_name in l_reader.fieldnames]
        if l_fieldnames != ["ops_path", "dispatch_slot"]:
            raise RuntimeError(
                f"unexpected CSV header in {a_csv_path}: expected ops_path,dispatch_slot; got {','.join(l_fieldnames)}"
            )

        l_rows: list[AdapterMappingRow] = []
        l_seen_ops: dict[str, int] = {}
        l_seen_slots: dict[str, int] = {}

        for l_lineno, l_row in enumerate(l_reader, start=2):
            l_ops_path = (l_row.get("ops_path") or "").strip()
            l_dispatch_slot = (l_row.get("dispatch_slot") or "").strip()

            if not l_ops_path and not l_dispatch_slot:
                continue
            if not l_ops_path or not l_dispatch_slot:
                raise RuntimeError(f"incomplete row at {a_csv_path}:{l_lineno}")
            if OPS_PATH_RE.match(l_ops_path) is None:
                raise RuntimeError(f"invalid ops_path at {a_csv_path}:{l_lineno}: {l_ops_path}")
            if DISPATCH_SLOT_RE.match(l_dispatch_slot) is None:
                raise RuntimeError(f"invalid dispatch_slot at {a_csv_path}:{l_lineno}: {l_dispatch_slot}")
            if l_ops_path in l_seen_ops:
                raise RuntimeError(
                    f"duplicate ops_path in {a_csv_path}: {l_ops_path} (lines {l_seen_ops[l_ops_path]} and {l_lineno})"
                )
            if l_dispatch_slot in l_seen_slots:
                raise RuntimeError(
                    f"duplicate dispatch_slot in {a_csv_path}: {l_dispatch_slot} "
                    f"(lines {l_seen_slots[l_dispatch_slot]} and {l_lineno})"
                )

            l_seen_ops[l_ops_path] = l_lineno
            l_seen_slots[l_dispatch_slot] = l_lineno
            l_rows.append(AdapterMappingRow(ops_path=l_ops_path, dispatch_slot=l_dispatch_slot))

    if not l_rows:
        raise RuntimeError(f"CSV spec is empty: {a_csv_path}")

    return l_rows


def mapping_rows_to_dict(a_rows: list[AdapterMappingRow]) -> dict[str, str]:
    return {l_row.ops_path: l_row.dispatch_slot for l_row in a_rows}


def render_include_text(a_rows: list[AdapterMappingRow]) -> str:
    l_lines = [
        "{",
        "  Generated from nextpas.core.simd.backend.adapter.map.csv.",
        "  Authoritative declarative mapping list for adapter-managed slots.",
        "  Edit the CSV spec and regenerate; do not hand-edit this file.",
        "  Forward:  TSimdBackendOps -> TSimdDispatchTable (with Assigned guard).",
        "  Backward: TSimdDispatchTable -> TSimdBackendOps.",
        "}",
        "",
    ]

    for l_index, l_row in enumerate(a_rows):
        l_lines.extend(
            [
                "{$IFDEF FAFAFA_SIMD_BACKEND_ADAPTER_FORWARD}",
                f"  if Assigned(ops.{l_row.ops_path}) then",
                f"    table.{l_row.dispatch_slot} := ops.{l_row.ops_path};",
                "{$ENDIF}",
                "{$IFDEF FAFAFA_SIMD_BACKEND_ADAPTER_BACKWARD}",
                f"  ops.{l_row.ops_path} := table.{l_row.dispatch_slot};",
                "{$ENDIF}",
            ]
        )
        if l_index != len(a_rows) - 1:
            l_lines.append("")

    return "\n".join(l_lines) + "\n"


def build_diff(a_expected_text: str, a_actual_text: str, a_max_lines: int = 40) -> list[str]:
    l_diff = list(
        difflib.unified_diff(
            normalize_text(a_expected_text).splitlines(),
            normalize_text(a_actual_text).splitlines(),
            fromfile="expected",
            tofile="actual",
            lineterm="",
        )
    )
    if len(l_diff) <= a_max_lines:
        return l_diff
    return l_diff[:a_max_lines] + [f"... ({len(l_diff) - a_max_lines} more diff lines)"]


def check_output(a_spec_path: Path, a_output_path: Path) -> int:
    l_rows = load_mapping_rows(a_spec_path)
    l_expected_text = render_include_text(l_rows)

    if not a_output_path.is_file():
        print(f"[ADAPTER-MAP-GEN] DRIFT: generated include missing: {a_output_path}")
        return 1

    l_actual_text = a_output_path.read_text(encoding="utf-8")
    if normalize_text(l_actual_text) == normalize_text(l_expected_text):
        print(f"[ADAPTER-MAP-GEN] OK: rows={len(l_rows)} output={a_output_path}")
        return 0

    print(f"[ADAPTER-MAP-GEN] DRIFT: spec={a_spec_path} output={a_output_path}")
    for l_line in build_diff(l_expected_text, l_actual_text):
        print(l_line)
    return 1


def write_output(a_spec_path: Path, a_output_path: Path) -> int:
    l_rows = load_mapping_rows(a_spec_path)
    l_rendered_text = render_include_text(l_rows)
    l_changed = True

    if a_output_path.is_file():
        l_current_text = a_output_path.read_text(encoding="utf-8")
        l_changed = normalize_text(l_current_text) != normalize_text(l_rendered_text)

    a_output_path.write_text(l_rendered_text, encoding="utf-8")
    if l_changed:
        print(f"[ADAPTER-MAP-GEN] WROTE: rows={len(l_rows)} output={a_output_path}")
    else:
        print(f"[ADAPTER-MAP-GEN] UP-TO-DATE: rows={len(l_rows)} output={a_output_path}")
    return 0


def print_stdout(a_spec_path: Path) -> int:
    l_rows = load_mapping_rows(a_spec_path)
    sys.stdout.write(render_include_text(l_rows))
    return 0


def main() -> int:
    l_parser = argparse.ArgumentParser(description="Generate SIMD backend adapter map include from CSV spec")
    l_parser.add_argument("--spec", default=str(default_spec_path()), help="CSV spec path")
    l_parser.add_argument("--output", default=str(default_output_path()), help="generated include output path")
    l_mode = l_parser.add_mutually_exclusive_group()
    l_mode.add_argument("--check", action="store_true", help="fail if generated include drifts from spec")
    l_mode.add_argument("--write", action="store_true", help="write generated include to --output")
    l_mode.add_argument("--stdout", action="store_true", help="print generated include to stdout")
    l_args = l_parser.parse_args()

    l_spec_path = Path(l_args.spec).resolve()
    l_output_path = Path(l_args.output).resolve()

    try:
        if l_args.check:
            return check_output(l_spec_path, l_output_path)
        if l_args.write:
            return write_output(l_spec_path, l_output_path)
        return print_stdout(l_spec_path)
    except Exception as l_ex:  # pylint: disable=broad-except
        print(f"[ADAPTER-MAP-GEN] ERROR: {l_ex}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
