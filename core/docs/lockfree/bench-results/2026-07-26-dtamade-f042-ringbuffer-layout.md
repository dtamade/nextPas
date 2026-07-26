# F-042 — RingBuffer: thread-affinity layout (NULL RESULT, consistency land)

> This is NOT a performance claim. The layout change measured flat on this
> host; it lands for layout-law consistency, with the null result disclosed
> in full below.

## Change

`TRingBufferImpl` (Vyukov-style bounded MPMC ring) was the last T1 hot
structure violating the thread-affinity layout law
(cacheline-layout-rules.md §1): FSlots/FCapacity/FMask/FHead/FTail/FClosed
all adjacent (~52B → one or two lines), so every producer CAS on FHead
invalidated the line holding the consumers' CAS target FTail plus the
per-op FMask/FCapacity reads.

Fix (no algorithm change; slot protocol and all memory orders untouched):
read-mostly header (FSlots/FCapacity/FMask) + FPadHeader; producer line
FHead + FPadHead; consumer line FTail + FPadTail; cold FClosed.
Same shape as F-035 (channel) / F-039 (spsc).

Bench coverage debt paid first: ringbuffer had NO bench scenarios — added
matched/R1_Ring_1P1C, matched/R2_Ring_2P2C (producers spin on rbFull,
consumers on rbEmpty; Try* return an enum, success = rbWritten on both
sides) and micro/Ring/TryWriteReadPair, built and measured on the
baseline tree before touching the source.

Pin surface: r2_queues pins ringbuffer's Create guards only
(IsManagedType / LockFreeNextPow2 / capacity limit) — untouched;
test_lockfree lists the unit in the no-asm/RTL-isolation contract —
unaffected. No pin edits needed this round.

## Envelope

```
date_utc:  2026-07-26 (same host, same session; baseline at load
           ~10.3-13.7, after at ~13.9-15.2 (main batch) and ~12.0-13.7
           (3 extra rounds) on a 44-core box)
host:      dtamade
os:        Linux 6.12.74+deb13+1-amd64 x86_64
cpu:       Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz (logical=44)
compiler:  fpc 3.3.1 -O2
build_id:  baseline = F-041 commit ae799ac4e + new ring bench scenarios;
           after = + ringbuffer layout fix; clean rebuild both sides
workload:  bench_lockfree matched (OPS=1e6; R1=1P+1C, R2=2P+2C,
           CAP=1024 bounded) + micro
warmup:    micro MinDuration=50ms MinSamples=5; matched = whole-run wall
measured:  matched: ms per 1e6 written+read values; micro: ns per
           TryWrite+TryRead pair (single thread, uncontended)
stats:     baseline n=6; after n=9 (6 + 3 extra rounds to bound the
           window drift seen in controls); outliers disclosed below
units:     ms/1e6 ops (matched), ns/iter (micro); lower is better
command:   core/build/.../bench_lockfree all (x1); ... matched (x5+3)
```

## Numbers (same host)

| Scenario | Before (n=6, median) | After (n=9, median) | Verdict |
|----------|---------------------|---------------------|---------|
| matched/R1_Ring_1P1C (signal) | 141.1–162.1 ms, median 146.1 | 127.9–156.9 ms, median 147.1 | **FLAT** — ranges fully overlap; after min even below before min |
| matched/R2_Ring_2P2C (signal) | 181.8–207.9 ms, median 198.4 | 188.2–225.7 ms, median 213.8 | +7.8% median drift, ranges overlap — tracks the M1 control drift (+11%) in the same window, attributed to background load (after main batch ran at load 13.9–15.2 vs baseline 10.3–13.7) |
| micro/Ring/TryWriteReadPair | 76.2 ns | 76.6 ns | flat (single sample per side) |
| matched/C1_1P1C (control) | median 117.1 (107.8–136.7) | median 114.9 (104.5–131.7) | flat |
| matched/C2_2P2C (control) | median 261.5 (206.4–298.4) | median 268.5 (244.3–287.6) | +2.7%, overlap |
| matched/C1s_ChannelSpsc_1P1C (control) | median 59.3 (32.9–73.9) | median 39.2 (32.2–47.7) | -34% swing, both inside known 26.5–96.0 range (C1s is the noisiest scenario) |
| matched/M1_Mpsc_1P1C (control) | median 203.5 (178.2–219.8) | median 225.9 (173.0–243.7, n=9) | **+11% drift = the window's noise bound**; R2's +7.8% sits inside it |
| matched/M2_Mpsc_2P1C (control) | median 112.0 (105.4–116.1) | median 109.0 (102.6–118.9) | flat |
| matched/Q1_MsQueue_1P1C (control) | median 430.6 (335.9–436.4) | median 420.1 (323.8–442.0) | flat — independently re-confirms F-041's after numbers (427.7) |
| matched/Q2_MsQueue_2P2C (control) | median 473.7 (441.4–524.4) | median 474.2 (457.2–498.6) | flat |
| matched/W1_Pool_1S1T (control) | median 215.4 (189.9–249.0) | median 219.4 (201.9–231.5) | flat |
| matched/W2_Pool_2S2T (control) | median 169.9 (164.8–179.5) | median 168.0 (156.9–179.0) | flat |
| matched/J1_ForkJoin_1F1W (control) | median 359.9 (352.0–372.5) | median 353.8 (334.5–363.0) | flat |
| matched/J2_ForkJoin_2F2W (control) | median 279.7 (263.0–303.2) | median 287.8 (272.5–297.5) | +2.9%, overlap |

Attribution — why the layout law measured flat here (the useful finding):

- The dominant coherence traffic in a Vyukov bounded ring is the **slot
  array, not the control words**. TSlot(Int64 seq + Int32 value) = 16B →
  4 slots per line; at steady state (~0..1 items) producers and consumers
  chase each other through the SAME slot lines — producer writes
  Value+Sequence, consumer immediately rewrites both. That data-plane
  ping-pong is inherent to the algorithm and dwarfs the control-word
  false sharing the fix removes.
- Baseline DID show the classic defect signature (R2 198.4 > R1 146.1,
  adding threads 36% slower) — but after the fix R2/R1 is unchanged,
  so that inversion is algorithmic (2P CAS-contending on one FHead,
  2C on one FTail, 4 threads on shared slot lines), not layout.
- Slot padding (64B stride) would isolate the data plane but 4x the
  memory (CAP=1024: 16KB → 64KB) and industry rings (crossbeam
  ArrayQueue, folly MPMCQueue) do not pad slots either — the cache
  density is WHY the ring beats msqueue 3x (R1 146 vs Q1 428).
  Recorded as an algorithm-level candidate, not attempted.

Why it still lands: ringbuffer was the last T1 hot structure violating
the layout law every sibling (channel/spsc/mpsc/forkjoin/msqueue) now
follows; the change measured no regression on any axis (R1 flat with
n=9, micro flat, R2 drift inside control drift); and the padding guards
against future field additions silently re-introducing control/data
sharing. Cost: +192B per instance.

Notes:
- Matched Sink checksum identical across all matched rounds on BOTH
  sides (15000019500000 = 3x the 13-scenario delivered-value sum; the
  ring scenarios' contribution checks out exactly, zero value loss).
- The r2 inversion (R2 > R1) remains the ring's honest scaling story at
  CAP=1024 on this host; single-line control words were not the cause.

## Functional check

- `test_lockfree_ringbuffer` behavior suite + `test_lockfree_timeseries_ringbuffer`
  + `test_lockfree_spinlock_contracts` + `test_lockfree_r2_queues` (pin gate)
  + `test_lockfree` + `test_lockfree_stress` + `test_atomic` + verify-t1
  + verify-t2-smoke + hygiene + `git diff --check`: see commit gate log
  (run after the after-batch so the measured binary is the committed source).
