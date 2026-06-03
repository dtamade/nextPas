# Task Plan: http h1 poll-driven phase2 step1

## Goal

把 `nextpas.core.http` 的 H1 poll-driven runtime 从
"整连接一次 worker bridge" 再推进一格：

- reactor 直接负责 request-side read/parse
- 每个已完成 request 单独 handoff 给 worker
- 同包已缓冲的 follow-up request 不必等待新的 readability
- 同时不破坏现有 threaded / epoll HTTP contract

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `nextpas.core.http` 相关文件
- [x] 审阅当前 H1 bridge 实现、parser pause 语义、epoll completion wake 路径
- [x] 先补 RED：
  - `test_http_server` 证明 poll-driven H1 对两个已完成请求必须 handoff 两次
- [x] GREEN：
  - `TH1ServerConnectionState` 改为 reactor-owned read/parse
  - 每个完整 request 单独 worker handoff
  - buffered follow-up request 不等新 readable
  - 保留无 `ITcpStreamRuntime` 时的旧 whole-run fallback
- [x] 跑 focused `test_http_server` 与 heaptrc
- [x] 更新 `docs/http/ARCHITECTURE.md`、`docs/http/API_COVERAGE.md`

## Scope

- 这轮只做 H1 poll-driven phase2 的第一格。
- 不改 `nextpas.core.http` public API。
- 不先拆 reactor-owned outbound drain。
- 不先把 `WakeDeadline` 接进 H1 生产语义。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- H1 不再是 “第一次 readable 后整连接 `Run` 一次 handoff” 的形态。
- reactor 现在已经掌管：
  - socket read
  - request parse
  - same-connection follow-up request continuation
- 当前剩余主线进一步收窄为：
  - outbound `TryDrainTo`
  - write/read deadline reactor-owned 语义
  - bounded outbound queue / backpressure 策略
