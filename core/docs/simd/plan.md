# SIMD 当前活动计划

> 最后更新: 2026-07-17  
> **权威主线**: [roadmap.md](roadmap.md)。本文件只跟踪「当前阶段」任务，避免与路线图双写。

## 当前阶段: Phase 20 — 文档与真相面收口

| 状态 | 进行中 |
|------|--------|
| 优先级 | P0 |
| 验收 | 见 roadmap §3 Phase 20 |

### 任务清单

- [x] 盘点文档/代码覆盖缺口与验证真相
- [x] 重写 `roadmap.md` 为可执行 Phase 20+
- [x] 对齐 `README.md` 入口与验证数字
- [x] 标注历史 plan 为 archived（不删历史）
- [x] 修正 `methodology.md` 失效引用
- [ ] 用户确认 Phase 20–27 范围与默认下一刀（P21）

### 确认后下一阶段

**Phase 21 — api-coverage-contract 变绿**  
入口命令:

```bash
make -C core/tests/nextpas.core.simd api-coverage-contract
make focused FOCUS=core/tests/nextpas.core.simd
```

## 非当前工作（勿抢跑）

- NEON Memory 真叶 → Phase 22  
- NEON Batch 最小面 → Phase 23  
- RVV / 性能 / 编译器 → Phase 24–26  

细节、依赖与验收一律以 [roadmap.md](roadmap.md) 为准。
