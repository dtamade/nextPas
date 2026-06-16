# nextpas.core.simd 模块文档

> 这页负责讲清模块全貌、阅读顺序和维护边界。
>
> 如果你只想查公开 API，请优先看 `docs/simd/api.md` 和 `docs/simd/interface.md`；如果你只想落地维护，请优先看 `docs/simd/map.md`、`docs/simd/maintenance.md` 和 `docs/simd/checklist.md`。

## 概述

`nextpas.core.simd` 是一个高性能、跨平台的 SIMD 优化模块，为 FreePascal 应用程序提供内存、文本、位集和搜索操作的硬件加速。

### 当前状态（2026-05-19）

- 模块状态应按 `code-green / cross-ready` 理解。
- 当前代码主线应按 `code-green` 理解：
  - Linux canonical `gate` 已为 PASS
  - `linux_qemu_cpuinfo_nonx86_evidence` 已 fresh PASS
- 当前 release closeout 也已完成：
  - full `freeze-status` 当前为 `ready=True / mainline-ready=True / cross-ready=True`
  - 最新 `windows_preflight_latest`、`windows_evidence_verify`、`windows_sources_not_newer_than_evidence` 都已 PASS
- 当前 public API proof 也已 fail-close：
  - canonical `public-api-coverage` 现在默认按 `strict-thin` 运行
  - future `thin > 0` 会直接让 `gate` / `gate-strict` 变红
- 因此，如果你这次只是从入口文档重新接手模块，不要先重开 SIMD 泛审查；先看 `docs/simd/checklist.md` 与 `docs/simd/closeout.md`，并把当前状态理解成 `code-green / cross-ready`

### 设计目标

- **性能优化**：在 FPC 缺少稳定 SIMD 内建支持的现实下，以“手写汇编微内核 + 运行时派发 + 标量回退”的方式，为常见热点提供可选加速
- **API 兼容性**：不改变调用方 API 语义；任何平台/构建环境下均可运行；有 SIMD 则自动用更快实现
- **跨平台支持**：支持 x86_64 (SSE2/AVX2/AVX-512) 和 AArch64 (NEON) 架构

### 设计原则

- **接口稳定、低耦合**：对外只暴露语义清晰的函数；不暴露 ISA 细节
- **运行时派发**：初始化时根据 CPU/OS 能力选择最优实现；支持环境/宏强制降级
- **平滑回退**：标量实现永远可用；汇编不可用/检测失败时自动回退
- **小而精**：优先覆盖高 ROI 原语（mem/text/bitset/search 的核心路径）
- **命名统一**：全部指令集名称使用全大写（SSE2/AVX2/NEON/AVX-512/SVE）

## 建议阅读顺序

- **模块入口**：`docs/simd/README.md`
- **公开 API 参考**：`docs/simd/api.md`
- **接口分层与 canonical/legacy 名称矩阵**：`docs/simd/interface.md`
- **public ABI wrapper**：`docs/simd/publicabi.md`
- **public ABI 稳定承诺**：`docs/simd/publicabi.stability.md`
- **阅读地图**：`docs/simd/map.md`
- **维护策略**：`docs/simd/maintenance.md`
- **极简行动清单**：`docs/simd/checklist.md`
- **本轮收尾与回归矩阵**：`docs/simd/closeout.md`
- **历史草案与分析快照**：统一看 `docs/legacy/simd/README.md`；如果你在顶层搜索结果里看到 `docs/SIMD_*.md` 或 `docs/NEON_*.md` 单页，占位文件只用于保路径，不是当前真相源

## 示例定位

- `examples/simd_ops_demo.lpr`：更贴近当前公开 API 的实际用法，适合作为教程入口
- `examples/example_simd_dispatch.pas`：概念演示（conceptual demo）；现在会显式区分 `CPU-supported` 与 `current runtime backend`，避免再把两层语义混写成同一个 “backend”

## Stable / Experimental 边界

这个模块有两个需要同时成立的判断：

- **公开 façade 是稳定面**：调用方正常接触到的 `nextpas.core.simd` / `nextpas.core.simd.api` 入口，仍然按 stable surface 理解
- **后端成熟度不是单一等级**：同一个 façade 背后可以连接不同成熟度的 backend；`sbRISCVV` 目前应继续按 experimental / 受限成熟度理解，而不是与 `SSE2` / `AVX2` / `NEON` 视为同等稳定级别
- **`sbRISCVV` 默认不进 umbrella**：当前只有在定义 `SIMD_EXPERIMENTAL_RISCVV` 时，`nextpas.core.simd` 才会接线 `nextpas.core.simd.riscvv`；默认 stable 入口链不会因为平台满足就自动带入实验后端
- **experimental intrinsics 默认不在稳定面内**：这些单元已有默认入口隔离检查，默认入口链只保证它们不会泄漏进常规 façade，而不意味着它们已经自动进入发布级保证范围

如果你在维护时需要一句最短判断，可以用这句：**stable 的是公开 façade 与仓库内 dispatch contract，不是“所有 backend 都已达到相同成熟度”，更不是“当前 record layout 已经是 public binary ABI”。**

## Backend 状态语义

当前建议把 backend 状态分成 4 层理解，不再用一个含糊的 “available” 混过去：

- `supported_on_cpu`：CPU/OS 语义上支持。推荐入口：`cpuinfo` 的 `GetSupportedBackendList` / `GetBestSupportedBackend`
- `registered`：当前二进制里已经注册。入口：`GetRegisteredBackendList` / `IsBackendRegisteredInBinary`
- `dispatchable`：CPU/OS 支持 + 已注册 + `BackendInfo.Available=True`。入口：`GetDispatchableBackendList`（`GetAvailableBackendList` 仅兼容保留）
- `active`：当前真正生效的 backend。入口：`GetCurrentRuntimeSnapshot` / `GetCurrentBackend` / `GetCurrentBackendInfo`

这四层里最容易混的是前两层与第三层：

- `cpuinfo` 的 `GetSupportedBackendList` 只说明 “这台机器支持”
- `GetAvailableBackends` / `GetBestBackendOnCPU` 继续保留，但仅作为兼容别名理解
- façade / runtime 的 `GetDispatchableBackendList` 才说明 “这份二进制现在真的可派发”
- façade 现在也直接提供 canonical convenience wrapper `GetCPUInfo`；legacy `GetCPUInformation` 仅为兼容保留
- active 文档、示例和新代码默认只写 canonical 名称；legacy 名称只保留在兼容映射里

## 架构设计

### 模块结构

```
src/
├── nextpas.core.simd.pas                 # 主用户入口；当前已拆出 types/framework 等 include
├── nextpas.core.simd.api.pas             # 门面函数 API：MemEqual/SumBytes/Utf8Validate 等
├── nextpas.core.simd.base.pas            # 类型定义：TVecF32x4/TMask4 等
├── nextpas.core.simd.dispatch.pas        # 运行时派发；当前已拆出 hook 管理 include
├── nextpas.core.simd.cpuinfo.pas         # CPU 能力检测；当前已拆出 backend 选择 include
├── nextpas.core.simd.memutils.pas        # 内存工具：对齐分配
├── nextpas.core.simd.scalar.pas          # 后端：标量回退实现
├── nextpas.core.simd.sse2.pas            # 后端：SSE2；当前保持相对稳态，不建议继续高风险细拆
├── nextpas.core.simd.avx2.pas            # 后端：AVX2；family / facade 已按 include 收口
├── nextpas.core.simd.avx512.pas          # 后端：AVX-512；512-bit family 已按 include 收口
├── nextpas.core.simd.neon.pas            # 后端：NEON；facade / fallback / family 已按 include 收口
└── nextpas.core.simd.*.inc               # 低风险物理拆分出的 types/framework/register/family/helper 区块
```

### 当前代码组织（2026-03）

当前代码已经从“少量超大单元”收口到“主单元 + include 片段”的结构：

- `nextpas.core.simd.pas` 负责对外 API，内部通过 `types` / `framework` include 保持主入口稳定。
- `dispatch` / `cpuinfo` 负责运行时选择与能力判定，当前把 hook、backend 选择等机制拆成独立 include。
- `AVX2` / `AVX-512` / `NEON` 的注册区、门面区和若干 family 区已拆出，便于审查与回归。
- 维护入口：结构收口与稳定边界说明见 `docs/simd/maintenance.md`。
- `SSE2` 仍然是重要但相对脆弱的基线后端；继续做细颗粒物理拆分的收益已经变小，风险开始上升。

### 支持的指令集

#### x86_64 架构
- **当前支持**：SSE2, AVX2, AVX-512F, POPCNT
- **规划支持**：AVX-512VL, AVX-512BW（部分子集）

#### AArch64 架构
- **当前支持**：NEON（支持原生 AArch64 汇编路径；不满足编译器/平台条件时自动回退到标量实现）
- **规划支持**：CRC32, AES, PMULL, SVE

### NEON default public status

NEON 的默认 public 状态是 default scalar fallback。AArch64 NEON asm opt-in 需要 FPC 3.3.1+，并且必须显式启用 `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM`、`NEXTPAS_SIMD_ENABLE_NEON_ASM`、`NEXTPAS_SIMD_NEON_ASM_COMPILER_READY`，同时不能定义 `SIMD_VECTOR_ASM_DISABLED`。因此，文档中的 NEON dispatch 覆盖率只说明当前派发表赋值口径，不等于默认构建已经启用 NEON inline asm。

NEON benchmark 还必须说明 AArch64 ABI GPR-to-vector 成本：部分 16-byte record 参数经 GPR 传入，asm 包装需要先组装到 vector register，返回时再拆回 GPR。只有当实测 workload 摊薄这段桥接成本时，才能宣称 NEON 路径比 scalar fallback 更快。

### 性能等级

| 等级 | x86_64 | AArch64 | 描述 |
|------|--------|---------|------|
| LEVEL_0 | SCALAR | SCALAR | 无 SIMD，纯标量实现 |
| LEVEL_1 | SSE2 | NEON | 基线 SIMD 支持 |
| LEVEL_2 | AVX2 | NEON+CRC/AES | 增强 SIMD 支持 |
| LEVEL_3 | AVX-512 | SVE/SVE2 | 高端 SIMD 支持 |

### 后端质量状态 (2026-03-11)

经过多轮质量迭代优化后的后端状态：

| 后端 | Dispatch 覆盖 | 当前状态 | 质量评级 |
|------|---------------|----------|----------|
| AVX-512 | 187 / 616 | 受构建与验证范围限制 | ⚠️ 受限 |
| AVX2 | 491 / 616 | 稳定主线 | ✅ 优秀 |
| NEON | 616 / 616 | 当前机器检查口径下已满覆盖 | ✅ 优秀 |
| SSE2 | 463 / 616 | 稳定主线 | ✅ 良好 |
| RISC-V V | 616 / 616 | 当前机器检查口径下已满覆盖，默认仍按 experimental 成熟度看待 | ⚠️ 受限成熟度 |

> 注：以上 `N/616` 中的 616 是 canonical dispatch_slots_total（`check_interface_implementation_completeness.py --strict` 输出）。`Backend/616` 表示该 backend 在全部 616 个槽位中赋值了 N 个。

以下是 IDE 兼容后端 backend 成熟度分类（基于 dispatch 覆盖和当前 evidence 状态）的快速对照表：

**说明**：
- 这里展示的是当前更有决策价值的 dispatch 覆盖与成熟度，不再使用早期的 ASM 块占比口径。
- `616 / 616` 表示在 `check_interface_implementation_completeness.py` 的当前机器检查口径下，该 backend 已为全部 dispatch 槽位提供赋值。
- `sbNEON` 的 `616 / 616` 不代表默认 public 构建启用 NEON asm；默认仍按 scalar fallback，除非满足上面的 asm opt-in 条件。
- `sbRISCVV` 虽然当前覆盖已补满，但默认成熟度仍受编译器/汇编链路限制约束，不能简单等同于 AVX2/NEON 主线成熟度。

### 性能基准 (4096 字节, 1M 次迭代)

| 函数 | Scalar | SSE2 | AVX2 | 加速比 |
|------|--------|------|------|--------|
| MemEqual | 3300ms | 743ms (4.4x) | 139ms | **23.7x** |
| MemFindByte | 161ms | 48ms (3.4x) | 12ms | **13.4x** |
| SumBytes | 1861ms | 757ms (2.5x) | 99ms | **18.8x** |
| CountByte | 3117ms | 708ms (4.4x) | 136ms | **22.9x** |
| MinMaxBytes | 4962ms | - | 121ms | **41.0x** |
| BitsetPopCount | 26591ms | - | 537ms | **49.5x** |
| Utf8Validate | 2936ms | - | 318ms | **9.2x** |
| AsciiIEqual | 5894ms | - | 247ms | **23.9x** |

**当前补充说明（2026-03-11）**：
- 当前稳定 benchmark 证据见 `tests/nextpas.core.simd/logs/backend-bench-20260311-103804/summary.md`。
- 这份 summary 通过 `run_backend_benchmarks.sh` 的 `AVX2_vs_Scalar` 稳定路径采集，x86_64 上直接复用 `nextpas.core.simd.test --bench-only --vector-asm`。
- 新补齐的宽整型路径已进入 benchmark 样本：`VecI16x32Add`、`VecU32x16Mul`、`VecU64x8Add`、`VecU8x64Max`。
- 默认 `--bench-only` 更接近“当前默认运行口径”；若要测 AVX2 向量路径，请使用 `--bench-only --vector-asm` 或 dedicated bench runner。
- 当前 `perf-smoke` 在 `x86_64/AMD64` 上默认已切到 `--bench-only --vector-asm` 口径。
- 最新 summary 里的关键行：
  - `VecU8x64Max`：`3.96x`；`VecU8x64MaxRaw`：`4.31x`
  - `VecI16x32Add`：`3.35x`；`VecI16x32AddRaw`：`3.07x`
  - `VecU32x16Mul`：`0.99x`；`VecU32x16MulRaw`：`1.00x`
  - `VecU64x8Add`：`0.76x`；`VecU64x8AddRaw`：`0.80x`
  - `VecF32x4Add`：`0.76x`；`VecF32x4AddRaw`：`0.89x`
- 当前性能结论：
  - `VecI16x32Add` 与 `VecU8x64Max` 已经证明有继续保留/复用 AVX2 fast-path 的价值。
  - `VecU32x16Mul` 在 façade fast-path 读序减负后已经回到接近持平；这类宽整型算子后续更适合“观察 + 只做低成本微调”，不再是优先事故。
  - `VecU64x8Add` 连 raw 口径都未超过 scalar，不适合继续作为高优先级优化目标。
  - `VecF32x4Add` 这类极小粒度算子仍不具备当前轮次的优化 ROI。

**当前推荐的后续动作排序（2026-03-11）**：
- 第一优先级：继续复用 `VecI16x32Add`、`VecU8x64Max` 这类已经证明 ROI 的 fast-path 模式
- 第二优先级：`VecU32x16Mul` 保持观察，只接受低成本微调
- 第三优先级：`VecU64x8Add`、`VecF32x4Add` 降级为观察项，不再占主线优化时间
- 第四优先级：把精力放回 stable boundary、evidence contract 与 closeout 文档一致性

### 质量迭代成果

**迭代概览**：

| 迭代 | 内容 | 目标后端 | 成果 |
|------|------|----------|------|
| Iteration 1 | NEON 256-bit 真正 SIMD 化 | NEON | 消除 Pascal for 循环 |
| Iteration 2 | NEON Scalar 回退批量替换 | NEON | +166 ASM 函数 (27% → 42.6%) |
| Iteration 4 | SSE2 窄整数/无符号/仿真 | SSE2 | +57 ASM 函数 (23% → 30.9%) |
| Iteration 5 | AVX-512 核心操作确认 | AVX-512 | 94 ASM 块，87.8% 覆盖率 |
| Iteration 6 | NEON 比较/MinMax, SSE2 舍入, FMA | NEON/SSE2 | 边界情况完善 |
| Iteration 7 | NEON 规约, SSE2 512-bit 直接实现 | NEON/SSE2 | 大向量操作优化 |

**质量提升统计**：

| 后端 | 迭代前 | 迭代后 | 提升 |
|------|--------|--------|------|
| NEON | 27% ASM | **42.6% ASM** | **+15.6%** |
| SSE2 | 23% ASM | **30.9% ASM** | **+7.9%** |
| AVX-512 | - | **87.8% ASM** | 已优秀 |
| AVX2 | - | **80.1% ASM** | 已优秀 |

**测试验证**：
- 测试数：575
- 通过率：100% ✅
- 内存泄漏：0 ✅
- IEEE 754 边界测试：通过 ✅

## 快速入门

### 基本用法
```pascal
uses
  nextpas.core.simd,      // 向量运算
  nextpas.core.simd.api;  // 门面函数

// 内存比较
if MemEqual(@buf1[0], @buf2[0], Length(buf1)) then
  WriteLn('缓冲区相等');

// 字节查找
pos := MemFindByte(@data[0], Length(data), $FF);

// 字节求和
total := SumBytes(@data[0], Length(data));

// UTF-8 验证
if Utf8Validate(@text[0], Length(text)) then
  WriteLn('UTF-8 有效');

// ASCII 转小写
ToLowerAscii(@str[1], Length(str));
```

### 向量运算
```pascal
var
  a, b, result: TVecF32x4;
begin
  // 使用运算符重载
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 5.0; b.f[1] := 6.0; b.f[2] := 7.0; b.f[3] := 8.0;
  result := a + b;  // [6.0, 8.0, 10.0, 12.0]
  result := a * b;  // [5.0, 12.0, 21.0, 32.0]
  result := -a;     // [-1.0, -2.0, -3.0, -4.0]

  // Shuffle 操作
  result := VecF32x4Shuffle(a, MM_SHUFFLE(0,0,0,0));  // 广播 a[0]
  result := VecF32x4Reverse(a);  // [4.0, 3.0, 2.0, 1.0]

  // 数学函数（示例：使用已实现的 API）
  result := VecF32x4Sqrt(a);
  result := VecF32x4Abs(result);
end;
```

### 高级算法
```pascal
var
  v: TVecI32x4;
  arr, out_arr: array[0..7] of Int32;
begin
  // 排序网络 - 4 元素排序
  v.i[0] := 4; v.i[1] := 1; v.i[2] := 3; v.i[3] := 2;
  v := SortNet4I32(v, True);  // 升序 [1, 2, 3, 4]

  // 前缀和
  v.i[0] := 1; v.i[1] := 2; v.i[2] := 3; v.i[3] := 4;
  v := PrefixSumI32x4(v, True);  // inclusive [1, 3, 6, 10]

  // 数组前缀和
  arr[0] := 1; arr[1] := 2; arr[2] := 3; arr[3] := 4;
  PrefixSumArrayI32(@arr[0], @out_arr[0], 4);  // [1, 3, 6, 10]

  // 字符串搜索
  pos := StrFindChar(@text[0], Length(text), Ord('x'));
end;
```

### 查询后端信息
```pascal
WriteLn('当前后端: ', GetCurrentBackendInfo.Name);
// 输出: "AVX2" 或 "SSE2" 或 "Scalar"
```

## API 参考

### 内存操作 (Memory Operations)

#### MemEqual
```pascal
function MemEqual(a, b: Pointer; len: SizeUInt): LongBool;
```
**功能**：比较两个内存区域是否相等
**参数**：
- `a`, `b`: 要比较的内存区域指针
- `len`: 比较的字节数

**返回值**：相等返回 `True`，否则返回 `False`
**优化**：x86_64 使用 SSE2/AVX2，AArch64 使用 NEON

#### MemFindByte
```pascal
function MemFindByte(p: Pointer; len: SizeUInt; value: Byte): PtrInt;
```
**功能**：在内存区域中查找指定字节的首次出现位置
**参数**：
- `p`: 搜索的内存区域指针
- `len`: 搜索的字节数
- `value`: 要查找的字节值

**返回值**：找到返回位置索引（0-based），未找到返回 -1
**优化**：x86_64 使用 SSE2/AVX2，AArch64 使用 NEON

#### MemDiffRange
```pascal
function MemDiffRange(a, b: Pointer; len: SizeUInt; out firstDiff, lastDiff: SizeUInt): Boolean;
```
**功能**：找出两个内存区域的差异范围
**参数**：
- `a`, `b`: 要比较的内存区域指针
- `len`: 比较的字节数
- `firstDiff`: 首个差异位置（0-based）
- `lastDiff`: 最后差异位置（0-based）

**返回值**：
- 有差异返回 `True`，并输出 `firstDiff/lastDiff`
- 完全相同返回 `False`

**优化**：x86_64 使用 SSE2/AVX2，AArch64 使用 NEON

### 文本操作 (Text Operations)

#### Utf8Validate
```pascal
function Utf8Validate(p: Pointer; len: SizeUInt): Boolean;
```
**功能**：验证内存区域是否为有效的 UTF-8 编码
**参数**：
- `p`: 要验证的内存区域指针
- `len`: 验证的字节数

**返回值**：有效 UTF-8 返回 `True`，否则返回 `False`
**优化**：x86_64 使用 SSE2 ASCII 快路径 + 标量回退，AArch64 使用 NEON ASCII 快路径

#### ToLowerAscii
```pascal
procedure ToLowerAscii(p: Pointer; len: SizeUInt);
```
**功能**：将 ASCII 字符转换为小写（就地修改）
**参数**：
- `p`: 要转换的内存区域指针
- `len`: 转换的字节数

**说明**：只转换 ASCII 字母 A-Z，非 ASCII 字节保持不变
**优化**：x86_64 使用 SSE2/AVX2，AArch64 使用 NEON

#### ToUpperAscii
```pascal
procedure ToUpperAscii(p: Pointer; len: SizeUInt);
```
**功能**：将 ASCII 字符转换为大写（就地修改）
**参数**：
- `p`: 要转换的内存区域指针
- `len`: 转换的字节数

**说明**：只转换 ASCII 字母 a-z，非 ASCII 字节保持不变
**优化**：x86_64 使用 SSE2/AVX2，AArch64 使用 NEON

#### AsciiIEqual
```pascal
function AsciiIEqual(a, b: Pointer; len: SizeUInt): Boolean;
```
**功能**：ASCII 字符串忽略大小写比较
**参数**：
- `a`, `b`: 要比较的内存区域指针
- `len`: 比较的字节数

**返回值**：忽略大小写相等返回 `True`，否则返回 `False`
**说明**：只对 ASCII 字母进行大小写转换，非 ASCII 字节直接比较
**优化**：x86_64 使用 SSE2/AVX2，AArch64 使用 NEON
实现与配置（以代码为准）
- 后端选择/强制：公开 control-plane 推荐使用 `nextpas.core.simd.runtime` 的 `TrySetCurrentBackend` / `SetCurrentBackend` / `ResetCurrentBackendSelection`；`dispatch` 层入口保留给更低层维护与测试。
- VectorAsm 开关：编译期定义 `SIMD_VECTOR_ASM_DISABLED`；运行时可调用 `SetVectorAsmEnabled`（支持初始化后切换，并触发 backend 重建；建议用于启动/测试阶段，而非业务热路径并发写切换）。
  - 对 `SSE* / AVX*` 这类 runtime-gated backend，会在重建时切换 fast path / fallback 能力位。
  - 对当前 `NEON / RISCVV` asm build，runtime 关闭后会重建为 scalar-backed table，以避免保留 stale asm dispatch；这条路径仍需在 arm64 / riscv64 asm-ready 主机上补 fresh execution evidence。
- 测试入口：
  - bash tests/nextpas.core.simd/BuildOrTest.sh check
  - bash tests/nextpas.core.simd/BuildOrTest.sh test

汇编与调用约定注意
- Windows x64：遵循 MS x64 ABI；如使用 AVX，返回前执行 vzeroupper；保存 XMM6–XMM15。
- SysV x86_64：保证 16 字节栈对齐；寄存器保存规则按照 SysV。
- AArch64：遵守 AAPCS64；必要时保存/恢复 V8–V15；NEON 为基线。
- 非对齐与尾部处理：内部处理任意指针与长度；严禁越界读写。

测试与基准（本地）
- 最小测试：tests/nextpas.core.simd/minitest_simd.lpr
- 边界测试：tests/nextpas.core.simd/minitest_simd_edges.lpr（未对齐、混合 UTF‑8）
- 微基准：tests/nextpas.core.simd/bench_simd.lpr（Mem*/Bitset/Utf8Validate/IndexOf/AsciiCase）
- 正确性：每个原语与标量参考实现对拍；覆盖随机/对抗/边界长度（0/1/15/16/31/32/n·W±k）。
- 一致性：强制不同 Profile（SCALAR/SSE2）结果一致（在支持平台上）。
- 性能：小/中/大三档；冷热缓存分别测试；记录速度提升比。

更好用、更现代（DX）
- 函数指针对外：直接调用 MemEqual 等，无需关心 ISA；Info 可用于日志。
- 便捷重载：支持 BytesView（ptr+len 轻量视图）与 open array of Byte 重载（后续）。
- 可插拔策略：允许在基准/诊断中显式选择 SCALAR/SSE2/AVX2/NEON 对比（后续 AVX2/SVE）。
- 文档与示例：提供最小示例打印当前 Profile 并跑一组微基准。

命名规范（强制）
- 指令集与 Profile：一律全大写（SSE2/AVX2/NEON/AVX-512/SVE）。
- 单元与符号：Pascal 风格，函数语义化命名（MemEqual/Utf8Validate 等）。

运行指南（本地）
- 构建与运行最小测试：
  - fpc -MObjFPC -S2 -Si -Fu./src tests/nextpas.core.simd/minitest_simd.lpr
- 构建与运行边界测试：
  - fpc -MObjFPC -S2 -Si -Fu./src tests/nextpas.core.simd/minitest_simd_edges.lpr
- 构建与运行微基准：
  - fpc -MObjFPC -S2 -Si -Fu./src tests/nextpas.core.simd/bench_simd.lpr
- 强制回退（对拍一致性）：
  - Windows: set FAFAFA_SIMD_FORCE=SCALAR
  - Linux/Mac: export FAFAFA_SIMD_FORCE=SCALAR

## 搜索基元（BytesIndexOf）

语义与约定
- 在字节序列 haystack 中查找 needle 的首次出现位置（0-based）；未找到返回 -1
- 约定：nlen=0 返回 0；nlen>len 返回 -1；指针可为任意对齐

实现策略
- 标量：BMH（Boyer–Moore–Horspool）快速滑动，通用可靠
- SSE2/AVX2：两段式加速
  1) 候选尾位批量筛选：利用 MemFindByte_SSE2/AVX2 在 pos+nlen-1 处批量查找 needle 的末字节
  2) 快速否决 + 完整确认：
     - 对命中候选，先比较首/尾块（SSE2: 16B；AVX2: 32B；长度不足退化）
     - 对超长 needle（SSE2: >32；AVX2: >64），再比较中段块快速否决
     - 最后用 CompareByte 完整确认匹配

复杂度
- 平均近似 O(len/nlen) 的滑动否决 + 常数次块比较；最坏退化 O(len·nlen)
- SIMD 路径对“长 needle + 稀疏命中”更具优势

绑定与回退
- 门面导出 BytesIndexOf：
  - x86_64：优先绑定 AVX2，其次 SSE2；无法使用则回退到标量 BMH
  - 可用 FAFAFA_SIMD_FORCE=SCALAR|SSE2|AVX2 强制覆盖，用于对拍与排障

使用示例
- 查找 'world' 在 'hello world' 中的位置：
  - i := BytesIndexOf(@buf[0], Length(buf), @pat[0], Length(pat)); // 命中返回 6

AVX2 注意事项
- 检测要求：OSXSAVE+AVX（CPUID leaf1 ECX bit27/28），XGETBV(XCR0) 确认 XMM/YMM 保存（bit1/bit2），leaf7 EBX bit5 为 AVX2。
- vzeroupper：所有 AVX 函数在与 SSE 路径切换及返回前调用 vzeroupper，避免 AVX→SSE 混用惩罚。
- 非对齐：使用 VMOVDQU/MOVDQU 支持任意指针；尾部采用 SSE2/标量收尾，严格控制访问范围。
- 覆盖顺序：优先级为 AVX2 > SSE2 > SCALAR；可用 FAFAFA_SIMD_FORCE 覆盖（SCALAR|SSE2|AVX2）。

支持矩阵（当前轮）
- x86_64：
  - SSE2：MemEqual / MemFindByte / MemDiffRange / ToLowerAscii / ToUpperAscii（内联汇编）
  - AVX2：MemEqual / MemFindByte / MemDiffRange / ToLowerAscii / ToUpperAscii（内联汇编）
  - POPCNT：BitsetPopCount 快路径
  - UTF‑8：FastPath（ASCII SSE2 + 非 ASCII 回退标量）
  - 搜索：BytesIndexOf（标量 BMH + SSE2/AVX2 快速筛选与否决）
- 其他架构：ARM NEON 后端有 616/616 dispatch 赋值口径，但默认 public 状态仍是 scalar fallback，NEON asm 需要显式 opt-in；RISC-V V 为实验性
- `sbNEON` 的 `616 / 616` 不代表默认 public 构建启用 NEON asm；默认仍按 scalar fallback，除非满足上面的 asm opt-in 条件

排障提示
- 若出现非预期性能/行为：
  - 设置 FAFAFA_SIMD_FORCE=SCALAR 重试以确认是否与 SIMD 路径相关
  - Windows x64 请确认未修改调用约定/优化开关；必要时以 /O- 测试
  - 如目标机为旧 CPU，请确认是否支持 AVX/AVX2（可打印 SimdInfo 获取 Profile）



## AArch64/NEON 后端状态

NEON 后端已于 2026-04 完成落地，实现 558/558 dispatch 覆盖。这个结论只表示 dispatch coverage，不改变默认 public scalar fallback 和 asm opt-in 契约。详见 `docs/simd/closeout.md`。

历史规划文档已归档至 `docs/legacy/simd/`。

## base.pas API 参考

### 向量类型

#### 128-bit 有符号向量

| 类型 | 元素类型 | 元素数 | 描述 |
|------|----------|--------|------|
| `TVecF32x4` | `Single` | 4 | 4 个 32 位浮点数 |
| `TVecF64x2` | `Double` | 2 | 2 个 64 位浮点数 |
| `TVecI32x4` | `Int32` | 4 | 4 个 32 位有符号整数 |
| `TVecI64x2` | `Int64` | 2 | 2 个 64 位有符号整数 |
| `TVecI16x8` | `Int16` | 8 | 8 个 16 位有符号整数 |
| `TVecI8x16` | `Int8` | 16 | 16 个 8 位有符号整数 |

#### 128-bit 无符号向量

| 类型 | 元素类型 | 元素数 | 描述 |
|------|----------|--------|------|
| `TVecU32x4` | `UInt32` | 4 | 4 个 32 位无符号整数 |
| `TVecU64x2` | `UInt64` | 2 | 2 个 64 位无符号整数 |
| `TVecU16x8` | `UInt16` | 8 | 8 个 16 位无符号整数 |
| `TVecU8x16` | `UInt8` | 16 | 16 个 8 位无符号整数 |

#### 256-bit 向量

| 类型 | 元素类型 | 元素数 | 描述 |
|------|----------|--------|------|
| `TVecF32x8` | `Single` | 8 | 8 个 32 位浮点数 |
| `TVecF64x4` | `Double` | 4 | 4 个 64 位浮点数 |
| `TVecI32x8` | `Int32` | 8 | 8 个 32 位有符号整数 |
| `TVecU32x8` | `UInt32` | 8 | 8 个 32 位无符号整数 |

#### 向量类型结构
所有向量类型都是 `record` 类型，支持通过 variant 访问：
```pascal
var v: TVecF32x4;
begin
  // 方式 1: 通过元素数组访问
  v.f[0] := 1.0;
  v.f[1] := 2.0;

  // 方式 2: 通过 raw 字节数组访问
  WriteLn(v.raw[0]);  // 访问底层字节
end;
```

### 运算符重载

#### TVecF32x4 运算符
```pascal
operator + (const a, b: TVecF32x4): TVecF32x4;  // 逐元素加法
operator - (const a, b: TVecF32x4): TVecF32x4;  // 逐元素减法
operator * (const a, b: TVecF32x4): TVecF32x4;  // 逐元素乘法
operator / (const a, b: TVecF32x4): TVecF32x4;  // 逐元素除法
operator - (const a: TVecF32x4): TVecF32x4;     // 取反
operator * (const a: TVecF32x4; s: Single): TVecF32x4;  // 标量乘法
operator * (s: Single; const a: TVecF32x4): TVecF32x4;  // 标量乘法
operator / (const a: TVecF32x4; s: Single): TVecF32x4;  // 标量除法
```

#### TVecF64x2 运算符
```pascal
operator + (const a, b: TVecF64x2): TVecF64x2;
operator - (const a, b: TVecF64x2): TVecF64x2;
operator * (const a, b: TVecF64x2): TVecF64x2;
operator / (const a, b: TVecF64x2): TVecF64x2;
operator - (const a: TVecF64x2): TVecF64x2;
```

#### TVecI32x4 运算符
```pascal
operator + (const a, b: TVecI32x4): TVecI32x4;
operator - (const a, b: TVecI32x4): TVecI32x4;
operator - (const a: TVecI32x4): TVecI32x4;
```

#### 无符号 128-bit 运算符
```pascal
operator + (const a, b: TVecU32x4): TVecU32x4;
operator - (const a, b: TVecU32x4): TVecU32x4;
operator * (const a, b: TVecU32x4): TVecU32x4;
operator and (const a, b: TVecU32x4): TVecU32x4;
operator or (const a, b: TVecU32x4): TVecU32x4;
operator xor (const a, b: TVecU32x4): TVecU32x4;
operator not (const a: TVecU32x4): TVecU32x4;

operator + (const a, b: TVecU64x2): TVecU64x2;
operator - (const a, b: TVecU64x2): TVecU64x2;
operator and (const a, b: TVecU64x2): TVecU64x2;
operator or (const a, b: TVecU64x2): TVecU64x2;
operator xor (const a, b: TVecU64x2): TVecU64x2;
operator not (const a: TVecU64x2): TVecU64x2;

operator + (const a, b: TVecU16x8): TVecU16x8;
operator - (const a, b: TVecU16x8): TVecU16x8;
operator * (const a, b: TVecU16x8): TVecU16x8;
operator and (const a, b: TVecU16x8): TVecU16x8;
operator or (const a, b: TVecU16x8): TVecU16x8;
operator xor (const a, b: TVecU16x8): TVecU16x8;
operator not (const a: TVecU16x8): TVecU16x8;

operator + (const a, b: TVecU8x16): TVecU8x16;
operator - (const a, b: TVecU8x16): TVecU8x16;
operator and (const a, b: TVecU8x16): TVecU8x16;
operator or (const a, b: TVecU8x16): TVecU8x16;
operator xor (const a, b: TVecU8x16): TVecU8x16;
operator not (const a: TVecU8x16): TVecU8x16;
```

#### 无符号 256-bit 运算符
```pascal
operator + (const a, b: TVecU32x8): TVecU32x8;
operator - (const a, b: TVecU32x8): TVecU32x8;
operator * (const a, b: TVecU32x8): TVecU32x8;
operator and (const a, b: TVecU32x8): TVecU32x8;
operator or (const a, b: TVecU32x8): TVecU32x8;
operator xor (const a, b: TVecU32x8): TVecU32x8;
operator not (const a: TVecU32x8): TVecU32x8;

operator + (const a, b: TVecU64x4): TVecU64x4;
operator - (const a, b: TVecU64x4): TVecU64x4;
operator and (const a, b: TVecU64x4): TVecU64x4;
operator or (const a, b: TVecU64x4): TVecU64x4;
operator xor (const a, b: TVecU64x4): TVecU64x4;
operator not (const a: TVecU64x4): TVecU64x4;
```

#### 无符号 512-bit 运算符
```pascal
operator + (const a, b: TVecU32x16): TVecU32x16;
operator - (const a, b: TVecU32x16): TVecU32x16;
operator * (const a, b: TVecU32x16): TVecU32x16;
operator and (const a, b: TVecU32x16): TVecU32x16;
operator or (const a, b: TVecU32x16): TVecU32x16;
operator xor (const a, b: TVecU32x16): TVecU32x16;
operator not (const a: TVecU32x16): TVecU32x16;

operator + (const a, b: TVecU64x8): TVecU64x8;
operator - (const a, b: TVecU64x8): TVecU64x8;
operator and (const a, b: TVecU64x8): TVecU64x8;
operator or (const a, b: TVecU64x8): TVecU64x8;
operator xor (const a, b: TVecU64x8): TVecU64x8;
operator not (const a: TVecU64x8): TVecU64x8;

operator + (const a, b: TVecU8x64): TVecU8x64;
operator - (const a, b: TVecU8x64): TVecU8x64;
operator and (const a, b: TVecU8x64): TVecU8x64;
operator or (const a, b: TVecU8x64): TVecU8x64;
operator xor (const a, b: TVecU8x64): TVecU8x64;
operator not (const a: TVecU8x64): TVecU8x64;
```

**示例**：
```pascal
var a, b, c: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  b.f[0] := 5.0; b.f[1] := 6.0; b.f[2] := 7.0; b.f[3] := 8.0;
  c := a + b;  // [6.0, 8.0, 10.0, 12.0]
  c := a * 2.0;  // [2.0, 4.0, 6.0, 8.0]
end;
```

### 掩码类型

#### 掩码类型定义
| 类型 | 元素类型 | 元素数 | 描述 |
|------|----------|--------|------|
| `TMaskF32x4` | `UInt32` | 4 | F32x4 的向量掩码 |
| `TMaskF64x2` | `UInt64` | 2 | F64x2 的向量掩码 |
| `TMaskI32x4` | `UInt32` | 4 | I32x4 的向量掩码 |
| `TMaskI64x2` | `UInt64` | 2 | I64x2 的向量掩码 |

掩码元素值：`0` 表示 false，`$FFFFFFFF` (或 `$FFFFFFFFFFFFFFFF` 对于 64-bit) 表示 true。

#### 位掩码类型
| 类型 | 有效位数 | 描述 |
|------|----------|------|
| `TMask2` | 2 | 用于 2 元素向量 |
| `TMask4` | 4 | 用于 4 元素向量 |
| `TMask8` | 8 | 用于 8 元素向量 |
| `TMask16` | 16 | 用于 16 元素向量 |
| `TMask32` | 32 | 用于 32 元素向量 |

#### TMaskF32x4 函数

```pascal
function MaskF32x4AllTrue: TMaskF32x4;
```
返回所有元素为 true 的掩码。

```pascal
function MaskF32x4AllFalse: TMaskF32x4;
```
返回所有元素为 false 的掩码。

```pascal
function MaskF32x4Set(m0, m1, m2, m3: Boolean): TMaskF32x4;
```
根据 4 个布尔值构造掩码。

```pascal
function MaskF32x4Test(const m: TMaskF32x4; index: Integer): Boolean;
```
测试指定位置的掩码元素是否为 true。

```pascal
function MaskF32x4ToBitmask(const m: TMaskF32x4): TMask4;
```
将向量掩码转换为 4-bit 位掩码。

```pascal
function MaskF32x4Any(const m: TMaskF32x4): Boolean;
```
返回是否有任意元素为 true。

```pascal
function MaskF32x4All(const m: TMaskF32x4): Boolean;
```
返回是否所有元素都为 true。

```pascal
function MaskF32x4None(const m: TMaskF32x4): Boolean;
```
返回是否所有元素都为 false。

```pascal
function MaskF32x4Select(const m: TMaskF32x4; const a, b: TVecF32x4): TVecF32x4;
```
根据掩码选择元素：m[i]=true 选择 a[i]，否则选择 b[i]。

#### TMaskF32x4 逻辑运算符
```pascal
operator and (const a, b: TMaskF32x4): TMaskF32x4;  // 逐元素与
operator or (const a, b: TMaskF32x4): TMaskF32x4;   // 逐元素或
operator xor (const a, b: TMaskF32x4): TMaskF32x4;  // 逐元素异或
operator not (const a: TMaskF32x4): TMaskF32x4;     // 逐元素取反
```

#### TMaskF64x2 / TMaskI32x4 函数
```pascal
function MaskF64x2AllTrue: TMaskF64x2;
function MaskF64x2AllFalse: TMaskF64x2;
function MaskF64x2ToBitmask(const m: TMaskF64x2): TMask2;

function MaskI32x4AllTrue: TMaskI32x4;
function MaskI32x4AllFalse: TMaskI32x4;
function MaskI32x4ToBitmask(const m: TMaskI32x4): TMask4;
```

### 类型转换函数

#### IntoBits / FromBits - 位模式重新解释
不改变位模式，仅重新解释类型：
```pascal
function VecF32x4IntoBits(const a: TVecF32x4): TVecI32x4;
function VecI32x4FromBitsF32(const a: TVecI32x4): TVecF32x4;
function VecF64x2IntoBits(const a: TVecF64x2): TVecI64x2;
function VecI64x2FromBitsF64(const a: TVecI64x2): TVecF64x2;
```

**示例**：
```pascal
var f: TVecF32x4; i: TVecI32x4;
begin
  f.f[0] := 1.0;
  i := VecF32x4IntoBits(f);  // i.i[0] = $3F800000 (1.0 的 IEEE 754 表示)
end;
```

#### Cast - 元素级别数值转换
```pascal
function VecF32x4CastToI32x4(const a: TVecF32x4): TVecI32x4;  // 浮点截断为整数
function VecI32x4CastToF32x4(const a: TVecI32x4): TVecF32x4;  // 整数转为浮点
function VecF64x2CastToI64x2(const a: TVecF64x2): TVecI64x2;
function VecI64x2CastToF64x2(const a: TVecI64x2): TVecF64x2;
```

#### Widen - 扩展宽度
```pascal
function VecI16x8WidenLoI32x4(const a: TVecI16x8): TVecI32x4;  // 低 4 元素符号扩展
function VecI16x8WidenHiI32x4(const a: TVecI16x8): TVecI32x4;  // 高 4 元素符号扩展
```

#### Narrow - 缩小宽度
```pascal
function VecI32x4NarrowToI16x8(const a, b: TVecI32x4): TVecI16x8;  // a->低4, b->高4
```

#### 精度转换
```pascal
function VecF32x4ToF64x2Lo(const a: TVecF32x4): TVecF64x2;  // 低 2 元素 F32->F64
function VecF64x2ToF32x4(const a, b: TVecF64x2): TVecF32x4;  // 2*F64x2 -> F32x4
```

### Shuffle/Swizzle 函数

#### 辅助宏
```pascal
function MM_SHUFFLE(d, c, b, a: Byte): Byte;
```
生成 shuffle 立即数。结果 = `(d << 6) | (c << 4) | (b << 2) | a`。

**示例**：
- `MM_SHUFFLE(3,2,1,0) = $E4` - 不变
- `MM_SHUFFLE(0,0,0,0) = $00` - 广播元素 0
- `MM_SHUFFLE(0,1,2,3) = $1B` - 反转

#### Shuffle - 单向量元素重排
```pascal
function VecF32x4Shuffle(const a: TVecF32x4; imm8: Byte): TVecF32x4;
function VecI32x4Shuffle(const a: TVecI32x4; imm8: Byte): TVecI32x4;
```
根据 imm8 重排元素。imm8 每 2 bit 选择一个源元素索引 (0-3)。

**示例**：
```pascal
var a, r: TVecF32x4;
begin
  a.f[0] := 1.0; a.f[1] := 2.0; a.f[2] := 3.0; a.f[3] := 4.0;
  r := VecF32x4Shuffle(a, MM_SHUFFLE(0,0,0,0));  // [1,1,1,1] 广播
  r := VecF32x4Shuffle(a, MM_SHUFFLE(0,1,2,3));  // [4,3,2,1] 反转
end;
```

#### Shuffle2 - 双向量元素选择
```pascal
function VecF32x4Shuffle2(const a, b: TVecF32x4; imm8: Byte): TVecF32x4;
```
低 2 元素来自 a，高 2 元素来自 b。

#### Blend - 根据掩码混合
```pascal
function VecF32x4Blend(const a, b: TVecF32x4; mask: Byte): TVecF32x4;
function VecF64x2Blend(const a, b: TVecF64x2; mask: Byte): TVecF64x2;
function VecI32x4Blend(const a, b: TVecI32x4; mask: Byte): TVecI32x4;
```
mask bit=0 选择 a，bit=1 选择 b。

#### Unpack - 交织元素
```pascal
function VecF32x4UnpackLo(const a, b: TVecF32x4): TVecF32x4;  // [a0,b0,a1,b1]
function VecF32x4UnpackHi(const a, b: TVecF32x4): TVecF32x4;  // [a2,b2,a3,b3]
function VecI32x4UnpackLo(const a, b: TVecI32x4): TVecI32x4;
function VecI32x4UnpackHi(const a, b: TVecI32x4): TVecI32x4;
```

#### Broadcast - 广播单元素
```pascal
function VecF32x4Broadcast(const a: TVecF32x4; index: Integer): TVecF32x4;
function VecI32x4Broadcast(const a: TVecI32x4; index: Integer): TVecI32x4;
```
将 a[index] 广播到所有位置。

#### Reverse - 反转元素顺序
```pascal
function VecF32x4Reverse(const a: TVecF32x4): TVecF32x4;  // [a3,a2,a1,a0]
function VecI32x4Reverse(const a: TVecI32x4): TVecI32x4;
```

#### RotateLeft - 循环旋转
```pascal
function VecF32x4RotateLeft(const a: TVecF32x4; n: Integer): TVecF32x4;
function VecI32x4RotateLeft(const a: TVecI32x4; n: Integer): TVecI32x4;
```
元素左移 n 个位置（循环）。

#### Insert/Extract - 插入和提取单元素
```pascal
function VecF32x4Insert(const a: TVecF32x4; value: Single; index: Integer): TVecF32x4;
function VecI32x4Insert(const a: TVecI32x4; value: Int32; index: Integer): TVecI32x4;
function VecF32x4Extract(const a: TVecF32x4; index: Integer): Single;
function VecI32x4Extract(const a: TVecI32x4; index: Integer): Int32;
```

### SIMD 数学函数

所有数学函数都是逐元素操作，当前为标量参考实现。

#### 三角函数
```pascal
function VecF32x4Sin(const a: TVecF32x4): TVecF32x4;   // sin(x)
function VecF32x4Cos(const a: TVecF32x4): TVecF32x4;   // cos(x)
function VecF32x4Tan(const a: TVecF32x4): TVecF32x4;   // tan(x)
procedure VecF32x4SinCos(const a: TVecF32x4; out sinResult, cosResult: TVecF32x4);
```

**示例**：
```pascal
var angles, sines, cosines: TVecF32x4;
begin
  angles.f[0] := 0; angles.f[1] := Pi/6; angles.f[2] := Pi/4; angles.f[3] := Pi/2;
  sines := VecF32x4Sin(angles);  // [0, 0.5, 0.707, 1.0]
  VecF32x4SinCos(angles, sines, cosines);  // 同时计算 sin 和 cos
end;
```

#### 指数/对数函数
```pascal
function VecF32x4Exp(const a: TVecF32x4): TVecF32x4;   // e^x
function VecF32x4Exp2(const a: TVecF32x4): TVecF32x4;  // 2^x
function VecF32x4Log(const a: TVecF32x4): TVecF32x4;   // ln(x)
function VecF32x4Log2(const a: TVecF32x4): TVecF32x4;  // log2(x)
function VecF32x4Log10(const a: TVecF32x4): TVecF32x4; // log10(x)
function VecF32x4Pow(const base, exp: TVecF32x4): TVecF32x4;  // base^exp
```

#### 反三角函数
```pascal
function VecF32x4Asin(const a: TVecF32x4): TVecF32x4;  // arcsin(x), x ∈ [-1,1]
function VecF32x4Acos(const a: TVecF32x4): TVecF32x4;  // arccos(x), x ∈ [-1,1]
function VecF32x4Atan(const a: TVecF32x4): TVecF32x4;  // arctan(x)
function VecF32x4Atan2(const y, x: TVecF32x4): TVecF32x4;  // arctan2(y, x)
```

### 高级算法

#### 排序网络 (Sorting Networks)
SIMD 友好的小数组排序，使用固定比较交换网络。

```pascal
function SortNet4I32(const a: TVecI32x4; ascending: Boolean = True): TVecI32x4;
```
对 4 个 Int32 元素排序。
- `ascending`: True 为升序，False 为降序
- 使用 5 次比较交换操作

```pascal
function SortNet4F32(const a: TVecF32x4; ascending: Boolean = True): TVecF32x4;
```
对 4 个 Single 元素排序。

```pascal
function SortNet8I32(const a: TVecI32x8; ascending: Boolean = True): TVecI32x8;
```
对 8 个 Int32 元素排序。

**示例**：
```pascal
var v: TVecI32x4;
begin
  v.i[0] := 4; v.i[1] := 1; v.i[2] := 3; v.i[3] := 2;
  v := SortNet4I32(v, True);   // [1, 2, 3, 4]
  v := SortNet4I32(v, False);  // [4, 3, 2, 1]
end;
```

#### 前缀和 (Prefix Sum / Scan)

```pascal
function PrefixSumI32x4(const a: TVecI32x4; inclusive: Boolean = True): TVecI32x4;
function PrefixSumF32x4(const a: TVecF32x4; inclusive: Boolean = True): TVecF32x4;
```
向量前缀和。
- `inclusive=True`: `[a0, a0+a1, a0+a1+a2, a0+a1+a2+a3]`
- `inclusive=False`: `[0, a0, a0+a1, a0+a1+a2]` (exclusive)

```pascal
procedure PrefixSumArrayI32(src, dst: PInt32; count: SizeUInt);
procedure PrefixSumArrayF32(src, dst: PSingle; count: SizeUInt);
```
数组前缀和，结果写入 dst。

**示例**：
```pascal
var v, r: TVecI32x4;
    arr, out_arr: array[0..7] of Int32;
begin
  // 向量前缀和
  v.i[0] := 1; v.i[1] := 2; v.i[2] := 3; v.i[3] := 4;
  r := PrefixSumI32x4(v, True);   // [1, 3, 6, 10]
  r := PrefixSumI32x4(v, False);  // [0, 1, 3, 6]

  // 数组前缀和
  arr[0] := 1; arr[1] := 2; arr[2] := 3; arr[3] := 4;
  PrefixSumArrayI32(@arr[0], @out_arr[0], 4);  // [1, 3, 6, 10]
end;
```

#### 字符串搜索

```pascal
function StrFindChar(p: Pointer; len: SizeUInt; ch: Byte): PtrInt;
```
在字节序列中查找单个字符。
- `p`: 搜索起点
- `len`: 搜索长度
- `ch`: 要查找的字节值
- 返回值：找到返回位置索引 (0-based)，未找到返回 -1

**示例**：
```pascal
var
  text: AnsiString;
  pos: PtrInt;
begin
  text := 'Hello, World!';
  pos := StrFindChar(@text[1], Length(text), Ord('W'));  // 返回 7
  pos := StrFindChar(@text[1], Length(text), Ord('x'));  // 返回 -1
end;
```

## 性能指南

### 何时使用 SIMD

#### 适合 SIMD 的场景
- **大批量数据处理**：数据量 >= 64 字节时 SIMD 优势明显
- **内存密集操作**：MemEqual/MemFindByte/SumBytes 等
- **批量数值计算**：向量加减乘除、数学函数
- **字符串/文本处理**：UTF-8 验证、大小写转换、比较
- **位集操作**：PopCount、批量位操作

#### 不适合 SIMD 的场景
- **小数据量**：< 16 字节时标量可能更快（派发开销）
- **分支密集代码**：SIMD 不擅长条件跳转
- **随机内存访问**：不连续的数据难以向量化
- **依赖链计算**：每步依赖前一步结果的计算

### 最佳实践

#### 1. 数据对齐
```pascal
// 推荐：16/32 字节对齐的数据
var
  data: array[0..1023] of Single; align 32;  // AVX2 对齐
```
未对齐数据也能工作，但对齐可提升 5-15% 性能。

#### 2. 批量处理
```pascal
// 不推荐：逐元素调用
for i := 0 to Length(arr) - 1 do
  result := SomeSimdFunc(@arr[i], 1);

// 推荐：一次性处理整个数组
result := SomeSimdFunc(@arr[0], Length(arr));
```

#### 3. 避免混合使用 AVX 和 SSE
混合使用会导致性能惩罚（状态切换）。本库内部已处理 `vzeroupper`。

#### 4. 向量类型使用
```pascal
// 好：使用运算符重载
var a, b, c: TVecF32x4;
c := a + b * 2.0;

// 避免：在紧密循环中访问单个元素
for i := 0 to 3 do
  total := total + v.f[i];  // 改用归约操作
```

### 性能对比参考

测试环境：4096 字节数据，1M 次迭代

| 函数 | Scalar | SSE2 | AVX2 | 加速比 |
|------|--------|------|------|--------|
| MemEqual | 11804ms | 774ms | 153ms | **77x** |
| MemFindByte | 657ms | 52ms | 11ms | **60x** |
| SumBytes | 10267ms | 759ms | 98ms | **105x** |
| BitsetPopCount | 81136ms | - | 539ms | **151x** |
| Utf8Validate | 2936ms | - | 318ms | **9x** |
| AsciiIEqual | 5894ms | - | 247ms | **24x** |

### 调试与排障

#### 强制使用标量后端
```bash
# 用于对拍测试或排除 SIMD 问题
export FAFAFA_SIMD_FORCE=SCALAR
./your_program
```

#### 查询当前后端
```pascal
WriteLn('Backend: ', GetCurrentBackendInfo.Name);  // 输出 "AVX2"/"SSE2"/"Scalar"
```

#### 常见问题
1. **性能未达预期**：检查数据量是否足够大，小数据量 SIMD 优势不明显
2. **结果不一致**：设置 `FAFAFA_SIMD_FORCE=SCALAR` 对拍确认是否为 SIMD 实现问题
3. **崩溃/越界**：检查指针和长度参数是否正确

---

## Batch Array API

Batch API 提供对整个数组的 SIMD 加速操作，自动处理对齐、尾部元素和后端选择。所有函数通过 dispatch table 路由，运行时自动选择最优后端（AVX2 → SSE2 → Scalar）。

### F32 Batch Operations

```pascal
uses nextpas.core.simd;

// 四则运算 (element-wise)
ArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
ArraySubF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
ArrayMulF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);
ArrayDivF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt);

// 一元运算
ArrayAbsF32(aSrc, aDst: PSingle; aCount: SizeUInt);
ArrayNegF32(aSrc, aDst: PSingle; aCount: SizeUInt);
ArraySqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt);
ArrayRcpF32(aSrc, aDst: PSingle; aCount: SizeUInt);   // ~12-bit 近似
ArrayRsqrtF32(aSrc, aDst: PSingle; aCount: SizeUInt); // ~12-bit 近似

// 标量广播
ArrayAddScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);
ArrayMulScalarF32(aSrc, aDst: PSingle; aCount: SizeUInt; aScalar: Single);

// 复合运算
ArrayClampF32(aSrc, aDst: PSingle; aCount: SizeUInt; aMin, aMax: Single);
ArrayFmaF32(aA, aB, aC, aDst: PSingle; aCount: SizeUInt);  // dst = a*b + c
ArrayAxpyF32(aAlpha: Single; aX, aY, aDst: PSingle; aCount: SizeUInt);

// 归约
ReduceSumF32(aSrc: PSingle; aCount: SizeUInt): Single;
ReduceDotF32(aSrc1, aSrc2: PSingle; aCount: SizeUInt): Single;
ReduceMinF32(aSrc: PSingle; aCount: SizeUInt): Single;
ReduceMaxF32(aSrc: PSingle; aCount: SizeUInt): Single;

// 超越函数
ArrayExpF32(aSrc, aDst: PSingle; aCount: SizeUInt);
ArrayLogF32(aSrc, aDst: PSingle; aCount: SizeUInt);
ArrayPowF32(aSrc, aDst: PSingle; aCount: SizeUInt; aExponent: Single);
ArraySinF32(aSrc, aDst: PSingle; aCount: SizeUInt);
ArrayCosF32(aSrc, aDst: PSingle; aCount: SizeUInt);
```

### F64 Batch Operations

```pascal
ArrayAddF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
ArraySubF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
ArrayMulF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
ArrayDivF64(aSrc1, aSrc2, aDst: PDouble; aCount: SizeUInt);
ArrayAbsF64(aSrc, aDst: PDouble; aCount: SizeUInt);
ArrayNegF64(aSrc, aDst: PDouble; aCount: SizeUInt);
ArraySqrtF64(aSrc, aDst: PDouble; aCount: SizeUInt);
ReduceSumF64(aSrc: PDouble; aCount: SizeUInt): Double;
ReduceDotF64(aSrc1, aSrc2: PDouble; aCount: SizeUInt): Double;
ReduceMinF64(aSrc: PDouble; aCount: SizeUInt): Double;
ReduceMaxF64(aSrc: PDouble; aCount: SizeUInt): Double;
```

### Integer / Bitwise Batch Operations

```pascal
ArrayAddI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
ArraySubI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
ArrayMulI16(aSrc1, aSrc2, aDst: PInt16; aCount: SizeUInt);
ArrayPackSatI32toI16(aSrc: PInt32; aDst: PInt16; aCount: SizeUInt);
ArrayF32toI32(aSrc: PSingle; aDst: PInt32; aCount: SizeUInt);
ArrayI32toF32(aSrc: PInt32; aDst: PSingle; aCount: SizeUInt);
ArrayAndI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
ArrayOrI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
ArrayXorI32(aSrc1, aSrc2, aDst: PInt32; aCount: SizeUInt);
ArrayShlI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
ArrayShrI32(aSrc, aDst: PInt32; aCount: SizeUInt; aShift: Integer);
```

### 使用示例

```pascal
program batch_demo;
uses nextpas.core.simd;
var
  X, Y, Z: array[0..1023] of Single;
  i: Integer;
begin
  for i := 0 to 1023 do begin
    X[i] := i * 0.01;
    Y[i] := 1.0 - i * 0.001;
  end;
  // Z = 2.5 * X + Y (BLAS axpy)
  ArrayAxpyF32(2.5, @X[0], @Y[0], @Z[0], 1024);
  WriteLn('Dot: ', ReduceDotF32(@X[0], @Y[0], 1024):0:4);
end.
```

### 注意事项

1. **In-place 安全**: 所有操作支持 `aSrc == aDst`
2. **对齐**: 不要求对齐，内部使用 unaligned load/store
3. **零长度**: `aCount = 0` 安全返回
4. **Rcp/Rsqrt**: 硬件近似 (~12-bit)，需高精度请用 `1.0/x`
5. **Exp 溢出**: 输入 > 88 产生 +Inf，< -87 产生 0

---

## High-Level Array API

高层 API 让外部模块无需手动管理指针即可使用 SIMD 加速。

### 对齐分配器

```pascal
uses nextpas.core.simd.alloc;

var p: Pointer;
begin
  p := SimdAlloc(1024);        // 自动对齐 (AVX2→32B, AVX-512→64B)
  p := SimdAlloc(1024, sa64);  // 强制 64B 对齐
  SimdFree(p);                 // 配套释放
end;
```

### TSimdF32Array / TSimdF64Array / TSimdI32Array

```pascal
uses nextpas.core.simd.arrays.typed;

var A, B, C: TSimdF32Array;
begin
  A := TSimdF32Array.Zeros(10000);
  B := TSimdF32Array.Ones(10000);

  // 运算符 (自动 SIMD 加速)
  C := A + B;
  C := A * 2.5;

  // 归约
  WriteLn('Sum: ', A.Sum:0:4);
  WriteLn('Mean: ', A.Mean:0:4);
  WriteLn('Dot: ', A.Dot(B):0:4);

  // Stride (矩阵列操作)
  var col := TSimdF32Array.WrapStrided(@matrix[0], rows, cols);
  WriteLn('Column sum: ', col.Sum:0:4);

  // Slice (零拷贝)
  var sub := A.Slice(100, 500);

  A.Free; B.Free; C.Free;
end;
```

### Pipeline API

```pascal
uses nextpas.core.simd.pipeline;

var src, dst: TSimdF32Array;
begin
  src := TSimdF32Array.Create(10000);
  dst := TSimdF32Array.Create(10000);

  // 链式操作 (自动融合: MulScalar+AddScalar → Linear 单 pass)
  TSimdF32Pipeline.FromArray(src)
    .MulScalar(2.0)
    .AddScalar(1.0)
    .ReLU
    .IntoArray(dst);

  // 或直接 Eval 返回新数组
  var result := TSimdF32Pipeline.FromArray(src)
    .Exp
    .Eval;

  src.Free; dst.Free; result.Free;
end;
```

### 性能特征

- **Contiguous fast path**: stride=1 时直接调用底层 SIMD batch slot (零开销)
- **Stride fallback**: 非连续内存自动回退到标量循环
- **Pipeline fusion**: `MulScalar+AddScalar` 自动识别为 `ArrayLinearF32` (单 FMA 指令)
- **对齐分配**: 所有 Create/Zeros 返回的数组自动对齐到最优边界

---

## Domain Modules (领域扩展)

### nextpas.core.simd.stats — 统计

```pascal
uses nextpas.core.simd.stats;

// 加权统计
WeightedSumF32(values, weights, count): Single;
WeightedMeanF32(values, weights, count): Single;

// 相关性
CovarianceF32(x, y, count): Single;
CorrelationF32(x, y, count): Single;
VarianceF32(x, count): Single;
StdDevF32(x, count): Single;

// 流式统计 (Welford 算法)
var stats: TSimdF32OnlineStats;
stats.Clear;
stats.AddBatch(@data[0], 1000);
WriteLn(stats.GetMean, stats.GetStdDev);
```

### nextpas.core.simd.nn — 神经网络

```pascal
uses nextpas.core.simd.nn;

SigmoidF32(src, dst, count);           // 1/(1+exp(-x))
SoftmaxF32(src, dst, count);           // exp(x)/sum(exp(x))
LayerNormF32(x, gamma, beta, dst, N);  // (x-mean)/std * gamma + beta
SiLUF32(src, dst, count);              // x * sigmoid(x)
GeluApproxF32(src, dst, count);        // x * sigmoid(1.702*x)
```

### nextpas.core.simd.linalg — 线性代数

```pascal
uses nextpas.core.simd.linalg;

var A: TSimdF32Matrix;
    X, Y: TSimdF32Array;

A := TSimdF32Matrix.Create(100, 50);
X := TSimdF32Array.Create(50);
Y := MatVecMulF32(A, X);              // y = A*x
GemvF32(2.0, A, X, 1.0, Y);           // y = 2*A*x + y
GemmF32(1.0, A, B, 0.0, C);           // C = A*B
```

### nextpas.core.simd.signal — 信号处理

```pascal
uses nextpas.core.simd.signal;

var data: array[0..1023] of TSimdComplexF32;
FftRadix2F32(@data[0], 1024, sfdForward);   // FFT
FftRadix2F32(@data[0], 1024, sfdInverse);   // IFFT

HannWindowF32(@win[0], 1024);               // SIMD 加速窗函数
Convolve1DF32(@signal[0], N, @kernel[0], K, @output[0]);
```

### nextpas.core.simd.image — 图像处理

```pascal
uses nextpas.core.simd.image;

var src, dst: TSimdImage;
src := TSimdImage.Create(1920, 1080, spfRGBA32);
dst := TSimdImage.Create(1920, 1080, spfGray8);
RgbaToGray(src, dst);
Convolve3x3(dst, dst, @sobelKernel[0]);
```
