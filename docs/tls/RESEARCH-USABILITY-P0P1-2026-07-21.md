# 专题调研：hash / crypto / tls 可用性 P0–P1

**日期**：2026-07-21  
**状态**：调研完成 · 实施按里程碑推进  
**范围**：RTL 终态 / 错误模型 / API 收敛 / stream 脱 Classes  
**权威约束**：仅 `nextpas.core.system*` 可直引 FPC RTL；生产应经 core owner 抽象  

---

## 1. 问题分类与根因

### 1.1 RTL 终态（合规 · 编译器透明）

| 问题 | 根因 | 对标 |
|------|------|------|
| `wolfssl.context` uses **Base64** | 证书固定仍走 FPC Base64 单元 | mbedtls/freepascal 已迁 `encoding.base64` |
| `mbedtls.connection` uses **Sockets** | uses 残留；实现几乎未用 Sockets 符号 | platform.socket / net |
| winssl `Windows` ×11 | Schannel FFI 必须绑 OS | Go `golang.org/x/sys/windows`；Rust `windows-sys` — **保留并契约化** |
| 生产 `system.classes.THandleStream` | freepascal 握手路径用 Classes 流 + WrapTStream | Go `net.Conn`；Rust `Read+Write` trait 对象 |

**合法终态矩阵**

| 类别 | 允许 | 路径 |
|------|------|------|
| system* | FPC SysUtils/Classes/… | 门面转发到 core owner |
| platform / net | OS FFI | `platform.socket`、`platform.random`、`net.tcp` |
| winssl | `Windows`（仅 winssl.*） | allowlist 标注 platform-FFI |
| hash/crypto/tls 其余 | **禁止** broad RTL | text.conv / encoding / time / crypto.random / io.intf |

### 1.2 错误模型

| 层 | 现状 | 根因 |
|----|------|------|
| crypto | `ECryptoError` + 4 code；热路径 0 裸 Exception | 上一波已修 |
| tls | 深 `ESSL*` 树 + **~32** 裸 `raise Exception` | 历史脚手架未收敛 |
| 跨层 | 无共享 code 映射 | 两套枚举独立演化 |

**对标策略**：Rust `thiserror` 分 crate 错误类型 + 上层 `From`；Go 哨兵 `errors.Is`。  
**本库策略**：保留 crypto / tls 两棵树，增加 **映射表**（crypto code → sslErr*）；tls 裸 Exception → `ESSLInvalidArgument` / `RaiseSSLError`。

### 1.3 API 收敛

| 问题 | 根因 |
|------|------|
| `tls.crypto.utils.THashAlgorithm` = `HASH_*` **与** `hash.base.ha*` **ordinal 不同** | OpenSSL 工具箱独立演化 |
| `TCryptoUtils` vs `nextpas.core.crypto` | 企业工具箱 vs pure Pascal 原语 |
| crypto 门面无 `random` | 遗漏 re-export |
| `tls.pas` 单行压缩 | 历史格式 |

**策略**：`HASH_*` 改为 **const 别名到 ha***（同一枚举）；case 自动正确。  
`TCryptoUtils` **保留**（OpenSSL 依赖路径）但文档降级为 “OpenSSL backend helper”，新代码走 `crypto.*`。

### 1.4 Stream 脱 Classes

| 现状 | 风险 |
|------|------|
| `THandleStream` + `TMemoryStream` + 本地 `TConcatStream(TStream)` | 生产绑定 FPC Classes |
| `net.tcp.NetTcpStreamFromConnectedSocket` 已存在 | Destroy 会 **close socket**，与 connection 拥有权冲突 |
| `WrapTStream` 桥双向存在 | 过渡可用 |

**策略（分两阶段）**：

1. **P1a（本波）**：为 fd/socket 增加 **不拥有 close** 的 `IStream` 适配（或 net 增加 `OwnsSocket=False` 参数）；替换纯 `THandleStream.Create(FSocket)` 路径。  
2. **P1b / M3**：`TConcatStream` / `TMemoryStream` → core `io` 缓冲拼接（值类型 buffer + IStream），完全去掉 freepascal.connection 的 `system.classes`。

---

## 2. 影响范围

| 改动 | 触达路径 |
|------|----------|
| Base64 迁移 | `tls.wolfssl.context` + 固定相关测试（若有） |
| 删 Sockets uses | `tls.mbedtls.connection` |
| HASH_* 别名 | `tls.crypto.utils` + 测试/bench 中 HASH_*（const 兼容可少改测试） |
| 裸 Exception | safety, crl, freepascal.session, posthandshake, … |
| 门面 | `crypto.pas`, `tls.pas` |
| Stream | `tls.freepascal.connection`（P1a 最小） |
| 契约 | layer contract / VERIFY / OWNERSHIP D14+ |

---

## 3. 修复策略与风险

| 项 | 策略 | 风险 | 缓解 |
|----|------|------|------|
| Base64 | 同 mbedtls：`Base64Decode` | 低 | 固定长度 32 校验保留 |
| Sockets | 删除 uses | 极低 | 静态确认无符号 |
| HASH enum | type 别名 + const HASH_*=ha* | 中：ordinal 变化 | 全量替换 case 已用常量名即可 |
| Exception | → ESSLInvalidArgument / RaiseSSLError | 低 | 语义同 message |
| random re-export | uses + type 别名 | 低 | 门面测试 |
| Socket IStream | 本地 adapter 不 close | 中 | 单测 dialer/handshake |
| winssl | 不迁出 Windows | — | 文档+allowlist |

---

## 4. 里程碑计划

```
M0  契约锁门（机检条目写入 VERIFY）          ──并行──
M1  P0: RTL 残留清零 + HASH_* 统一           依赖 M0 文档
M2  P1: 裸 Exception 清零（tls 生产）        依赖 M1
M3  P1: 门面可读 + crypto.random re-export   依赖 M1
M4  P1a: freepascal 路径去 THandleStream     依赖 M1
M5  文档 OWNERSHIP D14+ / 评估修订           依赖 M1–M4
M6  （后续）P1b 完全去 system.classes        独立 slice
```

**本波实施范围**：**M1 + M2 + M3 + M4（最小）+ M5**；M6 不在本波。

---

## 5. 成功标准

| 指标 | 目标 |
|------|------|
| non-winssl 生产 broad RTL | **0**（含 Base64/Sockets） |
| `tls.crypto.utils` 独立 enum 定义 | **0**（仅 alias） |
| tls 生产 `raise Exception.` | **0** |
| crypto 门面可 uses random | **是** |
| freepascal.connection 无 THandleStream | **是**（P1a） |
| hash/crypto focused + tls 关键门 | **绿** |
| hygiene | **pass** |

---

## 6. 明确不做（本波）

- winssl 迁出 `Windows`
- 删除 `TCryptoUtils`
- 全量 OpenSSL 错误码重构
- M6 完全删除 freepascal 内 TMemoryStream/TConcatStream（若 P1a 后仍依赖 system.classes 用于 Memory/Concat，允许保留 **仅** 这些类型并在报告中登记；目标是去掉 **THandleStream**）
