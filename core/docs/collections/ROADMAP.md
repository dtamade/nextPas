# nextpas.core.collections — 维护路线图

**日期**：2026-07-20（二次审查）
**阶段**：Landed / **维护 idle**
**范围**：仅本模块（`collections*` 源码 / tests / `docs/collections`）
**不在范围**：TLS 等跨模块迁移、机械 `.inc` 拆文件、无触发的大重构

---

## 1. 当前基线（二次审查结论）

### 1.1 已稳固

| 域 | 状态 |
|----|------|
| 公共接口 | 软冻结；Map/序列词表已统一 |
| 默认哈希 | 工厂与包装容器 → Swiss（见 STATUS） |
| OA `THashMap` | 保留专家路径；无默认工厂指向它 |
| Swiss adapter | TCollection 抽象 + GetKeys 已补 |
| 测试专项 | 44 focused suites |
| Facade 工厂 | **Make\* 29/29** 有烟雾探针（`TestFacadeRemainingFactorySmoke`） |
| 功能 Landing | `1f7cae0de` 已进 main |
| P0 文档卫生 | `0125831c9` 已进 main |
| P1 facade 烟雾 | `3ce508865` 已进 main |

### 1.2 体量（事实，非拆分任务）

| 单元 | 约行数 | 备注 |
|------|--------|------|
| vecdeque | ~8.9k | 大；禁止为变短切 `.inc` |
| vec | ~4.8k | 同上 |
| arr / arr.intf | ~4k / 3.5k | 同上 |
| 源文件总数 | ~83 | L1 容器库完整面 |

### 1.3 已关闭的裂缝（初审 → 已修）

| 项 | 初审问题 | 现状 |
|----|----------|------|
| CONSUMERS 模块内表 | Multi/Lru「视实现」 | **已 Swiss** |
| MakeSet 注释 | 写 OA | **Swiss-backed** |
| 负载因子 | intf 0.86 vs 常量 0.75 | **统一 0.75** |
| IHashMap 默认实现叙述 | 像默认 OA | **默认 Swiss / 专家 OA** |
| facade 工厂探针 | 约一半缺失 | **29/29** |

### 1.4 明确不是 bug

- TLS 直构 OA `THashMap`：他 lane 选择
- Concurrent 用 `TSwissTable` 分片：已是 Swiss 内核
- `vecdeque` 大文件：维护成本高，但机械拆分已否决
- 方法式算法 API 巨大：产品决策，不「为小而砍」

### 1.5 二次审查观察点（非开工令）

| ID | 观察 | 触发才做 |
|----|------|----------|
| O1 | lane 易 behind main | **每次改代码前** `fetch + rebase` |
| O2 | Swiss adapter `FIterIdx` unused note | 清理编译噪音时 |
| O3 | LruCache uses `hashmap` 仅 HashMix helper | 抽到 `hashmap.base` 减耦合时 |
| O4 | Swiss/OA `AppendToUnchecked` 不互通 | 有跨实现 bulk append 需求时 |
| O5 | vec/vecdeque 大体量 | **禁止**机械 `.inc`；仅真职责拆分 |
| O6 | PERF-HASHSET 为旧机数字 | 对外宣称性能时同机重跑 |
| O7 | TLS 仍 OA 直构 | **跨 lane**，本模块不排期 |

---

## 2. 工作队列

### P0 — 文档与契约卫生 — **完成**（`0125831c9`）

### P1 — Facade 工厂烟雾 — **完成**（`3ce508865`）

### P2 — 正确性 hardening（有触发才做）

触发：失败用例、heaptrc 泄漏、契约冲突、消费者报告。
候选见 §1.5 O2–O4；**无证据不开工**。

### P3 — 性能（必须有数字）

| 项 | 条件 |
|----|------|
| 更新 PERF-HASHSET / Multi/Lru bench | 对外宣称或怀疑回退 |
| wyhash 等 | **禁止**无 bench 替换 |

### P4 — 真职责（仅高重复 + 低风险）

见 `OWNERSHIP-AUDIT.md`。Serialize helper 仅第三份拷贝出现时。

### 明确不排期

- 按行数拆 `vec` / `vecdeque` / `arr`
- open generic 单 unit 门面
- 本 lane 改 TLS
- 为覆盖率刷无关测试

---

## 3. 维护姿态

```
P0/P1 已完成并进 main
  │
  ▼
idle  无新触发则停
  │
  ├─ bug / 泄漏 / 契约冲突 → P2
  └─ 性能数字需求 → P3
```

---

## 4. 质量门禁

```sh
git fetch origin main
git rev-list --count HEAD..origin/main   # 期望 0 再改代码

make focused FOCUS=core/tests/nextpas.core.collections/test_facade
make hygiene
git diff --check
```

Landing：path-limited；`ALLOW_PATHS` 列具体文件；禁止 planning 文件污染历史。

---

## 5. 成功画像

- 文档、intf、工厂、默认实现同一套说法
- 每个 public `MakeXxx` 有 facade 烟雾入口
- main 与 lane behind=0 后再开 slice
- 无「为做而做」的重构 PR

---

## 6. 审查快照元数据

| 项 | 值 |
|----|-----|
| 二次审查日 | 2026-07-20 |
| 源文件 | ~83 |
| 测试目录 | 44 |
| Make* 工厂 | 29；facade 探针 29/29 |
| 功能 Landing | `1f7cae0de` |
| P0 | `0125831c9` |
| P1 | `3ce508865` |
