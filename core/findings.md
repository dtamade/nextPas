# Findings: http server unsupported expect early 417

## Scope

- 本轮继续补 `HttpServer` request-side protocol completeness：
  当 `Expect` 含有 unsupported member 时，server 必须在 headers-stage
  直接回 final `417 Expectation Failed`，而不是静默忽略或错误进入
  `100 Continue` / body-wait 路径。

## Confirmed truths

### 1. 当前实现对 unsupported `Expect` 没有明确 final rejection

- 新增 `test_http_server` focused live case：
  - `Unsupported Expect rejects early`
  - `Unsupported Expect rejects early with epoll backend`
- RED 结果直接证明现状缺口：
  - unsupported `Expect` 不会被明确收口成 final `417`
  - 现状要么静默忽略，要么错误落入后续 body/read 路径

### 2. 最小生产修复仍然应落在 H1 parse 阶段，并补齐公开状态常量

- `src/nextpas.core.http.base.pas` / `src/nextpas.core.http.pas`
  - 新增 `HTTP_STATUS_EXPECTATION_FAILED = 417`
  - `HttpStatusText(417) = "Expectation Failed"`
- `src/nextpas.core.http.impl.h1.pas`
  - 新增 unsupported `Expect` 检测 helper
  - threaded `Run` 路径：headers 完整后、`100 Continue` 之前先 short-circuit
    到 `417`
  - poll-driven `AdvancePollRequestParse` 路径：同样在 parse 阶段直接
    short-circuit 到 `417`

这保证 `Expect` 的 final/interim 判定仍由 parse 阶段统一裁决，而不是等到
handler 或 body 累积阶段才被动发现。

### 3. 修复后的契约是“unsupported member 直接失败，不再误发 interim response”

- positive path 仍保持：
  - 正常 `Expect: 100-continue` 会先收到单条 `100 Continue`
- 已有 negative path 仍保持：
  - declared oversize `Content-Length` 会直接收到 final `413`
- 新增 negative path：
  - unsupported `Expect` 会直接收到 final `417`
  - wire 上不会再出现 `100 Continue`
  - handler 在任何 body byte 到达前不会被调用

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `185/185 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_base test`
    - `14/14 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_contract test`
    - `29/29 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮把 unsupported `Expect` 的显式 `417` 收口补上了，但仍未覆盖：
  - `Expect` 组合场景的更广泛 differential characterization
  - 其他可在 headers 阶段直接裁决的 request-side final status
- 下一步仍应优先剩余真实协议缺口，而不是继续做低价值 parity 平铺。
