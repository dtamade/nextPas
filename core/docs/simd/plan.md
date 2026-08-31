# SIMD 当前活动计划

> 最后更新: 2026-08-31
> **权威主线**: [roadmap.md](roadmap.md)
> **Goal 队列（执行入口）**: [../math-simd/GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md)
> **维护态**: [../math-simd/MAINTENANCE.md](../math-simd/MAINTENANCE.md)

## 当前 Goal

```text
CURRENT = IDLE  (见 GOAL_QUEUE.md)
```

| 字段 | 值 |
|------|-----|
| 阶段 | IDLE — 本 lane 无在途代码目标（M0 maintenance re-verify 2026-08-31 已记） |
| 优先级 | — |
| 验收 | 仅 re-verify gates；勿自启 Wave 4；债务见 MAINTENANCE.md |

**不要在聊天里用「继续」驱动开发。** 开 goal 时只跑 `CURRENT` 卡片到 commit，并翻指针。`IDLE` 时默认停止。

### 刚完成

- [x] Phase 20–23b / Phase 25 / G0 / S24–S25 / M-C1 / M-V1 / M-V2
- [x] **Q1** 指针新鲜度（验证数 1741；清除 math README 假 Double 缺口）
- [x] **Q2** math↔simd linkage table（GOAL_QUEUE 权威表 + README 指针）
- [x] **V0/D0**（2026-08-31）接管复验 + Phase 23 标题/API surface 指针对齐
- [x] **Batch B1** NEON `ArrayDivF32`（单测 + 叶 + math smoke；1742 passed）
- [x] **Batch B2** NEON MulScalar/AddScalar（1743 passed）
- [x] **Batch B3** NEON Clamp/Lerp（1744 passed）
- [x] **Batch B4** NEON Fma/Axpy（1745 passed）
- [x] **Batch B5** NEON Sqrt/ReduceSum（1746 passed）
- [x] **Batch B6** NEON ReduceMin/Max（1747 passed）
- [x] **Batch B7** NEON Rcp/ReduceDot（1748 passed）
- [x] **Batch B8** NEON Rsqrt/RcpRefine（1749 passed）
- [x] **Batch B9** RsqrtRefine + **代表集 23 叶 closed**（1750 passed）
- [x] **Wave C0/C1** ArrayLinear（1751 passed）
- [x] **Wave C2** Ceil/Floor/Trunc（1752 passed）
- [x] **Wave C3** ReLU/AbsDiff（1753 passed）
- [x] **Wave C4a** BatchF64 core 8（1754 passed）
- [x] **Wave C4b** BatchF64 Sqrt/broadcast/Reduce（1755 passed）
- [x] **Wave C4c** BatchF64 Linear/Clamp/Lerp/Fma/Axpy（1756 passed）
- [x] **Wave C4d** BatchF64 Ceil/Floor/Trunc/ReLU/AbsDiff（1757 passed）
- [x] **Wave C4e** BatchF64 Rcp/Rsqrt/Refine（1758 passed）
- [x] **Wave C5** 超越 design + Sin/Exp F32 sample（1759 passed）
- [x] **Wave C5b** Cos/SinCos F32（1760 passed）
- [x] **Wave C5c** Log/Log2/Log10 F32（1761 passed）
- [x] **Wave C5d** F64 Sin/Exp（1762 passed）
- [x] **Wave C5e** F32 Sin/Exp 4-wide NEON asm（1762 passed）
- [x] **Wave C5e-ext** Cos/Log F32 + Sin/Exp F64 vector asm（1762 passed）
- [x] **M0 maintenance**（2026-08-31）：FF main + re-verify 1762/math 71/0 + `MAINTENANCE.md`

### 队列摘要

- [x] B1–B9 代表集 closed
- [x] Wave C0–C4e + C5–C5e-ext done
- [ ] C6 Landing
- [x] **IDLE**（CURRENT；见 GOAL_QUEUE）

入口:

```bash
git diff --check
make hygiene
```

## 非当前工作（勿抢跑）

- M9 / macOS / RVV 真机 / compiler / 新 ISA（Wave 4 blocked）
- 新 math/simd 功能里程碑（residual 已关）

细节以 [GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md) 与 [roadmap.md](roadmap.md) 为准。
