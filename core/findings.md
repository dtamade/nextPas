# Findings: H1 server header-policy one-shot evaluation

## Scope

本轮是 HTTP server hot-path performance + build-correctness slice，不改公开 API，不改
request/response wire contract。目标是减少 body 读取循环中的重复 header metadata 解析，并把
Pascal translated llhttp 的性能疑点拆成独立 benchmark proof track。

## Confirmed truths

### 1. 当前证据不支持把 Pascal llhttp state machine 列为第一瓶颈

本轮重新跑：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

关键行：

| workload | ns/op |
| --- | ---: |
| raw llhttp simple GET | 308.9 |
| noop cb simple GET | 229.5 |
| llhttp adapter simple GET | 623.0 |
| raw llhttp 10 headers | 822.8 |
| noop cb 10 headers | 785.1 |
| llhttp adapter 10 headers | 3346.3 |
| raw llhttp POST 1KB | 455.9 |
| noop cb POST 1KB | 454.5 |
| llhttp adapter POST 1KB | 1428.8 |
| raw llhttp pipeline pause-only | 2171.3 |
| noop cb pipeline | 2170.8 |
| llhttp adapter pipeline | 6295.9 |

这只能说明 nextPas 当前 H1 stack 内第一瓶颈在 adapter/server materialization；不能证明 Pascal
translation 与 C llhttp 性能等价。严格证明仍需要 same-payload C llhttp comparator。

### 2. 子代理独立审视结论一致

`gpt-5.5 xhigh` 子代理只读审视后建议：

- 最小 C comparator 应固定 llhttp `9.4.1`，镜像 raw/no-op/pipeline rows。
- 不依赖系统 `pkg-config llhttp`，优先用 `LLHTTP_ROOT` 指向固定源码/静态库。
- 在不做 C comparator 前，最高收益仍是 request metadata / header-policy cache。

### 3. Server/fullchain 构建暴露现有 poll path syntax blocker

新增 `bench_fullchain` 场景后先跑 baseline：

```sh
make -C benchmarks/nextpas.core.http/bench_fullchain clean run
```

第一次构建失败在 `src/nextpas.core.http.impl.h1.pas:1807`，根因是
`TH1ServerConnectionState.AdvancePollRequestParse` 的 `case LReadResult of` 缺少结束 `end;`，
导致后续 `PollEvents` 被解析成非法嵌套函数。补上 `case` block 结束符后，server/fullchain 构建恢复。

### 4. Header policy 旧路径在 body read loop 中重复解析

旧路径在 headers 完成后，每次继续读取 body 都会重复执行：

- `FParser.GetHeaders.Get('host')`
- `RequestHasUnsupportedExpectations(FParser)` -> `GetAll('expect')` + comma token split + lowercase
- `DeclaredContentLengthExceedsLimit(...)` -> `Get('content-length')` + trim + int parse
- `ShouldSendContinueResponse(...)` -> `Expect` + declared body 判定

这些判定只依赖 headers-stage metadata，不需要随 body progress 重复计算。

### 5. New one-shot helper preserves contract

新增 `HeaderPolicyErrorStatus`：

- headers-size check 仍优先于 parser error。
- parser error 仍映射到 `400` / `501`。
- HTTP/1.1 missing `Host` 仍返回 `400`。
- unsupported `Expect` 仍返回 `417`，并且不会误发 `100 Continue`。
- declared `Content-Length` 超过 `MaxBodySize` 仍早返回 `413`。

threaded `Run` 与 poll/epoll `AdvancePollRequestParse` 都只在 headers 首次完成时调用该 helper；
body-size progress、trailer-size progress、parser error progress 仍保留在循环中继续检查。

## Benchmark projection

`bench_fullchain` 新增 16KB body sink 场景，用来暴露多 read-loop body ingress 的 server overhead。

Baseline after build-fix / before header-policy one-shot:

```sh
make -C benchmarks/nextpas.core.http/bench_fullchain clean run
```

| workload | elapsed | req/s |
| --- | ---: | ---: |
| Plaintext GET | 711 ms | 7023 |
| JSON GET | 722 ms | 6923 |
| Echo 1KB POST | 861 ms | 5806 |
| Sink 16KB POST | 998 ms | 5005 |
| Param GET | 684 ms | 7305 |

Confirmation after header-policy one-shot:

```sh
make -C benchmarks/nextpas.core.http/bench_fullchain clean run
```

| workload | before req/s | after req/s |
| --- | ---: | ---: |
| Sink 16KB POST | 5005 | 5488 |

Only the 16KB sink row should be treated as the signal for this slice. Other rows are short local
full-chain measurements and showed normal scheduler/network noise.

## Remaining gaps / risks

- C llhttp comparator is still missing; current evidence is stack-internal, not language parity proof.
- `HeaderPolicyErrorStatus` deliberately keeps header-derived checks one-shot, but body/trailer progress checks must remain per-read.
- `bench_fullchain` is a local directional benchmark, not a permanent Go/Rust ranking.

## Next optimization target

1. Build the C llhttp comparator proof track to directly answer Pascal translation parity.
2. Then consider parser/server request metadata cache deeper in the adapter, especially transfer-coding and body-reader copy paths.
3. Keep benchmark runner scoped; avoid full-suite sweeps unless a public/API contract changes.
