unit np_mir_model;

{$mode objfpc}{$H+}
{$UNITPATH ../sema}

interface

uses
  np_semantic_model;

type
  TMirValueId = LongInt;
  TMirTypeKind = (mtkVoid, mtkI1, mtkI64, mtkPtr);

  TMirValue = record
    ValueId: TMirValueId;
    TypeKind: TMirTypeKind;
    DefiningOpId: LongInt;
    ConstHasValue: Boolean;
    ConstInt: Int64;
    GlobalSymbol: string;
    DebugName: string;
  end;

  TMirOperandRefKind = (
    morkValue,
    morkLiteralInt,
    morkBlockLabel,
    morkGlobal
  );

  TMirOperandRef = record
    Kind: TMirOperandRefKind;
    ValueId: TMirValueId;
    LiteralInt: Int64;
    BlockId: LongInt;
    GlobalSymbol: string;
  end;

  TMirOperandRefs = array of TMirOperandRef;
  TLongIntArray = array of LongInt;

  TMirBlock = record
    BlockId: LongInt;
    LabelName: string;
    PredIds: TLongIntArray;
    SuccIds: TLongIntArray;
    TerminatorOpId: LongInt;
  end;

  TMirOperation = record
    OperationId: LongInt;
    Kind: string;
    BlockId: LongInt;
    DisplayName: string;
    Operand: string;
    ResultValueId: TMirValueId;
    OperandRefs: TMirOperandRefs;
  end;

  TMirModel = class
  private
    FBlocks: array of TMirBlock;
    FOperations: array of TMirOperation;
    FValues: array of TMirValue;
    FRootName: string;
    FStatus: string;
  public
    constructor Create;
    function AddBlock(const ALabelName: string): LongInt;
    function AddOperation(
      const AKind: string;
      const ABlockId: LongInt;
      const ADisplayName: string;
      const AOperand: string
    ): LongInt;
    function AddOperationWithResult(
      const AKind: string;
      const ABlockId: LongInt;
      const ADisplayName: string;
      const AOperand: string;
      const AResultValueId: TMirValueId;
      const AOperandRefs: TMirOperandRefs
    ): LongInt;
    function AddValue(
      const ATypeKind: TMirTypeKind;
      const ADefiningOpId: LongInt;
      const ADebugName: string
    ): TMirValueId;
    function AddConstIntValue(const AValue: Int64): TMirValueId;
    function AddGlobalPtrValue(const ASymbol: string): TMirValueId;
    procedure AddSuccEdge(const AFromBlockId, AToBlockId: LongInt);
    procedure SetTerminator(const ABlockId, AOpId: LongInt);
    function GetValue(const AValueId: TMirValueId): TMirValue;
    function ValueCount: LongInt;
    function BlockCount: LongInt;
    function BlockAt(const AIndex: LongInt): TMirBlock;
    function OperationCount: LongInt;
    function OperationAt(const AIndex: LongInt): TMirOperation;
    function EntryBlockLabel: string;
    function HasRuntimeKinds: Boolean;
    procedure SetRootName(const AName: string);
    function RootName: string;
    procedure MarkReady;
    procedure MarkFailure;
    function Status: string;
  end;

  TMirLowerer = class
  private
    FSemanticModel: TSemanticModel;
    FModel: TMirModel;
    function MirKindForTypedHirNode(const ANode: TTypedHirNode): string;
  public
    constructor Create(const ASemanticModel: TSemanticModel);
    destructor Destroy; override;
    procedure Lower;
    function DetachModel: TMirModel;
  end;

function MakeValueOperand(const AValueId: TMirValueId): TMirOperandRef;
function MakeLiteralIntOperand(const AValue: Int64): TMirOperandRef;
function MakeBlockLabelOperand(const ABlockId: LongInt): TMirOperandRef;
function MakeGlobalOperand(const ASymbol: string): TMirOperandRef;

implementation

uses
  SysUtils;

function MakeValueOperand(const AValueId: TMirValueId): TMirOperandRef;
begin
  Result.Kind := morkValue;
  Result.ValueId := AValueId;
  Result.LiteralInt := 0;
  Result.BlockId := 0;
  Result.GlobalSymbol := '';
end;

function MakeLiteralIntOperand(const AValue: Int64): TMirOperandRef;
begin
  Result.Kind := morkLiteralInt;
  Result.ValueId := 0;
  Result.LiteralInt := AValue;
  Result.BlockId := 0;
  Result.GlobalSymbol := '';
end;

function MakeBlockLabelOperand(const ABlockId: LongInt): TMirOperandRef;
begin
  Result.Kind := morkBlockLabel;
  Result.ValueId := 0;
  Result.LiteralInt := 0;
  Result.BlockId := ABlockId;
  Result.GlobalSymbol := '';
end;

function MakeGlobalOperand(const ASymbol: string): TMirOperandRef;
begin
  Result.Kind := morkGlobal;
  Result.ValueId := 0;
  Result.LiteralInt := 0;
  Result.BlockId := 0;
  Result.GlobalSymbol := ASymbol;
end;

constructor TMirModel.Create;
begin
  inherited Create;
  SetLength(FBlocks, 0);
  SetLength(FOperations, 0);
  SetLength(FValues, 0);
  FRootName := '';
  FStatus := 'deferred';
end;

function TMirModel.AddBlock(const ALabelName: string): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FBlocks);
  SetLength(FBlocks, NextIndex + 1);
  FBlocks[NextIndex].BlockId := NextIndex + 1;
  FBlocks[NextIndex].LabelName := ALabelName;
  SetLength(FBlocks[NextIndex].PredIds, 0);
  SetLength(FBlocks[NextIndex].SuccIds, 0);
  FBlocks[NextIndex].TerminatorOpId := 0;
  Result := FBlocks[NextIndex].BlockId;
end;

function TMirModel.AddOperation(
  const AKind: string;
  const ABlockId: LongInt;
  const ADisplayName: string;
  const AOperand: string
): LongInt;
var
  EmptyRefs: TMirOperandRefs;
begin
  SetLength(EmptyRefs, 0);
  Result := AddOperationWithResult(
    AKind, ABlockId, ADisplayName, AOperand, 0, EmptyRefs
  );
end;

function TMirModel.AddOperationWithResult(
  const AKind: string;
  const ABlockId: LongInt;
  const ADisplayName: string;
  const AOperand: string;
  const AResultValueId: TMirValueId;
  const AOperandRefs: TMirOperandRefs
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FOperations);
  SetLength(FOperations, NextIndex + 1);
  FOperations[NextIndex].OperationId := NextIndex + 1;
  FOperations[NextIndex].Kind := AKind;
  FOperations[NextIndex].BlockId := ABlockId;
  FOperations[NextIndex].DisplayName := ADisplayName;
  FOperations[NextIndex].Operand := AOperand;
  FOperations[NextIndex].ResultValueId := AResultValueId;
  FOperations[NextIndex].OperandRefs := AOperandRefs;
  Result := FOperations[NextIndex].OperationId;
end;

function TMirModel.AddValue(
  const ATypeKind: TMirTypeKind;
  const ADefiningOpId: LongInt;
  const ADebugName: string
): TMirValueId;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FValues);
  SetLength(FValues, NextIndex + 1);
  FValues[NextIndex].ValueId := NextIndex + 1;
  FValues[NextIndex].TypeKind := ATypeKind;
  FValues[NextIndex].DefiningOpId := ADefiningOpId;
  FValues[NextIndex].ConstHasValue := False;
  FValues[NextIndex].ConstInt := 0;
  FValues[NextIndex].GlobalSymbol := '';
  FValues[NextIndex].DebugName := ADebugName;
  Result := FValues[NextIndex].ValueId;
end;

function TMirModel.AddConstIntValue(const AValue: Int64): TMirValueId;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FValues);
  SetLength(FValues, NextIndex + 1);
  FValues[NextIndex].ValueId := NextIndex + 1;
  FValues[NextIndex].TypeKind := mtkI64;
  FValues[NextIndex].DefiningOpId := 0;
  FValues[NextIndex].ConstHasValue := True;
  FValues[NextIndex].ConstInt := AValue;
  FValues[NextIndex].GlobalSymbol := '';
  FValues[NextIndex].DebugName := '';
  Result := FValues[NextIndex].ValueId;
end;

function TMirModel.AddGlobalPtrValue(const ASymbol: string): TMirValueId;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FValues);
  SetLength(FValues, NextIndex + 1);
  FValues[NextIndex].ValueId := NextIndex + 1;
  FValues[NextIndex].TypeKind := mtkPtr;
  FValues[NextIndex].DefiningOpId := 0;
  FValues[NextIndex].ConstHasValue := False;
  FValues[NextIndex].ConstInt := 0;
  FValues[NextIndex].GlobalSymbol := ASymbol;
  FValues[NextIndex].DebugName := ASymbol;
  Result := FValues[NextIndex].ValueId;
end;

procedure TMirModel.AddSuccEdge(const AFromBlockId, AToBlockId: LongInt);
var
  FromIdx, ToIdx: LongInt;
  Last: SizeInt;
begin
  FromIdx := AFromBlockId - 1;
  ToIdx := AToBlockId - 1;
  if (FromIdx < 0) or (FromIdx >= Length(FBlocks)) then
    Exit;
  if (ToIdx < 0) or (ToIdx >= Length(FBlocks)) then
    Exit;
  Last := Length(FBlocks[FromIdx].SuccIds);
  SetLength(FBlocks[FromIdx].SuccIds, Last + 1);
  FBlocks[FromIdx].SuccIds[Last] := AToBlockId;
  Last := Length(FBlocks[ToIdx].PredIds);
  SetLength(FBlocks[ToIdx].PredIds, Last + 1);
  FBlocks[ToIdx].PredIds[Last] := AFromBlockId;
end;

procedure TMirModel.SetTerminator(const ABlockId, AOpId: LongInt);
var
  Idx: LongInt;
begin
  Idx := ABlockId - 1;
  if (Idx < 0) or (Idx >= Length(FBlocks)) then
    Exit;
  FBlocks[Idx].TerminatorOpId := AOpId;
end;

function TMirModel.GetValue(const AValueId: TMirValueId): TMirValue;
var
  Idx: LongInt;
begin
  Idx := AValueId - 1;
  if (Idx < 0) or (Idx >= Length(FValues)) then
  begin
    Result.ValueId := 0;
    Result.TypeKind := mtkVoid;
    Result.DefiningOpId := 0;
    Result.ConstHasValue := False;
    Result.ConstInt := 0;
    Result.GlobalSymbol := '';
    Result.DebugName := '';
    Exit;
  end;
  Result := FValues[Idx];
end;

function TMirModel.ValueCount: LongInt;
begin
  Result := Length(FValues);
end;

function TMirModel.BlockCount: LongInt;
begin
  Result := Length(FBlocks);
end;

function TMirModel.BlockAt(const AIndex: LongInt): TMirBlock;
begin
  if (AIndex < 0) or (AIndex >= Length(FBlocks)) then
  begin
    Result.BlockId := 0;
    Result.LabelName := '';
    SetLength(Result.PredIds, 0);
    SetLength(Result.SuccIds, 0);
    Result.TerminatorOpId := 0;
    Exit;
  end;
  Result := FBlocks[AIndex];
end;

function TMirModel.OperationCount: LongInt;
begin
  Result := Length(FOperations);
end;

function TMirModel.OperationAt(const AIndex: LongInt): TMirOperation;
var
  EmptyRefs: TMirOperandRefs;
begin
  if (AIndex < 0) or (AIndex >= Length(FOperations)) then
  begin
    SetLength(EmptyRefs, 0);
    Result.OperationId := 0;
    Result.Kind := '';
    Result.BlockId := 0;
    Result.DisplayName := '';
    Result.Operand := '';
    Result.ResultValueId := 0;
    Result.OperandRefs := EmptyRefs;
    Exit;
  end;
  Result := FOperations[AIndex];
end;

function TMirModel.EntryBlockLabel: string;
begin
  if Length(FBlocks) = 0 then
    Exit('');

  Result := FBlocks[0].LabelName;
end;

function TMirModel.HasRuntimeKinds: Boolean;
var
  Index: LongInt;
  Kind: string;
begin
  for Index := 0 to Length(FOperations) - 1 do
  begin
    Kind := FOperations[Index].Kind;
    if (Kind = 'alloca') or
      (Kind = 'store') or
      (Kind = 'load') or
      (Kind = 'add') or
      (Kind = 'sub') or
      (Kind = 'mul') or
      (Kind = 'icmp-eq') or
      (Kind = 'icmp-ne') or
      (Kind = 'icmp-slt') or
      (Kind = 'icmp-sle') or
      (Kind = 'icmp-sgt') or
      (Kind = 'icmp-sge') or
      (Kind = 'br') or
      (Kind = 'cond-br') or
      (Kind = 'argc-load') or
      (Kind = 'runtime-halt') or
      (Kind = 'runtime-return') then
      Exit(True);
  end;
  Result := False;
end;

procedure TMirModel.SetRootName(const AName: string);
begin
  FRootName := AName;
end;

function TMirModel.RootName: string;
begin
  Result := FRootName;
end;

procedure TMirModel.MarkReady;
begin
  FStatus := 'ready';
end;

procedure TMirModel.MarkFailure;
begin
  FStatus := 'failure';
end;

function TMirModel.Status: string;
begin
  Result := FStatus;
end;

function TMirLowerer.MirKindForTypedHirNode(const ANode: TTypedHirNode): string;
begin
  if ANode.Kind = 'compilation-root' then
    Exit('enter-root');
  if ANode.Kind = 'resolved-unit' then
    Exit('unit-ref');
  if ANode.Kind = 'runtime-contract' then
    Exit('runtime-contract-call');
  if ANode.Kind = 'halt-call' then
    Exit('halt');
  if ANode.Kind = 'write-call' then
    Exit('write-line');

  Result := 'typed-hir-node';
end;

constructor TMirLowerer.Create(const ASemanticModel: TSemanticModel);
begin
  inherited Create;
  FSemanticModel := ASemanticModel;
  FModel := TMirModel.Create;
end;

destructor TMirLowerer.Destroy;
begin
  FModel.Free;
  inherited Destroy;
end;

procedure TMirLowerer.Lower;
var
  BlockId: LongInt;
  Index: LongInt;
  Node: TTypedHirNode;
begin
  if (FSemanticModel = nil) or (FSemanticModel.Status <> 'ready') then
  begin
    FModel.MarkFailure;
    Exit;
  end;

  FModel.SetRootName(FSemanticModel.RootName);
  BlockId := FModel.AddBlock('entry');

  for Index := 0 to FSemanticModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemanticModel.TypedHirNodeAt(Index);
    FModel.AddOperation(
      MirKindForTypedHirNode(Node),
      BlockId,
      Node.DisplayName,
      Node.Operand
    );
  end;

  FModel.AddOperation('return', BlockId, FSemanticModel.RootName, '');
  FModel.MarkReady;
end;

function TMirLowerer.DetachModel: TMirModel;
begin
  Result := FModel;
  FModel := nil;
end;

end.
