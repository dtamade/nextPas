# nextpas.core.simd 代码契约

> 模块路径: `core/src/nextpas.core.simd.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

SIMD 加速子系统。提供跨平台向量运算、CPU 特性检测、内存工具和线性代数。
支持 SSE2/SSE3/SSSE3/SSE4.1/SSE4.2/AVX2/AVX-512/NEON/SVE/RISC-V V/LASX 后端。

---

## 模块分层

### L0: 基础

| 单元 | 职责 |
|------|------|
| `simd.base` | 基础类型和常量 |
| `simd.cpuinfo.*` | CPU 特性检测（x86/ARM/RISC-V/LoongArch） |
| `simd.dispatch` | 运行时后端选择 |
| `simd.mask` | 向量掩码操作 |

### L1: 向量原语

| 单元 | 职责 |
|------|------|
| `simd.vec16` | 128-bit 向量（SSE/NEON） |
| `simd.vec32` | 256-bit 向量（AVX2） |
| `simd.vec64` | 512-bit 向量（AVX-512） |
| `simd.vec` | 自动宽度选择（VecWidth=16 或 32） |
| `simd.sse2`/`simd.avx2`/`simd.neon`/... | 平台特化实现 |

### L2: 算法

| 单元 | 职责 |
|------|------|
| `simd.algorithms` | SIMD 加速搜索/比较 |
| `simd.memutils` | SIMD 加速内存操作 |
| `simd.mathutil` | SIMD 数学工具 |
| `simd.ops` | 向量运算操作 |
| `simd.arrays`/`simd.arrays.typed` | SIMD 数组操作 |
| `simd.pipeline` | SIMD 数据管道 |
| `simd.signal` | 信号处理 |
| `simd.stats` | 统计函数 |
| `simd.image`/`simd.imageproc` | 图像处理 |

### L3: 线性代数 & 机器学习

| 单元 | 职责 |
|------|------|
| `simd.linalg` | 线性代数 |
| `simd.linalg.gemm` | 矩阵乘法（含 Strassen） |
| `simd.nn` | 神经网络推理 |
| `simd.nn.attention` | 注意力机制 |
| `simd.nn.quantize` | 量化 |
| `simd.nn.winograd` | Winograd 卷积 |

---

## 关键接口

### 向量比较（simd.vec）

```pascal
const
  VecWidth = {$IFDEF HAS_AVX2} 32 {$ELSE} 16 {$ENDIF};

function VecCmpEq(AData: PByte; AValue: Byte): TVecMask;
function VecCmpEq2(AData, APattern: PByte): TVecMask;
function VecCmpLtU(AData: PByte; AThreshold: Byte): TVecMask;
function VecCmpGtU(AData: PByte; AThreshold: Byte): TVecMask;
function VecCmpRange(AData: PByte; ALo, AHi: Byte): TVecMask;
function VecCtz(AMask: TVecMask): Int32;
function VecFirstSet(AMask: TVecMask): Int32;
function VecPopcnt(AMask: TVecMask): Int32;
```

### CPU 特性检测

```pascal
function HasSSE2: Boolean;
function HasAVX2: Boolean;
function HasAVX512: Boolean;
function HasNEON: Boolean;
function HasSVE: Boolean;
```

---

## 前置条件

1. 向量比较: AData 必须对齐到 VecWidth
2. SIMD 数组操作: 数据长度 >= VecWidth
3. 内存工具: 源/目标不重叠（除非明确标注）

---

## 后置条件

1. `VecCmpEq`: 返回匹配字节的掩码
2. `VecCtz`: 返回最低设置位的索引
3. `VecPopcnt`: 返回设置位的数量

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 不支持的 SIMD 后端 | 自动降级到标量实现 |
| 对齐不满足 | 硬件异常（平台相关） |
| 数据长度 < VecWidth | 标量回退 |

---

## 线程安全

- 所有 SIMD 函数为纯函数，无线程安全问题
- CPU 特性检测为只读，可安全并发调用
- 可安全并发调用

---

## 内存管理

- 纯计算，无动态内存分配
- SIMD 分配器 (`simd.alloc`) 提供对齐分配

---

## 测试覆盖

| 套件 | 路径 |
|------|------|
| test_simd_* | `core/tests/nextpas.core.simd/` |

---

## 依赖关系

- 依赖: `nextpas.core.base`, `nextpas.core.platform.sync`（fence）
- 被依赖: text, collections, crypto, math

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
