# Task Plan: H1 server header-policy one-shot evaluation

## Goal

继续推进 `HttpServer 完成` 主线中的 `6/6 benchmark/performance` 阶段。用户提出
Pascal translated llhttp 可能存在性能问题；当前已有 raw/no-op/adapter 分层 benchmark 显示
nextPas 当前 H1 栈内的第一瓶颈仍在 adapter/server materialization，而不是 translated llhttp
state machine 本身。

本轮先落一个更靠近 server hot path 的窄优化：在 request headers 首次完成时一次性完成
server-side header policy 判定，避免 body 读取循环中重复执行 `Host` / `Expect` /
declared `Content-Length` / header-size 检查。C llhttp comparator 作为下一批独立 proof track
保留，不阻塞本轮已确认的高收益修正。

## Checklist

- [x] 复核 `docs/design-conventions.md`、HTTP coverage/control 文件和 `git status`。
- [x] 用子代理独立审视 Pascal llhttp vs C llhttp comparator 方案。
- [x] 跑 `bench_h1parser`，确认 raw/no-op/adapter 分层仍指向 materialization。
- [x] 给 `bench_fullchain` 增加 16KB body sink 场景。
- [x] 修复 `AdvancePollRequestParse` 的 `case` block 缺失结束符，恢复 server/fullchain 构建。
- [x] 实现 `HeaderPolicyErrorStatus`，headers-complete 时一次性执行 header policy。
- [x] threaded 与 poll/epoll 两条 server path 使用同一 helper。
- [x] 跑 `bench_fullchain` baseline / confirmation。
- [x] 跑 `test_http_server` focused gate + heaptrc。
- [x] 跑 `test_http_security` focused gate + heaptrc。
- [x] 更新 benchmark/control 文档。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.impl.h1.pas`
- `benchmarks/nextpas.core.http/bench_fullchain/bench_fullchain.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 大 body / Expect / body-stall 相关 server hot path 不再在每个 read-loop 重复拆 header policy。
- threaded 与 epoll backend 的错误状态、interim `100 Continue`、MaxBodySize、MaxHeaderSize 语义保持一致。
- C llhttp comparator 路线固定到下一批，避免混入本批生产优化。
