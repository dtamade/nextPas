# Findings: nextpas.core.http response-side write-timeout safety proof

## Scope

- 这轮继续做 `nextpas.core.http` 的 correctness / coverage 收口。
- 目标不是再讨论 server/runtime 方案，而是补上 response-side
  `WriteTimeout` / partial-write timeout / backpressure 风险点的 focused 证据。
- 本轮主要看：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
  - `src/nextpas.core.http.impl.h1.pas`
  - `tests/nextpas.core.http/test_http_server`

## Baseline truths

- 共享 worktree 仍是脏的，存在大量与本轮无关的 modified / untracked 文件；
  只能做 path-limited 变更与提交。
- server/runtime 设计已经正式固定，不需要本轮重新发散：
  - `docs/net/ARCHITECTURE.md` 是权威架构文档
  - `docs/http/ARCHITECTURE.md` 明确 HTTP runtime ownership 下沉到 `nextpas.core.net.server`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md` 保留了原始选型记录
- 当前 backend truth 没变：
  - `threaded` 仍是默认 backend
  - Linux `epoll` 仍是 phase-1 accept-evented backend
  - Windows 长期目标仍是 `IOCP`

## Confirmed decisions

### 1. 设计文件已经固定，本轮不再重开架构

- 这轮先核对了三层文件链：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
- 三者当前是同一方向：
  - public HTTP model 保持同步、Go-like
  - runtime/backend ownership 归 `nextpas.core.net.server`
  - HTTP 只负责 per-connection protocol state

### 2. 当前 H1 session 已经具备 write-timeout 安全语义，只是此前缺 focused proof

- `TH1ServerConnectionState.Run` 在每轮请求开始时会：
  - 设置 read deadline
  - 在 `WriteTimeout > 0` 时设置 write deadline
- 现有异常路径已经具备安全关闭语义：
  - 一旦响应写阶段抛异常，session 会停止 keep-alive
  - 不会继续消费同连接里的后续 pipelined request
- 但之前还没有专门锁定 timeout/backpressure 的 focused tests，
  所以这轮补的是“契约证据”，不是生产修复。

### 3. fake-stream 与 real-socket 两层 proof 现在都已落地

- 新增 fake stream `TTimeoutWriteTcpStream`，可以脚本化模拟：
  - 首次 inner write 前立刻 timeout
  - 先写出部分字节，再在后续 write 上 timeout
- 这让我们能直接锁定两个关键语义：
  - pre-wire timeout 不会追加 synthetic `500`
  - partial-write timeout 不会继续消费第二个 pipelined request
- 新增 real-socket stalled-peer/backpressure proof：
  - 通过调小 client recv buffer / server send buffer，制造更真实的写阻塞路径
  - 锁定首个响应启动后仍不会追加 synthetic `500`
  - 锁定后续 pipelined request 不会被继续消费
  - 锁定连接会在放宽观察窗口内关闭
- 这条 real-socket proof 刻意不把 `WriteTimeout = 50ms` 包装成严格的 wire-close SLA；
  它证明的是 eventual safe-close，而不是 OS 缓冲层面的精确关断时间。

### 4. `src/nextpas.core.net.tcp.pas` 这次生产改动不成立，已回退

- 我额外开了隔离 worktree，对同一 HEAD 做了“只带 `test_http_server` 变更、不带 `net.tcp` patch”的对比验证。
- 对比结果是：
  - shared checkout（曾带 `net.tcp` patch）`110/110 passed`
  - isolated worktree（不带 `net.tcp` patch）同样 `110/110 passed`
- 结论很明确：
  - 当前 real-socket proof 不能证明 `TTcpStream.Write` 需要内嵌 poller/nonblocking runtime 逻辑
  - 这次提交不应该夹带 `nextpas.core.net.tcp` 的生产行为变化
  - 所以该 patch 已回退，最终提交面保持为测试与控制文件

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `110 total, 110 passed, 0 failed`
  - 新增 proof 通过：
    - `Write timeout before any wire bytes does not append 500`
    - `Write timeout after partial wire bytes stops pipeline without 500`
    - `Real socket write timeout backpressure stops pipeline`
  - heaptrc：`0 unfreed memory blocks`
- detached worktree 对比验证（无 `net.tcp` patch）：
  - `make -C core/tests/nextpas.core.http/test_http_server clean test`
  - `110 total, 110 passed, 0 failed`
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- 本轮虽然已经补到 initial real-socket proof，但它还不是 backend-differential timing characterization。
- 下一步若继续收口 response-side transport correctness，优先应看：
  - threaded / epoll 路径在 stalled-peer 下是否存在可区分的 timing / close-observation 差异
  - backend runtime (`threaded` / `epoll`) 对 backpressure 的真实行为
  - 是否需要在 `test_http_security` 或更底层 `net.server`/`net.tcp` 增加 transport-level proof
- 在明确 public contract 之前，不应把 `WriteTimeout` 解读成严格的“多少毫秒内必须在 wire 上看到 EOF/RST”。
- 目前仍然没有证据要求改生产代码；再做生产变更前，应该先找到真实 runtime 缺口。

## Commit intent

- 这批改动应以 timeout/backpressure focused coverage 提交，最终提交面只包含测试与控制文件。
- 继续坚持 path-limited staging，不能把共享 worktree 里的其他改动带入本 commit。
