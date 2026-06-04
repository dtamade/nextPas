# Findings: H1 parser callback-cost diagnostics

## Scope

本轮是 benchmark 诊断增强，不改生产 HTTP parser/server 行为，也不改 public API。目标是拆分
Pascal translated llhttp 的状态机成本、callback dispatch 成本，以及 `IH1Parser` adapter
materialization 成本。

## Confirmed truths

### 1. Existing benchmark could not separate callback dispatch from materialization

上一批已有 raw no-callback rows 和 full adapter rows。它能说明 adapter 比 raw 状态机慢很多，
但还不能回答中间层问题：是 Pascal callback dispatch 本身很贵，还是 callback 里构建 string、
`IHttpHeaders`、body buffer 和 TE validation 很贵。

本轮新增的 no-op callback rows 注册 `on_url`、`on_header_field`、`on_header_value`、`on_body`、
`on_headers_complete`、`on_message_complete`，但只做计数，不分配 string/header/body。

### 2. Pipeline/reset raw cost is now visible

新增 `raw llhttp: pipeline pause-only (10 reqs)`。它只注册 `on_message_complete`，并返回
`HPE_PAUSED`，让 benchmark 像 adapter pipeline 一样按 message boundary 消费并 reset。

这比“整段 pipeline 一次 execute”更接近 server keep-alive / parser reset 场景。

### 3. Confirmation run still points to adapter materialization

验证命令：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

关键 rows：

| workload | ns/op |
| --- | ---: |
| raw llhttp simple GET | 232.1 |
| noop cb simple GET | 221.3 |
| adapter simple GET | 617.7 |
| raw llhttp 10 headers | 823.7 |
| noop cb 10 headers | 806.1 |
| adapter 10 headers | 3380.4 |
| raw llhttp POST 1KB | 489.4 |
| noop cb POST 1KB | 454.1 |
| adapter POST 1KB | 1401.3 |
| raw llhttp pipeline pause-only | 2170.1 |
| noop cb pipeline | 2163.7 |
| adapter pipeline | 6205.7 |

simple GET 的 raw/no-op 短请求 row 仍有本机微基准噪声，不单独作为结论依据。10 headers、POST 1KB
和 pipeline 的方向更稳定：no-op callback 成本接近 raw/pause-only，远低于 full adapter。

结论：当前没有证据说明 Pascal translated llhttp callback dispatch 是主瓶颈；瓶颈仍集中在
adapter materialization。

## Remaining gaps / risks

- 仍没有 C llhttp comparator，因此不能证明 Pascal translated llhttp 与 C llhttp parity。
- `bench_h1parser` 仍受 `MAX_ITERS = 1000` 和本机短请求计时噪声影响；需要看多 row、多次运行的方向，而不是单个 simple GET 数值。
- no-op callback 只覆盖 dispatch + minimal counter，不覆盖真实 Pascal string append、header normalization、metadata validation。

## Next optimization target

1. 继续优化 adapter materialization，优先拆 `THttpHeaders.Add` normalize/validate 成本，或给 parser/server 添加
   request metadata cache，减少 `Content-Length` / `Transfer-Encoding` / `Expect` 重复解析。
2. 若继续追问翻译本体，则补 C llhttp FFI raw/no-op callback comparator，保持同 payload、同 reset/pause 语义。
3. 不建议现在重写 translated llhttp 形状；先把已确认的 materialization 热点压下去。
