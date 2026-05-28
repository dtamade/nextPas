#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
RISCVV_FACADE_FILE = ROOT / "src" / "nextpas.core.simd.riscvv.facade.inc"

ROUTINE_BLOCK_RE = re.compile(
    r"(?ims)^(function|procedure)\s+([A-Za-z_][A-Za-z0-9_\.]*)\b.*?"
    r"(?=^(function|procedure)\s+[A-Za-z_][A-Za-z0-9_\.]*\b|^initialization\b|\Z)"
)
SCALAR_CALL_RE = re.compile(r"\bScalar[A-Za-z0-9_]+\s*\(", re.IGNORECASE)

EXPECTED_SENSITIVE_ROUTINES: dict[str, tuple[str, ...]] = {
    "RISCVVRcpF64x4": (
        "for i := 0 to 3 do",
        "if a.d[i] <> 0.0 then",
        "Result.d[i] := 1.0 / a.d[i]",
        "Result.d[i] := 0.0;",
    ),
    "RISCVVClampF64x4": (
        "for i := 0 to 3 do",
        "if a.d[i] < minVal.d[i] then",
        "else if a.d[i] > maxVal.d[i] then",
        "Result.d[i] := a.d[i];",
    ),
    "RISCVVClampF64x8": (
        "for i := 0 to 7 do",
        "if a.d[i] < minVal.d[i] then",
        "else if a.d[i] > maxVal.d[i] then",
        "Result.d[i] := a.d[i];",
    ),
    "RISCVVReduceAddF64x4": (
        "Result := a.d[0];",
        "for i := 1 to 3 do",
        "Result := Result + a.d[i];",
    ),
    "RISCVVReduceAddF64x8": (
        "Result := a.d[0];",
        "for i := 1 to 7 do",
        "Result := Result + a.d[i];",
    ),
    "RISCVVReduceMulF64x4": (
        "Result := a.d[0];",
        "for i := 1 to 3 do",
        "Result := Result * a.d[i];",
    ),
    "RISCVVReduceMulF64x8": (
        "Result := a.d[0];",
        "for i := 1 to 7 do",
        "Result := Result * a.d[i];",
    ),
}
IGNORED_LOCAL_UTILITY_PREFIXES = ("RISCVVMask",)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Fail-close unless the no-asm RISCVV facade keeps exactly the "
            "expected sensitive local-contract hold set."
        )
    )
    parser.add_argument("--json", action="store_true", help="Print JSON report.")
    parser.add_argument(
        "--json-file",
        default="",
        help="Write JSON report to file.",
    )
    parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print a single-line summary for log scraping.",
    )
    return parser.parse_args()


def read_text(aPath: Path) -> str:
    return aPath.read_text(encoding="utf-8")


def strip_pascal_comments(aText: str) -> str:
    aText = re.sub(r"\{.*?\}", " ", aText, flags=re.S)
    aText = re.sub(r"\(\*.*?\*\)", " ", aText, flags=re.S)
    aText = re.sub(r"//.*?$", "", aText, flags=re.M)
    return aText


def normalize(aText: str) -> str:
    return re.sub(r"\s+", " ", aText.strip())


def collect_routine_blocks(aSource: str) -> dict[str, str]:
    LBlocks: dict[str, str] = {}
    for LMatch in ROUTINE_BLOCK_RE.finditer(aSource):
        LBlocks[LMatch.group(2)] = LMatch.group(0)
    return LBlocks


def is_scalar_forwarder(aBlock: str) -> bool:
    return bool(SCALAR_CALL_RE.search(strip_pascal_comments(aBlock)))


def make_issue(aKind: str, aDetail: str) -> dict[str, str]:
    return {"kind": aKind, "detail": aDetail}


def build_report() -> dict[str, object]:
    if not RISCVV_FACADE_FILE.is_file():
        return {
            "ok": False,
            "file": str(RISCVV_FACADE_FILE),
            "issues": [make_issue("missing-file", str(RISCVV_FACADE_FILE))],
            "actual_sensitive_routines": [],
            "expected_sensitive_routines": sorted(EXPECTED_SENSITIVE_ROUTINES),
        }

    LSource = read_text(RISCVV_FACADE_FILE)
    LBlocks = collect_routine_blocks(LSource)
    LIssues: list[dict[str, str]] = []

    LActualSensitive: dict[str, str] = {}
    for LName, LBlock in LBlocks.items():
        if not LName.startswith("RISCVV"):
            continue
        if any(LName.startswith(LPrefix) for LPrefix in IGNORED_LOCAL_UTILITY_PREFIXES):
            continue
        if is_scalar_forwarder(LBlock):
            continue
        LActualSensitive[LName] = LBlock

    LExpectedNames = set(EXPECTED_SENSITIVE_ROUTINES)
    LActualNames = set(LActualSensitive)

    for LName in sorted(LExpectedNames - LActualNames):
        LIssues.append(make_issue("missing-sensitive-routine", LName))
    for LName in sorted(LActualNames - LExpectedNames):
        LIssues.append(make_issue("unexpected-sensitive-routine", LName))

    for LName in sorted(LExpectedNames & LActualNames):
        LNormalizedBlock = normalize(LActualSensitive[LName])
        for LFragment in EXPECTED_SENSITIVE_ROUTINES[LName]:
            if normalize(LFragment) not in LNormalizedBlock:
                LIssues.append(
                    make_issue(
                        "missing-fragment",
                        f"{LName}: {LFragment}",
                    )
                )

    return {
        "ok": not LIssues,
        "file": str(RISCVV_FACADE_FILE),
        "issues": LIssues,
        "actual_sensitive_routines": sorted(LActualNames),
        "expected_sensitive_routines": sorted(LExpectedNames),
    }


def render_summary(aReport: dict[str, object]) -> str:
    LActual = aReport["actual_sensitive_routines"]
    LIssues = aReport["issues"]
    return (
        "RISCVV_SENSITIVE_HOLD_SET_SUMMARY "
        f"routines={len(LActual)} issues={len(LIssues)} "
        f"status={'ok' if aReport['ok'] else 'fail'}"
    )


def print_human_report(aReport: dict[str, object]) -> None:
    print(f"[RISCVV-HOLD] file={aReport['file']}")
    print(
        f"[RISCVV-HOLD] expected={','.join(aReport['expected_sensitive_routines'])}"
    )
    print(
        f"[RISCVV-HOLD] actual={','.join(aReport['actual_sensitive_routines'])}"
    )
    if aReport["ok"]:
        print("[RISCVV-HOLD] OK")
        return

    print(f"[RISCVV-HOLD] FAILED issues={len(aReport['issues'])}")
    for LIssue in aReport["issues"]:
        print(f"  - {LIssue['kind']}: {LIssue['detail']}")


def main() -> int:
    LArgs = parse_args()
    LReport = build_report()

    if LArgs.json_file:
        LOutputPath = Path(LArgs.json_file)
        LOutputPath.parent.mkdir(parents=True, exist_ok=True)
        LOutputPath.write_text(
            json.dumps(LReport, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    if LArgs.json:
        print(json.dumps(LReport, ensure_ascii=False, indent=2))
    else:
        print_human_report(LReport)

    if LArgs.summary_line:
        print(render_summary(LReport))

    return 0 if LReport["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
