#!/usr/bin/env python3
"""Check experimental asm QEMU failure patterns against expected baseline."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_SCENARIO = "nonx86-experimental-asm"
DEFAULT_BASELINE = "tests/nextpas.core.simd/docs/experimental_asm_expected_failures.json"
SUMMARY_FILE = "summary.md"


@dataclass(frozen=True)
class PlatformEntry:
    platform: str
    status: str
    log_path: Path


@dataclass(frozen=True)
class ErrorItem:
    platform: str
    backend: str
    category: str
    signature: str


def classify_backend(line: str, platform: str) -> str:
    ll = line.lower()
    if "simd.neon.pas" in ll:
        return "neon"
    if "simd.riscvv.pas" in ll or "simd.rvv.pas" in ll:
        return "riscvv"
    if "simd.sve2.pas" in ll:
        return "sve2"
    if "simd.sve.pas" in ll:
        return "sve"
    if "simd.lasx.pas" in ll:
        return "lasx"
    if platform.endswith("arm64"):
        return "neon"
    if platform.endswith("riscv64"):
        return "riscvv"
    return "unknown"


def classify_category(message: str) -> str:
    lm = message.lower()
    if "unrecognized opcode" in lm:
        return "opcode"
    if "assembler syntax error" in lm or "invalid arrangement specifier" in lm:
        return "syntax"
    if "identifier not found" in lm:
        return "symbol"
    if "there were" in lm and "errors compiling module" in lm:
        return "compile-stop"
    return "other"


def parse_summary(summary_path: Path) -> tuple[str, list[PlatformEntry]]:
    text = summary_path.read_text(encoding="utf-8", errors="ignore")
    scenario = ""
    entries: list[PlatformEntry] = []
    row_re = re.compile(r"^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*`([^`]+)`\s*\|$")

    for line in text.splitlines():
        line = line.strip()
        if line.startswith("- scenario:"):
            scenario = line.split(":", 1)[1].strip()
            continue
        if not line.startswith("|"):
            continue
        if line.startswith("|---") or line.startswith("| Platform "):
            continue
        m = row_re.match(line)
        if not m:
            continue
        entries.append(
            PlatformEntry(
                platform=m.group(1).strip(),
                status=m.group(2).strip(),
                log_path=Path(m.group(3).strip()),
            )
        )
    return scenario, entries


def find_latest_experimental_dir(logs_root: Path, scenario: str) -> Path | None:
    candidates = sorted(logs_root.glob("qemu-multiarch-*"), key=lambda p: p.name, reverse=True)
    for candidate in candidates:
        summary_path = candidate / SUMMARY_FILE
        if not summary_path.is_file():
            continue
        detected_scenario, entries = parse_summary(summary_path)
        # Skip in-progress/incomplete runs whose summary has not flushed platform rows yet.
        if detected_scenario == scenario and entries:
            return candidate
    return None


def resolve_log_dir(args: argparse.Namespace, script_dir: Path) -> Path:
    if args.log_dir:
        return Path(args.log_dir)
    if args.latest:
        latest = find_latest_experimental_dir(script_dir / "logs", scenario=args.scenario)
        if latest is None:
            raise RuntimeError(f"no qemu-multiarch logs found for scenario '{args.scenario}'")
        return latest
    raise RuntimeError("either --log-dir or --latest is required")


def parse_errors(entry: PlatformEntry) -> list[ErrorItem]:
    if not entry.log_path.is_file():
        return []
    log_text = entry.log_path.read_text(encoding="utf-8", errors="ignore")
    err_line_re = re.compile(r"^(.*\b(?:Error|Fatal):\s+.*)$")
    items: list[ErrorItem] = []
    for raw in log_text.splitlines():
        line = raw.strip()
        m = err_line_re.match(line)
        if not m:
            continue
        signature = m.group(1).strip()
        backend = classify_backend(signature, entry.platform)
        message = signature.split(":", 1)[1].strip() if ":" in signature else signature
        category = classify_category(message)
        items.append(
            ErrorItem(
                platform=entry.platform,
                backend=backend,
                category=category,
                signature=signature,
            )
        )
    return items


def load_baseline(baseline_path: Path) -> dict[str, Any]:
    if not baseline_path.is_file():
        raise FileNotFoundError(f"baseline missing: {baseline_path}")
    return json.loads(baseline_path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Check experimental asm failures against baseline")
    parser.add_argument("--log-dir", default="", help="Path to qemu-multiarch-* log directory")
    parser.add_argument("--latest", action="store_true", help="Use latest qemu-multiarch log directory")
    parser.add_argument("--scenario", default=DEFAULT_SCENARIO, help="Expected QEMU scenario")
    parser.add_argument("--baseline", default=DEFAULT_BASELINE, help="Baseline JSON path")
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    repo_root = script_dir.parents[1]

    try:
        log_dir = resolve_log_dir(args=args, script_dir=script_dir)
    except RuntimeError as exc:
        print(f"ERROR: {exc}")
        return 2

    if not log_dir.exists():
        print(f"ERROR: log dir not found: {log_dir}")
        return 2

    summary_path = log_dir / SUMMARY_FILE
    if not summary_path.is_file():
        print(f"ERROR: summary file not found: {summary_path}")
        return 2

    baseline_path = Path(args.baseline)
    if not baseline_path.is_absolute():
        baseline_path = (repo_root / baseline_path).resolve()

    try:
        baseline = load_baseline(baseline_path=baseline_path)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}")
        return 2
    except json.JSONDecodeError as exc:
        print(f"ERROR: baseline invalid json: {exc}")
        return 2

    scenario, entries = parse_summary(summary_path)
    if not entries:
        print(f"ERROR: no platform rows parsed from summary: {summary_path}")
        return 2
    if args.scenario and scenario and scenario != args.scenario:
        print(f"ERROR: scenario mismatch, expected={args.scenario}, actual={scenario}")
        return 1

    platform_errors: dict[str, list[ErrorItem]] = {}
    for entry in entries:
        platform_errors[entry.platform] = parse_errors(entry)

    baseline_platforms: dict[str, Any] = baseline.get("platforms", {})
    errors: list[str] = []
    warnings: list[str] = []

    for entry in entries:
        platform = entry.platform
        entry_baseline = baseline_platforms.get(platform)
        items = platform_errors.get(platform, [])

        if entry_baseline is None:
            if entry.status.upper() == "FAIL" and items:
                errors.append(f"{platform}: unknown failing platform (not in baseline)")
            continue

        if entry.status.upper() == "PASS":
            warnings.append(f"{platform}: now PASS (improvement vs expected fail baseline)")
            continue

        min_failures = int(entry_baseline.get("min_failures", 1))
        max_failures = int(entry_baseline.get("max_failures", 1000000))
        total = len(items)
        if total < min_failures or total > max_failures:
            errors.append(
                f"{platform}: failure count drift ({total}) outside [{min_failures}, {max_failures}]"
            )

        expected_backend = str(entry_baseline.get("backend", "")).strip().lower()
        if expected_backend:
            backends = {item.backend for item in items}
            if expected_backend not in backends:
                errors.append(f"{platform}: backend drift, expected '{expected_backend}', actual={sorted(backends)}")

        required_categories = [str(x).strip().lower() for x in entry_baseline.get("required_categories", [])]
        cat_counter = Counter(item.category for item in items)
        for category in required_categories:
            if cat_counter.get(category, 0) == 0:
                errors.append(f"{platform}: missing required category '{category}'")

        allowed_patterns = [str(x) for x in entry_baseline.get("allowed_signature_patterns", [])]
        if allowed_patterns:
            for item in items:
                if not any(re.search(pattern, item.signature) for pattern in allowed_patterns):
                    errors.append(f"{platform}: unknown failure signature '{item.signature}'")
                    break

        known_failure_markers = [str(x) for x in entry_baseline.get("known_failure_markers", [])]
        for marker in known_failure_markers:
            if not any(marker in item.signature for item in items):
                warnings.append(f"{platform}: known failure marker disappeared '{marker}'")

    for platform in baseline_platforms.keys():
        if platform not in platform_errors:
            warnings.append(f"{platform}: baseline platform missing from summary rows")

    result = {
        "ok": len(errors) == 0,
        "log_dir": str(log_dir),
        "summary": str(summary_path),
        "baseline": str(baseline_path),
        "scenario": scenario,
        "errors": errors,
        "warnings": warnings,
        "platform_count": len(entries),
    }

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print("[QEMU-EXPERIMENTAL-BASELINE] Check result")
        print(f"  - log_dir: {result['log_dir']}")
        print(f"  - baseline: {result['baseline']}")
        print(f"  - scenario: {result['scenario']}")
        print(f"  - errors: {len(errors)}")
        print(f"  - warnings: {len(warnings)}")
        for msg in warnings:
            print(f"  [WARN] {msg}")
        for msg in errors:
            print(f"  [FAIL] {msg}")
        if len(errors) == 0:
            print("[QEMU-EXPERIMENTAL-BASELINE] OK")

    return 0 if len(errors) == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
