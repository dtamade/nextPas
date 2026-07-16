# nextpas.core.collections 代码契约

**模块路径**：`core/src/nextpas.core.collections*.pas`（84 个源文件）
**层级**：L1（依赖 L0: base, mem, exception）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 核心接口层级

```
ICollection                    ← 非泛型根（PtrIter/Count/Clear/IsEmpty）
  ├── IList<T>                 ← 有序序列（Add/Insert/Remove/Get/Set/IndexOf）
  ├── ISet<T>                  ← 集合（Add/Remove/Contains/Union/Intersect/Diff）
  ├── IMap<K,V>                ← 映射（Put/Get/Remove/ContainsKey/Keys/Values）
  ├── IQueue<T>                ← FIFO（Enqueue/Dequeue/Peek）
  ├── IStack<T>                ← LIFO（Push/Pop/Peek）
  └── IDeque<T>                ← 双端队列（PushFront/Back, PopFront/Back）
```

### 1.2 容器实现矩阵

| 容器 | 接口 | 实现文件 | 底层结构 | IAllocator |
|------|------|----------|----------|------------|
| Vec\<T\> | IList\<T\> | vec.pas | 连续数组 | ✅ |
| Arr\<T\> | — | arr.pas | 固定大小数组 | ❌ |
| SmallVec\<T,N\> | — | smallvec.pas | 内联N+溢出 | ✅ |
| Deque\<T\> | IDeque\<T\> | deque.pas | 分段数组 | ✅ |
| VecDeque\<T\> | IDeque\<T\> | vecdeque.pas | 环形缓冲 | ✅ |
| LinkedList\<T\> | IList\<T\> | list.pas | 双向链表 | ✅ |
| ForwardList\<T\> | IList\<T\> | forward_list.pas | 单向链表 | ✅ |
| HashMap\<K,V\> | IMap\<K,V\> | hashmap.pas | 开放寻址 | ✅ |
| SwissMap\<K,V\> | IMap\<K,V\> | hashmap.swiss.pas | Swiss Table | ✅ |
| HashSet\<T\> | ISet\<T\> | hashset.pas | 哈希表 | ✅ |
| BTreeMap\<K,V\> | IMap\<K,V\> | btree.pas | B-Tree | ✅ |
| TreeMap\<K,V\> | IMap\<K,V\> | treemap.pas | 红黑树 | ✅ |
| TreeSet\<T\> | ISet\<T\> | tree_set.pas | 红黑树 | ✅ |
| SkipList\<T\> | IList\<T\> | skiplist.pas | 跳表 | ✅ |
| Trie\<T\> | — | trie.pas | 前缀树 | ✅ |
| PriorityQueue\<T\> | IQueue\<T\> | priorityqueue.pas | 二叉堆 | ✅ |
| LruCache\<K,V\> | IMap\<K,V\> | lrucache.pas | HashMap+双向链表 | ✅ |
| MultiMap\<K,V\> | — | multimap.pas | K→List\<V\> | ✅ |
| MultiSet\<T\> | — | multiset.pas | T→Count | ✅ |
| CircularBuffer\<T\> | — | circularbuffer.pas | 环形缓冲 | ✅ |
| BitSet | — | bitset.pas | 位数组 | ✅ |
| LinkedHashMap\<K,V\> | IMap\<K,V\> | linkedhashmap.pas | HashMap+链表 | ✅ |
| LinkedHashSet\<T\> | ISet\<T\> | linkedhashset.pas | HashMap+链表 | ✅ |
| ConcurrentHashMap\<K,V\> | IConcurrentMap\<K,V\> | concurrent.hashmap.pas | 分片 | ✅ |

### 1.3 内存分配器集成

所有容器通过 `IAllocator` 接口注入分配器：
- 构造时 `ResolveAllocator(nil)` / `DefaultAllocator` → **Growing IAllocator 根**（与 `DefaultHeap` 同进程堆；S5）
- 显式 RTL 仅在传入 `GetRtlAllocator` 时
- 存储在 `FAllocator: IAllocator` 字段
- 所有内部堆分配通过 FAllocator

### 1.4 基础设施

| 模块 | 文件 | 用途 |
|------|------|------|
| base | collections.base.pas | THashFn, TCompareFn 回调类型 |
| intf | collections.intf.pas | ICollection 根接口 + PtrIterator |
| element_manager | element_manager.*.pas | 泛型元素生命周期管理 |
| iterators | iterators.pas | 迭代器基础设施 |
| slice | slice.pas | 非拥有视图（类似 TByteSpan） |
| algorithms | algorithms.pas | 排序/查找/过滤算法 |
| node | node.pas | 链表节点 |
| builder | builder.pas | 流式构建器 |

### 1.5 门面

`nextpas.core.collections.pas` — re-export 所有容器类型和接口。

---

## 2. 不变量

- **[INV-1]** `FAllocator` 永远非 nil（构造时 ResolveAllocator 保证）
- **[INV-2]** Vec 容量始终为 2 的幂（SwissTable 特化要求）
- **[INV-3]** BTree 节点填充因子：每个节点 `⌈M/2⌉-1 ≤ keys ≤ M-1`
- **[INV-4]** TreeMap/TreeSet 红黑树性质：红节点的子节点必须为黑
- **[INV-5]** SkipList 最大层数有上限（通常 32）
- **[INV-6]** LRU 容量固定，Put 超出时淘汰最久未访问
- **[INV-7]** CircularBuffer 的 `Head mod Capacity` 和 `Tail mod Capacity` 始终有效
- **[INV-8]** Concurrent 内部按分片键哈希路由，分片数为 2 的幂

---

## 3. 错误处理

| 场景 | 异常 | 来源 |
|------|------|------|
| 索引越界 | EOutOfRange | base |
| 空容器 Pop/Dequeue | EEmptyCollection | base |
| nil key (HashMap) | EArgumentNil | base |
| 容量溢出 | EOverflow | base |
| OOM | 返回 nil / EOutOfMemory | mem |
| 并发修改 | 未定义行为（非线程安全容器） | — |

---

## 4. 线程安全

| 容器 | 线程安全 | 说明 |
|------|----------|------|
| Vec/Arr/SmallVec | ❌ | 调用方同步 |
| HashMap/SwissMap/HashSet | ❌ | 调用方同步 |
| BTreeMap/TreeMap/TreeSet | ❌ | 调用方同步 |
| Deque/VecDeque | ❌ | 调用方同步 |
| LinkedList/ForwardList | ❌ | 调用方同步 |
| PriorityQueue | ❌ | 调用方同步 |
| LRU Cache | ❌ | 调用方同步 |
| ConcurrentHashMap | ✅ | 分片锁 |
| CircularBuffer | ❌ | 调用方同步 |
| BitSet | ❌ | 调用方同步 |

---

## 5. 内存管理

### 5.1 所有权模型

```
容器拥有：
  ├── 内部 buffer（通过 FAllocator 分配）
  ├── 节点/段（链表、树、跳表）
  └── 元素副本（值语义，非引用）

调用方拥有：
  ├── 容器实例本身（Create/Destroy）
  └── 通过 Get/Peek 返回的值拷贝
```

### 5.2 Allocator 集成

- 所有容器支持 `Create(AAllocator: IAllocator)` 构造
- `AAllocator=nil` → `GetGrowingIAllocator` / `DefaultAllocator`（与 DefaultHeap 同进程堆）
- 内部 buffer 的 Realloc/Free 全部通过 FAllocator
- Destroy 释放所有内部 buffer，heaptrc 0 泄漏

---

## 6. 测试覆盖

### 6.1 测试矩阵（44 个测试目录）

test_base, test_bitset, test_btree_custom_comparer, test_btree_managed_lifecycle, test_btree_managed_returns, test_btreemap, test_btreeset, test_circularbuffer, test_collections_killer, test_concurrent_hashmap, test_concurrent_hashmap_managed_returns, test_contracts, test_deque, test_error_paths, test_facade, test_forwardlist, test_forwardlist_managed_zero, test_hashmap, test_hashset, test_linkedhashmap, test_linkedhashset, test_list, test_lrucache, test_managed_stress, test_managed_types, test_multimap, test_multiset, test_priorityqueue, test_queue, test_rbtreemap_custom_comparer_data, test_rbtreemap_range_managed_state, test_skiplist, test_slice_contract, test_smallvec, test_stack, test_swiss_adapter, test_swisstable, test_swisstable_custom_callbacks, test_swisstable_managed_returns, test_treemap, test_treeset, test_trie, test_vec, test_vecdeque_full

### 6.2 必须覆盖的场景

| 场景 | 状态 |
|------|------|
| 创建/销毁 0 泄漏 | ✅ (heaptrc) |
| 增删改查 CRUD | ✅ |
| 迭代器正确性 | ✅ |
| 排序/查找算法 | ✅ |
| 空容器边界 | ✅ |
| 大量元素压力 | ✅ |
| Allocator 注入 | ✅ |
| SwissTable 特化 | ✅ |
| BTree 分裂/合并 | ✅ |
| 并发容器基本安全 | ✅ |

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：84 文件 / 24 容器 / 六项契约 | Claude |
