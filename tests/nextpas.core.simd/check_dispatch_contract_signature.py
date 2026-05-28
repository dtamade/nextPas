#!/usr/bin/env python3
"""Check the in-repo SIMD dispatch contract signature."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path


INCLUDE_RE = re.compile(r"\{\$I\s+([^}]+)\}", re.IGNORECASE)
RECORD_START_RE = re.compile(r"^\s*(T[A-Za-z0-9_]+)\s*=\s*record\b", re.IGNORECASE)

# Baseline signatures for the current in-repo dispatch contract.
EXPECTED_BACKEND_INFO_SIGNATURE = "5475286897138f473cd3148caa3e4df907f45b52b2eff55d2e67b7d2161b4b3a"
EXPECTED_DISPATCH_TABLE_SIGNATURE = "f5727966308911e2c4d50d601518c09effff47a332fba10ce118d987710cfede"


@dataclass(frozen=True)
class ContractSnapshot:
    generated_at: str
    backend_info_fields: list[str]
    dispatch_table_fields: list[str]
    backend_info_signature: str
    dispatch_table_signature: str
    backend_info_matches_expected: bool
    dispatch_table_matches_expected: bool


def read_text_with_local_includes(path: Path, seen: set[Path] | None = None) -> str:
    if seen is None:
        seen = set()

    path = path.resolve()
    if path in seen:
        return ""
    seen.add(path)

    text = path.read_text(encoding="utf-8", errors="ignore")

    def repl(match: re.Match[str]) -> str:
        include_name = match.group(1).strip().strip("'\"")
        include_path = (path.parent / include_name).resolve()
        if not include_path.exists():
            return match.group(0)
        return read_text_with_local_includes(include_path, seen)

    return INCLUDE_RE.sub(repl, text)


def normalize_decl_line(line: str) -> str:
    line = line.split("//", 1)[0].strip()
    if not line:
        return ""
    return " ".join(line.split())


def extract_record_fields(text: str, record_name: str) -> list[str]:
    lines = text.splitlines()
    in_record = False
    found_name = ""
    fields: list[str] = []

    for line in lines:
        if not in_record:
            match = RECORD_START_RE.match(line)
            if match and match.group(1).lower() == record_name.lower():
                in_record = True
                found_name = match.group(1)
            continue

        if re.match(r"^\s*end;\s*$", line):
            return fields

        normalized = normalize_decl_line(line)
        if not normalized:
            continue
        if ":" not in normalized or not normalized.endswith(";"):
            continue
        fields.append(normalized)

    raise RuntimeError(f"record not found or unterminated: {record_name} (matched={found_name!r})")


def compute_signature(lines: list[str]) -> str:
    payload = "\n".join(lines).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def build_snapshot(base_file: Path, dispatch_file: Path) -> ContractSnapshot:
    base_text = read_text_with_local_includes(base_file)
    dispatch_text = read_text_with_local_includes(dispatch_file)

    backend_info_fields = extract_record_fields(base_text, "TSimdBackendInfo")
    dispatch_table_fields = extract_record_fields(dispatch_text, "TSimdDispatchTable")

    backend_info_signature = compute_signature(backend_info_fields)
    dispatch_table_signature = compute_signature(dispatch_table_fields)

    return ContractSnapshot(
        generated_at=datetime.now().isoformat(timespec="seconds"),
        backend_info_fields=backend_info_fields,
        dispatch_table_fields=dispatch_table_fields,
        backend_info_signature=backend_info_signature,
        dispatch_table_signature=dispatch_table_signature,
        backend_info_matches_expected=(EXPECTED_BACKEND_INFO_SIGNATURE == backend_info_signature),
        dispatch_table_matches_expected=(EXPECTED_DISPATCH_TABLE_SIGNATURE == dispatch_table_signature),
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Check SIMD dispatch contract signature")
    parser.add_argument("--base-file", default="src/nextpas.core.simd.base.pas")
    parser.add_argument("--dispatch-file", default="src/nextpas.core.simd.dispatch.pas")
    parser.add_argument("--json-file")
    parser.add_argument("--summary-line", action="store_true")
    parser.add_argument("--dump-current", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    base_file = (repo_root / args.base_file).resolve()
    dispatch_file = (repo_root / args.dispatch_file).resolve()

    if not base_file.exists():
        print(f"[DISPATCH-CONTRACT] Missing base file: {base_file}")
        return 2
    if not dispatch_file.exists():
        print(f"[DISPATCH-CONTRACT] Missing dispatch file: {dispatch_file}")
        return 2

    snapshot = build_snapshot(base_file, dispatch_file)

    if args.json_file:
        json_path = Path(args.json_file)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(asdict(snapshot), ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"[DISPATCH-CONTRACT] JSON snapshot: {json_path}")

    if args.summary_line:
        print(
            "DISPATCH_CONTRACT_SIGNATURE "
            f"backend_info_sha={snapshot.backend_info_signature} "
            f"dispatch_table_sha={snapshot.dispatch_table_signature} "
            f"backend_info_fields={len(snapshot.backend_info_fields)} "
            f"dispatch_table_fields={len(snapshot.dispatch_table_fields)}"
        )

    if args.dump_current:
        print("[DISPATCH-CONTRACT] dump-current")
        print(f"[DISPATCH-CONTRACT] backend_info_signature={snapshot.backend_info_signature}")
        print(f"[DISPATCH-CONTRACT] dispatch_table_signature={snapshot.dispatch_table_signature}")
        return 0

    failed = False
    if not snapshot.backend_info_matches_expected:
        print(
            "[DISPATCH-CONTRACT] FAILED: TSimdBackendInfo signature drift "
            f"(expected={EXPECTED_BACKEND_INFO_SIGNATURE}, actual={snapshot.backend_info_signature})"
        )
        failed = True
    if not snapshot.dispatch_table_matches_expected:
        print(
            "[DISPATCH-CONTRACT] FAILED: TSimdDispatchTable signature drift "
            f"(expected={EXPECTED_DISPATCH_TABLE_SIGNATURE}, actual={snapshot.dispatch_table_signature})"
        )
        failed = True

    if failed:
        print("[DISPATCH-CONTRACT] Hint: if this is an intentional in-repo contract change, update the checker baseline together with docs/STABLE.")
        return 1

    print("[DISPATCH-CONTRACT] OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
