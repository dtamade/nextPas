{**
 * np_sema_hir_lowering.pas
 *
 * AST→HIR 降级模块 — 逻辑分组标记
 *
 * 实现代码已内联到 np_semantic_analyzer.pas（前 {$I np_sema_runtime_expr.inc}）。
 * 物理分离为独立类将在后续迭代中完成。
 *
 * 包含的方法类别（约 5 个方法，~3345 行）：
 *
 *   — 运行时表达式 —
 *   BuildRuntimeScalarHirExpr       (行 ~8750)
 *   AttachRuntimeReturnExpr
 *   AttachRuntimeConditionExpr
 *   EncodeRuntimeBoolExprFold
 *
 *   — 运行时语句降级 —
 *   WalkHaltCalls
 *}

unit np_sema_hir_lowering;

{$mode objfpc}{$H+}

interface

implementation

end.
