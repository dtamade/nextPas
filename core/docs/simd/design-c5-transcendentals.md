# C5 — NEON 超越函数设计（Wave C）

> Status: **C5–C5e-ext landed**（transc sample + vector asm for Sin/Exp/Cos/Log F32 + Sin/Exp F64）
> Updated: 2026-07-20
> Lane: `math-simd`
> Pointer: [GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md)

## 1. 问题

NEON Batch 已在 C0–C4e 覆盖代数 / 广播 / 归约 / mix / 取整 / 倒数。
`BatchSinF32` / `ArrayExpF32` 等在 ARM 上仍走 FillBase `ScalarArray*`（`System.Sin` / `System.Exp`）。
x86 已有 SSE2/AVX2 Cody-Waite + minimax 叶；NEON 需 **诚实自有路径**，禁止 `NEONX := ScalarX` 空壳注册。

## 2. 决策（锁定）

| ID | 决策 |
|----|------|
| **D1 Sample 范围** | Sin/Exp；C5b Cos/SinCos；**C5c Log/Log2/Log10** |
| **D2 算法** | 与 SSE2 同族：**Cody-Waite 归约 + minimax 多项式**；系数对齐 `sse2.batch.inc`；Cos 用 j+1 象限 |
| **D3 精度** | **near-parity** vs scalar（非 bit） |
| **D4 形态** | C5–C5d poly；**C5e/C5e-ext：Sin/Exp/Cos/Log F32 4-wide + Sin/Exp F64 2-wide asm** |
| **D5 非目标** | Log/Tan/F64 超越全表；外部 libm；改 math public ABI；raw-merge main |

### 精度验收（初始）

对有限 normal 输入：

```text
abs(a - e) <= max(8 * ulp(e), 1e-5 * abs(e), 1e-6)
```

- Sin 采样域：约 `[-4π, 4π]`
- Exp 采样域：约 `[-20, 20]`（避免 overflow 主导）
- 非有限 / 极值：与 scalar 同语义优先（允许走 `System.*` 旁路）
- `count = 0`：不写 dst

## 3. 参考实现

| 函数 | x86 参考 |
|------|----------|
| Sin | `SSE2ArraySinF32` — `core/src/nextpas.core.simd.sse2.batch.inc` |
| Exp | `SSE2ArrayExpF32` — 同文件 |

Scalar 金标准：`ScalarArraySinF32` / `ScalarArrayExpF32` → `System.Sin` / `System.Exp`。

## 4. 注册与契约

- `RegisterNEONBackend`（ASM opt-in）：`ArraySin` / `ArrayExp` / `ArrayCos` / `ArraySinCos` / `ArrayLog` / `ArrayLog2` / `ArrayLog10`
- 仍 scalar：`ArrayTan` / F64 Cos/Log / …
- F64 Sin/Exp 已注册（C5d）
- FacadeFastSlots：源码声明 + register + runtime 非 baseline（ASM 下）

## 5. 测试

- `Test_BatchF32_ArraySinExp_NearParity`
- `Test_BatchF32_ArrayCosSinCos_NearParity`
- `Test_BatchF32_ArrayLogFamily_NearParity`
- 长度 0/1/4/7/16/33；count=0 不破坏 dst
- Platform：禁止未拥有超越叶假注册

## 6. 后续切片（需新卡片）

| 卡片 | 内容 | 状态 |
|------|------|------|
| C5b | Cos / SinCos | **done** |
| C5c | Log / Log2 / Log10 | **done** |
| C5d | F64 Sin/Exp | **done** |
| C5e | AArch64 真向量 asm 提速（Sin/Exp F32） | **done** |

## 7. C6

Landing prep 与本设计无关；由总控另开。

## 8. Public numeric contract pointer

应用侧长度/错误/入口叙事见 `docs/math/CONTRACT.md` §0.1–0.3 与 `docs/math/API.md`。
本设计文只约束 NEON 超越叶算法与 near-parity 证据。
