# fafafa.ssl - Modern TLS Foundation for FreePascal

[![Version](https://img.shields.io/badge/Version-v1.6.0-blue)]()
[![TLS](https://img.shields.io/badge/TLS-1.2%20%7C%201.3-blue)](https://tools.ietf.org/html/rfc8446)
[![FPC](https://img.shields.io/badge/FreePascal-3.2.0%2B-orange)](https://www.freepascal.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

Multi-backend, Pascal-first, production-verifiable TLS infrastructure for FreePascal.

## 后端支持

| 后端 | 平台 | 状态 | 说明 |
|------|------|------|------|
| OpenSSL | Linux/macOS/Windows | 生产就绪 | 完整 TLS 1.2/1.3 |
| FreePascal (纯 Pascal) | 跨平台 | **生产就绪** | 零 C 依赖，TLS 1.2/1.3，AES-NI 加速 |
| MbedTLS | 跨平台 | 生产就绪 | 完整 TLS 1.2/1.3 |
| WolfSSL | 跨平台 | 生产就绪 | 完整 TLS 1.2/1.3 |
| WinSSL (Schannel) | Windows | 生产就绪 | TLS 1.2 + 条件 TLS 1.3 |

## 快速开始

```pascal
program HelloTLS;
uses
  SysUtils, fafafa.ssl, fafafa.ssl.context.builder;
var
  Ctx: ISSLContext;
  Stream: TSSLStream;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithSystemRoots
    .BuildClient;

  Stream := TSSLConnector.FromContext(Ctx)
    .ConnectSocket(YourSocket, 'example.com');
  try
    Stream.Write(Request[1], Length(Request));
  finally
    Stream.Free;
  end;
end.
```

### 编译

```bash
fpc -Fu./src your_app.pas
```

## 核心 API

### TSSLContextBuilder (推荐入口)

```pascal
Ctx := TSSLContextBuilder.Create
  .WithTLS13                    // 协议版本
  .WithVerifyPeer               // 验证对端证书
  .WithSystemRoots              // 加载系统 CA
  .WithCertificate('cert.pem')  // 客户端/服务端证书
  .WithPrivateKey('key.pem')    // 私钥
  .WithSessionCache(True)       // 会话复用
  .BuildClient;                 // 或 .BuildServer
```

### TSSLConnector / TSSLAcceptor (Rust 风格门面)

```pascal
// 客户端
Stream := TSSLConnector.FromContext(Ctx)
  .WithTimeout(5000)
  .WithSessionReuse(True)
  .ConnectSocket(Socket, 'host.com');

// 服务端
Stream := TSSLAcceptor.FromContext(Ctx)
  .AcceptSocket(ClientSocket);
```

### 证书生成

```pascal
uses fafafa.ssl.quick;

KeyPair := TSSLQuick.GenerateSelfSigned('localhost', 365);
```

### PKCS#11 硬件安全模块

```pascal
Ctx := TSSLContextBuilder.Create
  .UsePKCS11('pkcs11:token=MyToken;object=MyKey')
  .WithPKCS11PIN('1234')
  .BuildClient;
```

### Context-safe factory 示例：

用 context-safe config/factory 时，可选这两个字段：

- `TSSLContextConfig.ServerEarlyDataReplayStoreFile`
- `TSSLContextConfig.ServerEarlyDataReplayStoreDirectory`

Legacy `TSSLConfig` 字段仍保留给 `v1.x` 兼容调用方，新代码推荐 `TSSLContextConfig`。

```pascal
var
  LConfig: TSSLContextConfig;
begin
  LConfig := CreateDefaultContextConfig(sslCtxServer);
  LConfig.ServerEarlyDataReplayStoreFile := '/var/lib/myapp/replay.store';
  Ctx := TSSLFactory.CreateContext(LConfig);
end;
```

如果你明确锁定的是支持 custom cipher override 的 backend（当前 OpenSSL 与 FreePascal 显式 allowlist 路径），再在 capability check 之后调用 `SetCipherList(...)` / `SetCipherSuites(...)`。

## 架构

```
src/                          198 个源文件, 136K 行
├── fafafa.ssl.pas               主门面 (re-export 所有公共类型)
├── fafafa.ssl.base.pas          核心类型与接口定义
├── fafafa.ssl.context.builder   Fluent context builder
├── fafafa.ssl.tls.pas           Connector/Acceptor/Stream 门面
├── fafafa.ssl.factory.pas       多后端工厂
├── fafafa.ssl.openssl.*         OpenSSL 后端
├── fafafa.ssl.mbedtls.*         MbedTLS 后端
├── fafafa.ssl.wolfssl.*         WolfSSL 后端
├── fafafa.ssl.winssl.*          WinSSL 后端
├── fafafa.ssl.freepascal.*      纯 Pascal TLS 1.2/1.3 后端 (生产就绪)
├── fafafa.ssl.tls12.*           TLS 1.2 协议实现
├── fafafa.ssl.tls13.*           TLS 1.3 协议实现
├── fafafa.ssl.pkcs11.*          PKCS#11 支持
├── fafafa.ssl.cert.*            证书管理
└── fafafa.ssl.crypto.*          加密工具
```

## 构建与测试

```bash
# 编译所有模块
python3 scripts/compile_all_modules.py

# 本地最小门禁
bash scripts/run_minimal_ci_gate.sh --fast-local

# P2 模块回归测试
bash scripts/run_all_module_tests.sh --fast-local --modules PKCS7,PKCS12,CMS,Store,OCSP,TS,CT

# 代码风格检查
python3 scripts/check_code_style.py src

# FreePascal TLS 1.3 完整性门禁
bash scripts/run_freepascal_tls13_completeness_gate.sh --fast-local
```

## 安全特性

- TLS 1.2/1.3 协议支持，安全默认值
- AES-256-GCM, ChaCha20-Poly1305, SHA-256/384/512
- 恒定时间比较 (防时序攻击)
- 安全内存擦除 (SecureZeroMemory)
- 证书钉扎、OCSP Stapling、Certificate Transparency
- DANE/DNSSEC 支持
- 零拷贝 I/O (Lock-free ring buffer, Buffer pool)

## 性能优化

- Lock-free SPSC ring buffer (cache-line padding, memory barriers)
- 16-shard session cache (降低锁竞争)
- 三级 buffer pool (4KB/16KB/64KB 预分配)
- AES-GCM context pool (避免重复初始化)
- 自动后端选择 (40+ 维度评分)

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 文档

- 默认导航：先看 `docs/ROADMAP.md`、`docs/plans/2026-05-12-release-v1.5.0-formalization.md`、`docs/test_reports/RELEASE_READINESS_V1.5.0.md`。
- Wave C closeout / 审批参考：`docs/test_reports/WAVE_C_CLOSEOUT_STATUS_2026-03-18.md`、`docs/test_reports/WAVE_C_LOCAL_FIRST_AND_PRE_CI_CHAIN_STATUS_2026-03-16.md`。
- 历史手册仅作参考：`docs/test_reports/WAVE_C_B121_ONE_PAGE_RUNBOOK_2026-02-08.md`、`docs/test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md`。

- [当前路线图](docs/ROADMAP.md)
- [Release Plan](docs/plans/2026-05-12-release-v1.5.0-formalization.md)
- [Release Readiness](docs/test_reports/RELEASE_READINESS_V1.5.0.md)
- [架构文档](docs/ARCHITECTURE.md)
- [后端选择指南](docs/BACKEND_SELECTION_GUIDE.md)
- [平台支持](docs/PLATFORM_SUPPORT.md)
- [依赖说明](docs/DEPENDENCIES.md)
