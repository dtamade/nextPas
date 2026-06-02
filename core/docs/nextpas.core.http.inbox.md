# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- H1 writer 边界 smoke 已完成
- 预设 `Transfer-Encoding`、显式 `Content-Length` flush 路径、chunked finalization 状态机 已补齐测试
- HTTP focused/full suite + heaptrc 0 已验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
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

- 再补 client chunked response / close-delimited response 覆盖。
- 视需要决定是否把 `TChunkedWriter` 单独提升为 focused 实现级测试对象。
