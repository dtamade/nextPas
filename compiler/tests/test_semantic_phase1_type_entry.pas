program test_semantic_phase1_type_entry;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  np_semantic_analyzer,
  np_semantic_model,
  np_unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'semantic-phase1-type-entry-failure=', AMessage);
  Halt(1);
end;

procedure WriteTextFile(const APath: string; const AText: string);
var
  F: Text;
begin
  ForceDirectories(ExtractFileDir(APath));
  Assign(F, APath);
  Rewrite(F);
  try
    Write(F, AText);
  finally
    Close(F);
  end;
end;

procedure DeleteFileIfExists(const APath: string);
begin
  if FileExists(APath) then
    DeleteFile(APath);
end;

function BuildModel(const ASource: string; out ADiagnostics: TDiagnosticsSink
): TSemanticModel;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Graph: TUnitGraph;
  Lexer: TLexerResult;
  Tree: TGreenTree;
begin
  Result := nil;
  Analyzer := nil;
  Ast := nil;
  Graph := nil;
  Lexer := nil;
  Tree := nil;
  ADiagnostics := nil;
  try
    ADiagnostics := TDiagnosticsSink.CreateDefault;
    Lexer := TLexerResult.Create(ASource, ADiagnostics, 1);
    Tree := ParseGreenTree(Lexer, ADiagnostics, 1);
    Ast := TAstFacade.Create(Tree);
    Graph := TUnitGraph.Create;
    Graph.SetRootName(Ast.DeclaredName);
    Graph.MarkReady;
    Analyzer := TSemanticAnalyzer.Create(Ast, Graph, ADiagnostics, 1, True);
    Analyzer.Analyze;
    Result := Analyzer.DetachModel;
  finally
    Analyzer.Free;
    Graph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
  end;
end;

function BuildModelWithResolvedUnits(
  const ASource: string;
  const ARootName: string;
  const AResolvedUnits: array of TResolvedUnit;
  out ADiagnostics: TDiagnosticsSink
): TSemanticModel;
var
  Analyzer: TSemanticAnalyzer;
  Ast: TAstFacade;
  Graph: TUnitGraph;
  Index: LongInt;
  Lexer: TLexerResult;
  Tree: TGreenTree;
begin
  Result := nil;
  Analyzer := nil;
  Ast := nil;
  Graph := nil;
  Lexer := nil;
  Tree := nil;
  ADiagnostics := nil;
  try
    ADiagnostics := TDiagnosticsSink.CreateDefault;
    Lexer := TLexerResult.Create(ASource, ADiagnostics, 1);
    Tree := ParseGreenTree(Lexer, ADiagnostics, 1);
    Ast := TAstFacade.Create(Tree);
    Graph := TUnitGraph.Create;
    Graph.SetRootName(ARootName);
    for Index := Low(AResolvedUnits) to High(AResolvedUnits) do
      Graph.AddResolvedUnit(AResolvedUnits[Index]);
    Analyzer := TSemanticAnalyzer.Create(Ast, Graph, ADiagnostics, 1, True);
    Analyzer.Analyze;
    Result := Analyzer.DetachModel;
  finally
    Analyzer.Free;
    Graph.Free;
    Ast.Free;
    Tree.Free;
    Lexer.Free;
  end;
end;

function TypeNameOf(const AModel: TSemanticModel; const ATypeId: LongInt): string;
begin
  if (AModel = nil) or (ATypeId <= 0) or (ATypeId > AModel.TypeCount) then
    Exit('');
  Result := AModel.TypeAt(ATypeId - 1).Name;
end;

function FindAssignRuntimeNode(const AModel: TSemanticModel;
  const ADestName: string; out ANode: TTypedHirNode): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to AModel.TypedHirNodeCount - 1 do
  begin
    ANode := AModel.TypedHirNodeAt(Index);
    if SameText(ANode.Kind, 'assign-runtime') and
      SameText(ANode.DisplayName, ADestName) then
      Exit(True);
  end;
  Result := False;
end;

function SymbolIdByNameKindOwnerAndSignature(
  const AModel: TSemanticModel;
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const AParamCount: LongInt;
  const AParamSignature: string
): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and SameText(Symbol.Kind, AKind) and
      SameText(Symbol.OwnerUnitId, AOwnerUnitId) and
      (Symbol.ParamCount = AParamCount) and
      SameText(Symbol.ParamSignature, AParamSignature) then
      Exit(Symbol.SymbolId);
  end;
end;

function SymbolIdByNameKindOwnerAndOffset(
  const AModel: TSemanticModel;
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const AByteOffset: LongInt
): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and SameText(Symbol.Kind, AKind) and
      SameText(Symbol.OwnerUnitId, AOwnerUnitId) and
      (Symbol.ByteOffset = AByteOffset) then
      Exit(Symbol.SymbolId);
  end;
end;

function SymbolIdByNameKindOwnerAndOrdinal(
  const AModel: TSemanticModel;
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const AOrdinal: LongInt
): LongInt;
var
  Count: LongInt;
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  Count := 0;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and SameText(Symbol.Kind, AKind) and
      SameText(Symbol.OwnerUnitId, AOwnerUnitId) then
    begin
      Inc(Count);
      if Count = AOrdinal then
        Exit(Symbol.SymbolId);
    end;
  end;
end;

procedure CheckTypeCastAndIntrinsicCallsStayReady;
var
  AssignNode: TTypedHirNode;
  Diagnostics: TDiagnosticsSink;
  Expr: TSemanticHirExpr;
  LeftExpr: TSemanticHirExpr;
  Model: TSemanticModel;
begin
  Diagnostics := nil;
  Model := BuildModel(
    'program TypeCastAndIntrinsicCalls;' + LineEnding +
    'var' + LineEnding +
    '  I: Integer;' + LineEnding +
    '  B: Byte;' + LineEnding +
    '  S: string;' + LineEnding +
    '  R: RawByteString;' + LineEnding +
    '  N: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  I := 42;' + LineEnding +
    '  S := ''hello'';' + LineEnding +
    '  B := Byte(I);' + LineEnding +
    '  R := RawByteString(S);' + LineEnding +
    '  N := SizeOf(Integer) + 16;' + LineEnding +
    'end.' + LineEnding,
    Diagnostics
  );
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics-sink');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-diagnostic:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-model-status:' + Model.Status);
    if not FindAssignRuntimeNode(Model, 'B', AssignNode) then
      Fail('missing-byte-assign-node');
    if AssignNode.ExprId <= 0 then
      Fail('missing-byte-assign-expr');
    Expr := Model.HirExprAt(AssignNode.ExprId - 1);
    if Expr.Kind <> shekCast then
      Fail('byte-assign-expr-not-cast');
    if not SameText(TypeNameOf(Model, Expr.TypeId), 'Byte') then
      Fail('byte-cast-target-type:' + TypeNameOf(Model, Expr.TypeId));
    if SemanticHirChildCount(Expr.Children) < 1 then
      Fail('byte-cast-missing-child');
    LeftExpr := Model.HirExprAt(Expr.Children[SizeUInt(0)] - 1);
    if not SameText(TypeNameOf(Model, LeftExpr.TypeId), 'Integer') then
      Fail('byte-cast-child-type:' + TypeNameOf(Model, LeftExpr.TypeId));

    if not FindAssignRuntimeNode(Model, 'N', AssignNode) then
      Fail('missing-sizeof-assign-node');
    if AssignNode.ExprId <= 0 then
      Fail('missing-sizeof-assign-expr');
    Expr := Model.HirExprAt(AssignNode.ExprId - 1);
    if Expr.Kind <> shekBinaryOp then
      Fail('sizeof-assign-expr-not-binary');
    if not SameText(TypeNameOf(Model, Expr.TypeId), 'Integer') then
      Fail('sizeof-binary-type:' + TypeNameOf(Model, Expr.TypeId));
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckTypeCastAndIntrinsicOverloadBindings;
var
  Binding: TSemanticBinding;
  BooleanFound: Boolean;
  BooleanOffset, BooleanSymbolId: LongInt;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  IntegerFound: Boolean;
  IntegerOffset, IntegerSymbolId: LongInt;
  Model: TSemanticModel;
  SourceText: string;
begin
  Diagnostics := nil;
  SourceText :=
    'program TypeCastIntrinsicOverloads;' + LineEnding +
    'procedure Pick(Value: Integer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Pick(Value: Boolean);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  I: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  I := 42;' + LineEnding +
    '  Pick(Boolean(I));' + LineEnding +
    '  Pick(SizeOf(Integer));' + LineEnding +
    'end.' + LineEnding;
  Model := BuildModel(SourceText, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-overload-diagnostics-sink');
    if Model = nil then
      Fail('missing-overload-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-overload-diagnostic:' + Diagnostics.LastDiagnosticCode +
        ':' + Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-overload-model-status:' + Model.Status);

    IntegerSymbolId := SymbolIdByNameKindOwnerAndSignature(
      Model, 'Pick', 'procedure', 'typecastintrinsicoverloads', 1, 'i');
    BooleanSymbolId := SymbolIdByNameKindOwnerAndSignature(
      Model, 'Pick', 'procedure', 'typecastintrinsicoverloads', 1, 'b');
    if IntegerSymbolId <= 0 then
      Fail('missing-integer-overload-symbol');
    if BooleanSymbolId <= 0 then
      Fail('missing-boolean-overload-symbol');

    BooleanOffset := Pos('  Pick(Boolean(I));', SourceText) + Length('  ') - 1;
    IntegerOffset := Pos('  Pick(SizeOf(Integer));', SourceText) +
      Length('  ') - 1;
    BooleanFound := False;
    IntegerFound := False;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if not SameText(Binding.Kind, 'call') or not SameText(Binding.Name, 'Pick') then
        Continue;
      if Binding.ByteOffset = BooleanOffset then
      begin
        BooleanFound := True;
        if Binding.TargetSymbolId <> BooleanSymbolId then
          Fail('boolean-cast-binding-target-mismatch');
      end
      else if Binding.ByteOffset = IntegerOffset then
      begin
        IntegerFound := True;
        if Binding.TargetSymbolId <> IntegerSymbolId then
          Fail('sizeof-binding-target-mismatch');
      end;
    end;
    if not BooleanFound then
      Fail('missing-boolean-cast-binding');
    if not IntegerFound then
      Fail('missing-sizeof-binding');
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckPointerCompatibleOverloadsAndDefaultIntrinsic;
var
  Binding: TSemanticBinding;
  BodyFound: Boolean;
  BodyOffset: LongInt;
  BodySymbolId: LongInt;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  IntegerAssign: TTypedHirNode;
  IntegerAssignExpr: TSemanticHirExpr;
  Model: TSemanticModel;
  PickOffset: LongInt;
  PickSymbolId: LongInt;
  PointerOnlyFound: Boolean;
  PointerOnlyOffset: LongInt;
  PointerOnlySymbolId: LongInt;
  RecordAssignFound: Boolean;
  SourceText: string;
begin
  Diagnostics := nil;
  SourceText :=
    'program PointerCompatibleOverloads;' + LineEnding +
    'type' + LineEnding +
    '  TBytes = array of Byte;' + LineEnding +
    '  IReader = interface' + LineEnding +
    '  end;' + LineEnding +
    '  TRec = record' + LineEnding +
    '    Value: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'procedure TakeAny(const Value: Pointer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Pick(const Value: Pointer);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure Pick(const Value: PByte);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure PickBody(const Value: IReader);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure PickBody(const Value: TBytes);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Data: TBytes;' + LineEnding +
    '  I: Integer;' + LineEnding +
    '  P: PByte;' + LineEnding +
    '  R: TRec;' + LineEnding +
    'begin' + LineEnding +
    '  TakeAny(P);' + LineEnding +
    '  Pick(P);' + LineEnding +
    '  PickBody(Data);' + LineEnding +
    '  I := Default(Integer);' + LineEnding +
    '  R := Default(TRec);' + LineEnding +
    'end.' + LineEnding;
  Model := BuildModel(SourceText, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-pointer-default-diagnostics');
    if Model = nil then
      Fail('missing-pointer-default-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-pointer-default-diagnostic:' +
        Diagnostics.LastDiagnosticCode + ':' + Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-pointer-default-model-status:' + Model.Status);

    PointerOnlySymbolId := SymbolIdByNameKindOwnerAndSignature(
      Model, 'TakeAny', 'procedure', 'pointercompatibleoverloads', 1, 'p');
    if PointerOnlySymbolId <= 0 then
      Fail('missing-pointer-only-symbol');

    PickSymbolId := SymbolIdByNameKindOwnerAndOrdinal(
      Model,
      'Pick',
      'procedure',
      'pointercompatibleoverloads',
      2
    );
    if PickSymbolId <= 0 then
      Fail('missing-typed-pointer-overload-symbol');

    BodySymbolId := SymbolIdByNameKindOwnerAndOrdinal(
      Model,
      'PickBody',
      'procedure',
      'pointercompatibleoverloads',
      2
    );
    if BodySymbolId <= 0 then
      Fail('missing-bytes-overload-symbol');

    PointerOnlyOffset := Pos('  TakeAny(P);', SourceText) + Length('  ') - 1;
    PickOffset := Pos('  Pick(P);', SourceText) + Length('  ') - 1;
    BodyOffset := Pos('  PickBody(Data);', SourceText) + Length('  ') - 1;
    PointerOnlyFound := False;
    BodyFound := False;
    RecordAssignFound := False;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if not SameText(Binding.Kind, 'call') then
        Continue;
      if SameText(Binding.Name, 'TakeAny') and
        (Binding.ByteOffset = PointerOnlyOffset) then
      begin
        PointerOnlyFound := True;
        if Binding.TargetSymbolId <> PointerOnlySymbolId then
          Fail('pointer-only-binding-target-mismatch');
      end
      else if SameText(Binding.Name, 'Pick') and
        (Binding.ByteOffset = PickOffset) then
      begin
        RecordAssignFound := True;
        if Binding.TargetSymbolId <> PickSymbolId then
          Fail('typed-pointer-overload-target-mismatch');
      end
      else if SameText(Binding.Name, 'PickBody') and
        (Binding.ByteOffset = BodyOffset) then
      begin
        BodyFound := True;
        if Binding.TargetSymbolId <> BodySymbolId then
          Fail('bytes-overload-target-mismatch');
      end;
    end;
    if not PointerOnlyFound then
      Fail('missing-pointer-only-binding');
    if not RecordAssignFound then
      Fail('missing-typed-pointer-overload-binding');
    if not BodyFound then
      Fail('missing-bytes-overload-binding');

    if not FindAssignRuntimeNode(Model, 'I', IntegerAssign) then
      Fail('missing-default-integer-assign-node');
    if IntegerAssign.ExprId <= 0 then
      Fail('missing-default-integer-assign-expr');
    IntegerAssignExpr := Model.HirExprAt(IntegerAssign.ExprId - 1);
    if IntegerAssignExpr.Kind <> shekIntLiteral then
      Fail('default-integer-expr-not-int-literal');
    if IntegerAssignExpr.LiteralInt <> 0 then
      Fail('default-integer-literal-not-zero');

    RecordAssignFound := False;
    for Index := 0 to Model.TypedHirNodeCount - 1 do
      if SameText(Model.TypedHirNodeAt(Index).Kind, 'fillchar-runtime') and
        SameText(Model.TypedHirNodeAt(Index).DisplayName, 'R') then
      begin
        RecordAssignFound := True;
        Break;
      end;
    if not RecordAssignFound then
      Fail('missing-default-record-assign-node');
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckCachedInstalledSourceTypeSymbolsStayReady;
var
  Binding: TSemanticBinding;
  ClassesPath: string;
  ClearBindingCount: LongInt;
  Diagnostics: TDiagnosticsSink;
  Index: LongInt;
  Model: TSemanticModel;
  ProjectRoot: string;
  RootSourceText: string;
begin
  Randomize;
  ProjectRoot := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nextpas-phase1-cached-classes-' + IntToStr(Random(MaxInt));
  ClassesPath := ProjectRoot + DirectorySeparator + 'classes.pas';
  RootSourceText :=
    'program CachedClassesTypeSymbols;' + LineEnding +
    'uses Classes;' + LineEnding +
    'var' + LineEnding +
    '  List: TStringList;' + LineEnding +
    'begin' + LineEnding +
    '  List := TStringList.Create;' + LineEnding +
    '  List.Clear;' + LineEnding +
    'end.' + LineEnding;
  WriteTextFile(
    ClassesPath,
    'unit Classes;' + LineEnding +
    LineEnding +
    'interface' + LineEnding +
    'type' + LineEnding +
    '  TStringList = class' + LineEnding +
    '  public' + LineEnding +
    '    constructor Create;' + LineEnding +
    '    procedure Clear;' + LineEnding +
    '  end;' + LineEnding +
    LineEnding +
    'implementation' + LineEnding +
    'constructor TStringList.Create;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'procedure TStringList.Clear;' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    LineEnding +
    'end.' + LineEnding
  );

  Diagnostics := nil;
  Model := BuildModelWithResolvedUnits(
    RootSourceText,
    'CachedClassesWarmup',
    [
      BuildResolvedUnit('CachedClassesWarmup', '', ruoRootSource, '', 'program', 1),
      BuildResolvedUnit('Classes', ClassesPath, ruoInstalledSource, '', 'unit', 2)
    ],
    Diagnostics
  );
  try
    if Diagnostics = nil then
      Fail('missing-cached-warmup-diagnostics');
    if Model = nil then
      Fail('missing-cached-warmup-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-cached-warmup-diagnostic:' +
        Diagnostics.LastDiagnosticCode + ':' + Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-cached-warmup-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;

  Diagnostics := nil;
  Model := BuildModelWithResolvedUnits(
    RootSourceText,
    'CachedClassesReplay',
    [
      BuildResolvedUnit('CachedClassesReplay', '', ruoRootSource, '', 'program', 1),
      BuildResolvedUnit('Classes', ClassesPath, ruoInstalledSource, '', 'unit', 2)
    ],
    Diagnostics
  );
  try
    if Diagnostics = nil then
      Fail('missing-cached-replay-diagnostics');
    if Model = nil then
      Fail('missing-cached-replay-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-cached-replay-diagnostic:' +
        Diagnostics.LastDiagnosticCode + ':' + Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-cached-replay-status:' + Model.Status);
    ClearBindingCount := 0;
    for Index := 0 to Model.BindingCount - 1 do
    begin
      Binding := Model.BindingAt(Index);
      if SameText(Binding.Kind, 'member-call') and
        SameText(Binding.Name, 'Clear') then
        Inc(ClearBindingCount);
    end;
    if ClearBindingCount <> 1 then
      Fail('unexpected-cached-replay-clear-binding-count:' +
        IntToStr(ClearBindingCount));
  finally
    Model.Free;
    Diagnostics.Free;
    DeleteFileIfExists(ClassesPath);
    RmDir(ProjectRoot);
  end;
end;

begin
  CheckTypeCastAndIntrinsicCallsStayReady;
  CheckTypeCastAndIntrinsicOverloadBindings;
  CheckPointerCompatibleOverloadsAndDefaultIntrinsic;
  CheckCachedInstalledSourceTypeSymbolsStayReady;
  WriteLn('semantic-phase1-type-entry-status=pass');
end.
