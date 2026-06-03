# Progress Log: nextpas.core.net/http server runtime design freeze

## Session

- **Scope:** 把 `nextpas.core.net.server` 到 `nextpas.core.http` 的 server runtime
  设计固定到正式文档，明确当前执行模型、主流范式选型、以及下一阶段演进路线。
- **Status:** in_progress

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮只做 path-limited 文档与控制文件变更。
- `docs/net/ARCHITECTURE.md` 仍是权威源。
- 当前 runtime 真相已经重新核对：
  - `threaded` 是默认 correctness baseline
  - Linux `epoll` 已经是 phase-1 accept-evented backend
  - `TH1ServerConnectionState` 已经是 protocol-owned session object
- 当前没有生产代码改动。

## Completed work

- 复读并核对：
  - `docs/design-conventions.md`
  - `docs/nextpas.core.http.inbox.md`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 检查 `git status`，确认 shared checkout 有大量无关脏文件，继续只做 path-limited 变更。
- 审阅：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
  - `src/nextpas.core.net.server.*`
  - `src/nextpas.core.http.server.pas`
  - `src/nextpas.core.http.impl.h1.pas`
- 用子代理补做只读核对，确认当前并不存在 `BaseServer` 抽象；抽象已经落在
  `nextpas.core.net.server` 的 interface / runtime seam。
- 更新架构文档：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
- 更新控制文件：
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `git diff --check -- docs/net/ARCHITECTURE.md docs/http/ARCHITECTURE.md docs/plans/2026-06-03-http-server-runtime-foundation.md task_plan.md findings.md progress.md`
  - clean
- `/home/dtamade/node_modules/.bin/prettier --write /home/dtamade/projects/nextPas/core/docs/net/ARCHITECTURE.md /home/dtamade/projects/nextPas/core/docs/http/ARCHITECTURE.md /home/dtamade/projects/nextPas/core/docs/plans/2026-06-03-http-server-runtime-foundation.md`
  - unchanged
- `/home/dtamade/node_modules/.bin/prettier --write /home/dtamade/projects/nextPas/core/task_plan.md /home/dtamade/projects/nextPas/core/findings.md /home/dtamade/projects/nextPas/core/progress.md`
  - `task_plan.md` formatted, other files unchanged

## Next step

- 做 path-limited commit。
- 下一批若恢复实现，应直接进入 shared phase-2 per-connection evented driver 设计/落地，
  而不是重新讨论要不要大一统 `BaseServer`。
