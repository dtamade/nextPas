# Findings: http server expect-continue contract

## Scope

- 本轮不再只是 coverage-expansion，而是补 `HttpServer` 的真实协议能力：
  `Expect: 100-continue`。
- 目标是让 default threaded 与 Linux `epoll` backend 都能在 headers 完整、
  body 仍待发送时先返回单条 `100 Continue`，再继续读取 body。

## Confirmed truths

### 1. 当前 `HttpServer` 原本没有 `Expect: 100-continue` contract

- 现有证据已经包括：
  - writer 已能正确写 `HTTP_STATUS_CONTINUE`
  - server / security / parser 侧几乎没有任何 `Expect` 处理与证明
- 新增 `test_http_server` focused case 先 RED：
  - `Expect: 100-continue sends interim response`
  - `Expect: 100-continue sends interim response with epoll backend`
- RED 结果直接证明现状缺实现：`epoll` live case 收不到 interim `100 Continue`。

### 2. 最小生产修复落在 H1 parse 阶段，而不是 handler / writer 末端

- `src/nextpas.core.http.impl.h1.pas`
  - threaded `Run` 路径：headers 完整且 body 仍待发送时发送 interim `100 Continue`
  - poll-driven `AdvancePollRequestParse` 路径：通过 reactor-owned outbound drain 发送 interim `100 Continue`
- `src/nextpas.core.http.impl.h1.parser.pas`
  - 新增真实 `HeadersComplete` parser signal，避免把“URL 已出现”误当成“headers 已完成”

这保证 `100 Continue` 的发送点在协议上正确，也不会把行为焊死到 handler 内部。

### 3. 首版修复确实引入了 keep-alive partial-follow-up regression，但已经在本轮修正

- 首版实现把“headers complete”错判成了“URL 已出现”，导致 `epoll`
  `partial-follow-up request line can complete later` 家族回归失败。
- 用 parser 的 `HeadersComplete` 真实信号替换该启发式后，回归消失，`Expect: 100-continue`
  和既有 keep-alive bridge contract 同时成立。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `181/181 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是最基础的 positive `100-continue` contract，还没有扩展到：
  - unsupported `Expect` expectation 的拒绝策略
  - declared oversize `Content-Length` 在 headers 阶段的更早拒绝
- 下一步更值的方向仍应优先真缺口，而不是回到机械 parity 扩张。
