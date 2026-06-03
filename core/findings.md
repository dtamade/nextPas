# Findings: nextpas.core.http epoll backend differential proof

## Scope

- 当前目标是继续收紧 `nextpas.core.http` 在 Linux `epoll` backend 下的契约证据，
  重点验证 phase-1 backend 不会破坏 keep-alive / pipelining / hijack 这些 server 核心语义。
- 本轮只看 `tests/nextpas.core.http/test_http_server` 与最小控制面文件。

## Baseline truths

- 当前共享工作树是脏的，存在大量与本轮无关的 modified / untracked 文件；只能做
  path-limited 变更与提交。
- `epoll` phase-1 backend 当前真实语义仍然是：
  - listener readiness + `TryAccept` 走 `epoll`
  - accepted connection 仍交给 foundation worker 执行同步 HTTP session / handler

## Confirmed decisions

### 1. 当前这批工作是 coverage-expansion，不是生产修复

- 新增 `epoll` differential tests 直接通过，没有暴露新的 runtime bug。
- 本轮不需要改 `src/nextpas.core.http.*` 或 `src/nextpas.core.net.server.*` 生产代码。

### 2. `epoll` phase-1 已经不只是 simple GET smoke

- 现在 `test_http_server` 已直接证明 `epoll` backend 下这些 contract 与 threaded 保持一致：
  - keep-alive 两次复用
  - fixed-length same-write pipelining
  - chunked first-request same-write pipelining
  - hijack ownership
  - hijack 后异常路径不补写 `500`、不回收 handler-owned connection

### 3. phase-1 backend 的下一步仍然是更深的 backend-differential matrix，而不是先改模型

- 这轮已经把最关键的 fixed/chunked pipeline 与 hijack ownership 收进 focused proof。
- 更自然的下一批是：
  - chunked trailer-complete pipelining under `epoll`
  - keep-alive follow-up malformed tail under `epoll`
  - 之后再看 backpressure / per-connection evented runtime

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `93 total, 93 passed, 0 failed`
  - 新增通过：
    - `Keep-alive: two requests one connection with epoll backend`
    - `Pipelined requests in single write with epoll backend`
    - `Chunked pipelined requests in single write with epoll backend`
    - `Hijack keeps connection open for handler owner with epoll backend`
    - `Hijack exception does not write 500 or close handler connection with epoll backend`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- Linux `epoll` 当前已补到 keep-alive / pipelining / hijack，但 trailer-complete pipelining、
  malformed follow-up tail、backpressure 仍未形成独立 differential matrix。
- `kqueue` / `IOCP` 仍未实现；Windows 长期目标仍是 `IOCP`，不是 `WSAPoll` 终态。
- 当前还没有 benchmark 结论，性能判断必须后置到 correctness 和 backend contract 进一步稳定之后。

## Commit intent

- 这批改动应该以 HTTP correctness coverage-expansion 提交。
- 必须坚持 path-limited staging，不能把共享 worktree 中的其他改动带入本 commit。
