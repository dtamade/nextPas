# nextpas.core.http Benchmarks

This page records the current HTTP server benchmark harness and one local
snapshot. Treat the numbers as evidence for this machine and toolchain, not as
a permanent ranking across platforms.

The maintained Pascal benchmark assets under `benchmarks/nextpas.core.http/`
are the focused projects with their own project `Makefile`s and focused smoke
coverage:

- `bench_server`
- `bench_router`
- `bench_headers`
- `bench_h1writer`
- `bench_h1outbound`
- `bench_fullchain`
- `bench_h1parser`

An older top-level aggregate Pascal benchmark (`bench_http`) was removed on
2026-06-06 local time. It duplicated router / URL / header microbenchmarks,
had no project `Makefile`, no stable metadata contract, and no focused gate.
The maintained benchmark truth now lives only in the focused assets above and
the Go / Rust comparator projects.

## Run the Server Comparison

Run the comparison harness:

```sh
benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/report.txt
```

Capture a Markdown snapshot with environment metadata:

```sh
benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/snapshot.md
```

The comparison currently covers four HTTP/1.1 keep-alive hello-world workloads:

- `workload=no_url`: the handler does not read the request URL or query string.
- `workload=url_path`: the client sends `GET /api/v1/users` and the handler
  reads the path before returning the same hello-world response.
- `workload=adapter_no_url`: the request stays on `/` and does not read the
  URL, but it includes `Connection: keep-alive`. This was originally used to
  force nextPas off the H1 fast path; current nextPas treats explicit
  `keep-alive` as fast-path compatible while still rejecting `close`,
  `upgrade`, and other connection-policy tokens to the llhttp path.
- `workload=response_1k`: the request stays on `/`, and the server writes a
  1 KiB fixed-length response body. The raw nextPas/Rust clients wait for the
  complete response body, not just a status/header prefix.

It does not cover TLS, request bodies, WebSocket, router/middleware full-chain
cost, or `epoll`. The default Rust comparator is a std-only microbaseline
labeled `impl=rust_std` with `rust_profile=std_only`; it is still not a Rust
ecosystem benchmark by itself.

To include the optional Cargo-based Hyper/Tokio HTTP/1.1 comparator, pass
`--include-hyper`:

```sh
benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 \
  --include-hyper \
  --output build/projects/nextpas.core.http/server_comparison/report.txt
```

The Hyper/Tokio row reports `impl=rust_hyper` and
`rust_profile=hyper_tokio`. The snapshot helper accepts the same flag and
also accepts `--workload`; it records `workload=<name>`,
`cargo_version`, `hyper_cargo_lock_sha256`, and `include_hyper=1` in the
Markdown environment block:

```sh
benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 --include-hyper \
  --output build/projects/nextpas.core.http/server_comparison/snapshot.md
```

The snapshot helper embeds the raw runner output into the Markdown file and
then removes the intermediate `${output}.raw` file. Treat the `.md` snapshot as
the durable artifact; the adjacent `.raw` file is only a temporary capture path.
Its environment block now also records `requested_threads=...` and
`effective_threads=...`, so a later thread clamp does not silently erase the
original command argument from the long-lived snapshot.

This comparator is a benchmark-truth seam, not a final Rust ecosystem ranking:
it covers a minimal Hyper HTTP/1.1 server on Tokio with the same raw keep-alive
client workload shape as the std-only comparator.

Use `--runs N` to repeat each implementation after a single build and emit a
median summary at the end of the raw output. This is the preferred mode for
fresh local comparison rows because single-shot server results are visibly
affected by scheduler noise.

The comparison runner also serializes concurrent invocations through a shared
build-root lock under
`build/projects/nextpas.core.http/server_comparison/.comparison-lock`. This is
not a benchmark row feature; it is a harness-truth guard so a saved report and
an overlapping snapshot do not race while rebuilding the shared Go/Rust
comparator binaries into the same output directory.

The runner treats incomplete workload execution as a harness failure: every raw
row must report `iterations=<requests>` and `completed=<requests>`. The median
summary repeats this guard as `median_completed=<requests>`, nextPas rows print
`nextpas_h1_path=fast` for current no-body HTTP/1.1 workloads, and Rust
std-only / Hyper rows print `rust_profile=std_only` /
`rust_profile=hyper_tokio` so fast-path and comparator interpretation stay
explicit. The raw comparison header also prints `include_hyper=0|1`, so saved
reports do not need to infer whether the optional Hyper/Tokio comparator was
requested from later sections.

All single-implementation comparator binaries use the same workload allow-list
as the runner. An explicit invalid `--workload` exits non-zero with an
`invalid --workload` diagnostic instead of silently falling back to `no_url`.
`test_http_benchmarks` locks this for nextPas `bench_server`, Go `net/http`,
Rust std-only, and Hyper/Tokio comparator binaries.

The same focused gate also locks positive scale validation on the single
implementation binaries: explicit `--requests 0` or `--threads 0` now exits
non-zero with an `invalid --requests` / `invalid --threads` diagnostic instead
of silently clamping or falling back to a default run size. This keeps typoed
manual comparator runs from emitting misleading benchmark rows.

The nextPas `bench_server` binary now also emits `backend=<threaded|epoll>` on
its raw benchmark rows and accepts an explicit `--backend` selector:

```sh
build/projects/nextpas.core.http/bench_server/bench_http_server \
  --requests 128 --threads 1 --workload no_url --backend threaded

build/projects/nextpas.core.http/bench_server/bench_http_server \
  --requests 128 --threads 1 --workload no_url --backend epoll
```

This is a nextPas-only runtime characterization seam, not a cross-language
comparison flag. The server comparison runner and snapshot helper now accept
`--nextpas-backend threaded|epoll`, record `nextpas_backend=<...>` in the raw
header / snapshot environment block, and pass the selected backend only to the
nextPas row:

```sh
benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 \
  --nextpas-backend threaded

benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh \
  --requests 20000 --threads 4 --workload no_url --runs 3 \
  --nextpas-backend epoll \
  --output build/projects/nextpas.core.http/server_comparison/snapshot-epoll.md
```

The default remains `threaded`, so existing Go/Rust/nextPas comparison commands
keep the earlier apples-to-apples shape unless a caller explicitly asks for a
nextPas-only backend characterization run.

Fresh local backend smoke rows from 2026-06-07:

| impl    | backend  | workload | iterations | completed | ns/op | req/s |
| ------- | -------- | -------- | ---------: | --------: | ----: | ----: |
| nextPas | threaded | no_url   |        128 |       128 | 41890 | 23871 |
| nextPas | epoll    | no_url   |        128 |       128 | 91425 | 10937 |

Treat these as local backend smoke, not a stable threaded-vs-epoll ranking.
The durable conclusion is that benchmark artifacts can now distinguish backend
selection explicitly and can run a nextPas-only epoll row without patching the
comparison runner. The raw comparison report and Markdown snapshot now preserve
the same truth as `nextpas_backend=<threaded|epoll>`.

`bench_fullchain` now follows the same fail-fast benchmark-truth rule for its
filter path: when `NEXTPAS_BENCH_FILTER` matches no scenario, the benchmark
prints `No matching full-chain scenarios.` and exits non-zero instead of
silently succeeding with zero measured rows. This keeps typoed full-chain smoke
runs from looking like valid benchmark evidence.

## Local Median Snapshot: 2026-06-05

These rows were captured on the same host with:

```sh
benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 --workload <workload> --runs 3
```

Each cell is the script's median summary across three runs.

| workload       | nextPas ns/op | nextPas req/s | Rust std-only ns/op | Rust std-only req/s | Go `net/http` ns/op | Go `net/http` req/s |
| -------------- | ------------: | ------------: | ------------------: | ------------------: | ------------------: | ------------------: |
| no_url         |         10405 |         96098 |                9051 |              110479 |               47688 |               20969 |
| adapter_no_url |         12280 |         81433 |                8140 |              122845 |               48857 |               20467 |
| url_path       |         10133 |         98685 |                7391 |              135291 |               47782 |               20928 |
| response_1k    |          9896 |        101044 |                9408 |              106285 |               50560 |               19778 |

Interpretation for this host:

- `response_1k` is close to Rust std-only: nextPas is about 5% slower by
  median `ns/op`.
- `no_url` is about 15% slower than Rust std-only while staying far ahead of
  Go `net/http`.
- `url_path` is about 37% slower than Rust std-only and points at request URL
  materialization / path access costs.
- `adapter_no_url` was about 51% slower than Rust std-only in this snapshot,
  but that row is not apples-to-apples across implementations: Rust std-only
  has no equivalent fast/adapter split and simply ignores the extra
  `Connection` header. Treat this row primarily as a nextPas internal
  fast-gate differential.

This still does not represent async Rust such as Hyper/Tokio. Treat it as a
std-only comparator snapshot and a workload-routing guide for the next
optimization batch.

## Optimization Evidence: H1 Fast Path Explicit Keep-Alive

On 2026-06-05 local time, H1 server ingress stopped treating explicit
`Connection: keep-alive` on HTTP/1.1 no-body requests as an automatic llhttp
fallback. The fast path still rejects `Connection: close`, `Connection:
upgrade`, unsupported connection-policy tokens, `Expect`, `Transfer-Encoding`,
missing `Host`, and non-zero request bodies.

Focused RED before adding narrowed rows:

```text
NEXTPAS_BENCH_MAX_ITERS=2000 NEXTPAS_BENCH_FILTER='adapter no-url' \
make -C benchmarks/nextpas.core.http/bench_h1parser clean run

bench_filter=adapter no-url
summary contained no matching adapter no-url rows
```

Narrowed breakdown after adding the rows and the fast-gate change:

| row                                  | iterations |  ns/op |   ops/s |
| ------------------------------------ | ---------: | -----: | ------: |
| adapter no-url: metadata 3 headers   |       2000 |  372.2 | 2686504 |
| adapter no-url: fast reject + llhttp |       2000 | 2084.3 |  479786 |
| adapter no-url: llhttp direct only   |       2000 | 1494.0 |  669348 |
| adapter no-url: fast parse only      |       2000 |  629.3 | 1589120 |

Focused verification:

```text
make -C tests/nextpas.core.http/test_http_h1fast clean test
22 total, 22 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh same-host comparison rows after the change:

| workload       | nextPas median ns/op | nextPas median req/s | Rust std-only median ns/op | Go `net/http` median ns/op |
| -------------- | -------------------: | -------------------: | -------------------------: | -------------------------: |
| adapter_no_url |                11022 |                90720 |                       8843 |                      53076 |
| no_url         |                10948 |                91335 |                       8935 |                      49245 |

The `adapter_no_url` row improved from the earlier same-day `12280 ns/op` to
`11022 ns/op`, but the `no_url` row also showed scheduler noise. Do not treat
this as a permanent cross-language ranking; the durable conclusion is that
explicit HTTP/1.1 `Connection: keep-alive` no longer pays the old
fast-parse-then-llhttp double parse cost.

Later on 2026-06-05, the small H1 server policy helpers
`ShouldKeepAlive`, `ParserErrorStatus`, and `ShouldSendContinueResponse` were
marked as `inline`. These helpers sit on the keep-alive, parser-error, and
`Expect: 100-continue` decision paths; the large header-policy evaluator and
state-machine methods were deliberately left non-inline.

Focused RED before the production change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

28 total, 27 passed, 1 failed
failure: H1 server ShouldKeepAlive inline implementation missing
heaptrc: 0 unfreed memory blocks
```

Focused verification after the change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
28 total, 28 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Small nextPas-only smoke row:

```text
command=build/projects/nextpas.core.http/bench_server/bench_http_server --requests 128 --threads 1 --workload adapter_no_url
completed=128
ns/op=42022
req/s=23797
```

This smoke row proves the benchmark path still completes after the inline
slice. It is intentionally not a durable performance ranking.

## Optimization Evidence: H1 Fast Lazy Header Lookup

On 2026-06-06 local time, `TFastLazyHeaders.Get`, `Has`, `Count`, and `GetAll`
stopped forcing full header-block materialization. The fast path now scans the
raw request header block for first-value lookup, count-only access, and
same-name multi-value lookup; `ForEach`, `Clone`, and mutation methods still
materialize the full `THttpHeaders` store to preserve duplicate-order and
mutation semantics.

The same focused slice also fixed an empty-header-value fast validation bug:
`IsValidHeaderValueFast` now accepts `ALen = 0` instead of underflowing the
unsigned loop bound and falling back from the fast parser.

Focused verification:

```text
make -C tests/nextpas.core.http/test_http_h1fast clean test
23 total, 23 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
50 total, 50 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Small H1 parser benchmark rows:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='fast headers' \
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| row                                       | iterations |  ns/op |  ops/s |
| ----------------------------------------- | ---------: | -----: | -----: |
| adapter cost: fast headers get host only  |     100000 | 1565.5 | 638773 |
| adapter cost: fast headers count all      |     100000 | 1783.0 | 560854 |
| adapter cost: fast headers has accept     |     100000 | 1541.3 | 648818 |
| adapter cost: fast headers get all accept |     100000 | 2392.2 | 418020 |
| adapter cost: fast headers foreach all    |     100000 | 4033.6 | 247915 |

This is a nextPas internal materialization-cost split, not a cross-language
server ranking. It shows the single-header lookup, count-only path, and
same-name `GetAll` path no longer pay the same full materialization cost as
whole-header access. The `count all` row isolates raw header-line counting,
`has accept` isolates raw presence lookup without constructing a temporary
header value string, `get all accept` isolates raw multi-value lookup for one
header name, and `foreach all` still measures materialization plus iteration
callback overhead.

On 2026-06-06 local time, `TFastLazyHeaders.EnsureMaterialized` stopped
re-entering the public `IHttpHeaders.Add` validation / copy path and now inserts
the parser-trusted raw header spans into the concrete store. On this same host,
that reduced the `count all` row from `4617.2 ns/op` to `3823.4 ns/op` and the
`foreach all` row from `4695.8 ns/op` to `3873.9 ns/op`; `get host only`
remained an intentionally separate raw lookup row.

The follow-up count-only slice added a raw header-count helper for
`TFastLazyHeaders.Count`. On the same benchmark shape, `count all` dropped
again from `3823.4 ns/op` to `1740.7 ns/op`; `foreach all` remains the
materialization row.

The next same-name lookup slice added `TFastLazyHeaders.GetAllRawValues` and a
dedicated `get all accept` benchmark row. On this host that row reports
`2601.8 ns/op`, below the full `foreach all` materialization row at
`3893.2 ns/op`.

The follow-up presence-only slice added `TFastLazyHeaders.HasRawHeader` and
moved `TFastLazyHeaders.Has` off `FindRawFirstValue`. On the same benchmark
shape, `has accept` reports `1541.3 ns/op`, which keeps `Has` closer to the
single-header lookup path than to the value-materializing `GetAll` /
materializing `ForEach` rows.

## Run the Router Dispatch Benchmark

Run the focused router dispatch row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='handler dispatch' \
make -C benchmarks/nextpas.core.http/bench_router clean run
```

Run the direct no-router baseline row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='direct call' \
make -C benchmarks/nextpas.core.http/bench_router clean run
```

These rows report `operation=http.router.dispatch`:

- `handler dispatch (match + no-op handler)` measures
  `THttpRouter.ServeHTTP` for a static route plus a no-op handler. It reuses
  one request object and does not include socket I/O, H1 parsing, response
  serialization, middleware, or URL/query materialization.
- `direct call (same request, no router)` measures the same reused request
  object and the same no-op handler shape without router lookup or dispatch.
  The gap between the two rows is the narrowest current benchmark for router
  dispatch on this hot path.

The filter is still substring-based, so the row names intentionally stay
disjoint: `NEXTPAS_BENCH_FILTER='handler dispatch'` must not accidentally run
the direct baseline, and `NEXTPAS_BENCH_FILTER='direct call'` must not
accidentally run the routed row.

Local focused rows from 2026-06-07:

| workload                                 | iterations | ns/op |     ops/s |
| ---------------------------------------- | ---------: | ----: | --------: |
| direct call (same request, no router)    |     100000 |   3.8 | 261107514 |
| handler dispatch (match + no-op handler) |     100000 | 264.5 |   3781347 |

Treat these as local directional rows, not a permanent microbenchmark ranking.
The durable conclusion is that router dispatch can now be isolated against a
same-request/same-handler direct baseline, and that the remaining short-GET
full-chain cost still lives primarily outside this narrow dispatch slice.

## Run the Header Container Benchmark

Run the focused header lookup row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='Get hit' \
make -C benchmarks/nextpas.core.http/bench_headers clean run
```

This emits `operation=http.headers` and reports both lowercase and uppercase
lookup rows. Use it to isolate `THttpHeaders.Get` lookup cost without H1
parsing, router dispatch, response serialization, or socket I/O.

## Run the H1 Writer Serialization Benchmark

Run the focused header-only row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='headers only 200' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run
```

Run the focused multi-header block row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='headers block 200 6 headers' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run
```

Run the focused common error status-line row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='status lines common errors' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run
```

Run the focused response serialization row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='fixed 200 13B' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run
```

Run the focused writer-plus-outbound row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='outbound fixed 200 1KB' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run
```

These rows report `operation=http.h1writer.serialize`.

- `headers only 200` measures `TH1ResponseWriter` construction, two header
  mutations, fixed `200 OK` response header serialization, and `Flush`, with
  `Content-Length: 0` and no body write.
- `headers block 200 6 headers` measures the same header-only path with six
  representative response headers, so the row is more sensitive to header block
  serialization and write-call coalescing.
- `status lines common errors` cycles through common server error statuses
  (`400`, `404`, `413`, `417`, `431`, `500`, `501`) with `Content-Length: 0`
  to measure status-line serialization without request parsing or socket I/O.
- `fixed 200 13B` measures the same setup plus a 13-byte body write into a
  fixed in-memory writer.
- `outbound fixed 200 1KB` measures `TH1ResponseWriter` writing a fixed 1 KiB
  body into `IH1OutboundBuffer`, followed by `DrainAllTo` into a fixed
  in-memory writer. This isolates the response writer plus outbound-drain
  combination used by the server response path, without adding real socket I/O
  or scheduler noise.

Neither row includes request parsing, router dispatch, middleware, socket
drain, or backpressure.

Local focused row from 2026-06-05:

| workload         | iterations |  ns/op |  ops/s |
| ---------------- | ---------: | -----: | -----: |
| headers only 200 |     100000 | 1247.1 | 801852 |
| fixed 200 13B    |     100000 | 1250.5 | 799680 |

Local focused rows from 2026-06-06 after compact header-block writes:

| workload                    | iterations |  ns/op |  ops/s |
| --------------------------- | ---------: | -----: | -----: |
| headers only 200            |     100000 | 1280.4 | 781028 |
| headers block 200 6 headers |     100000 | 1890.9 | 528835 |

Local focused row from 2026-06-06 after known status-line fast paths:

| workload                   | iterations |  ns/op |  ops/s |
| -------------------------- | ---------: | -----: | -----: |
| status lines common errors |     100000 | 1204.8 | 830013 |

Local focused row from 2026-06-07 for writer plus outbound drain:

| workload               | iterations |  ns/op |  ops/s |
| ---------------------- | ---------: | -----: | -----: |
| outbound fixed 200 1KB |     100000 | 1892.3 | 528470 |

## Run the H1 Outbound Drain Benchmark

Run the focused outbound buffer row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='buffer write+drain 1KB' \
make -C benchmarks/nextpas.core.http/bench_h1outbound clean run
```

This row reports `operation=http.h1outbound.drain` and measures
`NewH1OutboundBuffer`, a 1 KiB buffer write, and `DrainAllTo` into a fixed
in-memory writer. It does not include response writer serialization, real
socket I/O, readiness wakeups, write deadlines, or backpressure.

Local focused row from 2026-06-05:

| workload               | iterations | ns/op |   ops/s |
| ---------------------- | ---------: | ----: | ------: |
| buffer write+drain 1KB |     100000 | 303.0 | 3300665 |

Later on 2026-06-05, `TH1OutboundBuffer.PendingBytes`, `IsEmpty`, and
`Advance` were marked as hot helper `inline` methods, with the implementations
ordered before hot callers to avoid FPC "marked as inline is not inlined" notes
in the focused benchmark build. `test_http_benchmarks` now has a source-contract
smoke that locks this shape.

Fresh single-run local row after that slice:

| workload               | iterations | ns/op |   ops/s |
| ---------------------- | ---------: | ----: | ------: |
| buffer write+drain 1KB |     100000 | 283.1 | 3532176 |

On 2026-06-07 local time, the same focused benchmark gained a narrower
runtime-facing drain row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100 \
NEXTPAS_BENCH_FILTER='buffer trydrain runtime 1KB chunk128' \
make -C benchmarks/nextpas.core.http/bench_h1outbound clean run
```

This row keeps the same 1 KiB payload but replaces the generic `IWriter` sink
with a fake `ITcpStreamRuntime` that accepts at most `128` bytes per
`TryWrite`. It therefore isolates repeated
`IH1OutboundBuffer.TryDrainTo(runtime)` loop cost without mixing in real
socket/backend/scheduler noise.

Small focused row from the same host:

| workload                             | iterations | ns/op |   ops/s |
| ------------------------------------ | ---------: | ----: | ------: |
| buffer trydrain runtime 1KB chunk128 |        100 | 393.5 | 2541231 |

Treat the pair as an internal split:

- `buffer write+drain 1KB` isolates drain-to-generic-writer cost
- `buffer trydrain runtime 1KB chunk128` isolates partial runtime drain cost

This row is directional only; keep using repeated or narrowed rows before
claiming a durable cross-run performance delta.

## Optimization Evidence: H1 Server Direct Outbound Response Path

On 2026-06-06 local time, H1 server response construction stopped wrapping the
per-request `IH1OutboundBuffer` in the generic `TBufferedWriter`. The response
writer now writes directly into the outbound buffer, and the server drains that
same buffer to the socket or poll runtime.

This removes one extra object, one extra in-memory buffer layer, and the
matching `IFlusher` probe from the threaded and poll-driven response paths. The
client request writer still uses `CreateBufferedWriter` because that path writes
directly to a transport stream instead of to the H1 outbound drain buffer.

Focused RED before the production change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

30 total, 29 passed, 1 failed
failure: H1 server response path should write directly into IH1OutboundBuffer
heaptrc: 0 unfreed memory blocks
```

Focused verification after the change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
30 total, 30 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Small local smoke rows:

```text
command=NEXTPAS_BENCH_MAX_ITERS=5000 NEXTPAS_BENCH_FILTER=plaintext make -C benchmarks/nextpas.core.http/bench_fullchain clean run
completed=5000
ns/op=38134.9
req/s=26223

command=build/projects/nextpas.core.http/bench_server/bench_http_server --requests 512 --threads 1 --workload response_1k
completed=512
ns/op=35310
req/s=28319
```

These rows prove the direct outbound response path runs through the focused
benchmark harness. They are intentionally not a durable cross-run ranking.

## Run the Full-Chain Keep-Alive Benchmark

Run a filtered full-chain row:

```sh
NEXTPAS_BENCH_MAX_ITERS=1000 \
NEXTPAS_BENCH_FILTER=plaintext \
make -C benchmarks/nextpas.core.http/bench_fullchain clean run
```

Run the same nextPas-only full-chain row on a specific backend:

```sh
NEXTPAS_BENCH_MAX_ITERS=128 \
NEXTPAS_BENCH_FILTER=direct_root \
NEXTPAS_BENCH_BACKEND=threaded \
make -C benchmarks/nextpas.core.http/bench_fullchain clean run

NEXTPAS_BENCH_MAX_ITERS=128 \
NEXTPAS_BENCH_FILTER=direct_root \
NEXTPAS_BENCH_BACKEND=epoll \
make -C benchmarks/nextpas.core.http/bench_fullchain clean run
```

This benchmark starts a real `THttpServer`, opens one keep-alive TCP
connection, sends requests, reads complete responses, and reports stable
markers:

- `operation=http.fullchain.keepalive`
- `workload=<direct_root|direct_1k|plaintext|json|echo_1k|sink_16k|param_route>`
- `request_body_bytes=<0|1024|16384|...>`
- `response_body_bytes=<13|1024|...>`
- `backend=<threaded|epoll>`
- `nextpas_h1_path=<fast|llhttp>`
- `iterations`
- `completed`
- `elapsed_ns`
- `ns/op`
- `req/s`
- `client_read_mode=buffered`

The narrowest full-chain workloads now split router dispatch and response size
from the rest of the keep-alive server path:

- `direct_root` keeps the same `GET /` fixed-response shape but intercepts it
  in an outer handler before router dispatch.
- `direct_1k` keeps the same direct outer-handler path but switches to
  `GET /1k` and a fixed 1 KiB body, so it can isolate large-response
  runtime/socket cost without reintroducing router dispatch.
- `plaintext` still sends `GET /` through the router path.

Each full-chain row now also reports `response_body_bytes=...`, so saved
single-connection artifacts do not need to infer whether a row was the tiny
hello-world shape, the direct 1 KiB shape, or another fixed-body workload from
the workload name alone.

Each full-chain row now also reports `request_body_bytes=...`, so saved
artifacts do not need to infer whether a row was a no-body GET, a 1 KiB echo,
or a request-heavy sink workload from the workload name alone. Current no-body
GET rows report `request_body_bytes=0`, `echo_1k` reports
`request_body_bytes=1024`, and `sink_16k` reports `request_body_bytes=16384`.

Full-chain rows now also report `nextpas_h1_path=...` for the current nextPas
ingress choice:

- `direct_root`, `direct_1k`, `plaintext`, `json`, and `param_route` are
  current no-body HTTP/1.1 GET requests and report `nextpas_h1_path=fast`.
- `echo_1k` and `sink_16k` are body-bearing requests and report
  `nextpas_h1_path=llhttp`.

The filter is still substring-based, so the direct workload is intentionally
named `direct_root` rather than `direct_plaintext`; this keeps
`NEXTPAS_BENCH_FILTER=plaintext` unambiguous.

`NEXTPAS_BENCH_BACKEND` defaults to `threaded`. When set, it must currently be
`threaded` or `epoll`; invalid values fail fast before the benchmark emits a
benchmark row. This is a nextPas-only runtime characterization seam, not a
cross-language comparison flag.

Local focused row from 2026-06-05:

| workload  | iterations | completed | elapsed_ns |   ns/op | req/s |
| --------- | ---------: | --------: | ---------: | ------: | ----: |
| plaintext |       1000 |      1000 |   42132376 | 42132.4 | 23735 |

The clean build for this row emitted two existing FPC `Note:` lines from
`nextpas.core.text.format` and the translated llhttp inline call. It emitted no
FPC `Warning:` lines.

Fresh local smoke rows from 2026-06-07:

| workload    | iterations | completed | elapsed_ns |   ns/op | req/s |
| ----------- | ---------: | --------: | ---------: | ------: | ----: |
| direct_root |       1000 |      1000 |   37200928 | 37200.9 | 26881 |
| plaintext   |       1000 |      1000 |   33733646 | 33733.6 | 29644 |

Treat these as single-run harness proof, not stable ranking evidence. The
durable conclusion is that `bench_fullchain` can now isolate a no-router
direct-handler path from the router path without reintroducing filter
ambiguity.

Fresh local backend smoke rows from 2026-06-07 for `direct_root`:

| backend  | workload    | iterations | completed | elapsed_ns |   ns/op | req/s |
| -------- | ----------- | ---------: | --------: | ---------: | ------: | ----: |
| threaded | direct_root |        128 |       128 |    4103527 | 32058.8 | 31193 |
| epoll    | direct_root |        128 |       128 |   11884206 | 92845.4 | 10771 |

Treat these as local backend smoke, not a stable threaded-vs-epoll ranking.
The durable conclusion is that `bench_fullchain` now records backend selection
explicitly and can characterize single-connection direct-handler runtime cost
on either backend without patching the server comparison runner.

Fresh local backend smoke rows from 2026-06-07 for `direct_1k`:

| backend  | workload  | iterations | completed | elapsed_ns |   ns/op | req/s |
| -------- | --------- | ---------: | --------: | ---------: | ------: | ----: |
| threaded | direct_1k |        128 |       128 |    4733204 | 36978.2 | 27043 |
| epoll    | direct_1k |        128 |       128 |    9643804 | 75342.2 | 13273 |

Treat these as local backend smoke, not a stable threaded-vs-epoll ranking.
The durable conclusion is narrower: `bench_fullchain` now has a real-socket,
single-connection, no-router 1 KiB response row that sits between the
in-memory writer/outbound benches and the broader `bench_server response_1k`
throughput workload.

Fresh local threaded smoke row from 2026-06-07 for the body-bearing llhttp
path:

| workload | request_body_bytes | response_body_bytes | nextpas_h1_path | iterations | completed | elapsed_ns |   ns/op | req/s |
| -------- | -----------------: | ------------------: | --------------- | ---------: | --------: | ---------: | ------: | ----: |
| echo_1k  |               1024 |                1024 | llhttp          |        128 |       128 |    5060196 | 39532.8 | 25295 |
| sink_16k |              16384 |                   0 | llhttp          |        128 |       128 |    6560641 | 51255.0 | 19510 |

Treat this as local harness proof, not a stable performance ranking. The
durable conclusion is that `bench_fullchain` now exposes both the fast-vs-llhttp
ingress split and the request/response body sizes directly on saved nextPas
rows instead of leaving either dimension implicit in workload names.
The focused benchmark gate now locks both body-bearing llhttp shapes:
`echo_1k` for symmetric request/response bodies, and `sink_16k` for the
request-heavy / empty-response path.
The same gate now also locks `epoll + echo_1k`, so epoll backend evidence no
longer depends only on the earlier `direct_root` fast-path row.
The focused gate also locks `param_route`, which keeps the full-chain URL path
plus route-parameter extraction seam under regression coverage.
It now also locks `epoll + sink_16k`, so epoll evidence covers a request-heavy
llhttp row instead of stopping at either the fast-path row or the symmetric
`echo_1k` body-bearing case.

## Optimization Evidence: Full-Chain Benchmark Buffered Client Read

On 2026-06-05 local time, `bench_fullchain` stopped reading the response header
one byte at a time. Its client-side response reader now reads available chunks,
finds the header boundary in the accumulated buffer, and then waits for the
declared `Content-Length` body bytes. The benchmark prints
`client_read_mode=buffered` so smoke tests can lock this harness behavior.

Focused RED before the harness change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
26 total, 25 passed, 1 failed
bench_fullchain plaintext smoke - fullchain client read mode marker missing
heaptrc: 0 unfreed memory blocks
```

Focused verification after the harness change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh same-host filtered row:

| workload  | before ns/op | after ns/op |
| --------- | -----------: | ----------: |
| plaintext |     112063.8 |     42132.4 |

This is a benchmark harness correction, not a production server code change.
The row still measures single-connection synchronous ping-pong and should not
be compared directly with the multi-client server comparison rows.

## Local Snapshot: 2026-06-04 UTC

Environment:

```text
captured_at=2026-06-04T21:50:49Z
git_head=f62d2a28dae20ab403a9f75bd2af8e7fa2d6aff7
git_status=## main...origin/main [ahead 166]
os=Linux dtamade 6.12.74+deb13+1-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.74-2 (2026-03-08) x86_64 GNU/Linux
fpc_version=3.3.1
go_version=go version go1.23.5 linux/amd64
rustc_version=rustc 1.94.0 (4a4ef493e 2026-03-02)
requests=20000
threads=4
```

Results:

| impl          | completed | elapsed_ns | ns/op |  req/s |
| ------------- | --------: | ---------: | ----: | -----: |
| nextPas       |     20000 |  247938762 | 12396 |  80665 |
| Go `net/http` |     20000 |  981937616 | 49096 |  20367 |
| Rust std-only |     20000 |  197099848 |  9854 | 101471 |

The snapshot build had no FPC `Warning:` or `Note:` lines in the captured raw
output. Re-run the command above after runtime, compiler, or OS changes before
drawing conclusions.

## Optimization Evidence: H1 Writer 200 OK Status Line

On 2026-06-05 local time, `TH1ResponseWriter.WriteStatusLine` gained a narrow
fast path for the common `HTTP_STATUS_OK` case. It writes the fixed
`HTTP/1.1 200 OK\r\n` status line in one write call and leaves all other
statuses on the existing generic path.

Focused verification:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test
29 total, 29 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh same-host filtered rows:

| workload         | before ns/op | after ns/op |
| ---------------- | -----------: | ----------: |
| headers only 200 |       1414.6 |      1284.0 |
| fixed 200 13B    |       1389.1 |      1261.1 |

The clean `bench_h1writer` build for the `headers only 200` row emitted no FPC
`Warning:` or `Note:` lines. This optimization deliberately does not change
header order, header normalization, chunked defaults, no-body statuses, `HEAD`
suppression, or non-200 status-line serialization.

## Optimization Evidence: H1 Writer Header Line Coalescing

On 2026-06-05 local time, `TH1ResponseWriter.WriteAllHeaders` gained a narrow
header-line coalescing path. Common header lines are materialized into a
512-byte stack buffer and sent through one write-all invocation per header line;
long header lines fall back to a heap string with the same wire bytes. A
full-progress writer sees one `IWriter.Write` call per header line, while
short writers still use the existing retry loop.

Focused RED before the production change:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test
30 total, 29 passed, 1 failed
Header lines use a single writer call each: expected 4, got 10
heaptrc: 0 unfreed memory blocks
```

Focused verification after the stack-buffer implementation:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test
30 total, 30 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh same-host filtered rows compared with the previous committed
`HTTP_STATUS_OK` status-line fast path:

| workload         | before ns/op | after ns/op |
| ---------------- | -----------: | ----------: |
| headers only 200 |       1284.0 |      1247.1 |
| fixed 200 13B    |       1261.1 |      1250.5 |

A simpler string-concatenation implementation was measured and rejected because
it reduced write calls but regressed these rows. The kept implementation
preserves header order, lowercase normalization, repeated-header iteration,
short-writer retry behavior, no-body statuses, `HEAD` suppression, and chunked
defaults.

## Optimization Evidence: H1 Writer Header Block Coalescing

On 2026-06-06 local time, `TH1ResponseWriter` gained a compact header-block
path for small response header sections. `WriteHeaderBlock` first tries to
serialize all header lines plus the final blank line into a 2048-byte stack
buffer and write that block through `WriteAllOrRaise`; oversized blocks fall
back to the previous per-line serialization before any compact bytes are
written.

Focused RED before the production change:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test
30 total, 29 passed, 1 failed
Small header block uses a single writer call: expected 2, got 4
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
34 total, 32 passed, 2 failed
missing headers block benchmark row and compact helper source-contract
heaptrc: 0 unfreed memory blocks
```

Focused verification after the compact block implementation:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test
31 total, 31 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
34 total, 34 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh same-host filtered rows:

| workload                    |  ns/op |  ops/s |
| --------------------------- | -----: | -----: |
| headers only 200            | 1280.4 | 781028 |
| headers block 200 6 headers | 1890.9 | 528835 |

This slice keeps the status line separate, preserves exact wire bytes for
short-writer and large-header fallback paths, and keeps `100/103` informational
headers on the same non-committing response path.

## Optimization Evidence: H1 Writer Known Status Lines

On 2026-06-06 local time, `TH1ResponseWriter.WriteStatusLine` gained fixed
status-line fast paths for common response statuses, including server error
paths used by malformed request handling (`400`, `413`, `417`, `431`, `500`,
`501`) and common application/router statuses such as `404`. Unknown status
codes still fall back to numeric formatting plus `HttpStatusText`.

Focused RED before the production change:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test
32 total, 31 passed, 1 failed
Common status lines use a single writer call: expected 2, got 6
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
35 total, 33 passed, 2 failed
missing status lines common errors row and known status-line source-contract
heaptrc: 0 unfreed memory blocks
```

Focused verification after the fixed status-line implementation:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test
34 total, 34 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
35 total, 35 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh same-host filtered row:

| workload                   |  ns/op |  ops/s |
| -------------------------- | -----: | -----: |
| status lines common errors | 1204.8 | 830013 |

The focused writer tests also lock the unknown-status fallback (`599 Unknown`)
and the short-writer retry behavior for a fixed `431` status-line.

## Optimization Evidence: H1 Ingress Fast Path

On 2026-06-05 local time, H1 server ingress gained a conservative fast path for
complete HTTP/1.1 no-body requests with a `Host` header and no
`Connection` / `Expect` / `Transfer-Encoding` policy headers. Other requests
fall back to the llhttp adapter.

Parser microbenchmark:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
llhttp simple GET ns/op=1111.4
fast simple GET ns/op=691.3
llhttp pipeline 10 reqs ns/op=9810.0
fast pipeline 10 reqs ns/op=6973.5
```

Server comparison after the fast path:

```text
command=benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4
```

| impl          | completed | elapsed_ns | ns/op | req/s |
| ------------- | --------: | ---------: | ----: | ----: |
| nextPas       |     50000 |  619882610 | 12397 | 80660 |
| Go `net/http` |     50000 | 2685471938 | 53709 | 18618 |
| Rust std-only |     50000 |  503399527 | 10067 | 99324 |

The same local 50k/4 comparison before the fast path measured nextPas at
`14736 ns/op` / `67857 req/s`, so this slice narrows the gap to the Rust
std-only comparator without changing public HTTP APIs.

## Optimization Evidence: Fast Parser Content-Length Cache

On 2026-06-05 local time, `FastParseRequest` stopped doing a second
`Headers.Get('Content-Length')` lookup after it had already identified the
`Content-Length` header during its header scan. The value is now parsed from
the original header value span and cached for the later `Consumed` calculation.

This keeps the public parser result unchanged:

- duplicate `Content-Length` still falls back to llhttp/server validation
- invalid `Content-Length` still falls back
- incomplete body still falls back
- valid body offsets and `IHttpHeaders` behavior remain unchanged

Parser microbenchmark:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| fast workload    | before ns/op | after ns/op |
| ---------------- | -----------: | ----------: |
| simple GET       |        856.4 |       754.9 |
| 10 headers       |       3679.0 |      3429.8 |
| POST 1KB body    |       1500.2 |      1374.2 |
| pipeline 10 reqs |       8685.5 |      7581.2 |

The same batch also tested a server-side disable-fast-path experiment and
rejected it: disabling the server fast path reduced the local `bench_server`
row from `86066 req/s` to `82888 req/s`. Later server rows were noisy
(`74197` then `85182 req/s`), so this batch records only the parser microbench
win and does not claim a stable server throughput improvement.

`test_http_h1fast` now includes invalid `Content-Length` fallback coverage.
`test_http_h1fast` and `test_http_server` both passed with heaptrc reporting
`0 unfreed memory blocks`.

## Optimization Evidence: Fast Parser Policy Flags

On 2026-06-05 local time, `TFastParseResult` gained scan-time policy flags for
the headers that decide whether the parsed request can enter the H1 server fast
path:

- `HasHost`
- `HasConnection`
- `HasExpect`
- `HasTransferEncoding`

`TryUseFastRequestParser` now uses those flags instead of doing four post-parse
`IHttpHeaders.Get(...)` lookups for `host`, `connection`, `expect`, and
`transfer-encoding`. This keeps the same narrow server fast-path policy:
HTTP/1.1, no body, non-empty `Host`, and no `Connection` / `Expect` /
`Transfer-Encoding` policy headers.

Focused verification:

```text
make -C tests/nextpas.core.http/test_http_h1fast clean test
20 total, 20 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
274 total, 274 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Benchmark sanity:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
fast simple GET ns/op=757.2
fast 10 headers ns/op=3554.1
fast POST 1KB ns/op=1394.2
fast pipeline 10 reqs ns/op=7821.6
```

Server keep-alive samples from this batch were `96699 req/s` and then
`86312 req/s` on an immediate second run. Treat these as noisy sanity rows, not
a stable full-chain throughput claim. The stable conclusion is narrower: the
server fast-path admission check now avoids repeated header lookups and remains
covered by focused parser/server gates.

## Optimization Evidence: Fast Parser Lazy Headers

On 2026-06-05 local time, `FastParseRequest` stopped eagerly materializing a
full `THttpHeaders` container on successful fast-path parses. It now validates
header name/value spans during the fast scan, caches the raw header block, and
returns an internal lazy `IHttpHeaders` implementation that materializes only
when code actually calls `Headers.Get` / `GetAll` / `ForEach` / mutation APIs.

The H1 server snapshot path also uses scan-time facts for the accepted fast
case, so ordinary HTTP/1.1 no-body requests with a non-empty `Host` and no
`Connection` / `Expect` / `Transfer-Encoding` policy headers do not force header
materialization before dispatch. Public HTTP APIs and wire contracts remain
unchanged.

Focused RED/GREEN:

```text
RED: make -C tests/nextpas.core.http/test_http_h1fast clean test
Invalid header name/value fallback raised EHttpError from eager THttpHeaders.Add

GREEN: make -C tests/nextpas.core.http/test_http_h1fast clean test
22 total, 22 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
274 total, 274 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Parser microbenchmark:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| fast workload    | previous ns/op | after ns/op |
| ---------------- | -------------: | ----------: |
| simple GET       |          757.2 |       349.9 |
| 10 headers       |         3554.1 |      1351.5 |
| POST 1KB body    |         1394.2 |       628.9 |
| pipeline 10 reqs |         7821.6 |      3526.5 |

The parser rows show the intended materialization win. A same-batch
`bench_server` sanity row measured `87356 req/s`, which is within the already
observed local noise band; do not treat it as a stable full-chain throughput
claim.

## Optimization Evidence: Header Allocation Fast Path

On 2026-06-05 local time, `THttpHeaders` switched from per-entry dynamic array
resizing to a count + capacity model. This targets the llhttp adapter path that
adds one parsed header at a time.

Header microbenchmark:

```text
command=make -C benchmarks/nextpas.core.http/bench_headers clean run
```

| workload                  | before ns/op | after ns/op |
| ------------------------- | -----------: | ----------: |
| Set+Get 5 headers         |       1235.6 |       924.2 |
| Set+Get 15 headers        |       3233.0 |      2712.2 |
| Add 15 headers            |       2424.4 |      1832.8 |
| Get miss (3 headers)      |         58.1 |        53.9 |
| Get hit (5 headers, last) |         64.7 |        61.6 |
| Has (3 headers)           |         49.7 |        46.0 |
| Clone 10 headers          |        725.9 |       732.4 |

`Add 15 headers` is the most relevant row for the current H1 parser adapter,
because parsed header callbacks append entries as they arrive. The change keeps
the public header API unchanged; `test_http_headers`, `test_http_h1parser`, and
`test_http_h1fast` all passed with heaptrc reporting `0 unfreed memory blocks`.

## Optimization Evidence: Parser Span Append Fast Path

On 2026-06-05 local time, the llhttp adapter stopped copying URL/header
callback spans through a temporary string before appending them to the parser
state. The first span now writes directly into the target string, and later
split spans append with `SetLength + Move`.

Parser microbenchmark:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| llhttp workload  | before ns/op | after ns/op |
| ---------------- | -----------: | ----------: |
| simple GET       |       1298.0 |      1208.7 |
| 10 headers       |       4704.7 |      3952.9 |
| POST 1KB body    |       2136.6 |      1926.7 |
| pipeline 10 reqs |      11400.4 |     10668.5 |

The benchmark has normal local noise, so these numbers should be treated as a
directional microbenchmark. The split-callback contract is covered by
`test_http_h1parser`, and `test_http_h1fast` keeps the fast parser differential
gate green against the llhttp adapter.

## Optimization Evidence: Header Lookup Exact Fast Path

On 2026-06-05 local time, `THttpHeaders.Get/Has` gained an exact-match fast path.
This favors the server/adapter hot path, where lookup keys such as `host`,
`content-length`, and `connection` are already lowercase. If exact lookup misses
and the query contains uppercase characters, lookup falls back to normalized
case-insensitive matching.

Header microbenchmark:

```text
command=make -C benchmarks/nextpas.core.http/bench_headers clean run
```

| workload                            | before ns/op | after ns/op |
| ----------------------------------- | -----------: | ----------: |
| Set+Get 5 headers                   |       1404.5 |       928.0 |
| Set+Get 15 headers                  |       3420.0 |      2665.6 |
| Add 15 headers                      |       2064.0 |      1775.8 |
| Get miss (3 headers)                |         58.8 |        55.6 |
| Get hit (5 headers, last)           |         68.6 |        46.6 |
| Get hit uppercase (5 headers, last) |        122.8 |       149.7 |
| Has (3 headers)                     |         53.3 |        25.1 |
| Clone 10 headers                    |        752.3 |       723.9 |

The uppercase lookup row is intentionally tracked because public header APIs
remain case-insensitive. This slice trades a slower uppercase fallback for a
faster lowercase hot path, which matches current server internals.

Later on 2026-06-06, `THttpHeaders.FindFirst`, `NeedsNormalize`, and
`NormalizeIfNeeded` were locked as `inline` hot helpers. This keeps
`Get` / `Has` exact lowercase lookup and the delete-path normalize check on a
short concrete-call path while leaving full normalization loops and public
interface dispatch unchanged.

Focused RED before the production change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

29 total, 28 passed, 1 failed
failure: THttpHeaders FindFirst inline declaration missing
heaptrc: 0 unfreed memory blocks
```

Focused verification after the change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
29 total, 29 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_headers clean test
17 total, 17 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Small filtered local row:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='Get hit' make -C benchmarks/nextpas.core.http/bench_headers clean run
Get hit (5 headers, last) = 48.9 ns/op
Get hit uppercase (5 headers, last) = 155.4 ns/op
```

This row is a small smoke for the header lookup path, not a durable
cross-run performance claim.

## Optimization Evidence: Header GetAll Miss Fast Path

On 2026-06-05 local time, `THttpHeaders.GetAll` stopped allocating a full
temporary result array for lowercase miss lookups. This targets normal requests
that do not carry `Expect` or `Transfer-Encoding`, while server code still
checks those header collections.

Header microbenchmark:

```text
command=make -C benchmarks/nextpas.core.http/bench_headers clean run
```

| workload                | before ns/op | after ns/op |
| ----------------------- | -----------: | ----------: |
| GetAll miss (5 headers) |        136.9 |        60.6 |

Parser projection:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| llhttp workload  | before ns/op | after ns/op |
| ---------------- | -----------: | ----------: |
| simple GET       |       1203.7 |      1094.1 |
| 10 headers       |       4061.6 |      3905.8 |
| POST 1KB body    |       1922.5 |      1867.3 |
| pipeline 10 reqs |      10602.0 |     10096.6 |

`test_http_headers`, `test_http_h1parser`, and `test_http_h1fast` all passed
with heaptrc reporting `0 unfreed memory blocks`.

## Diagnostic Evidence: Raw Translated llhttp vs Adapter

On 2026-06-05 local time, `bench_h1parser` gained raw translated llhttp
no-callback rows. These rows measure the Pascal-translated state machine without
the high-level `IH1Parser` adapter building URL strings, header objects, or body
buffers.

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| workload      | raw llhttp ns/op | adapter ns/op | adapter/raw |
| ------------- | ---------------: | ------------: | ----------: |
| simple GET    |            425.3 |        1138.6 |       2.68x |
| 10 headers    |            822.1 |        3813.1 |       4.64x |
| POST 1KB body |            456.2 |        1853.6 |       4.06x |

The same run showed the current conservative fast path at `843.0 ns/op` for
simple GET, `3467.6 ns/op` for 10 headers, `1474.5 ns/op` for POST 1KB, and
`8464.3 ns/op` for a 10-request pipeline.

This does not prove parity with C llhttp; there is no in-repo C llhttp
comparator yet. It does show that, inside the current nextPas H1 parser stack,
the dominant cost is adapter materialization rather than the Pascal-translated
llhttp state machine itself.

The raw simple-GET row was especially sensitive to the old benchmark runner's
`MAX_ITERS = 1000` cap, so these historical numbers are directional. The
classification remains stable: complete adapter parsing is materially slower
than raw state-machine execution. A later runner update in this document records
the current configurable iteration cap.

## Diagnostic Evidence: C llhttp Comparator

On 2026-06-05 local time, `bench_h1parser` gained an external C llhttp
comparator. The comparator does not vendor llhttp into nextPas. Point
`LLHTTP_ROOT` at llhttp `9.4.1`, matching the Pascal-translated
`nextpas.core.http.impl.h1.llhttp.pas` source.

Run the C comparator directly:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c \
  clean run LLHTTP_ROOT=/path/to/llhttp-9.4.1
```

Or run it through the parent parser benchmark:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser \
  run-c LLHTTP_ROOT=/path/to/llhttp-9.4.1
```

The benchmark smoke test always verifies that a missing `LLHTTP_ROOT` reports a
clear diagnostic. To run the real C comparator smoke, set
`NEXTPAS_LLHTTP_ROOT`:

```sh
NEXTPAS_LLHTTP_ROOT=/path/to/llhttp-9.4.1 \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
```

Local comparator input sizes match `bench_h1parser`: simple GET is 35 bytes,
10 headers is 286 bytes, POST 1KB is 1130 bytes, and the 10-request pipeline is
350 bytes.

Local snapshot with
`LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp`:

| workload         | Pascal raw ns/op | C raw ns/op | Pascal no-op ns/op | C no-op ns/op | nextPas adapter ns/op |
| ---------------- | ---------------: | ----------: | -----------------: | ------------: | --------------------: |
| simple GET       |            222.0 |       279.4 |              221.5 |         138.2 |                 623.0 |
| 10 headers       |            779.5 |       561.5 |              785.7 |         544.7 |                3341.4 |
| POST 1KB body    |            437.1 |       299.1 |              454.5 |         283.4 |                1429.1 |
| pipeline 10 reqs |           2203.0 |      1408.2 |             2159.2 |        1401.7 |                6273.4 |

The raw simple-GET row is too short and noisy to use as a standalone parity
claim. The more representative 10-header, POST, pipeline, and no-op callback
rows show C llhttp ahead by roughly `1.4x-1.6x` on this machine. That makes the
Pascal translation a real optimization track, but the larger current cost is
still the nextPas adapter/materialization layer: the adapter is about `2.2x` to
`6.0x` slower than C raw llhttp across these same rows.

Treat these rows as local directional evidence. This snapshot used the old
`MAX_ITERS = 1000` cap; the formal benchmark round should use the current
configurable runner settings before making cross-machine or cross-toolchain
claims.

## Optimization Evidence: Benchmark Runner Max Iterations

On 2026-06-05 local time, the Pascal `TBenchRunner` and the C llhttp comparator
stopped using a hard-coded `MAX_ITERS = 1000`. Both runners now default to
`bench_max_iters=100000`, print the effective value in the summary, and accept
`NEXTPAS_BENCH_MAX_ITERS` for short smoke runs or heavier formal captures.

The focused benchmark gate also now locks stable operation markers for these two
parser-facing tools:

- `bench_h1parser` emits `operation=http.h1parser`
- `bench_h1parser/compare_c` emits `operation=http.h1parser.c_llhttp`

This keeps parser-filtered smoke runs, saved raw output, and future snapshot
parsers from inferring tool identity from human-readable titles alone.

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
H1 parser benchmark max iterations env and C llhttp comparator max iterations env failed:
operation=http.h1parser / operation=http.h1parser.c_llhttp markers were missing.

GREEN: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
49 total, 49 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Default parser sanity:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
bench_max_iters=100000
raw llhttp simple GET ns/op=215.3
raw llhttp 10 headers ns/op=776.0
llhttp adapter 10 headers ns/op=3458.0
fast simple GET ns/op=350.1
fast 10 headers ns/op=1432.8
```

Default C comparator sanity:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp
bench_max_iters=100000
C raw llhttp simple GET ns/op=152.4
C raw llhttp 10 headers ns/op=535.1
C raw llhttp POST 1KB ns/op=300.9
C raw llhttp pipeline ns/op=1443.6
```

The default is intentionally a balance: it is 100x higher than the old cap, so
sub-microsecond parser rows are much less sensitive to timer noise, but it does
not make everyday benchmark sanity runs as expensive as a full formal capture.
Use `NEXTPAS_BENCH_MAX_ITERS=1000000` or higher for dedicated cross-toolchain
snapshot work when runtime cost is acceptable.

## Diagnostic Evidence: Adapter Materialization Breakdown

On 2026-06-05 local time, `bench_h1parser` gained an `adapter materialization
costs` group. These rows are synthetic and intentionally narrower than a full
parser run: they isolate string span accumulation, `THttpHeaders.Add`, and body
buffer copy so later optimization work can target the dominant adapter cost
instead of guessing from the full `IH1Parser` row.

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
H1 parser benchmark breakdown markers were missing:
adapter cost: span append 10 headers
adapter cost: header add 10 headers
adapter cost: body copy 1KB

GREEN: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
9 total, 9 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Default parser sanity:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
bench_max_iters=100000
raw translated llhttp 10 headers ns/op=753.6
noop callback 10 headers ns/op=786.6
adapter span append 10 headers ns/op=801.1
adapter header add 10 headers ns/op=1220.9
adapter body copy 1KB ns/op=33.1
full llhttp adapter 10 headers ns/op=3378.2
fast 10 headers ns/op=1381.5
```

The immediate conclusion is that body copy is not the current parser adapter
bottleneck. The 10-header adapter row is dominated by header string
materialization and header container insertion/normalization. Future production
optimization should therefore prioritize reducing ordinary-path header
materialization before spending time on body copy or hand-editing the
Pascal-translated llhttp state machine.

## Optimization Evidence: Trusted Parser Header Insertion

On 2026-06-05 local time, `TH1Parser` started storing parser-validated headers
through concrete `THttpHeaders.AddParsed`. This keeps `IHttpHeaders` unchanged
while avoiding repeated external-input validation on header names and values
that llhttp has already accepted. The helper still stores canonical lowercase
header names so case-insensitive lookups and duplicate header order stay stable.

Focused RED/GREEN:

```text
RED: make -C tests/nextpas.core.http/test_http_headers clean test
test_http_headers.lpr(...): Error: Identifier idents no member "AddParsed"

GREEN:
make -C tests/nextpas.core.http/test_http_headers clean test
16 total, 16 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_h1parser clean test
89 total, 89 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
274 total, 274 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
9 total, 9 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Parser benchmark sanity:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
bench_max_iters=100000
adapter header add 10 headers ns/op=866.7
full llhttp adapter 10 headers ns/op=3030.8
full llhttp adapter POST 1KB ns/op=1268.4
full llhttp adapter pipeline 10 reqs ns/op=6007.6
```

Compared with the previous adapter-breakdown snapshot, header insertion dropped
from `1220.9 ns/op` to `866.7 ns/op`, full 10-header adapter parsing dropped
from `3378.2 ns/op` to `3030.8 ns/op`, and POST 1KB dropped from `1417.2 ns/op`
to `1268.4 ns/op`. This confirms the previous direction: the next remaining
adapter target is string span materialization rather than body copying.

## Optimization Evidence: Parser Header Container Reuse

On 2026-06-05 local time, `IHttpHeaders` gained a focused `Clear` contract and
`TH1Parser.Reset` started reusing its parser-owned header container instead of
allocating a new `IHttpHeaders` object per reset. This targets repeated parse,
keep-alive, and pipelined request paths.

Baseline:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

Confirmation:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser run
```

| llhttp adapter workload | before ns/op | after ns/op |
| ----------------------- | -----------: | ----------: |
| simple GET              |       1101.7 |       641.8 |
| 10 headers              |       3808.5 |      3284.4 |
| POST 1KB body           |       1848.6 |      1457.6 |
| pipeline 10 reqs        |      11253.6 |      6201.2 |

`test_http_headers`, `test_http_h1parser`, and `test_http_h1fast` all passed
with heaptrc reporting `0 unfreed memory blocks`. The H1 parser heaptrc
allocation count dropped from the previous `1423` blocks to `1404` blocks in
the focused parser gate.

## Optimization Evidence: Parser Body Buffer Reuse

On 2026-06-05 local time, `TH1Parser` changed request/response body storage
from an exact-length dynamic array to a parser-owned capacity buffer plus an
effective `FBodySize`. `Reset` now preserves body capacity, while `GetBody` and
`NewBodyReader` only expose the current effective body bytes. `NewBodyReader`
still returns a snapshot so parser buffer reuse cannot mutate older readers.

The focused guard is `test_http_h1parser`'s `Reset and reparse` case: it parses
a body-bearing request, keeps a body reader, resets, parses a shorter body, and
proves the shorter body does not expose stale bytes while the old reader still
sees its original body.

Parser microbenchmark confirmation:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser run
```

| llhttp adapter workload | previous ns/op | after ns/op |
| ----------------------- | -------------: | ----------: |
| simple GET              |          641.8 |       644.2 |
| 10 headers              |         3284.4 |      3333.1 |
| POST 1KB body           |         1457.6 |      1404.6 |
| pipeline 10 reqs        |         6201.2 |      6206.8 |

This is a narrow optimization: the body workload improved, while no-body rows
remain effectively unchanged within local microbenchmark noise. It does not
settle Pascal-translated llhttp versus C llhttp parity; that still needs a
same-payload C llhttp comparator before making claims about translation cost.

`test_http_h1parser` and `test_http_h1fast` both passed with heaptrc reporting
`0 unfreed memory blocks`.

## Diagnostic Evidence: H1 Callback Dispatch vs Adapter Materialization

On 2026-06-05 local time, `bench_h1parser` gained two diagnostic groups:

- `raw llhttp: pipeline pause-only (10 reqs)` registers only
  `on_message_complete`, returns `HPE_PAUSED`, and consumes the pipeline one
  request at a time. This makes raw translated llhttp closer to the adapter's
  reset/keep-alive loop.
- `translated llhttp with no-op callbacks` registers URL/header/body/header
  completion/message completion callbacks, but the callbacks only count bytes
  or events. They do not build strings, headers, body buffers, or request
  metadata.

Confirmation run:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| workload                       |  ns/op |
| ------------------------------ | -----: |
| raw llhttp simple GET          |  232.1 |
| noop cb simple GET             |  221.3 |
| llhttp adapter simple GET      |  617.7 |
| raw llhttp 10 headers          |  823.7 |
| noop cb 10 headers             |  806.1 |
| llhttp adapter 10 headers      | 3380.4 |
| raw llhttp POST 1KB            |  489.4 |
| noop cb POST 1KB               |  454.1 |
| llhttp adapter POST 1KB        | 1401.3 |
| raw llhttp pipeline pause-only | 2170.1 |
| noop cb pipeline               | 2163.7 |
| llhttp adapter pipeline        | 6205.7 |

The simple-GET raw/no-op rows are very short and remain sensitive to local
microbenchmark noise. The 10-header, POST, and pipeline rows are the useful
classification signal: no-op callback cost stays close to raw translated
llhttp, while the full adapter is much slower. Current evidence therefore
continues to point at adapter materialization rather than callback dispatch.

This still does not prove Pascal-translated llhttp parity with C llhttp. A
same-payload C llhttp comparator is required before making claims about the
translation itself.

## Optimization Evidence: Header Name Normalization Fast Path

On 2026-06-05 local time, `THttpHeaders.Add` and `Set_` stopped normalizing
already-lowercase header names after validating them. A new combined scan
validates the name and detects whether uppercase normalization is actually
needed. Public mixed/uppercase input still canonicalizes to lowercase, and
invalid name/value rejection remains covered by focused tests.

Header benchmark:

```text
baseline=make -C benchmarks/nextpas.core.http/bench_headers clean run
confirmation=make -C benchmarks/nextpas.core.http/bench_headers run
```

| workload           | before ns/op | after ns/op |
| ------------------ | -----------: | ----------: |
| Set+Get 5 headers  |        828.2 |       784.3 |
| Set+Get 15 headers |       2665.1 |      2516.8 |
| Add 15 headers     |       1783.5 |      1635.8 |

Parser projection:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
llhttp adapter simple GET ns/op=622.7
llhttp adapter 10 headers ns/op=3324.8
llhttp adapter POST 1KB ns/op=1429.5
llhttp adapter pipeline 10 reqs ns/op=6280.6
```

The direct header workload improved on the intended lowercase hot path. The
full parser projection remains dominated by broader adapter materialization,
so the next high-value target is request metadata caching or callback string
materialization, not this header-name path alone.

`test_http_headers` and `test_http_h1parser` both passed with heaptrc reporting
`0 unfreed memory blocks`.

## Optimization Evidence: H1 Server Header-Policy One-Shot Evaluation

On 2026-06-05 local time, H1 server request validation moved headers-stage
policy checks to the first `HeadersComplete` transition. The threaded and
poll/epoll paths now share one helper for max header size, parser error status,
HTTP/1.1 `Host`, unsupported `Expect`, and declared `Content-Length` vs
`MaxBodySize` decisions. Body-size progress, trailer-size progress, and parser
errors still remain checked during the read loop.

This avoids repeating `Host` / `Expect` / declared `Content-Length` header
lookups and token parsing while a large request body arrives across multiple
reads. The same slice also fixed a poll-path `case` block syntax error that was
exposed by building the full-chain benchmark.

`bench_fullchain` now includes a 16KB POST body sink scenario:

```text
baseline=make -C benchmarks/nextpas.core.http/bench_fullchain clean run
confirmation=make -C benchmarks/nextpas.core.http/bench_fullchain clean run
```

| workload       | before req/s | after req/s |
| -------------- | -----------: | ----------: |
| Sink 16KB POST |         5005 |        5488 |

The full-chain benchmark is intentionally directional and local. Short GET rows
showed normal scheduler/socket noise in the same runs, so the 16KB sink row is
the useful signal for this slice.

`test_http_server` passed with `274 total, 274 passed, 0 failed`; `test_http_security`
passed with `242 total, 242 passed, 0 failed`; heaptrc reported
`0 unfreed memory blocks` in both focused gates.

## Optimization Evidence: Parser Direct Header Span Insertion

On 2026-06-05 local time, `TH1Parser` started inserting common unsplit
header field/value callbacks directly from llhttp spans into the parser-owned
`THttpHeaders` store. The new concrete helper is `THttpHeaders.AddParsedSpans`;
it remains outside `IHttpHeaders` and is only for parser-validated input.

The parser keeps the safe fallback for split or cross-buffer callbacks: any
captured span still pending when `Execute` returns is materialized into
`FCurrentField` / `FCurrentValue`, so no callback buffer pointer survives past
the caller's input lifetime.

Focused RED/GREEN:

```text
RED: make -C tests/nextpas.core.http/test_http_headers clean test
test_http_headers.lpr(290,10) Error: Identifier idents no member "AddParsedSpans"

GREEN:
make -C tests/nextpas.core.http/test_http_headers clean test
17 total, 17 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_h1parser clean test
89 total, 89 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
274 total, 274 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
9 total, 9 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Parser benchmark sanity:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
bench_max_iters=100000
raw translated llhttp 10 headers ns/op=785.4
raw translated llhttp POST 1KB ns/op=431.7
raw translated llhttp pipeline ns/op=2104.6
adapter span append 10 headers ns/op=787.0
adapter header add 10 headers ns/op=752.9
adapter header span add 10 headers ns/op=1293.0
full llhttp adapter 10 headers ns/op=2808.4
full llhttp adapter POST 1KB ns/op=1199.0
full llhttp adapter pipeline 10 reqs ns/op=5553.6
```

C comparator sanity with llhttp `9.4.1`:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp
bench_max_iters=100000
C raw llhttp 10 headers ns/op=532.2
C raw llhttp POST 1KB ns/op=275.3
C raw llhttp pipeline ns/op=1464.6
C noop callback 10 headers ns/op=548.7
C noop callback POST 1KB ns/op=280.3
C noop callback pipeline ns/op=1431.4
```

The user's suspicion about the Pascal-translated llhttp state machine is valid
enough to keep as a dedicated optimization track: representative raw rows are
still about `1.4x-1.5x` slower than C llhttp on this machine. It is not the
largest current bottleneck, though. Full `IH1Parser` adapter rows remain much
slower than raw translated llhttp, and this slice lowered the full adapter
10-header row from the previous `3030.8 ns/op` snapshot to `2808.4 ns/op`.

The isolated `adapter cost: header span add 10 headers` row is slower than the
string `AddParsed` row because it includes the final name/value string copy.
The full parser still benefits because the direct path removes the intermediate
`FCurrentField` / `FCurrentValue` string allocation/copy before the final store.

## Benchmark Tooling: H1 Row Filter and Flag Matrix

On 2026-06-05 local time, `TBenchRunner` and the C llhttp comparator gained a
shared row filter via `NEXTPAS_BENCH_FILTER`. This is an efficiency seam for
the Pascal-translated llhttp raw-gap work: focused flag/profile runs can target
one row instead of running the whole H1 parser benchmark.

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
H1 parser benchmark filter env failed:
bench_filter=raw llhttp: 10 headers marker was missing and unrelated rows still ran.

GREEN: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
12 total, 12 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Focused Pascal/C row commands:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='C raw llhttp: 10 headers' \
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run \
  LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp
```

Fresh filtered sanity after caching the Pascal raw/no-op request pointer and
length outside the inner loop:

```text
Pascal raw llhttp 10 headers: 749.7 ns/op
C raw llhttp 10 headers: 523.0 ns/op
Pascal raw llhttp 10 headers with -CpCOREAVX2 -CfAVX2: 759.6 ns/op
```

The CPU/FPU target flag trial did not show a useful improvement. The next
raw-gap step should use `perf stat/record` or codegen/profile evidence, not
hand-editing the generated llhttp state machine.

`bench_h1parser/run_flag_matrix.sh` now provides a repeatable smoke/full matrix
runner. It writes `results.tsv`, `summary.tsv`, `env.txt`, logs, and optional
`perf/*.txt` only under
`build/projects/nextpas.core.http/bench_h1parser/flag_matrix/...`.
If you override `NEXTPAS_FLAG_MATRIX_OUTPUT_DIR`, it must still stay under
that `flag_matrix` root. Unsafe overrides now fail fast with `unsafe output
dir` and a non-zero exit instead of letting the runner become a broader tree
cleanup tool.

```sh
LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --smoke --no-perf
```

Use `--runs N` when you want a median across repeated runs without rebuilding a
separate shell loop around the tool:

```sh
LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh \
  --smoke --no-perf --runs 3
```

Do not run multiple `clean run` jobs against the same `bench_h1parser` build
root in parallel; a concurrent parent benchmark clean can remove the C
comparator output directory or produce `Text file busy`. The flag-matrix runner
uses per-variant build directories to avoid that race.

## Benchmark Tooling: Perf Fallback

On 2026-06-05 local time, `run_flag_matrix.sh --perf` was hardened for ordinary
developer machines where Linux perf events are unavailable. The runner now
probes `perf stat -e cycles -- true` before wrapping benchmark binaries. If the
probe fails, it still runs the timing matrix and records the perf state in
`env.txt`.

Focused evidence:

```text
RED:
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
NEXTPAS_BENCH_MAX_ITERS=2000 \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --smoke --perf

exit=255
perf_event_paranoid setting is 3
Access to performance monitoring and observability operations is limited.

GREEN:
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
13 total, 13 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Current local environment:

```text
/proc/sys/kernel/perf_event_paranoid = 3
flag_matrix env.txt:
perf_requested=1
perf_usable=0
```

This means local timing rows are still usable, but hardware counters such as
`cycles`, `instructions`, `branches`, `branch-misses`, and `cache-misses` must
be captured on a machine with lower `perf_event_paranoid` or the required
`CAP_PERFMON` / tracing capabilities. The next raw-gap analysis step should use
the same flag-matrix runner on such a machine before changing generated llhttp
translation code.

## Optimization Evidence: H1 Request Metadata Cache

On 2026-06-06 local time, H1 request-side metadata moved from headers-complete
header-store rescans to one parser-owned parse-time cache. The parser now
updates pending `TH1RequestMetadata` as watched request headers complete, and
`BuildRequestMetadata` validates cached `Transfer-Encoding` state before
publishing the final metadata snapshot, without calling `IHttpHeaders.Get/GetAll`.

This targets the adapter hot path where the previous parser logic repeated
`Get/GetAll/Trim/LowerCase/TryStrToInt64` for `Host`, `Expect`,
`Content-Length`, `Transfer-Encoding`, and `Connection` after the public header
store had already been populated. The change does not alter public HTTP facade
APIs, response parsing, generated llhttp code, public `IHttpHeaders` order, or
the existing request-side `Connection` exact-string behavior. The cache keeps
first-value semantics for `Host` / `Connection` / `Content-Length`, merges
duplicate `Expect` values in parse order, and ignores chunked trailer headers.

Focused benchmark:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='request metadata' make -C benchmarks/nextpas.core.http/bench_h1parser clean run
adapter cost: request metadata legacy expect+cl ns/op=1321.3
adapter cost: request metadata cached expect+cl ns/op=6.1
```

Focused validation:

```text
make -C tests/nextpas.core.http/test_http_h1parser clean test
94 total, 94 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
32 total, 32 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

On 2026-06-06 local time, the watched metadata cache gained a narrower span
fast path. `Host`, `Connection`, `Content-Length`, and `Expect` metadata now
avoid materializing the captured header value string when llhttp delivered the
field/value as a single live span. `Transfer-Encoding` intentionally keeps the
existing combined-string validation path so malformed-vs-unsupported error
classification does not drift.

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test
36 total, 35 passed, 1 failed
failed at: H1 parser request metadata span fast path source contract
heaptrc: 0 unfreed memory blocks

GREEN:
make -C tests/nextpas.core.http/test_http_h1parser clean test
95 total, 95 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test
36 total, 36 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Small parser benchmark smoke:

```text
command=NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='adapter no-url' make -C benchmarks/nextpas.core.http/bench_h1parser clean run
adapter no-url: metadata 3 headers ns/op=322.2
adapter no-url: fast reject + llhttp ns/op=1813.5
adapter no-url: llhttp direct only ns/op=1172.1
adapter no-url: fast parse only ns/op=646.2
```

The immediate conclusion is that request metadata caching and the follow-up span
fast path remove measurable per-request policy/dispatch cost without changing
wire contracts. The broader H1 performance track should continue with
adapter/header materialization rows before returning to generated llhttp
translation changes.

## Optimization Evidence: Request-Target URL Parser

On 2026-06-05 local time, `TUrl` gained `ParseRequestTarget` for HTTP
request-target materialization. The common origin-form path skips authority,
userinfo, host, and port parsing, and it also avoids scanning for `://` when
the target starts with `/` or `*`. Absolute-form request targets still delegate
to `TUrl.Parse`, preserving proxy-style compatibility.

H1 server request construction used `TUrl.ParseRequestTarget(FParser.GetUrl)`
in both direct and poll-driven dispatch paths for this slice. A later lazy
request-target projection slice moved that parse out of dispatch for handlers
that do not read `Req.Url` / `Req.QueryParam`.

Focused benchmark:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='url parse' make -C benchmarks/nextpas.core.http/bench_h1parser clean run
adapter cost: url parse generic origin-form = 276.8 ns/op
adapter cost: url parse request-target origin-form = 232.0 ns/op
```

Focused validation:

```text
RED: make -C tests/nextpas.core.http/test_http_base clean test
Identifier idents no member "ParseRequestTarget"

make -C tests/nextpas.core.http/test_http_base clean test
22 total, 22 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
13 total, 13 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

The public parser proof now covers origin-form, path-only, absolute-form,
asterisk-form, authority-form, scheme-like origin-form, and empty input. The
server proof directly checks handler-visible URL materialization for
absolute-form, asterisk-form, authority-form, and an origin-form path that
contains `://`.

This is a narrow adapter/materialization win. It does not close the
Pascal-translated llhttp raw gap by itself, but it removes a per-request
server dispatch cost that sits after successful H1 parsing.

## Optimization Evidence: Lazy Request-Target Projection

On 2026-06-05 local time, `THttpRequest` gained an internal
`CreateFromRequestTarget` constructor. H1 direct and poll-driven dispatch now
pass the raw request-target into the request object and defer
`TUrl.ParseRequestTarget` until `Req.Url` or `Req.QueryParam` is actually read.
Existing `THttpRequest.Create` / `NewRequest` paths remain eager and keep their
public behavior.

This is intentionally not a wire-contract change. Routers, middleware, static
serving, and handlers that read `Req.Url.Path` still trigger the same
request-target parsing before observing URL fields. The savings apply to simple
handlers or internal paths that do not need URL/query materialization.

Focused benchmark:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='request create' make -C benchmarks/nextpas.core.http/bench_h1parser clean run
adapter cost: request create eager url parse = 557.1 ns/op
adapter cost: request create lazy target = 293.9 ns/op
```

Focused validation:

```text
RED: make -C tests/nextpas.core.http/test_http_message clean test
Identifier idents no member "CreateFromRequestTarget"

make -C tests/nextpas.core.http/test_http_message clean test
15 total, 15 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
13 total, 13 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

The Pascal-translated llhttp raw gap remains a real track, but this batch again
removed a larger, safer adapter/server materialization cost without touching
generated llhttp code.

## Optimization Evidence: Request Path Direct Accessor

On 2026-06-06 local time, `IHttpRequest` gained direct `Path` and `RawQuery`
accessors. The older `Req.Url` property is unchanged, but router, static
serving, middleware logging/timeout diagnostics, H1 client request writing, and
the `bench_server url_path` workload now use `Req.Path` / `Req.RawQuery` where
they only need the request-target path/query. This avoids copying the full
`TUrl` record on common handler/router path reads.

Focused RED before the production change:

```text
make -C tests/nextpas.core.http/test_http_message clean test

test_http_message.lpr(...) Error: Identifier idents no member "Path"
test_http_message.lpr(...) Error: Identifier idents no member "RawQuery"
```

Focused verification after the change:

```text
make -C tests/nextpas.core.http/test_http_message clean test
16 total, 16 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_contract clean test
29 total, 29 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_router clean test
21 total, 21 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_static clean test
10 total, 10 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_middlewares clean test
13 total, 13 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
29 total, 29 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Small filtered local row:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='request ' make -C benchmarks/nextpas.core.http/bench_h1parser clean run
adapter cost: request lazy Url.Path access = 780.6 ns/op
adapter cost: request direct Path access = 710.0 ns/op

command=build/projects/nextpas.core.http/bench_server/bench_http_server --requests 128 --threads 1 --workload url_path
completed=128
ns/op=42179
req/s=23708
```

The direct accessor row is a small adapter/materialization proof, not a durable
server throughput claim. A same-round `test_http_client` run was attempted
because H1 client request writing now uses `Req.Path` / `Req.RawQuery`, but the
shared checkout currently carries an unrelated dirty client test RED for
missing `HttpGetToWriter` / `HttpGetToFile`; that failure is not attributed to
this accessor slice.

## Optimization Evidence: Request Path-Only Projection

On 2026-06-06 local time, `THttpRequest.Path`, `RawQuery`, and `QueryParam`
stopped forcing full `TUrl.ParseRequestTarget` materialization for common
origin-form request-targets. `Req.Url` still materializes the complete `TUrl`
record, and absolute-form request-targets still fall back to the full parser so
scheme/host/port validation remains unchanged.

Focused RED before the production change:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

31 total, 30 passed, 1 failed
failure: THttpRequest request-target projection helper declaration missing
heaptrc: 0 unfreed memory blocks
```

Focused verification after the change:

```text
make -C tests/nextpas.core.http/test_http_message clean test
19 total, 19 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test
31 total, 31 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_router clean test
21 total, 21 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

The message test now covers origin-form query/fragment boundaries,
asterisk-form, authority-like targets, relative path targets, absolute-form
host/port preservation, and invalid absolute port rejection through the direct
accessors.

Fresh filtered local rows:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='request ' make -C benchmarks/nextpas.core.http/bench_h1parser clean run
adapter cost: request lazy Url.Path access = 779.9 ns/op
adapter cost: request direct Path access = 496.5 ns/op
adapter cost: request direct RawQuery access = 494.2 ns/op
adapter cost: request direct Path+RawQuery access = 542.6 ns/op

command=build/projects/nextpas.core.http/bench_server/bench_http_server --requests 512 --threads 1 --workload url_path
completed=512
ns/op=43622
req/s=22923
```

This closes the direct path accessor slow-path gap. The next high-value
performance slice should move to llhttp adapter metadata caching during parse,
then fast-path header block lazy materialization, rather than hand-editing the
generated llhttp state machine.

## Full-Chain Correlation: No-URL Keep-Alive Workload

On 2026-06-05 local time, the server comparison output gained an explicit
`workload=no_url` marker across nextPas, Go, and Rust std-only comparator
binaries. This locks the benchmark interpretation: the current keep-alive
comparison measures a simple handler that does not read `Req.Url` / query
parameters.

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
5 server benchmark/comparison smoke cases failed because workload=no_url was missing.

GREEN: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
17 total, 17 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh local correlation after lazy request-target projection:

```text
command=benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4
```

| impl          | workload | completed | elapsed_ns | ns/op | req/s |
| ------------- | -------- | --------: | ---------: | ----: | ----: |
| nextPas       | no_url   |     50000 |  641366179 | 12827 | 77958 |
| Go `net/http` | no_url   |     50000 | 2649511337 | 52990 | 18871 |
| Rust std-only | no_url   |     50000 |  508013046 | 10160 | 98422 |

The result is directionally useful but not a stable throughput claim. Compared
with earlier local rows, nextPas remains in the same noise band and still trails
the Rust std-only comparator on this no-URL workload. The lazy request-target
microbenchmark win therefore does not yet prove a full-chain req/s win; the next
high-value work should profile or isolate remaining server/runtime costs that
sit outside URL projection.

## Full-Chain Correlation: URL Path Workload

On 2026-06-05 local time, the server comparison runner gained
`--workload no_url|url_path|adapter_no_url`, and the nextPas, Go, and Rust
std-only comparator binaries now accept the same selector. `url_path` sends
`GET /api/v1/users`; nextPas and Go validate the parsed request path, while the
Rust std-only comparator checks the same path from the one buffered request
frame before writing its response.

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
4 url_path smoke cases failed before the comparator binaries and runner accepted
or propagated --workload url_path.

GREEN: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
17 total, 17 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh local correlation:

```text
command=benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload url_path
```

| impl          | workload | completed | elapsed_ns | ns/op |  req/s |
| ------------- | -------- | --------: | ---------: | ----: | -----: |
| nextPas       | url_path |     50000 |  628713623 | 12574 |  79527 |
| Go `net/http` | url_path |     50000 | 2628825324 | 52576 |  19019 |
| Rust std-only | url_path |     50000 |  441859972 |  8837 | 113158 |

The `url_path` row keeps nextPas ahead of the Go comparator and still behind the
Rust std-only comparator. It does not prove that Pascal-translated llhttp is the
full-chain bottleneck: this request still fits the H1 server fast path, and URL
projection is paid lazily only when the handler reads `Req.Url.Path`. The next
useful isolation step is a forced-adapter workload, or a narrower parser
comparison against C llhttp with hardware counters on a perf-enabled machine.

## Full-Chain Correlation: Forced Adapter No-URL Workload

On 2026-06-05 local time, `adapter_no_url` was added as a full-chain isolation
workload. It keeps the request target at `/` and keeps the handler from reading
the URL, but adds `Connection: keep-alive` to the request. In nextPas this
forces `TryUseFastRequestParser` to reject the H1 fast path (`HasConnection`)
and use the llhttp adapter path.

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
18 total, 17 passed, 1 failed
adapter_no_url runner smoke failed because --workload accepted only no_url|url_path.
heaptrc: 0 unfreed memory blocks

GREEN: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
18 total, 18 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh local correlation:

```text
command=benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload adapter_no_url
```

| impl          | workload       | completed | elapsed_ns | ns/op | req/s |
| ------------- | -------------- | --------: | ---------: | ----: | ----: |
| nextPas       | adapter_no_url |     50000 |  634287816 | 12685 | 78828 |
| Go `net/http` | adapter_no_url |     50000 | 2891101718 | 57822 | 17294 |
| Rust std-only | adapter_no_url |     50000 |  521882998 | 10437 | 95806 |

The forced-adapter row keeps nextPas in the same local band as the no-URL and
URL-path rows, still ahead of Go and behind the Rust std-only comparator. That
does not erase the raw Pascal-vs-C llhttp gap below, but it shows that the
current full-chain server gap is not explained by the H1 fast path alone. The
next useful step is to split adapter materialization, response writer/drain, and
runtime/socket overhead with narrower benchmarks or profiling.

## Full-Chain Correlation: 1 KiB Response Workload

On 2026-06-05 local time, `response_1k` was added to isolate response
writer/drain and socket throughput beyond the tiny hello-world body. This batch
also fixed the nextPas raw benchmark client to wait for `header_end + body_len`
before counting a response as complete. That makes the large-response row
meaningful and also makes new no-URL rows stricter than older prefix-read rows.
On 2026-06-07 local time, the direct comparator rows also gained explicit
response-read metadata: `response_body_bytes=1024` for this workload, plus
`client_read_mode=header_plus_content_length` for nextPas / Rust std-only /
Hyper and `client_read_mode=http_client_body_drain` for the Go `net/http`
comparator. This keeps response-writer/drain discussions honest about how each
client decides a response is complete.
For a nextPas-only single-connection no-router counterpart, see the
`bench_fullchain direct_1k` rows in the full-chain section above.

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
19 total, 18 passed, 1 failed
response_1k runner smoke failed because --workload accepted only no_url|url_path|adapter_no_url.
heaptrc: 0 unfreed memory blocks

GREEN: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
19 total, 19 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh local correlation:

```text
command=benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload response_1k
```

| impl          | workload    | completed | elapsed_ns | ns/op | req/s |
| ------------- | ----------- | --------: | ---------: | ----: | ----: |
| nextPas       | response_1k |     50000 |  623561283 | 12471 | 80184 |
| Go `net/http` | response_1k |     50000 | 2718470762 | 54369 | 18392 |
| Rust std-only | response_1k |     50000 |  554412389 | 11088 | 90185 |

Calibration no-URL row with the same complete-response reader:

```text
command=benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload no_url
```

| impl          | workload | completed | elapsed_ns | ns/op | req/s |
| ------------- | -------- | --------: | ---------: | ----: | ----: |
| nextPas       | no_url   |     50000 |  569950075 | 11399 | 87726 |
| Go `net/http` | no_url   |     50000 | 2740141668 | 54802 | 18247 |
| Rust std-only | no_url   |     50000 |  527895368 | 10557 | 94715 |

This suggests the current 1 KiB response writer/drain path is not the dominant
gap versus Rust std-only on this machine. nextPas remains close to the Rust
std-only comparator and far ahead of the Go comparator in these local rows.
Future rows should use the complete-response reader when comparing server
throughput.

## Benchmark Tooling: Multi-Run Server Comparison

On 2026-06-05 local time, `run_server_comparison.sh` and
`capture_server_comparison_snapshot.sh` gained `--runs N`. The server runner
now builds nextPas, Go, and Rust std-only once, repeats each implementation
`N` times, prints `run=...` markers for raw rows, and emits a median summary:

```text
summary=http.server.keepalive
summary_impl=go runs=3 median_completed=50000 median_ns/op=55017.0 median_req/s=18176
summary_impl=nextpas runs=3 median_completed=50000 median_ns/op=11431.0 median_req/s=87476
summary_impl=rust_std runs=3 median_completed=50000 median_ns/op=9885.0 median_req/s=101153
```

Each raw nextPas row for the current no-body H1 workloads also includes
`nextpas_h1_path=fast`, which keeps the fast-gate interpretation visible in
captured reports instead of relying on workload names alone.

On 2026-06-07 local time, the direct nextPas / Go / Rust std-only / Hyper
comparator rows also gained explicit thread-clamp metadata. They now preserve
the caller input as `requested_threads=...`, report the actual client
concurrency as `effective_threads=...`, and keep the legacy `threads=...`
line aligned with the effective value. This avoids a misleading row when a
standalone comparator clamps `--threads` down to `--requests`.

Focused RED/GREEN:

```text
RED:
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

21 total, 20 passed, 1 failed
server comparison runner runs summary smoke failed:
unknown argument: --runs
heaptrc: 0 unfreed memory blocks

GREEN:
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Later focused tightening made the same gate require `completed=<requests>` on
every raw implementation row, `nextpas_h1_path=...` on nextPas rows, and
`median_completed=<requests>` in stdout/report summaries. On 2026-06-06, the
std-only Rust comparator marker was tightened from `impl=rust` to
`impl=rust_std` and `rust_profile=std_only`, so future reports cannot be read
as a Hyper/Tokio or broader Rust ecosystem row. A small live smoke with
`--requests 8 --threads 1 --workload adapter_no_url --runs 2` produced
`completed=8`, `nextpas_h1_path=fast`, `rust_profile=std_only`, and
`median_completed=8` for the comparison summary.
Another focused clamp smoke now runs each direct comparator with
`--requests 3 --threads 5` and locks
`requested_threads=5` plus `effective_threads=3`, so saved raw rows cannot
silently discard the original caller intent.
The snapshot helper now preserves the same distinction in its own environment
block and keeps the command block at `--threads 5`, instead of rewriting the
captured snapshot down to `--threads 3`.
The focused gate now also locks the `--include-hyper + --workload response_1k`
snapshot combination, so Hyper/Tokio snapshot evidence is no longer covered
only on the default no-body workload.
A direct `bench_http_server_hyper --requests 32 --threads 2 --workload url_path`
smoke now sits in the focused gate as well, so the Cargo-based comparator has a
durable non-default request-target proof alongside the shared runner and
snapshot paths.

Fresh local `no_url` 50k/4 3-run summary:

```text
command=benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload no_url --runs 3

nextPas median: 11431 ns/op, 87476 req/s
Go net/http median: 55017 ns/op, 18176 req/s
Rust std-only median: 9885 ns/op, 101153 req/s
```

The median row keeps the earlier direction intact: nextPas is still far ahead
of Go `net/http` in this local no-URL microbaseline and remains behind the Rust
std-only comparator. The remaining gap is now small enough that future
optimization decisions should rely on multi-run rows or narrower dispatch /
serialization benchmarks rather than single-shot server samples.

## Diagnostic Evidence: Pascal llhttp Raw Gap Recheck

On 2026-06-05 local time, the Pascal-translated llhttp raw-gap hypothesis was
rechecked with the filtered benchmark rows instead of a full benchmark sweep.

Focused Pascal row:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser clean run
raw llhttp: 10 headers (~400B) = 766.5 ns/op
```

Focused C row:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='C raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp
C raw llhttp: 10 headers (~400B) = 525.0 ns/op
```

The representative raw gap is therefore about `1.46x` on this machine. That
keeps the Pascal translation as a real optimization track, but the evidence
still does not justify hand-editing the generated state machine.

Focused flag matrix:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --no-perf
pascal-default = 854.9 ns/op
c-default = 526.0 ns/op
pascal-coreavx2 = 769.7 ns/op
pascal-extra-opts = 750.6 ns/op
c-native = 524.5 ns/op
```

CPU/FPU flags and extra FPC optimizer switches do not close the gap. The extra
FPC opts also emit additional warnings in this benchmark build, so they should
not become the production default based on this row.

## Benchmark Tooling: Multi-Run H1 Parser Flag Matrix

On 2026-06-05 local time, `run_flag_matrix.sh` gained `--runs N`. The runner
now reuses each built Pascal/C variant across repeated measurements, writes
every run to `results.tsv`, and emits a median-based `summary.tsv`. This keeps
the narrowed Pascal-vs-C llhttp track reproducible without repeatedly
hand-running separate commands.

Focused RED/GREEN:

```text
RED:
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

20 total, 19 passed, 1 failed
H1 parser flag matrix runs summary smoke failed:
unknown argument: --runs
heaptrc: 0 unfreed memory blocks

GREEN:
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

20 total, 20 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Fresh local 3-run filtered summary:

```text
command=NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --smoke --no-perf --runs 3

summary.tsv:
c-default      C raw llhttp: 10 headers (~400B)      median 534.1 ns/op
pascal-default raw llhttp: 10 headers (~400B)        median 749.1 ns/op
```

This recheck keeps the raw translation gap in roughly the same band as the
earlier single-shot evidence: Pascal-translated llhttp remains about `1.40x`
slower than C llhttp on this machine for the narrowed 10-header row. The tool
improvement matters because future raw-gap work can now compare repeated runs
before deciding whether generator/codegen changes are warranted.

On 2026-06-07 local time, the same runner also gained an output-root guard for
`NEXTPAS_FLAG_MATRIX_OUTPUT_DIR`. The script now rejects custom output
directories outside
`build/projects/nextpas.core.http/bench_h1parser/flag_matrix/...` before any
cleanup step runs.

Focused RED/GREEN:

```text
RED:
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

53 total, 52 passed, 1 failed
H1 parser flag matrix rejects unsafe output dir failed:
H1 parser flag matrix unsafe output dir should fail
heaptrc: 0 unfreed memory blocks

GREEN:
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

53 total, 53 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Code inspection points to a generator/codegen track rather than a one-line
runtime fix:

- generated Pascal and C share the same broad llparse goto-state-machine shape;
- the Pascal file repeatedly stores enum states through pointer/integer casts;
- `llhttp__internal__run` has a large set of up-front local temporaries, which
  may increase FPC register pressure;
- the C source has conditional SIMD/range-match code, but `c-native` did not
  materially improve this 10-header row.

Local `perf` is still blocked by `perf_event_paranoid=3`, so hardware counters
for cycles, instructions, branches, branch misses, and cache misses must be
captured on a perf-enabled machine before changing generated llhttp code. Until
that evidence exists, the best production throughput path remains reducing the
larger adapter/materialization costs already exposed by the benchmark rows.
