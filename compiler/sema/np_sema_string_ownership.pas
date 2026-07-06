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
      const ANode: TGreenNode; out AValue: Int64): Boolean;
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

end.
