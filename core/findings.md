# Findings: Pascal llhttp raw-gap diagnosis

## Scope

本轮是 H1 parser raw llhttp 性能诊断，不改变 public facade API、不改变 wire
contract、不写 `docs/nextpas.core.http.inbox.md`，也不手改 generated
`nextpas.core.http.impl.h1.llhttp.pas`。

## Fresh focused evidence

Pascal raw row:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
make -C benchmarks/nextpas.core.http/bench_h1parser clean run

raw llhttp: 10 headers (~400B) = 766.5 ns/op
```

C raw row:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='C raw llhttp: 10 headers' \
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run \
  LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp

C raw llhttp: 10 headers (~400B) = 525.0 ns/op
```

This confirms a representative Pascal raw gap of about `1.46x` on this machine.

## Flag matrix evidence

Focused single-row matrix:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' \
LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --no-perf
```

Results:

```text
pascal-default      854.9 ns/op
c-default           526.0 ns/op
pascal-coreavx2     769.7 ns/op
pascal-extra-opts   750.6 ns/op
c-native            524.5 ns/op
```

The matrix shows that CPU/FPU flags and extra FPC opts can reduce noise or win a
small amount, but they do not close the gap. The extra-opts build also emits
additional FPC warnings, so it is not a production default decision from this
single diagnostic row.

## Code structure observations

- Pascal generated llhttp has the same broad llparse shape as C: large
  goto-driven state machine, `_current` state storage, and match helpers.
- Pascal stores `_current` as `Pointer` and repeatedly converts through
  `Pointer(PtrInt(...))` / `TLlparseStateT(PtrInt(...))`; the generated file has
  215 `_current` assignments and 216 `PtrInt` occurrences.
- The generated Pascal `llhttp__internal__run` declares many local match/start
  temporaries up front, matching the C shape but giving FPC a harder register
  allocation problem than a smaller function would.
- C llhttp has conditional SIMD/range-match blocks behind `__SSE4_2__`, but the
  focused `c-native` 10-header row did not materially improve over default C on
  this input, so SIMD alone is not the immediate explanation for this row.
- The Pascal port initializes generated `llparse_blob*` arrays at unit
  initialization rather than as C `static const` data. That is unlikely to affect
  steady-state raw rows, but it is a codegen difference to keep in mind.

## Perf availability

`perf stat -e cycles -- true` fails locally:

```text
Access to performance monitoring and observability operations is limited.
perf_event_paranoid setting is 3
```

So this checkout cannot yet provide cycles/instructions/branch/cache proof for
the raw gap. The existing flag-matrix perf fallback remains the right runner,
but it needs a machine with usable perf counters.

## Current conclusion

The Pascal-translated llhttp raw gap is real enough to keep as a dedicated
optimization track. It is not yet actionable as a production code change in this
round because the available evidence does not identify one safe generated-code
fix. The next raw-gap step should be perf/codegen evidence, not hand-editing the
generated state machine.

## Subagent review

Read-only `gpt-5.5 xhigh` subagent `Fermat` reached the same conclusion:

- do not hand-edit generated `nextpas.core.http.impl.h1.llhttp.pas`;
- the most likely raw-gap causes are FPC codegen/register pressure in the giant
  dispatcher, helper calling/record-return shape, and `_current` pointer/int
  state casts;
- keep production throughput work on adapter/materialization until perf or
  codegen evidence identifies a safe generated-code fix.

## Remaining gaps / risks

- Need perf counters or compiler codegen inspection to separate branch
  prediction, instruction count, register pressure, and callback/state dispatch
  costs.
- Need a generator-level plan before changing `nextpas.core.http.impl.h1.llhttp.pas`;
  hand edits would be hard to maintain and easy to lose on regeneration.
- Adapter/materialization still has larger proven cost than the raw state
  machine gap, so production throughput work should continue there unless perf
  evidence shows a higher-value raw parser fix.
