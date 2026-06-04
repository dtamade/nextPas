# Findings: http H1 poll-driven IdleTimeout parity

## Scope

- 本轮回到 `nextpas.core.http` 主线。
- 目标不是继续扩 malformed chunk grammar 覆盖，而是先补一个更靠近真实 backend
  正确性的缺口：poll-driven request-side `IdleTimeout` parity。

## Confirmed truths

### 1. 现有 poll-driven H1 只对 write-side stalled drain 暴露 `WakeDeadline`

- `TH1ServerConnectionState.WakeDeadline` 之前只返回 `FPollWriteDeadline`。
- `AdvancePollRequestParse(...)` 在等待 `peReadable` 时只会返回 `tsprWait` +
  `[peReadable]`，没有任何 read-side timeout 收口。
- readiness runtime 虽然已经支持 synthetic deadline wake，但 H1 request parse
  路径之前没有把这个机制接上。

### 2. 这不是“测试缺一条”的问题，而是真实行为缺口

- RED 新增 focused test 后，初次失败点就是：
  - `idle read timeout arms initial read deadline before first poll event: expected 1, got 0`
- 这说明 poll-driven session 在第一个 request byte 到来前，确实没有 arm
  read deadline，也就谈不上 timeout close。

### 3. blocking `Run` 的更接近真相的 parity 是“每个 request parse 周期一条 read deadline”

- `Run` 会在每个 request parse 开始前执行一次
  `SetReadDeadline(now + IdleTimeout)`。
- 它不是 write-side timeout，也不是 facade 级 SLA，而是 request parse 生命周期里的
  read deadline。
- 本轮最小实现也因此采用 request-parse state 的 read deadline，而不是扩 public API。

### 4. 最小修复已经落地

- `TH1ServerConnectionState` 新增了 `FPollReadDeadline`。
- 构造 poll-driven session 时会为初始 request parse arm read deadline。
- `ResetPollRequestState` 在进入下一次 request parse 前会重新 arm read deadline。
- `SubmitCurrentPollRequest(...)` 与 parse-error / timeout-close 路径会 clear
  read deadline，避免和 response drain/write deadline 生命周期混淆。
- `WakeDeadline` 现在返回 read/write 两侧 deadline 的 `Min(...)`。

## Verification evidence

- RED:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - 初次失败点：
    - `FAIL: H1 poll-driven session times out idle read wait before first request - idle read timeout arms initial read deadline before first poll event: expected 1, got 0`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `174/174 passed`
  - heaptrc: `0 unfreed memory blocks`
- light HTTP module gate:
  - `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `27/27 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 本轮只锁定了 “pre-first-byte idle wait” 的 poll-driven parity，还没有锁定
  partial mid-request body / trailer stall 的 timing truth。
- 目前 read deadline 语义已经能通过 readiness synthetic wake 收口，但还没把这条
  request-side timeout 进一步做成更细的 live socket characterization。
- malformed raw-wire chunked security proof 仍是 HTTP correctness 路线上的后续目标，
  只是这轮先让 evented runtime 的 request-side timeout 契约不再空着。
