# nextpas.core.collections — 核心 API 导读

**目的**：`IVec` / `IArray` 表面很大（算法与块操作齐全）。日常 90% 调用只需要下表；完整列表见对应 `*.intf`。

**用法前提（FPC 3.3.1）**：

```pascal
uses
  nextpas.core.collections,           // MakeXxx
  nextpas.core.collections.vec.intf;  // IVec 等
```

可运行模板：`core/examples/nextpas.core.collections/quickstart`。

---

## 1. 序列：`IVec` / `MakeVec`（默认路径）

| 意图 | API | 备注 |
|------|-----|------|
| 创建 | `MakeVec<T>` | 接口优先 |
| 长度 | `GetCount` / `IsEmpty` | 根集合能力 |
| 尾部增删 | `Push` / `Pop` / `TryPop` / `Peek` / `TryPeek` | 空 `Pop`/`Peek` → `EEmptyCollection` |
| 下标读写 | `Get` / `Put` | 越界 → `EOutOfRange` |
| 中段插入删除 | `Insert` / `RemoveAt` / `Delete` | `Delete` 丢弃；`RemoveAt` 取出 |
| 逻辑长度 | `Resize` / **`Ensure`** | **改 Count**（见 §3） |
| 仅容量 | **`EnsureCapacity`** / `Reserve` / `ReserveExact` | **不改 Count**（见 §3） |
| 清空 | `Clear` | |
| 释放余量 | `ShrinkToFit` | 滞回策略 |

算法（`FindIf` / `Sort` / 块 `Overwrite`…）在需要时再查 `arr.intf` / `vec.intf`，不是上手阻塞项。

---

## 2. 无序 map/set

| 意图 | Map | Set |
|------|-----|-----|
| 工厂 | `MakeMap` / `MakeHashMap`（Swiss） | `MakeSet` / `MakeHashSet` |
| 写 | `Put` / `Add` / `AddOrAssign` | `Add` |
| 读 | `TryGetValue` / checked `Get` | `Contains` |
| 删 | `Remove` | `Remove` |
| 容量 | `Reserve` / `GetCapacity` | （随内部 map） |

缺键：`Get` → 异常；`TryGetValue` → `False`。详见 [ERRORS.md](ERRORS.md)。

---

## 3. 容量词表（必读，防误用）

| API | 改 Count？ | 参数含义 | 典型场景 |
|-----|-----------|----------|----------|
| **`Ensure(n)`** | **是**（若 `Count < n` 则 `Resize(n)`，新元素初始化） | 最小**逻辑长度** | 需要「至少 n 个槽位且可下标访问」 |
| **`EnsureCapacity(n)`** | **否** | 最小**物理容量** | 即将 `Push` 多次，只想少 realloc |
| `Reserve(k)` | 否 | 为再追加 **k** 个预留（`Count+k`） | 已知还要追加 k 个 |
| `ReserveExact(k)` | 否 | 同上，尽量精确分配 | 内存敏感路径 |
| `Resize(n)` | 是 | 精确逻辑长度 | 已知最终长度 |
| `ShrinkToFit` | 否 | 可能降 Capacity | 峰值过后回收 |

**反例**：把 `Ensure` 当 `reserve` 用 → Count 被拉长，后续算法看到「假元素」。
**正例**：预分配只写 `EnsureCapacity` 或 `Reserve`。

权威对照也在 [CONTRACT.md §1.5](CONTRACT.md)。

---

## 4. 双端 / 队列 / 栈

| 意图 | 工厂 | 核心 API |
|------|------|----------|
| 双端 | `MakeVecDeque` | `PushFront`/`PushBack`/`PopFront`/`PopBack`/`Front`/`Back` |
| FIFO | `MakeQueue` | `Push`/`Pop`/`Peek`/`IsEmpty` |
| LIFO | `MakeStack` | `Push`/`Pop`/`Peek` |

空容器 checked 弹出 → **`EEmptyCollection`**（`Type.Method: empty`）。

示例：`examples/.../deque_queue`。

---

## 5. 有序容器怎么选

| 需求 | 推荐 | 何时换 |
|------|------|--------|
| 默认有序 map | **`MakeTreeMap`** | 大多数 ordered KV |
| 适配器/显式 RB 比较器入口 | `MakeRBTreeMap` | 已有 `TCompareFunc` 管线、orderedmap.rb 消费者 |
| 大块有序、范围扫描、磁盘友好布局 | **`MakeBTreeMap`** | 大 N、局部性敏感 |
| 默认有序 set | **`MakeTreeSet`** | 可 `MakeTreeSet(compare)` |
| B-Tree set | `MakeBTreeSet` | 与 BTreeMap 同场景 |

不必同时学三种 map：默认 **TreeMap/TreeSet**；BTree 有测量动机再上。

示例：`examples/.../treeset_compare`。

---

## 6. 不要默认走的路径

| 路径 | 原因 |
|------|------|
| 只 `uses nextpas.core.collections` 就写 `IVec` | FPC 3.3.1 通常找不到标识符 |
| 直构 `THashMap`（OA）当默认 map | 专家路径；默认 Swiss 用 `MakeMap` |
| `ILruCache.Get` 当纯 map Get | 含命中/近用语义 |
| Swiss 与 OA 容器互 `AppendToUnchecked` | **不互通**，会失败 |

---

## 7. 相关文档

| 文档 | 内容 |
|------|------|
| [README.md](README.md) | 5 分钟路径、决策树、examples |
| [CONTRACT.md](CONTRACT.md) | 完整契约 |
| [ERRORS.md](ERRORS.md) | 异常类型与文案 |
