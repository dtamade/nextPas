# Findings: HTTP parser header reuse fast path

## Scope

本轮继续压低 `IH1Parser` adapter materialization 成本。上一批 raw llhttp triage 已证明状态机本体
不是主要瓶颈；本轮针对 `TH1Parser.Reset` 每次重建 `IHttpHeaders` 的分配路径。

## Confirmed truths

### 1. Existing public headers API lacked an explicit reuse contract

`IHttpHeaders` 旧接口有 `Set_ / Add / Get / GetAll / Has / Del / Count / ForEach / Clone`，但没有
`Clear`。如果 parser 想复用 header container，只能依赖实现细节或继续分配新对象。

RED proof：

```sh
make -C tests/nextpas.core.http/test_http_headers clean test
```

失败点：

```text
test_http_headers.lpr(207,6) Error: Identifier idents no member "Clear"
```

### 2. Header Clear contract is now direct and reusable

新增 focused test 覆盖：

- `Clear` 后 `Count = 0`。
- `Get / GetAll / Has / ForEach` 不暴露 stale entries。
- 同一个 `IHttpHeaders` 实例 Clear 后可以继续 `Add / Set_ / GetAll`。

这比只在 parser 内部写 private reset 更好：它把 reusable mutable headers container 变成明确 API，
后续 response writer / request metadata cache 也能使用同一契约。

### 3. Parser Reset can reuse headers without stale header leakage

`TH1Parser.Reset` 现在调用 `FHeaders.Clear`，而不是 `FHeaders := NewHttpHeaders`。`test_http_h1parser`
的 `Reset and reparse` 现在额外锁住第二次 parse 的 `Host` 会替换第一次请求 header，不会串旧值。

这是一项性能取舍：`IH1Parser` 是实现层接口，不是 HTTP facade 的 request snapshot contract。Reset
后继续持有旧 `LP.GetHeaders` 引用不再应被视为稳定快照；调用方需要保留快照时应显式 `Clone`。

### 4. Benchmark projection

修改前 baseline：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| llhttp adapter workload | before ns/op |
| --- | ---: |
| simple GET | 1101.7 |
| 10 headers | 3808.5 |
| POST 1KB body | 1848.6 |
| pipeline 10 reqs | 11253.6 |

修改后 confirmation：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser run
```

| llhttp adapter workload | before ns/op | after ns/op |
| --- | ---: | ---: |
| simple GET | 1101.7 | 641.8 |
| 10 headers | 3808.5 | 3284.4 |
| POST 1KB body | 1848.6 | 1457.6 |
| pipeline 10 reqs | 11253.6 | 6201.2 |

pipeline row 改善最大，符合 repeated parser reset / keep-alive 场景减少 per-request headers object
allocation 的预期。

## Remaining gaps / risks

- `IHttpHeaders.Clear` 是 public API 扩展；本轮已有 focused unit test 和 heaptrc，但需要在
  API coverage matrix 记录。
- parser `GetHeaders` 返回的是 parser-owned mutable container，不是 immutable snapshot。后续如果要公开
  H1 parser 作为稳定用户 API，需文档化 Reset 生命周期或提供 snapshot helper。
- benchmark runner 仍是小样本本机微基准；本轮只作为方向性证据，不声明最终 Go/Rust parity。

## Next optimization target

继续沿 adapter materialization 降本路线：

1. 考虑复用 `FBody` buffer 或改成 body span/reader ownership，避免请求 body copy。
2. 针对 header field/value callback 做 span/capacity 优化，减少字符串 realloc。
3. server ingress metadata cache：把 `Content-Length` / `Transfer-Encoding` / `Expect` 语义解析结果缓存到 request context。
