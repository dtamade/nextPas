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
│  nextpas.core.simd.neon       NEON 后端                   │
│  nextpas.core.simd.riscvv     RISC-V V 后端              │
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

## 派发表结构

```pascal
TSimdDispatchTable = record
  Backend: TSimdBackend;
  BackendInfo: TSimdBackendInfo;

  // 558 个函数指针槽位
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
| `docs/nextpas.core.simd.quickref.md` | 快速参考（本文件的姊妹篇） |
| `docs/nextpas.core.simd.api.md` | 详细 API 文档 |
| `docs/SIMD_INTRINSICS_DISPOSITION.md` | 各 intrinsics 单元状态 |
| `docs/SIMD_BACKEND_TRUTH.md` | 后端真相源表 |
| `docs/SIMD_SSE2_MIGRATION_MAP.md` | SSE2 迁移分桶图 |
