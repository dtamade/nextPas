{**
 * np_sema_overload.pas
 *
 * 重载解析模块 — 逻辑分组标记
 *
 * 实现代码当前编译为 TSemanticAnalyzer 的方法（分布在其主文件中）。
 * 物理分离（独立 unit）将在阶段 1.2f 协调器收敛时完成。
 *
 * 本文件存在的目的是：
 *   1. 标记逻辑分组边界（God Class 拆分的第三步）
 *   2. 提供可独立编译检查的 unit 骨架
 *   3. 为后续物理分离提供目标文件路径
 *
 * 包含的方法类别（约 30 个方法，~1500 行）：
 *
 *   — 参数签名 —
 *   DeclParamSignatureMatchesArgs  (行 852)
 *   GetParamSignature              (行 885)
 *   GetParamIdentitySignature      (行 971)
 *   GetSubstitutedParamSignature   (行 1013)
 *   CompletePendingSignatures      (行 6500)
 *   TryBuildLegacyParamKindsFromSignature (行 9872)
 *
 *   — 名称重整 —
 *   MangledName     (行 1128)
 *   MangledNameSig  (行 1137)
 *
 *   — 重载查找 —
 *   LookupProcedureBody            (行 1243)
 *   HasOverload                    (行 1260)
 *   LookupOverload                 (行 1271)
 *   LookupCallBindingDeclaration   (行 1289)
 *
 *   — 调用签名 —
 *   CallArgumentSignatureIsStable  (行 1963)
 *   CallArgumentSignature          (行 2775)
 *   TypeSignatureForTypeId         (行 2695)
 *
 *   — 成员调用绑定 —
 *   TryResolveTypeNameMemberCallTarget (行 2340)
 *   TryRegisterMemberCallBinding       (行 3417)
 *   TryRegisterImplicitSelfBareMethodCallBinding (行 3532)
 *   RegisterCallBinding            (行 3765)
 *   SeedCallBindingsInNode         (行 3789)
 *   SeedCallBindings               (行 4027)
 *
 *   — 类型解析 —
 *   ResolveTypeId           (行 5545)
 *   ResolveTypeIdForOwner   (行 5550)
 *   ResolveOrInstantiateInlineGeneric (行 7462)
 *   ResolveArrayAccessElementTypeId   (行 9835)
 *
 *   — 调用合约 —
 *   TryGetDispatchedMemberCallContract (行 10104)
 *   TryGetDirectCallContract           (行 10254)
 *   TryGetOrdinaryMemberCallContract   (行 10302)
 *   BuildByRefArgumentAddressExpr      (行 10539)
 *
 *   — 字段查找 —
 *   LookupFieldMetaByTypeName   (行 9595)
 *
 * 状态依赖（需在物理分离时提取为 context record）：
 *   - FModel: TSemanticModel
 *   - FUnitGraph: TUnitGraph
 *   - FDiagnostics: TDiagnosticsSink
 *   - FRootFileId: TSourceFileId
 *   - FCurrentScopeId: LongInt
 *   - FCurrentMethodClass: string
 *   - FProcedureBodies: array of TProcedureBodyEntry
 *   - FCallBindings: array of TCallBinding
 *   - FPendingSignatures: array of TPendingSignature
 *}

unit np_sema_overload;

{$mode objfpc}{$H+}

interface

implementation

end.
