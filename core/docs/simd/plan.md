# SIMD 当前活动计划

> 最后更新: 2026-07-17
> **权威主线**: [roadmap.md](roadmap.md)
> **Goal 队列（执行入口）**: [../math-simd/GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md)

## 当前 Goal

```text
CURRENT = Q2  (见 GOAL_QUEUE.md)
```

| 字段 | 值 |
|------|-----|
| 阶段 | Q2 — math↔simd linkage table |
| 优先级 | P2 |
| 验收 | GOAL_QUEUE 卡内 GATES |

**不要在聊天里用「继续」驱动开发。** 开 goal 时只跑 `CURRENT` 卡片到 commit，并翻指针。

### 刚完成

- [x] Phase 20–23b / Phase 25 / G0 / S24–S25 / M-C1 / M-V1 / M-V2
- [x] **Q1** 指针新鲜度（验证数 1741；清除 math README 假 Double 缺口）

### 队列摘要

- [ ] **Q2** math↔simd linkage（CURRENT）
- [ ] IDLE

入口:

```bash
git diff --check
make hygiene
```

## 非当前工作（勿抢跑）

- M9 / macOS / RVV 真机 / compiler / 新 ISA（Wave 4 blocked）
- 新 math/simd 功能里程碑（residual 已关）

细节以 [GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md) 与 [roadmap.md](roadmap.md) 为准。
