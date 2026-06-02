# nextpas.core.http Inbox

最近更新：2026-06-02

## 当前批次

- 截断 `Content-Length` 响应 EOF 误判已修复
- `test_http_h1parser` / `test_http_client` 已补齐 fixed-length truncation focused proof
- full HTTP suite + heaptrc 0 已重新验证

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `nextpas.core.http.impl.h1.pas` 继续作为默认 H1 transport owner。
- internal registry 当前内建 `hvHttp10` / `hvHttp11` -> H1，client/server 默认版本都是 `hvHttp11`。
- `nextpas.core.http.NewHttpClient` / `NewHttpServer` 仍然支持显式注入 `IHttpTransport` / `IHttpServerTransport`；显式注入优先于 registry 默认解析。
- `http.impl.h1.chunked`、client 复用语义、hijack ownership 三条 H1 correctness 基线仍然保持成立。
- `impl.h1.parser` 现在不会再把“声明了 `Content-Length` 但 body 没收全”的 response 在 EOF 时当成 complete。
- `IHttpClient` 现在会对这类截断 fixed-length response 抛出 `EHttpError`，而不是返回截断 body 并误判连接可复用。
- registry 目前保持内部实现边界；在 H2/H3 真正进入实现前，不急着把它抬成 facade API。
- benchmark 继续后置，先补 correctness 与契约边界。

## 路线图

1. 接管与基线
2. 公开契约审计
3. H1 正确性加固
4. Server/Client 集成加固
5. 文档与示例
6. Benchmark 与优化

## 下一步

- 优先继续补 malformed chunked request/body parser/security focused tests，尤其是 invalid chunk-size、truncated chunk body、chunked + limits 组合场景。
- 后续如果扩协议层，直接在已落地的 registry 上接 H2/H3，而不是重新把默认选择散回 facade/factory。
