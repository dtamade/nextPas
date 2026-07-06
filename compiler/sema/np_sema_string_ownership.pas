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


end.
