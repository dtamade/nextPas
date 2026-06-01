# nextpas.core.http Inbox

最近更新：2026-06-01

## 当前批次

- 公开 API 覆盖矩阵
- H1 writer / integration 语义对齐
- HTTP 基线测试与 heaptrc 零泄漏

## 当前重点

- 先把 `nextpas.core.http` 的公开契约列清：已覆盖、间接覆盖、待补测试。
- 现阶段已确认的 writer 语义：当 `Content-Length` 和 `Transfer-Encoding` 都未预设时，默认补 `Transfer-Encoding: chunked`。
- 先做正确性、边界和可维护性，benchmark 放最后。

## 路线图

1. 接管与基线
2. 公开契约审计
3. H1 正确性加固
4. Server/Client 集成加固
5. 文档与示例
6. Benchmark 与优化

## 下一步

- 先补完公开 API 覆盖矩阵。
- 下一批重点看 `IHttpClient` 额外动词、transport 接口、H1 writer / response 行为。
