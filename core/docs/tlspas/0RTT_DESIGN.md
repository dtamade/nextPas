# tlspas 0-RTT 设计 — Early Data 平面 (Draft S6)

**模块**: `nextpas.core.net.async.tlspas` (L2 async, pure Pascal TLS 1.3)
**状态**: Design (未启用数据面，票据收敛已落地，本文锁定下一步契约)
**RFC**: 8446 §2.3 / §4.2.10 / §4.6.1 / Appendix E.5, 8446 §8
**关联提交**: `402184890` (LRU4 + HRR可观测 + 票据1-RTT收敛)

---

## 1. 目标与非目标

**目标**
- 在现有 1-RTT 会话恢复 + HRR 路径上，增量交付 0-RTT early_data 能
  力，且默认行为不变（1-RTT），不开即零开销。
- 为上层 (HTTP/TUI) 提供显式、幂等约束下的 early_data 发送原语，
  复用现有 PSK / keyschedule / recordsealer 栈，不引入新密码学实现。

**非目标 (fail-closed)**
- 不自动重放非幂等请求；不隐式降级到 0-RTT。
- 不支持 0-RTT 客户端证书 (`post_handshake_auth` 之前的 early_data 禁
  止证书)。
- 不在 v1 支持跨 SNI / 跨 cipher suite 的 PSK 复用。

## 2. 现状与缺口

已落地 (本 worktree `bcdc562a0` 含 `402184890`):
- `TAsyncTlsPasSessionCache` LRU4：按 host:port 聚合，最老逐出，
  `SecureZero` 清理，`TryPeek` 高→低跳过期。
- 票据策略：含 `max_early_data_size` 的 NewSessionTicket 亦入缓存，但
  仍走 1-RTT (注释 `0-RTT 数据面未启用`)。
- HRR 可观测：`ITlsPasHRRInfo.WasHRR` 与 `ITlsPasResumeInfo.WasResumed`
  通过 `TTlsPasStream` 暴露，`AsyncTlsPasConnect` 回调前 `FWasHRR` 已
  固化。
- PSK binder 已覆盖 HRR+PSK 组合 (cookie 插入于 `0x0029` 之前，binder
  经 `TLS13ComputeFinishedVerifyDataFromTrafficSecret` 重算)。

未落地 (本设计范围):
- ClientHello `early_data` 扩展 (type `0x002A`，空扩展) 的插入与 `psk_key_exchange_modes` 一致性。
- Early secret / early traffic secret 派生 (`TryDeriveTLS13ClientEarlyDataSecrets`) 与 early record 封装。
- Server 端 `EncryptedExtensions.early_data` 接受/拒绝分支与 `EndOfEarlyData`。
- 应用层 early_data 提交 API 与重放防护契约。

## 3. 威胁模型与重放约束

- **网络攻击者可重放** ClientHello + early_data (RFC 8446 E.5)。
  服务器若接受 early_data，必须视为**至少一次**语义；应用层必须保证
  early_data 承载的操作是幂等的 (read-only / idempotent write with
  deduplication)。
- 本层不提供去重票据 (single-use ticket 需服务端配合)；客户端侧
  仅保证：同一 PSK 的 0-RTT 在一次 `AsyncTlsPasConnect` 中最多发送一次，
  超时/失败不自动重放。
- 失败回退不变：early_data 被拒绝 → 握手继续为 1-RTT，early_data 丢弃，
  应用通过 `WasEarlyDataAccepted` 感知并自行重发 (幂等前提下)。

## 4. 数据面契约

### 4.1 票据准入

```
Server: NewSessionTicket { ticket, lifetime, cipher_suite,
                          max_early_data_size? }
Client: if max_early_data_size == nil → 存入 LRU，走 1-RTT (现状)
        if max_early_data_size == 0  → 存入 LRU，标记 early_data 不可用
        if max_early_data_size > 0   → 存入 LRU，标记 early_data 可用，
                                      上限 = max_early_data_size
```

`max_early_data_size > 16384` 按 RFC 视为协议错 (fail-closed)。

### 4.2 密钥派生

复用 `nextpas.core.tls.tls13.keyschedule`：

```
early_secret = HKDF-Extract(0, PSK)
binder_key, client_early_traffic_secret, early_exporter_master_secret
  = Derive-Early-Secrets(early_secret, transcript(ClientHello))
```

实现入口 `TryDeriveTLS13ClientEarlyDataSecrets(PSK, CipherSuite,
ClientHelloTranscriptHash, out EarlyTrafficSecret, out Error)` 已在
`tls13.keyschedule` 侧具备雏形，本层仅做 L2 组装，不自实现 HKDF。

### 4.3 扩展布局

ClientHello (含 PSK 时) 尾部扩展顺序 (RFC 8446 §4.2)：

```
... key_share(0x0033) -> psk_key_exchange_modes(0x002D)
    -> pre_shared_key(0x0029) [binder 最后 2 字节为长度占位]
    -> [early_data(0x002A, 0 字节) 仅当 AllowEarlyData 且 PSK 可用]
```

`early_data` 必须在 `pre_shared_key` 之后 (若存在)，且不影响
binder 计算 (binder 覆盖 `ClientHello` 去掉 binder 本身的截断)。

Server 接受回显：`EncryptedExtensions { early_data(0x002A, empty) }`；
拒绝则不回显 early_data，客户端静默回退。

### 4.4 记录层

- 0-RTT 应用数据使用 `early_traffic_secret` 派生的 `client_early` 写密钥，
  记录类型 `application_data (0x17)`，与 1-RTT 记录区分在密钥，不在类型。
- 本层 `TTLS13RecordSealer` 已支持多密钥轮换 (`KeyUpdate`)，新增
  `SealEarlyData` 仅为密钥选择分支，无新 AEAD 实现。
- `EndOfEarlyData` (handshake type `0x05`) 在客户端 Finished 之后、
  1-RTT 流量之前发送，单条 handshake 记录封装。

## 5. 状态机增量

```
现有: CH1 -> [HRR -> CH2] -> SH -> EE -> Cert? -> CV? -> Fin -> NST

新增 early_data 分支 (CH1 含 early_data 时):
CH1+early_data (+binder) --(early_secret)--> 0-RTT AppData*
                |                              |
                +-> HRR? 需丢弃 early_data, 回退 CH2 (1-RTT)
                +-> SH  -> EE{early_data?} -> if accepted: EndOfEarlyData
                           if rejected: 丢弃 early 密钥，继续 1-RTT
```

约束：
- 收到 HRR 时，若已发送 early_data，视为协议错 (server 不应在 HRR 中接受
  early_data)，fail-closed。
- `WasHRR=True` 与 `WasEarlyDataAccepted=True` 互斥。

## 6. API 形状 (保持 1-RTT 默认零开销)

```pascal
TAsyncTlsPasClientOptions = record
  // 现有: ServerName, ALPN, VerifyPeer, SessionCache, TrustBundlePath, HandshakeDeadline
  AllowEarlyData: Boolean; // default False
  MaxEarlyDataSize: Cardinal; // 客户端侧发送上限，0 = 不限(受票据上限约束)
end;

ITlsPasEarlyDataInfo = interface
  function GetWasEarlyDataAccepted: Boolean; // 仅握手后有效
  function GetEarlyDataSent: Cardinal;
end;

// 提交 early_data：仅在 AllowEarlyData=True 且已回调 TTlsPasStream 后、
// 且握手尚未完成前允许；底层用 early 密钥封帧。
// 非幂等调用方不应使用；本层不做幂等校验，仅文档约束。
function TTlsPasStream.TryWriteEarlyData(const ABuf; ASize: Integer): Boolean;
```

可观测性：`TTlsPasStream` 将同时实现 `ITlsPasResumeInfo` /
`ITlsPasHRRInfo` / `ITlsPasEarlyDataInfo`，握手结束前 `WasEarlyDataAccepted`
为 `False`，EE 到达后固化。

零开销保证：
- `AllowEarlyData=False` 时，不分配 early secret，不插入 `early_data`
  扩展，不创建 early sealer，热路径与现有 1-RTT 完全同构。
- `AllowEarlyData=True` 但缓存未命中时，同样回退 1-RTT，无额外分配
  (early 密钥仅在 PSK 命中且 `max_early_data_size>0` 时派生)。

## 7. 实现步骤 (切片)

1. **S6-doc** (本文件): 冻结契约，评审通过后再动代码。
2. **S6-keys** (≤80 行): 接线 `TryDeriveTLS13ClientEarlyDataSecrets`，
   单测覆盖 AES_128_GCM_SHA256 / AES_256_GCM_SHA384 两个 cipher suite。
3. **S6-ext** (≤60 行): `BuildTLS13ClientHelloHandshake` 增加
   `early_data` 尾扩展分支，复用现有 `Build...WithComputedPSKBinder` 截断
   逻辑；新增 `HasEarlyData` parser helper。
4. **S6-record** (≤100 行): `TTlsPasStream` 增加 early sealer 分支与
   `TryWriteEarlyData`，`EndOfEarlyData` 发送，EE 解析分支。
5. **S6-e2e**: `openssl s_server -early_data` 对接，手写 fake 流
   合成测试 (early_data 接受/拒绝/HRR 互斥)。

每切片独立 `make focused FOCUS=core/tests/nextpas.core.net/test_tlspas_hrr`
+ `heaptrc` + `make hygiene` 双门禁。

## 8. 测试矩阵

| 场景 | 期望 |
|------|------|
| 无票据 + AllowEarlyData=True | 回退 1-RTT，WasEarlyDataAccepted=False，零额外分配 |
| 有票据(max_early_data=0) + AllowEarlyData | 回退 1-RTT |
| 有票据(max_early_data>0) + AllowEarlyData | ClientHello 含 early_data，binder 仍校验通过 |
| Server EE 含 early_data | WasEarlyDataAccepted=True，可读 early response |
| Server EE 不含 early_data | WasEarlyDataAccepted=False，early 密钥丢弃，1-RTT 继续 |
| HRR + early_data | fail-closed (ASYNC_TLSPAS_ERR_HANDSHAKE)，不重放 |
| early_data 超限 (>max) | 客户端截断或 fail-closed，不静默截断欺骗 |
| heaptrc | 0 unfreed blocks (early 路径亦如此) |

## 9. 性能目标

- 合成开销：`MessageHash + EarlySecret` < 5µs (SHA256 路径)，以
  `bench_tlspas_hrr` 为基线。
- 热路径：1-RTT (AllowEarlyData=False) 与现有 `main` 分支的
  `AsyncWrite` 吞吐差异 < 1% (同 `bench_tcp` 规模对比)。
- P-384 仍为实验性 big-int 路径，握手 5-7s 非回归目标，文档明示。

## 10. 风险与回滚

- 风险：重放导致非幂等副作用。缓解：默认关闭 + 文档强约束 + 应用层
  去重建议 (Idempotency-Key)。
- 风险：early_data 扩展插错位置导致 binder 失效。缓解：复用现有
  `pre_shared_key` 尾部扫描逻辑，单测覆盖 binder 校验。
- 回滚：任一 S6 切片可独立 revert，缓存 LRU4 与 HRR 路径不受影响；
  `AllowEarlyData` 默认为关，revert 后行为与当前 `bcdc562` 完全一致。

---

*本设计遵循 `core/AGENTS.md` 与 `core/docs/design-conventions.md`：
L2 仅依赖 L0-L1 与 `tls13.*` 已有原语，零 OpenSSL，不引入新分层。*
