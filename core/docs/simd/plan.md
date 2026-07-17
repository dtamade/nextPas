# SIMD 当前活动计划

> 最后更新: 2026-07-17
> **权威主线**: [roadmap.md](roadmap.md)
> **Goal 队列（执行入口）**: [../math-simd/GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md)

## 当前 Goal

```text
CURRENT = IDLE  (见 GOAL_QUEUE.md)
```

| 字段 | 值 |
|------|-----|
| 阶段 | IDLE — 本 lane 无在途代码目标 |
| 优先级 | — |
| 验收 | 仅 re-verify gates；勿自启 Wave 4 |

**不要在聊天里用「继续」驱动开发。** 开 goal 时只跑 `CURRENT` 卡片到 commit，并翻指针。`IDLE` 时默认停止。

### 刚完成

- [x] Phase 20–23b / Phase 25 / G0 / S24–S25 / M-C1 / M-V1 / M-V2
- [x] **Q1** 指针新鲜度（验证数 1741；清除 math README 假 Double 缺口）
- [x] **Q2** math↔simd linkage table（GOAL_QUEUE 权威表 + README 指针）

### 队列摘要

- [x] Q1 / Q2 quality wave
- [x] **IDLE**（CURRENT）

入口:

```bash
git diff --check
make hygiene
```

## 非当前工作（勿抢跑）

- M9 / macOS / RVV 真机 / compiler / 新 ISA（Wave 4 blocked）
- 新 math/simd 功能里程碑（residual 已关）

细节以 [GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md) 与 [roadmap.md](roadmap.md) 为准。
