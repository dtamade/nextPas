#!/usr/bin/env python3
"""bench_regression gate: 10% p50 degradation assert (F-H23, G6).

v2 (2026-08-31): 环境噪声感知 — 系统负载比 (load1/nproc) > NOISE_RATIO 时
超阈值降级为 WARN 而非 REGRESSION（单线程 bench 在高负载下退化明显，
2026-08-31 实测负载 32/44=0.73 时误报 +25.5% REGRESSION，A/B 对比证伪；
负载 27/44=0.63 时 loop 亦波动 +34% → 阈值取 0.6）。
同时校验样本量充足（sample_count < 3 视为不可信，skip 标注）。
"""
import json, os, sys, glob

THRESHOLD = float(os.environ.get("THRESHOLD", "10"))
NOISE_RATIO = float(os.environ.get("NOISE_RATIO", "0.6"))
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


def system_noisy():
    """负载比 load1/nproc > NOISE_RATIO 视为噪声环境（bench 结果不可信）。"""
    try:
        la = float(open("/proc/loadavg").read().split()[0])
        nproc = os.cpu_count() or 1
        ratio = la / nproc
        return ratio > NOISE_RATIO, la, nproc, ratio
    except Exception:
        return False, 0.0, 0, 0.0


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
            stats = b.get("statistics", {})
            p50 = stats.get("median", b.get("ns_per_op"))
            sample_count = stats.get("sample_count", 0)
            if p50 is not None:
                # keep minimal per name (multiple files same name: take last)
                cur[name] = (float(p50), int(sample_count))
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
    noisy, la, nproc, ratio = system_noisy()
    if noisy:
        print(f"[bench_regression] noisy env: load1={la:.1f} nproc={nproc} "
              f"ratio={ratio:.2f} > {NOISE_RATIO} — 超阈值降级为 WARN（A/B 同负载对比证伪）")
    fail = 0
    warn = 0
    for name, (now, sample_count) in sorted(cur.items()):
        base = FROZEN.get(name)
        if base is None:
            # unknown bench: just report
            print(f"[bench_regression] {name}: p50={now:.1f} ns (no frozen baseline, skip)")
            continue
        if sample_count < 3:
            print(f"[bench_regression] {name}: p50={now:.1f} ns (sample_count={sample_count} < 3, skip)")
            continue
        pct = (now - base) / base * 100 if base else 0
        if pct <= args.threshold:
            status = "OK"
            print(f"[bench_regression] {name}: baseline {base:.1f} ns, current {now:.1f} ns, {pct:+.1f}% -> {status}")
            continue
        if noisy:
            status = "WARN (noisy env, verify manually)"
            warn += 1
        else:
            status = "REGRESSION"
            fail += 1
        print(f"[bench_regression] {name}: baseline {base:.1f} ns, current {now:.1f} ns, {pct:+.1f}% -> {status}")
    if fail:
        print(f"[bench_regression] FAILED: {fail} bench(es) degraded >{args.threshold}%")
        return 1
    if warn:
        print(f"[bench_regression] OK (warn {warn} in noisy env): all within {args.threshold}% under clean env assumption")
        return 0
    print(f"[bench_regression] OK: all within {args.threshold}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
