# Findings: EHttpError public category proof

## Scope

本轮补齐 `http.base` 中 `EHttpError` 的 public contract proof。`EHttpError`
是 HTTP 模块边界异常，应该保持 nextPas 统一错误分类语义，而不是只证明
“能被 catch”。

## Confirmed truths

### 1. 当前实现已是正确 truth

`EHttpError.Create` 当前直接调用：

- `inherited Create(AMessage, ecNetwork)`

因此这轮没有生产修复；如果为了 RED 人为改坏实现，会降低效率且污染共享
worktree。

### 2. Focused proof

`test_http_base` 新增 `EHttpError category`：

- 直接构造的 `EHttpError` 继承 `ENextPasError`。
- message 原样保留。
- `Category = ecNetwork`。
- `HttpStrToMethod('INVALID')` 抛出的 `EHttpError` 同样保持 `ecNetwork`。

这把 `docs/http/API_COVERAGE.md` 中 `http.base` 的 `EHttpError` next-action
收口为 direct focused coverage。

### 3. Scope boundary

本轮只证明 public error category，不改变 HTTP server/client 错误映射策略。

## Remaining gaps / risks

- 后续如果引入更细分 HTTP error type 或 status-aware exception，需要单独设计。
- 当前 `EHttpError` 仍是模块级 network-boundary exception，不表达具体 HTTP status。
- 这轮不跑 server/client gate，因为没有 runtime 行为改动。
