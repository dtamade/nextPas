# Findings: HTTP examples and facade truth

## What landed

- 新增两个可运行示例：
  - `examples/nextpas.core.http/http_hello_server`
  - `examples/nextpas.core.http/http_get_client`
- `docs/http/README.md` 的 Quick Start 已从片段式伪代码切到可运行命令。

## Key findings

- `NewRouter` 返回的是 `IHttpRouter`，公开接口稳定面是 `Handle(...)` / `Use(...)`；
  `Get/Post/Put/Delete` convenience methods 目前只在 concrete `THttpRouter` 上，不在 facade interface 上。
- `hmGet` 等枚举值当前也不经过 `nextpas.core.http` facade 直接入作用域；
  example 需要显式使用 `nextpas.core.http.base`。
- 因而 README 若继续写成“只 `uses nextpas.core.http` 就能 `Router.Get(...)` / `Handle(hmGet, ...)`”
  会误导使用者；本轮已把文档收口到 current truth。

## Scope decision

- 本轮不扩公开 API，不为 example 去新增 facade re-export 或扩 `IHttpRouter`。
- benchmark 继续后置；本轮目标是 examples/doc truth，不是性能工作。
