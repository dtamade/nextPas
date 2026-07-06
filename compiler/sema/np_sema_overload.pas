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
   * 名称重整：AName + '$' + ParamCount
   * 对标：FPC 的 mangled name 约定
   *}
  function MangledName(const AName: string; AParamCount: LongInt): string;

  {**
   * 名称重整：AName + '$' + Signature
   *}
  function MangledNameSig(const AName, ASig: string): string;

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

end.
