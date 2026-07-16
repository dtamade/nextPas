# nextpas.core.http Inbox

最近更新：2026-07-16

## 控制面状态

- Owner lane：`.worktrees/http` / 分支 `http`
- 当前阶段：G2/G3/G4/H1-H2 硬化收口；H3 blocked on QUIC
- 权威文档：
  - 完成度与切片队列 → `GOAL_TREE.md`
  - 稳定架构事实 → `ARCHITECTURE.md`
  - 公开契约 → `CONTRACT.md`
  - API 证据矩阵 → `API_COVERAGE.md`

## Slice 0（2026-07-16）已完成

- 门禁审计：主 Makefile 从 27 扩到 34 个 focused suites
- 新增纳入：`base` / `url` / `router` / `middleware` / `static` / `h1scan` / `h1outbound`
- 旁路保留：`benchmarks` / `examples` / `smoke` / `integration` / `tls_real`
- 修复：router 404/405 测试对齐 RFC 7807；group 测试显式释放；`THttpRouter.Destroy` 清理 middleware / regex handlers
- `test_http_router`：30 passed / 0 failed / 0 unfreed

## 当前队列（严格顺序）

1. **P1 keep-alive request-tail 契约决策**
   CL/chunked garbage tail 是 final public contract 还是 transport truth only
2. **P2 H2 facade 端到端证明**
   `Options.WithVersion(hvHttp2)` 的 client/server live path
3. **P3 API surface 审计**
   `THttpRequestBuilder` 为推荐入口；旧 `NewRequest` overload 已 deprecated；防止第二套 API 家族
4. **P4 runtime/socket 成本隔离**
   不扩 public API，不抢排名
5. **P5 H3**
   等 QUIC 模块；只维护 registry seam

## 明确不做

- public API 改成 async / callback-first
- HTTP 内复制 `net.server` runtime
- 空 H3 facade
- 把临时 `task_plan` / `findings` / `progress` 带进主线
