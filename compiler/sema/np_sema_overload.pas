{**
 * np_sema_overload.pas
 *
 * 重载解析模块 — 从 TSemanticAnalyzer 提取
 *
 * 职责：
 *   - 参数计数与签名（CountDeclParams, GetParamSignature 等）
 *   - 名称重整（MangledName, MangledNameSig）
 *   - 重载查找（HasOverload, LookupOverload, LookupCallBindingDeclaration）
 *   - 调用绑定（TryRegisterMemberCallBinding 等）
 *   - 调用合约（TryGetDirectCallContract 等）
 *
 * 对标：rustc 的 fn_ctxt/overload_resolution
 *}

unit np_sema_overload;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  np_green_tree;

type
  TProcedureBodyEntry = record
    Name: string;
    Body: TGreenNode;
    Decl: TGreenNode;
    OwnerUnitId: string;
    ScopeId: LongInt;
  end;
  TProcedureBodyArray = array of TProcedureBodyEntry;
  TTypeIdArray = array of LongInt;

  TStringArray = array of string;

  { 参数签名结果 }
  TParamSignatureResult = record
    Signature: string;
    ParamCount: LongInt;
    RequiredParamCount: LongInt;
  end;

  {**
   * 统计声明中的参数数量
   *}
  function CountDeclParams(const ADecl: TGreenNode): LongInt;

  {**
   * 统计声明中必需的参数数量（排除有默认值的参数）
   *}
  function CountRequiredDeclParams(const ADecl: TGreenNode): LongInt;

  {**
   * 检查声明是否接受指定数量的参数
   *}
  function DeclAcceptsArgCount(const ADecl: TGreenNode; const AArgCount: LongInt): Boolean;

  {**
   * 名称重整：AName + '$' + ParamCount
   * 对标：FPC 的 mangled name 约定
   *}
  function MangledName(const AName: string; AParamCount: LongInt): string;

  {**
   * 名称重整：AName + '$' + Signature
   *}
  function MangledNameSig(const AName, ASig: string): string;

function HasOverload(const AName: string;
  const AProcedureBodies: TProcedureBodyArray): Boolean;
function LookupOverload(const AName: string; AArgCount: LongInt;
  const AProcedureBodies: TProcedureBodyArray;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;

function TypeIdArrayHasKnownTypes(const ATypeIds: TTypeIdArray): Boolean;
function GetParamIdentitySignature(const ADecl: TGreenNode): string;

implementation

function CountDeclParams(const ADecl: TGreenNode): LongInt;
var
  J, K: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := 0;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
          Inc(Result);
      end;
      Exit;
    end;
  end;
end;

function CountRequiredDeclParams(const ADecl: TGreenNode): LongInt;
var
  J, K: LongInt;
  Child, ParamChild: TGreenNode;
begin
  Result := 0;
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) and
          (ParamChild.ChildCount <= 1) then
          Inc(Result);
      end;
      Exit;
    end;
  end;
end;

function DeclAcceptsArgCount(const ADecl: TGreenNode; const AArgCount: LongInt): Boolean;
var
  MaxParamCount: LongInt;
  MinParamCount: LongInt;
begin
  MaxParamCount := CountDeclParams(ADecl);
  MinParamCount := CountRequiredDeclParams(ADecl);
  Result := (AArgCount >= MinParamCount) and (AArgCount <= MaxParamCount);
end;

function MangledName(const AName: string; AParamCount: LongInt): string;
begin
  if AParamCount = 0 then
    Result := AName
  else
    Result := AName + '$' + IntToStr(AParamCount);
end;

function MangledNameSig(const AName, ASig: string): string;
begin
  if ASig = '' then
    Result := AName
  else
    Result := AName + '$' + ASig;
end;


function HasOverload(const AName: string;
  const AProcedureBodies: TProcedureBodyArray): Boolean;
var
  Index, Count: LongInt;
begin
  Count := 0;
  for Index := 0 to Length(AProcedureBodies) - 1 do
    if SameText(AProcedureBodies[Index].Name, AName) then
      Inc(Count);
  Result := Count > 1;
end;

function LookupOverload(const AName: string; AArgCount: LongInt;
  const AProcedureBodies: TProcedureBodyArray;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  for Index := 0 to Length(AProcedureBodies) - 1 do
    if SameText(AProcedureBodies[Index].Name, AName) and
      DeclAcceptsArgCount(AProcedureBodies[Index].Decl, AArgCount) then
    begin
      ABody := AProcedureBodies[Index].Body;
      ADecl := AProcedureBodies[Index].Decl;
      Exit(True);
    end;
  Result := False;
end;


function TypeIdArrayHasKnownTypes(const ATypeIds: TTypeIdArray): Boolean;
var
  Index: LongInt;
begin
  Result := Length(ATypeIds) = 0;
  if Result then
    Exit;
  for Index := 0 to Length(ATypeIds) - 1 do
    if ATypeIds[Index] > 0 then
      Exit(True);
  Result := False;
end;

function GetParamIdentitySignature(const ADecl: TGreenNode): string;
var
  Child: TGreenNode;
  Index: LongInt;
  ParamChild: TGreenNode;
  ParamIndex: LongInt;
  TypeChild: TGreenNode;
  TypeName: string;
begin
  Result := '';
  if ADecl = nil then
    Exit;
  for Index := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(Index);
    if (Child = nil) or (Child.NodeKind <> gnkParameterList) then
      Continue;
    ParamIndex := 0;
    while ParamIndex < Child.ChildCount do
    begin
      ParamChild := Child.ChildAt(ParamIndex);
      if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
      begin
        TypeName := '';
        if ParamChild.ChildCount > 0 then
        begin
          TypeChild := ParamChild.ChildAt(0);
          if TypeChild <> nil then
            TypeName := LowerCase(TypeChild.Text);
        end;
        if Result <> '' then
          Result := Result + '|';
        Result := Result + TypeName;
      end;
      Inc(ParamIndex);
    end;
    Exit;
  end;
end;

end.
