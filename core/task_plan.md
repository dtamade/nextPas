# Task Plan: http H1 poll-driven mid-request IdleTimeout proof

## Goal

在上一轮已经补齐 poll-driven H1 初始 idle wait read deadline 的基础上，
继续把 request-side timeout 契约往前推进一刀：

- focused 锁定 partial mid-request stall 的 current truth
- 优先覆盖 `Content-Length` body stall 与 chunked trailer stall
- 顺手锁定一个关键性能/语义点：partial request progress 不会重置 read deadline
- 如果现有实现已经满足契约，就不做生产改动，只补测试与文档证据

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 先写 focused tests：partial fixed-length body stall / partial chunked trailer stall
- [x] 跑 focused `test_http_server`
- [x] 判断是否需要生产修复：本轮不需要
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改生产代码
- 不跑全量测试

## Intended outcome

- poll-driven request-side `IdleTimeout` 不再只停留在 “首字节前 idle wait” 的 focused proof
- partial fixed-length body stall 与 partial chunked trailer stall 也有 focused timeout evidence
- `WakeDeadline` / read deadline 语义被进一步固定为 request-parse 周期 deadline，
  而不是“每次有进度就续期”的 per-chunk idle timer
- 下一刀可以回到 malformed raw-wire chunked security proof，而不是继续空转在
  synthetic timeout widening
