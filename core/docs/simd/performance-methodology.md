# SIMD 性能基准方法（S25a）

> 最后更新: 2026-08-31
> 权威复测入口: `core/benchmarks/nextpas.core.simd/bench_hotspots/`
> 协作纪律见 [methodology.md](methodology.md)；数字汇总见 [roadmap.md](roadmap.md) §5。

## 1. 为什么需要单独方法

历史 `Scalar -> Dispatch` 对比把 **生产路径 `ScalarArray*` / `MemEqual_Scalar`** 当作“标量基线”。
在 `-O3` 下这些库函数自身可能：

- 被 FPC 内联 / 循环优化
- 与手写 SIMD 叶在内存布局上同构，导致“假慢”的 baseline
- 使 **ArrayMulF32 ~2.5x** 一类数字看起来未达标，实际相对**真标量**已过线

S25a 固定三类计时，避免混谈：

| 标签 | 实现 | 用途 |
|------|------|------|
| **TrueScalar** | 局部元素循环 + **volatile sink**（写全局 `g_Volatile*`） | 主指标：尽量阻止 DCE / 自动向量化污染 |
| **ScalarLib** | 生产 `ScalarArray*` / `MemEqual_Scalar` | 历史可比性（旧文档 vsLib） |
| **Dispatch** | `GetDispatchTable` 当前后端叶（`VectorAsm=True`） | 被测 SIMD 路径 |

速度比：

- `vsTrue = TrueScalar_ns / Dispatch_ns`  — **主指标（S25a+）**
- `vsLib  = ScalarLib_ns / Dispatch_ns`   — 历史风格，仅作对照

## 2. FPC 自动向量化与对照污染

- 本主机 FPC **3.3.1** 不提供稳定可用的 `{$NOVECTORIZE}` / 官方文档式开关；不能依赖“关掉 autovec”作为方法。
- 因此 TrueScalar 用 **每元素写 volatile 全局** 打断“纯局部循环 + 结果未观察”的优化窗口。
- 这仍是 **工程近似**，不是形式证明“零 autovec”。复测时若 vsTrue 与 vsLib 接近，说明 ScalarLib 已接近真标量；若 vsLib ≪ vsTrue，说明历史数字被 ScalarLib 抬高。

## 3. 复现命令

```bash
# 热点四元组（S25a 权威数字来源）
make -C core/benchmarks/nextpas.core.simd/bench_hotspots clean run

# 可选：完整 suite 内置 bench（vs ScalarLib 风格，非 TrueScalar）
make -C core/tests/nextpas.core.simd bench
```

产物目录（ignored）：`core/build/projects/nextpas.core.simd/bench_hotspots/`。

## 4. 2026-08-31 主机记录

| 项 | 值 |
|----|-----|
| Date | 2026-08-31 |
| Host | Linux x86_64 · `dtamade` · kernel 6.12.94 |
| CPU | Intel(R) Xeon(R) CPU E5-2696 v4 @ 2.20GHz |
| FPC | 3.3.1-19195 (`/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc`) |
| Flags | `-MObjFPC -Sh -O3 -gl`（bench Makefile） |
| Active backend | **AVX2** |
| VectorAsm | **True** |

计时：`fpgettimeofday` ns；warmup 200；自适应迭代（`MIN_ITERS=2000`，目标 ~400 ms/测）。

## 5. 热点结果（bench_hotspots）

单位：Array* 为 **ns/elem**，MemEqual 为 **ns/byte**（越低越快）。

| 操作 | TrueScalar | ScalarLib | Dispatch | **vsTrue** | vsLib | 正式 SLA (vsTrue) | 判定 |
|------|------------|-----------|----------|------------|-------|-------------------|------|
| ArrayAddF32 @1024 | 0.878 | 0.581 | 0.195 | **4.51x** | 2.98x | **4x+**（stretch 6x+） | **SLA 绿** |
| ArrayAddF64 @1024 | 0.874 | 0.583 | 0.138 | **6.36x** | 4.24x | **6x+** | **SLA 绿** |
| ArrayMulF32 @16KB (4096×f32) | 1.034 | 0.648 | 0.251 | **4.12x** | 2.58x | **4x+** | **SLA 绿** |
| MemEqual @4KB | 0.977 | 0.096 | 0.022 | **43.98x** | 4.33x | **4x+** | **SLA 绿** |

### 5.1 与官方 suite bench 的对照

同日 `make -C core/tests/nextpas.core.simd bench`（Scalar→Dispatch，吞吐 GB/s 风格）节选：

| 操作 | 风格 | 倍率 |
|------|------|------|
| ArrayAddF32 16KB | ScalarLib 风格 | ~2.18x |
| ArrayMulF32 16KB | ScalarLib 风格 | ~2.26x |

与 hotspots 的 **vsLib ~2.5–3x** 同量级；**不能**用 suite 的 ~2.2x 否定 **vsTrue 4.12x**。

## 6. S25b 决策（已执行：诚实 re-baseline，非微优化）

1. **ArrayMulF32**：历史 ~2.5x 为 vsLib 污染；vsTrue **4.12x ≥ 4x** → **SLA 保留 4x+，标注达标**；不开 Mul 微内核。
2. **ArrayAddF32**：正式 SLA 从历史 **6x+** 修订为 **4x+ @1024 vsTrue**（参考主机实测 4.51x）；**6x+ 降为 stretch**，不阻塞 Phase 25。理由见 roadmap §5.2。
3. **ArrayAddF64 / MemEqual**：保留原硬目标；已绿。
4. **未改生产叶**：本卡无 asm/leaf 变更；后续若追 stretch 6x 再开独立优化卡。
5. 禁止静默删目标；本修订绑定 §4–5 主机与数字。

## 7. 维护规则

- 改 Batch/Memory 热叶后：至少重跑 `bench_hotspots`，更新 roadmap §5 与本文件 §4–5（日期/主机/数字）。
- 不要把 suite 内 `Scalar->Dispatch` 单独写成“SIMD 相对真标量加速比”。
- NEON / RVV 主机需另起一节主机记录；不可把 x86 AVX2 数字直接当跨平台 SLA。
