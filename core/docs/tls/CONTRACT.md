# nextpas.core.tls 代码契约

**模块路径**：`core/src/nextpas.core.tls*.pas`
**层级**：L2（依赖 L0–L1、hash、crypto、net/platform 后端 FFI）
**Owner**：hash / crypto / tls lane
**最后更新**：2026-07-20
**版本**：1.1

---

## 1. 接口契约（当前 public truth）

### 1.1 门面

```pascal
uses nextpas.core.tls;

// 便捷：DNS + TCP + TLS
function TLSDial(const AHost: string; APort: Word): IStream;
function TryTLSDial(...; out AStream: IStream; out AError: string): Boolean;

// 主 API：TSSLConnector / TSSLAcceptor / TSSLStream (IStream)
```

配置入口：`TSSLContextBuilder`（`nextpas.core.tls.context.builder`）。
默认 pure Pascal 后端在 `uses nextpas.core.tls` 时注册。

### 1.2 与 crypto 边界

| 能力 | Owner | TLS 侧 |
|------|-------|--------|
| Hash | `nextpas.core.hash` | 经 `crypto.hash` 适配或直接 hash |
| ChaCha20-Poly1305 | `crypto.chacha20poly1305` | `tls.tls13.chacha20poly1305` 仅为 shim |
| ASN.1 | `crypto.asn1` | `tls.asn1` 仅为 shim |
| X.509 chain verify | `tls.x509verify` | 使用 `tls.x509` 类型 + crypto 签名校验 |
| AEAD record | crypto 原语 + tls record 封装 | |

### 1.3 后端

OpenSSL / mbedTLS / WolfSSL / WinSSL / FreePascal pure。
能力矩阵必须以 runtime 真实行为为准（capability 不撒谎）。

---

## 2. 不变量

- **[INV-1]** 握手完成前不得应用数据 Send/Recv（后端语义）
- **[INV-2]** Close 发送 close_notify（支持的后端）
- **[INV-3]** 证书验证失败 fail-closed（除非显式关闭验证）
- **[INV-4]** 不得把 AEAD/hash 实现塞回 tls 生产单元（shim 除外）

---

## 错误处理

- 握手失败、证书验证失败必须 **fail-closed**（INV-3），不静默降级、不降级到明文。
- 便捷 `TLSDial` 失败抛异常；调用方需要区分成功/失败路径时改用 `TryTLSDial`（`out AError: string`）。
- 后端能力不符在 runtime 检查（capability 不撒谎），提前失败并报告真实原因，不跨后端伪兼容。

## 线程安全

- `TSSLStream` / `TSSLConnector` 实例单线程使用；跨线程共享需调用方同步。
- `TSSLContextBuilder` 配置完成后不可变；只读共享的安全性取决于后端（原生后端自带锁，pure Pascal 后端无全局状态）。
- 同一实例并发 Send/Recv 未定义，调用方负责串行化数据面访问。

## 内存管理

- 原生后端（FPC 下 OpenSSL / mbedTLS / WolfSSL / WinSSL）的上下文与连接句柄由 TLS 层在 finalize 路径释放；pure Pascal 后端无外部句柄。
- `TSSLStream` 释放时发送 close_notify 并释放后端连接资源（INV-2，支持的后端）。
- 传入的底层 `IStream` 所有权仍归调用方，TLS 层不窃取、不重复释放。

---

## 3. 测试覆盖（最小）

见 `docs/tls/VERIFY.md`。

```bash
make focused FOCUS=core/tests/nextpas.core.tls/test_tls13_aead
make focused FOCUS=core/tests/nextpas.core.tls/test_stream_migration
make focused FOCUS=core/tests/nextpas.core.tls/test_tls_rtl_dependency_contract
make focused FOCUS=core/tests/nextpas.core.tls/test_dialer
```

---

## 4. 历史文档

`docs/tls/GOAL_TREE.md`、`ROADMAP.md`、旧 fafafa.ssl 叙事为 **historical**。
以本 CONTRACT + `docs/tls/OWNERSHIP.md` 为准。

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-07-20 | 1.1 | IStream 门面；分层边界；shim 说明 |
| 2026-07-01 | 1.0 | 初始版本 |
