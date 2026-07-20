# collections lane — Ready

**状态**：`Ready`（landing candidate）
**日期**：2026-07-20
**分支**：`collections`
**Worktree**：`.worktrees/collections`

## Git

| 项 | 值 |
|----|-----|
| HEAD | 见 `git rev-parse --short HEAD`（本提交 tip） |
| 基线 | `origin/main` @ `63ed1ee3b`（behind 0） |
| 独有提交 | 10（去噪后 9 功能/文档 + Ready 报告） |
| 工作树 | clean |

```text
docs(collections): Ready report for landing candidate
docs(collections): Wave 0 contract truth and status
feat(collections): Wave 1 MakeMap/MakeSet default factories
perf(collections): back THashSet with Swiss table map
docs(collections): cancel Wave 2 mechanical .inc splits
fix(collections): implement TSwissHashMap TCollection abstracts
docs(collections): consumers, HashSet bench, ownership audit
perf(collections): Swiss-backed MultiMap, MultiSet, and LruCache
perf(collections): Swiss-backed LinkedHashMap lookup maps
perf(collections): THashMapBuilder uses Swiss backend
```

## 保留带入

- `core/src/nextpas.core.collections*`（默认哈希族 Swiss 收敛 + adapter 契约）
- `core/tests/nextpas.core.collections/*`（facade / swiss_adapter 等）
- `core/docs/collections/*`（CONTRACT、STATUS、PERF-HASHSET、CONSUMERS、OWNERSHIP-AUDIT、READY）

## 禁止带入

- 根目录 `task_plan.collections.md` / `findings.collections.md` / `progress.collections.md` 若仍为历史 superseded，可不进主线或仅作参考
- 任何 `vecdeque.*.inc` 机械拆分产物（已不存在）
- 跨模块 TLS 迁移

## 交付摘要

1. **契约真相**：MakeXxx、Map/序列词表、FPC 门面+intf 用法、Swiss 默认文档
2. **正确性**：Swiss adapter 补齐 TCollection 抽象 + GetKeys；无 abstract 构造 warning
3. **实现收敛**：HashSet / MultiMap / MultiSet / LruCache / LinkedHashMap / Builder → Swiss；序仍由链表维护
4. **性能证据**：`PERF-HASHSET.md` 本机 bench_set 数字
5. **纪律**：取消按行数 `.inc` 拆文件；OA `THashMap` 留给专家/TLS

## Focused verification（rebase 后 smoke）

```sh
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make focused FOCUS=core/tests/nextpas.core.collections/test_facade
make focused FOCUS=core/tests/nextpas.core.collections/test_hashset
make focused FOCUS=core/tests/nextpas.core.collections/test_linkedhashmap
make focused FOCUS=core/tests/nextpas.core.collections/test_multimap
make focused FOCUS=core/tests/nextpas.core.collections/test_lrucache
make focused FOCUS=core/tests/nextpas.core.collections/test_swiss_adapter
make hygiene
```

预期：均 `0 failed`，heaptrc 0 unfreed，`build-hygiene=pass`。

全量 44 suite 曾在 Swiss 收敛后扫过实质全绿（`test_managed_stress` 输出格式无 `0 failed` 字样，实质 ALL PASS）。

## Merge 建议

- **不要** raw merge 长 lane
- 用 path-limited landing / cherry-pick 栈或 landing candidate 分支
- 路径范围：`core/src/nextpas.core.collections*`、`core/tests/nextpas.core.collections/`、`core/docs/collections/`
- land 后 collections worktree 再基于新 main 收敛

## 后续（非本 Ready 阻塞）

- 消费者驱动 bug 才再开刀
- TLS 是否迁 `MakeHashMap`：跨 lane 另议
- Serialize helper 抽公共：有第三份拷贝再做
