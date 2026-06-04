# Findings: HTTP llhttp raw translation performance triage

## Scope

本轮验证用户提出的风险：`llhttp` 的 Pascal 翻译移植是否本身就是主要性能问题。做法是把
`bench_h1parser` 拆出 raw translated llhttp no-callback rows，与现有 `IH1Parser` adapter 和
fast path rows 对比。

## Confirmed truths

### 1. Raw translated llhttp is not the current dominant cost

运行：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

当前 raw translated llhttp no-callback rows：

| workload | raw translated llhttp ns/op |
| --- | ---: |
| simple GET | 425.3 |
| 10 headers | 822.1 |
| POST 1KB body | 456.2 |

对应 `IH1Parser` adapter rows：

| workload | raw ns/op | adapter ns/op | adapter/raw |
| --- | ---: | ---: | ---: |
| simple GET | 425.3 | 1138.6 | 2.68x |
| 10 headers | 822.1 | 3813.1 | 4.64x |
| POST 1KB body | 456.2 | 1853.6 | 4.06x |

结论：当前证据不支持“主要慢在 Pascal 翻译状态机本体”。更大的成本在 `IH1Parser` adapter
materialization：URL/header/body 字符串组装、`IHttpHeaders` 对象分配/填充、以及 headers-complete
后的语义校验。

### 2. Fast path still only partially bypasses adapter cost

同一次 benchmark：

| workload | adapter ns/op | fast path ns/op | delta |
| --- | ---: | ---: | ---: |
| simple GET | 1138.6 | 843.0 | -26.0% |
| 10 headers | 3813.1 | 3467.6 | -9.1% |
| POST 1KB body | 1853.6 | 1474.5 | -20.4% |
| pipeline 10 reqs | 9924.9 | 8464.3 | -14.5% |

fast path 有收益，但仍会创建 high-level headers/path 等对象；它不是零拷贝 parser，也不是最终
Go/Rust 级 server 性能方案。

### 3. No in-repo C llhttp comparator exists yet

仓库里只有 `src/nextpas.core.http.impl.h1.llhttp.pas`，没有 C llhttp 或 native comparator。
因此本轮不能声明 Pascal translation 与 C llhttp 已经持平，只能确认：在当前 nextPas H1 parser
栈里，adapter 层成本明显大于 raw translated state machine 成本。

## Remaining gaps / risks

- `TBenchRunner` 当前 `MAX_ITERS = 1000`，parser rows 是小样本本机微基准；趋势足以指导下一刀，
  但正式 benchmark 轮应提高采样质量。
- raw no-callback 只证明状态机执行成本，不覆盖真实 callback cost；真实 server 仍必须保留完整
  malformed framing / transfer-coding correctness。
- 下一批如果优化 adapter，不能牺牲现有 `test_http_h1parser` / `test_http_security` malformed 语义。

## Next optimization target

优先级应从“重写/怀疑 llhttp Pascal 翻译”转向：

1. `IH1Parser.Reset` / per-request `NewHttpHeaders` allocation reduction。
2. header materialization 的 span/capacity 策略，减少 URL/header value string reallocation。
3. server ingress metadata cache，让 `Expect` / `Transfer-Encoding` / `Content-Length` 等语义只解析一次。
4. 等 adapter 物化成本压低后，再补 C llhttp comparator 或 generator-level translation tuning。
