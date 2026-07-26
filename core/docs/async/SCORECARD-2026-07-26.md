# async / net / io 质量记分卡（2026-07-26）

**范围**: nextpas.core.async + io reactors/poller + net.async
**对照**: Go `net`/`context`；Rust `tokio`（质量属性，非 API 克隆）
**基线**: Q1–Q41 done；前一版 [SCORECARD-2026-07-20.md](SCORECARD-2026-07-20.md)

## 本轮变化（Q41）

1. **Wake coalescing**（Go netpollBreak 协议）：`FWakeSignaled` 原子标志合并唤醒，
   只有 0→1 转换支付 eventfd write；`Poll`/`Run` 热路径去 `DrainWake` read；
   `HasPending=0` 时跳过 `Flush`+`epoll_wait(0)`。post 热路径从 ~3 syscall/op 降到 ~0。
2. **bench 旗标诚实化**：parity 脚本原用默认测试旗标（含 `-gh` heaptrc 全量堆跟踪），
   Go/Rust peer 却是 release——nextpas 侧单方面征税。脚本改 release 旗标；
   泄漏纪律仍归默认 `make test`（全套件 0 leak 不变）。
3. 归因证据链见 [ROADMAP-Q13.md](../net-async-io/ROADMAP-Q13.md) Q41 细节。

## D1–D8（重估）

| 维度 | 分 | 说明 |
|------|-----|------|
| D1 取消 | 8.5 | Q14 统一入口；新增 StopDuringDeepSleep 保证睡眠中 Stop 不被合并吞掉 |
| D2 超时竞态 | 8.5 | CAS + dial deadline |
| D3 双栈 HE | 8.5 | 严格 CAD + DNS race + lab feed |
| D4 错误可判定 | 8.0 | ClassifyNetError (Q13) |
| D5 平台证据 | 8.0 | Q39 ConnectEx pre-bind + Q40 IOCP datagram；soft→STRICT 待 GHA streak |
| D6 性能诚实 | **7.8→8.5** | **Q41**: post/channel 与 Go 同数量级 + 旗标对等 + 归因表 |
| D7 API 可用性 | 8.2 | Dial options 面 Q25–Q31 + pool Ex |
| D8 生命周期 | 9.0 | class loop + 0 leak 纪律；lost-wakeup 探测器（PingPong 200 轮）绿 |
| **综合** | **~8.4** | Q41 后诚实重估 |

## 性能 scorecard（同机 2026-07-26，release 旗标）

运行：`bash core/scripts/async-bench-parity.sh`

**诚实声明**：peer 为 std 通道/互斥/定时器创建量级参考，**不是** TAsyncLoop API 等价；
**禁止**据此宣称「快于 Go/Rust」。CI 不强制本脚本。

| Metric | nextpas | go peer | rust peer | vs Go |
|--------|---------|---------|-----------|-------|
| `post_ops_per_s` | ~4.0e6 | ~1.3e7 | ~1.3e8 | 3.2× 慢（旧 37×） |
| `timer_schedule_ops_per_s` | ~5.5e6 | ~1.5e6 | ~1.0e8 | **3.7× 快** |
| `mutex_ops_per_s` | ~1.7e7 | ~7.1e7 | ~6.4e7 | 4.1× 慢 |
| `channel_ops_per_s` | ~7.7e6 | ~1.5e7 | ~2.3e7 | 2.0× 慢（旧 34×） |
| `dial_ops_per_s` | ~1.25e4 | ~1.0e4 | — | **1.2× 快** |
| `dial_concurrent_ops_per_s` | ~1.7e4 (inflight=8) | ~9.7e4 (goroutine×16) | — | 形态不同 |

truth=`same-host-order-of-magnitude`；dial 行 truth=`localhost-*-dial`

### 与 2026-07-20 对照

| Metric | 旧（heaptrc+每op syscall） | 新（release+coalescing） | 提升 |
|--------|---------------------------|--------------------------|------|
| `post_ops_per_s` | ~3.2e5 | ~4.0e6 | ~13× |
| `channel_ops_per_s` | ~4.7e5 | ~7.7e6 | ~16× |

拆分归因：post 主因 syscall（coalescing ~11×），channel 主因 heaptrc（旗标 ~19×）。

## 残留差距（诚实清单）

| 项 | 差距 | 归因 | 处置 |
|----|------|------|------|
| post vs Go 3.2× | MPSC per-node New/Dispose + FPC 调用开销 | lockfree F-044 证明池化为否定结果 | 不动；数量级已对齐 |
| mutex vs Go 4.1× | TryLock/Unlock 经 interface 虚调用 | 形态差异（Go 是裸 futex 快路径） | 观察 |
| dial_concurrent | 单 loop inflight=8 vs goroutine×16 | 执行模型差异 | 形态说明已注记 |
