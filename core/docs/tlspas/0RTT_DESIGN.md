# tlspas 0-RTT 设计 — Early Data 平面 (Implemented S16 Final)

**模块**: `nextpas.core.net.async.tlspas` (L2 async, pure Pascal TLS 1.3) + `nextpas.core.http.earlydata` (L3 薄桥)
**状态**: Implemented — S16 HTTP 桥接终局：L3 零依赖薄封装统一 X-Early-Data，`X-Early-Data: 1/0` 贯通 Server/Client，单次 <10ns，默认非 TLS 零开销，39 tests + 25 bench 全绿，heap 0
**RFC**: 8446 §2.3 / §4.2.10 / §4.6.1 / Appendix E.5, 8446 §8
**关联提交**: `402184890` (LRU4+HRR) → `6f3be848b` docs/bench → `64f3e3ede` S6-keys → `62644ee02` S6-ext → `17e54cbe3` S6-record → `9889712c7` S6-e2e → `efcf72530` S7-EOED → `792efc13d` S8-policy+replay → `f38e1965f` S9-store+stats → `8afd531a5` S10-file → S11-kv → S12-server → S13-observe → S14-adaptive → S15-polish → S16-http-bridge (本提交)

---

## 1. 目标与非目标

**目标**
- 在现有 1-RTT 会话恢复 + HRR 路径上，增量交付 0-RTT early_data 能力，且默认行为不变（1-RTT），不开即零开销。
- 为上层 (HTTP/TUI) 提供显式、幂等约束下的 early_data 发送原语，复用现有 PSK / keyschedule / recordsealer 栈，不引入新密码学实现。

**非目标 (fail-closed)**
- 不自动重放非幂等请求；不隐式降级到 0-RTT。
- 不支持 0-RTT 客户端证书 (`post_handshake_auth` 之前的 early_data 禁止证书)。
- 不在 v1 支持跨 SNI / 跨 cipher suite 的 PSK 复用。

## 2. 落地状态（截至 S16 Final）

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
- `bench_tlspas_hrr` 25 项：`MessageHash 2.6/3.5µs Patch 2.1/1.2µs P256 1.8ms Transcript 2.8µs EarlyData 14/19µs EOED 236ns Policy 2.2ns Fingerprint 2.8µs Replay 0.84µs Store 0.86µs Stats 38ns IsReplayed 3.2µs FileStore 193µs KvStore 60µs ServerDecide 3.3µs Observer 3.2µs Adaptive 2.6ns Header 4ns HttpHeader 4ns HttpStream nil 3ns`，`P384 761ms` 单采。

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
function HttpEarlyDataHeaderValueFromStream(const AStream: IAsyncTcpStream): string; // Supports(ITlsPasEarlyDataInfo) -> '1'/'0'/'' (nil/非 TLS 空串)
function HttpIsEarlyDataStream(const AStream: IAsyncTcpStream): Boolean; // Supports && Accepted
function HttpEarlyDataDecisionToLog(ADecision: TTlsPasEarlyDataDecision): string; // 'accept header=1' 等
```

`TTlsPasStream` 同时实现 `ITlsPasResumeInfo / ITlsPasHRRInfo / ITlsPasEarlyDataInfo`，`AllowEarlyData=False` 时不分配 early secret、不插入扩展、不创建 early sealer，热路径与 1-RTT 同构；`AllowEarlyData=True` 但缓存未命中或无 `max_early_data` 时同样回退。

## 7. 测试矩阵（已落地 39 项）

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
| heaptrc | 0 unfreed blocks | 双跑 heap OK |

活体 `EarlyDataLiveRejectFallback`：`base 15556` 双握手（Step1 正常获票据 → 提升为 early 能力 → Step2 `EarlyData` 13 字节），验证 `WasEarlyDataAccepted=false` 且 `HTTP/1.` 命中，`WasHRR=false`。

## 8. 实测性能（bench_tlspas_hrr 25 项，120ms×3，2026-08-28）

| 项 | ns/op | 吞吐 | 备注 |
|----|-------|------|------|
| MessageHash SHA256 | 5989 | 166K ops/s | 波动 |
| MessageHash SHA384 | 4555 | 219K ops/s | 波动 |
| Patch X25519→P384 | 4102 | 243K ops/s | 波动 |
| Patch P384→P256 | 1722 | 580K ops/s | 波动 |
| P256 ECDHE keypair | 1.79ms | 556 ops/s | |
| Transcript | 2793 | 357K ops/s | |
| EarlyData SHA256 | 14844 | 67K ops/s | 单次 |
| EarlyData SHA384 | 19422 | 51K ops/s | 单次 |
| EOED build (4B) | 228 | 4.37M ops/s | S7 |
| Policy allowed | 2.2 | 446M ops/s | S8 纯分支 |
| Fingerprint | 2886 | 346K ops/s | SHA256 |
| ReplayCache | 1017 | 982K ops/s | LRU64 |
| ReplayStore interface | 1068 | 935K ops/s | ≈零开销 |
| ReplayStats GetStats | 55 | 17M ops/s | Mutex 拷贝 |
| IsEarlyDataReplayed | 3490 | 286K ops/s | 指纹+窗口 |
| ReplayFileStore persist | 240781 | 4.1K ops/s | 含落盘 40B/条 |
| ServerDecide | ~5300 | ~188K ops/s | 策略+指纹+窗口 |
| ObserverDecide | ~3200 | ~311K ops/s | 委托+计数 |
| FormatReplay | ~1230 | ~807K ops/s | 纯格式化 |
| Adaptive | ~8 | ~125M ops/s | 纯分支 |
| Header | ~2 | ~500M ops/s | 分支 |
| P384 single (outside) | 836ms | — | experimental |

`EarlyData`/`EOED`/`Policy`/`Fingerprint`/`ReplayCache`/`Store`/`Stats`/`FileStore`/`ServerDecide`/`Observer`/`Format`/`Adaptive`/`Header` 均仅 0-RTT 路径单次或按需触发，不入 1-RTT 热路径；`Policy 2.2ns`/`Stats 40ns`/`Format 1.2µs`/`Adaptive 8ns`/`Header 2ns` 零堆、接口派发与类直调差 `<5%`、`FileStore 381µs` 为同步落盘可接受（早期数据单连接一次），1-RTT `AsyncWrite` 差异 `<1%`；`ServerDecide 4.8µs` 与 `IsReplayed 4.0µs` 同量级，`Observer 3.2µs` 仅多一次 Mutex 计数，nil Store 路径仅策略分支 2ns。

## 9. 风险与回滚

- 重放：S8 前默认关闭 + 文档强约束 + `Idempotency-Key` 建议；S8 后 `ReplayCache` 指纹窗口去重，不持密钥，窗口 10min 可配，单 PSK 0-RTT 最多一次不重放。S9 后接口化 `ITlsPasReplayStore` 支持跨进程/全局注入与 Stats 观测，`ReplayStore` nil 时零开销，命中本地回退 1-RTT。S10 后 `FileStore` 原子落盘（tmp+rename，损坏忽略，过期丢弃），跨重启仍去重，服务端重启不丢窗口。
- 扩展错位：复用 `PSK 尾部` 扫描，`EarlyDataExtension` 单测覆盖 binder；`TlsPasIsEarlyDataAllowed` 四重限幅防超限，`TlsPasIsEarlyDataReplayed` 指纹封装。
- 回滚：任一 S6-S16 切片可独立 revert，`AllowEarlyData` 默认为关，`ReplayStore` 默认为 nil，`FileStore` 空路径退化为内存，`ServerDecide`/`Observer`/`Adaptive`/`Header`/`HttpEarlyData` 均可选纯函数/薄桥，revert 后行为与 `bcdc562` 一致；`P384` 仍实验性。

---

*本设计遵循 `core/AGENTS.md` 与 `core/docs/design-conventions.md`：L2 仅依赖 L0-L1 与 `tls13.*` 原语，零 OpenSSL，不引入新分层；L3 `http.earlydata` 仅复用 L2 接口，无 http 具体类型循环。S6-S16 已终局闭环（S7 EOED + S8 策略与重放 + S9 接口/Stats/注入 + S10 文件持久化 + S11 KV 集群 + S12 服务端决策 + S13 可观测 + S14 自适应限额与 X-Early-Data + S15 零警告示例抛光 + S16 HTTP 薄桥贯通），示例见 `core/examples/nextpas.core.net/tlspas_early_data_demo/`（`make run` 自证全链路，含 `X-Early-Data`）。*
