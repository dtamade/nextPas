# Task Plan: http facade helper boundary audit

## Goal

继续留在 `3/6 H1 正确性加固` 主线，但这一刀不再横向复制 malformed case，
而是收口 `nextpas.core.http` 的 public facade 完整性：

- 验证文档宣称的单入口 facade 是否真正承接 static / websocket helper
- 用现有 focused suite 做 RED，而不是新造一批轻量 smoke
- 只补最小门面转发，不改 static / websocket 实现
- 跑两组 focused 测试并保留 heaptrc 无泄漏证据

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 审核 facade / static / websocket 当前导出边界
- [x] 让 `test_http_static` / `test_http_websocket` 经由 facade 做 RED
- [x] 在 `src/nextpas.core.http.pas` 做最小 re-export / inline forward
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_static clean test`
  - `make -C tests/nextpas.core.http/test_http_websocket clean test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.http.pas`
  - `tests/nextpas.core.http/test_http_static/test_http_static.lpr`
  - `tests/nextpas.core.http/test_http_websocket/test_http_websocket.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不动 `inbox`
- 不跑全量测试
- 不扩散到 router/server 其他 concrete type 讨论

## Intended outcome

- `nextpas.core.http` 可直接消费：
  - `ServeFile`
  - `ServeDir`
  - `UpgradeWebSocket`
  - `IWebSocket`
  - `TWebSocketOpcode`
  - `TWebSocketFrame`
  - `wsOp*` 枚举值
- `test_http_static` / `test_http_websocket` 作为 focused facade proof 保持通过
