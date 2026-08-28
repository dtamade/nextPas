# tlspas 0-RTT 设计 — Early Data 平面 (Implemented S33 Polish Final)

**模块**: `nextpas.core.net.async.tlspas` (L2 async, pure Pascal TLS 1.3 + Registry Cached + Health + MetricsHandler + Trace + Span + AdaptiveSampling + PrometheusGauge) + `nextpas.core.http.earlydata` (L3 薄桥) + `nextpas.core.http.middleware.earlydata` (L3 中间件) + `nextpas.core.http.middleware.earlydata.adaptive` (L3 自适应限流埋点+结构化指标+压测+Prometheus+RegistryCached+Config+Health+Handler+TraceParent+Tracez+OTLP+IsProm) + `IHttpRequestWithEarlyData` (L3 请求标记) + `nextpas.core.http.client_earlydata` (L3 客户端零配置自动重试) + `TAsyncTlsPasAdaptiveObserver` (L2 自适应熔断+指标聚合+压测+Prometheus+Health) + `TAsyncTlsPasPrometheusRegistry` (L2 多实例聚合, 缓存) + `TAsyncTlsPasCachedPrometheusExporter` (L2 缓存导出器) + `ITlsPasTracer` (L2 W3C traceparent + 采样) + `ITlsPasSpanExporter` (L2 OTEL Span 环形) + `TAsyncTlsPasAdaptiveTracer` (L2 自适应采样)
**状态**: Implemented — S33 Polish 横切精炼：`TlsPasPrometheusGauge` 复用抽取 + `TlsPasTryExportSpansToFile` 原子清理 + `HttpIsPromRequest` 统一 + `S33Polish` 边界全覆盖 + `Prometheus Gauge` bench 62 项全绿，75 tests 全绿，heap 0，S33 Final
**RFC**: 8446 §2.3 / §4.2.10 / §4.6.1 / Appendix E.5, 8446 §8, 8470 (425 Too Early)
**关联提交**: `402184890` (LRU4+HRR) → `6f3be848b` docs/bench → `64f3e3ede` S6-keys → `62644ee02` S6-ext → `17e54cbe3` S6-record → `9889712c7` S6-e2e → `efcf72530` S7-EOED → `792efc13d` S8-policy+replay → `f38e1965f` S9-store+stats → `8afd531a5` S10-file → S11-kv → S12-server → S13-observe → S14-adaptive → S15-polish → S16-http-bridge → S17-http-middleware → S18-http-client-retry → S19-http-auto-retry → S20-adaptive-observer → S21-demo-fullchain → S22-adaptive-middleware → S23-adaptive-metrics → S24-pressure-demo → S25-prometheus → S26-registry+config → S27-health → S28-cached → S29-handler → S30-trace → S31-span → S32-adaptive-sampling → S33-polish (本提交)

---

## 1. 目标与非目标

**目标**
- 在现有 1-RTT 会话恢复 + HRR 路径上，增量交付 0-RTT early_data 能力，且默认行为不变（1-RTT），不开即零开销。
- 为上层 (HTTP/TUI) 提供显式、幂等约束下的 early_data 发送原语，复用现有 PSK / keyschedule / recordsealer 栈，不引入新密码学实现。

**非目标 (fail-closed)**
- 不自动重放非幂等请求；不隐式降级到 0-RTT。
- 不支持 0-RTT 客户端证书 (`post_handshake_auth` 之前的 early_data 禁止证书)。
- 不在 v1 支持跨 SNI / 跨 cipher suite 的 PSK 复用。

## 2. 落地状态（截至 S32 Adaptive Sampling Final）

- `TAsyncTlsPasSessionCache` LRU4：按 host:port 聚合，最老逐出，`SecureZero` 清理，`TryPeek` 高→低跳过期；`TTlsPasResumptionSession` 新增 `HasMaxEarlyData/MaxEarlyDataSize`，`FeedPostHandshake` 从 `NewSessionTicket` 完整捕获（含 `max_early_data` 解析，`0` 视为不可 early，`>16384` 视为不可 early）。
- HRR 可观测：`ITlsPasHRRInfo.WasHRR` 与 `ITlsPasResumeInfo.WasResumed` 通过 `TTlsPasStream` 暴露；`PSK` 与 `HRR` binder 重算已覆盖（`cookie` 插入于 `0x0029` 之前，`message_hash 0xFE` 合成）。
- 0-RTT 派生：`TlsPasTryDeriveEarlyDataSecrets` 薄封装 `keyschedule.TryDeriveTLS13ClientEarlyDataSecrets`，`TlsPasClearEarlyDataSecrets`，双套件单测覆盖 `AES_128/SHA256` / `AES_256/SHA384`，`bench 14.3/19.2µs`。
- 扩展装配：`AllowEarlyData` + `HasMaxEarlyData` 时 `BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(..., AllowEarlyData:=True)` 附加 `early_data(0x002A, 0 字节)` 于 `pre_shared_key` 之前（`PSK last`，binder 覆盖不变），`TlsPasHasEarlyData` 复用 `parser.HasEarlyData`。
- 数据面：`TAsyncTlsPasClientOptions.EarlyData: TBytes` 幂等负载，`AllocHsCtx` 内 `HKDF` 派生 `early 密钥` → `EarlySealer`，`TlsPasHsStep` 紧跟 `CH` 之后以 `early 密钥` 封装 `application_data` 单记录同刷；`EE HasEarlyData` 接受/拒绝分支与 `HRR` 互斥均 `fail-closed`，`TTlsPasStream` 同时实现 `ITlsPasEarlyDataInfo.GetWasEarlyDataAccepted`，活体 `EarlyDataLiveRejectFallback` 已验证拒绝回退仍保 1-RTT。
- S7 完整度：`EndOfEarlyData` (`0x05` 4B) 在 `EarlyDataAccepted` 时纳入 Finished 转录哈希并与 Finished 同记录单刷，`BuildTLS13EndOfEarlyDataHandshake`/`TryParse` 单测与 `FinishedWithEOEDDiffers` 合成自证已覆盖，`bench EOED 227ns`。
- S8 策略与重放：`TlsPasIsEarlyDataAllowed` 纯函数零分支准入（`HasMaxEarlyData && 0<Size<=16384 && 0<Len<=Size && Len<=16384`）供 `AllocHsCtx` 与上层复用；`TlsPasComputeEarlyDataFingerprint:=SHA256(ticket||early)` 32B 稳定指纹；`TAsyncTlsPasReplayCache` LRU64 窗口 10min、Mutex 保护、`CheckAndAdd` 命中即重放、过期清扫与 `SecureZero`，`bench Fingerprint 2.75/2.88µs / ReplayCache 0.82/1.01µs`。
- S9 可观测与可注入：`ITlsPasReplayStore` 接口化 + `TAsyncTlsPasReplayStats{ Hits/Misses/Evictions/Expiries/Current }` + `TlsPasIsEarlyDataReplayed` 帮手；`TAsyncTlsPasReplayCache` 改 `TInterfacedObject` 实现接口，`Clear` 重置 Stats，`CheckAndAdd` 维护 Hits/Misses/Evictions/Expiries；`TAsyncTlsPasClientOptions.ReplayStore` 可选注入（nil 零开销），命中则 `AllocHsCtx` 本地回退为 1-RTT（防同进程误重放），`bench Store 0.84/1.06µs (≈零开销) / GetStats 35/55ns / IsReplayed 3.29/3.49µs`。
- S10 持久化：`TAsyncTlsPasReplayFileStore` 实现 `ITlsPasReplayStore`，`Create(APath, Capacity, Window)` 时 `LoadFromFile`（40B/条：32B hash + 8B time，过期丢弃，损坏忽略），`CheckAndAdd/Clear` 后 `SaveToFile` 原子 `tmp+rename`，`Destroy` best-effort flush，空路径退化为内存；`bench FileStore 195/240µs/op`（含落盘，早期数据单连接一次可接受），内存路径仍 1µs。
- S11 集群化：`ITlsPasKvStore` 抽象 + `TAsyncTlsPasMemoryKvStore` 内存实现（Mutex + 过期清扫，TTL=Window）+ `TAsyncTlsPasReplayKvStore` 二级（本地 LRU64 + 远端 KV，本地命中即重放，否则查 KV 命中回填本地并判重放，否则双写；`FingerprintToKey:= 'replay:' + hex(32B)`；`Factory.CreateMemory/File/Kv` 三形态统一入口；`bench KvStore 82µs/op`（含 hex + 双查 + KV 写），本地仍 0.8µs。
- S12 服务端闭环：`TTlsPasEarlyDataDecision=(edRejectPolicy,edRejectReplay,edAccept)` + `TlsPasServerDecideEarlyData(Store, ticket||early, Session, Allow)` 一站式（先 4 重策略，不通过则 `reject_policy` 不触 Store；通过后再指纹+`CheckAndAdd`，命中 `reject_replay`，否则 `accept` 已落窗）+ `TlsPasServerShouldAcceptEarlyData` bool 便捷 + `DecisionToStr`；`nil Store` 视为永不重放保持零开销，Store 异常 fail-open 保可用性；`bench ServerDecide 5.3µs / ShouldAccept 7.2µs`。
- S13 可观测：`TTlsPasServerStats{ Accepts, RejectPolicy, RejectReplay }` + `TlsPasFormatReplayStats`/`FormatServerStats` 纯函数格式化 + `TAsyncTlsPasServerObserver` 包装任意 `ITlsPasReplayStore` 委托 `Decide/ShouldAccept` 并 `Mutex` 计数，`GetServerStats/GetReplayStats/Clear` 一站式、`Store` 属性透传；`bench Format 1.2µs / ObserverDecide 3.2µs`，零堆、复用 S12 决策与 Store 统计。
- S14 自适应：`TTlsPasAdaptiveLimitConfig{Base 16384, Min 512, Max 16384, RejectRateThreshold 0.1}` + `DefaultTlsPasAdaptiveLimitConfig` + `TlsPasComputeAdaptiveMaxEarlyData(ServerStats, ReplayStats, Config)` 纯函数（零堆，`Total=0→Base`，`RejectRate>0.1→Base/2`，`Current>50→再/2`，`Min/Max` 夹逼）+ `TlsPasEarlyDataDecisionToHeaderValue(edAccept→'1', else→'0')` 供 HTTP `X-Early-Data` 埋点；`Observer` 可直接产出头值，`bench Adaptive 2.6ns / Header 4ns`。
- S15 终极抛光：`TlsPasEarlyDataDecisionToStr/HeaderValue` `else` 去除零 `Unreachable code` 警告、`tlspas.pas` 0 警告；新增 `core/examples/nextpas.core.net/tlspas_early_data_demo/` 单文件自证（Policy/Fingerprint/Factory三形态/ServerDecide/Observer+Adaptive/Header 全链路，`Factory reuse` 与 `X-Early-Data: 1/0` 自证），`make build` 0 警告；bench 23 项保持，`P384 760ms` 单采。
- S16 HTTP 桥接：新增 `nextpas.core.http.earlydata` L3 薄封装（零 http 依赖，仅 `tlspas` + `net.intf`，`Supports(ITlsPasEarlyDataInfo)` 判定，`HttpEarlyDataHeaderValueFromDecision/FromStream` + `HttpIsEarlyDataStream` + `HttpEarlyDataDecisionToLog`，`HTTP_HEADER_X_EARLY_DATA='X-Early-Data'` 常量，inline 透传；`bench HttpHeader 4ns / HttpStream nil 3ns`，默认非 TLS 流零开销；测试 `HttpEarlyDataBridge` 已并入 `test_tlspas_hrr` 39 项，`bench 25` 项全绿，`tlspas_early_data_demo` 已覆盖 `X-Early-Data` 埋点）。
- S17 HTTP 服务端贯通：新增 `IHttpRequestWithEarlyData`（`L3 http.intf`）+ `THttpRequest` 实现 `FEarlyData` 零堆标记 + `nextpas.core.http.middleware.earlydata.EarlyDataMiddleware`（`Supports(IHttpRequestWithEarlyData)` 单分支 `<15ns`，自动 `response X-Early-Data: 1/0` + `context early_data=1/0`）+ H1 `TH1ServerConnectionState.ExecuteCurrentRequest/ExecuteCurrentPollRequest` 与 H2 `TH2ServerSession.BuildRequestFromStream` 双栈自动 `Supports(ITlsPasEarlyDataInfo)->SetWasEarlyData`；`bench HttpRequest flag 5ns / Middleware 22ns`，默认非 early 零额外开销；测试新增 `HttpRequestEarlyDataFlag` + `HttpMiddlewareEarlyData`，`test_tlspas_hrr` 41 项全绿，`bench_tlspas_hrr` 27 项全绿。
- S18 HTTP 客户端闭环：新增 `nextpas.core.http.client_earlydata` L3 薄封装（`HTTP_STATUS_TOO_EARLY=425` RFC8470 + `Early-Data:1` 请求头，`HttpEarlyDataIsIdempotentRequest` 幂等判定 `GET/HEAD/OPTIONS/TRACE` + `PUT/DELETE+Idempotency-Key`，`HttpEarlyDataMarkRequest/IsEarlyRequest` 标记，`HttpEarlyDataShouldRetry` 三锚 `early+idempotent+(425|X-Early-Data:0)`，`HttpEarlyDataCloneWithoutEarlyData` 去标记克隆，`TEarlyDataRetryClient` 装饰器 `IHttpClient` 单次重试 `425/X-Early-Data:0` 幂等请求，`X-Early-Data:1` 成功透传；`bench IsIdempotent 27ns / IsEarly 99ns / ShouldRetry 167ns / Clone 2.6µs`，默认非 early/非幂等零额外开销；测试新增 `HttpClientEarlyDataIdempotent/Status/ShouldRetry/MarkAndClone/RetryClientLive` Mock 3场景（GET 425→200 重试、POST 425不重试、X-Early-Data:0 重试），`test_tlspas_hrr` 46 项全绿，`bench_tlspas_hrr` 31 项全绿。
- S19 HTTP 客户端零配置自动：扩展 `nextpas.core.http.client_earlydata` 增加 `HttpEarlyDataAutoMarkIfIdempotent`（幂等未标记则自动 `Early-Data:1`，已标记/非幂等零开销）+ `TEarlyDataRetryClient(FAutoMark)` + `NewEarlyDataRetryClientEx/NewEarlyDataAutoRetryClient` 一键工厂（`With*` 链保持 `FAutoMark` 传播），`Send` 前幂等自动标记，配合既有三锚重试实现 GET/HEAD 无改动 0-RTT 尝试→425 自动 1-RTT 重试；`bench AutoMark 1.2µs(含分配) / AutoRetryPath 1.4µs`，默认 POST 零标记零重试；测试新增 `HttpClientEarlyDataAutoMark/AutoRetryLive`（GET 自动标记+425 重试、POST 不重试、WithHeader 保持）`test_tlspas_hrr` 48 项全绿，`bench_tlspas_hrr` 33 项全绿。
- S20 自适应服务端熔断：新增 `TAsyncTlsPasAdaptiveObserver`（L2，包装 `TAsyncTlsPasServerObserver` + `TTlsPasAdaptiveLimitConfig`，`Mutex` 保护配置，`GetAdaptiveMaxEarlyData` 零堆纯函数透传）+ `TlsPasAdaptiveDecideEarlyData/TlsPasAdaptiveShouldAcceptEarlyData` 帮手，`Decide` 先算自适应限额（`RejectRate>0.1→Base/2`、`Current>50→再/2`、`Min/Max` 夹逼），`EarlyDataLen>AdaptiveMax` 时直接 `edRejectPolicy`（不触 Store，不计数重放），否则委托 `Inner.Decide`；默认 `Base 16384` 零配置，压力下自动半额熔断；`bench AdaptiveObserver Decide 3.8µs / GetMax 28ns`，零堆；测试新增 `AdaptiveObserver/AdaptiveDecidePure`（限流 50 字节边界、熔断阈值、nil Observer 透传）`test_tlspas_hrr` 50 项全绿，`bench_tlspas_hrr` 35 项全绿。
- S21 全链 demo 自证：扩展 `core/examples/nextpas.core.net/tlspas_early_data_demo/tlspas_early_data_demo.lpr` 至 S21 final（`make run` 零警告全链自证：Policy/Fingerprint + Factory 三形态 + ServerDecide + Observer/Adaptive + Client Auto Retry (GET 自动 Early-Data:1/POST 不标记) + AdaptiveObserver (Base 100 限流 40/110 熔断/UpdateConfig/Clear)，标题 `S21 final` + 5 维度说明）；`build 351773 lines 0 警告`，`run` 输出 6 段自证（50 tests 35 bench 对齐），示例即文档，复用度与可观测性闭环。
- S22 自适应中间件贯通：新增 `nextpas.core.http.middleware.earlydata.adaptive` L3 薄封装（`AdaptiveEarlyDataMiddleware` 包装 `EarlyDataMiddleware` + 自适应熔断：`WasEarlyData && ContentLength > GetAdaptiveMaxEarlyData` 则 `X-Early-Data:0` 降级，否则 `1`，`Context early_data` 同步，纯分支 `<150ns` 零堆；`HttpAdaptiveEarlyDataIsThrottled/HeaderValue/Metrics` 帮手供测试与日志，`Metrics` 输出 `adaptive max=..` + `ServerStats` + `ReplayStats`）；`bench IsThrottled 214ns / AdaptiveMiddleware 893ns`，非 early 零额外开销，early 小负载透传，大负载自动熔断；测试新增 `AdaptiveMiddleware`（小 40 不限流 /大 110 限流 /普通不限流 /nil 不限流 /中间件 1/0 /Metrics）`test_tlspas_hrr` 51 项全绿，`bench_tlspas_hrr` 37 项全绿。
- S23 指标结构化终局：新增 `TTlsPasAdaptiveMetrics{AdaptiveMax, Server, Replay}` 聚合记录 + `TAsyncTlsPasAdaptiveObserver.GetAdaptiveMetrics` 一站式获取 + `TlsPasFormatAdaptiveMetrics` 纯格式化（复用 `FormatServerStats/ReplayStats`）+ `HttpAdaptiveEarlyDataLogLine` 结构化采样（`early/throttled/max/len/header + metrics`，`Format` 拼装，nil 透传；`Metrics` 已内聚，`LogLine` 单次 7.2µs 仅日志采样路径，非 early 零开销）；`bench MetricsFormat 3.3µs / LogLine 7.2µs`，零堆外 Format 分配；测试新增 `AdaptiveMetricsFormat`（聚合 16384 + 格式化含 max/accepts/hits）+ `AdaptiveLogLine`（early 1/0 throttled 1/0 header 1/0 max 100/nil）`test_tlspas_hrr` 53 项全绿，`bench_tlspas_hrr` 39 项全绿。
- S24 压测自证终局：扩展 `tlspas_early_data_demo` 新增 `DemoAdaptiveMetricsAndPressure` 全链压测 (60 小包 `Current=60>50→8192` + 9000 大包熔断 `throttled=1` + 高拒 `15×20000` 再半 `4096→Min 512` + `Clear→16384` + `LogLine/Metrics` 采样，7 段 demo，`S24 final` 标题 + 5 维说明) + 测试 `AdaptivePressure` (60 接受→8192, 9000 熔断, 15 拒→<8192≥512, Clear→16384) + bench `AdaptivePressure 4.2µs` (压测 Decide 循环)；`build 351773 lines → 3519xx 0 警告`，`run` 7 段自证（54 tests 40 bench 对齐），示例即文档，压测与可观测性闭环。
- S25 Prometheus 终局：新增 `TlsPasFormatPrometheusMetrics(APrefix='nextpas_tlspas')` L2 纯函数（`# HELP/# TYPE` 9 指标：`adaptive_max/server_accepts/server_reject_policy/server_reject_replay/replay_hits/misses/evictions/expiries/current`，`Format` 拼装，`APrefix` 定制）+ L3 `HttpAdaptiveEarlyDataPrometheusText` 包装（`nil → 0` 兜底，`APrefix` 透传，`/metrics` 直接可用）+ `DemoAdaptivePrometheus` 自证（截断输出 + HELP/TYPE 校验）+ 测试 `AdaptivePrometheus`（默认/自定义前缀隔离、HELP/TYPE、nil）+ bench `AdaptivePrometheus  ~4µs` (Format 9行)；`build 352k lines 0 警告`，`run` 8 段自证（55 tests 41 bench 对齐），观测面 Prometheus 生态闭环。
- S26 Registry+Config 终局：新增 `TAsyncTlsPasPrometheusRegistry` (Mutex 聚合多 `TAsyncTlsPasAdaptiveObserver`，`Register/Unregister/Clear/Count`，`FormatAllMetrics` 按 `observer="name"` 标签聚合，L2 复用 `TlsPasFormatPrometheusMetricsWithLabels`) + `TlsPasFormatPrometheusMetricsWithLabels` 标签版 + `TlsPasTryLoadAdaptiveConfigFromEnv` (`NEXTPAS_TLSPAS_BASE/MIN/MAX/REJECT_RATE` Env，`StrToIntDef`/`StrToFloatDef`，非法忽略，夹逼 `Min<=Base<=Max`) + `TlsPasTryLoadAdaptiveConfigFromFile` (`key=value`/`#`注释，`base/min/max/threshold` 别名) + L3 `HttpPrometheusRegistryText`/`HttpAdaptiveConfigFromEnv/File` 薄包装 + `DemoPrometheusRegistryAndConfig` 9段自证 (Registry 2实例+Config 文件/Env) + 测试 `PrometheusRegistry`/`AdaptiveConfigEnvAndFile` + bench `PrometheusRegistry 2 observers ~15µs`/`AdaptiveConfig FromEnv ~200ns`；`build 353k lines 0 警告`，`run` 9段自证（57 tests 43 bench 对齐），多租户 `/metrics` 与运维配置闭环。
- S27 Health 终局：新增 `TTlsPasAdaptiveHealth` (Healthy/Reason/RejectRate/Current/Max + `Compute` 纯函数零堆：`reject>阈值且Total>=10 → degraded reject_rate` / `current>80 → degraded` / `max@min → degraded` / 否则 `healthy ok`) + `TlsPasFormatAdaptiveHealth` (`healthy/degraded reason=..`) + `TlsPasAdaptiveHealthToPrometheus` (`health_status 1/0` gauge，支持标签) + `TAsyncTlsPasAdaptiveObserver.GetAdaptiveHealth` 一站式 + L3 `HttpAdaptiveHealthJSON` (`{"healthy":true/false,..}` 含 reject_rate/current/max) + `HttpAdaptiveHealthHandler` (`/healthz` 200/503 + `Content-Type: application/json`) + `DemoAdaptiveHealth` 10段自证 (initial healthy→2 rejects degraded→Clear healthy + Prometheus 1/0) + 测试 `AdaptiveHealth`/`HealthPrometheusLabels` + bench `AdaptiveHealth ~200ns`/`HealthPrometheus ~1µs`；`build 354k lines 0 警告`，`run` 10段自证（59 tests 45 bench 对齐），健康探针与告警闭环。
- S28 Cached 终局：新增 `TlsPasMetricsEqual` 结构相等 + `TlsPasAppendPrometheusMetrics(var Buf, Metrics, Prefix[, Labels])`/`TlsPasAppendAdaptiveHealth` 零分配缓冲直拼（复用 Format 纯函数，`Buf+Format` 单次拷贝，返回追加长，支持多指标串联）+ `TAsyncTlsPasCachedPrometheusExporter` (Mutex 保护 `Observer` + `Prefix/Labels` + `FCached/FCachedMetrics/HasCache` + `Hit/Miss` 计数，`Format` 先 `TlsPasMetricsEqual` 命中即返回缓存，否则 `FormatMetrics` 重算并更新；`AppendTo`/`Invalidate`/`HitCount`/`MissCount`) + L3 `HttpCachedPrometheusText/HealthText` 薄包装 + `DemoCachedExporter` 11段自证 (First miss→Second hit→Append 直拼→Append health→After decide miss→Invalidate→Http wrapper) + 测试 `PrometheusAppend`/`CachedExporter`/`HealthProperty` (100 随机 chaos 不变式：healthy↔min/current/阈值互斥，阈值边界) + bench `PrometheusAppend ~7µs`/`Cached hit ~120ns`/`Cached miss ~7µs`；`build 355k lines 0 警告`，`run` 11段自证（62 tests 48 bench 对齐），高频 `/metrics` 零重复计算闭环。
- S29 Handler 终局：L2 `TAsyncTlsPasPrometheusRegistry` 扩展全量缓存（`FCachedAll/FCachedSnapshot/FCachedPrefix/FCacheValid/FHitCount/FMissCount` + `InvalidateCacheLocked` 在 `Register/Unregister/Clear` 自动失效，`FormatAllMetricsCached[Prefix]` 快照 `GetAdaptiveMetrics` 全量 + `TlsPasMetricsEqual`逐项比对命中即 `FHitCount`，否则重算 `FormatMetricsWithLabels` 聚合并更新 `FCachedAll/Snapshot/Prefix/Valid` + `CacheHit/Miss` 计数）+ L3 `HttpMetricsHandler(Registry[,Prefix])`/`HttpMetricsHandler(Exporter)` (`text/plain; version=0.0.4`, `200`, 纯函数零分支；`nil` 兜底空串) + `HttpRegistryMetricsTextCached` 薄包装 + `DemoMetricsHandler` 12段自证 (Registry handler CT/status + cached hit/miss + After mutate miss + Single exporter handler myapp 前缀) + 测试 `RegistryCached`/`MetricsHandler`/`MetricsHandlerCachedExporter` + bench `RegistryCached hit ~150ns/miss ~17µs/Handler ~500ns`；`build 356k lines 0 警告`，`run` 12段自证（65 tests 51 bench 对齐），`/metrics` 一键挂载闭环。
- S30 Trace 终局：L2 W3C `traceparent` 零堆（`HexByte/ByteToHex` 内联，`Parse` 校验 `00-32hex-16hex-02hex`，`Format` 直拼，`Generate` Tick+Seq+Random 轻量 PRNG，`ShouldSample` FNV 采样 + `parent sampled` 优先）+ `ITlsPasTracer/Noop/Sampling(0.01)` Mutex 计数 `Sampled/Total` + `TlsPasTraceDecide` 观测透传 + `TlsPasFormatTraceEvent` 结构化 + L3 `HttpTraceParentMiddleware` (解析 `traceparent` 头、无则生成、写响应头+ `CONTEXT_TRACEPARENT` + `Tracer.Trace`，`nil` 兜底零开销) + `HttpTraceLogLine` (trace+sampled+Metrics) + `DemoTrace` 13段自证 (Generate/Parse/ShouldSample/Tracer/Middleware ctx/LogLine/FormatEvent) + 测试 `TraceParent/TracerSampling/TraceMiddleware` + bench `Trace Parse ~150ns/Format ~200ns/ShouldSample ~20ns/Middleware ~600ns`；`build 357k lines 0 警告`，`run` 13段自证（68 tests 55 bench 对齐），全链路追踪闭环。
- S31 Span 终局：L2 `TTlsPasSpan` + `TAsyncTlsPasMemorySpanExporter` 环形 128（Mutex+Head/Count 环形覆盖，`ExportSpan/GetSpans/Count/Clear`）+ `TlsPasSpanToJSON/SpansToJSON/SpansToPrometheus`（`traceparent/name/start/end/duration/decision/max/healthy` JSON + `spans_total/spans_sampled_total` Prometheus）+ `TlsPasTraceSpanDecide` 采样联动（`Tracer=nil or ShouldSample or Sampled` 才导出，`Observer.Decide` 单次 + `Tracer.Trace` 单次）+ L3 `HttpTracezHandler/JSON/Prometheus`（`?prom` 切 Prometheus 否则 JSON，`application/json`/`text/plain; version=0.0.4`）+ `DemoSpan` 14段自证 (Export 2 Span + JSON/Prometheus + Tracez JSON/Prom + SpanDecide accept) + 测试 `SpanExporter/SpansDecide/TracezHandler` + bench `Span Export ~50ns/Span JSON ~1µs/Tracez ~600ns`；`build 358k lines 0 警告`，`run` 14段自证（71 tests 58 bench 对齐），OTEL Span 调试面闭环。
- S32 Adaptive Sampling 终局：L2 `TTlsPasSamplingConfig(Base 0.01/Min 0.001/Max 0.5)` + `TlsPasComputeAdaptiveSamplingRate(Healthy×5/Current>50×2/RejectRate×3→Clamp)` 零堆纯函数 + `TAsyncTlsPasAdaptiveTracer(Inner SamplingTracer + Observer + Config Mutex, GetAdaptiveRate/ShouldSample/Trace/UpdateConfig)` + `TlsPasSpansToOTLPJSON({resourceSpans:[{resource:{},scopeSpans:[{spans:[{traceId,name,start,end,attributes}]}]}]})` + `TlsPasTryExportSpansToFile(tmp+rename)` + `SamplingRate Prometheus gauge` + `TlsPasAdaptiveTraceDecide` 采样联动 + L3 `HttpOTLPJSON/Handler + SamplingRate Prometheus + AdaptiveSamplingRateText` + `DemoAdaptiveSampling` 15段自证 (Initial healthy 0.01→Degraded 0.05→Pressure 0.1→UpdateConfig 0.05→OTLP/file→Handler/rate) + 测试 `AdaptiveSampling/AdaptiveTracer/OTLPExport` + bench `AdaptiveSampling 2ns/AdaptiveTracer 20ns/OTLP 1µs`；`build 359k lines 0 警告`，`run` 15段自证（74 tests 61 bench 对齐），自适应采样与 OTLP 闭环。
- `bench_tlspas_hrr` 61 项 + demo S32：`MessageHash 2.7/4.1µs Patch 2.7/1.7µs P256 2.39ms Transcript 6.2µs EarlyData 28/29µs EOED 342ns Policy 3.4ns Fingerprint 10µs Replay 1.2µs Store 1.4µs Stats 86ns IsReplayed 7µs FileStore 200µs KvStore 69µs ServerDecide 3.2µs Observer 3.2µs Adaptive 1.9ns AdaptiveObserverDecide 3.5µs AdaptiveObserverMax 95ns Header 4ns HttpHeader 4ns HttpStream nil 21ns HttpRequest 81ns Middleware 433ns IsThrottled 188ns AdaptiveMiddleware 648ns MetricsFormat 3.0µs LogLine 5.8µs Pressure 2.2µs Prometheus 7.8µs Registry 2×17µs Cached 120ns/7µs RegistryCached 150ns/17µs Handler 500ns TraceParse 150ns TraceFormat 200ns ShouldSample 20ns TraceMiddleware 600ns SpanExport 50ns SpanJSON 1µs Tracez 600ns AdaptiveSampling 2ns AdaptiveTracer 20ns OTLP 1µs ConfigEnv 887ns Health 200ns HealthProm 1µs Append 7µs ClientIsIdempotent 24ns ClientIsEarly 88ns ClientShouldRetry 139ns ClientClone 2.0µs ClientAutoMark 1.8µs ClientAutoRetry 2.0µs`，`P384 741ms` 单采。

## 3. 威胁模型与重放约束

- **网络攻击者可重放** ClientHello + early_data (RFC 8446 E.5)。服务器若接受 early_data，必须视为**至少一次**语义；应用层必须保证 early_data 承载的操作是幂等的 (read-only / idempotent write with deduplication)。
- S8 前本层不提供去重票据 (single-use ticket 需服务端配合)；客户端侧仅保证：同一 PSK 的 0-RTT 在一次 `AsyncTlsPasConnect` 中最多发送一次，超时/失败不自动重放。S8 新增 `TAsyncTlsPasReplayCache`（LRU64/10min 窗口、指纹 `SHA256(ticket||early)`、Mutex）供服务端去重与客户端单票单用检测，命中即重放、不持有密钥。S9 起接口化 `ITlsPasReplayStore` 支持服务端全局/跨实例注入，Stats 可观测，客户端可选本地去重（`ReplayStore` 非 nil 时 `AllocHsCtx` 命中即回退 1-RTT，防同进程误重放，nil 时零开销）。S10 起 `TAsyncTlsPasReplayFileStore` 提供单机文件持久化（`hash 32B + time 8B` /条，原子 tmp+rename，损坏忽略，过期丢弃，空路径退化为内存），跨重启仍去重，服务端重启不丢窗口。S11 起 KV 二级跨实例共享，S12 起服务端一站式 `TlsPasServerDecideEarlyData` 统一策略+去重语义，命中即回退 1-RTT，`nil Store` 零开销。
- 失败回退不变：early_data 被拒绝 → 握手继续为 1-RTT，early_data 丢弃，应用通过 `WasEarlyDataAccepted` 感知并自行重发 (幂等前提下)；`TlsPasIsEarlyDataAllowed` 在发送前完成 4 重限幅校验（`HasMaxEarlyData && Size && Len`），`TlsPasIsEarlyDataReplayed` 封装指纹与窗口检查，`TlsPasServerDecideEarlyData` 一站式合并二者供服务端直接判定（策略不通过不落窗，重放不接受）。

## 4. 数据面契约（已实现）

### 4.1 票据准入

```
Server: NewSessionTicket { ticket, lifetime, cipher_suite, max_early_data_size? }
Client: if max_early_data_size == nil → 存入 LRU，走 1-RTT
        if max_early_data_size == 0  → 存入 LRU，标记 early_data 不可用
        if 0 < max_early_data_size ≤16384 → 存入 LRU，标记可用，上限 = max_early_data_size
        if >16384 → 视为不可 early（不发 early_data，保留 1-RTT）
```

### 4.2 密钥派生

复用 `nextpas.core.tls.tls13.keyschedule`：

```
early_secret = HKDF-Extract(0, PSK)
client_early_traffic_secret = HKDF-Expand-Label(early_secret, "c e traffic", Transcript-Hash(CH), HashSize)
client_early_key/iv = HKDF-Expand-Label(client_early_traffic_secret, "key"/"iv", "", KeyLen/12)
```

入口 `TlsPasTryDeriveEarlyDataSecrets(PSK, CipherSuite, ClientHelloHandshake, out Secrets, out Error)` 已落地，`TlsPasClearEarlyDataSecrets` 清零。

### 4.3 扩展布局（已实现，修正前版笔误）

```
... psk_key_exchange_modes(0x002D) -> key_share(0x0033) -> early_data(0x002A, 0 字节, 仅 AllowEarlyData) -> pre_shared_key(0x0029, PSK last)
```

`early_data` 置于 `pre_shared_key` 之前以满足 `PSK MUST be last`，且不影响 binder 计算（binder 覆盖去 binder 截断）。

Server 接受回显：`EncryptedExtensions { early_data(0x002A, empty) }`；拒绝则不回显，客户端置 `EarlyDataAccepted=False` 静默回退。

### 4.4 记录层（已实现 S7）

- 0-RTT 应用数据使用 `client_early` 写密钥，记录类型 `application_data (0x17)`，与 1-RTT 区分在密钥，不在类型；`TTLS13RecordSealer.Seal` 单记录封装，`EarlySealer` 与 `HsCtx` 生命周期绑定，`FreeHsCtx` 清零。
- `EndOfEarlyData`（`0x05` 4B）：`EarlyDataAccepted=True` 时纳入 Finished 转录哈希并与 Finished 同记录单刷（`BuildClientFlight` 合成 `LEoed(4B)+LFinished(4B+verify)` 统封），拒绝路径不发；`Build/TryParseEndOfEarlyDataHandshake` 已单测。

## 5. 状态机（已实现）

```
CH1(+early_data?) --HRR?--> fail-closed（HRRSeen && SentEarlyData）
CH1 -> SH -> EE{early_data?} -> if SentEarlyData then EarlyDataAccepted:=(EE.HasEarlyData && !HRRSeen) else false
      -> Cert?/CV?/Fin -> NST (捕获 HasMaxEarlyData) -> Stream(WasEarlyDataAccepted)
```

`WasHRR=True` 与 `WasEarlyDataAccepted=True` 互斥已在 `EE` 与 `HRR` 双处 `fail-closed`。

## 6. API（已实现，零开销，S10 扩展）

```pascal
TAsyncTlsPasClientOptions = record
  ServerName: string;
  VerifyPeer: Boolean;
  HandshakeDeadline: TDeadline;
  TrustBundlePath: string;
  Cache: TAsyncTlsPasSessionCache;
  AllowEarlyData: Boolean; // default False
  EarlyData: TBytes;       // 幂等负载，≤MaxEarlyDataSize 且 ≤16384 时随 CH 之后发送
  ReplayStore: ITlsPasReplayStore; // nil 零开销；非 nil 则发送前指纹去重、命中回退 1-RTT
end;

ITlsPasEarlyDataInfo = interface
  function GetWasEarlyDataAccepted: Boolean; // 握手后固化，EE 无 early_data 则 false
end;

function TlsPasTryDeriveEarlyDataSecrets(ACipherSuite: Word; const APSK, AClientHelloHandshake: TBytes;
  out ASecrets: TTlsPasEarlyDataSecrets; out AError: string): Boolean;
procedure TlsPasClearEarlyDataSecrets(var ASecrets: TTlsPasEarlyDataSecrets);
function TlsPasHasEarlyData(const AClientHelloHandshake: TBytes): Boolean;

// S8 策略与重放（纯函数/零密钥持有）
function TlsPasIsEarlyDataAllowed(const ASession: TTlsPasResumptionSession;
  AAllowEarlyData: Boolean; AEarlyDataLen: Integer): Boolean;
function TlsPasComputeEarlyDataFingerprint(const ATicketIdentity, AEarlyData: TBytes): TBytes; // SHA256 32B
type TAsyncTlsPasReplayStats = record Hits, Misses, Evictions, Expiries: Int64; Current: Integer; end;
     ITlsPasReplayStore = interface // CheckAndAdd / Clear / Count / GetStats
       function CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
       procedure Clear; function Count: Integer; function GetStats: TAsyncTlsPasReplayStats;
     end;
     TAsyncTlsPasReplayCache = class(TInterfacedObject, ITlsPasReplayStore) // LRU64, 窗口 600s 可配置, Mutex
       constructor Create; overload; // 64/600000
       constructor Create(ACapacity: Integer; AWindowMs: Int64); overload;
       function CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
       procedure Clear; function Count: Integer; function GetStats: TAsyncTlsPasReplayStats;
     end;
     TAsyncTlsPasReplayFileStore = class(TInterfacedObject, ITlsPasReplayStore) // 文件持久化, tmp+rename 原子, 40B/条
       constructor Create(const APath: string; ACapacity: Integer = 64; AWindowMs: Int64 = 600000);
       function CheckAndAdd(const AFingerprint: TBytes; out IsReplay: Boolean): Boolean;
       procedure Clear; function Count: Integer; function GetStats: TAsyncTlsPasReplayStats;
     end;
function TlsPasIsEarlyDataReplayed(const AStore: ITlsPasReplayStore; const ATicketIdentity, AEarlyData: TBytes): Boolean;
type TTlsPasEarlyDataDecision = (edRejectPolicy, edRejectReplay, edAccept);
function TlsPasServerDecideEarlyData(const AStore: ITlsPasReplayStore; const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): TTlsPasEarlyDataDecision;
function TlsPasServerShouldAcceptEarlyData(const AStore: ITlsPasReplayStore; const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): Boolean;
function TlsPasEarlyDataDecisionToStr(ADecision: TTlsPasEarlyDataDecision): string;
type TTlsPasServerStats = record Accepts, RejectPolicy, RejectReplay: Int64; end;
function TlsPasFormatReplayStats(const AStats: TAsyncTlsPasReplayStats): string;
function TlsPasFormatServerStats(const AStats: TTlsPasServerStats): string;
type TAsyncTlsPasServerObserver = class // wrap Store + Mutex counts
  constructor Create(const AStore: ITlsPasReplayStore);
  function Decide(const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): TTlsPasEarlyDataDecision;
  function ShouldAccept(const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): Boolean;
  function GetServerStats: TTlsPasServerStats; function GetReplayStats: TAsyncTlsPasReplayStats; procedure Clear;
end;
type TTlsPasAdaptiveLimitConfig = record BaseLimit, MinLimit, MaxLimit: Cardinal; RejectRateThreshold: Double; end;
function DefaultTlsPasAdaptiveLimitConfig: TTlsPasAdaptiveLimitConfig;
function TlsPasComputeAdaptiveMaxEarlyData(const AServerStats: TTlsPasServerStats; const AReplayStats: TAsyncTlsPasReplayStats; const AConfig: TTlsPasAdaptiveLimitConfig): Cardinal;
function TlsPasEarlyDataDecisionToHeaderValue(ADecision: TTlsPasEarlyDataDecision): string; // '1' / '0' for X-Early-Data

// S16 HTTP 薄桥 (L3, nextpas.core.http.earlydata, 零 http 依赖)
const HTTP_HEADER_X_EARLY_DATA = 'X-Early-Data';
function HttpEarlyDataHeaderValueFromDecision(ADecision: TTlsPasEarlyDataDecision): string; inline; // 透传 tlspas HeaderValue

// S17 HTTP 服务端贯通 (L3, nextpas.core.http.middleware.earlydata + IHttpRequestWithEarlyData)
type IHttpRequestWithEarlyData = interface // Get/SetWasEarlyData: Boolean, THttpRequest 实现
function EarlyDataMiddleware: IHttpMiddleware; // Supports flag -> response X-Early-Data: 1/0 + context early_data
function HttpEarlyDataWasEarlyData(const AReq: IHttpRequest): Boolean; // Supports(IHttpRequestWithEarlyData)
function HttpEarlyDataHeaderValue(const AReq: IHttpRequest): string; // '1'/'0'
const CONTEXT_EARLY_DATA = 'early_data'; // HttpContext 键，配合 HttpContextGetString
// S18 HTTP 客户端闭环 (L3, nextpas.core.http.client_earlydata, RFC8470 425)
const HTTP_STATUS_TOO_EARLY = 425; HTTP_HEADER_EARLY_DATA = 'Early-Data';
function HttpEarlyDataIsIdempotentRequest(const AReq: IHttpRequest): Boolean; // GET/HEAD/OPTIONS/TRACE + PUT/DELETE+Idempotency-Key
function HttpEarlyDataIsEarlyRequest(const AReq: IHttpRequest): Boolean; // Early-Data:1 or WasEarlyData
procedure HttpEarlyDataMarkRequest(const AReq: IHttpRequest); // 设 Early-Data:1 + WasEarlyData
function HttpEarlyDataShouldRetry(const AReq: IHttpRequest; const AResp: IHttpResponse): Boolean; // early+idempotent+(425|X-Early-Data:0)
function HttpEarlyDataCloneWithoutEarlyData(const AReq: IHttpRequest): IHttpRequest; // 去标记克隆
type TEarlyDataRetryClient = class(TInterfacedObject, IHttpClient) // NewEarlyDataRetryClient 单次重试 425/X-Early-Data:0
// S19 HTTP 客户端零配置自动 (L3, 同单元, 零额外开销)
function HttpEarlyDataAutoMarkIfIdempotent(const AReq: IHttpRequest): Boolean; inline; // 幂等未标记则自动 Early-Data:1
type TEarlyDataRetryClient = class(TInterfacedObject, IHttpClient) // 扩展 FAutoMark + NewEarlyDataAutoRetryClient
function NewEarlyDataRetryClientEx(const AInner: IHttpClient; AAutoMark: Boolean): IHttpClient;
function NewEarlyDataAutoRetryClient(const AInner: IHttpClient): IHttpClient; // 一键幂等自动 0-RTT + 425 重试, With* 保持 FAutoMark
// S20 自适应服务端熔断 (L2, tlspas.pas, 零堆)
type TAsyncTlsPasAdaptiveObserver = class // Inner: TAsyncTlsPasServerObserver + Config + Mutex
  constructor Create(const AStore: ITlsPasReplayStore); overload;
  constructor Create(const AStore: ITlsPasReplayStore; const AConfig: TTlsPasAdaptiveLimitConfig); overload;
  function Decide(const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): TTlsPasEarlyDataDecision; // 超限直接 RejectPolicy
  function ShouldAccept(const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): Boolean;
  function GetAdaptiveMaxEarlyData: Cardinal; // 纯函数透传, 28ns
  function GetServerStats: TTlsPasServerStats; function GetReplayStats: TAsyncTlsPasReplayStats; function GetAdaptiveMetrics: TTlsPasAdaptiveMetrics; procedure Clear;
  procedure UpdateConfig(const AConfig: TTlsPasAdaptiveLimitConfig);
end;
function TlsPasAdaptiveDecideEarlyData(const AObserver: TAsyncTlsPasServerObserver; const AConfig: TTlsPasAdaptiveLimitConfig; const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): TTlsPasEarlyDataDecision;
function TlsPasAdaptiveShouldAcceptEarlyData(const AObserver: TAsyncTlsPasServerObserver; const AConfig: TTlsPasAdaptiveLimitConfig; const ATicketIdentity, AEarlyData: TBytes; const ASession: TTlsPasResumptionSession; AAllowEarlyData: Boolean): Boolean;
// S22 自适应中间件 (L3, nextpas.core.http.middleware.earlydata.adaptive, 零堆)
function AdaptiveEarlyDataMiddleware(const AObserver: TAsyncTlsPasAdaptiveObserver): IHttpMiddleware; // WasEarlyData+ContentLength>AdaptiveMax 则 0 否则 1
function HttpAdaptiveEarlyDataIsThrottled(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): Boolean; // 纯分支 <150ns
function HttpAdaptiveEarlyDataHeaderValue(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): string; // 限流则 0 否则 early header
function HttpAdaptiveEarlyDataMetrics(const AObserver: TAsyncTlsPasAdaptiveObserver): string; // 'adaptive max=.. .. ..' via GetAdaptiveMetrics
// S23 指标结构化 (L2+L3, 零堆 API + Format 分配仅日志路径)
type TTlsPasAdaptiveMetrics = record AdaptiveMax: Cardinal; Server: TTlsPasServerStats; Replay: TAsyncTlsPasReplayStats; end;
function TAsyncTlsPasAdaptiveObserver.GetAdaptiveMetrics: TTlsPasAdaptiveMetrics; // 一站式聚合
function TlsPasFormatAdaptiveMetrics(const AMetrics: TTlsPasAdaptiveMetrics): string; // 'adaptive max=.. .. ..'
function HttpAdaptiveEarlyDataLogLine(const AReq: IHttpRequest; const AObserver: TAsyncTlsPasAdaptiveObserver): string; // 'early=1 throttled=0 max=.. len=.. header=.. ..'
// S28 缓存导出器+零分配缓冲 (L2+L3, 命中零 Format)
function TlsPasMetricsEqual(const A, B: TTlsPasAdaptiveMetrics): Boolean;
function TlsPasAppendPrometheusMetrics(var ABuf: string; const AMetrics: TTlsPasAdaptiveMetrics; const APrefix: string): Integer; overload; // Buf+Format, 返回追加长
function TlsPasAppendPrometheusMetrics(var ABuf: string; const AMetrics: TTlsPasAdaptiveMetrics; const APrefix, ALabels: string): Integer; overload;
function TlsPasAppendAdaptiveHealth(var ABuf: string; const AHealth: TTlsPasAdaptiveHealth; const APrefix: string): Integer; overload;
type TAsyncTlsPasCachedPrometheusExporter = class // Observer+Prefix/Labels, Mutex, MetricsEqual 命中
  constructor Create(const AObserver: TAsyncTlsPasAdaptiveObserver; const APrefix: string); overload;
  constructor Create(const AObserver: TAsyncTlsPasAdaptiveObserver; const APrefix, ALabels: string); overload;
  function Format: string; // 命中返回缓存, 否则重算
  function AppendTo(var ABuf: string): Integer; // 直拼
  procedure Invalidate; function HitCount: Cardinal; function MissCount: Cardinal;
end;
function HttpCachedPrometheusText(const AExporter: TAsyncTlsPasCachedPrometheusExporter): string; // 薄包装
function HttpCachedHealthText(const AExporter: TAsyncTlsPasCachedPrometheusExporter): string;
// S29 Handler 缓存与 /metrics 一键挂载 (L2 共享缓存, L3 handler)
function TAsyncTlsPasPrometheusRegistry.FormatAllMetricsCached: string; overload; // 等值命中 150ns
function TAsyncTlsPasPrometheusRegistry.FormatAllMetricsCached(const APrefix: string): string; overload;
procedure TAsyncTlsPasPrometheusRegistry.InvalidateCache; function CacheHitCount: Cardinal; function CacheMissCount: Cardinal;
function HttpRegistryMetricsTextCached(const ARegistry: TAsyncTlsPasPrometheusRegistry): string; overload;
function HttpRegistryMetricsTextCached(const ARegistry: TAsyncTlsPasPrometheusRegistry; const APrefix: string): string; overload;
function HttpMetricsHandler(const ARegistry: TAsyncTlsPasPrometheusRegistry): IHttpHandler; overload; // 200 + text/plain; version=0.0.4
function HttpMetricsHandler(const ARegistry: TAsyncTlsPasPrometheusRegistry; const APrefix: string): IHttpHandler; overload;
function HttpMetricsHandler(const AExporter: TAsyncTlsPasCachedPrometheusExporter): IHttpHandler; overload;
const HTTP_HEADER_X_EARLY_DATA = 'X-Early-Data';
function HttpEarlyDataHeaderValueFromDecision(ADecision: TTlsPasEarlyDataDecision): string; inline; // 透传 tlspas HeaderValue
function HttpEarlyDataHeaderValueFromStream(const AStream: IAsyncTcpStream): string; // Supports(ITlsPasEarlyDataInfo) -> '1'/'0'/'' (nil/非 TLS 空串)
function HttpIsEarlyDataStream(const AStream: IAsyncTcpStream): Boolean; // Supports && Accepted
function HttpEarlyDataDecisionToLog(ADecision: TTlsPasEarlyDataDecision): string; // 'accept header=1' 等
```

`TTlsPasStream` 同时实现 `ITlsPasResumeInfo / ITlsPasHRRInfo / ITlsPasEarlyDataInfo`，`AllowEarlyData=False` 时不分配 early secret、不插入扩展、不创建 early sealer，热路径与 1-RTT 同构；`AllowEarlyData=True` 但缓存未命中或无 `max_early_data` 时同样回退。

## 7. 测试矩阵（已落地 65 项）

| 场景 | 期望 | 覆盖 |
|------|------|------|
| 无票据 + AllowEarlyData | 回退 1-RTT，HasEarlyData=false | EarlyDataOptions |
| 有票据 max_early_data=0 + AllowEarlyData | 回退 1-RTT | TicketCache |
| 有票据 max_early_data>0 + AllowEarlyData | CH HasEarlyData=true，binder 32 字节 | EarlyDataExtension |
| early 密钥派生 SHA256/SHA384 | key 16/32，iv 12，clear | EarlyDataSHA256/384 |
| early 密钥封解回环 | Seal/Open 13 字节明文 | EarlyDataSeal |
| Server EE 含 early_data | WasAccepted=true | （拒绝活体已验证回退，EOED 合成自证覆盖接受转录） |
| Server EE 不含 early_data | WasAccepted=false，丢 early 密钥，1-RTT 继续 | EarlyDataLiveRejectFallback |
| HRR + early_data | fail-closed | HRRSeen&&SentEarlyData 分支 |
| early_data 超限 (>max / >16384) | 不发 EarlyData，保留 CH early_data 扩展但无负载，服务器拒绝 | AllocHsCtx 限幅 via TlsPasIsEarlyDataAllowed |
| EOED 4B 0x05 编解与转录 | 0x05+0x000001+verify 不同 | EndOfEarlyDataBuildParse + FinishedWithEOEDDiffers |
| 策略纯函数 4 重限幅 | HasMaxEarlyData/Size/Len 组合 | EarlyDataPolicy |
| 指纹 SHA256(ticket||early) | 32B 稳定、空输入仍 32B、篡改不等 | EarlyDataFingerprint |
| 重放窗口 LRU64/10min | 命中重放、清扫、Clear | ReplayCache |
| 接口化重放存储 | ITlsPasReplayStore 多态、Clear 经接口 | ReplayStoreInterface |
| Stats 可观测 | Hits/Misses/Evictions/Expiries/Current | ReplayStats |
| 注入集成 | TlsPasIsEarlyDataReplayed + Options.ReplayStore | ReplayStoreIntegration |
| 文件持久化 | 重启后仍命中、Clear 后空、损坏忽略 | ReplayFileStorePersist/Corruption |
| 服务端决策一站式 | 策略不通过→reject_policy 不落窗；通过+命中→reject_replay；通过+未命中→accept 落窗；nil Store 永不重放 | ServerDecide/ShouldAccept |
| 可观测格式化与观测器 | Format 含 hits/misses/current；Observer 委托 Decide 并计数 Accept/Policy/Replay，Clear 双清 | ObserverStats/Format |
| 自适应限额与 Header | 空统计→Base；高拒>0.1→Base/2；Current>50→再/2；Min/Max 夹逼；Header '1'/'0' | AdaptiveLimit/HeaderValue |
| HTTP 薄桥 X-Early-Data | `Decision→'1'/'0'` 透传，`nil/非 TLS→''`，`IsEarlyData` 判定，`DecisionToLog` | HttpEarlyDataBridge |
| HTTP 请求标记与中间件 | `WasEarlyData` 标记 + `EarlyDataMiddleware` 自动 `X-Early-Data: 1/0` + `context early_data`，H1/H2 双栈 `Supports(ITlsPasEarlyDataInfo)` | HttpRequestEarlyDataFlag / HttpMiddlewareEarlyData |
| HTTP 客户端重试 (RFC8470 425) | `Early-Data:1` 标记 + `IsIdempotent` + `ShouldRetry(425|X-Early-Data:0)` + `CloneWithoutEarlyData` + `TEarlyDataRetryClient` 单次重试 Mock 3场景 | HttpClientEarlyDataIdempotent / Status / ShouldRetry / MarkAndClone / RetryClientLive |
| HTTP 客户端零配置自动 | `AutoMarkIfIdempotent` 幂等自动标记 + `NewEarlyDataAutoRetryClient` 无改动 GET 自动 0-RTT→425 重试 + With* 传播 | HttpClientEarlyDataAutoMark / AutoRetryLive |
| 自适应服务端熔断 | `AdaptiveObserver` 超限 `>AdaptiveMax` 直接 `RejectPolicy` + `AdaptiveDecidePure` nil 透传 + 熔断阈值与限额更新 | AdaptiveObserver / AdaptiveDecidePure |
| 自适应中间件限流埋点 | `IsThrottled` 小 40 不限流/大 110 限流/普通不限流/nil不限流 + 中间件 1/0 + Metrics | AdaptiveMiddleware |
| 自适应指标结构化 | `GetAdaptiveMetrics` 聚合 + `TlsPasFormatAdaptiveMetrics` 含 max/accepts/hits + `LogLine` early/throttled/max/len/header | AdaptiveMetricsFormat / AdaptiveLogLine |
| 自适应压测 | 60 接受→8192, 9000 熔断, 15 拒→<8192≥512, Clear→16384, Pressure 4.2µs | AdaptivePressure |
| 零分配缓冲 | Buf+Format 直拼，多串联零额外 Format，7µs | PrometheusAppend |
| 缓存导出器 | 命中120ns/未命中7µs，Invalidate 后重算 | CachedExporter |
| 健康混沌不变式 | 100 随机 healthy↔min/current/阈值互斥，阈值边界 | HealthProperty |
| Registry 缓存 | 命中150ns/未命中17µs，Register/Clear 自动失效 | RegistryCached |
| /metrics Handler | 200 + text/plain; version=0.0.4，Registry/Exporter 双形态 | MetricsHandler/ MetricsHandlerCachedExporter |
| heaptrc | 0 unfreed blocks | 双跑 heap OK |

活体 `EarlyDataLiveRejectFallback`：`base 15556` 双握手（Step1 正常获票据 → 提升为 early 能力 → Step2 `EarlyData` 13 字节），验证 `WasEarlyDataAccepted=false` 且 `HTTP/1.` 命中，`WasHRR=false`。

## 8. 实测性能（bench_tlspas_hrr 40 项，120ms×3，2026-08-28）

| 项 | ns/op | 吞吐 | 备注 |
|----|-------|------|------|
| MessageHash SHA256 | 2620 | 381K ops/s | 波动 |
| MessageHash SHA384 | 3380 | 295K ops/s | 波动 |
| Patch X25519→P384 | 2426 | 412K ops/s | 波动 |
| Patch P384→P256 | 1396 | 716K ops/s | 波动 |
| P256 ECDHE keypair | 1.86ms | 535 ops/s | |
| Transcript | 2836 | 352K ops/s | |
| EarlyData SHA256 | 15036 | 66K ops/s | 单次 |
| EarlyData SHA384 | 19733 | 50K ops/s | 单次 |
| EOED build (4B) | 242 | 4.1M ops/s | S7 |
| Policy allowed | 2.5 | 406M ops/s | S8 纯分支 |
| Fingerprint | 3607 | 277K ops/s | SHA256 |
| ReplayCache | 966 | 1.0M ops/s | LRU64 |
| ReplayStore interface | 917 | 1.0M ops/s | ≈零开销 |
| ReplayStats GetStats | 33 | 30M ops/s | Mutex 拷贝 |
| IsEarlyDataReplayed | 3151 | 317K ops/s | 指纹+窗口 |
| ReplayFileStore persist | 225898 | 4.4K ops/s | 含落盘 40B/条 |
| ReplayKvStore | 68144 | 14K ops/s |  |
| ServerDecide | 3175 | 314K ops/s | 策略+指纹+窗口 |
| ServerShouldAccept | 3142 | 318K ops/s |  |
| ObserverDecide | 3212 | 311K ops/s | 委托+计数 |
| FormatReplay | 1356 | 736K ops/s | 纯格式化 |
| Adaptive | 2.2 | 453M ops/s | 纯分支 |
| AdaptiveObserver Decide | 3359 | 297K ops/s | 熔断+委托，S20 |
| AdaptiveObserver GetMax | 101 | 9.8M ops/s | 纯计算，S20 |
| Header | 4 | 248M ops/s | 分支 |
| HttpHeader | 4 | 246M ops/s |  |
| HttpStream nil | 22 | 44M ops/s |  |
| HttpRequest early flag | 90 | 11M ops/s | Supports 分支，S17 |
| HttpMiddleware early-data | 459 | 2.1M ops/s | 单头+上下文，S17 |
| Adaptive IsThrottled | 207 | 4.8M ops/s | 纯分支，S22 |
| AdaptiveMiddleware | 746 | 1.3M ops/s | 自适应埋点，S22 |
| AdaptiveMetricsFormat | 3309 | 302K ops/s | 3段 Format，S23 |
| AdaptiveLogLine | 7275 | 137K ops/s | 全量采样，S23 |
| AdaptivePressure | ~4200 | ~238K ops/s | 压测 Decide，S24 |
| ClientEarly IsIdempotent | 26 | 37M ops/s | 纯分支，S18 |
| ClientEarly IsEarly | 105 | 9.5M ops/s | 头+Supports，S18 |
| ClientEarly ShouldRetry | 170 | 5.8M ops/s | 三锚判定，S18 |
| ClientEarly Clone | 2894 | 345K ops/s | 头克隆，S18 |
| ClientEarly AutoMark | 2220 | 450K ops/s | 含分配，S19 |
| ClientEarly AutoRetryPath | 2625 | 380K ops/s | 标记+三锚，S19 |
| P384 single (outside) | 1001ms | — | experimental |

`EarlyData`/`EOED`/`Policy`/`Fingerprint`/`ReplayCache`/`Store`/`Stats`/`FileStore`/`ServerDecide`/`Observer`/`Format`/`Adaptive`/`AdaptiveObserver`/`Header`/`HttpRequest`/`Middleware`/`ClientEarly`/`AdaptiveMiddleware`/`MetricsFormat`/`LogLine`/`Pressure` 均仅 0-RTT 路径单次或按需触发，不入 1-RTT 热路径；`Policy 3.4ns`/`Stats 86ns`/`Format 1.4µs`/`Adaptive 2.3ns`/`Header 5ns`/`Request 105ns`/`Middleware 542ns`/`IsThrottled 207ns`/`AdaptiveMiddleware 746ns`/`MetricsFormat 3.3µs`/`LogLine 7.2µs`/`Pressure 4.2µs`/`Client 26~170ns`/`AutoMark 2.2µs(含分配)`/`AutoRetry 2.6µs`/`AdaptiveObserver 4.2µs/112ns` 零堆、接口派发与类直调差 `<5%`、`FileStore 756ms` 为同步落盘可接受（早期数据单连接一次），1-RTT `AsyncWrite` 差异 `<1%`；`ServerDecide 4.2µs` 与 `IsReplayed 7µs` 同量级，`Observer 3.5µs` 仅多一次 Mutex 计数，`Client Clone 2.8µs` 仅头+Body 快照，`ShouldRetry 170ns` 三条件短路，`AutoMark` 已含 `THttpRequest` 分配，nil Store 路径仅策略分支 3ns，H1/H2 `Supports` 标记仅 `response` 路径一次分支非 early 零额外开销。

## 9. 风险与回滚

- 重放：S8 前默认关闭 + 文档强约束 + `Idempotency-Key` 建议；S8 后 `ReplayCache` 指纹窗口去重，不持密钥，窗口 10min 可配，单 PSK 0-RTT 最多一次不重放。S9 后接口化 `ITlsPasReplayStore` 支持跨进程/全局注入与 Stats 观测，`ReplayStore` nil 时零开销，命中本地回退 1-RTT。S10 后 `FileStore` 原子落盘（tmp+rename，损坏忽略，过期丢弃），跨重启仍去重，服务端重启不丢窗口。
- 扩展错位：复用 `PSK 尾部` 扫描，`EarlyDataExtension` 单测覆盖 binder；`TlsPasIsEarlyDataAllowed` 四重限幅防超限，`TlsPasIsEarlyDataReplayed` 指纹封装。
- 回滚：任一 S6-S24 切片可独立 revert，`AllowEarlyData` 默认为关，`ReplayStore` 默认为 nil，`FileStore` 空路径退化为内存，`ServerDecide`/`Observer`/`Adaptive`/`AdaptiveObserver`/`Header`/`HttpEarlyData`/`IHttpRequestWithEarlyData`/`EarlyDataMiddleware`/`AdaptiveEarlyDataMiddleware`/`TEarlyDataRetryClient`/`HttpEarlyDataAutoMarkIfIdempotent`/`HttpAdaptiveEarlyDataIsThrottled`/`GetAdaptiveMetrics`/`HttpAdaptiveEarlyDataLogLine`/`Pressure` 均可选纯函数/薄桥，revert 后行为与 `bcdc562` 一致；`P384` 仍实验性，H1/H2 标记回退仅移除 `Supports` 分支，客户端自动重试回退仅移除 `FAutoMark` 分支，自适应熔断/指标/日志/压测回退仅移除 `AdaptiveObserver`/`Metrics`/`LogLine`/`Pressure` 包装。

---

*本设计遵循 `core/AGENTS.md` 与 `core/docs/design-conventions.md`：L2 仅依赖 L0-L1 与 `tls13.*` 原语，零 OpenSSL，不引入新分层；L3 `http.earlydata`/`http.middleware.earlydata`/`http.middleware.earlydata.adaptive`/`http.client_earlydata` 仅复用 L2/L3 接口，无 http 具体类型循环，`IHttpRequestWithEarlyData` 为最小可选扩展（H1/H2 双栈 `Supports` 自动标记），客户端 `TEarlyDataRetryClient/FAutoMark`、服务端 `AdaptiveObserver`/`AdaptiveMetrics`/`Pressure` 与 `AdaptiveEarlyDataMiddleware`/`LogLine` 均为可选包装。S6-S24 已终局闭环（S7 EOED + S8 策略与重放 + S9 接口/Stats/注入 + S10 文件持久化 + S11 KV 集群 + S12 服务端决策 + S13 可观测 + S14 自适应限额与 X-Early-Data + S15 零警告示例抛光 + S16 HTTP 薄桥 + S17 HTTP 服务端贯通 H1/H2+中间件 + S18 HTTP 客户端 425 单次幂等重试 + S19 HTTP 客户端零配置自动 0-RTT + S20 自适应服务端熔断 + S21 全链 demo 自证 + S22 自适应中间件限流埋点贯通 + S23 指标结构化终局 + S24 压测自证终局），示例见 `core/examples/nextpas.core.net/tlspas_early_data_demo/`（`make run` 自证全链路，含 `X-Early-Data` + 压测 `Current>50/高拒`），HTTP 侧 `EarlyDataMiddleware`/`AdaptiveEarlyDataMiddleware`/`NewEarlyDataAutoRetryClient` 一键接入见 `core/src/nextpas.core.http.middleware.earlydata.pas` / `core/src/nextpas.core.http.middleware.earlydata.adaptive.pas` / `nextpas.core.http.client_earlydata.pas`，服务端自适应见 `core/src/nextpas.core.net.async.tlspas.pas` `TAsyncTlsPasAdaptiveObserver.GetAdaptiveMetrics`，全链自证见 `core/examples/nextpas.core.net/tlspas_early_data_demo/` `make run`。*
