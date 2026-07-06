# nextpas.core.system Thread Safety

本规范定义 system kernel 的线程安全保证、同步原语使用指南和并发编程最佳实践。

## 1. 线程安全原则

### 1.1 默认非线程安全

- 除非明确标注，所有类型和函数都不是线程安全的
- 多线程访问共享数据时，程序员必须自行同步

### 1.2 线程安全等级

| 等级 | 含义 | 使用场景 |
|------|------|---------|
| **线程安全** | 可以从任意线程调用 | TThread, TRTLCriticalSection |
| **线程无关** | 不访问共享状态 | 纯函数、局部变量 |
| **非线程安全** | 访问共享状态但不保护 | 全局变量、单例 |

### 1.3 线程安全标注

```pascal
{ 线程安全 }
procedure EnterCriticalSection(var ACriticalSection: TRTLCriticalSection);

{ 线程无关 }
function SwapEndian(AValue: LongInt): LongInt;

{ 非线程安全 }
var GlobalCounter: LongInt;  // 需要外部同步
```

## 2. 同步原语

### 2.1 TRTLCriticalSection

临界区是最基本的同步原语，用于保护共享数据。

```pascal
var
  LSection: TRTLCriticalSection;
  LCounter: LongInt = 0;

procedure IncrementCounter;
begin
  EnterCriticalSection(LSection);
  try
    Inc(LCounter);
  finally
    LeaveCriticalSection(LSection);
  end;
end;

begin
  InitCriticalSection(LSection);
  try
    // 多线程调用 IncrementCounter
  finally
    DoneCriticalSection(LSection);
  end;
end.
```

**API 参考**：

| 函数 | 语义 | 线程安全 |
|------|------|---------|
| `InitCriticalSection` | 初始化临界区 | 否（只能调用一次） |
| `DoneCriticalSection` | 销毁临界区 | 否（只能调用一次） |
| `EnterCriticalSection` | 进入临界区（阻塞） | 是 |
| `LeaveCriticalSection` | 离开临界区 | 是 |
| `TryEnterCriticalSection` | 尝试进入（非阻塞） | 是 |

**使用规则**：

1. 临界区必须在使用前初始化（`InitCriticalSection`）
2. 临界区必须在使用后销毁（`DoneCriticalSection`）
3. 进入和离开必须配对（`EnterCriticalSection` / `LeaveCriticalSection`）
4. 使用 `try...finally` 确保离开
5. 不要嵌套临界区（可能死锁）

### 2.2 原子操作

原子操作用于简单的数值操作，无需锁。

```pascal
var
  LCounter: LongInt = 0;

procedure IncrementInThread;
begin
  InterlockedIncrement(LCounter);
end;

procedure DecrementInThread;
begin
  InterlockedDecrement(LCounter);
end;
```

**API 参考**：

| 函数 | 语义 | 返回值 |
|------|------|--------|
| `InterlockedIncrement(var Target)` | 原子递增 | 递增后的值 |
| `InterlockedDecrement(var Target)` | 原子递减 | 递减后的值 |
| `InterlockedExchange(var Target, Source)` | 原子交换 | 旧值 |
| `InterlockedCompareExchange(var Target, Source, Comparand)` | 原子比较交换 | 旧值 |
| `InterlockedExchangeAdd(var Target, Source)` | 原子加法 | 旧值 |

**使用场景**：

1. 引用计数
2. 计数器
3. 标志位
4. 简单的状态机

**限制**：

1. 只支持 `LongInt` 类型
2. 只支持简单的算术和逻辑操作
3. 不支持复杂的原子事务

### 2.3 内存屏障

内存屏障用于控制内存操作的顺序。

```pascal
// 写入屏障：确保写入操作在屏障前完成
procedure WriteBarrier;

// 读取屏障：确保读取操作在屏障后开始
procedure ReadBarrier;

// 读写屏障：确保读写操作的顺序
procedure ReadWriteBarrier;

// 预取：提示 CPU 预取数据
procedure Prefetch(var AAddress);
```

**使用场景**：

1. 无锁数据结构
2. 生产者-消费者模式
3. 内存映射 I/O

## 3. 线程管理

### 3.1 TThread

TThread 是线程的高级抽象。

```pascal
type
  TMyThread = class(TThread)
  protected
    procedure Execute; override;
  end;

procedure TMyThread.Execute;
begin
  while not Terminated do
  begin
    // 执行工作
    Sleep(100);
  end;
end;

var
  LThread: TMyThread;
begin
  LThread := TMyThread.Create(False);  // 立即启动
  try
    // 主线程继续工作
    Sleep(1000);
    LThread.Terminate;
    LThread.WaitFor;
  finally
    LThread.Free;
  end;
end;
```

**API 参考**：

| 成员 | 语义 | 线程安全 |
|------|------|---------|
| `Create(ACreateSuspended)` | 创建线程 | 否 |
| `Destroy` | 销毁线程 | 否 |
| `Start` | 启动线程 | 否 |
| `Terminate` | 请求终止 | 是 |
| `WaitFor` | 等待完成 | 否 |
| `Execute` | 线程入口 | - |
| `DoTerminate` | 终止回调 | - |
| `ThreadID` | 线程 ID | 是 |
| `Handle` | 线程句柄 | 是 |
| `Terminated` | 终止标志 | 是 |
| `Suspended` | 挂起状态 | 否 |
| `FreeOnTerminate` | 自动释放 | 否 |
| `Finished` | 完成标志 | 是 |
| `OnTerminate` | 终止事件 | 否 |

### 3.2 BeginThread/EndThread

低级线程创建函数。

```pascal
function MyThreadFunc(AParam: Pointer): PtrInt;
begin
  // 线程工作
  Result := 0;
end;

var
  LThreadID: TThreadID;
begin
  BeginThread(@MyThreadFunc, nil, LThreadID);
  // ... 等待线程完成
  EndThread(0);
end;
```

**API 参考**：

| 函数 | 语义 | 线程安全 |
|------|------|---------|
| `BeginThread(ThreadFunc, Param, ThreadID)` | 创建线程 | 是 |
| `EndThread(ReturnValue)` | 终止当前线程 | 是 |

## 4. 线程局部存储

### 4.1 threadvar

`threadvar` 声明线程局部变量，每个线程有独立的副本。

```pascal
threadvar
  TLSCounter: LongInt;

procedure IncrementTLS;
begin
  Inc(TLSCounter);  // 每个线程独立计数
end;
```

**使用场景**：

1. 线程独立的缓冲区
2. 线程独立的错误状态
3. 线程独立的配置

**限制**：

1. 不能初始化（只能是零值或编译时常量）
2. 不能是托管类型（字符串、接口、动态数组）
3. 每个线程消耗独立内存

## 5. 线程安全类型

### 5.1 线程安全的类型

| 类型 | 线程安全 | 说明 |
|------|---------|------|
| `TThread` | 是 | 线程管理 |
| `TRTLCriticalSection` | 是 | 临界区 |
| `TThreadID` | 是 | 线程标识 |
| `TThreadFunc` | 是 | 线程函数类型 |

### 5.2 非线程安全的类型

| 类型 | 线程安全 | 说明 |
|------|---------|------|
| `TObject` | 否 | 需要外部同步 |
| `AnsiString` | 否 | 引用计数非原子 |
| `UnicodeString` | 否 | 引用计数非原子 |
| `IUnknown` | 否 | 引用计数非原子 |
| `TMemoryManager` | 否 | 需要外部同步 |

### 5.3 条件线程安全

| 类型 | 线程安全 | 条件 |
|------|---------|------|
| `TMemoryManager` | 是 | `NeedLock = True` |
| `Variant` | 否 | 需要外部同步 |

## 6. 线程安全编程指南

### 6.1 共享数据保护

**规则**：多线程访问共享数据时必须同步。

```pascal
// ❌ 错误：未保护的共享数据
var
  GCounter: LongInt = 0;

procedure Increment;
begin
  Inc(GCounter);  // 竞态条件
end;

// ✅ 正确：使用临界区保护
var
  GSection: TRTLCriticalSection;
  GCounter: LongInt = 0;

procedure Increment;
begin
  EnterCriticalSection(GSection);
  try
    Inc(GCounter);
  finally
    LeaveCriticalSection(GSection);
  end;
end;

// ✅ 正确：使用原子操作
var
  GCounter: LongInt = 0;

procedure Increment;
begin
  InterlockedIncrement(GCounter);
end;
```

### 6.2 对象生命周期

**规则**：不要在多个线程间共享对象，除非对象是线程安全的。

```pascal
// ❌ 错误：共享非线程安全对象
var
  GList: TList;

// 线程 A
GList.Add(Item1);

// 线程 B
GList.Add(Item2);  // 竞态条件

// ✅ 正确：使用同步保护
var
  GSection: TRTLCriticalSection;
  GList: TList;

// 线程 A
EnterCriticalSection(GSection);
try
  GList.Add(Item1);
finally
  LeaveCriticalSection(GSection);
end;

// ✅ 正确：使用线程安全容器
var
  GList: TThreadList;  // 线程安全的列表
```

### 6.3 接口引用计数

**规则**：接口引用计数操作不是原子的，需要外部同步。

```pascal
// ❌ 错误：多线程共享接口变量
var
  GIntf: IMyInterface;

// 线程 A
GIntf := TMyClass.Create;  // 竞态条件

// 线程 B
GIntf := nil;  // 竞态条件

// ✅ 正确：使用同步保护
var
  GSection: TRTLCriticalSection;
  GIntf: IMyInterface;

// 线程 A
EnterCriticalSection(GSection);
try
  GIntf := TMyClass.Create;
finally
  LeaveCriticalSection(GSection);
end;

// ✅ 正确：使用线程局部存储
threadvar
  TLSIntf: IMyInterface;
```

### 6.4 字符串操作

**规则**：字符串引用计数不是原子的，需要外部同步。

```pascal
// ❌ 错误：多线程共享字符串
var
  GStr: AnsiString;

// 线程 A
GStr := 'Hello';  // 竞态条件

// 线程 B
GStr := 'World';  // 竞态条件

// ✅ 正确：使用同步保护
var
  GSection: TRTLCriticalSection;
  GStr: AnsiString;

// 线程 A
EnterCriticalSection(GSection);
try
  GStr := 'Hello';
finally
  LeaveCriticalSection(GSection);
end;

// ✅ 正确：使用线程局部存储
threadvar
  TLSStr: AnsiString;
```

### 6.5 全局变量

**规则**：全局变量默认非线程安全，需要保护。

```pascal
// ❌ 错误：未保护的全局变量
var
  GConfig: TConfig;

// ✅ 正确：使用临界区保护
var
  GConfigSection: TRTLCriticalSection;
  GConfig: TConfig;

// ✅ 正确：使用线程局部存储
threadvar
  TLSConfig: TConfig;

// ✅ 正确：使用原子操作（简单类型）
var
  GInitialized: LongBool = False;

procedure InitOnce;
begin
  if InterlockedCompareExchange(GInitialized, True, False) = False then
  begin
    // 初始化（只执行一次）
  end;
end;
```

## 7. 死锁预防

### 7.1 死锁条件

死锁需要同时满足四个条件：
1. 互斥：资源不能共享
2. 持有并等待：持有资源的同时等待其他资源
3. 不可剥夺：资源不能被强制释放
4. 循环等待：存在等待环

### 7.2 预防策略

**策略 1：固定顺序获取锁**

```pascal
// ❌ 错误：不同顺序获取锁
// 线程 A
EnterCriticalSection(Lock1);
EnterCriticalSection(Lock2);

// 线程 B
EnterCriticalSection(Lock2);
EnterCriticalSection(Lock1);  // 死锁

// ✅ 正确：固定顺序
// 线程 A 和 B
EnterCriticalSection(Lock1);
EnterCriticalSection(Lock2);
```

**策略 2：使用 TryEnterCriticalSection**

```pascal
// 尝试获取锁，失败则释放已持有的锁
if TryEnterCriticalSection(Lock1) then
begin
  if TryEnterCriticalSection(Lock2) then
  begin
    // 使用资源
    LeaveCriticalSection(Lock2);
  end;
  LeaveCriticalSection(Lock1);
end;
```

**策略 3：使用超时**

```pascal
// 带超时的等待（如果支持）
if WaitForSingleObject(Lock, 1000) = WAIT_TIMEOUT then
begin
  // 超时处理
end;
```

### 7.3 常见死锁场景

1. **嵌套临界区**：在临界区内调用可能获取其他临界区的函数
2. **回调死锁**：在临界区内调用回调函数，回调函数又获取同一临界区
3. **析构死锁**：在临界区内释放对象，对象的析构函数又获取临界区

## 8. 性能考虑

### 8.1 锁粒度

**规则**：锁的粒度要适中，不要太粗也不要太细。

```pascal
// ❌ 太粗：整个操作都加锁
EnterCriticalSection(Lock);
try
  // 读取数据（不需要锁）
  // 修改数据（需要锁）
  // 写入数据（不需要锁）
finally
  LeaveCriticalSection(Lock);
end;

// ❌ 太细：每个操作都加锁
EnterCriticalSection(Lock);
try
  ReadData;
finally
  LeaveCriticalSection(Lock);
end;

EnterCriticalSection(Lock);
try
  ModifyData;
finally
  LeaveCriticalSection(Lock);
end;

EnterCriticalSection(Lock);
try
  WriteData;
finally
  LeaveCriticalSection(Lock);
end;

// ✅ 适中：只保护需要的部分
ReadData;  // 不需要锁
EnterCriticalSection(Lock);
try
  ModifyData;  // 需要锁
finally
  LeaveCriticalSection(Lock);
end;
WriteData;  // 不需要锁
```

### 8.2 原子操作 vs 临界区

**规则**：简单操作用原子操作，复杂操作用临界区。

```pascal
// ✅ 简单计数器用原子操作
InterlockedIncrement(Counter);

// ✅ 复杂操作用临界区
EnterCriticalSection(Lock);
try
  List.Add(Item);
  Counter := Counter + Value;
finally
  LeaveCriticalSection(Lock);
end;
```

### 8.3 读写锁

**规则**：读多写少的场景使用读写锁。

```pascal
// 如果有读写锁支持
EnterReadLock;
try
  // 读取数据（多个线程可以同时读）
finally
  LeaveReadLock;
end;

EnterWriteLock;
try
  // 修改数据（独占访问）
finally
  LeaveWriteLock;
end;
```

## 9. 线程安全测试

### 9.1 竞态条件检测

使用工具检测竞态条件：
- ThreadSanitizer (TSan)
- Helgrind
- DRD

### 9.2 压力测试

多线程压力测试：

```pascal
const
  THREAD_COUNT = 10;
  ITERATIONS = 10000;

procedure ThreadFunc(AParam: Pointer);
var
  I: LongInt;
begin
  for I := 0 to ITERATIONS - 1 do
  begin
    InterlockedIncrement(GlobalCounter);
  end;
end;

begin
  // 创建多个线程
  for I := 0 to THREAD_COUNT - 1 do
    BeginThread(@ThreadFunc, nil, ThreadIDs[I]);

  // 等待所有线程完成
  for I := 0 to THREAD_COUNT - 1 do
    WaitForThreadTerminate(ThreadIDs[I], 0);

  // 验证结果
  Assert(GlobalCounter = THREAD_COUNT * ITERATIONS);
end.
```

### 9.3 死锁检测

使用工具检测死锁：
- ThreadSanitizer (TSan)
- Helgrind
- 手动分析锁顺序

## 10. 最佳实践总结

### 10.1 同步选择

| 场景 | 推荐方式 |
|------|---------|
| 简单计数器 | `InterlockedIncrement/Decrement` |
| 复杂操作 | `TRTLCriticalSection` |
| 读多写少 | 读写锁（如果支持） |
| 一次性初始化 | `InterlockedCompareExchange` |
| 线程独立数据 | `threadvar` |

### 10.2 编码规范

1. 始终使用 `try...finally` 确保离开临界区
2. 不要在临界区内调用可能阻塞的函数
3. 不要在临界区内抛出异常
4. 使用固定顺序获取多个锁
5. 避免嵌套临界区

### 10.3 测试策略

1. 使用 ThreadSanitizer 检测竞态条件
2. 多线程压力测试
3. 死锁检测
4. 边界条件测试

## 11. 参考资料

| 文档 | 用途 |
|------|------|
| `abi-specification.md` | 线程类型 ABI 细节 |
| `api-reference.md` | 线程 API 清单 |
| `design-decisions.md` | DD-12 线程模型选择 |
| `error-handling.md` | 线程错误处理 |
