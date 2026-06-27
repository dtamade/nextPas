program test_semantic_phase1_type_entry;

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
  WriteLn(StdErr, 'semantic-phase1-type-entry-failure=', AMessage);
  Halt(1);
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
    if Length(Expr.Children) < 1 then
      Fail('byte-cast-missing-child');
    LeftExpr := Model.HirExprAt(Expr.Children[0] - 1);
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

begin
  CheckTypeCastAndIntrinsicCallsStayReady;
  CheckTypeCastAndIntrinsicOverloadBindings;
  WriteLn('semantic-phase1-type-entry-status=pass');
end.
