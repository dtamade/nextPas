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
| F8 DNS IPv6 | **部分** | 有 v6 fallback；非 multi-addr / Happy Eyeballs |
| F9 TCP positioned read | **关闭** | AsyncRecv/Send |
| F10 Combinator Ref | **关闭** | WhenAllRef/WhenAnyRef |
| F11 Channel 背压 | **关闭** | SendAsync (B1) |
| F12 取消传播 | **Q1 已贯通** | combinator/taskgroup/Recv|SendTimeoutEx；非全 API 表面 |

## Go/Rust 差距（当前）

| 能力 | Go/Rust | nextpas 现状 | Q 计划 |
|------|---------|--------------|--------|
| 取消贯通 API | context 几乎全栈 | Token 孤立 | **Q1** |
| 超时+取消竞态 | 标准 | Timeout CAS 有；缺 token 方 | **Q1** |
| dual-stack | 默认 | 单地址 fallback | Q3 |
| 组合器竞态 soak | 成熟 | 基础测有 | Q2 |
| 性能 scorecard | 社区基准 | bench 烟雾 | Q4 |

## 本轮 Q1 成功标准（摘要）

- Combinator `Token` 取消 → 一次 completion、0 leak  
- TaskGroup `Token` → CancelAll  
- `AsyncRecvTimeoutEx` / `AsyncSendTimeoutEx` + token 与 timer 竞态单次完成  
- 文档不再写「无取消传播」  
