# nextpas.core.collections — 维护路线图

**日期**：2026-07-20
**阶段**：Landed / 稳定维护
**范围**：仅本模块（`collections*` 源码 / tests / `docs/collections`）
**不在范围**：TLS 等跨模块迁移、机械 `.inc` 拆文件、无触发的大重构

---

## 1. 当前基线（审查结论）

### 1.1 已稳固

| 域 | 状态 |
|----|------|
| 公共接口 | 软冻结；Map/序列词表已统一 |
| 默认哈希 | 工厂与包装容器 → Swiss（见 STATUS） |
| OA `THashMap` | 保留专家路径；无默认工厂指向它 |
| Swiss adapter | TCollection 抽象 + GetKeys 已补 |
| 测试 | 44 focused suites；容器专项覆盖齐全 |
| Landing | `1f7cae0de` 已进 main |

### 1.2 体量（事实，非拆分任务）

| 单元 | 约行数 | 备注 |
|------|--------|------|
| vecdeque | ~8.9k | 大；禁止为变短切 `.inc` |
| vec | ~4.8k | 同上 |
| arr / arr.intf | ~4k / 3.5k | 同上 |
| 源文件总数 | ~83 | L1 容器库完整面 |

### 1.3 文档与代码裂缝（审查发现）

| 项 | 问题 | 优先级 |
|----|------|--------|
| `CONSUMERS.md` 模块内表 | 仍写 Multi*/Lru「视实现」；实际已 Swiss | P0 文档 |
| `test_facade` 注释 | MakeSet 仍写「OA IHashSet」 | P0 文档/注释 |
| `hashmap.intf` | 负载因子文案 0.86；常量/CONTRACT 为 0.75 | P1 契约对齐 |
| `IHashMap` 注释 | 仍写「开放寻址」为默认实现叙述 | P1 契约 |
| facade 工厂探针 | 29 个 Make* 中约一半无 facade smoke | P2 测试卫生 |
| lane 同步 | worktree 可能 behind main（维护时先 rebase） | 操作纪律 |

### 1.4 明确不是 bug

- TLS 直构 OA `THashMap`：他 lane 选择
- Concurrent 用 `TSwissTable` 分片：已是 Swiss 内核
- `vecdeque` 大文件：维护成本高，但机械拆分已否决
- 方法式算法 API 巨大：产品决策，不「为小而砍」

---

## 2. 工作队列（只做 collections）

按 **收益 / 风险 / 可验证** 排序。默认 **小步提交 + focused 验证**。

### P0 — 文档与契约卫生 — **完成**（`0125831c9` on main）

已完成：CONSUMERS 后端表、MakeSet 注释、负载因子 0.75 对齐、IHashMap Swiss/OA 叙述、STATUS→ROADMAP 指针。

### P1 — Facade 工厂烟雾补全 — **完成**（本批）

`test_facade` 新增 `TestFacadeRemainingFactorySmoke`：Arr、VecDeque、Queue、Stack、List、ForwardList、TreeMap/Set、LinkedHash*、LruCache、BTree*、BitSet、ConcurrentHashMap。深度行为仍在各专项 suite。

### P2 — 正确性 hardening（有触发才做）

触发条件：失败用例、heaptrc 泄漏、契约与实现冲突、消费者报告。

候选观察点（**无证据不开工**）：

| 观察 | 说明 |
|------|------|
| Swiss `DoZero` 语义 | 与 OA 对齐「清 value 留 key」；若无人调用可维持 |
| `AppendToUnchecked` 仅接受同类 Swiss | 跨 OA/Swiss append 会抛；是否扩展按需 |
| LruCache + HashMix 仍 uses OA unit | 仅 helper；可抽到 `hashmap.base` 减耦合（小 refactor） |
| `FIterIdx` unused note | 清理噪音，非功能 |
| managed + Swiss 包装路径 | 已有 managed suites；新后端回归时重跑 |

### P3 — 性能（必须有数字）

| 项 | 条件 |
|----|------|
| 更新 PERF-HASHSET / 补 Multi 或 Lru bench | 需要对外宣称或怀疑回退时 |
| 同机 Go/Rust peer | 可选，非阻塞 |
| wyhash 等 | **禁止**无 bench 替换 |

### P4 — 真职责（仅高重复 + 低风险）

见 `OWNERSHIP-AUDIT.md`：

- Serialize/Append helper 仅当第三份拷贝出现
- 不把 FindIf 家族硬抽到 free function
- Concurrent 保持现状

### 明确不排期

- 按行数拆 `vec` / `vecdeque` / `arr`
- open generic 单 unit 门面（FPC 限制；等编译器）
- 本 lane 改 TLS
- 为覆盖率刷无关测试

---

## 3. 建议执行顺序（下一维护周期）

```
P0  完成 → main
P1  完成 → 本批 commit / landing
  │
  ▼
停  无新触发则停；有 bug 进 P2；有 bench 需求进 P3
```

---

## 4. 质量门禁（维护期）

```sh
git fetch origin main
git rev-list --count HEAD..origin/main   # 期望 0 再改代码

make focused FOCUS=core/tests/nextpas.core.collections/test_facade
# 按改动追加：
# test_hashmap / test_hashset / test_swiss_adapter / test_vec / …

make hygiene
git diff --check
```

Landing：path-limited；`ALLOW_PATHS` 列具体文件或 `core/docs/collections` + 变更源文件；**禁止**历史触碰 planning 文件污染。

---

## 5. 成功画像（维护健康）

- 文档、intf、工厂、默认实现 **同一套说法**
- 每个 public `MakeXxx` 有 **可指认的测试入口**
- main 与 lane **behind=0** 后再开 slice
- 无「为做而做」的重构 PR
- 新 bug 有回归测试

---

## 6. 审查快照元数据

| 项 | 值 |
|----|-----|
| 审查日 | 2026-07-20 |
| 源文件 | ~83 `collections*.pas` |
| 测试目录 | 44 |
| Make* 工厂 | 29 个名称（含 overload 族） |
| facade 已探针 | ~14 名称 |
| Landing 功能 SHA | `1f7cae0de` |
