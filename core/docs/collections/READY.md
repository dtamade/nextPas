# collections lane — Landed

**状态**：`Landed`
**日期**：2026-07-20
**Landing SHA**：`452bd0678`（可用性 Waves 0–6）
**前序功能 Landing**：`1f7cae0de`
**Remote**：已 `git push origin HEAD:main`（ff）

## 本轮合入（可用性）

1. Path-limited 候选：`origin/main` + cherry-pick 单提交
2. `make landing-check`（exact file ALLOW_PATHS）+ hygiene
3. 验证：collections **45/45** focused suites；`test_source_contracts`；`bench-set` 编译
4. `git push origin HEAD:main`
5. `collections` lane `reset --hard origin/main`；临时 landing 分支已删

### 交付摘要

| 域 | 内容 |
|----|------|
| RTL 隔离 | 测试去 SysUtils/Classes；text.conv + System IO |
| 门禁 | `test_source_contracts` |
| API | TreeSet comparer；TMemAllocator 统一；HashMix→hashmap.base |
| 文档 | README 决策树、ERRORS.md、CONTRACT 1.6 |
| Bench | `core/benchmarks/nextpas.core.collections/Makefile` |

## 当前

Lane 进入 **稳定维护**。新工作仅在有消费者痛点或可证伪 bug 时再开。

详见 [`STATUS.md`](STATUS.md)。
