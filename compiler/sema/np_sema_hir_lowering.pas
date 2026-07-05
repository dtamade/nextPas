{**
 * np_sema_hir_lowering.pas
 *
 * AST→HIR 降级模块 — AL2 物理分离候选
 *
 * 当前状态：逻辑分组标记。实现代码在 np_semantic_analyzer.pas 中。
 *
 * 物理分离策略（AL2 收敛期执行）：
 *   1. 提取 context record: TSemaHirLoweringContext
 *      - FHirModule: THIRModule
 *      - FModel: TSemanticModel
 *      - FDiagnostics: TDiagnosticsSink
 *      - FRootFileId: TSourceFileId
 *      - FRuntimeVarRegistry: TRuntimeVarRegistry
 *      - FOwnedStringTracker: TOwnedStringTracker
 *   2. 方法签名添加 const ctx: TSemaHirLoweringContext 参数
 *   3. 验证：compiler-pass 34/34
 *
 * 包含的方法（约 5 个方法，~3345 行）：
 *
 *   运行时表达式:
 *     BuildRuntimeScalarHirExpr       (~行 8750)
 *     AttachRuntimeReturnExpr
 *     AttachRuntimeConditionExpr
 *     EncodeRuntimeBoolExprFold
 *
 *   运行时语句降级:
 *     WalkHaltCalls
 *
 * 风险评估：高（5 个大方法共 3345 行，但方法数少，依赖复杂）
 * 建议：AL2 收敛期第三个物理分离目标
 *}

unit np_sema_hir_lowering;

{$mode objfpc}{$H+}

interface

implementation

end.
