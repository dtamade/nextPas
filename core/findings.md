# Findings: nextpas.core.http epoll follow-up tail differential proof

## Scope

- 当前目标是继续收紧 `nextpas.core.http` 在 Linux `epoll` backend 下的契约证据，
  重点验证 phase-1 backend 不会破坏 plain `Content-Length` / plain chunked follow-up tail
  这类 keep-alive 边界语义。
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

### 2. `epoll` phase-1 的 differential proof 已经补齐 plain follow-up tail 语义

- 现在 `test_http_server` 已直接证明 `epoll` backend 下这些 contract 与 threaded 保持一致：
  - keep-alive 两次复用
  - fixed-length same-write pipelining
  - chunked first-request same-write pipelining
  - keep-alive `Content-Length` garbage tail -> follow-up `400`
  - keep-alive `Content-Length` truncated follow-up request line / headers -> follow-up `400`
  - keep-alive plain chunked garbage tail -> follow-up `400`
  - keep-alive plain chunked truncated follow-up request line / headers -> follow-up `400`
  - chunked trailer-complete keep-alive garbage tail -> follow-up `400`
  - chunked trailer-complete keep-alive truncated follow-up request line / headers -> follow-up `400`
  - chunked trailer-complete same-write pipelined next-request
  - chunked trailer-complete partial follow-up request line 在后续字节到达后可完成为合法第二请求
  - hijack ownership
  - hijack 后异常路径不补写 `500`、不回收 handler-owned connection

### 3. 这轮仍然是 coverage-expansion，不需要生产修复

- 新增 `epoll` plain follow-up tail tests 直接通过，没有暴露新的 runtime bug。
- 因此本轮不改 `src/nextpas.core.http.*` 或 `src/nextpas.core.net.server.*` 生产代码。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `104 total, 104 passed, 0 failed`
  - 新增通过：
    - `Content-Length keep-alive garbage tail -> follow-up 400 with epoll backend`
    - `Content-Length keep-alive truncated follow-up request line -> follow-up 400 with epoll backend`
    - `Content-Length keep-alive truncated follow-up headers -> follow-up 400 with epoll backend`
    - `Chunked keep-alive garbage tail -> follow-up 400 with epoll backend`
    - `Chunked keep-alive truncated follow-up request line -> follow-up 400 with epoll backend`
    - `Chunked keep-alive truncated follow-up headers -> follow-up 400 with epoll backend`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- Linux `epoll` 现在已经把 plain `Content-Length` / plain chunked / trailer-complete
  follow-up tail 路径都补进 differential proof；后续更值钱的差距更偏向 backpressure、
  per-connection evented runtime、以及未来 `IOCP` / `kqueue` 家族实现，而不是继续横向复制同类 H1 tail 用例。
- `kqueue` / `IOCP` 仍未实现；Windows 长期目标仍是 `IOCP`，不是 `WSAPoll` 终态。
- 当前还没有 benchmark 结论，性能判断必须后置到 correctness 和 backend contract 进一步稳定之后。

## Commit intent

- 这批改动应该以 HTTP epoll follow-up-tail differential coverage-expansion 提交。
- 必须坚持 path-limited staging，不能把共享 worktree 中的其他改动带入本 commit。
