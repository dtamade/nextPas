program test_semantic_constructor_type_infer;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.diagnostics.sink,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.syntax.lexer,
  nextpas.compiler.sema.analyzer,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.frontend.unit_graph;

procedure Fail(const AMessage: string);
begin
  WriteLn(StdErr, 'semantic-constructor-type-infer-failure=', AMessage);
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

function SymbolIdByNameAndParamCount(
  const AModel: TSemanticModel;
  const AName: string;
  const AParamCount: LongInt
): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  if AModel = nil then
    Exit;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and
      (Symbol.ParamCount = AParamCount) and
      (SameText(Symbol.Kind, 'method') or
       SameText(Symbol.Kind, 'constructor')) then
      Exit(Symbol.SymbolId);
  end;
end;

function TypeNameOf(const AModel: TSemanticModel; const ATypeId: LongInt): string;
begin
  if (AModel = nil) or (ATypeId <= 0) or (ATypeId > AModel.TypeCount) then
    Exit('');
  Result := AModel.TypeAt(ATypeId - 1).Name;
end;

function FindSingleMemberCallBinding(
  const AModel: TSemanticModel;
  const AName: string;
  out ABinding: TSemanticBinding
): Boolean;
var
  Binding: TSemanticBinding;
  Count: LongInt;
  Index: LongInt;
begin
  Count := 0;
  FillChar(ABinding, SizeOf(ABinding), 0);
  if AModel = nil then
    Exit(False);
  for Index := 0 to AModel.BindingCount - 1 do
  begin
    Binding := AModel.BindingAt(Index);
    if SameText(Binding.Kind, 'member-call') and SameText(Binding.Name, AName) then
    begin
      Inc(Count);
      ABinding := Binding;
    end;
  end;
  Result := Count = 1;
end;

function SymbolTypeIdByNameAndKind(
  const AModel: TSemanticModel;
  const AName: string;
  const AKind: string
): LongInt;
var
  Index: LongInt;
  Symbol: TSemanticSymbol;
begin
  Result := 0;
  if AModel = nil then
    Exit;
  for Index := 0 to AModel.SymbolCount - 1 do
  begin
    Symbol := AModel.SymbolAt(Index);
    if SameText(Symbol.Name, AName) and SameText(Symbol.Kind, AKind) then
      Exit(Symbol.TypeId);
  end;
end;

function TypeCountByName(const AModel: TSemanticModel; const AName: string): LongInt;
var
  Index: LongInt;
begin
  Result := 0;
  if AModel = nil then
    Exit;
  for Index := 0 to AModel.TypeCount - 1 do
    if SameText(AModel.TypeAt(Index).Name, AName) then
      Inc(Result);
end;

procedure CheckParameterizedSubclassConstructorCallKeepsSubclassType;
var
  Binding: TSemanticBinding;
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  Src: string;
  TargetSymbolId: LongInt;
begin
  Src :=
    'program ConstructorTyping;' + LineEnding +
    'type' + LineEnding +
    '  TAnimal = class' + LineEnding +
    '  public' + LineEnding +
    '    constructor Create(const AName: string; AAge: LongInt);' + LineEnding +
    '  end;' + LineEnding +
    '  TDog = class(TAnimal)' + LineEnding +
    '  public' + LineEnding +
    '    constructor Create(const AName: string; AAge: LongInt; const ABreed: string);' + LineEnding +
    '  end;' + LineEnding +
    'constructor TAnimal.Create(const AName: string; AAge: LongInt);' + LineEnding +
    'begin' + LineEnding +
    'end;' + LineEnding +
    'constructor TDog.Create(const AName: string; AAge: LongInt; const ABreed: string);' + LineEnding +
    'begin' + LineEnding +
    '  inherited Create(AName, AAge);' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  D: TDog;' + LineEnding +
    'begin' + LineEnding +
    '  D := TDog.Create(''Rex'', 5, ''Shepherd'');' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-diagnostics');
    if Model = nil then
      Fail('missing-model');

    TargetSymbolId := SymbolIdByNameAndParamCount(
      Model,
      'TDog.Create',
      3
    );
    if TargetSymbolId <= 0 then
      Fail('missing-tdog-create-symbol');

    if not FindSingleMemberCallBinding(Model, 'Create', Binding) then
      Fail('unexpected-create-binding-count');
    if Binding.TargetSymbolId <> TargetSymbolId then
      Fail(
        'wrong-create-binding-target:' + IntToStr(Binding.TargetSymbolId) +
        ' expected=' + IntToStr(TargetSymbolId)
      );

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

procedure CheckAbstractSubclassConstructorUpcast;
var
  BaseSymbolTypeId: LongInt;
  CircleParentTypeId: LongInt;
  CircleSymbolTypeId: LongInt;
  CircleTypeId: LongInt;
  Diagnostics: TDiagnosticsSink;
  Model: TSemanticModel;
  ShapeTypeId: LongInt;
  ShapeSymbolTypeId: LongInt;
  Src: string;
begin
  Src :=
    'program AbstractCtorUpcast;' + LineEnding +
    'type' + LineEnding +
    '  TShape = class' + LineEnding +
    '    function Area: Double; virtual; abstract;' + LineEnding +
    '  end;' + LineEnding +
    '  TCircle = class(TShape)' + LineEnding +
    '    FRadius: Double;' + LineEnding +
    '    constructor Create(ARadius: Double);' + LineEnding +
    '    function Area: Double; override;' + LineEnding +
    '  end;' + LineEnding +
    'constructor TCircle.Create(ARadius: Double);' + LineEnding +
    'begin' + LineEnding +
    '  FRadius := ARadius;' + LineEnding +
    'end;' + LineEnding +
    'function TCircle.Area: Double;' + LineEnding +
    'begin' + LineEnding +
    '  Result := FRadius;' + LineEnding +
    'end;' + LineEnding +
    'var' + LineEnding +
    '  Base: TShape;' + LineEnding +
    'begin' + LineEnding +
    '  Base := TCircle.Create(5.0);' + LineEnding +
    'end.' + LineEnding;

  Diagnostics := nil;
  Model := BuildModel(Src, Diagnostics);
  try
    if Diagnostics = nil then
      Fail('missing-abstract-diagnostics');
    if Model = nil then
      Fail('missing-abstract-model');

    ShapeTypeId := Model.FindTypeByName('TShape');
    CircleTypeId := Model.FindTypeByName('TCircle');
    if ShapeTypeId <= 0 then
      Fail('missing-tshape-type');
    if CircleTypeId <= 0 then
      Fail('missing-tcircle-type');
    if TypeCountByName(Model, 'TShape') <> 1 then
      Fail('unexpected-tshape-type-count:' +
        IntToStr(TypeCountByName(Model, 'TShape')));
    if TypeCountByName(Model, 'TCircle') <> 1 then
      Fail('unexpected-tcircle-type-count:' +
        IntToStr(TypeCountByName(Model, 'TCircle')));

    ShapeSymbolTypeId := SymbolTypeIdByNameAndKind(Model, 'TShape', 'type');
    CircleSymbolTypeId := SymbolTypeIdByNameAndKind(Model, 'TCircle', 'type');
    BaseSymbolTypeId := SymbolTypeIdByNameAndKind(Model, 'Base', 'variable');
    if ShapeSymbolTypeId <> ShapeTypeId then
      Fail('wrong-tshape-symbol-type:' + IntToStr(ShapeSymbolTypeId));
    if CircleSymbolTypeId <> CircleTypeId then
      Fail('wrong-tcircle-symbol-type:' + IntToStr(CircleSymbolTypeId));
    if BaseSymbolTypeId <> ShapeTypeId then
      Fail('wrong-base-symbol-type:' + IntToStr(BaseSymbolTypeId));

    CircleParentTypeId := Model.TypeAt(CircleTypeId - 1).ParentTypeId;
    if CircleParentTypeId <> ShapeTypeId then
      Fail(
        'wrong-tcircle-parent:' + TypeNameOf(Model, CircleParentTypeId) +
        ' expected=' + TypeNameOf(Model, ShapeTypeId)
      );

    if Diagnostics.HasErrors then
      Fail('unexpected-abstract-error:' + Diagnostics.LastDiagnosticCode + ':' +
        Diagnostics.LastDiagnosticMessage);
    if not SameText(Model.Status, 'ready') then
      Fail('unexpected-abstract-status:' + Model.Status);
  finally
    Model.Free;
    Diagnostics.Free;
  end;
end;

begin
  CheckParameterizedSubclassConstructorCallKeepsSubclassType;
  CheckAbstractSubclassConstructorUpcast;
  WriteLn('semantic-constructor-type-infer-status=pass');
end.
