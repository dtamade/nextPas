# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- facade callback/overload smoke 已完成
- `HandlerFunc(THttpHandlerMethod/THttpHandlerProc)` 与 `NewHttpServer(IHttpHandler)` 已补齐到 facade
- HTTP focused/full suite + heaptrc 0 已验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- facade callback alias、server/client overload 现在有直接契约烟测。
- Hijack 后 HTTP server 不再 `Shutdown/Close` 已移交给 handler 的连接。
- transport 当前只冻结公开接口形状；registry / client-server 注入机制仍未完成。
- benchmark 继续后置，先补 correctness 与契约边界。

## 路线图

1. 接管与基线
2. 公开契约审计
3. H1 正确性加固
4. Server/Client 集成加固
5. 文档与示例
6. Benchmark 与优化

## 下一步

- 再补 H1 writer 边界测试：预设 `Transfer-Encoding`、显式 `Content-Length`、flush finalization。
- 再补 client chunked response / close-delimited response 覆盖。
