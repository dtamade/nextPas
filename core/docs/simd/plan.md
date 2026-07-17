# SIMD 当前活动计划

> 最后更新: 2026-07-17  
> **权威主线**: [roadmap.md](roadmap.md)  
> **Goal 队列（执行入口）**: [../math-simd/GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md)

## 当前 Goal

```text
CURRENT = S23a  (见 GOAL_QUEUE.md)
```

| 字段 | 值 |
|------|-----|
| 阶段 | Phase 23a — NEON BatchF32 ArrayAdd/Sub/Mul |
| 优先级 | P1 |
| 验收 | GOAL_QUEUE 卡内 GATES + roadmap §6 |

**不要在聊天里用「继续」驱动开发。** 开 goal 时只跑 `CURRENT` 卡片到 commit，并翻指针。

### 刚完成

- [x] Phase 20 文档真相面
- [x] Phase 21 api-coverage
- [x] Phase 22a/22b NEON Memory 15/15
- [x] G0 Goal 队列 + 指针

### 队列摘要

- [ ] **S23a** NEON `ArrayAdd/Sub/Mul` F32（CURRENT）
- [ ] S23b Min/Max/Abs/Neg
- [ ] M-C1 math consumer smoke
- [ ] S24a RVV 诚实化
- [ ] S25 性能方法与热点
- [ ] M-V1/M-V2 math residual

入口命令（与卡一致）:

```bash
make focused FOCUS=core/tests/nextpas.core.simd
make -C core/tests/nextpas.core.simd neon-optin-focused
make hygiene
```

## 非当前工作（勿抢跑）

- 整表 BatchF64/Integer
- RVV 真机叶（无硬件）
- M9 / macOS / compiler / 新 ISA

细节以 [GOAL_QUEUE.md](../math-simd/GOAL_QUEUE.md) 与 [roadmap.md](roadmap.md) 为准。
