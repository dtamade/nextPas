# Findings: http server expect-continue early 413

## Scope

- 本轮继续补 `HttpServer` request-side protocol completeness，但不是继续扩
  `100 Continue` 的 positive path，而是把它补完整：
  当 declared `Content-Length` 在 headers 阶段已明确超过 `MaxBodySize`
  时，server 必须直接回 final `413`。

## Confirmed truths

### 1. 当前实现会把“已知必拒绝”的 declared oversize body 误走成 `100 Continue`

- 新增 `test_http_server` focused live case：
  - `Expect: declared oversize content-length rejects early`
  - `Expect: declared oversize content-length rejects early with epoll backend`
- RED 结果直接证明现状缺口：
  - 至少 `epoll` 路径不会在 headers-stage 直接给 final `413`
  - 现状会把 declared oversize request 继续按普通 `Expect: 100-continue`
    处理，先发 `100 Continue`

### 2. 最小生产修复仍然应落在 H1 parse 阶段

- `src/nextpas.core.http.impl.h1.pas`
  - 新增 declared `Content-Length` 解析 helper
  - threaded `Run` 路径：headers 完整后、`100 Continue` 之前先判断
    declared size 是否已超过 `MaxBodySize`
  - poll-driven `AdvancePollRequestParse` 路径：在同一阶段直接 short-circuit
    到 `413`

这保证“是否发送 `100 Continue`”仍然由 parse 阶段统一裁决，而不是等到
handler 或 body 累积阶段才被动发现。

### 3. 修复后的契约是“已知最终失败时不再误发 interim response”

- positive path 仍保持：
  - 正常 `Expect: 100-continue` 会先收到单条 `100 Continue`
- 新增 negative path：
  - declared oversize `Content-Length` 会直接收到 final `413`
  - wire 上不会再出现 `100 Continue`
  - handler 在任何 body byte 到达前不会被调用

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `183/183 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮把 declared oversize `Content-Length` 的 headers-stage final rejection
  补上了，但仍未覆盖：
  - unsupported `Expect` expectation 的拒绝策略
  - 其他可在 headers 阶段直接裁决的 request-side final status
- 下一步仍应优先剩余真实协议缺口，而不是继续做低价值 parity 平铺。
