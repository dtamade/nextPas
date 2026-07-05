{**
 * np_sema_type_check.pas
 *
 * 类型检查/推导模块 — AL2 物理分离候选
 *
 * 当前状态：逻辑分组标记。实现代码在 np_semantic_analyzer.pas 中。
 *
 * 物理分离策略（AL2 收敛期执行）：
 *   1. 提取 context record: TSemaTypeCheckContext
 *      - FModel: TSemanticModel
 *      - FDiagnostics: TDiagnosticsSink
 *      - FRootFileId: TSourceFileId
 *      - FCurrentScopeId: LongInt
 *      - FCurrentMethodClass: string
 *   2. 方法签名添加 const ctx: TSemaTypeCheckContext 参数
 *   3. 验证：compiler-pass 34/34
 *
 * 包含的方法（约 25 个方法，~1500 行）：
 *
 *   类型推导:
 *     InferExpressionType            (~行 4560)
 *     AreTypesCompatible             (~行 4920)
 *     TypeIdForVariable              (~行 2281)
 *     TypeIdForMemberReceiver        (~行 2314)
 *
 *   类型检查:
 *     CheckAssignmentTypes           (~行 5300)
 *     CheckTypeMismatches            (~行 5400)
 *     CheckTypeMismatchesInNode      (~行 5450)
 *
 *   类型查询:
 *     TypeSymbolForTypeId            (~行 2420)
 *     ClassTypeHasKnownNonMethodMember (~行 2451)
 *     TypeIdHasKnownClassLayout      (~行 2476)
 *     IsDeferredSystemObjectMember   (~行 2497)
 *     TypeInfo                       (~行 2750)
 *
 *   标量类型:
 *     ExpressionTypeFactIsStable     (~行 1840)
 *
 *   类型 ID 工具:
 *     IsIntrinsicExprName            (~行 2055)
 *     TryGetTypeCastTargetTypeId     (~行 2070)
 *     TryGetIntrinsicExprName        (~行 2101)
 *
 * 风险评估：中（25 个方法，依赖主要是 FModel）
 * 建议：AL2 收敛期第二个物理分离目标
 *}

unit np_sema_type_check;

{$mode objfpc}{$H+}

interface

implementation

end.
