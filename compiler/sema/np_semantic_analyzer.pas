unit np_semantic_analyzer;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}
{$UNITPATH ../syntax}

interface

uses
  np_ast_facade, np_diagnostics_sink, np_source_database, np_unit_graph,
  np_semantic_model, np_green_tree;

type
  TProcedureBodyEntry = record
    Name: string;
    Body: TGreenNode;
    Decl: TGreenNode;
  end;

  TParamSnapshot = record
    Name: string;
    HadValue: Boolean;
    PriorValue: Int64;
  end;
  TParamSnapshots = array of TParamSnapshot;

  TSemanticAnalyzer = class
  private
    FRootAst: TAstFacade;
    FUnitGraph: TUnitGraph;
    FDiagnostics: TDiagnosticsSink;
    FRootFileId: TSourceFileId;
    FNoFold: Boolean;
    FModel: TSemanticModel;
    FProcedureBodies: array of TProcedureBodyEntry;
    FInliningStack: array of string;
    FBlockLabelCounter: LongInt;
    FCurrentBlockTerminated: Boolean;
    FCurrentScopeId: LongInt;
    FRuntimeVarNames: array of string;
    procedure RegisterRuntimeVar(const AName: string);
    function IsRuntimeVar(const AName: string): Boolean;
    function NewBlockLabel(const APrefix: string): string;
    procedure EmitBlockLabel(const ALabel: string);
    procedure EmitGotoLabel(const ALabel: string);
    procedure RegisterProcedureBody(const AName: string;
      const ABody: TGreenNode; const ADecl: TGreenNode);
    function LookupProcedureBody(const AName: string;
      out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
    function IsCurrentlyInlining(const AName: string): Boolean;
    procedure PushInlining(const AName: string);
    procedure PopInlining;
    function BindCallArgs(const ADecl: TGreenNode;
      const ACallNode: TGreenNode;
      const ANameSkip: LongInt): TParamSnapshots;
    procedure RestoreCallArgs(const ASnapshots: TParamSnapshots);
    function DuplicateImportName: string;
    procedure EmitSemaError(
      const ACode: string;
      const AMessage: string;
      const AByteOffset: LongInt
    );
    function RegisterSymbol(
      const AName: string;
      const AKind: string;
      const AOwnerUnitId: string;
      const ATypeId: LongInt;
      const AByteOffset: LongInt
    ): LongInt;
    function IsBuiltinProcedure(const AName: string): Boolean;
    function InferExpressionType(const ANode: TGreenNode): LongInt;
    function AreTypesCompatible(const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
    procedure SeedBuiltinTypes;
    procedure AssignScopesToSymbols;
    procedure CheckDuplicateDeclarations;
    procedure CheckUndeclaredIdentifiers;
    procedure CheckIdentifiersInNode(const ANode: TGreenNode);
    procedure CheckTypeMismatches;
    procedure CheckTypeMismatchesInNode(const ANode: TGreenNode);
    procedure CheckUnusedSymbols;
    procedure CheckUnreachableCode;
    procedure CheckUnreachableInNode(const ANode: TGreenNode;
      var ATerminated: Boolean);
    procedure CheckDuplicateCaseLabels;
    procedure CheckCaseLabelsInNode(const ANode: TGreenNode);
    procedure SeedDeclarations;
    procedure CheckAssignmentTypes;
    procedure SeedUnitSymbolsAndHir;
    procedure SeedForeignProcedureBindings;
    procedure SeedRuntimeContracts;
    function ResolveTypeId(const ATypeName: string): LongInt;
    function FindSymbolByName(const AName: string): LongInt;
    procedure ProcessVarSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessConstSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessProcedureDecl(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessFunctionDecl(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessTypeSection(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure ProcessEnumType(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure ProcessRecordFields(const ANode: TGreenNode;
      const AOwnerUnitId: string; const ATypeId: LongInt);
    procedure WalkDeclarations(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure WalkAssignmentStatements(const ANode: TGreenNode);
    procedure UnrollAssignmentForLoop(const ANode: TGreenNode);
    procedure UnrollAssignmentWhileLoop(const ANode: TGreenNode);
    procedure UnrollAssignmentRepeatLoop(const ANode: TGreenNode);
    function EvaluateIntegerConstant(const ANode: TGreenNode;
      out AValue: Int64): Boolean;
    function EvaluateStringConstant(const ANode: TGreenNode;
      out AValue: string): Boolean;
    procedure WalkHaltCalls(const ANode: TGreenNode);
    function EncodeRuntimeIntExprFold(const ANode: TGreenNode;
      out ABlob: string): Boolean;
    function EncodeRuntimeBoolExprFold(const ANode: TGreenNode;
      out ABlob: string): Boolean;
    procedure LowerRuntimeIfStatement(
      const AIfNode: TGreenNode; const ACondBlob: string);
    procedure LowerRuntimeWhileStatement(const ANode: TGreenNode);
    procedure LowerRuntimeForStatement(const ANode: TGreenNode);
    procedure LowerRuntimeRepeatStatement(const ANode: TGreenNode);
    procedure UnrollHaltForLoop(const ANode: TGreenNode);
    procedure UnrollHaltWhileLoop(const ANode: TGreenNode);
    procedure UnrollHaltRepeatLoop(const ANode: TGreenNode);
    procedure SeedRuntimeVarDecls;
    procedure WalkRuntimeVarDecls(const ANode: TGreenNode);
    procedure SeedHaltCalls;
    procedure SeedFunctionBodies;
  public
    constructor Create(
      const ARootAst: TAstFacade;
      const AUnitGraph: TUnitGraph;
      const ADiagnostics: TDiagnosticsSink;
      const ARootFileId: TSourceFileId;
      const ANoFold: Boolean
    );
    destructor Destroy; override;
    procedure Analyze;
    function DetachModel: TSemanticModel;
    function Status: string;
  end;

implementation

uses
  SysUtils;

type
  TStringArray = array of string;

function ContainsString(
  const AItems: TStringArray;
  const AValue: string
): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(AItems) - 1 do
    if AItems[Index] = AValue then
      Exit(True);

  Result := False;
end;

procedure AppendString(var AItems: TStringArray; const AValue: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(AItems);
  SetLength(AItems, NextIndex + 1);
  AItems[NextIndex] := AValue;
end;

constructor TSemanticAnalyzer.Create(
  const ARootAst: TAstFacade;
  const AUnitGraph: TUnitGraph;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ANoFold: Boolean
);
begin
  inherited Create;
  FRootAst := ARootAst;
  FUnitGraph := AUnitGraph;
  FDiagnostics := ADiagnostics;
  FRootFileId := ARootFileId;
  FNoFold := ANoFold;
  FModel := TSemanticModel.Create;
  FBlockLabelCounter := 0;
  FCurrentScopeId := 0;
end;

function TSemanticAnalyzer.NewBlockLabel(const APrefix: string): string;
begin
  Inc(FBlockLabelCounter);
  Result := APrefix + IntToStr(FBlockLabelCounter);
end;

procedure TSemanticAnalyzer.RegisterRuntimeVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeVarNames) - 1 do
    if SameText(FRuntimeVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeVarNames);
  SetLength(FRuntimeVarNames, NextIndex + 1);
  FRuntimeVarNames[NextIndex] := AName;
end;

function TSemanticAnalyzer.IsRuntimeVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeVarNames) - 1 do
    if SameText(FRuntimeVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.EmitBlockLabel(const ALabel: string);
begin
  FModel.AddTypedHirNode('block-label-runtime', ALabel, 0, 0, ALabel);
  FCurrentBlockTerminated := False;
end;

procedure TSemanticAnalyzer.EmitGotoLabel(const ALabel: string);
begin
  if FCurrentBlockTerminated then
    Exit;
  FModel.AddTypedHirNode('br-runtime', ALabel, 0, 0, ALabel);
  FCurrentBlockTerminated := True;
end;

destructor TSemanticAnalyzer.Destroy;
begin
  FModel.Free;
  inherited Destroy;
end;

function TSemanticAnalyzer.DuplicateImportName: string;
var
  SeenImports: TStringArray;
  Index: LongInt;
  ImportName: string;
  ImportId: string;
begin
  SeenImports := nil;

  for Index := 0 to FRootAst.InterfaceUseCount - 1 do
  begin
    ImportName := FRootAst.InterfaceUseAt(Index);
    ImportId := NormalizeUnitIdentity(ImportName);
    if ContainsString(SeenImports, ImportId) then
      Exit(ImportName);
    AppendString(SeenImports, ImportId);
  end;

  for Index := 0 to FRootAst.ImplementationUseCount - 1 do
  begin
    ImportName := FRootAst.ImplementationUseAt(Index);
    ImportId := NormalizeUnitIdentity(ImportName);
    if ContainsString(SeenImports, ImportId) then
      Exit(ImportName);
    AppendString(SeenImports, ImportId);
  end;

  Result := '';
end;

procedure TSemanticAnalyzer.RegisterProcedureBody(const AName: string;
  const ABody: TGreenNode; const ADecl: TGreenNode);
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) then
    begin
      FProcedureBodies[Index].Body := ABody;
      FProcedureBodies[Index].Decl := ADecl;
      Exit;
    end;
  NextIndex := Length(FProcedureBodies);
  SetLength(FProcedureBodies, NextIndex + 1);
  FProcedureBodies[NextIndex].Name := AName;
  FProcedureBodies[NextIndex].Body := ABody;
  FProcedureBodies[NextIndex].Decl := ADecl;
end;

function TSemanticAnalyzer.LookupProcedureBody(const AName: string;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
var
  Index: LongInt;
begin
  ABody := nil;
  ADecl := nil;
  for Index := 0 to Length(FProcedureBodies) - 1 do
    if SameText(FProcedureBodies[Index].Name, AName) then
    begin
      ABody := FProcedureBodies[Index].Body;
      ADecl := FProcedureBodies[Index].Decl;
      Exit(True);
    end;
  Result := False;
end;

function TSemanticAnalyzer.BindCallArgs(const ADecl: TGreenNode;
  const ACallNode: TGreenNode;
  const ANameSkip: LongInt): TParamSnapshots;
var
  ParamList: TGreenNode;
  ParamDecl, ArgNode: TGreenNode;
  Index, ParamIndex, ArgIndex: LongInt;
  Value, Prior: Int64;
  Snap: TParamSnapshot;
begin
  Result := nil;
  if (ADecl = nil) or (ACallNode = nil) then
    Exit;
  ParamList := nil;
  for Index := 0 to ADecl.ChildCount - 1 do
    if (ADecl.ChildAt(Index) <> nil) and
      (ADecl.ChildAt(Index).NodeKind = gnkParameterList) then
    begin
      ParamList := ADecl.ChildAt(Index);
      Break;
    end;
  if ParamList = nil then
    Exit;
  ParamIndex := 0;
  for Index := 0 to ParamList.ChildCount - 1 do
  begin
    ParamDecl := ParamList.ChildAt(Index);
    if (ParamDecl = nil) or (ParamDecl.NodeKind <> gnkParameterDecl) then
      Continue;
    ArgIndex := ANameSkip + ParamIndex;
    if ArgIndex >= ACallNode.ChildCount then
      Break;
    ArgNode := ACallNode.ChildAt(ArgIndex);
    if (ArgNode <> nil) and EvaluateIntegerConstant(ArgNode, Value) then
    begin
      Snap.Name := ParamDecl.Text;
      Snap.HadValue := FModel.LookupVarInitValue(ParamDecl.Text, Prior);
      Snap.PriorValue := Prior;
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := Snap;
      FModel.AddVarInitValue(ParamDecl.Text, Value);
    end;
    Inc(ParamIndex);
  end;
end;

procedure TSemanticAnalyzer.RestoreCallArgs(const ASnapshots: TParamSnapshots);
var
  Index: LongInt;
begin
  for Index := High(ASnapshots) downto 0 do
  begin
    if ASnapshots[Index].HadValue then
      FModel.AddVarInitValue(ASnapshots[Index].Name,
        ASnapshots[Index].PriorValue)
    else
      FModel.RemoveVarInitValue(ASnapshots[Index].Name);
  end;
end;

function TSemanticAnalyzer.IsCurrentlyInlining(const AName: string): Boolean;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FInliningStack) - 1 do
    if SameText(FInliningStack[Index], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemanticAnalyzer.PushInlining(const AName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FInliningStack);
  SetLength(FInliningStack, NextIndex + 1);
  FInliningStack[NextIndex] := AName;
end;

procedure TSemanticAnalyzer.PopInlining;
var
  Last: LongInt;
begin
  Last := Length(FInliningStack) - 1;
  if Last >= 0 then
    SetLength(FInliningStack, Last);
end;

function EncodeRuntimeIntExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean; forward;

function EncodeRuntimeBoolExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op, Pred: string;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if ANode.NodeKind <> gnkBinaryExpression then
    Exit(False);
  if ANode.ChildCount < 2 then
    Exit(False);
  Op := ANode.Text;
  if Op = '=' then Pred := 'eq'
  else if Op = '<>' then Pred := 'ne'
  else if Op = '<' then Pred := 'slt'
  else if Op = '<=' then Pred := 'sle'
  else if Op = '>' then Pred := 'sgt'
  else if Op = '>=' then Pred := 'sge'
  else
    Exit(False);
  if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not EncodeRuntimeIntExpr(ANode.ChildAt(1), RightBlob) then
    Exit(False);
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;

function EncodeRuntimeIntExpr(const ANode: TGreenNode;
  out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op: string;
  Parsed: Int64;
  ParseCode: Word;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkIntegerLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        ABlob := 'int ' + IntToStr(Parsed) + #10;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if ANode.Text = '' then
          Exit(False);
        ABlob := 'var ' + ANode.Text + #10;
        Exit(True);
      end;
    gnkUnaryExpression:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
          Exit(False);
        Op := ANode.Text;
        if Op = '-' then
        begin
          ABlob := LeftBlob + 'neg' + #10;
          Exit(True);
        end
        else if Op = '+' then
        begin
          ABlob := LeftBlob;
          Exit(True);
        end
        else
          Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(0), LeftBlob) then
          Exit(False);
        if not EncodeRuntimeIntExpr(ANode.ChildAt(1), RightBlob) then
          Exit(False);
        Op := ANode.Text;
        if Op = '+' then
          ABlob := LeftBlob + RightBlob + 'add' + #10
        else if Op = '-' then
          ABlob := LeftBlob + RightBlob + 'sub' + #10
        else if Op = '*' then
          ABlob := LeftBlob + RightBlob + 'mul' + #10
        else if SameText(Op, 'div') then
          ABlob := LeftBlob + RightBlob + 'div' + #10
        else if SameText(Op, 'mod') then
          ABlob := LeftBlob + RightBlob + 'mod' + #10
        else
          Exit(False);
        Exit(True);
      end;
    gnkFunctionCall:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
          Exit(False);
        ABlob := '';
        for Parsed := 1 to ANode.ChildCount - 1 do
        begin
          if not EncodeRuntimeIntExpr(ANode.ChildAt(Parsed), RightBlob) then
            Exit(False);
          ABlob := ABlob + RightBlob;
        end;
        ABlob := ABlob + 'call ' + ANode.ChildAt(0).Text + ' ' +
          IntToStr(ANode.ChildCount - 1) + #10;
        Exit(True);
      end;
  end;
  Result := False;
end;

procedure TSemanticAnalyzer.EmitSemaError(
  const ACode: string;
  const AMessage: string;
  const AByteOffset: LongInt
);
begin
  FDiagnostics.EmitError(ACode, 'sema', FRootFileId, AByteOffset, AMessage);
  FModel.MarkFailure;
end;

function TSemanticAnalyzer.RegisterSymbol(
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const ATypeId: LongInt;
  const AByteOffset: LongInt
): LongInt;
var
  Existing: LongInt;
begin
  if (FCurrentScopeId > 0) and (AName <> '') then
  begin
    Existing := FModel.FindSymbolInScope(AName, FCurrentScopeId);
    if Existing > 0 then
    begin
      EmitSemaError(
        'sema.duplicate-declaration',
        'duplicate identifier "' + AName + '"',
        AByteOffset
      );
    end;
  end;
  Result := FModel.AddSymbol(AName, AKind, AOwnerUnitId, ATypeId, AByteOffset);
  if FCurrentScopeId > 0 then
    FModel.SetSymbolScope(Result, FCurrentScopeId);
end;

function TSemanticAnalyzer.IsBuiltinProcedure(const AName: string): Boolean;
begin
  Result := SameText(AName, 'WriteLn') or SameText(AName, 'Write') or
    SameText(AName, 'ReadLn') or SameText(AName, 'Read') or
    SameText(AName, 'Inc') or SameText(AName, 'Dec') or
    SameText(AName, 'SetLength') or SameText(AName, 'Length') or
    SameText(AName, 'High') or SameText(AName, 'Low') or
    SameText(AName, 'Ord') or SameText(AName, 'Chr') or
    SameText(AName, 'Pred') or SameText(AName, 'Succ') or
    SameText(AName, 'Abs') or SameText(AName, 'Sqr') or
    SameText(AName, 'Sqrt') or SameText(AName, 'Round') or
    SameText(AName, 'Trunc') or SameText(AName, 'Halt') or
    SameText(AName, 'Exit') or SameText(AName, 'Break') or
    SameText(AName, 'Continue') or SameText(AName, 'Assigned') or
    SameText(AName, 'New') or SameText(AName, 'Dispose') or
    SameText(AName, 'SizeOf') or SameText(AName, 'TypeOf') or
    SameText(AName, 'Str') or SameText(AName, 'Val') or
    SameText(AName, 'Copy') or SameText(AName, 'Concat') or
    SameText(AName, 'Pos') or SameText(AName, 'Delete') or
    SameText(AName, 'Insert') or SameText(AName, 'IntToStr') or
    SameText(AName, 'StrToInt') or SameText(AName, 'Addr') or
    SameText(AName, 'FillChar') or SameText(AName, 'Move') or
    SameText(AName, 'Exclude') or SameText(AName, 'Include') or
    SameText(AName, 'Assert') or SameText(AName, 'Swap') or
    SameText(AName, 'Lo') or SameText(AName, 'Hi') or
    SameText(AName, 'Odd') or SameText(AName, 'Char') or
    SameText(AName, 'Free');
end;

function TSemanticAnalyzer.InferExpressionType(const ANode: TGreenNode): LongInt;
var
  SymId: LongInt;
  Sym: TSemanticSymbol;
begin
  Result := 0;
  if ANode = nil then
    Exit;
  case ANode.NodeKind of
    gnkIntegerLiteral:
      Result := FModel.FindTypeByName('Integer');
    gnkRealLiteral:
      Result := FModel.FindTypeByName('Double');
    gnkStringLiteral:
      Result := FModel.FindTypeByName('AnsiString');
    gnkCharLiteral:
      Result := FModel.FindTypeByName('Char');
    gnkIdentifier:
      begin
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Result := Sym.TypeId;
        end
        else
          Result := FModel.FindTypeByName(ANode.Text);
      end;
    gnkBinaryExpression:
      begin
        if ANode.Text = '+' then
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = FModel.FindTypeByName('AnsiString') then
            Exit;
          if Result = 0 then
            Result := InferExpressionType(ANode.ChildAt(1));
          if Result = 0 then
            Result := FModel.FindTypeByName('Integer');
        end
        else if (ANode.Text = '=') or (ANode.Text = '<>') or
          (ANode.Text = '<') or (ANode.Text = '>') or
          (ANode.Text = '<=') or (ANode.Text = '>=') or
          (ANode.Text = 'in') or (ANode.Text = 'is') then
          Result := FModel.FindTypeByName('Boolean')
        else if (ANode.Text = 'and') or (ANode.Text = 'or') or
          (ANode.Text = 'xor') then
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = FModel.FindTypeByName('Boolean') then
            Exit;
          Result := FModel.FindTypeByName('Integer');
        end
        else
        begin
          Result := InferExpressionType(ANode.ChildAt(0));
          if Result = 0 then
            Result := FModel.FindTypeByName('Integer');
        end;
      end;
    gnkUnaryExpression:
      begin
        if ANode.Text = 'not' then
          Result := InferExpressionType(ANode.ChildAt(0))
        else
          Result := InferExpressionType(ANode.ChildAt(0));
        if Result = 0 then
          Result := FModel.FindTypeByName('Integer');
      end;
    gnkFunctionCall:
      begin
        SymId := FModel.LookupSymbol(ANode.Text, FCurrentScopeId);
        if SymId > 0 then
        begin
          Sym := FModel.SymbolAt(SymId - 1);
          Result := Sym.TypeId;
        end;
      end;
    gnkDotAccess, gnkArrayAccess, gnkDereference:
      Result := 0;
  end;
end;

function TSemanticAnalyzer.AreTypesCompatible(
  const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
var
  IntIds: array[0..9] of LongInt;
  StrIds: array[0..3] of LongInt;
  I: LongInt;
  LhsIsInt, RhsIsInt, LhsIsStr, RhsIsStr: Boolean;
  LhsType, RhsType: TSemanticType;
begin
  if ALhsTypeId = ARhsTypeId then
    Exit(True);
  if (ALhsTypeId = 0) or (ARhsTypeId = 0) then
    Exit(True);

  LhsType := FModel.TypeAt(ALhsTypeId - 1);
  RhsType := FModel.TypeAt(ARhsTypeId - 1);
  if (LhsType.Kind = 'declared') or (RhsType.Kind = 'declared') or
    (LhsType.Kind = 'alias') or (RhsType.Kind = 'alias') then
  begin
    if FModel.IsTypeDescendantOf(ARhsTypeId, ALhsTypeId) then
      Exit(True);
    if FModel.IsTypeDescendantOf(ALhsTypeId, ARhsTypeId) then
      Exit(True);
    Exit(True);
  end;

  IntIds[0] := FModel.FindTypeByName('Byte');
  IntIds[1] := FModel.FindTypeByName('Word');
  IntIds[2] := FModel.FindTypeByName('LongInt');
  IntIds[3] := FModel.FindTypeByName('Integer');
  IntIds[4] := FModel.FindTypeByName('Int64');
  IntIds[5] := FModel.FindTypeByName('QWord');
  IntIds[6] := FModel.FindTypeByName('LongWord');
  IntIds[7] := FModel.FindTypeByName('Single');
  IntIds[8] := FModel.FindTypeByName('Double');
  IntIds[9] := FModel.FindTypeByName('Pointer');

  LhsIsInt := False;
  RhsIsInt := False;
  for I := 0 to 9 do
  begin
    if ALhsTypeId = IntIds[I] then LhsIsInt := True;
    if ARhsTypeId = IntIds[I] then RhsIsInt := True;
  end;
  if LhsIsInt and RhsIsInt then
    Exit(True);

  StrIds[0] := FModel.FindTypeByName('AnsiString');
  StrIds[1] := FModel.FindTypeByName('ShortString');
  StrIds[2] := FModel.FindTypeByName('WideString');
  StrIds[3] := FModel.FindTypeByName('UnicodeString');

  LhsIsStr := False;
  RhsIsStr := False;
  for I := 0 to 3 do
  begin
    if ALhsTypeId = StrIds[I] then LhsIsStr := True;
    if ARhsTypeId = StrIds[I] then RhsIsStr := True;
  end;
  if LhsIsStr and RhsIsStr then
    Exit(True);

  if ALhsTypeId = FModel.FindTypeByName('Boolean') then
    Exit(ARhsTypeId = FModel.FindTypeByName('Boolean'));

  if LhsIsStr and (ARhsTypeId = FModel.FindTypeByName('Char')) then
    Exit(True);
  if (ALhsTypeId = FModel.FindTypeByName('Char')) and RhsIsStr then
    Exit(True);
  if (ALhsTypeId = FModel.FindTypeByName('Char')) and
    (ARhsTypeId = FModel.FindTypeByName('Char')) then
    Exit(True);

  Result := False;
end;

procedure TSemanticAnalyzer.SeedBuiltinTypes;
begin
  FModel.AddType('Boolean', 'builtin');
  FModel.AddType('Integer', 'builtin');
  FModel.AddType('AnsiString', 'builtin');
  FModel.AddType('Char', 'builtin');
  FModel.AddType('Byte', 'builtin');
  FModel.AddType('Word', 'builtin');
  FModel.AddType('LongInt', 'builtin');
  FModel.AddType('Int64', 'builtin');
  FModel.AddType('QWord', 'builtin');
  FModel.AddType('Single', 'builtin');
  FModel.AddType('Double', 'builtin');
  FModel.AddType('Pointer', 'builtin');
  FModel.AddType('Text', 'builtin');
  FModel.AddType('ShortString', 'builtin');
  FModel.AddType('WideString', 'builtin');
  FModel.AddType('UnicodeString', 'builtin');
  FModel.AddType('Variant', 'builtin');
  FModel.AddType('OleVariant', 'builtin');
  FModel.AddType('String', 'alias');
  FModel.AddType('Cardinal', 'alias');
end;

procedure TSemanticAnalyzer.AssignScopesToSymbols;
var
  I: LongInt;
  Sym: TSemanticSymbol;
begin
  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Sym := FModel.SymbolAt(I);
    if Sym.ScopeId = 0 then
      FModel.SetSymbolScope(Sym.SymbolId, FCurrentScopeId);
  end;
end;

procedure TSemanticAnalyzer.CheckDuplicateDeclarations;
var
  I, J: LongInt;
  SymI, SymJ: TSemanticSymbol;
begin
  for I := 0 to FModel.SymbolCount - 2 do
  begin
    SymI := FModel.SymbolAt(I);
    if SymI.Kind = 'unit' then
      Continue;
    for J := I + 1 to FModel.SymbolCount - 1 do
    begin
      SymJ := FModel.SymbolAt(J);
      if SymJ.Kind = 'unit' then
        Continue;
      if (SymI.ScopeId = SymJ.ScopeId) and SameText(SymI.Name, SymJ.Name) and
        (SymI.Kind <> 'parameter') and (SymJ.Kind <> 'parameter') and
        (SymI.Kind <> 'enum-value') and (SymJ.Kind <> 'enum-value') then
      begin
        EmitSemaError(
          'sema.duplicate-declaration',
          'duplicate identifier "' + SymJ.Name + '"',
          SymJ.ByteOffset
        );
        Exit;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckIdentifiersInNode(const ANode: TGreenNode);
var
  I: LongInt;
  Child: TGreenNode;
  SymId: LongInt;
  Name: string;
begin
  if ANode = nil then
    Exit;
  case ANode.NodeKind of
    gnkAssignmentStatement:
      begin
        Name := ANode.Text;
        if (Name <> '') and (Name <> 'Result') then
        begin
          SymId := FModel.LookupSymbol(Name, FCurrentScopeId);
          if (SymId = 0) and (FModel.FindTypeByName(Name) = 0) and
            not IsBuiltinProcedure(Name) then
            EmitSemaError(
              'sema.undeclared-identifier',
              'identifier not found "' + Name + '"',
              ANode.ByteOffset
            );
        end;
      end;
    gnkStatementList, gnkBeginBlock, gnkIfStatement,
    gnkWhileStatement, gnkForStatement, gnkForInStatement,
    gnkRepeatStatement, gnkCaseStatement, gnkCaseSelector,
    gnkTryExceptStatement, gnkTryFinallyStatement:
      begin
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then
            CheckIdentifiersInNode(Child);
        end;
      end;
  end;
end;

procedure TSemanticAnalyzer.CheckUndeclaredIdentifiers;
var
  RootNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
      CheckIdentifiersInNode(Child);
  end;
end;

procedure TSemanticAnalyzer.CheckTypeMismatchesInNode(const ANode: TGreenNode);
var
  I: LongInt;
  Child, RhsChild: TGreenNode;
  LhsName: string;
  LhsSymId: LongInt;
  LhsSym: TSemanticSymbol;
  LhsTypeId, RhsTypeId: LongInt;
begin
  if ANode = nil then
    Exit;

  case ANode.NodeKind of
    gnkAssignmentStatement:
      begin
        LhsName := ANode.Text;
        if LhsName = '' then
          Exit;
        LhsSymId := FModel.LookupSymbol(LhsName, FCurrentScopeId);
        if LhsSymId = 0 then
          Exit;
        LhsSym := FModel.SymbolAt(LhsSymId - 1);
        LhsTypeId := LhsSym.TypeId;
        if LhsTypeId = 0 then
          Exit;
        RhsChild := nil;
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if (Child <> nil) and (Child.NodeKind <> gnkDotAccess) and
            (Child.NodeKind <> gnkArrayAccess) and
            (Child.NodeKind <> gnkIdentifier) then
          begin
            RhsChild := Child;
            Break;
          end;
        end;
        if RhsChild = nil then
          Exit;
        RhsTypeId := InferExpressionType(RhsChild);
        if RhsTypeId = 0 then
          Exit;
        if AreTypesCompatible(LhsTypeId, RhsTypeId) then
          Exit;
        EmitSemaError(
          'sema.type-mismatch',
          'incompatible types: cannot assign to "' + LhsName + '"',
          ANode.ByteOffset
        );
      end;
    gnkProcedureCallStatement:
      begin
        LhsName := ANode.Text;
        if LhsName <> '' then
        begin
          LhsSymId := FModel.LookupSymbol(LhsName, FCurrentScopeId);
          if LhsSymId > 0 then
          begin
            LhsSym := FModel.SymbolAt(LhsSymId - 1);
            if (LhsSym.ParamCount >= 0) and
              ((LhsSym.Kind = 'procedure') or (LhsSym.Kind = 'function')) then
            begin
              RhsChild := ANode.ChildAt(0);
              if (RhsChild <> nil) and (RhsChild.NodeKind = gnkFunctionCall) then
                LhsTypeId := RhsChild.ChildCount - 1
              else
                LhsTypeId := ANode.ChildCount;
              if LhsTypeId > LhsSym.ParamCount then
                EmitSemaError(
                  'sema.wrong-argument-count',
                  'too many arguments for "' + LhsName + '" (expected ' +
                    IntToStr(LhsSym.ParamCount) + ', got ' +
                    IntToStr(LhsTypeId) + ')',
                  ANode.ByteOffset
                );
            end;
          end;
        end;
      end;
    gnkStatementList, gnkBeginBlock, gnkIfStatement,
    gnkWhileStatement, gnkForStatement, gnkForInStatement,
    gnkRepeatStatement, gnkCaseStatement, gnkCaseSelector,
    gnkTryExceptStatement, gnkTryFinallyStatement:
      begin
        for I := 0 to ANode.ChildCount - 1 do
        begin
          Child := ANode.ChildAt(I);
          if Child <> nil then
            CheckTypeMismatchesInNode(Child);
        end;
      end;
  end;
end;

procedure TSemanticAnalyzer.CheckTypeMismatches;
var
  RootNode: TGreenNode;
  I: LongInt;
  Child: TGreenNode;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
      CheckTypeMismatchesInNode(Child);
  end;
end;

procedure TSemanticAnalyzer.CheckUnusedSymbols;

  function IsNameUsedInNode(const ANode: TGreenNode; const AName: string): Boolean;
  var
    I: LongInt;
    Child: TGreenNode;
  begin
    if ANode = nil then
      Exit(False);
    if (ANode.NodeKind = gnkIdentifier) and SameText(ANode.Text, AName) then
      Exit(True);
    if (ANode.NodeKind = gnkAssignmentStatement) and SameText(ANode.Text, AName) then
      Exit(True);
    if (ANode.NodeKind = gnkProcedureCallStatement) and SameText(ANode.Text, AName) then
      Exit(True);
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if IsNameUsedInNode(Child, AName) then
        Exit(True);
    end;
    Result := False;
  end;

var
  I: LongInt;
  Sym: TSemanticSymbol;
  RootNode, Child: TGreenNode;
  BeginBlock: TGreenNode;
  J: LongInt;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;

  BeginBlock := nil;
  for J := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
    begin
      BeginBlock := Child;
      Break;
    end;
  end;
  if BeginBlock = nil then
    Exit;

  for I := 0 to FModel.SymbolCount - 1 do
  begin
    Sym := FModel.SymbolAt(I);
    if Sym.Kind <> 'variable' then
      Continue;
    if Sym.ScopeId <> FCurrentScopeId then
      Continue;
    if not IsNameUsedInNode(BeginBlock, Sym.Name) then
      FDiagnostics.EmitWarning(
        'sema.unused-variable',
        'sema',
        FRootFileId,
        Sym.ByteOffset,
        'variable "' + Sym.Name + '" is declared but never used'
      );
  end;
end;

procedure TSemanticAnalyzer.CheckUnreachableInNode(const ANode: TGreenNode;
  var ATerminated: Boolean);
var
  I: LongInt;
  Child: TGreenNode;
  ChildTerminated: Boolean;
begin
  if ANode = nil then
    Exit;
  ATerminated := False;

  if ANode.NodeKind = gnkStatementList then
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child = nil then
        Continue;
      if ATerminated then
      begin
        if (Child.NodeKind <> gnkError) then
          FDiagnostics.EmitWarning(
            'sema.unreachable-code',
            'sema',
            FRootFileId,
            Child.ByteOffset,
            'unreachable code after unconditional exit'
          );
        Exit;
      end;
      ChildTerminated := False;
      CheckUnreachableInNode(Child, ChildTerminated);
      if ChildTerminated then
        ATerminated := True;
    end;
  end
  else
  begin
    case ANode.NodeKind of
      gnkExitStatement:
        ATerminated := True;
      gnkBreakStatement:
        ATerminated := True;
      gnkContinueStatement:
        ATerminated := True;
      gnkProcedureCallStatement:
        if SameText(ANode.Text, 'Halt') then
          ATerminated := True;
      gnkBeginBlock, gnkIfStatement, gnkWhileStatement,
      gnkForStatement, gnkRepeatStatement, gnkCaseStatement,
      gnkTryExceptStatement, gnkTryFinallyStatement:
        begin
          for I := 0 to ANode.ChildCount - 1 do
          begin
            Child := ANode.ChildAt(I);
            if Child <> nil then
              CheckUnreachableInNode(Child, ChildTerminated);
          end;
        end;
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckUnreachableCode;
var
  RootNode, Child: TGreenNode;
  I: LongInt;
  Terminated: Boolean;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkBeginBlock) then
    begin
      Terminated := False;
      CheckUnreachableInNode(Child, Terminated);
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckCaseLabelsInNode(const ANode: TGreenNode);
var
  I, J, K: LongInt;
  Child, Selector, Label1, Label2: TGreenNode;
  Val1, Val2: Int64;
  SeenValues: array of Int64;
  SeenCount: LongInt;
begin
  if ANode = nil then
    Exit;
  if ANode.NodeKind = gnkCaseStatement then
  begin
    SeenCount := 0;
    SetLength(SeenValues, 0);
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Selector := ANode.ChildAt(I);
      if (Selector = nil) or (Selector.NodeKind <> gnkCaseSelector) then
        Continue;
      for J := 0 to Selector.ChildCount - 1 do
      begin
        Label1 := Selector.ChildAt(J);
        if (Label1 = nil) or (Label1.NodeKind <> gnkCaseLabel) then
          Continue;
        if (Label1.ChildCount > 0) and
          EvaluateIntegerConstant(Label1.ChildAt(0), Val1) then
        begin
          for K := 0 to SeenCount - 1 do
          begin
            if SeenValues[K] = Val1 then
            begin
              FDiagnostics.EmitWarning(
                'sema.duplicate-case-label',
                'sema',
                FRootFileId,
                Label1.ByteOffset,
                'duplicate case label value ' + IntToStr(Val1)
              );
              Break;
            end;
          end;
          Inc(SeenCount);
          SetLength(SeenValues, SeenCount);
          SeenValues[SeenCount - 1] := Val1;
        end;
      end;
    end;
  end
  else
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Child := ANode.ChildAt(I);
      if Child <> nil then
        CheckCaseLabelsInNode(Child);
    end;
  end;
end;

procedure TSemanticAnalyzer.CheckDuplicateCaseLabels;
var
  RootNode, Child: TGreenNode;
  I: LongInt;
begin
  if FRootAst = nil then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  for I := 0 to RootNode.ChildCount - 1 do
  begin
    Child := RootNode.ChildAt(I);
    if Child <> nil then
      CheckCaseLabelsInNode(Child);
  end;
end;

procedure TSemanticAnalyzer.SeedUnitSymbolsAndHir;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
  SymbolId: LongInt;
begin
  FModel.SetRootName(FUnitGraph.RootName);
  FModel.AddTypedHirNode('compilation-root', FUnitGraph.RootName, 0, 0, '');

  for Index := 0 to FUnitGraph.ResolvedUnitCount - 1 do
  begin
    ResolvedUnit := FUnitGraph.ResolvedUnitAt(Index);
    SymbolId := FModel.AddSymbol(
      ResolvedUnit.CanonicalName,
      'unit',
      ResolvedUnit.UnitId,
      0,
      0
    );
    FModel.AddTypedHirNode(
      'resolved-unit',
      ResolvedUnit.CanonicalName,
      SymbolId,
      0,
      ''
    );
  end;
end;

procedure TSemanticAnalyzer.SeedRuntimeContracts;
const
  RuntimeContracts: array[0..1] of string = (
    'np.system.process_init',
    'np.system.process_fini'
  );
var
  Index: LongInt;
begin
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;

  for Index := Low(RuntimeContracts) to High(RuntimeContracts) do
  begin
    FModel.AddRuntimeContract(RuntimeContracts[Index]);
    FModel.AddTypedHirNode('runtime-contract', RuntimeContracts[Index], 0, 0, '');
  end;
end;

procedure TSemanticAnalyzer.SeedForeignProcedureBindings;
var
  ForeignProcedureDecl: TForeignProcedureDecl;
  Index: LongInt;
  RootOwnerUnitId: string;
  SymbolId: LongInt;
begin
  if FRootAst = nil then
    Exit;

  RootOwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  for Index := 0 to FRootAst.ForeignProcedureDeclCount - 1 do
  begin
    ForeignProcedureDecl := FRootAst.ForeignProcedureDeclAt(Index);
    if not ForeignProcedureDecl.HasExplicitSymbolName then
    begin
      EmitSemaError(
        'sema.missing-external-symbol-name',
        'external procedure "' + ForeignProcedureDecl.ProcedureName +
          '" must declare explicit foreign symbol name via name ''<symbol>''',
        ForeignProcedureDecl.ByteOffset
      );
      Exit;
    end;

    SymbolId := FModel.AddSymbol(
      ForeignProcedureDecl.ProcedureName,
      'foreign-procedure',
      RootOwnerUnitId,
      0,
      ForeignProcedureDecl.ByteOffset
    );
    FModel.AddForeignProcedureBinding(
      ForeignProcedureDecl.ProcedureName,
      ForeignProcedureDecl.CallingConvention,
      ForeignProcedureDecl.LibraryId,
      ForeignProcedureDecl.ExternalSymbolName,
      SymbolId
    );
    FModel.AddTypedHirNode(
      'foreign-procedure-binding',
      ForeignProcedureDecl.ProcedureName,
      SymbolId,
      0,
      ''
    );
    FModel.AddLibraryRequest(
      ForeignProcedureDecl.LibraryId,
      'shared',
      'strong'
    );
  end;
end;

procedure TSemanticAnalyzer.Analyze;
var
  DuplicateName: string;
begin
  if (FRootAst = nil) or (FUnitGraph = nil) or not FRootAst.IsValid then
  begin
    FModel.MarkFailure;
    Exit;
  end;

  DuplicateName := DuplicateImportName;
  if DuplicateName <> '' then
  begin
    EmitSemaError(
      'sema.duplicate-declaration',
      'duplicate unit import: "' + DuplicateName + '"',
      0
    );
    Exit;
  end;

  SeedBuiltinTypes;
  FModel.AddScope(skCompilation, FUnitGraph.RootName, 0);
  FCurrentScopeId := FModel.AddScope(skUnit, FUnitGraph.RootName, 1);
  SeedDeclarations;
  AssignScopesToSymbols;
  CheckDuplicateDeclarations;
  CheckUndeclaredIdentifiers;
  CheckTypeMismatches;
  CheckAssignmentTypes;
  SeedUnitSymbolsAndHir;
  SeedForeignProcedureBindings;
  if FDiagnostics.HasErrors then
    Exit;
  SeedRuntimeContracts;
  SeedRuntimeVarDecls;
  SeedHaltCalls;
  if FNoFold then
    SeedFunctionBodies;
  CheckUnusedSymbols;
  CheckUnreachableCode;
  CheckDuplicateCaseLabels;

  if FDiagnostics.HasErrors then
    FModel.MarkFailure
  else
    FModel.MarkReady;
end;

function TSemanticAnalyzer.DetachModel: TSemanticModel;
begin
  Result := FModel;
  FModel := nil;
end;

function TSemanticAnalyzer.Status: string;
begin
  if FModel = nil then
    Exit('deferred');

  Result := FModel.Status;
end;

function TSemanticAnalyzer.ResolveTypeId(const ATypeName: string): LongInt;
begin
  if ATypeName = '' then
    Exit(0);
  if SameText(ATypeName, 'String') then
    Exit(FModel.FindTypeByName('AnsiString'));
  if SameText(ATypeName, 'Cardinal') then
    Exit(FModel.FindTypeByName('LongWord'));
  if SameText(ATypeName, 'Real') then
    Exit(FModel.FindTypeByName('Double'));
  if SameText(ATypeName, 'Extended') then
    Exit(FModel.FindTypeByName('Double'));
  Result := FModel.FindTypeByName(ATypeName);
end;

function TSemanticAnalyzer.FindSymbolByName(const AName: string): LongInt;
begin
  if AName = '' then
    Exit(0);
  Result := FModel.FindSymbolByName(AName);
end;

procedure TSemanticAnalyzer.ProcessVarSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, TypeChild: TGreenNode;
  TypeId: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkVarDecl) then
      Continue;
    TypeId := 0;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) then
      begin
        TypeId := ResolveTypeId(TypeChild.Text);
        Break;
      end;
    end;
    FModel.AddSymbol(Child.Text, 'variable', AOwnerUnitId, TypeId,
      Child.ByteOffset);
  end;
end;

procedure TSemanticAnalyzer.ProcessConstSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, ValueChild: TGreenNode;
  Value: Int64;
  StringValue: string;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkConstDecl) then
      Continue;
    FModel.AddSymbol(Child.Text, 'constant', AOwnerUnitId, 0,
      Child.ByteOffset);
    for J := 0 to Child.ChildCount - 1 do
    begin
      ValueChild := Child.ChildAt(J);
      if EvaluateIntegerConstant(ValueChild, Value) then
      begin
        FModel.AddConstValue(Child.Text, Value);
        Break;
      end;
      if EvaluateStringConstant(ValueChild, StringValue) then
      begin
        FModel.AddStringConstValue(Child.Text, StringValue);
        Break;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.ProcessProcedureDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  Index, J: LongInt;
  Child, ParamChild: TGreenNode;
  CallableScopeId, SavedScopeId: LongInt;
  ParamCount: LongInt;
begin
  if ANode = nil then
    Exit;
  SymbolId := FModel.AddSymbol(ANode.Text, 'procedure', AOwnerUnitId, 0,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('procedure-decl', ANode.Text, SymbolId, 0, '');

  CallableScopeId := FModel.AddScope(skCallable, ANode.Text, FCurrentScopeId);
  SavedScopeId := FCurrentScopeId;
  FCurrentScopeId := CallableScopeId;
  ParamCount := 0;

  for Index := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(Index);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkParameterList then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(J);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
        begin
          FModel.AddSymbol(ParamChild.Text, 'parameter', AOwnerUnitId, 0,
            ParamChild.ByteOffset);
          FModel.SetSymbolScope(FModel.SymbolCount, CallableScopeId);
          Inc(ParamCount);
        end;
      end;
    end
    else if Child.NodeKind = gnkBeginBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode);
      Break;
    end;
  end;

  FModel.SetSymbolParamCount(SymbolId, ParamCount);
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.ProcessFunctionDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  TypeId: LongInt;
  J: LongInt;
  Child, ParamChild: TGreenNode;
  CallableScopeId, SavedScopeId: LongInt;
  ParamCount: LongInt;
begin
  if ANode = nil then
    Exit;
  TypeId := 0;
  for J := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(J);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
    begin
      TypeId := ResolveTypeId(Child.Text);
      Break;
    end;
  end;
  SymbolId := FModel.AddSymbol(ANode.Text, 'function', AOwnerUnitId, TypeId,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('function-decl', ANode.Text, SymbolId, TypeId, '');

  CallableScopeId := FModel.AddScope(skCallable, ANode.Text, FCurrentScopeId);
  SavedScopeId := FCurrentScopeId;
  FCurrentScopeId := CallableScopeId;
  ParamCount := 0;

  for J := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(J);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkParameterList then
    begin
      for TypeId := 0 to Child.ChildCount - 1 do
      begin
        ParamChild := Child.ChildAt(TypeId);
        if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
        begin
          FModel.AddSymbol(ParamChild.Text, 'parameter', AOwnerUnitId, 0,
            ParamChild.ByteOffset);
          FModel.SetSymbolScope(FModel.SymbolCount, CallableScopeId);
          Inc(ParamCount);
        end;
      end;
    end
    else if Child.NodeKind = gnkBeginBlock then
    begin
      RegisterProcedureBody(ANode.Text, Child, ANode);
      Break;
    end;
  end;

  FModel.SetSymbolParamCount(SymbolId, ParamCount);
  FCurrentScopeId := SavedScopeId;
end;

procedure TSemanticAnalyzer.ProcessEnumType(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I: LongInt;
  Child: TGreenNode;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child <> nil) and (Child.NodeKind = gnkIdentifier) then
      FModel.AddSymbol(Child.Text, 'enum-value', AOwnerUnitId, ATypeId,
        Child.ByteOffset);
  end;
end;

procedure TSemanticAnalyzer.ProcessRecordFields(const ANode: TGreenNode;
  const AOwnerUnitId: string; const ATypeId: LongInt);
var
  I: LongInt;
  Child: TGreenNode;
  RecordScopeId: LongInt;
  FieldTypeId: LongInt;
  TypeChild: TGreenNode;
  J: LongInt;
begin
  if ANode = nil then
    Exit;
  RecordScopeId := FModel.AddScope(skRecord, '', FCurrentScopeId);
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkVarDecl) then
      Continue;
    FieldTypeId := 0;
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if (TypeChild <> nil) and (TypeChild.NodeKind = gnkIdentifier) then
      begin
        FieldTypeId := ResolveTypeId(TypeChild.Text);
        Break;
      end;
    end;
    FModel.AddSymbol(Child.Text, 'field', AOwnerUnitId, FieldTypeId,
      Child.ByteOffset);
    FModel.SetSymbolScope(FModel.SymbolCount, RecordScopeId);
  end;
end;

procedure TSemanticAnalyzer.ProcessTypeSection(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I, J: LongInt;
  Child, TypeChild: TGreenNode;
  TypeId: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if (Child = nil) or (Child.NodeKind <> gnkTypeDecl) then
      Continue;
    if Child.Text = '' then
      Continue;
    TypeId := FModel.AddType(Child.Text, 'declared');
    FModel.AddSymbol(Child.Text, 'type', AOwnerUnitId, TypeId,
      Child.ByteOffset);
    for J := 0 to Child.ChildCount - 1 do
    begin
      TypeChild := Child.ChildAt(J);
      if TypeChild = nil then
        Continue;
      if TypeChild.NodeKind = gnkEnumType then
        ProcessEnumType(TypeChild, AOwnerUnitId, TypeId)
      else if TypeChild.NodeKind = gnkRecordType then
        ProcessRecordFields(TypeChild, AOwnerUnitId, TypeId)
      else if TypeChild.NodeKind = gnkClassType then
      begin
        if TypeChild.ChildCount > 0 then
        begin
          if TypeChild.ChildAt(0).NodeKind = gnkIdentifier then
            FModel.SetTypeParent(TypeId,
              FModel.FindTypeByName(TypeChild.ChildAt(0).Text));
        end;
      end;
    end;
  end;
end;

procedure TSemanticAnalyzer.WalkDeclarations(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  I: LongInt;
  Child: TGreenNode;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    case Child.NodeKind of
      gnkVarSection:
        ProcessVarSection(Child, AOwnerUnitId);
      gnkConstSection:
        ProcessConstSection(Child, AOwnerUnitId);
      gnkTypeSection:
        ProcessTypeSection(Child, AOwnerUnitId);
      gnkProcedureDecl:
        ProcessProcedureDecl(Child, AOwnerUnitId);
      gnkFunctionDecl:
        ProcessFunctionDecl(Child, AOwnerUnitId);
      gnkInterfaceSection, gnkImplementationSection:
        WalkDeclarations(Child, AOwnerUnitId);
    end;
  end;
end;

procedure TSemanticAnalyzer.SeedDeclarations;
var
  OwnerUnitId: string;
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  OwnerUnitId := NormalizeUnitIdentity(FUnitGraph.RootName);
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkDeclarations(RootNode, OwnerUnitId);
end;

procedure TSemanticAnalyzer.WalkAssignmentStatements(const ANode: TGreenNode);
var
  I: LongInt;
  Child, RhsNode, BranchNode: TGreenNode;
  LhsSymbolId, RhsSymbolId: LongInt;
  LhsTypeId, RhsTypeId: LongInt;
  Value, CondValue: Int64;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkIfStatement then
    begin
      if (Child.ChildCount >= 2) and
        EvaluateIntegerConstant(Child.ChildAt(0), CondValue) then
      begin
        if CondValue <> 0 then
          BranchNode := Child.ChildAt(1)
        else if Child.ChildCount >= 3 then
          BranchNode := Child.ChildAt(2)
        else
          BranchNode := nil;
        if BranchNode <> nil then
          WalkAssignmentStatements(BranchNode);
      end
      else
        WalkAssignmentStatements(Child);
      Continue;
    end;
    if Child.NodeKind = gnkForStatement then
    begin
      UnrollAssignmentForLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkWhileStatement then
    begin
      UnrollAssignmentWhileLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkRepeatStatement then
    begin
      UnrollAssignmentRepeatLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkAssignmentStatement then
    begin
      LhsSymbolId := FindSymbolByName(Child.Text);
      if LhsSymbolId = 0 then
        Continue;
      LhsTypeId := FModel.SymbolTypeId(LhsSymbolId);
      RhsNode := nil;
      if Child.ChildCount >= 2 then
        RhsNode := Child.ChildAt(1)
      else if (Child.ChildCount = 1) and
        (Child.ChildAt(0).NodeKind <> gnkIdentifier) and
        (Child.ChildAt(0).NodeKind <> gnkDotAccess) and
        (Child.ChildAt(0).NodeKind <> gnkArrayAccess) then
        RhsNode := Child.ChildAt(0);
      if RhsNode <> nil then
      begin
        if EvaluateIntegerConstant(RhsNode, Value) then
          FModel.AddVarInitValue(Child.Text, Value)
        else
          FModel.RemoveVarInitValue(Child.Text);
      end;
    end
    else
      WalkAssignmentStatements(Child);
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentForLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  LoopVar: string;
  StartValue, EndValue, IterValue: Int64;
  Direction: string;
  BodyNode: TGreenNode;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  if not EvaluateIntegerConstant(ANode.ChildAt(1), StartValue) then
    Exit;
  if not EvaluateIntegerConstant(ANode.ChildAt(2), EndValue) then
    Exit;
  Direction := ANode.Text;
  BodyNode := ANode.ChildAt(3);
  IterCount := 0;
  IterValue := StartValue;
  if SameText(Direction, 'to') then
  begin
    while (IterValue <= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkAssignmentStatements(BodyNode);
      Inc(IterValue);
      Inc(IterCount);
    end;
  end
  else if SameText(Direction, 'downto') then
  begin
    while (IterValue >= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkAssignmentStatements(BodyNode);
      Dec(IterValue);
      Inc(IterCount);
    end;
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentWhileLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  CondNode, BodyNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue = 0 then
      Exit;
    WalkAssignmentStatements(BodyNode);
    Inc(IterCount);
  end;
end;

procedure TSemanticAnalyzer.UnrollAssignmentRepeatLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  BodyNode, CondNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    WalkAssignmentStatements(BodyNode);
    Inc(IterCount);
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue <> 0 then
      Exit;
  end;
end;

procedure TSemanticAnalyzer.CheckAssignmentTypes;
var
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkAssignmentStatements(RootNode);
end;

function TSemanticAnalyzer.EvaluateIntegerConstant(const ANode: TGreenNode;
  out AValue: Int64): Boolean;
var
  Parsed: Int64;
  ParseCode: Word;
  Left, Right: Int64;
  Op: string;
  BodyNode, DeclNode: TGreenNode;
  ParamSnaps: TParamSnapshots;
begin
  AValue := 0;
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkIntegerLiteral:
      begin
        Val(ANode.Text, Parsed, ParseCode);
        if ParseCode <> 0 then
          Exit(False);
        AValue := Parsed;
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if SameText(ANode.Text, 'true') then
        begin
          AValue := 1;
          Exit(True);
        end;
        if SameText(ANode.Text, 'false') then
        begin
          AValue := 0;
          Exit(True);
        end;
        if FModel.LookupConstValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if FModel.LookupVarInitValue(ANode.Text, Parsed) then
        begin
          AValue := Parsed;
          Exit(True);
        end;
        if LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
          (BodyNode <> nil) and
          not IsCurrentlyInlining(ANode.Text) then
        begin
          PushInlining(ANode.Text);
          ParamSnaps := nil;
          try
            WalkAssignmentStatements(BodyNode);
          finally
            PopInlining;
            RestoreCallArgs(ParamSnaps);
          end;
          if FModel.LookupVarInitValue(ANode.Text, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end;
        end;
        Exit(False);
      end;
    gnkFunctionCall:
      begin
        if LookupProcedureBody(ANode.Text, BodyNode, DeclNode) and
          (BodyNode <> nil) and
          not IsCurrentlyInlining(ANode.Text) then
        begin
          PushInlining(ANode.Text);
          ParamSnaps := BindCallArgs(DeclNode, ANode, 1);
          try
            WalkAssignmentStatements(BodyNode);
          finally
            PopInlining;
            RestoreCallArgs(ParamSnaps);
          end;
          if FModel.LookupVarInitValue(ANode.Text, Parsed) then
          begin
            AValue := Parsed;
            Exit(True);
          end;
        end;
        Exit(False);
      end;
    gnkUnaryExpression:
      begin
        if ANode.ChildCount < 1 then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(0), Parsed) then
          Exit(False);
        Op := ANode.Text;
        if Op = '-' then
          AValue := -Parsed
        else if Op = '+' then
          AValue := Parsed
        else if SameText(Op, 'not') then
          AValue := Ord(Parsed = 0)
        else
          Exit(False);
        Exit(True);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateIntegerConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        Op := ANode.Text;
        if Op = '+' then
          AValue := Left + Right
        else if Op = '-' then
          AValue := Left - Right
        else if Op = '*' then
          AValue := Left * Right
        else if SameText(Op, 'div') then
        begin
          if Right = 0 then
          begin
            EmitSemaError(
              'sema.division-by-zero',
              'division by zero in constant expression',
              ANode.ByteOffset
            );
            Exit(False);
          end;
          AValue := Left div Right;
        end
        else if SameText(Op, 'mod') then
        begin
          if Right = 0 then
          begin
            EmitSemaError(
              'sema.division-by-zero',
              'division by zero in constant expression',
              ANode.ByteOffset
            );
            Exit(False);
          end;
          AValue := Left mod Right;
        end
        else if Op = '=' then
          AValue := Ord(Left = Right)
        else if Op = '<>' then
          AValue := Ord(Left <> Right)
        else if Op = '<' then
          AValue := Ord(Left < Right)
        else if Op = '>' then
          AValue := Ord(Left > Right)
        else if Op = '<=' then
          AValue := Ord(Left <= Right)
        else if Op = '>=' then
          AValue := Ord(Left >= Right)
        else if SameText(Op, 'and') then
          AValue := Ord((Left <> 0) and (Right <> 0))
        else if SameText(Op, 'or') then
          AValue := Ord((Left <> 0) or (Right <> 0))
        else
          Exit(False);
        Exit(True);
      end;
  end;
  Result := False;
end;

function DecodePascalStringLiteral(const AText: string): string; forward;

function TSemanticAnalyzer.EvaluateStringConstant(const ANode: TGreenNode;
  out AValue: string): Boolean;
var
  Op, Left, Right: string;
begin
  AValue := '';
  if ANode = nil then
    Exit(False);
  case ANode.NodeKind of
    gnkStringLiteral:
      begin
        AValue := DecodePascalStringLiteral(ANode.Text);
        Exit(True);
      end;
    gnkIdentifier:
      begin
        if FModel.LookupStringConstValue(ANode.Text, Left) then
        begin
          AValue := Left;
          Exit(True);
        end;
        Exit(False);
      end;
    gnkBinaryExpression:
      begin
        if ANode.ChildCount < 2 then
          Exit(False);
        Op := ANode.Text;
        if Op <> '+' then
          Exit(False);
        if not EvaluateStringConstant(ANode.ChildAt(0), Left) then
          Exit(False);
        if not EvaluateStringConstant(ANode.ChildAt(1), Right) then
          Exit(False);
        AValue := Left + Right;
        Exit(True);
      end;
  end;
  Result := False;
end;

function DecodePascalStringLiteral(const AText: string): string;
var
  Raw: string;
  Index: SizeInt;
begin
  Result := '';
  if Length(AText) < 2 then
    Exit;
  if (AText[1] <> '''') or (AText[Length(AText)] <> '''') then
    Exit;
  Raw := Copy(AText, 2, Length(AText) - 2);
  Index := 1;
  while Index <= Length(Raw) do
  begin
    if (Raw[Index] = '''') and (Index < Length(Raw)) and (Raw[Index + 1] = '''') then
    begin
      Result := Result + '''';
      Inc(Index, 2);
    end
    else
    begin
      Result := Result + Raw[Index];
      Inc(Index);
    end;
  end;
end;

function TSemanticAnalyzer.EncodeRuntimeIntExprFold(
  const ANode: TGreenNode; out ABlob: string): Boolean;

  function NeedsFoldFallback(const N: TGreenNode): Boolean;
  var
    I: LongInt;
    Child: TGreenNode;
  begin
    if N = nil then
      Exit(False);
    if (N.NodeKind = gnkIdentifier) and (N.Text <> '') and
      not IsRuntimeVar(N.Text) then
      Exit(True);
    if N.NodeKind = gnkFunctionCall then
      Exit(True);
    for I := 0 to N.ChildCount - 1 do
    begin
      Child := N.ChildAt(I);
      if (Child <> nil) and NeedsFoldFallback(Child) then
        Exit(True);
    end;
    Result := False;
  end;

var
  Folded: Int64;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if NeedsFoldFallback(ANode) then
    if EvaluateIntegerConstant(ANode, Folded) then
    begin
      ABlob := 'int ' + IntToStr(Folded) + #10;
      Exit(True);
    end;
  Result := EncodeRuntimeIntExpr(ANode, ABlob);
end;

function TSemanticAnalyzer.EncodeRuntimeBoolExprFold(
  const ANode: TGreenNode; out ABlob: string): Boolean;
var
  LeftBlob, RightBlob, Op, Pred: string;
begin
  ABlob := '';
  if ANode = nil then
    Exit(False);
  if ANode.NodeKind <> gnkBinaryExpression then
    Exit(False);
  if ANode.ChildCount < 2 then
    Exit(False);
  Op := ANode.Text;
  if Op = '=' then Pred := 'eq'
  else if Op = '<>' then Pred := 'ne'
  else if Op = '<' then Pred := 'slt'
  else if Op = '<=' then Pred := 'sle'
  else if Op = '>' then Pred := 'sgt'
  else if Op = '>=' then Pred := 'sge'
  else
    Exit(False);
  if not EncodeRuntimeIntExprFold(ANode.ChildAt(0), LeftBlob) then
    Exit(False);
  if not EncodeRuntimeIntExprFold(ANode.ChildAt(1), RightBlob) then
    Exit(False);
  ABlob := LeftBlob + RightBlob + 'cmp ' + Pred + #10;
  Result := True;
end;

procedure TSemanticAnalyzer.WalkHaltCalls(const ANode: TGreenNode);
var
  I, ArgIndex: LongInt;
  Child, Arg, RhsNode, BranchNode, DeclNode: TGreenNode;
  Operand: string;
  Value, CondValue: Int64;
  Decoded, StringValue: string;
  ParamSnaps: TParamSnapshots;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkIfStatement then
    begin
      if (not FNoFold) and
        (Child.ChildCount >= 2) and
        EvaluateIntegerConstant(Child.ChildAt(0), CondValue) then
      begin
        if CondValue <> 0 then
          BranchNode := Child.ChildAt(1)
        else if Child.ChildCount >= 3 then
          BranchNode := Child.ChildAt(2)
        else
          BranchNode := nil;
        if BranchNode <> nil then
          WalkHaltCalls(BranchNode);
        Continue;
      end;
      if FNoFold and (Child.ChildCount >= 2) and
        EncodeRuntimeBoolExprFold(Child.ChildAt(0), Operand) then
      begin
        LowerRuntimeIfStatement(Child, Operand);
        Continue;
      end;
      WalkHaltCalls(Child);
      Continue;
    end;
    if Child.NodeKind = gnkForStatement then
    begin
      if FNoFold then
        LowerRuntimeForStatement(Child)
      else
        UnrollHaltForLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkWhileStatement then
    begin
      if FNoFold then
        LowerRuntimeWhileStatement(Child)
      else
        UnrollHaltWhileLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkRepeatStatement then
    begin
      if FNoFold then
        LowerRuntimeRepeatStatement(Child)
      else
        UnrollHaltRepeatLoop(Child);
      Continue;
    end;
    if Child.NodeKind = gnkAssignmentStatement then
    begin
      Arg := nil;
      if Child.ChildCount >= 2 then
        Arg := Child.ChildAt(1)
      else if (Child.ChildCount = 1) and
        (Child.ChildAt(0).NodeKind <> gnkIdentifier) and
        (Child.ChildAt(0).NodeKind <> gnkDotAccess) and
        (Child.ChildAt(0).NodeKind <> gnkArrayAccess) then
        Arg := Child.ChildAt(0);
      if Arg <> nil then
      begin
        if FNoFold then
        begin
          if EncodeRuntimeIntExprFold(Arg, Operand) then
            FModel.AddTypedHirNode(
              'assign-runtime', Child.Text, 0, 0,
              Child.Text + #9 + Operand
            );
        end
        else if EvaluateIntegerConstant(Arg, Value) then
          FModel.AddVarInitValue(Child.Text, Value)
        else
          FModel.RemoveVarInitValue(Child.Text);
      end;
      Continue;
    end;
    if Child.NodeKind = gnkProcedureCallStatement then
    begin
      if SameText(Child.Text, 'Halt') then
      begin
        Operand := '0';
        Arg := nil;
        if Child.ChildCount >= 1 then
        begin
          Arg := Child.ChildAt(0);
          if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) and
            (Arg.ChildCount >= 2) then
            Arg := Arg.ChildAt(1);
        end;
        if FNoFold and (Arg <> nil) then
        begin
          if EncodeRuntimeIntExprFold(Arg, Operand) then
          begin
            FModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0, Operand);
            FCurrentBlockTerminated := True;
            Continue;
          end;
        end;
        if Arg <> nil then
        begin
          if EvaluateIntegerConstant(Arg, Value) then
            Operand := IntToStr(Value);
        end;
        FModel.AddTypedHirNode('halt-call', 'Halt', 0, 0, Operand);
        FCurrentBlockTerminated := True;
        Continue;
      end;
      if SameText(Child.Text, 'WriteLn') or SameText(Child.Text, 'Write') then
      begin
        Arg := nil;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          Arg := Child.ChildAt(0)
        else
          Arg := Child;
        if FNoFold then
        begin
          if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) then
            ArgIndex := 1
          else
            ArgIndex := 0;
          while ArgIndex < Arg.ChildCount do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if RhsNode = nil then
            begin
              Inc(ArgIndex);
              Continue;
            end;
            if RhsNode.NodeKind = gnkStringLiteral then
              FModel.AddTypedHirNode(
                'write-string-runtime', 'Write', 0, 0,
                DecodePascalStringLiteral(RhsNode.Text)
              )
            else if EvaluateStringConstant(RhsNode, StringValue) then
              FModel.AddTypedHirNode(
                'write-string-runtime', 'Write', 0, 0, StringValue
              )
            else if EncodeRuntimeIntExprFold(RhsNode, Operand) then
              FModel.AddTypedHirNode(
                'write-int-runtime', 'Write', 0, 0, Operand
              );
            Inc(ArgIndex);
          end;
          if SameText(Child.Text, 'WriteLn') then
            FModel.AddTypedHirNode(
              'write-string-runtime', 'Write', 0, 0, #10
            );
          Continue;
        end;
        Decoded := '';
        if (Arg <> nil) and (Arg.NodeKind = gnkFunctionCall) then
          ArgIndex := 1
        else
          ArgIndex := 0;
        while ArgIndex < Arg.ChildCount do
        begin
          RhsNode := Arg.ChildAt(ArgIndex);
          if RhsNode = nil then
          begin
            Inc(ArgIndex);
            Continue;
          end;
          if RhsNode.NodeKind = gnkStringLiteral then
            Decoded := Decoded + DecodePascalStringLiteral(RhsNode.Text)
          else if EvaluateStringConstant(RhsNode, StringValue) then
            Decoded := Decoded + StringValue
          else if EvaluateIntegerConstant(RhsNode, Value) then
            Decoded := Decoded + IntToStr(Value);
          Inc(ArgIndex);
        end;
        if SameText(Child.Text, 'WriteLn') then
          Decoded := Decoded + #10;
        FModel.AddTypedHirNode('write-call', Child.Text, 0, 0, Decoded);
        Continue;
      end;
      if LookupProcedureBody(Child.Text, BranchNode, DeclNode) and
        (BranchNode <> nil) and
        not IsCurrentlyInlining(Child.Text) then
      begin
        PushInlining(Child.Text);
        ParamSnaps := BindCallArgs(DeclNode, Child, 0);
        try
          WalkHaltCalls(BranchNode);
        finally
          PopInlining;
          RestoreCallArgs(ParamSnaps);
        end;
        Continue;
      end;
      if FNoFold and LookupProcedureBody(Child.Text, BranchNode, DeclNode) then
      begin
        Operand := Child.Text;
        Arg := nil;
        if (Child.ChildCount >= 1) and
          (Child.ChildAt(0) <> nil) and
          (Child.ChildAt(0).NodeKind = gnkFunctionCall) then
          Arg := Child.ChildAt(0)
        else
          Arg := Child;
        if Arg <> nil then
        begin
          if Arg.NodeKind = gnkFunctionCall then
            ArgIndex := 1
          else
            ArgIndex := 0;
          while ArgIndex < Arg.ChildCount do
          begin
            RhsNode := Arg.ChildAt(ArgIndex);
            if (RhsNode <> nil) and EncodeRuntimeIntExprFold(RhsNode, Decoded) then
              Operand := Operand + #9 + Decoded;
            Inc(ArgIndex);
          end;
        end;
        FModel.AddTypedHirNode('call-runtime', Child.Text, 0, 0, Operand);
        Continue;
      end;
    end;
    WalkHaltCalls(Child);
  end;
end;

procedure TSemanticAnalyzer.LowerRuntimeIfStatement(
  const AIfNode: TGreenNode; const ACondBlob: string);
var
  ThenLabel, ElseLabel, EndLabel: string;
  HasElse: Boolean;
begin
  HasElse := AIfNode.ChildCount >= 3;
  ThenLabel := NewBlockLabel('then');
  if HasElse then
    ElseLabel := NewBlockLabel('else')
  else
    ElseLabel := '';
  EndLabel := NewBlockLabel('endif');
  if not HasElse then
    ElseLabel := EndLabel;
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'if', 0, 0,
    ACondBlob + 'labels ' + ThenLabel + #9 + ElseLabel + #10
  );
  FCurrentBlockTerminated := True;
  EmitBlockLabel(ThenLabel);
  WalkHaltCalls(AIfNode.ChildAt(1));
  EmitGotoLabel(EndLabel);
  if HasElse then
  begin
    EmitBlockLabel(ElseLabel);
    WalkHaltCalls(AIfNode.ChildAt(2));
    EmitGotoLabel(EndLabel);
  end;
  EmitBlockLabel(EndLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeWhileStatement(const ANode: TGreenNode);
var
  CondNode, BodyNode: TGreenNode;
  CondBlob, CondLabel, BodyLabel, ExitLabel: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  if not EncodeRuntimeBoolExprFold(CondNode, CondBlob) then
    Exit;
  CondLabel := NewBlockLabel('while-cond');
  BodyLabel := NewBlockLabel('while-body');
  ExitLabel := NewBlockLabel('while-end');
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'while', 0, 0,
    CondBlob + 'labels ' + BodyLabel + #9 + ExitLabel + #10
  );
  FCurrentBlockTerminated := True;
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(ExitLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeRepeatStatement(const ANode: TGreenNode);
var
  CondNode, BodyNode: TGreenNode;
  CondBlob, BodyLabel, CondLabel, ExitLabel: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  if not EncodeRuntimeBoolExprFold(CondNode, CondBlob) then
    Exit;
  BodyLabel := NewBlockLabel('repeat-body');
  CondLabel := NewBlockLabel('repeat-cond');
  ExitLabel := NewBlockLabel('repeat-end');
  EmitGotoLabel(BodyLabel);
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'until', 0, 0,
    CondBlob + 'labels ' + ExitLabel + #9 + BodyLabel + #10
  );
  FCurrentBlockTerminated := True;
  EmitBlockLabel(ExitLabel);
end;

procedure TSemanticAnalyzer.LowerRuntimeForStatement(const ANode: TGreenNode);
var
  LoopVar, Direction: string;
  StartNode, EndNode, BodyNode: TGreenNode;
  StartBlob, EndBlob, CondBlob: string;
  CondLabel, BodyLabel, StepLabel, ExitLabel: string;
  Pred, Op: string;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  RegisterRuntimeVar(LoopVar);
  StartNode := ANode.ChildAt(1);
  EndNode := ANode.ChildAt(2);
  BodyNode := ANode.ChildAt(3);
  Direction := ANode.Text;
  if not EncodeRuntimeIntExprFold(StartNode, StartBlob) then
    Exit;
  if not EncodeRuntimeIntExprFold(EndNode, EndBlob) then
    Exit;
  if SameText(Direction, 'to') then
  begin
    Pred := 'sle';
    Op := 'add';
  end
  else if SameText(Direction, 'downto') then
  begin
    Pred := 'sge';
    Op := 'sub';
  end
  else
    Exit;
  FModel.AddTypedHirNode(
    'assign-runtime', LoopVar, 0, 0,
    LoopVar + #9 + StartBlob
  );
  CondLabel := NewBlockLabel('for-cond');
  BodyLabel := NewBlockLabel('for-body');
  StepLabel := NewBlockLabel('for-step');
  ExitLabel := NewBlockLabel('for-end');
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(CondLabel);
  CondBlob := 'var ' + LoopVar + #10 + EndBlob + 'cmp ' + Pred + #10;
  FModel.AddTypedHirNode(
    'cond-br-runtime', 'for', 0, 0,
    CondBlob + 'labels ' + BodyLabel + #9 + ExitLabel + #10
  );
  FCurrentBlockTerminated := True;
  EmitBlockLabel(BodyLabel);
  WalkHaltCalls(BodyNode);
  EmitGotoLabel(StepLabel);
  EmitBlockLabel(StepLabel);
  FModel.AddTypedHirNode(
    'assign-runtime', LoopVar, 0, 0,
    LoopVar + #9 + 'var ' + LoopVar + #10 + 'int 1' + #10 + Op + #10
  );
  EmitGotoLabel(CondLabel);
  EmitBlockLabel(ExitLabel);
end;

procedure TSemanticAnalyzer.UnrollHaltForLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  LoopVar: string;
  StartValue, EndValue, IterValue: Int64;
  Direction: string;
  BodyNode: TGreenNode;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 4) then
    Exit;
  if ANode.ChildAt(0).NodeKind <> gnkIdentifier then
    Exit;
  LoopVar := ANode.ChildAt(0).Text;
  if not EvaluateIntegerConstant(ANode.ChildAt(1), StartValue) then
    Exit;
  if not EvaluateIntegerConstant(ANode.ChildAt(2), EndValue) then
    Exit;
  Direction := ANode.Text;
  BodyNode := ANode.ChildAt(3);
  IterCount := 0;
  IterValue := StartValue;
  if SameText(Direction, 'to') then
  begin
    while (IterValue <= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkHaltCalls(BodyNode);
      Inc(IterValue);
      Inc(IterCount);
    end;
  end
  else if SameText(Direction, 'downto') then
  begin
    while (IterValue >= EndValue) and (IterCount < MaxIterations) do
    begin
      FModel.AddVarInitValue(LoopVar, IterValue);
      WalkHaltCalls(BodyNode);
      Dec(IterValue);
      Inc(IterCount);
    end;
  end;
end;

procedure TSemanticAnalyzer.UnrollHaltWhileLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  CondNode, BodyNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  CondNode := ANode.ChildAt(0);
  BodyNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue = 0 then
      Exit;
    WalkHaltCalls(BodyNode);
    Inc(IterCount);
  end;
end;

procedure TSemanticAnalyzer.UnrollHaltRepeatLoop(const ANode: TGreenNode);
const
  MaxIterations = 1024;
var
  BodyNode, CondNode: TGreenNode;
  CondValue: Int64;
  IterCount: LongInt;
begin
  if (ANode = nil) or (ANode.ChildCount < 2) then
    Exit;
  BodyNode := ANode.ChildAt(0);
  CondNode := ANode.ChildAt(1);
  IterCount := 0;
  while IterCount < MaxIterations do
  begin
    WalkHaltCalls(BodyNode);
    Inc(IterCount);
    if not EvaluateIntegerConstant(CondNode, CondValue) then
      Exit;
    if CondValue <> 0 then
      Exit;
  end;
end;

procedure TSemanticAnalyzer.WalkRuntimeVarDecls(const ANode: TGreenNode);
var
  I, J: LongInt;
  Child, Decl: TGreenNode;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if (Child.NodeKind = gnkProcedureDecl) or
      (Child.NodeKind = gnkFunctionDecl) then
      Continue;
    if Child.NodeKind = gnkVarSection then
    begin
      for J := 0 to Child.ChildCount - 1 do
      begin
        Decl := Child.ChildAt(J);
        if (Decl <> nil) and
          (Decl.NodeKind = gnkVarDecl) and
          (Decl.Text <> '') then
        begin
          RegisterRuntimeVar(Decl.Text);
          FModel.AddTypedHirNode(
            'var-decl-runtime', Decl.Text, 0, 0, Decl.Text
          );
        end;
      end;
      Continue;
    end;
    WalkRuntimeVarDecls(Child);
  end;
end;

procedure TSemanticAnalyzer.SeedRuntimeVarDecls;
var
  RootNode: TGreenNode;
begin
  if not FNoFold then
    Exit;
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkRuntimeVarDecls(RootNode);
end;

procedure TSemanticAnalyzer.SeedHaltCalls;
var
  RootNode: TGreenNode;
begin
  if (FRootAst = nil) or not FRootAst.IsValid then
    Exit;
  if (FRootAst.RootKindName <> 'program') and
    (FRootAst.RootKindName <> 'library') and
    (FRootAst.RootKindName <> 'package') then
    Exit;
  RootNode := FRootAst.RootNode;
  if RootNode = nil then
    Exit;
  WalkHaltCalls(RootNode);
  if FNoFold and not FCurrentBlockTerminated then
  begin
    FModel.AddTypedHirNode('halt-call-runtime', 'Halt', 0, 0, 'int 0' + #10);
    FCurrentBlockTerminated := True;
  end;
end;

procedure TSemanticAnalyzer.SeedFunctionBodies;
var
  I, J, K: LongInt;
  Entry: TProcedureBodyEntry;
  ParamCount: LongInt;
  Child, ParamChild: TGreenNode;
  SavedTerminated: Boolean;
begin
  for I := 0 to Length(FProcedureBodies) - 1 do
  begin
    Entry := FProcedureBodies[I];
    if Entry.Body = nil then
      Continue;
    ParamCount := 0;
    if Entry.Decl <> nil then
    begin
      for J := 0 to Entry.Decl.ChildCount - 1 do
      begin
        Child := Entry.Decl.ChildAt(J);
        if (Child <> nil) and (Child.NodeKind = gnkParameterList) then
        begin
          for K := 0 to Child.ChildCount - 1 do
          begin
            ParamChild := Child.ChildAt(K);
            if (ParamChild <> nil) and (ParamChild.NodeKind = gnkParameterDecl) then
            begin
              RegisterRuntimeVar(ParamChild.Text);
              Inc(ParamCount);
            end;
          end;
          Break;
        end;
      end;
    end;
    FModel.AddTypedHirNode('function-body-begin', Entry.Name, 0, 0,
      IntToStr(ParamCount));
    RegisterRuntimeVar(Entry.Name);
    SavedTerminated := FCurrentBlockTerminated;
    FCurrentBlockTerminated := False;
    WalkHaltCalls(Entry.Body);
    if not FCurrentBlockTerminated then
      FModel.AddTypedHirNode('ret-runtime', Entry.Name, 0, 0,
        'var ' + Entry.Name + #10);
    FModel.AddTypedHirNode('function-body-end', Entry.Name, 0, 0, '');
    FCurrentBlockTerminated := SavedTerminated;
  end;
end;

end.
