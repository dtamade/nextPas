# nextpas.core.simd 分派器层详解

> 最后更新: 2026-07-06

## 概述

分派器层是 SIMD 模块的控制面，负责后端注册、优先级排序和运行时选择。它采用控制面/数据面分离设计，热路径通过 atomic_load 访问不可变快照。

## 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│  门面 (simd.pas)                                            │
│  VecF32x4Add(a, b) → 分派器调用                             │
├─────────────────────────────────────────────────────────────┤
│  数据面 (dataplane.pas)                                     │
│  不可变快照指针, atomic_load, 无锁                           │
├─────────────────────────────────────────────────────────────┤
│  控制面 (dispatch.pas)                                      │
│  后端注册, 优先级排序, 强制选择, 锁保护                      │
├─────────────────────────────────────────────────────────────┤
│  Backend Adapters                                            │
│  SSE2, AVX2, AVX-512, NEON, Scalar                          │
└─────────────────────────────────────────────────────────────┘
```

## 控制面 (dispatch.pas)

### 职责

1. **后端注册**: 每个 Backend Adapter 注册到分派器
2. **优先级排序**: 根据 CPU 能力排序后端
3. **强制选择**: 支持环境变量/宏强制选择后端
4. **锁保护**: 控制面变更需要锁保护

### 核心数据结构

```pascal
type
  TSimdDispatchTable = record
    Backend: TSimdBackend;
    BackendInfo: TSimdBackendInfo;
    
    // 函数指针 (616 个槽位)
    AddF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    SubF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    MulF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    DivF32x4: function(const a, b: TVecF32x4): TVecF32x4;
    // ... 更多操作
  end;
```

### 后端注册

```pascal
procedure RegisterSSE2Backend;
var
  dispatchTable: TSimdDispatchTable;
begin
  // 填充标量基线
  FillBaseDispatchTable(dispatchTable);
  
  // 设置后端信息
  dispatchTable.Backend := sbSSE2;
  dispatchTable.BackendInfo.Name := 'SSE2';
  dispatchTable.BackendInfo.Priority := GetSimdBackendPriorityValue(sbSSE2);
  
  // 覆盖 SSE2 操作
  dispatchTable.AddF32x4 := @SSE2AddF32x4;
  dispatchTable.SubF32x4 := @SSE2SubF32x4;
  // ... 更多操作
  
  // 注册
  RegisterBackend(sbSSE2, dispatchTable);
end;
```

## 数据面 (dataplane.pas)

### 职责

1. **不可变快照**: 维护当前后端的函数指针表快照
2. **atomic_load**: 热路径通过 atomic_load 访问
3. **无锁**: 数据面变更不需要锁

### 核心数据结构

```pascal
type
  TSimdDataPlane = record
    // 快照指针
    DispatchTable: PSimdDispatchTable;
    
    // 快速路径函数指针
    AddF32x4Ptr: Pointer;
    SubF32x4Ptr: Pointer;
    MulF32x4Ptr: Pointer;
    // ... 更多操作
  end;
```

### 热路径访问

```pascal
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
var
  LFunc: TVecF32x4AddFunc;
begin
  // atomic_load 获取函数指针
  LFunc := TVecF32x4AddFunc(LoadSimdFacadeFastPath(g_FastVecF32x4AddPtr));
  
  // 如果未绑定，重新绑定
  if not Assigned(LFunc) then
  begin
    RebindSimdFacadeFastPaths;
    LFunc := TVecF32x4AddFunc(LoadSimdFacadeFastPath(g_FastVecF32x4AddPtr));
  end;
  
  // 调用
  if Assigned(LFunc) then
    Result := LFunc(a, b)
  else
    Result := GetSimdFacadeDispatchFastPath^.AddF32x4(a, b);
end;
```

## 性能特征

### 当前性能

| 操作 | 开销 |
|------|------|
| atomic_load | ~5 cycles |
| 函数指针调用 | ~10-15 cycles |
| **总计** | **~15-20 cycles** |

### 为什么有开销

1. **FPC 编译器限制**: 无法内联函数指针调用
2. **atomic_load**: 需要内存屏障
3. **间接调用**: 需要跳转到函数地址

### 优化方向

#### 1. 编译期快速路径

```pascal
{$IFDEF HAS_AVX2}
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := AVX2AddF32x4(a, b);  // 直接调用，无分派器开销
end;
{$ELSE}
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  // 分派器调用
end;
{$ENDIF}
```

#### 2. nextpas 编译器优化

- **内联函数指针**: 编译器可以内联函数指针调用
- **去虚拟化**: 编译器可以识别常量函数指针
- **编译期特化**: 编译器可以为特定后端生成代码

#### 3. 批量操作摊薄

```pascal
procedure BatchAddF32x4(const A, B: array of TVecF32x4; 
                        var C: array of TVecF32x4);
var
  I: SizeInt;
begin
  // 一次分派，多次调用
  for I := 0 to High(A) do
    C[I] := VecF32x4Add(A[I], B[I]);
end;
```

## 设计决策

### 为什么选择运行时分派

1. **兼容性**: 支持动态后端切换
2. **灵活性**: 支持环境变量/宏强制选择
3. **可扩展性**: 支持新后端热插拔

### 为什么不选择编译期分派

1. **FPC 限制**: 不支持 `target_feature` 属性
2. **二进制兼容**: 同一二进制需要在不同 CPU 上运行
3. **维护成本**: 需要为每个平台编译不同二进制

### Highway 的双模式

Google Highway 提供编译期 + 运行时双模式：
- **静态调度**: `HWY_STATIC_DISPATCH(func)(args)`
- **动态调度**: `HWY_DYNAMIC_DISPATCH(func)(args)`

nextpas.core.simd 当前只有动态调度，未来可以添加静态调度。

## 未来改进

### Phase 1: 编译期快速路径 (短期)

- 为 AVX2/AVX-512 提供编译期快速路径
- 通过 `{$IFDEF}` 条件编译
- 需要用户手动选择后端

### Phase 2: nextpas 编译器优化 (中期)

- 内联函数指针调用
- 去虚拟化
- 编译期特化

### Phase 3: 静态调度 (长期)

- 参考 Highway 的双模式设计
- 支持编译期确定后端
- 支持运行时动态切换

## 使用示例

### 查看当前后端

```pascal
uses nextpas.core.simd;

var
  Info: TSimdBackendInfo;
begin
  Info := GetCurrentBackendInfo;
  WriteLn('Current backend: ', Info.Name);
  WriteLn('Priority: ', Info.Priority);
end;
```

### 强制选择后端

```pascal
uses nextpas.core.simd;

begin
  // 强制使用 SSE2
  SetActiveBackend(sbSSE2);
  
  // 或者使用环境变量
  // NEXTPAS_SIMD_BACKEND=SSE2
end;
```

### 重置为自动选择

```pascal
uses nextpas.core.simd;

begin
  ResetToAutomaticBackend;
end;
```
