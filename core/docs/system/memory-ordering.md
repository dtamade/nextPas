# nextpas.core.system Memory Ordering Guarantees

本规范定义 system kernel 的内存排序保证、内存屏障语义和原子操作的内存顺序。

## 1. 内存模型概述

### 1.1 x86_64 内存模型

x86_64 使用**强内存模型**（TSO - Total Store Order）：

- **Load-Load**：后面的加载不会重排到前面的加载之前
- **Store-Store**：后面的存储不会重排到前面的存储之前
- **Load-Store**：后面的存储不会重排到前面的加载之前
- **Store-Load**：**可能重排**！前面的存储可能在后面的加载之后可见

### 1.2 ARM64 内存模型

ARM64 使用**弱内存模型**：

- 所有类型的重排都可能发生
- 需要显式内存屏障来保证顺序

### 1.3 对程序员的影响

- x86_64：大多数情况下不需要内存屏障
- ARM64：必须使用内存屏障来保证顺序
- 跨平台代码：应该使用内存屏障

## 2. 内存屏障

### 2.1 屏障类型

| 屏障 | 语义 | x86_64 实现 | ARM64 实现 |
|------|------|------------|-----------|
| `ReadBarrier` | 读屏障 | 无操作（编译器屏障） | `dmb ishld` |
| `WriteBarrier` | 写屏障 | 无操作（编译器屏障） | `dmb ish` |
| `ReadWriteBarrier` | 读写屏障 | `mfence` | `dmb ish` |

### 2.2 屏障语义

**ReadBarrier**：
- 保证屏障后的读取在屏障前的读取之后发生
- 保证屏障后的读取看到屏障前的读取的结果

```pascal
// 生产者-消费者模式
// 生产者
Data := 42;
WriteBarrier;        // 确保 Data 在 Flag 之前可见
Flag := True;

// 消费者
while not Flag do;    // 等待 Flag
ReadBarrier;          // 确保读取 Data 在读取 Flag 之后
Assert(Data = 42);    // 保证看到 42
```

**WriteBarrier**：
- 保证屏障前的写入在屏障后的写入之前完成
- 保证屏障前的写入在屏障后的写入之前可见

```pascal
// 初始化模式
Buffer[0] := 1;
Buffer[1] := 2;
Buffer[2] := 3;
WriteBarrier;          // 确保 Buffer 初始化在 Ready 之前完成
Ready := True;
```

**ReadWriteBarrier**：
- 结合读屏障和写屏障的语义
- 保证屏障前的操作在屏障后的操作之前完成

### 2.3 使用场景

| 场景 | 推荐屏障 |
|------|---------|
| 生产者-消费者（写端） | `WriteBarrier` |
| 生产者-消费者（读端） | `ReadBarrier` |
| 双向同步 | `ReadWriteBarrier` |
| 锁实现 | `ReadWriteBarrier` |

## 3. 原子操作内存顺序

### 3.1 内存顺序类型

| 顺序 | 语义 | 使用场景 |
|------|------|---------|
| Relaxed | 无顺序保证 | 计数器 |
| Acquire | 加载获取 | 锁获取 |
| Release | 存储释放 | 锁释放 |
| AcqRel | 获取+释放 | 读-修改-写 |
| SeqCst | 顺序一致性 | 默认 |

### 3.2 当前实现

nextPas 的原子操作目前使用**顺序一致性**（SeqCst）：

```pascal
function InterlockedIncrement(var ATarget: LongInt): LongInt;
begin
  // 使用 lock xadd（x86_64）或 ldaxr/stlxr（ARM64）
  // 保证顺序一致性
end;
```

### 3.3 未来优化

未来可能添加带内存顺序参数的原子操作：

```pascal
// 未来 API（可能）
function AtomicLoad(var Target: LongInt; Order: TMemoryOrder = moSeqCst): LongInt;
procedure AtomicStore(var Target: LongInt; Value: LongInt; Order: TMemoryOrder = moSeqCst);
function AtomicCAS(var Target: LongInt; Compare, Value: LongInt; Order: TMemoryOrder = moSeqCst): Boolean;
```

## 4. 编译器屏障

### 4.1 编译器重排

编译器可能重排代码以优化性能：

```pascal
// 源代码
A := 1;
B := 2;

// 编译器可能重排为
B := 2;
A := 1;
```

### 4.2 编译器屏障

内存屏障同时也是编译器屏障，阻止编译器重排：

```pascal
A := 1;
ReadWriteBarrier;  // 编译器屏障
B := 2;
// 编译器不会将 B := 2 重排到 ReadWriteBarrier 之前
```

### 4.3 volatile 语义

nextPas 没有 `volatile` 关键字。使用原子操作或内存屏障来保证可见性。

## 5. 常见模式

### 5.1 标志模式

```pascal
var
  Data: LongInt;
  Ready: Boolean = False;

// 生产者
procedure Producer;
begin
  Data := 42;
  WriteBarrier;        // 确保 Data 在 Ready 之前可见
  Ready := True;
end;

// 消费者
procedure Consumer;
begin
  while not Ready do;  // 等待 Ready
  ReadBarrier;         // 确保读取 Data 在读取 Ready 之后
  Assert(Data = 42);
end;
```

### 5.2 双重检查锁定

```pascal
var
  Instance: TObject = nil;
  Lock: TRTLCriticalSection;
  Initialized: Boolean = False;

function GetInstance: TObject;
begin
  if not Initialized then           // 第一次检查（无锁）
  begin
    EnterCriticalSection(Lock);
    try
      if not Initialized then       // 第二次检查（有锁）
      begin
        Instance := TMyClass.Create;
        ReadWriteBarrier;           // 确保 Instance 在 Initialized 之前可见
        Initialized := True;
      end;
    finally
      LeaveCriticalSection(Lock);
    end;
  end;
  Result := Instance;
end;
```

### 5.3 生产者-消费者队列

```pascal
var
  Buffer: array[0..99] of LongInt;
  Head: LongInt = 0;
  Tail: LongInt = 0;

procedure Produce(Value: LongInt);
begin
  Buffer[Head mod 100] := Value;
  WriteBarrier;                    // 确保 Buffer 写入在 Head 更新之前完成
  InterlockedIncrement(Head);
end;

function Consume: LongInt;
begin
  while Head = Tail do;            // 等待数据
  ReadBarrier;                     // 确保读取 Buffer 在读取 Head 之后
  Result := Buffer[Tail mod 100];
  InterlockedIncrement(Tail);
end;
```

### 5.4 无锁栈

```pascal
type
  PNode = ^TNode;
  TNode = record
    Value: LongInt;
    Next: PNode;
  end;

var
  Top: PNode = nil;

procedure Push(Value: LongInt);
var
  LNew, LOld: PNode;
begin
  New(LNew);
  LNew^.Value := Value;
  repeat
    LOld := Top;
    LNew^.Next := LOld;
  until InterlockedCompareExchange(Pointer(Top), Pointer(LNew), Pointer(LOld)) = Pointer(LOld);
end;

function Pop: LongInt;
var
  LOld, LNew: PNode;
begin
  repeat
    LOld := Top;
    if LOld = nil then
      Exit(-1);
    LNew := LOld^.Next;
  until InterlockedCompareExchange(Pointer(Top), Pointer(LNew), Pointer(LOld)) = Pointer(LOld);
  Result := LOld^.Value;
  Dispose(LOld);
end;
```

## 6. 平台差异

### 6.1 x86_64

- 强内存模型，大多数情况不需要屏障
- Store-Load 重排是唯一需要注意的
- `lock` 前缀提供完整的内存屏障

```pascal
// x86_64 上的 WriteBarrier 通常是无操作
procedure WriteBarrier;
begin
  // 编译器屏障（阻止编译器重排）
  // 硬件保证 Store-Store 顺序
end;
```

### 6.2 ARM64

- 弱内存模型，需要显式屏障
- 所有类型的重排都可能发生
- 使用 `dmb`（数据内存屏障）指令

```pascal
// ARM64 上的 WriteBarrier
procedure WriteBarrier;
begin
  // dmb ish  // 数据内存屏障，内部共享域
end;
```

### 6.3 跨平台建议

1. 始终使用内存屏障，不要依赖平台特定行为
2. 使用原子操作而不是普通读写
3. 测试在弱内存模型平台上的行为

## 7. 性能考虑

### 7.1 屏障开销

| 平台 | ReadBarrier | WriteBarrier | ReadWriteBarrier |
|------|-------------|--------------|------------------|
| x86_64 | ~0 ns | ~0 ns | ~20 ns |
| ARM64 | ~10 ns | ~10 ns | ~20 ns |

### 7.2 原子操作开销

| 操作 | x86_64 | ARM64 |
|------|--------|-------|
| `InterlockedIncrement` | ~5 ns | ~10 ns |
| `InterlockedCompareExchange` | ~10 ns | ~20 ns |

### 7.3 优化建议

1. 减少屏障使用次数
2. 使用原子操作代替锁
3. 批量操作后使用单个屏障

## 8. 常见错误

### 8.1 忘记屏障

```pascal
// ❌ 错误：忘记屏障
Data := 42;
Ready := True;  // 消费者可能看到 Ready=True 但 Data!=42

// ✅ 正确：使用屏障
Data := 42;
WriteBarrier;
Ready := True;
```

### 8.2 错误的屏障类型

```pascal
// ❌ 错误：使用读屏障保护写入
Data := 42;
ReadBarrier;  // 应该用 WriteBarrier
Ready := True;

// ✅ 正确
Data := 42;
WriteBarrier;
Ready := True;
```

### 8.3 依赖平台特定行为

```pascal
// ❌ 错误：假设 x86_64 的强内存模型
Data := 42;
Ready := True;  // 在 ARM64 上可能失败

// ✅ 正确：使用屏障
Data := 42;
WriteBarrier;
Ready := True;
```

## 9. 测试内存顺序

### 9.1 内存顺序测试

```pascal
procedure TestMemoryOrdering;
var
  Data: LongInt = 0;
  Ready: Boolean = False;
  I: LongInt;
begin
  // 多次测试以检测重排
  for I := 0 to 1000000 do
  begin
    Data := 0;
    Ready := False;

    // 生产者
    Data := 42;
    WriteBarrier;
    Ready := True;

    // 消费者
    if Ready then
    begin
      ReadBarrier;
      Assert(Data = 42);
    end;
  end;
end;
```

### 9.2 原子操作测试

```pascal
procedure TestAtomicOperations;
var
  Counter: LongInt = 0;
  I: LongInt;
begin
  // 多线程递增
  for I := 0 to 1000000 do
    InterlockedIncrement(Counter);

  Assert(Counter = 1000000);
end;
```

## 10. 参考资料

| 文档 | 用途 |
|------|------|
| `abi-specification.md` | 屏障函数签名 |
| `api-reference.md` | 屏障 API 清单 |
| `design-decisions.md` | DD-12 线程模型 |
| `thread-safety.md` | 同步原语使用 |
| `platform-differences.md` | 平台内存模型差异 |
