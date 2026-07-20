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
| D5 平台证据 | **8.0** | accept/connect smoke + kqueue accept/connect；Windows still wine |
| D6 性能诚实 | **7.5** | Q18 same-host peer table; not API-equivalent |
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
| Windows native | **candidate fail-closed** (Q24B) |
| 性能 A/B | **Q18** |

## Q 清单

- [x] Q1–Q12（取消、HE、DNS race、CAD、lab feed、macOS fail-closed）
- [x] Q13 Wave R 文档 + ClassifyNetError + Dial 推荐路径
- [x] Q14 NetCancelFromAsync + BindCancelToken + test_net_cancel_bridge
- [x] Q15 AsyncUdpBind + SendTo/RecvFrom + test_net_async_udp
- [x] Q16 Pool AcquireAsync + AsyncTcpDial + test_net_async_pool
- [x] Q17 accept/connect smoke + kqueue expand + WINDOWS-NATIVE-ASSESSMENT
- [x] Q18 async-bench-parity.sh + peer fixtures + SCORECARD 表
- [x] Q19 localhost dial_ops_per_s + go-dial peer
- [x] Q20 dial_concurrent_ops_per_s + go-dial-concurrent peer；Windows native 仅评估挂钩
- [x] Q21 public DNS HE stats opt-in (`NEXTPAS_PUBLIC_DNS_HE=1`)
- [x] Q22 async-windows-native-smoke CI step (continue-on-error)
- [x] Q23 multi-host public HE matrix (opt-in)
- [x] Q24A windows smoke streak observer; **Q24B fail-closed promoted** (candidate claim)
- [x] Q25 Dial LocalAddr bind-before-connect + Default() managed-safe options
- [x] Q26 Dial NoDelay/KeepAlive options on winning stream
- [x] Q27 Dial OnControl (Control subset)
- [x] Q28 Dial OnResolve (custom resolver via feed)
- [x] Q29 Pool AcquireAsyncEx dial options
- [x] Q30 Dial AddressFamily filter (dafIPv4/dafIPv6)
- [ ] MPTCP deferred; full native-windows deferred

## 性能 scorecard（同机 2026-07-20）

运行：`bash core/scripts/async-bench-parity.sh`

**诚实声明**：peer 为 std 通道/互斥/定时器创建量级参考，**不是** TAsyncLoop API 等价；**禁止**据此宣称「快于 Go/Rust」。CI 不强制本脚本。

| Metric | nextpas | go peer | rust peer |
|--------|---------|---------|-----------|
| `post_ops_per_s` | ~3.2e5 | ~1.2e7 | ~1.3e8 |
| `timer_schedule_ops_per_s` | ~6.2e6 | ~1.7e6 | ~1.3e8 |
| `mutex_ops_per_s` | ~1.6e7 | ~7.3e7 | ~7.7e7 |
| `channel_ops_per_s` | ~4.7e5 | ~1.6e7 | ~3.2e7 |
| `dial_ops_per_s` | O(10³–10⁴) | O(10⁴) | — |
| `dial_concurrent_ops_per_s` | O(10³–10⁴) single-loop | O(10⁴–10⁵) goroutine | — |

truth=`same-host-order-of-magnitude`；dial 行 truth=`localhost-*-dial`
