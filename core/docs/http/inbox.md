# nextpas.core.http Inbox

最近更新：2026-07-16

## 控制面状态

- Owner lane：`.worktrees/http` / 分支 `http`
- 当前阶段：G2/G3/G4 收口；H3 blocked on QUIC
- 权威文档：
  - 完成度与切片队列 → `GOAL_TREE.md`
  - 稳定架构事实 → `ARCHITECTURE.md`
  - 公开契约 → `CONTRACT.md`（含 INV-12 keep-alive request-tail）
  - API 证据矩阵 → `API_COVERAGE.md`

## 已完成

### Slice 0 — 控制面 + 门禁

- 主 Makefile 34 focused suites
- 文档对齐真实 IHttp* / builder / H2
- router RFC 7807 测试 + group 泄漏修复

### P1 — keep-alive request-tail 契约定稿

- **Decision**: final public contract（不是 transport current truth）
- **INV-12** 写入 `CONTRACT.md` §3.1
- 策略摘要：
  - framing 完成 → 交付首请求；tail 进 `FPending`
  - partial follow-up 不早拒；可补全成合法第二请求
  - conclusively malformed / EOF 截断 follow-up → follow-up `400`
  - `Connection: close` + extra bytes → 同请求 `400`、不进 handler
- 证据：`test_http_h1parser` / `test_http_server` / `test_http_security`
- 不做：因 keep-alive 垃圾尾巴把已完成首请求改成同请求 `400`

## 当前队列

1. ~~P1 keep-alive request-tail~~ ✅
2. **P2 H2 facade 端到端证明**
3. **P3 API surface 审计**（builder 优先，默认停扩面）
4. **P4 runtime/socket 成本隔离**
5. **P5 H3**（等 QUIC）

## 明确不做

- public API 改成 async / callback-first
- HTTP 内复制 `net.server` runtime
- 空 H3 facade
- 临时 `task_plan` / `findings` / `progress` 进主线
