# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- 编译器主线已完成 `C4-E`，C4 可以收口：typed scalar 表达式已经能表达真实宽度、显式 cast、signed/unsigned opcode、sema-side promotion，以及 legacy alloca store 边界归一。
- 结构化路径里，typed integer 表达式已经覆盖真实宽度、显式 cast、signed/unsigned LLVM opcode，以及 mixed-width integer common type。
- 旧 blob 仍保持 legacy i64 路径；`Expr.TypeId=0`、缺少 scalar fact，或未迁移到 typed 路径的表达式，继续回落 blob。
- `var-decl-runtime` alloca 暂不切真实宽度；typed scalar 写入 legacy i64 alloca 时，builder 先按槽类型插入 `sext/zext/trunc`，再 `store i64`。
- 最近验证：focused C4 tests `7/7`；`scripts/rebuild-compiler.sh` 输出 `44547 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. `C5`：补 `lvalue/address` 模型，建立 `EmitAddress` vs `EmitValue`，修 `P^.Field`、`@Arr[i]` 一类地址表达式。
2. `C6`：补 allocator 和真实释放。
3. `C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改 `compiler/`，不碰 `core/` 的并行工作。
- 每轮先给任务清单，再给结果报告。
- 任何编译器改动都必须过完整重编译和 137 个 smoke。
- 结构化表达式和旧 blob 现在是双轨并存，没迁移的 producer 必须能回退。
- 运行时 helper 如果仍是 legacy i64 ABI，typed 值必须在 builder 侧显式归一，不能靠 emitter 猜。
- 下一步不要继续修字符串暗号局部个案；C5 应先把 address/value 契约建起来。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-02-c4e-legacy-alloca-store-normalization.md`](../compiler/docs/plans/2026-06-02-c4e-legacy-alloca-store-normalization.md)
