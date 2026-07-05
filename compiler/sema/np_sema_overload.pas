{**
 * np_sema_overload.pas
 *
 * 重载解析模块 — AL2 物理分离候选
 *
 * 当前状态：逻辑分组标记。实现代码在 np_semantic_analyzer.pas 中。
 *
 * 物理分离策略（AL2 收敛期执行）：
 *   1. 提取 context record: TSemaOverloadContext
 *      - FModel: TSemanticModel
 *      - FUnitGraph: TUnitGraph
 *      - FDiagnostics: TDiagnosticsSink
 *      - FRootFileId: TSourceFileId
 *      - FCurrentScopeId: LongInt
 *      - FCurrentMethodClass: string
 *      - FProcedureBodies: array of TProcedureBodyEntry
 *      - FCallBindings: array of TCallBinding
 *      - FPendingSignatures: array of TPendingSignature
 *   2. 方法签名添加 const ctx: TSemaOverloadContext 参数
 *   3. 所有方法变为独立函数（非 TSemanticAnalyzer 方法）
 *   4. 验证：compiler-pass 34/34
 *
 * 包含的方法（约 30 个方法，~1500 行，分布在 np_semantic_analyzer.pas 中）：
 *
 *   参数签名:
 *     DeclParamSignatureMatchesArgs  (~行 852)
 *     GetParamSignature              (~行 885)
 *     GetParamIdentitySignature      (~行 971)
 *     GetSubstitutedParamSignature   (~行 1013)
 *     CompletePendingSignatures      (~行 6500)
 *     TryBuildLegacyParamKindsFromSignature (~行 9872)
 *
 *   名称重整:
 *     MangledName     (~行 1128)
 *     MangledNameSig  (~行 1137)
 *
 *   重载查找:
 *     LookupProcedureBody            (~行 1243)
 *     HasOverload                    (~行 1260)
 *     LookupOverload                 (~行 1271)
 *     LookupCallBindingDeclaration   (~行 1289)
 *
 *   调用签名:
 *     CallArgumentSignatureIsStable  (~行 1963)
 *     CallArgumentSignature          (~行 2775)
 *     TypeSignatureForTypeId         (~行 2695)
 *
 *   成员调用绑定:
 *     TryResolveTypeNameMemberCallTarget    (~行 2340)
 *     TryRegisterMemberCallBinding          (~行 3417)
 *     TryRegisterImplicitSelfBareMethodCallBinding (~行 3532)
 *     RegisterCallBinding            (~行 3765)
 *     SeedCallBindingsInNode         (~行 3789)
 *     SeedCallBindings               (~行 4027)
 *
 *   类型解析:
 *     ResolveTypeId                  (~行 5545)
 *     ResolveTypeIdForOwner          (~行 5550)
 *     ResolveOrInstantiateInlineGeneric (~行 7462)
 *     ResolveArrayAccessElementTypeId (~行 9835)
 *
 *   调用合约:
 *     TryGetDispatchedMemberCallContract (~行 10104)
 *     TryGetDirectCallContract           (~行 10254)
 *     TryGetOrdinaryMemberCallContract   (~行 10302)
 *     BuildByRefArgumentAddressExpr      (~行 10539)
 *
 *   字段查找:
 *     LookupFieldMetaByTypeName      (~行 9595)
 *
 * 风险评估：高（30 个方法，交叉依赖 FModel/FUnitGraph/FCallBindings）
 * 建议：AL2 收敛期第一个物理分离目标
 *}

unit np_sema_overload;

{$mode objfpc}{$H+}

interface

implementation

end.
