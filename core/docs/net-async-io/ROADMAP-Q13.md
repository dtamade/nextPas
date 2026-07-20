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
| **—** | MPTCP | 平台/可移植性不足 | **deferred** |
| **—** | full native-windows | 更广套件后再评估 | **deferred** |

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
