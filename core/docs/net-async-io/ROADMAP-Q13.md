# ROADMAP Q13+（Go/Rust 质量波次）

**基线**: Q1–Q12 Landed；调研见 [GO-RUST-PARITY.md](GO-RUST-PARITY.md)

## 波次

| 波次 | 主题 | 退出标准 | 状态 |
|------|------|----------|------|
| **R** | 对标文档 + 记分卡 | GO-RUST-PARITY + 本文件 + SCORECARD 更新 | **本轮** |
| **Q13** | ClassifyNetError + Dial 推荐路径文档 | 单测 0 leak；CONTRACT 表 | **done** |
| **Q14** | 统一 IAsyncCancellationToken / INetCancelToken | `NetCancelFromAsync` + soak | **done** |
| **Q15** | Async UDP 最小面 | Bind/RecvFrom/SendTo + Timeout | **done** |
| **Q16** | Pool.AcquireAsync → AsyncTcpDial | Token + idle 校验 | **done** |
| **Q17** | 平台证据加深 | kqueue accept/connect；Windows native 评估 | **done** |
| **Q18** | 同机 Go/Rust bench 脚本 | SCORECARD 表；CI 不强制对照 | **done** |
| **Q19** | localhost dial 吞吐对照 | dial_ops_per_s + go peer | **done** |
| **Q20** | 并发 multi-dial 吞吐 | dial_concurrent_ops_per_s + go concurrent peer；Windows assessment 轻量 | **done** |
| **Q21** | 公网 DNS HE 统计样本 | opt-in `NEXTPAS_PUBLIC_DNS_HE=1`；metrics；非 CI 门 | **done** |
| **Q22** | Windows native async smoke 挂钩 | `async-windows-native-smoke.sh` + CI continue-on-error | **done** |
| **Q23** | 多 host 公网 HE 矩阵 | 3 host + v4/v6 attempt 分计；可选 PreferIPv6First 遍 | **done** |
| **Q24** | Windows fail-closed 就绪 | streak 观测 + **fail-closed 升格** | **done (A+B)** |
| **Q25** | Dial LocalAddr bind-before-connect | Go Dialer.LocalAddr subset；family match；0 leak | **done** |
| **Q26** | Dial NoDelay/KeepAlive 选项 | 成功 stream 回调前 best-effort 应用 | **done** |
| **Q27** | Dial OnControl | Go Control 子集；attempt 级 fail | **done** |
| **Q28** | Dial OnResolve | 自定义 Resolver via DnsFeed 契约 | **done** |
| **Q29** | Pool AcquireAsyncEx | 贯通 TAsyncTcpDialOptions | **done** |
| **Q30** | Dial AddressFamily 过滤 | dafAny/v4/v6 | **done** |
| **Q31** | Dial OnAttemptResult | attempt 结果可观测 | **done** |
| **Q32** | 门面 DnsFeed + 对标重估 | AsyncTcpDialWithDnsFeed re-export；D 轴 ~8.3 | **done** |
| **Q33** | Windows candidate 套件扩容 | dial/resolve/udp/pool/error/cancel 入 smoke | **done** |
| **Q34** | smoke 与 platform matrix 解耦 | FPC 安装成功即跑 async smoke | **done** |
| **Q35** | Windows 测试 cthreads 条件化 | `{$IFDEF UNIX}cthreads{$ENDIF}` 修编译 | **done** |
| **Q36** | net.tcp/udp 去 POSIX sockaddr 耦合 | TPlatformSockAddr only — win64 可编 dial/udp | **done** |
| **—** | MPTCP | 见下文：不做的原因 | **deferred permanently (for now)** |
| **—** | full native-windows claim | 等 Q33+Q36 扩容 smoke 多周绿 | **deferred** |

### 为何 MPTCP 不做

1. **无跨平台内核契约**：Linux 用 `IPPROTO_MPTCP`/`mptcp` socket；macOS/Windows 无对等稳定公开 ABI。
2. **非 Dial 默认路径**：Go 也只是 opt-in；强行默认会改变路径选择与失败语义。
3. **可观测/测试成本高**：需要多路径网卡/内核配置，CI 无法诚实 fail-closed。
4. **当前质量北极星**是 HE + cancel + Windows candidate 证据，不是 MPTCP 功能点。

若未来做：仅 Linux opt-in `DialOptions.Multipath`，默认 false，独立 lab 套件，永不进默认 CI 门。

### 为何 full native-windows 尚未宣称

1. claim 名 **native-windows** = 满血 host 对等；当前只能诚实标 **candidate**。
2. Q33 扩容后曾 **编不过**（cthreads + sockaddr POSIX 耦合）→ Q35/Q36 修编译。
3. 升满血条件（assessment）：扩容 smoke **多周** step=success streak + 无 flaky + 文档矩阵对齐。
4. platform.watch 等 **非 async 套件** 仍可能让 job overall 红；Q34 已解耦 smoke 证据。

Q36 落地后：Windows 上 dial/udp/pool 应能 **编译**；下一刀是盯 GHA async smoke 全绿，再谈 claim 升级。

## Q13 细节

### ClassifyNetError

- 单元: `nextpas.core.net.errors`
- API: `ClassifyNetError(ACode)` → `TNetErrorClass`（Kind, Timeout, Temporary, Canceled, Code）
- 接受负码（dial 回调惯例）与正码（PLATFORM_ERR_*）
- 测试: `test_net_error_classify`

### Dial 产品默认

- 源码头注释 + CONTRACT：推荐 `AsyncTcpDial`，`AsyncTcpConnect` = HE-lite legacy
- LocalAddr：~~本轮跳过~~ → **Q25** bind-before-connect 已接线

### 不做

- 改回调签名为 INetError 对象（保留 Int32 + Classify）
- MPTCP / 完整 Dialer Control

## 依赖

```
R ──► Q13 ──► Q14 ──► Q15
              └─────► Q16
R ──► Q17 (证据，可并行)
R ──► Q18 (性能，可并行)
```

## 验证命令

```bash
make -C core/tests/nextpas.core.net/test_net_error_classify clean test
make -C core/tests/nextpas.core.net/test_net_async_dial clean test
bash core/scripts/async-host-matrix.sh
```
