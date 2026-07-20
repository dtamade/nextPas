# async / net / io 质量记分卡（2026-07-20）

**范围**: nextpas.core.async + io reactors/poller + net.async  
**对照**: Go `net`/`context`；Rust `tokio`（质量属性，非 API 克隆）  
**基线**: Q1–Q12 Landed；调研 [GO-RUST-PARITY.md](../net-async-io/GO-RUST-PARITY.md)

## D1–D8（重估）

| 维度 | 分 | 说明 |
|------|-----|------|
| D1 取消 | **8.5** | Q14: `NetCancelFromAsync` 统一推荐入口；Net 为阻塞 plumbing |
| D2 超时竞态 | 8.5 | CAS + dial deadline |
| D3 双栈 HE | 8.5 | 严格 CAD + DNS race + lab feed |
| D4 错误可判定 | **7.5→8.0** | **ClassifyNetError (Q13)** |
| D5 平台证据 | 7.5 | macOS L0/L1 fail-closed；Windows wine |
| D6 性能诚实 | 7.0 | metric 行；无同 harness A/B |
| D7 API 可用性 | 7.5 | Dial 推荐路径文档化 |
| D8 生命周期 | 9.0 | class loop + 0 leak 纪律 |
| **综合** | **~8.1** | 较 07-19 的 ~8.6 更严（按 D 轴诚实重估） |

## Go/Rust 差距（当前）

| 能力 | 状态 |
|------|------|
| 取消贯通 | Q1 核心 done；net 双 Token **Q14** |
| HE / DNS race | **Q6–Q12 done** |
| 错误分类 | **Q13 ClassifyNetError** |
| Async UDP / Pool async | **Q15 / Q16** |
| Windows native | 未宣称 |
| 性能 A/B | **Q18** |

## Q 清单

- [x] Q1–Q12（取消、HE、DNS race、CAD、lab feed、macOS fail-closed）
- [x] Q13 Wave R 文档 + ClassifyNetError + Dial 推荐路径
- [x] Q14 NetCancelFromAsync + BindCancelToken + test_net_cancel_bridge
- [ ] Q15–Q18 见 ROADMAP-Q13.md

## 性能 scorecard

诚实声明：非同 harness 对照 Go/Rust。CI 仅要求 metric `> 0`。

运行：`make -C core/tests/nextpas.core.async/test_async_bench clean test`
