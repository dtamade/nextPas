# net-async-io 问题修复调研报告

**日期**: 2026-07-11
**范围**: nextpas.core.io / nextpas.core.net / nextpas.core.async 三模块
**方法**: 根因分析 + Rust tokio / Go net+sync 对标

---

## 1. 问题分类与根因分析

### 类别 A: 全局状态 (3 个问题)

| ID | 文件 | 问题 | 根因 |
|----|------|------|------|
| F1 | async.timeout.pas:76 | `GTimeoutHandle` 全局变量 | TAsyncCallback 是 procedure 类型，不能捕获上下文 |
| F2 | async.taskgroup.pas:109 | `GTaskGroup` 全局变量 | 同上 |
| F3 | async.shutdown.pas:89 | `GShutdownManager` 全局变量 | 同上 |

**根因深挖**: 三个模块的定时器回调都是 `procedure(AContext: Pointer)` 类型，无法像匿名过程那样捕获外部变量。开发者用全局变量传递实例引用，但 `Schedule` 已经支持 `AContext: Pointer` 参数——完全可以把实例指针作为上下文传入。

**对标**:
- **Rust tokio**: `tokio::time::timeout(duration, future)` 返回 `JoinHandle`，通过闭包捕获上下文，无全局状态
- **Go**: `context.WithTimeout(parent, timeout)` 返回新 context 链，通过参数传递，无全局状态
- **关键差异**: Rust/Go 都通过闭包/参数传递上下文，从不使用全局变量存储实例引用

**修复策略**: 把实例指针作为 AContext 传给 Schedule，回调中通过 AContext 恢复实例引用。移除全局变量。

**风险**: 低。纯机械替换，不改变公共 API。

---

### 类别 B: 生命周期安全 (3 个问题)

| ID | 文件 | 问题 | 根因 |
|----|------|------|------|
| F11 | 7 个文件 | `FLoop := @ALoop` 存储栈指针 | TAsyncLoop 是 record，栈分配后指针悬空 |
| F5 | async.combinators.pas:170 | WhenAll 超时后 LState 泄漏 | 超时回调不清理堆分配状态 |
| F9 | async.condvar.pas:141 | CondVar Wait 丢失唤醒 | 先入队再 Unlock 的竞态窗口 |

**根因深挖 (F11)**: TAsyncLoop 是 record，所有同步原语 (mutex/semaphore/channel/condvar/timeout/shutdown/taskgroup/retry/combinators) 都存储 `@ALoop` 指针。如果 loop 在同步原语之前离开作用域，指针悬空。

**对标**:
- **Rust tokio**: `tokio::runtime::Handle` 是 `Clone + Send + Sync` 的 Arc 包装，引用计数保证生命周期
- **Go**: `context.Context` 是接口，通过参数传递，GC 管理生命周期；`errgroup.Group` 是纯值对象，零值可用
- **关键差异**: Rust 用 Arc 引用计数，Go 用 GC。两者都不需要调用方手动管理生命周期指针

**修复策略**: TAsyncLoop 改为 class（堆分配 + 引用计数），或引入 `IAsyncLoop` 接口。推荐前者，改动最小。

**风险**: 中。涉及 TAsyncLoop 的所有使用方，需要同步修改。

---

### 类别 C: 类型安全缺失 (3 个问题)

| ID | 文件 | 问题 | 根因 |
|----|------|------|------|
| F10 | async.combinators.pas:56 | `ALoop: Pointer` 参数 | 绕过编译器类型检查 |
| F19 | async.combinators.pas + retry.pas | 同上 | 同上 |
| F6 | async.taskgroup.pas:218 | `Pointer(ACallback)` 丢失上下文 | 把用户回调指针当作 AContext 传递 |

**根因深挖**: WhenAll/WhenAny/RetryWithBackoff 的 ALoop 参数类型是 `Pointer`，调用者可以传任意指针。TaskGroup 的 RunTask 把用户回调函数指针转为 Pointer 传递，丢失了用户原始 AContext。

**修复策略**:
- F10/F19: 改为 `PAsyncLoop` 或直接传 `TAsyncLoop`（改为 class 后传对象引用）
- F6: 使用堆分配的上下文记录同时保存回调和用户上下文

**风险**: 低。改变函数签名，需要更新调用方。

---

### 类别 D: 代码重复 (4 个问题)

| ID | 问题 | 重复次数 |
|----|------|---------|
| F12 | Post/PostRef/PostMethod 三套方法 | ~60 行×3 在 loop.pas |
| F13 | 三种回调类型 (Regular/Ref/Method) | 每个 API 三个版本 |
| F14 | IoCompletionRefWrapper 重复定义 | 2 处 (loop.pas + net.async.tcp.pas) |
| F15 | TIoCompletion 类型重复定义 | 6 处 (reactor/epoll/iocp/kqueue/poller/base) |

**根因深挖**: FPC 不支持泛型匿名过程，所以每种回调风格都需要独立实现。TIoCompletion 在 6 个文件中各定义一次，完全相同。

**对标**:
- **Rust**: `Future<Output = T>` 统一异步模型，trait 自动派生
- **Go**: goroutine + channel 统一并发模型，无需回调风格选择

**修复策略**:
- F15: 统一 TIoCompletion 到 `nextpas.core.async.base`，其他文件删除本地定义
- F14: 提取到 `nextpas.core.async.base` 或新建 `nextpas.core.async.util`
- F12/F13: 渐进统一，优先支持 Ref 类型（FPC 匿名过程），Regular/Method 保留但标记 deprecated

**风险**: 低。纯重构，不改变行为。

---

### 类别 E: 功能缺陷 (9 个问题)

| ID | 文件 | 问题 | 严重度 |
|----|------|------|--------|
| F4 | async.timeout.pas:209 | `RemainingMs` 返回定时器 ID 而非剩余时间 | 高 |
| F7 | async.taskgroup.pas:241 | WaitAll 在调用者栈上直接执行回调 | 中 |
| F8 | async.shutdown.pas:206 | OnShutdown 在调用者栈上直接执行回调 | 中 |
| F16 | async.signal.pas | ProcessSignals 不集成事件循环 | 中 |
| F17 | async.buffer.pas | IAsyncBufferPool 非线程安全 | 低 |
| F18 | async.retry.pas | AOnError 回调修改外部布尔值 | 低 |
| F20 | async.pas | 门面缺少工厂函数 re-export | 低 |
| F21 | net.pas | 门面缺少异步工厂函数 re-export | 低 |
| F22 | 多文件 | 编译指令不统一 | 低 |

**修复策略**: 逐个修复，详见实施规划。

---

## 2. 影响范围分析

| 类别 | 受影响文件数 | 受影响测试数 | 公共 API 变更 |
|------|:-----------:|:-----------:|:------------:|
| A. 全局状态 | 3 | 3 (timeout/taskgroup/shutdown) | 无 |
| B. 生命周期 | 10+ | 全部 async 测试 | TAsyncLoop 类型变更 |
| C. 类型安全 | 4 | combinators/retry/taskgroup | 函数签名变更 |
| D. 代码重复 | 8 | 无（纯重构） | TIoCompletion 来源变更 |
| E. 功能缺陷 | 7 | 相关测试 | 部分 API 变更 |

---

## 3. 修复策略总结

| 优先级 | 类别 | 策略 | 工作量 |
|:------:|------|------|:------:|
| **P0** | A. 全局状态 | 用 AContext 传递实例指针 | 小 |
| **P0** | E:F4 RemainingMs | 实现真正的剩余时间计算 | 小 |
| **P1** | B. 生命周期 | TAsyncLoop 改为 class | 中 |
| **P1** | C. 类型安全 | 强类型化参数 | 小 |
| **P1** | E:F7/F8 回调调度 | 改为 Post 调度 | 小 |
| **P2** | D. 代码重复 | 统一 TIoCompletion + 提取公共代码 | 中 |
| **P2** | E:F16-F22 | 逐个修复 | 小 |

---

## 4. 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| TAsyncLoop 改 class 破坏现有代码 | 高 | 中 | 保持公共 API 不变，只改内部实现 |
| 全局状态移除引入新的生命周期问题 | 低 | 中 | 用引用计数管理实例生命周期 |
| 回调风格统一导致调用方需要迁移 | 中 | 低 | 保留旧 API，标记 deprecated |

---

## 附录: Go 对标详细数据

| 模式 | Go API | 全局状态 | 实例化方式 |
|------|--------|:--------:|-----------|
| Context+timeout | `context.WithTimeout(parent, timeout)` | **无** | 返回新 context 链 |
| errgroup | `errgroup.Group` | **无** | 纯值对象，零值可用 |
| http.Shutdown | `Server.Shutdown(ctx)` | **无** | 实例级 `inShutdown atomic.Bool` + `onShutdown []func()` |
| signal.Notify | `signal.Notify(c, sig...)` | **有**（OS 信号是进程级资源） | 全局 `handlers` map + Mutex + 引用计数 |
| 类型安全 | interface + channel + 强类型签名 | — | 编译期检查，零 unsafe 转换 |

**Go 设计哲学**: "能用值传递就不用全局注册，能用 channel 就不用共享内存，能用类型系统就不用运行时检查。"

**对我们的启示**:
1. 全局单例是设计反模式 — Go 从不这样做
2. 唯一合理的全局状态是信号处理 — OS 信号确实是进程级资源
3. 实例级状态 + 参数传递是标准做法
4. 强类型签名消除运行时类型错误
