# SIMD 当前活动计划

> 最后更新: 2026-07-17
> **权威主线**: [roadmap.md](roadmap.md)
> **Goal 队列（执行入口）**: [../math-simd/GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md)

## 当前 Goal

```text
CURRENT = M-V2  (见 GOAL_QUEUE.md)
```

| 字段 | 值 |
|------|-----|
| 阶段 | M-V2 — math residual docs + lane mode |
| 优先级 | P1 |
| 验收 | GOAL_QUEUE 卡内 GATES |

**不要在聊天里用「继续」驱动开发。** 开 goal 时只跑 `CURRENT` 卡片到 commit，并翻指针。

### 刚完成

- [x] Phase 20–23b / G0 / M-C1 / S24a / S25a / S25b
- [x] **M-V1** vec.batch Double 最小对称（Dot/Normalize/Transform/Lerp/Clamp）

### 队列摘要

- [ ] **M-V2** residual docs / lane-complete（CURRENT）
- [ ] Q1/Q2 指针与 linkage

入口命令（与卡一致）:

```bash
# docs-focused; math clean test only if residual claims need proof
make hygiene
git diff --check
```

## 非当前工作（勿抢跑）

- AddF32 stretch 6x 微优化
- 整表 BatchF64/Integer / RVV 真机
- M9 / macOS / compiler / 新 ISA

细节以 [GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md) 与 [roadmap.md](roadmap.md) 为准。
