# nextpas.core.http.transports — Transports 产品面域契约

**模块**：`nextpas.core.http.transports` 纯 re-export 子facade（inline 薄转发，不含逻辑）
**层级**：L3 http（只依赖 L0–L2：`http.server`/`client`/`base`/`net.server`/`io`/`json`/`bytes`/`text`）
**四件套**：`nextpas.core.http.transports.pas` 薄门面 ← 直连 `http.server`/`http.client`/`http.base`/`net.server` owner 实现（`base←intf←impl←门面` 单向，owner 侧 `bytes.ops` 单源）；本 facade 不新增 `base/intf`，仅聚合转发
**依赖**：L0–L2 only（`bytes.ops:25/89` 单源经 `text.conv`，`net.server` TCP 运行时）
**对应主契约**：`CONTRACT.md` §1.1 Transports 行 + §2.1 Server/Client + §2.2 With* 链/超时分界 + §4/§5 H1/H2 transports/池 — **业务以 CONTRACT 为准**，本域仅为不变量锚点索引视图，不新增阈值源
**门禁**：本域独立 `heaptrc 0 unfreed`（`PoolClear`/`CloseIdleConnections`/`Close` 释放经 owner，不依赖 umbrella 聚合门禁）

## 职责（不变量锚点）

- Server 工厂：`NewHttpServer(Handler[, Transport][, Options])` / `NewHttpServerWithRequestArena`（无 options→`Production`+Arena，显式 options→`WithRequestArena`）；`DefaultTcpServerBackend`/`TcpServerBackendName` 透传 `net.server`
- Client 工厂：`NewHttpClient([Transport][, Options])`（registry 默认 `hvHttp11`，`WithVersion` 钉版本，无自动 ALPN 升级）；`THttpServerOptions`/`THttpClientOptions` carrier（`Timeout`/`ConnectTimeout`/`MaxPoolSize`/`IdleTTL` 等见 `timeout.md`/`pool.md` 单源）
- 抓取/便捷族：`HttpGetToWriter/ToFile`（原子发布、同目录 temp）、`HttpReadResponseBodyBytes/String/StringAuto`、`HttpDecodeContentEncoding`/`HttpReadResponseBody*Decoded`（单 coding `gzip|x-gzip|deflate|identity`，`AMaxSize` 约束）、`HttpEnsureSuccess(Method,Url)` 前缀 `METHOD url:`、非 2xx `Op=ensure`
- JSON 三层：`PostJson/PutJson/PatchJson/DeleteJson` raw→`IHttpResponse`；`HttpPostJson/HttpGetString` ensure string；`HttpPostJsonDocument/HttpGetJson/HttpReadResponseJson` ensure+`JsonParse`（非法→`hekProtocol` Op=`json`）、`Head/Options/PostString/PutString/PatchString/DeleteString`
- 池/连接：`CloseIdleConnections` 生命周期缝（optional capability，unsupported→no-op）、`PoolClear`/`CloseIdle`/`IdleTTL` 墙钟淘汰见 `pool.md`，H1 `https|host`/`connect|host` 键隔离，直连 https（dial→TLS wrap，ALPN `http/1.1`）与 CONNECT 隧道
- With* 链：`WithTimeout/WithConnectTimeout/WithMaxRedirects/WithFollowRedirects/WithRetry/WithHeader/WithBasicAuth/WithBearerAuth/WithCookieJar/WithProxyUrl/WithTLSContext` decorator/rebuild 语义与覆盖规则见主契约 §2.2 With* 表（rebuild 经 `RebindInner` 不丢外层）

## 性能

- 全部 API `inline` 薄转发（const string/TBytes/IClient），门面内无 `Move`/`FillChar`/`CompareMem` 体（`Move` 单源 `bytes.ops:25/89`，符合 `design-conventions.md:125-131` 豁免，路由/扫描体 out-of-line 在 owner，避免 I-Cache 膨胀；伞面经五子facade 二次薄转发仅一层跳转）
- 零拷贝视图：`TByteSpan` pending tail（`impl.h1.framing.tail.base:TH1TailBuffer`）、`body Bytes` 引用共享、host key 归一 `CanonicalPoolHostKey` 经 `bytes.ops` 零分配比较
- `bytes.ops` 单源复用：门面不复制 `LowerCase`/`CompareMem`，`pool.pas:32` 直连 `text.conv→bytes.ops` 单源透传；`EffectiveConnectTimeout`/`IsExpired` 等墙钟判定 inline 零拷贝整数比较

## 稳定性

- 资源释放不丢：`try/finally`/`Close`/`PoolClear`/`HttpReleaseResponseBody` 幂等 `Close`（析构未 Close 自动补关），`CloseIdleConnections` 锁外关，不持锁做 IO；`Send` 拥有 close-capable request body，终局 `IReadCloser/ICloser/IStream.Close`
- `heaptrc 0 unfreed` 每域独立门禁（`pool.md`/`retry.md`/`timeout.md` 各自门禁，不经 umbrella 聚合）；`HttpErrorIsRetryable`/`HttpErrorIsUserError` 边界包装裸 `ETimeoutError/ECancelledError/ENetworkError→EHttpError(Op=transport)`

## Owner 边界

- 缺能力先反哺 `http.server`/`client`/`base`/`net.server`/`net`/`bytes.ops`/`io`/`json`/`platform` 等 owner，不在 facade 复制 dial/池/重试算法或绕过 `platform` 边界
- 四件套方向 `base←intf←impl←门面`，L3 只依赖 L0–L2（见 `design-conventions.md:59`）；跨 http 复用池再评估下沉 `net.pool`
