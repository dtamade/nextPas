{**
 * np_sema_type_check.pas
 *
 * 类型检查/推导模块 — 逻辑分组标记
 *
 * 实现代码当前编译为 TSemanticAnalyzer 的方法。
 * 物理分离（独立 unit）将在阶段 1.2f 协调器收敛时完成。
 *
 * 包含的方法类别（约 25 个方法，~1500 行）：
 *
 *   — 类型推导 —
 *   InferExpressionType            (行 4560)
 *   AreTypesCompatible             (行 4920)
 *   TypeIdForVariable              (行 2281)
 *   TypeIdForMemberReceiver        (行 2314)
 *
 *   — 类型检查 —
 *   CheckAssignmentTypes           (行 ~5300)
 *   CheckTypeMismatches            (行 ~5400)
 *   CheckTypeMismatchesInNode      (行 ~5450)
 *
 *   — 类型查询 —
 *   TypeSymbolForTypeId            (行 2420)
 *   ClassTypeHasKnownNonMethodMember (行 2451)
 *   TypeIdHasKnownClassLayout      (行 2476)
 *   IsDeferredSystemObjectMember   (行 2497)
 *   TypeInfo                       (行 ~2750)
 *
 *   — 标量类型 —
 *   ExpressionTypeFactIsStable     (行 1840)
 *
 *   — 类型 ID 工具 —
 *   IsIntrinsicExprName            (行 2055)
 *   TryGetTypeCastTargetTypeId     (行 2070)
 *   TryGetIntrinsicExprName        (行 2101)
 *
 * 状态依赖：
 *   - FModel: TSemanticModel
 *   - FDiagnostics: TDiagnosticsSink
 *   - FRootFileId: TSourceFileId
 *   - FCurrentScopeId: LongInt
 *   - FCurrentMethodClass: string
 *}

unit np_sema_type_check;

{$mode objfpc}{$H+}

interface

implementation

end.
