# Task Plan: http H1 poll-driven IdleTimeout parity

## Goal

把 `nextpas.core.http` 当前最具体、最能影响真实 evented backend 正确性的缺口补齐一刀：

- 为 `TH1ServerConnectionState` 的 poll-driven request parse 路径补上
  read-side `IdleTimeout` / `WakeDeadline` parity
- 先用 focused RED 证明“第一个 request byte 到达前的 idle wait”确实没被 timeout
  机制覆盖
- 再做最小生产修复，不扩 public API，不顺手重构
- 用 focused test + 轻量 contract gate 收口，并保留 heaptrc 无泄漏证据

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 先写 RED：给 `test_http_server` 增加 poll-driven idle-read timeout focused test
- [x] 最小修改 `src/nextpas.core.http.impl.h1.pas`，补 read-side deadline 生命周期
- [x] 跑 focused `test_http_server`
- [x] 跑轻量 HTTP module gate `test_http_contract`
- [x] 更新必要 coverage 文档与控制文件
- [ ] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.http.impl.h1.pas`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改 facade/public API
- 不跑全量测试

## Intended outcome

- poll-driven H1 session 不再只对 write-side stalled drain 暴露 `WakeDeadline`
- 初始 request idle wait 也会暴露有限 read-side deadline，并在 timeout 后安全关闭
- `WakeDeadline` 生命周期与已有 write-timeout state machine 不冲突
- 下一刀可以更专注在 mid-request stall characterization，或回到 malformed raw-wire
  chunked security proof
