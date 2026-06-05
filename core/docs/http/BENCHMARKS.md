# nextpas.core.http Benchmarks

This page records the current HTTP server benchmark harness and one local
snapshot. Treat the numbers as evidence for this machine and toolchain, not as
a permanent ranking across platforms.

## Run the Server Comparison

Run the comparison harness:

```sh
benchmarks/nextpas.core.http/run_server_comparison.sh \
  --requests 20000 --threads 4 \
  --output build/projects/nextpas.core.http/server_comparison/report.txt
```

Capture a Markdown snapshot with environment metadata:

```sh
benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh \
  --requests 20000 --threads 4 \
  --output build/projects/nextpas.core.http/server_comparison/snapshot.md
```

The comparison currently covers one HTTP/1.1 keep-alive hello-world workload.
It does not cover TLS, request bodies, WebSocket, router/middleware full-chain
cost, `epoll`, or an async Rust server. The Rust comparator is a std-only
microbaseline; add a Hyper/Tokio comparator before treating Rust ecosystem
performance as represented.

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

The raw simple-GET row is especially sensitive to the current benchmark
runner's `MAX_ITERS = 1000` cap, so these numbers are directional. The
classification remains stable: complete adapter parsing is materially slower
than raw state-machine execution.

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

Treat these rows as local directional evidence. The current runner still caps
iterations at `MAX_ITERS = 1000`; the formal benchmark round should improve the
runner before making cross-machine or cross-toolchain claims.

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
