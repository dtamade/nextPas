#!/usr/bin/env python3
"""bench_regression gate: 10% p50 degradation assert (F-H23, G6)."""
import json, os, sys, glob

THRESHOLD = float(os.environ.get("THRESHOLD", "10"))
BENCH_ROOT = os.path.join(os.path.dirname(__file__), "..")
BUILD_GLOB = os.path.join(BENCH_ROOT, "bench_*/build/bench-agent-*.json")
# Baseline frozen median values (BENCHMARKS.md §2, 2026-08-29)
FROZEN = {
    "fold/10k-deltas-50-slots": 1.18e6,  # ns/op (1.18 ms)
    "sse-feed/16MiB-32KiB-chunks": 92.3e6,  # ns/op
    "loop/fake-provider-10-rounds": 165.8e3,  # ns/op (per run)
    "wire/responses-encode-16msg-5tools": 18.0e3,
    "wire/responses-decode-mixed-14items": 171.2e3,
    "wire/anthropic-encode-base": 34.6e3,
    "wire/anthropic-encode-ccm-auto": 34.6e3,
    "wire/validate-5-headers": 203,  # ns
}

def load_current():
    cur = {}
    for path in glob.glob(BUILD_GLOB):
        try:
            with open(path) as f:
                data = json.load(f)
        except Exception as e:
            print(f"[bench_regression] warn: cannot load {path}: {e}")
            continue
        for b in data.get("benchmarks", []):
            name = b.get("name")
            # use median as p50 approximation; fallback ns_per_op
            stats = b.get("statistics", {})
            p50 = stats.get("median", b.get("ns_per_op"))
            if p50 is not None:
                # keep minimal per name (multiple files same name: take last)
                cur[name] = float(p50)
    return cur

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--threshold", type=float, default=THRESHOLD)
    args = ap.parse_args()
    cur = load_current()
    if not cur:
        print("[bench_regression] no bench JSON found; skip (run benches first)")
        return 0
    # If frozen not matched exactly, use current as self-check: ensure no >threshold vs frozen where known
    fail = 0
    for name, now in sorted(cur.items()):
        base = FROZEN.get(name)
        if base is None:
            # unknown bench: just report
            print(f"[bench_regression] {name}: p50={now:.1f} ns (no frozen baseline, skip)")
            continue
        pct = (now - base) / base * 100 if base else 0
        status = "OK" if pct <= args.threshold else "REGRESSION"
        print(f"[bench_regression] {name}: baseline {base:.1f} ns, current {now:.1f} ns, {pct:+.1f}% -> {status}")
        if pct > args.threshold:
            fail += 1
    if fail:
        print(f"[bench_regression] FAILED: {fail} bench(es) degraded >{args.threshold}%")
        return 1
    print(f"[bench_regression] OK: all within {args.threshold}%")
    return 0

if __name__ == "__main__":
    sys.exit(main())
