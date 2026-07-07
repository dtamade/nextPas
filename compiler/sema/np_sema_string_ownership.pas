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
  np_green_tree, np_semantic_model, np_hir_types,
  np_diagnostics_sink, np_base_types, np_ast_facade,
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
    ProcedureBodies: TProcedureBodyArray;
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

function StringReturnFunctionNameFromNode(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode; out AName: string): Boolean;
var
  BodyNode, DeclNode: TGreenNode;
  SymbolId, TypeId: LongInt;
  TypeName: string;
begin
  AName := '';
  Result := False;
  if ANode = nil then
    Exit;
  if ANode.NodeKind = gnkIdentifier then
    AName := ANode.Text
  else if (ANode.NodeKind = gnkFunctionCall) then
    AName := ANode.Text;
  if AName = '' then
    Exit;
  if Ctx.LookupProcedureBody(Ctx.CallbackCtx, AName, BodyNode, DeclNode) and
    Ctx.DeclReturnsString(Ctx.CallbackCtx, DeclNode) then
    Exit(True);
  { Fallback: check semantic model for imported functions }
  SymbolId := Ctx.Model.LookupSymbol(AName, Ctx.CurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := Ctx.Model.FindSymbolByName(AName);
  if SymbolId <= 0 then
    Exit;
  { Only accept actual function/procedure symbols }
  if not SameText(Ctx.Model.SymbolAt(SymbolId - 1).Kind, 'function') and
    not SameText(Ctx.Model.SymbolAt(SymbolId - 1).Kind, 'procedure') then
    Exit;
  TypeId := Ctx.Model.SymbolTypeId(SymbolId);
  if (TypeId > 0) and (TypeId <= Ctx.Model.TypeCount) then
  begin
    TypeName := Ctx.Model.TypeAt(TypeId - 1).Name;
    Result := SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') or
      SameText(TypeName, 'ShortString') or SameText(TypeName, 'WideString') or
      SameText(TypeName, 'UnicodeString');
  end;
end;

function FunctionCallReturnsString(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode): Boolean;
var
  BodyNode, DeclNode: TGreenNode;
  SymbolId, TypeId: LongInt;
  TypeName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.Text = '') then
    Exit;
  if Ctx.LookupProcedureBody(Ctx.CallbackCtx, ANode.Text, BodyNode, DeclNode) then
    Exit(Ctx.DeclReturnsString(Ctx.CallbackCtx, DeclNode));
  SymbolId := Ctx.Model.LookupSymbol(ANode.Text, Ctx.CurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := Ctx.Model.FindSymbolByName(ANode.Text);
  if SymbolId <= 0 then
    Exit;
  if not SameText(Ctx.Model.SymbolAt(SymbolId - 1).Kind, 'function') and
    not SameText(Ctx.Model.SymbolAt(SymbolId - 1).Kind, 'procedure') then
    Exit;
  TypeId := Ctx.Model.SymbolTypeId(SymbolId);
  if (TypeId <= 0) or (TypeId > Ctx.Model.TypeCount) then
    Exit;
  TypeName := Ctx.Model.TypeAt(TypeId - 1).Name;
  Result := SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString');
end;

function MemberCallReturnsString(const Ctx: TSemaOwnershipContext;
  const ANode: TGreenNode): Boolean;
var
  CalleeNode, ReceiverNode, MemberNode: TGreenNode;
  ReceiverTypeName: string;
  ReceiverSymbolId, ReceiverTypeId: LongInt;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkDotAccess) or
    (CalleeNode.ChildCount < 2) then
    Exit;
  ReceiverNode := CalleeNode.ChildAt(0);
  MemberNode := CalleeNode.ChildAt(1);
  if (ReceiverNode = nil) or (MemberNode = nil) or
    (ReceiverNode.NodeKind <> gnkIdentifier) or
    (MemberNode.NodeKind <> gnkIdentifier) then
    Exit;
  if SameText(ReceiverNode.Text, 'Self') and (Ctx.CurrentMethodClass <> '') then
    ReceiverTypeName := Ctx.CurrentMethodClass
  else
    ReceiverTypeName := Ctx.LookupClassVar(Ctx.CallbackCtx, ReceiverNode.Text);
  if ReceiverTypeName = '' then
  begin
    ReceiverSymbolId := Ctx.Model.FindSymbolByName(ReceiverNode.Text);
    if ReceiverSymbolId > 0 then
    begin
      ReceiverTypeId := Ctx.Model.SymbolTypeId(ReceiverSymbolId);
      if (ReceiverTypeId > 0) and (ReceiverTypeId <= Ctx.Model.TypeCount) then
        ReceiverTypeName := Ctx.Model.TypeAt(ReceiverTypeId - 1).Name;
    end;
  end;
  Result := (ReceiverTypeName <> '') and
    Ctx.TypeMetaRetStr(Ctx.CallbackCtx, ReceiverTypeName, MemberNode.Text);
end;

function TypeIdIsManagedString(const Ctx: TSemaOwnershipContext;
  const ATypeId: LongInt): Boolean;
begin
  Result := np_sema_type_check.TypeIdIsManagedString(Ctx.Model, ATypeId);
end;


function IsRootOwnedStringReturnCandidate(const Ctx: TSemaOwnershipContext; 
  const AEntry: TProcedureBodyEntry; const AIsStrReturn: Boolean): Boolean;
begin
  Result := AIsStrReturn and (AEntry.Body <> nil) and
    (AEntry.Decl <> nil) and (AEntry.Decl.NodeKind = gnkFunctionDecl) and
    (Pos('.', AEntry.Name) = 0) and
    SameText(AEntry.OwnerUnitId, NormalizeUnitIdentity(Ctx.UnitGraph.RootName));
end;

function IsSupportedOwnedStringReturnIdentifierTarget(const Ctx: TSemaOwnershipContext; 
  const ATargetNode: TGreenNode): Boolean;
var
  LookupName, RetName: string;
  Symbol: TSemanticSymbol;
  SymbolId: LongInt;
begin
  Result := False;
  if (ATargetNode = nil) or (ATargetNode.NodeKind <> gnkIdentifier) then
    Exit;

  LookupName := ATargetNode.Text;
  if LookupName = '' then
    Exit;
  if SameText(LookupName, 'Result') and (Ctx.CurrentRetVarName <> '') then
    LookupName := Ctx.CurrentRetVarName;

  SymbolId := Ctx.Model.LookupSymbol(LookupName, Ctx.CurrentScopeId);
  if SymbolId <= 0 then
    SymbolId := Ctx.Model.FindSymbolByName(LookupName);
  if SymbolId <= 0 then
    Exit;

  Symbol := Ctx.Model.SymbolAt(SymbolId - 1);
  if SameText(Symbol.Kind, 'variable') then
    Exit(TypeIdIsManagedString(Ctx, Symbol.TypeId));

  RetName := Ctx.CurrentRetVarName;
  Result := SameText(Symbol.Kind, 'function') and (RetName <> '') and
    SameText(LookupName, RetName) and TypeIdIsManagedString(Ctx, Symbol.TypeId);
end;

function IsSupportedOwnedStringReturnStoreTarget(const Ctx: TSemaOwnershipContext; 
  const ATargetNode: TGreenNode): Boolean;
var
  BaseNode, FieldNode: TGreenNode;
  BaseName, ClassTypeName: string;
  BaseSymbolId, BaseTypeId: LongInt;
  FieldMeta: TFieldMeta;
begin
  Result := False;
  if (ATargetNode = nil) or (ATargetNode.NodeKind <> gnkDotAccess) or
    (ATargetNode.ChildCount < 2) then
    Exit;

  BaseNode := ATargetNode.ChildAt(0);
  FieldNode := ATargetNode.ChildAt(1);
  if (BaseNode = nil) or (FieldNode = nil) or
    (BaseNode.NodeKind <> gnkIdentifier) or
    (FieldNode.NodeKind <> gnkIdentifier) then
    Exit;

  BaseName := BaseNode.Text;
  if BaseName = '' then
    Exit;
  if SameText(BaseName, 'Self') then
  begin
    if Ctx.CurrentMethodClass = '' then
      Exit;
    BaseTypeId := Ctx.Model.FindTypeByName(Ctx.CurrentMethodClass);
  end
  else
  begin
    BaseSymbolId := Ctx.Model.LookupSymbol(BaseName, Ctx.CurrentScopeId);
    if BaseSymbolId <= 0 then
      BaseSymbolId := Ctx.Model.FindSymbolByName(BaseName);
    if BaseSymbolId <= 0 then
      Exit;
    BaseTypeId := Ctx.Model.SymbolTypeId(BaseSymbolId);
  end;
  if (BaseTypeId <= 0) or (BaseTypeId > Ctx.Model.TypeCount) then
    Exit;

  ClassTypeName := Ctx.Model.TypeAt(BaseTypeId - 1).Name;
  if ClassTypeName = '' then
    Exit;
  { Accept both class and record field assignments as safe targets for
    owned string returns. If type metadata is not fully resolved (e.g.
    imported record types), trust the assignment as safe. }
  if np_sema_type_check.TypeMetaIsClass(Ctx.Model, ClassTypeName) or np_sema_type_check.TypeMetaIsRecord(Ctx.Model, ClassTypeName) then
  begin
    if Ctx.Model.GetFieldMetaByName(BaseTypeId, FieldNode.Text, FieldMeta) then
      Exit(FieldMeta.IsString and TypeIdIsManagedString(Ctx, FieldMeta.TypeId));
  end;
  { Type exists but metadata not fully resolved — accept as safe.
    This handles imported record types whose field metadata is not yet
    populated during C6-H4 pre-registration.
    TODO: tighten once type metadata is fully populated for all imported
    types during the pre-registration phase. Currently this fallback is
    necessary because imported record field metadata may be incomplete. }
  Result := True;
end;

function IsSupportedOwnedStringReturnConsumerTarget(const Ctx: TSemaOwnershipContext; 
  const ATargetNode: TGreenNode): Boolean;
begin
  { Accept any valid assignment target as a safe consumer for owned string
    returns. The key invariant: if the node appears on the left side of an
    assignment, the owned string temporary is transferred to the target,
    which is always safe. }
  Result := (ATargetNode <> nil) and
    (ATargetNode.NodeKind in [gnkIdentifier, gnkDotAccess,
      gnkArrayAccess]);
end;

function AssignmentOwnsStringReturn(const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const AEntry: TProcedureBodyEntry): Boolean;
var
  DestNode, SourceNode: TGreenNode;
  FuncName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  SourceNode := ANode.ChildAt(1);
  if (DestNode = nil) or
    (not StringReturnFunctionNameFromNode(Ctx, SourceNode, FuncName)) then
    Exit;
  if Ctx.HasOverload(Ctx.CallbackCtx, FuncName) then
    Exit;
  if IsSupportedOwnedStringReturnStoreTarget(Ctx, DestNode) then
    Exit(True);
  // Accept local variable assignments in any function context.
  // This is needed for functions like SameText(Boolean) that use
  // LowerCase internally — without this, LowerCase is never registered
  // as an owned string return function, causing C6-H4 false positives
  // when SysUtils is loaded.
  if IsSupportedOwnedStringReturnIdentifierTarget(Ctx, DestNode) then
    Exit(True);
  if not IsRootOwnedStringReturnCandidate(Ctx, AEntry, Ctx.DeclReturnsString(Ctx.CallbackCtx, AEntry.Decl)) then
    Exit;
  Result := False;
end;

function AssignmentOwnsTopLevelStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  DestNode, SourceNode: TGreenNode;
  FuncName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  SourceNode := ANode.ChildAt(1);
  if (DestNode = nil) or
    (not StringReturnFunctionNameFromNode(Ctx, SourceNode, FuncName)) then
    Exit;
  if Ctx.HasOverload(Ctx.CallbackCtx, FuncName) then
    Exit;
  Result := IsSupportedOwnedStringReturnConsumerTarget(Ctx, DestNode);
end;

function CallArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt;
  out AFuncName: string): Boolean;
var
  BodyNode, DeclNode, FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ACallNode = nil) or (AArgNode = nil) or
    (ACallNode.NodeKind <> gnkFunctionCall) or
    (AArgNode.NodeKind <> gnkFunctionCall) then
    Exit;
  if (ACallNode.Text = '') or Ctx.HasOverload(Ctx.CallbackCtx, ACallNode.Text) then
    Exit;
  if not Ctx.LookupProcedureBody(Ctx.CallbackCtx, ACallNode.Text, BodyNode, DeclNode) then
    Exit;
  if Ctx.IsVarParamAtPosition(Ctx.CallbackCtx, DeclNode, AArgPosition) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, AArgNode, AFuncName) then
    Exit;
  if Ctx.HasOverload(Ctx.CallbackCtx, AFuncName) then
    Exit;
  FuncNode := nil;
  if AArgNode.ChildCount > 0 then
    FuncNode := AArgNode.ChildAt(0);
  Result := (FuncNode <> nil) and (FuncNode.NodeKind = gnkIdentifier) and
    SameText(FuncNode.Text, AFuncName);
end;

function DirectOwnedStringReturnAssignmentNode(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  DestNode: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkAssignmentStatement) or
    (ANode.ChildCount < 2) then
    Exit;
  DestNode := ANode.ChildAt(0);
  if not StringReturnFunctionNameFromNode(Ctx, ANode.ChildAt(1), SourceName) then
    Exit;
  Result := (DestNode <> nil) and Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, SourceName) and
    IsSupportedOwnedStringReturnConsumerTarget(Ctx, DestNode);
end;

function IsSupportedOwnedStringReturnArgument(const Ctx: TSemaOwnershipContext; 
  const ACallNode, AArgNode: TGreenNode; AArgPosition: LongInt): Boolean;
var
  SourceName: string;
begin
  Result := CallArgumentOwnsStringReturn(Ctx, 
    ACallNode, AArgNode, AArgPosition, SourceName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, SourceName);
end;

function LengthArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode, ArgNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 2) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  ArgNode := ANode.ChildAt(1);
  if (CalleeNode = nil) or (ArgNode = nil) or
    (CalleeNode.NodeKind <> gnkIdentifier) or
    (not SameText(CalleeNode.Text, 'Length')) then
    Exit;
  if (ArgNode.NodeKind <> gnkFunctionCall) or
    (ArgNode.ChildCount < 1) or (ArgNode.ChildAt(0) = nil) or
    (ArgNode.ChildAt(0).NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ArgNode, AFuncName) then
    Exit;
  Result := not Ctx.HasOverload(Ctx.CallbackCtx, AFuncName);
end;

function IsSupportedOwnedStringReturnLengthArgument(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := LengthArgumentOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;

function EmitOwnedStringLengthTemp(var Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  SourceName, TempName: string;
begin
  ABlob := '';
  Result := False;
  if not IsSupportedOwnedStringReturnLengthArgument(Ctx, ANode, SourceName) then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  TempName := '$str_len_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
    TempName);
  Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    TempName + #9 + 'callee ' + SourceName + #9 +
    'ptr len owner alloc_size');
  Ctx.Model.AddTypedHirNode('string-temp-length-runtime', SourceName, 0, 0,
    'strvar ' + TempName + #10);
  Ctx.Model.AddTypedHirNode('string-temp-release-runtime', SourceName, 0, 0,
    TempName);
  ABlob := 'var ' + TempName + '$len' + #10;
  Result := True;
end;

function CopyArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode, ArgNode, FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 4) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  ArgNode := ANode.ChildAt(1);
  if (CalleeNode = nil) or (ArgNode = nil) or
    (CalleeNode.NodeKind <> gnkIdentifier) or
    (not SameText(CalleeNode.Text, 'Copy')) then
    Exit;
  if (ArgNode.NodeKind <> gnkFunctionCall) or
    (ArgNode.ChildCount < 1) then
    Exit;
  FuncNode := ArgNode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ArgNode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName) and
    (not Ctx.HasOverload(Ctx.CallbackCtx, AFuncName));
end;

function IsSupportedOwnedStringReturnCopyArgument(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := CopyArgumentOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;

function EmitOwnedStringCopyTemp(var Ctx: TSemaOwnershipContext; const ACopyNode: TGreenNode;
  const ADestName: string; out ATempName: string): Boolean;
var
  SourceName, StartBlob, LenBlob: string;
begin
  ATempName := '';
  Result := False;
  if (ADestName = '') or
    (not IsSupportedOwnedStringReturnCopyArgument(Ctx, ACopyNode, SourceName)) then
    Exit;
  if (not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ACopyNode.ChildAt(2), StartBlob)) or
    (not Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ACopyNode.ChildAt(3), LenBlob)) then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  ATempName := '$str_cpy_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, ATempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, ATempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    ATempName + #9 + 'callee ' + SourceName + #9 +
    'ptr len owner alloc_size');
  Ctx.Model.AddTypedHirNode('tstring-copy-runtime', ADestName, 0, 0,
    ADestName + #9 + ATempName + #9 + StartBlob + #9 + LenBlob);
  Ctx.Model.AddTypedHirNode('string-temp-release-runtime', SourceName, 0, 0,
    ATempName);
  Result := True;
end;

function WriteArgumentOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  CalleeNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  CalleeNode := ANode.ChildAt(0);
  if (CalleeNode = nil) or (CalleeNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ANode, AFuncName) then
    Exit;
  Result := SameText(CalleeNode.Text, AFuncName) and
    (not Ctx.HasOverload(Ctx.CallbackCtx, AFuncName));
end;

function IsSupportedOwnedStringReturnWriteArgument(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := WriteArgumentOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;

function EmitOwnedStringWriteTemp(var Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  SourceName: string;
begin
  ATempName := '';
  Result := False;
  if not IsSupportedOwnedStringReturnWriteArgument(Ctx, ANode, SourceName) then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  ATempName := '$str_wrt_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, ATempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, ATempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
    ATempName + #9 + 'callee ' + SourceName + #9 +
    'ptr len owner alloc_size');
  Ctx.RuntimeVars.QueuePendingStringTempRelease(ATempName, SourceName);
  Result := True;
end;

function ConcatOperandOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount <> 1) then
    Exit;
  FuncNode := ANode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ANode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName);
end;

function IsSupportedOwnedStringReturnConcatOperand(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := ConcatOperandOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;

function CompareOperandOwnsStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
var
  FuncNode: TGreenNode;
begin
  AFuncName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 1) then
    Exit;
  FuncNode := ANode.ChildAt(0);
  if (FuncNode = nil) or (FuncNode.NodeKind <> gnkIdentifier) then
    Exit;
  if not StringReturnFunctionNameFromNode(Ctx, ANode, AFuncName) then
    Exit;
  Result := SameText(FuncNode.Text, AFuncName) and
    (not Ctx.HasOverload(Ctx.CallbackCtx, AFuncName));
end;

function IsSupportedOwnedStringReturnCompareOperand(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out AFuncName: string): Boolean;
begin
  Result := CompareOperandOwnsStringReturn(Ctx, ANode, AFuncName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, AFuncName);
end;



function EmitOwnedStringConcatLengthTemp(var Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out ABlob: string): Boolean;
var
  ConcatNode: TGreenNode;
  LeftName, RightName, TempName: string;
begin
  ABlob := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkFunctionCall) or
    (ANode.ChildCount < 2) or (ANode.ChildAt(0) = nil) or
    (not SameText(ANode.ChildAt(0).Text, 'Length')) then
    Exit;
  ConcatNode := ANode.ChildAt(1);
  if (ConcatNode = nil) or (ConcatNode.NodeKind <> gnkBinaryExpression) or
    (ConcatNode.Text <> '+') or (ConcatNode.ChildCount < 2) or
    (not ConcatTreeHasSupportedOwnedStringReturn(Ctx, ConcatNode)) or
    (not CanEmitStrConcatOperand(Ctx, ConcatNode)) then
    Exit;
  LeftName := EmitStrConcatOperand(Ctx, ConcatNode.ChildAt(0), '');
  RightName := EmitStrConcatOperand(Ctx, ConcatNode.ChildAt(1), '');
  if (LeftName = '') or (RightName = '') then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  TempName := '$str_len_cat_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
    TempName);
  Ctx.Model.AddTypedHirNode('assign-tstring-concat-runtime', TempName, 0, 0,
    LeftName + #9 + RightName);
  Ctx.Model.AddTypedHirNode('string-temp-length-runtime', TempName, 0, 0,
    'strvar ' + TempName + #10);
  Ctx.RuntimeVars.QueuePendingStringTempRelease(TempName, TempName);
  Ctx.RuntimeVars.ClearPendingStringTempReleases;
  ABlob := 'var ' + TempName + '$len' + #10;
  Result := True;
end;

function EmitOwnedStringConcatWriteTemp(var Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; out ATempName: string): Boolean;
var
  LeftName, RightName: string;
begin
  ATempName := '';
  Result := False;
  if (ANode = nil) or (ANode.NodeKind <> gnkBinaryExpression) or
    (ANode.Text <> '+') or (ANode.ChildCount < 2) or
    (not ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode)) or
    (not CanEmitStrConcatOperand(Ctx, ANode)) then
    Exit;
  LeftName := EmitStrConcatOperand(Ctx, ANode.ChildAt(0), '');
  RightName := EmitStrConcatOperand(Ctx, ANode.ChildAt(1), '');
  if (LeftName = '') or (RightName = '') then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  ATempName := '$str_wrt_cat_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, ATempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, ATempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', ATempName, 0, 0,
    ATempName);
  Ctx.Model.AddTypedHirNode('assign-tstring-concat-runtime', ATempName, 0, 0,
    LeftName + #9 + RightName);
  Ctx.RuntimeVars.QueuePendingStringTempRelease(ATempName, ATempName);
  Result := True;
end;

function ConcatExpressionConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  I: LongInt;
  Child: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, SourceName) then
    Exit(False);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if ConcatExpressionConsumesOwnedStringReturnDeferred(Ctx, Child,
        AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    end;
    Exit(False);
  end;
  Result := NodeConsumesOwnedStringReturnDeferred(Ctx, ANode,
    AInsideDirectOwnedAssignmentRhs);
end;

function BoolConditionHasSupportedOwnedStringCompare(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;

  function CanEmitOwnedCompareOperand(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkIdentifier) and
      Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ALocalNode.Text) then
      Exit(True);
    if ALocalNode.NodeKind = gnkStringLiteral then
      Exit(True);
    if IsSupportedOwnedStringReturnCompareOperand(Ctx, ALocalNode, Dummy) then
      Exit(True);
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (ALocalNode.Text = '+') and (ALocalNode.ChildCount >= 2) then
      Exit(
        ConcatTreeHasSupportedOwnedStringReturn(Ctx, ALocalNode) and
        CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
        CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1)));
  end;

  function IsSupportedCompareNode(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if (ALocalNode = nil) or (ALocalNode.NodeKind <> gnkBinaryExpression) or
      ((ALocalNode.Text <> '=') and (ALocalNode.Text <> '<>')) or
      (ALocalNode.ChildCount < 2) then
      Exit;
    if not (CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1))) then
      Exit;
    Result :=
      IsSupportedOwnedStringReturnCompareOperand(Ctx, ALocalNode.ChildAt(0),
        Dummy) or
      IsSupportedOwnedStringReturnCompareOperand(Ctx, ALocalNode.ChildAt(1),
        Dummy) or
      ConcatTreeHasSupportedOwnedStringReturn(Ctx, ALocalNode.ChildAt(0)) or
      ConcatTreeHasSupportedOwnedStringReturn(Ctx, ALocalNode.ChildAt(1));
  end;

  function HasSupportedOwnedCompare(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkUnaryExpression) and
      SameText(ALocalNode.Text, 'not') and (ALocalNode.ChildCount >= 1) then
      Exit(HasSupportedOwnedCompare(ALocalNode.ChildAt(0)));
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (SameText(ALocalNode.Text, 'and') or SameText(ALocalNode.Text, 'or')) and
      (ALocalNode.ChildCount >= 2) then
      Exit(HasSupportedOwnedCompare(ALocalNode.ChildAt(0)) or
        HasSupportedOwnedCompare(ALocalNode.ChildAt(1)));
    Result := IsSupportedCompareNode(ALocalNode);
  end;

  function CanEmitOwnedBoolCondition(const ALocalNode: TGreenNode): Boolean;
  begin
    Result := False;
    if ALocalNode = nil then
      Exit;
    if (ALocalNode.NodeKind = gnkUnaryExpression) and
      SameText(ALocalNode.Text, 'not') and (ALocalNode.ChildCount >= 1) then
      Exit(CanEmitOwnedBoolCondition(ALocalNode.ChildAt(0)));
    if (ALocalNode.NodeKind = gnkIdentifier) and
      (Ctx.IsRuntimeVar(Ctx.CallbackCtx, ALocalNode.Text) or SameText(ALocalNode.Text, 'True') or
       SameText(ALocalNode.Text, 'False')) then
      Exit(True);
    if (ALocalNode.NodeKind = gnkBinaryExpression) and
      (SameText(ALocalNode.Text, 'and') or SameText(ALocalNode.Text, 'or')) and
      (ALocalNode.ChildCount >= 2) then
      Exit(CanEmitOwnedBoolCondition(ALocalNode.ChildAt(0)) and
        CanEmitOwnedBoolCondition(ALocalNode.ChildAt(1)));
    Result :=
      (ALocalNode.NodeKind = gnkBinaryExpression) and
      ((ALocalNode.Text = '=') or (ALocalNode.Text = '<>')) and
      (ALocalNode.ChildCount >= 2) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(0)) and
      CanEmitOwnedCompareOperand(ALocalNode.ChildAt(1));
  end;
begin
  Result := CanEmitOwnedBoolCondition(ANode) and
    HasSupportedOwnedCompare(ANode);
end;

function CompareExpressionConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  I: LongInt;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkUnaryExpression) and SameText(ANode.Text, 'not') and
    (ANode.ChildCount >= 1) then
    Exit(CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(0)));
  if (ANode.NodeKind = gnkBinaryExpression) and
    (SameText(ANode.Text, 'and') or SameText(ANode.Text, 'or')) and
    (ANode.ChildCount >= 2) then
    Exit(CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(0)) or
      CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(1)));
  if (ANode.NodeKind <> gnkBinaryExpression) or
    ((ANode.Text <> '=') and (ANode.Text <> '<>')) or
    (ANode.ChildCount < 2) then
  begin
    { In compare expressions (if/while conditions), all sub-expressions are
      consumed immediately. Temporaries from owned string returns are safe. }
    for I := 0 to ANode.ChildCount - 1 do
      if NodeConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(I), True) then
        Exit(True);
    Exit(False);
  end;
  if CanEmitStrCompareOperand(Ctx, ANode.ChildAt(0), True) and
    CanEmitStrCompareOperand(Ctx, ANode.ChildAt(1), True) then
    Exit(False);
  Result := NodeConsumesOwnedStringReturnDeferred(Ctx, ANode, False);
end;

function NodeConsumesOwnedStringReturnDeferred(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode;
  const AInsideDirectOwnedAssignmentRhs: Boolean): Boolean;
var
  I: LongInt;
  BodyNode, Child, DeclNode, DestNode, SourceNode: TGreenNode;
  SourceName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;

  if (ANode.NodeKind = gnkProcedureDecl) or
    (ANode.NodeKind = gnkFunctionDecl) then
    Exit;

  { Concatenation (+) is a safe context: temporaries live for the entire
    expression evaluation. This handles patterns like FormatFloat(...) + 'x'
    or 'a' + F() + 'b' where the owned string return is used in a concatenation. }
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then Continue;
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  { Set constructors [...] are safe contexts: temporaries live for the entire
    constructor evaluation. This handles patterns like TextFormat('...', [FormatFloat(...)])
    where the owned string return is used inside a set constructor. }
  if ANode.NodeKind = gnkSetConstructor then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then Continue;
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  if (ANode.NodeKind = gnkIfStatement) and (ANode.ChildCount >= 1) then
  begin
    if CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, ANode.ChildAt(0)) then
      Exit(True);
    for I := 1 to ANode.ChildCount - 1 do
      if NodeConsumesOwnedStringReturnDeferred(Ctx, 
        ANode.ChildAt(I), AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    Exit(False);
  end;

  if ((ANode.NodeKind = gnkWhileStatement) or
    (ANode.NodeKind = gnkRepeatStatement)) and (ANode.ChildCount >= 2) then
  begin
    if ANode.NodeKind = gnkWhileStatement then
    begin
      Child := ANode.ChildAt(0);
      BodyNode := ANode.ChildAt(1);
    end
    else
    begin
      BodyNode := ANode.ChildAt(0);
      Child := ANode.ChildAt(1);
    end;
    if CompareExpressionConsumesOwnedStringReturnDeferred(Ctx, Child) then
      Exit(True);
    if BoolConditionHasSupportedOwnedStringCompare(Ctx, Child) then
      Exit(NodeConsumesOwnedStringReturnDeferred(Ctx, 
        BodyNode, AInsideDirectOwnedAssignmentRhs));
  end;

  if DirectOwnedStringReturnAssignmentNode(Ctx, ANode) then
  begin
    if ANode.ChildCount >= 2 then
    begin
      for I := 0 to ANode.ChildAt(1).ChildCount - 1 do
      begin
        if (ANode.ChildAt(1).NodeKind = gnkFunctionCall) and (I = 0) then
          Continue;
        if (ANode.ChildAt(1).NodeKind = gnkFunctionCall) and
          IsSupportedOwnedStringReturnArgument(Ctx, ANode.ChildAt(1),
            ANode.ChildAt(1).ChildAt(I), I - 1) then
          Continue;
        if NodeConsumesOwnedStringReturnDeferred(Ctx, 
          ANode.ChildAt(1).ChildAt(I), False) then
          Exit(True);
      end;
    end;
    Exit(False);
  end;

  if ANode.NodeKind = gnkAssignmentStatement then
  begin
    if ANode.ChildCount >= 2 then
    begin
      DestNode := ANode.ChildAt(0);
      SourceNode := ANode.ChildAt(1);
      if (IsSupportedOwnedStringReturnStoreTarget(Ctx, DestNode) or
        IsSupportedOwnedStringReturnIdentifierTarget(Ctx, DestNode)) and
        StringReturnFunctionNameFromNode(Ctx, SourceNode, SourceName) and
        Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, SourceName) then
        Exit(False);
      if (DestNode <> nil) and (DestNode.NodeKind = gnkIdentifier) and
        Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, DestNode.Text) and
        (SourceNode <> nil) and (SourceNode.NodeKind = gnkBinaryExpression) and
        (SourceNode.Text = '+') then
        Exit(ConcatExpressionConsumesOwnedStringReturnDeferred(Ctx, SourceNode,
          True));
      Exit(NodeConsumesOwnedStringReturnDeferred(Ctx, 
        SourceNode, {AInsideDirectOwnedAssignmentRhs=}True));
    end;
    Exit(False);
  end;

  if (ANode.NodeKind = gnkFunctionCall) and
    ((SameText(ANode.Text, 'WriteLn')) or (SameText(ANode.Text, 'Write'))) then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if IsSupportedOwnedStringReturnWriteArgument(Ctx, Child, SourceName) then
        Continue;
      if (Child.NodeKind = gnkBinaryExpression) and (Child.Text = '+') and
        ConcatTreeHasSupportedOwnedStringReturn(Ctx, Child) and
        CanEmitStrConcatOperand(Ctx, Child) then
        Continue;
      { WriteLn/Write arguments are safe contexts: temporaries live for
        the entire call duration. }
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  if (ANode.NodeKind = gnkFunctionCall) and
    Ctx.LookupProcedureBody(Ctx.CallbackCtx, ANode.Text, BodyNode, DeclNode) and
    (not FunctionCallReturnsString(Ctx, ANode)) then
  begin
    for I := 1 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if IsSupportedOwnedStringReturnArgument(Ctx, ANode, Child, I - 1) then
        Continue;
      if NodeConsumesOwnedStringReturnDeferred(Ctx, 
        Child, AInsideDirectOwnedAssignmentRhs) then
        Exit(True);
    end;
    Exit(False);
  end;

  if IsSupportedOwnedStringReturnLengthArgument(Ctx, ANode, SourceName) then
    Exit(False);
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text, 'Length') and
    (ANode.ChildAt(1) <> nil) and
    (ANode.ChildAt(1).NodeKind = gnkBinaryExpression) and
    (ANode.ChildAt(1).Text = '+') and
    ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode.ChildAt(1)) and
    CanEmitStrConcatOperand(Ctx, ANode.ChildAt(1)) then
    Exit(False);
  if IsSupportedOwnedStringReturnCopyArgument(Ctx, ANode, SourceName) then
    Exit(False);

  if StringReturnFunctionNameFromNode(Ctx, ANode, SourceName) and
    Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, SourceName) and
    (not AInsideDirectOwnedAssignmentRhs) then
    Exit(True);
  if MemberCallReturnsString(Ctx, ANode) and
    (not AInsideDirectOwnedAssignmentRhs) then
    Exit(True);
  { Note: FunctionCallReturnsString catch-all intentionally removed.
    It was too broad — flagging ALL string-returning functions, not just
    registered owned string return functions. The StringReturnFunctionNameFromNode
    + IsOwnedStringReturnFunc check above correctly limits to registered
    functions. }
  if DirectOwnedStringReturnAssignmentNode(Ctx, ANode) and
    StringReturnFunctionNameFromNode(Ctx, ANode.ChildAt(1), SourceName) and
    Ctx.HasOverload(Ctx.CallbackCtx, SourceName) then
    Exit(True);

  { Exit(Expr) is equivalent to Result := Expr — the temporary lives for
    the entire function scope. Treat as safe context.
    Without this guard, Exit(F()) patterns where F is an imported function
    (like ExpandFileName from nextpas.core.fs) would fall through to the
    for-loop below, where the F() child would be flagged as a deferred
    owned-string return. }
  if ANode.NodeKind = gnkExitStatement then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then Continue;
      { The owned string temporary from F() in Exit(F()) lives for the
        entire duration of Exit — treat as safe context. }
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end;
    Exit(False);
  end;

  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    { Owned string temporaries passed as arguments to a function call are
      safe: the temporary lives for the entire enclosing call's duration.
      This handles patterns like SameText(LowerCase(S), 'value') where the
      outer call has overloads (preventing IsSupportedOwnedStringReturnArgument
      from applying). Mark argument positions (I >= 1) as safe contexts. }
    if (ANode.NodeKind = gnkFunctionCall) and (I >= 1) then
    begin
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end
    { Concatenation operands are safe: temporaries live for the entire
      expression evaluation. }
    else if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
    begin
      if NodeConsumesOwnedStringReturnDeferred(Ctx, Child, True) then
        Exit(True);
    end
    else if NodeConsumesOwnedStringReturnDeferred(Ctx, 
      Child, AInsideDirectOwnedAssignmentRhs) then
      Exit(True);
  end;
end;

procedure ScanOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; const AEntry: TProcedureBodyEntry;
  var AChanged: Boolean);
var
  I, J: LongInt;
  Child: TGreenNode;
  FuncName: string;
begin
  if ANode = nil then
    Exit;
  if AssignmentOwnsStringReturn(Ctx, ANode, AEntry) and
    StringReturnFunctionNameFromNode(Ctx, ANode.ChildAt(1), FuncName) and
    (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
  begin
    Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
    AChanged := True;
  end;
  if ANode.NodeKind = gnkFunctionCall then
  begin
    for J := 1 to ANode.ChildCount - 1 do
    begin
      if CallArgumentOwnsStringReturn(Ctx, 
        ANode, ANode.ChildAt(J), J - 1, FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
      if (SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write')) and
        WriteArgumentOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
      if SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write') then
        RegisterConcatOwnedStringReturnConsumers(Ctx, ANode.ChildAt(J), AChanged);
    end;
    if LengthArgumentOwnsStringReturn(Ctx, ANode, FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
    if (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
      SameText(ANode.ChildAt(0).Text, 'Length') then
      RegisterConcatOwnedStringReturnConsumers(Ctx, ANode.ChildAt(1), AChanged);
    if CopyArgumentOwnsStringReturn(Ctx, ANode, FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if ConcatOperandOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    ((ANode.Text = '=') or (ANode.Text = '<>')) then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if CompareOperandOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
    end;
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and
      ((Child.NodeKind = gnkProcedureDecl) or
       (Child.NodeKind = gnkFunctionDecl)) then
      Continue;
    ScanOwnedStringReturnConsumers(Ctx, Child, AEntry, AChanged);
  end;
end;

procedure CheckDeferredOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode);
begin
  if ANode = nil then
    Exit;
  if NodeConsumesOwnedStringReturnDeferred(Ctx, ANode, False) then
  begin
    Ctx.EmitSemaError(Ctx.CallbackCtx, 
      'sema.c6h4-owned-string-return-deferred-consumer',
      'C6-H4: owned string return used in deferred context; ' +
      'assign to a local variable first',
      ANode.ByteOffset);
    Exit;
  end;
end;

procedure PreRegisterOwnedStringReturnConsumers(var Ctx: TSemaOwnershipContext);
var
  I: LongInt;
  Changed: Boolean;
  Entry: TProcedureBodyEntry;
  RootNode: TGreenNode;
  SavedMethodClass, SavedRetVarName: string;
  SavedScopeId: LongInt;
begin
  repeat
    Changed := False;
    if (Ctx.RootAst <> nil) and Ctx.RootAst.IsValid then
    begin
      RootNode := Ctx.RootAst.RootNode;
      if RootNode <> nil then
        ScanTopLevelOwnedStringReturnConsumers(Ctx, RootNode, Changed);
    end;
    for I := 0 to Length(Ctx.ProcedureBodies) - 1 do
    begin
      Entry := Ctx.ProcedureBodies[I];
      if (Entry.Body = nil) or (Entry.Decl = nil) or (Pos('<', Entry.Name) > 0) then
        Continue;
      SavedMethodClass := Ctx.CurrentMethodClass;
      SavedRetVarName := Ctx.CurrentRetVarName;
      SavedScopeId := Ctx.CurrentScopeId;
      if Pos('.', Entry.Name) > 0 then
        Ctx.CurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1)
      else
        Ctx.CurrentMethodClass := '';
      Ctx.CurrentRetVarName := Entry.Name;
      if Pos('.', Ctx.CurrentRetVarName) > 0 then
        Ctx.CurrentRetVarName := Copy(Ctx.CurrentRetVarName,
          Pos('.', Ctx.CurrentRetVarName) + 1, Length(Ctx.CurrentRetVarName));
      if Entry.ScopeId > 0 then
        Ctx.CurrentScopeId := Entry.ScopeId;
      try
        ScanOwnedStringReturnConsumers(Ctx, Entry.Body, Entry, Changed);
      finally
        Ctx.CurrentMethodClass := SavedMethodClass;
        Ctx.CurrentRetVarName := SavedRetVarName;
        Ctx.CurrentScopeId := SavedScopeId;
      end;
    end;
  until not Changed;
  { Root-level C6-H4 check removed: procedure body loop below already covers
    all root-unit bodies with OwnerUnitId filtering. The old root-level call
    traversed imported units' code and caused false positives. }
  if not Ctx.Diagnostics.HasErrors then
  begin
    for I := 0 to Length(Ctx.ProcedureBodies) - 1 do
    begin
      Entry := Ctx.ProcedureBodies[I];
      if (Entry.Body = nil) or (Entry.Decl = nil) or (Pos('<', Entry.Name) > 0) then
        Continue;
      // Skip C6-H4 check for procedure bodies in external (non-root) units.
      // External units like SysUtils may use owned string returns in safe patterns
      // that the C6-H4 check does not fully support.
      if not SameText(NormalizeUnitIdentity(Entry.OwnerUnitId),
        NormalizeUnitIdentity(Ctx.UnitGraph.RootName)) then
        Continue;
      SavedMethodClass := Ctx.CurrentMethodClass;
      SavedRetVarName := Ctx.CurrentRetVarName;
      SavedScopeId := Ctx.CurrentScopeId;
      if Pos('.', Entry.Name) > 0 then
        Ctx.CurrentMethodClass := Copy(Entry.Name, 1, Pos('.', Entry.Name) - 1)
      else
        Ctx.CurrentMethodClass := '';
      Ctx.CurrentRetVarName := Entry.Name;
      if Pos('.', Ctx.CurrentRetVarName) > 0 then
        Ctx.CurrentRetVarName := Copy(Ctx.CurrentRetVarName,
          Pos('.', Ctx.CurrentRetVarName) + 1, Length(Ctx.CurrentRetVarName));
      if Entry.ScopeId > 0 then
        Ctx.CurrentScopeId := Entry.ScopeId;
      try
        CheckDeferredOwnedStringReturnConsumers(Ctx, Entry.Body);
      finally
        Ctx.CurrentMethodClass := SavedMethodClass;
        Ctx.CurrentRetVarName := SavedRetVarName;
        Ctx.CurrentScopeId := SavedScopeId;
      end;
      if Ctx.Diagnostics.HasErrors then
        Exit;
    end;
  end;
end;

procedure EmitOwnedStringCleanupNodes(const Ctx: TSemaOwnershipContext; const AExceptName: string);
var
  I: LongInt;
  VarName: string;
  OwnedNames: TStringArray;
begin
  OwnedNames := Ctx.RuntimeVars.GetOwnedRuntimeStrVarNames;
  for I := 0 to Length(OwnedNames) - 1 do
  begin
    VarName := OwnedNames[I];
    if (VarName = '') or Ctx.IsBorrowedRuntimeStrVar(Ctx.CallbackCtx, VarName) or
      SameText(VarName, AExceptName) then
      Continue;
    Ctx.Model.AddTypedHirNode(
      'tstring-cleanup-runtime',
      VarName,
      0,
      0,
      VarName
    );
  end;
end;

procedure EmitOwnedDynArrayCleanupNodes(const Ctx: TSemaOwnershipContext);
var
  I: LongInt;
  VarName: string;
  ArrNames: TStringArray;
begin
  ArrNames := Ctx.RuntimeVars.GetRuntimeArrVarNames;
  for I := 0 to Length(ArrNames) - 1 do
  begin
    VarName := ArrNames[I];
    if (VarName = '') or Ctx.IsBorrowedRuntimeArrVar(Ctx.CallbackCtx, VarName) or
      Ctx.IsStaticRuntimeArrVar(Ctx.CallbackCtx, VarName) then
      Continue;
    Ctx.Model.AddTypedHirNode(
      'dynarray-cleanup-runtime',
      VarName,
      0,
      0,
      VarName + #9 + 'int ' + IntToStr(Ctx.DynArrayElemSizeOfVar(Ctx.CallbackCtx, VarName)) + #10
    );
  end;
end;

procedure EmitOwnedManagedRecordCleanupNodes(const Ctx: TSemaOwnershipContext);
var
  I, J: LongInt;
  VarName, TypeName, Blob: string;
  Meta: TTypeMetadata;
  NeedCleanup: Boolean;
  MgrNames: TStringArray;
  MgrTypes: TStringArray;
begin
  MgrNames := Ctx.RuntimeVars.GetManagedRecordVarNames;
  MgrTypes := Ctx.RuntimeVars.GetManagedRecordVarTypes;
  for I := 0 to Length(MgrNames) - 1 do
  begin
    VarName := MgrNames[I];
    TypeName := MgrTypes[I];
    if not Ctx.Model.GetTypeMetaByName(TypeName, Meta) then
      Continue;
    Blob := VarName + #9 + TypeName;
    NeedCleanup := False;
    for J := 0 to High(Meta.Fields) do
    begin
      if Meta.Fields[J].IsString then
      begin
        Blob := Blob + #9 + Meta.Fields[J].Name + ':s';
        NeedCleanup := True;
      end
      else if Meta.Fields[J].IsDynArray then
      begin
        Blob := Blob + #9 + Meta.Fields[J].Name + ':d';
        NeedCleanup := True;
      end;
    end;
    if NeedCleanup then
      Ctx.Model.AddTypedHirNode(
        'managed-record-cleanup-runtime',
        VarName,
        0,
        0,
        Blob
      );
  end;
end;

function ConcatTreeHasSupportedOwnedStringReturn(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, Dummy) then
    Exit(True);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) then
    Exit(ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode.ChildAt(0)) or
      ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode.ChildAt(1)));
end;

function CanEmitStrConcatOperand(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode): Boolean;
var
  Dummy: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ANode.Text) then
    Exit(True);
  if (ANode.NodeKind = gnkIdentifier) and (Ctx.CurrentMethodClass <> '') and
    Ctx.TypeMetaFieldIsStr(Ctx.CallbackCtx, Ctx.CurrentMethodClass, ANode.Text) then
    Exit(True);
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) then
    Exit(CanEmitStrConcatOperand(Ctx, ANode.ChildAt(0)) and
      CanEmitStrConcatOperand(Ctx, ANode.ChildAt(1)));
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and SameText(ANode.ChildAt(0).Text,
    'IntToStr') and Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(1), Dummy) then
    Exit(True);
  if IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, Dummy) then
    Exit(True);
  if ANode.NodeKind = gnkStringLiteral then
    Exit(True);
  Result := Ctx.EvaluateStringConstant(Ctx.CallbackCtx, ANode, Dummy);
end;

function EmitStrConcatOperand(var Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const ADestVar: string): string;
var
  TempName, LitValue: string;
  FieldIdx: Int64;
begin
  Result := '';
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ANode.Text) then
    Exit(ANode.Text);
  if (ANode.NodeKind = gnkIdentifier) and (Ctx.CurrentMethodClass <> '') and
    Ctx.TypeMetaFieldIsStr(Ctx.CallbackCtx, Ctx.CurrentMethodClass, ANode.Text) then
  begin
    FieldIdx := Ctx.TypeMetaFieldIndex(Ctx.CallbackCtx, Ctx.CurrentMethodClass, ANode.Text);
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
    Ctx.Model.AddTypedHirNode(
      'assign-tstring-field-load-runtime', TempName, 0, 0,
      TempName + #9 + IntToStr(FieldIdx)
    );
    Exit(TempName);
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(1) <> nil) then
  begin
    LitValue := EmitStrConcatOperand(Ctx, ANode.ChildAt(0), ADestVar);
    if LitValue <> '' then
    begin
      TempName := EmitStrConcatOperand(Ctx, ANode.ChildAt(1), ADestVar);
      if TempName <> '' then
      begin
        Inc(Ctx.BlockLabelCounter);
        Result := '$str_tmp_' + IntToStr(Ctx.BlockLabelCounter);
        Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, Result);
        Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, Result);
        Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', Result, 0, 0, Result);
        Ctx.Model.AddTypedHirNode(
          'assign-tstring-concat-runtime',
          LitValue + #9 + TempName,
          0, 0, Result
        );
        Exit;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkFunctionCall) and (ANode.ChildCount >= 2) and
    (ANode.ChildAt(0) <> nil) and
    SameText(ANode.ChildAt(0).Text, 'IntToStr') and
    Ctx.EncodeRuntimeIntExprFold(Ctx.CallbackCtx, ANode.ChildAt(1), LitValue) then
  begin
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
    Ctx.Model.AddTypedHirNode('tstring-from-int-runtime', TempName, 0, 0,
      TempName + #9 + LitValue);
    Exit(TempName);
  end;
  if IsSupportedOwnedStringReturnConcatOperand(Ctx, ANode, LitValue) then
  begin
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_cat_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', LitValue, 0, 0,
      TempName + #9 + 'callee ' + LitValue + #9 +
      'ptr len owner alloc_size');
    Ctx.RuntimeVars.QueuePendingStringTempRelease(TempName, LitValue);
    Exit(TempName);
  end;
  if ANode.NodeKind = gnkStringLiteral then
    LitValue := Ctx.DecodePascalStringLiteral(Ctx.CallbackCtx, ANode.Text)
  else if not Ctx.EvaluateStringConstant(Ctx.CallbackCtx, ANode, LitValue) then
    Exit;
  Inc(Ctx.BlockLabelCounter);
  TempName := '$str_tmp_' + IntToStr(Ctx.BlockLabelCounter);
  Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
  Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
  Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0, TempName);
  Ctx.Model.AddTypedHirNode('assign-tstring-literal-runtime', TempName, 0, 0, LitValue);
  Result := TempName;
end;

function CanEmitStrCompareOperand(const Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean): Boolean;
var
  SourceName: string;
begin
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ANode.Text) then
    Exit(True);
  { Any identifier can safely participate in string comparisons —
    comparisons don't hold references to owned string returns. }
  if (ANode.NodeKind = gnkIdentifier) and (AAllowOwnedStringReturn) then
    Exit(True);
  if ANode.NodeKind = gnkStringLiteral then
    Exit(True);
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.Text = '+') and ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode) and
    CanEmitStrConcatOperand(Ctx, ANode) then
    Exit(True);
  if AAllowOwnedStringReturn and
    IsSupportedOwnedStringReturnCompareOperand(Ctx, ANode, SourceName) then
    Exit(True);
  { LowerCase/UpperCase are safe for comparisons even when overloaded }
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkFunctionCall) and
    (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
    (ANode.ChildAt(0).NodeKind = gnkIdentifier) and
    (SameText(ANode.ChildAt(0).Text, 'LowerCase') or
     SameText(ANode.ChildAt(0).Text, 'UpperCase')) then
    Exit(True);
  { Any function call returning a string is safe as a compare operand —
    temporaries live for the entire comparison evaluation. This covers
    imported functions like Trim, Copy, etc. that are not registered as
    owned string return functions but still create safe temporaries. }
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkFunctionCall) and
    FunctionCallReturnsString(Ctx, ANode) then
    Exit(True);
end;

function EmitStrCompareOperand(var Ctx: TSemaOwnershipContext; const ANode: TGreenNode;
  const AAllowOwnedStringReturn: Boolean; out ABlob: string): Boolean;
var
  LeftName, RightName, SourceName, TempName: string;
begin
  ABlob := '';
  Result := False;
  if ANode = nil then
    Exit;
  if (ANode.NodeKind = gnkIdentifier) and Ctx.IsRuntimeStrVar(Ctx.CallbackCtx, ANode.Text) then
  begin
    ABlob := 'strvar ' + ANode.Text + #10;
    Exit(True);
  end;
  if ANode.NodeKind = gnkStringLiteral then
  begin
    ABlob := 'strlit ' + ANode.Text + #10;
    Exit(True);
  end;
  if AAllowOwnedStringReturn and (ANode.NodeKind = gnkBinaryExpression) and
    (ANode.Text = '+') and (ANode.ChildCount >= 2) and
    ConcatTreeHasSupportedOwnedStringReturn(Ctx, ANode) and
    CanEmitStrConcatOperand(Ctx, ANode) then
  begin
    LeftName := EmitStrConcatOperand(Ctx, ANode.ChildAt(0), '');
    RightName := EmitStrConcatOperand(Ctx, ANode.ChildAt(1), '');
    if (LeftName = '') or (RightName = '') then
      Exit(False);
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_cmp_cat_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    Ctx.Model.AddTypedHirNode('assign-tstring-concat-runtime', TempName, 0, 0,
      LeftName + #9 + RightName);
    Ctx.RuntimeVars.QueuePendingStringTempRelease(TempName, TempName);
    ABlob := 'strvar ' + TempName + #10;
    Exit(True);
  end;
  if AAllowOwnedStringReturn and
    IsSupportedOwnedStringReturnCompareOperand(Ctx, ANode, SourceName) then
  begin
    Inc(Ctx.BlockLabelCounter);
    TempName := '$str_cmp_tmp_' + IntToStr(Ctx.BlockLabelCounter);
    Ctx.RegisterRuntimeVar(Ctx.CallbackCtx, TempName);
    Ctx.RegisterRuntimeStrVar(Ctx.CallbackCtx, TempName);
    Ctx.Model.AddTypedHirNode('var-decl-tstring-runtime', TempName, 0, 0,
      TempName);
    Ctx.Model.AddTypedHirNode('string-temp-owned-runtime', SourceName, 0, 0,
      TempName + #9 + 'callee ' + SourceName + #9 +
      'ptr len owner alloc_size');
    Ctx.RuntimeVars.QueuePendingStringTempRelease(TempName, SourceName);
    ABlob := 'strvar ' + TempName + #10;
    Exit(True);
  end;
end;

procedure ScanTopLevelOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const ANode: TGreenNode; var AChanged: Boolean);
var
  I, J: LongInt;
  Child: TGreenNode;
  FuncName: string;
begin
  if ANode = nil then
    Exit;
  if AssignmentOwnsTopLevelStringReturn(Ctx, ANode) and
    StringReturnFunctionNameFromNode(Ctx, ANode.ChildAt(1), FuncName) and
    (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
  begin
    Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
    AChanged := True;
  end;
  if ANode.NodeKind = gnkFunctionCall then
  begin
    for J := 1 to ANode.ChildCount - 1 do
    begin
      if CallArgumentOwnsStringReturn(Ctx, 
        ANode, ANode.ChildAt(J), J - 1, FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
      if (SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write')) and
        WriteArgumentOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
      if SameText(ANode.Text, 'WriteLn') or SameText(ANode.Text, 'Write') then
        RegisterConcatOwnedStringReturnConsumers(Ctx, ANode.ChildAt(J), AChanged);
    end;
    if LengthArgumentOwnsStringReturn(Ctx, ANode, FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
    if (ANode.ChildCount >= 2) and (ANode.ChildAt(0) <> nil) and
      SameText(ANode.ChildAt(0).Text, 'Length') then
      RegisterConcatOwnedStringReturnConsumers(Ctx, ANode.ChildAt(1), AChanged);
    if CopyArgumentOwnsStringReturn(Ctx, ANode, FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and (ANode.Text = '+') then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if ConcatOperandOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
    end;
  end;
  if (ANode.NodeKind = gnkBinaryExpression) and
    ((ANode.Text = '=') or (ANode.Text = '<>')) then
  begin
    for J := 0 to ANode.ChildCount - 1 do
    begin
      if CompareOperandOwnsStringReturn(Ctx, ANode.ChildAt(J), FuncName) and
        (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
      begin
        Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
        AChanged := True;
      end;
    end;
  end;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and
      ((Child.NodeKind = gnkProcedureDecl) or
       (Child.NodeKind = gnkFunctionDecl)) then
      Continue;
    ScanTopLevelOwnedStringReturnConsumers(Ctx, Child, AChanged);
  end;
end;

procedure RegisterConcatOwnedStringReturnConsumers(const Ctx: TSemaOwnershipContext; 
  const AConcatNode: TGreenNode; var AChanged: Boolean);
var
  I: LongInt;
  FuncName: string;
begin
  if (AConcatNode = nil) or (AConcatNode.NodeKind <> gnkBinaryExpression) or
    (AConcatNode.Text <> '+') then
    Exit;
  for I := 0 to AConcatNode.ChildCount - 1 do
  begin
    if ConcatOperandOwnsStringReturn(Ctx, AConcatNode.ChildAt(I), FuncName) and
      (not Ctx.IsOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName)) then
    begin
      Ctx.RegisterOwnedStringReturnFunc(Ctx.CallbackCtx, FuncName);
      AChanged := True;
    end;
    RegisterConcatOwnedStringReturnConsumers(Ctx, AConcatNode.ChildAt(I), AChanged);
  end;
end;

end.
