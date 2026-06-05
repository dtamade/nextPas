#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys


TARGET_SPECS: dict[str, dict[str, tuple[str, ...]]] = {
    "docs/simd/README.md": {
        "required": (
            "模块状态应按 `code-green / cross-ready` 理解",
            "docs/simd/checklist.md",
            "docs/simd/closeout.md",
            "full `freeze-status` 当前为 `ready=True / mainline-ready=True / cross-ready=True`",
            "当前状态理解成 `code-green / cross-ready`",
            "canonical `public-api-coverage` 现在默认按 `strict-thin` 运行",
        ),
        "forbidden": (
            "截至 `2026-05-17`，模块状态应按 `code-green / release-evidence-blocked` 理解",
        ),
    },
    "docs/simd/checklist.md": {
        "required": (
            "`cross-ready=True`",
            "`code-green / cross-ready`",
            "只有当 future `freeze-status` 再次变红时",
            "canonical `public-api-coverage` 现在默认按 `strict-thin` 运行",
        ),
    },
    "docs/simd/closeout.md": {
        "required": (
            "`ready=True / mainline-ready=True / cross-ready=True`",
            "`code-green / cross-ready`",
            "如果 future `freeze-status` 里的 Windows evidence log 旧于最新",
            "live `check_nonx86_helper_semantics.py --summary-line` source truth",
            "`check_riscvv_sensitive_hold_set.py`",
            "canonical `public-api-coverage` 现在默认按 `strict-thin` 运行",
        ),
        "forbidden_line_pairs": (
            ("当前 fresh 结果应理解为：", "`checks="),
            ("当前 fresh 结果：", "`checks="),
        ),
    },
    "docs/simd/maintenance.md": {
        "required": (
            "当前应按 `code-green / cross-ready` 理解",
            "默认不要再重开 closeout blocker 讨论",
            "canonical `public-api-coverage` 现在默认按 `strict-thin` 运行",
        ),
    },
    "docs/simd/handoff.md": {
        "required": (
            "cross-platform `freeze-status` 当前为 `ready=True / mainline-ready=True / cross-ready=True`",
            "当前 `HEAD` 的更准确交接口径应是 `code-green / cross-ready`",
            "canonical `public-api-coverage` 现在默认按 `strict-thin` 运行",
        ),
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Fail-close when active SIMD entry/closeout docs drift away from the "
            "current HEAD truth for release readiness and handoff wording."
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

    failures: list[tuple[Path, list[str]]] = []

    for rel_path_str, spec in TARGET_SPECS.items():
        rel_path = Path(rel_path_str)
        target = repo_root / rel_path
        if not target.is_file():
            failures.append((rel_path, ["missing file"]))
            continue

        text = target.read_text(encoding="utf-8", errors="ignore")
        issues: list[str] = []
        for required in spec.get("required", ()):
            if required not in text:
                issues.append(f"missing required text: {required}")
        for forbidden in spec.get("forbidden", ()):
            if forbidden in text:
                issues.append(f"forbidden stale text present: {forbidden}")
        for line_pair in spec.get("forbidden_line_pairs", ()):
            for line in text.splitlines():
                if all(fragment in line for fragment in line_pair):
                    issues.append(
                        "forbidden line pair present: " + " + ".join(line_pair)
                    )
                    break

        if issues:
            failures.append((rel_path, issues))

    if failures:
        if args.summary_line:
            print(
                f"[CHECK] FAIL active closeout truth: {len(failures)}/{len(TARGET_SPECS)} target docs drift from current HEAD truth"
            )
        else:
            print("[CHECK] FAIL active closeout current-head truth")
            for rel_path, issues in failures:
                print(f"[CHECK] {rel_path}")
                for issue in issues:
                    print(f"[CHECK]   {issue}")
        return 1

    if args.summary_line:
        print(f"[CHECK] OK active closeout truth: {len(TARGET_SPECS)} target docs")
    else:
        print(
            f"[CHECK] OK active closeout current-head truth ({len(TARGET_SPECS)} target docs)"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
