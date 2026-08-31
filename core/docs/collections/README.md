# nextpas.core.collections

**最后更新**：2026-08-30
**版本**：1.8

L1 容器库：动态数组、双端队列、哈希/有序映射与集合、链表、堆、缓存、并发 map 等。

## 读哪里

| 文档 | 内容 |
|------|------|
| [CONTRACT.md](CONTRACT.md) | **稳定契约**（接口词表、工厂、不变量、测试门禁） |
| [CORE-API.md](CORE-API.md) | **核心 API 导读**（日常 20 方法 + 容量词表 + 有序选型） |
| [ERRORS.md](ERRORS.md) | 异常类型与文案规范 |
| [STATUS.md](STATUS.md) | 当前阶段、已完成目标、进行中 Wave |
| [PERF-HASHSET.md](PERF-HASHSET.md) | HashSet Swiss 本机 bench 数字 |
| [CONSUMERS.md](CONSUMERS.md) | 外部消费者审计 |
| [OWNERSHIP-AUDIT.md](OWNERSHIP-AUDIT.md) | 真职责边界（非按行数拆文件） |
| [READY.md](READY.md) | 历史 Ready / Landed 记录 |
| [ROADMAP.md](ROADMAP.md) | 维护期审查结论与工作队列 |
| 本 README | 导航、5 分钟路径、选型决策树 |

设计风格见 `core/docs/design-conventions.md`。不要依赖仓库根下 `task_plan.collections.md` 等临时规划文件作为真相。

## 5 分钟路径

日常 90% 场景只用这些工厂（接口优先）：

| 需求 | 工厂 | 接口单元 |
|------|------|----------|
| 动态数组 | `MakeVec` | `collections.vec.intf` |
| 无序 map | `MakeMap` / `MakeHashMap` | `collections.hashmap.intf` |
| 无序 set | `MakeSet` / `MakeHashSet` | `collections.hashset.intf` |
| 双端队列 | `MakeVecDeque` | `collections.vecdeque.intf` / `deque.intf` |
| 栈 | `MakeStack` | `collections.stack.intf` |

```pascal
uses
  nextpas.core.collections,              // MakeXxx
  nextpas.core.collections.vec.intf,     // IVec
  nextpas.core.collections.hashmap.intf; // IHashMap

var
  V: specialize IVec<Integer>;
  M: specialize IHashMap<string, Integer>;
begin
  V := specialize MakeVec<Integer>;
  V.Push(1);
  M := specialize MakeMap<string, Integer>;  // 默认 Swiss
  M.Put('a', 1);
end;
```

**注意（FPC 3.3.1）**：仅 `uses nextpas.core.collections` 时，open generic 接口名（`IVec` 等）通常**不可见**。工厂在门面；接口类型在对应 `*.intf`。详见 CONTRACT §0。

## 选型决策树

```
需要线程安全 map？
  └─ 是 → MakeConcurrentHashMap
  └─ 否 → 需要有序键？
            ├─ 是 → map: MakeTreeMap / MakeRBTreeMap / MakeBTreeMap
            │       set: MakeTreeSet（可传 TCompareFunc）/ MakeBTreeSet
            └─ 否 → 需要插入序？
                      ├─ 是 → MakeLinkedHashMap / MakeLinkedHashSet
                      └─ 否 → 序列还是 map/set？
                                ├─ 序列
                                │   ├─ 随机访问 / 尾部为主 → MakeVec
                                │   ├─ 双端 → MakeVecDeque
                                │   ├─ FIFO → MakeQueue
                                │   ├─ LIFO → MakeStack
                                │   └─ 中段频繁插删 → MakeList / MakeForwardList
                                └─ map/set
                                    ├─ 默认 → MakeMap / MakeSet（Swiss）
                                    ├─ 显式 Swiss → MakeHashMap / MakeSwissHashMap / MakeHashSet
                                    └─ 专家 OA 开放寻址 → 直构 THashMap（无默认工厂）
特殊语义：
  缓存（含淘汰）→ MakeLruCache（不是纯 map）
  优先队列 → MakePriorityQueue
  位集 → MakeBitSet
  环形缓冲 → MakeCircularBuffer
  元素自持下标的稀疏槽登记簿 → 直构 TSlotRegistry（uses collections.slotregistry）
```

### Hash 默认叙事

| 入口 | 后端 |
|------|------|
| `MakeMap` / `MakeHashMap` / `MakeSwissHashMap` | **Swiss** `IHashMap` |
| `MakeSet` / `MakeHashSet` | **Swiss-backed** `IHashSet` |
| `THashMap` 直构 | 开放寻址（OA）专家路径 |

`MakeSwissHashMap` **保留**（显式别名），不删除符号。

### 有序 map 怎么选

| 工厂 | 默认？ | 何时用 |
|------|--------|--------|
| **`MakeTreeMap`** | **是** | 通用有序 KV |
| `MakeRBTreeMap` | 否 | 显式 RB 适配 / `TCompareFunc` 管线 |
| `MakeBTreeMap` | 否 | 大 N、范围扫描、节点局部性 |

有序 set：默认 **`MakeTreeSet`**（可传 comparer）；B-Tree 用 `MakeBTreeSet`。

### 容量：`Ensure` ≠ `EnsureCapacity`

| API | 改 Count？ | 用途 |
|-----|-----------|------|
| `Ensure(n)` | **是**（不足则 Resize） | 逻辑长度至少 n |
| `EnsureCapacity(n)` | **否** | 物理容量至少 n |
| `Reserve(k)` | 否 | 再追加 k 个的 headroom |

详见 [CORE-API.md §3](CORE-API.md) 与 [CONTRACT.md §1.5](CONTRACT.md)。

## 工厂一览

统一 `MakeXxx`：`MakeVec`、`MakeArr`、`MakeVecDeque`、`MakeDeque`、`MakeQueue`、`MakeStack`、`MakeList`、`MakeForwardList`、`MakeMap`、`MakeHashMap`、`MakeSwissHashMap`、`MakeSet`、`MakeHashSet`、`MakeLinkedHashMap`、`MakeLinkedHashSet`、`MakeTreeMap`、`MakeTreeSet`、`MakeRBTreeMap`、`MakeBTreeMap`、`MakeBTreeSet`、`MakeSkipList`、`MakeTrie`、`MakeMultiMap`、`MakeMultiSet`、`MakePriorityQueue`、`MakeCircularBuffer`、`MakeLruCache`、`MakeBitSet`、`MakeConcurrentHashMap`。

`TSmallVec<T, N>` 是 **record** 值类型（常量 N），走 `Init`/`Done`，无门面 `Make*`。

完整对比见 [CONTRACT.md §5](CONTRACT.md)。异常见 [ERRORS.md](ERRORS.md)。

## Span 合约

`collections.slice` 提供非拥有只读视图；`SubSpan` 在越界时拒绝，不依赖溢出加法。细节见 CONTRACT 与历史说明。

## Focused gates

```sh
# 门面
make focused FOCUS=core/tests/nextpas.core.collections/test_facade

# FPC RTL 隔离（生产 + 测试禁止 SysUtils/Classes/…）
make -C core/tests/nextpas.core.collections/test_source_contracts clean test

# 改 span / 范围算术后
make -C core/tests/nextpas.core.collections/test_slice_contract clean test
make -C core/tests/nextpas.core.collections/test_contracts clean test
make -C core/tests/nextpas.core.collections/test_error_paths clean test

# 单容器示例
make -C core/tests/nextpas.core.collections/test_vec clean test
make -C core/tests/nextpas.core.collections/test_vecdeque_full clean test
```

Leak-sensitive 运行应报告 heaptrc `0 unfreed memory blocks`。

## Examples（可编译）

双 uses 模板 + 默认可运行路径（产物在 `core/build/`）：

```sh
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/examples/nextpas.core.collections test
# 或单个：
make -C core/examples/nextpas.core.collections/quickstart test
make -C core/examples/nextpas.core.collections/deque_queue test
make -C core/examples/nextpas.core.collections/treeset_compare test
make -C core/examples/nextpas.core.collections/capacity_ensure test
```

| 示例 | 演示 |
|------|------|
| `quickstart` | MakeVec / MakeMap / MakeSet + 门面+intf |
| `deque_queue` | MakeVecDeque 双端 + MakeQueue FIFO |
| `treeset_compare` | MakeTreeSet 默认序与自定义 comparer |
| `capacity_ensure` | **Ensure 改 Count** vs **EnsureCapacity 只改 Capacity** |

## Benchmarks

```sh
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/benchmarks/nextpas.core.collections help
make -C core/benchmarks/nextpas.core.collections bench-set   # 编译到 core/build/...
```

## 源码布局

```
core/src/nextpas.core.collections.pas          # 门面：工厂转发（inline 零拷贝，<800 行）
core/src/nextpas.core.collections.factories.pas # 工厂实现层：真实 Make* 创建逻辑
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

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-20 | 1.0 | 初版（导航、5 分钟路径、决策树、工厂一览） | collections lane |
| 2026-07-21 | 1.7 | 对齐 CONTRACT 1.7：Ensure 语义、CORE-API、有序选型 | collections lane |
| 2026-08-30 | 1.8 | 文档时效性修复：补齐最后更新/版本与变更记录，对齐周边契约 | Grok |
