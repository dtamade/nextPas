# Task Plan: http server runtime architecture refinement

## Goal

把 `nextpas.core.http` / `nextpas.core.net.server` 的 server runtime 选型再收紧一层，
把下面几件事固定成明确文档 truth：

- public API 继续保持 Go-like 同步 contract
- protocol/runtime ownership split 继续走 Tokio / Hyper-like
- backend policy 继续走 libuv-like：`epoll` / `kqueue` / `IOCP`
- 明确 `epoll` / `kqueue` 属于 readiness family，而 `IOCP` 属于
  completion/proactor family，不能伪装成同一种 low-level driver

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` / `net.server`
      相关文档与控制文件
- [x] 复读 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
      `task_plan.md`、`findings.md`、`progress.md`
- [x] 审阅 `docs/http/ARCHITECTURE.md`、`docs/net/ARCHITECTURE.md`、
      `docs/plans/2026-06-03-http-server-runtime-foundation.md` 与
      `nextpas.core.net.server` / H1 当前 seam
- [x] 对照一手资料确认选型锚点：
  - Go `net/http` 的同步 handler surface
  - Hyper 的 connection-driven runtime split
  - libuv 的跨平台 backend discipline
  - Microsoft IOCP 的 completion-queue 语义
- [x] 更新架构文档与 README，补足 readiness-vs-IOCP 边界
- [x] 更新 `task_plan.md`、`findings.md`、`progress.md`
- [x] 跑文档 hygiene 验证
- [x] path-limited commit

## Scope

- 本轮只改设计文档、README 与控制文件
- 不改生产代码
- 不新增/修改测试
- 不跑全量测试
- 不碰 shared checkout 里的无关脏文件

## Intended outcome

- 后续实现者不会再把 `HTTP Server` 误解成“固定线程模型”
- 不会再把 `IOCP` 错误地压成 `epoll` 式 readiness backend
- `HTTP` 层的固定职责保持为协议状态机，不重新吞回 runtime ownership
- 下一阶段实现顺序明确：
  - readiness family 先继续服务 `epoll` / `kqueue`
  - `IOCP` 之前先在 foundation 层补 completion-aware driver 规则
