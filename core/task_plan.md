# Task Plan: nextpas.core.http response-side write-timeout safety proof

## Goal

继续 `nextpas.core.http` 的 response-side correctness 收口，
这轮不重开 runtime 架构讨论，先把已经固定下来的 server/runtime 设计真相确认到位，
然后补齐 `WriteTimeout` / partial-write timeout / backpressure 风险点的 focused proof：

- `WriteTimeout > 0` 时 session 确实会设置 write deadline
- timeout 发生在首个响应写出前时，不会补写 synthetic `500`
- timeout 发生在部分字节已写出后时，session 会安全停止，且不再消费同连接后续 pipelined request
- real socket stalled-peer/backpressure 下，连接会在放宽观察窗口内安全关闭，且不会消费后续 pipelined request
- Linux `epoll` backend 下同一条 real-socket backpressure 契约也与 threaded 路径保持一致

## Checklist

- [x] 读取 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status`，确认 shared checkout 仍有大量无关脏文件，本轮继续只做 path-limited 变更。
- [x] 核对 server/runtime 设计是否已经正式落盘：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
- [x] 审阅 `src/nextpas.core.http.impl.h1.pas`，确认本轮聚焦的是 session-level timeout/backpressure 语义，而不是重开架构。
- [x] 补 `test_http_server` focused proof：
  - timeout before any wire bytes: no synthetic `500`
  - partial-write timeout: safe-stop + no later pipelined request consumption
- [x] 补 `test_http_server` real-socket stalled-peer proof：
  - backpressure 下首个响应开始后会安全停会话
  - 不追加 synthetic `500`
  - 不消费后续 pipelined request
- [x] 补 `test_http_server` Linux `epoll` backend differential proof：
  - real-socket stalled-peer/backpressure 契约与 threaded 路径保持一致
- [x] 下钻 `tests/nextpas.core.net/test_net_deep`：
  - 补 simplified stalled-peer `SetWriteDeadline` proof
  - 验证 lower-level `TTcpStream.Write` absolute-deadline RED 是否真实存在
- [x] 用隔离 worktree 对比当前测试在“带/不带 `src/nextpas.core.net.tcp.pas` patch”两种状态下的结果，确认是否真的需要生产修复。
- [x] 运行 focused 验证：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 做 path-limited staging / commit，并输出中文收尾报告。

## Current Status

- 本轮是 coverage-expansion / contract proof，不是生产修复。
- server/runtime 设计文件已经存在且一致：
  `docs/net/ARCHITECTURE.md` 是权威源，
  `docs/http/ARCHITECTURE.md` 是 HTTP 侧架构入口，
  `docs/plans/2026-06-03-http-server-runtime-foundation.md` 保留原始决策记录。
- 当前没有证据要求改生产代码；先把 timeout/backpressure 安全语义做成 focused proof。
- isolated worktree 对比已经证明：real-socket proof 不要求 `src/nextpas.core.net.tcp.pas` 生产变更，这批应收口为纯测试/控制面提交。
- Linux `epoll` real-socket proof 也已通过，当前没有暴露 threaded / `epoll` 的契约分叉。
- `test_net_deep` 的 simplified stalled-peer write-deadline proof 同样通过，当前没有拿到 lower-level `TTcpStream.Write` RED。

## Out of Scope

- 重开 `BaseServer` / `IOCP` / `kqueue` / runtime 选型讨论
- 跑全量测试或 benchmark
- 把 fake-stream proof 直接扩成慢 peer / 大流量 OS 级性能测试
- 碰 `nextpas.core.http` 之外的无关模块或共享 worktree 脏文件
