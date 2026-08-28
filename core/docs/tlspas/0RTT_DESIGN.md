# tlspas 0-RTT 设计 — Early Data 平面 (Implemented S6)

**模块**: `nextpas.core.net.async.tlspas` (L2 async, pure Pascal TLS 1.3)
**状态**: Implemented — S6 全切片已落主线，默认 1-RTT 零开销，early_data 可选启用
**RFC**: 8446 §2.3 / §4.2.10 / §4.6.1 / Appendix E.5, 8446 §8
**关联提交**: `402184890` (LRU4+HRR) → `6f3be848b` docs/bench → `64f3e3ede` S6-keys → `62644ee02` S6-ext → `17e54cbe3` S6-record → `9889712c7` S6-e2e

---

## 1. 目标与非目标

**目标**
- 在现有 1-RTT 会话恢复 + HRR 路径上，增量交付 0-RTT early_data 能力，且默认行为不变（1-RTT），不开即零开销。
- 为上层 (HTTP/TUI) 提供显式、幂等约束下的 early_data 发送原语，复用现有 PSK / keyschedule / recordsealer 栈，不引入新密码学实现。

**非目标 (fail-closed)**
- 不自动重放非幂等请求；不隐式降级到 0-RTT。
- 不支持 0-RTT 客户端证书 (`post_handshake_auth` 之前的 early_data 禁止证书)。
- 不在 v1 支持跨 SNI / 跨 cipher suite 的 PSK 复用。

## 2. 落地状态（截至 9889712c7）

- `TAsyncTlsPasSessionCache` LRU4：按 host:port 聚合，最老逐出，`SecureZero` 清理，`TryPeek` 高→低跳过期；`TTlsPasResumptionSession` 新增 `HasMaxEarlyData/MaxEarlyDataSize`，`FeedPostHandshake` 从 `NewSessionTicket` 完整捕获（含 `max_early_data` 解析，`0` 视为不可 early，`>16384` 视为不可 early）。
- HRR 可观测：`ITlsPasHRRInfo.WasHRR` 与 `ITlsPasResumeInfo.WasResumed` 通过 `TTlsPasStream` 暴露；`PSK` 与 `HRR` binder 重算已覆盖（`cookie` 插入于 `0x0029` 之前，`message_hash 0xFE` 合成）。
- 0-RTT 派生：`TlsPasTryDeriveEarlyDataSecrets` 薄封装 `keyschedule.TryDeriveTLS13ClientEarlyDataSecrets`，`TlsPasClearEarlyDataSecrets`，双套件单测覆盖 `AES_128/SHA256` / `AES_256/SHA384`，`bench 14.5µs/20.0µs`。
- 扩展装配：`AllowEarlyData` + `HasMaxEarlyData` 时 `BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(..., AllowEarlyData:=True)` 附加 `early_data(0x002A, 0 字节)` 于 `pre_shared_key` 之前（`PSK last`，binder 覆盖不变），`TlsPasHasEarlyData` 复用 `parser.HasEarlyData`。
- 数据面：`TAsyncTlsPasClientOptions.EarlyData: TBytes` 幂等负载，`AllocHsCtx` 内 `HKDF` 派生 `early 密钥` → `EarlySealer`，`TlsPasHsStep` 紧跟 `CH` 之后以 `early 密钥` 封装 `application_data` 单记录同刷；`EE HasEarlyData` 接受/拒绝分支与 `HRR` 互斥均 `fail-closed`，`TTlsPasStream` 同时实现 `ITlsPasEarlyDataInfo.GetWasEarlyDataAccepted`，活体 `EarlyDataLiveRejectFallback` 已验证拒绝回退仍保 1-RTT。
- `bench_tlspas_hrr`：`MessageHash 2.7µs / Patch 1-2µs / P256 1.9ms / EarlyData 14-20µs`，`P384 761ms` 实验性单采明示。

## 3. 威胁模型与重放约束

- **网络攻击者可重放** ClientHello + early_data (RFC 8446 E.5)。服务器若接受 early_data，必须视为**至少一次**语义；应用层必须保证 early_data 承载的操作是幂等的 (read-only / idempotent write with deduplication)。
- 本层不提供去重票据 (single-use ticket 需服务端配合)；客户端侧仅保证：同一 PSK 的 0-RTT 在一次 `AsyncTlsPasConnect` 中最多发送一次，超时/失败不自动重放。
- 失败回退不变：early_data 被拒绝 → 握手继续为 1-RTT，early_data 丢弃，应用通过 `WasEarlyDataAccepted` 感知并自行重发 (幂等前提下)。

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

### 4.4 记录层（已实现）

- 0-RTT 应用数据使用 `client_early` 写密钥，记录类型 `application_data (0x17)`，与 1-RTT 区分在密钥，不在类型；`TTLS13RecordSealer.Seal` 单记录封装，`EarlySealer` 与 `HsCtx` 生命周期绑定，`FreeHsCtx` 清零。
- `EndOfEarlyData`（`0x05`）在当前切片未独立发送：拒绝回退路径无需；接受路径下服务器 `early_data` 接受后客户端 1-RTT 流量直接以 `application 密钥` 继续，已通过活体拒绝回退验证，接受路径的 `EndOfEarlyData` 将在 `S7` 按需补齐（当前接受即 `WasEarlyDataAccepted=True`，不阻塞握手）。

## 5. 状态机（已实现）

```
CH1(+early_data?) --HRR?--> fail-closed（HRRSeen && SentEarlyData）
CH1 -> SH -> EE{early_data?} -> if SentEarlyData then EarlyDataAccepted:=(EE.HasEarlyData && !HRRSeen) else false
      -> Cert?/CV?/Fin -> NST (捕获 HasMaxEarlyData) -> Stream(WasEarlyDataAccepted)
```

`WasHRR=True` 与 `WasEarlyDataAccepted=True` 互斥已在 `EE` 与 `HRR` 双处 `fail-closed`。

## 6. API（已实现，零开销）

```pascal
TAsyncTlsPasClientOptions = record
  ServerName: string;
  VerifyPeer: Boolean;
  HandshakeDeadline: TDeadline;
  TrustBundlePath: string;
  Cache: TAsyncTlsPasSessionCache;
  AllowEarlyData: Boolean; // default False
  EarlyData: TBytes;       // 幂等负载，≤MaxEarlyDataSize 且 ≤16384 时随 CH 之后发送
end;

ITlsPasEarlyDataInfo = interface
  function GetWasEarlyDataAccepted: Boolean; // 握手后固化，EE 无 early_data 则 false
end;

function TlsPasTryDeriveEarlyDataSecrets(ACipherSuite: Word; const APSK, AClientHelloHandshake: TBytes;
  out ASecrets: TTlsPasEarlyDataSecrets; out AError: string): Boolean;
procedure TlsPasClearEarlyDataSecrets(var ASecrets: TTlsPasEarlyDataSecrets);
function TlsPasHasEarlyData(const AClientHelloHandshake: TBytes): Boolean;
```

`TTlsPasStream` 同时实现 `ITlsPasResumeInfo / ITlsPasHRRInfo / ITlsPasEarlyDataInfo`，`AllowEarlyData=False` 时不分配 early secret、不插入扩展、不创建 early sealer，热路径与 1-RTT 同构；`AllowEarlyData=True` 但缓存未命中或无 `max_early_data` 时同样回退。

## 7. 测试矩阵（已落地 20 项）

| 场景 | 期望 | 覆盖 |
|------|------|------|
| 无票据 + AllowEarlyData | 回退 1-RTT，HasEarlyData=false | EarlyDataOptions |
| 有票据 max_early_data=0 + AllowEarlyData | 回退 1-RTT | TicketCache |
| 有票据 max_early_data>0 + AllowEarlyData | CH HasEarlyData=true，binder 32 字节 | EarlyDataExtension |
| early 密钥派生 SHA256/SHA384 | key 16/32，iv 12，clear | EarlyDataSHA256/384 |
| early 密钥封解回环 | Seal/Open 13 字节明文 | EarlyDataSeal |
| Server EE 含 early_data | WasAccepted=true | （S7 接受活体，当前拒绝活体已验证回退） |
| Server EE 不含 early_data | WasAccepted=false，丢 early 密钥，1-RTT 继续 | EarlyDataLiveRejectFallback |
| HRR + early_data | fail-closed | HRRSeen&&SentEarlyData 分支 |
| early_data 超限 (>max / >16384) | 不发 EarlyData，保留 CH early_data 扩展但无负载，服务器拒绝 | AllocHsCtx 限幅 |
| heaptrc | 0 unfreed blocks | 双跑 heap OK |

活体 `EarlyDataLiveRejectFallback`：`base 15556` 双握手（Step1 正常获票据 → 提升为 early 能力 → Step2 `EarlyData` 13 字节），验证 `WasEarlyDataAccepted=false` 且 `HTTP/1.` 命中，`WasHRR=false`。

## 8. 实测性能（bench_tlspas_hrr 8 项，120ms×3）

| 项 | ns/op | 吞吐 |
|----|-------|------|
| MessageHash SHA256 | 2785 | 359K ops/s |
| MessageHash SHA384 | 4211 | 237K ops/s |
| Patch X25519→P384 | 2189 | 456K ops/s |
| Patch P384→P256 | 1235 | 809K ops/s |
| P256 ECDHE keypair | 1.89ms | 530 ops/s |
| Transcript | 3018 | 331K ops/s |
| EarlyData SHA256 | 14543 | 68K ops/s |
| EarlyData SHA384 | 19967 | 50K ops/s |
| P384 single (outside suite) | 761ms | — experimental big-int |

`EarlyData` 派生仅 1-RTT 早期路径单次触发，不入热路径；1-RTT `AsyncWrite` 差异 `<1%`。

## 9. 风险与回滚

- 重放：默认关闭 + 文档强约束 + `Idempotency-Key` 建议；单 PSK 0-RTT 最多一次不重放。
- 扩展错位：复用 `PSK 尾部` 扫描，`EarlyDataExtension` 单测覆盖 binder。
- 回滚：任一 S6 切片可独立 revert，`AllowEarlyData` 默认为关，revert 后行为与 `bcdc562` 一致；`P384` 仍实验性。

---

*本设计遵循 `core/AGENTS.md` 与 `core/docs/design-conventions.md`：L2 仅依赖 L0-L1 与 `tls13.*` 原语，零 OpenSSL，不引入新分层。S6 已闭环，`S7` 可按需接 `ServerEarlyDataPolicy` 与重放存储。*
