# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- `C5-I` 已完成：array-of-record-field `arr[i].Field := rhs` 已生成结构化 nested target：`shekField -> shekArrayElem -> index`。
- `shekArrayElem` 现在携带语义元素类型；aggregate array element 可以作为 address base，作为 value load 仍要求 concrete scalar HIR type。
- `C5-H` 能力保留：direct static array `arr[i] := rhs` 与 `@arr[i]` 已接入结构化 target/address producer。
- `assign-arr-elem-runtime` 现在在保留旧 operand/blob 的同时，为 direct array element store 附加 RHS `ExprId` 与 LHS `TargetExprId`。
- static/dynamic array 仍共用 `shekArrayElem`，static 语义依赖 C5-H0 的 bounds/backing metadata 与 builder lower-bound normalization。
- `C5-H0` 能力保留：先补静态数组基础，而不是直接做 static array target/address。
- parser 现在保留 `array[lo..hi] of T` bounds；sema 区分 static/dynamic array 并记录 low/high/len；builder 给 static array 建真实存储，并在访问时做 low-bound index normalization。
- 静态数组仍复用现有 `arr$ptr` / `arr$len` 通道，旧 blob fallback 保留。
- `C5-G` 已完成：普通动态数组 `arr[i] := rhs` 的 LHS 现在可以走独立 `TargetExprId` target/address 通道。
- builder 对普通 `assign-arr-elem-runtime` 优先 `LowerExprAddress(TargetExprId)`，成功时不再解析 legacy index；失败时仍回落旧 operand/blob。
- sema producer 为普通 runtime `array of Integer` store 生成 `shekArrayElem(ValueClass=shvcAddress)` target，index child 仍是结构化 scalar expr。
- `C5-F` 能力保留：`TTypedHirNode.TargetExprId` 是独立 LHS target/address 通道，`ExprId` 继续只表示 RHS。
- `field-store-runtime` / `record-field-store-runtime` 继续优先通过 `LowerExprAddress(TargetExprId)` 得到 LHS 地址，失败时仍回落旧 operand target。
- sema producer 已覆盖普通 `record.field := rhs`、方法内 `self.field := rhs` 和 `obj.field := rhs` target：
  `record -> shekField -> shekSymbolAddress`，`class/self -> shekField -> shekDeref -> shekSymbolValue`。
- `C5-E` 能力保留：field store / record field store 的 RHS 可以走结构化 `ExprId`，失败时仍回落旧 blob。
- `C5-D` 能力保留：builder 支持 `shekField` 作为 field address，sema producer 支持 `@p^.Field -> shekAddressOf -> shekField -> shekDeref -> shekSymbolValue`。
- `shekDeref` 现在可作为 non-scalar aggregate address base；字段值仍由 `LowerExprValue` 显式 load。
- 旧 blob 仍保留：新增临时 fallback token `field_ref`；C5-C 的 `arr_elem_ref` 继续保底 array element address。
- 最近验证：focused C3/C4/C5 tests `9/9`；`scripts/rebuild-compiler.sh` 输出 `46013 lines compiled`；LLVM smoke `137/137`，全部 exit=42。
- 本批没有迁移字段数组 `self.Items[i]`、更深 `arr[i].A.B` field chain 或 class/object RHS 特殊分支。
- C4 已完成：typed scalar 表达式已经覆盖真实宽度、显式 cast、signed/unsigned opcode、sema-side promotion，以及 legacy alloca store 归一。

## 接下来怎么走

1. `C5-J`：字段数组 `self.Items[i]` 或更深 `arr[i].A.B` field chain，继续减少 `$ptr`、`arr_load_ptr` 等 blob 暗号。
2. `C5-K`：收口 class/object RHS 特殊分支和剩余 array/field store producer。
3. `C6`：补 allocator 和真实释放。
4. `C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改 `compiler/`，不碰 `core/` 的并行工作。
- 每轮先给任务清单，再给结果报告。
- 任何编译器改动都必须过完整重编译和 137 个 smoke。
- 结构化表达式和旧 blob 现在是双轨并存，没迁移的 producer 必须能回退。
- `ExprId` 是 RHS value 通道；`TargetExprId` 是 LHS address 通道，不要混用。
- 运行时 helper 如果仍是 legacy i64 ABI，typed 值必须在 builder 侧显式归一，不能靠 emitter 猜。
- 下一步不要继续修字符串暗号局部个案；C5 应先把 address/value 契约建起来。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-03-c5i-array-record-field-target.md`](../compiler/docs/plans/2026-06-03-c5i-array-record-field-target.md)
