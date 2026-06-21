# nextpas.core.mem API 参考

## 接口

### IArena
线性分配器接口。

#### 方法

##### Alloc
```pascal
function Alloc(aSize: SizeUInt): Pointer;
```
分配 `aSize` 字节的内存。

**参数：**
- `aSize` - 要分配的字节数

**返回值：**
- 成功：分配的内存指针
- 失败：nil（空间不足）

**示例：**
```pascal
var
  LArena: IArena;
  LP: Pointer;
begin
  LArena := TLocalArena.Create(1024);
  LP := LArena.Alloc(64);
  if LP <> nil then
    WriteLn('分配成功');
end;
```

##### AllocAligned
```pascal
function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
```
分配 `aSize` 字节的内存，按 `aAlignment` 对齐。

**参数：**
- `aSize` - 要分配的字节数
- `aAlignment` - 对齐要求（必须是 2 的幂）

**返回值：**
- 成功：对齐的内存指针
- 失败：nil（空间不足或对齐无效）

**示例：**
```pascal
var
  LP: Pointer;
begin
  LP := LArena.AllocAligned(64, 16);
  if LP <> nil then
    WriteLn('对齐分配成功，地址：', PtrUInt(LP) mod 16 = 0);
end;
```

##### AllocZeroed
```pascal
function AllocZeroed(aSize: SizeUInt): Pointer;
```
分配 `aSize` 字节的内存并清零。

**参数：**
- `aSize` - 要分配的字节数

**返回值：**
- 成功：清零的内存指针
- 失败：nil（空间不足）

**示例：**
```pascal
var
  LP: PByte;
begin
  LP := LArena.AllocZeroed(64);
  if LP <> nil then
    WriteLn('第一个字节：', LP^); // 输出 0
end;
```

##### SaveMark
```pascal
function SaveMark: TArenaMarker;
```
保存当前分配位置的标记。

**返回值：**
- TArenaMarker 记录

**示例：**
```pascal
var
  LMark: TArenaMarker;
begin
  LMark := LArena.SaveMark;
  // 分配一些内存...
  LArena.RestoreToMark(LMark); // 恢复到标记位置
end;
```

##### RestoreToMark
```pascal
procedure RestoreToMark(aMark: TArenaMarker);
```
恢复到之前保存的标记位置。

**参数：**
- `aMark` - SaveMark 返回的标记

**示例：**
```pascal
begin
  LArena.RestoreToMark(LMark);
end;
```

##### Reset
```pascal
procedure Reset;
```
重置 Arena，所有已分配内存可重新使用。

**示例：**
```pascal
begin
  LArena.Reset;
  // 现在可以重新分配内存
end;
```

##### TotalSize
```pascal
function TotalSize: SizeUInt;
```
返回后备内存总字节数。

**返回值：**
- 总字节数

##### UsedSize
```pascal
function UsedSize: SizeUInt;
```
返回已分配字节数。

**返回值：**
- 已分配字节数

##### RemainingSize
```pascal
function RemainingSize: SizeUInt;
```
返回剩余可用字节数。

**返回值：**
- 剩余可用字节数

---

## 类型

### TLocalArena
基于 GetMem 的固定大小 Arena。

#### 构造函数
```pascal
constructor Create(const ACapacity: SizeUInt);
```
创建 Arena 并分配 `ACapacity` 字节的后备内存。

**参数：**
- `ACapacity` - Arena 容量（字节数）

**示例：**
```pascal
var
  LArena: TLocalArena;
begin
  LArena := TLocalArena.Create(1024);
  try
    // 使用 Arena...
  finally
    LArena.Free;
  end;
end;
```

#### 方法
- `Alloc` - 分配内存
- `AllocAligned` - 对齐分配
- `AllocZeroed` - 分配并清零
- `AllocFast` - 快速分配（无检查版本）
- `AllocAlignedFast` - 快速对齐分配（无检查版本）
- `Reset` - 重置 Arena
- `SaveMark` - 保存标记
- `RestoreToMark` - 恢复到标记
- `TotalSize` - 总大小
- `UsedSize` - 已使用大小
- `RemainingSize` - 剩余大小

---

### TFastArena
基于 mmap 的高性能 Arena，零虚分发。

#### 初始化
```pascal
procedure TArena_Init(var AArena: TArena; AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
```
初始化 TArena。

**参数：**
- `AArena` - 要初始化的 TArena 记录
- `AAlignment` - 对齐要求（默认 DEFAULT_ALIGNMENT）

**示例：**
```pascal
var
  LArena: TFastArena;
begin
  TFastArena_Init(LArena);
  try
    // 使用 Arena...
  finally
    TFastArena_Release(LArena);
  end;
end;
```

#### 释放
```pascal
procedure TArena_Release(var AArena: TArena);
```
释放 TArena 所有资源。

**参数：**
- `AArena` - 要释放的 TArena 记录

#### 方法
- `Alloc` - 分配内存
- `AllocAligned` - 对齐分配
- `AllocZeroed` - 分配并清零
- `SaveMark` - 保存标记
- `RestoreToMark` - 恢复到标记
- `Reset` - 重置 Arena（保留 mmap 映射）
- `Release` - 释放所有 mmap 映射
- `TotalAllocated` - 总 mmap 分配字节数
- `TotalUsed` - 实际使用字节数
- `PeakUsed` - 峰值使用字节数
- `AllocCount` - 分配次数

---

### TGrowableArena
可增长的 Arena，支持段增长。

#### 构造函数
```pascal
constructor Create(const AConfig: TGrowableArenaConfig);
```
创建可增长 Arena。

**参数：**
- `AConfig` - 配置记录

**示例：**
```pascal
var
  LConfig: TGrowableArenaConfig;
  LArena: TGrowableArena;
begin
  LConfig := TGrowableArenaConfig.Default(4096);
  LConfig.GrowthKind := agkGeometric;
  LConfig.GrowthFactor := 2.0;
  LArena := TGrowableArena.Create(LConfig);
  try
    // 使用 Arena...
  finally
    LArena.Free;
  end;
end;
```

#### 配置
```pascal
TGrowableArenaConfig = record
  InitialSize: SizeUInt;
  MaxSize: SizeUInt;
  GrowthKind: TArenaGrowthKind;
  GrowthFactor: Double;
  GrowthStep: SizeUInt;
  Alignment: SizeUInt;
  Allocator: IAllocator;
  KeepSegments: Boolean;
end;
```

---

### TFastArenaAllocator
包装 TFastArena 为 IAllocator 接口。

#### 构造函数
```pascal
constructor Create(AChunkSize: SizeUInt = ARENA_INITIAL_CHUNK_SIZE;
  AAlignment: SizeUInt = DEFAULT_ALIGNMENT);
```
创建 TFastArenaAllocator。

**参数：**
- `AChunkSize` - 初始 chunk 大小
- `AAlignment` - 对齐要求

**示例：**
```pascal
var
  LAllocator: IAllocator;
begin
  LAllocator := TFastArenaAllocator.Create;
  // 使用 LAllocator...
end;
```

#### 方法
- `GetMem` - 分配内存
- `AllocMem` - 分配并清零
- `ReallocMem` - 重新分配
- `FreeMem` - 释放内存（no-op）
- `Reset` - 重置 Arena
- `Traits` - 返回特性

---

### TTrackingAllocator
内存泄漏检测包装器。

#### 构造函数
```pascal
constructor Create(const AInner: IAllocator);
```
创建 TTrackingAllocator。

**参数：**
- `AInner` - 内部分配器

**示例：**
```pascal
var
  LAllocator: IAllocator;
  LTracker: TTrackingAllocator;
begin
  LAllocator := TFastArenaAllocator.Create;
  LTracker := TTrackingAllocator.Create(LAllocator);
  try
    // 使用 LTracker...
  finally
    LTracker.Free;
  end;
end;
```

#### 方法
- `GetMem` - 分配内存并记录
- `AllocMem` - 分配并清零并记录
- `ReallocMem` - 重新分配并记录
- `FreeMem` - 释放内存并记录
- `ActiveAllocCount` - 当前活跃分配数
- `ActiveAllocBytes` - 当前活跃分配字节数
- `HasLeaks` - 是否有泄漏
- `ReportLeaks` - 生成泄漏报告

---

### TLeakCheckResult
泄漏检测结果。

#### 字段
- `LeakCount` - 泄漏数量
- `LeakBytes` - 泄漏字节数
- `MaxLeakSize` - 最大泄漏大小
- `LeakDetails` - 泄漏详情

---

### RunTestWithLeakCheck
运行测试并检查泄漏。

#### 函数签名
```pascal
function RunTestWithLeakCheck(const ATest: TAllocatorTestProc): TLeakCheckResult;
```

**参数：**
- `ATest` - 测试过程

**返回值：**
- TLeakCheckResult 记录

**示例：**
```pascal
var
  LResult: TLeakCheckResult;
begin
  LResult := RunTestWithLeakCheck(procedure(AAllocator: IAllocator)
  begin
    // 测试代码...
  end);
  if LResult.LeakCount > 0 then
    WriteLn('Memory leaks detected!');
end;
```

---

## 常量

### ARENA_INITIAL_CHUNK_SIZE
```pascal
ARENA_INITIAL_CHUNK_SIZE = 64 * 1024; // 64KB
```
初始 chunk 大小。

### ARENA_LARGE_THRESHOLD
```pascal
ARENA_LARGE_THRESHOLD = 64 * 1024; // 64KB
```
大对象阈值：>= 此值的对象直接 mmap。

### DEFAULT_ALIGNMENT
```pascal
DEFAULT_ALIGNMENT = 16;
```
默认对齐要求。
