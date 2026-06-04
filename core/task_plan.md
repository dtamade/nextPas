# Task Plan: HTTP parser body buffer reuse

## Goal

继续推进 `HttpServer 完成` 主线中的 `6/6 benchmark/performance` 阶段。当前
raw translated llhttp 诊断显示：在 nextPas 当前 H1 parser stack 内，主要成本仍来自
`IH1Parser` adapter materialization，而不是裸 llhttp 状态机执行。本轮延续该方向，聚焦
request/response body materialization。

旧实现中 `CbOnBody` 每次 body callback 都对 `FBody` 按有效长度重新 `SetLength`，
`TH1Parser.Reset` 又直接释放 body array。目标是在不改变 `IH1Parser` public behavior 的前提下，
让 parser-owned body buffer 可复用，并保留 `NewBodyReader` 的快照语义。

## Checklist

- [x] 复核 `docs/design-conventions.md`、HTTP coverage/control 文件和 `git status`。
- [x] 保留并验证 `Reset and reparse` body guard：短 body 不暴露旧字节，旧 reader 在 Reset 后仍是快照。
- [x] 将 `TH1Parser` body storage 改为 reusable capacity buffer + effective `FBodySize`。
- [x] 确保 `GetBody` / `GetBodySize` / `NewBodyReader` 只暴露有效 body 区间。
- [x] 跑 `test_http_h1parser` focused gate + heaptrc。
- [x] 跑 `test_http_h1fast` differential gate + heaptrc。
- [x] 跑 `bench_h1parser` after + confirmation。
- [x] 用 `gpt-5.5 xhigh` 子代理只读审视 Pascal translated llhttp 性能归因。
- [x] 更新 benchmark/control 文档。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.impl.h1.parser.pas`
- `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- parser Reset 不再释放 body capacity，repeated parse / POST body path 减少动态数组 resize。
- body reader snapshot contract 明确被 focused test 锁住，避免 buffer reuse 引入 stale/mutated body 暴露。
- benchmark 记录这轮 body buffer reuse 的真实收益边界：主要影响 body workload，不夸大为整体 parser/server parity。
