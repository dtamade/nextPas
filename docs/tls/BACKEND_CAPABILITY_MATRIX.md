# 后端能力矩阵

本文档详细说明各 SSL/TLS 后端的功能支持情况。

**更新时间**: 2026-05-29

---

## 快速参考

| 功能                         | FreePascal | OpenSSL | WinSSL | MbedTLS | WolfSSL |
| ---------------------------- | ---------- | ------- | ------ | ------- | ------- |
| **TLS 1.2**                  | ✅         | ✅      | ✅     | ✅      | ✅      |
| **TLS 1.3**                  | ✅         | ✅      | ⚠️     | ⚠️      | ✅      |
| **Early Data (0-RTT)**       | ✅         | ✅      | ❌     | ❌      | ⚠️      |
| **Session Resumption**       | ✅         | ✅      | ⚠️     | ⚠️      | ✅      |
| **OCSP Stapling**            | ✅         | ✅      | ❌     | ❌      | ⚠️      |
| **Certificate Transparency** | ✅         | ❌      | ❌     | ❌      | ❌      |
| **ALPN**                     | ✅         | ✅      | ✅     | ✅      | ✅      |
| **SNI**                      | ✅         | ✅      | ✅     | ✅      | ✅      |
| **PSK**                      | ✅         | ✅      | ❌     | ✅      | ✅      |
| **PKCS#11**                  | ❌         | ✅      | ❌     | ❌      | ❌      |
| **PKCS#12 / PFX**            | ❌         | ✅      | ⚠️     | ❌      | ❌      |
| **Password-Protected Keys**  | ✅         | ✅      | ⚠️     | ✅      | ❌      |
| **Custom Cipher Suites**      | ✅         | ✅      | ❌     | ❌      | ❌      |
| **Context Callbacks**        | ⚠️         | ✅      | ⚠️     | ❌      | ❌      |
| **Hardware Acceleration**    | ✅         | ✅      | ❌     | ❌      | ❌      |

**图例**:

- ✅ 完整支持
- ⚠️ 部分支持或有限制（接口存在但功能受限）
- ❌ 不支持

## FreePascal 后端说明

FreePascal 后端是纯 Pascal 实现，零外部 C 依赖。**已通过 7 轮独立安全审查（L6 门禁 3/3）**。

- **TLS 1.2 + 1.3**: 完整 client + server，8 cipher suites，P-256/P-384/X25519 key exchange
- **Session Resumption**: TLS 1.2 (session ID) + TLS 1.3 (PSK tickets)，OpenSSL 互操作验证通过
- **0-RTT Early Data**: 完整实现（client send + server accept/reject + replay 防护）
- **OCSP Stapling**: 完整验证（server-pushed stapled response，纯 Pascal 密码学验签）
- **Certificate Transparency**: 完整 SCT 解析 + 签名验证 + policy 检查（OpenSSL 后端反而未实现）
- **Hardware Acceleration**: AES-NI + PCLMULQDQ (x86_64)
- **Constant-time crypto**: X25519 Montgomery ladder + P-256/P-384 Montgomery ladder + AEAD tag comparison
- **Security hardening**: 证书链密码学验签（无 DN-only 快捷路径）、on-curve 点验证、密钥材料安全擦除、序列号溢出保护、记录长度上限、ASN.1 深度限制
- **Password-Protected Keys**: PKCS#8 + 传统 PEM 加密格式
- **Context Callbacks**: VerifyCallback 支持；PasswordCallback/InfoCallback 不支持（设计决策）
- **Known Limitations**: 无 PKCS#11/PKCS#12，无 Online OCSP（需 HTTP client），TLS 1.2 renegotiation 不完成

`Session Resumption` 这一行按当前 runtime/capability truth 汇总：

- `FreePascal`: public surface 已闭合，但 `SessionTicketsSupport` / `SessionCacheSupport` 仍发布为 `experimental`
- `WinSSL`: public surface 存在，但当前 dedicated Windows runtime truth 仍是 `observed_reuse=false` / `session_configured=true`
- `MbedTLS`: public surface 已发布 `GetSession / SetSession / Serialize / Deserialize` 与 cache/ticket 候选路径，但当前 local source/header truth 只有 `mbedtls_ssl_set_session` / `mbedtls_ssl_get_session` / `mbedtls_ssl_session_load/save`，没有对称的 public reused getter；因此当前不把 `SetSession(...)` 自动解释成 observed resumed-handshake

`Context Callbacks` 这一行按当前 published runtime truth 汇总：

- `OpenSSL`: verify/password/info callback 都已发布并具备 runtime wiring
- `WinSSL`: 仅 verify/info callback 已发布；password callback 当前仍为 unsupported
- `FreePascal`: 仅 verify callback 已发布并接入 peer-certificate trust failure path；password/info callback 当前仍为 unsupported
- `WolfSSL` / `MbedTLS`: `SupportsCallbacks=False`，verify/password/info setter 当前都已 fail-closed

`Password-Protected Keys` 这一行按当前 published/runtime truth 汇总：

- `OpenSSL` / `MbedTLS`: password-protected private-key path 当前已发布
- `WinSSL`: 当前仅 password-protected PFX/P12 import path 已发布；PEM private-key password path 仍为 unsupported
- `FreePascal` / `WolfSSL`: `SupportsPasswordProtectedKeys=False`；non-empty `APassword` 当前会 fail-closed

`Custom Cipher Suites` 这一行按当前 published/runtime truth 汇总：

- `OpenSSL`: `SupportsCustomCipherSuites=True` 仅在 TLS 1.2 / TLS 1.3 custom-cipher helper 都就绪时发布；custom cipher override 当前具备 runtime apply
- `FreePascal`: `SupportsCustomCipherSuites=True`；支持显式列出当前纯 Pascal runtime 已实现的 TLS 1.2 / TLS 1.3 suite allowlist，并在 ClientHello / TLS 1.2 server selection 中生效；不发布完整 OpenSSL selector/denylist 语法
- `WinSSL` / `MbedTLS` / `WolfSSL`: `SupportsCustomCipherSuites=False`；custom non-default `SetCipherList` / `SetCipherSuites` 当前会 fail-closed，empty clear / shipped baseline defaults 仅保留 compatibility/default-context path

`PKCS#12 / PFX` 这一行按当前 published/runtime truth 汇总：

- `OpenSSL`: `SupportsPKCS12=True`；当前发布完整 PKCS#12 helper/API surface（create / parse / BIO I/O）
- `WinSSL`: `SupportsPKCS12=True`；当前仅发布 PFX/P12 private-key/certificate bundle import path
- `FreePascal` / `MbedTLS` / `WolfSSL`: `SupportsPKCS12=False`；当前没有 shipped PKCS#12 bundle create / parse / import surface

---

## TLS 1.3 Early Data (0-RTT)

### FreePascal 后端

**状态**: ⚠️ 实验性支持（public surface 已接通，默认 shipped path 已切到本地持久化 replay-store 路径）

**功能**:

- ✅ 客户端 Early Data
- ✅ 服务端 Early Data
- ✅ 重放防护（内存/文件/目录存储）
- ✅ 策略配置（Reject/Accept/IssueOnly）
- ✅ 可配置大小限制

**限制**:

- `TSSLBackendCapabilities.ZeroRTTSupport` / `EarlyDataSupport` 当前发布为 `sslSupportExperimental`
- 默认 shipped path 已经把 replay truth 落到本地持久化 replay-store 路径
- 如果默认路径不可用或不可写，resumed early data 会 fail-closed reject
- 显式 file / directory replay-store opt-in 仍然用于 caller-controlled path placement

**示例**:

```pascal
Lib := TSSLFactory.GetLibraryInstance(sslFreePascal);
Ctx := Lib.CreateContext(sslCtxClient);
if Supports(Ctx, ISSLEarlyDataContext, EarlyDataCtx) then
  EarlyDataCtx.SetClientEarlyDataEnabled(True);
```

### OpenSSL 后端

**状态**: ✅ 完整支持（生产就绪，v1.4.1+）

**功能**:

- ✅ 客户端 Early Data
- ✅ 服务端 Early Data
- ✅ 策略配置
- ✅ 可配置大小限制
- ✅ 使用 OpenSSL 内置重放防护

**要求**:

- OpenSSL 1.1.1+ 或 3.0+

**示例**:

```pascal
Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
Ctx := Lib.CreateContext(sslCtxClient);
if Supports(Ctx, ISSLEarlyDataContext, EarlyDataCtx) then
  EarlyDataCtx.SetClientEarlyDataEnabled(True);
```

### WinSSL 后端

**状态**: ❌ 不支持

**原因**:

- Windows Schannel 没有公开的 Early Data API
- TLS 1.3 支持有限（Windows 10 1903+）
- Microsoft 未提供完整文档

**替代方案**:

- 使用 OpenSSL 后端（推荐）
- 使用 FreePascal 后端

**检测**:

```pascal
Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);
Ctx := Lib.CreateContext(sslCtxClient);
if not Supports(Ctx, ISSLEarlyDataContext) then
  WriteLn('Early Data not supported on WinSSL');
```

### MbedTLS 后端

**状态**: ❌ 不支持

**原因**:

- MbedTLS 3.x 的 Early Data API 尚未完善
- 当前后端不会暴露 `ISSLEarlyDataContext` 可选接口，避免调用方命中存根异常

**计划**:

- 等待 MbedTLS 4.x 完善 API
- 再补完整的 runtime/public contract

### WolfSSL 后端

**状态**: ⚠️ 受 build/runtime helper 门控的实验性支持

**原因**:

- 依赖 WolfSSL TLS 1.3 early-data 原生 API
- 当前证据以 focused contract + 全仓编译为主，尚未把所有主机都提升成 production-ready runtime proof
- 只有在 build/runtime helper 完整时，context / connection 才会暴露 early-data 可选接口

**当前范围**:

- ⚠️ helper 完整时提供客户端 context enable / policy / max-size surface
- ⚠️ helper 完整时提供客户端连接级 queue / status / limit surface
- 如果当前 `wolfSSL` 动态库未导出 `wolfSSL_write_early_data`、`wolfSSL_get_early_data_status`、`wolfSSL_CTX_set_max_early_data`、`wolfSSL_CTX_get_max_early_data`，则 capability 发布为 `sslSupportNone`
- 在上述 helper 缺失时，client context 不暴露 `ISSLEarlyDataContext`，client connection 也不暴露 `ISSLEarlyDataConnection`
- 因此更广泛的 runtime readiness 仍应按实验性能力理解，而不是无条件假定可用

---

## Server OCSP Stapling

### FreePascal 后端

**状态**: ⚠️ 已暴露 public surface，capability 仍按 `experimental` 发布

**功能**:

- ✅ 加载 OCSP 响应
- ✅ 从文件加载
- ✅ 动态更新

**边界**:

- `TSSLBackendCapabilities.OCSPStaplingSupport` 当前发布为 `sslSupportExperimental`
- 这表示 connection/context public surface 已闭合，不等于 broader revocation/runtime parity 已经全部升到 production-complete

### OpenSSL 后端

**状态**: ✅ 完整支持（v1.4.1+，含 focused runtime proof）

**功能**:

- ✅ 加载 OCSP 响应
- ✅ 从文件加载
- ✅ 动态更新
- ✅ server-side native status callback wiring
- ✅ focused TLS 1.3 runtime handshake proof（含 builder file-load path）

**当前范围**:

- ✅ `ISSLServerOCSPStaplingContext` public surface
- ✅ `WithServerOCSPStapledResponseFile(...)`
- ✅ `configured + requested => client surface 收到 stapled DER`
- ✅ `not requested` / `no material` => client surface 保持空响应

**边界**:

- 只负责 caller-provided stapled OCSP response material
- 不负责 online fetch、refresh，或 responder 调度

### WinSSL 后端

**状态**: ❌ 不支持当前仓库的 OCSP stapling public surface

**说明**:

- Schannel 可能有系统级自动行为，但当前 `GetCapabilities` 仍发布：
  - `OCSPStaplingSupport=sslSupportNone`
  - legacy `SupportsOCSPStapling=False` 仅是 compatibility projection
- 因此 connection / context 不对外暴露仓库定义的 OCSP stapling optional interface

### MbedTLS 后端

**状态**: ❌ 不支持

**原因**:

- 当前后端不会暴露 `ISSLServerOCSPStaplingContext`
- `server_ocsp_stapled_response_file` 配置会被 builder fail-fast 拦下，而不是 silent ignore

### WolfSSL 后端

**状态**: ⚠️ 实验性支持

**当前范围**:

- ✅ public optional context interface `ISSLServerOCSPStaplingContext`
- ✅ builder `WithServerOCSPStapledResponseFile(...)`
- ✅ caller-provided DER bytes / file material
- ✅ server-side native status callback wiring
- ✅ client-side stapled-response request / consume surface
- ✅ scripted `TStream` TLS 1.3 baseline handshake 已在本机验证
- ⚠️ `configured + requested => stapled DER` 与 builder file-load emission proof 目前按 `wolfSSL >= 5.9.1` 门控；旧版本 host 会显式 skip 这些场景

**边界**:

- 只负责 caller-provided stapled OCSP response material
- 不负责 online fetch、refresh，或 responder 调度
- 现阶段 capability 应按 `experimental` 看待，而不是生产稳定支持
- 当前 Debian 13 开发主机自带 `wolfSSL 5.7.2`，属于上述 emission gate 范围

---

## Certificate Transparency (CT)

### FreePascal 后端

**状态**: ⚠️ 已暴露连接级 CT / validation surface，capability 仍按 `experimental` 发布

**功能**:

- ✅ SCT 验证
- ✅ CT 日志列表
- ✅ 策略配置
- ✅ `ISSLCertificateTransparency` / `ISSLCertificateTransparencyValidation`

**边界**:

- `TSSLBackendCapabilities.CertTransparencySupport` 当前发布为 `sslSupportExperimental`
- 这里表达的是 public surface 已闭合，而不是把整个 CT family 写成 production-complete

### OpenSSL 后端

**状态**: ❌ 当前默认 backend capability 不暴露连接级 CT surface

**说明**:

- 仓库里已有底层 OpenSSL CT binding
- 但当前默认 capability 仍是 `CertTransparencySupport=sslSupportNone`
- legacy `SupportsCertificateTransparency=False` 只是 compatibility projection
- 因此 connection 不再对外暴露 `ISSLCertificateTransparency` / `ISSLCertificateTransparencyValidation`

### WinSSL / MbedTLS / WolfSSL 后端

**状态**: ❌ 不支持

**说明**:

- 当前 backend capability 为 `False/None`
- connection 不暴露 CT / validation optional interface，避免 `Supports(...)` 假阳性

---

## PKCS#11 硬件令牌

### OpenSSL 后端

**状态**: ✅ 支持（依赖 Provider / ENGINE runtime surface readiness）

**功能**:

- ✅ 从 PKCS#11 令牌加载私钥
- ✅ 支持 PIN 保护
- ✅ URI 格式

**说明**:

- 当前 capability truth 跟随 `TPKCS11BackendFactory.IsBackendAvailable(btAuto)`
- 也就是说：
  - 仓库里仍有 shipped PKCS#11 loader path
  - 但若当前 OpenSSL 运行时缺少 Provider / ENGINE 必需 surface，`SupportsPKCS11` 会降为 `False`

**示例**:

```pascal
Ctx.LoadPrivateKey('pkcs11:token=MyToken;object=MyKey', 'PIN');
```

### 其他后端

**状态**: ❌ 不支持

---

## 平台支持

### FreePascal 后端

**平台**:

- ✅ Linux (x86_64, ARM64)
- ✅ macOS (x86_64, ARM64)
- ✅ Windows (x86_64)
- ✅ FreeBSD

**依赖**: 无（纯 Pascal 实现）

### OpenSSL 后端

**平台**:

- ✅ Linux
- ✅ macOS
- ✅ Windows
- ✅ FreeBSD
- ✅ 其他 Unix

**依赖**: OpenSSL 1.1.1+ 或 3.0+

### WinSSL 后端

**平台**:

- ✅ Windows 10+
- ✅ Windows Server 2016+

**依赖**: Windows Schannel（系统内置）

### MbedTLS 后端

**平台**:

- ✅ Linux
- ✅ 嵌入式系统
- ⚠️ Windows（实验性）

**依赖**: MbedTLS 2.x 或 3.x

### WolfSSL 后端

**平台**:

- ✅ Linux
- ✅ 嵌入式系统
- ✅ RTOS

**依赖**: WolfSSL 5.0+

---

## 性能与测量入口

本页不再维护固定“相对值表”。backend 性能会同时受到 CPU、操作系统、编译参数、
OpenSSL/Schannel/WolfSSL 运行时、目标端点、网络路径、是否启用 TLS lane 与当前
session/ticket 证据状态影响；因此固定 `x 倍`、固定 `ms` 或固定 `ops/s` 都不应被
当成长期 truth。

当前性能真相源优先看：

- `scripts/run_phase2_performance_baseline.sh`
- `tests/benchmarks/run_all_benchmarks.sh`
- `docs/guides/PERFORMANCE_GUIDE.md`
- `docs/guides/PERFORMANCE_OPTIMIZATION_GUIDE.md`

解读时请特别注意：

- loopback、本机 TLS 栈与公网端点结果要分开记录
- `WinSSL` session resumption / tickets 当前仍按 experimental public surface 理解
- `FreePascal` / `WolfSSL` 的 early-data 能力也要结合当前 capability 和 fresh run 判断
- 发布性能结论时，应同时附带命令、环境、输出目录和生成时间

---

## 选择建议

### 通用跨平台 / 功能优先

**优先考虑**: OpenSSL 后端

- 当前 published capability 最完整
- 需要 OpenSSL 完整 custom cipher selector 语法、PKCS#11、完整 PKCS#12 helper/API surface 时优先
- 需要 caller-provided server OCSP stapling 或更稳的 early-data/runtime 证据时优先

### Windows 专有客户端 / 零依赖

**优先考虑**: WinSSL 后端

- 适合 Windows 专有客户端
- 零依赖部署、系统证书存储、企业策略集成是当前优势
- 但 Early Data / caller-provided server OCSP stapling 当前不发布，session resumption / tickets 仍按 experimental public surface 理解

### 嵌入式 / 体积与移植优先

**优先考虑**: MbedTLS 或 WolfSSL 后端

- 更适合资源受限或嵌入式环境
- `MbedTLS` 当前不要假设 Early Data / OCSP stapling / CT 已可用
- `WolfSSL` 当前不要假设 early-data / OCSP stapling 无条件可用；它们仍受 build/runtime helper 门控

### Pascal-first / 零外部 SSL 动态库

**优先考虑**: FreePascal 后端

- 无外部 SSL 动态库依赖
- 适合 Pascal-first、跨平台、自带 TLS core 的接入路径
- `0-RTT / early data`、OCSP stapling、CT 当前仍按 experimental capability 理解

---

## 当前发布状态与历史里程碑

**当前稳定版本**: `v1.6.0`

**当前权威入口**:

- [当前路线图](ROADMAP.md)
- [Release Readiness v1.5.0](test_reports/RELEASE_READINESS_V1.5.0.md)
- [Release Notes](RELEASE_NOTES.md)

下面这些条目只保留 capability/capability-doc 相关的历史里程碑，不能替代当前
`v1.5.0` 的 release/runtime truth。

### v1.4.1 capability 里程碑 (2026-05-02)

- ✅ OpenSSL 后端添加 Early Data 支持
- ✅ OpenSSL 后端添加 Server OCSP Stapling 支持

### v1.4.0 capability 里程碑 (2026-05-02)

- ✅ FreePascal 后端 Early Data 支持
- ✅ 完整的 TLS 1.3 实现
- ✅ Certificate Transparency 支持

### v1.3.0 capability 里程碑

- ✅ WinSSL 后端
- ✅ MbedTLS 后端
- ✅ WolfSSL 后端

---

## 参考文档

- [Early Data 使用指南](guides/EARLY_DATA_GUIDE.md)
- [OpenSSL 模块与后端说明](reference/OPENSSL_MODULES.md)
- [WinSSL 后端能力矩阵](reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md)
- [WinSSL 设计说明](reference/WINSSL_DESIGN.md)
- [MbedTLS 后端能力矩阵](reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md)
- [API 参考](reference/API_REFERENCE.md)

---

**维护者**: fafafa.ssl 开发团队
**更新频率**: 每个版本发布时更新
