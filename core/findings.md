# Findings: HandlerFunc nil-callback contract

## Scope

本轮补齐 `HandlerFunc` nil-callback contract。`HandlerFunc` 是 public
handler factory；nil callback 应该在 factory 边界被显式拒绝，避免运行时
调用 nil procedure variable。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_middleware` 新增 `HandlerFunc rejects nil callbacks` 后首次 focused
gate 失败：

- `10 total, 9 passed, 1 failed`
- failure: `nil handler closure raises EHttpError`

这证明旧 factory 会接受 nil closure，留下后续未定义调用风险。

### 2. 最小修复

`nextpas.core.http.middleware.HandlerFunc` 三个 overload 现在都会在 factory
边界做 nil guard：

- `THttpHandlerFunc`
- `THttpHandlerMethod`
- `THttpHandlerProc`

nil 时抛 `EHttpError`；非 nil path 保持原有 wrapping / dispatch 行为。

### 3. Focused proof

`test_http_middleware` 现在同时覆盖：

- 正常 `HandlerFunc` wrapping。
- nil closure / method / procedure 三类 callback 都显式抛 `EHttpError`。
- middleware chain 既有 order / short-circuit / response mutation 行为仍保持。

## Remaining gaps / risks

- 本轮没有额外跑 facade contract gate；`nextpas.core.http.HandlerFunc` 是 inline
  forward 到同一个 implementation，既有 facade wrapping tests 保持覆盖。
- 后续若要对 `MiddlewareFunc(nil)` 或 `Chain(nil, ...)` 做同类 contract，应单独成批。
- 这轮不涉及 server runtime。
