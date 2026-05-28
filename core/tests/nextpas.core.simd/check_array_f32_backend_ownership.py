#!/usr/bin/env python3
"""Fail-close the ArrayF32 dispatch/backend ownership truth."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path


SLOTS = {
    "ArrayAddF32": {
        "scalar": "ScalarArrayAddF32",
        "sse2": "SSE2ArrayAddF32",
        "avx2": "AVX2ArrayAddF32",
        "sse2_opcodes": ("movups", "addps"),
        "avx2_opcodes": ("vmovups", "vaddps", "vzeroupper"),
    },
    "ArraySubF32": {
        "scalar": "ScalarArraySubF32",
        "sse2": "SSE2ArraySubF32",
        "avx2": "AVX2ArraySubF32",
        "sse2_opcodes": ("movups", "subps"),
        "avx2_opcodes": ("vmovups", "vsubps", "vzeroupper"),
    },
    "ArrayMulF32": {
        "scalar": "ScalarArrayMulF32",
        "sse2": "SSE2ArrayMulF32",
        "avx2": "AVX2ArrayMulF32",
        "sse2_opcodes": ("movups", "mulps"),
        "avx2_opcodes": ("vmovups", "vmulps", "vzeroupper"),
    },
    "ArrayDivF32": {
        "scalar": "ScalarArrayDivF32",
        "sse2": "SSE2ArrayDivF32",
        "avx2": "AVX2ArrayDivF32",
        "sse2_opcodes": ("movups", "divps"),
        "avx2_opcodes": ("vmovups", "vdivps", "vzeroupper"),
    },
    "ArrayMinF32": {
        "scalar": "ScalarArrayMinF32",
        "sse2": "SSE2ArrayMinF32",
        "avx2": "AVX2ArrayMinF32",
        "sse2_opcodes": ("movups", "minps"),
        "avx2_opcodes": ("vmovups", "vminps", "vzeroupper"),
    },
    "ArrayMaxF32": {
        "scalar": "ScalarArrayMaxF32",
        "sse2": "SSE2ArrayMaxF32",
        "avx2": "AVX2ArrayMaxF32",
        "sse2_opcodes": ("movups", "maxps"),
        "avx2_opcodes": ("vmovups", "vmaxps", "vzeroupper"),
    },
    "ArrayAbsF32": {
        "scalar": "ScalarArrayAbsF32",
        "sse2": "SSE2ArrayAbsF32",
        "avx2": "AVX2ArrayAbsF32",
        "sse2_opcodes": ("movups", "andps"),
        "avx2_opcodes": ("vmovups", "vandps", "vzeroupper"),
    },
    "ArrayNegF32": {
        "scalar": "ScalarArrayNegF32",
        "sse2": "SSE2ArrayNegF32",
        "avx2": "AVX2ArrayNegF32",
        "sse2_opcodes": ("movups", "xorps"),
        "avx2_opcodes": ("vmovups", "vxorps", "vzeroupper"),
    },
    "ArraySqrtF32": {
        "scalar": "ScalarArraySqrtF32",
        "sse2": "SSE2ArraySqrtF32",
        "avx2": "AVX2ArraySqrtF32",
        "sse2_opcodes": ("movups", "sqrtps"),
        "avx2_opcodes": ("vmovups", "vsqrtps", "vzeroupper"),
    },
    "ArrayMulScalarF32": {
        "scalar": "ScalarArrayMulScalarF32",
        "sse2": "SSE2ArrayMulScalarF32",
        "avx2": "AVX2ArrayMulScalarF32",
        "sse2_opcodes": ("movss", "shufps", "mulps"),
        "avx2_opcodes": ("vmovss", "vbroadcastss", "vmulps", "vzeroupper"),
    },
    "ArrayAddScalarF32": {
        "scalar": "ScalarArrayAddScalarF32",
        "sse2": "SSE2ArrayAddScalarF32",
        "avx2": "AVX2ArrayAddScalarF32",
        "sse2_opcodes": ("movss", "shufps", "addps"),
        "avx2_opcodes": ("vmovss", "vbroadcastss", "vaddps", "vzeroupper"),
    },
    "ArrayClampF32": {
        "scalar": "ScalarArrayClampF32",
        "sse2": "SSE2ArrayClampF32",
        "avx2": "AVX2ArrayClampF32",
        "sse2_opcodes": ("movss", "shufps", "maxps", "minps"),
        "avx2_opcodes": ("vmovss", "vbroadcastss", "vmaxps", "vminps", "vzeroupper"),
    },
    "ArrayAxpyF32": {
        "scalar": "ScalarArrayAxpyF32",
        "sse2": "SSE2ArrayAxpyF32",
        "avx2": "AVX2ArrayAxpyF32",
        "sse2_opcodes": ("movss", "shufps", "mulps", "addps"),
        "avx2_opcodes": ("vmovss", "vbroadcastss", "vmulps", "vaddps", "vzeroupper"),
    },
}

PROCEDURE_START_RE = re.compile(r"^\s*procedure\s+([A-Za-z_][A-Za-z0-9_]*)\b", re.IGNORECASE)
ROUTINE_START_RE = re.compile(r"^\s*(?:procedure|function)\s+[A-Za-z_][A-Za-z0-9_]*\b", re.IGNORECASE)
INCLUDE_RE = re.compile(r"\{\$I\s+([^}]+)\}", re.IGNORECASE)


@dataclass(frozen=True)
class SlotReport:
    slot: str
    scalar_fallback: str
    sse2_owner: str
    avx2_owner: str
    sse2_opcodes: list[str]
    avx2_opcodes: list[str]
    sse2_tail_scalar: bool
    avx2_tail_scalar: bool


@dataclass(frozen=True)
class OwnershipReport:
    generated_at: str
    slots: list[SlotReport]
    issues: list[str]
    status: str


def read_text(path: Path) -> str:
    if not path.is_file():
        raise FileNotFoundError(str(path))
    return path.read_text(encoding="utf-8", errors="ignore")


def require_contains(text: str, pattern: str, issue: str, issues: list[str]) -> None:
    if pattern not in text:
        issues.append(issue)


def extract_routine_body(text: str, routine_name: str) -> str:
    lines = text.splitlines()
    start = -1

    for index, line in enumerate(lines):
        match = PROCEDURE_START_RE.match(line)
        if match and match.group(1).lower() == routine_name.lower():
            start = index
            break

    if start < 0:
        return ""

    end = len(lines)
    for index in range(start + 1, len(lines)):
        if ROUTINE_START_RE.match(lines[index]):
            end = index
            break

    return "\n".join(lines[start:end])


def opcode_hits(body: str, opcodes: tuple[str, ...]) -> list[str]:
    lowered = body.lower()
    return [opcode for opcode in opcodes if re.search(rf"\b{re.escape(opcode.lower())}\b", lowered)]


def body_has_tail_scalar(body: str) -> bool:
    lowered = body.lower()
    has_zero_guard = "if acount = 0 then exit" in lowered
    has_pascal_tail = "while i < acount do" in lowered
    has_asm_tail = "@tail_scalar" in lowered or "@scalar_loop" in lowered
    return has_zero_guard and (has_pascal_tail or has_asm_tail)


def build_report(repo_root: Path) -> OwnershipReport:
    src_root = repo_root / "src"
    dispatch_text = read_text(src_root / "nextpas.core.simd.dispatch.pas")
    generated_fillbase_text = read_text(src_root / "generated" / "nextpas.core.simd.fillbase.inc")
    sse2_unit_text = read_text(src_root / "nextpas.core.simd.sse2.pas")
    avx2_unit_text = read_text(src_root / "nextpas.core.simd.avx2.pas")
    sse2_register_text = read_text(src_root / "nextpas.core.simd.sse2.register.inc")
    avx2_register_text = read_text(src_root / "nextpas.core.simd.avx2.register.inc")
    sse2_batch_text = read_text(src_root / "nextpas.core.simd.sse2.batch.inc")
    avx2_batch_text = read_text(src_root / "nextpas.core.simd.avx2.batch.inc")

    issues: list[str] = []
    slot_reports: list[SlotReport] = []

    require_contains(
        sse2_unit_text,
        "{$I nextpas.core.simd.sse2.batch.inc}",
        "sse2 unit does not include nextpas.core.simd.sse2.batch.inc",
        issues,
    )
    require_contains(
        avx2_unit_text,
        "{$I nextpas.core.simd.avx2.batch.inc}",
        "avx2 unit does not include nextpas.core.simd.avx2.batch.inc",
        issues,
    )

    for slot, truth in SLOTS.items():
        scalar = truth["scalar"]
        sse2_owner = truth["sse2"]
        avx2_owner = truth["avx2"]

        require_contains(
            dispatch_text,
            f"dispatchTable.{slot} := @{scalar};",
            f"{slot} missing scalar fallback assignment in dispatch.pas",
            issues,
        )
        require_contains(
            generated_fillbase_text,
            f"aTable.{slot} := @{scalar};",
            f"{slot} missing generated FillBase assignment",
            issues,
        )
        require_contains(
            sse2_register_text,
            f"dispatchTable.{slot} := @{sse2_owner};",
            f"{slot} is not bound to {sse2_owner} in SSE2 register include",
            issues,
        )
        require_contains(
            avx2_register_text,
            f"dispatchTable.{slot} := @{avx2_owner};",
            f"{slot} is not bound to {avx2_owner} in AVX2 register include",
            issues,
        )

        sse2_body = extract_routine_body(sse2_batch_text, sse2_owner)
        avx2_body = extract_routine_body(avx2_batch_text, avx2_owner)
        if not sse2_body:
            issues.append(f"{sse2_owner} procedure body missing from SSE2 batch include")
        if not avx2_body:
            issues.append(f"{avx2_owner} procedure body missing from AVX2 batch include")

        sse2_hits = opcode_hits(sse2_body, truth["sse2_opcodes"])
        avx2_hits = opcode_hits(avx2_body, truth["avx2_opcodes"])
        missing_sse2 = sorted(set(truth["sse2_opcodes"]) - set(sse2_hits))
        missing_avx2 = sorted(set(truth["avx2_opcodes"]) - set(avx2_hits))
        if missing_sse2:
            issues.append(f"{sse2_owner} missing SIMD opcode witness: {','.join(missing_sse2)}")
        if missing_avx2:
            issues.append(f"{avx2_owner} missing SIMD opcode witness: {','.join(missing_avx2)}")

        sse2_tail_scalar = body_has_tail_scalar(sse2_body)
        avx2_tail_scalar = body_has_tail_scalar(avx2_body)
        if not sse2_tail_scalar:
            issues.append(f"{sse2_owner} missing zero-count guard or scalar tail")
        if not avx2_tail_scalar:
            issues.append(f"{avx2_owner} missing zero-count guard or scalar tail")

        slot_reports.append(
            SlotReport(
                slot=slot,
                scalar_fallback=scalar,
                sse2_owner=sse2_owner,
                avx2_owner=avx2_owner,
                sse2_opcodes=sse2_hits,
                avx2_opcodes=avx2_hits,
                sse2_tail_scalar=sse2_tail_scalar,
                avx2_tail_scalar=avx2_tail_scalar,
            )
        )

    return OwnershipReport(
        generated_at=datetime.now().isoformat(timespec="seconds"),
        slots=slot_reports,
        issues=issues,
        status="ok" if not issues else "fail",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Check ArrayF32 backend ownership")
    parser.add_argument("--json-file", default="")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--summary-line", action="store_true")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    try:
        report = build_report(repo_root)
    except FileNotFoundError as exc:
        print(f"[ARRAY-F32-OWNERSHIP] Missing input file: {exc}")
        return 2

    payload = {
        "generated_at": report.generated_at,
        "slots": [asdict(slot) for slot in report.slots],
        "issues": report.issues,
        "status": report.status,
    }

    if args.json_file:
        json_path = Path(args.json_file)
        if not json_path.is_absolute():
            json_path = repo_root / json_path
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"[ARRAY-F32-OWNERSHIP] JSON snapshot: {json_path}")

    print("[ARRAY-F32-OWNERSHIP] ArrayF32 dispatch/backend ownership")
    for slot in report.slots:
        print(
            f"  - {slot.slot}: scalar={slot.scalar_fallback} "
            f"sse2={slot.sse2_owner} avx2={slot.avx2_owner}"
        )
    if report.issues:
        print("[ARRAY-F32-OWNERSHIP] FAIL")
        for issue in report.issues:
            print(f"  - {issue}")
    else:
        print("[ARRAY-F32-OWNERSHIP] OK")

    if args.summary_line:
        print(
            "ARRAY_F32_BACKEND_OWNERSHIP_SUMMARY "
            f"slots={len(report.slots)} "
            f"scalar={len(report.slots)} "
            f"sse2={len(report.slots)} "
            f"avx2={len(report.slots)} "
            f"issues={len(report.issues)} "
            f"status={report.status}"
        )

    if args.json:
        print(json.dumps(payload, ensure_ascii=False, indent=2))

    return 0 if not report.issues else 1


if __name__ == "__main__":
    sys.exit(main())
