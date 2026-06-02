# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- `C5-A` 已完成：HIR builder 现在能区分结构化 address/value，支持 `shekSymbolAddress`、`shekAddressOf`、`shekDeref`。
- `LowerExprValue` 遇到 `shvcAddress` 会显式 load；`LowerExprAddress` 只接受真正的 address 结果。
- 本轮仍未迁移 sema producer，真实源码里的 `@x` / `P^` 目前主要还在旧 blob 路径。
- 最近验证：focused C5/C4 tests `8/8`；`scripts/rebuild-compiler.sh` 输出 `44709 lines compiled`；LLVM smoke `137/137`，全部 exit=42。
- C4 已完成：typed scalar 表达式已经覆盖真实宽度、显式 cast、signed/unsigned opcode、sema-side promotion，以及 legacy alloca store 归一。

## 接下来怎么走

1. `C5-B`：迁移一个 sema producer 切片，优先 `@x` / `P^` 标量指针表达式。
2. `C5-C+`：逐步补 field/array element address chain，修 `P^.Field`、`@Arr[i]`。
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
- 当前批次：[`compiler/docs/plans/2026-06-02-c5a-address-value-builder-skeleton.md`](../compiler/docs/plans/2026-06-02-c5a-address-value-builder-skeleton.md)
