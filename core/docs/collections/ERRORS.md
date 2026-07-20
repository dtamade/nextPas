# nextpas.core.collections — 错误与异常约定

**范围**：`core/src/nextpas.core.collections*.pas`
**最后更新**：2026-07-20

---

## 1. 文案规范

统一格式：

```text
Type.Method: reason
```

示例：

| 场景 | 文案 |
|------|------|
| 空容器 Pop | `TVec.Pop: empty` / `TVecDeque.PopFront: empty` |
| 空容器 First/Last | `TVecDeque.First: empty` |
| 键缺失 checked Get | `THashMap.Get: key not found` |
| 越界 | `Span.Get: index out of range` |
| nil 参数 | `TNodeManager.Create: aAllocator cannot be nil` |
| 分配失败 | `TSwissTable.AllocBuffers: ctrl allocation failed` |

**空容器统一类型**：`EEmptyCollection`（不要用 `EOutOfRange` / `EInvalidOperation` 表示「空」）。

避免仅写 `collection is empty` / `key not found` 而无类型/方法上下文。

---

## 2. 异常类型表（collections 内）

| 类型 | Owner 单元 | 何时用 |
|------|------------|--------|
| `EInvalidArgument` | `nextpas.core.base` | 参数非法但非 nil（容量 0、回调不成对、重叠写等） |
| `EArgumentNil` | `nextpas.core.base` | 必填指针/接口为 nil |
| `EOutOfRange` | `nextpas.core.base` | 索引/范围越界 |
| `EEmptyCollection` | collections / base 路径 | 空容器上的 checked Pop/Peek/First/Last |
| `EInvalidOperation` | `nextpas.core.base` | 状态不允许（checked Get 缺键、不支持的操作） |
| `ENotSupported` / `ENotSupportedError` | base / exception | 类型无默认 hasher/comparer 等 |
| `EOutOfMemory` | exception / base | 分配失败 |
| `EArgumentError` | exception（via errors） | **避免在 collections 新代码使用**；优先 `EInvalidArgument` |

`TryXxx` 路径：**不**因「未找到 / 空」抛异常；返回 `False`。

---

## 3. 操作语义 ↔ 失败形态

| 操作族 | 失败形态 |
|--------|----------|
| checked `Get(Index)` / `Put(Index)` | `EOutOfRange` |
| checked map `Get(Key)` | `EInvalidOperation`（key not found） |
| `TryGetValue` / `TryPop` / `Contains` | `Boolean`，无异常 |
| 空 `Pop` / `Peek` / `Front` / `First` / `Last` | `EEmptyCollection` |
| nil 缓冲区 / nil allocator（必填） | `EArgumentNil` |
| 自定义类型无 hash/compare 且未注入 | `ENotSupported*` |

---

## 4. Swiss / OA 差异

- 默认工厂 `MakeHashMap` / `MakeMap` → Swiss（`TSwissHashMap`）。
- 专家路径 `THashMap`（OA）直构；二者 `AppendToUnchecked` **不互通**（见 CONTRACT）。
- 特化表（i32 / str / i32i32）分配失败与缺键消息遵循 §1。

---

## 5. 回归

改异常类型或文案时至少跑：

```sh
make -C core/tests/nextpas.core.collections/test_error_paths clean test
make -C core/tests/nextpas.core.collections/test_facade clean test
```
