# nextpas.core.simd 技术架构分析

> 这份文档描述的是**当前实现导向的架构视图**。
>
> 其中少量代码块是概念示意，不保证逐字可编译；遇到 API 名称、类型布局、后端接线细节时，以 `src/nextpas.core.simd.pas`、`src/nextpas.core.simd.base.pas`、`src/nextpas.core.simd.dispatch.pas` 为准。
>
> 如果你要裁决“为什么不是 façade 直接引用 intrinsics”“`dispatch + dataplane` 这条 seam 在哪里”“`public ABI wrapper` / `direct dispatch companion` 在哪里”“backend adapter 与 raw leaf 怎么分账”，以 `docs/SIMD_LAYERING_IMPLEMENTATION.md` 为准；这页只保留高层大图景。

## 🏗️ 架构设计原则

### 1. 分层抽象 (Layered Abstraction)
```
┌─────────────────────────────────────────┐
│           用户应用层                      │
├─────────────────────────────────────────┤
│  public / control surface               │  ← simd / api / runtime / cpuinfo
├─────────────────────────────────────────┤
│  companion surfaces                     │  ← public ABI wrapper / direct
├─────────────────────────────────────────┤
│  control / publication seam             │  ← dispatch / dataplane
├─────────────────────────────────────────┤
│  backend adapter                        │  ← scalar / sse2 / avx2 / neon
├─────────────────────────────────────────┤
│  raw leaf + infra                       │  ← intrinsics / base / memutils
└─────────────────────────────────────────┘
```

补充说明：

- `public ABI wrapper` 物理上在 `simd.pas` 的 `public_abi` include 中，但逻辑上是独立的外部稳定包装面。
- `direct` 是 direct dataplane companion，不是新的 control-plane 真相源。
- `dataplane` 是 façade fast-path / public ABI / direct 共用的 published binding seam，不应继续被当成隐藏 helper。
- 这张图是高层视角；`experimental isolated` / `active leaf` 之类实施准入规则，统一看 `docs/SIMD_LAYERING_IMPLEMENTATION.md`。

### 2. 零开销抽象 (Zero-Cost Abstraction)
- **编译时优化**: 内联函数 + 常量折叠
- **运行时派发**: 函数指针表，避免条件分支
- **类型擦除**: 编译后无额外运行时开销

### 3. 类型安全 (Type Safety)
- **强类型向量**: 防止不同长度向量混用
- **位掩码系统**: 与硬件 SIMD 掩码完美对齐
- **编译时检查**: 最大化编译期错误检测

## 🔧 核心组件架构

### 类型系统设计
```pascal
// 向量类型层次（示意；真实定义见 nextpas.core.simd.base）
TVecF32x4 = record
  case Integer of
    0: (f: array[0..3] of Single);
    1: (raw: array[0..15] of Byte);
end;

TVecF32x8 = record
  case Integer of
    0: (f: array[0..7] of Single);
    1: (raw: array[0..31] of Byte);
end;

TVecF64x2 = record
  case Integer of
    0: (d: array[0..1] of Double);
    1: (raw: array[0..15] of Byte);
end;

TVecI32x4 = record
  case Integer of
    0: (i: array[0..3] of Int32);
    1: (raw: array[0..15] of Byte);
end;

// 掩码类型层次
TMask4  = type Byte;   // 4位掩码  (F32x4, I32x4)
TMask8  = type Byte;   // 8位掩码  (F32x8, I16x8)
TMask16 = type Word;   // 16位掩码 (I8x16)
```

### 派发机制架构
```pascal
// 函数指针表结构
type TSimdDispatchTable = record
  // 后端信息
  Backend: TSimdBackend;
  BackendInfo: TSimdBackendInfo;

  // 函数指针 (零开销派发)
  AddF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  MulF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  // ... 更多操作
end;

// 全局派发表 (运行时初始化一次)
var g_CurrentDispatch: PSimdDispatchTable;

// 高级 API (内联到函数指针调用)
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := g_CurrentDispatch^.AddF32x4(a, b);
end;
```

### 后端注册机制

当前实现中，大多数后端注册代码已经从主单元抽到 `*.register.inc`，主文件保留接入点，便于控制单文件体积并减少 review 噪音。`SSE2` 是刻意保留在主单元内的例外，因为继续物理拆分它的风险已经高于收益。

```pascal
// 后端自注册模式
procedure RegisterSSE2Backend;
var dispatchTable: TSimdDispatchTable;
begin
  // 填充函数指针
  dispatchTable.AddF32x4 := @SSE2_AddF32x4;
  dispatchTable.MulF32x4 := @SSE2_MulF32x4;
  // ...

  // 注册到全局系统
  RegisterBackend(sbSSE2, dispatchTable);
end;

// 单元初始化时自动注册（多数 backend 位于 `*.register.inc`；SSE2 当前保留在主单元）
initialization
  RegisterSSE2Backend;
```

## 🚀 性能优化策略

### 1. 编译时优化
```pascal
{$INLINE ON}                    // 启用内联
{$OPTIMIZATION LEVEL3}          // 最高优化级别
{$CODEALIGN VARMIN=16}         // 变量对齐
{$RANGECHECKS OFF}             // Release 模式关闭边界检查
```

### 2. 内存对齐策略
```pascal
// 自动对齐分配
function AlignedAlloc(size: NativeUInt; alignment: NativeUInt = 32): Pointer;

// RAII 对齐数组
type TAlignedArray<T> = record
  class function Create(count: NativeUInt; alignment: NativeUInt = 32): TAlignedArray<T>;
  procedure Free;
end;

// 对齐检查 (Debug 模式)
{$IFDEF SIMD_DEBUG_ASSERTIONS}
Assert(IsAligned(ptr, 16), 'Vector data must be 16-byte aligned');
{$ENDIF}
```

### 3. 缓存友好设计
```pascal
// 预取指令包装
procedure Prefetch(ptr: Pointer); inline;
procedure PrefetchNTA(ptr: Pointer); inline;  // 非时间局部性

// 批量操作优化
procedure VecF32x4AddArray(src1, src2, dst: PSingle; count: NativeUInt);
// 内部使用循环展开 + 预取优化
```

## 🔍 后端实现策略

### SSE2 后端架构
```pascal
{$IFDEF SIMD_BACKEND_SSE2}
unit nextpas.core.simd.sse2;

// 内联汇编实现
function SSE2_AddF32x4(const a, b: TVecF32x4): TVecF32x4; inline;
asm
  {$IFDEF CPUX86_64}
  movups xmm0, [a]      // 非对齐加载
  movups xmm1, [b]
  addps  xmm0, xmm1     // 并行加法
  movups [Result], xmm0
  {$ELSE}
  // 32位回退或不同实现
  {$ENDIF}
end;

// 对齐版本 (更高性能)
function SSE2_AddF32x4Aligned(const a, b: TVecF32x4): TVecF32x4; inline;
asm
  movaps xmm0, [a]      // 对齐加载 (更快)
  movaps xmm1, [b]
  addps  xmm0, xmm1
  movaps [Result], xmm0
end;
{$ENDIF}
```

### AVX2 后端架构
```pascal
{$IFDEF SIMD_BACKEND_AVX2}
unit nextpas.core.simd.avx2;

// 256位向量支持
function AVX2_AddF32x8(const a, b: TVecF32x8): TVecF32x8; inline;
asm
  vmovups ymm0, [a]     // 256位加载
  vmovups ymm1, [b]
  vaddps  ymm0, ymm0, ymm1  // AVX 三操作数语法
  vmovups [Result], ymm0
  vzeroupper            // 清理上半部分 (避免性能损失)
end;

// FMA 支持
function AVX2_FMAF32x8(const a, b, c: TVecF32x8): TVecF32x8; inline;
asm
  vmovups ymm0, [a]
  vmovups ymm1, [b]
  vmovups ymm2, [c]
  vfmadd213ps ymm0, ymm1, ymm2  // a * b + c
  vmovups [Result], ymm0
  vzeroupper
end;
{$ENDIF}
```

### ARM NEON 后端架构
```pascal
{$IFDEF SIMD_BACKEND_NEON}
unit nextpas.core.simd.neon;

// NEON 内联汇编
function NEON_AddF32x4(const a, b: TVecF32x4): TVecF32x4; inline;
asm
  {$IFDEF CPUAARCH64}
  ldr q0, [a]           // 加载 128位向量
  ldr q1, [b]
  fadd v0.4s, v0.4s, v1.4s  // 4个单精度浮点加法
  str q0, [Result]
  {$ENDIF}
end;
{$ENDIF}
```

## 🧪 测试架构设计

### 分层测试策略
```pascal
// 1. 单元测试 (正确性)
type TSimdCorrectnessTests = class(TTestCase)
  procedure TestAllOperationsConsistency;  // 标量 vs SIMD 对比
  procedure TestBoundaryConditions;        // 边界值测试
  procedure TestSpecialValues;             // NaN, Inf, 零值
end;

// 2. 性能测试 (基准)
type TSimdPerformanceTests = class(TTestCase)
  procedure BenchmarkArithmeticOps;        // 算术运算性能
  procedure BenchmarkMemoryOps;            // 内存操作性能
  procedure BenchmarkRealWorldScenarios;   // 真实场景测试
end;

// 3. 随机化测试 (鲁棒性)
procedure RandomizedTest(iterations: Integer = 10000);
var
  a, b: TVecF32x4;
  scalarResult, simdResult: TVecF32x4;
begin
  for i := 1 to iterations do
  begin
    // 生成随机输入
    GenerateRandomVector(a);
    GenerateRandomVector(b);

    // 对比结果
    scalarResult := ScalarAdd(a, b);
    simdResult := VecF32x4Add(a, b);

    // 验证一致性 (考虑浮点误差)
    AssertVectorEqual(scalarResult, simdResult, 1e-6);
  end;
end;
```

## 📊 性能分析框架

### 微基准测试
```pascal
type TSimdBenchmark = record
  class function MeasureOperation(
    const name: string;
    op: TSimdOperation;
    iterations: Integer = 1000000
  ): TBenchmarkResult; static;
end;

// 使用示例
var result: TBenchmarkResult;
begin
  result := TSimdBenchmark.MeasureOperation('VecF32x4Add',
    function(const a, b: TVecF32x4): TVecF32x4
    begin
      Result := VecF32x4Add(a, b);
    end);

  WriteLn(Format('Throughput: %.2f GOps/sec', [result.ThroughputGOps]));
  WriteLn(Format('Latency: %.2f ns', [result.LatencyNs]));
end;
```

### 性能回归检测
```pascal
// 自动性能回归检测
procedure CheckPerformanceRegression;
const
  EXPECTED_SPEEDUP = 2.0;  // 期望的最小加速比
var
  scalarTime, simdTime: Double;
  speedup: Double;
begin
  scalarTime := BenchmarkScalar;
  simdTime := BenchmarkSIMD;
  speedup := scalarTime / simdTime;

  if speedup < EXPECTED_SPEEDUP then
    raise Exception.CreateFmt('Performance regression detected: %.2fx < %.2fx',
                             [speedup, EXPECTED_SPEEDUP]);
end;
```

## 🔮 未来扩展架构

> 注意：以下为概念性设计，当前未实现。实际后端注册使用 `RegisterBackend` + `TSimdDispatchTable` 模式。

### 可插拔后端系统
```pascal
// 后端接口标准化
type ISimdBackend = interface
  function GetBackendInfo: TSimdBackendInfo;
  function IsAvailable: Boolean;
  procedure RegisterOperations(var dispatchTable: TSimdDispatchTable);
end;

// 动态后端加载
procedure LoadBackendPlugin(const filename: string);
var
  backend: ISimdBackend;
begin
  backend := LoadLibrary(filename) as ISimdBackend;
  if backend.IsAvailable then
    backend.RegisterOperations(g_DispatchTable);
end;
```

### 自适应优化
```pascal
// 运行时性能监控
type TPerformanceMonitor = class
  procedure RecordOperation(op: TSimdOperation; duration: Double);
  function ShouldSwitchBackend: Boolean;
  function GetOptimalBackend: TSimdBackend;
end;

// 自适应后端切换
if g_PerfMonitor.ShouldSwitchBackend then
  SetActiveBackend(g_PerfMonitor.GetOptimalBackend);
```

这个架构设计确保了 nextpas.core.simd 具有**高性能、高可扩展性、高可维护性**的特点，为构建世界级的 SIMD 框架奠定了坚实的技术基础。
