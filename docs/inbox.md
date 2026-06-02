# nextPas 工作看板

> 这是给快速扫状态用的，不是日志。

## 当前在做什么

- 编译器主线已完成 `C4-B`：结构化表达式新增 `shekCast`，builder 可以把显式 scalar cast lower 成 typed `zext` / `sext` / `trunc`。
- 旧 blob 仍保持 legacy i64 路径；`Expr.TypeId=0`、缺少 scalar fact，或 cast 超出当前支持范围时，必须回落 blob。
- 本轮没有迁移新的 sema producer，当前只是把 C4 后续 promotion/signedness 的 builder 骨架补齐。
- 最近验证：focused tests 全绿；`scripts/rebuild-compiler.sh` 输出 `44265 lines compiled`；LLVM smoke `137/137`，全部 exit=42。

## 接下来怎么走

1. `C4-C`：补 signedness lowering，明确 `sdiv/udiv`、`srem/urem`、`icmp signed/unsigned`，并把 promotion 规则落回 sema。
2. `C5`：补 `lvalue/address` 模型，修 `P^.Field`、`@Arr[i]` 一类地址表达式。
3. `C6`：补 allocator 和真实释放。
4. `C7/C8`：多目标、优化、自举探针。

## 重要约束

- 只改 `compiler/`，不碰 `core/` 的并行工作。
- 每轮先给任务清单，再给结果报告。
- 任何编译器改动都必须过完整重编译和 137 个 smoke。
- 结构化表达式和旧 blob 现在是双轨并存，没迁移的 producer 必须能回退。

## 入口文档

- 总路线：[`compiler/docs/compiler-goal-tree.md`](../compiler/docs/compiler-goal-tree.md)
- 当前批次：[`compiler/docs/plans/2026-06-02-c4b-structured-casts.md`](../compiler/docs/plans/2026-06-02-c4b-structured-casts.md)
