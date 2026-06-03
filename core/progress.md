# Progress Log: nextpas.core.net.server poll-driven session seam

## Session

- **Scope:** 把 `nextpas.core.net.server` 从 provider seam 继续推进到
  poll-driven per-connection session seam，但不直接迁移 HTTP H1 生产实现。
- **Status:** in verification / commit-prep

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- foundation 已新增 `ITcpServerPollDrivenSession` contract。
- Linux `epoll` 现在不仅能 evented accept，也能直接驱动 opt-in 的 poll-driven session。
- `nextpas.core.http.impl.h1` 本轮未改，HTTP 当前运行真相仍然以 worker-driven session 为主。

## Completed work

- 审阅并确认当前 runtime seam：
  - `ITcpListenerRuntime.TryAccept`
  - `ITcpStreamRuntime.TryRead/TryWrite`
  - backend registry/provider seam
- 先写 focused proof：
  - threaded backend 面对 poll-driven session 仍走 `Run`
  - epoll backend 可直接驱动 poll-driven session
- 在 `src/nextpas.core.net.server.intf.pas` 落地：
  - `TTcpServerPollResult`
  - `ITcpServerPollDrivenSession`
- 在 `src/nextpas.core.net.server.runtime.pas` 落地：
  - `TryCreateTcpServerSession(...)`
  - `ExecuteTcpServerSession(...)`
- 在 `src/nextpas.core.net.server.epoll.pas` 落地：
  - accepted session 的 poll-driven 注册路径
  - direct `epoll` dispatch / re-arm / completion cleanup
  - blocking session 的 worker fallback 保持不变
- 在 `test_net_server` 新增 poll-driven echo session 与 focused proof。
- 同步更新：
  - `docs/net/ARCHITECTURE.md`
  - `docs/net/README.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- 已有回归证据：
  - `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `20/20 passed`
  - heaptrc：`0 unfreed memory blocks`
  - 这次通过发生在最终 warning 修正前，需要再跑一次拿最终 fresh 证据
- 已有 HTTP 回归证据：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `111/111 passed`
  - heaptrc：`0 unfreed memory blocks`
- 待本轮收口补齐：
  - rerun `test_net_server`
  - `git diff --check` scoped clean

## Next step

- 跑最终 focused 验证，确认本轮测试文件 warning 修正后的 fresh 结果。
- 做 path-limited staging / commit。
- 下一批主线直接进入：
  - `TH1ServerConnectionState` 如何迁到 `ITcpServerPollDrivenSession`
  - 再据此评估 `kqueue` / `IOCP` 的最小 backend 形状
