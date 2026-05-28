# nextpas.core.simd API 文档

> **模块状态**: STABLE | 2025-12-27
>
> 本文档以代码为准；不包含“审计报告/测试计数”等不可自动验证的断言。
>
> 本文档描述的是 `nextpas.core.simd` / `nextpas.core.simd.api` / `nextpas.core.simd.runtime` 对外公开的分层 façade。像 `TSimdDispatchTable`、`TSimdBackendOps`、后端 `*_Scalar` / `*_AVX2` / `*_SSE2` 之类符号，属于实现细节或后端扩展接口，不是常规使用入口。
>
> 这里的“稳定”首先指公开 façade，与仓库内已声明稳定的 dispatch contract；并不表示每个 backend 都具有同样的成熟度或验证深度。特别是 `sbRISCVV` 仍应视为 experimental / 受限成熟度后端。

## 概述

`nextpas.core.simd` 是一个跨平台 SIMD 抽象层，支持多后端自动调度。

推荐按下面分层理解公开入口：

- `nextpas.core.simd`: 向量/数学 façade + 少量 canonical convenience wrapper（如 `GetCPUInfo`）
- `nextpas.core.simd.api`: mem/text/stat façade
- `nextpas.core.simd.runtime`: runtime/control-plane 视图与后端切换
- `nextpas.core.simd.cpuinfo`: CPU/OS capability 视图

如果你要先把 canonical API 与兼容别名区分清楚，先看 `docs/nextpas.core.simd.interface.md`。

如果你要看 Pascal 侧最小可运行的 v2 snapshot façade，用 `examples/example_simd_public_api_v2.pas`。

### 支持的后端

| 后端 | 平台 | 向量宽度 |
|------|------|----------|
| AVX-512 | x86-64 | 512-bit |
| AVX2 | x86-64 | 256-bit |
| SSE4.2 | x86-64 | 128-bit |
| SSE4.1 | x86-64 | 128-bit |
| SSSE3 | x86-64 | 128-bit |
| SSE3 | x86-64 | 128-bit |
| SSE2 | x86-64 | 128-bit |
| NEON | ARM64 | 128-bit |
| RISC-V V | RISC-V | 可变（experimental / 受限成熟度） |
| Scalar | 全平台 | N/A |

## 设计原则

### Stable / Experimental 口径

- **稳定面**：公开 façade、已声明稳定的 in-repo dispatch contract，以及默认入口链
- **实验面**：实验性 intrinsics 与受限成熟度 backend，不默认计入 stable surface
- **默认隔离**：experimental intrinsics 默认入口链已隔离；默认 façade 可见，不等于这些实验单元自动进入发布级保证


### 1. Rust 级别代码质量标准

本模块遵循以下质量标准：

- **输入语义清晰**: 对 `len=0` / `nil` 指针有明确约定（见下文），其余情况下调用方需保证指针与长度有效。
- **对齐安全**: `*Aligned` 系列会断言指针满足对齐要求。
- **线程安全**: Dispatch 初始化与后端切换使用原子状态与内存屏障。
- **浮点一致性**: 浮点向量运算以 Scalar 参考实现为语义基准（包含 NaN/Inf/-0.0 等边界）。

### 2. 命名规范

#### 公开 façade（推荐直接使用）

```pascal
// 公开 API 以语义和向量族命名为主
VecF32x4Add(a, b)
VecF32x4LoadAligned(p)
VecF32x4Store(p, v)
MemEqual(a, b, len)
Utf8Validate(p, len)
```

#### 后端实现 / 调试符号（通常不是常规入口）

```pascal
// 这类名称更偏实现细节、后端扩展或调试上下文
ScalarAddF32x4(a, b)
SSE2MulF32x4(a, b)
AVX2DivF32x8(a, b)
```

如果你只是正常使用模块，请优先查 `Vec*` / `Mask*` / `Mem*` / `Utf8*` / `Ascii*` 这些公开 façade，而不是从后端私有符号开始读。

## 安全要求

### 对齐要求

| 函数 | 对齐要求 | 失败行为 |
|------|----------|----------|
| `VecF32x4LoadAligned` | 16 字节 | Assert 失败 |
| `VecF32x4StoreAligned` | 16 字节 | Assert 失败 |
| `VecF32x4Load` | 无要求 | 正常工作 |
| `VecF32x4Store` | 无要求 | 正常工作 |

**示例**:
```pascal
var
  buf: array[0..7] of Single;
  aligned: PSingle;
  v: TVecF32x4;
begin
  // 获取 16 字节对齐地址
  aligned := PSingle((PtrUInt(@buf[0]) + 15) and not PtrUInt(15));

  // 安全: 使用对齐地址
  v := VecF32x4LoadAligned(aligned);

  // 安全: 非对齐加载无要求
  v := VecF32x4Load(@buf[1]);
end;
```

### 索引边界处理

采用**饱和策略**（Saturation Strategy）而非异常：

```pascal
// 索引 < 0 饱和到 0
VecF32x4Extract(v, -1)   // 返回 v.f[0]

// 索引 > 3 饱和到 3
VecF32x4Extract(v, 99)   // 返回 v.f[3]

// 正常索引
VecF32x4Extract(v, 2)    // 返回 v.f[2]
```

**设计理由**: 性能优先，避免异常开销。

### 空指针处理

| 函数 | nil 指针行为 |
|------|-------------|
| `Utf8Validate(nil, n)` | 返回 `False` |
| `MemEqual(nil, nil, n)` | 返回 `True` |
| `MemEqual(nil, p, n)` | 返回 `False`（p<>nil） |
| `MemFindByte(nil, n, x)` | 返回 `-1` |
| `SumBytes(nil, n)` | 返回 `0` |

### 零长度处理

| 函数 | len=0 行为 |
|------|-----------|
| `MemEqual(a, b, 0)` | 返回 `True` |
| `Utf8Validate(p, 0)` | 返回 `True` |
| `MemFindByte(p, 0, x)` | 返回 `-1` |
| `SumBytes(p, 0)` | 返回 `0` |

## IEEE 754 浮点行为

### NaN 传播

```pascal
var a, b, r: TVecF32x4;
begin
  a.f[0] := NaN;
  b.f[0] := 1.0;

  r := VecF32x4Add(a, b);
  // r.f[0] = NaN  (NaN 传播)

  r := VecF32x4Mul(a, b);
  // r.f[0] = NaN
end;
```

### 无穷大处理

```pascal
// Inf + 1 = Inf
// -Inf + 1 = -Inf
// Inf - Inf = NaN
// 0 * Inf = NaN
// 1 / 0 = Inf
// 1 / -0 = -Inf
```

### Reduction 与特殊值

```pascal
// ReduceAdd([1, NaN, 3, 4]) = NaN
// ReduceMax([1, Inf, 3, 4]) = Inf
// ReduceMin([1, -Inf, 3, 4]) = -Inf
```

## 后端调度

### 自动选择

```pascal
uses
  nextpas.core.simd,
  nextpas.core.simd.runtime;

begin
  // 获取当前 runtime backend
  WriteLn(GetCurrentBackend);  // sbAVX2, sbSSE2, sbScalar 等
end;
```

### 四层状态语义

```pascal
// 1) supported_on_cpu: 只看 CPU/OS 能力
supported := GetSupportedBackendList;

// 2) registered: 只看当前二进制里有没有注册这个 backend
// 推荐来自 nextpas.core.simd.runtime
registered := GetRegisteredBackendList;
ok := IsBackendRegisteredInBinary(sbAVX2);

// 3) dispatchable: CPU 支持 + 已注册 + BackendInfo.Available=True
// 推荐来自 nextpas.core.simd.runtime
dispatchable := GetDispatchableBackendList;

// 4) active: 当前真正生效的 backend
// 推荐来自 nextpas.core.simd.runtime
snapshot := GetCurrentRuntimeSnapshot;
active := snapshot.CurrentBackend;
```

`GetSupportedBackendList`（来自 `cpuinfo`，`GetAvailableBackends` 为兼容别名）和 `GetDispatchableBackendList`（来自 `runtime`，`GetAvailableBackendList` 为兼容别名）不是同一语义：
- 前者是 `supported_on_cpu`
- 后者是 `dispatchable`

### 强制后端

```pascal
uses nextpas.core.simd;

// 强制使用特定后端（用于测试）
SetCurrentBackend(sbScalar);

// 恢复自动选择
ResetCurrentBackendSelection;
```

`nextpas.core.simd` 现在直接重导出了更清晰的 control-plane 入口：

- `GetCPUInfo`
- `GetCurrentRuntimeSnapshot`
- `TrySetCurrentBackend`
- `SetCurrentBackend`
- `ResetCurrentBackendSelection`

如果你想按层细分导入，仍然可以直接使用 `nextpas.core.simd.runtime`。兼容入口 `TryForceBackend` / `ForceBackend` / `ResetBackendSelection` 继续保留，但属于 legacy façade alias。

### 线程安全

对外语义上，dispatch 初始化是线程安全的；但**运行时切换后端**更适合发生在启动阶段、测试阶段，或者受控切换点，而不是高并发热路径中。调用方应把 `SetCurrentBackend` / `ResetCurrentBackendSelection` 视为“控制面操作”，不要把它们当作普通数据面 API 高频调用。

更具体地说：

- `GetCurrentBackend`
- `GetCurrentBackendInfo`
- `GetDispatchTable`
- `GetDispatchableBackendList`
- `GetBestDispatchableBackend`

这些 helper/getter 各自都会返回一份**已发布的单次 snapshot**。单个调用内部不应暴露 torn snapshot 或 half-rebuilt state。

但这不等于承诺“两个独立 helper 调用在并发 control-plane 写入下会自动原子配对”。如果别的线程正在同时执行：

- `RegisterBackend(...)`
- `SetCurrentBackend(...)`
- `ResetCurrentBackendSelection`
- `SetVectorAsmEnabled(...)`

那么分两次读出来的结果可能分别对应两个不同的已发布 snapshot。这是文档边界，不是默认 bug。

稳定态合同是：

- 控制面 API 返回后
- 且没有新的并发 control-plane mutation

此时 `GetCurrentBackend`、`GetCurrentBackendInfo.Backend` 与 `GetDispatchTable^.Backend` 应该收敛到同一个 active backend。

## 使用示例

### 基础向量运算

```pascal
uses nextpas.core.simd;

var
  a, b, c: TVecF32x4;
begin
  a := VecF32x4Splat(1.0);
  b := VecF32x4Splat(2.0);
  c := VecF32x4Add(a, b);

  WriteLn(VecF32x4Extract(c, 0));  // 输出: 3.0
end;
```

### 内存操作

```pascal
var
  buf1, buf2: array[0..1023] of Byte;
  idx: PtrInt;
begin
  // 内存比较
  if MemEqual(@buf1[0], @buf2[0], 1024) then
    WriteLn('相等');

  // 查找字节
  idx := MemFindByte(@buf1[0], 1024, $FF);

  // UTF-8 验证
  if Utf8Validate(@buf1[0], 1024) then
    WriteLn('有效 UTF-8');
end;
```

如果你是在做 external/public ABI 调用方，不要在循环里重复 `GetSimdPublicApi`；先取一次 table，再缓存后直调。详细约束见 `docs/nextpas.core.simd.publicabi.md`。

### 高级扩展：`TSimdBackendOps`

这一节面向后端接入或内部扩展，不是普通调用方入口。

```pascal
uses
  nextpas.core.simd.backend.iface,
  nextpas.core.simd.backend.adapter;

var
  ops: TSimdBackendOps;
  a, b, c: TVecF32x4;
begin
  FillScalarOps(ops);

  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 0.5; b.f[1] := 1.0; b.f[2] := 1.5; b.f[3] := 2.0;

  c := ops.ArithmeticF32x4.Add(a, b);
  // c = [1.5, 3.0, 4.5, 6.0]
end;
```

## AVX/SSE 状态管理

### vzeroupper 要求

使用 YMM 寄存器（256位 AVX）后必须调用 `vzeroupper`：

```pascal
// 正确示例
function MyAVX2Function: Integer;
var usedYMM: Boolean;
begin
  usedYMM := False;

  if dataLen >= 32 then
  begin
    usedYMM := True;
    asm
      vmovdqu ymm0, [rax]  // 使用 YMM
      // ...
    end;
  end;

  // 所有退出路径都要清理
  if usedYMM then
    asm vzeroupper end;

  Result := 0;
end;
```

## 测试

建议使用仓库内置脚本来构建/检查/运行 SIMD 测试（输出目录为 `tests/nextpas.core.simd/bin2/` 与 `tests/nextpas.core.simd/lib2/`）。

```bash
# 编译并检查：SIMD 单元不允许出现 Warning/Hint
bash tests/nextpas.core.simd/BuildOrTest.sh check

# 运行测试并检查 heaptrc 泄漏
bash tests/nextpas.core.simd/BuildOrTest.sh test

# Release 模式（可选）
bash tests/nextpas.core.simd/BuildOrTest.sh release

# 也可以运行仓库测试入口（限定此模块）
bash tests/run_all_tests.sh nextpas.core.simd
```
