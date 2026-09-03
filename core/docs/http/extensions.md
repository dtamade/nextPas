# nextpas.core.http.extensions — Extensions 产品面域契约

**模块**：`nextpas.core.http.extensions` 纯 re-export 子facade（inline 薄转发，不含逻辑）
**层级**：L3 http（只依赖 L0–L2：`http.static`/`websocket`/`websocket.room`/`sse`/`stream`/`cookie`/`form`/`headers`/`url`/`net.server`/`vfs`/`io`/`bytes`/`text`）
**四件套**：`nextpas.core.http.extensions.pas` 薄门面 ← 直连 `http.static`/`websocket`/`sse`/`stream`/`cookie`/`form`/`headers`/`url` owner 实现（`base←intf←impl←门面` 单向，owner 侧 `bytes.ops` 单源）；本 facade 不新增 `base/intf`，仅聚合转发
**依赖**：L0–L2 only（`bytes.ops:25/89` 单源经 `text.conv`，`platform.sendfile` L0 零拷贝缝）
**对应主契约**：`CONTRACT.md` §1.1 Extensions 行 + §2 静态/Range/条件请求 + §2.2.3b/c WebSocket + §4.1 SSE/§4.2 Multipart + Headers/URL 工具 — **业务以 CONTRACT 为准**，本域仅为不变量锚点索引视图，不新增阈值源
**门禁**：本域独立 `heaptrc 0 unfreed`（`Close`/`FreeAndNil`/`PoolClear` 经 owner，不依赖 umbrella 聚合门禁）

## 职责（不变量锚点）

- 静态文件：`ServeFile/ServeDir/ServeVfs/ServeFileDownload`（发布 strong `ETag` `HttpMakeStrongETag(size,mtime_ns)`、`Last-Modified` 秒精度、`Cache-Control: public,max-age=0,must-revalidate`、`Accept-Ranges: bytes`）；条件请求 `If-None-Match` 精确/* /列表→304（优先于 `If-Modified-Since`）、`If-Modified-Since` 合法 date 且 `mtime_seconds<=date`→304、辅助 `HttpIfNoneMatchMatches/HttpNotModifiedSince/HttpTryWriteNotModified`；Range 单段 `bytes=start-end/start-/-suffix`→206+`Content-Range`+精确 `Content-Length`，非法/多段/越界→416+`Content-Range: bytes */size`，先评估 304 再 Range
- 流式：`ServeFile` 经 `IFile:IWriterTo`→`io.Copy` + `CopyRange(32K)`（`IO_COPY_BUF_SIZE`/`PLATFORM_SENDFILE_CHUNK` 32K 对齐单源，`STATIC_COPY_BUF_SIZE=32K` 对齐 `IO_COPY_BUF_SIZE` 8*4K 页，L0 `platform.sendfile` file→file/file→socket 真零拷贝已兑现 via `IWriter` fd 缝 `ISendfileFileHandle`+`ISendfileSocketHandle`，`PLATFORM_SENDFILE_CHUNK` 32K 单源 chunk，Linux `sendfile`，回退 honest 32K 缓冲），HEAD 仅头不打开流，`If-Range` 回退 200；整文件禁止 `ReadAll` 全缓冲（source-contract 锁定）
- WebSocket：`UpgradeWebSocket(Req,Writer[,Options])`/`ConnectWebSocket(Url[,Options][,Client])`→`IWebSocket`，`TWebSocketOptions.Default` 16MiB frame/64MiB message/30s `ConnectTimeout`/`Timeout`，`With*` fluent；lifecycle `IsOpen=FOpen and not FCloseSent and not FCloseReceived`，`Close(code,reason)` 幂等、`ReadFrame`/`WriteText/Binary/Ping/Pong` 控制帧 ≤125，关闭后 Read/Write*→`hekProtocol`，cancel 同 transports waitable（socketpair/TCP-loopback），`permessage-deflate` opt-in `EnablePermessageDeflate` 需双方同意 RSV1+raw DEFLATE，受 `MaxMessageSize` 约束
- Room：`IWebSocketRoom`/`TWebSocketRoomManager` `Join/Leave/Broadcast` 有界管理器
- SSE：`StartSSE(Writer)`→`ISSEEventWriter`（`Content-Type:text/event-stream`/`Cache-Control:no-cache`/`Connection:keep-alive`+`WriteHeader(200)`，nil→`hekArgument` Op=`sse`），`WriteEvent/WriteEventSimple/WriteComment/WriteRetry` 编码后 `Flush`，`Close` 幂等仅本地 `IsOpen=false`，超限/注入 `hekArgument` Op=`sse`，write-after-close/zero-progress→`hekProtocol` Op=`sse`
- Stream：`HttpWriteStream(HttpWriteStreamWithLength)` 仅 `IReader→writer` copy，不设 TE/`WriteHeader`，framing 归 writer；`HttpRequestReadChunks/HttpRequestReadBody` 有界流式 ingest
- Cookie：`ParseCookies/BuildSetCookie/MakeCookie/ParseSingleCookie/NewHttpCookieJar/HttpCookieSiteKey`（RFC6265 最小存储，`Max-Age` 优先 `Expires`，eTLD+1 SiteKey 含 `co.uk` 等 multi-label PSL 子集，`Domain=public-suffix` 拒存储，`Secure` 必需当 `SameSite=None`，同站发送仅 `None` 跨 SiteKey）
- Form：`EncodeUrlEncodedForm/NewMultipartBoundary/EncodeMultipartFormData/ParseMultipartFormData/ParseMultipartFormDataFromReader(MultipartParseOptionsDefault=4MiB)`（有界 `MaxBytes`，nil/空 boundary→`hekArgument` Op=`multipart`，超限→`hekBody`）
- Headers/URL：`NewHeaders/SetBasicAuth/SetBearerAuth`（nil→`hekArgument`，大小写不敏感）、`UrlEncode/UrlDecode/UrlDecodeQuery/UrlDecodePath/ParseQueryString/EncodeQueryString/QueryParamValue/Has`（`TUrl` core 类型拥有解析）

## 性能

- 全部 API `inline` 薄转发（const string/TBytes），门面内无 `Move`/`FillChar`/`CompareMem` 体（`Move` 单源 `bytes.ops:25/89`，符合 `design-conventions.md:125-131` 豁免，真实循环/路由/SIMD 在 owner out-of-line，避免 I-Cache 膨胀）
- 零拷贝视图：`TByteSpan` pending tail（`impl.h1.framing.tail`）、`VFS TEmbeddedSlice/Move` 零拷贝嵌入、stream chunk 视图、`SortAsciiNormalization` 仅指针/长度比较，不分配；探针 `HttpRangeHasBytesPrefix/HttpWeakETagEquals` inline 零分配（`bytes.ops:CompareMem` 单源），`HttpCookieSiteKey/CanonicalPoolHostKey` 零分配比较
- `bytes.ops` 单源：ETag FNV hash、`SpanCompare`、`Move` 均单源透传，`CopyRange(32K)`/`io.Copy` 对齐 `IO_COPY_BUF_SIZE`/`PLATFORM_SENDFILE_CHUNK` 单源

## 稳定性

- 资源释放不丢：`try/finally`/`Close`/`FreeAndNil`/`PoolClear` 经 owner 幂等，不丢；facade 不新增所有权；`heaptrc 0 unfreed` 每域独立门禁（不再经 umbrella 二次聚合）；静态路径 `STATIC_COPY_BUF_SIZE` 32K 缓冲对齐 `IO_COPY_BUF_SIZE`，L0 `platform.sendfile` file→file/file→socket 真零拷贝已兑现 via fd 缝
- SSE/Room/WebSocket 关闭幂等，`Close` 后状态冻结，`hijack` 后 `IWebSocket` 持有 stream 所有权，handler 异常不向已升级连接追加 500

## Owner 边界

- 缺能力先反哺 `http.static`/`websocket`/`sse`/`stream`/`cookie`/`form`/`headers`/`url`/`vfs`/`fs`/`io`/`bytes.ops`/`platform.sendfile` 等 owner，不在 facade 复制 ETag/Range/WebSocket 帧逻辑或绕过 `platform`/`net` 边界
- 四件套方向 `base←intf←impl←门面`，L3 只依赖 L0–L2（见 `design-conventions.md:59`）；`platform.sendfile` L0 反哺已落地，L3 仅依赖 L0 缝
