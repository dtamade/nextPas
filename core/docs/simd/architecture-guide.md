# nextpas.core.simd 架构指南

> 最后更新：2026-05-23 | 反映当前代码真实状态

## 分层架构

```
┌─────────────────────────────────────────────────────────┐
│  用户代码                                                │
├─────────────────────────────────────────────────────────┤
│  Layer 1: Public Surface                                │
│  nextpas.core.simd          向量操作门面                  │
│  nextpas.core.simd.algorithms  宽度无关算法层             │
│  nextpas.core.simd.api      内存/文本工具                 │
│  nextpas.core.simd.runtime  运行时控制                    │
│  nextpas.core.simd.cpuinfo  CPU 能力检测                  │
├─────────────────────────────────────────────────────────┤
│  Layer 2: Control / Publication Seam                    │
│  nextpas.core.simd.dispatch   控制面（注册/选择/切换）    │
│  nextpas.core.simd.dataplane  数据面（已发布快照）        │
├─────────────────────────────────────────────────────────┤
│  Layer 3: Companion Surfaces                            │
│  nextpas.core.simd.direct     直接派发 companion          │
│  public ABI wrapper          外部 ABI 稳定包装          │
├─────────────────────────────────────────────────────────┤
│  Layer 4: Backend Adapters                              │
│  nextpas.core.simd.scalar     标量参考实现                │
│  nextpas.core.simd.sse2       SSE2 后端                   │
│  nextpas.core.simd.avx2       AVX2 后端                   │
│  nextpas.core.simd.neon       NEON adapter（asm opt-in）   │
│  nextpas.core.simd.riscvv     RISC-V V experimental       │
│  ... (sse3/ssse3/sse41/sse42/avx512)                    │
├─────────────────────────────────────────────────────────┤
│  Layer 5: Raw Leaves (ISA Intrinsics)                   │
│  nextpas.core.simd.intrinsics.base    基础类型 TM128      │
│  nextpas.core.simd.intrinsics.x86.sse2  SSE2 raw leaf    │
│  nextpas.core.simd.intrinsics.avx2   AVX2 raw leaf       │
│  nextpas.core.simd.intrinsics.mmx    MMX raw leaf        │
│  nextpas.core.simd.intrinsics.sse    SSE raw leaf        │
│  ... (experimental: neon/rvv/sve/aes/sha/avx/fma3)      │
└─────────────────────────────────────────────────────────┘
```

## 核心设计原则

### 1. 零开销派发

热路径只需一次 atomic_load + 一次间接调用（~3-7 cycles）：

```pascal
function VecF32x4Add(const a, b: TVecF32x4): TVecF32x4; inline;
begin
  Result := GetSimdFacadeDispatchFastPath^.AddF32x4(a, b);
end;
```

### 2. 控制面/数据面分离

- **dispatch.pas**（控制面）：后端注册、优先级排序、强制选择。需要锁保护，不频繁调用。
- **dataplane.pas**（数据面）：维护不可变快照指针。热路径只需 atomic_load，无锁。

这是网络路由器级别的设计模式——控制面变更不阻塞数据面转发。

### 3. 后端继承链

```
Scalar → SSE2 → SSE3 → SSSE3 → SSE4.1 → SSE4.2 → AVX2 → AVX-512
```

每个后端通过 `CloneDispatchTable` 继承上一级的实现，只覆盖它能加速的操作。

### 4. 单元 Disposition 规则

| Disposition | 含义 | 能被 stable adapter 依赖？ |
|-------------|------|---------------------------|
| `active leaf` | 活跃维护，有测试 | ✅ 可以 |
| `experimental isolated` | 默认隔离，需 opt-in | ❌ 不可以 |
| `retire target` | 已确认可删除 | ❌ 不可以 |

## Active Contract Boundaries

### 512-bit record alignment contract

FPC currently caps `{$CODEALIGN RECORDMIN}` at `32`, so 512-bit record types are only 64-byte payload value types. `FPC RECORDMIN=32` does not make ordinary storage 64-byte aligned. In particular, ordinary record/stack/array/object fields, variant-record fields, hidden result pointers, and by-value or `constref` parameters cannot be used as proof for AVX-512 aligned load/store.

Backend code that reads 512-bit records from ordinary Pascal storage must use unaligned-safe instructions or ordinary copy semantics. Code that needs a 64-byte address must use `SimdAlloc(..., sa64)`, `AlignedAlloc(..., SIMD_ALIGN_64)`, `TAlignedArray<T>.Create(..., SIMD_ALIGN_64)`, or another explicitly documented aligned storage owner.

### NEON public backend status

The NEON public backend status is conservative by default: default scalar fallback remains the public behavior unless the build explicitly opts into NEON assembly. Inline asm is enabled only when all of these gates hold: AArch64 target, `FPC 3.3.1+`, no `SIMD_VECTOR_ASM_DISABLED`, `NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM`, `NEXTPAS_SIMD_ENABLE_NEON_ASM`, and `NEXTPAS_SIMD_NEON_ASM_COMPILER_READY`.

The AArch64 ABI shape matters for performance. Several small vector record APIs arrive in GPRs, so the current asm path has GPR-to-vector assembly and vector-to-GPR return work (`fmov` / `ins` / `umov`) around the actual NEON operation. Benchmark reports must call out this overhead and must not claim NEON is faster until the measured workload amortizes that ABI cost.

### Experimental non-x86 backends

RISC-V V and LoongArch/LASX are experimental/stub surfaces. They can appear in source contracts, opt-in tests, or QEMU/target-machine evidence, but they must not be presented as stable public backends. Stable adapters must not depend on `experimental isolated` raw leaves by default, and tests for these surfaces stay isolated from normal x86 runs.

### Gather/scatter partial coverage

Gather/scatter partial coverage already exists. `VecF32x4Gather`, `VecI32x4Gather`, `VecF32x4Scatter`, and `VecI32x4Scatter` live in the utility layer with focused tests. Masked utility variants `VecF32x4GatherSelect`, `VecI32x4GatherSelect`, `VecF32x4ScatterSelect`, and `VecI32x4ScatterSelect` also exist and must get focused coverage before the surface expands. AVX2 raw intrinsics expose `avx2_gather_*` helpers with argument validation. The missing work is a formal public facade contract plus more lane/backend coverage, not the feature being completely absent.

Do not add gather/scatter fields to the public ABI wrapper until the public facade has tests before ABI changes. Public ABI growth is a separate stable-surface decision, not a side effect of utility helper availability.

### F16/half precision design

F16/half precision design is not a public ABI yet. The proposed boundary is:

- a scalar storage type such as `TF16` / `THalf`, with explicit conversion APIs rather than implicit arithmetic;
- conversion functions for `F32 <-> F16` and, separately, `F32 <-> BF16` when the type is introduced;
- capability detection for `F16C`, `AVX512BF16`, `AVX-512 FP16`, and `NEON FP16`;
- scalar fallback semantics that define rounding, NaN payload handling, infinities, denormals, and saturation before any backend is advertised.

No vector ABI should expose half-precision records until the type and conversion tests are stable. As with gather/scatter, public ABI wrapper changes require tests before ABI changes.

### Transpose API boundary

The transpose API boundary has two separate meanings. `linalg matrix transpose` belongs to matrix layout APIs such as `TSimdF32Matrix.Transpose` and may allocate or repack storage. `SIMD lane transpose` belongs to register-local lane rearrangement and should use explicit names such as `VecF32x4Transpose*` or `LaneTranspose*` if introduced. The two APIs must not share a vague `Transpose` facade name without the matrix/lane owner in the name or unit.

## 派发表结构

```pascal
TSimdDispatchTable = record
  Backend: TSimdBackend;
  BackendInfo: TSimdBackendInfo;

  // 616 个函数指针槽位
  AddF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  SubF32x4: function(const a, b: TVecF32x4): TVecF32x4;
  // ... 更多操作
end;
```

### 后端注册

```pascal
initialization
  RegisterSSE2Backend;  // 自动注册，填充 dispatch table
```

每个后端在 `initialization` 段自动注册。运行时根据 CPU 能力选择最优后端。

## 代码生成器 (tools/simdgen)

用于减少 boilerplate 的 Python 代码生成器：

```bash
python3 tools/simdgen/simdgen.py           # 生成 canonical type-order .inc 文件
python3 tools/simdgen/simdgen.py --verify  # 校验已提交 generated include 没有漂移
python3 tools/simdgen/simdgen.py --audit   # 审计生成器覆盖 dispatch table 的程度
```

当前 `simdgen --verify` 已是日常 `check` 的一部分：它只回答“`src/generated/nextpas.core.simd.*.inc` 是否等于 canonical 生成器输出”。如果这里红了，应先判断是否需要重新生成并审查 diff，而不是把它解释成 public surface 缺口。
当前状态：`simdgen --audit` 是生成器覆盖审计而不是完整 public surface 证明；当前快照为 438/566 slots 匹配、0 signature mismatch、0 extra，剩余 128 个槽仍由手写/专项路径负责。
默认入口的 unsigned operator 面由 `tests/nextpas.core.simd/check_public_operator_surface.py` 额外守住，防止 generated façade 声明或主门面 `VecU*` 函数扩展后漏掉 `nextpas.core.simd` operator 声明/实现。

## 验证体系

```bash
# 日常门禁
bash tests/nextpas.core.simd/BuildOrTest.sh gate

# 严格门禁（发布前）
bash tests/nextpas.core.simd/BuildOrTest.sh gate-strict

# SSE2 结构检查
python3 tests/nextpas.core.simd/check_sse2_structure.py

# 审计
python3 tools/simdgen/simdgen.py --verify
python3 tools/simdgen/simdgen.py --audit
```

## 文件索引

### 核心源码

| 文件 | 行数 | 职责 |
|------|------|------|
| `src/nextpas.core.simd.pas` | ~7500 | 公共门面 |
| `src/nextpas.core.simd.base.pas` | ~500 | 类型定义 |
| `src/nextpas.core.simd.dispatch.pas` | ~2500 | 派发表 + 控制面 |
| `src/nextpas.core.simd.dataplane.pas` | ~200 | 数据面快照 |
| `src/nextpas.core.simd.scalar.pas` | ~5000 | 标量参考实现 |
| `src/nextpas.core.simd.sse2.pas` | ~5000 | SSE2 后端 |
| `src/nextpas.core.simd.avx2.pas` | ~3000 | AVX2 后端 |
| `src/nextpas.core.simd.algorithms.pas` | ~300 | 宽度无关算法 |

### 文档

| 文件 | 用途 |
|------|------|
| `docs/simd/quickref.md` | 快速参考（本文件的姊妹篇） |
| `docs/simd/api.md` | 详细 API 文档 |
| `docs/SIMD_INTRINSICS_DISPOSITION.md` | 各 intrinsics 单元状态 |
| `docs/SIMD_BACKEND_TRUTH.md` | 后端真相源表 |
| `docs/SIMD_SSE2_MIGRATION_MAP.md` | SSE2 迁移分桶图 |

## 热路径 inline 原语层 (vec16/32/64)

> 新增于 2026-05-29

### 设计理念

dispatch 表适合批量操作（MemEqual 处理整个 buffer，一次间接调用开销可忽略），
但热路径内循环（如 SwissTable 每次 probe、text scanner 每 16 字节）不能承受
间接调用开销。vec16/32/64 提供编译期平台选择的 inline 原语，零开销。

### 架构位置

```
消费者 (hashmap.swiss, text.scanner, ...)
    │
    ▼
vec16/32/64 inline 原语层 (编译期选平台，全 inline)
    │
    ├── vec16.x86_64.inc  (SSE2 asm, 始终可用)
    ├── vec32.avx2.inc    (AVX2 asm, -dHAS_AVX2)
    ├── vec64.avx512.inc  (AVX-512 asm, -dHAS_AVX512)
    └── *.scalar.inc      (纯 Pascal fallback)
```

### 使用方式

```pascal
uses nextpas.core.simd.vec16;  // 或 vec32, vec64

var mask: TMask16;
begin
  mask := Vec16CmpEq(@data[0], needle);  // 16 字节比较，返回 bitmask
  if mask <> 0 then
    idx := Vec16Ctz(mask);               // 第一个匹配位置
end;
```

### 接口清单 (每个宽度相同)

| 函数 | 语义 |
|------|------|
| `VecNCmpEq(data, value)` | 逐字节相等比较 → bitmask |
| `VecNCmpEq2(data, pattern)` | 两块数据逐字节比较 |
| `VecNCmpLtU(data, threshold)` | 无符号小于 |
| `VecNCmpGtU(data, threshold)` | 无符号大于 |
| `VecNCmpRange(data, lo, hi)` | 范围检测 [lo, hi] |
| `VecNCtz(mask)` | 第一个 set bit，-1 if 0 |
| `VecNPopcnt(mask)` | set bit 计数 |
| `VecNAddWhere(data, mask, delta)` | 条件字节加法 |
| `VecNSubWhere(data, mask, delta)` | 条件字节减法 |

### 与 dispatch 层的关系

- dispatch 层：处理"给我整个 buffer 的结果"（ToLowerAscii, MemEqual）
- vec16/32/64 层：处理"给我这 N 字节的 mask"（probe, scan）
- 两者互补，不重叠。dispatch 后端内部可以使用相同的算法模式。
