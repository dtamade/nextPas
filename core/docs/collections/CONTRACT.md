# nextpas.core.collections 代码契约

**模块路径**：`core/src/nextpas.core.collections*.pas`（约 84 个单元）
**层级**：L1（依赖 L0：`base`、`mem`、`errors`/`exception`）
**Owner**：collections lane（本 worktree）
**最后更新**：2026-07-20
**版本**：1.1

权威状态见同目录 [`STATUS.md`](STATUS.md)。活动进度以本文与 STATUS 为准；根目录 `task_plan.collections.md` / `findings.collections.md` / `progress.collections.md` **不作为**当前契约源。

---

## 0. 官方用法

### 0.1 门面聚合工厂，按容器粒度引入接口

`nextpas.core.collections` 为门面聚合单元：统一提供 `MakeXxx` 工厂、回调类型与非泛型公共类型；各容器接口按容器粒度在对应 `*.intf` 单元中定义（`vec.intf` 提供 `IVec`，`hashmap.intf` 提供 `IHashMap` 等）。调用方按需以“门面 + 所需容器 `*.intf`”组合引入。

**推荐写法**：

```pascal
uses
  nextpas.core.collections,           // MakeXxx 工厂、回调类型、非泛型类型
  nextpas.core.collections.vec.intf;  // IVec / 具体容器接口

var
  V: specialize IVec<Integer>;
begin
  V := specialize MakeVec<Integer>;
  // ...
end;
```

需要哪个容器接口，就额外 `uses` 对应的 `*.intf`（或实现单元，若必须接触具体类）。

### 0.2 接口优先

- 常规路径：工厂返回接口（`IVec`、`IHashMap`…），调用方持有接口。
- 具体类（`TVec`、`THashMap`…）保留给实现、benchmark、极致性能路径。
- **不要**引入 `IMap` / `ISet` 等语义别名接口（identity 风险）。
- 工厂命名统一 **`MakeXxx`**；短工厂（`Vec` / `Set_`）已否决且不恢复。

---

## 1. 接口契约

### 1.1 能力层级（示意）

```
ICollection                          非泛型根（Count / Clear / IsEmpty / PtrIter / Allocator）
  └── IGenericCollection<T>          泛型遍历与通用能力（各容器 intf 继承）

连续数组能力：
  IArray<T>                          可变、可索引、连续存储 + 算法/块操作
    └── IVec<T>                      可增长序列（Push/Pop/Insert/Drain/…）

序列 / 队列：
  IDeque<T>                          双端；VecDeque / 分段 Deque 的公共接口
  IQueue<T>                          FIFO（Push/Pop/Peek）；实现由 VecDeque 工厂提供
  IStack<T>                          LIFO（Push/Pop/Peek）；TStack 基于 TVec
  IList<T> / IForwardList<T>         双向 / 单向链表

映射 / 集合（具体语义名，无 IMap/ISet 别名）：
  IHashMap<K,V>                      默认 Swiss Table（MakeHashMap/MakeMap）；OA THashMap 仍可专家直用
  ILinkedHashMap<K,V>                插入序哈希映射
  ITreeMap<K,V>                      红黑有序映射
  IRBTreeMap<K,V>                    有序映射适配器（orderedmap.rb）
  IBTreeMap<K,V>                     B-Tree 映射
  IHashSet<T> / ITreeSet<T> / ILinkedHashSet<T> / IBTreeSet<T>
  ISkipList<K,V> / ITrie<V>
  IMultiMap<K,V> / IMultiSet<T>
  ILruCache<K,V>                     缓存语义（Get 含命中/近用统计，不是纯 map）
  IPriorityQueue<T> / ICircularBuffer<T> / IBitSet
  IConcurrentMap<K,V>                线程安全；不继承 IHashMap
```

### 1.2 容器实现矩阵

| 容器 | 主要接口 | 实现单元 | 结构 | 门面工厂 |
|------|----------|----------|------|----------|
| Vec | `IVec` / `IArray` | `vec` | 连续动态数组 | `MakeVec` |
| Arr | `IArray` | `arr` | 连续数组能力实现 | `MakeArr` |
| SmallVec | （record，无 I*） | `smallvec` | 内联 N + 堆溢出 | **无** `Make*`（值类型 + 常量 N） |
| VecDeque | `IDeque` | `vecdeque` | 环形缓冲 | `MakeVecDeque` |
| Deque | `IDeque` | `deque` | 分段数组 | `MakeDeque` |
| Queue | `IQueue` | 由 VecDeque 工厂 | 环形 FIFO | `MakeQueue` |
| Stack | `IStack` | `stack`（`TVec` 后端） | LIFO | `MakeStack` |
| List | `IList` | `list` | 双向链表 | `MakeList` |
| ForwardList | `IForwardList` | `forward_list` | 单向链表 | `MakeForwardList` |
| HashMap (默认) | `IHashMap` | `hashmap.swiss*` | Swiss Table | `MakeHashMap` / **`MakeMap`** |
| SwissHashMap | `IHashMap` | `hashmap.swiss*` | Swiss Table（与默认相同） | `MakeSwissHashMap` |
| HashMap OA 类 | `IHashMap` | `hashmap` | 开放寻址 `THashMap` | 无默认工厂；专家直接 `THashMap` |
| HashSet | `IHashSet` | `hashset` | Swiss 后端（`TSwissHashMap<K,Byte>` 包装） | `MakeHashSet` / **`MakeSet`** |
| LinkedHashMap | `ILinkedHashMap` | `linkedhashmap` | Swiss map + 链表序 | `MakeLinkedHashMap` |
| LinkedHashSet | `ILinkedHashSet` | `linkedhashset` | LinkedHashMap 包装（插入序） | `MakeLinkedHashSet` |
| TreeMap | `ITreeMap` | `treemap` | 红黑树 | `MakeTreeMap` |
| TreeSet | `ITreeSet` | `tree_set` | 红黑集合；可选 `TCompareFunc` | `MakeTreeSet` / `MakeTreeSet(compare)` |
| RBTreeMap | `IRBTreeMap` | `orderedmap.rb` | RB 有序适配 | `MakeRBTreeMap` |
| BTreeMap / BTreeSet | `IBTreeMap` / `IBTreeSet` | `btree` | B-Tree | `MakeBTreeMap` / `MakeBTreeSet` |
| SkipList | `ISkipList` | `skiplist` | 跳表 | `MakeSkipList` |
| Trie | `ITrie` | `trie` | 前缀树（string key） | `MakeTrie` |
| MultiMap / MultiSet | `IMultiMap` / `IMultiSet` | `multimap` / `multiset` | Swiss map + Vec/计数 | `MakeMultiMap` / `MakeMultiSet` |
| PriorityQueue | `IPriorityQueue` | `priorityqueue` | 二叉堆 | `MakePriorityQueue` |
| CircularBuffer | `ICircularBuffer` | `circularbuffer` | 定长环 | `MakeCircularBuffer` |
| LruCache | `ILruCache` | `lrucache` | Swiss map + 双向链表 | `MakeLruCache` |
| BitSet | `IBitSet` | `bitset` | 位数组 | `MakeBitSet` |
| ConcurrentHashMap | `IConcurrentMap` | `concurrent.hashmap` | 分片 | `MakeConcurrentHashMap` |
| SlotRegistry | `ISlotRegistryItem` + 具体类 `TSlotRegistry<T>` | `slotregistry` | 稀疏槽 + 空闲栈 LIFO + tail-swap | 无 `Make*`（专家直构；`uses collections.slotregistry` 后 specialize。FPC 3.3.1 不能对限定名泛型做子类别名） |

### 1.3 Map 词表（HashMap / TreeMap / SkipList / Trie / RBTreeMap 等）

| 方法 | 语义 |
|------|------|
| `TryGetValue(Key, out Value): Boolean` | 非抛查找；缺失返回 False |
| `Get(Key): Value` | **checked** 查找；缺失抛异常 |
| `Put(Key, Value)` | 写入；不报告插入/更新 |
| `Add(Key, Value): Boolean` | 仅当键不存在时插入 |
| `AddOrAssign(Key, Value): Boolean` | 插入或更新；True=新插入 |

LruCache 的 `Get` 是缓存命中/近用语义，**不要**按上表改名或强行 checked。

### 1.4 序列词表

| 方法 | 语义 |
|------|------|
| `Get` / `Put`（下标） | checked；越界抛 |
| `GetUnchecked` / `PutUnchecked` | 调用方保证边界 |
| `Push` / `Pop` / `Peek` | 队列/栈/向量尾或端点；**不用** Enqueue/Dequeue |
| `Delete` / `DeleteSwap` | 按下标丢弃（保序 / 不保序） |
| `RemoveAt` / `TryRemoveAt` | 按下标取出 |
| `SwapRemoveAt` / `TrySwapRemoveAt` | 不保序取出（Vec 等） |

`IArray` = 连续存储能力基。**非连续**索引容器（环形 deque）不得继承 `IArray` 只为共享下标。

### 1.5 容量词表（Vec / IArray 系）

| 方法 | 改 `Count`？ | 参数含义 | 典型用途 |
|------|-------------|----------|----------|
| **`Ensure(n)`** | **是**（`Count < n` 时等价 `Resize(n)`，新元素初始化） | 最小**逻辑长度** | 需要可下标访问的 n 个槽 |
| **`EnsureCapacity(n)`** | **否** | 最小**物理容量** | 即将多次 `Push`，减少 realloc |
| `Resize(n)` | 是 | 精确逻辑长度 | 已知最终长度 |
| `Reserve(k)` | 否 | 为再追加 **k** 个预留（`Count+k`） | 已知还要写 k 个 |
| `ReserveExact(k)` | 否 | 同上，尽量精确分配 | 内存敏感 |
| `ShrinkToFit` / `FreeBuffer` 等 | 否 | 释放多余容量 | 峰值过后 |

**禁止**：把 `Ensure` 当成 Rust `reserve` / Go `make` 容量预留——那会**拉长 Count**。
**只预留容量**：`EnsureCapacity` 或 `Reserve` / `ReserveExact`。

块操作：`Overwrite` 不改 Count；`Write` / `WriteExact` 可扩展 Count（Exact 绕过增长策略）。

更短的「核心 20」见 [`CORE-API.md`](CORE-API.md)。

### 1.6 分配器

- 公共类型：**`TMemAllocator`**（`= IAllocator` 类型别名，见 `mem.allocator.base` / `ICollection.GetAllocator`）。
- 构造与工厂参数统一写 **`TMemAllocator`**，不在 collections 公共签名混用 `IAllocator` 标识符。
- 工厂参数 `aAllocator: TMemAllocator = nil` 时走模块默认（与 mem 默认堆路径一致）。
- 容器拥有内部 buffer / 节点；调用方拥有容器实例生命周期（接口引用计数或类 `Free` 按具体类型）。
- 整数 `HashMix32` / `HashOfUInt*` 位于 **`hashmap.base`**（`hashmap` 单元 re-export）；LruCache 等只依赖 base，不耦合 OA 实现单元。

---

## 2. 不变量

- **[INV-1]** `GetAllocator` 返回值非 nil（构造时 resolve）。
- **[INV-2]** HashMap 默认最大负载因子 `DEFAULT_MAX_LOAD_FACTOR = 0.75`。
- **[INV-3]** BTree 节点填充：`⌈M/2⌉-1 ≤ keys ≤ M-1`。
- **[INV-4]** TreeMap/TreeSet 红黑树颜色性质成立。
- **[INV-5]** SkipList 层数有上限（`SKIPLIST_MAX_LEVEL`）。
- **[INV-6]** LruCache 容量固定；超出淘汰最久未用。
- **[INV-7]** CircularBuffer head/tail 对 Capacity 取模始终有效。
- **[INV-8]** ConcurrentHashMap 分片数为 2 的幂；路由按键哈希。

---

## 3. 错误处理

文案与类型细节见 [`ERRORS.md`](ERRORS.md)。摘要：

| 场景 | 异常 / 结果 |
|------|-------------|
| 下标越界 | `EOutOfRange` |
| 空容器 checked Pop/Peek | `EEmptyCollection`（`Type.Method: empty`） |
| 映射 checked Get 键缺失 | `EInvalidOperation`（`…Get: key not found`） |
| nil 必填参数 | `EArgumentNil` |
| 非法参数 | `EInvalidArgument` |
| OOM | `EOutOfMemory` |
| 非并发容器跨线程写 | **未定义**（调用方同步） |
| Swiss ↔ OA `AppendToUnchecked` | **不互通**；勿依赖静默跨实现 bulk 合并 |

---

## 4. 线程安全

| 容器 | 线程安全 |
|------|----------|
| 普通容器 | ❌ 调用方同步 |
| `ConcurrentHashMap` | ✅ 分片锁 |

---

## 内存管理

- 所有动态容器通过注入的 `IAllocator` 分配（见 §1.6 分配器）；`GetAllocator` 构造时 resolve，非 nil（INV-1）。
- 默认使用唯一全局 allocator；用户可在构造时注入自定义 allocator。allocator 所有权归调用方，容器只借用、不释放。
- 元素按值存储；容器释放时销毁其持有的元素，元素内部资源由调用方负责（除非元素自带引用计数/析构语义）。
- 栈上小容器（`TSmallVec` 等 record 类型）不触堆；显式 `Init`/`Done`，无隐式 finalize。

---

## 5. 选型速查

| 需求 | 优先选择 |
|------|----------|
| 动态数组 / 默认序列 | `MakeVec` → `IVec` |
| 小 N、栈上临时 | `TSmallVec` record（手动 Init/Done） |
| 双端队列 | `MakeVecDeque`（通用）；`MakeDeque`（分段） |
| 无序 KV | `MakeMap` 或 `MakeHashMap`（当前均为 Swiss）；`MakeSwissHashMap` 同实现 |
| 插入序 KV | `MakeLinkedHashMap` |
| 有序 KV（默认） | **`MakeTreeMap`** |
| 有序 KV（RB 适配器入口） | `MakeRBTreeMap`（显式 `TCompareFunc` 管线） |
| 有序 KV（大块/局部性） | `MakeBTreeMap` |
| 无序集合 | `MakeSet` 或 `MakeHashSet`（当前 Swiss 包装 `THashSet`） |
| 有序集合 / 区间 | **`MakeTreeSet`**（可选 comparer）；大 N 可 `MakeBTreeSet` |
| 插入序集合 | `MakeLinkedHashSet` |
| 线程安全 map | `MakeConcurrentHashMap` → `IConcurrentMap` |
| 缓存 | `MakeLruCache`（非纯 map 词表） |

### 5.1 有序 map 选型（何时换）

| 工厂 | 结构 | 默认推荐？ | 换用动机 |
|------|------|------------|----------|
| `MakeTreeMap` | 红黑树 | **是** | 通用有序 KV / 上下界 |
| `MakeRBTreeMap` | RB 适配器 | 否 | 已绑定 `orderedmap.rb` / 统一 `TCompareFunc` 注入 |
| `MakeBTreeMap` | B-Tree | 否 | 更大 N、范围扫描、节点填充局部性 |

不必三种一起学：默认 Tree；BTree 有测量或数据形态动机再上。

---

## 6. 测试覆盖

### 6.1 Focused suites（`core/tests/nextpas.core.collections/`）

`test_base`, `test_bitset`, `test_btree_custom_comparer`, `test_btree_managed_lifecycle`, `test_btree_managed_returns`, `test_btreemap`, `test_btreeset`, `test_circularbuffer`, `test_collections_killer`, `test_concurrent_hashmap`, `test_concurrent_hashmap_managed_returns`, `test_contracts`, `test_deque`, `test_error_paths`, `test_facade`, `test_forwardlist`, `test_forwardlist_managed_zero`, `test_hashmap`, `test_hashset`, `test_linkedhashmap`, `test_linkedhashset`, `test_list`, `test_lrucache`, `test_managed_stress`, `test_managed_types`, `test_multimap`, `test_multiset`, `test_priorityqueue`, `test_queue`, `test_rbtreemap_custom_comparer_data`, `test_rbtreemap_range_managed_state`, `test_skiplist`, `test_slice_contract`, `test_slotregistry`, `test_smallvec`, `test_source_contracts`, `test_stack`, `test_swiss_adapter`, `test_swisstable`, `test_swisstable_custom_callbacks`, `test_swisstable_managed_returns`, `test_treemap`, `test_treeset`, `test_trie`, `test_vec`, `test_vecdeque_full`

### 6.2 门禁

| 场景 | 要求 |
|------|------|
| 创建/销毁 | heaptrc 0 unfreed blocks（leak-sensitive suites） |
| 公共 API | 有 focused 覆盖；改契约补测试 |
| Span 溢出 | `test_slice_contract` + `test_contracts` + `test_error_paths` |

### 6.3 常用命令

```sh
make focused FOCUS=core/tests/nextpas.core.collections/test_facade
make -C core/tests/nextpas.core.collections/test_slice_contract clean test
make -C core/tests/nextpas.core.collections/test_vec clean test
```

---

## 7. 基础设施单元

| 单元 | 用途 |
|------|------|
| `collections.base` | 增长策略、回调类型、共享抽象 |
| `collections.intf` | `ICollection` 等根契约 |
| `element_manager.*` | 元素生命周期 |
| `iterators` / `slice` / `algorithms` / `node` / `builder` | 迭代、视图、算法、节点、构建 |

---

## 变更记录

| 日期 | 版本 | 变更 |
|------|------|------|
| 2026-07-01 | 1.0 | 初版（已部分过时） |
| 2026-07-20 | 1.1 | Wave 0：对齐 MakeXxx、Map/序列词表、TMemAllocator、FPC 门面用法、真实测试矩阵；废弃 IMap/ISet/Enqueue 主叙事 |
| 2026-07-20 | 1.2 | Wave 1：`MakeMap`/`MakeSet` 默认语义工厂；文档纠正 `MakeHashMap` 当前为 Swiss 后端 |
| 2026-07-20 | 1.3 | Wave 3：`THashSet` 内部 map 从 OA `THashMap` 切换为 `TSwissHashMap` |
| 2026-07-20 | 1.4 | Phase D：MultiMap/MultiSet/LruCache 默认 Swiss；adapter 增加 `GetKeys` |
| 2026-07-20 | 1.5 | Phase E：LinkedHashMap 双表 Swiss；插入序仍由链表维护 |
| 2026-07-20 | 1.6 | 可用性 Wave：测试 RTL 隔离 + source-contract；MakeTreeSet(compare)；HashMix→base；TMemAllocator 统一；ERRORS.md；bench Makefile |
| 2026-07-21 | 1.7 | Ensure vs EnsureCapacity 对照表；有序 map 选型 §5.1；CORE-API 导读；空容器 EEmptyCollection；可编译 examples |
