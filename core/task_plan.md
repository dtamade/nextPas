# Task Plan: Pascal llhttp raw-gap diagnosis

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦用户提出的疑点：Pascal-translated llhttp 是否存在 raw state-machine 性能差距。

本轮不改 HTTP public facade API、不改 wire contract、不写
`docs/nextpas.core.http.inbox.md`，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`。

## Checklist

- [x] 复核设计规范、HTTP coverage、benchmark docs、控制文件与 git status。
- [x] 使用 focused row 复测 Pascal raw llhttp 与 C raw llhttp 的 10-header 代表行。
- [x] 跑单行 flag matrix，确认 CPU/FPU flags 与 extra FPC opts 是否能追平 C raw row。
- [x] 检查 generated Pascal llhttp 与 C llhttp 的结构差异，分类最可能的 raw-gap 来源。
- [x] 确认本机 `perf` 是否可用于 cycles/branch/cache 证据。
- [x] 开只读 `gpt-5.5 xhigh` 子代理做第二视角审计。
- [x] 更新 benchmark 文档与控制文件，固定本轮证据和下一步路线。
- [x] 跑 focused benchmark smoke / diff check。
- [ ] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

如果后续需要新增或修改 benchmark 工具，只能在新的 RED/GREEN 小切片中处理：

- `benchmarks/nextpas.core.http/bench_h1parser/*`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`

## Current conclusion

用户怀疑是合理的：fresh focused rows 显示 Pascal raw llhttp 10-header 约
`766.5 ns/op`，C raw llhttp 约 `525.0 ns/op`，差距约 `1.46x`。

但本轮证据仍不支持直接手改 generated state machine：

- flag matrix 只能把 Pascal row 小幅压到约 `750.6 ns/op`，仍无法追平 C。
- `perf` 在本机受 `perf_event_paranoid=3` 限制，不可采集 cycles / branch / cache counters。
- 当前 full adapter/materialization 成本仍比 raw state-machine gap 更大。

## Intended outcome

- 把 Pascal raw-gap 作为独立性能轨道固定到 benchmark docs。
- 下一步先用 perf 可用环境或 codegen 级证据定位 state-machine 差距。
- 生产优化继续优先处理 adapter/materialization 中已证明的高倍数成本。
