#!/usr/bin/env python3
"""Report top blockers for non-x86 experimental backend asm QEMU logs."""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


DEFAULT_SCENARIO = "nonx86-experimental-asm"
SUMMARY_FILE = "summary.md"
DEFAULT_OUTPUT = "tests/nextpas.core.simd/docs/experimental_asm_blockers.md"


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
        platform = m.group(1).strip()
        status = m.group(2).strip()
        log_str = m.group(3).strip()
        entries.append(PlatformEntry(platform=platform, status=status, log_path=Path(log_str)))

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


def extract_error_items(entry: PlatformEntry) -> tuple[list[ErrorItem], dict[str, Counter[str]]]:
    if not entry.log_path.is_file():
        return [], {}

    log_text = entry.log_path.read_text(encoding="utf-8", errors="ignore")
    err_line_re = re.compile(r"^(.*\b(?:Error|Fatal):\s+.*)$")

    all_items: list[ErrorItem] = []
    grouped: dict[str, Counter[str]] = {}

    for raw in log_text.splitlines():
        line = raw.strip()
        m = err_line_re.match(line)
        if not m:
            continue
        signature = m.group(1).strip()
        backend = classify_backend(signature, entry.platform)
        message = signature.split(":", 1)[1].strip() if ":" in signature else signature
        category = classify_category(message)
        grouped.setdefault(backend, Counter())[f"{category}|||{signature}"] += 1
        all_items.append(
            ErrorItem(
                platform=entry.platform,
                backend=backend,
                category=category,
                signature=signature,
            )
        )

    return all_items, grouped


def resolve_log_dir(args: argparse.Namespace, script_dir: Path) -> Path:
    if args.log_dir:
        return Path(args.log_dir)

    logs_root = script_dir / "logs"
    if args.latest:
        latest = find_latest_experimental_dir(logs_root=logs_root, scenario=args.scenario)
        if latest is None:
            print(f"ERROR: no qemu-multiarch logs found for scenario '{args.scenario}' under {logs_root}")
            raise SystemExit(2)
        return latest

    print("ERROR: either --log-dir or --latest is required")
    raise SystemExit(2)


def render_report(
    report_dir: Path,
    scenario: str,
    entries: list[PlatformEntry],
    all_items: list[ErrorItem],
    grouped_by_backend: dict[str, Counter[str]],
    output_path: Path,
    max_rows_per_backend: int,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    lines: list[str] = []

    lines.append("# Experimental ASM Blockers Report")
    lines.append("")
    lines.append(f"- generated_at: {datetime.now().isoformat(timespec='seconds')}")
    lines.append(f"- log_dir: `{report_dir}`")
    lines.append(f"- scenario: `{scenario}`")
    lines.append("")
    lines.append("## Platform Summary")
    lines.append("")
    lines.append("| Platform | Status | Log |")
    lines.append("|---|---|---|")
    for entry in entries:
        lines.append(f"| {entry.platform} | {entry.status} | `{entry.log_path}` |")

    lines.append("")
    lines.append("## Platform Blockers")
    lines.append("")

    by_platform: dict[str, Counter[str]] = {}
    for item in all_items:
        by_platform.setdefault(item.platform, Counter())[f"{item.backend}|||{item.category}"] += 1

    for entry in entries:
        lines.append(f"### {entry.platform}")
        lines.append("")
        if entry.platform not in by_platform:
            lines.append("- no compile errors parsed")
            lines.append("")
            continue
        lines.append("| Backend | Category | Count |")
        lines.append("|---|---|---:|")
        for packed, count in by_platform[entry.platform].most_common():
            backend, category = packed.split("|||", 1)
            lines.append(f"| {backend} | {category} | {count} |")
        lines.append("")

    lines.append("")
    lines.append("## Backend Blockers")
    lines.append("")

    if not grouped_by_backend:
        lines.append("- no backend errors parsed")
    else:
        for backend in sorted(grouped_by_backend.keys()):
            counter = grouped_by_backend[backend]
            cat_counter: Counter[str] = Counter()
            for packed, count in counter.items():
                category = packed.split("|||", 1)[0]
                cat_counter[category] += count

            lines.append(f"### {backend}")
            lines.append("")
            lines.append(f"- total_errors: {sum(counter.values())}")
            lines.append(
                "- category_breakdown: "
                + ", ".join(f"{cat}={cat_counter[cat]}" for cat in sorted(cat_counter.keys()))
            )
            lines.append("")
            lines.append("| Category | Count | Signature |")
            lines.append("|---|---:|---|")
            for packed, count in counter.most_common(max_rows_per_backend):
                category, signature = packed.split("|||", 1)
                normalized_sig = signature.replace("|", "/")
                lines.append(f"| {category} | {count} | `{normalized_sig}` |")
            lines.append("")

    output_path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Report experimental asm blockers from QEMU logs")
    parser.add_argument("--log-dir", default="", help="Path to qemu-multiarch-* log directory")
    parser.add_argument("--latest", action="store_true", help="Use latest qemu-multiarch log directory")
    parser.add_argument("--scenario", default=DEFAULT_SCENARIO, help="Expected QEMU scenario")
    parser.add_argument("--top", type=int, default=15, help="Top signatures per backend in report")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="Output markdown path")
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    report_dir = resolve_log_dir(args, script_dir=script_dir)

    if not report_dir.exists():
        print(f"ERROR: log dir not found: {report_dir}")
        return 2
    if not report_dir.is_dir():
        print(f"ERROR: log dir is not a directory: {report_dir}")
        return 2

    summary_path = report_dir / SUMMARY_FILE
    if not summary_path.is_file():
        print(f"ERROR: summary file not found: {summary_path}")
        return 2

    scenario, entries = parse_summary(summary_path)
    if not entries:
        print(f"ERROR: no platform rows parsed from summary: {summary_path}")
        return 2

    if args.scenario and scenario and scenario != args.scenario:
        print(f"ERROR: scenario mismatch, expected={args.scenario}, actual={scenario}")
        return 2

    backend_grouped: dict[str, Counter[str]] = {}
    all_items: list[ErrorItem] = []

    for entry in entries:
        items, grouped = extract_error_items(entry=entry)
        all_items.extend(items)
        for backend, counter in grouped.items():
            backend_grouped.setdefault(backend, Counter()).update(counter)

    output_path = Path(args.output)
    if not output_path.is_absolute():
        repo_root = script_dir.parents[1]
        output_path = (repo_root / output_path).resolve()

    render_report(
        report_dir=report_dir.resolve(),
        scenario=scenario or args.scenario,
        entries=entries,
        all_items=all_items,
        grouped_by_backend=backend_grouped,
        output_path=output_path,
        max_rows_per_backend=max(1, args.top),
    )

    print(f"[QEMU-EXPERIMENTAL-REPORT] log_dir={report_dir}")
    print(f"[QEMU-EXPERIMENTAL-REPORT] output={output_path}")
    print(f"[QEMU-EXPERIMENTAL-REPORT] platform_rows={len(entries)} parsed_errors={len(all_items)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
