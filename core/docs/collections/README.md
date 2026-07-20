# nextpas.core.collections

L1 容器库：动态数组、双端队列、哈希/有序映射与集合、链表、堆、缓存、并发 map 等。

## 读哪里

| 文档 | 内容 |
|------|------|
| [CONTRACT.md](CONTRACT.md) | **稳定契约**（接口词表、工厂、不变量、测试门禁） |
| [STATUS.md](STATUS.md) | 当前阶段、已完成目标、进行中 Wave |
| [PERF-HASHSET.md](PERF-HASHSET.md) | HashSet Swiss 本机 bench 数字 |
| [CONSUMERS.md](CONSUMERS.md) | 外部消费者审计 |
| [OWNERSHIP-AUDIT.md](OWNERSHIP-AUDIT.md) | 真职责边界（非按行数拆文件） |
| [READY.md](READY.md) | 历史 Ready / Landed 记录 |
| [ROADMAP.md](ROADMAP.md) | 维护期审查结论与工作队列 |
| 本 README | 导航与日常命令 |

设计风格见 `core/docs/design-conventions.md`。不要依赖仓库根下 `task_plan.collections.md` 等临时规划文件作为真相。

## 快速开始

```pascal
uses
  nextpas.core.collections,
  nextpas.core.collections.vec.intf,
  nextpas.core.collections.hashmap.intf;

var
  V: specialize IVec<Integer>;
  M: specialize IHashMap<string, Integer>;
begin
  V := specialize MakeVec<Integer>;
  V.Push(1);
  M := specialize MakeHashMap<string, Integer>;
  M.Put('a', 1);
end;
```

**注意（FPC 3.3.1）**：仅 `uses nextpas.core.collections` 时，open generic 接口名（`IVec` 等）通常**不可见**。工厂在门面；接口类型在对应 `*.intf`。详见 CONTRACT §0。

## 工厂一览

统一 `MakeXxx`：`MakeVec`、`MakeArr`、`MakeVecDeque`、`MakeDeque`、`MakeQueue`、`MakeStack`、`MakeList`、`MakeForwardList`、`MakeMap`、`MakeHashMap`、`MakeSwissHashMap`、`MakeSet`、`MakeHashSet`、`MakeLinkedHashMap`、`MakeLinkedHashSet`、`MakeTreeMap`、`MakeTreeSet`、`MakeRBTreeMap`、`MakeBTreeMap`、`MakeBTreeSet`、`MakeSkipList`、`MakeTrie`、`MakeMultiMap`、`MakeMultiSet`、`MakePriorityQueue`、`MakeCircularBuffer`、`MakeLruCache`、`MakeBitSet`、`MakeConcurrentHashMap`。

默认语义工厂映射（写死，变更须改 CONTRACT）：

- `MakeMap` → 与 `MakeHashMap` 相同 → **Swiss** `IHashMap`
- `MakeSet` → 与 `MakeHashSet` 相同 → **Swiss-backed** `IHashSet`

`TSmallVec<T, N>` 是 **record** 值类型（常量 N），走 `Init`/`Done`，无门面 `Make*`（无法在不指定 N 的情况下做统一工厂）。

## 选型（极简）

- 默认动态数组 → `MakeVec`
- 双端队列 → `MakeVecDeque`
- 无序 map/set → `MakeMap` / `MakeSet`（或显式 `MakeHashMap` / `MakeHashSet`）
- 有序 map/set → `MakeTreeMap` / `MakeTreeSet`
- 线程安全 map → `MakeConcurrentHashMap`
- 缓存 → `MakeLruCache`（语义不是纯 map）

完整对比见 [CONTRACT.md §5](CONTRACT.md)。

## Span 合约

`collections.slice` 提供非拥有只读视图；`SubSpan` 在越界时拒绝，不依赖溢出加法。细节见 CONTRACT 与历史说明。

## Focused gates

```sh
# 门面
make focused FOCUS=core/tests/nextpas.core.collections/test_facade

# 改 span / 范围算术后
make -C core/tests/nextpas.core.collections/test_slice_contract clean test
make -C core/tests/nextpas.core.collections/test_contracts clean test
make -C core/tests/nextpas.core.collections/test_error_paths clean test

# 单容器示例
make -C core/tests/nextpas.core.collections/test_vec clean test
make -C core/tests/nextpas.core.collections/test_vecdeque_full clean test
```

Leak-sensitive 运行应报告 heaptrc `0 unfreed memory blocks`。

## 源码布局

```
core/src/nextpas.core.collections.pas          # 门面：工厂 + re-export
core/src/nextpas.core.collections.<name>.pas   # 实现
core/src/nextpas.core.collections.<name>.intf  # 接口
core/src/nextpas.core.collections.<name>.base  # 常量/载体（按需）
core/tests/nextpas.core.collections/           # focused suites
core/benchmarks/nextpas.core.collections/      # 跨语言/微基准
```

## 模块纪律

- 软冻结公共语义：bugfix 与实现优化随时可做；补工厂需文档同步。
- 禁止为门面 re-export 制造第二套 generic interface 身份。
- 性能改动必须有 before/after bench 数据。
