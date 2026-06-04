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
