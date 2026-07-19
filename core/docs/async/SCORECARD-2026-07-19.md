# async / net / io 质量记分卡（2026-07-19）

**范围**: nextpas.core.async + io reactors/poller + net.async
**对照**: Go `context` / `net` / channel；Rust `tokio` CancellationToken / select
**基线**: main 已 land M3 + B1–B4

## 综合分（重估）

| 维度 | 分 | 说明 |
|------|-----|------|
| 正确性 / 生命周期 | 8.5 | WhenAll RefCount+OnDiscard；Timeout CAS；class loop |
| 取消传播 | **8.5** | Q1：combinator/taskgroup/Recv|SendTimeoutEx 贯通 |
| 类型安全 | 8.5 | TAsyncLoop 强类型；TIoCompletion 统一 io.base |
| 后端完整度 | 8.0 | io_uring/epoll 运行时；kqueue compile；IOCP wine-smoke |
| 测试 / 契约 | 8.0 | 多套件 0 leak；Truth Matrix source-contract |
| **综合** | **~8.6** | Q1 取消贯通后 |

## 旧 F 项状态

| ID | 状态 | 备注 |
|----|------|------|
| F1 WhenAll UAF | **关闭** | RefCount + ScheduleEx OnDiscard |
| F2 ALoop Pointer | **关闭** | `TAsyncLoop` 参数 |
| F3 class / 测试泄漏 | **关闭** | M3 + Free 纪律 |
| F4 TIoCompletion 重复 | **关闭** | `io.base` 唯一定义 |
| F5 IoCompletionRefWrapper | **关闭** | `async.base` |
| F6 BufferPool 锁 | **关闭** | platform_mutex |
| F7 Signal 吞异常 | **部分** | 有错误回调路径；非本轮 |
| F8 DNS IPv6 | **关闭** | multi-A + dual-stack list；v4-first 排序 |
| F9 TCP positioned read | **关闭** | AsyncRecv/Send |
| F10 Combinator Ref | **关闭** | WhenAllRef/WhenAnyRef |
| F11 Channel 背压 | **关闭** | SendAsync (B1) |
| F12 取消传播 | **Q1+Q5** | combinator/taskgroup + Read/Write/Recv/Send TimeoutEx |

## Go/Rust 差距（当前）

| 能力 | Go/Rust | nextpas 现状 | 状态 |
|------|---------|--------------|------|
| 取消贯通 API | context 几乎全栈 | Token 贯通核心路径 | **Q1 done** |
| 超时+取消竞态 | 标准 | CAS 三方 | **Q1 done** |
| dual-stack | 默认 | multi-A + HE-lite 串行试连 | **Q6 done** |
| 组合器竞态 soak | 成熟 | soak100 + token/timeout race | **Q2 done** |
| 性能 scorecard | 社区基准 | 本机 metric 行 | **Q4 done** |

## 性能 scorecard（本机 2026-07-19，非严格 A/B）

诚实声明：非同 harness 对照 Go/Rust；仅为数量级参考。CI 仅要求 `> 0`。

| Metric | nextpas (this host) | 说明 |
|--------|---------------------|------|
| `post_ops_per_s` | ~3.6e5 | Post+Poll empty |
| `timer_schedule_ops_per_s` | ~5.6e6 | Schedule only |
| `mutex_ops_per_s` | ~1.3e7 | async mutex lock/unlock |
| `channel_ops_per_s` | ~4.6e5 | send+TryReceive |

运行：`make -C core/tests/nextpas.core.async/test_async_bench clean test`

## Q1–Q4 成功标准（摘要）

- [x] Combinator Token 取消 / soak
- [x] TaskGroup Token
- [x] Recv/SendTimeoutEx token
- [x] dual-stack resolve list
- [x] bench metric 行 + 本文档
