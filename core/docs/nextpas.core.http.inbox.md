# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- `IHttpTransport` / `IHttpServerTransport` contract shape 覆盖
- 公开 API 覆盖矩阵继续收敛
- HTTP focused/full suite + heaptrc 验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
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

- 优先补 `IHttpHijacker` 生命周期与 ownership 测试。
- 再补 H1 writer 边界测试和 facade-only callback/overload smoke。
