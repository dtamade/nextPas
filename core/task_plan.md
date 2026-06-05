# Task Plan: H1 fast parser policy flags

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已经删除 fast parser 内部 `Content-Length` 的重复 lookup；本轮继续减少
server fast path 成功判定中的重复 header lookup。`FastParseRequest` 在扫描 header
时本来就能看到 `Host` / `Connection` / `Expect` / `Transfer-Encoding`，因此把这些
policy facts 直接暴露给 `TryUseFastRequestParser`，避免成功路径后再执行多次
`Headers.Get(...)`。

本轮不改公开 HTTP facade API，不改 wire contract，不写 inbox。

## Checklist

- [x] 复核当前 git status、HTTP benchmark/control 文件和上一批结论。
- [x] 新增 focused RED：`TFastParseResult` 缺少 policy flag 字段导致 `test_http_h1fast` 编译失败。
- [x] 给 `TFastParseResult` 增加 `HasHost` / `HasConnection` / `HasExpect` / `HasTransferEncoding`。
- [x] 在 fast header scan 中直接设置 policy flags。
- [x] `TryUseFastRequestParser` 使用 policy flags，删除 4 次 server fast-path `Headers.Get(...)` 判定。
- [x] 跑 `test_http_h1fast` focused gate + heaptrc。
- [x] 跑 `test_http_server` focused gate + heaptrc。
- [x] 跑 `bench_h1parser` / `bench_server` sanity，不把噪声结果写成稳定吞吐结论。
- [x] 更新 `findings.md`、`progress.md`、`docs/http/BENCHMARKS.md`。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.impl.h1.fast.pas`
- `src/nextpas.core.http.impl.h1.pas`
- `tests/nextpas.core.http/test_http_h1fast/test_http_h1fast.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

server fast path 不再为了判断是否可用而做 `host` / `connection` / `expect` /
`transfer-encoding` 四次 `IHttpHeaders.Get` lookup。语义由 `test_http_h1fast`
和 `test_http_server` 锁住。`bench_server` 当前仍有明显调度噪声，本轮只记录方向性
sanity，不声明稳定 server throughput 提升。

## Intended outcome

- 保留 server fast path。
- 减少 fast path 成功判定的 post-parse header lookup。
- 为后续 lazy headers / policy snapshot 继续降 adapter/materialization 成本铺路。
