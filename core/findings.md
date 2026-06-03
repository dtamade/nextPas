# Findings: nextpas.core.http h1 response short-write hardening

## Scope

- 当前目标是继续收紧 `nextpas.core.http` 的 response write correctness，
  重点验证 `TH1ResponseWriter` / `TChunkedWriter` 在底层 short-write / zero-progress 时
  不会静默截断 status/header/chunk/body framing。
- 本轮主要看 `tests/nextpas.core.http/test_http_h1writer`、
  `tests/nextpas.core.http/test_http_h1chunked`、`src/nextpas.core.http.impl.h1.*`
  与最小控制面文件。

## Baseline truths

- 当前共享工作树是脏的，存在大量与本轮无关的 modified / untracked 文件；只能做
  path-limited 变更与提交。
- `epoll` phase-1 backend 当前真实语义仍然是：
  - listener readiness + `TryAccept` 走 `epoll`
  - accepted connection 仍交给 foundation worker 执行同步 HTTP session / handler

## Confirmed decisions

### 1. 这轮不是纯 coverage-expansion，而是用 TDD 拉出了一条真实生产 bug

- 旧实现对 short-write 没有防护：
  - `TH1ResponseWriter` 的 status/header/CRLF framing 直接裸 `Write`
  - `TChunkedWriter` 的 chunk-size / CRLF / body / terminal chunk 直接裸 `Write`
  - `TH1ResponseWriter` 的非 chunked body path 直接把 partial count 返给调用方
- 新增 RED tests 直接证明现状会静默截断响应，而不是完整写出或显式失败。

### 2. 生产修复的最小正确解是 write-all-or-raise，而不是继续容忍 partial count

- 现在 `TChunkedWriter` 与 `TH1ResponseWriter` 都统一成：
  - 对 framing/body 内部写入循环直到全部写完
  - 如果底层 writer `0` 进度，则抛 `EIOError`
  - 因此 public-facing `IHttpResponseWriter.Write` 现在对常见 handler 语义更直线：
    写完全部字节返回完整 count，否则异常传播

### 3. 这轮修复没有破坏现有 server contract

- `test_http_server` 全套回归仍然全绿，说明 write-all 修复没有破坏现有
  keep-alive / chunked request / hijack / epoll differential contract。

## Verification evidence

- RED:
  - `make -C tests/nextpas.core.http/test_http_h1chunked clean test`
    - 失败点直接命中：
      - short writer chunk framing 被截断
      - short writer terminal chunk 被截断
      - zero-progress writer 没有抛 `EIOError`
  - `make -C tests/nextpas.core.http/test_http_h1writer clean test`
    - 失败点直接命中：
      - short writer status/header framing 被截断
      - `Content-Length` body path 只返回 partial count
      - chunked body path 通过 writer 集成后同样被截断
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_h1chunked clean test`
    - `9 total, 9 passed, 0 failed`
    - heaptrc `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1writer clean test`
    - `24 total, 24 passed, 0 failed`
    - heaptrc `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `104 total, 104 passed, 0 failed`
    - heaptrc `0 unfreed memory blocks`

## Remaining gaps / risks

- 现在 unit-level short-write seam 已经封住，但 transport/session 层仍缺少更高层契约证据：
  - response-side write timeout
  - server/raw-wire backpressure 行为
  - 未来 evented write path 下的 pending/drain 语义
- `kqueue` / `IOCP` 仍未实现；Windows 长期目标仍是 `IOCP`，不是 `WSAPoll` 终态。
- 当前还没有 benchmark 结论，性能判断必须后置到 correctness 和 backend contract 进一步稳定之后。

## Commit intent

- 这批改动应该以 HTTP response short-write hardening 提交。
- 必须坚持 path-limited staging，不能把共享 worktree 中的其他改动带入本 commit。
