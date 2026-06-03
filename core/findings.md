# Findings: HTTP router convenience methods publicized

## What changed

- `IHttpRouter` 现在正式公开：
  - `Get`
  - `Post`
  - `Put`
  - `Delete`
- `http_hello_server` example 已回到更自然的 `Router.Get(...)` 用法。
- `docs/http/README.md` 与 `docs/http/API_COVERAGE.md` 已同步 current truth。

## TDD evidence

- RED 已验证：
  `test_http_contract` 在 `IHttpRouter` 上直接调用 `Get/Post/Put/Delete` 时，编译报
  `Identifier idents no member`.
- GREEN 已验证：
  同一组 contract tests 现在编译通过并运行通过，且新增 focused test
  `IHttpRouter convenience methods are callable through interface`。

## Scope decision

- 本轮只把已有 concrete capability 升格为 public interface。
- 不顺手扩到 `Patch/Head/Options`，避免一次把 public router surface 拉大而没有足够契约审计。
