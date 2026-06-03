# Progress Log: http server runtime architecture refinement

## Session

- **Scope:** 固化 `nextpas.core.http` / `nextpas.core.net.server` 的长期 server
  runtime 方向，特别是把 readiness-family backend 与 Windows `IOCP`
  completion-family backend 的边界写清楚。
- **Status:** committed

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- HTTP 当前已经不再自己拥有 runtime loop；真正的长期方向应继续落在
  `nextpas.core.net.server` foundation。
- 文档里原先最大的歧义点是：虽然已经写到未来支持 `IOCP`，但还不够明确说明
  `IOCP` 不能被压扁成 `epoll` 式 readiness backend。

## Completed work

- 重新审阅：
  - `docs/design-conventions.md`
  - `docs/http/API_COVERAGE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/net/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
  - `src/nextpas.core.net.server.intf.pas`
  - `src/nextpas.core.net.intf.pas`
- 结合一手资料收紧设计结论：
  - Go `net/http` 作为 public synchronous contract 参考
  - Hyper 作为 protocol/runtime ownership split 参考
  - libuv 作为 backend policy 参考
  - Microsoft IOCP 作为 completion/proactor 语义约束参考
- 已更新文档：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/net/README.md`
  - `docs/http/README.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
- 已更新控制文件：
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `git diff --check -- docs/net/ARCHITECTURE.md docs/http/ARCHITECTURE.md docs/net/README.md docs/http/README.md docs/plans/2026-06-03-http-server-runtime-foundation.md task_plan.md findings.md progress.md`
  - clean
- path-limited `git status --short`
  - 仅本轮目标文件为 modified

## Next step

- 如果下一轮进入实现，不应该先碰 HTTP facade API。
- 更合理的顺序是：
  - 先在 `nextpas.core.net.server` 把 readiness-family driver 与
    completion-aware driver 规则拆清楚
  - 然后 readiness family 继续服务 `epoll` / `kqueue`
  - Windows `IOCP` 再按同一 public contract 单独接入
