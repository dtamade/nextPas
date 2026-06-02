# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- `C5-B` 已完成：sema producer 现在会给普通 runtime scalar assignment 中的 `@x` / `p^` 附加结构化 `ExprId`。
- `@x` 结构化为 `shekSymbolAddress -> shekAddressOf`；`p^` 结构化为 `shekDeref`，builder 仍通过 address/value 契约决定何时 load。
- 旧 blob 没移除：`varref` / `deref` 仍保留在 `Operand`，结构化 lowering 失败时继续回退。
- 最近验证：focused C3/C4/C5 tests `9/9`；`scripts/rebuild-compiler.sh` 输出 `44805 lines compiled`；LLVM smoke `137/137`，全部 exit=42。
- 本批没有引入精确 pointee metadata，也没有迁移 field/array/class/record address chain。
- C4 已完成：typed scalar 表达式已经覆盖真实宽度、显式 cast、signed/unsigned opcode、sema-side promotion，以及 legacy alloca store 归一。

## 接下来怎么走

1. `C5-C`：迁移一个 lvalue chain 切片，建议从 `@Arr[i]` 或 `P^.Field` 二选一开始。
2. `C5-D+`：逐步补齐 field/array element/class/record address chain，并减少 `$ptr`、`arr_load_ptr` 这类 blob 暗号。
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
- 当前批次：[`compiler/docs/plans/2026-06-02-c5b-address-deref-producer.md`](../compiler/docs/plans/2026-06-02-c5b-address-deref-producer.md)
