#!/usr/bin/env python3
"""Generate normalize_compose_index.inc from COMPOSE_TABLE in normalize.inc."""
import re
from pathlib import Path

def main() -> None:
    root = Path(__file__).resolve().parents[1]
    text = (root / "src/nextpas.core.text.unicode.normalize.inc").read_text()
    sec = text.split("COMPOSE_TABLE:")[1].split(");")[0]
    starters = []
    for m in re.finditer(
        r"Starter: \$([0-9A-Fa-f]+); Combining: \$([0-9A-Fa-f]+); ResultCp: \$([0-9A-Fa-f]+)",
        sec,
    ):
        starters.append(int(m.group(1), 16))
    runs = []
    i = 0
    while i < len(starters):
        s = starters[i]
        lo = i
        while i < len(starters) and starters[i] == s:
            i += 1
        runs.append((s, lo, i - 1))
    lines = [
        "// {Auto-generated compose starter runs from COMPOSE_TABLE}",
        "type",
        "  TComposeRun = record",
        "    Starter: TUnicodeCodepoint;",
        "    Lo: Int32;",
        "    Hi: Int32;",
        "  end;",
        "",
        "const",
        f"  COMPOSE_RUN_COUNT = {len(runs)};",
        f"  COMPOSE_RUNS: array[0..{len(runs)-1}] of TComposeRun = (",
    ]
    for j, (s, lo, hi) in enumerate(runs):
        comma = "," if j < len(runs) - 1 else ""
        lines.append(f"    (Starter: ${s:04X}; Lo: {lo}; Hi: {hi}){comma}")
    lines.append("  );")
    out = root / "src/nextpas.core.text.unicode.normalize_compose_index.inc"
    out.write_text("\n".join(lines) + "\n")
    print(f"Wrote {out} runs={len(runs)}")

if __name__ == "__main__":
    main()
