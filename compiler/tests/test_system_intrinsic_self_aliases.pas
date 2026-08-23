program test_system_intrinsic_self_aliases;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  np_semantic_analyzer,
  np_semantic_model,
  nextpas.compiler.frontend.symbol_cache,
  nextpas.compiler.frontend.unit_graph;

const
  PoisonedCacheSymbolName = 'SystemCachePoison';
  SymbolCacheDirectory = '.nextpas/cache';
  SystemCacheFilePath = '.nextpas/cache/system.npb';
  SystemCacheSeedUnitName = 'SystemCacheSeed';
  SystemUnitId = 'system';

type
  TSystemAnalysisFailure = record
    PhaseName: string;
    MessageText: string;
  end;

  TSystemAnalysisFailures = array of TSystemAnalysisFailure;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'system-intrinsic-self-aliases-failure=', AMessage);
  Halt(1);
end;

procedure RecordSystemAnalysisFailure(var AFailures: TSystemAnalysisFailures;
  const APhaseName: string; const AMessage: string);
var
  FailureIndex: SizeInt;
begin
  FailureIndex := Length(AFailures);
  SetLength(AFailures, FailureIndex + 1);
  AFailures[FailureIndex].PhaseName := APhaseName;
  AFailures[FailureIndex].MessageText := AMessage;
end;

procedure ReportSystemAnalysisFailures(const AFailures: TSystemAnalysisFailures);
var
  FailureIndex: SizeInt;
begin
  for FailureIndex := 0 to Length(AFailures) - 1 do
    WriteLn(StdErr, 'system-intrinsic-self-aliases-phase-failure=',
      AFailures[FailureIndex].PhaseName, ':',
      AFailures[FailureIndex].MessageText);
  Halt(1);
end;

procedure SavePoisonedDiskCache(const AUnitId: string;
  const ASourcePath: string);
var
  CachedUnit: TDiskCachedUnit;
  DiskCache: TDiskSymbolCache;
begin
  CachedUnit.UnitId := AUnitId;
  CachedUnit.SourcePath := ASourcePath;
  CachedUnit.Fingerprint := ComputeSourceFingerprintFromFile(ASourcePath);
  CachedUnit.SymbolCount := 1;
  SetLength(CachedUnit.Symbols, 1);
  CachedUnit.Symbols[0].Name := PoisonedCacheSymbolName;
  CachedUnit.Symbols[0].Kind := 'procedure';
  CachedUnit.Symbols[0].OwnerUnitId := LowerCase(AUnitId);
  CachedUnit.Symbols[0].ParamCount := 0;
  CachedUnit.Symbols[0].MinParamCount := 0;
  CachedUnit.Symbols[0].ParamSignature := '';
  CachedUnit.Symbols[0].TypeRefName := '';
  CachedUnit.Symbols[0].ByteOffset := 0;

  DiskCache := TDiskSymbolCache.Create(SymbolCacheDirectory);
  try
    DiskCache.Save(CachedUnit);
  finally
    DiskCache.Free;
  end;
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
  const AExpectedBitWidth: LongInt; const AExpectedSigned: Boolean;
  const APhaseName: string; var AFailures: TSystemAnalysisFailures);
var
  Fact: TSemanticScalarTypeFact;
  TypeCount: LongInt;
  TypeId: LongInt;
  SymbolType: TSemanticType;
begin
  TypeCount := TypeCountByName(AModel, ATypeName);
  if TypeCount <> 1 then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'unexpected-type-count:' + ATypeName + ':' + IntToStr(TypeCount));

  TypeId := AModel.FindTypeByName(ATypeName);
  if TypeId <= 0 then
  begin
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'missing-type:' + ATypeName);
    Exit;
  end;
  SymbolType := AModel.TypeAt(TypeId - 1);
  if not SameText(SymbolType.OwnerUnitId, 'system') then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'type-owner-mismatch:' + ATypeName + ':' + SymbolType.OwnerUnitId);
  if SystemTypeSymbolTypeId(AModel, ATypeName) <> TypeId then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'system-symbol-type-id-mismatch:' + ATypeName);
  if not AModel.GetTypeScalarFact(TypeId, Fact) then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'missing-scalar-fact:' + ATypeName)
  else if (Fact.TypeId <> TypeId) or (Fact.Kind <> AExpectedKind) or
      (Fact.BitWidth <> AExpectedBitWidth) or
      (Fact.Signed <> AExpectedSigned) then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'scalar-fact-mismatch:' + ATypeName);
end;

procedure AssertAliasParent(const AModel: TSemanticModel;
  const AAliasName: string; const ATargetName: string;
  const APhaseName: string; var AFailures: TSystemAnalysisFailures);
var
  AliasTypeId: LongInt;
  TargetTypeId: LongInt;
begin
  AliasTypeId := AModel.FindTypeByName(AAliasName);
  TargetTypeId := AModel.FindTypeByName(ATargetName);
  if (AliasTypeId <= 0) or (TargetTypeId <= 0) then
  begin
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'missing-alias-pair:' + AAliasName + ':' + ATargetName);
    Exit;
  end;
  if AModel.TypeAt(AliasTypeId - 1).ParentTypeId <> TargetTypeId then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'alias-parent-mismatch:' + AAliasName + ':' + ATargetName);
end;

procedure AssertNoSelfParentTypes(const AModel: TSemanticModel;
  const APhaseName: string; var AFailures: TSystemAnalysisFailures);
var
  Index: LongInt;
  SymbolType: TSemanticType;
begin
  for Index := 0 to AModel.TypeCount - 1 do
  begin
    SymbolType := AModel.TypeAt(Index);
    if SymbolType.ParentTypeId = SymbolType.TypeId then
      RecordSystemAnalysisFailure(AFailures, APhaseName,
        'self-parent-type:' + SymbolType.Name + ':' +
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

function AnalyzeImportedUnitModel(const ASourcePath: string;
  const AImportedUnitName: string; const ARootName: string;
  const AOrigin: TResolvedUnitOrigin;
  const APhaseName: string;
  var AFailures: TSystemAnalysisFailures): TSemanticModel;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Diagnostics: TDiagnosticsSink;
  Lexer: TLexerResult;
  SourceText: string;
  Tree: TGreenTree;
  UnitGraph: TUnitGraph;
begin
  Result := nil;
  SourceText :=
    'program ' + ARootName + ';' + LineEnding +
    'begin' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := TDiagnosticsSink.CreateDefault;
  Lexer := TLexerResult.Create(SourceText, Diagnostics, 1);
  Tree := ParseGreenTree(Lexer, Diagnostics, 1);
  Ast := TAstFacade.Create(Tree);
  UnitGraph := TUnitGraph.Create;
  Analyzer := nil;
  try
    UnitGraph.SetRootName(Ast.DeclaredName);
    UnitGraph.AddResolvedUnit(BuildResolvedUnit(
      Ast.DeclaredName, '', ruoRootSource, 'linux-x86_64', 'program', 1));
    UnitGraph.AddResolvedUnit(BuildResolvedUnit(
      AImportedUnitName, ASourcePath, AOrigin,
      'linux-x86_64', 'unit', 2));
    UnitGraph.AddEdge(
      ugeImplicitRuntime,
      LowerCase(Ast.DeclaredName),
      LowerCase(AImportedUnitName)
    );

    Analyzer := TSemanticAnalyzer.Create(Ast, UnitGraph, Diagnostics, 1, True);
    Analyzer.Analyze;
    Result := Analyzer.DetachModel;

    if Diagnostics.HasErrors then
      RecordSystemAnalysisFailure(AFailures, APhaseName,
        'unexpected-diagnostic:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
  finally
    Analyzer.Free;
    UnitGraph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
    Diagnostics.Free;
  end;
end;

function ValidateModelForAssertions(const AModel: TSemanticModel;
  const APhaseName: string; var AFailures: TSystemAnalysisFailures): Boolean;
begin
  Result := False;
  if AModel = nil then
  begin
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'missing-semantic-model');
    Exit;
  end;

  if not SameText(AModel.Status, 'ready') then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'unexpected-model-status:' + AModel.Status);
  Result := True;
end;

procedure AssertSystemModel(const AModel: TSemanticModel;
  const APhaseName: string; var AFailures: TSystemAnalysisFailures);
begin
  if not ValidateModelForAssertions(AModel, APhaseName, AFailures) then
    Exit;

  if AModel.FindSymbolByName(PoisonedCacheSymbolName) > 0 then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'poisoned-cache-symbol-loaded');

  AssertIntrinsicScalarType(
    AModel, 'Boolean', sskBool, 1, False, APhaseName, AFailures);
  AssertIntrinsicScalarType(
    AModel, 'Integer', sskInt, 32, True, APhaseName, AFailures);
  AssertIntrinsicScalarType(
    AModel, 'Cardinal', sskInt, 32, False, APhaseName, AFailures);
  AssertAliasParent(
    AModel, 'ByteBool', 'Boolean', APhaseName, AFailures);
  AssertAliasParent(
    AModel, 'Extended', 'Double', APhaseName, AFailures);
  AssertNoSelfParentTypes(AModel, APhaseName, AFailures);
end;

procedure AssertCacheSeedModel(const AModel: TSemanticModel;
  const APhaseName: string; var AFailures: TSystemAnalysisFailures);
begin
  if not ValidateModelForAssertions(AModel, APhaseName, AFailures) then
    Exit;

  if AModel.FindSymbolByName(PoisonedCacheSymbolName) <= 0 then
    RecordSystemAnalysisFailure(AFailures, APhaseName,
      'poisoned-cache-symbol-not-loaded');
end;

procedure RunSystemAnalysisPhase(const ASystemPath: string;
  const ARootName: string; const AOrigin: TResolvedUnitOrigin;
  const APhaseName: string; var AFailures: TSystemAnalysisFailures);
var
  Model: TSemanticModel;
begin
  Model := AnalyzeImportedUnitModel(
    ASystemPath, 'System', ARootName, AOrigin, APhaseName, AFailures);
  try
    AssertSystemModel(Model, APhaseName, AFailures);
  finally
    Model.Free;
  end;
end;

procedure SeedProcessGlobalCache(const ASystemPath: string;
  var AFailures: TSystemAnalysisFailures);
const
  PhaseName = 'process-global-seed';
var
  Model: TSemanticModel;
begin
  SavePoisonedDiskCache(SystemCacheSeedUnitName, ASystemPath);
  Model := AnalyzeImportedUnitModel(
    ASystemPath,
    SystemCacheSeedUnitName,
    'SystemProcessGlobalCacheSeed',
    ruoImplicitRuntime,
    PhaseName,
    AFailures
  );
  try
    AssertCacheSeedModel(Model, PhaseName, AFailures);
  finally
    Model.Free;
  end;
end;

var
  Failures: TSystemAnalysisFailures;
  SystemPath: string;
begin
  AssertTypeParentMutationRejectsInvalidGraphs;

  if ParamCount <> 1 then
    Fail('expected-system-source-path');
  SystemPath := ExpandFileName(ParamStr(1));
  if not FileExists(SystemPath) then
    Fail('missing-installed-system:' + SystemPath);

  SetLength(Failures, 0);
  RunSystemAnalysisPhase(
    SystemPath,
    'SystemSourcePopulate',
    ruoInstalledSource,
    'source-populate',
    Failures
  );
  if FileExists(SystemCacheFilePath) then
    RecordSystemAnalysisFailure(Failures, 'source-populate',
      'unexpected-system-cache-file');

  SeedProcessGlobalCache(SystemPath, Failures);
  RunSystemAnalysisPhase(
    SystemPath,
    'SystemProcessGlobalWarm',
    ruoInstalledSource,
    'process-global-warm',
    Failures
  );
  SavePoisonedDiskCache(SystemUnitId, SystemPath);
  if not FileExists(SystemCacheFilePath) then
    RecordSystemAnalysisFailure(Failures, 'disk-warm-setup',
      'missing-poisoned-system-cache-file');
  RunSystemAnalysisPhase(
    SystemPath,
    'SystemDiskWarm',
    ruoImplicitRuntime,
    'disk-warm',
    Failures
  );

  if Length(Failures) > 0 then
    ReportSystemAnalysisFailures(Failures);

  WriteLn('system-intrinsic-self-aliases-status=pass');
end.
