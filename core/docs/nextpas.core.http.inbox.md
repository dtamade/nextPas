# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- transport injection seam 已落地
- `impl.h1` 现在拥有默认 H1 client/server transport
- HTTP focused/full suite + heaptrc 0 已验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `nextpas.core.http.impl.h1.pas` 已落地，默认 H1 连接复用、请求往返、per-connection serve loop 不再散落在 `client/server` 骨架里。
- `nextpas.core.http.NewHttpClient` / `NewHttpServer` 现在支持显式注入 `IHttpTransport` / `IHttpServerTransport`。
- `http.impl.h1.chunked`、client 复用语义、hijack ownership 这三条 H1 correctness 基线仍然保持成立。
- transport registry 仍未落地；当前扩展 seam 是“显式 transport 注入”，不是“协议版本自动注册/协商”。
- benchmark 继续后置，先补 correctness 与契约边界。

## 路线图

1. 接管与基线
2. 公开契约审计
3. H1 正确性加固
4. Server/Client 集成加固
5. 文档与示例
6. Benchmark 与优化

## 下一步

- 优先把 `impl.registry` 设计成真实默认协议解析层，而不是继续把默认选择散落在 facade/factory。
- 如果继续走 H1 correctness，则转向 malformed chunk/body parser/security focused tests。
