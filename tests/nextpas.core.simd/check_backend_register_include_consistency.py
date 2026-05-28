#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check that backend *.register.inc files are actually included by their sibling Pascal units."
    )
    parser.add_argument(
        "--summary-line",
        action="store_true",
        help="Print a single-line summary for log scraping.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    root = Path(__file__).resolve().parents[2]
    src_dir = root / "src"
    register_includes = sorted(src_dir.glob("nextpas.core.simd*.register.inc"))

    if not register_includes:
        print("[REGISTER-INCLUDE] No *.register.inc files found")
        return 0

    missing_units: list[str] = []
    orphan_includes: list[str] = []

    for inc_path in register_includes:
        unit_path = inc_path.with_name(inc_path.name.replace(".register.inc", ".pas"))
        if not unit_path.exists():
            missing_units.append(inc_path.name)
            continue

        unit_text = unit_path.read_text(encoding="utf-8", errors="replace")
        include_pattern = re.compile(
            r"\{\$I\s+" + re.escape(inc_path.name) + r"\s*\}",
            re.IGNORECASE,
        )
        if include_pattern.search(unit_text) is None:
            orphan_includes.append(inc_path.name)

    print("[REGISTER-INCLUDE] backend register include consistency")
    print(f"  - register_includes: {len(register_includes)}")
    print(f"  - missing_units:     {len(missing_units)}")
    print(f"  - orphan_includes:   {len(orphan_includes)}")

    if missing_units:
        print("  - missing_unit_files:")
        for item in missing_units:
            print(f"    - {item}")

    if orphan_includes:
        print("  - orphan_register_includes:")
        for item in orphan_includes:
            print(f"    - {item}")

    if args.summary_line:
        print(
            "REGISTER_INCLUDE_SUMMARY "
            f"includes={len(register_includes)} "
            f"missing_units={len(missing_units)} "
            f"orphan_includes={len(orphan_includes)}"
        )

    if missing_units or orphan_includes:
        return 1

    print("[REGISTER-INCLUDE] OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
