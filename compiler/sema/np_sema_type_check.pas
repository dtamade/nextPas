{**
 * np_sema_type_check.pas
 *
 * 类型检查/元数据查询模块 — 从 TSemanticAnalyzer 提取
 *
 * 职责：
 *   - 类型元数据查询（TypeMetaSize, TypeMetaIsRecord, TypeMetaIsClass 等）
 *   - 类型字段查询（TypeMetaFieldIndex, TypeMetaFieldIsStr 等）
 *   - VMT 查询（TypeMetaVmtSlot, TypeMetaVmtCount 等）
 *   - 类型层级查询（TypeMetaParentClass, NextClassAncestorName 等）
 *   - 接口查询（TypeMetaIsInterface, TypeIsInterfaceByName, TypeMetaInterfaces）
 *
 * 所有函数接收 const AModel: TSemanticModel 作为第一个参数，
 * 纯查询，零副作用。
 *
 * 对标：rustc 的 ty 模块
 *}

unit np_sema_type_check;

{$mode objfpc}{$H+}

interface

uses
  np_semantic_model, nextpas.compiler.syntax.green_tree;

{ === 基本类型元数据 === }

function TypeMetaSize(const AModel: TSemanticModel; const ATypeName: string): Int64;
function TypeMetaIsDynArrayType(const AModel: TSemanticModel;
  const ATypeName: string): Boolean;
function TypeMetaIsRecord(const AModel: TSemanticModel; const ATypeName: string): Boolean;
function TypeMetaIsPointer(const AModel: TSemanticModel; const ATypeName: string): Boolean;
function TypeMetaIsClass(const AModel: TSemanticModel; const ATypeName: string): Boolean;
function TypeMetaIsInterface(const AModel: TSemanticModel; const ATypeName: string): Boolean;
function TypeIsInterfaceByName(const AModel: TSemanticModel; const ATypeName: string): Boolean;

{ === 字段元数据 === }

function TypeMetaFieldIndex(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Int64;
function TypeMetaFieldIsStr(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
function TypeMetaFieldIsPtr(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
function TypeMetaFieldIsDynArray(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
function TypeMetaFieldDynArrayElemSize(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Int64;

{ === VMT 元数据 === }

function TypeMetaVmtSlot(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Int64;
function TypeMetaRetPtr(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Boolean;
function TypeMetaRetStr(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Boolean;
function TypeMetaVmtCount(const AModel: TSemanticModel; const ATypeName: string): Int64;

{ === 类型层级 === }

function TypeMetaParentClass(const AModel: TSemanticModel; const ATypeName: string): string;
function NextClassAncestorName(const AModel: TSemanticModel; const ATypeName: string): string;

{ === 接口 === }

function TypeMetaInterfaces(const AModel: TSemanticModel; const ATypeName: string): string;

function IsIntrinsicExprName(const AName: string): Boolean;
function TypeIdIsManagedString(const AModel: TSemanticModel; const ATypeId: LongInt): Boolean;

function TypeSymbolForTypeId(const AModel: TSemanticModel; const ATypeId: LongInt;
  out ASymbol: TSemanticSymbol): Boolean;
function TypeIdHasKnownClassLayout(const AModel: TSemanticModel;
  const ATypeId: LongInt): Boolean;
function IsDeferredSystemObjectMember(const AMemberName: string): Boolean;
function IsSimpleIdentifierName(const AName: string): Boolean;
function DeclReturnsString(const ADecl: TGreenNode): Boolean;
function DeclaresStringLocal(const ADecl: TGreenNode;
  const AName: string): Boolean;

{ === AST 节点查询（纯函数，零依赖 TSemanticAnalyzer） === }

function CallArgumentCount(const ACallNode: TGreenNode): LongInt;
function BareCallCalleeName(const ACallNode: TGreenNode): string;
function IsWrappedCallChild(const AParent, AChild: TGreenNode): Boolean;
function IsImplicitSelfCallNode(const ACallNode: TGreenNode): Boolean;
function IsQualifiedCallNode(const ACallNode: TGreenNode): Boolean;
function ExtractDirectMemberCall(const ACallNode: TGreenNode;
  out AReceiverName: string; out AMemberName: string;
  out AMemberOffset: LongInt; out AArgCount: LongInt): Boolean;

implementation
{$I np_sema_type_check_meta.inc}
function TypeIdIsManagedString(const AModel: TSemanticModel;
  const ATypeId: LongInt): Boolean;
var
  TypeName: string;
begin
  Result := False;
  if (ATypeId <= 0) or (ATypeId > AModel.TypeCount) then
    Exit;
  TypeName := AModel.TypeAt(ATypeId - 1).Name;
  Result := SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString');
end;

function TypeSymbolForTypeId(const AModel: TSemanticModel; const ATypeId: LongInt;
  out ASymbol: TSemanticSymbol): Boolean;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  ASymbol.SymbolId := 0;
  ASymbol.Name := '';
  ASymbol.Kind := '';
  ASymbol.OwnerUnitId := '';
  ASymbol.ScopeId := 0;
  ASymbol.TypeId := 0;
  ASymbol.ParamCount := -1;
  ASymbol.ParamSignature := '';
  ASymbol.ByteOffset := 0;
  Result := False;
  if (ATypeId <= 0) or (ATypeId > AModel.TypeCount) then
    Exit;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Kind, 'type') and (Symbol.TypeId = ATypeId) then
    begin
      ASymbol := Symbol;
      Exit(True);
    end;
  end;
end;

function TypeIdHasKnownClassLayout(const AModel: TSemanticModel;
  const ATypeId: LongInt): Boolean;
var
  ConstValue: Int64;
  TypeSymbol: TSemanticSymbol;
  Meta: TTypeMetadata;
begin
  Result := False;
  if (ATypeId <= 0) or (ATypeId > AModel.TypeCount) then
    Exit;
  if AModel.GetTypeMeta(ATypeId, Meta) then
  begin
    Result := (not Meta.IsRecord) and (Meta.Size > 0);
    Exit;
  end;
  if not TypeSymbolForTypeId(AModel, ATypeId, TypeSymbol) then
    Exit;
  Result := AModel.LookupConstValue(TypeSymbol.Name + '$vmt_count', ConstValue);
end;

function IsDeferredSystemObjectMember(const AMemberName: string): Boolean;
begin
  Result := SameText(AMemberName, 'Free') or
    SameText(AMemberName, 'Create') or
    SameText(AMemberName, 'Destroy') or
    SameText(AMemberName, 'CreateFmt') or
    SameText(AMemberName, 'CreateRes') or
    SameText(AMemberName, 'CreateResFmt') or
    SameText(AMemberName, 'ClassName') or
    SameText(AMemberName, 'ClassType') or
    SameText(AMemberName, 'InheritsFrom') or
    SameText(AMemberName, 'GetInterface') or
    SameText(AMemberName, 'AfterConstruction') or
    SameText(AMemberName, 'BeforeDestruction') or
    SameText(AMemberName, '_AddRef') or
    SameText(AMemberName, '_Release') or
    SameText(AMemberName, 'Write') or SameText(AMemberName, 'Read') or
    SameText(AMemberName, 'Close') or SameText(AMemberName, 'Flush') or
    SameText(AMemberName, 'Seek') or SameText(AMemberName, 'GetSize') or
    SameText(AMemberName, 'SetSize') or
    SameText(AMemberName, 'WriteByte') or SameText(AMemberName, 'ReadByte') or
    SameText(AMemberName, 'Clone') or SameText(AMemberName, 'Reset') or
    SameText(AMemberName, 'SetBlocking') or
    SameText(AMemberName, 'CreateWithContext') or
    SameText(AMemberName, 'Contains') or
    SameText(AMemberName, 'Render');
end;

function IsSimpleIdentifierName(const AName: string): Boolean;
var
  I: LongInt;
  Ch: Char;
begin
  if AName = '' then
    Exit(False);
  Ch := AName[1];
  if not (Ch in ['A'..'Z', 'a'..'z', '_']) then
    Exit(False);
  for I := 2 to Length(AName) do
  begin
    Ch := AName[I];
    if not (Ch in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
  end;
  Result := True;
end;


function DeclReturnsString(const ADecl: TGreenNode): Boolean;
var
  I: LongInt;
  Child: TGreenNode;
begin
  Result := False;
  if ADecl = nil then
    Exit;
  for I := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) and
      (SameText(Child.Text, 'String') or SameText(Child.Text, 'AnsiString')) then
      Exit(True);
  end;
end;

function DeclaresStringLocal(const ADecl: TGreenNode;
  const AName: string): Boolean;
var
  I, J: LongInt;
  Child, Decl, TypeChild: TGreenNode;
begin
  Result := False;
  if (ADecl = nil) or (AName = '') then
    Exit;
  for I := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkVarSection) then
      Continue;
    for J := 0 to Child.ChildCount - 1 do
    begin
      Decl := Child.ChildAt(J);
      if (Decl = nil) or (Decl.NodeKind <> gnkVarDecl) or
        (not SameText(Decl.Text, AName)) or (Decl.ChildCount = 0) then
        Continue;
      TypeChild := Decl.ChildAt(0);
      if (TypeChild <> nil) and
        (SameText(TypeChild.Text, 'String') or
         SameText(TypeChild.Text, 'AnsiString')) then
        Exit(True);
    end;
  end;
end;

{ === AST 节点查询（纯函数，零依赖 TSemanticAnalyzer） === }

function CallArgumentCount(const ACallNode: TGreenNode): LongInt;
var
  InnerCall: TGreenNode;
begin
  Result := 0;
  if ACallNode = nil then
    Exit;

  if ACallNode.NodeKind = gnkFunctionCall then
  begin
    if ACallNode.ChildCount > 0 then
      Result := ACallNode.ChildCount - 1;
    Exit;
  end;

  if ACallNode.NodeKind = gnkProcedureCallStatement then
  begin
    if (ACallNode.ChildCount = 1) and
      (ACallNode.ChildAt(0) <> nil) and
      (ACallNode.ChildAt(0).NodeKind = gnkFunctionCall) then
    begin
      InnerCall := ACallNode.ChildAt(0);
      if InnerCall.ChildCount > 0 then
        Result := InnerCall.ChildCount - 1;
      Exit;
    end;

    Result := ACallNode.ChildCount;
  end;
end;

function BareCallCalleeName(const ACallNode: TGreenNode): string;
var
  CalleeNode: TGreenNode;
  InnerCallNode: TGreenNode;
begin
  Result := '';
  if ACallNode = nil then
    Exit;
  if ACallNode.ChildCount = 0 then
    Exit(ACallNode.Text);

  CalleeNode := ACallNode.ChildAt(0);
  if (CalleeNode <> nil) and (CalleeNode.NodeKind = gnkIdentifier) then
    Exit(CalleeNode.Text);

  if (ACallNode.NodeKind = gnkProcedureCallStatement) and
    (CalleeNode <> nil) and (CalleeNode.NodeKind = gnkFunctionCall) then
  begin
    InnerCallNode := CalleeNode;
    if (InnerCallNode.ChildCount > 0) and
      (InnerCallNode.ChildAt(0) <> nil) and
      (InnerCallNode.ChildAt(0).NodeKind = gnkIdentifier) then
      Exit(InnerCallNode.ChildAt(0).Text);
  end;

  Result := ACallNode.Text;
end;

function IsWrappedCallChild(const AParent, AChild: TGreenNode): Boolean;
begin
  Result := (AParent <> nil) and (AChild <> nil) and
    (AParent.NodeKind = gnkProcedureCallStatement) and
    (AChild.NodeKind = gnkFunctionCall) and
    (AParent.ByteOffset = AChild.ByteOffset) and
    SameText(AParent.Text, AChild.Text);
end;

function IsImplicitSelfCallNode(const ACallNode: TGreenNode): Boolean;
var
  CalleeNode: TGreenNode;
begin
  Result := False;
  if ACallNode = nil then
    Exit;

  case ACallNode.NodeKind of
    gnkIdentifier:
      Exit(ACallNode.Text <> '');
    gnkFunctionCall:
      begin
        if ACallNode.ChildCount <= 0 then
          Exit(False);
        CalleeNode := ACallNode.ChildAt(0);
        Exit((CalleeNode <> nil) and (CalleeNode.NodeKind = gnkIdentifier));
      end;
    gnkProcedureCallStatement:
      begin
        if ACallNode.ChildCount = 0 then
          Exit(ACallNode.Text <> '');
        CalleeNode := ACallNode.ChildAt(0);
        if CalleeNode = nil then
          Exit(False);
        if CalleeNode.NodeKind = gnkIdentifier then
          Exit(True);
        if (CalleeNode.NodeKind = gnkFunctionCall) and
          (CalleeNode.ChildCount > 0) and (CalleeNode.ChildAt(0) <> nil) and
          (CalleeNode.ChildAt(0).NodeKind = gnkIdentifier) then
          Exit(True);
        Exit(False);
      end;
  end;
end;

function IsQualifiedCallNode(const ACallNode: TGreenNode): Boolean;
var
  CalleeNode: TGreenNode;
begin
  Result := False;
  if (ACallNode = nil) or
    not (ACallNode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall]) or
    (ACallNode.ChildCount = 0) then
    Exit;

  CalleeNode := ACallNode.ChildAt(0);
  if CalleeNode = nil then
    Exit;

  if ACallNode.NodeKind = gnkFunctionCall then
    Exit(CalleeNode.NodeKind in [gnkDotAccess, gnkArrayAccess,
      gnkDereference]);

  if CalleeNode.ByteOffset <> ACallNode.ByteOffset then
    Exit;

  if CalleeNode.NodeKind in [gnkDotAccess, gnkArrayAccess, gnkDereference] then
    Exit(True);

  if (CalleeNode.NodeKind = gnkFunctionCall) and
    SameText(ACallNode.Text, CalleeNode.Text) and
    (CalleeNode.ChildCount > 0) then
  begin
    CalleeNode := CalleeNode.ChildAt(0);
    Result := (CalleeNode <> nil) and
      (CalleeNode.NodeKind in [gnkDotAccess, gnkArrayAccess,
       gnkDereference]);
  end;
end;

function ExtractDirectMemberCall(
  const ACallNode: TGreenNode;
  out AReceiverName: string;
  out AMemberName: string;
  out AMemberOffset: LongInt;
  out AArgCount: LongInt
): Boolean;
var
  CalleeNode: TGreenNode;
  DotNode: TGreenNode;
  InnerCallNode: TGreenNode;
  MemberNode: TGreenNode;
  ReceiverNode: TGreenNode;
begin
  Result := False;
  AReceiverName := '';
  AMemberName := '';
  AMemberOffset := 0;
  AArgCount := 0;
  if (ACallNode = nil) or
    not (ACallNode.NodeKind in [gnkProcedureCallStatement, gnkFunctionCall]) or
    (ACallNode.ChildCount = 0) then
    Exit;

  CalleeNode := ACallNode.ChildAt(0);
  if CalleeNode = nil then
    Exit;

  DotNode := nil;
  InnerCallNode := nil;
  if CalleeNode.NodeKind = gnkDotAccess then
    DotNode := CalleeNode
  else if (CalleeNode.NodeKind = gnkFunctionCall) and
    SameText(ACallNode.Text, CalleeNode.Text) and
    (CalleeNode.ChildCount > 0) and
    (CalleeNode.ChildAt(0) <> nil) and
    (CalleeNode.ChildAt(0).NodeKind = gnkDotAccess) then
  begin
    DotNode := CalleeNode.ChildAt(0);
    InnerCallNode := CalleeNode;
  end;

  if (DotNode = nil) or (DotNode.ChildCount < 2) then
    Exit;

  ReceiverNode := DotNode.ChildAt(0);
  MemberNode := DotNode.ChildAt(1);
  if (ReceiverNode = nil) or (MemberNode = nil) or
    (ReceiverNode.NodeKind <> gnkIdentifier) or
    (MemberNode.NodeKind <> gnkIdentifier) then
    Exit;

  AReceiverName := ReceiverNode.Text;
  AMemberName := MemberNode.Text;
  AMemberOffset := MemberNode.ByteOffset;
  if ACallNode.NodeKind = gnkFunctionCall then
    AArgCount := ACallNode.ChildCount - 1
  else if InnerCallNode <> nil then
    AArgCount := InnerCallNode.ChildCount - 1
  else
    AArgCount := 0;
  Result := (AReceiverName <> '') and (AMemberName <> '');
end;

end.
