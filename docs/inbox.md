# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- 编译器主线停在 `C3-B6`：普通标量变量赋值和 `Inc/Dec` 合成 `assign-runtime` 已接入结构化 `ExprId`，同时保留旧 blob。
- 当前结论：C3 的安全单表达式 producer 面已经足够；`call-runtime` 参数列表、`for` 合成循环赋值、field/address/lvalue 场景不适合继续用单个 `ExprId` 硬迁移。
- 最近验证：`scripts/rebuild-compiler.sh` 输出 `43803 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. `C4`：把整数宽度从单一 `i64` 推进到真实标量宽度，先设计 TypeId -> HIR type 的宽度/符号来源。
2. `C4` 后续：补 cast/extend/trunc、signedness，明确 `sdiv/udiv` 与 `icmp signed/unsigned`。
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
- 当前批次：[`compiler/docs/plans/2026-06-02-c3b6-incdec-expr-producer.md`](../compiler/docs/plans/2026-06-02-c3b6-incdec-expr-producer.md)
