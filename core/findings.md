# Findings: HTTP parser body buffer reuse

## Scope

本轮继续压低 `IH1Parser` adapter materialization 成本，聚焦 body callback 和 parser Reset 的动态数组分配。
这不是公开 API 扩展，也不是 correctness 修复；它是内部 storage refactor，必须由 focused guard
证明不改变现有 parser behavior。

## Confirmed truths

### 1. Existing behavior already allowed the intended Reset/body semantics

新增的 `TestResetAndReparse` guard 在生产修改前已经通过，因此这条不是 RED 行为修复，而是 refactor
防回归证据。guard 覆盖：

- 第一次 parse 为 `POST /first`，body 为 `abcdefghi`。
- Reset 后第二次 parse 为更短的 `POST /second`，body 为 `xy`。
- `GetBodySize` / `GetBody` 只暴露第二次有效 body，不包含旧字节。
- Reset 前创建的 `NewBodyReader` 在 Reset/reparse 后仍读取旧 body 快照。

### 2. Parser body buffer can be reused without leaking stale body bytes

`TH1Parser` 现在维护：

- `FBody`: parser-owned capacity buffer。
- `FBodySize`: 当前 message 的有效 body 长度。

`CbOnBody` 先按几何增长确保 capacity，再从 `FBodySize` offset append。`Reset` 只把 `FBodySize`
清零，不释放 `FBody` capacity。`GetBody` / `GetBodySize` 只看有效长度。

关键约束是 `NewBodyReader`：它不能直接共享可复用的 `FBody`，否则 Reset/reparse 会污染旧 reader。
当前实现会复制有效区间生成快照，再交给 `TSharedBytesReader`。

### 3. Benchmark projection is narrow but positive for body workload

上一批 header container reuse 文档 baseline：

| llhttp adapter workload | previous ns/op |
| --- | ---: |
| simple GET | 641.8 |
| 10 headers | 3284.4 |
| POST 1KB body | 1457.6 |
| pipeline 10 reqs | 6201.2 |

本轮 confirmation：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser run
```

| llhttp adapter workload | previous ns/op | after ns/op |
| --- | ---: | ---: |
| simple GET | 641.8 | 644.2 |
| 10 headers | 3284.4 | 3333.1 |
| POST 1KB body | 1457.6 | 1404.6 |
| pipeline 10 reqs | 6201.2 | 6206.8 |

结论：body buffer reuse 主要投射到 POST body workload；simple/pipeline 基本持平，10 headers 的轻微回退属于
无 body workload 的本机噪声范围。这轮不能夸大为全局性能突破，但它移除了一个明确的 repeated body
allocation 热点。

### 4. Subagent review agrees on llhttp attribution boundary

`gpt-5.5 xhigh` 只读子代理结论与本地证据一致：当前没有证据说明 Pascal translated llhttp 是
nextPas H1 parser stack 内的主瓶颈。raw no-callback rows 和 adapter rows 的差距仍指向
URL/header/body materialization、header container、TE validation 等 adapter 成本。

但这不是“Pascal 翻译本体没有性能问题”的最终证明。严谨比较需要最小 C llhttp comparator：

- C llhttp raw/no-callback vs Pascal translated raw/no-callback。
- C llhttp no-op callbacks vs Pascal translated no-op callbacks。
- Pascal adapter stage rows：count-only、URL-only、header string-only、headers.Add-only、body copy-only、TE validation-only。
- raw pipeline row，补齐 keep-alive/reset 场景的公平对照。
- generated shape comparator，比较当前翻译形状和更紧凑 table/action 形状。

## Remaining gaps / risks

- `bench_h1parser` 仍是小样本本机微基准；用于方向判断，不声明最终 Go/Rust parity。
- 目前 raw translated llhttp 只有 no-callback rows，还没有 C llhttp 对照，因此不能排除 Pascal 翻译本体相对 C
  仍有差距；只能说当前 nextPas stack 内 adapter 成本更高。
- body buffer reuse 会保留旧 body bytes 在 parser-owned capacity 内，但不会通过 `GetBody` /
  `NewBodyReader` 暴露。若未来要支持敏感数据主动清零，需要单独设计安全/性能 tradeoff。

## Next optimization target

1. 继续 adapter materialization：优先做 header/value storage 和 request metadata cache，减少
   `Content-Length` / `Transfer-Encoding` / `Expect` 重复字符串解析。
2. 为“Pascal translated llhttp 是否慢于 C llhttp”补严谨 comparator：最小 C llhttp no-callback / callback
   benchmark，和当前 raw translated llhttp 同 payload 对齐。
3. server parity 继续用 focused benchmark，不回到全量测试驱动的低效节奏。
