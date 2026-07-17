# SIMD 当前活动计划

> 最后更新: 2026-07-17  
> **权威主线**: [roadmap.md](roadmap.md)。本文件只跟踪「当前阶段」任务，避免与路线图双写。

## 当前阶段: Phase 22 — NEON Memory 真叶

| 状态 | 下一刀（P21 已收口） |
|------|----------------------|
| 优先级 | P1 |
| 验收 | 见 roadmap §3 Phase 22 |

### 刚完成

- [x] **Phase 20** 文档真相面 + 可执行 Phase 20–27 路线图
- [x] **Phase 21** `api-coverage-contract` 变绿（missing=0 / thin=0，strict 不降）

### 本阶段任务

- [ ] 优先实现 NEON `Copy` / `Fill` / `DiffRange` 真叶（asm + register + 契约翻转）
- [ ] focused + neon-optin + hygiene 绿
- [ ] 次优槽（Reverse / BytesIndexOf / Utf8Validate）按收益拆 22b

入口命令:

```bash
make focused FOCUS=core/tests/nextpas.core.simd
make -C core/tests/nextpas.core.simd neon-optin-focused
make hygiene
```

## 非当前工作（勿抢跑）

- NEON Batch 最小面 → Phase 23  
- RVV 契约诚实 → Phase 24  
- 性能 / 编译器 → Phase 25–26  

细节、依赖与验收一律以 [roadmap.md](roadmap.md) 为准。
