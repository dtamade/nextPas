program test_semantic_type_compat;

{$mode objfpc}{$H+}

uses
  nextpas.core.text.conv,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  nextpas.compiler.sema.analyzer,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.frontend.unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'semantic-type-compat-failure=', AMessage);
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

procedure CheckIntegerToIntegerAssignment;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program IntAssign;' + LineEnding +
    'var' + LineEnding +
    '  A, B: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  A := B;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckIntegerToByteAssignmentShouldWarn;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program IntToByte;' + LineEnding +
    'var' + LineEnding +
    '  A: Integer;' + LineEnding +
    '  B: Byte;' + LineEnding +
    'begin' + LineEnding +
    '  B := A;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    { Byte := Integer may produce a warning but should still be ready }
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckBooleanExpressionTypes;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program BoolExpr;' + LineEnding +
    'var' + LineEnding +
    '  A, B: Integer;' + LineEnding +
    '  Flag: Boolean;' + LineEnding +
    'begin' + LineEnding +
    '  Flag := A > B;' + LineEnding +
    '  if Flag then' + LineEnding +
    '    A := 0;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckStringTypeAssignment;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program StrAssign;' + LineEnding +
    'var' + LineEnding +
    '  S: string;' + LineEnding +
    'begin' + LineEnding +
    '  S := ''hello'';' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckRecordFieldTypeAccess;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program RecordField;' + LineEnding +
    'type' + LineEnding +
    '  TPoint = record' + LineEnding +
    '    X, Y: Integer;' + LineEnding +
    '  end;' + LineEnding +
    'var' + LineEnding +
    '  P: TPoint;' + LineEnding +
    '  Val: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Val := P.X;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckArrayAccessType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program ArrAccess;' + LineEnding +
    'var' + LineEnding +
    '  Arr: array[0..9] of Integer;' + LineEnding +
    '  Val: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Val := Arr[5];' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckPointerDerefType;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program PtrDeref;' + LineEnding +
    'var' + LineEnding +
    '  P: ^Integer;' + LineEnding +
    '  Val: Integer;' + LineEnding +
    'begin' + LineEnding +
    '  Val := P^;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

procedure CheckArithmeticExpressionTypes;
var
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
begin
  Src :=
    'program ArithExpr;' + LineEnding +
    'var' + LineEnding +
    '  A, B, C: Integer;' + LineEnding +
    '  D: Double;' + LineEnding +
    'begin' + LineEnding +
    '  C := A + B;' + LineEnding +
    '  C := A * B;' + LineEnding +
    '  C := A - B;' + LineEnding +
    '  D := A / B;' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');
    if Diagnostics.HasErrors then
      Fail('unexpected-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

begin
  CheckIntegerToIntegerAssignment;
  CheckIntegerToByteAssignmentShouldWarn;
  CheckBooleanExpressionTypes;
  CheckStringTypeAssignment;
  CheckRecordFieldTypeAccess;
  CheckArrayAccessType;
  CheckPointerDerefType;
  CheckArithmeticExpressionTypes;
  WriteLn('semantic-type-compat-status=pass');
end.
