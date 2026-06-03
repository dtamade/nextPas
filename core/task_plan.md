# Task Plan: nextpas.core.net/http server runtime design freeze

## Goal

把 `nextpas.core.net.server` 到 `nextpas.core.http` 的 server runtime 设计固定到正式文档，
回答并冻结下面几个问题：

- 当前 HTTP server 到底是不是线程驱动
- `threaded` / `epoll` / future `kqueue` / future `IOCP` 的 ownership 边界在哪里
- 为什么不从一个膨胀的 `BaseServer` 基类开始
- nextPas 应该采用什么样的主流范式组合
- 下一阶段真正该做的 runtime 演进点是什么

## Checklist

- [x] 读取 `docs/design-conventions.md`
- [x] 读取 `docs/nextpas.core.http.inbox.md`、`docs/http/API_COVERAGE.md`、
      `task_plan.md`、`findings.md`、`progress.md`
- [x] 检查 `git status`，确认 shared checkout 存在大量无关脏文件，只做 path-limited 变更
- [x] 审阅架构链：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
- [x] 审源码：
  - `src/nextpas.core.net.server.*`
  - `src/nextpas.core.http.server.pas`
  - `src/nextpas.core.http.impl.h1.pas`
- [x] 对照 Go / Tokio-Hyper / libuv 的范式，固定选型结论
- [x] 更新权威架构文档与 HTTP 入口文档
- [x] 更新控制文件并做最小验证
- [ ] path-limited commit

## Scope

- 这轮是设计固定，不是生产修复。
- 不改 `nextpas.core.http` / `nextpas.core.net.server` 的生产逻辑。
- 不跑全量测试，不做 benchmark。
- 不写 `docs/nextpas.core.http.inbox.md`。

## Intended outcome

- `docs/net/ARCHITECTURE.md` 成为 server runtime 的权威答案
- `docs/http/ARCHITECTURE.md` 对 HTTP 使用者说清当前 runtime 真相
- `docs/plans/2026-06-03-http-server-runtime-foundation.md` 保留为已更新的决策记录
- `task_plan.md` / `findings.md` / `progress.md` 与这一轮设计批次保持一致
