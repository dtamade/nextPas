{**
 * np_sema_string_ownership.pas
 *
 * 字符串所有权分析模块 — 从 TSemanticAnalyzer 提取
 *
 * 职责：
 *   - 字符串返回检测（StringReturnFunctionNameFromNode, FunctionCallReturnsString 等）
 *   - Owned string return 消费分析（IsSupportedOwned*, AssignmentOwns* 等）
 *   - 临时变量发射（EmitOwned*Temp）
 *   - 所有权扫描编排（ScanOwned*, CheckDeferred*, PreRegister*）
 *   - 清理节点发射（EmitOwned*CleanupNodes）
 *
 * 所有函数接收 const Ctx: TSemaOwnershipContext 作为第一个参数，
 * 通过回调访问 TSemanticAnalyzer 的方法。
 *
 * 对标：rustc 的 borrowck 模块（简化版）
 *}

unit np_sema_string_ownership;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.syntax.green_tree, np_semantic_model, np_hir_types,
  nextpas.compiler.diagnostics.sink, np_base_types, nextpas.compiler.syntax.ast_facade,
  np_unit_graph, np_sema_runtime_vars, np_source_database,
  np_sema_overload;

type
  { Context record — 打包 TSemanticAnalyzer 中 SO 方法需要的所有依赖 }
  TSemaOwnershipContext = record
    Model: TSemanticModel;
    CurrentScopeId: LongInt;
    CurrentMethodClass: string;
    CurrentRetVarName: string;
    CurrentBlockTerminated: Boolean;
    BlockLabelCounter: LongInt;
    Diagnostics: TDiagnosticsSink;
    RootFileId: TSourceFileId;
    RootAst: TAstFacade;
    UnitGraph: TUnitGraph;
    CurrentProcessingUnitId: string;
    ProcedureBodies: TProcedureBodyVec;
    RuntimeVars: TSemaRuntimeVarRegistry;
    { Callback context pointer — 指向 TSemanticAnalyzer 实例 }
    CallbackCtx: Pointer;
    { Callbacks for methods still owned by TSemanticAnalyzer }
    LookupProcedureBody: function(const ACtx: Pointer; const AName: string;
      out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
    DeclReturnsString: function(const ACtx: Pointer;
      const ADecl: TGreenNode): Boolean;
    LookupClassVar: function(const ACtx: Pointer;
      const AName: string): string;
    TypeMetaRetStr: function(const ACtx: Pointer;
      const ATypeName, AMethodName: string): Boolean;
    IsRuntimeStrVar: function(const ACtx: Pointer;
      const AName: string): Boolean;
    IsOwnedStringReturnFunc: function(const ACtx: Pointer;
      const AName: string): Boolean;
    RegisterOwnedStringReturnFunc: procedure(const ACtx: Pointer;
      const AName: string);
    IsRuntimeVar: function(const ACtx: Pointer;
      const AName: string): Boolean;
    RegisterRuntimeStrVar: procedure(const ACtx: Pointer;
      const AName: string);
    RegisterRuntimeVar: procedure(const ACtx: Pointer;
      const AName: string);
    HasOverload: function(const ACtx: Pointer;
      const AName: string): Boolean;
    EffectiveRuntimeCalleeName: function(const ACtx: Pointer;
      const AName: string): string;
    EmitSemaError: procedure(const ACtx: Pointer;
      const ACode, AMessage: string; const AByteOffset: LongInt);
    EncodeRuntimeIntExprFold: function(const ACtx: Pointer;
      const ANode: TGreenNode; out ABlob: string): Boolean;
    BuildRuntimeScalarHirExpr: function(const ACtx: Pointer;
      const ANode: TGreenNode; out AExprId: LongInt): Boolean;
    IsVarParamAtPosition: function(const ACtx: Pointer;
      const ADecl: TGreenNode; APosition: LongInt): Boolean;
    IsBorrowedRuntimeStrVar: function(const ACtx: Pointer;
      const AName: string): Boolean;
    IsBorrowedRuntimeArrVar: function(const ACtx: Pointer;
      const AName: string): Boolean;
    IsStaticRuntimeArrVar: function(const ACtx: Pointer;
      const AName: string): Boolean;
    DynArrayElemSizeOfVar: function(const ACtx: Pointer;
      const AName: string): Int64;
    EvaluateStringConstant: function(const ACtx: Pointer;
      const ANode: TGreenNode; out AValue: string): Boolean;
    TypeMetaFieldIndex: function(const ACtx: Pointer;
      const ATypeName, AFieldName: string): Int64;
    TypeMetaFieldIsStr: function(const ACtx: Pointer;
      const ATypeName, AFieldName: string): Boolean;
    DecodePascalStringLiteral: function(const ACtx: Pointer;
      const AText: string): string;
    { B2+ callbacks }
    CanEmitStrConcatOperand: function(const ACtx: Pointer;
      const SOwnCtx: TSemaOwnershipContext; const ANode: TGreenNode): Boolean;
    EmitStrConcatOperand: function(const ACtx: Pointer;
      const SOwnCtx: TSemaOwnershipContext; const ANode: TGreenNode;
      const ADestVar: string): string;
    ConcatTreeHasSupportedOwnedStringReturn: function(const ACtx: Pointer;
      const SOwnCtx: TSemaOwnershipContext; const ANode: TGreenNode): Boolean;
    NodeConsumesOwnedStringReturnDeferred: function(const ACtx: Pointer;
      const SOwnCtx: TSemaOwnershipContext; const ANode: TGreenNode;
      const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
  end;

{ === B1: String return 检测 === }
function StringReturnFunctionNameFromNode(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out AName: string): Boolean;
function FunctionCallReturnsString(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode): Boolean;
function MemberCallReturnsString(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode): Boolean;
function TypeIdIsManagedString(const Ctx: TSemaOwnershipContext;
  const ATypeId: LongInt): Boolean;

{ === B2: IsSupported* + Owns* detection + Emit* temps === }
function IsRootOwnedStringReturnCandidate(const Ctx: TSemaOwnershipContext;
  const AEntry: TProcedureBodyEntry; const AIsStrReturn: Boolean): Boolean;
function IsSupportedOwnedStringReturnIdentifierTarget(
  const Ctx: TSemaOwnershipContext; const ATargetNode: TGreenNode): Boolean;
function IsSupportedOwnedStringReturnStoreTarget(
  const Ctx: TSemaOwnershipContext; const ATargetNode: TGreenNode): Boolean;
function IsSupportedOwnedStringReturnConsumerTarget(
  const Ctx: TSemaOwnershipContext; const ATargetNode: TGreenNode): Boolean;
function AssignmentOwnsStringReturn(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; const AEntry: TProcedureBodyEntry): Boolean;
function AssignmentOwnsTopLevelStringReturn(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode): Boolean;
function CallArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext;
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt;
  out AFuncName: string): Boolean;
function DirectOwnedStringReturnAssignmentNode(
  const Ctx: TSemaOwnershipContext; const ANode: TGreenNode): Boolean;
function IsSupportedOwnedStringReturnArgument(const Ctx: TSemaOwnershipContext;
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt): Boolean;
function LengthArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out AFuncName: string): Boolean;
function IsSupportedOwnedStringReturnLengthArgument(
  const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  out AFuncName: string): Boolean;
function EmitOwnedStringLengthTemp(var Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out ABlob: string): Boolean;
function CopyArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out AFuncName: string): Boolean;
function IsSupportedOwnedStringReturnCopyArgument(
  const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  out AFuncName: string): Boolean;
function EmitOwnedStringCopyTemp(var Ctx: TSemaOwnershipContext;
  const ACopyNode: TGreenNode; const ADestName: string;
  out ATempName: string): Boolean;
function WriteArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out AFuncName: string): Boolean;
function IsSupportedOwnedStringReturnWriteArgument(
  const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  out AFuncName: string): Boolean;
function EmitOwnedStringWriteTemp(var Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out ATempName: string): Boolean;
function ConcatOperandOwnsStringReturn(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out AFuncName: string): Boolean;
function IsSupportedOwnedStringReturnConcatOperand(
  const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  out AFuncName: string): Boolean;
function CompareOperandOwnsStringReturn(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out AFuncName: string): Boolean;
function IsSupportedOwnedStringReturnCompareOperand(
  const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  out AFuncName: string): Boolean;

{ === B3: Deferred ownership analysis + Concat/Compare support === }
function EmitOwnedStringConcatLengthTemp(var Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out ABlob: string): Boolean;
function EmitOwnedStringConcatWriteTemp(var Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out ATempName: string): Boolean;
function ConcatExpressionConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
function BoolConditionHasSupportedOwnedStringCompare(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
function CompareExpressionConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
function NodeConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode;
  const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
procedure ScanOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; const AEntry: TProcedureBodyEntry;
  var AChanged: Boolean);
procedure CheckDeferredOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode);
procedure PreRegisterOwnedStringReturnConsumers(var Ctx: TSemaOwnershipContext);
procedure EmitOwnedStringCleanupNodes(const Ctx: TSemaOwnershipContext; const AExceptName: string);
procedure EmitOwnedDynArrayCleanupNodes(const Ctx: TSemaOwnershipContext);
procedure EmitOwnedManagedRecordCleanupNodes(const Ctx: TSemaOwnershipContext);
function ConcatTreeHasSupportedOwnedStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
function CanEmitStrConcatOperand(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
function EmitStrConcatOperand(var Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const ADestVar: string): string;
function CanEmitStrCompareOperand(const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean): Boolean;
function EmitStrCompareOperand(var Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean; out ABlob: string): Boolean;
procedure ScanTopLevelOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; var AChanged: Boolean);
procedure RegisterConcatOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const AConcatNode: TGreenNode; var AChanged: Boolean);

implementation

uses
  nextpas.core.text.conv, np_sema_type_check;

{ === B1: String return 检测 === }

{$I np_sema_string_ownership_detect.inc}

{$I np_sema_string_ownership_args.inc}

{$I np_sema_string_ownership_deferred.inc}

{$I np_sema_string_ownership_scan.inc}

{$I np_sema_string_ownership_concat.inc}

end.
