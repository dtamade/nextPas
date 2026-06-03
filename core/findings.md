# Findings: nextpas.core.http zero-progress buffered write boundary

## Scope

- 当前目标是继续收紧 `nextpas.core.http` 的 response-side correctness，
  直接消除上轮留下的 silent flush-error residual。
- 本轮主要看：
  - `src/nextpas.core.io.buffer.pas`
  - `tests/nextpas.core.io/test_io`
  - `tests/nextpas.core.http/test_http_server`
  - 最小 HTTP 控制面文件

## Baseline truths

- 当前共享工作树仍然是脏的，存在大量与本轮无关的 modified / untracked 文件；只能做
  path-limited 变更与提交。
- HTTP backend truth 没变：
  - `threaded` 仍是默认 backend
  - Linux `epoll` 仍是 phase-1 accept-evented runtime
  - 本轮不重开 server/IO 模型方案讨论

## Confirmed decisions

### 1. 旧的真正缺口在 `TBufferedWriter`，不是 H1 session 自己的 happy-path 逻辑

- `TBufferedWriter.FlushBuffer` 之前在底层 `Write = 0` 时只做：
  - 保留剩余缓冲
  - `FError := True`
  - 静默 `Exit`
- `TBufferedWriter.Write` 的 direct-write 分支也一样：
  - 遇到 `Write = 0` 就静默返回 partial progress
- 因为 `TH1ServerConnectionState.Run` 只看异常，不看内部 `FError`，
  所以 zero-progress response write 会被当成“没事”，session 还能继续处理同连接的后续 request。

### 2. 最小正确解是在 buffered writer 边界把 zero-progress 升级成显式 `EIOError`

- 这比在 HTTP 层追加局部探测更干净：
  - 不需要暴露新的 public state probe
  - 不需要在 HTTP 层复制缓冲逻辑
  - client / server 两条使用 `CreateBufferedWriter` 的路径同时受益
- 本轮修复后：
  - `FlushBuffer` 遇到 zero-progress 直接抛 `EIOError`
  - direct-write 分支遇到 zero-progress 也直接抛 `EIOError`
  - destructor 中的隐式 flush 继续吞异常，避免 destructor 抛错污染调用方

### 3. HTTP server 行为因此自然收口成安全语义

- 新增 session-level RED proof 直接证明旧行为会继续处理第二个 pipelined request。
- GREEN 后：
  - 首个响应写失败就立即停止 session
  - 不会继续消费同连接里的第二个 request
  - 不会把 zero-progress failure 静默当成 keep-alive 成功

## Verification evidence

- RED:
  - `make -C tests/nextpas.core.io/test_io clean test`
    - `BufWriter flush zero-progress raises`
    - `BufWriter direct write zero-progress raises`
    - 两条都按预期失败
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `Session stops after zero-progress response write failure`
    - 旧行为实际处理到了第 2 个 pipelined request，直接命中缺口
- GREEN:
  - `make -C tests/nextpas.core.io/test_io clean test`
    - `48 total, 48 passed, 0 failed`
    - heaptrc `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `107 total, 107 passed, 0 failed`
    - heaptrc `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_client clean test`
    - `16 total, 16 passed, 0 failed`
    - heaptrc `0 unfreed memory blocks`

## Remaining gaps / risks

- zero-progress buffered write 这条 seam 已经封住，但 response-side transport/session 仍有后续 residual：
  - write-timeout 触发时的契约证明还不够窄
  - backpressure / pending-drain 语义还没有 phase-2 runtime proof
  - 非 zero-progress partial-write + later exception 的更细 transport timing 仍可继续补
- `kqueue` / `IOCP` 仍未实现；Windows 长期目标仍是 `IOCP`，不是 `WSAPoll` 终态。
- benchmark 仍后置，先继续 correctness / contract 收口。

## Commit intent

- 这批改动应该以 zero-progress buffered write hardening 提交。
- 必须坚持 path-limited staging，不能把共享 worktree 中的其他改动带入本 commit。
