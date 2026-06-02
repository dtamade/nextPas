# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- 编译器主线进入 `C4-A`：语义模型已有 scalar width facts，typed structured lowering 可以产出 i1/i8/i32/i64/f32/f64/ptr 等真实 HIR 类型。
- 旧 blob 仍保持 legacy i64 路径；`Expr.TypeId=0` 或缺少 scalar fact 时必须回落 blob，避免半迁移破坏现有 smoke。
- 最近验证：`scripts/rebuild-compiler.sh` 输出 `44143 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. `C4-B`：补 cast/extend/trunc 与 sema promotion 规则，解决不同宽度表达式同处一棵树的问题。
2. `C4-C`：补 signedness lowering，明确 `sdiv/udiv`、`srem/urem` 与 `icmp signed/unsigned`。
3. `C5`：补 `lvalue/address` 模型，修 `P^.Field`、`@Arr[i]` 一类地址表达式。
4. `C6`：补 allocator 和真实释放。
5. `C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改 `compiler/`，不碰 `core/` 的并行工作。
- 每轮先给任务清单，再给结果报告。
- 任何编译器改动都必须过完整重编译和 137 个 smoke。
- 结构化表达式和旧 blob 现在是双轨并存，没迁移的 producer 必须能回退。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-02-c4a-scalar-width-facts.md`](../compiler/docs/plans/2026-06-02-c4a-scalar-width-facts.md)
