# nextpas.core.simd 代码契约

**模块路径**：`core/src/nextpas.core.simd*.pas`（84 个源文件）
**层级**：L1（依赖 L0: base, bytes, mem）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| simd.base | 基础类型（TSimdLaneInfo 等） |
| simd.backend.iface | SIMD 后端接口 |
| simd.backend.adapter | 后端适配器 |
| simd.backend.priority | 后端优先级选择 |
| simd.cpu.detect | CPU 特性检测 |
| simd.sse2 | SSE2 指令封装 |
| simd.sse41 | SSE4.1 指令封装 |
| simd.avx2 | AVX2 指令封装 |
| simd.avx512 | AVX-512 指令封装 |
| simd.neon | ARM NEON 指令封装 |
| simd.sve | ARM SVE 指令封装 |
| simd.algorithms | SIMD 加速算法 |
| simd.alloc | SIMD 对齐分配 |
| simd.arrays | SIMD 数组操作 |
| simd.arrays.typed | 类型化 SIMD 数组 |
| simd.pas | 门面 re-export |

### 1.2 ISA 扩展支持

| 扩展 | 平台 | 状态 |
|------|------|------|
| SSE2 | x86_64 | 完成 |
| SSE4.1 | x86_64 | 完成 |
| SSSE3 | x86_64 | 完成 |
| AVX2 | x86_64 | 完成 |
| AVX-512 | x86_64 | 完成 |
| NEON | AArch64 | 完成 |
| SVE | AArch64 | 完成 |
| SVE2 | AArch64 | 完成 |

### 1.3 核心 API

```pascal
// CPU 检测
function CpuHasSSE2: Boolean;
function CpuHasAVX2: Boolean;
function CpuHasNEON: Boolean;
function CpuHasSVE: Boolean;

// SIMD 对齐分配
function SimdAlloc(ASize: SizeUInt): Pointer;
procedure SimdFree(APtr: Pointer);

// SIMD 数组操作
function SimdMemCmp(ABuf1, ABuf2: Pointer; ALen: SizeInt): Integer;
function SimdMemChr(ABuf: Pointer; AByte: Byte; ALen: SizeInt): Pointer;
```

---

## 2. 不变量

- SIMD 分配地址对齐到 64 字节（AVX-512）或 32 字节（AVX2）
- 运行时 ISA 检测，未检测到时降级到标量
- 所有 SIMD 操作在 SIMD 对齐内存上执行

---

## 3. 错误处理

- ISA 不可用时静默降级
- 分配失败返回 nil

---

## 4. 线程安全

- CPU 检测缓存结果，初始化后只读
- SIMD 操作本身线程安全

---

## 5. 内存管理

- SIMD 分配使用 aligned_alloc/VirtualAlloc
- SimdFree 释放 SIMD 对齐内存

---

## 6. 测试覆盖

- `test_simd`: CPU 检测/SSE2/AVX2/NEON/算法/分配/数组操作
