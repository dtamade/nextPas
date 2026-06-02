# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- client response framing smoke 已完成
- chunked response / close-delimited response 现在有 focused 读取覆盖
- HTTP focused/full suite + heaptrc 0 已验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `http.client` 的 chunked / close-delimited body 读取行为已被 focused 测试直接证明。
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

- 视需要决定是否把 `TChunkedWriter` 单独提升为 focused 实现级测试对象。
- 再决定 transport registry / client-server 注入 ownership 的设计边界。
