# C6-H17: Class String Field Owned Store

> 设计文档，经 Codex 审议确认。record field/array/property/constructor 继续 fail-closed。

## 核心判断

先做 class field owned string store，不先做 record。record 会立刻拖出 copy/finalize 语义债；class 可以把 owner 边界限定在 field slot + object free path 上。

## H17 第一阶段覆盖范围

- `Cls.FName := MakeText()`
- `Self.FName := MakeText()`
- 可选：`Obj.Field := OwnedReturn(plain args...)`

## 继续 fail-closed

- `Rec.Name := MakeText()` — 拖出 record copy/finalize
- `Arr[0] := MakeText()` — 需要 element-level owner slot replace
- property setter — object-dot/setter special-case
- constructor arg — call-shape 未统一
- nested string-return chain — 组合爆炸
- record/class field as call arg consumer — var/out boundary

## 路线选择

新增专用 `field-store-str-owned-runtime` node，不混用旧 `field-store-str-runtime` visible path。

理由：语义清楚，fail-closed 边界清楚，builder/emitter 不污染旧 path。

## 五层改动

### 1. sema 层

新增判断函数：

- `IsSupportedOwnedStringReturnStoreTarget(ATargetNode)`
- H17-v1 只返回 true for:
  - `gnkDesignator` / `gnkDotAccess`
  - base 是 class receiver / `Self`
  - field type 是 string
  - 不是 property
  - 不是 array elem / record field / nested chain

改四处：

1. `AssignmentOwnsStringReturn` (line 970) — 不再只认 `gnkIdentifier`；class string field target 也支持；record/array 先不放开
2. `DirectOwnedStringReturnAssignmentNode` (line 1048) — RHS 是 owned return 且 LHS 是受支持的 owned consumer target
3. `NodeConsumesOwnedStringReturnDeferred` (line 1552) — 对 class field string store 加 shortcut，避免递归 RHS 报 deferred-consumer
4. `ScanOwnedStringReturnConsumers` (line 1665) — 在 supported target 上注册 producer

### 2. HIR model 层

新增 node kind：

- `hnkFieldStoreStrOwnedRuntime`
- 字符串名：`field-store-str-owned-runtime`

`np_hir_types.pas` 加两处：enum + `ParseHirNodeKind`。

### 3. sema → HIR 编码

新 node operand 编码：`<receiver>\t<fieldIndex>\t<srcTemp>`

流程：
1. `var-decl-str-owned-runtime $tmp`
2. `string-temp-owned-runtime` 或 `assign-str-owned-call-runtime` 到 temp
3. `field-store-str-owned-runtime receiver\tfieldIndex\ttmp`
4. store 完后 temp ownership 由 node consume（move into field slot）

### 4. builder 层

新增 `ProcessFieldStoreStrOwned`：

语义步骤：
1. 定位 object field 4 个 slot (field_ptr, field_len, field_owner, field_alloc_size)
2. load old owner + old alloc_size
3. `string_release(old_owner, old_alloc_size)`
4. 从 temp 取出 4 个 slot 值
5. store 到 field 4 slots
6. clear temp owner slots，避免 temp cleanup 二次释放

**前提：class string field layout 必须扩成 4-slot**。当前是 2-slot (ptr/len) visible ABI layout。
这是 H17 的主要工程量。

### 5. emitter 层

object free 路径必须补：按 class string field metadata 逐个释放 field owner。

## TDD 顺序

- RED-1: sema fail-closed contract（class field pass, record/array fail）
- RED-2: HIR shape contract（新 node kind 出现）
- RED-3: LLVM/object free contract（string_release + field cleanup）
- GREEN-1: sema consumer gating
- GREEN-2: HIR kind + builder lowering + field layout 扩展
- GREEN-3: object free cleanup
