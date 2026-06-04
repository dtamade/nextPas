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
