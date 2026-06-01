# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- 公开 API 覆盖矩阵落地
- `IHttpClient.Put/Delete/Patch/Head` focused 覆盖
- HTTP suite + heaptrc 验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- 已补齐 `IHttpClient` 额外动词的直接测试证据。
- 下一步继续补真正缺口，不做 benchmark。

## 路线图

1. 接管与基线
2. 公开契约审计
3. H1 正确性加固
4. Server/Client 集成加固
5. 文档与示例
6. Benchmark 与优化

## 下一步

- 优先处理 `IHttpTransport` / `IHttpServerTransport` 是否应保留为公开 contract。
- 再补 `IHttpHijacker` 和 H1 writer 边界测试。
