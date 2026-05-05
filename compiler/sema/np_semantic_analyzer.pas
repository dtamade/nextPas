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
  TSemanticAnalyzer = class
  private
    FRootAst: TAstFacade;
    FUnitGraph: TUnitGraph;
    FDiagnostics: TDiagnosticsSink;
    FRootFileId: TSourceFileId;
    FModel: TSemanticModel;
    function DuplicateImportName: string;
    procedure EmitSemaError(
      const ACode: string;
      const AMessage: string;
      const AByteOffset: LongInt
    );
    procedure SeedBuiltinTypes;
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
    procedure WalkDeclarations(const ANode: TGreenNode;
      const AOwnerUnitId: string);
    procedure WalkAssignmentStatements(const ANode: TGreenNode);
  public
    constructor Create(
      const ARootAst: TAstFacade;
      const AUnitGraph: TUnitGraph;
      const ADiagnostics: TDiagnosticsSink;
      const ARootFileId: TSourceFileId
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
  const ARootFileId: TSourceFileId
);
begin
  inherited Create;
  FRootAst := ARootAst;
  FUnitGraph := AUnitGraph;
  FDiagnostics := ADiagnostics;
  FRootFileId := ARootFileId;
  FModel := TSemanticModel.Create;
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

procedure TSemanticAnalyzer.EmitSemaError(
  const ACode: string;
  const AMessage: string;
  const AByteOffset: LongInt
);
begin
  FDiagnostics.EmitError(ACode, 'sema', FRootFileId, AByteOffset, AMessage);
  FModel.MarkFailure;
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
end;

procedure TSemanticAnalyzer.SeedUnitSymbolsAndHir;
var
  Index: LongInt;
  ResolvedUnit: TResolvedUnit;
  SymbolId: LongInt;
begin
  FModel.SetRootName(FUnitGraph.RootName);
  FModel.AddTypedHirNode('compilation-root', FUnitGraph.RootName, 0, 0);

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
      0
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
    FModel.AddTypedHirNode('runtime-contract', RuntimeContracts[Index], 0, 0);
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
      0
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
  SeedDeclarations;
  CheckAssignmentTypes;
  SeedUnitSymbolsAndHir;
  SeedForeignProcedureBindings;
  if FDiagnostics.HasErrors then
    Exit;
  SeedRuntimeContracts;

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
  I: LongInt;
  Child: TGreenNode;
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
  end;
end;

procedure TSemanticAnalyzer.ProcessProcedureDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
begin
  if ANode = nil then
    Exit;
  SymbolId := FModel.AddSymbol(ANode.Text, 'procedure', AOwnerUnitId, 0,
    ANode.ByteOffset);
  FModel.AddTypedHirNode('procedure-decl', ANode.Text, SymbolId, 0);
end;

procedure TSemanticAnalyzer.ProcessFunctionDecl(const ANode: TGreenNode;
  const AOwnerUnitId: string);
var
  SymbolId: LongInt;
  TypeId: LongInt;
  J: LongInt;
  Child: TGreenNode;
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
  FModel.AddTypedHirNode('function-decl', ANode.Text, SymbolId, TypeId);
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
  Child: TGreenNode;
  LhsSymbolId, RhsSymbolId: LongInt;
  LhsTypeId, RhsTypeId: LongInt;
begin
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child = nil then
      Continue;
    if Child.NodeKind = gnkAssignmentStatement then
    begin
      LhsSymbolId := FindSymbolByName(Child.Text);
      if LhsSymbolId = 0 then
        Continue;
      LhsTypeId := FModel.SymbolTypeId(LhsSymbolId);
      if LhsTypeId = 0 then
        Continue;
      if (Child.ChildCount >= 1) and
        (Child.ChildAt(0).NodeKind = gnkIdentifier) then
      begin
        RhsSymbolId := FindSymbolByName(Child.ChildAt(0).Text);
        if RhsSymbolId > 0 then
        begin
          RhsTypeId := FModel.SymbolTypeId(RhsSymbolId);
          if (RhsTypeId > 0) and (LhsTypeId <> RhsTypeId) then
            EmitSemaError(
              'sema.type-mismatch',
              'type mismatch: cannot assign "' +
                Child.ChildAt(0).Text + '" to "' +
                Child.Text + '"',
              Child.ByteOffset
            );
        end;
      end;
    end
    else
      WalkAssignmentStatements(Child);
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

end.
