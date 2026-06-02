# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- `TChunkedWriter` focused coverage 已完成
- helper 现在在 terminal chunk 发出后拒绝继续写入，避免生成非法 chunked stream
- HTTP focused/full suite + heaptrc 0 已验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `http.impl.h1.chunked` 已有 focused 覆盖：单 chunk、多 chunk、0 长写、hex 长度、terminal chunk 幂等、flush 后写入抛错。
- `http.client` 现在会把 close-delimited response、HTTP/1.0 非 keep-alive response 视为不可复用连接。
- `http.impl.h1.parser` 新增 focused 复用语义覆盖：close-delimited / content-length / HTTP/1.0。
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

- 回到 transport registry / client-server 注入 ownership 设计边界。
- 继续补 H1 malformed chunk/body 边界时，优先从 parser/security focused tests 切入。
