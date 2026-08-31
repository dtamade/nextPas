# nextpas.core.tls 代码契约

**模块路径**：`core/src/nextpas.core.tls*.pas`
**层级**：L2（依赖 L0–L1、hash、crypto、net/platform 后端 FFI）
**Owner**：hash / crypto / tls lane
**最后更新**：2026-08-31
**版本**：1.3

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

## 5. 测试环境变量契约（2026-08-23 去 fafafa 品牌更名）

测试侧 opt-in 门与环境变量已由 `FAFAFA_*` 统一更名为 `NEXTPAS_*`，
旧名不再被读取。映射表：

| 旧名 | 新名 |
|------|------|
| `FAFAFA_RUN_NETWORK_TESTS` | `NEXTPAS_RUN_NETWORK_TESTS` |
| `FAFAFA_TLS_CA` | `NEXTPAS_TLS_CA` |
| `FAFAFA_PROJECT_ROOT` | `NEXTPAS_PROJECT_ROOT` |
| `FAFAFA_SSL_FREEPASCAL_EARLY_DATA_REPLAY_STORE_DIR` | `NEXTPAS_SSL_EARLY_DATA_REPLAY_STORE_DIR` |
| `FAFAFA_WINSSL_*`（REVOCATION_TEST / PFX / PFX_PASSWORD / CLIENT_CERT_SUBJECT / MTLS_SERVER / MTLS_PORT / SESSION_HOST / SESSION_ATTEMPTS / ENABLE_NATIVE_PROBE / NATIVE_PROBE_CHILD / BENCH_ITERATIONS / PEER_CERT_HOST / REQUIRE_REUSE / REQUIRE_NATIVE_REUSE） | `NEXTPAS_WINSSL_*`（同名后缀） |

有意保留的 fafafa 字样（非品牌残留，属行为/历史事实）：

- 会话序列化 MAGIC（`fafafa-winssl/mbedtls/wolfssl-session-v1`）：线格式
  稳定标签，改值破坏既有持久化 blob 兼容。
- `nextpas.core.math.vec.compat` 的兼容层文档：该单元职责即桥接旧
  fafafa.game 向量 API。
- `tui.base`/`tui.input` 的「移植自 fafafa.tui」出处说明。
- `platform.mmap` 的共享内存文件名前缀 `fafafa_shm_`：运行时命名。
- `core/tests/shared/tls_test_sockets.pas` 头部出处说明。

### 离线边界

- 回环类测试（session resumption、loopback accept 等）默认可离线运行。
- 真实网络项一律经 `NEXTPAS_RUN_NETWORK_TESTS=1` 或对应专项变量显式
  开启；未开启时输出 SKIP 而非 FAIL。依赖外网的对端包括 badssl.com、
  www.cloudflare.com 及 WinSSL 专项变量指定的服务器。
- 计时敏感断言（如 padding-oracle 恒时校验）对机器负载敏感，偶发红
  属抖动，复跑三次判定。

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-08-23 | 1.2 | 测试环境变量 NEXTPAS_* 更名映射；离线边界说明 |
| 2026-07-20 | 1.1 | IStream 门面；分层边界；shim 说明 |
| 2026-07-01 | 1.0 | 初始版本 |
| 2026-08-31 | 1.3 | 时效刷新：批量校正至 2026-08-31，统一 AL1 口径 | core-docs |
