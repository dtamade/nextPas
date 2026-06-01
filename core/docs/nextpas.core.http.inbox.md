# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- `IHttpHijacker` 生命周期与连接 ownership 覆盖
- 公开 API 覆盖矩阵继续收敛
- HTTP focused/full suite + heaptrc 验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- Hijack 后 HTTP server 不再 `Shutdown/Close` 已移交给 handler 的连接。
- Transport 当前只冻结公开接口形状；registry / client-server 注入机制仍未完成。
- 下一步继续补真正缺口，不做 benchmark。

## 路线图

1. 接管与基线
2. 公开契约审计
3. H1 正确性加固
4. Server/Client 集成加固
5. 文档与示例
6. Benchmark 与优化

## 下一步

- 补 facade-only callback/overload smoke：`THttpHandlerMethod`、`THttpHandlerProc`、server/client overload。
- 再补 H1 writer 边界测试：预设 `Transfer-Encoding`、显式 `Content-Length`、flush finalization。
