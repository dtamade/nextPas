# Task Plan: net.server readiness runtime owner extraction

## Goal

把 `epoll` 内已经与 Linux syscall 脱钩的 readiness-family runtime owner
正式抽成共享 internal unit：

- 新增 `nextpas.core.net.server.readiness`
- 让 `epoll` backend 退成 Linux 命名工厂包装
- 用 focused tests 直接锁定 generic readiness owner 的 worker-completion
  wake / re-entry 契约
- 保持 HTTP server contract 全量不回退

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `net.server` / `http` 相关路径
- [x] 审阅 `docs/net/ARCHITECTURE.md`、HTTP/runtime 计划文件与当前源码边界
- [x] 先写 RED：`test_net_server` 直接引用尚不存在的 `nextpas.core.net.server.readiness`
- [x] 新增 `src/nextpas.core.net.server.readiness.pas`
- [x] 让 `src/nextpas.core.net.server.epoll.pas` 退成薄包装
- [x] 跑 focused `test_net_server`
- [x] 跑 module gate `test_http_server`
- [x] 更新必要架构文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.net.server.readiness.pas`
  - `src/nextpas.core.net.server.epoll.pas`
  - `tests/nextpas.core.net.server/test_net_server/test_net_server.lpr`
  - `docs/net/ARCHITECTURE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改 HTTP public API
- 不跑全量测试

## Intended outcome

- readiness-family runtime owner 从 Linux `epoll` 私有实现里继续抽离
- future `kqueue` 可以复用 shared readiness owner，而不是复制主循环骨架
- 现有 `epoll` / HTTP contract 保持稳定，并有 focused tests + heaptrc 证据
