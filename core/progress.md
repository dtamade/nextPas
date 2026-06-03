# Progress Log: HTTP server lifecycle contract surfacing batch 7

## Session

- **Scope:** 把 `THttpServer` 已有的生命周期状态正式公开进 `IHttpServer`。
- **Status:** completed

## Notes

- `src/nextpas.core.http.intf.pas` 现在把 `IsRunning` 纳入 `IHttpServer` public contract。
- `test_http_contract` 现在直接证明：`IHttpServer` 可读取 pre-listen `IsRunning`，
  `LocalAddr` 稳定返回 `0.0.0.0:0` placeholder，且 pre-listen `Shutdown` 仍安全。
- `docs/http/README.md`、`docs/http/ARCHITECTURE.md`、
  `docs/http/API_COVERAGE.md` 已同步到这条生命周期公开面。

## Fresh verification

- `make -C tests/nextpas.core.http/test_http_contract clean test`

- 上述命令已作为本轮 changed-surface focused 验证入口；结果见本轮收尾报告。
