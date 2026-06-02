# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- `C5-C` 已完成：builder 支持 `shekArrayElem` 作为 array element address，sema producer 支持 `@arr[i] -> shekArrayElem -> shekAddressOf`。
- 本批覆盖动态 `array of Integer` 的元素地址；`p^` 继续复用 C5-B 的 deref/value lowering。
- 旧 blob 仍保留：新增临时 fallback token `arr_elem_ref`，但结构化路径优先。
- 最近验证：focused C3/C4/C5 tests `9/9`；`scripts/rebuild-compiler.sh` 输出 `44967 lines compiled`；LLVM smoke `137/137`，全部 exit=42。
- 本批没有迁移 static array、array store、record/class field 或 `P^.Field`。
- C4 已完成：typed scalar 表达式已经覆盖真实宽度、显式 cast、signed/unsigned opcode、sema-side promotion，以及 legacy alloca store 归一。

## 接下来怎么走

1. `C5-D`：迁移 `P^.Field` 的结构化 field offset 链。
2. `C5-E+`：补齐 array store、static array、record/class field 和剩余 address chain，继续减少 `$ptr`、`arr_load_ptr` 等 blob 暗号。
3. `C6`：补 allocator 和真实释放。
4. `C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改 `compiler/`，不碰 `core/` 的并行工作。
- 每轮先给任务清单，再给结果报告。
- 任何编译器改动都必须过完整重编译和 137 个 smoke。
- 结构化表达式和旧 blob 现在是双轨并存，没迁移的 producer 必须能回退。
- 运行时 helper 如果仍是 legacy i64 ABI，typed 值必须在 builder 侧显式归一，不能靠 emitter 猜。
- 下一步不要继续修字符串暗号局部个案；C5 应先把 address/value 契约建起来。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-02-c5c-array-element-address.md`](../compiler/docs/plans/2026-06-02-c5c-array-element-address.md)
