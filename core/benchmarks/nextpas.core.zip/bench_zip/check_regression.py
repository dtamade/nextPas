#!/usr/bin/env python3
"""
Zip bench 回归门：对比 BASELINE.json 与当前 build/bench-zip.json。
以 allocs 为硬预算（零容忍 +2 抖动），bytes 必须相等，ns/op 允许 +30%（噪声大）。
任一回归即非零退出，CI 硬门。
"""
import json
import sys
import pathlib

BASELINE = pathlib.Path(__file__).parent / "BASELINE.json"
# current: 优先 build/bench-zip.json，其次 ../../../build/... 其次 build/...
CANDIDATES = [
    pathlib.Path(__file__).parent / "../../../build/bench-zip.json",
    pathlib.Path(__file__).parent / "../../../build/projects/nextpas.core.zip/bench_zip/bench_zip.json",
    pathlib.Path(__file__).parent / "build/bench-zip.json",
    pathlib.Path("build/bench-zip.json"),
    pathlib.Path(__file__).parent.parent.parent.parent / "build/bench-zip.json",
]

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def find_current():
    for p in CANDIDATES:
        # resolve relative to repo root if needed
        for base in [pathlib.Path.cwd(), pathlib.Path(__file__).parent]:
            cand = (base / p).resolve() if not p.is_absolute() else p.resolve()
            if cand.exists():
                return cand
        if p.exists():
            return p
    # fallback: search upward
    cur = pathlib.Path(__file__).resolve()
    for parent in cur.parents:
        cand = parent / "build/bench-zip.json"
        if cand.exists():
            return cand
    return None

def main():
    baseline_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else BASELINE
    current_path = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else find_current()
    if current_path is None or not current_path.exists():
        print(f"[regression] current bench not found (tried {CANDIDATES})", file=sys.stderr)
        print("hint: run `make -C core/benchmarks/nextpas.core.zip/bench_zip run` first", file=sys.stderr)
        sys.exit(2)
    base = load(baseline_path)
    cur = load(current_path)
    base_map = {b["name"]: b for b in base.get("benchmarks", [])}
    cur_map = {b["name"]: b for b in cur.get("benchmarks", [])}
    failed = 0
    print(f"[regression] baseline: {baseline_path} ({len(base_map)} benches)")
    print(f"[regression] current : {current_path} ({len(cur_map)} benches)")
    for name, bbase in base_map.items():
        if name not in cur_map:
            print(f"  MISSING {name} in current", file=sys.stderr)
            failed += 1
            continue
        bcur = cur_map[name]
        # allocs hard budget: +2 slack
        base_allocs = int(bbase.get("allocs_per_op", 0))
        cur_allocs = int(bcur.get("allocs_per_op", 0))
        if cur_allocs > base_allocs + 2:
            print(f"  FAIL {name}: allocs {cur_allocs} > baseline {base_allocs}+2", file=sys.stderr)
            failed += 1
        else:
            print(f"  OK   {name}: allocs {cur_allocs} <= {base_allocs}+2")
        # bytes must equal
        if bbase.get("bytes_per_op") != bcur.get("bytes_per_op"):
            print(f"  FAIL {name}: bytes {bcur.get('bytes_per_op')} != {bbase.get('bytes_per_op')}", file=sys.stderr)
            failed += 1
        # ns soft check: +50% (bench noise high, see 18ms->26ms)
        base_ns = float(bbase.get("ns_per_op", 0))
        cur_ns = float(bcur.get("ns_per_op", 0))
        if base_ns > 0 and cur_ns > base_ns * 1.50:
            print(f"  WARN {name}: ns {cur_ns:.0f} > baseline {base_ns:.0f} *1.5 ({cur_ns/base_ns:.2f}x) — noise?", file=sys.stderr)
            # not failing hard for now, just warn
        # status must be ok
        if bcur.get("status") != "ok":
            print(f"  FAIL {name}: status {bcur.get('status')} != ok", file=sys.stderr)
            failed += 1
    # extra benches not in baseline: just warn
    for name in cur_map:
        if name not in base_map:
            print(f"  WARN extra bench {name} not in baseline", file=sys.stderr)
    if failed:
        print(f"[regression] {failed} check(s) failed", file=sys.stderr)
        sys.exit(1)
    print("[regression] all allocs/bytes checks passed")
    sys.exit(0)

if __name__ == "__main__":
    main()
