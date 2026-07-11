program test_system_intrinsic_self_aliases;

{$mode objfpc}{$H+}

uses
  SysUtils,
  np_ast_facade,
  np_diagnostics_sink,
  np_green_tree,
  np_lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'system-intrinsic-self-aliases-failure=', AMessage);
  Halt(1);
end;

function TypeCountByName(const AModel: TSemanticModel;
  const ATypeName: string): LongInt;
var
  Index: LongInt;
begin
  Result := 0;
  for Index := 0 to AModel.TypeCount - 1 do
    if SameText(AModel.TypeAt(Index).Name, ATypeName) then
      Inc(Result);
end;

function SystemTypeSymbolTypeId(const AModel: TSemanticModel;
  const ATypeName: string): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Name, ATypeName) and
      SameText(Symbol.Kind, 'type') and
      SameText(Symbol.OwnerUnitId, 'system') then
      Exit(Symbol.TypeId);
  end;
end;

procedure AssertIntrinsicScalarType(const AModel: TSemanticModel;
  const ATypeName: string; const AExpectedKind: TSemanticScalarKind;
  const AExpectedBitWidth: LongInt; const AExpectedSigned: Boolean);
var
  Fact: TSemanticScalarTypeFact;
  TypeId: LongInt;
  SymbolType: TSemanticType;
begin
  if TypeCountByName(AModel, ATypeName) <> 1 then
    Fail('unexpected-type-count:' + ATypeName + ':' +
      IntToStr(TypeCountByName(AModel, ATypeName)));

  TypeId := AModel.FindTypeByName(ATypeName);
  if TypeId <= 0 then
    Fail('missing-type:' + ATypeName);
  SymbolType := AModel.TypeAt(TypeId - 1);
  if not SameText(SymbolType.OwnerUnitId, 'system') then
    Fail('type-owner-mismatch:' + ATypeName + ':' + SymbolType.OwnerUnitId);
  if SystemTypeSymbolTypeId(AModel, ATypeName) <> TypeId then
    Fail('system-symbol-type-id-mismatch:' + ATypeName);
  if not AModel.GetTypeScalarFact(TypeId, Fact) then
    Fail('missing-scalar-fact:' + ATypeName);
  if (Fact.TypeId <> TypeId) or (Fact.Kind <> AExpectedKind) or
    (Fact.BitWidth <> AExpectedBitWidth) or
    (Fact.Signed <> AExpectedSigned) then
    Fail('scalar-fact-mismatch:' + ATypeName);
end;

procedure AssertAliasParent(const AModel: TSemanticModel;
  const AAliasName: string; const ATargetName: string);
var
  AliasTypeId: LongInt;
  TargetTypeId: LongInt;
begin
  AliasTypeId := AModel.FindTypeByName(AAliasName);
  TargetTypeId := AModel.FindTypeByName(ATargetName);
  if (AliasTypeId <= 0) or (TargetTypeId <= 0) then
    Fail('missing-alias-pair:' + AAliasName + ':' + ATargetName);
  if AModel.TypeAt(AliasTypeId - 1).ParentTypeId <> TargetTypeId then
    Fail('alias-parent-mismatch:' + AAliasName + ':' + ATargetName);
end;

procedure AssertNoSelfParentTypes(const AModel: TSemanticModel);
var
  Index: LongInt;
  SymbolType: TSemanticType;
begin
  for Index := 0 to AModel.TypeCount - 1 do
  begin
    SymbolType := AModel.TypeAt(Index);
    if SymbolType.ParentTypeId = SymbolType.TypeId then
      Fail('self-parent-type:' + SymbolType.Name + ':' +
        IntToStr(SymbolType.TypeId));
  end;
end;

procedure AssertTypeParentMutationRejectsInvalidGraphs;
var
  ChildTypeId: LongInt;
  Model: TSemanticModel;
  ParentTypeId: LongInt;
begin
  Model := TSemanticModel.Create;
  try
    ParentTypeId := Model.AddType('TInvariantParent', 'class');
    ChildTypeId := Model.AddType('TInvariantChild', 'class');

    Model.SetTypeParent(ChildTypeId, ParentTypeId);
    if Model.TypeAt(ChildTypeId - 1).ParentTypeId <> ParentTypeId then
      Fail('valid-parent-assignment-rejected');

    Model.SetTypeParent(ChildTypeId, ChildTypeId);
    if Model.TypeAt(ChildTypeId - 1).ParentTypeId <> ParentTypeId then
      Fail('self-parent-overwrote-valid-parent');

    Model.SetTypeParent(ParentTypeId, ChildTypeId);
    if Model.TypeAt(ParentTypeId - 1).ParentTypeId <> 0 then
      Fail('indirect-parent-cycle-accepted');

    Model.SetTypeParent(ChildTypeId, Model.TypeCount + 1);
    if Model.TypeAt(ChildTypeId - 1).ParentTypeId <> ParentTypeId then
      Fail('out-of-range-parent-overwrote-valid-parent');

    Model.SetTypeParent(ChildTypeId, 0);
    if Model.TypeAt(ChildTypeId - 1).ParentTypeId <> 0 then
      Fail('parent-clear-rejected');

    Model.SetTypeParent(ChildTypeId, ParentTypeId);
    Model.SetTypeParent(ChildTypeId, -1);
    if Model.TypeAt(ChildTypeId - 1).ParentTypeId <> ParentTypeId then
      Fail('negative-parent-overwrote-valid-parent');
  finally
    Model.Free;
  end;
end;

var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  Model: TSemanticModel;
  SourceText: string;
  SystemPath: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  AssertTypeParentMutationRejectsInvalidGraphs;

  if ParamCount <> 1 then
    Fail('expected-system-source-path');
  SystemPath := ExpandFileName(ParamStr(1));
  if not FileExists(SystemPath) then
    Fail('missing-installed-system:' + SystemPath);

  SourceText :=
    'program SystemIntrinsicSelfAliases;' + LineEnding +
    'begin' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(SourceText, Diagnostics, 1);
  Tree := ParseGreenTree(Lexer, Diagnostics, 1);
  Ast := TAstFacade.Create(Tree);
  UnitGraph := TUnitGraph.Create;
  Analyzer := nil;
  Model := nil;
  try
    UnitGraph.SetRootName(Ast.DeclaredName);
    UnitGraph.AddResolvedUnit(BuildResolvedUnit(
      Ast.DeclaredName, '', ruoRootSource, 'linux-x86_64', 'program', 1));
    UnitGraph.AddResolvedUnit(BuildResolvedUnit(
      'System', SystemPath, ruoImplicitRuntime, 'linux-x86_64', 'unit', 2));
    UnitGraph.AddEdge(
      ugeImplicitRuntime,
      LowerCase(Ast.DeclaredName),
      'system'
    );

    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Model := Analyzer.DetachModel;

    if Diagnostics.HasErrors then
      Fail('unexpected-diagnostic:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if Model = nil then
      Fail('missing-semantic-model');
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-model-status:' + Model.Status);

    AssertIntrinsicScalarType(Model, 'Boolean', sskBool, 1, False);
    AssertIntrinsicScalarType(Model, 'Integer', sskInt, 32, True);
    AssertIntrinsicScalarType(Model, 'Cardinal', sskInt, 32, False);
    AssertAliasParent(Model, 'ByteBool', 'Boolean');
    AssertAliasParent(Model, 'Extended', 'Double');
    AssertNoSelfParentTypes(Model);
    WriteLn('system-intrinsic-self-aliases-status=pass');
  finally
    Model.Free;
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end.
