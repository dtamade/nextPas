# Findings: Middleware nil-input contract

## Scope

本轮补齐 `MiddlewareFunc` / `TMiddlewareChain` / `Chain` 的 nil 输入 contract。
这些 API 都是 public middleware 组装边界；nil callback、nil root handler、nil
middleware entry 应该被显式拒绝。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_middleware` 新增 `Middleware factories reject nil inputs` 后首次 focused
gate 失败：

- `11 total, 10 passed, 1 failed`
- failure: `nil middleware wrap callback raises EHttpError`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `MiddlewareFunc` 会接受 nil callback，留下后续 nil procedure variable
调用风险。

### 2. GREEN 过程中暴露了异常路径泄漏

首次 GREEN 后 functional checks 已经全过，但 heaptrc 报告：

- `11 total, 11 passed, 0 failed`
- `2 unfreed memory blocks : 120`

根因是 `Chain(ValidHandler, [nil])` 会先创建中间 `TMiddlewareChain`，再由
`Use(nil)` 抛异常；旧 `Chain` 没有在异常路径释放中间对象。

### 3. 最小修复

`nextpas.core.http.middleware` 现在补齐：

- `MiddlewareFunc(nil)` 立即抛 `EHttpError`。
- `TMiddlewareChain.Create(nil)` 立即抛 `EHttpError`。
- `TMiddlewareChain.Use(nil)` 立即抛 `EHttpError`。
- `Chain` 在构造后续步骤抛异常时释放中间 chain，再重新抛出原异常。

### 4. Focused proof

`test_http_middleware` 现在同时覆盖：

- 正常 handler / middleware wrapping。
- middleware nil callback / nil root handler / nil middleware entry 都显式抛
  `EHttpError`。
- 异常路径无泄漏。
- middleware chain 既有 order / short-circuit / response mutation 行为仍保持。

## Remaining gaps / risks

- 本轮不改变 router / server runtime。
- 仍未把 concrete middleware classes 作为 facade API 扩大暴露；当前只收紧已公开
  middleware assembly 边界。
- 后续如果要约束 `IHttpMiddleware.Wrap(nil)` 或 middleware 返回 nil handler，应单独成批，
  因为那涉及更细的 implementation contract。
