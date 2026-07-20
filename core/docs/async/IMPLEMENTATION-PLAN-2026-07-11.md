# net-async-io 问题修复实施规划

**日期**: 2026-07-11
**基于**: core/docs/async/RESEARCH-REPORT-2026-07-11.md
**总工作量**: 6 个里程碑，预计 15-20 个文件改动

---

## 里程碑总览

```
M1: P0 全局状态清除 (3 文件)          ← DONE
M2: P0 RemainingMs 修复 (1 文件)      ← DONE
M3: TAsyncLoop record→class (10+ 文件) ← DONE 2026-07-19
M4: 类型安全 + 回调调度修复 (5 文件)    ← DONE（强类型 ALoop）
M5: 代码去重 (4 文件)                  ← DONE（TIoCompletion/io.base + RefWrapper）
M6: 功能缺陷收尾                       ← 部分（SendAsync/TCP Recv 等）
Q1: CancellationToken 贯通             ← 2026-07-19（combinator/taskgroup/Recv|SendTimeoutEx）
Q2–Q4: 见 SCORECARD-2026-07-19.md
```

---

## M1: P0 全局状态清除

**目标**: 移除 GTimeoutHandle / GTaskGroup / GShutdownManager 三个全局变量
**策略**: 把实例指针作为 AContext 传给 Schedule，回调中通过 AContext 恢复实例
**影响**: 3 文件，0 公共 API 变更

### M1.1 async.timeout.pas

```
Before:
  var GTimeoutHandle: TAsyncTimeoutHandle = nil;
  procedure TimeoutCallback(AContext: Pointer);
  begin
    if GTimeoutHandle <> nil then
      GTimeoutHandle.HandleTimeout(AContext);
  end;
  // ...
  GTimeoutHandle := LHandle;
  LHandle.FTimerHandle := ALoop.Schedule(..., @TimeoutCallback, nil);

After:
  // 移除 GTimeoutHandle 全局变量
  // 定时器回调通过 AContext 获取实例
  LHandle.FTimerHandle := ALoop.Schedule(..., @TimeoutCallback, Pointer(LHandle));
  // 回调中:
  procedure TimeoutCallback(AContext: Pointer);
  var LHandle: TAsyncTimeoutHandle;
  begin
    LHandle := TAsyncTimeoutHandle(AContext);
    LHandle.HandleTimeout(nil);
  end;
```

### M1.2 async.taskgroup.pas

```
Before:
  var GTaskGroup: TAsyncTaskGroup = nil;
  // WrappedTaskCallback 通过 GTaskGroup 访问实例

After:
  // 移除 GTaskGroup 全局变量
  // 堆分配上下文记录，包含回调+用户上下文+组指针
  type
    PTaskWrapCtx = ^TTaskWrapCtx;
    TTaskWrapCtx = record
      UserCallback: TAsyncCallback;
      UserContext: Pointer;
      Group: TAsyncTaskGroup;
    end;
  // Post 时传入 PTaskWrapCtx，回调中恢复并使用
```

### M1.3 async.shutdown.pas

```
Before:
  var GShutdownManager: TAsyncShutdownManager = nil;
  // DrainTimeoutCallback 通过 GShutdownManager 访问实例

After:
  // 移除 GShutdownManager 全局变量
  // Schedule 时传入 Self 指针作为 AContext
  FLoop^.Schedule(..., @DrainTimeoutCallback, Pointer(Self));
  // 回调中:
  procedure DrainTimeoutCallback(AContext: Pointer);
  var LMgr: TAsyncShutdownManager;
  begin
    LMgr := TAsyncShutdownManager(AContext);
    // 使用 LMgr 替代 GShutdownManager
  end;
```

**验证**: test_async_timeout / test_async 通过，无全局变量残留

---

## M2: P0 RemainingMs 修复

**文件**: async.timeout.pas
**问题**: `RemainingMs` 返回 `FTimerHandle.FId`（定时器 ID），不是剩余毫秒数
**修复**: 计算真正的剩余时间

```pascal
function TAsyncTimeoutHandle.RemainingMs: UInt32;
var
  LDeadline: TDeadline;
  LRemaining: TDuration;
begin
  platform_mutex_lock(FLock);
  try
    if FDone then
      Exit(0);
    // 需要存储创建时间和超时时长来计算剩余时间
    // 或者从 FTimerHandle 查询定时器剩余时间
    LRemaining := FDeadline.Remaining;
    if LRemaining.AsMilliseconds <= 0 then
      Exit(0);
    Result := UInt32(LRemaining.AsMilliseconds);
  finally
    platform_mutex_unlock(FLock);
  end;
end;
```

**前提**: TAsyncTimeoutHandle 需要存储 TDeadline（创建时的时间点+超时时长）

**验证**: test_async_timeout 中 RemainingMs 相关断言

---

## M3: TAsyncLoop record→class

**目标**: TAsyncLoop 从 record 改为 class，解决所有 PAsyncLoop 指针悬空问题
**影响**: 10+ 文件，所有使用 PAsyncLoop 的模块
**策略**: 保持公共 API 不变（`TAsyncLoop.Create` 工厂函数仍可用），内部改为堆分配

### 变更清单

| 文件 | 变更 |
|------|------|
| async.loop.pas | `TAsyncLoop = record` → `TAsyncLoop = class`，Create 改为 constructor |
| async.mutex.pas | `FLoop: PAsyncLoop` → `FLoop: TAsyncLoop`，移除 `@ALoop` |
| async.semaphore.pas | 同上 |
| async.channel.pas | 同上 |
| async.condvar.pas | 同上 |
| async.timeout.pas | 同上 |
| async.shutdown.pas | 同上 |
| async.taskgroup.pas | 同上 |
| async.retry.pas | 同上 |
| async.combinators.pas | 同上 |

### 关键设计决策

```pascal
// Before (record):
TAsyncLoop = record
  class function Create(AQueueDepth: UInt32 = 64): TAsyncLoop; static;
  procedure Close;
end;

// After (class):
TAsyncLoop = class
public
  constructor Create(AQueueDepth: UInt32 = 64);
  destructor Destroy; override;
end;
```

**注意**: 改为 class 后，`TAsyncLoop.Create` 语法不变（FPC class 构造器），但语义从值语义变为引用语义。所有 `var LLoop: TAsyncLoop` 自动变为引用。

**验证**: 全部 233 个测试通过

---

## M4: 类型安全 + 回调调度修复

### M4.1 类型安全 (F10/F19)

```
// Before:
procedure WhenAll(...; ALoop: Pointer);
procedure RetryWithBackoff(...; ALoop: Pointer);

// After:
procedure WhenAll(...; ALoop: TAsyncLoop);
procedure RetryWithBackoff(...; ALoop: TAsyncLoop);
```

### M4.2 TaskGroup 上下文丢失 (F6)

```
// Before:
FLoop^.Post(@WrappedTaskCallback, Pointer(ACallback));
// 回调中: LUserCallback := TAsyncCallback(AContext); LUserCallback(nil);
// 问题: 用户的 AContext 丢失

// After:
// 堆分配上下文记录
type
  PTaskItemCtx = ^TTaskItemCtx;
  TTaskItemCtx = record
    UserCallback: TAsyncCallback;
    UserContext: Pointer;
    Group: TAsyncTaskGroup;
  end;
// Post 时传入 PTaskItemCtx
// 回调中恢复完整上下文
```

### M4.3 WaitAll/OnShutdown 回调调度 (F7/F8)

```
// Before (直接调用，在调用者栈上):
if FActiveCount = 0 then begin
  platform_mutex_unlock(FLock);
  ACallback(AContext);  // ← 直接执行
  Exit;
end;

// After (通过 Post 调度):
if FActiveCount = 0 then begin
  platform_mutex_unlock(FLock);
  FLoop^.Post(ACallback, AContext);  // ← 通过事件循环调度
  Exit;
end;
```

**验证**: test_async / test_async_combinators / test_async_retry 通过

---

## M5: 代码去重

### M5.1 统一 TIoCompletion 定义 (F15)

**当前**: 6 个文件各自定义 `TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer)`
**方案**: 统一到 `nextpas.core.async.base`，其他文件删除本地定义

| 文件 | 操作 |
|------|------|
| async.base.pas | 保留定义（已有） |
| io.reactor.pas | 删除本地定义，uses async.base |
| io.reactor.epoll.pas | 删除本地定义，uses async.base |
| io.reactor.iocp.pas | 删除本地定义，uses async.base |
| io.reactor.kqueue.pas | 删除本地定义，uses async.base |
| io.poller.pas | 删除本地定义，uses async.base |

**注意**: io.reactor.* 和 io.poller 目前不依赖 async 模块。引入依赖后层级关系变化：io.poller → async.base。需要确认这不会造成循环依赖。

**备选方案**: 新建 `nextpas.core.io.completion.pas` 只定义 TIoCompletion，io 和 async 都依赖它。

### M5.2 提取 IoCompletionRefWrapper (F14)

**当前**: loop.pas 和 net.async.tcp.pas 各定义一份
**方案**: 提取到 `nextpas.core.async.util`（新建）或 `nextpas.core.async.base`

### M5.3 统一编译指令 (F22)

**当前**: 部分用 `{$I nextpas.core.settings.inc}`，部分用 `{$mode ObjFPC}{$H+}`
**方案**: 统一使用 `{$I nextpas.core.settings.inc}`

**验证**: 编译通过，测试通过

---

## M6: 功能缺陷收尾

### M6.1 信号集成事件循环 (F16)

**当前**: ProcessSignals 需要手动调用
**方案**: 在 CreateAsyncSignalHandler 时接受 TAsyncLoop 参数，自动将 signalfd 注册为 AsyncRead 源

### M6.2 BufferPool 线程安全说明 (F17)

**方案**: 在接口文档中明确标注"单线程设计"，或加 TPlatformMutex 保护

### M6.3 Retry AOnError 返回值 (F18)

**当前**: AOnError 回调修改外部布尔值 `LState.Failed`
**方案**: 改为 `TAsyncRetryErrorCheck = function: Boolean` 返回值模式

### M6.4 门面导出补全 (F20/F21)

**方案**: async.pas 补充 CreateAsyncMutex 等工厂函数 re-export；net.pas 补充 AsyncTcpListen/AsyncTcpConnect

---

## 执行顺序

```
M1 (全局状态) ──┐
M2 (RemainingMs) ──┤── 独立并行
M5 (代码去重) ──┘
                 ↓
           M3 (TAsyncLoop→class) ── 核心变更
                 ↓
           M4 (类型安全+回调) ── 依赖 M3
                 ↓
           M6 (功能收尾) ── 独立
```

**建议**: M1/M2/M5 先行（独立且风险低），M3 核心变更单独一个 commit，M4 依赖 M3，M6 最后收尾。

---

## 预期成果

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| 全局单例 | 3 个 | 0 个 |
| TIoCompletion 重复定义 | 6 处 | 1 处 |
| IoCompletionRefWrapper 重复 | 2 处 | 1 处 |
| Pointer 类型参数 | 4 处 | 0 处 |
| PAsyncLoop 悬空风险 | 10 文件 | 0 文件 |
| 可用性得分 | 6.1/10 | 8.0+/10 |
