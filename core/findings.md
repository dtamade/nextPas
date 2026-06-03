# Findings: nextpas.core.http committed-response exception boundary

## Scope

- 当前目标是继续收紧 `nextpas.core.http` 的 response-side correctness，
  从 writer short-write seam 上移到 server session 异常路径。
- 本轮主要看 `tests/nextpas.core.http/test_http_server`、
  `src/nextpas.core.http.impl.h1.pas`、
  `src/nextpas.core.http.impl.h1.writer.pas`，以及最小控制面文件。

## Baseline truths

- 当前共享工作树仍然是脏的，存在大量与本轮无关的 modified / untracked 文件；只能做
  path-limited 变更与提交。
- HTTP backend truth 已固定：
  - `threaded` 仍是默认 backend
  - Linux `epoll` 仍是 phase-1 accept-evented runtime
  - 本轮不重开 server/IO 模型方案讨论

## Confirmed decisions

### 1. 旧实现确实会在 committed response 后继续补写 `500`

- 新增 RED tests 直接证明：
  - handler 先写 `200` + body 并 `Flush`
  - 随后抛异常
  - server 当前会继续在同一连接上追加 synthetic `500`
- 这个问题同时存在于 threaded / epoll 两条路径，因为两者共享
  `TH1ServerConnectionState.Run` 的异常处理逻辑。

### 2. 最小正确解是按 response commit 状态分流异常路径

- hijack 已经有一条 ownership-specific 特例：
  - hijack 后异常不补写 `500`
- committed response 本质上也是类似约束：
  - 响应一旦已经 committed，server 不应再尝试改写成新的错误响应
- 因此本轮最小修复是：
  - `TH1ResponseWriter` 暴露内部 committed truth
  - `TH1ServerConnectionState.Run` 在异常时：
    - hijacked -> 返回 handler ownership
    - not committed -> 仍可补写 `500`
    - already committed -> 只安全关闭连接，不再追加 `500`

### 3. 这轮修复把 server contract 收紧了，但没有扩大 public API

- 没有改 `nextpas.core.http` facade / public interface。
- 新增的 commit-state 查询只存在于 H1 implementation class 内部协作面。
- `test_http_h1writer` 回归保持全绿，说明 writer 的现有 framing / short-write
  contract 没被破坏。

## Verification evidence

- RED:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `Committed response exception does not append 500`
    - `Committed response exception does not append 500 with epoll backend`
    - 两条新增测试都按预期失败
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `106 total, 106 passed, 0 failed`
    - heaptrc `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1writer clean test`
    - `24 total, 24 passed, 0 failed`
    - heaptrc `0 unfreed memory blocks`

## Remaining gaps / risks

- 当前更上层的 committed-response seam 已封住，但 transport/session 仍有一条更细的 residual：
  - `TBufferedWriter.FlushBuffer` 在底层 zero-progress 时只标记 `FError`
  - 这条 silent flush-error 没有被 `TH1ServerConnectionState.Run` 直接感知
  - 因此 response-side write-timeout / zero-progress flush / backpressure 仍缺 focused proof
- `kqueue` / `IOCP` 仍未实现；Windows 长期目标仍是 `IOCP`，不是 `WSAPoll` 终态。
- benchmark 仍后置，先保持 correctness / contract 收口。

## Commit intent

- 这批改动应该以 committed-response exception hardening 提交。
- 必须坚持 path-limited staging，不能把共享 worktree 中的其他改动带入本 commit。
