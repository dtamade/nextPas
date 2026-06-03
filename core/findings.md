# Findings: HTTP router head/patch/options publicized

## What changed

- `IHttpRouter` 现在正式公开：
  - `Head`
  - `Patch`
  - `Options`
- `THttpRouter` 现在也有同名 convenience wrappers。
- `docs/http/README.md` 与 `docs/http/API_COVERAGE.md` 已同步 current truth。

## TDD evidence

- RED 已验证：
  - `test_http_contract` 编译报 `Identifier idents no member "Head" / "Patch" / "Options"`
  - `test_http_router` 编译报同样缺口
- GREEN 已验证：
  - 两套 focused tests 均重新通过
  - interface 级 `IHttpRouter convenience methods are callable through interface`
    现在覆盖 `GET/POST/PUT/DELETE/HEAD/PATCH/OPTIONS`
  - concrete 级 `Convenience methods` 现在也覆盖同一矩阵

## Scope decision

- 本轮只补常用 HTTP method 的 router convenience surface。
- 暂不顺手扩到 `Connect/Trace`，后续如要公开，再单独做契约审计与 focused proof。
