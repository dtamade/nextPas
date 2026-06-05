# Task Plan: H1 fast parser Content-Length hot-path trim

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批 C llhttp comparator 证明 Pascal translated llhttp 与 adapter/materialization
都需要继续优化；本轮聚焦当前 server fast path 的一个明确重复成本：
`FastParseRequest` 在 header scan 中已经识别 `Content-Length`，但随后又通过
`Headers.Get('Content-Length')` 做一次额外 lookup / normalization / scan。

本轮不改公开 API，不改 HTTP wire contract，不写 inbox。工作性质是窄生产性能修正
加 focused regression。

## Checklist

- [x] 复核 `docs/design-conventions.md`、HTTP benchmark/coverage/control 文件和 `git status`。
- [x] 建立基线：`bench_h1parser` 显示 fast path 当前比 adapter 慢，尤其 simple GET / 10 headers / pipeline。
- [x] 做负收益实验：禁用 server fast path 后 `bench_server` 下降，撤销该实验，不提交。
- [x] 新增 invalid `Content-Length` fast fallback focused test。
- [x] 实现 `Content-Length` scan-time parse/cache，删除后续 `Headers.Get('Content-Length')`。
- [x] 跑 `test_http_h1fast` focused gate + heaptrc。
- [x] 跑 `bench_h1parser`，确认 fast parser rows 有方向性改善。
- [x] 跑 `test_http_server` focused gate + heaptrc。
- [x] 更新 `findings.md`、`progress.md`、`docs/http/BENCHMARKS.md`。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.impl.h1.fast.pas`
- `tests/nextpas.core.http/test_http_h1fast/test_http_h1fast.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

`FastParseRequest` 的重复 `Content-Length` lookup 可以安全删除，parser microbench
显示 fast rows 改善：simple GET `856.4 -> 754.9 ns/op`，10 headers
`3679.0 -> 3429.8 ns/op`，POST 1KB `1500.2 -> 1374.2 ns/op`，pipeline
`8685.5 -> 7581.2 ns/op`。server full-chain 单次 benchmark 噪声较大，本轮不声明
server req/s 已提升。

## Intended outcome

- 减少 fast parser 自身重复 header lookup 成本。
- 保留 server fast path，不做负收益禁用。
- 为下一步更大的 lazy-header / adapter materialization 优化打基础。
