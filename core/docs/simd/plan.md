# SIMD 当前活动计划

> 最后更新: 2026-07-17
> **权威主线**: [roadmap.md](roadmap.md)
> **Goal 队列（执行入口）**: [../math-simd/GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md)

## 当前 Goal

```text
CURRENT = M-V1  (见 GOAL_QUEUE.md)
```

| 字段 | 值 |
|------|-----|
| 阶段 | M-V1 — math vec.batch Double minimal parity |
| 优先级 | P1 |
| 验收 | GOAL_QUEUE 卡内 GATES |

**不要在聊天里用「继续」驱动开发。** 开 goal 时只跑 `CURRENT` 卡片到 commit，并翻指针。

### 刚完成

- [x] Phase 20–23b / G0 / M-C1 / S24a
- [x] **S25a** performance-methodology + `bench_hotspots`
- [x] **S25b** 诚实 re-baseline（vsTrue SLA 全绿；AddF32 正式 4x+ / stretch 6x+）

### 队列摘要

- [ ] **M-V1** math vec.batch Double 最小对称（CURRENT）
- [ ] M-V2 residual docs
- [ ] Q1/Q2 指针与 linkage

入口命令（与卡一致）:

```bash
make -C core/tests/nextpas.core.math clean test
make hygiene
```

## 非当前工作（勿抢跑）

- AddF32 stretch 6x 微优化（可选独立卡）
- 整表 BatchF64/Integer
- RVV 真机叶（无硬件）
- M9 / macOS / compiler / 新 ISA

细节以 [GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md) 与 [roadmap.md](roadmap.md) 为准。
