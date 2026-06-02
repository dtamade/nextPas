# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- client response framing coverage 已完成
- 本轮已完成 mixed commit git hygiene 收口，HTTP 变更重新隔离
- HTTP focused/full suite + heaptrc 0 已重新验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `http.client` 的 chunked / close-delimited body 读取行为已被 focused 测试直接证明，本批没有新的生产修复。
- `TH1ResponseWriter` 现在禁止在 chunked final chunk 发出后继续写 body。
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

- 先审 close-delimited response 在 client pooling 下的可复用语义。
- 再决定是否把 `TChunkedWriter` 单独提升为 focused 实现级测试对象。
