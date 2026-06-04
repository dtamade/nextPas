# Findings: http facade helper boundary audit

## Scope

- 本轮目标不是再补一层 malformed/runtime parity，而是校正 `nextpas.core.http`
  的 facade public surface。
- 只审 static / websocket 这两个已经公开、且文档明显暗示应可从 facade 进入的 helper。

## Confirmed truths

### 1. facade 之前确实缺 static / websocket helper 转发

- `test_http_static` 切到 `uses nextpas.core.http` 后，RED 直接报：
  - `ServeFile`
  - `ServeDir`
- `test_http_websocket` 切到 `uses nextpas.core.http` 后，RED 直接报：
  - `UpgradeWebSocket`
  - `IWebSocket`
  - `TWebSocketFrame`
  - `wsOpText/wsOpBinary/wsOpClose`

这说明文档里的“single uses entry point”在这两个 helper 族上原先并不成立。

### 2. 最小修复点只需要落在 facade

- `src/nextpas.core.http.pas` 新增对：
  - `nextpas.core.http.static`
  - `nextpas.core.http.websocket`
  的依赖与 inline forward。
- 同时补齐 facade re-export：
  - `IWebSocket`
  - `TWebSocketOpcode`
  - `TWebSocketFrame`
  - `wsOpContinuation/wsOpText/wsOpBinary/wsOpClose/wsOpPing/wsOpPong`

static / websocket 子模块自身没有缺陷，因此不需要改生产实现。

### 3. focused suite 现在已成为 facade helper 的直接证据

- `test_http_static` 现在通过 facade 直接消费 `ServeFile/ServeDir`
- `test_http_websocket` 现在通过 facade 直接消费
  `UpgradeWebSocket/IWebSocket/TWebSocket*` 与 `wsOp*`
- 这不是 compile-only proof：两组 suite 都完整跑到了真实行为与 heaptrc

## Verification evidence

- RED:
  - `make -C tests/nextpas.core.http/test_http_static test`
  - `make -C tests/nextpas.core.http/test_http_websocket test`
  - 预期失败，直接暴露 facade 缺口
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_static clean test`
    - `9/9 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_websocket clean test`
    - `8/8 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮只收口了 helper surface，不代表所有 concrete type 都该进 facade。
- 下一步应回到 correctness 主线，先判断：
  - 还剩哪些真正高价值的 malformed/runtime/security 边角
  - 或 H1 correctness 是否已接近本阶段收口线
