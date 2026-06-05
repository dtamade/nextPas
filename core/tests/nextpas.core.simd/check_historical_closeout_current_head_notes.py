#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys


SUPSERSEDED_MARKER = "Status: superseded historical plan."
CURRENT_HEAD_NOTE = "Current HEAD note"
KEYWORDS = (
    "cross-ready",
    "freeze-status",
    "win-evidence",
    "windows evidence",
    "Windows 实机证据",
    "closeout",
)
REQUIRED_REFERENCES = (
    "docs/simd/closeout.md",
    "tests/nextpas.core.simd/docs/windows_b07_closeout_runbook.md",
)


def is_target_document(text: str) -> bool:
    if SUPSERSEDED_MARKER not in text:
        return False

    lowered = text.lower()
    return any(keyword.lower() in lowered for keyword in KEYWORDS)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Fail-close when historical SIMD closeout/freeze plans no longer carry "
            "a Current HEAD note that redirects maintainers to the active truth sources."
        )
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=None,
        help="Override repository root. Defaults to ../../ from this script.",
    )
    parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print a single summary line instead of the detailed report.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    script_dir = Path(__file__).resolve().parent
    repo_root = (args.repo_root or script_dir.parent.parent).resolve()
    plans_dir = repo_root / "docs" / "plans"

    if not plans_dir.is_dir():
        print(f"[CHECK] Missing plans dir: {plans_dir}")
        return 2

    targets = []
    failures: list[tuple[Path, list[str]]] = []

    for path in sorted(plans_dir.glob("*.md")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        if not is_target_document(text):
            continue

        targets.append(path)
        missing = []
        if CURRENT_HEAD_NOTE not in text:
            missing.append(CURRENT_HEAD_NOTE)
        for required_ref in REQUIRED_REFERENCES:
            if required_ref not in text:
                missing.append(required_ref)
        if missing:
            failures.append((path.relative_to(repo_root), missing))

    if failures:
        if args.summary_line:
            print(
                f"[CHECK] FAIL historical closeout notes: {len(failures)}/{len(targets)} target docs missing Current HEAD guidance"
            )
        else:
            print("[CHECK] FAIL historical closeout current-head notes")
            for rel_path, missing in failures:
                print(f"[CHECK] {rel_path}")
                for item in missing:
                    print(f"[CHECK]   missing: {item}")
        return 1

    if args.summary_line:
        print(f"[CHECK] OK historical closeout notes: {len(targets)} target docs")
    else:
        print(
            f"[CHECK] OK historical closeout current-head notes ({len(targets)} target docs)"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
