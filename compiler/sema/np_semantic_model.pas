unit np_semantic_model;

{$mode objfpc}{$H+}

interface

type
  TSemanticSymbol = record
    SymbolId: LongInt;
    Name: string;
    Kind: string;
    OwnerUnitId: string;
    TypeId: LongInt;
    ByteOffset: LongInt;
  end;

  TSemanticType = record
    TypeId: LongInt;
    Name: string;
    Kind: string;
  end;

  TTypedHirNode = record
    HirNodeId: LongInt;
    Kind: string;
    DisplayName: string;
    SymbolId: LongInt;
    TypeId: LongInt;
    Operand: string;
  end;

  TRuntimeContract = record
    ContractId: LongInt;
    Name: string;
  end;

  TSemanticForeignProcedureBinding = record
    BindingId: LongInt;
    PascalName: string;
    CallingConvention: string;
    LibraryId: string;
    ExternalSymbolName: string;
    SymbolId: LongInt;
  end;

  TSemanticLibraryRequest = record
    RequestId: LongInt;
    LogicalId: string;
    LinkageKind: string;
    Strength: string;
  end;

  TSemanticConstValue = record
    Name: string;
    Value: Int64;
  end;

  TSemanticModel = class
  private
    FSymbols: array of TSemanticSymbol;
    FTypes: array of TSemanticType;
    FTypedHirNodes: array of TTypedHirNode;
    FRuntimeContracts: array of TRuntimeContract;
    FForeignProcedureBindings: array of TSemanticForeignProcedureBinding;
    FLibraryRequests: array of TSemanticLibraryRequest;
    FConstValues: array of TSemanticConstValue;
    FRootName: string;
    FStatus: string;
  public
    constructor Create;
    function AddSymbol(
      const AName: string;
      const AKind: string;
      const AOwnerUnitId: string;
      const ATypeId: LongInt;
      const AByteOffset: LongInt
    ): LongInt;
    function AddType(const AName: string; const AKind: string): LongInt;
    function AddTypedHirNode(
      const AKind: string;
      const ADisplayName: string;
      const ASymbolId: LongInt;
      const ATypeId: LongInt;
      const AOperand: string
    ): LongInt;
    function AddRuntimeContract(const AName: string): LongInt;
    function AddForeignProcedureBinding(
      const APascalName: string;
      const ACallingConvention: string;
      const ALibraryId: string;
      const AExternalSymbolName: string;
      const ASymbolId: LongInt
    ): LongInt;
    function AddLibraryRequest(
      const ALogicalId: string;
      const ALinkageKind: string;
      const AStrength: string
    ): LongInt;
    function SymbolCount: LongInt;
    function SymbolAt(const AIndex: LongInt): TSemanticSymbol;
    function FindTypeByName(const AName: string): LongInt;
    function FindSymbolByName(const AName: string): LongInt;
    function SymbolTypeId(const ASymbolId: LongInt): LongInt;
    function TypeCount: LongInt;
    function TypedHirNodeCount: LongInt;
    function TypedHirNodeAt(const AIndex: LongInt): TTypedHirNode;
    function RuntimeContractCount: LongInt;
    function ForeignProcedureBindingCount: LongInt;
    function ForeignProcedureBindingAt(
      const AIndex: LongInt
    ): TSemanticForeignProcedureBinding;
    function LibraryRequestCount: LongInt;
    function LibraryRequestAt(const AIndex: LongInt): TSemanticLibraryRequest;
    procedure AddConstValue(const AName: string; const AValue: Int64);
    function LookupConstValue(const AName: string;
      out AValue: Int64): Boolean;
    procedure SetRootName(const AName: string);
    function RootName: string;
    procedure MarkReady;
    procedure MarkFailure;
    function Status: string;
  end;

implementation

uses
  SysUtils;

constructor TSemanticModel.Create;
begin
  inherited Create;
  SetLength(FSymbols, 0);
  SetLength(FTypes, 0);
  SetLength(FTypedHirNodes, 0);
  SetLength(FRuntimeContracts, 0);
  SetLength(FForeignProcedureBindings, 0);
  SetLength(FLibraryRequests, 0);
  SetLength(FConstValues, 0);
  FRootName := '';
  FStatus := 'deferred';
end;

function TSemanticModel.AddSymbol(
  const AName: string;
  const AKind: string;
  const AOwnerUnitId: string;
  const ATypeId: LongInt;
  const AByteOffset: LongInt
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FSymbols);
  SetLength(FSymbols, NextIndex + 1);
  FSymbols[NextIndex].SymbolId := NextIndex + 1;
  FSymbols[NextIndex].Name := AName;
  FSymbols[NextIndex].Kind := AKind;
  FSymbols[NextIndex].OwnerUnitId := AOwnerUnitId;
  FSymbols[NextIndex].TypeId := ATypeId;
  FSymbols[NextIndex].ByteOffset := AByteOffset;
  Result := FSymbols[NextIndex].SymbolId;
end;

function TSemanticModel.AddType(
  const AName: string;
  const AKind: string
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FTypes);
  SetLength(FTypes, NextIndex + 1);
  FTypes[NextIndex].TypeId := NextIndex + 1;
  FTypes[NextIndex].Name := AName;
  FTypes[NextIndex].Kind := AKind;
  Result := FTypes[NextIndex].TypeId;
end;

function TSemanticModel.AddTypedHirNode(
  const AKind: string;
  const ADisplayName: string;
  const ASymbolId: LongInt;
  const ATypeId: LongInt;
  const AOperand: string
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FTypedHirNodes);
  SetLength(FTypedHirNodes, NextIndex + 1);
  FTypedHirNodes[NextIndex].HirNodeId := NextIndex + 1;
  FTypedHirNodes[NextIndex].Kind := AKind;
  FTypedHirNodes[NextIndex].DisplayName := ADisplayName;
  FTypedHirNodes[NextIndex].SymbolId := ASymbolId;
  FTypedHirNodes[NextIndex].TypeId := ATypeId;
  FTypedHirNodes[NextIndex].Operand := AOperand;
  Result := FTypedHirNodes[NextIndex].HirNodeId;
end;

function TSemanticModel.AddRuntimeContract(const AName: string): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FRuntimeContracts);
  SetLength(FRuntimeContracts, NextIndex + 1);
  FRuntimeContracts[NextIndex].ContractId := NextIndex + 1;
  FRuntimeContracts[NextIndex].Name := AName;
  Result := FRuntimeContracts[NextIndex].ContractId;
end;

function TSemanticModel.AddForeignProcedureBinding(
  const APascalName: string;
  const ACallingConvention: string;
  const ALibraryId: string;
  const AExternalSymbolName: string;
  const ASymbolId: LongInt
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FForeignProcedureBindings);
  SetLength(FForeignProcedureBindings, NextIndex + 1);
  FForeignProcedureBindings[NextIndex].BindingId := NextIndex + 1;
  FForeignProcedureBindings[NextIndex].PascalName := APascalName;
  FForeignProcedureBindings[NextIndex].CallingConvention := ACallingConvention;
  FForeignProcedureBindings[NextIndex].LibraryId := ALibraryId;
  FForeignProcedureBindings[NextIndex].ExternalSymbolName := AExternalSymbolName;
  FForeignProcedureBindings[NextIndex].SymbolId := ASymbolId;
  Result := FForeignProcedureBindings[NextIndex].BindingId;
end;

function TSemanticModel.AddLibraryRequest(
  const ALogicalId: string;
  const ALinkageKind: string;
  const AStrength: string
): LongInt;
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FLibraryRequests) - 1 do
    if SameText(FLibraryRequests[Index].LogicalId, ALogicalId) and
      SameText(FLibraryRequests[Index].LinkageKind, ALinkageKind) and
      SameText(FLibraryRequests[Index].Strength, AStrength) then
      Exit(FLibraryRequests[Index].RequestId);

  NextIndex := Length(FLibraryRequests);
  SetLength(FLibraryRequests, NextIndex + 1);
  FLibraryRequests[NextIndex].RequestId := NextIndex + 1;
  FLibraryRequests[NextIndex].LogicalId := ALogicalId;
  FLibraryRequests[NextIndex].LinkageKind := ALinkageKind;
  FLibraryRequests[NextIndex].Strength := AStrength;
  Result := FLibraryRequests[NextIndex].RequestId;
end;

function TSemanticModel.SymbolCount: LongInt;
begin
  Result := Length(FSymbols);
end;

function TSemanticModel.SymbolAt(const AIndex: LongInt): TSemanticSymbol;
begin
  if (AIndex < 0) or (AIndex >= Length(FSymbols)) then
  begin
    Result.SymbolId := 0;
    Result.Name := '';
    Result.Kind := '';
    Result.OwnerUnitId := '';
    Result.TypeId := 0;
    Result.ByteOffset := 0;
    Exit;
  end;
  Result := FSymbols[AIndex];
end;

function TSemanticModel.FindTypeByName(const AName: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FTypes) - 1 do
    if SameText(FTypes[Index].Name, AName) then
      Exit(FTypes[Index].TypeId);
  Result := 0;
end;

function TSemanticModel.FindSymbolByName(const AName: string): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FSymbols) - 1 do
    if SameText(FSymbols[Index].Name, AName) then
      Exit(FSymbols[Index].SymbolId);
  Result := 0;
end;

function TSemanticModel.SymbolTypeId(const ASymbolId: LongInt): LongInt;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FSymbols) - 1 do
    if FSymbols[Index].SymbolId = ASymbolId then
      Exit(FSymbols[Index].TypeId);
  Result := 0;
end;

function TSemanticModel.TypeCount: LongInt;
begin
  Result := Length(FTypes);
end;

function TSemanticModel.TypedHirNodeCount: LongInt;
begin
  Result := Length(FTypedHirNodes);
end;

function TSemanticModel.TypedHirNodeAt(const AIndex: LongInt): TTypedHirNode;
begin
  if (AIndex < 0) or (AIndex >= Length(FTypedHirNodes)) then
  begin
    Result.HirNodeId := 0;
    Result.Kind := '';
    Result.DisplayName := '';
    Result.SymbolId := 0;
    Result.TypeId := 0;
    Exit;
  end;

  Result := FTypedHirNodes[AIndex];
end;

function TSemanticModel.RuntimeContractCount: LongInt;
begin
  Result := Length(FRuntimeContracts);
end;

function TSemanticModel.ForeignProcedureBindingCount: LongInt;
begin
  Result := Length(FForeignProcedureBindings);
end;

function TSemanticModel.ForeignProcedureBindingAt(
  const AIndex: LongInt
): TSemanticForeignProcedureBinding;
begin
  if (AIndex < 0) or (AIndex >= Length(FForeignProcedureBindings)) then
  begin
    Result.BindingId := 0;
    Result.PascalName := '';
    Result.CallingConvention := '';
    Result.LibraryId := '';
    Result.ExternalSymbolName := '';
    Result.SymbolId := 0;
    Exit;
  end;

  Result := FForeignProcedureBindings[AIndex];
end;

function TSemanticModel.LibraryRequestCount: LongInt;
begin
  Result := Length(FLibraryRequests);
end;

function TSemanticModel.LibraryRequestAt(
  const AIndex: LongInt
): TSemanticLibraryRequest;
begin
  if (AIndex < 0) or (AIndex >= Length(FLibraryRequests)) then
  begin
    Result.RequestId := 0;
    Result.LogicalId := '';
    Result.LinkageKind := '';
    Result.Strength := '';
    Exit;
  end;

  Result := FLibraryRequests[AIndex];
end;

procedure TSemanticModel.AddConstValue(const AName: string; const AValue: Int64);
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FConstValues) - 1 do
    if SameText(FConstValues[Index].Name, AName) then
    begin
      FConstValues[Index].Value := AValue;
      Exit;
    end;
  NextIndex := Length(FConstValues);
  SetLength(FConstValues, NextIndex + 1);
  FConstValues[NextIndex].Name := AName;
  FConstValues[NextIndex].Value := AValue;
end;

function TSemanticModel.LookupConstValue(const AName: string;
  out AValue: Int64): Boolean;
var
  Index: LongInt;
begin
  AValue := 0;
  for Index := 0 to Length(FConstValues) - 1 do
    if SameText(FConstValues[Index].Name, AName) then
    begin
      AValue := FConstValues[Index].Value;
      Exit(True);
    end;
  Result := False;
end;

procedure TSemanticModel.SetRootName(const AName: string);
begin
  FRootName := AName;
end;

function TSemanticModel.RootName: string;
begin
  Result := FRootName;
end;

procedure TSemanticModel.MarkReady;
begin
  FStatus := 'ready';
end;

procedure TSemanticModel.MarkFailure;
begin
  FStatus := 'failure';
end;

function TSemanticModel.Status: string;
begin
  Result := FStatus;
end;

end.
