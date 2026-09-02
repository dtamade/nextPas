#!/usr/bin/env python3
"""
Tar bench 回归门：对比 BASELINE.json 与当前 build/bench-tar.json。
以 allocs 为硬预算（+2 抖动）、bytes 强一致、ns/op ≤1.50×、MB/s ≥0.65× 均为硬门（CI 红）；
status=ok 强一致。Go/Rust 对照同口径 Pascal ns/op ≤1.50× 且 MB/s ≥0.70× 为硬门（CI 硬红，缺失即硬红）。
任一硬门失败即非零退出，CI 红。
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
# compare artifacts: Go archive/tar vs Rust tar (CONTRACT §6)
COMPARE_GO_CANDIDATES = [
    pathlib.Path(__file__).parent / "compare_go/build/bench-tar-compare-go.json",
    pathlib.Path(__file__).parent / "../../../build/bench-tar-compare-go.json",
    pathlib.Path(__file__).parent / "build/bench-tar-compare-go.json",
]
COMPARE_RUST_CANDIDATES = [
    pathlib.Path(__file__).parent / "compare_rust/build/bench-tar-compare-rust.json",
    pathlib.Path(__file__).parent / "../../../build/bench-tar-compare-rust.json",
    pathlib.Path(__file__).parent / "build/bench-tar-compare-rust.json",
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

def find_compare(cands):
    for p in cands:
        for base in [pathlib.Path.cwd(), pathlib.Path(__file__).parent]:
            cand = (base / p).resolve() if not p.is_absolute() else p.resolve()
            if cand.exists():
                return cand
        if p.exists():
            return p
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
            print(f"  FAIL {name}: ns {cur_ns:.0f} > baseline {base_ns:.0f} *1.5 ({cur_ns/base_ns:.2f}x)", file=sys.stderr)
            failed += 1
        else:
            print(f"  OK   {name}: ns {cur_ns:.0f} <= {base_ns:.0f}*1.5")
        base_mbs = float(bbase.get("bytes_per_op", 0)) / base_ns if base_ns else 0
        cur_mbs = float(bcur.get("bytes_per_op", 0)) / cur_ns if cur_ns else 0
        if base_mbs > 0 and cur_mbs < base_mbs * 0.65:
            print(f"  FAIL {name}: MB/s {cur_mbs:.1f} < baseline {base_mbs:.1f} *0.65 ({cur_mbs/base_mbs:.2f}x)", file=sys.stderr)
            failed += 1
        else:
            if base_mbs > 0:
                print(f"  OK   {name}: MB/s {cur_mbs:.1f} >= {base_mbs:.1f}*0.65")
        if bcur.get("status") != "ok":
            print(f"  FAIL {name}: status {bcur.get('status')} != ok", file=sys.stderr)
            failed += 1
    for name in cur_map:
        if name not in base_map:
            print(f"  WARN extra bench {name} not in baseline", file=sys.stderr)
    # --- Go/Rust compare hard gate (CONTRACT §6) ---
    want_compare = "--with-compare" in sys.argv
    go_path = find_compare(COMPARE_GO_CANDIDATES)
    rust_path = find_compare(COMPARE_RUST_CANDIDATES)
    # CLI explicit compare paths: --compare-go <path> --compare-rust <path>
    if "--compare-go" in sys.argv:
        try:
            go_path = pathlib.Path(sys.argv[sys.argv.index("--compare-go") + 1])
        except Exception:
            pass
    if "--compare-rust" in sys.argv:
        try:
            rust_path = pathlib.Path(sys.argv[sys.argv.index("--compare-rust") + 1])
        except Exception:
            pass
    compare_failed = 0
    for label, cpath in [("Go", go_path), ("Rust", rust_path)]:
        if cpath is None or not cpath.exists():
            print(f"  FAIL compare {label}: missing artifact {cpath} (hard gate, CI 硬红)", file=sys.stderr)
            print(f"       hint: run `make -C core/benchmarks/nextpas.core.tar/bench_tar run-compare` to generate", file=sys.stderr)
            compare_failed += 1
            continue
        try:
            cdata = load(cpath)
        except Exception as e:
            print(f"  FAIL compare {label}: load {cpath} failed: {e}", file=sys.stderr)
            compare_failed += 1
            continue
        cmap = {b["name"]: b for b in cdata.get("benchmarks", [])}
        print(f"[compare] {label}: {cpath} ({len(cmap)} benches)")
        for name, bcur in cur_map.items():
            if name not in cmap:
                continue
            cbench = cmap[name]
            pascal_ns = float(bcur.get("ns_per_op", 0))
            compare_ns = float(cbench.get("ns_per_op", 0))
            if compare_ns > 0 and pascal_ns > compare_ns * 1.50:
                print(f"  FAIL compare {label} {name}: Pascal ns {pascal_ns:.0f} > {label} {compare_ns:.0f} *1.5 ({pascal_ns/compare_ns:.2f}x)", file=sys.stderr)
                compare_failed += 1
            else:
                if compare_ns > 0:
                    print(f"  OK   compare {label} {name}: Pascal {pascal_ns:.0f} <= {label} {compare_ns:.0f}*1.5")
            pascal_mbs = float(bcur.get("bytes_per_op", 0)) / pascal_ns if pascal_ns else 0
            compare_mbs = float(cbench.get("bytes_per_op", 0)) / compare_ns if compare_ns else 0
            if compare_mbs > 0 and pascal_mbs < compare_mbs * 0.70:
                print(f"  FAIL compare {label} {name}: Pascal MB/s {pascal_mbs:.1f} < {label} {compare_mbs:.1f} *0.70", file=sys.stderr)
                compare_failed += 1
            else:
                if compare_mbs > 0:
                    print(f"  OK   compare {label} {name}: Pascal MB/s {pascal_mbs:.1f} >= {label} {compare_mbs:.1f}*0.70")
        # status guard
        for b in cmap.values():
            if b.get("status") != "ok":
                print(f"  WARN compare {label} {b.get('name')}: status {b.get('status')} != ok", file=sys.stderr)
    if compare_failed:
        print(f"[regression] compare gate {compare_failed} failure(s) (CI 硬红)", file=sys.stderr)
        failed += compare_failed
    if failed:
        print(f"[regression] {failed} check(s) failed", file=sys.stderr)
        sys.exit(1)
    print("[regression] all checks passed (allocs/bytes/ns/MB/s hard gate, status ok)")
    if go_path or rust_path:
        print("[regression] compare guard: Go/Rust artifacts checked (CONTRACT §6 closed, CI 硬红)")
    else:
        print("[regression] compare guard: no artifacts checked (unexpected, should be hard gate)")
    sys.exit(0)

if __name__ == "__main__":
    main()
