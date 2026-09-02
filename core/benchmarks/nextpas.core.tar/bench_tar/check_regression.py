#!/usr/bin/env python3
"""
Tar bench 回归门：对比 BASELINE.json 与当前 build/bench-tar.json。
以 allocs 为硬预算（+2 抖动），bytes 必须相等，ns/op 允许 +50%（噪声大）。
任一硬门失败即非零退出，CI 红；ns/MB/s 超限仅 WARN。
"""
import json
import sys
import pathlib

BASELINE = pathlib.Path(__file__).parent / "BASELINE.json"
CANDIDATES = [
    pathlib.Path(__file__).parent / "../../../build/bench-tar.json",
    pathlib.Path(__file__).parent / "../../../build/projects/nextpas.core.tar/bench_tar/bench_tar.json",
    pathlib.Path(__file__).parent / "build/bench-tar.json",
    pathlib.Path("build/bench-tar.json"),
    pathlib.Path(__file__).parent.parent.parent.parent / "build/bench-tar.json",
]

def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def find_current():
    for p in CANDIDATES:
        for base in [pathlib.Path.cwd(), pathlib.Path(__file__).parent]:
            cand = (base / p).resolve() if not p.is_absolute() else p.resolve()
            if cand.exists():
                return cand
        if p.exists():
            return p
    cur = pathlib.Path(__file__).resolve()
    for parent in cur.parents:
        cand = parent / "build/bench-tar.json"
        if cand.exists():
            return cand
    return None

def main():
    baseline_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else BASELINE
    current_path = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else find_current()
    if current_path is None or not current_path.exists():
        print(f"[regression] current bench not found (tried {CANDIDATES})", file=sys.stderr)
        print("hint: run `make -C core/benchmarks/nextpas.core.tar/bench_tar run` first", file=sys.stderr)
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
        base_allocs = int(bbase.get("allocs_per_op", 0))
        cur_allocs = int(bcur.get("allocs_per_op", 0))
        if cur_allocs > base_allocs + 2:
            print(f"  FAIL {name}: allocs {cur_allocs} > baseline {base_allocs}+2", file=sys.stderr)
            failed += 1
        else:
            print(f"  OK   {name}: allocs {cur_allocs} <= {base_allocs}+2")
        if bbase.get("bytes_per_op") != bcur.get("bytes_per_op"):
            print(f"  FAIL {name}: bytes {bcur.get('bytes_per_op')} != {bbase.get('bytes_per_op')}", file=sys.stderr)
            failed += 1
        base_ns = float(bbase.get("ns_per_op", 0))
        cur_ns = float(bcur.get("ns_per_op", 0))
        if base_ns > 0 and cur_ns > base_ns * 1.50:
            print(f"  WARN {name}: ns {cur_ns:.0f} > baseline {base_ns:.0f} *1.5 ({cur_ns/base_ns:.2f}x) — noise?", file=sys.stderr)
        base_mbs = float(bbase.get("bytes_per_op", 0)) / base_ns if base_ns else 0
        cur_mbs = float(bcur.get("bytes_per_op", 0)) / cur_ns if cur_ns else 0
        if base_mbs > 0 and cur_mbs < base_mbs * 0.65:
            print(f"  WARN {name}: MB/s {cur_mbs:.1f} < baseline {base_mbs:.1f} *0.65", file=sys.stderr)
        if bcur.get("status") != "ok":
            print(f"  FAIL {name}: status {bcur.get('status')} != ok", file=sys.stderr)
            failed += 1
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
