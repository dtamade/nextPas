# nextpas.core.http Benchmarks

This page records the current HTTP server benchmark harness and one local
snapshot. Treat the numbers as evidence for this machine and toolchain, not as
a permanent ranking across platforms.

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
  --requests 20000 --threads 4 --runs 3 \
  --output build/projects/nextpas.core.http/server_comparison/snapshot.md
```

The comparison currently covers three HTTP/1.1 keep-alive hello-world workloads:

- `workload=no_url`: the handler does not read the request URL or query string.
- `workload=url_path`: the client sends `GET /api/v1/users` and the handler
  reads the path before returning the same hello-world response.
- `workload=adapter_no_url`: the request stays on `/` and does not read the
  URL, but it includes `Connection: keep-alive` so nextPas must leave the H1
  fast path and use the llhttp adapter path.
- `workload=response_1k`: the request stays on `/`, and the server writes a
  1 KiB fixed-length response body. The raw nextPas/Rust clients wait for the
  complete response body, not just a status/header prefix.

It does not cover TLS, request bodies, WebSocket, router/middleware full-chain
cost, `epoll`, or an async Rust server. The Rust comparator is a std-only
microbaseline; add a Hyper/Tokio comparator before treating Rust ecosystem
performance as represented.

Use `--runs N` to repeat each implementation after a single build and emit a
median summary at the end of the raw output. This is the preferred mode for
fresh local comparison rows because single-shot server results are visibly
affected by scheduler noise.

## Run the Router Dispatch Benchmark

Run the focused router dispatch row:

```sh
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='handler dispatch' \
make -C benchmarks/nextpas.core.http/bench_router clean run
```

This row reports `operation=http.router.dispatch` and measures
`THttpRouter.ServeHTTP` for a static route plus a no-op handler. It reuses one
request object and does not include socket I/O, H1 parsing, response
serialization, middleware, or URL/query materialization.

Local focused row from 2026-06-05:

| workload | iterations | ns/op | ops/s |
| --- | ---: | ---: | ---: |
| handler dispatch (match + no-op handler) | 100000 | 508.1 | 1968021 |

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

| impl | completed | elapsed_ns | ns/op | req/s |
| --- | ---: | ---: | ---: | ---: |
| nextPas | 20000 | 247938762 | 12396 | 80665 |
| Go `net/http` | 20000 | 981937616 | 49096 | 20367 |
| Rust std-only | 20000 | 197099848 | 9854 | 101471 |

The snapshot build had no FPC `Warning:` or `Note:` lines in the captured raw
output. Re-run the command above after runtime, compiler, or OS changes before
drawing conclusions.

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

| impl | completed | elapsed_ns | ns/op | req/s |
| --- | ---: | ---: | ---: | ---: |
| nextPas | 50000 | 619882610 | 12397 | 80660 |
| Go `net/http` | 50000 | 2685471938 | 53709 | 18618 |
| Rust std-only | 50000 | 503399527 | 10067 | 99324 |

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

| fast workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| simple GET | 856.4 | 754.9 |
| 10 headers | 3679.0 | 3429.8 |
| POST 1KB body | 1500.2 | 1374.2 |
| pipeline 10 reqs | 8685.5 | 7581.2 |

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

| fast workload | previous ns/op | after ns/op |
| --- | ---: | ---: |
| simple GET | 757.2 | 349.9 |
| 10 headers | 3554.1 | 1351.5 |
| POST 1KB body | 1394.2 | 628.9 |
| pipeline 10 reqs | 7821.6 | 3526.5 |

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

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| Set+Get 5 headers | 1235.6 | 924.2 |
| Set+Get 15 headers | 3233.0 | 2712.2 |
| Add 15 headers | 2424.4 | 1832.8 |
| Get miss (3 headers) | 58.1 | 53.9 |
| Get hit (5 headers, last) | 64.7 | 61.6 |
| Has (3 headers) | 49.7 | 46.0 |
| Clone 10 headers | 725.9 | 732.4 |

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

| llhttp workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| simple GET | 1298.0 | 1208.7 |
| 10 headers | 4704.7 | 3952.9 |
| POST 1KB body | 2136.6 | 1926.7 |
| pipeline 10 reqs | 11400.4 | 10668.5 |

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

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| Set+Get 5 headers | 1404.5 | 928.0 |
| Set+Get 15 headers | 3420.0 | 2665.6 |
| Add 15 headers | 2064.0 | 1775.8 |
| Get miss (3 headers) | 58.8 | 55.6 |
| Get hit (5 headers, last) | 68.6 | 46.6 |
| Get hit uppercase (5 headers, last) | 122.8 | 149.7 |
| Has (3 headers) | 53.3 | 25.1 |
| Clone 10 headers | 752.3 | 723.9 |

The uppercase lookup row is intentionally tracked because public header APIs
remain case-insensitive. This slice trades a slower uppercase fallback for a
faster lowercase hot path, which matches current server internals.

## Optimization Evidence: Header GetAll Miss Fast Path

On 2026-06-05 local time, `THttpHeaders.GetAll` stopped allocating a full
temporary result array for lowercase miss lookups. This targets normal requests
that do not carry `Expect` or `Transfer-Encoding`, while server code still
checks those header collections.

Header microbenchmark:

```text
command=make -C benchmarks/nextpas.core.http/bench_headers clean run
```

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| GetAll miss (5 headers) | 136.9 | 60.6 |

Parser projection:

```text
command=make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| llhttp workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| simple GET | 1203.7 | 1094.1 |
| 10 headers | 4061.6 | 3905.8 |
| POST 1KB body | 1922.5 | 1867.3 |
| pipeline 10 reqs | 10602.0 | 10096.6 |

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

| workload | raw llhttp ns/op | adapter ns/op | adapter/raw |
| --- | ---: | ---: | ---: |
| simple GET | 425.3 | 1138.6 | 2.68x |
| 10 headers | 822.1 | 3813.1 | 4.64x |
| POST 1KB body | 456.2 | 1853.6 | 4.06x |

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

| workload | Pascal raw ns/op | C raw ns/op | Pascal no-op ns/op | C no-op ns/op | nextPas adapter ns/op |
| --- | ---: | ---: | ---: | ---: | ---: |
| simple GET | 222.0 | 279.4 | 221.5 | 138.2 | 623.0 |
| 10 headers | 779.5 | 561.5 | 785.7 | 544.7 | 3341.4 |
| POST 1KB body | 437.1 | 299.1 | 454.5 | 283.4 | 1429.1 |
| pipeline 10 reqs | 2203.0 | 1408.2 | 2159.2 | 1401.7 | 6273.4 |

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

Focused RED/GREEN:

```text
RED: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
H1 parser benchmark max iterations env and C llhttp comparator max iterations env failed:
bench_max_iters=2000 marker was missing; both still emitted 1000-iter rows.

GREEN: NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
9 total, 9 passed, 0 failed
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
| --- | ---: | ---: |
| simple GET | 1101.7 | 641.8 |
| 10 headers | 3808.5 | 3284.4 |
| POST 1KB body | 1848.6 | 1457.6 |
| pipeline 10 reqs | 11253.6 | 6201.2 |

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
| --- | ---: | ---: |
| simple GET | 641.8 | 644.2 |
| 10 headers | 3284.4 | 3333.1 |
| POST 1KB body | 1457.6 | 1404.6 |
| pipeline 10 reqs | 6201.2 | 6206.8 |

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

| workload | ns/op |
| --- | ---: |
| raw llhttp simple GET | 232.1 |
| noop cb simple GET | 221.3 |
| llhttp adapter simple GET | 617.7 |
| raw llhttp 10 headers | 823.7 |
| noop cb 10 headers | 806.1 |
| llhttp adapter 10 headers | 3380.4 |
| raw llhttp POST 1KB | 489.4 |
| noop cb POST 1KB | 454.1 |
| llhttp adapter POST 1KB | 1401.3 |
| raw llhttp pipeline pause-only | 2170.1 |
| noop cb pipeline | 2163.7 |
| llhttp adapter pipeline | 6205.7 |

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

| workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| Set+Get 5 headers | 828.2 | 784.3 |
| Set+Get 15 headers | 2665.1 | 2516.8 |
| Add 15 headers | 1783.5 | 1635.8 |

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

| workload | before req/s | after req/s |
| --- | ---: | ---: |
| Sink 16KB POST | 5005 | 5488 |

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

On 2026-06-05 local time, H1 request-side metadata moved from repeated server
lookup/token parsing to one parser-owned snapshot. The parser now builds
`TH1RequestMetadata` once at request headers-complete time and the server reuses
it for header policy, `100-continue`, dispatch Host validation, and request
keep-alive decisions.

This targets the hot path where the previous server-side logic repeated
`Get/GetAll/Trim/LowerCase/TryStrToInt64` for `Host`, `Expect`,
`Content-Length`, `Transfer-Encoding`, and `Connection`. The change does not
alter public HTTP facade APIs, response parsing, generated llhttp code, or the
existing request-side `Connection` exact-string keep-alive behavior.
The fast-parser snapshot also records whether `Content-Length` was actually
present, so accepted fast-path requests do not confuse an omitted header with
`Content-Length: 0`.

Focused benchmark:

```text
command=NEXTPAS_BENCH_FILTER='request metadata' make -C benchmarks/nextpas.core.http/bench_h1parser clean run
adapter cost: request metadata legacy expect+cl ns/op=1320.7
adapter cost: request metadata cached expect+cl ns/op=6.1
```

Focused validation:

```text
make -C tests/nextpas.core.http/test_http_h1parser clean test
91 total, 91 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_h1fast clean test
22 total, 22 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
274 total, 274 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
13 total, 13 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

The immediate conclusion is that request metadata caching removes a measurable
per-request policy/dispatch cost without changing wire contracts. The broader
H1 performance track should continue with adapter materialization rows before
returning to generated llhttp translation changes.

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

## Full-Chain Correlation: No-URL Keep-Alive Workload

On 2026-06-05 local time, the server comparison output gained an explicit
`workload=no_url` marker across nextPas, Go, and Rust comparator binaries. This
locks the benchmark interpretation: the current keep-alive comparison measures a
simple handler that does not read `Req.Url` / query parameters.

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

| impl | workload | completed | elapsed_ns | ns/op | req/s |
| --- | --- | ---: | ---: | ---: | ---: |
| nextPas | no_url | 50000 | 641366179 | 12827 | 77958 |
| Go `net/http` | no_url | 50000 | 2649511337 | 52990 | 18871 |
| Rust std-only | no_url | 50000 | 508013046 | 10160 | 98422 |

The result is directionally useful but not a stable throughput claim. Compared
with earlier local rows, nextPas remains in the same noise band and still trails
the Rust std-only comparator on this no-URL workload. The lazy request-target
microbenchmark win therefore does not yet prove a full-chain req/s win; the next
high-value work should profile or isolate remaining server/runtime costs that
sit outside URL projection.

## Full-Chain Correlation: URL Path Workload

On 2026-06-05 local time, the server comparison runner gained
`--workload no_url|url_path|adapter_no_url`, and the nextPas, Go, and Rust
comparator binaries now accept the same selector. `url_path` sends
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

| impl | workload | completed | elapsed_ns | ns/op | req/s |
| --- | --- | ---: | ---: | ---: | ---: |
| nextPas | url_path | 50000 | 628713623 | 12574 | 79527 |
| Go `net/http` | url_path | 50000 | 2628825324 | 52576 | 19019 |
| Rust std-only | url_path | 50000 | 441859972 | 8837 | 113158 |

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

| impl | workload | completed | elapsed_ns | ns/op | req/s |
| --- | --- | ---: | ---: | ---: | ---: |
| nextPas | adapter_no_url | 50000 | 634287816 | 12685 | 78828 |
| Go `net/http` | adapter_no_url | 50000 | 2891101718 | 57822 | 17294 |
| Rust std-only | adapter_no_url | 50000 | 521882998 | 10437 | 95806 |

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

| impl | workload | completed | elapsed_ns | ns/op | req/s |
| --- | --- | ---: | ---: | ---: | ---: |
| nextPas | response_1k | 50000 | 623561283 | 12471 | 80184 |
| Go `net/http` | response_1k | 50000 | 2718470762 | 54369 | 18392 |
| Rust std-only | response_1k | 50000 | 554412389 | 11088 | 90185 |

Calibration no-URL row with the same complete-response reader:

```text
command=benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload no_url
```

| impl | workload | completed | elapsed_ns | ns/op | req/s |
| --- | --- | ---: | ---: | ---: | ---: |
| nextPas | no_url | 50000 | 569950075 | 11399 | 87726 |
| Go `net/http` | no_url | 50000 | 2740141668 | 54802 | 18247 |
| Rust std-only | no_url | 50000 | 527895368 | 10557 | 94715 |

This suggests the current 1 KiB response writer/drain path is not the dominant
gap versus Rust std-only on this machine. nextPas remains close to the Rust
std-only comparator and far ahead of the Go comparator in these local rows.
Future rows should use the complete-response reader when comparing server
throughput.

## Benchmark Tooling: Multi-Run Server Comparison

On 2026-06-05 local time, `run_server_comparison.sh` and
`capture_server_comparison_snapshot.sh` gained `--runs N`. The server runner
now builds nextPas, Go, and Rust once, repeats each implementation `N` times,
prints `run=...` markers for raw rows, and emits a median summary:

```text
summary=http.server.keepalive
summary_impl=go runs=3 median_ns/op=55017.0 median_req/s=18176
summary_impl=nextpas runs=3 median_ns/op=11431.0 median_req/s=87476
summary_impl=rust runs=3 median_ns/op=9885.0 median_req/s=101153
```

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

22 total, 22 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

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
