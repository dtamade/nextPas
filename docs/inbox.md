# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- 编译器主线停在 `C3-B3`：`ret-runtime` 已接入结构化 `ExprId`，同时保留旧 `Operand` blob。
- 本轮核心取舍：`ret-runtime` 先表达“读取返回槽变量”，不回溯 `Result := ...` 的原始表达式树。
- 最近验证：`scripts/rebuild-compiler.sh` 输出 `43694 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. `C3-B4`：迁移 `cond-br` producer，让运行时条件分支优先走结构化表达式。
2. `C4`：把整数宽度从单一 `i64` 推进到真实标量宽度。
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
- 批次计划：[`compiler/docs/plans/2026-06-01-c3b1-halt-expr-producer.md`](../compiler/docs/plans/2026-06-01-c3b1-halt-expr-producer.md)
- 上一批次：[`compiler/docs/plans/2026-06-01-c3b2-write-int-expr-producer.md`](../compiler/docs/plans/2026-06-01-c3b2-write-int-expr-producer.md)
- 当前批次：[`compiler/docs/plans/2026-06-01-c3b3-ret-runtime-expr-producer.md`](../compiler/docs/plans/2026-06-01-c3b3-ret-runtime-expr-producer.md)
