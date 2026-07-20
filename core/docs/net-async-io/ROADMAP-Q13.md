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
| Q17 | 平台证据加深 | kqueue accept/connect；Windows native 评估 | 后续 |
| Q18 | 同机 Go/Rust bench 脚本 | SCORECARD 表；CI 不强制对照 | 后续 |

## Q13 细节

### ClassifyNetError

- 单元: `nextpas.core.net.errors`
- API: `ClassifyNetError(ACode)` → `TNetErrorClass`（Kind, Timeout, Temporary, Canceled, Code）
- 接受负码（dial 回调惯例）与正码（PLATFORM_ERR_*）
- 测试: `test_net_error_classify`

### Dial 产品默认

- 源码头注释 + CONTRACT：推荐 `AsyncTcpDial`，`AsyncTcpConnect` = HE-lite legacy
- LocalAddr：本轮 **跳过**（platform bind-before-connect 未作为稳定 API 暴露）

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
