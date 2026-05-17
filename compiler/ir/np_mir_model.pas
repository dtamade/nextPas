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
    function BlockById(const ABlockId: LongInt): TMirBlock;
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

  TMirAllocaEntry = record
    Name: string;
    AllocaValueId: TMirValueId;
  end;

  TMirBlockEntry = record
    Name: string;
    BlockId: LongInt;
  end;

  TMirLowerer = class
  private
    FSemanticModel: TSemanticModel;
    FModel: TMirModel;
    FEntryBlockId: LongInt;
    FCurrentBlockId: LongInt;
    FAllocaTable: array of TMirAllocaEntry;
    FBlockTable: array of TMirBlockEntry;
    function MirKindForTypedHirNode(const ANode: TTypedHirNode): string;
    function EnsureAlloca(
      const AName: string;
      const ABlockId: LongInt
    ): TMirValueId;
    function EnsureBlock(const AName: string): LongInt;
    function LowerVarLoadRuntime(
      const AName: string;
      const ABlockId: LongInt
    ): TMirValueId;
    function LowerRuntimeIntBlob(
      const ABlob: string;
      const ABlockId: LongInt;
      out AThenLabel, AElseLabel: string
    ): TMirValueId;
    function LowerHaltRuntimeBlob(
      const ABlob: string;
      const ABlockId: LongInt
    ): TMirValueId;
    procedure LowerAssignRuntime(
      const AOperand: string;
      const ABlockId: LongInt
    );
    procedure LowerCondBrRuntime(const AOperand: string);
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

function TMirModel.BlockById(const ABlockId: LongInt): TMirBlock;
var
  Index: LongInt;
begin
  for Index := 0 to Length(FBlocks) - 1 do
    if FBlocks[Index].BlockId = ABlockId then
    begin
      Result := FBlocks[Index];
      Exit;
    end;
  Result.BlockId := 0;
  Result.LabelName := '';
  SetLength(Result.PredIds, 0);
  SetLength(Result.SuccIds, 0);
  Result.TerminatorOpId := 0;
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
      (Kind = 'runtime-return') or
      (Kind = 'write-int') then
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
  FEntryBlockId := 0;
end;

destructor TMirLowerer.Destroy;
begin
  FModel.Free;
  inherited Destroy;
end;

function TMirLowerer.EnsureAlloca(
  const AName: string;
  const ABlockId: LongInt
): TMirValueId;
var
  Index: LongInt;
  AllocaResult: TMirValueId;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FAllocaTable) - 1 do
    if FAllocaTable[Index].Name = AName then
      Exit(FAllocaTable[Index].AllocaValueId);
  AllocaResult := FModel.AddValue(mtkPtr, 0, AName);
  FModel.AddOperationWithResult(
    'alloca', ABlockId, AName, AName, AllocaResult, nil
  );
  NextIndex := Length(FAllocaTable);
  SetLength(FAllocaTable, NextIndex + 1);
  FAllocaTable[NextIndex].Name := AName;
  FAllocaTable[NextIndex].AllocaValueId := AllocaResult;
  Result := AllocaResult;
end;

function TMirLowerer.LowerVarLoadRuntime(
  const AName: string;
  const ABlockId: LongInt
): TMirValueId;
var
  AllocaResult, LoadResult: TMirValueId;
  Operands: TMirOperandRefs;
begin
  AllocaResult := EnsureAlloca(AName, ABlockId);
  LoadResult := FModel.AddValue(mtkI64, 0, AName);
  SetLength(Operands, 1);
  Operands[0] := MakeValueOperand(AllocaResult);
  FModel.AddOperationWithResult(
    'load', ABlockId, AName, AName, LoadResult, Operands
  );
  Result := LoadResult;
end;

function TMirLowerer.LowerRuntimeIntBlob(
  const ABlob: string;
  const ABlockId: LongInt;
  out AThenLabel, AElseLabel: string
): TMirValueId;
var
  Stack: array of TMirValueId;
  StackLen: SizeInt;
  Cursor, BlobLen, TabIdx: SizeInt;
  Token, Arg: string;
  Parsed: Int64;
  ParseCode: Word;
  Lhs, Rhs, Res: TMirValueId;
  Operands: TMirOperandRefs;

  procedure StackPush(const AId: TMirValueId);
  begin
    StackLen := Length(Stack);
    SetLength(Stack, StackLen + 1);
    Stack[StackLen] := AId;
  end;

  function StackPop: TMirValueId;
  begin
    StackLen := Length(Stack) - 1;
    if StackLen < 0 then
      Exit(0);
    Result := Stack[StackLen];
    SetLength(Stack, StackLen);
  end;

  function ReadLineToken(out AOp: string; out AArg: string): Boolean;
  var
    LineEnd, SpacePos: SizeInt;
    Line: string;
  begin
    AOp := '';
    AArg := '';
    if Cursor > BlobLen then
      Exit(False);
    LineEnd := Cursor;
    while (LineEnd <= BlobLen) and (ABlob[LineEnd] <> #10) do
      Inc(LineEnd);
    Line := Copy(ABlob, Cursor, LineEnd - Cursor);
    Cursor := LineEnd + 1;
    if Line = '' then
    begin
      Result := False;
      Exit;
    end;
    SpacePos := Pos(' ', Line);
    if SpacePos = 0 then
    begin
      AOp := Line;
      AArg := '';
    end
    else
    begin
      AOp := Copy(Line, 1, SpacePos - 1);
      AArg := Copy(Line, SpacePos + 1, Length(Line) - SpacePos);
    end;
    Result := True;
  end;

begin
  AThenLabel := '';
  AElseLabel := '';
  SetLength(Stack, 0);
  Cursor := 1;
  BlobLen := Length(ABlob);
  while ReadLineToken(Token, Arg) do
  begin
    if Token = 'int' then
    begin
      Val(Arg, Parsed, ParseCode);
      if ParseCode <> 0 then
        Exit(0);
      StackPush(FModel.AddConstIntValue(Parsed));
    end
    else if Token = 'var' then
    begin
      Res := LowerVarLoadRuntime(Arg, ABlockId);
      if Res = 0 then
        Exit(0);
      StackPush(Res);
    end
    else if (Token = 'add') or (Token = 'sub') or (Token = 'mul') then
    begin
      Rhs := StackPop;
      Lhs := StackPop;
      if (Lhs = 0) or (Rhs = 0) then
        Exit(0);
      Res := FModel.AddValue(mtkI64, 0, Token);
      SetLength(Operands, 2);
      Operands[0] := MakeValueOperand(Lhs);
      Operands[1] := MakeValueOperand(Rhs);
      FModel.AddOperationWithResult(
        Token, ABlockId, Token, '', Res, Operands
      );
      StackPush(Res);
    end
    else if Token = 'neg' then
    begin
      Rhs := StackPop;
      if Rhs = 0 then
        Exit(0);
      Lhs := FModel.AddConstIntValue(0);
      Res := FModel.AddValue(mtkI64, 0, Token);
      SetLength(Operands, 2);
      Operands[0] := MakeValueOperand(Lhs);
      Operands[1] := MakeValueOperand(Rhs);
      FModel.AddOperationWithResult(
        'sub', ABlockId, Token, '', Res, Operands
      );
      StackPush(Res);
    end
    else if Token = 'cmp' then
    begin
      Rhs := StackPop;
      Lhs := StackPop;
      if (Lhs = 0) or (Rhs = 0) then
        Exit(0);
      Res := FModel.AddValue(mtkI1, 0, 'cmp-' + Arg);
      SetLength(Operands, 2);
      Operands[0] := MakeValueOperand(Lhs);
      Operands[1] := MakeValueOperand(Rhs);
      FModel.AddOperationWithResult(
        'icmp-' + Arg, ABlockId, 'cmp', '', Res, Operands
      );
      StackPush(Res);
    end
    else if Token = 'labels' then
    begin
      TabIdx := Pos(#9, Arg);
      if TabIdx <= 0 then
        Exit(0);
      AThenLabel := Copy(Arg, 1, TabIdx - 1);
      AElseLabel := Copy(Arg, TabIdx + 1, Length(Arg) - TabIdx);
    end
    else
      Exit(0);
  end;
  if Length(Stack) <> 1 then
    Exit(0);
  Result := Stack[0];
end;

function TMirLowerer.LowerHaltRuntimeBlob(
  const ABlob: string;
  const ABlockId: LongInt
): TMirValueId;
var
  ThenLabel, ElseLabel: string;
begin
  Result := LowerRuntimeIntBlob(ABlob, ABlockId, ThenLabel, ElseLabel);
end;

procedure TMirLowerer.LowerAssignRuntime(
  const AOperand: string;
  const ABlockId: LongInt
);
var
  TabPos: SizeInt;
  Name, Blob, ThenLabel, ElseLabel: string;
  RhsValue, AllocaResult: TMirValueId;
  StoreOperands: TMirOperandRefs;
begin
  TabPos := Pos(#9, AOperand);
  if TabPos <= 0 then
    Exit;
  Name := Copy(AOperand, 1, TabPos - 1);
  Blob := Copy(AOperand, TabPos + 1, Length(AOperand) - TabPos);
  if Name = '' then
    Exit;
  AllocaResult := EnsureAlloca(Name, ABlockId);
  RhsValue := LowerRuntimeIntBlob(Blob, ABlockId, ThenLabel, ElseLabel);
  if RhsValue = 0 then
    Exit;
  SetLength(StoreOperands, 2);
  StoreOperands[0] := MakeValueOperand(RhsValue);
  StoreOperands[1] := MakeValueOperand(AllocaResult);
  FModel.AddOperationWithResult(
    'store', ABlockId, Name, '', 0, StoreOperands
  );
end;

function TMirLowerer.EnsureBlock(const AName: string): LongInt;
var
  Index: LongInt;
  NextIndex: SizeInt;
begin
  for Index := 0 to Length(FBlockTable) - 1 do
    if FBlockTable[Index].Name = AName then
      Exit(FBlockTable[Index].BlockId);
  Result := FModel.AddBlock(AName);
  NextIndex := Length(FBlockTable);
  SetLength(FBlockTable, NextIndex + 1);
  FBlockTable[NextIndex].Name := AName;
  FBlockTable[NextIndex].BlockId := Result;
end;

procedure TMirLowerer.LowerCondBrRuntime(const AOperand: string);
var
  CondValue: TMirValueId;
  ThenLabel, ElseLabel: string;
  ThenBlockId, ElseBlockId: LongInt;
  Operands: TMirOperandRefs;
begin
  CondValue := LowerRuntimeIntBlob(
    AOperand, FCurrentBlockId, ThenLabel, ElseLabel
  );
  if (CondValue = 0) or (ThenLabel = '') or (ElseLabel = '') then
    Exit;
  ThenBlockId := EnsureBlock(ThenLabel);
  ElseBlockId := EnsureBlock(ElseLabel);
  SetLength(Operands, 3);
  Operands[0] := MakeValueOperand(CondValue);
  Operands[1] := MakeBlockLabelOperand(ThenBlockId);
  Operands[2] := MakeBlockLabelOperand(ElseBlockId);
  FModel.AddOperationWithResult(
    'cond-br', FCurrentBlockId, 'cond-br', '', 0, Operands
  );
end;

procedure TMirLowerer.Lower;
var
  Index: LongInt;
  Node: TTypedHirNode;
  ExitValue: TMirValueId;
  Operands: TMirOperandRefs;
begin
  if (FSemanticModel = nil) or (FSemanticModel.Status <> 'ready') then
  begin
    FModel.MarkFailure;
    Exit;
  end;

  FModel.SetRootName(FSemanticModel.RootName);
  FEntryBlockId := FModel.AddBlock('entry');
  FCurrentBlockId := FEntryBlockId;
  SetLength(FBlockTable, 1);
  FBlockTable[0].Name := 'entry';
  FBlockTable[0].BlockId := FEntryBlockId;

  for Index := 0 to FSemanticModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemanticModel.TypedHirNodeAt(Index);
    if Node.Kind = 'var-decl-runtime' then
    begin
      EnsureAlloca(Node.Operand, FEntryBlockId);
      Continue;
    end;
    if Node.Kind = 'assign-runtime' then
    begin
      LowerAssignRuntime(Node.Operand, FCurrentBlockId);
      Continue;
    end;
    if Node.Kind = 'cond-br-runtime' then
    begin
      LowerCondBrRuntime(Node.Operand);
      Continue;
    end;
    if Node.Kind = 'br-runtime' then
    begin
      SetLength(Operands, 1);
      Operands[0] := MakeBlockLabelOperand(EnsureBlock(Node.Operand));
      FModel.AddOperationWithResult(
        'br', FCurrentBlockId, 'br', '', 0, Operands
      );
      Continue;
    end;
    if Node.Kind = 'block-label-runtime' then
    begin
      FCurrentBlockId := EnsureBlock(Node.Operand);
      Continue;
    end;
    if Node.Kind = 'write-string-runtime' then
    begin
      FModel.AddOperation(
        'write-line', FCurrentBlockId, Node.DisplayName, Node.Operand
      );
      Continue;
    end;
    if Node.Kind = 'write-int-runtime' then
    begin
      ExitValue := LowerHaltRuntimeBlob(Node.Operand, FCurrentBlockId);
      if ExitValue = 0 then
      begin
        FModel.MarkFailure;
        Exit;
      end;
      SetLength(Operands, 1);
      Operands[0] := MakeValueOperand(ExitValue);
      FModel.AddOperationWithResult(
        'write-int', FCurrentBlockId, 'WriteInt', '', 0, Operands
      );
      Continue;
    end;
    if Node.Kind = 'halt-call-runtime' then
    begin
      ExitValue := LowerHaltRuntimeBlob(Node.Operand, FCurrentBlockId);
      if ExitValue = 0 then
      begin
        FModel.MarkFailure;
        Exit;
      end;
      SetLength(Operands, 1);
      Operands[0] := MakeValueOperand(ExitValue);
      FModel.AddOperationWithResult(
        'runtime-halt', FCurrentBlockId, 'Halt', '', 0, Operands
      );
      Continue;
    end;
    FModel.AddOperation(
      MirKindForTypedHirNode(Node),
      FEntryBlockId,
      Node.DisplayName,
      Node.Operand
    );
  end;

  FModel.AddOperation('return', FEntryBlockId, FSemanticModel.RootName, '');
  FModel.MarkReady;
end;

function TMirLowerer.DetachModel: TMirModel;
begin
  Result := FModel;
  FModel := nil;
end;

end.
