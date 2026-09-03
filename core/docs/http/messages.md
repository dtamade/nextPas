# nextpas.core.http.messages — Messages 产品面域契约

**模块**：`nextpas.core.http.messages` 纯 re-export 子facade（inline 薄转发，不含逻辑）
**层级**：L3 http（只依赖 L0–L2：`http.message`/`headers`/`url`/`form`/`json`/`bytes`/`text`/`io`）
**四件套**：`nextpas.core.http.messages.pas` 薄门面 ← 直连 `http.message`/`http.headers`/`http.form`/`json` owner 实现（`base←intf←impl←门面` 单向，owner 侧 `bytes.ops` 单源）；本 facade 不新增 `base/intf`，仅聚合转发
**依赖**：L0–L2 only（`bytes.ops:25/89` 单源复用经 `text.conv`，`io.intf` 流抽象）
**对应主契约**：`CONTRACT.md` §1.1 Messages 行 + §2.2 Request/Response + §2.2.1/§4.1-§4.2（RFC7807/有界读入）— **业务以 CONTRACT 为准**，本域仅为不变量锚点索引视图，不新增阈值源
**门禁**：本域独立 `heaptrc 0 unfreed`（`Close`/`HttpReleaseResponseBody`/`PoolClear` 经 owner，不依赖 umbrella 聚合门禁）

## 职责（不变量锚点）

- Request 工厂白名单：`NewRequest(Method,TUrl)` / `NewRequest(Method,string)` URL 解析桥 / `NewGetRequest(Path)`；多参 `NewRequest` 与 `NewStreamingRequest` 已物理删除，统一 `THttpRequestBuilder`（`Header`/`Body`/`ContentLength`/`QueryParam`/`Timeout`/`MaxRedirects` 等 fluent）
- Body framing：`Body(string|TBytes)` 发布 `Content-Length`（空串 `0` 与未调用区分）；`Body(IReader)+ContentLength(N)` 已知长度；仅 `Body(IReader)` 未声明长度→H1 chunked，H2 拒 chunked/未知长度（`hekArgument`）
- Response 工厂：`NewResponse(Status,Headers,Body)` 多重载（`IReader`/`string`/`TBytes`/`nil`），`Content-Length` 冲突与 `Transfer-Encoding` 拒绝，合成 `FinalUrl`/`Version` 见主契约 §2.2.4
- 写入器：`HttpWriteResponseString/Json/Bytes/Html/NoContent/Ok/Created/Accepted/NotModified/ResetContent/Gone`（nil writer→`hekArgument`，204/304 空体豁免 entity header）
- 重定向：`HttpRedirect` + 301/302/303/307/308 便捷（`Location` 必备，相对/网络路径解析归一）
- RFC7807：`HttpWriteErrorResponse` + 400/401/403/404/500/429/409/422/413/415/504 家族（`application/problem+json`）
- 有界读入：`HttpReadRequestBodyBytes/String/Json` 默认 `HTTP_DEFAULT_BODY_READ_MAX=4MiB`（与 `Server MaxBodySize` 对齐），`BytesMax(AReq,AMax)` 显式上限（`<=0` 无界仅测试/工具）、`BytesUnlimited` 逃生口，超限→`hekBody` Op=`body` / `BodyCacheMiddleware`→413
- 幂等门闩：`HttpIsRetrySafeRequest`/`HttpIsRetryableMethod`/`HttpHasRetryIdempotencyKey`（GET/HEAD/OPTIONS/TRACE 或 `Idempotency-Key`/`X-Idempotency-Key`），与 `retry`/`pool` 同源复用

## 性能

- 全部 API `inline` 薄转发至 owner（门面内无 `Move`/`FillChar` 体，`Move` 单源驻留 `bytes.ops:25/89`，符合 `design-conventions.md:125-131` 薄转发豁免，真实循环/SIMD 在 owner out-of-line，避免 I-Cache 膨胀）
- 零拷贝视图：`TByteSpan` pending 视图、`BodyCache` `TBytes` 只读视图共享、`SortAsciiNormalization` 指针/长度比较不分配；header 名大小写不敏感经 `bytes.ops` 零拷贝比较（`HttpCookieSiteKey`/`CanonicalPoolHostKey` 同源）
- `bytes.ops` 单源复用：门面不复制比较/拷贝实现，直连 `text.conv→bytes.ops` 单源透传

## 稳定性

- 资源释放不丢：facade 不新增所有权，释放经 owner `try/finally`/`Close`/`HttpReleaseResponseBody` 幂等 `Close`（析构未 Close 自动补关），`PoolClear`/`CloseIdleConnections` 锁外关，避免 dead hang
- `heaptrc 0 unfreed` 每域独立门禁（不再经 umbrella 二次聚合）；`BodyCacheMiddleware` 超限/解压损坏→400 不进 next，`DecompressMiddleware` 默认 `AMaxSize=HTTP_DEFAULT_BODY_READ_MAX`

## Owner 边界

- 缺能力先反哺 `http.message`/`http.headers`/`http.form`/`json`/`bytes.ops`/`io`/`text.conv` 等 owner，不在 facade 复制逻辑或绕过 `platform`/`net` 边界
- 公开面稳定：`EHttpError(Kind/Op)` 与 `IHttp*` 保持 CONTARCT 冻结行为
