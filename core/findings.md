# Findings: H1 fast parser policy flags

## Scope

本轮是 `nextpas.core.http` H1 server fast path 的窄性能修正，不改公开 HTTP facade
API，不改 request/response wire contract。目标是减少 fast parser 成功后 server
integration 再次扫描 headers 的成本。

## RED evidence

新增 focused test 后先跑：

```sh
make -C tests/nextpas.core.http/test_http_h1fast clean test
```

失败点：

```text
Identifier idents no member "HasHost"
Identifier idents no member "HasConnection"
Identifier idents no member "HasExpect"
Identifier idents no member "HasTransferEncoding"
```

这证明当前 `TFastParseResult` 没有把 fast scan 已经知道的 server policy facts 暴露出来。

## Implemented change

新增 `TFastParseResult` fields：

- `HasHost`
- `HasConnection`
- `HasExpect`
- `HasTransferEncoding`

`FastParseRequest` 在 header scan 阶段直接设置这些 flags：

- `Host` 只有 value 非空才算 `HasHost=True`，保持原先 server fast path 必须有非空
  Host 的窄入口。
- `Connection` 和 `Expect` 一出现就置 flag，server fast path 继续 fallback。
- `Transfer-Encoding` 一出现就置 flag 并继续 fallback 到 llhttp/server validation。

`TryUseFastRequestParser` 现在使用这些 flags 判定能否走 server fast path，不再做：

```pascal
Headers.Get('host')
Headers.Get('connection')
Headers.Get('expect')
Headers.Get('transfer-encoding')
```

## Verification

- Focused fast parser gate:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `20 total, 20 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Focused server gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Benchmark sanity

Parser benchmark:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

Representative fast rows:

| workload | ns/op |
| --- | ---: |
| simple GET | 757.2 |
| 10 headers | 3554.1 |
| POST 1KB | 1394.2 |
| pipeline 10 reqs | 7821.6 |

Server benchmark sanity:

```sh
make -C benchmarks/nextpas.core.http/bench_server clean run
build/projects/nextpas.core.http/bench_server/bench_http_server --requests 20000 --threads 4
```

Rows:

- clean run: `96699 req/s`
- immediate second run: `86312 req/s`

Conclusion: this batch removes definite repeated lookups from the server fast path, but the current
server benchmark runner is too noisy to claim a stable full-chain throughput win from this slice alone.

## Remaining gaps / risks

- Fast parser still eagerly materializes `IHttpHeaders`; this remains the larger cost.
- `TFastParseResult` is internal implementation surface, but tests consume it directly; keep future
  changes in `test_http_h1fast`.
- The next larger step should be lazy headers or a dedicated policy snapshot so simple handler paths
  avoid constructing full header collections until actually needed.
