# nextpas.core.collections 代码契约

> 模块路径: `core/src/nextpas.core.collections.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

泛型容器子系统。提供 20+ 种数据结构，包括数组、哈希表、链表、树、队列等。
依赖 `nextpas.core.reflect` 进行 RTTI 驱动的元素管理。

---

## 容器类型

### 序列容器

| 类型 | 单元 | 特性 |
|------|------|------|
| TArray<T> | `arr.pas` | 动态数组，随机访问 O(1) |
| TDeque<T> | `deque.pas` | 双端队列，头尾操作 O(1) |
| TCircularBuffer<T> | `circularbuffer.pas` | 环形缓冲区 |
| TSortedList<T> | `arr.sort.pas` | 有序数组 |

### 关联容器

| 类型 | 单元 | 特性 |
|------|------|------|
| THashMap<K,V> | `hashmap.pas` | 开放寻址哈希表 |
| TLinkedHashMap<K,V> | `linkedhashmap.pas` | 有序插入哈希表 |
| TConcurrentHashMap<K,V> | `concurrent.hashmap.pas` | 分片并发哈希表 |
| TBTree<K,V> | `btree.pas` | B-树 |
| TLinkedHashMap<K,V> | `linkedhashmap.pas` | LRU 有序 |

### 集合

| 类型 | 单元 | 特性 |
|------|------|------|
| TBitSet | `bitset.pas` | 位集合 |
| THashSet<T> | `hashset.pas` | 哈希集合 |

### 工具

| 类型 | 单元 | 特性 |
|------|------|------|
| TCollection | `base.pas` | 集合基类 |
| TMapEntry<K,V> | `base.pas` | 键值对记录 |
| Algorithms | `algorithms.pas` | 排序/搜索/分区 |
| Builder | `builder.pas` | 流式构建器 |

---

## 关键接口

### THashMap<K,V>

```pascal
function Get(AKey: K): V;
procedure Put(AKey: K; AValue: V);
function ContainsKey(AKey: K): Boolean;
function Remove(AKey: K): Boolean;
procedure Clear;
function Count: SizeInt;
function GetOrInsert(AKey: K; ADefault: V): V;
function TryGetValue(AKey: K; out AValue: V): Boolean;
```

### Algorithms

```pascal
procedure Sort<T>(var AArr: array of T; ACompare: TComparer<T>);
function BinarySearch<T>(AArr: array of T; ATarget: T; ACompare: TComparer<T>): SizeInt;
procedure Reverse<T>(var AArr: array of T);
```

---

## 前置条件

1. HashMap: Key 类型必须支持相等比较和哈希
2. Sort: 比较函数必须满足全序关系
3. BinarySearch: 数组必须已排序

---

## 后置条件

1. HashMap.Get: ContainsKey(AKey)=true 时返回对应值
2. Sort: 排序后数组满足比较函数定义的全序
3. BinarySearch: 返回目标索引或 -1

---

## 错误语义

| 场景 | 行为 |
|------|------|
| HashMap.Get 不存在的键 | raise EInvalidArgument 或返回默认值 |
| HashMap 容量超限 | 自动扩容 |
| Sort 比较函数违反全序 | 未定义行为 |

---

## 线程安全

- 默认容器不线程安全
- `ConcurrentHashMap` 线程安全（分片锁）
- 需要并发访问时使用 sync 模块保护

---

## 内存管理

- 所有容器拥有元素生命周期
- 接口类型元素走引用计数
- 值类型元素在容器析构时释放

---

## 测试覆盖

| 套件 | 路径 |
|------|------|
| test_hashmap | `core/tests/nextpas.core.collections/test_hashmap/` |
| test_concurrent_hashmap | `core/tests/nextpas.core.collections/test_concurrent_hashmap/` |
| test_linkedhashmap | `core/tests/nextpas.core.collections/test_linkedhashmap/` |
| test_arr | `core/tests/nextpas.core.collections/test_arr/` |
| test_deque | `core/tests/nextpas.core.collections/test_deque/` |
| test_bitset | `core/tests/nextpas.core.collections/test_bitset/` |
| test_algorithms | `core/tests/nextpas.core.collections/test_algorithms/` |

---

## 依赖关系

- 依赖: base, mem, text.conv, nextpas.core.reflect, math
- 被依赖: fs, http, json, config, 几乎所有高层模块

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
