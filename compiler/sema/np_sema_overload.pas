{**
 * np_sema_overload.pas
 *
 * 重载解析模块 — 从 TSemanticAnalyzer 提取
 *
 * 对标：rustc 的 fn_ctxt/overload_resolution
 *}

unit np_sema_overload;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  np_green_tree,
  np_unit_graph,
  np_ast_facade,
  np_semantic_model,
  np_sema_builtins,
  np_sema_type_check;

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
  TParamSignatureResult = record
    Signature: string;
    ParamCount: LongInt;
    RequiredParamCount: LongInt;
  end;

  { 重载解析上下文 }
  TSemaOverloadContext = record
    Model: TSemanticModel;
    UnitGraph: TUnitGraph;
    RootAst: TAstFacade;
    CurrentProcessingUnitId: string;
    CurrentScopeId: LongInt;
    ProcedureBodies: TProcedureBodyArray;
    ImportedUnitOwners: array of string;
    ImportedUnitTrees: array of TGreenTree;
    BuiltinRegistry: TBuiltinRegistry;
    PC: LongInt;
  end;

  { 单元导入查询上下文 }
  TSemaImportContext = record
    UnitGraph: TUnitGraph;
    RootAst: TAstFacade;
    ImportedUnitOwners: array of string;
    ImportedUnitTrees: array of TGreenTree;
  end;

function CountDeclParams(const ADecl: TGreenNode): LongInt;
function CountRequiredDeclParams(const ADecl: TGreenNode): LongInt;
function DeclAcceptsArgCount(const ADecl: TGreenNode; const AArgCount: LongInt): Boolean;
function MangledName(const AName: string; AParamCount: LongInt): string;
function MangledNameSig(const AName, ASig: string): string;
function HasOverload(const AName: string;
  const AProcedureBodies: TProcedureBodyArray): Boolean;
function LookupOverload(const AName: string; AArgCount: LongInt;
  const AProcedureBodies: TProcedureBodyArray;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
function TypeIdArrayHasKnownTypes(const ATypeIds: TTypeIdArray): Boolean;
function GetParamIdentitySignature(const ADecl: TGreenNode): string;

{ 单元导入查询 }
function OwnerUnitAllowsProjectSourceDiagnostic(
  const Ctx: TSemaImportContext; const AOwnerUnitId: string): Boolean;
function UnitDirectlyImports(
  const Ctx: TSemaImportContext;
  const AOwnerUnitId, AImportedUnitId: string): Boolean;

{ === 重载解析核心 — 从 TSemanticAnalyzer 提取 === }

function GetParamSignature(const Ctx: TSemaOverloadContext; const ADecl: TGreenNode): string;
function DeclParamSignatureMatchesArgs(const Ctx: TSemaOverloadContext;
  const ADecl: TGreenNode;
  const AArgSignature: string;
  const AArgCount: LongInt): Boolean;
function DeclParamTypesExactMatch(const Ctx: TSemaOverloadContext;
  const ADecl: TGreenNode;
  const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray;
  const AArgCount: LongInt): Boolean;
function DeclParamTypesCompatibleMatch(const Ctx: TSemaOverloadContext;
  const ADecl: TGreenNode;
  const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray;
  const AArgCount: LongInt): Boolean;
function CanonicalTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): LongInt;
function ParamDeclTypeId(const Ctx: TSemaOverloadContext;
  const AParamDecl: TGreenNode;
  const AOwnerUnitId: string): LongInt;
function AreTypesCompatible(const Ctx: TSemaOverloadContext;
  const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
function IsPointerTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): Boolean;
function ResolveTypeId(const Ctx: TSemaOverloadContext; const ATypeName: string): LongInt;
function ResolveTypeIdForOwner(const Ctx: TSemaOverloadContext;
  const ATypeName: string;
  const APreferredOwnerUnitId: string;
  const AAllowDirectImportSearch: Boolean = True): LongInt;
function TypeSignatureForTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): string;
function LookupCallBindingDeclaration(const Ctx: TSemaOverloadContext;
  const AName: string;
  const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ABody: TGreenNode;
  out ADecl: TGreenNode;
  out AOwnerUnitId: string): Boolean;

{ 辅助查询函数 }
function HasInstalledSourceImports(const Ctx: TSemaOverloadContext): Boolean;

{ 重载：接受 TSemaOverloadContext 的导入查询函数 }
function OwnerUnitAllowsProjectSourceDiagnostic(
  const Ctx: TSemaOverloadContext; const AOwnerUnitId: string): Boolean; overload;
function UnitDirectlyImports(
  const Ctx: TSemaOverloadContext;
  const AOwnerUnitId, AImportedUnitId: string): Boolean; overload;

implementation

{ === 重载解析核心实现 === }

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

function OwnerUnitAllowsProjectSourceDiagnostic(
  const Ctx: TSemaImportContext; const AOwnerUnitId: string): Boolean;
var
  ResolvedUnit: TResolvedUnit;
begin
  Result := False;
  if Trim(AOwnerUnitId) = '' then
    Exit;
  if not Ctx.UnitGraph.FindUnit(AOwnerUnitId, ResolvedUnit) then
    Exit;
  Result := SameText(ResolvedUnit.OriginClass, 'project-source');
end;

function UnitDirectlyImports(
  const Ctx: TSemaImportContext;
  const AOwnerUnitId, AImportedUnitId: string): Boolean;
var
  ImportId: string;
  Index: LongInt;
  OwnerUnitId: string;
  UnitTree: TGreenTree;
  UseIndex: LongInt;
begin
  Result := False;
  if (Trim(AOwnerUnitId) = '') or (Trim(AImportedUnitId) = '') then
    Exit;

  OwnerUnitId := NormalizeUnitIdentity(AOwnerUnitId);
  ImportId := NormalizeUnitIdentity(AImportedUnitId);
  if (OwnerUnitId = '') or (ImportId = '') then
    Exit;

  if SameText(OwnerUnitId, NormalizeUnitIdentity(Ctx.UnitGraph.RootName)) then
  begin
    for UseIndex := 0 to Ctx.RootAst.InterfaceUseCount - 1 do
      if SameText(NormalizeUnitIdentity(Ctx.RootAst.InterfaceUseAt(UseIndex)),
        ImportId) then
        Exit(True);
    for UseIndex := 0 to Ctx.RootAst.ImplementationUseCount - 1 do
      if SameText(NormalizeUnitIdentity(Ctx.RootAst.ImplementationUseAt(UseIndex)),
        ImportId) then
        Exit(True);
    Exit(False);
  end;

  for Index := 0 to Length(Ctx.ImportedUnitTrees) - 1 do
  begin
    if not SameText(Ctx.ImportedUnitOwners[Index], OwnerUnitId) then
      Continue;
    UnitTree := Ctx.ImportedUnitTrees[Index];
    if UnitTree = nil then
      Exit(False);
    for UseIndex := 0 to UnitTree.InterfaceUseCount - 1 do
      if SameText(NormalizeUnitIdentity(UnitTree.InterfaceUseAt(UseIndex)),
        ImportId) then
        Exit(True);
    for UseIndex := 0 to UnitTree.ImplementationUseCount - 1 do
      if SameText(NormalizeUnitIdentity(
        UnitTree.ImplementationUseAt(UseIndex)), ImportId) then
        Exit(True);
    Exit(False);
  end;
end;

function GetParamSignature(const Ctx: TSemaOverloadContext; const ADecl: TGreenNode): string;
var
  J, K: LongInt;
  Child, ParamChild, TypeChild: TGreenNode;
  TypeId: LongInt;
  TypeName: string;
  Dummy: Int64;
  LTypeId: LongInt;
  TypeSig: string;
begin
  Result := '';
  if ADecl = nil then Exit;
  for J := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
    begin
      for K := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(K);
        if (ParamChild = nil) or (ParamChild.NodeKind <> gnkParameterDecl) then
          Continue;
        TypeName := '';
        TypeChild := nil;
        if ParamChild.ChildCount > 0 then
        begin
          TypeChild := ParamChild.ChildAt(0);
          if TypeChild <> nil then
            TypeName := LowerCase(TypeChild.Text);
        end;
        TypeId := 0;
        if TypeChild <> nil then
        begin
          TypeId := ResolveTypeIdForOwner(Ctx, 
            TypeChild.Text,
            NormalizeUnitIdentity(Ctx.CurrentProcessingUnitId)
          );
          if TypeId <= 0 then
            TypeId := ResolveTypeIdForOwner(Ctx, 
              TypeChild.Text,
              NormalizeUnitIdentity(Ctx.UnitGraph.RootName)
            );
          if TypeId <= 0 then
            TypeId := ResolveTypeId(Ctx, TypeChild.Text);
        end;
        TypeSig := TypeSignatureForTypeId(Ctx, TypeId);
        if TypeSig <> '' then
          Result := Result + TypeSig
        else if (TypeName = 'string') or (TypeName = 'ansistring') then
          Result := Result + 's'
        else if (TypeName = 'boolean') or (TypeName = 'bool') then
          Result := Result + 'b'
        else if (TypeChild <> nil) and TypeMetaIsRecord(Ctx.Model, TypeChild.Text) then
          Result := Result + 'r'
        else if (TypeChild <> nil) and TypeIsInterfaceByName(Ctx.Model, TypeChild.Text) then
          Result := Result + 'f'
        else if SameText(TypeName, 'integer') or SameText(TypeName, 'longint') or
          SameText(TypeName, 'longword') or SameText(TypeName, 'cardinal') or
          SameText(TypeName, 'smallint') or SameText(TypeName, 'word') or
          SameText(TypeName, 'byte') or SameText(TypeName, 'shortint') or
          SameText(TypeName, 'int64') or SameText(TypeName, 'qword') or
          SameText(TypeName, 'uint64') or SameText(TypeName, 'sizeint') or
          SameText(TypeName, 'sizeuint') or SameText(TypeName, 'uint32') or
          SameText(TypeName, 'ptruint') or SameText(TypeName, 'ptrint') then
          Result := Result + 'i'
        else if (TypeChild <> nil) then
        begin
          LTypeId := Ctx.Model.FindTypeByName(TypeChild.Text);
          if (LTypeId > 0) and
            SameText(Ctx.Model.TypeAt(LTypeId - 1).Kind, 'class') then
            Result := Result + 'c'
          else if TypeMetaIsClass(Ctx.Model, TypeChild.Text) then
            Result := Result + 'c'
          else if TypeMetaSize(Ctx.Model, TypeChild.Text) > 0 then
            Result := Result + 'p'
          else
            Result := Result + 'i';
        end
        else
          Result := Result + 'i';
      end;
      Exit;
    end;
  end;
end;


function DeclParamSignatureMatchesArgs(const Ctx: TSemaOverloadContext; 
  const ADecl: TGreenNode;
  const AArgSignature: string;
  const AArgCount: LongInt
): Boolean;
var
  I: LongInt;
  ParamSignature: string;
begin
  ParamSignature := GetParamSignature(Ctx, ADecl);
  if (AArgCount >= 0) and (Length(ParamSignature) >= AArgCount) and
    SameText(Copy(ParamSignature, 1, AArgCount), AArgSignature) then
    Exit(True);
  { Char → String promotion: 'i' arg matches 's' param }
  if (AArgCount > 0) and (Length(ParamSignature) >= AArgCount) then
  begin
    Result := True;
    for I := 1 to AArgCount do
    begin
      if (ParamSignature[I] = 's') and (I <= Length(AArgSignature)) and
        (AArgSignature[I] = 'i') then
        Continue;
      if (I <= Length(AArgSignature)) and
        SameText(ParamSignature[I], AArgSignature[I]) then
        Continue;
      Result := False;
      Break;
    end;
  end
  else
    Result := False;
end;


function DeclParamTypesExactMatch(const Ctx: TSemaOverloadContext; 
  const ADecl: TGreenNode;
  const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray;
  const AArgCount: LongInt
): Boolean;
var
  Child: TGreenNode;
  ChildIndex: LongInt;
  LeftFact: TSemanticScalarTypeFact;
  RightFact: TSemanticScalarTypeFact;
  ParamEntryIndex: LongInt;
  ParamDecl: TGreenNode;
  ParamIndex: LongInt;
  ParamTypeId: LongInt;
begin
  Result := False;
  if (ADecl = nil) or (AArgCount < 0) or
    (Length(AArgTypeIds) <> AArgCount) then
    Exit;

  for ChildIndex := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(ChildIndex);
    if (Child = nil) or (Child.NodeKind <> gnkParameterList) then
      Continue;

    ParamIndex := 0;
    for ParamEntryIndex := 0 to Child.ChildCount - 1 do
    begin
      ParamDecl := Child.ChildAt(ParamEntryIndex);
      if (ParamDecl = nil) or (ParamDecl.NodeKind <> gnkParameterDecl) then
        Continue;
      if ParamIndex >= AArgCount then
        Break;
      ParamTypeId := ParamDeclTypeId(Ctx, ParamDecl, AOwnerUnitId);
      if (ParamTypeId > 0) and (AArgTypeIds[ParamIndex] > 0) and
        (CanonicalTypeId(Ctx, ParamTypeId) <>
         CanonicalTypeId(Ctx, AArgTypeIds[ParamIndex])) then
      begin
        if not (
          Ctx.Model.GetTypeScalarFact(CanonicalTypeId(Ctx, ParamTypeId), LeftFact) and
          Ctx.Model.GetTypeScalarFact(CanonicalTypeId(Ctx, AArgTypeIds[ParamIndex]), RightFact) and
          (LeftFact.Kind in [sskBool, sskInt, sskFloat]) and
          (RightFact.Kind = LeftFact.Kind) and
          (RightFact.BitWidth = LeftFact.BitWidth) and
          (RightFact.Signed = LeftFact.Signed)
        ) then
          Exit(False);
      end;
      Inc(ParamIndex);
    end;
    Exit(ParamIndex = AArgCount);
  end;
  Result := AArgCount = 0;
end;


function DeclParamTypesCompatibleMatch(const Ctx: TSemaOverloadContext; 
  const ADecl: TGreenNode;
  const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray;
  const AArgCount: LongInt
): Boolean;
var
  Child: TGreenNode;
  ChildIndex: LongInt;
  ParamEntryIndex: LongInt;
  ParamDecl: TGreenNode;
  ParamIndex: LongInt;
  ParamTypeId: LongInt;
begin
  Result := False;
  if (ADecl = nil) or (AArgCount < 0) or
    (Length(AArgTypeIds) <> AArgCount) then
    Exit;

  for ChildIndex := 0 to ADecl.ChildCount - 1 do
  begin
    Child := ADecl.ChildAt(ChildIndex);
    if (Child = nil) or (Child.NodeKind <> gnkParameterList) then
      Continue;

    ParamIndex := 0;
    for ParamEntryIndex := 0 to Child.ChildCount - 1 do
    begin
      ParamDecl := Child.ChildAt(ParamEntryIndex);
      if (ParamDecl = nil) or (ParamDecl.NodeKind <> gnkParameterDecl) then
        Continue;
      if ParamIndex >= AArgCount then
        Break;
      ParamTypeId := ParamDeclTypeId(Ctx, ParamDecl, AOwnerUnitId);
      if (ParamTypeId > 0) and (AArgTypeIds[ParamIndex] > 0) and
        not AreTypesCompatible(Ctx, ParamTypeId, AArgTypeIds[ParamIndex]) then
        Exit(False);
      Inc(ParamIndex);
    end;
    Exit(ParamIndex = AArgCount);
  end;
  Result := AArgCount = 0;
end;


function CanonicalTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): LongInt;
var
  CurrentTypeId: LongInt;
  Depth: LongInt;
  Meta: TTypeMetadata;
begin
  CurrentTypeId := ATypeId;
  Depth := 0;
  while (CurrentTypeId > 0) and (CurrentTypeId <= Ctx.Model.TypeCount) and
    (Depth < 16) do
  begin
    if Ctx.Model.GetTypeMeta(CurrentTypeId, Meta) and
      (Meta.AliasTargetTypeId > 0) and
      (Meta.AliasTargetTypeId <> CurrentTypeId) then
      CurrentTypeId := Meta.AliasTargetTypeId
    else
      Break;
    Inc(Depth);
  end;
  Result := CurrentTypeId;
end;


function ParamDeclTypeId(const Ctx: TSemaOverloadContext; 
  const AParamDecl: TGreenNode;
  const AOwnerUnitId: string
): LongInt;
var
  TypeChild: TGreenNode;
begin
  Result := 0;
  if (AParamDecl = nil) or (AParamDecl.ChildCount <= 0) then
    Exit;
  TypeChild := AParamDecl.ChildAt(0);
  if (TypeChild = nil) or (TypeChild.NodeKind <> gnkIdentifier) then
    Exit;
  Result := ResolveTypeIdForOwner(Ctx, TypeChild.Text, AOwnerUnitId);
  if Result <= 0 then
    Result := ResolveTypeIdForOwner(Ctx, 
      TypeChild.Text,
      NormalizeUnitIdentity(Ctx.UnitGraph.RootName)
    );
  if Result <= 0 then
    Result := ResolveTypeId(Ctx, TypeChild.Text);
end;


function AreTypesCompatible(const Ctx: TSemaOverloadContext; 
  const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
var
  IntIds: array[0..16] of LongInt;
  StrIds: array[0..4] of LongInt;
  I: LongInt;
  LhsIsInt, RhsIsInt, LhsIsStr, RhsIsStr: Boolean;
  CharTypeId, WideCharTypeId: LongInt;
  CanonicalLhsTypeId, CanonicalRhsTypeId: LongInt;
begin
  if ALhsTypeId = ARhsTypeId then
    Exit(True);
  if (ALhsTypeId = 0) or (ARhsTypeId = 0) then
    Exit(True);

  CanonicalLhsTypeId := CanonicalTypeId(Ctx, ALhsTypeId);
  CanonicalRhsTypeId := CanonicalTypeId(Ctx, ARhsTypeId);
  if CanonicalLhsTypeId = CanonicalRhsTypeId then
    Exit(True);
  if Ctx.Model.IsTypeDescendantOf(CanonicalRhsTypeId, CanonicalLhsTypeId) then
    Exit(True);
  if Ctx.Model.IsTypeDescendantOf(CanonicalLhsTypeId, CanonicalRhsTypeId) then
    Exit(True);
  if IsPointerTypeId(Ctx, CanonicalLhsTypeId) and IsPointerTypeId(Ctx, CanonicalRhsTypeId) then
    Exit(True);

  IntIds[0] := Ctx.Model.FindTypeByName('Byte');
  IntIds[1] := Ctx.Model.FindTypeByName('Word');
  IntIds[2] := Ctx.Model.FindTypeByName('LongInt');
  IntIds[3] := Ctx.Model.FindTypeByName('Integer');
  IntIds[4] := Ctx.Model.FindTypeByName('Int64');
  IntIds[5] := Ctx.Model.FindTypeByName('QWord');
  IntIds[6] := Ctx.Model.FindTypeByName('LongWord');
  IntIds[7] := Ctx.Model.FindTypeByName('ShortInt');
  IntIds[8] := Ctx.Model.FindTypeByName('SmallInt');
  IntIds[9] := Ctx.Model.FindTypeByName('Int32');
  IntIds[10] := Ctx.Model.FindTypeByName('UInt32');
  IntIds[11] := Ctx.Model.FindTypeByName('UInt64');
  IntIds[12] := Ctx.Model.FindTypeByName('WideChar');
  IntIds[13] := Ctx.Model.FindTypeByName('Single');
  IntIds[14] := Ctx.Model.FindTypeByName('Double');
  IntIds[15] := Ctx.Model.FindTypeByName('AnsiChar');
  IntIds[16] := Ctx.Model.FindTypeByName('Char');

  LhsIsInt := False;
  RhsIsInt := False;
  for I := 0 to High(IntIds) do
  begin
    if CanonicalLhsTypeId = IntIds[I] then LhsIsInt := True;
    if CanonicalRhsTypeId = IntIds[I] then RhsIsInt := True;
  end;
  if LhsIsInt and RhsIsInt then
    Exit(True);

  StrIds[0] := Ctx.Model.FindTypeByName('AnsiString');
  StrIds[1] := Ctx.Model.FindTypeByName('ShortString');
  StrIds[2] := Ctx.Model.FindTypeByName('WideString');
  StrIds[3] := Ctx.Model.FindTypeByName('UnicodeString');
  StrIds[4] := Ctx.Model.FindTypeByName('RawByteString');

  LhsIsStr := False;
  RhsIsStr := False;
  for I := 0 to High(StrIds) do
  begin
    if CanonicalLhsTypeId = StrIds[I] then LhsIsStr := True;
    if CanonicalRhsTypeId = StrIds[I] then RhsIsStr := True;
  end;
  if LhsIsStr and RhsIsStr then
    Exit(True);

  if CanonicalLhsTypeId = Ctx.Model.FindTypeByName('Boolean') then
    Exit(CanonicalRhsTypeId = Ctx.Model.FindTypeByName('Boolean'));

  CharTypeId := Ctx.Model.FindTypeByName('Char');
  WideCharTypeId := Ctx.Model.FindTypeByName('WideChar');
  if LhsIsStr and ((CanonicalRhsTypeId = CharTypeId) or
    (CanonicalRhsTypeId = WideCharTypeId)) then
    Exit(True);
  if ((CanonicalLhsTypeId = CharTypeId) or
    (CanonicalLhsTypeId = WideCharTypeId)) and RhsIsStr then
    Exit(True);
  if ((CanonicalLhsTypeId = CharTypeId) or
    (CanonicalLhsTypeId = WideCharTypeId)) and
    ((CanonicalRhsTypeId = CharTypeId) or
     (CanonicalRhsTypeId = WideCharTypeId)) then
    Exit(True);

  { String literal → PAnsiChar / PChar implicit conversion }
  if RhsIsStr and IsPointerTypeId(Ctx, CanonicalLhsTypeId) then
    Exit(True);

  { Single-char string literal → Char/AnsiChar/WideChar implicit conversion }
  if RhsIsStr and ((CanonicalLhsTypeId = CharTypeId) or
    (CanonicalLhsTypeId = WideCharTypeId) or
    (CanonicalLhsTypeId = Ctx.Model.FindTypeByName('AnsiChar'))) then
    Exit(True);

  Result := False;
end;


function IsPointerTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): Boolean;
var
  CurrentTypeId: LongInt;
  Fact: TSemanticScalarTypeFact;
begin
  Result := False;
  CurrentTypeId := CanonicalTypeId(Ctx, ATypeId);
  while (CurrentTypeId > 0) and (CurrentTypeId <= Ctx.Model.TypeCount) do
  begin
    if Ctx.Model.GetTypeScalarFact(CurrentTypeId, Fact) and
      (Fact.Kind = sskPointer) then
      Exit(True);
    CurrentTypeId := Ctx.Model.TypeAt(CurrentTypeId - 1).ParentTypeId;
  end;
end;


function ResolveTypeId(const Ctx: TSemaOverloadContext; const ATypeName: string): LongInt;
begin
  Result := ResolveTypeIdForOwner(Ctx, ATypeName, '', True);
end;

function ResolveTypeIdForOwner(const Ctx: TSemaOverloadContext; 
  const ATypeName: string;
  const APreferredOwnerUnitId: string;
  const AAllowDirectImportSearch: Boolean
): LongInt;
var
  CandidateSeen: Boolean;
  DirectImportMatchCount: LongInt;
  DotPos: LongInt;
  I: LongInt;
  Index: LongInt;
  NormalizedOwnerUnitId: string;
  PreferredMatchCount: LongInt;
  QualifiedOwnerUnitId: string;
  ShortTypeName: string;
  Symbol: TSemanticSymbol;
  UniqueTypeId: LongInt;
begin
  if ATypeName = '' then
    Exit(0);
  if SameText(ATypeName, 'String') then
    Exit(Ctx.Model.FindTypeByName('AnsiString'));
  if SameText(ATypeName, 'Cardinal') then
    Exit(Ctx.Model.FindTypeByName('LongWord'));
  if SameText(ATypeName, 'Real') then
    Exit(Ctx.Model.FindTypeByName('Double'));
  if SameText(ATypeName, 'Extended') then
    Exit(Ctx.Model.FindTypeByName('Double'));

  DotPos := 0;
  for I := Length(ATypeName) downto 1 do
    if ATypeName[I] = '.' then
    begin
      DotPos := I;
      Break;
    end;
  if (DotPos > 1) and (DotPos < Length(ATypeName)) then
  begin
    QualifiedOwnerUnitId := NormalizeUnitIdentity(
      Copy(ATypeName, 1, DotPos - 1)
    );
    ShortTypeName := Copy(ATypeName, DotPos + 1, MaxInt);
    if (QualifiedOwnerUnitId <> '') and (ShortTypeName <> '') then
    begin
      PreferredMatchCount := 0;
      UniqueTypeId := 0;
      for Index := 0 to Ctx.Model.SymbolCount - 1 do
      begin
        Symbol := Ctx.Model.SymbolAt(Index);
        if SameText(Symbol.Kind, 'type') and
          SameText(Symbol.Name, ShortTypeName) and
          SameText(Symbol.OwnerUnitId, QualifiedOwnerUnitId) and
          (Symbol.TypeId > 0) and (Symbol.TypeId <= Ctx.Model.TypeCount) then
        begin
          Inc(PreferredMatchCount);
          if UniqueTypeId = 0 then
            UniqueTypeId := Symbol.TypeId
          else if UniqueTypeId <> Symbol.TypeId then
          begin
            if SameText(Ctx.Model.TypeAt(Symbol.TypeId - 1).Kind, 'class') or
              SameText(Ctx.Model.TypeAt(Symbol.TypeId - 1).Kind, 'interface') then
              UniqueTypeId := Symbol.TypeId
            else if not (SameText(Ctx.Model.TypeAt(UniqueTypeId - 1).Kind, 'class') or
              SameText(Ctx.Model.TypeAt(UniqueTypeId - 1).Kind, 'interface')) then
              Exit(0);
          end;
        end;
      end;
      if PreferredMatchCount >= 1 then
        Exit(UniqueTypeId);
    end;
  end;

  NormalizedOwnerUnitId := NormalizeUnitIdentity(APreferredOwnerUnitId);
  if NormalizedOwnerUnitId <> '' then
  begin
    PreferredMatchCount := 0;
    UniqueTypeId := 0;
    for Index := 0 to Ctx.Model.SymbolCount - 1 do
    begin
      Symbol := Ctx.Model.SymbolAt(Index);
      if SameText(Symbol.Kind, 'type') and
        SameText(Symbol.Name, ATypeName) and
        SameText(Symbol.OwnerUnitId, NormalizedOwnerUnitId) and
        (Symbol.TypeId > 0) and (Symbol.TypeId <= Ctx.Model.TypeCount) then
      begin
        Inc(PreferredMatchCount);
        if UniqueTypeId = 0 then
          UniqueTypeId := Symbol.TypeId
        else if UniqueTypeId <> Symbol.TypeId then
        begin
          if SameText(Ctx.Model.TypeAt(Symbol.TypeId - 1).Kind, 'class') or
            SameText(Ctx.Model.TypeAt(Symbol.TypeId - 1).Kind, 'interface') then
            UniqueTypeId := Symbol.TypeId
          else if SameText(Ctx.Model.TypeAt(UniqueTypeId - 1).Kind, 'class') or
            SameText(Ctx.Model.TypeAt(UniqueTypeId - 1).Kind, 'interface') then
            { Keep existing class/interface UniqueTypeId }
          else
            { Neither is class/interface yet — prefer later entry }
            UniqueTypeId := Symbol.TypeId;
        end;
      end;
    end;
    if PreferredMatchCount >= 1 then
      Exit(UniqueTypeId);

    if AAllowDirectImportSearch then
    begin
      DirectImportMatchCount := 0;
      UniqueTypeId := 0;
      for Index := 0 to Ctx.Model.SymbolCount - 1 do
      begin
        Symbol := Ctx.Model.SymbolAt(Index);
        if SameText(Symbol.Kind, 'type') and
          SameText(Symbol.Name, ATypeName) and
          UnitDirectlyImports(Ctx, NormalizedOwnerUnitId, Symbol.OwnerUnitId) and
          (Symbol.TypeId > 0) and (Symbol.TypeId <= Ctx.Model.TypeCount) then
        begin
          Inc(DirectImportMatchCount);
          { Prefer later entry (full definition over forward declaration) }
          UniqueTypeId := Symbol.TypeId;
        end;
      end;
      if DirectImportMatchCount >= 1 then
        Exit(UniqueTypeId);
    end;
  end;

  CandidateSeen := False;
  UniqueTypeId := 0;
  for Index := 0 to Ctx.Model.SymbolCount - 1 do
  begin
    Symbol := Ctx.Model.SymbolAt(Index);
    if SameText(Symbol.Kind, 'type') and SameText(Symbol.Name, ATypeName) and
      (Symbol.TypeId > 0) and (Symbol.TypeId <= Ctx.Model.TypeCount) then
    begin
      { Prefer later type entry (full definition over forward declaration) }
      UniqueTypeId := Symbol.TypeId;
      CandidateSeen := True;
    end;
  end;
  if CandidateSeen then
    Exit(UniqueTypeId);

  Result := Ctx.Model.FindTypeByName(ATypeName);
end;


function TypeSignatureForTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): string;
var
  Fact: TSemanticScalarTypeFact;
  TypeName: string;
  TypeInfo: TSemanticType;
  Dummy: Int64;
  Meta: TTypeMetadata;
begin
  Result := '';
  if (ATypeId <= 0) or (ATypeId > Ctx.Model.TypeCount) then
    Exit;

  TypeInfo := Ctx.Model.TypeAt(ATypeId - 1);
  TypeName := TypeInfo.Name;
  if (TypeName = '') then
    Exit;
  if SameText(TypeName, 'String') or SameText(TypeName, 'AnsiString') or
    SameText(TypeName, 'RawByteString') or
    SameText(TypeName, 'ShortString') or SameText(TypeName, 'WideString') or
    SameText(TypeName, 'UnicodeString') then
    Exit('s');
  if SameText(TypeName, 'Boolean') then
    Exit('b');
  if SameText(TypeName, 'Integer') or SameText(TypeName, 'LongInt') or
    SameText(TypeName, 'LongWord') or SameText(TypeName, 'Cardinal') or
    SameText(TypeName, 'SmallInt') or SameText(TypeName, 'Word') or
    SameText(TypeName, 'Byte') or SameText(TypeName, 'ShortInt') or
    SameText(TypeName, 'Int64') or SameText(TypeName, 'QWord') or
    SameText(TypeName, 'UInt64') or SameText(TypeName, 'SizeInt') or
    SameText(TypeName, 'SizeUInt') or SameText(TypeName, 'UInt32') or
    SameText(TypeName, 'PtrUInt') or SameText(TypeName, 'PtrInt') then
    Exit('i');
  if Ctx.Model.GetTypeScalarFact(ATypeId, Fact) and (Fact.Kind = sskPointer) then
    Exit('p');
  if Ctx.Model.GetTypeMeta(ATypeId, Meta) then
  begin
    if Meta.IsRecord then
      Exit('r');
    if TypeIsInterfaceByName(Ctx.Model, TypeName) then
      Exit('f');
    if SameText(TypeInfo.Kind, 'class') then
      Exit('c');
    Exit('p');
  end;
  if TypeMetaIsRecord(Ctx.Model, TypeName) then
    Exit('r');
  if TypeIsInterfaceByName(Ctx.Model, TypeName) then
    Exit('f');
  if TypeMetaIsClass(Ctx.Model, TypeName) then
    Exit('c');
  if TypeMetaSize(Ctx.Model, TypeName) > 0 then
    Exit('p');
  Result := 'i';
end;


function LookupCallBindingDeclaration(const Ctx: TSemaOverloadContext; 
  const AName: string;
  const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ABody: TGreenNode;
  out ADecl: TGreenNode;
  out AOwnerUnitId: string
): Boolean;
var
  DirectImportCompatibleMatchCount: LongInt;
  DirectImportCompatibleMatchIndex: LongInt;
  DirectImportExactMatchCount: LongInt;
  DirectImportExactMatchIndex: LongInt;
  HasArgTypeIds: Boolean;
  Index: LongInt;
  ImportedDiagnosticMatchCount: LongInt;
  ImportedMatchCount: LongInt;
  ImportedMatchIndex: LongInt;
  ImportedDiagnosticNameCount: LongInt;
  ImportedNameCount: LongInt;
  ImportedCompatibleMatchCount: LongInt;
  ImportedCompatibleMatchIndex: LongInt;
  ImportedDiagnosticSignatureMatchCount: LongInt;
  ImportedExactMatchCount: LongInt;
  ImportedExactMatchIndex: LongInt;
  ImportedSignatureMatchCount: LongInt;
  ImportedSignatureMatchIndex: LongInt;
  DirectImportMatchCount: LongInt;
  DirectImportMatchIndex: LongInt;
  KnownSymbolId: LongInt;
  RootMatchCount: LongInt;
  RootMatchIndex: LongInt;
  RootNameCount: LongInt;
  RootOwnerUnitId: string;
  RootCompatibleMatchCount: LongInt;
  RootCompatibleMatchIndex: LongInt;
  RootExactMatchCount: LongInt;
  RootExactMatchIndex: LongInt;
  RootSignatureMatchCount: LongInt;
  RootSignatureMatchIndex: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  AOwnerUnitId := '';
  AResolutionFailureKind := '';
  { 内建过程 (Write/WriteLn/Read/ReadLn 等) 可变参数，跳过重载解析 }
  if Ctx.BuiltinRegistry.IsBuiltinProcedure(AName) then
    Exit(False);
  ImportedDiagnosticMatchCount := 0;
  ImportedMatchCount := 0;
  ImportedMatchIndex := -1;
  ImportedDiagnosticNameCount := 0;
  ImportedDiagnosticSignatureMatchCount := 0;
  ImportedNameCount := 0;
  ImportedCompatibleMatchCount := 0;
  ImportedCompatibleMatchIndex := -1;
  ImportedExactMatchCount := 0;
  ImportedExactMatchIndex := -1;
  ImportedSignatureMatchCount := 0;
  ImportedSignatureMatchIndex := -1;
  DirectImportCompatibleMatchCount := 0;
  DirectImportCompatibleMatchIndex := -1;
  DirectImportExactMatchCount := 0;
  DirectImportExactMatchIndex := -1;
  DirectImportMatchCount := 0;
  DirectImportMatchIndex := -1;
  RootMatchCount := 0;
  RootMatchIndex := -1;
  RootNameCount := 0;
  RootCompatibleMatchCount := 0;
  RootCompatibleMatchIndex := -1;
  RootExactMatchCount := 0;
  RootExactMatchIndex := -1;
  RootSignatureMatchCount := 0;
  RootSignatureMatchIndex := -1;
  RootOwnerUnitId := NormalizeUnitIdentity(Ctx.UnitGraph.RootName);
  HasArgTypeIds := (Length(AArgTypeIds) = AArgCount) and
    TypeIdArrayHasKnownTypes(AArgTypeIds);

  for Index := 0 to Length(Ctx.ProcedureBodies) - 1 do
    if SameText(Ctx.ProcedureBodies[Index].Name, AName) then
    begin
      if SameText(Ctx.ProcedureBodies[Index].OwnerUnitId, RootOwnerUnitId) or
        SameText(Ctx.ProcedureBodies[Index].OwnerUnitId,
          Ctx.CurrentProcessingUnitId) then
      begin
        Inc(RootNameCount);
        if DeclAcceptsArgCount(Ctx.ProcedureBodies[Index].Decl, AArgCount) then
        begin
          RootMatchIndex := Index;
          Inc(RootMatchCount);
          if HasArgTypeIds and DeclParamTypesExactMatch(Ctx, 
            Ctx.ProcedureBodies[Index].Decl,
            Ctx.ProcedureBodies[Index].OwnerUnitId,
            AArgTypeIds,
            AArgCount
          ) then
          begin
            RootExactMatchIndex := Index;
            Inc(RootExactMatchCount);
          end
          else if HasArgTypeIds and DeclParamTypesCompatibleMatch(Ctx, 
            Ctx.ProcedureBodies[Index].Decl,
            Ctx.ProcedureBodies[Index].OwnerUnitId,
            AArgTypeIds,
            AArgCount
          ) then
          begin
            RootCompatibleMatchIndex := Index;
            Inc(RootCompatibleMatchCount);
          end;
          if AHasArgSignature and
            DeclParamSignatureMatchesArgs(Ctx, 
              Ctx.ProcedureBodies[Index].Decl,
              AArgSignature,
              AArgCount
            ) then
          begin
            RootSignatureMatchIndex := Index;
            Inc(RootSignatureMatchCount);
          end;
        end;
      end
      else
      begin
        Inc(ImportedNameCount);
        if OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[Index].OwnerUnitId
        ) then
          Inc(ImportedDiagnosticNameCount);
        if DeclAcceptsArgCount(Ctx.ProcedureBodies[Index].Decl, AArgCount) then
        begin
          ImportedMatchIndex := Index;
          Inc(ImportedMatchCount);
          if HasArgTypeIds and DeclParamTypesExactMatch(Ctx, 
            Ctx.ProcedureBodies[Index].Decl,
            Ctx.ProcedureBodies[Index].OwnerUnitId,
            AArgTypeIds,
            AArgCount
          ) then
          begin
            ImportedExactMatchIndex := Index;
            Inc(ImportedExactMatchCount);
          end
          else if HasArgTypeIds and DeclParamTypesCompatibleMatch(Ctx, 
            Ctx.ProcedureBodies[Index].Decl,
            Ctx.ProcedureBodies[Index].OwnerUnitId,
            AArgTypeIds,
            AArgCount
          ) then
          begin
            ImportedCompatibleMatchIndex := Index;
            Inc(ImportedCompatibleMatchCount);
          end;
          if UnitDirectlyImports(Ctx, RootOwnerUnitId,
            Ctx.ProcedureBodies[Index].OwnerUnitId) then
          begin
            DirectImportMatchIndex := Index;
            Inc(DirectImportMatchCount);
            if HasArgTypeIds and DeclParamTypesExactMatch(Ctx, 
              Ctx.ProcedureBodies[Index].Decl,
              Ctx.ProcedureBodies[Index].OwnerUnitId,
              AArgTypeIds,
              AArgCount
            ) then
            begin
              DirectImportExactMatchIndex := Index;
              Inc(DirectImportExactMatchCount);
            end
            else if HasArgTypeIds and DeclParamTypesCompatibleMatch(Ctx, 
              Ctx.ProcedureBodies[Index].Decl,
              Ctx.ProcedureBodies[Index].OwnerUnitId,
              AArgTypeIds,
              AArgCount
            ) then
            begin
              DirectImportCompatibleMatchIndex := Index;
              Inc(DirectImportCompatibleMatchCount);
            end;
          end;
          if OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
            Ctx.ProcedureBodies[Index].OwnerUnitId
          ) then
            Inc(ImportedDiagnosticMatchCount);
          if AHasArgSignature and
            DeclParamSignatureMatchesArgs(Ctx, 
              Ctx.ProcedureBodies[Index].Decl,
              AArgSignature,
              AArgCount
            ) then
          begin
            ImportedSignatureMatchIndex := Index;
            Inc(ImportedSignatureMatchCount);
            if OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
              Ctx.ProcedureBodies[Index].OwnerUnitId
            ) then
              Inc(ImportedDiagnosticSignatureMatchCount);
          end;
        end;
      end;
    end;

  if RootMatchCount > 0 then
  begin
    if HasArgTypeIds and
      ((RootExactMatchCount > 0) or (RootCompatibleMatchCount > 0)) then
    begin
      if RootExactMatchCount = 1 then
        RootSignatureMatchIndex := RootExactMatchIndex
      else if RootExactMatchCount > 1 then
      begin
        AResolutionFailureKind := 'ambiguous-overload';
        Exit(False);
      end
      else if RootCompatibleMatchCount = 1 then
        RootSignatureMatchIndex := RootCompatibleMatchIndex
      else if RootCompatibleMatchCount > 1 then
      begin
        AResolutionFailureKind := 'ambiguous-overload';
        Exit(False);
      end
      else
      begin
        if AHasTypeMismatchEvidence then
          AResolutionFailureKind := 'no-matching-overload';
        Exit(False);
      end;
    end
    else if RootMatchCount = 1 then
    begin
      if AHasArgSignature and
        (not DeclParamSignatureMatchesArgs(Ctx, 
          Ctx.ProcedureBodies[RootMatchIndex].Decl,
          AArgSignature,
          AArgCount
        )) then
      begin
        if AHasTypeMismatchEvidence then
        begin
          AResolutionFailureKind := 'type-mismatch';
        end;
        Exit(False);
      end;
      RootSignatureMatchIndex := RootMatchIndex
    end
    else if (not AHasArgSignature) or (RootSignatureMatchCount > 1) then
    begin
        if RootSignatureMatchCount = 1 then
        RootSignatureMatchIndex := RootMatchIndex
      else if RootSignatureMatchCount > 1 then
      begin
        AResolutionFailureKind := 'ambiguous-overload';
        Exit(False);
      end
      else
      begin
        AResolutionFailureKind := 'ambiguous-overload';
        Exit(False);
      end;
    end
    else if RootSignatureMatchCount = 0 then
    begin
      if AHasTypeMismatchEvidence then
        AResolutionFailureKind := 'no-matching-overload';
      Exit(False);
    end;

    ABody := Ctx.ProcedureBodies[RootSignatureMatchIndex].Body;
    ADecl := Ctx.ProcedureBodies[RootSignatureMatchIndex].Decl;
    AOwnerUnitId := Ctx.ProcedureBodies[RootSignatureMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if RootNameCount > 0 then
  begin
    AResolutionFailureKind := 'wrong-argument-count';
    Exit(False);
  end;

  if (RootNameCount = 0) and (ImportedNameCount = 0) then
  begin
    KnownSymbolId := Ctx.Model.LookupSymbolWithImports(AName, Ctx.CurrentScopeId);
    if IsSimpleIdentifierName(AName) and (KnownSymbolId = 0) and
      (Ctx.Model.FindTypeByName(AName) = 0) and
      (not Ctx.BuiltinRegistry.IsBuiltinProcedure(AName)) and
      (not HasInstalledSourceImports(Ctx)) then
      AResolutionFailureKind := 'unknown-callable';
    Exit(False);
  end;

  if ImportedMatchCount = 0 then
  begin
    if ImportedDiagnosticNameCount > 0 then
      AResolutionFailureKind := 'wrong-argument-count';
    Exit(False);
  end;

  { Prefer direct imports over transitive imports (Ctx.PC-compatible).
    When multiple imported units expose the same overload, a unit that
    the current compilation unit directly uses takes priority.
    Note: DirectImportMatchIndex always records the LAST matching direct
    import. When DirectImportMatchCount > 1, the index may not point to
    the "best" candidate — but we only use it when Count = 1, so this
    is safe. If Count > 1, we fall through to the ambiguity check below. }
  if HasArgTypeIds and (DirectImportExactMatchCount = 1) then
  begin
    ABody := Ctx.ProcedureBodies[DirectImportExactMatchIndex].Body;
    ADecl := Ctx.ProcedureBodies[DirectImportExactMatchIndex].Decl;
    AOwnerUnitId := Ctx.ProcedureBodies[DirectImportExactMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if HasArgTypeIds and (DirectImportExactMatchCount > 1) then
  begin
    AResolutionFailureKind := 'ambiguous-overload';
    Exit(False);
  end;

  if HasArgTypeIds and (DirectImportCompatibleMatchCount = 1) and
    (DirectImportExactMatchCount = 0) then
  begin
    ABody := Ctx.ProcedureBodies[DirectImportCompatibleMatchIndex].Body;
    ADecl := Ctx.ProcedureBodies[DirectImportCompatibleMatchIndex].Decl;
    AOwnerUnitId := Ctx.ProcedureBodies[DirectImportCompatibleMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if HasArgTypeIds and (DirectImportCompatibleMatchCount > 1) and
    (DirectImportExactMatchCount = 0) then
  begin
    AResolutionFailureKind := 'ambiguous-overload';
    Exit(False);
  end;

  if (ImportedMatchCount > 1) and (DirectImportMatchCount = 1) then
  begin
    if HasArgTypeIds and (DirectImportExactMatchCount = 1) then
      DirectImportMatchIndex := DirectImportExactMatchIndex
    else if HasArgTypeIds and (DirectImportCompatibleMatchCount = 1) then
      DirectImportMatchIndex := DirectImportCompatibleMatchIndex
    else if HasArgTypeIds then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[DirectImportMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end
    else if AHasArgSignature and
      (not DeclParamSignatureMatchesArgs(Ctx, 
        Ctx.ProcedureBodies[DirectImportMatchIndex].Decl,
        AArgSignature,
        AArgCount
      )) then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[DirectImportMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end;
    ABody := Ctx.ProcedureBodies[DirectImportMatchIndex].Body;
    ADecl := Ctx.ProcedureBodies[DirectImportMatchIndex].Decl;
    AOwnerUnitId := Ctx.ProcedureBodies[DirectImportMatchIndex].OwnerUnitId;
    Exit(True);
  end;

  if ImportedMatchCount = 1 then
  begin
    if HasArgTypeIds and DeclParamTypesExactMatch(Ctx, 
      Ctx.ProcedureBodies[ImportedMatchIndex].Decl,
      Ctx.ProcedureBodies[ImportedMatchIndex].OwnerUnitId,
      AArgTypeIds,
      AArgCount
    ) then
      ImportedSignatureMatchIndex := ImportedMatchIndex
    else if HasArgTypeIds and DeclParamTypesCompatibleMatch(Ctx, 
      Ctx.ProcedureBodies[ImportedMatchIndex].Decl,
      Ctx.ProcedureBodies[ImportedMatchIndex].OwnerUnitId,
      AArgTypeIds,
      AArgCount
    ) then
      ImportedSignatureMatchIndex := ImportedMatchIndex
    else if HasArgTypeIds then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[ImportedMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end
    else if AHasArgSignature and
      (not DeclParamSignatureMatchesArgs(Ctx, 
        Ctx.ProcedureBodies[ImportedMatchIndex].Decl,
        AArgSignature,
        AArgCount
      )) then
    begin
      if AHasTypeMismatchEvidence and
        OwnerUnitAllowsProjectSourceDiagnostic(Ctx, 
          Ctx.ProcedureBodies[ImportedMatchIndex].OwnerUnitId
        ) then
        AResolutionFailureKind := 'type-mismatch';
      Exit(False);
    end
    else
      ImportedSignatureMatchIndex := ImportedMatchIndex
  end
  else if HasArgTypeIds and
    ((ImportedExactMatchCount > 0) or (ImportedCompatibleMatchCount > 0)) then
  begin
    if ImportedExactMatchCount = 1 then
      ImportedSignatureMatchIndex := ImportedExactMatchIndex
    else if ImportedExactMatchCount > 1 then
    begin
      AResolutionFailureKind := 'ambiguous-overload';
      Exit(False);
    end
    else if ImportedCompatibleMatchCount = 1 then
      ImportedSignatureMatchIndex := ImportedCompatibleMatchIndex
    else if ImportedCompatibleMatchCount > 1 then
    begin
      AResolutionFailureKind := 'ambiguous-overload';
      Exit(False);
    end
    else
    begin
      if AHasTypeMismatchEvidence and
        (ImportedDiagnosticMatchCount = ImportedMatchCount) then
        AResolutionFailureKind := 'no-matching-overload';
      Exit(False);
    end;
  end
  else if (not AHasArgSignature) or (ImportedSignatureMatchCount > 1) then
  begin
    if ImportedSignatureMatchCount = 1 then
    begin
      { Fall through to use ImportedSignatureMatchIndex }
    end
    else if ImportedSignatureMatchCount > 1 then
    begin
      AResolutionFailureKind := 'ambiguous-overload';
      Exit(False);
    end
    else
    begin
      if ((not AHasArgSignature) and (ImportedDiagnosticMatchCount > 1)) or
        (ImportedDiagnosticSignatureMatchCount > 1) then
        AResolutionFailureKind := 'ambiguous-overload';
      Exit(False);
    end;
  end
  else if ImportedSignatureMatchCount = 0 then
  begin
    if AHasTypeMismatchEvidence and
      (ImportedDiagnosticMatchCount = ImportedMatchCount) then
      AResolutionFailureKind := 'no-matching-overload';
    Exit(False);
  end;

  ABody := Ctx.ProcedureBodies[ImportedSignatureMatchIndex].Body;
  ADecl := Ctx.ProcedureBodies[ImportedSignatureMatchIndex].Decl;
  AOwnerUnitId := Ctx.ProcedureBodies[ImportedSignatureMatchIndex].OwnerUnitId;
  Result := True;
end;

function HasInstalledSourceImports(const Ctx: TSemaOverloadContext): Boolean;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
begin
  Result := False;
  for Index := 0 to Ctx.UnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := Ctx.UnitGraph.ResolvedUnitAt(Index);
    if SameText(ResolvedUnit.OriginClass, 'installed-source') then
      Exit(True);
  end;
end;

function OwnerUnitAllowsProjectSourceDiagnostic(
  const Ctx: TSemaOverloadContext; const AOwnerUnitId: string): Boolean;
var ImportCtx: TSemaImportContext;
begin
  ImportCtx.UnitGraph := Ctx.UnitGraph;
  ImportCtx.RootAst := Ctx.RootAst;
  ImportCtx.ImportedUnitOwners := Ctx.ImportedUnitOwners;
  ImportCtx.ImportedUnitTrees := Ctx.ImportedUnitTrees;
  Result := OwnerUnitAllowsProjectSourceDiagnostic(ImportCtx, AOwnerUnitId);
end;

function UnitDirectlyImports(
  const Ctx: TSemaOverloadContext;
  const AOwnerUnitId, AImportedUnitId: string): Boolean;
var ImportCtx: TSemaImportContext;
begin
  ImportCtx.UnitGraph := Ctx.UnitGraph;
  ImportCtx.RootAst := Ctx.RootAst;
  ImportCtx.ImportedUnitOwners := Ctx.ImportedUnitOwners;
  ImportCtx.ImportedUnitTrees := Ctx.ImportedUnitTrees;
  Result := UnitDirectlyImports(ImportCtx, AOwnerUnitId, AImportedUnitId);
end;


end.
